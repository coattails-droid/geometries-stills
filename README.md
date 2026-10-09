# geometries-stills

Weekday automation that renders preview stills for new **Touring**, **Seeded**, **Tidal** and **Luminous Geometries** mints and
prepares the Safe batch that sets them on-chain. Everything is a public chain read, so no secrets are needed. It
does **not** upload anything to Pinata and it never signs anything. You do those two steps yourself; the issue it
opens tells you how.

| Series | Contract (Ethereum mainnet) | Setter | "No still yet" means | Still | Image URI format |
|---|---|---|---|---|---|
| Touring Geometries | `0x68488544434fd5c5a23198E5Ca15a3B7e8F2702C` | `setTokenImage(uint256[],string[])` | `tokenImage(id) == ""` | frame 0 (t = 0 s), 1000×1000 | `ipfs://<CID>/<id>.png` |
| Seeded Geometries | `0xf8b604CC9108bAd6cC306B0a9F207CFb477562A7` | `setTokenImages(uint256[],string[])` | `tokenURI(id).image` is the on-chain SVG placeholder | loop rest frame (phase 0), 1000×1000 | `https://gateway.pinata.cloud/ipfs/<CID>/<id>.png` |
| Tidal Geometries | `0x9F4b042cD0D2B4B93a2b78bDa8862a2473A3485d` | `setTokenImages(uint256[],string[])` | same as Seeded | loop rest frame (phase 0), 1000×1000 | same as Seeded |
| Luminous Geometries | `0xbA6D94f07B0B0a092eB1AF763A5b721a274343e6` | `setTokenImage(uint256[],string[])` | `tokenImage(id) == ""` | frame 0 (t = 0 s), canvas is fixed at 900×900, Lanczos-resized to 1000×1000 | `ipfs://<CID>/<id>.png` |

All four contracts are owned by the Safe `0x851294C9bdb242Ea0448FBb9083Fd7757E4265E9`. Per-series settings live in
[`series.json`](series.json). Each series matches what is already on-chain for it: the same frame, size and URI
format. The Seeded and Tidal renders are pixel-identical to the stills already set for those tokens. Luminous #1 was set by hand
(`ipfs://bafybeiboay6fo376f22hugfw3i5iq5ne5vvxqpcyhg3pixx4bsr3pjyy6q/1.png`), so the job skips it; the job's render of #1 is
byte-identical to that file.

## Schedule

`.github/workflows/geometries-stills.yml` runs **Monday–Friday at 12:35 UTC**. That is 8:35 AM Eastern during
daylight time and 7:35 AM Eastern in winter. GitHub often starts scheduled runs a few minutes late, sometimes 15+
minutes at busy times.

Each run checks all four series in parallel. For each series it:

1. reads `totalSupply` and finds minted ids (1…totalSupply) that have no still yet;
2. if there are none, writes "nothing to do" in the run summary and stops. If an old issue for the series is still
   open, it closes that issue, because the stills are set now;
3. if an open issue already covers **exactly** the same ids, it skips rendering and leaves one reminder comment per day;
4. otherwise it renders each token's on-chain `animation_url` in headless Chrome, using a controlled clock so the
   frame is exact. It writes `<prefix>-stills-<first>-<last>/<id>.png`, zips the folder (the folder sits at the zip
   root), and computes the folder CID with kubo (`ipfs add -r --only-hash --cid-version=1`, which gives the same CID
   as a Pinata folder upload). It builds the Safe Transaction Builder JSON, **simulates it from the Safe**
   (`cast call --from <Safe>`; the job fails if it would revert), and makes a contact sheet;
5. commits the zip, Safe batch, contact sheet and `manifest.json` (ids, CID, per-file CIDs, date, Chrome/kubo
   versions) to `batches/<series>/YYYY-MM-DD-<first>-<last>/`, and uploads the same files as a workflow artifact;
6. opens an issue assigned to you, labelled `touring-stills` / `seeded-stills` / `tidal-stills` / `luminous-stills`, e.g.
   *"Touring stills ready: #3–#5"*. If an older open issue for that series covers a different set of ids, the old
   issue is closed with a note pointing to the new one. The new issue always covers the full current set.

GitHub sends you an email for each new issue and reminder comment, because you're the assignee and you watch your own repo.

## What to do when an issue arrives

The issue has the exact links and CID. In short:

1. Download the zip from the issue and extract it. You get a folder such as `touring-stills-3-5/`.
2. Upload that **folder** to [Pinata](https://app.pinata.cloud) (Files → Upload → Folder). Don't upload the zip.
3. **Check that the CID Pinata shows is exactly the one in the issue.** If it's different, don't sign. Comment on the issue instead.
4. Download the `.safe-batch.json` from the issue.
5. In the Safe go to **Apps → Transaction Builder** and drag the JSON in. Check that it shows 1 transaction to the
   right contract, then Create Batch → Send Batch.
6. Sign with the Trezor and execute.
7. Close the issue.

## Running it by hand

GitHub → **Actions** → **Geometries stills** → **Run workflow**. The inputs:

- **series**: `all` (default), `touring`, `seeded`, `tidal` or `luminous`.
- **force_ids**: for testing. Renders these ids (e.g. `1,2`) even if they already have a still.
- **dry_run**: only uploads the result as a workflow artifact (no commit, no issue). Use this with `force_ids` to
  check that rendering still works. Download the artifact from the run page.

From a terminal with `gh`:

```bash
gh workflow run geometries-stills.yml -R coattails-droid/geometries-stills                                   # normal run
gh workflow run geometries-stills.yml -R coattails-droid/geometries-stills -f force_ids=1,2 -f dry_run=true  # test render
```

A normal manual run (no force_ids, dry_run off) does exactly what the scheduled run does.

## Running it locally

Needs Node 20+, Google Chrome, Foundry (`cast`), kubo (`ipfs`, initialised), Python 3 with Pillow, and `jq`.

```bash
npm ci
./scripts/find_missing.sh touring           # which ids need a still (FORCE_IDS=1,2 to override)
./scripts/build.sh touring 1,2              # -> out/touring/YYYY-MM-DD-1-2/
```

## Files

- `series.json`: per-series contract, setter, missing-still check, URI prefix, folder prefix, label and capture settings.
- `scripts/find_missing.sh`: chain reads and missing-still detection.
- `scripts/build.sh`: render, zip, CID, batch, simulation, contact sheet and manifest.
- `scripts/capture.js`: headless Chrome capture with a controlled clock (`perfnow` mode for Touring/Luminous, `raf` mode for Seeded/Tidal).
- `scripts/gen_batch.js`: Safe Transaction Builder JSON (version 1.0, chainId 1, raw calldata, tx-builder checksum).
- `scripts/issues.sh`: issue dedupe, open, supersede, close and reminders.
- `batches/`: everything the workflow prepared, one folder per batch.

Rendering uses the runner's Google Chrome with `--disable-gpu` (software raster). Don't add
`--use-angle=swiftshader`: it changes 2D-canvas pixels compared with the stills already on-chain.
