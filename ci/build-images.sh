#!/bin/sh
# 构建 ingress-nginx Fork 的三个镜像（nginx 基础镜像 / controller / kube-webhook-certgen）。
# 该脚本同时被 .gitlab-ci.yml 与本地演练调用，保证「CI 跑的」和「本地跑的」是同一条命令。
#
# 用法：
#   REG=reg.yondervision.com.cn:8081 NS=library/ingress-nginx TAG=v1.30.7 \
#     PUSH=0 BUILD_NGINX=0 BASE_IMAGE=.../nginx:v1.30.7 sh ci/build-images.sh
#
# 关键环境变量：
#   REG / NS / TAG        必填，镜像仓库、项目路径、版本 tag
#   ARCH                  默认 amd64
#   PUSH                  1=构建并推送，0=只构建（默认 1）
#   BUILD_NGINX           1=先构建 nginx 基础镜像，0=复用 BASE_IMAGE（默认 1）
#   BASE_IMAGE            BUILD_NGINX=0 时使用的基础镜像
#   BUILD_EXTRA_ARGS      透传给 docker build 的额外参数，例如
#                         "--build-arg HTTP_PROXY=http://172.29.13.25:7890 ..."
#                         （nginx 基础镜像内的 git clone/curl 需要外网，内网 runner 常用）

set -eu

# certgen 的 Dockerfile 使用 FROM --platform=$BUILDPLATFORM：legacy builder 无法解析，
# 必须用 BuildKit。这里显式开启并做前置检查，避免跑到第 4 个镜像才失败。
export DOCKER_BUILDKIT=1
if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx 不可用；kube-webhook-certgen 镜像必须用 BuildKit 构建" >&2
  exit 1
fi

# shellcheck disable=SC2086  # BUILD_EXTRA_ARGS 需要按空格拆分

REG=${REG:?REG is required (e.g. reg.yondervision.com.cn:8081)}
NS=${NS:?NS is required (e.g. library/ingress-nginx)}
TAG=${TAG:?TAG is required (e.g. v1.30.7)}

ARCH=${ARCH:-amd64}
NGINX_TAG=${NGINX_TAG:-$TAG}
PUSH=${PUSH:-1}
BUILD_NGINX=${BUILD_NGINX:-1}
BASE_IMAGE=${BASE_IMAGE:-"$REG/$NS/nginx:$NGINX_TAG"}
BUILD_EXTRA_ARGS=${BUILD_EXTRA_ARGS:-}

GOLANG_VERSION=$(cat GOLANG_VERSION)
CERTGEN_TAG=$(cat images/kube-webhook-certgen/TAG)
COMMIT=${CI_COMMIT_SHA:-}
REPO=${CI_PROJECT_URL:-}
if [ -z "$COMMIT" ] && command -v git >/dev/null 2>&1; then
  COMMIT=$(git rev-parse HEAD)
fi
COMMIT=${COMMIT:-unknown}
REPO=${REPO:-unknown}

BUILDER_IMAGE=${BUILDER_IMAGE:-ingress-nginx/ci-builder:$TAG}
ARTIFACT_DIR=${ARTIFACT_DIR:-ci-artifacts}

echo "============================================================"
echo " registry      : $REG"
echo " project       : $NS"
echo " tag           : $TAG"
echo " arch          : $ARCH"
echo " go            : $GOLANG_VERSION"
echo " certgen tag   : $CERTGEN_TAG"
echo " build nginx   : $BUILD_NGINX"
echo " push          : $PUSH"
echo "============================================================"

# ---------- 1. 编译三个二进制 ----------
echo "[1/4] build controller binaries (docker build + docker cp)"
docker build $BUILD_EXTRA_ARGS \
  -f build/ci/Dockerfile.builder \
  --build-arg GOLANG_VERSION="$GOLANG_VERSION" \
  --build-arg VERSION="$TAG" \
  --build-arg COMMIT_SHA="$COMMIT" \
  --build-arg REPO_INFO="$REPO" \
  -t "$BUILDER_IMAGE" .

rm -rf "rootfs/bin/$ARCH"
mkdir -p "rootfs/bin/$ARCH"

container_id=$(docker create "$BUILDER_IMAGE")
# docker cp 走 CLI 流式传输，不依赖宿主机路径映射（runner 挂的是宿主 socket）
docker cp "$container_id:/out/." "rootfs/bin/$ARCH/"
docker rm "$container_id" >/dev/null
ls -l "rootfs/bin/$ARCH"

# ---------- 2. nginx 基础镜像 ----------
if [ "$BUILD_NGINX" = "1" ]; then
  echo "[2/4] build nginx base image ($REG/$NS/nginx:$NGINX_TAG)"
  docker build $BUILD_EXTRA_ARGS \
    -t "$REG/$NS/nginx:$NGINX_TAG" \
    images/nginx/rootfs
else
  echo "[2/4] skip nginx base image, reuse $BASE_IMAGE"
fi

# ---------- 3. controller 镜像 ----------
echo "[3/4] build controller image ($REG/$NS/controller:$TAG)"
docker build $BUILD_EXTRA_ARGS \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  --build-arg TARGETARCH="$ARCH" \
  --build-arg VERSION="$TAG" \
  --build-arg COMMIT_SHA="$COMMIT" \
  --build-arg BUILD_ID="${CI_PIPELINE_ID:-local}" \
  -t "$REG/$NS/controller:$TAG" \
  rootfs

# ---------- 4. webhook certgen 镜像 ----------
echo "[4/4] build kube-webhook-certgen image ($REG/$NS/kube-webhook-certgen:$CERTGEN_TAG)"
docker build $BUILD_EXTRA_ARGS \
  --build-arg GOLANG_VERSION="$GOLANG_VERSION" \
  -t "$REG/$NS/kube-webhook-certgen:$CERTGEN_TAG" \
  images/kube-webhook-certgen/rootfs

if [ "$PUSH" != "1" ]; then
  echo "PUSH=0, images built locally:"
  echo "  $REG/$NS/nginx:$NGINX_TAG"
  echo "  $REG/$NS/controller:$TAG"
  echo "  $REG/$NS/kube-webhook-certgen:$CERTGEN_TAG"
  exit 0
fi

# ---------- 5. 全部构建成功后再统一推送，避免半发布 ----------
mkdir -p "$ARTIFACT_DIR"
: > "$ARTIFACT_DIR/images.txt"

for ref in \
  "$REG/$NS/nginx:$NGINX_TAG" \
  "$REG/$NS/controller:$TAG" \
  "$REG/$NS/kube-webhook-certgen:$CERTGEN_TAG"
do
  echo "push $ref"
  docker push "$ref"
  docker image inspect "$ref" --format '{{index .RepoDigests 0}}' >> "$ARTIFACT_DIR/images.txt"
done

echo "pushed:"
cat "$ARTIFACT_DIR/images.txt"
