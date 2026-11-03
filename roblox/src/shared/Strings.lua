-- 화면에 보이는 글자 (한국어 / 영어)
-- 로블록스 언어 설정이 한국어면 한국어, 아니면 영어로 보여요.

local Strings = {}

Strings.en = {
	lift_object = "%s Lift",
	lift_ride = "Ride lift",
	lift_unlock = "Unlock · %d ❄",
	start_object = "%s",
	start_ride = "Grab a sled",
	lodge = "Lodge",
	garage_open = "Open garage",
	garage_button = "🛷 Garage",
	garage_title = "Sled Garage",
	slopes_title = "Slopes",
	sleds_title = "Sleds",
	top_speed = "Top speed %d km/h",
	riding = "Riding",
	owned = "Owned",
	buy = "Buy %d ❄",
	locked = "🔒",
	slope_locked = "Unlock at the lift · %d ❄",
	slope_open = "Open · coins ×%s",
	best = "Best %s",
	no_best = "No record yet",
	close = "Close",
	need_coins = "%s: you need %d more ❄",
	unlocked = "%s is open! Enjoy the ride",
	sled_bought = "New sled: %s!",
	no_save = "Test mode: progress won't be saved.",
	hint_push = "Press W or push forward to start!",
	gates = "Gates %d/%d",
	finish_title = "FINISH!",
	finish_time = "%s",
	finish_detail = "Gates %d/%d   +%d ❄",
	perfect = "Perfect run!",
	new_best = "New best!",
	course_green = "Snowflake Meadow",
	course_blue = "Pine Trail",
	course_red = "Fox Run",
	course_black = "Yeti Drop",
	sled_wood = "Wooden Sled",
	sled_plastic = "Plastic Sled",
	sled_racer = "Racing Sled",
	sled_pro = "Pro Sled",
	sled_gold = "Golden Sled",
}

Strings.ko = {
	lift_object = "%s 리프트",
	lift_ride = "리프트 타기",
	lift_unlock = "해금 · %d ❄",
	start_object = "%s",
	start_ride = "썰매 타기",
	lodge = "산장",
	garage_open = "차고 열기",
	garage_button = "🛷 차고",
	garage_title = "썰매 차고",
	slopes_title = "슬로프",
	sleds_title = "썰매",
	top_speed = "최고 속도 %d km/h",
	riding = "타는 중",
	owned = "보유",
	buy = "%d ❄ 구매",
	locked = "🔒",
	slope_locked = "리프트에서 해금 · %d ❄",
	slope_open = "열림 · 코인 ×%s",
	best = "최고 %s",
	no_best = "아직 기록 없음",
	close = "닫기",
	need_coins = "%s까지 ❄ %d개가 더 필요해요",
	unlocked = "%s 열렸어요! 신나게 타 봐요",
	sled_bought = "새 썰매: %s!",
	no_save = "테스트 모드라서 기록이 저장되지 않아요.",
	hint_push = "W 키를 누르거나 앞으로 밀어서 출발!",
	gates = "깃발 %d/%d",
	finish_title = "완주!",
	finish_time = "%s",
	finish_detail = "깃발 %d/%d   +%d ❄",
	perfect = "깃발 전부 통과!",
	new_best = "최고 기록!",
	course_green = "눈꽃 초원",
	course_blue = "소나무 길",
	course_red = "여우 런",
	course_black = "설인 낭떠러지",
	sled_wood = "나무 썰매",
	sled_plastic = "플라스틱 썰매",
	sled_racer = "레이싱 썰매",
	sled_pro = "프로 썰매",
	sled_gold = "황금 썰매",
}

function Strings.lang(localeId)
	if type(localeId) == "string" and string.sub(string.lower(localeId), 1, 2) == "ko" then
		return "ko"
	end
	return "en"
end

function Strings.get(lang, key, ...)
	local t = Strings[lang] or Strings.en
	local s = t[key] or Strings.en[key] or key
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		if ok then
			return out
		end
	end
	return s
end

function Strings.time(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds - m * 60
	return string.format("%d:%04.1f", m, s)
end

return Strings
