#!/usr/bin/env bash
# Fresh-install registration lock through the supported v2.26.0 flow
# (POST /auth/register, provider LOCAL), run inside the container before any
# public route exists. With DISABLE_REGISTRATION=true, LOCAL registration closes
# once one organisation exists. Login is Google Workspace (OIDC) only and the
# edge blocks password login, so the generated password is not kept.
# Only runs on an empty database; restored installations skip it.
set -euo pipefail
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
owner="${POSTIZ_OWNER_EMAIL:-hamza@appsdoc.com}"
company="${POSTIZ_OWNER_COMPANY:-AppsDoc}"
umask 077
if ! can_register; then
  log "bootstrap: an organisation already exists; registration is closed"
  exit 0
fi
if grep -q '^EMAIL_PROVIDER=' "$POSTIZ_SHARED_DIR/app.env"; then
  log "bootstrap: refusing while an email provider is set (owner would need activation)"; exit 1
fi
pass="$(openssl rand -base64 36 | tr -d '/+=' | cut -c1-32)"
body="$(python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"password":sys.argv[2],"company":sys.argv[3],"provider":"LOCAL"}))' "$owner" "$pass" "$company")"
res="$(printf '%s' "$body" | backend_call POST /auth/register)"
case "$res" in
  "200 "*'"register":true'*) log "bootstrap: organisation $company created (password discarded; sign in with Google Workspace)" ;;
  *) log "bootstrap: registration failed (status ${res%% *})"; exit 1 ;;
esac
if can_register; then log "bootstrap: registration still open after bootstrap"; exit 1; fi
log "bootstrap: registration closed"
