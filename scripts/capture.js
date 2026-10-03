// capture.js — render a token's ON-CHAIN animation_url HTML headless and grab its canvas at an exact loop time.
// Usage: node scripts/capture.js <html-file> <out.png> <mode perfnow|raf> <canvasId> [timeMs=0] [size=1000]
//  perfnow (Touring): performance.now and rAF are taken over so the boot sees t0 = 0; one frame is fed at now = timeMs.
//  raf (Seeded/Tidal): rAF is taken over; first frame at t=0 (t0 = 0, phase 0), then a frame at timeMs if non-zero.
// Either way the frame is exact and deterministic. Chrome: $CHROME_PATH or /usr/bin/google-chrome.
const puppeteer = require('puppeteer-core'); const fs = require('fs'); const path = require('path');
(async () => {
  const [,, htmlFile, out, mode, canvasId, tArg, sArg] = process.argv;
  if (!htmlFile || !out || !['perfnow', 'raf'].includes(mode) || !canvasId) {
    console.error('usage: node capture.js <html> <out.png> <perfnow|raf> <canvasId> [timeMs] [size]'); process.exit(2);
  }
  const T = parseFloat(tArg || '0'), S = parseInt(sArg || '1000', 10);
  const extra = (process.env.CHROME_FLAGS || '').split(/\s+/).filter(Boolean);
  const b = await puppeteer.launch({ executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome', headless: true,
    args: ['--no-sandbox', ...extra] });
  const p = await b.newPage(); await p.setViewport({ width: S, height: S, deviceScaleFactor: 1 });
  const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  await p.evaluateOnNewDocument((mode) => {
    if (mode === 'perfnow') { window.__now = 0; performance.now = () => window.__now; window.cancelAnimationFrame = () => {}; }
    window.__rafQ = []; window.requestAnimationFrame = cb => { window.__rafQ.push(cb); return window.__rafQ.length; };
  }, mode);
  await p.goto('file://' + path.resolve(htmlFile), { waitUntil: 'load' });
  await p.waitForFunction(() => window.__rafQ.length > 0, { timeout: 60000, polling: 100 });
  const res = await p.evaluate((mode, T, canvasId) => {
    const step = (t) => { const q = window.__rafQ.splice(0); q.forEach(cb => cb(t)); return q.length; };
    if (mode === 'perfnow') { window.__now = T; step(T); }
    else { step(0); if (T !== 0) step(T); }
    const c = document.getElementById(canvasId);
    if (!c) return { error: 'no canvas #' + canvasId };
    return { w: c.width, h: c.height, url: c.toDataURL('image/png'),
             tokenId: (typeof tokenData !== 'undefined' && tokenData) ? tokenData.tokenId : null };
  }, mode, T, canvasId);
  if (res.error) throw new Error(res.error);
  fs.writeFileSync(out, Buffer.from(res.url.split(',')[1], 'base64'));
  console.log(JSON.stringify({ out, mode, timeMs: T, w: res.w, h: res.h, tokenId: res.tokenId, errors: errs }));
  await b.close();
  if (res.w !== S || res.h !== S) { console.error(`canvas is ${res.w}x${res.h}, expected ${S}x${S}`); process.exit(1); }
})().catch(e => { console.error(e); process.exit(1); });
