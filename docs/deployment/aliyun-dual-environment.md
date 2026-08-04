# Aliyun production Web deployment

`.github/workflows/deploy-aliyun.yml` is the only GitHub Actions deployment
entrypoint. It builds one Flutter Web artifact from the selected commit and
publishes it to `/talk/` on the Aliyun host.

The workflow uploads a stamped tarball, extracts it under a commit-specific
release directory, switches `/opt/ai-talk-teacher` to the new Web root, runs
`nginx -t`, reloads nginx, and verifies the public entry point, deep-link
fallback, and `version.json`. A failed post-activation check restores the
previous production root. Demo and E2E builds remain CI/local test concerns and
are not deployed by this workflow.

## Required GitHub environment secrets

Configure these secrets in the `aliyun-production` environment:

`ALIYUN_HOST`, `ALIYUN_USER`, and `ALIYUN_SSH_KEY`. `ALIYUN_SSH_PORT` is
optional and defaults to `22`.

The current server layout used by the workflow is:

- Public URL: `https://zoomlab.top/talk/`
- Nginx Web root: `/opt/ai-talk-teacher`
- Immutable release root: `/opt/ai-talk-teacher-releases`

The workflow must not be considered successful unless the remote nginx test and
public version/deep-link checks pass. Local builds or a manual rsync are not
deployment evidence.
