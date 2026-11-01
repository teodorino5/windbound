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

-- Capture session tracking for anti-exploit validation
type ActiveWeave = {
	Player: Player,
	DrifterModel: Model,
	StartTime: number,
	CheckpointsCompleted: number,
}
local activeWeaves: { [Player]: ActiveWeave } = {}

-- Defined Spawning Anchor Points around Greenwake Meadows
local SPAWN_ANCHORS = {
	Vector3.new(0, 205, -50),   -- Whispering Ridge Thermal
	Vector3.new(95, 188, 20),   -- Windwake Pier Cliff Outskirts
	Vector3.new(125, 198, 75),  -- Satellite Islet Drift
	Vector3.new(-65, 190, -25), -- Sunspire West Meadows
}

function DrifterServerService.init()
	local driftersFolder = Workspace:FindFirstChild("Drifters")
	if not driftersFolder then
		driftersFolder = Instance.new("Folder")
		driftersFolder.Name = "Drifters"
		driftersFolder.Parent = Workspace
	end
	
	-- Spawn initial population
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
	
	-- AI Movement Loop
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			DrifterServerService.stepAI(dt)
		end
	end)
	
	print("[DrifterServerService] Initialized with 4 wild Drifter anchors.")
end

function DrifterServerService.spawnDrifter(drifterId: string, anchor: Vector3)
	local stats = DrifterConfig.getDrifter(drifterId)
	if not stats then return end
	
	local template = WindboundShared.Assets.Drifters:FindFirstChild(drifterId) :: Model?
	if not template then return end
	
	local driftersFolder = Workspace:WaitForChild("Drifters")
	local drifter = template:Clone()
	drifter.Name = string.format("Drifter_%s_%d", drifterId, os.clock())
	
	local root = drifter.PrimaryPart or drifter:FindFirstChild("RootPart") :: BasePart?
	if not root then return end
	
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = CFrame.new(anchor)
	
	CollectionService:AddTag(drifter, GameConfig.Tags.Drifter)
	drifter.Parent = driftersFolder
	
	activeDrifters[drifter] = {
		Model = drifter,
		Stats = stats,
		HomeAnchor = anchor,
		CurrentTarget = anchor + Vector3.new(math.random(-25, 25), 0, math.random(-25, 25)),
		BaseY = anchor.Y,
		Speed = stats.Speed,
		NextWaypointTime = os.clock() + math.random(5, 9),
		IsCaptured = false,
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
		
		-- Pick new random wander waypoint within radius
		if now >= data.NextWaypointTime then
			local rad = data.Stats.WanderRadius
			local randOffset = Vector3.new(
				math.random(-rad, rad),
				math.random(-8, 8),
				math.random(-rad, rad)
			)
			data.CurrentTarget = data.HomeAnchor + randOffset
			data.NextWaypointTime = now + math.random(6, 11)
		end
		
		-- Sinusoidal vertical bobbing
		local bob = math.sin(now * data.Stats.HoverBobFrequency * math.pi * 2) * data.Stats.HoverBobAmplitude
		local targetWithBob = Vector3.new(data.CurrentTarget.X, data.BaseY + bob, data.CurrentTarget.Z)
		
		local currentPos = root.Position
		local moveDir = (targetWithBob - currentPos)
		local dist = moveDir.Magnitude
		
		if dist > 1 then
			local stepDist = math.min(dist, data.Speed * dt)
			local newPos = currentPos + (moveDir.Unit * stepDist)
			local lookAt = currentPos + moveDir.Unit * 10
			-- Smooth banking toward waypoint
			local targetCF = CFrame.lookAt(newPos, Vector3.new(lookAt.X, newPos.Y, lookAt.Z))
			model:PivotTo(targetCF)
		end
	end
end

function DrifterServerService.handleStartWeave(player: Player, data: any)
	local drifter = data and data.drifterModel :: Model?
	if not drifter then return end
	local drifterData = activeDrifters[drifter]
	if not drifterData or drifterData.IsCaptured then return end
	
	-- Verify player has flying kite
	local playerKites = Workspace:FindFirstChild("PlayerKites")
	local kite = playerKites and playerKites:FindFirstChild("Kite_" .. player.Name) :: Model?
	if not kite or not kite.PrimaryPart then return end
	
	local dist = (kite.PrimaryPart.Position - drifter.PrimaryPart.Position).Magnitude
	if dist <= (drifterData.Stats.CaptureRadius + 12) then
		activeWeaves[player] = {
			Player = player,
			DrifterModel = drifter,
			StartTime = os.clock(),
			CheckpointsCompleted = 0,
		}
		-- Send confirmation to client to spawn weave rings
		NetworkService.Remotes.CaptureEvent:FireClient(player, "WeaveStarted", {
			drifter = drifter,
			stats = drifterData.Stats,
			timeLimit = drifterData.Stats.CaptureTimeLimit,
		})
	end
end

function DrifterServerService.handleCompleteWeave(player: Player, data: any)
	local weave = activeWeaves[player]
	if not weave then return end
	
	local drifter = weave.DrifterModel
	local drifterData = activeDrifters[drifter]
	if not drifterData or drifterData.IsCaptured then return end
	
	local timeTaken = os.clock() - weave.StartTime
	if timeTaken > drifterData.Stats.CaptureTimeLimit + 2.5 then
		-- Expired
		activeWeaves[player] = nil
		return
	end
	
	-- Mark captured
	drifterData.IsCaptured = true
	activeWeaves[player] = nil
	
	print(string.format("[DrifterServerService] Player %s captured %s!", player.Name, drifterData.Stats.DisplayName))
	
	-- Notify client
	NetworkService.Remotes.CaptureEvent:FireClient(player, "CaptureSuccess", {
		drifterName = drifterData.Stats.DisplayName,
		exp = drifterData.Stats.ExpReward,
		rarity = drifterData.Stats.Rarity,
	})
	
	-- Despawn Drifter with dissolve effect
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.05)
			if drifter.PrimaryPart then
				drifter.PrimaryPart.Transparency = i * 0.1
			end
		end
		activeDrifters[drifter] = nil
		local anchor = drifterData.HomeAnchor
		local id = drifterData.Stats.Id
		drifter:Destroy()
		
		-- Respawn after 20 seconds
		task.wait(20)
		DrifterServerService.spawnDrifter(id, anchor)
	end)
end

return DrifterServerService
