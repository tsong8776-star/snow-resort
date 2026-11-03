// 눈꽃 스키장 게임 서버
// - 브라우저에 index.html(게임 화면)을 보내 줍니다.
// - /ws 로 접속한 플레이어끼리 위치·사격 정보를 실시간으로 주고받게 해 줍니다.
// - 다 같이 만든 눈사람을 기억해 두었다가 늦게 온 사람에게도 보여 줍니다.
//   눈사람은 20분 뒤에 녹아 없어지고, 서버가 다시 켜져도 사라져요.
// - 누가 언제 들어오고 나갔는지 기록하고, /admin/visits?key=비밀번호 에서 보여 줍니다.
//   Render 환경 변수에 UPSTASH_REDIS_REST_URL / UPSTASH_REDIS_REST_TOKEN 을 넣으면
//   기록이 Upstash(무료 Redis)에 저장돼서 업데이트하거나 서버가 잠들어도 남아요.
//   ADMIN_KEY 에는 기록 페이지 비밀번호를 넣어요.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');
const crypto = require('crypto');

const PORT = process.env.PORT || 3000;
const MAX_PLAYERS = 40;
const INDEX = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
let OG = null; // 링크 공유·메타모아 썸네일용 대표 이미지
try { OG = fs.readFileSync(path.join(__dirname, 'og.png')); } catch (e) { OG = null; }

const server = http.createServer((req, res) => {
  if (req.url.startsWith('/admin/visits')) { visitsPage(req, res); return; }
  if (req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }
  if (req.url === '/og.png' && OG) {
    res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=3600' });
    res.end(OG);
    return;
  }
  // 공유 미리보기 이미지는 전체 주소가 필요해서, 접속한 주소를 넣어 보내요
  const host = String(req.headers.host || 'localhost').replace(/[^\w.:-]/g, '');
  const proto = String(req.headers['x-forwarded-proto'] || (/^(localhost|127\.)/.test(host) ? 'http' : 'https')).split(',')[0].trim() === 'http' ? 'http' : 'https';
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache' });
  res.end(INDEX.replace(/__ORIGIN__/g, proto + '://' + host));
});

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 8 * 1024 });
const players = new Map(); // id -> { ws, presence }
const history = []; // 최근 대화 50개 (늦게 온 사람도 볼 수 있게)
const fishBoard = []; // 빙어 길이 순위 (사람마다 최고 기록 하나)
const jumpBoard = []; // 스키점프 비거리 순위 (사람마다 최고 기록 하나)
const sledBoard = []; // 썰매 점수 순위 (사람마다 최고 기록 하나)
const skateBoard = []; // 피겨 점수 순위 (사람마다 최고 기록 하나)
const snowmen = []; // 플레이어가 만든 눈사람 (전체 최대 40개, 한 사람당 최대 3개)
const SNOWMAN_MAX = 40, SNOWMAN_PER_PLAYER = 3;
const SNOWMAN_LIFE = Number(process.env.SNOWMAN_LIFE_MS) || 20 * 60 * 1000; // 눈사람이 녹기까지 걸리는 시간
const SNOWMAN_MAX_R = 2.2; // 눈덩이 반지름 최대 (m)
const pubSnowman = (s) => ({ id: s.id, x: s.x, z: s.z, h: s.h, r: s.r, n: s.n, c: s.c, d: s.d, at: s.at });
let smCounter = 0;
const clean = (v, n) => String(v || '').replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2060-\u206f\ufeff]/g, '').trim().slice(0, n);
let counter = 0;

// ---------- 들어오고 나간 기록 ----------
const VISIT_MAX = 1000;
const VISIT_KEY = 'snow:visits';
const UPSTASH_URL = (process.env.UPSTASH_REDIS_REST_URL || '').replace(/\/+$/, '');
const UPSTASH_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN || '';
const ADMIN_KEY = process.env.ADMIN_KEY || '';
const visits = []; // 최신이 앞: { t: 'in' | 'out', n: 닉네임, at: 시각(ms), dur: 머문 시간(ms), r: 메모 }
let visitStore = UPSTASH_URL && UPSTASH_TOKEN ? 'loading' : 'memory';
let saveChain = Promise.resolve();

