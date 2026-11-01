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
}

local activeDrifters: { [Model]: ActiveDrifter } = {}

type ActiveWeave = {
	Player: Player,
	DrifterModel: Model,
	StartTime: number,
	CheckpointsCompleted: number,
}
local activeWeaves: { [Player]: ActiveWeave } = {}

-- Defined Spawning Anchor Points directly at the SkywindPier LaunchPad
local SPAWN_ANCHORS = {
	Vector3.new(138, 172, 0),   -- Directly above the Launch Pad disc (8 studs up)
	Vector3.new(165, 172, 0),   -- 27 studs ahead in the open sky
	Vector3.new(155, 174, 20),  -- Off the right wing of the Launch Pad
}

function DrifterServerService.init()
	local driftersFolder = Workspace:FindFirstChild("Drifters")
	if not driftersFolder then
		driftersFolder = Instance.new("Folder")
		driftersFolder.Name = "Drifters"
		driftersFolder.Parent = Workspace
	end
	
	-- Clear any leftover drifters from previous session
	driftersFolder:ClearAllChildren()
	activeDrifters = {}
	
	-- Spawn initial population directly at Launch Pad
	for _, anchor in ipairs(SPAWN_ANCHORS) do
		DrifterServerService.spawnDrifter("Leafglider", anchor)
	end
	
	-- Listen for capture events
	NetworkService.onCaptureEvent(function(player: Player, eventType: string, data: any)
		if eventType == "RequestStartWeave" then
			DrifterServerService.handleStartWeave(player, data)
		elseif eventType == "CompleteWeave" then
			DrifterServerService.handleCompleteWeave(player, data)
		end
	end)
	
	-- AI Movement Loop (10 Hz)
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			DrifterServerService.stepAI(dt)
		end
	end)
	
	print("[DrifterServerService] Initialized with glowing ball Drifters at Launch Pad.")
end

function DrifterServerService.spawnDrifter(drifterId: string, anchor: Vector3)
	local stats = DrifterConfig.getDrifter(drifterId)
	if not stats then
		warn("[DrifterServerService] No stats for drifter: " .. drifterId)
		return
	end
	
	local assets = WindboundShared:FindFirstChild("Assets")
	local drifterAssets = assets and assets:FindFirstChild("Drifters")
	local template = drifterAssets and drifterAssets:FindFirstChild(drifterId) :: Model?
	if not template then
		warn("[DrifterServerService] No template in ReplicatedStorage for: " .. drifterId)
		return
	end
	
	local driftersFolder = Workspace:WaitForChild("Drifters")
	local drifter = template:Clone()
	drifter.Name = string.format("Drifter_%s_%d", drifterId, math.floor(os.clock()))
	
	local root = drifter.PrimaryPart or drifter:FindFirstChild("RootPart") :: BasePart?
	if not root then
		warn("[DrifterServerService] Template missing PrimaryPart: " .. drifterId)
		drifter:Destroy()
		return
	end
	
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = CFrame.new(anchor)
	
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
		CurrentTarget = anchor + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)),
		BaseY = anchor.Y,
		Speed = stats.Speed,
		NextWaypointTime = os.clock() + math.random(5, 8),
		IsCaptured = false,
	}
	print(string.format("[DrifterServerService] Spawned %s at Launch Pad (%.1f, %.1f, %.1f)", drifter.Name, anchor.X, anchor.Y, anchor.Z))
end

function DrifterServerService.stepAI(dt: number)
	local now = os.clock()
	
	for model, data in activeDrifters do
		if data.IsCaptured or not model.Parent then
			continue
		end
		
		local root = model.PrimaryPart
		if not root then continue end
		
		-- Pick new random wander waypoint within tight radius near launch pad
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
		
		-- Sinusoidal vertical bobbing
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

function DrifterServerService.handleStartWeave(player: Player, data: any)
	local drifter = data and data.drifterModel :: Model?
	if not drifter then return end
	local drifterData = activeDrifters[drifter]
	if not drifterData or drifterData.IsCaptured then return end
	
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
		
		NetworkService.Remotes.CaptureEvent:FireClient(player, "WeaveStarted", {
			drifter = drifter,
			stats = drifterData.Stats,
			timeLimit = drifterData.Stats.CaptureTimeLimit,
		})
		print(string.format("[DrifterServerService] %s initiated windweaving with %s (dist=%.1f)",
			player.Name, drifter.Name, dist))
	else
		print(string.format("[DrifterServerService] StartWeave rejected: player too far (dist=%.1f, max=%.1f)",
			dist, maxDist))
	end
end

function DrifterServerService.handleCompleteWeave(player: Player, data: any)
	local weave = activeWeaves[player]
	if not weave then return end
	
	local drifter = weave.DrifterModel
	local drifterData = activeDrifters[drifter]
	if not drifterData or drifterData.IsCaptured then return end
	
	local timeTaken = os.clock() - weave.StartTime
	if timeTaken > drifterData.Stats.CaptureTimeLimit + 3.0 then
		activeWeaves[player] = nil
		print(string.format("[DrifterServerService] Weave expired for %s (took %.1fs)", player.Name, timeTaken))
		return
	end
	
	drifterData.IsCaptured = true
	activeWeaves[player] = nil
	
	print(string.format("[DrifterServerService] %s successfully captured %s in %.1fs!",
		player.Name, drifterData.Stats.DisplayName, timeTaken))
	
	NetworkService.Remotes.CaptureEvent:FireClient(player, "CaptureSuccess", {
		drifterName = drifterData.Stats.DisplayName,
		exp = drifterData.Stats.ExpReward,
		rarity = drifterData.Stats.Rarity,
	})
	
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
