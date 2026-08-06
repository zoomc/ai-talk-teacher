# Aliyun production and Demo Web deployment

`.github/workflows/deploy-aliyun.yml` is the GitHub Actions deployment
entrypoint. It builds two Flutter Web artifacts from the selected commit:

- Production: `APP_MODE=production`, `https://zoomlab.top/talk/`
- Demo: `APP_MODE=demo`, `https://zoomlab.top/talk-demo/`, protected by nginx
  Basic Auth

The workflow uploads one stamped tarball, extracts it under a commit-specific
release directory, synchronizes the Demo credentials into
`/etc/nginx/.htpasswd.ai-talk-teacher-demo`, atomically switches both Web roots,
runs `nginx -t`, reloads nginx, and verifies both public entry points.
Production and Demo must both report the current commit in `version.json`; the
Demo must return `401` without credentials, pass with the configured credentials,
and send `X-Robots-Tag: noindex`. Any post-activation failure restores both
previous roots.

## Required GitHub environment secrets

Configure these secrets in the `aliyun-production` environment:

`ALIYUN_HOST`, `ALIYUN_USER`, `ALIYUN_SSH_KEY`, `DEMO_BASIC_AUTH_USER`, and
`DEMO_BASIC_AUTH_PASSWORD`. `ALIYUN_SSH_PORT` is optional and defaults to `22`.

The current server layout used by the workflow is:

- Production root: `/opt/ai-talk-teacher`
- Demo root: `/opt/ai-talk-teacher-demo`
- Immutable release root: `/opt/ai-talk-teacher-releases`
- Production URL: `https://zoomlab.top/talk/`
- Demo URL: `https://zoomlab.top/talk-demo/`

The workflow must not be considered successful unless nginx validation and both
production/Demo health checks pass. Local builds or a manual rsync are not
deployment evidence.
