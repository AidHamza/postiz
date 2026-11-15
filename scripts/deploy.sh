#!/usr/bin/env bash
# Server-side deployment of the release this script lives in.
# Order: config -> pull -> pre-deploy backup -> start/wait -> readiness ->
# owner bootstrap -> optional SMTP import -> edge route. Secrets never rotate.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
cd "$here/.."
umask 077
scripts/configure.sh "$POSTIZ_SHARED_DIR" "${POSTIZ_PUBLIC_URL:-https://social.appsdoc.com}"
dc config -q
log "pulling pinned images"
dc pull -q
if [ -n "$(dc ps -q postiz-postgres 2>/dev/null)" ]; then
  log "existing installation: pre-deploy backup"
  scripts/backup.sh "$POSTIZ_ROOT/backups"
fi
log "starting stack"
dc up -d --wait --wait-timeout 900 --remove-orphans
scripts/wait-ready.sh
scripts/bootstrap-owner.sh
if [ -n "${POSTIZ_SMTP_SOURCE:-}" ] && ! grep -q '^EMAIL_PROVIDER=' "$POSTIZ_SHARED_DIR/app.env"; then
  scripts/import-smtp.sh "$POSTIZ_SMTP_SOURCE" "$POSTIZ_SHARED_DIR/app.env"
  if grep -q '^EMAIL_PROVIDER=' "$POSTIZ_SHARED_DIR/app.env"; then
    log "recreating postiz with email settings"
    dc up -d --wait --wait-timeout 900 postiz
    scripts/wait-ready.sh
  fi
fi
scripts/install-edge.sh
log "deploy complete"
