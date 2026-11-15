#!/usr/bin/env bash
# Public checks through Cloudflare (real certificate validation, no -k).
set -euo pipefail
url="${POSTIZ_URL:-https://social.appsdoc.com}"
fail=0
ok() { echo "PASS: $*"; }
no() { echo "FAIL: $*"; fail=1; }
code() { curl -sS -o /dev/null -w '%{http_code}' --retry 3 --retry-all-errors --max-time 30 "$@"; }

c="$(code "$url/auth/login")"; [ "$c" = 200 ] && ok "login page 200" || no "login page $c"
c="$(code "http://${url#https://}/auth/login")"; [[ "$c" = 30[178] ]] && ok "http redirects to https ($c)" || no "http -> $c"
loc="$(curl -sS -o /dev/null -w '%{redirect_url}' --max-time 30 "$url/")"
[[ "$loc" == "$url/"* ]] && ok "/ redirects unauthenticated users to $loc" || no "/ redirect: '$loc'"
body="$(curl -sS --max-time 30 "$url/api/auth/can-register")"
[[ "$body" == *'"register":false'* ]] && ok "registration closed" || no "can-register: $body"
c="$(code "$url/api/user/self")"; [[ "$c" = 401 || "$c" = 403 ]] && ok "private API denied unauthenticated ($c)" || no "private API $c"
c="$(code "$url/api/posts?startDate=2026-01-01T00:00:00Z&endDate=2026-01-02T00:00:00Z")"; [[ "$c" = 401 || "$c" = 403 ]] && ok "posts API denied unauthenticated ($c)" || no "posts API $c"
# Only after confirming closed: an outsider's registration must be refused.
if [[ "$body" == *'"register":false'* ]]; then
  r="$(curl -sS -w ' %{http_code}' --max-time 30 -H 'content-type: application/json' \
    -d '{"email":"outsider-smoke@example.invalid","password":"not-a-real-pass-123","company":"Outsider","provider":"LOCAL"}' "$url/api/auth/register")"
  [[ "$r" == *"Registration is disabled"*" 400" ]] && ok "outsider registration refused" || no "outsider registration: $r"
fi
# Team login: Postiz generic OIDC -> Cloudflare Access (team@appsdoc.com only).
oidc="$(curl -sS --max-time 30 "$url/api/auth/oauth/GENERIC")"
if [[ "$oidc" == https://*.cloudflareaccess.com/cdn-cgi/access/sso/oidc/*redirect_uri=https%3A%2F%2F${url#https://}%2Fsettings* ]]; then
  ok "OIDC login link points at Cloudflare Access with the /settings callback"
  c="$(code "$oidc")"; [[ "$c" = 302 || "$c" = 200 ]] && ok "Access authorization endpoint responds ($c)" || no "Access authorization endpoint $c"
else no "OIDC link: ${oidc:0:120}"; fi
html="$(curl -sS --max-time 30 "$url/auth/login")"
asset="$(grep -oE '/_next/static/[^"]+\.js' <<<"$html" | head -1)"
[ -n "$asset" ] && c="$(code "$url$asset")" && [ "$c" = 200 ] && ok "static asset loads ($asset)" || no "static asset '$asset' ${c:-}"
issuer="$(echo | openssl s_client -connect "${url#https://}:443" -servername "${url#https://}" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null || true)"
echo "INFO: edge certificate $issuer"
[ "$fail" = 0 ] && echo "PUBLIC SMOKE PASSED" || { echo "PUBLIC SMOKE FAILED"; exit 1; }
