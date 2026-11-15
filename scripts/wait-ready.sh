#!/usr/bin/env bash
# Readiness beyond container health: backend API, orchestrator->Temporal, worker poller.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
for i in $(seq 1 60); do
  if backend_call GET /auth/can-register </dev/null 2>/dev/null | grep -q '^200 '; then break; fi
  [ "$i" = 60 ] && { log "backend did not become ready"; exit 1; }
  sleep 5
done
log "backend API ready"
for i in $(seq 1 60); do
  if dc exec -T postiz node -e 'fetch("http://localhost:3002/health/status").then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))' 2>/dev/null; then break; fi
  [ "$i" = 60 ] && { log "orchestrator Temporal health failed"; exit 1; }
  sleep 5
done
log "orchestrator connected to Temporal namespace default"
