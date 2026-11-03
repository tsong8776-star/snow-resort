-- Snowflake Peak 서버 시작점
-- 1) 클라이언트와 주고받을 통로(Remote) 만들기  2) 스키장 만들기  3) 플레이어 저장·리프트·썰매 연결

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PlayerData = require(script.Parent.PlayerData)
local WorldBuilder = require(script.Parent.WorldBuilder)
local Sleds = require(script.Parent.Sleds)

---------------------------------------------------------------- 통로

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local Notify = remote("Notify") -- 서버 → 화면 알림
local RunEvent = remote("Run") -- 서버 → 화면 런 진행 상황
local Fade = remote("Fade") -- 서버 → 화면 페이드 (리프트 이동)
local BuySled = remote("BuySled") -- 화면 → 서버 썰매 구매
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- 스키장

local world = WorldBuilder.build()
Sleds.init(RunEvent, PlayerData)

local busy = {} -- 버튼 연타 방지
local function debounce(player, seconds)
	local now = os.clock()
	if busy[player] and now - busy[player] < seconds then
		return false
	end
	busy[player] = now
	return true
end

local function notify(player, key, data)
	if player.Parent then
		Notify:FireClient(player, key, data or {})
	end
end

local function teleport(player, cf)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	Fade:FireClient(player)
	task.wait(0.35)
	Sleds.remove(player)
	if char.Parent then
		char:PivotTo(cf)
	end
end

local function useLift(player, course)
	if not debounce(player, 1) then
		return
	end
	local id = course.cfg.id
	if not PlayerData.isUnlocked(player, id) then
		local price = course.cfg.price
		if PlayerData.trySpend(player, price) then
			PlayerData.unlock(player, id)
			notify(player, "unlocked", { course = id })
		else
			local data = PlayerData.get(player)
			local need = price - (data and data.coins or 0)
			notify(player, "need_coins", { course = id, amount = need })
			return
		end
	end
	teleport(player, course.arrivalCF)
end

local function useStart(player, course)
	if not debounce(player, 1) then
		return
	end
	if not PlayerData.isUnlocked(player, course.cfg.id) then
		return
	end
	Sleds.spawn(player, course)
end

for _, course in ipairs(world.courses) do
	course.liftPrompt.Triggered:Connect(function(player)
		useLift(player, course)
	end)
	course.startPrompt.Triggered:Connect(function(player)
		useStart(player, course)
	end)
end

BuySled.OnServerEvent:Connect(function(player, level)
	if type(level) ~= "number" or not debounce(player, 0.5) then
		return
	end
	local data = PlayerData.get(player)
	if not data or level ~= data.sled + 1 then
		return
	end
	local sled = Config.Sleds[level]
	if not sled then
		return
	end
	if PlayerData.trySpend(player, sled.price) then
		PlayerData.setSled(player, level)
		notify(player, "sled_bought", { sled = sled.id })
	else
		notify(player, "need_coins", { sled = sled.id, amount = sled.price - data.coins })
	end
end)

---------------------------------------------------------------- 플레이어

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	stats.Parent = player

	local profile = PlayerData.load(player)
	if not profile then
		return
	end
	PlayerData.sync(player)
	if not profile.canSave then
		task.delay(5, function()
			notify(player, "no_save")
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	Sleds.remove(player)
	PlayerData.release(player)
end)

task.spawn(function()
	while true do
		task.wait(Config.AUTOSAVE_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(PlayerData.save, player)
		end
	end
end)

game:BindToClose(function()
	PlayerData.saveAll()
end)
