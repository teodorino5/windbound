--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WindboundShared = ReplicatedStorage:WaitForChild("Windbound")
local KiteConfig = require(WindboundShared.Config:WaitForChild("KiteConfig") :: ModuleScript)
local WindService = require(WindboundShared.Modules:WaitForChild("WindService") :: ModuleScript)
local NetworkService = require(WindboundShared.Network:WaitForChild("NetworkService") :: ModuleScript)

local clientFolder = script.Parent.Parent
local KiteFlightController = require(script.Parent:WaitForChild("KiteFlightController") :: ModuleScript)

local UIController = {}

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

-- HUD Elements
local hudGui: ScreenGui
local compassNeedle: ImageLabel
local windSpeedLabel: TextLabel
local kiteNameLabel: TextLabel
local flightStatusLabel: TextLabel
local speedAltitudeLabel: TextLabel
local dashFillBar: Frame
local controlsPromptLabel: TextLabel

local currentEquippedId = "MeadowKite"

local function createCorner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function createStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.2
	s.Transparency = 0.4
	s.Parent = parent
	return s
end

function UIController.init()
	-- 1. Main ScreenGui
	hudGui = Instance.new("ScreenGui")
	hudGui.Name = "WindboundHUD"
	hudGui.ResetOnSpawn = false
	hudGui.IgnoreGuiInset = true
	hudGui.Parent = pGui
	
	-- ====================================================================
	-- 2. TOP-RIGHT WIND COMPASS WIDGET
	-- ====================================================================
	local compassFrame = Instance.new("Frame")
	compassFrame.Name = "CompassFrame"
	compassFrame.Size = UDim2.new(0, 160, 0, 75)
	compassFrame.Position = UDim2.new(1, -180, 0, 30)
	compassFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 26)
	compassFrame.BackgroundTransparency = 0.35
	createCorner(compassFrame, 16)
	createStroke(compassFrame, Color3.fromRGB(116, 215, 175), 1.2)
	compassFrame.Parent = hudGui
	
	-- Compass dial icon
	local dialCircle = Instance.new("Frame")
	dialCircle.Name = "Dial"
	dialCircle.Size = UDim2.new(0, 48, 0, 48)
	dialCircle.Position = UDim2.new(0, 12, 0.5, -24)
	dialCircle.BackgroundColor3 = Color3.fromRGB(30, 45, 38)
	dialCircle.BackgroundTransparency = 0.2
	createCorner(dialCircle, 24)
	createStroke(dialCircle, Color3.fromRGB(140, 240, 200), 1)
	dialCircle.Parent = compassFrame
	
	-- Wind Needle
	local needle = Instance.new("Frame")
	needle.Name = "Needle"
	needle.Size = UDim2.new(0, 4, 0, 20)
	needle.Position = UDim2.new(0.5, -2, 0.5, -10)
	needle.BackgroundColor3 = Color3.fromRGB(116, 185, 255)
	createCorner(needle, 2)
	needle.Parent = dialCircle
	
	-- Arrow tip
	local needleTip = Instance.new("Frame")
	needleTip.Size = UDim2.new(0, 8, 0, 8)
	needleTip.Position = UDim2.new(0.5, -4, 0, -4)
	needleTip.BackgroundColor3 = Color3.fromRGB(255, 220, 110)
	needleTip.Rotation = 45
	createCorner(needleTip, 2)
	needleTip.Parent = needle
	
	compassNeedle = dialCircle :: any
	
	local windTitle = Instance.new("TextLabel")
	windTitle.Size = UDim2.new(0, 90, 0, 16)
	windTitle.Position = UDim2.new(0, 68, 0, 16)
	windTitle.BackgroundTransparency = 1
	windTitle.Text = "WIND SPEED"
	windTitle.TextColor3 = Color3.fromRGB(160, 210, 185)
	windTitle.TextSize = 10
	windTitle.Font = Enum.Font.GothamBold
	windTitle.TextXAlignment = Enum.TextXAlignment.Left
	windTitle.Parent = compassFrame
	
	windSpeedLabel = Instance.new("TextLabel")
	windSpeedLabel.Size = UDim2.new(0, 90, 0, 26)
	windSpeedLabel.Position = UDim2.new(0, 68, 0, 32)
	windSpeedLabel.BackgroundTransparency = 1
	windSpeedLabel.Text = "16.0 s/s"
	windSpeedLabel.TextColor3 = Color3.fromRGB(250, 252, 245)
	windSpeedLabel.TextSize = 18
	windSpeedLabel.Font = Enum.Font.GothamBold
	windSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
	windSpeedLabel.Parent = compassFrame
	
	-- ====================================================================
	-- 3. BOTTOM-LEFT KITE STATUS & SWAPPER
	-- ====================================================================
	local kiteCard = Instance.new("Frame")
	kiteCard.Name = "KiteStatusCard"
	kiteCard.Size = UDim2.new(0, 240, 0, 105)
	kiteCard.Position = UDim2.new(0, 30, 1, -135)
	kiteCard.BackgroundColor3 = Color3.fromRGB(20, 30, 26)
	kiteCard.BackgroundTransparency = 0.35
	createCorner(kiteCard, 16)
	createStroke(kiteCard, Color3.fromRGB(116, 215, 175), 1.2)
	kiteCard.Parent = hudGui
	
	kiteNameLabel = Instance.new("TextLabel")
	kiteNameLabel.Size = UDim2.new(0, 150, 0, 22)
	kiteNameLabel.Position = UDim2.new(0, 16, 0, 12)
	kiteNameLabel.BackgroundTransparency = 1
	kiteNameLabel.Text = "Meadow Kite"
	kiteNameLabel.TextColor3 = Color3.fromRGB(250, 252, 245)
	kiteNameLabel.TextSize = 18
	kiteNameLabel.Font = Enum.Font.GothamBold
	kiteNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	kiteNameLabel.Parent = kiteCard
	
	flightStatusLabel = Instance.new("TextLabel")
	flightStatusLabel.Size = UDim2.new(0, 60, 0, 18)
	flightStatusLabel.Position = UDim2.new(1, -74, 0, 14)
	flightStatusLabel.BackgroundColor3 = Color3.fromRGB(35, 55, 45)
	flightStatusLabel.Text = "STOWED"
	flightStatusLabel.TextColor3 = Color3.fromRGB(140, 240, 180)
	flightStatusLabel.TextSize = 10
	flightStatusLabel.Font = Enum.Font.GothamBold
	createCorner(flightStatusLabel, 6)
	flightStatusLabel.Parent = kiteCard
	
	speedAltitudeLabel = Instance.new("TextLabel")
	speedAltitudeLabel.Size = UDim2.new(1, -32, 0, 18)
	speedAltitudeLabel.Position = UDim2.new(0, 16, 0, 38)
	speedAltitudeLabel.BackgroundTransparency = 1
	speedAltitudeLabel.Text = "Airspeed: 0 s/s  •  Alt: 162m"
	speedAltitudeLabel.TextColor3 = Color3.fromRGB(160, 210, 185)
	speedAltitudeLabel.TextSize = 12
	speedAltitudeLabel.Font = Enum.Font.GothamMedium
	speedAltitudeLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedAltitudeLabel.Parent = kiteCard
	
	-- Dash cooldown bar
	local dashBarBg = Instance.new("Frame")
	dashBarBg.Name = "DashBarBg"
	dashBarBg.Size = UDim2.new(1, -32, 0, 6)
	dashBarBg.Position = UDim2.new(0, 16, 0, 62)
	dashBarBg.BackgroundColor3 = Color3.fromRGB(35, 45, 40)
	createCorner(dashBarBg, 3)
	dashBarBg.Parent = kiteCard
	
	dashFillBar = Instance.new("Frame")
	dashFillBar.Name = "DashFill"
	dashFillBar.Size = UDim2.new(1, 0, 1, 0)
	dashFillBar.BackgroundColor3 = Color3.fromRGB(116, 185, 255)
	createCorner(dashFillBar, 3)
	dashFillBar.Parent = dashBarBg
	
	-- Quick Switch Buttons (Meadow vs Swiftleaf)
	local swapFrame = Instance.new("Frame")
	swapFrame.Size = UDim2.new(1, -32, 0, 22)
	swapFrame.Position = UDim2.new(0, 16, 0, 74)
	swapFrame.BackgroundTransparency = 1
	swapFrame.Parent = kiteCard
	
	local btnMeadow = Instance.new("TextButton")
	btnMeadow.Size = UDim2.new(0.48, 0, 1, 0)
	btnMeadow.BackgroundColor3 = Color3.fromRGB(30, 48, 40)
	btnMeadow.Text = "[1] Meadow"
	btnMeadow.TextColor3 = Color3.fromRGB(240, 245, 240)
	btnMeadow.TextSize = 11
	btnMeadow.Font = Enum.Font.GothamMedium
	createCorner(btnMeadow, 6)
	btnMeadow.Parent = swapFrame
	btnMeadow.MouseButton1Click:Connect(function()
		UIController.switchKite("MeadowKite")
	end)
	
	local btnSwiftleaf = Instance.new("TextButton")
	btnSwiftleaf.Size = UDim2.new(0.48, 0, 1, 0)
	btnSwiftleaf.Position = UDim2.new(0.52, 0, 0, 0)
	btnSwiftleaf.BackgroundColor3 = Color3.fromRGB(30, 48, 40)
	btnSwiftleaf.Text = "[2] Swiftleaf"
	btnSwiftleaf.TextColor3 = Color3.fromRGB(240, 245, 240)
	btnSwiftleaf.TextSize = 11
	btnSwiftleaf.Font = Enum.Font.GothamMedium
	createCorner(btnSwiftleaf, 6)
	btnSwiftleaf.Parent = swapFrame
	btnSwiftleaf.MouseButton1Click:Connect(function()
		UIController.switchKite("SwiftleafKite")
	end)
	
	-- Keybinds [1] and [2] for quick switching
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.One then
			UIController.switchKite("MeadowKite")
		elseif input.KeyCode == Enum.KeyCode.Two then
			UIController.switchKite("SwiftleafKite")
		end
	end)
	
	-- ====================================================================
	-- 4. BOTTOM-CENTER CONTROLS PROMPT PILL
	-- ====================================================================
	local promptPill = Instance.new("Frame")
	promptPill.Name = "PromptPill"
	promptPill.Size = UDim2.new(0, 380, 0, 36)
	promptPill.Position = UDim2.new(0.5, -190, 1, -60)
	promptPill.BackgroundColor3 = Color3.fromRGB(20, 30, 26)
	promptPill.BackgroundTransparency = 0.35
	createCorner(promptPill, 18)
	createStroke(promptPill, Color3.fromRGB(116, 215, 175), 1.2)
	promptPill.Parent = hudGui
	
	controlsPromptLabel = Instance.new("TextLabel")
	controlsPromptLabel.Size = UDim2.new(1, 0, 1, 0)
	controlsPromptLabel.BackgroundTransparency = 1
	controlsPromptLabel.Text = "[E] Launch Kite  •  [1/2] Switch Kite"
	controlsPromptLabel.TextColor3 = Color3.fromRGB(240, 248, 242)
	controlsPromptLabel.TextSize = 13
	controlsPromptLabel.Font = Enum.Font.GothamMedium
	controlsPromptLabel.Parent = promptPill
	
	-- RenderStepped update loop
	RunService.RenderStepped:Connect(function(dt)
		UIController.update(dt)
	end)
	
	print("[UIController] Solarpunk HUD loaded successfully.")
