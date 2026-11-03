-- 슬로프 모양 계산 (서버에서 지형을 만들 때, 깃발 위치를 정할 때 사용)
-- z가 커질수록 아래쪽(광장 방향)이에요.

local Config = require(script.Parent.Config)

local Geo = {}

function Geo.build()
	local courses = {}
	local n = #Config.Courses
	for i, c in ipairs(Config.Courses) do
		local a = math.rad(c.angle)
		local runDrop = Config.RUNOUT * math.tan(a * 0.5)
		local mainLen = (Config.DROP - runDrop) / math.tan(a)
		local x = (i - (n + 1) / 2) * Config.COURSE_SPACING
		local endZ = Config.END_Z
		local mainEndZ = endZ - Config.RUNOUT
		local startZ = mainEndZ - mainLen
		courses[i] = {
			cfg = c,
			index = i,
			x = x,
			width = Config.COURSE_WIDTH,
			startZ = startZ,
			mainEndZ = mainEndZ,
			finishZ = mainEndZ,
			endZ = endZ,
			mainLen = mainLen,
			-- 위에서 아래로: 정상 출발대 → 메인 슬로프 → 감속 구간
			pts = {
				{ z = startZ - Config.PLATFORM, y = Config.DROP },
				{ z = startZ, y = Config.DROP },
				{ z = mainEndZ, y = runDrop },
				{ z = endZ, y = 0 },
			},
		}
	end
	return courses
end

function Geo.heightAt(pts, z)
	if z <= pts[1].z then
		return pts[1].y
	end
	for k = 1, #pts - 1 do
		local p, q = pts[k], pts[k + 1]
		if z <= q.z then
			local t = (z - p.z) / (q.z - p.z)
			return p.y + (q.y - p.y) * t
		end
	end
	return 0
end

function Geo.shifted(pts, dy)
	local out = {}
	for k, p in ipairs(pts) do
		out[k] = { z = p.z, y = p.y + dy }
	end
	return out
end

return Geo
