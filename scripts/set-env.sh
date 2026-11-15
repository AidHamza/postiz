#!/usr/bin/env bash
# Upsert KEY=VALUE pairs from a JSON object on stdin into a private env file.
# Values are single-quoted (literal for Compose). Prints key names only.
# Usage: terraform output -json postiz_oidc_env | ssh host bash scripts/set-env.sh /opt/appsdoc/postiz/shared/app.env
set -euo pipefail
dst="${1:?env file}"
umask 077
# Program passed with -c so that stdin stays the JSON input.
prog=$(cat <<'PY'
import json, os, sys, tempfile
dst = sys.argv[1]
new = json.load(sys.stdin)
lines = open(dst).read().splitlines() if os.path.exists(dst) else []
out, seen = [], set()
for v in new.values():
    if "\n" in str(v) or "'" in str(v):
        sys.exit("set-env: refusing value with newline or single quote")
for line in lines:
    k = line.split("=", 1)[0]
    if k in new:
        out.append(f"{k}='{new[k]}'"); seen.add(k)
    else:
        out.append(line)
out += [f"{k}='{v}'" for k, v in new.items() if k not in seen]
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(dst))
with os.fdopen(fd, "w") as f:
    f.write("\n".join(out) + "\n")
os.chmod(tmp, 0o600); os.replace(tmp, dst)
print("set-env: updated " + ", ".join(sorted(new)))
PY
)
python3 -c "$prog" "$dst"
