#!/usr/bin/env bash
# First-owner bootstrap through the supported v2.26.0 flow (POST /auth/register,
# provider LOCAL). Runs against the backend inside the container while no public
# route exists. With DISABLE_REGISTRATION=true, registration closes as soon as
# one organisation exists. Credentials go to $POSTIZ_SHARED_DIR/owner-login (0600).
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
owner="${POSTIZ_OWNER_EMAIL:-hamza@appsdoc.com}"
company="${POSTIZ_OWNER_COMPANY:-AppsDoc}"
cred="$POSTIZ_SHARED_DIR/owner-login"
umask 077
if ! can_register; then
  log "bootstrap: an organisation already exists; registration is closed"
  exit 0
fi
if grep -q '^EMAIL_PROVIDER=' "$POSTIZ_SHARED_DIR/app.env"; then
  log "bootstrap: refusing while an email provider is set (owner would need activation)"; exit 1
fi
pass="$(openssl rand -base64 36 | tr -d '/+=' | cut -c1-32)"
printf 'POSTIZ_URL=%s\nEMAIL=%s\nPASSWORD=%s\n' "$(grep '^POSTIZ_PUBLIC_URL=' "$POSTIZ_SHARED_DIR/infra.env" | cut -d= -f2-)" "$owner" "$pass" >"$cred"
chmod 600 "$cred"
body="$(python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"password":sys.argv[2],"company":sys.argv[3],"provider":"LOCAL"}))' "$owner" "$pass" "$company")"
res="$(printf '%s' "$body" | backend_call POST /auth/register)"
case "$res" in
  "200 "*'"register":true'*) log "bootstrap: owner $owner and organisation $company created" ;;
  *) log "bootstrap: registration failed (status ${res%% *})"; rm -f "$cred"; exit 1 ;;
esac
if can_register; then log "bootstrap: registration still open after bootstrap"; exit 1; fi
log "bootstrap: registration closed"
