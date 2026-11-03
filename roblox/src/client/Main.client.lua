-- 내 화면: 코인, 런 기록, 알림, 썰매 차고, 눈 내리는 효과

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local LocalizationService = game:GetService("LocalizationService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Strings = require(Shared:WaitForChild("Strings"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SledController = require(script.Parent:WaitForChild("SledController"))

local okLocale, localeId = pcall(function()
	return LocalizationService.RobloxLocaleId
end)
local LANG = Strings.lang(okLocale and localeId or "en")
local function T(key, ...)
	return Strings.get(LANG, key, ...)
end

local NAVY = Color3.fromRGB(27, 42, 74)
local WHITE = Color3.fromRGB(255, 255, 255)
local ACCENT = Color3.fromRGB(47, 125, 225)
local MUTED = Color3.fromRGB(91, 107, 135)
local FONT = Enum.Font.FredokaOne
local BODY = Enum.Font.GothamMedium

---------------------------------------------------------------- UI 도우미

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or NAVY
	return new("TextLabel", props)
end

local gui = new("ScreenGui", {
	Name = "SnowflakeHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

---------------------------------------------------------------- 코인

local coinPill = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.new(0, 170, 0, 44),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.08,
	Parent = gui,
}, { corner(22), new("UIStroke", { Color = Color3.fromRGB(200, 220, 245), Thickness = 2 }) })
local coinScale = new("UIScale", { Parent = coinPill })
local coinText = label({ Size = UDim2.fromScale(1, 1), Text = "❄ 0", TextSize = 26, Parent = coinPill })

local shownCoins = 0
local function updateCoins()
	local coins = player:GetAttribute("Coins") or 0
	coinText.Text = "❄ " .. tostring(coins)
	if coins > shownCoins then
		coinScale.Scale = 1.15
		TweenService:Create(coinScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	shownCoins = coins
end

---------------------------------------------------------------- 런 기록판

local runBox = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 58),
	Size = UDim2.new(0, 280, 0, 58),
	BackgroundColor3 = NAVY,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = gui,
}, { corner(14) })
local timerText = label({ Position = UDim2.new(0, 14, 0, 4), Size = UDim2.new(0.5, -14, 1, -8), Text = "0:00.0", TextSize = 30, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, Parent = runBox })
local gateText = label({ Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.5, -14, 0.5, -4), Text = "", TextSize = 18, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Right, Parent = runBox })
local speedText = label({ Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.5, -14, 0.5, -6), Text = "", TextSize = 18, TextColor3 = Color3.fromRGB(170, 210, 255), TextXAlignment = Enum.TextXAlignment.Right, Parent = runBox })

local run = { active = false, startedAt = nil, hits = 0, total = 0 }

RunService.RenderStepped:Connect(function()
	if SledController.driving then
		speedText.Text = string.format("%d km/h", math.floor(SledController.speed + 0.5))
	end
	if run.active and run.startedAt then
		timerText.Text = Strings.time(os.clock() - run.startedAt)
	end
end)

---------------------------------------------------------------- 알림

local toast = label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(0.8, 0, 0, 40),
	Text = "",
	TextSize = 28,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.4,
	TextStrokeColor3 = NAVY,
	TextTransparency = 1,
	TextWrapped = true,
	Parent = gui,
})
local toastId = 0
local function showToast(text, seconds)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	task.delay(seconds or 2.5, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local function popCoins(amount)
	local pop = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0, 200, 0, 40),
		Text = "+" .. amount .. " ❄",
		TextSize = 34,
		TextColor3 = Color3.fromRGB(255, 230, 120),
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = NAVY,
		Parent = gui,
	})
	TweenService:Create(pop, TweenInfo.new(0.8), { Position = UDim2.fromScale(0.5, 0.34), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.9, function()
		pop:Destroy()
	end)
end

---------------------------------------------------------------- 완주 화면

local finishBox = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.new(0, 340, 0, 170),
	BackgroundColor3 = WHITE,
	Visible = false,
	Parent = gui,
}, { corner(18), new("UIStroke", { Color = ACCENT, Thickness = 3 }) })
local finishTitle = label({ Position = UDim2.new(0, 0, 0, 10), Size = UDim2.new(1, 0, 0, 40), Text = "", TextSize = 36, TextColor3 = ACCENT, Parent = finishBox })
local finishTime = label({ Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 0, 40), Text = "", TextSize = 34, Parent = finishBox })
local finishDetail = label({ Position = UDim2.new(0, 0, 0, 96), Size = UDim2.new(1, 0, 0, 26), Text = "", TextSize = 20, Font = BODY, TextColor3 = MUTED, Parent = finishBox })
local finishExtra = label({ Position = UDim2.new(0, 0, 0, 126), Size = UDim2.new(1, 0, 0, 30), Text = "", TextSize = 22, TextColor3 = Color3.fromRGB(230, 120, 40), Parent = finishBox })
local finishId = 0

