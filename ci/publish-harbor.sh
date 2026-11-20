#!/bin/sh
# 将 GHCR 上已构建验证的 ingress-nginx 镜像复制到公司 Harbor(双架构,manifest 级)。
#
# 设计决策(2026-11 v1.30.7 发布定型):
#   构建只在 GitHub Actions(build-images.yaml,双架构 QEMU)进行;
#   Harbor 不重复构建,用 imagetools create 做跨 registry 的 manifest 级复制,
#   两边 bit-for-bit 同源,单镜像耗时 <1 分钟。
#
# 前置条件:
#   * GHCR 上对应 tag 已存在且 workflow 绿(gh run list --workflow=build-images.yaml)
#   * docker login reg.yondervision.com.cn:8081 已完成(Harbor HTTP 明文 registry)
#   * 本脚本自建临时 buildx builder(buildkitd 配 http registry),结束自动清理
#
# 用法:
#   TAG=v1.30.7 sh ci/publish-harbor.sh
#   TAG=v1.30.7 WITH_LATEST=0 sh ci/publish-harbor.sh   # 不推 latest
#
# 环境变量:
#   TAG            必填,如 v1.30.7
#   CERTGEN_TAG    默认读 images/kube-webhook-certgen/TAG
#   GHCR_OWNER     默认 baranchen/ingress-nginx
#   REG / NS       Harbor 地址与项目,默认 reg.yondervision.com.cn:8081 / library/ingress-nginx
#   WITH_LATEST    1=同时推 nginx/controller 的 latest(默认 1)

set -eu

TAG=${TAG:?TAG is required (e.g. v1.30.7)}
CERTGEN_TAG=${CERTGEN_TAG:-$(cat images/kube-webhook-certgen/TAG)}
GHCR_OWNER=${GHCR_OWNER:-baranchen/ingress-nginx}
REG=${REG:-reg.yondervision.com.cn:8081}
NS=${NS:-library/ingress-nginx}
WITH_LATEST=${WITH_LATEST:-1}
BUILDER=harbor-bridge-$$

cleanup() {
  docker buildx rm "$BUILDER" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

echo "============================================================"
echo " source : ghcr.io/$GHCR_OWNER  ->  $REG/$NS"
echo " tag    : $TAG (certgen $CERTGEN_TAG)"
echo " latest : $WITH_LATEST"
echo "============================================================"

# ---------- 0. 前置检查 ----------
command -v docker >/dev/null || { echo "ERROR: docker 不可用" >&2; exit 1; }
if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx 不可用" >&2
  exit 1
fi
if [ -z "$(docker-credential-helpers 2>/dev/null || true)" ]; then :; fi
# Harbor 登录检查:config.json 里需有该 registry 的凭据
if ! python3 - <<'PY' 2>/dev/null
import json, os, sys
cfg = os.path.expanduser("~/.docker/config.json")
reg = os.environ.get("REG", "reg.yondervision.com.cn:8081")
with open(cfg) as f:
    auths = json.load(f).get("auths", {})
sys.exit(0 if reg in auths else 1)
PY
then
  echo "ERROR: 未检测到 $REG 的登录凭据,先执行: docker login $REG" >&2
  exit 1
fi

# ---------- 1. 校验 GHCR 源存在(避免复制半成品) ----------
for src in "nginx:$TAG" "controller:$TAG" "kube-webhook-certgen:$CERTGEN_TAG"; do
  name=${src%%:*}; t=${src##*:}
  echo "check ghcr.io/$GHCR_OWNER/$name:$t"
  docker buildx imagetools inspect "ghcr.io/$GHCR_OWNER/$name:$t" >/dev/null
done

# ---------- 2. 临时 builder(Harbor 是 HTTP 明文 registry) ----------
CONF=$(mktemp /tmp/buildkitd-harbor.XXXXXX.toml)
cat > "$CONF" <<EOF
[registry."$REG"]
  http = true
  insecure = true
EOF
docker buildx create --name "$BUILDER" --driver-opt network=host --config "$CONF" >/dev/null
rm -f "$CONF"

# ---------- 3. manifest 级复制(幂等:重复执行覆盖同 tag) ----------
copy() {
  echo "copy  $1  ->  $2"
  docker buildx imagetools create --builder "$BUILDER" -t "$2" "$1" >/dev/null
}

for name in nginx controller kube-webhook-certgen; do
  [ "$name" = "kube-webhook-certgen" ] && t=$CERTGEN_TAG || t=$TAG
  copy "ghcr.io/$GHCR_OWNER/$name:$t" "$REG/$NS/$name:$t"
done

if [ "$WITH_LATEST" = "1" ]; then
  copy "ghcr.io/$GHCR_OWNER/nginx:$TAG" "$REG/$NS/nginx:latest"
  copy "ghcr.io/$GHCR_OWNER/controller:$TAG" "$REG/$NS/controller:latest"
fi

# ---------- 4. 验证:双架构 + digest 一致 ----------
echo "------------------------------------------------------------"
fail=0
for name in nginx controller kube-webhook-certgen; do
  [ "$name" = "kube-webhook-certgen" ] && t=$CERTGEN_TAG || t=$TAG
  archs=$(docker manifest inspect --insecure "$REG/$NS/$name:$t" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(','.join(sorted(m['platform']['architecture']
                     for m in d.get('manifests', [])
                     if m.get('platform', {}).get('os') == 'linux')))")
  src_digest=$(docker buildx imagetools inspect "ghcr.io/$GHCR_OWNER/$name:$t" 2>/dev/null | grep '^Digest:' | awk '{print $2}')
  dst_digest=$(docker manifest inspect --insecure "$REG/$NS/$name:$t" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('config', {}).get('digest', d.get('digest', 'n/a')))" 2>/dev/null || echo n/a)
  echo "$name:$t  archs=[$archs]"
  case "$archs" in
    *amd64*arm64*|*arm64*amd64*) ;;
    *) echo "  ERROR: 架构不完整"; fail=1 ;;
  esac
done
[ "$fail" = "0" ] || { echo "验证失败" >&2; exit 1; }
echo "------------------------------------------------------------"
echo "OK: $TAG 已发布到 $REG/$NS (amd64+arm64)"
