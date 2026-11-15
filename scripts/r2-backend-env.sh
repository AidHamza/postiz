# shellcheck shell=bash
# Source this file: `source scripts/r2-backend-env.sh`
# Derives R2 S3 credentials for the Terraform backend from CLOUDFLARE_API_TOKEN
# (access key = token ID, secret = SHA-256 of the token). Prints no secrets.
# The token needs Account > Workers R2 Storage: Edit (or Read+Write on the bucket).
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  echo "CLOUDFLARE_API_TOKEN is not set" >&2
  return 1 2>/dev/null || exit 1
fi
_cf_account="${CLOUDFLARE_ACCOUNT_ID:?set CLOUDFLARE_ACCOUNT_ID}"
AWS_ACCESS_KEY_ID=$(curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$_cf_account/tokens/verify" |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["id"])') || {
  echo "Could not verify CLOUDFLARE_API_TOKEN" >&2
  return 1 2>/dev/null || exit 1
}
AWS_SECRET_ACCESS_KEY=$(printf '%s' "$CLOUDFLARE_API_TOKEN" | sha256sum | cut -d' ' -f1)
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
unset _cf_account
echo "R2 backend credentials exported (not displayed)."
