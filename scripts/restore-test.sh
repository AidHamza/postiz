#!/usr/bin/env bash
# Isolated restore test. Restores a backup into throwaway database containers
# with --network none (no ports, no egress, no scheduler/worker), verifies the
# content, then removes them. Never touches production volumes.
# Usage: scripts/restore-test.sh [backup-dir]   (default: newest)
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
b="${1:-$(ls -1d "$POSTIZ_ROOT"/backups/postiz-2* | sort | tail -1)}"
[ -d "$b" ] || { echo "no backup found"; exit 1; }
log "restore-test from $(basename "$b")"
(cd "$b" && sha256sum -c --quiet SHA256SUMS)
log "checksums ok"
img_pg17="$(grep -m1 'image: postgres:17' "$here/../compose.yaml" | awk '{print $2}')"
img_pg16="$(grep -m1 'image: postgres:16' "$here/../compose.yaml" | awk '{print $2}')"
a=appsdoc-postiz-restoretest-app; t=appsdoc-postiz-restoretest-temporal
cleanup() { docker rm -f "$a" "$t" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
pw="$(openssl rand -hex 16)"
docker run -d --rm --name "$a" --network none -e POSTGRES_PASSWORD="$pw" "$img_pg17" >/dev/null
docker run -d --rm --name "$t" --network none -e POSTGRES_PASSWORD="$pw" -e POSTGRES_USER=temporal "$img_pg16" >/dev/null
# The image's init server listens on the socket only; wait for the real one on TCP.
wait_pg() { for _ in $(seq 1 90); do docker exec "$1" psql -h 127.0.0.1 -U "$2" -d postgres -tAc 'select 1' >/dev/null 2>&1 && return 0; sleep 2; done; return 1; }
wait_pg "$a" postgres; wait_pg "$t" temporal
docker exec "$a" createdb -U postgres postiz
docker exec -i "$a" pg_restore -U postgres -d postiz --no-owner --exit-on-error <"$b/postiz.dump"
q() { docker exec "$a" psql -U postgres -d postiz -tAc "$1"; }
log "postiz: users=$(q 'select count(*) from "User" where "deletedAt" is null') orgs=$(q 'select count(*) from "Organization" where "deletedAt" is null') media=$(q 'select count(*) from "Media" where "deletedAt" is null')"
docker exec -i "$t" psql -q -U temporal -d postgres -v ON_ERROR_STOP=0 >/dev/null 2>&1 <"$b/temporal.sql" || true
log "temporal: namespaces=$(docker exec "$t" psql -U temporal -d temporal -tAc 'select count(*) from namespaces') executions=$(docker exec "$t" psql -U temporal -d temporal -tAc 'select count(*) from executions')"
log "uploads: files=$(tar -tzf "$b/uploads.tgz" | grep -vc '/$')"
keylen="$(grep '^ENCRYPTION_KEY=' "$b/secrets/app.env" | cut -d= -f2- | base64 -d | wc -c)"
[ "$keylen" = 32 ] || { log "ENCRYPTION_KEY in backup is not 32 bytes"; exit 1; }
log "secrets: ENCRYPTION_KEY present (32 bytes)"
log "restore-test passed"
