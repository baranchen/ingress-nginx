# Ingress NGINX Controller (Community Fork)

[English](#english) | [中文](#中文)

---

## English

> This is a community-maintained fork of [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx).
> The upstream project was officially retired in March 2026. This fork continues maintenance
> with NGINX version updates, security patches, and bug fixes.

### About This Fork

The original `kubernetes/ingress-nginx` project ceased active development after March 2026.
This fork was created to continue providing security updates and NGINX version upgrades
for users who still rely on the Ingress NGINX controller in their Kubernetes clusters.

#### What's Changed from Upstream

| Item | Upstream (v1.15.1) | This Fork (v1.30.2) |
|------|-------------------|---------------------|
| NGINX Version | 1.27.1 | **1.30.2** |
| OpenSSL | 3.5.x | 3.5.6 |
| CVE-2025-23419 | Backported patch | **Fixed upstream in NGINX 1.27.4+** |
| Controller Version | v1.15.1 | v1.30.2 |

For users currently running the upstream `kubernetes/ingress-nginx`, this fork is a
**drop-in replacement** — no configuration changes required.

### Overview

ingress-nginx is an Ingress controller for Kubernetes using [NGINX](https://www.nginx.org/)
as a reverse proxy and load balancer.

[Learn more about Ingress on the Kubernetes documentation site](https://kubernetes.io/docs/concepts/services-networking/ingress/).

### Quick Start

#### Using Helm

```bash
helm repo add ingress-nginx https://baranchen.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx
```

#### Using kubectl

```bash
kubectl apply -f https://raw.githubusercontent.com/baranchen/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

#### Build from Source

```bash
git clone https://github.com/baranchen/ingress-nginx.git
cd ingress-nginx

# Build nginx base image
cd images/nginx
docker build --platform linux/amd64,linux/arm64 rootfs \
  --tag your-registry/ingress-nginx/nginx:v1.30.2

# Build controller
cd ../..
make REGISTRY=your-registry TAG=v1.30.2 build
make REGISTRY=your-registry TAG=v1.30.2 image
```

### Supported Versions

| Ingress-NGINX version | Kubernetes Version | Alpine | NGINX Version | Helm Chart |
| --------------------- | ------------------ | ------ | ------------- | ---------- |
| **v1.30.2**           | 1.35, 1.34, 1.33   | 3.23.3 | 1.30.2        | -          |

### Usage Warnings

Do not use in multi-tenant Kubernetes production installations. This project assumes
that users who can create Ingress objects are administrators of the cluster.

### Upstream Credit

This project is a fork of [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx),
originally developed by the Kubernetes community and licensed under the
[Apache License 2.0](LICENSE). We gratefully acknowledge the work of all upstream contributors.

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request

### Reporting Issues

Please use [GitHub Issues](https://github.com/baranchen/ingress-nginx/issues) to report
bugs or request features.

### Security Vulnerabilities

If you discover a security vulnerability, please report it privately by opening a
[GitHub Security Advisory](https://github.com/baranchen/ingress-nginx/security/advisories/new).
Do not file public issues for security vulnerabilities.

### Changelog

See [Changelog.md](Changelog.md) for the upstream changelog history.
Changes specific to this fork are tracked in [GitHub Releases](https://github.com/baranchen/ingress-nginx/releases).

### License

[Apache License 2.0](LICENSE) — Same license as the upstream project.

---

## 中文

> 这是 [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx) 的社区维护分支。
> 上游项目已于 2026 年 3 月正式停止维护。本分支将继续提供 NGINX 版本更新、安全补丁和缺陷修复。

### 关于本分支

原 `kubernetes/ingress-nginx` 项目在 2026 年 3 月后停止了积极开发。
创建本分支是为了继续为仍在 Kubernetes 集群中使用 Ingress NGINX 控制器的用户提供安全更新和 NGINX 版本升级。

#### 与上游的差异

| 项目 | 上游 (v1.15.1) | 本分支 (v1.30.2) |
|------|---------------|-----------------|
| NGINX 版本 | 1.27.1 | **1.30.2** |
| OpenSSL | 3.5.x | 3.5.6 |
| CVE-2025-23419 | 回移补丁 | **已在 NGINX 1.27.4+ 上游修复** |
| 控制器版本 | v1.15.1 | v1.30.2 |

对于当前运行上游 `kubernetes/ingress-nginx` 的用户，本分支是**直接替换方案**——无需修改任何配置。

### 概述

ingress-nginx 是一个使用 [NGINX](https://www.nginx.org/) 作为反向代理和负载均衡器的 Kubernetes Ingress 控制器。

[了解更多关于 Ingress 的信息，请访问 Kubernetes 文档](https://kubernetes.io/docs/concepts/services-networking/ingress/)。

### 快速开始

#### 使用 Helm

```bash
helm repo add ingress-nginx https://baranchen.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx
```

#### 使用 kubectl

```bash
kubectl apply -f https://raw.githubusercontent.com/baranchen/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

#### 从源码构建

```bash
git clone https://github.com/baranchen/ingress-nginx.git
cd ingress-nginx

# 构建 nginx 基础镜像
cd images/nginx
docker build --platform linux/amd64,linux/arm64 rootfs \
  --tag your-registry/ingress-nginx/nginx:v1.30.2

# 构建控制器
cd ../..
make REGISTRY=your-registry TAG=v1.30.2 build
make REGISTRY=your-registry TAG=v1.30.2 image
```

### 支持版本

| Ingress-NGINX 版本 | Kubernetes 版本 | Alpine | NGINX 版本 | Helm Chart |
| ------------------ | --------------- | ------ | ---------- | ---------- |
| **v1.30.2**        | 1.35, 1.34, 1.33 | 3.23.3 | 1.30.2     | -          |

### 使用警告

请勿在多租户 Kubernetes 生产环境中使用。本项目假设能够创建 Ingress 资源的用户即为集群管理员。

### 上游致谢

本项目是 [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx) 的分支，
最初由 Kubernetes 社区开发，采用 [Apache License 2.0](LICENSE) 许可证。我们衷心感谢所有上游贡献者的工作。

### 贡献

欢迎贡献代码！请随时提交 Pull Request。

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/my-feature`)
3. 提交修改 (`git commit -am 'Add some feature'`)
4. 推送到分支 (`git push origin feature/my-feature`)
5. 创建新的 Pull Request

### 报告问题

请使用 [GitHub Issues](https://github.com/baranchen/ingress-nginx/issues) 报告缺陷或提交功能请求。

### 安全漏洞

如发现安全漏洞，请通过
[GitHub 安全公告](https://github.com/baranchen/ingress-nginx/security/advisories/new)私密报告。
请勿公开提交安全漏洞问题。

### 更新日志

上游更新历史见 [Changelog.md](Changelog.md)。
本分支的变更通过 [GitHub Releases](https://github.com/baranchen/ingress-nginx/releases) 追踪。

### 许可证

[Apache License 2.0](LICENSE) — 与上游项目保持一致。
