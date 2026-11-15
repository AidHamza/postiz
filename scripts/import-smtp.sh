#!/usr/bin/env bash
# Map an existing SMTP configuration (OpenPanel's SMTP_*/EMAIL_SENDER names) to
# Postiz v2.26.0 names (EMAIL_PROVIDER=nodemailer, EMAIL_HOST/PORT/SECURE/USER/PASS,
# EMAIL_FROM_ADDRESS/NAME). No-op when app.env already sets EMAIL_PROVIDER.
# Prints no values. Usage: scripts/import-smtp.sh <source.env> <app.env>
set -euo pipefail
src="${1:?source env}"; dst="${2:?app.env}"
umask 077
[ -r "$src" ] || { echo "import-smtp: source not readable, skipping"; exit 0; }
grep -q '^EMAIL_PROVIDER=' "$dst" && { echo "import-smtp: EMAIL_PROVIDER already set, skipping"; exit 0; }
python3 - "$src" "$dst" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
vals = {}
for line in open(src):
    line = line.rstrip("\n")
    if "=" in line and not line.lstrip().startswith("#"):
        k, v = line.split("=", 1)
        vals[k.strip()] = v.strip().strip('"').strip("'")
need = ["SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS", "EMAIL_SENDER"]
if not all(vals.get(k) for k in need):
    print("import-smtp: source lacks complete SMTP settings, skipping")
    sys.exit(0)
sender = vals["EMAIL_SENDER"]
m = re.match(r"^\s*(.*?)\s*<([^>]+)>\s*$", sender)
name, addr = (m.group(1) or "AppsDoc Social", m.group(2)) if m else ("AppsDoc Social", sender)
secure = vals.get("SMTP_SECURE", "").lower() in ("true", "1", "yes")
out = {
    "EMAIL_PROVIDER": "nodemailer",
    "EMAIL_HOST": vals["SMTP_HOST"],
    "EMAIL_PORT": vals["SMTP_PORT"],
    "EMAIL_SECURE": "true" if secure else "false",
    "EMAIL_USER": vals["SMTP_USER"],
    "EMAIL_PASS": vals["SMTP_PASS"],
    "EMAIL_FROM_ADDRESS": addr,
    "EMAIL_FROM_NAME": "AppsDoc Social",
}
for v in out.values():
    if "\n" in v or "'" in v:
        sys.exit("import-smtp: refusing value with newline or single quote")
with open(dst, "a") as f:
    for k, v in out.items():
        # Single quotes: Compose env files then take the value literally.
        f.write(f"{k}='{v}'\n")
print("import-smtp: mapped SMTP settings into app.env (values not shown)")
PY
