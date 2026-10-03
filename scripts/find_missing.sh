#!/usr/bin/env bash
# find_missing.sh <series> — list minted token ids that have no still set on-chain.
#   touring: tokenImage(id) == ""                        (contract has a public tokenImage getter)
#   seeded/tidal: tokenURI(id).image is the on-chain SVG placeholder (data:image/svg+xml...) — _tokenImage is private
# FORCE_IDS="1,2" skips detection and uses those ids (must be minted). Outputs: ids, count, first, last, total_supply.
SERIES="${1:?series}"; source "$(dirname "$0")/lib.sh"
C=$(cfg .contract); CHECK=$(cfg .missing_check); NAME=$(cfg .name)
N=$(ccall "$C" 'totalSupply()(uint256)' | awk '{print $1}')
BLOCK=$(cast block-number -r "$RPC")
echo "$NAME $C totalSupply=$N (block $BLOCK)"
ids=()
if [[ -n "${FORCE_IDS:-}" ]]; then
  IFS=', ' read -r -a req <<< "$FORCE_IDS"
  for id in "${req[@]}"; do [[ -z "$id" ]] && continue
    [[ "$id" =~ ^[0-9]+$ && "$id" -ge 1 && "$id" -le "$N" ]] || { echo "::error::force id '$id' is not a minted $NAME token (1..$N)"; exit 1; }
    ids+=("$id"); done
  mapfile -t ids < <(printf '%s\n' "${ids[@]}" | sort -n | uniq)
  echo "FORCE_IDS given -> using ${ids[*]}"
else
  for id in $(seq 1 "$N"); do
    if [[ "$CHECK" == tokenImage-empty ]]; then
      img=$(ccall "$C" 'tokenImage(uint256)(string)' "$id"); [[ "$img" == '""' || -z "$img" ]] && ids+=("$id")
    else
      img=$(ccall "$C" 'tokenURI(uint256)(string)' "$id" | uri_field image)
      [[ "$img" == data:image/svg+xml* ]] && ids+=("$id")
    fi
  done
fi
csv=$(IFS=,; echo "${ids[*]:-}")
gh_out total_supply "$N"; gh_out block "$BLOCK"; gh_out ids "$csv"; gh_out count "${#ids[@]}"
if [[ ${#ids[@]} -gt 0 ]]; then gh_out first "${ids[0]}"; gh_out last "${ids[${#ids[@]}-1]}"; fi
if [[ ${#ids[@]} -eq 0 ]]; then summary "✅ $NAME: all $N minted tokens already have a still on-chain (block $BLOCK) — nothing to do."
else summary "🖼️ $NAME: ${#ids[@]} token(s) to render: #${csv//,/, #} (totalSupply $N, block $BLOCK)"; fi
