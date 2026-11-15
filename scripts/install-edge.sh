#!/usr/bin/env bash
# Install the Postiz site into the shared server-edge Caddy, validate the full
# edge configuration, then hot-reload. Refuses while registration is open.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
edge="${SERVER_EDGE_DIR:-/opt/server-edge}"
src="$(dirname "$0")/../deploy/edge/appsdoc-postiz.caddy"
dst="$edge/sites/appsdoc-postiz.caddy"
if can_register; then log "edge: registration is open; not exposing Postiz"; exit 1; fi
if [ -f "$dst" ] && cmp -s "$src" "$dst"; then log "edge: site file unchanged"; exit 0; fi
prev=""
if [ -f "$dst" ]; then prev="$(mktemp)"; cp -p "$dst" "$prev"; fi
install -m 0644 "$src" "$dst"
if ! (cd "$edge" && make -s validate >/dev/null); then
  log "edge: validation failed; restoring previous site file"
  if [ -n "$prev" ]; then cp -p "$prev" "$dst"; else rm -f "$dst"; fi
  (cd "$edge" && make -s validate) || true
  exit 1
fi
(cd "$edge" && docker compose --env-file .env -f compose.yml exec -T caddy caddy reload --config /etc/caddy/Caddyfile)
log "edge: site installed and Caddy reloaded"
[ -n "$prev" ] && rm -f "$prev"
exit 0
