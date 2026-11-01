--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local WindboundShared = ReplicatedStorage:WaitForChild("Windbound")
local GameConfig = require(WindboundShared.Config:WaitForChild("GameConfig") :: ModuleScript)
local DrifterConfig = require(WindboundShared.Config:WaitForChild("DrifterConfig") :: ModuleScript)
local NetworkService = require(WindboundShared.Network:WaitForChild("NetworkService") :: ModuleScript)

local DrifterServerService = {}

type ActiveDrifter = {
	Model: Model,
	Stats: any,
	HomeAnchor: Vector3,
	CurrentTarget: Vector3,
	BaseY: number,
	Speed: number,
	NextWaypointTime: number,
	IsCaptured: boolean,
	IsFleeing: boolean,
	FleeWaypoints: { Vector3 },
	FleeIndex: number,
	FleeTrail: ParticleEmitter?,
}

local activeDrifters: { [Model]: ActiveDrifter } = {}

type ActiveWeave = {
	Player: Player,
	DrifterModel: Model,
	StartTime: number,
	CheckpointsCompleted: number,
}
local activeWeaves: { [Player]: ActiveWeave } = {}

-- Defined Spawning Anchor Points directly at the Skywind Launch Pad
local SPAWN_ANCHORS = {
	Vector3.new(138, 172, 0),   -- Directly above the Launch Pad disc (8 studs up)
	Vector3.new(170, 173, 0),   -- 32 studs ahead in the open sky
	Vector3.new(155, 175, 20),  -- Off the right wing of the Launch Pad
}

function DrifterServerService.init()
	local driftersFolder = Workspace:FindFirstChild("Drifters")
	if not driftersFolder then
		driftersFolder = Instance.new("Folder")
		driftersFolder.Name = "Drifters"
		driftersFolder.Parent = Workspace
	end
	
	driftersFolder:ClearAllChildren()
	activeDrifters = {}
	
	for _, anchor in ipairs(SPAWN_ANCHORS) do
		DrifterServerService.spawnDrifter("Leafglider", anchor)
	end
	
	NetworkService.onCaptureEvent(function(player: Player, eventType: string, data: any)
		if eventType == "RequestStartWeave" then
			DrifterServerService.handleStartWeave(player, data)
		elseif eventType == "CompleteWeave" then
			DrifterServerService.handleCompleteWeave(player, data)
		end
	end)
	
	task.spawn(function()
		while true do
			local dt = task.wait(0.08)
			DrifterServerService.stepAI(dt)
		end
	end)
	
	print("[DrifterServerService] Initialized with chase-enabled wild Drifters.")
end

function DrifterServerService.spawnDrifter(drifterId: string, anchor: Vector3)
	local stats = DrifterConfig.getDrifter(drifterId)
	if not stats then return end
	
	local assets = WindboundShared:FindFirstChild("Assets")
	local drifterAssets = assets and assets:FindFirstChild("Drifters")
	local template = drifterAssets and drifterAssets:FindFirstChild(drifterId) :: Model?
	if not template then return end
	
	local driftersFolder = Workspace:WaitForChild("Drifters")
	local drifter = template:Clone()
	drifter.Name = string.format("Drifter_%s_%d", drifterId, math.floor(os.clock()))
	
	local root = drifter.PrimaryPart or drifter:FindFirstChild("RootPart") :: BasePart?
	if not root then
		drifter:Destroy()
		return
	end
	
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = CFrame.lookAt(anchor, anchor + Vector3.new(1, 0, 0))
	
	for _, desc in drifter:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
		end
	end
	
	CollectionService:AddTag(drifter, GameConfig.Tags.Drifter)
	drifter.Parent = driftersFolder
	
	activeDrifters[drifter] = {
		Model = drifter,
		Stats = stats,
		HomeAnchor = anchor,
		CurrentTarget = anchor + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)),
		BaseY = anchor.Y,
		Speed = stats.Speed,
		NextWaypointTime = os.clock() + math.random(5, 8),
		IsCaptured = false,
		IsFleeing = false,
		FleeWaypoints = {},
		FleeIndex = 1,
		FleeTrail = nil,
	}
end

function DrifterServerService.stepAI(dt: number)
	local now = os.clock()
	
	for model, data in activeDrifters do
		if data.IsCaptured or not model.Parent then
			continue
		end
		
		local root = model.PrimaryPart
		if not root then continue end
		
		if data.IsFleeing then
			-- ACTIVE CHASE: Fleeing along escape flight path
			local targetWP = data.FleeWaypoints[data.FleeIndex]
			if targetWP then
				local currentPos = root.Position
				local toWP = (targetWP - currentPos)
				local dist = toWP.Magnitude
				
				if dist > 1.0 then
					local stepDist = math.min(dist, data.Speed * dt)
					local newPos = currentPos + (toWP.Unit * stepDist)
					local lookAtPos = currentPos + (toWP.Unit * 10)
					local targetCF = CFrame.lookAt(newPos, lookAtPos)
					model:PivotTo(targetCF)
				else
					-- Reached waypoint, advance to next
					if data.FleeIndex < #data.FleeWaypoints then
						data.FleeIndex += 1
					else
						-- Hovering at final destination awaiting capture
						local bob = math.sin(now * 3) * 0.8
						local targetCF = CFrame.new(targetWP + Vector3.new(0, bob, 0)) * root.CFrame.Rotation
						model:PivotTo(targetCF)
					end
				end
			end
		else
			-- AMBIENT IDLE WANDER & BOBBING
			if now >= data.NextWaypointTime then
				local rad = 12
				local randOffset = Vector3.new(
					math.random(-rad, rad),
					math.random(-2, 2),
					math.random(-rad, rad)
				)
				data.CurrentTarget = data.HomeAnchor + randOffset
				data.NextWaypointTime = now + math.random(5, 8)
			end
			
			local bob = math.sin(now * data.Stats.HoverBobFrequency * math.pi * 2) * data.Stats.HoverBobAmplitude
			local targetWithBob = Vector3.new(data.CurrentTarget.X, data.BaseY + bob, data.CurrentTarget.Z)
			
			local currentPos = root.Position
			local moveDir = (targetWithBob - currentPos)
			local dist = moveDir.Magnitude
			
			if dist > 0.1 then
				local stepDist = math.min(dist, data.Speed * dt)
				local newPos = currentPos + (moveDir.Unit * stepDist)
				
				local horizDir = Vector3.new(moveDir.X, 0, moveDir.Z)
				if horizDir.Magnitude > 0.2 then
					local targetCF = CFrame.lookAt(newPos, newPos + horizDir.Unit)
					model:PivotTo(targetCF)
				else
					local currentRot = root.CFrame.Rotation
					model:PivotTo(CFrame.new(newPos) * currentRot)
				end
			end
		end
	end
