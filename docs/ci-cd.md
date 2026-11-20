# CI/CD 配置与应用发布（ingress-nginx Fork）

> 适用仓库：`git@172.29.13.21:chenzhong/ingress-nginx.git`（GitLab 自建实例 172.29.13.21）
> 配置入口：[.gitlab-ci.yml](.gitlab-ci.yml)、[ci/build-images.sh](ci/build-images.sh)、[build/ci/Dockerfile.builder](build/ci/Dockerfile.builder)
> 设计参考：WeWin `docs/hxyd/09-CI-CD与应用发布.md` 的三段式流水线（测试门禁 → 版本 tag 构建 → deploy tag 上生产）。
> 落地日期：2026-11-16。

---

## 1. 总览：三段式流水线

```
  日常开发 / MR
  ─────────────────────────────────────────────
  feature 分支 push      → 不跑 CI
  MR → main（路径命中）  → go-test + lua-test + chart-lint
  main push              → 同上（全量）

  版本发布（只出镜像，不部署）
  ─────────────────────────────────────────────
  push tag vX.Y.Z        → 测试全绿 → build-images
                            ├─ nginx 基础镜像（源码编译）
                            ├─ controller
                            └─ kube-webhook-certgen
                          三镜像推 Harbor，产物 digest 存档

  生产部署（当前为人工闸门）
  ─────────────────────────────────────────────
  push tag deploy-vX.Y.Z → deploy-manual（manual，只校验镜像存在并打印命令）
                          不改集群；实际 helm upgrade 由人执行
```

设计原则与 WeWin 一致：

1. **日常 push / 版本 tag 永不触碰生产**；
2. **构建与部署分离**：版本 tag 只产镜像，部署必须再打 `deploy-*` tag 且点 manual；
3. **先在测试门禁全绿，才允许构建**（`build-images` 的 `needs` 锁定三个 test job）；
4. **凭证只放 GitLab Variables**，不落仓库、不进日志；
5. **构建产物可追溯**：推送后把 `RepoDigest` 写入 `ci-artifacts/images.txt` 作为流水线 artifact 保留 90 天。

与 WeWin 的主要差异：

| | WeWin | 本项目 |
|---|---|---|
| 构建物 | Node/Python 四镜像，docker build | Go 控制器 + **源码编译的 NGINX 基础镜像**，共三镜像 |
| 构建耗时 | 约 14 分钟（含 build-push） | nginx 基础镜像 20–40 分钟；controller/certgen 各数分钟 |
| 部署目标 | 26 机 docker compose | Kubernetes（当前不自动部署） |
| 测试镜像 | node:22 / python:3.12 | 上游 `e2e-test-runner`（自带 Go、etcd、kube-apiserver、helm、resty） |
| 版本号 | `2026.N.F` | 沿用 `vX.Y.Z`（与 [TAG](TAG)、chart、NGINX 版本对齐） |

---

## 2. 触发规则

| 事件 | 条件 | 跑什么 |
|---|---|---|
| main push | 总是 | go-test、lua-test、chart-lint |
| MR → main | 路径命中 `.changes-paths` | 同上 |
| push tag `vX.Y.Z` | `$CI_COMMIT_TAG !~ /^deploy-/` | 测试三 job + build-images |
| push tag `deploy-vX.Y.Z` | `$CI_COMMIT_TAG =~ /^deploy-/` | 仅 deploy-manual（manual） |
| 其他分支 push | — | 不跑（走 MR） |

路径触发集合见 [.gitlab-ci.yml](.gitlab-ci.yml) 的 `.changes-paths`，包含 Go 源码、go.mod/go.sum、rootfs、images、charts、TAG、NGINX_BASE、CI 自身文件。

---

## 3. 测试门禁（3 个 job）

| Job | 镜像 | 命令 | 覆盖 |
|---|---|---|---|
| `go-test` | `$TEST_IMAGE`（e2e-test-runner v2.2.9） | `bash test/test.sh` | 全部 Go 单测（含 store 的 envtest 集成测试） |
| `lua-test` | 同上 | `bash test/test-lua.sh` | Lua 单测（本地实测 184 通过 / 0 失败） |
| `chart-lint` | 同上 | `helm lint` + `helm template` | Chart 语法与可渲染性 |

