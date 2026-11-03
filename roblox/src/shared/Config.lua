-- Snowflake Peak 게임 설정값
-- 숫자를 바꾸면 게임 밸런스가 바뀌어요. (코인 보상, 가격, 썰매 속도 등)

local Config = {}

Config.DATA_STORE = "SnowflakePeak_v1" -- 저장소 이름 (바꾸면 모든 저장 기록이 새로 시작돼요)
Config.AUTOSAVE_SECONDS = 90

-- 산 모양
Config.DROP = 200 -- 정상 높이 (stud)
Config.END_Z = -60 -- 모든 슬로프가 끝나는 지점 (광장 앞)
Config.COURSE_WIDTH = 56
Config.COURSE_SPACING = 140
Config.RUNOUT = 80 -- 결승선 뒤 감속 구간 길이
Config.PLATFORM = 70 -- 정상 출발대 길이

-- 코인 보상
Config.GATE_COINS = 5 -- 깃발 문 하나 통과
Config.FINISH_COINS = 20 -- 완주
Config.PERFECT_BONUS = 25 -- 모든 깃발 통과
Config.BEST_BONUS = 15 -- 개인 최고 기록

-- 슬로프: 왼쪽(완만)부터 오른쪽(가파름) 순서
-- price: 해금 가격, mult: 코인 배수
Config.Courses = {
	{ id = "green", angle = 12, price = 0, mult = 1, color = Color3.fromRGB(70, 190, 110), sign = "SNOWFLAKE MEADOW" },
	{ id = "blue", angle = 17, price = 250, mult = 1.6, color = Color3.fromRGB(60, 130, 230), sign = "PINE TRAIL" },
	{ id = "red", angle = 23, price = 1200, mult = 2.5, color = Color3.fromRGB(230, 70, 80), sign = "FOX RUN" },
	{ id = "black", angle = 30, price = 5000, mult = 4, color = Color3.fromRGB(40, 44, 56), sign = "YETI DROP" },
}

-- 썰매: 순서대로 하나씩 업그레이드
-- speed: 최고 속도 (stud/s, 대략 km/h와 같아요)
Config.Sleds = {
	{ id = "wood", speed = 70, price = 0, color = Color3.fromRGB(160, 110, 65), trim = Color3.fromRGB(230, 200, 150) },
	{ id = "plastic", speed = 85, price = 300, color = Color3.fromRGB(240, 80, 95), trim = Color3.fromRGB(255, 220, 225) },
	{ id = "racer", speed = 100, price = 1500, color = Color3.fromRGB(55, 135, 240), trim = Color3.fromRGB(255, 255, 255) },
	{ id = "pro", speed = 120, price = 6000, color = Color3.fromRGB(245, 248, 255), trim = Color3.fromRGB(40, 60, 110) },
	{ id = "gold", speed = 140, price = 20000, color = Color3.fromRGB(245, 200, 60), trim = Color3.fromRGB(255, 245, 200) },
}

function Config.courseById(id)
	for _, c in ipairs(Config.Courses) do
		if c.id == id then
			return c
		end
	end
	return nil
end

return Config
