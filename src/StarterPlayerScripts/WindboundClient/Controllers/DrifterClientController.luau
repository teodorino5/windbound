--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
}

local currentTargetDrifter: Model? = nil
local activeSession: ActiveWeaveSession? = nil

-- Simple procedural capture notification UI
local notificationGui: ScreenGui? = nil
local notificationLabel: TextLabel? = nil

local function getOrCreateNotificationUI()
	local player = Players.LocalPlayer
	local pGui = player:WaitForChild("PlayerGui")
	local existing = pGui:FindFirstChild("WindboundHUD")
	if not existing then
		local sg = Instance.new("ScreenGui")
		sg.Name = "WindboundHUD"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.Parent = pGui
		existing = sg
	end
	
	if not notificationLabel then
		local banner = Instance.new("TextLabel")
		banner.Name = "CaptureNotification"
		banner.Size = UDim2.new(0, 360, 0, 60)
		banner.Position = UDim2.new(0.5, -180, 0.18, 0)
		banner.BackgroundColor3 = Color3.fromRGB(30, 42, 35)
		banner.BackgroundTransparency = 1
		banner.TextColor3 = Color3.fromRGB(180, 255, 190)
		banner.TextSize = 22
		banner.Font = Enum.Font.GothamBold
		banner.Text = ""
		banner.Visible = false
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = banner
		
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(120, 220, 150)
		stroke.Thickness = 1.5
		stroke.Transparency = 1
		stroke.Parent = banner
		
		banner.Parent = existing
		notificationLabel = banner
	end
end

function DrifterClientController.showNotification(text: string, subtext: string)
	getOrCreateNotificationUI()
	if not notificationLabel then return end
	
	notificationLabel.Text = string.format("%s\n%s", text, subtext)
	notificationLabel.Visible = true
	
	local stroke = notificationLabel:FindFirstChildOfClass("UIStroke")
	
	-- Fade in
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(notificationLabel, tweenInfo, { BackgroundTransparency = 0.25 }):Play()
	if stroke then
		TweenService:Create(stroke, tweenInfo, { Transparency = 0.2 }):Play()
	end
	
	-- Fade out after 3 seconds
	task.delay(3.0, function()
		if notificationLabel and notificationLabel.Visible then
			local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local tw = TweenService:Create(notificationLabel, fadeInfo, { BackgroundTransparency = 1 })
			if stroke then
				TweenService:Create(stroke, fadeInfo, { Transparency = 1 }):Play()
			end
			tw:Play()
			tw.Completed:Connect(function()
				if notificationLabel then notificationLabel.Visible = false end
			end)
		end
	end)
end

function DrifterClientController.init()
	getOrCreateNotificationUI()
	
	-- Listen for capture key press (LMB / RT / Mobile)
	InputManager.onCapture(function()
		if currentTargetDrifter and not activeSession and KiteFlightController.isFlying() then
			NetworkService.sendCaptureEvent("RequestStartWeave", {
				drifterModel = currentTargetDrifter,
			})
		end
	end)
	
	-- Listen for server weave events
	NetworkService.Remotes.CaptureEvent.OnClientEvent:Connect(function(eventType: string, data: any)
		if eventType == "WeaveStarted" then
			DrifterClientController.startWeaveChallenge(data.drifter, data.stats, data.timeLimit)
		elseif eventType == "CaptureSuccess" then
			DrifterClientController.onCaptureSuccess(data.drifterName, data.exp, data.rarity)
		end
	end)
	
	-- Continuous Proximity Check
	RunService.RenderStepped:Connect(function(dt: number)
		DrifterClientController.stepDetection(dt)
	end)
end

function DrifterClientController.stepDetection(dt: number)
	local kite = KiteFlightController.getActiveKite()
	if not kite or not kite.PrimaryPart then
		currentTargetDrifter = nil
		return
	end
	
	local kitePos = kite.PrimaryPart.Position
	local driftersFolder = Workspace:FindFirstChild("Drifters")
	if not driftersFolder then return end
	
	local closestDrifter: Model? = nil
	local closestDist = 28 -- Detection threshold
	
	for _, drifter in driftersFolder:GetChildren() do
		if drifter:IsA("Model") and drifter.PrimaryPart then
			local dist = (drifter.PrimaryPart.Position - kitePos).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestDrifter = drifter
			end
		end
	end
	
	currentTargetDrifter = closestDrifter
	
	-- Active Weave Challenge Step
	if activeSession then
		activeSession.TimeRemaining -= dt
		if activeSession.TimeRemaining <= 0 then
			DrifterClientController.cancelWeave()
			return
		end
		
		-- Check collision with current ring
		local currentRing = activeSession.RingObjects[activeSession.CurrentRingIndex]
		if currentRing then
			local distToRing = (currentRing.Position - kitePos).Magnitude
			if distToRing < 6.5 then
				-- Passed ring!
				currentRing.Color = Color3.fromRGB(255, 235, 120)
				currentRing.Material = Enum.Material.Neon
				activeSession.CurrentRingIndex += 1
				
				if activeSession.CurrentRingIndex > #activeSession.RingObjects then
					-- Finished all checkpoints!
					local drifter = activeSession.Drifter
					DrifterClientController.cleanupRings()
					NetworkService.sendCaptureEvent("CompleteWeave", {
						drifter = drifter,
					})
				end
			end
		end
	end
end

function DrifterClientController.startWeaveChallenge(drifter: Model, stats: any, timeLimit: number)
	DrifterClientController.cleanupRings()
	
	local root = drifter.PrimaryPart
	if not root then return end
	
	local dCF = root.CFrame
	local rings: { Part } = {}
	
	-- Create 3 curved wind rings positioned around the Drifter
	local offsets = {
		dCF * CFrame.new(-10, 4, -14) * CFrame.Angles(0, math.rad(-25), 0),
		dCF * CFrame.new(12, 6, -28) * CFrame.Angles(0, math.rad(20), math.rad(15)),
		dCF * CFrame.new(0, -2, -42) * CFrame.Angles(math.rad(-15), 0, 0),
	}
	
	local ringsFolder = Workspace:FindFirstChild("ActiveWeaveRings")
	if not ringsFolder then
		ringsFolder = Instance.new("Folder")
		ringsFolder.Name = "ActiveWeaveRings"
		ringsFolder.Parent = Workspace
	end
	
	for idx, ringCF in ipairs(offsets) do
		local ring = Instance.new("Part")
		ring.Name = "WindRing_" .. idx
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.5, 9, 9)
		ring.CFrame = ringCF * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = Color3.fromRGB(140, 235, 255)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.4
		ring.CanCollide = false
		ring.Anchored = true
		ring.CastShadow = false
		ring.Parent = ringsFolder
		table.insert(rings, ring)
	end
	
	activeSession = {
		Drifter = drifter,
		CurrentRingIndex = 1,
		RingObjects = rings,
		TimeRemaining = timeLimit or 16,
	}
	
	DrifterClientController.showNotification("Windweaving Initiated!", "Steer through the 3 wind rings!")
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
end

function DrifterClientController.cancelWeave()
	DrifterClientController.cleanupRings()
	DrifterClientController.showNotification("Weave Lost", "The Drifter slipped away into the wind.")
end

function DrifterClientController.onCaptureSuccess(drifterName: string, exp: number, rarity: string)
	DrifterClientController.cleanupRings()
	DrifterClientController.showNotification(
		string.format("Captured %s!", drifterName),
		string.format("+%d EXP • %s Drifter", exp, rarity)
	)
end

return DrifterClientController
