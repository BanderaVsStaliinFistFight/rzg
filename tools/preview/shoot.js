// Renders tools/preview/parts.json (from `lune run tools/build -- --parts ...`) in headless
// Chromium. Usage: node shoot.js <outdir> view1 view2 ...  (views are listed in render.html)
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', '..'); // serve the repo, so textures/ is reachable
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(p, (err, buf) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' });
    res.end(buf);
  });
});

(async () => {
  await new Promise(r => server.listen(0, r));
  const port = server.address().port;
  const [outDir, ...views] = process.argv.slice(2);
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  for (const v of views) {
    const top = v === 'top';
    const w = top ? 440 : 1280, h = top ? 826 : 720;
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    page.on('console', m => console.log(v, 'console:', m.text()));
    page.on('pageerror', e => console.log(v, 'error:', e.message));
    await page.goto(`http://localhost:${port}/tools/preview/render.html?view=${v}&w=${w}&h=${h}`);
    await page.waitForFunction(() => window.__done === true, null, { timeout: 180000 });
    await page.screenshot({ path: path.join(outDir, `${v}.png`) });
    console.log('rendered', v);
    await page.close();
  }
  await browser.close();
  server.close();
})();
