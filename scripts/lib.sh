# lib.sh — shared helpers (sourced). Needs: cast (Foundry), jq, python3.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RPC="${RPC_URL:-https://ethereum-rpc.publicnode.com}"
SAFE=0x851294C9bdb242Ea0448FBb9083Fd7757E4265E9
cfg() { jq -er --arg s "$SERIES" ".[\$s]$1" "$ROOT/series.json"; }
# cast call with retries (public RPCs occasionally rate-limit or time out)
ccall() { local i out; for i in 1 2 3 4 5; do if out=$(cast call "$@" -r "$RPC" 2>/tmp/ccall.err); then printf '%s\n' "$out"; return 0; fi
  if grep -qiE 'revert' /tmp/ccall.err; then cat /tmp/ccall.err >&2; return 1; fi; sleep $((i * 3)); done; cat /tmp/ccall.err >&2; return 1; }
gh_out() { if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "$1=$2" >> "$GITHUB_OUTPUT"; fi; echo "  $1=$2"; }
summary() { echo "$1"; if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then echo "$1" >> "$GITHUB_STEP_SUMMARY"; fi; }
# decode a tokenURI (data:application/json;base64,...) -> field
uri_field() { python3 -c '
import json,base64,sys
s=sys.stdin.read().strip(); s=json.loads(s) if s.startswith("\"") else s
j=json.loads(base64.b64decode(s.split(",",1)[1])); print(j[sys.argv[1]])' "$1"; }