要点：

- 使用上游 `registry.k8s.io/ingress-nginx/e2e-test-runner:v2.2.9@sha256:6eda…` 作为 job 镜像，**直接在里面跑脚本，不再嵌套 docker run**。原因是 Runner 挂的是宿主 docker socket，`build/run-in-docker.sh` 里的 `-v "$(pwd)"` 会把 job 内路径当宿主路径，必然错位。
- 该镜像自带 `/usr/local/bin/{etcd,kube-apiserver,kubectl}`，正好满足 `store_test.go` 里 `KUBEBUILDER_ASSETS=/usr/local/bin` 的硬编码。
- **e2e 不在门禁**：上游 GitHub Actions 的 10 个 kind e2e job 长期全红且不产出 junit，直接搬进来只会让流水线永久红。先保住单测/渲染门禁，e2e 单独立项修。

本地验证记录（2026-11-16，同一镜像、同一命令）：

| 门禁 | 结果 | 说明 |
|---|---|---|
| `go-test` | ✅ rc=0，0 FAIL | 需 `CGO_ENABLED=0`（否则 `cmd/plugin/.../ingresses` 测试二进制找不到 `ld`）+ 预建 `/etc/ingress-controller/{geoip,auth,ssl,telemetry}`（否则 `cmd/nginx` 的 `TestHandleSigterm` 失败） |
| `lua-test` | ✅ 184 successes / 0 failures | 15 秒内完成 |
| `chart-lint` | ✅ `helm lint` + `helm template` | Helm v4.1.3 |

---

## 4. 构建与推送（build-images）

触发：`push tag vX.Y.Z`，且三个 test job 全绿。

镜像清单（沿用 Harbor `library` 项目下已有的 `ingress-nginx/` 路径）：

| 镜像 | 构建上下文 | Dockerfile | Tag 来源 |
|---|---|---|---|
| `$REG/$NS/nginx` | `images/nginx/rootfs` | 内置 | 版本 tag 或 `NGINX_TAG` |
| `$REG/$NS/controller` | `rootfs` | `rootfs/Dockerfile` | 本次版本 tag |
| `$REG/$NS/kube-webhook-certgen` | `images/kube-webhook-certgen/rootfs` | 内置 | [images/kube-webhook-certgen/TAG](images/kube-webhook-certgen/TAG)（当前 `v1.6.9`，独立于版本 tag） |

其中 `REG=reg.yondervision.com.cn:8081`、`NS=library/ingress-nginx`。

构建步骤（[ci/build-images.sh](ci/build-images.sh)）：

1. `build/ci/Dockerfile.builder` 在 `golang:1.26.1-alpine3.23` 内编译 `nginx-ingress-controller` / `dbg` / `wait-shutdown`，然后 `docker create` + `docker cp` 落到 `rootfs/bin/amd64/`；
2. 构建 nginx 基础镜像（34 个补丁 + LuaJIT/ModSecurity/OTel 等源码编译）；
3. 以第 2 步镜像为 `BASE_IMAGE` 构建 controller；
4. 构建 certgen；
5. **三个镜像全部构建成功后才统一 push**，避免半发布；推送后记录 digest。

版本/提交信息通过 `-ldflags -X k8s.io/ingress-nginx/version.{RELEASE,COMMIT,REPO}` 注入，与 [build/build.sh](build/build.sh) 的口径一致。

本地构建验证（2026-11-16）：

- `BUILD_NGINX=0`、复用 Harbor 已有 `nginx:v1.30.6` 时，**controller 与 certgen 均构建成功**；
- 在 `docker:24` job 镜像 + 宿主 socket 的组合下，完整跑通脚本（`PUSH=0`），确认 BuildKit、`docker cp`、上下文路径均无问题；
- nginx 基础镜像的完整编译（34 补丁 + 源码依赖）需在 25 机 amd64 上首次触发验证，是投产前最后一个未本地覆盖的环节。

