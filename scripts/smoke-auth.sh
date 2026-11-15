#!/usr/bin/env bash
# Server-side checks: Temporal worker pollers, owner OIDC account present,
# registration closed. Interactive Google Workspace login cannot be scripted;
# check it in a browser (docs/OPERATIONS.md).
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
fail=0
ok() { echo "PASS: $*"; }; no() { echo "FAIL: $*"; fail=1; }
pollers="$(timeout 60 "$here/compose.sh" exec -T temporal temporal task-queue describe --task-queue main --address temporal:7233 -o json </dev/null 2>/dev/null | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("pollers") or []))' 2>/dev/null || echo 0)"
[ "${pollers:-0}" -gt 0 ] && ok "Temporal task queue 'main' has $pollers worker poller(s)" || no "no Temporal pollers on 'main'"
counts="$(dc exec -T postiz-postgres psql -U postiz -d postiz -tAc "select count(*) filter (where \"providerName\"::text='GENERIC' and \"deletedAt\" is null), count(*) filter (where \"providerName\"::text='LOCAL' and \"deletedAt\" is null) from \"User\"" </dev/null)"
[[ "${counts%%|*}" -ge 1 ]] && ok "Google Workspace (OIDC) users: ${counts%%|*}" || no "no active OIDC user"
[ "${counts##*|}" = 0 ] && ok "no active password users" || no "active password users: ${counts##*|}"
can_register && no "LOCAL registration open" || ok "LOCAL registration closed"
[ "$fail" = 0 ] && echo "SERVER SMOKE PASSED" || { echo "SERVER SMOKE FAILED"; exit 1; }
