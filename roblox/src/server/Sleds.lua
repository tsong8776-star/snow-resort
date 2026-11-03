-- 썰매 만들기와 한 판(런) 기록
-- 조종은 클라이언트(SledController)가 하고, 서버는 깃발 통과와 완주를 확인해서 코인을 줘요.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Sleds = {}

local active = {} -- [player] = run
local folder
local RunEvent
local PlayerData

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function makePart(name, size, cf, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildModel(player, sledCfg)
	local model = Instance.new("Model")
	model.Name = player.Name .. "_Sled"

	local base = makePart("Base", Vector3.new(4.2, 0.8, 7.5), CFrame.new(), sledCfg.color, model)
	-- 마찰 0: 눈 위를 미끄러지게
	base.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0, 0, 100, 1)
	model.PrimaryPart = base

	-- 앞쪽이 위로 말린 썰매 코
	local nose = makePart("Nose", Vector3.new(4.2, 0.6, 2), CFrame.new(0, 0.55, -4.1) * CFrame.Angles(math.rad(35), 0, 0), sledCfg.color, model)
	nose.CanCollide = false
	nose.Massless = true
	weld(base, nose)

	for _, sx in ipairs({ -1.95, 1.95 }) do
		local rail = makePart("Rail", Vector3.new(0.3, 0.6, 7), CFrame.new(sx, 0.6, 0.2), sledCfg.trim, model)
		rail.CanCollide = false
		rail.Massless = true
		weld(base, rail)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.6, 0.4, 2.6)
	seat.CFrame = CFrame.new(0, 0.6, 0.9)
	seat.Color = sledCfg.trim
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.Massless = true
	seat.CanCollide = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.Parent = model
	weld(base, seat)

	-- 썰매가 뒤집히지 않게 방향을 잡아 주는 장치 (목표 방향은 클라이언트가 정해요)
	local att = Instance.new("Attachment")
	att.Name = "AlignAtt"
	att.Parent = base
	local align = Instance.new("AlignOrientation")
	align.Name = "Align"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.MaxTorque = 1e7
	align.Responsiveness = 35
	align.Parent = base

	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("MaxSpeed", sledCfg.speed)
	return model, base, seat, align
end

local function fire(player, kind, data)
	if player.Parent then
		RunEvent:FireClient(player, kind, data)
	end
end

function Sleds.remove(player)
	local run = active[player]
	if not run then
		return
	end
	active[player] = nil
	if run.model then
		run.model:Destroy()
	end
	fire(player, "ended", {})
end

function Sleds.spawn(player, course)
	Sleds.remove(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not char:FindFirstChild("HumanoidRootPart") then
		return
	end
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local sledCfg = Config.Sleds[data.sled] or Config.Sleds[1]
	local model, base, seat, align = buildModel(player, sledCfg)
	local cf = course.sledCF
	align.CFrame = cf.Rotation
	model:PivotTo(cf)
	model.Parent = folder
	char:PivotTo(cf * CFrame.new(0, 3, 0.9))
	seat:Sit(hum)
	pcall(function()
		base:SetNetworkOwner(player)
	end)
	active[player] = {
		model = model,
		base = base,
		seat = seat,
		course = course,
		sledCfg = sledCfg,
		passed = {},
		hits = 0,
		lastPos = base.Position,
		startTime = nil,
		finished = false,
		leftAt = nil,
		spawnedAt = os.clock(),
	}
	fire(player, "ready", { course = course.cfg.id, total = #course.gates })
end

local function finish(player, run)
	run.finished = true
	local course = run.course
	local t = os.clock() - run.startTime
	-- 최고 속도로도 불가능한 기록은 무시 (부정행위 방지)
	local minTime = course.mainLen / (run.sledCfg.speed * 1.2)
	if t < minTime then
		warn("[Sleds] 너무 빠른 완주 기록 무시: " .. player.Name .. " " .. t)
		return
	end
	local mult = course.cfg.mult
	local total = #course.gates
	local perfect = total > 0 and run.hits == total
	local coins = math.floor(Config.FINISH_COINS * mult + 0.5)
	if perfect then
		coins += math.floor(Config.PERFECT_BONUS * mult + 0.5)
	end
	local isBest = PlayerData.recordTime(player, course.cfg.id, t)
	if isBest then
		coins += math.floor(Config.BEST_BONUS * mult + 0.5)
	end
	PlayerData.addCoins(player, coins)
	fire(player, "finish", {
		course = course.cfg.id,
		time = t,
		coins = coins,
		hits = run.hits,
		total = total,
		perfect = perfect,
		best = isBest,
	})
end

local function step(player, run)
	local base = run.base
	if not base.Parent or not player.Parent then
		Sleds.remove(player)
		return
	end
	local pos = base.Position
	if pos.Y < -80 then
		Sleds.remove(player)
		return
	end

	-- 썰매에서 내리고 3초가 지나면 썰매를 치워요
	local occupant = run.seat.Occupant
	local seated = occupant ~= nil and player.Character ~= nil and occupant.Parent == player.Character
	if seated then
		run.leftAt = nil
	elseif os.clock() - run.spawnedAt > 1.5 then
		run.leftAt = run.leftAt or os.clock()
		if os.clock() - run.leftAt > 3 then
			Sleds.remove(player)
			return
		end
	end

	local course = run.course
	local prev = run.lastPos
	run.lastPos = pos
	if run.finished or not seated then
		return
	end

	-- 출발선을 넘으면 시간 재기 시작
	if not run.startTime then
		if prev.Z < course.startZ and pos.Z >= course.startZ then
			run.startTime = os.clock()
			fire(player, "start", {})
		end
		return
	end

	local function crossX(z)
		local dz = pos.Z - prev.Z
		if dz == 0 then
			return pos.X
		end
		return prev.X + (pos.X - prev.X) * (z - prev.Z) / dz
	end

	for i, gate in ipairs(course.gates) do
		if not run.passed[i] and prev.Z < gate.z and pos.Z >= gate.z then
			run.passed[i] = true
			if math.abs(crossX(gate.z) - gate.x) <= gate.half then
				run.hits += 1
				local coins = math.floor(Config.GATE_COINS * course.cfg.mult + 0.5)
				PlayerData.addCoins(player, coins)
				fire(player, "gate", { coins = coins, hits = run.hits, total = #course.gates })
			else
				fire(player, "miss", { hits = run.hits, total = #course.gates })
			end
		end
	end

	if prev.Z < course.finishZ and pos.Z >= course.finishZ and math.abs(crossX(course.finishZ) - course.x) <= course.width / 2 + 10 then
		finish(player, run)
	end
end

function Sleds.init(runEvent, playerData)
	RunEvent = runEvent
	PlayerData = playerData
	folder = Instance.new("Folder")
	folder.Name = "Sleds"
	folder.Parent = Workspace

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		for player, run in pairs(active) do
			step(player, run)
		end
	end)
end

return Sleds