async function redis(cmds) {
  const res = await fetch(UPSTASH_URL + '/pipeline', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + UPSTASH_TOKEN, 'Content-Type': 'application/json' },
    body: JSON.stringify(cmds),
  });
  if (!res.ok) throw new Error('Upstash 응답 ' + res.status);
  return res.json();
}
function logVisit(e) {
  visits.unshift(e);
  if (visits.length > VISIT_MAX) visits.length = VISIT_MAX;
  if (visitStore === 'memory') return;
  saveChain = saveChain
    .then(() => redis([['LPUSH', VISIT_KEY, JSON.stringify(e)], ['LTRIM', VISIT_KEY, 0, VISIT_MAX - 1]]))
    .then(() => { visitStore = 'upstash'; })
    .catch((err) => { visitStore = 'error'; console.error('방문 기록 저장 실패:', err.message); });
}
async function loadVisits() {
  if (visitStore === 'memory') return;
  try {
    const [r] = await redis([['LRANGE', VISIT_KEY, 0, VISIT_MAX - 1]]);
    const old = ((r && r.result) || []).map((x) => { try { return JSON.parse(x); } catch (e) { return null; } }).filter(Boolean);
    visits.push(...old); // 서버가 켜진 뒤에 생긴 기록은 이미 앞쪽에 있어요
    if (visits.length > VISIT_MAX) visits.length = VISIT_MAX;
    visitStore = 'upstash';
  } catch (err) {
    visitStore = 'error';
    console.error('방문 기록 불러오기 실패:', err.message);
  }
}
loadVisits();

const esc = (v) => String(v).replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
const kst = (ms) => new Date(ms).toLocaleString('ko-KR', { timeZone: 'Asia/Seoul', month: 'numeric', day: 'numeric', weekday: 'short', hour: '2-digit', minute: '2-digit', second: '2-digit' });
function span(ms) {
  const m = Math.round(ms / 60000);
  if (m < 1) return '1분 미만';
  return m < 60 ? m + '분' : Math.floor(m / 60) + '시간 ' + (m % 60) + '분';
}
function keyOk(k) {
  const a = Buffer.from(String(k || '')), b = Buffer.from(ADMIN_KEY);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}
