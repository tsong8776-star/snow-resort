// 눈꽃 스키장 게임 서버
// - 브라우저에 index.html(게임 화면)을 보내 줍니다.
// - /ws 로 접속한 플레이어끼리 위치·사격 정보를 실시간으로 주고받게 해 줍니다.
// - 다 같이 만든 눈사람을 기억해 두었다가 늦게 온 사람에게도 보여 줍니다.
//   눈사람은 20분 뒤에 녹아 없어지고, 서버가 다시 켜져도 사라져요.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 3000;
const MAX_PLAYERS = 40;
const INDEX = fs.readFileSync(path.join(__dirname, 'index.html'));

const server = http.createServer((req, res) => {
  if (req.url === '/healthz') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('ok');
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache' });
  res.end(INDEX);
});

const wss = new WebSocketServer({ server, path: '/ws', maxPayload: 8 * 1024 });
const players = new Map(); // id -> { ws, presence }
const history = []; // 최근 대화 50개 (늦게 온 사람도 볼 수 있게)
const fishBoard = []; // 빙어 길이 순위 (사람마다 최고 기록 하나)
const jumpBoard = []; // 스키점프 비거리 순위 (사람마다 최고 기록 하나)
const sledBoard = []; // 썰매 점수 순위 (사람마다 최고 기록 하나)
const snowmen = []; // 플레이어가 만든 눈사람 (전체 최대 40개, 한 사람당 최대 3개)
const SNOWMAN_MAX = 40, SNOWMAN_PER_PLAYER = 3;
const SNOWMAN_LIFE = Number(process.env.SNOWMAN_LIFE_MS) || 20 * 60 * 1000; // 눈사람이 녹기까지 걸리는 시간
const SNOWMAN_MAX_R = 2.2; // 눈덩이 반지름 최대 (m)
const pubSnowman = (s) => ({ id: s.id, x: s.x, z: s.z, h: s.h, r: s.r, n: s.n, c: s.c, d: s.d, at: s.at });
let smCounter = 0;
const clean = (v, n) => String(v || '').replace(/[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u202a-\u202e\u2060-\u206f\ufeff]/g, '').trim().slice(0, n);
let counter = 0;

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
  const me = { ws, presence: {}, budget: 60, last: Date.now() };
  players.set(id, me);

  send(ws, { t: 'hello', id, now: Date.now(), history, board: fishBoard, jboard: jumpBoard, sboard: sledBoard, sm: snowmen.map(pubSnowman), peers: [...players].filter(([k]) => k !== id).map(([k, v]) => ({ id: k, presence: v.presence })) });
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
      broadcast({ t: 'presence', id, p: m.p }, id);
    }
  });

  ws.on('close', () => {
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

server.listen(PORT, () => {
  console.log('눈꽃 스키장 서버 실행 중: http://localhost:' + PORT);
});
