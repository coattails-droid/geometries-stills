#!/usr/bin/env bash
# build.sh <series> <ids 3,4,5> — render stills for exactly those ids, zip (folder at zip root), folder CID,
# Safe batch JSON, simulate it from the Safe (fails on revert), contact sheet, manifest.
# Output: out/<series>/<YYYY-MM-DD>-<first>-<last>/ ; outputs: dir, cid, folder, zip, batch, contact, manifest.
SERIES="${1:?series}"; IDS="${2:?ids}"; source "$(dirname "$0")/lib.sh"
C=$(cfg .contract); NAME=$(cfg .name); SIG=$(cfg .setter); PREFIX=$(cfg .uri_prefix); FP=$(cfg .folder_prefix)
MODE=$(cfg .capture.mode); CID_=$(cfg .capture.canvas_id); TMS=$(cfg .capture.time_ms); SIZE=$(cfg .capture.size); NOTE=$(cfg .still_note)
OSIZE=$(jq -r --arg s "$SERIES" '.[$s].output_size // ""' "$ROOT/series.json")  # optional resize after capture
IFS=, read -r -a ids <<< "$IDS"; FIRST=${ids[0]}; LAST=${ids[${#ids[@]}-1]}
DATE=$(TZ=America/New_York date +%F)
FOLDER="$FP-$FIRST-$LAST"; OUT="$ROOT/out/$SERIES/$DATE-$FIRST-$LAST"; WORK="$ROOT/out/$SERIES/work"
rm -rf "$OUT" "$WORK"; mkdir -p "$OUT" "$WORK/html" "$WORK/raw" "$WORK/$FOLDER"
for id in "${ids[@]}"; do
  ccall "$C" 'tokenURI(uint256)(string)' "$id" > "$WORK/uri-$id.txt"
  python3 - "$WORK/uri-$id.txt" "$WORK/html/$id.html" <<'PY'
import json,base64,sys
s=open(sys.argv[1]).read().strip(); s=json.loads(s) if s.startswith('"') else s
j=json.loads(base64.b64decode(s.split(',',1)[1])); au=j['animation_url']
assert au.startswith('data:text/html;base64,'), au[:40]
open(sys.argv[2],'wb').write(base64.b64decode(au.split(',',1)[1]))
PY
  node "$ROOT/scripts/capture.js" "$WORK/html/$id.html" "$WORK/raw/$id.png" "$MODE" "$CID_" "$TMS" "$SIZE" | tee "$WORK/capture-$id.json"
  python3 "$ROOT/scripts/flatten.py" "$WORK/raw/$id.png" "$WORK/$FOLDER/$id.png" "$OSIZE"
done
# fail if a still is (near-)blank — means the renderer didn't draw
python3 - "$WORK/$FOLDER" <<'PY'
import sys,os
from PIL import Image, ImageStat
for f in sorted(os.listdir(sys.argv[1])):
    st = ImageStat.Stat(Image.open(os.path.join(sys.argv[1], f)).convert('L'))
    print(f, 'mean %.2f stddev %.2f' % (st.mean[0], st.stddev[0]))
    if st.stddev[0] < 2: sys.exit(f'::error::{f} looks blank (stddev {st.stddev[0]:.2f})')
PY
ZIP="$OUT/$FOLDER.zip"; python3 "$ROOT/scripts/mkzip.py" "$WORK/$FOLDER" "$ZIP"
( cd "$WORK" && ipfs add -r --progress=false --only-hash --cid-version=1 "$FOLDER" ) | awk '{print $3"\t"$2}' \
  | sed "s#^$FOLDER/##; s#^$FOLDER\t#<root>\t#" > "$OUT/cids.txt"
CID=$(awk '$1=="<root>"{print $2}' "$OUT/cids.txt"); [[ "$CID" =~ ^baf ]] || { echo "::error::no folder CID"; exit 1; }
FN=${SIG%%(*}; BATCH="$OUT/$SERIES-$FN-$FIRST-$LAST.safe-batch.json"
node "$ROOT/scripts/gen_batch.js" "$C" "$SIG" "$PREFIX" "$CID" "$IDS" "$BATCH" "$NAME stills #$FIRST-$LAST" > "$WORK/batch.json"
DATA=$(jq -r .data "$WORK/batch.json")
echo "Simulating $FN from the Safe $SAFE ..."
if ! SIM=$(ccall "$C" "$DATA" --from "$SAFE"); then echo "::error::Safe batch simulation REVERTED"; exit 1; fi
echo "simulation ok (returned $SIM)"
# sanity: a non-owner must be rejected (proves the simulation really exercised the owner check)
if cast call "$C" "$DATA" --from 0x000000000000000000000000000000000000dEaD -r "$RPC" >/dev/null 2>&1; then echo "::warning::non-owner call did not revert?"; fi
CONTACT="$OUT/contact-sheet.png"; python3 "$ROOT/scripts/contact.py" "$WORK/$FOLDER" "$CONTACT" "$NAME" "$NOTE"
jq -n --arg series "$SERIES" --arg name "$NAME" --arg contract "$C" --arg setter "$SIG" --arg date "$DATE" \
  --arg created "$(date -u +%FT%TZ)" --arg cid "$CID" --arg folder "$FOLDER" --arg prefix "$PREFIX" --arg ids "$IDS" \
  --arg block "${BLOCK:-}" --arg run "${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}" \
  --arg chrome "$("${CHROME_PATH:-/usr/bin/google-chrome}" --version)" --arg kubo "$(ipfs version -n)" --arg note "$NOTE" \
  --rawfile cids "$OUT/cids.txt" '{series:$series, name:$name, contract:$contract, setter:$setter, safe:"'"$SAFE"'",
   ids:($ids|split(",")|map(tonumber)), folder:$folder, folder_cid:$cid,
   uri_example:($prefix+$cid+"/"+($ids|split(",")[0])+".png"), file_cids:($cids|split("\n")|map(select(length>0)|split("\t")|{(.[0]):.[1]})|add),
   date:$date, created_utc:$created, block:$block, still:$note, chrome:$chrome, kubo:$kubo, run:$run}' > "$OUT/manifest.json"
rm "$OUT/cids.txt"; cat "$OUT/manifest.json"
gh_out dir "$OUT"; gh_out cid "$CID"; gh_out folder "$FOLDER"; gh_out zip "$ZIP"; gh_out batch "$BATCH"; gh_out contact "$CONTACT"
gh_out manifest "$OUT/manifest.json"; gh_out first "$FIRST"; gh_out last "$LAST"; gh_out date "$DATE"
summary "   → folder \`$FOLDER\`, CID \`$CID\`, Safe simulation passed."
