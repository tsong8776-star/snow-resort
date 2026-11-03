-- 게임을 시작할 때 스키장 전체를 코드로 만들어요.
-- 눈 지형, 슬로프 4개, 깃발 문, 출발대·결승선, 리프트, 광장, 산장, 나무

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Geo = require(Shared:WaitForChild("CourseGeometry"))

local WorldBuilder = {}

local terrain = Workspace.Terrain
local SNOW = Enum.Material.Snow
local STRIP_DROP = -14 -- 슬로프 사이 언덕은 슬로프보다 이만큼 낮아요
local WHITE = Color3.fromRGB(255, 255, 255)
local NAVY = Color3.fromRGB(27, 42, 74)
local WOOD = Color3.fromRGB(150, 105, 62)
local METAL = Color3.fromRGB(90, 100, 117)

local world -- 만들어진 오브젝트를 담는 폴더

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent or world
	return p
end

local function sign(cf, size, text, bg, fg)
	local p = part({ Name = "Sign", Size = size, CFrame = cf, Color = bg })
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = p
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = fg
		label.Parent = gui
	end
	return p
end

local function prompt(parent, tag, courseId, action, object)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	if courseId then
		pr:SetAttribute("CourseId", courseId)
	end
	pr.Parent = parent
	CollectionService:AddTag(pr, tag)
	return pr
end

---------------------------------------------------------------- 지형

-- p에서 q까지 기울어진 두꺼운 눈 블록 (윗면이 슬로프 표면)
local function fillSegment(x, width, p, q, thickness, extend)
	local a = Vector3.new(x, p.y, p.z)
	local b = Vector3.new(x, q.y, q.z)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(a, b)
	local total = len + extend
	local center = cf * CFrame.new(0, -thickness / 2, -total / 2)
	terrain:FillBlock(center, Vector3.new(width, thickness, total), SNOW)
end

-- 기울어진 블록 아래 빈 공간을 계단식으로 채워요 (겉에서는 안 보여요)
local function fillUnder(x, width, pts, margin)
	local z0, z1 = pts[1].z, pts[#pts].z
	local step = 24
	local z = z0
	while z < z1 do
		local zEnd = math.min(z + step, z1)
		local h = math.min(Geo.heightAt(pts, z), Geo.heightAt(pts, zEnd)) - margin
		if h > 2 then
			terrain:FillBlock(CFrame.new(x, h / 2, (z + zEnd) / 2), Vector3.new(width, h, zEnd - z), SNOW)
		end
		z = zEnd
	end
end

local function slope(i, pts)
	local s = (pts[i].y - pts[i + 1].y) / (pts[i + 1].z - pts[i].z)
	return s
end

local function fillProfile(x, width, pts)
	for k = 1, #pts - 1 do
		-- 다음 구간이 더 완만할 때만 앞으로 살짝 늘려서 이음새를 메워요
		local extend = 10
		if k < #pts - 1 and slope(k + 1, pts) > slope(k, pts) then
			extend = 0
		end
		fillSegment(x, width, pts[k], pts[k + 1], 40, extend)
	end
	fillUnder(x, width, pts, 30)
end

---------------------------------------------------------------- 장식

local function tree(pos, scale)
	part({ Name = "Trunk", Size = Vector3.new(1.4, 5, 1.4) * scale, CFrame = CFrame.new(pos + Vector3.new(0, 2.5 * scale, 0)), Color = Color3.fromRGB(107, 74, 43), Material = Enum.Material.Wood })
	local layers = { { 9, 7, 5.5 }, { 7, 6, 9.5 }, { 4.8, 5, 13 } }
	for _, l in ipairs(layers) do
		local leaf = part({ Name = "Leaves", Size = Vector3.new(l[1], l[2], l[1]) * scale, CFrame = CFrame.new(pos + Vector3.new(0, l[3] * scale, 0)), Color = Color3.fromRGB(47, 106, 70), Material = Enum.Material.Grass })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = leaf
	end
	local cap = part({ Name = "SnowCap", Size = Vector3.new(3.2, 2.4, 3.2) * scale, CFrame = CFrame.new(pos + Vector3.new(0, 15.6 * scale, 0)), Color = WHITE, Material = SNOW })
	local capMesh = Instance.new("SpecialMesh")
	capMesh.MeshType = Enum.MeshType.Sphere
	capMesh.Parent = cap
end

local function snowman(pos, scale)
	for _, s in ipairs({ { 4, 2 }, { 3, 5.2 }, { 2.2, 7.6 } }) do
		local ball = part({ Name = "Snowman", Shape = Enum.PartType.Ball, Size = Vector3.new(s[1], s[1], s[1]) * scale, CFrame = CFrame.new(pos + Vector3.new(0, s[2] * scale, 0)), Color = WHITE, Material = SNOW })
		ball.CanCollide = true
	end
	part({ Name = "Nose", Size = Vector3.new(0.4, 0.4, 1.2) * scale, CFrame = CFrame.new(pos + Vector3.new(0, 7.6 * scale, 1.4 * scale)), Color = Color3.fromRGB(255, 138, 42) })
	part({ Name = "Hat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 1.8, 1.8) * scale, CFrame = CFrame.new(pos + Vector3.new(0, 9.1 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = NAVY })
end

local function arch(x, y, z, halfWidth, text, color)
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "ArchPost", Size = Vector3.new(1, 12, 1), CFrame = CFrame.new(x + sx * halfWidth, y + 5, z), Color = METAL, CanCollide = false })
	end
	sign(CFrame.new(x, y + 11, z), Vector3.new(halfWidth * 2 + 1, 3, 0.4), text, color, WHITE).CanCollide = false
end

local function gateVisual(x, y, z, half, color)
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "GatePole", Size = Vector3.new(0.6, 8, 0.6), CFrame = CFrame.new(x + sx * half, y + 3, z), Color = color, CanCollide = false, Material = Enum.Material.Neon })
	end
	part({ Name = "GateBanner", Size = Vector3.new(half * 2, 1.4, 0.3), CFrame = CFrame.new(x, y + 6.4, z), Color = color, CanCollide = false })
