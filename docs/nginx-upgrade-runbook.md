# NGINX 版本升级手册

> 基于 v1.30.7 升级(2026-11)总结、并在 v1.30.8 升级中按评审意见修订的标准化流程。全程约 2 小时,
> 其中 ~90 分钟是 GitHub Actions 自动构建,人工操作约 30 分钟。

## 发布架构

```
代码 push GitHub main(先不打 tag)
  └→ GitHub Actions: build-images.yaml(双架构 QEMU,唯一构建点)
       ├→ GHCR: ghcr.io/baranchen/ingress-nginx/{nginx,controller,kube-webhook-certgen}
       └→ (本地脚本,GitLab 不参与) ci/publish-harbor.sh
            └→ Harbor: manifest 级复制,GHCR/Harbor bit-for-bit 同源
```

- 构建只在 GitHub Actions;Harbor 永不本地构建
- 分发只走本地脚本 `ci/publish-harbor.sh`;GitLab CI 只承担测试门禁(MR/push),不参与构建与分发(`.gitlab-ci.yml` 中的 `publish-images` job 不作为发布路径)
- 放行条件是验证结果而非日历:CI 全绿 + 冒烟通过之前,不打 tag、不分发
- 历史 tag 的单架构镜像(v1.30.2/5/6 期)不迁移,新 tag 起全为双架构

## 升级步骤

### 1. 代码修改(~30 分钟)

```bash
OLD=1.30.7   # 当前版本
NEW=1.30.8   # 目标版本
```

1. **核实新版本**:nginx.org/en/download.html(stable)+ CHANGES-$OLD 的 CVE 清单
2. **下载 tarball,算 SHA256 并验签**(SHA256 必须实测,不抄网页):
   ```bash
   curl -sLO https://nginx.org/download/nginx-$NEW.tar.gz
   curl -sLO https://nginx.org/download/nginx-$NEW.tar.gz.asc
   shasum -a 256 nginx-$NEW.tar.gz
   gpg --verify nginx-$NEW.tar.gz.asc nginx-$NEW.tar.gz   # 密钥见 nginx.org/en/pgp_keys.html
   ```
   `build.sh` 里的 SHA256 校验是注释掉的,不起作用,所以必须手工做。
   本机没有 gpg 就在记录里明确写"未验签",不要静默跳过。
3. **改文件**(参照上个版本的 diff,如 `git show 4914d318d`):
   - `images/nginx/rootfs/build.sh`:NGINX_VERSION + tarball SHA256
   - 33 个 patch 改名(`00_drop-alias-root.patch` 不含版本号,不动):
     `cd images/nginx/rootfs/patches && for f in *_nginx-$OLD-*.patch; do git mv "$f" "${f/$OLD/$NEW}"; done`
   - `TAG`、`NGINX_BASE`、`images/nginx/TAG`
   - `charts/ingress-nginx/Chart.yaml`(version/appVersion/annotation)、`values.yaml`(tag)
   - 9 个 `deploy/static/provider/*/deploy.yaml`(+aws/nlb 子目录)
   - `README.md` 中英双语(对照表、CVE 表、升级要点)、`SECURITY.md`、`Changelog.md`
   - `changelog/controller-$NEW.md`(保留历史,别删旧版)
4. **验证补丁**(必须真实应用,不能 dry-run——补丁间有依赖):
   ```bash
   cd /tmp && tar xzf nginx-$NEW.tar.gz && cd nginx-$NEW
   for p in /path/to/repo/images/nginx/rootfs/patches/*.patch; do
     patch -p1 -s < "$p" || echo "FAILED: $p"
   done
   ```

### 2. 本地门禁(全绿才提交)

```bash
helm unittest charts/ingress-nginx        # 必须 140/140
helm lint charts/ingress-nginx
~/go/bin/helm-docs --chart-search-root charts && git diff --exit-code charts/ingress-nginx/README.md
bash -n images/nginx/rootfs/build.sh
```

两项硬门禁(必须脚本核对,不靠目视):

a. **版本一致性**:`build.sh` 的 NGINX_VERSION、`TAG`、`images/nginx/TAG`、`Chart.yaml` 的 appVersion、`values.yaml` 的 tag
   五处一致,且这些文件里不再出现 `$OLD`。
b. **补丁树等价**:对 `$OLD` 和 `$NEW` 源码树分别顺序打完 34 个补丁,`diff -rq` 两棵树,
   差异必须恰好等于上游两版 tarball 之间的差异(`diff -rq nginx-$OLD nginx-$NEW` 的输出)。
   差异多一个文件,就说明某个补丁在新版本上的落点变了。

⚠️ CVE 严重级别必须对照 https://nginx.org/en/security_advisories.html
(major→High, medium→Medium, minor→Low),中英两表同口径。

### 3. 提交并推送(先不打 tag)