---------------------------------------------------------------- 페이드 (리프트)

local fade = new("Frame", {
	Size = UDim2.new(1, 0, 1, 80),
	Position = UDim2.new(0, 0, 0, -60),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 1,
	ZIndex = 50,
	Parent = gui,
})

Remotes:WaitForChild("Fade").OnClientEvent:Connect(function()
	TweenService:Create(fade, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	task.delay(0.8, function()
		TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end)
end)

---------------------------------------------------------------- 썰매 차고

local garageButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.new(0, 130, 0, 48),
	BackgroundColor3 = WHITE,
	Text = T("garage_button"),
	Font = FONT,
	TextSize = 22,
	TextColor3 = NAVY,
	AutoButtonColor = true,
	Parent = gui,
}, { corner(14), new("UIStroke", { Color = Color3.fromRGB(200, 220, 245), Thickness = 2 }) })

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.82),
	BackgroundColor3 = Color3.fromRGB(244, 248, 253),
	Visible = false,
	ZIndex = 10,
	Parent = gui,
}, { corner(18), new("UISizeConstraint", { MaxSize = Vector2.new(460, 480) }), new("UIStroke", { Color = Color3.fromRGB(200, 220, 245), Thickness = 2 }) })
label({ Position = UDim2.new(0, 18, 0, 10), Size = UDim2.new(1, -90, 0, 40), Text = T("garage_title"), TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11, Parent = panel })
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.new(0, 64, 0, 34),
	BackgroundColor3 = Color3.fromRGB(225, 233, 244),
	Text = T("close"),
	Font = FONT,
	TextSize = 18,
	TextColor3 = NAVY,
	ZIndex = 11,
	Parent = panel,
}, { corner(10) })
local list = new("ScrollingFrame", {
	Position = UDim2.new(0, 12, 0, 58),
	Size = UDim2.new(1, -24, 1, -70),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 11,
	Parent = panel,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function sectionTitle(text, order)
	label({ Size = UDim2.new(1, 0, 0, 28), Text = text, TextSize = 20, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 11, Parent = list })
end

local function row(order, color, title, detail, buttonText, buttonEnabled, onClick)
	local r = new("Frame", { Size = UDim2.new(1, -8, 0, 60), BackgroundColor3 = WHITE, LayoutOrder = order, ZIndex = 11, Parent = list }, { corner(12) })
	new("Frame", { Position = UDim2.new(0, 10, 0.5, -16), Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = color, ZIndex = 12, Parent = r }, { corner(8) })
	label({ Position = UDim2.new(0, 52, 0, 8), Size = UDim2.new(1, -170, 0, 24), Text = title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12, Parent = r })
	label({ Position = UDim2.new(0, 52, 0, 32), Size = UDim2.new(1, -170, 0, 20), Text = detail, TextSize = 15, Font = BODY, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12, Parent = r })
	if buttonText then
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 108, 0, 38),
			BackgroundColor3 = buttonEnabled and ACCENT or Color3.fromRGB(215, 223, 235),
			Text = buttonText,
			Font = FONT,
			TextSize = 17,
			TextColor3 = buttonEnabled and WHITE or MUTED,
			AutoButtonColor = buttonEnabled,
			ZIndex = 12,
			Parent = r,
		}, { corner(10) })
		if buttonEnabled and onClick then
			b.Activated:Connect(onClick)
		end
	end
end

local BuySled = Remotes:WaitForChild("BuySled")

local function renderGarage()
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local coins = player:GetAttribute("Coins") or 0
	local level = player:GetAttribute("SledLevel") or 1

	sectionTitle(T("sleds_title"), 0)
	for i, s in ipairs(Config.Sleds) do
		local text, enabled = nil, false
		if i == level then
			text = T("riding")
		elseif i < level then
			text = T("owned")
		elseif i == level + 1 then
			text = T("buy", s.price)
			enabled = coins >= s.price
		else
			text = T("locked")
		end
		row(i, s.color, T("sled_" .. s.id), T("top_speed", s.speed), text, enabled, function()
			BuySled:FireServer(i)
		end)
	end

	sectionTitle(T("slopes_title"), 100)
	for i, c in ipairs(Config.Courses) do
		local detail
		if player:GetAttribute("Unlocked_" .. c.id) then
			local best = player:GetAttribute("Best_" .. c.id)
			detail = T("slope_open", tostring(c.mult)) .. " · " .. (best and T("best", Strings.time(best)) or T("no_best"))
		else
			detail = T("slope_locked", c.price)
		end
		row(100 + i, c.color, T("course_" .. c.id), detail, nil, false, nil)
	end
end

local function setGarage(open)
	panel.Visible = open
	if open then
		renderGarage()
	end
end

garageButton.Activated:Connect(function()
	setGarage(not panel.Visible)
end)
closeButton.Activated:Connect(function()
	setGarage(false)
end)

