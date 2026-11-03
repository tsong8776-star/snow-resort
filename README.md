# 눈꽃 스키장

여러 명이 로그인 없이 링크만으로 함께 접속하는 3D 스키장 게임입니다.

## Render 설정값

| 항목 | 값 |
|---|---|
| Language | Node |
| Region | Singapore |
| Build Command | `npm install` |
| Start Command | `npm start` |
| Instance Type | Free |

## 방문 기록 보기

누가 언제 들어오고 나갔는지 `https://(게임 주소)/admin/visits?key=(비밀번호)` 에서 볼 수 있어요.

Render → 서비스 → **Environment** 에 아래 값을 넣어 주세요.

| 이름 | 값 |
|---|---|
| `ADMIN_KEY` | 기록 페이지 비밀번호 (직접 정하기) |
| `UPSTASH_REDIS_REST_URL` | Upstash 데이터베이스의 REST URL |
| `UPSTASH_REDIS_REST_TOKEN` | Upstash 데이터베이스의 REST Token |

Upstash(https://upstash.com, 무료)를 연결하지 않으면 기록이 서버 메모리에만 있어서,
업데이트하거나 서버가 잠들면 사라져요.


## 로블록스 버전 (Snowflake Peak)

로블록스용으로 다시 만드는 중이에요. 열고 테스트하고 올리는 방법은 [`roblox/README.md`](roblox/README.md)를 보세요.
웹 버전(`index.html`, `server.js`)은 그대로 동작해요.
