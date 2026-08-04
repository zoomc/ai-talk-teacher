# Aliyun dual-environment deployment

`.github/workflows/deploy-aliyun.yml` builds two immutable Flutter Web artifacts
from the same commit:

- Production: `APP_MODE=production`, base path `/talk/`.
- Demo: `APP_MODE=demo`, base path `/talk-demo/`, protected by nginx Basic Auth.

The workflow uploads one tarball, extracts it under a commit-specific release
directory, checks both `index.html` files, then atomically swaps the two nginx
document-root symlinks and reloads nginx only after `nginx -t` succeeds. It keeps
old release directories so rollback does not require rebuilding.

## Required GitHub environment secrets

`ALIYUN_HOST`, `ALIYUN_USER`, `ALIYUN_SSH_KEY`, optional `ALIYUN_SSH_PORT`,
`ALIYUN_RELEASE_ROOT`, `ALIYUN_PROD_TARGET`, `ALIYUN_DEMO_TARGET`,
`ALIYUN_PROD_URL`, `ALIYUN_DEMO_URL`, `DEMO_BASIC_AUTH_USER`, and
`DEMO_BASIC_AUTH_PASSWORD`.

`ALIYUN_PROD_TARGET` and `ALIYUN_DEMO_TARGET` are symlink paths used as nginx
roots. The server must already have nginx locations for `/talk/` and
`/talk-demo/`, SPA fallback for each path, and `auth_basic` on the Demo location.
The workflow validates the nginx configuration and public entry points but does
not create credentials or weaken server access controls.

The legacy `scripts/deploy_web.sh` remains a manual production helper for the
existing `/talk/` installation. It must not be used as proof of CI deployment;
the GitHub workflow is the dual-environment release path.
