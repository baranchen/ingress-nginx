# Changelog

### controller-v1.30.5 (Community Fork)

Security update of the community-maintained fork of ingress-nginx: NGINX upgraded from 1.30.2 to 1.30.5 (stable).

### All changes:

* Upgrade NGINX from 1.30.2 to 1.30.5 (stable)
* Update nginx tarball SHA256 hash for 1.30.5
* Rebase the log_escape_non_ascii patch to NGINX 1.30.5 (the log module was refactored upstream with buffer length checks and a new ngx_http_log_escape call site)
* Rename 33 nginx patches to 1.30.5 naming (contents unchanged, verified all 34 patches apply cleanly)
* Update TAG, NGINX_BASE, Helm chart and deploy manifests to v1.30.5

### NGINX version highlights (1.30.2 → 1.30.5):

* NGINX 1.30.3: CVE-2026-42055 fix (heap buffer overflow when proxying crafted requests to HTTP/2 or gRPC backends), CVE-2026-48142 fix (worker memory disclosure via charset_map UTF-8 decoding)
* NGINX 1.30.4: CVE-2026-42533 fix (heap buffer overflow with map regex matching), CVE-2026-60005 fix (worker memory disclosure with the slice directive / unnamed regex captures), CVE-2026-56434 fix (use-after-free in the SSI filter module)
* NGINX 1.30.5: CVE-2026-90439 fix (heap buffer overflow in ngx_http_v3_module when using HTTP/3 with OpenSSL 3.5.0 and earlier), hardening: QUIC transport parameters extension received during an SSL connection is now always ignored

### Supported Kubernetes versions:

1.35, 1.34, 1.33

**Full Changelog**: https://github.com/baranchen/ingress-nginx/compare/controller-v1.30.2...controller-v1.30.5
