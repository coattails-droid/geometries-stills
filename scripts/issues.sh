#!/usr/bin/env bash
# issues.sh — GitHub issue handling (uses `gh` with GH_TOKEN = the workflow's GITHUB_TOKEN).
#   issues.sh check <series> <ids-csv>
#       ids empty            -> close any open issue for the series ("all set"), action=none
#       open issue, same ids -> leave a reminder comment at most once per day, action=skip
#       otherwise            -> action=build (old open issues are closed later, by `open`)
#   issues.sh open <series> <ids-csv> <cid> <folder> <batch-dir-in-repo> <commit-sha> <zip> <batch> <block> <supply>
#       opens the new issue (assigned to $ASSIGNEE), then closes older open issues for the series as superseded.
SERIES="${2:?series}"; source "$(dirname "$0")/lib.sh"
NAME=$(cfg .name); LABEL=$(cfg .label); C=$(cfg .contract)
REPO="${GITHUB_REPOSITORY:?}"; ASSIGNEE="${ASSIGNEE:-coattails-droid}"; TODAY=$(TZ=America/New_York date +%F)
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/$REPO/actions/runs/${GITHUB_RUN_ID:-0}"
MARK_RE='geometries-stills:series=([a-z]+);ids=([0-9,]+)'
gh label create "$LABEL" --repo "$REPO" --color 5319e7 --description "$NAME stills waiting for upload + Safe signature" --force >/dev/null
open_issues() {  # number<TAB>ids for open issues of this series
  gh issue list --repo "$REPO" --label "$LABEL" --state open --limit 50 --json number,body \
  | jq -r --arg s "$SERIES" '.[] | (.body | capture("geometries-stills:series=(?<s>[a-z]+);ids=(?<ids>[0-9,]+)")? ) as $m
      | select($m != null and $m.s == $s) | "\(.number)\t\($m.ids)"'
}
hashes() { local IFS=,; for i in $1; do printf '#%s, ' "$i"; done | sed 's/, $//'; }
title_ids() { local a; IFS=, read -r -a a <<< "$1"; if [[ ${#a[@]} -eq 1 ]]; then echo "#${a[0]}"; else echo "#${a[0]}–#${a[${#a[@]}-1]}"; fi; }

case "${1:?check|open}" in
check)
  IDS="${3:-}"; action=build; LIST=$(open_issues)
  while IFS=$'\t' read -r num oids; do [[ -z "$num" ]] && continue
    if [[ -z "$IDS" ]]; then
      gh issue comment "$num" --repo "$REPO" --body "All minted $NAME tokens now have a still on-chain (checked by [this run]($RUN_URL)), so this is done. Closing automatically. 🎉"
      gh issue close "$num" --repo "$REPO" --reason completed; summary "Closed #$num (all $NAME tokens have stills now)."
    elif [[ "$oids" == "$IDS" ]]; then
      action=skip
      if gh api "repos/$REPO/issues/$num/comments?per_page=100" --jq '.[].body' | grep -q "reminder:$TODAY"; then
        summary "Open issue #$num already covers $(hashes "$IDS"); already reminded today, skipping."
      else
        gh issue comment "$num" --repo "$REPO" --body "<!-- reminder:$TODAY -->
Reminder: $(hashes "$IDS") still show the placeholder on-chain, so this batch is still waiting. Nothing changed, so the zip, CID and Safe batch above are still the right ones. ([run]($RUN_URL))"
        summary "Open issue #$num already covers $(hashes "$IDS"); left today's reminder comment, skipping the render."
      fi
    fi
  done <<< "$LIST"
  [[ -z "$IDS" ]] && action=none
  gh_out action "$action" ;;
open)
  IDS="$3"; CID="$4"; FOLDER="$5"; DIR="$6"; SHA="$7"; ZIPF="$8"; BATCHF="$9"; BLOCK="${10:-}"; SUPPLY="${11:-}"
  B="https://github.com/$REPO/blob/$SHA/$DIR"; RAW="https://github.com/$REPO/raw/$SHA/$DIR"
  NOTE=$(cfg .still_note); PREFIX=$(cfg .uri_prefix); FIRST=${IDS%%,*}; FILES=$(IFS=,; for i in $IDS; do printf '%s.png, ' "$i"; done | sed 's/, $//')
  TB="https://app.safe.global/apps/open?safe=eth:$SAFE&appUrl=https%3A%2F%2Fapps-portal.safe.global%2Ftx-builder"
  N=$(tr ',' '\n' <<< "$IDS" | wc -l | tr -d ' ')
  TITLE="${NAME%% *} stills ready: $(title_ids "$IDS")"
  BODY=$(cat <<MD
<!-- geometries-stills:series=$SERIES;ids=$IDS;cid=$CID -->
**$N new $NAME token(s) need a preview still:** $(hashes "$IDS")

Right now these tokens show the plain placeholder image on marketplaces. This automation already rendered the stills from each token's own on-chain artwork ($NOTE) and prepared the Safe transaction. Your part is to upload and sign.

| | |
|---|---|
| **Expected folder CID** | \`$CID\` |
| Folder inside the zip | \`$FOLDER\` (contains $FILES) |
| 1️⃣ Stills zip | [⬇️ $(basename "$ZIPF")]($RAW/$(basename "$ZIPF")) |
| 2️⃣ Safe batch | [⬇️ $(basename "$BATCHF")]($RAW/$(basename "$BATCHF")) ([view]($B/$(basename "$BATCHF"))) |
| Manifest | [manifest.json]($B/manifest.json) |
| Contract | [\`$C\`](https://etherscan.io/address/$C) — owner Safe \`$SAFE\` |
| Checked at | block $BLOCK (totalSupply $SUPPLY), [workflow run]($RUN_URL) |

The image URIs that will be written look like \`$PREFIX$CID/$FIRST.png\`.

![Contact sheet of the new stills]($B/contact-sheet.png?raw=true)

### What to do (about 10 minutes)

1. **Download and extract the zip.** Click the zip link above (it downloads right away). Double-click it to extract. You get a folder named \`$FOLDER\` with $FILES inside. Don't rename the folder or the files.
2. **Upload the folder to Pinata.** Go to [app.pinata.cloud](https://app.pinata.cloud) → **Files** → **Add** / **Upload** → **Folder**, and pick the \`$FOLDER\` folder itself. Don't upload the zip, and don't upload the PNGs one at a time.
3. **Check that the CID matches before you sign. This step matters most.** Pinata shows a CID for the folder you uploaded. It has to be exactly
   \`$CID\`
   Check every character. The easiest way is to paste it into your browser's find box (Ctrl/Cmd+F) on this page. **If it is different, stop: don't sign.** Leave a comment here instead, because the batch points at this exact CID and a different one would leave the tokens with broken images.
4. **Download the Safe batch.** Click the Safe batch link above. If your browser just shows text, use right-click → *Save Link As…* and keep the \`.json\` name.
5. **Load it in the Safe.** Open [Safe → Apps → Transaction Builder]($TB) for the Safe \`$SAFE\` (Ethereum). Drag the \`.json\` file onto the *"Drag and drop a JSON file"* box. You should see **1 transaction** to \`$C\` ($NAME). Click **Create Batch**, then **Send Batch**.
6. **Sign with the Trezor.** Connect the Trezor, check the transaction in the Safe screen (the Safe's simulation should succeed), and confirm on the device. Then **Execute** the transaction (once the Safe has enough signatures) and pay the gas.
7. **Close this issue** once the transaction has gone through. The next weekday run checks the chain, and if these tokens still show the placeholder it opens a new issue.

<sub>Opened by the geometries-stills workflow. If more $NAME tokens are minted before you sign, this issue is closed and replaced by one covering the full set. Use only the newest issue.</sub>
MD
)
  OLD=$(open_issues | cut -f1)
  URL=$(gh issue create --repo "$REPO" --title "$TITLE" --label "$LABEL" --assignee "$ASSIGNEE" --body "$BODY")
  NEW=${URL##*/}; gh_out issue_url "$URL"; summary "Opened $URL"
  for num in $OLD; do [[ "$num" == "$NEW" ]] && continue
    gh issue comment "$num" --repo "$REPO" --body "The set of $NAME tokens without a still has changed, so this batch is out of date. **Don't sign this one.** It's replaced by #$NEW, which covers the full current set ($(hashes "$IDS")) with a new zip and CID. If you already uploaded this folder to Pinata, you can delete it there."
    gh issue close "$num" --repo "$REPO" --reason "not planned"; summary "Closed superseded #$num → #$NEW"
  done ;;
*) echo "usage: issues.sh check|open ..."; exit 2 ;;
esac
