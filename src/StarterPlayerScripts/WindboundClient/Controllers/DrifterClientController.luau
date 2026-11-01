--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local WindboundShared = ReplicatedStorage:WaitForChild("Windbound")
local NetworkService = require(WindboundShared.Network:WaitForChild("NetworkService") :: ModuleScript)

local clientFolder = script.Parent.Parent
local InputManager = require(clientFolder.Input:WaitForChild("InputManager") :: ModuleScript)
local KiteFlightController = require(script.Parent:WaitForChild("KiteFlightController") :: ModuleScript)

local DrifterClientController = {}

type ActiveWeaveSession = {
	Drifter: Model,
	CurrentRingIndex: number,
	RingObjects: { Part },
	TimeRemaining: number,
	TotalTime: number,
}

local currentTargetDrifter: Model? = nil
local activeSession: ActiveWeaveSession? = nil

-- UI elements
local hudGui: ScreenGui? = nil
local promptBanner: TextLabel? = nil
local weavePanel: Frame? = nil
local weaveRingLabel: TextLabel? = nil
local weaveTimerBar: Frame? = nil
local victoryBanner: TextLabel? = nil

local function getOrCreateHUD(): ScreenGui
	if hudGui and hudGui.Parent then return hudGui end
	
	local player = Players.LocalPlayer
	local pGui = player:WaitForChild("PlayerGui")
	local existing = pGui:FindFirstChild("WindboundHUD") :: ScreenGui?
	if not existing then
		existing = Instance.new("ScreenGui")
		existing.Name = "WindboundHUD"
		existing.ResetOnSpawn = false
		existing.IgnoreGuiInset = true
		existing.Parent = pGui
	end
	hudGui = existing
	
	-- 1. Proximity Prompt Banner
	if not promptBanner or not promptBanner.Parent then
		local prompt = Instance.new("TextLabel")
		prompt.Name = "DrifterPrompt"
		prompt.Size = UDim2.new(0, 420, 0, 44)
		prompt.Position = UDim2.new(0.5, -210, 0.76, 0)
		prompt.BackgroundColor3 = Color3.fromRGB(22, 35, 28)
		prompt.BackgroundTransparency = 0.25
		prompt.TextColor3 = Color3.fromRGB(190, 255, 210)
		prompt.TextSize = 16
		prompt.Font = Enum.Font.GothamMedium
		prompt.Text = "🍃 Leafglider nearby • Press [LMB] or [F] to Start Windweaving"
		prompt.Visible = false
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = prompt
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 230, 150)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.3
		stroke.Parent = prompt
		
		prompt.Parent = existing
		promptBanner = prompt
	end
	
	-- 2. Active Weave HUD Panel
	if not weavePanel or not weavePanel.Parent then
		local panel = Instance.new("Frame")
		panel.Name = "WeaveHUD"
		panel.Size = UDim2.new(0, 360, 0, 72)
		panel.Position = UDim2.new(0.5, -180, 0.12, 0)
		panel.BackgroundColor3 = Color3.fromRGB(20, 30, 26)
		panel.BackgroundTransparency = 0.25
		panel.Visible = false
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = panel
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(120, 240, 200)
		stroke.Thickness = 1.5
		stroke.Parent = panel
		
		local title = Instance.new("TextLabel")
		title.Name = "WeaveTitle"
		title.Size = UDim2.new(1, 0, 0, 24)
		title.Position = UDim2.new(0, 0, 0, 6)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(255, 235, 140)
		title.TextSize = 16
		title.Font = Enum.Font.GothamBold
		title.Text = "🍃 WINDWEAVING CHALLENGE"
		title.Parent = panel
		
		local ringStatus = Instance.new("TextLabel")
		ringStatus.Name = "RingStatus"
		ringStatus.Size = UDim2.new(1, 0, 0, 20)
		ringStatus.Position = UDim2.new(0, 0, 0, 28)
		ringStatus.BackgroundTransparency = 1
		ringStatus.TextColor3 = Color3.fromRGB(220, 245, 235)
		ringStatus.TextSize = 14
		ringStatus.Font = Enum.Font.GothamMedium
		ringStatus.Text = "Fly through Ring 1 / 3"
		ringStatus.Parent = panel
		weaveRingLabel = ringStatus
		
		local timerTrack = Instance.new("Frame")
		timerTrack.Name = "TimerTrack"
		timerTrack.Size = UDim2.new(1, -24, 0, 6)
		timerTrack.Position = UDim2.new(0, 12, 1, -12)
		timerTrack.BackgroundColor3 = Color3.fromRGB(40, 55, 48)
		timerTrack.BorderSizePixel = 0
		timerTrack.Parent = panel
		
		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 3)
		tCorner.Parent = timerTrack
		
		local timerFill = Instance.new("Frame")
		timerFill.Name = "TimerFill"
		timerFill.Size = UDim2.new(1, 0, 1, 0)
		timerFill.BackgroundColor3 = Color3.fromRGB(100, 240, 180)
		timerFill.BorderSizePixel = 0
		timerFill.Parent = timerTrack
		
		local fCorner = Instance.new("UICorner")
		fCorner.CornerRadius = UDim.new(0, 3)
		fCorner.Parent = timerFill
		weaveTimerBar = timerFill
		
		panel.Parent = existing
		weavePanel = panel
	end
	
	-- 3. Victory / Result Banner
	if not victoryBanner or not victoryBanner.Parent then
		local vb = Instance.new("TextLabel")
		vb.Name = "VictoryBanner"
		vb.Size = UDim2.new(0, 440, 0, 68)
		vb.Position = UDim2.new(0.5, -220, 0.22, 0)
		vb.BackgroundColor3 = Color3.fromRGB(24, 40, 32)
		vb.BackgroundTransparency = 1
		vb.TextColor3 = Color3.fromRGB(255, 240, 160)
		vb.TextSize = 22
		vb.Font = Enum.Font.GothamBold
		vb.Text = ""
		vb.Visible = false
		
		local vCorner = Instance.new("UICorner")
		vCorner.CornerRadius = UDim.new(0, 14)
		vCorner.Parent = vb
		
		local vStroke = Instance.new("UIStroke")
		vStroke.Color = Color3.fromRGB(240, 215, 100)
		vStroke.Thickness = 2
		vStroke.Transparency = 1
		vStroke.Parent = vb
		
		vb.Parent = existing
		victoryBanner = vb
	end
	
	return existing
