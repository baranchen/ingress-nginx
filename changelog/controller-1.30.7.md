# Changelog

### controller-v1.30.7 (Community Fork)

Security update of the community-maintained fork of ingress-nginx: NGINX upgraded from 1.30.6 to 1.30.7 (stable).

* Upgrade NGINX from 1.30.6 to 1.30.7 (stable)
* Update nginx tarball SHA256 hash for 1.30.7
* Rename 33 nginx patches to 1.30.7 naming (contents unchanged, verified all 34 patches apply cleanly)
* Update TAG, NGINX_BASE, Helm chart and deploy manifests to v1.30.7

### NGINX version highlights (1.30.6 → 1.30.7):

Security fixes relevant to ingress-nginx:

* CVE-2026-125283: buffer overflow with "try_files" and "alias" in certain configurations
* CVE-2026-123007: HTTP/2 flow control window overflow, could segfault a worker process
* CVE-2026-123633: use-after-free in HTTP/2 when worker_connections were not enough
* CVE-2026-121810: use-after-free in HTTP/3 when worker_connections were not enough
* CVE-2026-123634: use-after-free in resolver when the same name was resolved in subrequests
* CVE-2026-118899: worker processes endless loop while reading the request body over SSL
* CVE-2026-120967: stream module — client SSL certificates might be verified using the default server's config rather than the SNI-selected virtual server (stream modules are compiled into ingress-nginx)
* CVE-2026-123640: ngx_stream_ssl_preread_module might interpret malformed ClientHello messages differently than other TLS implementations (compiled into ingress-nginx)

Not compiled in (mail proxy only): CVE-2026-113425.

**Full Changelog**: https://github.com/baranchen/ingress-nginx/compare/v1.30.6...v1.30.7
