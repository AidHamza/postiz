#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
dc ps --format 'table {{.Service}}\t{{.Status}}'
scripts_dir="$(dirname "$0")"
"$scripts_dir/wait-ready.sh" >/dev/null 2>&1 && echo "readiness: backend + orchestrator OK" || echo "readiness: FAILED"
can_register && echo "registration: OPEN (unexpected)" || echo "registration: closed"
