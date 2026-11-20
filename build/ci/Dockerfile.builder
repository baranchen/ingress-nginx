# CI 专用构建镜像：在容器内编译 ingress-nginx 的三个二进制，供 rootfs/Dockerfile 使用。
#
# 为什么需要它：GitLab Runner 挂载的是宿主机 docker socket，`build/run-in-docker.sh`
# 里的 `docker run -v "$(pwd)"` 会把 job 容器内的路径当成宿主机路径，必然对不上；
# 因此这里改用「docker build 产出二进制 → docker cp 到 rootfs/bin/<arch>/」的方式，
# 路径始终由 docker CLI 流式传输，不依赖宿主机挂载。
#
# 使用方式见 ci/build-images.sh。

ARG GOLANG_VERSION=1.26.1

FROM golang:${GOLANG_VERSION}-alpine3.23 AS builder

ARG VERSION=dev
ARG COMMIT_SHA=unknown
ARG REPO_INFO=unknown
ARG GOPROXY=https://goproxy.cn,direct
ENV GOPROXY=${GOPROXY}

RUN apk add --no-cache git

WORKDIR /src

# 先单独拷贝 go.mod/go.sum，依赖不变时可复用这一层缓存
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -buildvcs=false \
      -ldflags="-buildid= -w -s \
        -X k8s.io/ingress-nginx/version.RELEASE=${VERSION} \
        -X k8s.io/ingress-nginx/version.COMMIT=${COMMIT_SHA} \
        -X k8s.io/ingress-nginx/version.REPO=${REPO_INFO}" \
      -o /out/nginx-ingress-controller ./cmd/nginx \
 && go build -trimpath -buildvcs=false \
      -ldflags="-buildid= -w -s \
        -X k8s.io/ingress-nginx/version.RELEASE=${VERSION} \
        -X k8s.io/ingress-nginx/version.COMMIT=${COMMIT_SHA} \
        -X k8s.io/ingress-nginx/version.REPO=${REPO_INFO}" \
      -o /out/dbg ./cmd/dbg \
 && go build -trimpath -buildvcs=false \
      -ldflags="-buildid= -w -s \
        -X k8s.io/ingress-nginx/version.RELEASE=${VERSION} \
        -X k8s.io/ingress-nginx/version.COMMIT=${COMMIT_SHA} \
        -X k8s.io/ingress-nginx/version.REPO=${REPO_INFO}" \
      -o /out/wait-shutdown ./cmd/waitshutdown

# 仅用于 docker create + docker cp 取产物；CMD 必须能通过 docker create 校验
FROM alpine:3.23.3
COPY --from=builder /out /out
CMD ["/bin/true"]
