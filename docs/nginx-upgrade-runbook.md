# NGINX 版本升级手册

> 基于 v1.30.7 升级(2026-11)总结的标准化流程。全程约 2 小时,
> 其中 ~90 分钟是 GitHub Actions 自动构建,人工操作约 30 分钟。

## 发布架构

```
代码 push GitHub main + tag
  └→ GitHub Actions: build-images.yaml(双架构 QEMU,唯一构建点)
       ├→ GHCR: ghcr.io/baranchen/ingress-nginx/{nginx,controller,kube-webhook-certgen}
       └→ (手动或 GitLab tag) ci/publish-harbor.sh
            └→ Harbor: manifest 级复制,GHCR/Harbor bit-for-bit 同源
```

- 构建只在 GitHub Actions;Harbor 永不本地构建
- GitLab pipeline:MR/push 跑测试门禁;`v*` tag 跑 GHCR→Harbor 分发;`deploy-*` tag 人工校验
- 历史 tag 的单架构镜像(v1.30.2/5/6 期)不迁移,新 tag 起全为双架构

## 升级步骤

### 1. 代码修改(~30 分钟)

```bash
NEW=1.30.8  # 举例
```

1. **核实新版本**:nginx.org/en/download.html(stable)+ CHANGES-1.x 的 CVE 清单
2. **下载 tarball 算 SHA256**(必须实测,不抄网页):
   ```bash
   curl -sLO https://nginx.org/download/nginx-$NEW.tar.gz && shasum -a 256 nginx-$NEW.tar.gz
   ```
3. **改文件**(参照上个版本的 diff,如 `git show 4914d318d`):
   - `images/nginx/rootfs/build.sh`:NGINX_VERSION + tarball SHA256
   - 33 个 patch 改名:`cd images/nginx/rootfs/patches && for f in *_nginx-1.30.7-*.patch; do git mv "$f" "${f/1.30.7/$NEW}"; done`
   - `TAG`、`NGINX_BASE`、`images/nginx/TAG`
   - `charts/ingress-nginx/Chart.yaml`(version/appVersion/annotation)、`values.yaml`(tag)
   - 9 个 `deploy/static/provider/*/deploy.yaml`(+aws/nlb 子目录)
   - `README.md` 中英双语(对照表、CVE 表、升级要点)、`SECURITY.md`、`Changelog.md`
   - `changelog/controller-v$NEW.md`(保留历史,别删旧版)
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
helm-docs --chart-search-root charts && git diff --exit-code charts/ingress-nginx/README.md
bash -n images/nginx/rootfs/build.sh
```

⚠️ CVE 严重级别必须对照 https://nginx.org/en/security_advisories.html
(major→High, medium→Medium, minor→Low),中英两表同口径。

### 3. 提交推送 GitHub

```bash
git add -A images/nginx/rootfs/patches   # 收口 patch rename(否则 commit 带两套)
git add -u && git add changelog/
git commit -m "feat: upgrade NGINX from 1.30.7 to $NEW"
git push github main && git tag v$NEW && git push github v$NEW
```

push main 会自动触发 build-images.yaml(~90 分钟)。
重复构建会被 concurrency 串行;若 main 与分支各跑一次,cancel 掉一次。

### 4. 等构建 + 验证 GHCR

```bash
gh run watch $(gh run list --workflow=build-images.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
# 构建绿后:
docker run --rm --platform linux/amd64 ghcr.io/baranchen/ingress-nginx/nginx:v$NEW nginx -v
docker run --rm --platform linux/arm64 ghcr.io/baranchen/ingress-nginx/nginx:v$NEW nginx -v
docker run --rm --platform linux/amd64 --entrypoint /nginx-ingress-controller \
  ghcr.io/baranchen/ingress-nginx/controller:v$NEW --version
```

三个输出都应含新版本号。

### 5. 分发到 Harbor(二选一)

```bash
# A. 本地(需 docker login reg.yondervision.com.cn:8081)
TAG=v$NEW sh ci/publish-harbor.sh
# B. GitLab tag 触发(需 .gitlab-ci.yml 已在 gitlab/main,tag 同步推过去)
git push gitlab v$NEW   # pipeline: 测试门禁 → publish-images → Harbor
```

### 6. GitHub 收尾

```bash
gh release create v$NEW --title "v$NEW — NGINX $NEW (stable)" --notes "..."  # 参照上个 release 模板
gh repo edit --description "Community-maintained fork of kubernetes/ingress-nginx with NGINX $NEW"
```

### 7. 检查清单

- [ ] CI workflow 全绿(`gh run list --branch main`)
- [ ] GHCR 双架构 + 运行验证
- [ ] Harbor 双架构 + manifest 确认
- [ ] GitHub Release(Latest)+ About 描述
- [ ] GitLab main 已同步(git push gitlab main)

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
