// gen_batch.js — build a Safe Transaction Builder batch JSON that sets token stills.
// Usage: node scripts/gen_batch.js <contract> <setterSig> <uriPrefix> <folderCID> <ids 3,4,5> <out.json> <batch name>
//   setterSig e.g. "setTokenImage(uint256[],string[])" (Touring) or "setTokenImages(uint256[],string[])" (Seeded/Tidal)
//   URI per token: <uriPrefix><folderCID>/<id>.png
// Tx is raw calldata (to/value/data, contractMethod/contractInputsValues null), exactly as Tx Builder exports
// custom-data txs; meta.checksum per safe-react-apps tx-builder lib/checksum.ts. Needs `cast` (Foundry) on PATH.
const { execFileSync } = require('child_process'); const fs = require('fs');
const SAFE = '0x851294C9bdb242Ea0448FBb9083Fd7757E4265E9';
const [,, contract, sig, prefix, cid, idSpec, out, name] = process.argv;
if (!/^0x[0-9a-fA-F]{40}$/.test(contract || '') || !/^set\w+\(uint256\[\],string\[\]\)$/.test(sig || '') ||
    !/^(ipfs:\/\/|https:\/\/)/.test(prefix || '') || !/^baf[a-z2-7]{50,}$/.test(cid || '') || !/^\d+(,\d+)*$/.test(idSpec || '') || !out) {
  console.error('usage: node gen_batch.js <contract> <setterSig> <uriPrefix> <folderCID> <ids 1,2,3> <out.json> [name]'); process.exit(2);
}
const ids = idSpec.split(',').map(Number);
const uris = ids.map(id => `${prefix}${cid}/${id}.png`);
// mirror the contract's _checkURI so the Safe tx can't revert on a bad URI
for (const u of uris) if (u.length > 2048 || /["\\\x00-\x1f]/.test(u) || !(u.startsWith('https://') || u.startsWith('ipfs://'))) throw new Error('URI fails _checkURI: ' + u);
const data = execFileSync('cast', ['calldata', sig, `[${ids.join(',')}]`, `[${uris.join(',')}]`], { encoding: 'utf8' }).trim();
const dec = execFileSync('cast', ['decode-calldata', sig, data], { encoding: 'utf8' });   // round-trip check
for (const u of uris) if (!dec.includes(u)) throw new Error('decode mismatch ' + u);
const serialize = (j) => Array.isArray(j) ? `[${j.map(serialize).join(',')}]`
  : (typeof j === 'object' && j !== null) ? (() => { const k = Object.keys(j).sort(); let a = `{${JSON.stringify(k)}`; for (const x of k) a += `${serialize(j[x])},`; return a + '}'; })()
  : JSON.stringify(j === undefined ? null : j);
const fn = sig.split('(')[0];
const batch = {
  version: '1.0', chainId: '1', createdAt: Date.now(),
  meta: { name: name || `${fn} ${idSpec}`, description: `${fn} for tokens ${ids.join(',')} -> ${prefix}${cid}/<id>.png`,
          txBuilderVersion: '1.18.0', createdFromSafeAddress: SAFE, createdFromOwnerAddress: '' },
  transactions: [{ to: contract, value: '0', data, contractMethod: null, contractInputsValues: null }],
};
const ser = serialize({ ...batch, meta: { ...batch.meta, name: null } });
batch.meta.checksum = execFileSync('cast', ['keccak', ser], { encoding: 'utf8' }).trim();
fs.writeFileSync(out, JSON.stringify(batch, null, 2) + '\n');
console.log(JSON.stringify({ out, tokens: ids.length, selector: data.slice(0, 10), calldataBytes: (data.length - 2) / 2, checksum: batch.meta.checksum, data }));
