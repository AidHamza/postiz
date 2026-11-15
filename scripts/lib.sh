# shellcheck shell=bash
# Shared helpers. Source from scripts/*.sh.
POSTIZ_ROOT="${POSTIZ_ROOT:-/opt/appsdoc/postiz}"
export POSTIZ_SHARED_DIR="${POSTIZ_SHARED_DIR:-$POSTIZ_ROOT/shared}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dc() { "$here/compose.sh" "$@"; }
log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
# Call the Postiz backend from inside the container (no public route needed).
# Usage: backend_call METHOD PATH [json-body-on-stdin]  -> prints "status body"
backend_call() {
  dc exec -T postiz node -e '
    const [m,p]=process.argv.slice(1); let b="";
    process.stdin.on("data",d=>b+=d).on("end",async()=>{
      const r=await fetch("http://localhost:3000"+p,{method:m,headers:{"content-type":"application/json"},body:m==="GET"?undefined:b});
      const t=await r.text(); console.log(r.status+" "+t.slice(0,200));
    });' "$1" "$2"
}
can_register() { backend_call GET /auth/can-register </dev/null | grep -q '"register":true'; }
