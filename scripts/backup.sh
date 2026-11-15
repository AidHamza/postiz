#!/usr/bin/env bash
# Consistent online backup (no pause): pg_dump of the Postiz DB, pg_dumpall of
# Temporal persistence, uploads/config archives and the private env files.
# Output is secret: directory 0700, files 0600. Keeps the newest $RETAIN (14).
# Not included: Redis (cache/queue state) and Elasticsearch (Temporal visibility
# index) — see docs/OPERATIONS.md.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
dest="${1:-$POSTIZ_ROOT/backups}"
umask 077
mkdir -p "$dest"; chmod 700 "$dest"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
out="$dest/postiz-$ts"
mkdir "$out.partial"
trap 'rm -rf "$out.partial"' ERR
dc exec -T postiz-postgres pg_dump -U postiz -d postiz -Fc >"$out.partial/postiz.dump"
dc exec -T temporal-postgresql pg_dumpall -U temporal >"$out.partial/temporal.sql"
dc exec -T postiz tar -C /uploads -czf - . >"$out.partial/uploads.tgz"
dc exec -T postiz tar -C /config -czf - . >"$out.partial/config.tgz"
mkdir "$out.partial/secrets"
cp "$POSTIZ_SHARED_DIR/infra.env" "$POSTIZ_SHARED_DIR/app.env" "$out.partial/secrets/"
[ -f "$POSTIZ_SHARED_DIR/owner-login" ] && cp "$POSTIZ_SHARED_DIR/owner-login" "$out.partial/secrets/"
(cd "$out.partial" && sha256sum postiz.dump temporal.sql uploads.tgz config.tgz secrets/* >SHA256SUMS)
mv "$out.partial" "$out"
trap - ERR
log "backup written: $out ($(du -sh "$out" | cut -f1))"
ls -1d "$dest"/postiz-2* 2>/dev/null | sort | head -n -"${RETAIN:-14}" | xargs -r rm -rf
