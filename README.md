<div align="center">

# Ingress NGINX Controller

### Community-Maintained Fork

[![GitHub Release](https://img.shields.io/github/v/release/baranchen/ingress-nginx?style=for-the-badge&label=Release&color=blue)](https://github.com/baranchen/ingress-nginx/releases)
[![NGINX](https://img.shields.io/badge/NGINX-1.30.6-green?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge)](LICENSE)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.33%20%7C%201.34%20%7C%201.35-blue?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)

**English** | [中文](#中文)

> Community-maintained fork of [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx).
> The upstream project was retired in March 2026.
> This fork continues with NGINX updates, security patches, and bug fixes.

</div>

---

## What's Changed

| | Upstream (v1.15.1) | This Fork (v1.30.6) |
|---|---|---|
| **NGINX** | 1.27.1 | **1.30.6** (stable) |
| **OpenSSL** | 3.5.x | 3.5.6 |
| **CVE-2025-23419** | Backported patch | Fixed upstream (1.27.4+) |

**Drop-in replacement** — no configuration changes required for existing installations.

## Security Fixes

### NGINX (upgraded from 1.27.1, currently 1.30.6)

| CVE | Severity | Description |
|-----|----------|-------------|
| **CVE-2026-42945** | Critical | Heap buffer overflow in `ngx_http_rewrite_module` (NGINX Rift) |
| **CVE-2026-15176** | Critical (9.2) | Heap buffer overflow when the request URI is changed by `rewrite` and then mapped to a file path via `alias` (fixed in 1.30.6) |
| **CVE-2026-9256** | High | Buffer overflow vulnerability |
| **CVE-2026-42055** | High | Heap buffer overflow when proxying crafted requests to HTTP/2 or gRPC backends (fixed in 1.30.3) |
| **CVE-2026-42533** | High | Heap buffer overflow when using `map` with regex matching (fixed in 1.30.4) |
| **CVE-2026-93479** | High | Buffer overflow when evaluating string expressions with variables, affecting document root calculation and request logging (fixed in 1.30.6) |
| **CVE-2026-95101** | High | HTTP/3 unknown frame part treated as request body, bypassing `client_max_body_size` or injecting data into the proxied request (fixed in 1.30.6) |
| **CVE-2026-28755** | Medium | OCSP result bypass in stream module |
| **CVE-2026-1642** | Medium | SSL upstream injection |
| **CVE-2026-48142** | Medium | Worker memory disclosure via `charset_map` UTF-8 decoding (fixed in 1.30.3) |
| **CVE-2026-60005** | Medium | Worker memory disclosure with `slice` directive / unnamed regex captures (fixed in 1.30.4) |
| **CVE-2026-56434** | Medium | Use-after-free in `ngx_http_ssi_filter_module` (fixed in 1.30.4) |
| **CVE-2026-90439** | Medium (6.9) | Heap buffer overflow in `ngx_http_v3_module` with HTTP/3 + OpenSSL ≤ 3.5.0 (fixed in 1.30.5) |
| **CVE-2026-97629** | Medium | TLS session ticket key rotation left a key uninitialized, allowing session forgery (fixed in 1.30.6) |
| **CVE-2026-97205** | Medium | Use-after-free with AIO when an SSI page has `include virtual` commands (fixed in 1.30.6) |
| **CVE-2025-53859** | Medium | SSL-related vulnerability |
| **CVE-2025-23419** | Medium | TLSv1.3 SNI session resumption bypass |

### Ingress-NGINX Controller (upstream patches through v1.15.1)

| CVE | Severity | Description |
|-----|----------|-------------|
| **CVE-2025-1974** | Critical (9.8) | IngressNightmare — unauthenticated RCE via admission webhook |
| **CVE-2025-24514** | Medium (6.5) | DoS via validating admission controller |
| **CVE-2025-1097** | High | IngressNightmare chain — auth-method injection |
| **CVE-2025-1098** | High | IngressNightmare chain — configuration injection |

## Quick Start

### Using Helm

```bash
helm install ingress-nginx oci://ghcr.io/baranchen/ingress-nginx/charts/ingress-nginx \
  --set controller.image.tag=v1.30.6
```

> **Note:** Helm chart OCI publishing is not yet available.
> Alternatively, clone the repo and install from source:
> ```bash
> helm install ingress-nginx charts/ingress-nginx \
>   --set controller.image.registry=ghcr.io/baranchen/ingress-nginx \
>   --set controller.image.tag=v1.30.6
> ```

### Using kubectl

```bash
kubectl apply -f https://raw.githubusercontent.com/baranchen/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### Build from Source

```bash
git clone https://github.com/baranchen/ingress-nginx.git
cd ingress-nginx

# Build nginx base image
cd images/nginx
docker buildx build --platform linux/amd64,linux/arm64 rootfs \
  --tag your-registry/ingress-nginx/nginx:v1.30.6 --push

# Build controller
cd ../..
make REGISTRY=your-registry TAG=v1.30.6 release
```

## Supported Versions

| Ingress-NGINX | Kubernetes | NGINX | Alpine | Helm Chart |
|---|---|---|---|---|
| **v1.30.6** | 1.35, 1.34, 1.33 | 1.30.6 | 3.23.3 | — |

## NGINX Upgrade Highlights (1.27.1 → 1.30.6)

- **1.27.2** — SSL certificate caching, `ssl_session_log` directive
- **1.27.3** — Upstream server `resolve` parameter, resolver in upstream blocks
- **1.27.4** — CVE-2025-23419 fix (TLSv1.3 SNI session resumption bypass)
- **1.27.5** — CUBIC congestion control in QUIC, `ssl_certificate_compression` directive
- **1.28.0** — Stable branch from 1.27.5
- **1.30.0** — HTTP/2 upstream proxy, upstream sticky sessions, early hints (103)
- **1.30.2** — CVE-2026-9256 fix (rewrite module buffer overflow)
- **1.30.3** — CVE-2026-42055 / CVE-2026-48142 fixes (HTTP/2 backend proxying, charset decoding)
- **1.30.4** — CVE-2026-42533 / CVE-2026-60005 / CVE-2026-56434 fixes (map regex, slice, SSI)
- **1.30.5** — CVE-2026-90439 fix (HTTP/3); always ignore QUIC transport parameters during SSL handshake
- **1.30.6** — CVE-2026-15176 / CVE-2026-93479 / CVE-2026-95101 / CVE-2026-97629 / CVE-2026-97205 fixes (alias+rewrite overflow, string expression overflow, HTTP/3 request body injection, TLS session ticket forgery, AIO+SSI use-after-free) — latest stable

## Usage Warning

Do not use in multi-tenant Kubernetes production installations.
This project assumes users who can create Ingress objects are cluster administrators.

## Long-Term Recommendation: Migrate to Gateway API

This fork is a **transitional solution**. It keeps NGINX and security patches current,
but the sustainable path is to migrate to an actively maintained gateway that is part of
the Kubernetes ecosystem's standard direction:

- **Recommended:** [Gateway API](https://gateway-api.sigs.k8s.io/) + [Envoy Gateway](https://envoygateway.io/) (or another Gateway API implementation)
- **Alternatives:** Traefik, HAProxy Ingress, Kong Ingress Controller, Cilium Gateway API — choose based on L4/L7 needs, auth/rate-limiting requirements, and existing stack

Suggested migration approach:

1. Deploy the new gateway in parallel (new entry IP or nodes — do not replace the controller in place)
2. Convert existing Ingress rules with [`ingress2gateway`](https://github.com/kubernetes-sigs/ingress2gateway), then manually review NGINX-specific annotations (`rewrite-target`, `configuration-snippet`, etc.)
3. Shift traffic gradually per hostname, keeping rollback paths open
4. Decommission ingress-nginx once all domains are stable on the new gateway

Until migration is complete, running this fork keeps your ingress layer patched. But treat
it as a bridge, not a destination — plan the migration before your next architecture review.

## Upstream Credit

This project is a fork of [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx),
originally developed by the Kubernetes community under the
[Apache License 2.0](LICENSE). We gratefully acknowledge all upstream contributors.

## Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## Reporting Issues

Use [GitHub Issues](https://github.com/baranchen/ingress-nginx/issues) for bugs and feature requests.

## Security

Report vulnerabilities privately via
[GitHub Security Advisory](https://github.com/baranchen/ingress-nginx/security/advisories/new).
Do not file public issues for security vulnerabilities.

## Changelog

- Fork changes: [GitHub Releases](https://github.com/baranchen/ingress-nginx/releases)
- Upstream history: [Changelog.md](Changelog.md)

---

<div align="center">

## 中文

</div>

> 这是 [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx) 的社区维护分支。
> 上游项目已于 2026 年 3 月正式停止维护。本分支将继续提供 NGINX 版本更新、安全补丁和缺陷修复。

## 与上游的差异

| | 上游 (v1.15.1) | 本分支 (v1.30.6) |
|---|---|---|
| **NGINX** | 1.27.1 | **1.30.6** (stable) |
| **OpenSSL** | 3.5.x | 3.5.6 |
| **CVE-2025-23419** | 回移补丁 | 已在上游修复 (1.27.4+) |

**直接替换方案** — 无需修改任何配置即可从上游迁移。

## 安全修复

### NGINX（从 1.27.1 升级，当前 1.30.6）

| CVE | 严重程度 | 描述 |
|-----|----------|------|
| **CVE-2026-42945** | 严重 | `ngx_http_rewrite_module` 堆缓冲区溢出（NGINX Rift） |
| **CVE-2026-15176** | 严重 (9.2) | 请求 URI 被 `rewrite` 修改后再经 `alias` 映射为文件路径时堆缓冲区溢出（1.30.6 修复） |
| **CVE-2026-9256** | 高 | 缓冲区溢出漏洞 |
| **CVE-2026-42055** | 高 | 向 HTTP/2 或 gRPC 后端代理特制请求时堆缓冲区溢出（1.30.3 修复） |
| **CVE-2026-42533** | 高 | `map` 正则匹配堆缓冲区溢出（1.30.4 修复） |
| **CVE-2026-93479** | 高 | 含变量的字符串表达式求值时缓冲区溢出，影响 document root 计算与请求日志（1.30.6 修复） |
| **CVE-2026-95101** | 高 | HTTP/3 未知帧部分被当作请求体，可绕过 `client_max_body_size` 或向代理请求注入数据（1.30.6 修复） |
| **CVE-2026-28755** | 中 | Stream 模块 OCSP 结果绕过 |
| **CVE-2026-1642** | 中 | SSL 上游注入 |
| **CVE-2026-48142** | 中 | `charset_map` UTF-8 解码致 worker 内存泄露（1.30.3 修复） |
| **CVE-2026-60005** | 中 | `slice` 指令/未命名正则捕获致 worker 内存泄露（1.30.4 修复） |
| **CVE-2026-56434** | 中 | `ngx_http_ssi_filter_module` 释放后使用（1.30.4 修复） |
| **CVE-2026-90439** | 中 (6.9) | HTTP/3 + OpenSSL ≤ 3.5.0 时 `ngx_http_v3_module` 堆缓冲区溢出（1.30.5 修复） |
| **CVE-2026-97629** | 中 | TLS session ticket 密钥轮换时某个密钥未初始化，可伪造会话（1.30.6 修复） |
| **CVE-2026-97205** | 中 | 使用 AIO 时 SSI 页面含 `include virtual` 指令的场景下释放后使用（1.30.6 修复） |
| **CVE-2025-53859** | 中 | SSL 相关漏洞 |
| **CVE-2025-23419** | 中 | TLSv1.3 SNI 会话恢复绕过 |

### Ingress-NGINX 控制器（上游补丁至 v1.15.1）

| CVE | 严重程度 | 描述 |
|-----|----------|------|
| **CVE-2025-1974** | 严重 (9.8) | IngressNightmare — 通过准入 Webhook 实现未认证远程代码执行 |
| **CVE-2025-24514** | 中 (6.5) | 通过验证准入控制器实现拒绝服务 |
| **CVE-2025-1097** | 高 | IngressNightmare 攻击链 — 认证方式注入 |
| **CVE-2025-1098** | 高 | IngressNightmare 攻击链 — 配置注入 |

## 快速开始

### 使用 Helm

```bash
helm install ingress-nginx oci://ghcr.io/baranchen/ingress-nginx/charts/ingress-nginx \
  --set controller.image.tag=v1.30.6
```

> **注意：** Helm Chart OCI 发布尚未就绪。
> 替代方案——克隆仓库后从源码安装：
> ```bash
> helm install ingress-nginx charts/ingress-nginx \
>   --set controller.image.registry=ghcr.io/baranchen/ingress-nginx \
>   --set controller.image.tag=v1.30.6
> ```

### 使用 kubectl

```bash
kubectl apply -f https://raw.githubusercontent.com/baranchen/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

### 从源码构建

```bash
git clone https://github.com/baranchen/ingress-nginx.git
cd ingress-nginx

# 构建 nginx 基础镜像
cd images/nginx
docker buildx build --platform linux/amd64,linux/arm64 rootfs \
  --tag your-registry/ingress-nginx/nginx:v1.30.6 --push

# 构建控制器
cd ../..
make REGISTRY=your-registry TAG=v1.30.6 release
```

## 支持版本

| Ingress-NGINX | Kubernetes | NGINX | Alpine | Helm Chart |
|---|---|---|---|---|
| **v1.30.6** | 1.35, 1.34, 1.33 | 1.30.6 | 3.23.3 | — |

## NGINX 升级要点 (1.27.1 → 1.30.6)

- **1.27.2** — SSL 证书缓存、`ssl_session_log` 指令
- **1.27.3** — Upstream 服务器 `resolve` 参数、upstream 块中的 resolver
- **1.27.4** — CVE-2025-23419 修复（TLSv1.3 SNI 会话恢复绕过）
- **1.27.5** — QUIC CUBIC 拥塞控制、`ssl_certificate_compression` 指令
- **1.28.0** — 从 1.27.5 衍生的稳定分支
- **1.30.0** — HTTP/2 上游代理、upstream 粘性会话、Early Hints (103)
- **1.30.2** — CVE-2026-9256 修复（rewrite 模块缓冲区溢出）
- **1.30.3** — CVE-2026-42055 / CVE-2026-48142 修复（HTTP/2 后端代理、charset 解码）
- **1.30.4** — CVE-2026-42533 / CVE-2026-60005 / CVE-2026-56434 修复（map 正则、slice、SSI）
- **1.30.5** — CVE-2026-90439 修复（HTTP/3）；SSL 连接中一律忽略 QUIC transport parameters 扩展
- **1.30.6** — CVE-2026-15176 / CVE-2026-93479 / CVE-2026-95101 / CVE-2026-97629 / CVE-2026-97205 修复（alias+rewrite 溢出、字符串表达式溢出、HTTP/3 请求体注入、TLS 会话票据伪造、AIO+SSI 释放后使用）— 最新稳定版

## 使用警告

请勿在多租户 Kubernetes 生产环境中使用。本项目假设能够创建 Ingress 资源的用户即为集群管理员。

## 长期建议：迁移到 Gateway API

本分支是**过渡方案**。它会持续跟进 NGINX 版本和安全补丁，但可持续的方向是迁移到
Kubernetes 生态标准演进路线上仍在积极维护的网关：

- **推荐：** [Gateway API](https://gateway-api.sigs.k8s.io/) + [Envoy Gateway](https://envoygateway.io/)（或其他 Gateway API 实现）
- **备选：** Traefik、HAProxy Ingress、Kong Ingress Controller、Cilium Gateway API —— 按四层/七层需求、认证/限流要求和现有技术栈选择

建议的迁移方式：

1. 并行部署新网关（新增入口 IP 或入口节点，不要原地替换现有控制器）
2. 使用 [`ingress2gateway`](https://github.com/kubernetes-sigs/ingress2gateway) 转换现有 Ingress 规则，人工复核 NGINX 专有注解（`rewrite-target`、`configuration-snippet` 等）
3. 按域名逐步灰度切流，保留回滚路径
4. 全部域名稳定后下线 ingress-nginx

迁移完成前，运行本分支可保持入口层持续获得安全补丁。但请把它当作桥梁而非终点——
建议在下一次架构评审前制定迁移计划。

## 上游致谢

本项目是 [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx) 的分支，
最初由 Kubernetes 社区开发，采用 [Apache License 2.0](LICENSE) 许可证。衷心感谢所有上游贡献者的工作。

## 贡献

欢迎贡献代码！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/my-feature`)
3. 提交修改 (`git commit -am 'Add some feature'`)
4. 推送到分支 (`git push origin feature/my-feature`)
5. 创建 Pull Request

详细指南请参阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 报告问题

请使用 [GitHub Issues](https://github.com/baranchen/ingress-nginx/issues) 报告缺陷或提交功能请求。

## 安全漏洞

如发现安全漏洞，请通过
[GitHub 安全公告](https://github.com/baranchen/ingress-nginx/security/advisories/new)私密报告。
请勿公开提交安全漏洞问题。

## 更新日志

- 本分支变更：[GitHub Releases](https://github.com/baranchen/ingress-nginx/releases)
- 上游历史：[Changelog.md](Changelog.md)

---

<div align="center">

**[Apache License 2.0](LICENSE)**

</div>