---

## 5. 部署占位（deploy-manual）

当前决策是**不自动改生产**（符合"没有全量 e2e 不上生产"的现状）。

- 触发：`push tag deploy-vX.Y.Z`，job 为 `manual`；
- 动作：`docker manifest inspect` 校验 nginx/controller/certgen 三个 tag 真的在 Harbor，然后打印手工 helm 命令；
- **不接触集群、不需要 kubeconfig**。

真正上生产仍按人工 SOP（见第 7 节第 6 步）。

---

## 6. 变量与前置条件

### 6.1 GitLab Variables（Settings → CI/CD → Variables，Masked）

| 变量 | 必填 | 用途 |
|---|---|---|
| `HARBOR_USER` | 是 | Harbor 账号；**需要对 `library` 项目有 push 权限** |
| `HARBOR_PASS` | 是 | 对应密码，`--password-stdin` 注入 |
| `TEST_IMAGE` | 否 | 覆盖测试镜像；内网拉不到 `registry.k8s.io` 时改为 Harbor 镜像 |
| `BUILD_EXTRA_ARGS` | 否 | 透传 `docker build` 参数，解决 nginx 源码构建的外网问题（见 6.3） |
| `BUILD_NGINX` | 否 | `1`（默认）重建 nginx 基础镜像；`0` 复用已有基础镜像（controller 单独发版时用） |
| `NGINX_TAG` | 否 | nginx 基础镜像 tag；默认等于版本 tag。controller 与 NGINX 版本不一致时显式指定 |
| `DEPLOY_NAMESPACE` | 否 | deploy-manual 打印命令用的 namespace，默认 `ingress-nginx` |

### 6.2 Runner

复用 25 机（172.29.13.25）的 docker executor + 宿主 `/var/run/docker.sock`，与 WeWin 相同：

- 注册时勾选 **Run untagged jobs**（本配置的 job 均未指定 tags）；
- 宿主 docker daemon 已配 `insecure-registries` 与 Harbor hosts 解析（沿用 WeWin 的 25 机配置）；
- **必须支持 BuildKit**（`docker buildx` 可用）：certgen 的 Dockerfile 使用 `FROM --platform=$BUILDPLATFORM`，legacy builder 会直接报 `failed to parse platform`。`ci/build-images.sh` 会显式 `DOCKER_BUILDKIT=1` 并前置检查，缺失时在第一个镜像前就失败。

### 6.3 网络（最容易卡住的一环）

`build-images` 的外网依赖：

- 拉 `golang:1.26.1-alpine3.23`、`alpine:3.23.3`、`docker.m.daocloud.io/alpine:3.23.3`；
- nginx 基础镜像构建时，容器内要 `curl nginx.org`、`git clone github.com/{ngx_brotli,ssdeep,ModSecurity,coreruleset,opentelemetry-cpp-contrib}`、`wget dl.k8s.io`；
- Go 依赖走 `GOPROXY`（builder 默认 `https://goproxy.cn,direct`，可用 build-arg 覆盖）。

若 25 机是「daemon 走代理、build 容器直连受限」的组合，在 GitLab Variables 配：

```
BUILD_EXTRA_ARGS=--network host --build-arg HTTP_PROXY=http://127.0.0.1:7890 --build-arg HTTPS_PROXY=http://127.0.0.1:7890 --build-arg NO_PROXY=172.29.0.0/16,reg.yondervision.com.cn
```

（`--network host` 让 build 容器共享宿主网络，`127.0.0.1:7890` 才可达；mihomo 只监听回环时必须这样配。）

诊断命令（在 25 机执行）：

```bash
docker run --rm --network host alpine:3.23.3 sh -c \
  'apk add --no-cache curl >/dev/null && curl -sSI https://nginx.org/download/ | head -1'
```

### 6.4 Harbor 权限

`library` 是 public 项目（拉取匿名可用），但**推送需要 developer 及以上角色**。现有 `v1.30.2/v1.30.5/v1.30.6` 镜像是手工以 admin 推送的；WeWin 使用的 `sid-user` 只对 `sid` 项目有权限，直接复用会 401。二选一：

