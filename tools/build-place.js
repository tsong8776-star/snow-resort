#!/usr/bin/env node
// roblox/default.project.json 을 읽어서 Roblox Studio에서 바로 여는 .rbxlx 파일을 만들어요.
// Rojo의 파일 이름 규칙을 따라요: *.server.lua → Script, *.client.lua → LocalScript, *.lua → ModuleScript,
// 폴더 안 init(.server/.client).lua 는 폴더 자체가 그 스크립트가 돼요.
// 사용법: node tools/build-place.js [출력 경로]

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', 'roblox');
const project = JSON.parse(fs.readFileSync(path.join(root, 'default.project.json'), 'utf8'));
const out = path.resolve(process.argv[2] || path.join(root, 'SnowflakePeak.rbxlx'));

let refCounter = 0;
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const cdata = (s) => '<![CDATA[' + s.split(']]>').join(']]]]><![CDATA[>') + ']]>';

function scriptClass(file) {
  if (file.endsWith('.server.lua') || file.endsWith('.server.luau')) return 'Script';
  if (file.endsWith('.client.lua') || file.endsWith('.client.luau')) return 'LocalScript';
  if (file.endsWith('.lua') || file.endsWith('.luau')) return 'ModuleScript';
  return null;
}
function baseName(file) {
  return file.replace(/\.(server|client)?\.?luau?$/, '').replace(/\.$/, '');
}

// { className, name, source?, children[] }
function fromPath(name, p) {
  const st = fs.statSync(p);
  if (!st.isDirectory()) {
    const cls = scriptClass(p);
    if (!cls) return null;
    return { className: cls, name, source: fs.readFileSync(p, 'utf8'), children: [] };
  }
  const files = fs.readdirSync(p).sort();
  const init = files.find((f) => /^init(\.server|\.client)?\.luau?$/.test(f));
  const node = { className: 'Folder', name, children: [] };
  if (init) {
    node.className = scriptClass(init);
    node.source = fs.readFileSync(path.join(p, init), 'utf8');
  }
  for (const f of files) {
    if (f === init) continue;
    const child = fromPath(fs.statSync(path.join(p, f)).isDirectory() ? f : baseName(f), path.join(p, f));
    if (child) node.children.push(child);
  }
  return node;
}

function fromTree(name, tree) {
  let node;
  if (tree.$path) {
    node = fromPath(name, path.join(root, tree.$path));
    if (tree.$className) node.className = tree.$className;
  } else {
    node = { className: tree.$className || 'Folder', name, children: [] };
  }
  for (const [key, value] of Object.entries(tree)) {
    if (key.startsWith('$')) continue;
    node.children.push(fromTree(key, value));
  }
  return node;
}

function toXml(node, depth) {
  const pad = '  '.repeat(depth);
  const lines = [`${pad}<Item class="${esc(node.className)}" referent="RBX${refCounter++}">`, `${pad}  <Properties>`, `${pad}    <string name="Name">${esc(node.name)}</string>`];
  if (node.source !== undefined) lines.push(`${pad}    <ProtectedString name="Source">${cdata(node.source)}</ProtectedString>`);
  lines.push(`${pad}  </Properties>`);
  for (const child of node.children) lines.push(toXml(child, depth + 1));
  lines.push(`${pad}</Item>`);
  return lines.join('\n');
}

const dm = fromTree(project.name, project.tree);
const xml = ['<roblox version="4">', ...dm.children.map((c) => toXml(c, 1)), '</roblox>', ''].join('\n');
fs.writeFileSync(out, xml);

let count = 0;
(function walk(n) { if (n.source !== undefined) count++; n.children.forEach(walk); })(dm);
console.log(`만들었어요: ${path.relative(process.cwd(), out)} (스크립트 ${count}개)`);
