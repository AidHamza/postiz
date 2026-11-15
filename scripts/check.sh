#!/usr/bin/env bash
# Static checks (no secrets, no production access). Used locally and in CI.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0; bad() { echo "FAIL: $*"; fail=1; }

echo "==> compose renders with placeholder config"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf 'POSTIZ_PUBLIC_URL=https://social.example.test\nPOSTIZ_DB_PASSWORD=x\nPOSTIZ_REDIS_PASSWORD=x\nTEMPORAL_DB_PASSWORD=x\n' >"$tmp/infra.env"
: >"$tmp/app.env"
POSTIZ_SHARED_DIR="$tmp" scripts/compose.sh config -q
POSTIZ_SHARED_DIR="$tmp" scripts/compose.sh --profile admin --profile debug config -q
rendered="$(POSTIZ_SHARED_DIR="$tmp" scripts/compose.sh --profile admin --profile debug config --format json)"

echo "==> image pinning, ports, sockets, names"
python3 - "$rendered" <<'PY' || fail=1
import json, sys, re
c = json.loads(sys.argv[1]); bad = []
for name, s in c["services"].items():
    img = s.get("image", "")
    if not re.search(r":[\w.-]+@sha256:[0-9a-f]{64}$", img) or ":latest" in img:
        bad.append(f"{name}: image not pinned by tag+digest: {img}")
    if "container_name" in s:
        bad.append(f"{name}: global container_name")
    for p in s.get("ports", []):
        if p.get("host_ip") != "127.0.0.1":
            bad.append(f"{name}: publishes non-loopback port {p}")
        if "debug" not in (s.get("profiles") or []):
            bad.append(f"{name}: default service publishes a port")
    for v in s.get("volumes", []):
        if "docker.sock" in v.get("source", ""):
            bad.append(f"{name}: mounts docker socket")
    for k, v in (s.get("environment") or {}).items():
        if v in ("postiz-password", "temporal", "random string that is unique to every install - just type random characters here!") and "PASSWORD" in k:
            bad.append(f"{name}: default password in {k}")
edge = [n for n, s in c["services"].items() if "public-edge" in (s.get("networks") or {})]
if edge != ["postiz"]:
    bad.append(f"only postiz may join public-edge, got {edge}")
for n in ("postiz-data", "temporal"):
    if not c["networks"][n].get("internal"):
        bad.append(f"network {n} must be internal")
print("\n".join(bad) or "ok")
sys.exit(1 if bad else 0)
PY

echo "==> shell syntax"
for f in scripts/*.sh; do bash -n "$f" || bad "$f"; done
if command -v shellcheck >/dev/null; then shellcheck -S warning scripts/*.sh || bad shellcheck; fi

echo "==> no committed secrets/state"
if git ls-files | grep -E '(^|/)(\.env|app\.env|infra\.env|owner-login|backend\.hcl|terraform\.tfvars|.*\.tfstate.*|.*\.tfplan|inventory\.ini)$'; then bad "private file tracked"; fi

if command -v terraform >/dev/null; then
  echo "==> terraform fmt/validate"
  terraform -chdir=infra/terraform fmt -check -recursive || bad "terraform fmt"
  d="$(mktemp -d)"; cp infra/terraform/*.tf infra/terraform/.terraform.lock.hcl "$d"/ 2>/dev/null || cp infra/terraform/*.tf "$d"/
  rm -f "$d/backend.tf"
  (terraform -chdir="$d" init -backend=false -input=false >/dev/null && terraform -chdir="$d" validate) || bad "terraform validate"
  rm -rf "$d"
fi
if command -v ansible-playbook >/dev/null && ansible-playbook --version >/dev/null 2>&1; then
  echo "==> ansible syntax"
  printf '[postiz]\nlocalhost ansible_connection=local\n' >"$tmp/inv"
  (cd infra/ansible && ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i "$tmp/inv" --syntax-check deploy.yml) || bad "ansible syntax"
fi
[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || { echo "CHECKS FAILED"; exit 1; }
