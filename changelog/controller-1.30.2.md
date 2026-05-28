# Changelog

### controller-v1.30.2 (Community Fork)

This is the first release of the community-maintained fork of ingress-nginx, based on upstream v1.15.1 with NGINX upgraded to 1.30.2.

### All changes:

* Upgrade NGINX from 1.27.1 to 1.30.2 (stable)
* Update nginx tarball SHA256 hash for 1.30.2
* Remove CVE-2025-23419 patch (fixed upstream in NGINX 1.27.4+)
* Rebase 34 OpenResty patches to NGINX 1.30.2
* Update README and documentation for community fork
* Update OWNERS, SECURITY, CONTRIBUTING for fork maintenance
* Remove Kubernetes community-specific process documents

### NGINX version highlights (1.27.1 → 1.30.2):

* NGINX 1.27.2: SSL certificate caching, ssl_session_log directive
* NGINX 1.27.3: Upstream server `resolve` parameter, resolver in upstream blocks
* NGINX 1.27.4: CVE-2025-23419 fix (TLSv1.3 SNI session resumption bypass)
* NGINX 1.27.5: CUBIC congestion control in QUIC, ssl_certificate_compression directive
* NGINX 1.28.0: Stable branch from 1.27.5
* NGINX 1.28.1: Bug fixes
* NGINX 1.28.2: Security fixes
* NGINX 1.30.0: HTTP/2 upstream proxy support, upstream sticky sessions, early hints (103)
* NGINX 1.30.1: Bug fixes
* NGINX 1.30.2: Latest stable with all security patches

### Supported Kubernetes versions:

1.35, 1.34, 1.33

**Full Changelog**: https://github.com/kubernetes/ingress-nginx/compare/controller-v1.15.1...baranchen:ingress-nginx:controller-v1.30.2
