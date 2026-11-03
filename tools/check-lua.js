#!/usr/bin/env node
// 아주 간단한 Lua/Luau 구조 검사: 블록(function/if/do/repeat ↔ end/until)과 괄호 짝이 맞는지 확인해요.
// 진짜 컴파일러는 아니지만, 흔한 실수(빠진 end, 안 닫힌 괄호)를 미리 찾아 줘요.
// 사용법: node tools/check-lua.js roblox/src

const fs = require('fs');
const path = require('path');

function files(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((d) => {
    const p = path.join(dir, d.name);
    if (d.isDirectory()) return files(p);
    return /\.luau?$/.test(d.name) ? [p] : [];
  });
}

function tokens(src) {
  const out = [];
  let i = 0, line = 1;
  const longBracket = (at) => { const m = /^\[(=*)\[/.exec(src.slice(at)); return m ? m[1].length : -1; };
  while (i < src.length) {
    const c = src[i];
    if (c === '\n') { line++; i++; continue; }
    if (src.startsWith('--', i)) {
      const lvl = longBracket(i + 2);
      if (lvl >= 0) {
        const close = ']' + '='.repeat(lvl) + ']';
        const end = src.indexOf(close, i);
        if (end < 0) throw new Error(`${line}: 닫히지 않은 긴 주석`);
        line += (src.slice(i, end).match(/\n/g) || []).length; i = end + close.length;
      } else { while (i < src.length && src[i] !== '\n') i++; }
      continue;
    }
    if (c === '[') {
      const lvl = longBracket(i);
      if (lvl >= 0) {
        const close = ']' + '='.repeat(lvl) + ']';
        const end = src.indexOf(close, i);
        if (end < 0) throw new Error(`${line}: 닫히지 않은 긴 문자열`);
        line += (src.slice(i, end).match(/\n/g) || []).length; i = end + close.length; out.push({ t: 'str', line });
        continue;
      }
    }
    if (c === '"' || c === "'" || c === '`') {
      let j = i + 1;
      while (j < src.length && src[j] !== c) { if (src[j] === '\\') j++; if (src[j] === '\n') throw new Error(`${line}: 문자열이 줄 끝까지 안 닫혔어요`); j++; }
      out.push({ t: 'str', line }); i = j + 1; continue;
    }
    if (/[A-Za-z_]/.test(c)) {
      let j = i; while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++;
      out.push({ t: 'word', v: src.slice(i, j), line, prev: out.length ? out[out.length - 1] : null }); i = j; continue;
    }
    if ('(){}[]'.includes(c)) { out.push({ t: 'sym', v: c, line }); i++; continue; }
    i++;
  }
  return out;
}

function check(file) {
  const src = fs.readFileSync(file, 'utf8');
  const stack = [];
  const pairs = { ')': '(', '}': '{', ']': '[' };
  for (const tk of tokens(src)) {
    if (tk.t === 'word') {
      if (['function', 'if', 'do', 'repeat'].includes(tk.v)) stack.push(tk);
      else if (tk.v === 'end') {
        const top = stack.pop();
        if (!top || !['function', 'if', 'do'].includes(top.v)) throw new Error(`${tk.line}: 'end'가 맞지 않아요 (열린 것: ${top ? top.v + '@' + top.line : '없음'})`);
      } else if (tk.v === 'until') {
        const top = stack.pop();
        if (!top || top.v !== 'repeat') throw new Error(`${tk.line}: 'until'이 맞지 않아요`);
      }
    } else if (tk.t === 'sym') {
      if ('({['.includes(tk.v)) stack.push(tk);
      else {
        const top = stack.pop();
        if (!top || top.v !== pairs[tk.v]) throw new Error(`${tk.line}: '${tk.v}' 짝이 맞지 않아요 (열린 것: ${top ? top.v + '@' + top.line : '없음'})`);
      }
    }
  }
  if (stack.length) { const t = stack[stack.length - 1]; throw new Error(`${t.line}: '${t.v}'가 닫히지 않았어요`); }
}

const dir = process.argv[2] || path.join(__dirname, '..', 'roblox', 'src');
let bad = 0;
for (const f of files(dir)) {
  try { check(f); console.log('ok   ' + path.relative(process.cwd(), f)); }
  catch (e) { bad++; console.log('FAIL ' + path.relative(process.cwd(), f) + ':' + e.message); }
}
process.exit(bad ? 1 : 0);
