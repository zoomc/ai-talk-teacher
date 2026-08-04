# Rollback

Rollback is a pair of symlink switches to a previously extracted Production and
Demo Web release. It does not delete the release directory or touch user
SQLite/IndexedDB data.

1. SSH to the Aliyun host and list `/opt/ai-talk-teacher-releases` by commit SHA.
2. Confirm the candidate contains `release-payload/prod/index.html` and
   `release-payload/demo/index.html`.
3. Point the production and Demo `.next` symlinks at the candidate directories.
4. Atomically replace both active roots with `mv -Tf`.
5. Run `sudo -n nginx -t && sudo -n systemctl reload nginx`.
6. Verify both URLs, including Demo Basic Auth and `version.json`, then record the old/new SHA.

The rollback must never use `rm -rf` against the active document root. Retain at
least the last two immutable releases and remove old releases only under an
explicit retention policy after a successful health check.
