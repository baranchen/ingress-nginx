# Changelog

### controller-v1.30.6 (Community Fork)

Security update of the community-maintained fork of ingress-nginx: NGINX upgraded from 1.30.5 to 1.30.6 (stable).

### All changes:

* Upgrade NGINX from 1.30.5 to 1.30.6 (stable)
* Update nginx tarball SHA256 hash for 1.30.6
* Rename 33 nginx patches to 1.30.6 naming (contents unchanged, verified all 34 patches apply cleanly)
* Update TAG, NGINX_BASE, Helm chart and deploy manifests to v1.30.6
* README: add long-term Gateway API migration recommendation (this fork is a transitional solution)

### NGINX version highlights (1.30.5 → 1.30.6):

* CVE-2026-15176 fix — heap buffer overflow when the request URI was changed by the rewrite directive and then mapped to a file path via alias (Critical, CVSS 9.2)
* CVE-2026-93479 fix — buffer overflow while evaluating string expressions with variables, affecting document root calculation and request logging
* CVE-2026-95101 fix — HTTP/3 unknown frame part treated as request body, bypassing client_max_body_size or injecting data into the proxied request
* CVE-2026-97629 fix — TLS session ticket key rotation left a key uninitialized, allowing session forgery
* CVE-2026-97205 fix — use-after-free with AIO when an SSI page has include virtual commands

### Supported Kubernetes versions:

1.35, 1.34, 1.33

**Full Changelog**: https://github.com/baranchen/ingress-nginx/compare/v1.30.5...v1.30.6