- 给 `HARBOR_USER` 所属账号授 `library` 项目 developer；或
- Harbor 建 robot account（`library` 项目，push 权限），用其账号密码填 `HARBOR_USER/PASS`。

---

## 7. 发版 SOP（下次照此敲）

以发布 `v1.30.7` 为例。注意：**CI 在 GitLab 上，必须推 `gitlab` 远端**（`origin` 是上游 kubernetes/ingress-nginx，推不上去）。

### 第 0 步：前置检查（首次发版前做一次）

```bash
# 测试镜像可达（不可达则先镜像到 Harbor 并改 TEST_IMAGE）
docker manifest inspect registry.k8s.io/ingress-nginx/e2e-test-runner:v2.2.9

# Harbor push 权限（用 CI 将使用的账号）
docker login reg.yondervision.com.cn:8081 -u "$HARBOR_USER"
```

### 第 1 步：升版本号（仅当 NGINX/版本真的变化）

```bash
vim TAG                 # v1.30.7
vim NGINX_BASE          # ghcr.io/... 或 Harbor 的 nginx 基础镜像（按发布策略）
vim charts/ingress-nginx/Chart.yaml    # appVersion/version
vim charts/ingress-nginx/values.yaml   # controller.image.tag
# 如采用静态清单部署，同步改 deploy/static/.../deploy.yaml
```

> 若本次只改控制器、NGINX 版本未变：在 GitLab Variables 设 `BUILD_NGINX=0`、`NGINX_TAG=v1.30.6`，直接复用 Harbor 里已有的 nginx 基础镜像，可省 20–40 分钟。（下次 NGINX 升级后请同步改为新 tag）

### 第 2 步：本地跑与 CI 相同的门禁

```bash
# Go 单测（与 go-test 完全同命令）
docker run --rm -v "$PWD:/go/src/k8s.io/ingress-nginx" \
  -w /go/src/k8s.io/ingress-nginx \
  -e PKG=k8s.io/ingress-nginx -e GOFLAGS=-buildvcs=false -e CGO_ENABLED=0 \
  registry.k8s.io/ingress-nginx/e2e-test-runner:v2.2.9 \
  bash -c 'mkdir -p /tmp/nginx /etc/ingress-controller/geoip && bash test/test.sh'

# Lua 单测
docker run --rm -v "$PWD:/go/src/k8s.io/ingress-nginx" \
  -w /go/src/k8s.io/ingress-nginx \
  registry.k8s.io/ingress-nginx/e2e-test-runner:v2.2.9 \
  bash -c 'bash test/test-lua.sh'
```

### 第 3 步：提交并推 main（触发测试门禁）

```bash
git commit -am "chore(release): 升版 v1.30.7"
git push gitlab main
```

### 第 4 步：打版本 tag（触发构建推送）

```bash
git tag v1.30.7
git push gitlab v1.30.7
```

### 第 5 步：确认镜像就绪

```bash
# GitLab CI 页面看 build-images 绿；或本地查 Harbor
docker manifest inspect reg.yondervision.com.cn:8081/library/ingress-nginx/controller:v1.30.7
docker manifest inspect reg.yondervision.com.cn:8081/library/ingress-nginx/nginx:v1.30.7
docker manifest inspect reg.yondervision.com.cn:8081/library/ingress-nginx/kube-webhook-certgen:v1.6.9
```

流水线 artifact `ci-artifacts/images.txt` 里有本次三个镜像的 digest，**生产固定用 digest 更稳**。

### 第 6 步：手工部署（当前唯一上生产通道）

```bash
helm upgrade --install ingress-nginx charts/ingress-nginx \
  -n ingress-nginx \
  --set controller.image.repository=reg.yondervision.com.cn:8081/library/ingress-nginx/controller \
  --set controller.image.tag=v1.30.7 \
  --set controller.admissionWebhooks.patch.image.repository=reg.yondervision.com.cn:8081/library/ingress-nginx/kube-webhook-certgen \
  --set controller.admissionWebhooks.patch.image.tag=v1.6.9 \
  --set controller.admissionWebhooks.patch.image.digest=

kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=5m
kubectl -n ingress-nginx get pods -l app.kubernetes.io/component=controller -o wide
```