end

---------------------------------------------------------------- 리프트

local function liftLine(course, lx)
	local pts = course.pts
	local towers = {}
	local z = Config.END_Z + 20
	local topZ = course.startZ - 30
	while z > topZ do
		table.insert(towers, z)
		z -= 150
	end
	table.insert(towers, topZ)
	local tops = {}
	for _, tz in ipairs(towers) do
		local surface = Geo.heightAt(pts, tz)
		local ground = math.max(0, surface + STRIP_DROP)
		local top = surface + 26
		part({ Name = "LiftTower", Size = Vector3.new(1.6, top - ground + 2, 1.6), CFrame = CFrame.new(lx, (top + ground) / 2, tz), Color = METAL })
		part({ Name = "LiftArm", Size = Vector3.new(8, 0.8, 1.2), CFrame = CFrame.new(lx, top + 0.6, tz), Color = METAL })
		table.insert(tops, Vector3.new(lx, top + 1, tz))
	end
	for k = 1, #tops - 1 do
		local a, b = tops[k], tops[k + 1]
		for _, side in ipairs({ -3.4, 3.4 }) do
			local pa, pb = a + Vector3.new(side, 0, 0), b + Vector3.new(side, 0, 0)
			part({ Name = "Cable", Size = Vector3.new(0.25, 0.25, (pb - pa).Magnitude), CFrame = CFrame.lookAt((pa + pb) / 2, pb), Color = Color3.fromRGB(50, 56, 66), CanCollide = false })
		end
		-- 줄에 매달린 의자 몇 개 (움직이지는 않아요)
		for t = 0.25, 0.75, 0.5 do
			local side = (t < 0.5) and -3.4 or 3.4
			local p = a:Lerp(b, t) + Vector3.new(side, 0, 0)
			part({ Name = "ChairHanger", Size = Vector3.new(0.2, 5, 0.2), CFrame = CFrame.new(p - Vector3.new(0, 2.5, 0)), Color = METAL, CanCollide = false })
			part({ Name = "Chair", Size = Vector3.new(4, 0.5, 1.8), CFrame = CFrame.new(p - Vector3.new(0, 5, 0)), Color = course.cfg.color, CanCollide = false })
		end
	end
end

local function liftHut(course, lx)
	local c = course.cfg
	local z = Config.END_Z + 20
	part({ Name = "HutFloor", Size = Vector3.new(14, 1, 12), CFrame = CFrame.new(lx, 0.5, z), Color = WOOD, Material = Enum.Material.WoodPlanks })
	for _, sx in ipairs({ -6, 6 }) do
		part({ Name = "HutPost", Size = Vector3.new(1, 9, 1), CFrame = CFrame.new(lx + sx, 5, z + 5), Color = WOOD })
		part({ Name = "HutPost", Size = Vector3.new(1, 9, 1), CFrame = CFrame.new(lx + sx, 5, z - 5), Color = WOOD })
	end
	part({ Name = "HutRoof", Size = Vector3.new(16, 1.2, 14), CFrame = CFrame.new(lx, 10, z), Color = c.color })
	part({ Name = "HutRoofSnow", Size = Vector3.new(16.4, 0.6, 14.4), CFrame = CFrame.new(lx, 10.9, z), Color = WHITE, Material = SNOW })
	sign(CFrame.new(lx, 13.5, z + 6.5), Vector3.new(14, 3, 0.4), c.sign .. " LIFT", c.color, WHITE)
	local pad = part({ Name = "LiftGate", Size = Vector3.new(6, 4, 1), CFrame = CFrame.new(lx, 3, z + 6.5), Color = Color3.fromRGB(255, 197, 61), CanCollide = false, Transparency = 0.2 })
	return prompt(pad, "LiftPrompt", c.id, "Ride lift", c.sign .. " Lift")