end

function DrifterClientController.showVictory(title: string, sub: string)
	getOrCreateHUD()
	if not victoryBanner then return end
	
	victoryBanner.Text = string.format("%s
<font size='15' color='#B4FFC8'>%s</font>", title, sub)
	victoryBanner.RichText = true
	victoryBanner.Visible = true
	
	local stroke = victoryBanner:FindFirstChildOfClass("UIStroke")
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(victoryBanner, tweenInfo, { BackgroundTransparency = 0.2 }):Play()
	if stroke then
		TweenService:Create(stroke, tweenInfo, { Transparency = 0.15 }):Play()
	end
	
	task.delay(3.5, function()
		if victoryBanner and victoryBanner.Visible then
			local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local tw = TweenService:Create(victoryBanner, fade, { BackgroundTransparency = 1 })
			if stroke then
				TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
			end
			tw:Play()
			tw.Completed:Connect(function()
				if victoryBanner then victoryBanner.Visible = false end
			end)
		end
	end)
end

function DrifterClientController.init()
	getOrCreateHUD()
	
	-- Listen for capture trigger from InputManager (LMB, F, C, Gamepad R2, Mobile Catch)
	InputManager.onCapture(function()
		if currentTargetDrifter and not activeSession and KiteFlightController.isFlying() then
			print("[DrifterClientController] Requesting windweave with: " .. currentTargetDrifter.Name)
			NetworkService.sendCaptureEvent("RequestStartWeave", {
				drifterModel = currentTargetDrifter,
			})
		end
	end)
	
	-- Listen for server events
	NetworkService.Remotes.CaptureEvent.OnClientEvent:Connect(function(eventType: string, data: any)
		if eventType == "WeaveStarted" then
			DrifterClientController.startWeaveChallenge(data.drifter, data.stats, data.timeLimit)
		elseif eventType == "CaptureSuccess" then
			DrifterClientController.onCaptureSuccess(data.drifterName, data.exp, data.rarity)
		end
	end)
	
	-- Detection & Weave Tick Loop
	RunService.RenderStepped:Connect(function(dt: number)
		DrifterClientController.stepDetection(dt)
	end)
	
	print("[DrifterClientController] Initialized with interactive windweaving capture loop.")
end

function DrifterClientController.stepDetection(dt: number)
	getOrCreateHUD()
	
	local player = Players.LocalPlayer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	
	-- Only detect drifters if character exists
	if not hrp then
		currentTargetDrifter = nil
		if promptBanner then promptBanner.Visible = false end
		return
	end
	
	local kitePos = hrp.Position
	local driftersFolder = Workspace:FindFirstChild("Drifters")
	
	local closestDrifter: Model? = nil
	local closestDist = 42 -- Detection threshold
	
	if driftersFolder and not activeSession then
		for _, drifter in driftersFolder:GetChildren() do
			if drifter:IsA("Model") and drifter.PrimaryPart then
				local dist = (drifter.PrimaryPart.Position - kitePos).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestDrifter = drifter
				end
			end
		end
	end
	
	currentTargetDrifter = closestDrifter
	
	-- Update proximity prompt banner
	if promptBanner then
		if currentTargetDrifter and not activeSession then
			if KiteFlightController.isFlying() then
				promptBanner.Text = string.format("🍃 Wild Drifter nearby (%.0fm) • Press [LMB] or [F] to Start Windweaving!", closestDist)
			else
				promptBanner.Text = string.format("🍃 Wild Drifter nearby (%.0fm) • Jump & Press [Space] to Fly!", closestDist)
			end
			promptBanner.Visible = true
		else
			promptBanner.Visible = false
		end
	end
	
	-- Active Weave Challenge Step
	if activeSession then
		activeSession.TimeRemaining -= dt
		
		-- Update HUD timer & text
		if weavePanel then weavePanel.Visible = true end
		if weaveTimerBar then
			local fraction = math.clamp(activeSession.TimeRemaining / activeSession.TotalTime, 0, 1)
			weaveTimerBar.Size = UDim2.new(fraction, 0, 1, 0)
			if fraction < 0.25 then
				weaveTimerBar.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
			else
				weaveTimerBar.BackgroundColor3 = Color3.fromRGB(100, 240, 180)
			end
		end
		
		if activeSession.TimeRemaining <= 0 then
			DrifterClientController.cancelWeave()
			return
		end
		
		-- Check collision with current ring
		local currentRing = activeSession.RingObjects[activeSession.CurrentRingIndex]
		if currentRing and currentRing.Parent then
			local distToRing = (currentRing.Position - kitePos).Magnitude
			
			-- Make current ring pulse and glow brighter
			local pulse = math.sin(os.clock() * 6) * 0.15
			currentRing.Transparency = 0.2 + pulse
			
			if distToRing < 10.5 then
				-- Passed ring!
				currentRing.Color = Color3.fromRGB(255, 230, 80)
				currentRing.Material = Enum.Material.Neon
				currentRing.Transparency = 0.05
				
				-- Play ring pass sound / visual pop
				local ringIdx = activeSession.CurrentRingIndex
				activeSession.CurrentRingIndex += 1
				
				-- Tween ring fade
				TweenService:Create(currentRing, TweenInfo.new(0.35), {
					Size = currentRing.Size * 1.5,
					Transparency = 1,
				}):Play()
				
				if activeSession.CurrentRingIndex > #activeSession.RingObjects then
					-- ALL 3 RINGS CLEARED!
					local drifter = activeSession.Drifter
					DrifterClientController.cleanupRings()
					NetworkService.sendCaptureEvent("CompleteWeave", {
						drifter = drifter,
					})
				else
					-- Next ring becomes bright active
					local nextRing = activeSession.RingObjects[activeSession.CurrentRingIndex]
					if nextRing then
						nextRing.Color = Color3.fromRGB(100, 245, 255)
						nextRing.Transparency = 0.2
					end
					if weaveRingLabel then
						weaveRingLabel.Text = string.format("✨ Ring %d / %d Cleared! Fly through Ring %d!",
							ringIdx, #activeSession.RingObjects, activeSession.CurrentRingIndex)
					end
				end
			end
		end
	else
		if weavePanel then weavePanel.Visible = false end
	end
end

function DrifterClientController.startWeaveChallenge(drifter: Model, stats: any, timeLimit: number)
	DrifterClientController.cleanupRings()
	
	local root = drifter.PrimaryPart
	if not root then return end
	
	local dCF = root.CFrame
	local rings: { Part } = {}
	
	local ringsFolder = Workspace:FindFirstChild("ActiveWeaveRings")
	if not ringsFolder then
		ringsFolder = Instance.new("Folder")
		ringsFolder.Name = "ActiveWeaveRings"
		ringsFolder.Parent = Workspace
	end
	
	-- 3 wide aerodynamic wind rings forming a sweeping arc ahead of the Drifter
	-- Ring 1: 32 studs ahead
	-- Ring 2: 68 studs ahead, banking right
	-- Ring 3: 105 studs ahead, sweeping down
	local offsets = {
		dCF * CFrame.new(-6, 2, -32),
		dCF * CFrame.new(10, 5, -68) * CFrame.Angles(0, math.rad(15), 0),
		dCF * CFrame.new(-2, -4, -105) * CFrame.Angles(math.rad(-10), 0, 0),
	}
	
	for idx, ringCF in ipairs(offsets) do
		local ring = Instance.new("Part")
		ring.Name = "WindRing_" .. idx
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.6, 16, 16)
		ring.CFrame = ringCF * CFrame.Angles(0, 0, math.rad(90))
		ring.CanCollide = false
		ring.Anchored = true
		ring.CastShadow = false
		
		if idx == 1 then
			ring.Color = Color3.fromRGB(100, 245, 255)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.25
		else
			ring.Color = Color3.fromRGB(160, 230, 210)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.65
		end
		
		-- Add soft billboard label for clear guidance
		local bbg = Instance.new("BillboardGui")
		bbg.Name = "RingMarker"
		bbg.Size = UDim2.new(0, 60, 0, 60)
		bbg.AlwaysOnTop = true
		bbg.MaxDistance = 250
		bbg.Parent = ring
		
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.TextColor3 = Color3.fromRGB(255, 255, 255)
		icon.TextSize = 22
		icon.Font = Enum.Font.GothamBold
		icon.Text = tostring(idx)
		icon.Parent = bbg
		
		ring.Parent = ringsFolder
		table.insert(rings, ring)
	end
	
	local duration = timeLimit or 22
	activeSession = {
		Drifter = drifter,
		CurrentRingIndex = 1,
		RingObjects = rings,
		TimeRemaining = duration,
		TotalTime = duration,
	}
	
	if weaveRingLabel then
		weaveRingLabel.Text = "Fly through Ring 1 / 3"
	end
	if weavePanel then
		weavePanel.Visible = true
	end
end

function DrifterClientController.cleanupRings()
	if activeSession then
		for _, r in activeSession.RingObjects do
			r:Destroy()
		end
	end
	activeSession = nil
	local folder = Workspace:FindFirstChild("ActiveWeaveRings")
	if folder then folder:Destroy() end
	if weavePanel then weavePanel.Visible = false end
end

function DrifterClientController.cancelWeave()
	DrifterClientController.cleanupRings()
	DrifterClientController.showVictory("Weave Lost", "The Leafglider slipped into the mountain breeze.")
end

function DrifterClientController.onCaptureSuccess(drifterName: string, exp: number, rarity: string)
	DrifterClientController.cleanupRings()
	DrifterClientController.showVictory(
		string.format("✨ CAPTURED %s!", string.upper(drifterName)),
		string.format("+%d EXP • %s Windseeker Discoveries", exp, rarity)
	)
end

return DrifterClientController