说明：chart 的 `controller.image.repository` 会优先于 registry/image 拼接（见 `_helpers.tpl` 的 `if .repository`）；certgen 的 `digest` 必须显式置空，否则会继续按上游 digest 拉取。

### 第 7 步：打 deploy tag（留痕，可选）

```bash
git tag deploy-v1.30.7
git push gitlab deploy-v1.30.7
# → deploy-manual 出现在流水线，点击后只校验镜像存在并打印命令
```

---

## 8. 回滚

- **最快**：`helm rollback ingress-nginx -n ingress-nginx`（回到上一 revision）；
- **指定版本**：重跑第 6 步，把 tag 换成旧版本（Harbor 保留历史 tag：v1.30.2/1.30.5/1.30.6）；
- **按 digest**：`--set controller.image.digest=sha256:...`（artifact 里有记录）；
- 回滚后同样执行 `kubectl rollout status` 并观察入口 5xx/延迟。

---

## 9. 本地演练（Runner 未就绪时）

除第 2 步的测试命令外，构建也可以本地跑（`PUSH=0` 不推 Harbor）：

```bash
# 只验证 controller/certgen（复用 Harbor 已有的 nginx 基础镜像，跳过 30 分钟编译）
REG=reg.yondervision.com.cn:8081 NS=library/ingress-nginx TAG=v1.30.7 \
  PUSH=0 BUILD_NGINX=0 \
  BASE_IMAGE=reg.yondervision.com.cn:8081/library/ingress-nginx/nginx:v1.30.7 \
  sh ci/build-images.sh

# 完整演练（含 nginx 基础镜像，耗时 20–40 分钟）
REG=reg.yondervision.com.cn:8081 NS=library/ingress-nginx TAG=v1.30.7 \
  PUSH=0 sh ci/build-images.sh
```

---

## 10. 已知边界与后续项

- **无 e2e 门禁**：与上游 GitHub Actions 现状一致（10 个 kind e2e 长期失败）。在 e2e 修好前，配置层改动仍需靠第 2 步 + 人工影子验证。
- **chart README 仍与 values 漂移**：本 CI 只做 `helm lint`/`helm template`，不做 `helm-docs` 差异检查。修 README 后再加 `helm-docs` 门禁。
- **chart 默认镜像仍指 GHCR**：部署必须按第 6 步显式覆盖 `repository`，否则会拉到上游/不存在的镜像。后续应把默认值改为 Harbor（需同步改 chart 单测）。
- **不自动部署**：deploy job 目前只是人工闸门的占位。
- **双重发布风险**：若同时推 GitHub，`build-images.yaml` 仍会向 GHCR 推送；GitLab 稳定后建议禁用它，避免同一 tag 两个来源。
- **可变 tag**：本 CI 每次构建都会覆盖 Harbor 的 `vX.Y.Z`。生产环境建议按 digest 固定；实验构建用 `-rc.N` tag。
- **构建网络**：nginx 基础镜像依赖外网 git/curl，是首次落地最可能失败的点，先按 6.3 诊断。

---

## 11. 与 WeWin 配置的对照

| 能力 | WeWin | 本项目 |
|---|---|---|
| 测试隔离 | sidecar/server/client 三 job，真库 | go/lua/chart 三 job，envtest + resty |
| 构建触发 | tag `2026.*.*` | tag `vX.Y.Z` |
| 部署触发 | tag `deploy-*` → SSH compose | tag `deploy-*` → manual 占位（暂不部署） |
| 凭证 | HARBOR_USER/PASS、DEPLOY_SSH_KEY | HARBOR_USER/PASS（未来加 KUBECONFIG） |
| 健康检查 | compose ps + curl 首页 | 手工 `kubectl rollout status`（自动部署接入后补） |
| 产物追溯 | docker history/digest（待办） | `ci-artifacts/images.txt`（已实现） |