end

---------------------------------------------------------------- 슬로프

local function buildCourse(course)
	local c = course.cfg
	local x, w = course.x, course.width
	fillProfile(x, w, course.pts)

	-- 깃발 문 (지그재그)
	course.gates = {}
	local count = math.max(3, math.floor(course.mainLen / 90))
	for g = 1, count do
		local z = course.startZ + g * course.mainLen / (count + 1)
		local off = ((g % 2 == 0) and 1 or -1) * w * 0.2
		local gate = { z = z, x = x + off, half = 9 }
		table.insert(course.gates, gate)
		gateVisual(gate.x, Geo.heightAt(course.pts, z), z, gate.half, c.color)
	end

	-- 출발대와 결승선
	local top = Config.DROP
	arch(x, top, course.startZ - 2, w / 2 + 2, "START", c.color)
	arch(x, Geo.heightAt(course.pts, course.finishZ), course.finishZ, w / 2 + 3, "FINISH", NAVY)
	sign(CFrame.new(x, top + 16, course.startZ - Config.PLATFORM + 4), Vector3.new(w - 6, 8, 1), c.sign, c.color, WHITE)

	local pad = part({ Name = "StartPad", Size = Vector3.new(14, 0.4, 8), CFrame = CFrame.new(x, top + 0.3, course.startZ - 22), Color = c.color, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.25 })
	course.startPrompt = prompt(pad, "StartPrompt", c.id, "Grab a sled", c.sign)

	course.sledCF = CFrame.lookAt(Vector3.new(x, top + 4, course.startZ - 8), Vector3.new(x, top + 4, course.startZ + 10))
	course.arrivalCF = CFrame.lookAt(Vector3.new(x, top + 5, course.startZ - 48), Vector3.new(x, top + 5, course.startZ))

	-- 리프트 (슬로프 오른쪽 옆)
	local lx = x + w / 2 + 24
	course.liftX = lx
	liftLine(course, lx)
	course.liftPrompt = liftHut(course, lx)
end

