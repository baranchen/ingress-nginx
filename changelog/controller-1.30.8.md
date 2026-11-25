# Changelog

### controller-v1.30.8 (Community Fork)

Security update of the community-maintained fork of ingress-nginx: NGINX upgraded from 1.30.7 to 1.30.8 (stable), released upstream on 2026-11-23.

* Upgrade NGINX from 1.30.7 to 1.30.8 (stable)
* Update nginx tarball SHA256 hash for 1.30.8
* Rename 33 nginx patches to 1.30.8 naming (contents unchanged; `00_drop-alias-root.patch` carries no version and is untouched)
* Update TAG, NGINX_BASE, Helm chart and deploy manifests to v1.30.8

### NGINX version highlights (1.30.7 → 1.30.8):

Security fixes relevant to ingress-nginx:

* CVE-2026-132779 (medium, NGINX official): excessive CPU usage in TLS 1.3 when the "ssl_early_data" directive is used. The default configuration is not affected (`ssl-early-data: false`); deployments that enable it via ConfigMap, `http-snippet` or `server-snippet` are affected — disable the directive to mitigate.

Bugfixes relevant to ingress-nginx:

* nginx might hog CPU if SSL connections to backends were used.

### Upgrade scope

Upstream changed only three source files between 1.30.7 and 1.30.8: `src/core/nginx.h` (version), `src/core/ngx_output_chain.c` and `src/http/ngx_http_write_filter_module.c` (the two CPU fixes). Neither of the two fixed files is touched by any of the 34 nginx patches carried in this fork. Third-party module versions are unchanged.

### Rollback

* Helm: `helm rollback <release> <previous-revision>` (or reinstall with `controller.image.tag=v1.30.7`).
* Harbor (only if the v1.30.7 images need to be re-published): `TAG=v1.30.7 WITH_LATEST=0 sh ci/publish-harbor.sh`.

**Full Changelog**: https://github.com/baranchen/ingress-nginx/compare/v1.30.7...v1.30.8
