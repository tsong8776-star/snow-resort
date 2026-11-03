# Snowflake Peak (로블록스 버전)

웹 게임 "눈꽃 스키장"을 로블록스용으로 다시 만드는 폴더예요.
기획은 [`docs/roblox/01-market-research-and-plan.md`](../docs/roblox/01-market-research-and-plan.md)에 있어요.

## 지금 들어 있는 것 (1단계)
- 코드로 만드는 설산: 슬로프 4개 (눈꽃 초원 → 소나무 길 → 여우 런 → 설인 낭떠러지)
- 슬로프마다 리프트 (지금은 타면 정상으로 순간 이동), 출발대, 깃발 문, 결승선
- 썰매 타기: A/D 방향, W 밀기, S 브레이크, 스페이스 내리기 (모바일은 조이스틱)
- 코인(❄): 깃발 통과, 완주, 깃발 전부 통과, 최고 기록 보너스
- 썰매 차고: 썰매 5단계 업그레이드 (속도 증가)
- 슬로프 해금: 리프트에서 코인으로 해금
- 저장: 코인, 썰매, 해금, 최고 기록 (DataStore)
- 광장: 산장(썰매 차고), 모닥불, 눈사람, 눈 내리는 효과
- 한국어 / 영어 자동 전환

## 처음 한 번: 준비
1. 노트북(Windows 또는 Mac)에서 https://create.roblox.com 접속 → 로블록스 계정으로 로그인
2. **Roblox Studio 다운로드** 후 설치, 같은 계정으로 로그인

## 게임 열고 테스트하기
1. GitHub에서 [`roblox/SnowflakePeak.rbxlx`](SnowflakePeak.rbxlx) 파일을 내려받아요
   (파일 페이지에서 오른쪽 위 **Download raw file** 버튼)
2. 내려받은 파일을 더블클릭하거나, Studio에서 **File → Open from File**로 열어요
3. 위쪽 **Play** 버튼(▶)을 누르면 테스트가 시작돼요
   - 처음 몇 초 동안 산이 만들어져요. 편집 화면에서는 빈 땅으로 보이는 게 정상이에요
   - 아직 업로드 전이라 "테스트 모드라서 기록이 저장되지 않아요"라는 알림이 떠요
4. 광장 앞쪽 리프트 → 정상 → 초록색 출발대에서 **E** → **W**로 출발!

## 로블록스에 올리기
1. Studio에서 **File → Publish to Roblox** → 새 게임 만들기
   - 이름: `Snowflake Peak`
   - 장르, 설명은 나중에 바꿀 수 있어요
2. **Home → Game Settings → Security** → **Enable Studio Access to API Services** 켜기
   (Studio 테스트에서도 저장이 돼요)
3. 처음에는 **비공개(Private)** 로 두고 친구와 테스트하기
4. 공개 전에 할 일
   - Creator Hub에서 **성숙도 설문(Maturity & Compliance)** 작성
   - 아이콘과 썸네일 등록
   - **Permissions**에서 공개(Public)로 전환

## 코드 수정 후 다시 만들기 (개발용)
```bash
node tools/check-lua.js
```
```bash
node tools/build-place.js
```
- `roblox/src/shared`: 설정(Config), 글자(Strings), 슬로프 계산
- `roblox/src/server`: 서버 스크립트 (지형, 썰매, 저장)
- `roblox/src/client`: 화면과 썰매 조종
- 폴더 구조는 [Rojo](https://rojo.space) 규칙을 따라서, 나중에 Rojo로 Studio와 실시간 연동도 할 수 있어요.

## 다음 단계 (2단계 예정)
- 눈꽃 펫 수집 (구슬 열기, 등급, 펫 효과)
- 빙어 낚시 도감, 스키점프
- 일일 미션, 연속 출석 보상
- 게임 패스·상품 연결
- 진짜로 움직이는 리프트 의자