-- 슬로프 사이의 낮은 언덕과 나무
local function buildStrip(cx, width, pts, rng, avoidX)
	local lowered = Geo.shifted(pts, STRIP_DROP)
	fillProfile(cx, width, lowered)
	local length = pts[#pts].z - pts[1].z
	local count = math.floor(length / 30 * width / 40)
	for _ = 1, count do
		local z = rng:NextNumber(pts[1].z, pts[#pts].z - 30)
		local tx = cx + rng:NextNumber(-width / 2 + 6, width / 2 - 6)
		if not avoidX or math.abs(tx - avoidX) > 9 then
			local y = math.max(0, Geo.heightAt(lowered, z))
			tree(Vector3.new(tx, y - 1, z), rng:NextNumber(0.8, 1.3))
		end
	end
end

---------------------------------------------------------------- 광장

local function buildPlaza(rng)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = world

	-- 산장 (썰매 차고)
	local lz = 270
	part({ Name = "Lodge", Size = Vector3.new(44, 18, 26), CFrame = CFrame.new(0, 9, lz), Color = Color3.fromRGB(122, 82, 50), Material = Enum.Material.WoodPlanks, Parent = plaza })
	for _, s in ipairs({ -1, 1 }) do
		local roof = part({ Name = "LodgeRoof", Size = Vector3.new(48, 1.4, 17), CFrame = CFrame.new(0, 22, lz + s * 7) * CFrame.Angles(s * math.rad(-32), 0, 0), Color = Color3.fromRGB(122, 47, 59), Parent = plaza })
		roof.CanCollide = true
		part({ Name = "LodgeRoofSnow", Size = Vector3.new(48.6, 0.6, 16), CFrame = CFrame.new(0, 22.9, lz + s * 6.6) * CFrame.Angles(s * math.rad(-32), 0, 0), Color = WHITE, Material = SNOW, Parent = plaza })
	end
	for _, wx in ipairs({ -14, 14 }) do
		part({ Name = "Window", Size = Vector3.new(7, 5, 0.4), CFrame = CFrame.new(wx, 9, lz - 13.1), Color = Color3.fromRGB(255, 217, 138), Material = Enum.Material.Neon, Parent = plaza })
	end
	part({ Name = "Door", Size = Vector3.new(7, 10, 0.4), CFrame = CFrame.new(0, 5, lz - 13.1), Color = Color3.fromRGB(80, 50, 30), Parent = plaza })
	sign(CFrame.new(0, 16, lz - 13.4), Vector3.new(26, 4, 0.4), "SNOWFLAKE LODGE", NAVY, WHITE)

	local counter = part({ Name = "GarageCounter", Size = Vector3.new(10, 3.5, 3), CFrame = CFrame.new(0, 1.75, lz - 22), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = plaza })
	sign(CFrame.new(0, 6, lz - 22), Vector3.new(10, 2.4, 0.3), "SLED GARAGE", Color3.fromRGB(240, 80, 95), WHITE).CanCollide = false
	prompt(counter, "ShopPrompt", nil, "Open garage", "Lodge")

	-- 모닥불 자리
	local fireZ = 200
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		part({ Name = "FireStone", Size = Vector3.new(1.6, 1.2, 1.6), CFrame = CFrame.new(math.cos(a) * 3.4, 0.6, fireZ + math.sin(a) * 3.4), Color = Color3.fromRGB(120, 124, 132), Material = Enum.Material.Slate, Parent = plaza })
	end
	local flame = part({ Name = "Campfire", Size = Vector3.new(2.4, 3, 2.4), CFrame = CFrame.new(0, 1.5, fireZ), Color = Color3.fromRGB(255, 140, 40), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.3, Parent = plaza })
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 8
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Range = 22
	light.Brightness = 2
	light.Parent = flame
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		part({ Name = "Bench", Size = Vector3.new(7, 1, 2), CFrame = CFrame.lookAt(Vector3.new(math.cos(a) * 10, 1.4, fireZ + math.sin(a) * 10), Vector3.new(0, 1.4, fireZ)), Color = WOOD, Material = Enum.Material.Wood, Parent = plaza })
	end

	snowman(Vector3.new(-26, 0, 190), 1.2)
	snowman(Vector3.new(30, 0, 215), 1)

	-- 광장 가장자리 나무
	for _ = 1, 40 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local x = side * rng:NextNumber(70, 300)
		local z = rng:NextNumber(150, 330)
		tree(Vector3.new(x, -1, z), rng:NextNumber(0.9, 1.4))
	end
end

---------------------------------------------------------------- 하늘과 빛

local function setupLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 185, 210)
	Lighting.GlobalShadows = true
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(220, 232, 250)
	atm.Decay = Color3.fromRGB(160, 180, 215)
	atm.Glare = 0.2
	atm.Haze = 1.2
	atm.Parent = Lighting
	terrain:SetMaterialColor(SNOW, Color3.fromRGB(246, 250, 255))
end

---------------------------------------------------------------- 전체

function WorldBuilder.build()
	world = Instance.new("Folder")
	world.Name = "SnowflakePeak"
	world.Parent = Workspace

	-- 1) 처음 들어온 사람이 떨어지지 않게 출발 지점부터
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 225)
	spawn.Color = Color3.fromRGB(150, 200, 255)
	spawn.Material = Enum.Material.Ice
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world

	setupLighting()

	local courses = Geo.build()
	local spacing = Config.COURSE_SPACING
	local minZ = 0
	for _, c in ipairs(courses) do
		minZ = math.min(minZ, c.pts[1].z)
	end

	-- 2) 바닥 눈밭
	local minX = courses[1].x - spacing * 2
	local maxX = courses[#courses].x + spacing * 2
	local z0, z1 = minZ - 160, 360
	terrain:FillBlock(CFrame.new((minX + maxX) / 2, -8, (z0 + z1) / 2), Vector3.new(maxX - minX, 16, z1 - z0), SNOW)

	-- 3) 슬로프와 그 사이 언덕
	local rng = Random.new(7)
	for _, c in ipairs(courses) do
		buildCourse(c)
	end
	local gap = spacing - Config.COURSE_WIDTH
	local first, last = courses[1], courses[#courses]
	buildStrip(first.x - Config.COURSE_WIDTH / 2 - 50, 100, first.pts, rng, nil)
	for i = 1, #courses - 1 do
		local c = courses[i]
		buildStrip(c.x + spacing / 2, gap, c.pts, rng, c.liftX)
	end
	buildStrip(last.x + Config.COURSE_WIDTH / 2 + 50, 100, last.pts, rng, last.liftX)

	-- 4) 광장
	buildPlaza(rng)

	return { courses = courses, spawn = spawn }
end

return WorldBuilder
