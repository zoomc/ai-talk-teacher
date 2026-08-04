# Rollback

Rollback is a symlink switch to a previously extracted production Web release.
It does not delete the release directory or touch user SQLite/IndexedDB data.

1. SSH to the Aliyun host and list `/opt/ai-talk-teacher-releases` by commit SHA.
2. Confirm the candidate contains `release-payload/web/index.html`.
3. Point the production `.next` symlink at the candidate Web directory.
4. Atomically replace the active production root with `mv -Tf`.
5. Run `sudo -n nginx -t && sudo -n systemctl reload nginx`.
6. Verify `https://zoomlab.top/talk/` and its `version.json`, then record the old/new SHA.

The rollback must never use `rm -rf` against the active document root. Retain at
least the last two immutable releases and remove old releases only under an
explicit retention policy after a successful health check.
