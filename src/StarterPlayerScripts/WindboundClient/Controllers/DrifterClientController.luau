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
	HoopModels: { Model },
	CenterDetectors: { Part },
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
		prompt.Size = UDim2.new(0, 440, 0, 46)
		prompt.Position = UDim2.new(0.5, -220, 0.74, 0)
		prompt.BackgroundColor3 = Color3.fromRGB(20, 36, 28)
		prompt.BackgroundTransparency = 0.2
		prompt.TextColor3 = Color3.fromRGB(190, 255, 210)
		prompt.TextSize = 16
		prompt.Font = Enum.Font.GothamMedium
		prompt.Text = "🍃 Wild Drifter nearby • Press [LMB] or [F] to Start Chase!"
		prompt.Visible = false
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = prompt
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 240, 160)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.25
		stroke.Parent = prompt
		
		prompt.Parent = existing
		promptBanner = prompt
	end
	
	-- 2. Active Weave / Chase HUD Panel
	if not weavePanel or not weavePanel.Parent then
		local panel = Instance.new("Frame")
		panel.Name = "WeaveHUD"
		panel.Size = UDim2.new(0, 400, 0, 78)
		panel.Position = UDim2.new(0.5, -200, 0.10, 0)
		panel.BackgroundColor3 = Color3.fromRGB(18, 30, 24)
		panel.BackgroundTransparency = 0.2
		panel.Visible = false
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = panel
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 245, 210)
		stroke.Thickness = 2
		stroke.Parent = panel
		
		local title = Instance.new("TextLabel")
		title.Name = "WeaveTitle"
		title.Size = UDim2.new(1, 0, 0, 26)
		title.Position = UDim2.new(0, 0, 0, 6)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(255, 235, 120)
		title.TextSize = 17
		title.Font = Enum.Font.GothamBold
		title.Text = "🍃 AERIAL CHASE IN PROGRESS!"
		title.Parent = panel
		
		local ringStatus = Instance.new("TextLabel")
		ringStatus.Name = "RingStatus"
		ringStatus.Size = UDim2.new(1, 0, 0, 22)
		ringStatus.Position = UDim2.new(0, 0, 0, 30)
		ringStatus.BackgroundTransparency = 1
		ringStatus.TextColor3 = Color3.fromRGB(220, 255, 240)
		ringStatus.TextSize = 14
		ringStatus.Font = Enum.Font.GothamMedium
		ringStatus.Text = "Fly through Ring 1 / 3 to keep up!"
		ringStatus.Parent = panel
		weaveRingLabel = ringStatus
		
		local timerTrack = Instance.new("Frame")
		timerTrack.Name = "TimerTrack"
		timerTrack.Size = UDim2.new(1, -28, 0, 6)
		timerTrack.Position = UDim2.new(0, 14, 1, -12)
		timerTrack.BackgroundColor3 = Color3.fromRGB(35, 52, 44)
		timerTrack.BorderSizePixel = 0
		timerTrack.Parent = panel
		
		local tCorner = Instance.new("UICorner")
		tCorner.CornerRadius = UDim.new(0, 3)
		tCorner.Parent = timerTrack
		
		local timerFill = Instance.new("Frame")
		timerFill.Name = "TimerFill"
		timerFill.Size = UDim2.new(1, 0, 1, 0)
		timerFill.BackgroundColor3 = Color3.fromRGB(80, 245, 180)
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
		vb.Size = UDim2.new(0, 460, 0, 72)
		vb.Position = UDim2.new(0.5, -230, 0.22, 0)
		vb.BackgroundColor3 = Color3.fromRGB(22, 38, 30)
		vb.BackgroundTransparency = 1
		vb.TextColor3 = Color3.fromRGB(255, 240, 160)
		vb.TextSize = 22
		vb.Font = Enum.Font.GothamBold
		vb.Text = ""
		vb.Visible = false
		
		local vCorner = Instance.new("UICorner")
		vCorner.CornerRadius = UDim.new(0, 16)
		vCorner.Parent = vb
		
		local vStroke = Instance.new("UIStroke")
		vStroke.Color = Color3.fromRGB(240, 220, 100)
		vStroke.Thickness = 2
		vStroke.Transparency = 1
		vStroke.Parent = vb
		
		vb.Parent = existing
		victoryBanner = vb
	end
	
	return existing
end

