#!/usr/bin/env bash
# Wrapper for every Compose call: constant project name (volumes survive
# release changes) and private env files from outside the release directory.
#   POSTIZ_SHARED_DIR   private config dir (default /opt/appsdoc/postiz/shared)
#   POSTIZ_COMPOSE_EXTRA optional extra compose file (e.g. compose.local.yaml)
set -euo pipefail
cd "$(dirname "$0")/.."
export POSTIZ_SHARED_DIR="${POSTIZ_SHARED_DIR:-/opt/appsdoc/postiz/shared}"
args=(--project-name "${POSTIZ_PROJECT:-appsdoc_postiz}" --env-file "$POSTIZ_SHARED_DIR/infra.env" -f compose.yaml)
if [ -n "${POSTIZ_COMPOSE_EXTRA:-}" ]; then args+=(-f "$POSTIZ_COMPOSE_EXTRA"); fi
exec docker compose "${args[@]}" "$@"
