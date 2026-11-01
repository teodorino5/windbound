--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WindboundShared = ReplicatedStorage:WaitForChild("Windbound")
local KiteConfig = require(WindboundShared.Config:WaitForChild("KiteConfig") :: ModuleScript)
local NetworkService = require(WindboundShared.Network:WaitForChild("NetworkService") :: ModuleScript)

local KiteServerService = {}

type PlayerGliderSession = {
	GliderModel: Model?,
	GliderWeld: Weld?,
	KiteId: string,
	IsGliding: boolean,
}

local sessions: { [Player]: PlayerGliderSession } = {}

local function setupGlider(player: Player, character: Model, kiteId: string, isGliding: boolean): (Model?, Weld?)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") :: BasePart?
	if not torso then return nil, nil end
	
	local existingGlider = character:FindFirstChild("EquippedGlider")
	if existingGlider then existingGlider:Destroy() end
	
	local template = WindboundShared.Assets.Kites:FindFirstChild(kiteId) :: Model?
	if not template then return nil, nil end
	
	local glider = template:Clone()
	glider.Name = "EquippedGlider"
	
	for _, desc in glider:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
			desc.Massless = true
		elseif desc:IsA("Trail") then
			desc.Enabled = isGliding
		end
	end
	
	local root = glider.PrimaryPart or glider:FindFirstChild("RootPart") :: BasePart?
	if not root then
		glider:Destroy()
		return nil, nil
	end
	
	local weld = Instance.new("Weld")
	weld.Name = "GliderWeld"
	weld.Part0 = torso
	weld.Part1 = root
	
	if isGliding then
		-- Deployed overhead: scaled up to 3.8x for authentic, majestic hang-glider wingspan
		glider:ScaleTo(3.8)
		weld.C0 = CFrame.new(0, 4.0, 0.2) * CFrame.Angles(math.rad(-6), 0, 0)
	else
		-- Stowed neatly on back like a folded wing pack
		glider:ScaleTo(0.55)
		weld.C0 = CFrame.new(0, 0.25, 0.65) * CFrame.Angles(math.rad(80), math.rad(180), 0)
	end
	
	weld.Parent = root
	glider.Parent = character
	
	return glider, weld
end

function KiteServerService.init()
	NetworkService.onKiteAction(function(player: Player, action: string, data: any)
		local session = sessions[player]
		if not session then return end
		
		if action == "RequestLaunch" then
			KiteServerService.deployGlider(player)
		elseif action == "RequestRecall" then
			KiteServerService.stowGlider(player)
		elseif action == "SwitchKite" then
			local newId = data and data.kiteId
			if newId and (newId == "MeadowKite" or newId == "SwiftleafKite") then
				if not session.IsGliding then
					session.KiteId = newId
					if player.Character then
						local g, w = setupGlider(player, player.Character, newId, false)
						session.GliderModel = g
						session.GliderWeld = w
					end
					print(string.format("[KiteServerService] %s switched glider to %s", player.Name, newId))
				end
			end
		end
	end)
	
	local function onCharacterAdded(player: Player, character: Model)
		local session = sessions[player]
		if session then
			session.IsGliding = false
			task.wait(0.2)
			if character.Parent then
				local g, w = setupGlider(player, character, session.KiteId, false)
				session.GliderModel = g
				session.GliderWeld = w
			end
		end
	end
	
	local function onPlayerAdded(player: Player)
		sessions[player] = {
			GliderModel = nil,
			GliderWeld = nil,
			KiteId = KiteConfig.DefaultKiteId,
			IsGliding = false,
		}
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end
	
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
end

function KiteServerService.deployGlider(player: Player)
	local session = sessions[player]
	if not session or session.IsGliding then return end
	local char = player.Character
	if not char then return end
	
	local stats = KiteConfig.getKite(session.KiteId)
	assert(stats, "KiteStats must exist")
	
	local g, w = setupGlider(player, char, session.KiteId, true)
	session.GliderModel = g
	session.GliderWeld = w
	session.IsGliding = true
	
	print(string.format("[KiteServerService] %s deployed %s (Hang-Glider mode)", player.Name, stats.DisplayName))
	
	NetworkService.Remotes.KiteAction:FireClient(player, "LaunchConfirmed", {
		glider = g,
		stats = stats,
		timestamp = workspace:GetServerTimeNow(),
	})
end

function KiteServerService.stowGlider(player: Player)
	local session = sessions[player]
	if not session or not session.IsGliding then return end
	local char = player.Character
	if char then
		local g, w = setupGlider(player, char, session.KiteId, false)
		session.GliderModel = g
		session.GliderWeld = w
	end
	session.IsGliding = false
	
	print(string.format("[KiteServerService] %s stowed glider", player.Name))
	
	NetworkService.Remotes.KiteAction:FireClient(player, "RecallConfirmed", {
		timestamp = workspace:GetServerTimeNow(),
	})
end

function KiteServerService.getSession(player: Player): PlayerGliderSession?
	return sessions[player]
end

return KiteServerService
