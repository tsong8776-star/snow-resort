// Render all SVGs in a folder into one labelled preview sheet (PNG) via headless Chromium.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const [dir, out] = process.argv.slice(2);
const files = fs.readdirSync(dir).filter(f => f.endsWith('.svg')).sort();
const cells = files.map(f => `<div class=c><div class=i>${fs.readFileSync(path.join(dir, f), 'utf8')}</div><p>${f.replace('.svg','')}</p></div>`).join('');
const html = `<style>body{margin:0;font:13px sans-serif;background:#fff}.g{display:grid;grid-template-columns:repeat(4,220px);gap:12px;padding:16px}
.c{background:#f3f3f5;padding:12px;text-align:center}.i svg{width:150px;height:150px}p{margin:6px 0 0}</style><div class=g>${cells}</div>`;
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 960, height: 400 } });
  await p.setContent(html); await p.screenshot({ path: out, fullPage: true }); await b.close();
})();
