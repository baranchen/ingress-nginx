# Ingress NGINX Controller (Community Fork)

> This is a community-maintained fork of [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx).
> The upstream project was officially retired in March 2026. This fork continues maintenance
> with NGINX version updates, security patches, and bug fixes.

## About This Fork

The original `kubernetes/ingress-nginx` project ceased active development after March 2026.
This fork was created to continue providing security updates and NGINX version upgrades
for users who still rely on the Ingress NGINX controller in their Kubernetes clusters.

### What's Changed from Upstream

| Item | Upstream (v1.15.1) | This Fork (v1.30.2) |
|------|-------------------|---------------------|
| NGINX Version | 1.27.1 | **1.30.2** |
| OpenSSL | 3.5.x | 3.5.6 |
| CVE-2025-23419 | Backported patch | **Fixed upstream in NGINX 1.27.4+** |
| Controller Version | v1.15.1 | v1.30.2 |

For users currently running the upstream `kubernetes/ingress-nginx`, this fork is a
**drop-in replacement** — no configuration changes required.

## Overview

ingress-nginx is an Ingress controller for Kubernetes using [NGINX](https://www.nginx.org/)
as a reverse proxy and load balancer.

[Learn more about Ingress on the Kubernetes documentation site](https://kubernetes.io/docs/concepts/services-networking/ingress/).

## Quick Start

### Using Helm

```bash
helm repo add ingress-nginx https://baranchen.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx
```

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
docker build --platform linux/amd64,linux/arm64 rootfs \
  --tag your-registry/ingress-nginx/nginx:v1.30.2

# Build controller
cd ../..
make REGISTRY=your-registry TAG=v1.30.2 build
make REGISTRY=your-registry TAG=v1.30.2 image
```

## Supported Versions

| Ingress-NGINX version | Kubernetes Version | Alpine | NGINX Version | Helm Chart |
| --------------------- | ------------------ | ------ | ------------- | ---------- |
| **v1.30.2**           | 1.35, 1.34, 1.33   | 3.23.3 | 1.30.2        | -          |

## Usage Warnings

Do not use in multi-tenant Kubernetes production installations. This project assumes
that users who can create Ingress objects are administrators of the cluster.

## Upstream Credit

This project is a fork of [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx),
originally developed by the Kubernetes community and licensed under the
[Apache License 2.0](LICENSE). We gratefully acknowledge the work of all upstream contributors.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request

## Reporting Issues

Please use [GitHub Issues](https://github.com/baranchen/ingress-nginx/issues) to report
bugs or request features.

## Security Vulnerabilities

If you discover a security vulnerability, please report it privately by opening a
[GitHub Security Advisory](https://github.com/baranchen/ingress-nginx/security/advisories/new).
Do not file public issues for security vulnerabilities.

## Changelog

See [Changelog.md](Changelog.md) for the upstream changelog history.
Changes specific to this fork are tracked in [GitHub Releases](https://github.com/baranchen/ingress-nginx/releases).

## License

[Apache License 2.0](LICENSE) — Same license as the upstream project.