end

function DrifterServerService.handleStartWeave(player: Player, data: any)
	local drifter = data and data.drifterModel :: Model?
	if not drifter then return end
	local drifterData = activeDrifters[drifter]
	if not drifterData or drifterData.IsCaptured or drifterData.IsFleeing then return end
	
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or not drifter.PrimaryPart then return end
	
	local dist = (hrp.Position - drifter.PrimaryPart.Position).Magnitude
	local maxDist = drifterData.Stats.CaptureRadius + 25
	
	if dist <= maxDist then
		activeWeaves[player] = {
			Player = player,
			DrifterModel = drifter,
			StartTime = os.clock(),
			CheckpointsCompleted = 0,
		}
		
		-- INITIATE CHASE: Start fleeing into the open sky!
		drifterData.IsFleeing = true
		drifterData.Speed = 16.5 -- Catchable chase speed (glider flies at 22-26)
		
		local root = drifter.PrimaryPart
		local startPos = root.Position
		
		-- Flee outward along +X into the open sky with exciting banking turns!
		-- WP1: 42 studs ahead, slight rise
		-- WP2: 90 studs ahead, bank right
		-- WP3: 140 studs ahead, sweeping center
		local wp1 = startPos + Vector3.new(42, 3, -4)
		local wp2 = startPos + Vector3.new(90, 6, 14)
		local wp3 = startPos + Vector3.new(140, 4, -2)
		
		drifterData.FleeWaypoints = { wp1, wp2, wp3 }
		drifterData.FleeIndex = 1
		
		-- Create fleeing slipstream trail on drifter
		local trail = Instance.new("ParticleEmitter")
		trail.Name = "ChaseSlipstream"
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 200, 255))
		})
		trail.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.8),
			NumberSequenceKeypoint.new(1, 0)
		})
		trail.Transparency = NumberSequence.new(0.3)
		trail.Lifetime = NumberRange.new(1.0, 1.8)
		trail.Rate = 35
		trail.Speed = NumberRange.new(4, 8)
		trail.SpreadAngle = Vector2.new(15, 15)
		trail.Parent = root
		drifterData.FleeTrail = trail
		
		-- Send confirmation to client to spawn vertical hoops along the chase trajectory
		NetworkService.Remotes.CaptureEvent:FireClient(player, "WeaveStarted", {
			drifter = drifter,
			stats = drifterData.Stats,
			timeLimit = 28, -- Generous 28-second chase timer
			waypoints = {
				{ pos = wp1, dir = (wp2 - wp1).Unit },
				{ pos = wp2, dir = (wp3 - wp2).Unit },
				{ pos = wp3, dir = Vector3.new(1, 0, 0) },
			}
		})
		print(string.format("[DrifterServerService] %s initiated chase with %s! Fleeing across sky.",
			player.Name, drifter.Name))
	end
end

function DrifterServerService.handleCompleteWeave(player: Player, data: any)
	local weave = activeWeaves[player]
	if not weave then return end
	
	local drifter = weave.DrifterModel
	local drifterData = activeDrifters[drifter]
	if not drifterData or drifterData.IsCaptured then return end
	
	local timeTaken = os.clock() - weave.StartTime
	if timeTaken > 32.0 then
		activeWeaves[player] = nil
		drifterData.IsFleeing = false
		return
	end
	
	drifterData.IsCaptured = true
	activeWeaves[player] = nil
	
	if drifterData.FleeTrail then
		drifterData.FleeTrail:Destroy()
		drifterData.FleeTrail = nil
	end
	
	print(string.format("[DrifterServerService] Player %s caught %s after chase in %.1fs!",
		player.Name, drifterData.Stats.DisplayName, timeTaken))
	
	NetworkService.Remotes.CaptureEvent:FireClient(player, "CaptureSuccess", {
		drifterName = drifterData.Stats.DisplayName,
		exp = drifterData.Stats.ExpReward + 10,
		rarity = drifterData.Stats.Rarity,
	})
	
	-- Golden victory celebration & dissolve
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.06)
			for _, desc in drifter:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.Transparency = i * 0.1
				end
			end
		end
		activeDrifters[drifter] = nil
		local anchor = drifterData.HomeAnchor
		local id = drifterData.Stats.Id
		drifter:Destroy()
		
		task.wait(8)
		DrifterServerService.spawnDrifter(id, anchor)
	end)
end

return DrifterServerService