end

function UIController.switchKite(kiteId: string)
	if KiteFlightController.isFlying() then return end
	currentEquippedId = kiteId
	local stats = KiteConfig.getKite(kiteId)
	if stats then
		kiteNameLabel.Text = stats.DisplayName
	end
	NetworkService.sendKiteAction("SwitchKite", { kiteId = kiteId })
end

function UIController.update(dt: number)
	local cam = Workspace.CurrentCamera
	local kite = KiteFlightController.getActiveKite()
	local isFlying = KiteFlightController.isFlying()
	
	-- 1. Wind Reading
	local samplePos = kite and kite.PrimaryPart and kite.PrimaryPart.Position or (player.Character and player.Character:GetPivot().Position) or Vector3.zero
	local wind = WindService.getWindAt(samplePos)
	local windSpeed = wind.Magnitude
	windSpeedLabel.Text = string.format("%.1f s/s", windSpeed)
	
	-- Rotate compass needle relative to camera
	if cam then
		local camYaw = math.atan2(-cam.CFrame.LookVector.X, -cam.CFrame.LookVector.Z)
		local windAngle = math.atan2(wind.X, wind.Z)
		local relativeAngle = math.deg(windAngle - camYaw)
		dialCircle = compassNeedle
		if dialCircle then
			dialCircle.Rotation = -relativeAngle
		end
	end
	
	-- 2. Kite Status & Prompts
	if isFlying and kite and kite.PrimaryPart then
		flightStatusLabel.Text = "FLYING"
		flightStatusLabel.BackgroundColor3 = Color3.fromRGB(70, 55, 20)
		flightStatusLabel.TextColor3 = Color3.fromRGB(255, 220, 110)
		
		local vel = kite.PrimaryPart.AssemblyLinearVelocity.Magnitude
		local alt = math.floor(kite.PrimaryPart.Position.Y)
		speedAltitudeLabel.Text = string.format("Airspeed: %.1f s/s  •  Alt: %dm", vel, alt)
		
		controlsPromptLabel.Text = "[A/D] Steer  •  [W] Dive  •  [S] Climb  •  [Shift] Dash  •  [E] Stow"
	else
		flightStatusLabel.Text = "STOWED"
		flightStatusLabel.BackgroundColor3 = Color3.fromRGB(35, 55, 45)
		flightStatusLabel.TextColor3 = Color3.fromRGB(140, 240, 180)
		
		local alt = player.Character and math.floor(player.Character:GetPivot().Position.Y) or 160
		speedAltitudeLabel.Text = string.format("On Foot  •  Meadow Alt: %dm", alt)
		
		controlsPromptLabel.Text = "[E] Open Glider  •  [1/2] Switch Glider"
	end
end

return UIController