```bash
git add -A images/nginx/rootfs/patches   # 收口 patch rename(否则 commit 带两套)
git add -u && git add changelog/
git commit -m "feat: upgrade NGINX from $OLD to $NEW"
git fetch github                                   # 先确认能快进
git push github HEAD:main && git push gitlab HEAD:main
```

push main 会自动触发 build-images.yaml(上次实测 1 小时 43 分)、CI 和 Chart 三个 workflow。
重复构建会被 concurrency 串行;若 main 与分支各跑一次,cancel 掉一次。

### 4. 等三个 workflow 结束,再验证 GHCR

三个 workflow 都要结束:「CI」「Build and Push Images」「Chart」(后者只做 lint)。
CI 里做 helm-docs 漂移检查的是「Chart / Lint」job 的 Check docs 步骤(不是「Verify Doc generation」)。
CI 的 `Build` job 把基镜像写死成 `registry.k8s.io/...`:基镜像步骤被跳过而下一步照常执行时,
就会报 `registry.k8s.io/ingress-nginx/nginx:...: not found`。改动命中 `images/nginx/**` 时两步都会执行。
红了就停下来报告,先看「Build NGINX Base image」是 success 还是 skipped/failure,连同日志一起给出,不要改 workflow。

```bash
gh run list --branch main --limit 5
# 三个都绿后:
docker run --rm --platform linux/amd64 ghcr.io/baranchen/ingress-nginx/nginx:v$NEW nginx -v
docker run --rm --platform linux/arm64 ghcr.io/baranchen/ingress-nginx/nginx:v$NEW nginx -v
docker run --rm --platform linux/amd64 --entrypoint /nginx-ingress-controller \
  ghcr.io/baranchen/ingress-nginx/controller:v$NEW --version
```

三个输出都应含新版本号。

### 5. 冒烟(kind)

在 kind 集群用新镜像装 chart,Pod ready 后访问一个测试 Ingress。
有条件再加 HTTPS 后端的大请求体和大响应各一次,对照 `$OLD`(看传输完成、无 502/504、worker CPU 无空转)。
做不了就明确记录"冒烟未做"。

### 6. 验证全部通过后,才在通过的那个 commit 上打 tag

```bash
git tag v$NEW && git push github v$NEW && git push gitlab v$NEW
```

不要 force 挪 tag。发布后「kubectl plugin」workflow 会失败(`.goreleaser.yaml` 还指向上游仓库),是已知问题。

### 7. 分发到 Harbor(本地脚本,唯一路径)

```bash
# 前置:docker login reg.yondervision.com.cn:8081
TAG=v$NEW WITH_LATEST=0 sh ci/publish-harbor.sh
# 只发版本 tag,不移动 latest;latest 与对外发布时间由负责人决定
# 幂等可重跑;自动验证双架构;~20 秒
```

需要回拨时:`TAG=v$OLD sh ci/publish-harbor.sh`。

### 8. GitHub 收尾

```bash
gh release create v$NEW --title "v$NEW — NGINX $NEW (stable)" --notes "..."  # 参照上个 release 模板
gh repo edit --description "Community-maintained fork of kubernetes/ingress-nginx with NGINX $NEW"
```

Release 说明里记录 nginx / controller / certgen 三个镜像在 GHCR 和 Harbor 的 digest:
发布过程会连带 certgen 镜像重建、apk 包漂移,GHCR 的 controller:latest / certgen:latest 在构建时自动前移。

### 9. 检查清单

- [ ] 三个 workflow 全绿(「CI」「Build and Push Images」「Chart」)
- [ ] GHCR 双架构 + 运行验证
- [ ] 冒烟通过
- [ ] tag 打在通过验证的 commit 上
- [ ] Harbor 双架构 + manifest 确认(仅版本 tag)
- [ ] GitHub Release(Latest)+ About 描述 + 三镜像 digest
- [ ] GitLab main 已同步

## 已知坑(v1.30.7 踩过)

| 坑 | 规避 |
|---|---|
| patch dry-run 假失败 | 必须真实顺序应用 |
| GHCR package 无 Actions 写权限 | 已配置;新 package 首次发布前用 perm-smoke 验证 |
| controller 镜像缺 Go 二进制 | workflow 已修;若重写 workflow 记得保留 setup-go + 交叉编译步骤 |
| 容器内 git clone 偶发失败 | build.sh 已加 retry;仍失败 rerun 即可 |
| helm-docs 漂移 | 改 values 后必须 helm-docs 再生成,别手编 README 表格 |
| 测试断言镜像路径 | 改默认镜像路径时同步 tests/ 的期望值 |
| CVE 级别想当然 | 一律查官方 advisories |
| Harbor 是 HTTP registry | imagetools 直连会 HTTPS 报错,publish-harbor.sh 已内置 buildkitd 配置 |
