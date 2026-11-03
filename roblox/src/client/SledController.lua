-- 썰매 조종 (내 화면에서 계산)
-- A/D 또는 왼쪽 조이스틱: 방향 전환, W: 밀기, S: 브레이크, 스페이스(점프): 내리기

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local SledController = {}
SledController.speed = 0 -- 화면에 보여 줄 현재 속도
SledController.driving = false

local TURN_RATE = 1.9 -- 초당 회전 (라디안)
local GRIP = 5 -- 옆으로 미끄러지는 걸 얼마나 빨리 잡는지
local PUSH = 45 -- W 키로 밀 때 가속
local PUSH_LIMIT = 30 -- 이 속도보다 느릴 때만 밀 수 있어요
local BRAKE = 2

local conn

local function stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	SledController.driving = false
	SledController.speed = 0
end

local function drive(seat, humanoid)
	stop()
	local sled = seat.Parent
	local base = sled:WaitForChild("Base", 5)
	local align = base and base:WaitForChild("Align", 5)
	if not align then
		return
	end
	SledController.driving = true

	-- 방향각: 0이면 -Z를 바라봐요 (로블록스 기본)
	local look = base.CFrame.LookVector
	local heading = math.atan2(-look.X, -look.Z)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { sled, player.Character }

	conn = RunService.Heartbeat:Connect(function(dt)
		if seat.Occupant ~= humanoid or not base.Parent then
			stop()
			return
		end
		local maxSpeed = sled:GetAttribute("MaxSpeed") or 70
		local steer = seat.SteerFloat
		local throttle = seat.ThrottleFloat

		heading -= steer * TURN_RATE * dt

		local hit = Workspace:Raycast(base.Position, Vector3.new(0, -6, 0), params)
		local up = hit and hit.Normal or Vector3.yAxis
		local flat = Vector3.new(-math.sin(heading), 0, -math.cos(heading))
		local fwd = flat - up * flat:Dot(up)
		if fwd.Magnitude < 1e-3 then
			fwd = flat
		end
		fwd = fwd.Unit
		align.CFrame = CFrame.lookAt(Vector3.zero, fwd, up)

		local v = base.AssemblyLinearVelocity
		if hit then
			-- 눈에 닿아 있을 때: 옆미끄러짐을 앞으로 바꿔 주는 '카빙'
			local upV = up * v:Dot(up)
			local along = v:Dot(fwd)
			local side = v - upV - fwd * along
			local grip = math.clamp(dt * GRIP, 0, 1)
			local carry = side.Magnitude * grip * 0.5
			if along >= 0 then
				along += carry
			else
				along -= carry
			end
			if throttle > 0.1 and along < PUSH_LIMIT then
				along += PUSH * dt
			elseif throttle < -0.1 then
				along *= 1 - math.clamp(dt * BRAKE, 0, 1)
			end
			v = upV + fwd * along + side * (1 - grip)
		end
		local s = v.Magnitude
		if s > maxSpeed then
			v = v * (maxSpeed / s)
			s = maxSpeed
		end
		base.AssemblyLinearVelocity = v
		SledController.speed = s
	end)
end

local function bind(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart:IsA("VehicleSeat") and seatPart.Parent and seatPart.Parent:GetAttribute("OwnerId") == player.UserId then
			drive(seatPart, humanoid)
		elseif not active then
			stop()
		end
	end)
end

function SledController.start()
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		stop()
		bind(character)
	end)
end

return SledController
