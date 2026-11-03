-- 플레이어 저장 데이터 (코인, 썰매 단계, 해금한 슬로프, 최고 기록)
-- DataStore에 저장해요. Studio에서 API 접근을 켜지 않았으면 저장 없이 테스트 모드로 동작해요.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerData = {}

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore(Config.DATA_STORE)
end)

local profiles = {} -- [player] = { data = {...}, canSave = bool, dirty = bool }

local function keyFor(player)
	return "p_" .. player.UserId
end

local function defaults()
	local d = { coins = 0, sled = 1, unlocked = {}, best = {}, runs = 0 }
	for _, c in ipairs(Config.Courses) do
		if c.price <= 0 then
			d.unlocked[c.id] = true
		end
	end
	return d
end

local function reconcile(saved)
	local d = defaults()
	if type(saved) ~= "table" then
		return d
	end
	if type(saved.coins) == "number" then
		d.coins = math.max(0, math.floor(saved.coins))
	end
	if type(saved.sled) == "number" then
		d.sled = math.clamp(math.floor(saved.sled), 1, #Config.Sleds)
	end
	if type(saved.unlocked) == "table" then
		for id, v in pairs(saved.unlocked) do
			if v == true and Config.courseById(id) then
				d.unlocked[id] = true
			end
		end
	end
	if type(saved.best) == "table" then
		for id, v in pairs(saved.best) do
			if type(v) == "number" and v > 0 and Config.courseById(id) then
				d.best[id] = v
			end
		end
	end
	if type(saved.runs) == "number" then
		d.runs = math.max(0, math.floor(saved.runs))
	end
	return d
end

function PlayerData.load(player)
	local saved, canSave = nil, false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				saved, canSave = result, true
				break
			end
			warn("[PlayerData] 불러오기 실패 (" .. attempt .. "/3): " .. tostring(result))
			if attempt < 3 then
				task.wait(1.5 * attempt)
			end
		end
	end
	if player.Parent == nil then
		return nil
	end
	local profile = { data = reconcile(saved), canSave = canSave, dirty = false }
	profiles[player] = profile
	return profile
end

function PlayerData.get(player)
	local p = profiles[player]
	return p and p.data or nil
end

function PlayerData.save(player)
	local p = profiles[player]
	if not p or not p.canSave or not store or not p.dirty then
		return
	end
	local data = p.data
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if ok then
		p.dirty = false
	else
		warn("[PlayerData] 저장 실패: " .. tostring(err))
	end
end

function PlayerData.release(player)
	PlayerData.save(player)
	profiles[player] = nil
end

function PlayerData.saveAll()
	local pending = 0
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function()
			PlayerData.save(player)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 25 do
		waited += task.wait(0.5)
	end
end

-- 화면(클라이언트)이 읽을 수 있게 플레이어 속성과 리더보드에 반영
function PlayerData.sync(player)
	local p = profiles[player]
	if not p then
		return
	end
	local d = p.data
	player:SetAttribute("Coins", d.coins)
	player:SetAttribute("SledLevel", d.sled)
	for _, c in ipairs(Config.Courses) do
		player:SetAttribute("Unlocked_" .. c.id, d.unlocked[c.id] == true)
		player:SetAttribute("Best_" .. c.id, d.best[c.id])
	end
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins then
		coins.Value = d.coins
	end
end

local function changed(player)
	local p = profiles[player]
	if p then
		p.dirty = true
	end
	PlayerData.sync(player)
end

function PlayerData.addCoins(player, amount)
	local d = PlayerData.get(player)
	if not d or amount <= 0 then
		return
	end
	d.coins += math.floor(amount)
	changed(player)
end

function PlayerData.trySpend(player, amount)
	local d = PlayerData.get(player)
	if not d or d.coins < amount then
		return false
	end
	d.coins -= amount
	changed(player)
	return true
end

function PlayerData.isUnlocked(player, courseId)
	local d = PlayerData.get(player)
	return d ~= nil and d.unlocked[courseId] == true
end

function PlayerData.unlock(player, courseId)
	local d = PlayerData.get(player)
	if d then
		d.unlocked[courseId] = true
		changed(player)
	end
end

function PlayerData.setSled(player, level)
	local d = PlayerData.get(player)
	if d then
		d.sled = level
		changed(player)
	end
end

-- 새 최고 기록이면 true
function PlayerData.recordTime(player, courseId, seconds)
	local d = PlayerData.get(player)
	if not d then
		return false
	end
	d.runs += 1
	local old = d.best[courseId]
	local isBest = old == nil or seconds < old
	if isBest then
		d.best[courseId] = math.floor(seconds * 100 + 0.5) / 100
	end
	changed(player)
	return isBest
end

return PlayerData
