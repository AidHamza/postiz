#!/usr/bin/env bash
# Create the private runtime configuration once. Never rotates existing values:
# missing keys are appended, present keys are left untouched.
# Usage: scripts/configure.sh <shared-dir> [public-url]
set -euo pipefail
shared="${1:?shared dir required}"
url="${2:-https://social.appsdoc.com}"
umask 077
mkdir -p "$shared"
chmod 700 "$shared"
hex() { openssl rand -hex 32; }

ensure() { # file key value-command...
  local file="$1" key="$2"; shift 2
  touch "$file"; chmod 600 "$file"
  if ! grep -q "^${key}=" "$file"; then
    printf '%s=%s\n' "$key" "$("$@")" >>"$file"
    echo "configure: generated ${key} in $(basename "$file")"
  fi
}
literal() { printf '%s' "$1"; }

infra="$shared/infra.env"
ensure "$infra" POSTIZ_PUBLIC_URL literal "$url"
ensure "$infra" POSTIZ_DB_PASSWORD hex
ensure "$infra" POSTIZ_REDIS_PASSWORD hex
ensure "$infra" TEMPORAL_DB_PASSWORD hex

app="$shared/app.env"
ensure "$app" JWT_SECRET hex
# v2.26.0 token encryption (libraries/nestjs-libraries/src/encryption/local.provider.ts):
# 32 random bytes, base64. Generated once; must never change after first use.
ensure "$app" ENCRYPTION_PROVIDER literal local
ensure "$app" ENCRYPTION_KEY sh -c 'openssl rand -base64 32'
ensure "$app" API_LIMIT literal 300
