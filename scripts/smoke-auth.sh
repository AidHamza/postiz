#!/usr/bin/env bash
# Authenticated checks on the server using the owner credentials (never printed):
# login over the public URL, session use, harmless media upload + public fetch,
# Temporal worker pollers. Creates one small PNG in the media library.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
cred="$POSTIZ_SHARED_DIR/owner-login"
url="$(grep '^POSTIZ_URL=' "$cred" | cut -d= -f2-)"
email="$(grep '^EMAIL=' "$cred" | cut -d= -f2-)"
umask 077
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
jar="$work/jar"; fail=0
ok() { echo "PASS: $*"; }; no() { echo "FAIL: $*"; fail=1; }
python3 - "$cred" >"$work/login.json" <<'PY'
import json, sys
kv = dict(l.rstrip("\n").split("=", 1) for l in open(sys.argv[1]) if "=" in l)
print(json.dumps({"email": kv["EMAIL"], "password": kv["PASSWORD"], "provider": "LOCAL"}))
PY
c="$(curl -sS --max-time 60 -o /dev/null -w '%{http_code}' -c "$jar" -H 'content-type: application/json' --data @"$work/login.json" "$url/api/auth/login")"
[ "$c" = 200 ] && grep -q $'\tauth\t' "$jar" && ok "owner login ($email) sets secure auth cookie" || no "owner login $c"
grep -qE 'TRUE.*auth' "$jar" && ok "auth cookie is Secure" || no "auth cookie not Secure"
self="$(curl -sS --max-time 60 -b "$jar" "$url/api/user/self")"
[[ "$self" == *"\"email\":\"$email\""* ]] && ok "session resolves to owner" || no "user/self: ${self:0:80}"
orgs="$(curl -sS --max-time 60 -b "$jar" "$url/api/user/organizations")"
[[ "$orgs" == *AppsDoc* ]] && ok "owner organisation AppsDoc present" || no "organizations: ${orgs:0:80}"
python3 -c 'import base64,sys;sys.stdout.buffer.write(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="))' >"$work/smoke.png"
up="$(curl -sS --max-time 60 -b "$jar" -F "file=@$work/smoke.png;type=image/png" "$url/api/media/upload-simple")"
path="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d.get("path",""))' "$up" 2>/dev/null || true)"
if [ -n "$path" ]; then
  [[ "$path" != http* ]] && path="$url$path"
  c="$(curl -sS --max-time 60 -o "$work/fetched" -w '%{http_code} %{content_type}' "$path")"
  cmp -s "$work/smoke.png" "$work/fetched" && ok "media upload publicly retrievable ($c)" || no "media fetch $c"
else no "upload: ${up:0:120}"; fi
pollers="$(timeout 60 "$here/compose.sh" exec -T temporal temporal task-queue describe --task-queue main --address temporal:7233 -o json </dev/null 2>/dev/null | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("pollers") or []))' 2>/dev/null || echo 0)"
[ "${pollers:-0}" -gt 0 ] && ok "Temporal task queue 'main' has $pollers worker poller(s)" || no "no Temporal pollers on 'main'"
[ "$fail" = 0 ] && echo "AUTH SMOKE PASSED" || { echo "AUTH SMOKE FAILED"; exit 1; }