---------------------------------------------------------------- 리프트·출발대 안내 글자

local function refreshPrompt(prompt)
	local id = prompt:GetAttribute("CourseId")
	if CollectionService:HasTag(prompt, "ShopPrompt") then
		prompt.ActionText = T("garage_open")
		prompt.ObjectText = T("lodge")
		return
	end
	local course = id and Config.courseById(id)
	if not course then
		return
	end
	local name = T("course_" .. id)
	if CollectionService:HasTag(prompt, "LiftPrompt") then
		prompt.ObjectText = T("lift_object", name)
		if player:GetAttribute("Unlocked_" .. id) then
			prompt.ActionText = T("lift_ride")
		else
			prompt.ActionText = T("lift_unlock", course.price)
		end
	elseif CollectionService:HasTag(prompt, "StartPrompt") then
		prompt.ObjectText = T("start_object", name)
		prompt.ActionText = T("start_ride")
	end
end

local function refreshAllPrompts()
	for _, tag in ipairs({ "LiftPrompt", "StartPrompt", "ShopPrompt" }) do
		for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
			refreshPrompt(prompt)
		end
	end
end

for _, tag in ipairs({ "LiftPrompt", "StartPrompt", "ShopPrompt" }) do
	CollectionService:GetInstanceAddedSignal(tag):Connect(refreshPrompt)
end
ProximityPromptService.PromptShown:Connect(function(prompt)
	refreshPrompt(prompt)
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if CollectionService:HasTag(prompt, "ShopPrompt") then
		setGarage(true)
	end
end)

---------------------------------------------------------------- 서버 메시지

local function nameOf(data)
	if data.course then
		return T("course_" .. data.course)
	elseif data.sled then
		return T("sled_" .. data.sled)
	end
	return ""
end

Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(key, data)
	data = data or {}
	if key == "need_coins" then
		showToast(T("need_coins", nameOf(data), data.amount or 0), 3)
	elseif key == "unlocked" or key == "sled_bought" then
		showToast(T(key, nameOf(data)), 3)
	else
		showToast(T(key), 4)
	end
end)

Remotes:WaitForChild("Run").OnClientEvent:Connect(function(kind, data)
	data = data or {}
	if kind == "ready" then
		setGarage(false)
		run.active, run.startedAt, run.hits, run.total = true, nil, 0, data.total or 0
		runBox.Visible = true
		timerText.Text = "0:00.0"
		gateText.Text = T("gates", 0, run.total)
		showToast(T("hint_push"), 3)
	elseif kind == "start" then
		run.startedAt = os.clock()
	elseif kind == "gate" then
		run.hits = data.hits or run.hits
		gateText.Text = T("gates", run.hits, data.total or run.total)
		popCoins(data.coins or 0)
	elseif kind == "miss" then
		gateText.Text = T("gates", data.hits or run.hits, data.total or run.total)
	elseif kind == "finish" then
		run.active = false
		timerText.Text = Strings.time(data.time or 0)
		finishId += 1
		local id = finishId
		finishTitle.Text = T("finish_title")
		finishTime.Text = T("finish_time", Strings.time(data.time or 0))
		finishDetail.Text = T("finish_detail", data.hits or 0, data.total or 0, data.coins or 0)
		local extras = {}
		if data.best then
			table.insert(extras, T("new_best"))
		end
		if data.perfect then
			table.insert(extras, T("perfect"))
		end
		finishExtra.Text = table.concat(extras, "  ")
		finishBox.Visible = true
		task.delay(4, function()
			if id == finishId then
				finishBox.Visible = false
			end
		end)
	elseif kind == "ended" then
		run.active = false
		task.delay(2, function()
			if not run.active then
				runBox.Visible = false
			end
		end)
	end
end)

---------------------------------------------------------------- 속성 변화 반영

player.AttributeChanged:Connect(function(name)
	if name == "Coins" then
		updateCoins()
	end
	if panel.Visible then
		renderGarage()
	end
	if string.sub(name, 1, 9) == "Unlocked_" then
		refreshAllPrompts()
	end
end)
updateCoins()
refreshAllPrompts()

---------------------------------------------------------------- 눈 내리는 효과

local snowPart = new("Part", {
	Name = "Snowfall",
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	Transparency = 1,
	Size = Vector3.new(140, 1, 140),
	Parent = Workspace,
})
new("ParticleEmitter", {
	Rate = 160,
	Lifetime = NumberRange.new(6, 8),
	Speed = NumberRange.new(5, 9),
	SpreadAngle = Vector2.new(15, 15),
	EmissionDirection = Enum.NormalId.Bottom,
	Size = NumberSequence.new(0.3),
	Color = ColorSequence.new(WHITE),
	LightEmission = 0.4,
	Acceleration = Vector3.new(1.5, 0, 0.8),
	Parent = snowPart,
})
RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if cam then
		snowPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 35, 0))
	end
end)

SledController.start()