function visitsPage(req, res) {
  const url = new URL(req.url, 'http://localhost');
  const head = '<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">'
    + '<title>방문 기록</title><style>body{font-family:system-ui,"Apple SD Gothic Neo","Malgun Gothic",sans-serif;background:#f4f8fd;color:#1b2a4a;margin:0;padding:16px}main{max-width:760px;margin:0 auto}'
    + 'h1{font-size:22px;margin:4px 0 12px}.box{background:#fff;border:1px solid #d7e2ef;border-radius:12px;padding:12px 14px;margin-bottom:12px}.muted{color:#5b6b87;font-size:13px}'
    + 'table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:7px 6px;border-bottom:1px solid #e6edf6}th{font-size:12px;color:#5b6b87}'
    + '.in{color:#1f8f55;font-weight:700}.out{color:#c2364b;font-weight:700}.ok{color:#1f8f55}.warn{color:#b36b00}.bad{color:#c2364b}ul{margin:6px 0 0;padding-left:18px}</style></head><body><main>';
  const end = '</main></body></html>';
  res.setHeader('Cache-Control', 'no-store');
  if (!ADMIN_KEY) {
    res.writeHead(503, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(head + '<h1>방문 기록</h1><div class="box">아직 비밀번호가 없어요. Render의 Environment에 <b>ADMIN_KEY</b>를 추가하고 다시 열어 주세요.</div>' + end);
    return;
  }
  if (!keyOk(url.searchParams.get('key'))) {
    res.writeHead(403, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(head + '<h1>방문 기록</h1><div class="box bad">비밀번호가 맞지 않아요. 주소 끝의 <b>?key=</b> 뒤를 확인해 주세요.</div>' + end);
    return;
  }
  const store = visitStore === 'upstash' ? '<span class="ok">✔ Upstash에 저장 중 · 업데이트하거나 서버가 잠들어도 남아요</span>'
    : visitStore === 'loading' ? '<span class="warn">Upstash에서 불러오는 중…</span>'
    : visitStore === 'error' ? '<span class="bad">⚠ Upstash 연결 오류 · 주소와 토큰을 확인해 주세요 (지금은 메모리에만 있어요)</span>'
    : '<span class="warn">⚠ 서버 메모리에만 저장 중 · 업데이트하거나 서버가 잠들면 사라져요 (Upstash를 연결하면 남아요)</span>';
  const now = Date.now(), online = [...players.values()].filter((p) => p.logged);
  const onlineHtml = online.length
    ? '<ul>' + online.map((p) => '<li><b>' + esc(p.name) + '</b> <span class="muted">' + kst(p.joinAt) + '부터 · ' + span(now - p.joinAt) + '째</span></li>').join('') + '</ul>'
    : '<div class="muted">지금은 아무도 없어요</div>';
  const dayKey = (ms) => new Date(ms).toLocaleDateString('ko-KR', { timeZone: 'Asia/Seoul' });
  const today = dayKey(now), todayNames = new Set(visits.filter((v) => v.t === 'in' && dayKey(v.at) === today).map((v) => v.n));
  const rows = visits.map((v) => '<tr><td>' + kst(v.at) + '</td><td><b>' + esc(v.n) + '</b></td><td class="' + (v.t === 'in' ? 'in">들어옴' : 'out">나감') + '</td><td class="muted">'
    + (v.t === 'out' ? span(v.dur || 0) + ' 머묾' + (v.r ? ' · ' + esc(v.r) : '') : '') + '</td></tr>').join('');
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(head + '<h1>❄ 눈꽃 스키장 방문 기록</h1>'
    + '<div class="box">' + store + '<div class="muted" style="margin-top:4px">최근 ' + VISIT_MAX + '건까지 보관 · 시간은 한국 시간</div></div>'
    + '<div class="box"><b>지금 접속 중 ' + online.length + '명</b>' + onlineHtml + '</div>'
    + '<div class="box"><b>오늘 다녀간 사람 ' + todayNames.size + '명</b>' + (todayNames.size ? '<div class="muted" style="margin-top:4px">' + [...todayNames].map(esc).join(', ') + '</div>' : '') + '</div>'
    + '<div class="box"><table><thead><tr><th>시간</th><th>닉네임</th><th></th><th></th></tr></thead><tbody>'
    + (rows || '<tr><td colspan="4" class="muted">아직 기록이 없어요</td></tr>') + '</tbody></table></div>' + end);
}

function send(ws, msg) {
  if (ws.readyState === 1) ws.send(JSON.stringify(msg));
}
function broadcast(msg, exceptId) {
  const text = JSON.stringify(msg);
  for (const [id, p] of players) if (id !== exceptId && p.ws.readyState === 1) p.ws.send(text);
}

wss.on('connection', (ws) => {
  if (players.size >= MAX_PLAYERS) {
    ws.close(1013, 'full');
    return;
  }
  const id = 'p' + (++counter).toString(36) + Math.random().toString(36).slice(2, 6);
  const me = { ws, presence: {}, budget: 60, last: Date.now(), joinAt: Date.now(), logged: false, name: '' };
  players.set(id, me);

  send(ws, { t: 'hello', id, now: Date.now(), history, board: fishBoard, jboard: jumpBoard, sboard: sledBoard, kboard: skateBoard, sm: snowmen.map(pubSnowman), peers: [...players].filter(([k]) => k !== id).map(([k, v]) => ({ id: k, presence: v.presence })) });
  broadcast({ t: 'join', id }, id);

  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (raw) => {
    // 초당 약 60개까지만 받습니다(과도한 전송 방지).
    const now = Date.now();
    me.budget = Math.min(60, me.budget + ((now - me.last) / 1000) * 60);
    me.last = now;
    if (me.budget < 1) return;
    me.budget -= 1;

    let m;
    try { m = JSON.parse(raw); } catch (e) { return; }
    // clock sync: everyone starts races and sees lift chairs on the server's clock
    if (m && m.t === 'ping' && typeof m.c === 'number') { send(ws, { t: 'pong', c: m.c, now: Date.now() }); return; }
    if (m && m.t === 'fish' && typeof m.s === 'number' && m.s > 0 && m.s <= 40) {
      const n = clean(m.n, 10) || '스키어', size = Math.round(m.s * 10) / 10;
      const cur = fishBoard.find((e) => e.n === n);
      if (cur) { if (size <= cur.s) return; cur.s = size; cur.at = Date.now(); } else fishBoard.push({ n, s: size, at: Date.now() });
      fishBoard.sort((a, b) => b.s - a.s); fishBoard.length = Math.min(fishBoard.length, 30);
      broadcast({ t: 'board', board: fishBoard });
      return;
    }
    if (m && m.t === 'jump' && typeof m.d === 'number' && m.d > 0 && m.d <= 200) {
      const n = clean(m.n, 10) || '스키어', d = Math.round(m.d * 10) / 10;
      const cur = jumpBoard.find((e) => e.n === n);
      if (cur) { if (d <= cur.d) return; cur.d = d; cur.at = Date.now(); } else jumpBoard.push({ n, d, at: Date.now() });
      jumpBoard.sort((a, b) => b.d - a.d); jumpBoard.length = Math.min(jumpBoard.length, 30);
      broadcast({ t: 'jboard', board: jumpBoard });
      return;
    }
    if (m && m.t === 'sled' && typeof m.s === 'number' && m.s > 0 && m.s <= 30000) {
      const n = clean(m.n, 10) || '스키어', sc = Math.round(m.s);
      const cur = sledBoard.find((e) => e.n === n);
      if (cur) { if (sc <= cur.s) return; cur.s = sc; cur.at = Date.now(); } else sledBoard.push({ n, s: sc, at: Date.now() });
      sledBoard.sort((a, b) => b.s - a.s); sledBoard.length = Math.min(sledBoard.length, 30);
      broadcast({ t: 'sboard', board: sledBoard });
      return;
    }
    if (m && m.t === 'skate' && typeof m.s === 'number' && m.s > 0 && m.s <= 99999) {
      const n = clean(m.n, 10) || '스키어', sc = Math.round(m.s);
      const cur = skateBoard.find((e) => e.n === n);
      if (cur) { if (sc <= cur.s) return; cur.s = sc; cur.at = Date.now(); } else skateBoard.push({ n, s: sc, at: Date.now() });
      skateBoard.sort((a, b) => b.s - a.s); skateBoard.length = Math.min(skateBoard.length, 30);
      broadcast({ t: 'kboard', board: skateBoard });
      return;
    }
    if (m && m.t === 'snowman') {
      // 눈사람 완성: 위치·눈덩이 크기 3개·꾸미기 번호를 받아 모두에게 알려 줍니다.
      if (now - (me.smAt || 0) < 8000) return;
      const x = Number(m.x), z = Number(m.z), h = Number(m.h), r = Array.isArray(m.r) ? m.r.slice(0, 3).map(Number) : [];
      if (![x, z, h].every(Number.isFinite) || Math.abs(x) > 400 || Math.abs(z) > 400) return;
      if (r.length !== 3 || !r.every((v) => Number.isFinite(v) && v >= 0.2 && v <= SNOWMAN_MAX_R)) return;
      const key = clean(m.k, 40);
      if (!key) return;
      me.smAt = now;
      const removed = [];
      const mine = snowmen.filter((e) => e.key === key);
      while (mine.length >= SNOWMAN_PER_PLAYER) { const old = mine.shift(); snowmen.splice(snowmen.indexOf(old), 1); removed.push(old.id); }
      while (snowmen.length >= SNOWMAN_MAX) removed.push(snowmen.shift().id);
      const sm = {
        id: 's' + (++smCounter).toString(36) + Math.random().toString(36).slice(2, 6),
        x: Math.round(x * 100) / 100, z: Math.round(z * 100) / 100, h: Math.round(h * 100) / 100,
        r: r.map((v) => Math.round(v * 100) / 100), n: clean(m.n, 10) || '스키어',
        c: /^#[0-9a-f]{6}$/i.test(m.c) ? m.c : '#ff4f6d', d: Math.max(0, Math.min(3, m.d | 0)), at: now, key,
      };
      snowmen.push(sm);
      for (const id of removed) broadcast({ t: 'smdel', id });
      broadcast({ t: 'sm', sm: pubSnowman(sm) }, id);
      send(ws, { t: 'sm', sm: pubSnowman(sm), mine: true });
      return;
    }
    if (m && m.t === 'smdel' && typeof m.id === 'string') {
      // 자기가 만든 눈사람만 치울 수 있어요 (브라우저에 저장된 비밀 열쇠로 확인).
      const key = clean(m.k, 40), i = snowmen.findIndex((e) => e.id === m.id);
      if (!key || i < 0 || snowmen[i].key !== key) return;
      snowmen.splice(i, 1);
      broadcast({ t: 'smdel', id: m.id });
      return;
    }
    if (m && m.t === 'presence' && m.p && typeof m.p === 'object' && !Array.isArray(m.p)) {
      const chat = m.p.m;
      if (chat && typeof chat === 'object' && typeof chat.i === 'number' && me.chatI !== undefined && chat.i !== me.chatI) {
        const text = clean(chat.t, 60);
        if (text) { history.push({ n: clean(m.p.n, 10) || '스키어', c: /^#[0-9a-f]{6}$/i.test(m.p.c) ? m.p.c : '#ff4f6d', t: text, at: Date.now() }); if (history.length > 50) history.shift(); }
      }
      if (chat && typeof chat.i === 'number') me.chatI = chat.i; else if (me.chatI === undefined) me.chatI = null;
      me.presence = m.p;
      // 처음 게임에 들어와 이름을 보낼 때 '들어옴'을 기록해요 (시작 화면만 열어 본 사람은 빼요)
      const nick = clean(m.p.n, 10);
      if (nick && !me.logged) { me.logged = true; me.name = nick; me.joinAt = Date.now(); logVisit({ t: 'in', n: nick, at: me.joinAt }); }
      else if (nick) me.name = nick;
      broadcast({ t: 'presence', id, p: m.p }, id);
    }
  });

  ws.on('close', () => {
    if (me.logged && !me.outLogged) { me.outLogged = true; logVisit({ t: 'out', n: me.name, at: Date.now(), dur: Date.now() - me.joinAt }); }
    players.delete(id);
    broadcast({ t: 'leave', id });
  });
});

// 녹을 때가 된 눈사람 치우기
setInterval(() => {
  const now = Date.now();
  for (let i = snowmen.length - 1; i >= 0; i--) if (now - snowmen[i].at >= SNOWMAN_LIFE) { broadcast({ t: 'smdel', id: snowmen[i].id }); snowmen.splice(i, 1); }
}, Math.min(15000, SNOWMAN_LIFE / 4));

// 끊긴 연결 정리
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 30000);

// 업데이트로 서버가 꺼질 때: 접속 중이던 사람들의 '나감'을 남기고 저장이 끝난 뒤 종료해요
let stopping = false;
async function shutdown() {
  if (stopping) return;
  stopping = true;
  const now = Date.now();
  for (const p of players.values()) if (p.logged && !p.outLogged) { p.outLogged = true; logVisit({ t: 'out', n: p.name, at: now, dur: now - p.joinAt, r: '서버 업데이트·재시작' }); }
  await Promise.race([saveChain, new Promise((r) => setTimeout(r, 4000))]);
  process.exit(0);
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

server.listen(PORT, () => {
  console.log('눈꽃 스키장 서버 실행 중: http://localhost:' + PORT);
});