-- Helper: Create a gorgeous, vertical 3D hollow hoop in the sky
local function createVerticalHoop(centerCF: CFrame, radius: number, ringIndex: number, parentFolder: Instance): (Model, Part)
	local hoopModel = Instance.new("Model")
	hoopModel.Name = "WindHoop_" .. ringIndex
	
	local centerPart = Instance.new("Part")
	centerPart.Name = "CenterDetector"
	centerPart.Size = Vector3.new(0.5, 0.5, 0.5)
	centerPart.CFrame = centerCF
	centerPart.Transparency = 1
	centerPart.CanCollide = false
	centerPart.CanQuery = false
	centerPart.CanTouch = false
	centerPart.Anchored = true
	centerPart.Parent = hoopModel
	hoopModel.PrimaryPart = centerPart
	
	local numSegments = 16
	local thickness = 0.75
	local isActive = (ringIndex == 1)
	local segColor = isActive and Color3.fromRGB(80, 240, 255) or Color3.fromRGB(130, 220, 205)
	local segTrans = isActive and 0.15 or 0.55
	
	local points = {}
	for i = 0, numSegments - 1 do
		local theta = (i / numSegments) * math.pi * 2
		-- Vertical circle: X is horizontal, Y is vertical, Z is 0 (normal points along LookVector)
		local localOffset = Vector3.new(math.cos(theta) * radius, math.sin(theta) * radius, 0)
		local worldPoint = centerCF:PointToWorldSpace(localOffset)
		table.insert(points, worldPoint)
	end
	
	for i = 1, numSegments do
		local nextI = (i % numSegments) + 1
		local p1 = points[i]
		local p2 = points[nextI]
		local mid = (p1 + p2) * 0.5
		local segDist = (p2 - p1).Magnitude
		
		local seg = Instance.new("Part")
		seg.Name = "HoopSegment"
		seg.Shape = Enum.PartType.Cylinder
		seg.Size = Vector3.new(segDist + 0.12, thickness, thickness)
		-- Align cylinder axis (X) along segment vector
		seg.CFrame = CFrame.lookAt(mid, p2) * CFrame.Angles(0, math.rad(90), 0)
		seg.Material = Enum.Material.Neon
		seg.Color = segColor
		seg.Transparency = segTrans
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.Anchored = true
		seg.CastShadow = false
		seg.Parent = hoopModel
	end
	
	-- Numbered Marker on Top of Hoop
	local topOffset = centerCF:PointToWorldSpace(Vector3.new(0, radius + 2.0, 0))
	local topMarker = Instance.new("Part")
	topMarker.Name = "TopMarker"
	topMarker.Size = Vector3.new(1, 1, 1)
	topMarker.CFrame = CFrame.new(topOffset)
	topMarker.Transparency = 1
	topMarker.CanCollide = false
	topMarker.CanQuery = false
	topMarker.CanTouch = false
	topMarker.Anchored = true
	topMarker.Parent = hoopModel
	
	local bbg = Instance.new("BillboardGui")
	bbg.Name = "RingMarker"
	bbg.Size = UDim2.new(0, 52, 0, 52)
	bbg.AlwaysOnTop = true
	bbg.MaxDistance = 600
	bbg.Parent = topMarker
	
	local numBadge = Instance.new("TextLabel")
	numBadge.Name = "BadgeText"
	numBadge.Size = UDim2.new(1, 0, 1, 0)
	numBadge.BackgroundColor3 = Color3.fromRGB(20, 36, 30)
	numBadge.BackgroundTransparency = 0.25
	numBadge.TextColor3 = isActive and Color3.fromRGB(100, 255, 240) or Color3.fromRGB(200, 235, 225)
	numBadge.TextSize = 22
	numBadge.Font = Enum.Font.GothamBold
	numBadge.Text = tostring(ringIndex)
	
	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0.5, 0)
	bCorner.Parent = numBadge
	
	local bStroke = Instance.new("UIStroke")
	bStroke.Name = "BadgeStroke"
	bStroke.Color = isActive and Color3.fromRGB(80, 240, 255) or Color3.fromRGB(130, 220, 205)
	bStroke.Thickness = 2
	bStroke.Parent = numBadge
	numBadge.Parent = bbg
	
	-- Center soft wind swirl
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WindSwirl"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 255, 220))
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0)
	})
	emitter.Transparency = NumberSequence.new(0.35)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = isActive and 22 or 6
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = centerPart
	
	hoopModel.Parent = parentFolder
	return hoopModel, centerPart
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
	
	task.delay(4.0, function()
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
	
	InputManager.onCapture(function()
		if currentTargetDrifter and not activeSession and KiteFlightController.isFlying() then
			print("[DrifterClientController] Starting aerial chase with: " .. currentTargetDrifter.Name)
			NetworkService.sendCaptureEvent("RequestStartWeave", {
				drifterModel = currentTargetDrifter,
			})
		end
	end)
	
	NetworkService.Remotes.CaptureEvent.OnClientEvent:Connect(function(eventType: string, data: any)
		if eventType == "WeaveStarted" then
			DrifterClientController.startWeaveChallenge(data.drifter, data.stats, data.timeLimit, data.waypoints)
		elseif eventType == "CaptureSuccess" then
			DrifterClientController.onCaptureSuccess(data.drifterName, data.exp, data.rarity)
		end
	end)
	
	RunService.RenderStepped:Connect(function(dt: number)
		DrifterClientController.stepDetection(dt)
	end)
	
	print("[DrifterClientController] Initialized with vertical hoop chase system.")
end

function DrifterClientController.stepDetection(dt: number)
	getOrCreateHUD()
	
	local player = Players.LocalPlayer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	
	if not hrp then
		currentTargetDrifter = nil
		if promptBanner then promptBanner.Visible = false end
		return
	end
	
	local kitePos = hrp.Position
	local driftersFolder = Workspace:FindFirstChild("Drifters")
	
	local closestDrifter: Model? = nil
	local closestDist = 42
	
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
				promptBanner.Text = string.format("🍃 Wild Drifter nearby (%.0fm) • Press [LMB] or [F] to Start Chase!", closestDist)
			else
				promptBanner.Text = string.format("🍃 Wild Drifter nearby (%.0fm) • Jump & Press [Space] to Fly!", closestDist)
			end
			promptBanner.Visible = true
		else
			promptBanner.Visible = false
		end
	end
	
	-- Active Chase / Weave Step
	if activeSession then
		activeSession.TimeRemaining -= dt
		
		if weavePanel then weavePanel.Visible = true end
		if weaveTimerBar then
			local fraction = math.clamp(activeSession.TimeRemaining / activeSession.TotalTime, 0, 1)
			weaveTimerBar.Size = UDim2.new(fraction, 0, 1, 0)
			if fraction < 0.25 then
				weaveTimerBar.BackgroundColor3 = Color3.fromRGB(255, 95, 95)
			else
				weaveTimerBar.BackgroundColor3 = Color3.fromRGB(80, 245, 180)
			end
		end
		
		if activeSession.TimeRemaining <= 0 then
			DrifterClientController.cancelWeave()
			return
		end
		
		-- Check collision with current hoop center
		local currentCenter = activeSession.CenterDetectors[activeSession.CurrentRingIndex]
		local currentHoop = activeSession.HoopModels[activeSession.CurrentRingIndex]
		
		if currentCenter and currentCenter.Parent and currentHoop and currentHoop.Parent then
			local distToCenter = (currentCenter.Position - kitePos).Magnitude
			
			-- Pulse active hoop segments
			local pulse = math.sin(os.clock() * 8) * 0.12
			for _, desc in currentHoop:GetChildren() do
				if desc.Name == "HoopSegment" and desc:IsA("BasePart") then
					desc.Transparency = 0.15 + pulse
				end
			end
			
			-- Fly-through detection threshold (radius = 8 studs, threshold = 9.5 studs)
			if distToCenter < 9.5 then
				-- PASSED HOOP!
				for _, desc in currentHoop:GetChildren() do
					if desc.Name == "HoopSegment" and desc:IsA("BasePart") then
						desc.Color = Color3.fromRGB(255, 235, 90) -- Golden pop
						desc.Transparency = 0.05
					end
				end
				
				-- Refill flight stamina by +8 seconds on passing each hoop!
				KiteFlightController.addStamina(8)
				
				local passedIdx = activeSession.CurrentRingIndex
				activeSession.CurrentRingIndex += 1
				
				-- Fade out cleared hoop
				task.spawn(function()
					for step = 1, 10 do
						task.wait(0.03)
						for _, desc in currentHoop:GetChildren() do
							if desc:IsA("BasePart") then
								desc.Transparency = step * 0.1
								desc.Size = desc.Size * 1.03
							end
						end
					end
					currentHoop:Destroy()
				end)
				
				if activeSession.CurrentRingIndex > #activeSession.CenterDetectors then
					-- ALL 3 HOOPS CLEARED! CHASE WON!
					local drifter = activeSession.Drifter
					DrifterClientController.cleanupRings()
					NetworkService.sendCaptureEvent("CompleteWeave", {
						drifter = drifter,
					})
				else
					-- Activate Next Hoop!
					local nextHoop = activeSession.HoopModels[activeSession.CurrentRingIndex]
					local nextCenter = activeSession.CenterDetectors[activeSession.CurrentRingIndex]
					if nextHoop and nextHoop.Parent then
						for _, desc in nextHoop:GetChildren() do
							if desc.Name == "HoopSegment" and desc:IsA("BasePart") then
								desc.Color = Color3.fromRGB(80, 240, 255)
								desc.Transparency = 0.15
							end
						end
						local nextEmitter = nextCenter and nextCenter:FindFirstChild("WindSwirl") :: ParticleEmitter?
						if nextEmitter then nextEmitter.Rate = 22 end
					end
					
					if weaveRingLabel then
						weaveRingLabel.Text = string.format("✨ Ring %d Cleared! ⏩ Chasing Leafglider to Ring %d!",
							passedIdx, activeSession.CurrentRingIndex)
					end
				end
			end
		end
	else
		if weavePanel then weavePanel.Visible = false end
	end
end

function DrifterClientController.startWeaveChallenge(drifter: Model, stats: any, timeLimit: number, waypoints: any)
	DrifterClientController.cleanupRings()
	
	local root = drifter.PrimaryPart
	if not root then return end
	
	local ringsFolder = Workspace:FindFirstChild("ActiveWeaveRings")
	if not ringsFolder then
		ringsFolder = Instance.new("Folder")
		ringsFolder.Name = "ActiveWeaveRings"
		ringsFolder.Parent = Workspace
	end
	
	local hoops: { Model } = {}
	local detectors: { Part } = {}
	local radius = 8.0 -- 16 stud diameter vertical hoop
	
	if waypoints and #waypoints >= 3 then
		for idx, wp in ipairs(waypoints) do
			local lookDir = wp.dir or Vector3.new(1, 0, 0)
			local centerCF = CFrame.lookAt(wp.pos, wp.pos + lookDir)
			local hoopModel, centerPart = createVerticalHoop(centerCF, radius, idx, ringsFolder)
			table.insert(hoops, hoopModel)
			table.insert(detectors, centerPart)
		end
	else
		-- Fallback forward arc
		local dCF = root.CFrame
		local defaultOffsets = {
			dCF * CFrame.new(0, 3, -40),
			dCF * CFrame.new(12, 6, -85) * CFrame.Angles(0, math.rad(15), 0),
			dCF * CFrame.new(-4, 3, -135) * CFrame.Angles(math.rad(-8), 0, 0),
		}
		for idx, cCF in ipairs(defaultOffsets) do
			local hoopModel, centerPart = createVerticalHoop(cCF, radius, idx, ringsFolder)
			table.insert(hoops, hoopModel)
			table.insert(detectors, centerPart)
		end
	end
	
	local duration = timeLimit or 28
	activeSession = {
		Drifter = drifter,
		CurrentRingIndex = 1,
		HoopModels = hoops,
		CenterDetectors = detectors,
		TimeRemaining = duration,
		TotalTime = duration,
	}
	
	if weaveRingLabel then
		weaveRingLabel.Text = "Fly through Ring 1 / 3 to keep up with the Leafglider!"
	end
	if weavePanel then
		weavePanel.Visible = true
	end
end

function DrifterClientController.cleanupRings()
	if activeSession then
		for _, h in activeSession.HoopModels do
			if h and h.Parent then h:Destroy() end
		end
	end
	activeSession = nil
	local folder = Workspace:FindFirstChild("ActiveWeaveRings")
	if folder then folder:Destroy() end
	if weavePanel then weavePanel.Visible = false end
end

function DrifterClientController.cancelWeave()
	DrifterClientController.cleanupRings()
	DrifterClientController.showVictory("Chase Lost", "The Leafglider outpaced you and vanished into the breeze.")
end

function DrifterClientController.onCaptureSuccess(drifterName: string, exp: number, rarity: string)
	DrifterClientController.cleanupRings()
	DrifterClientController.showVictory(
		string.format("✨ CAPTURED %s!", string.upper(drifterName)),
		string.format("+%d EXP • Skill Check Completed • %s Windseeker", exp, rarity)
	)
end

return DrifterClientController
