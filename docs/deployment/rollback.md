# Rollback

Rollback is a symlink switch to a previously extracted release. It does not
delete the release directory or touch user SQLite/IndexedDB data.

1. SSH to the Aliyun host and list `$ALIYUN_RELEASE_ROOT` by commit SHA.
2. Confirm the candidate contains both `release-payload/prod/index.html` and
   `release-payload/demo/index.html`.
3. Point the production and Demo `.next` symlinks at the candidate directories.
4. Atomically replace each active symlink with `mv -Tf`.
5. Run `sudo -n nginx -t && sudo -n systemctl reload nginx`.
6. Verify production and Basic-Auth Demo URLs, then record the old/new SHA.

The rollback must never use `rm -rf` against the active document root. Retain at
least the last two immutable releases and remove old releases only under an
explicit retention policy after a successful health check.
