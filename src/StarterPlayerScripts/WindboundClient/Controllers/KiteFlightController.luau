--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WindboundShared = ReplicatedStorage:WaitForChild("Windbound")
local KiteConfig = require(WindboundShared.Config:WaitForChild("KiteConfig") :: ModuleScript)
local WindService = require(WindboundShared.Modules:WaitForChild("WindService") :: ModuleScript)
local NetworkService = require(WindboundShared.Network:WaitForChild("NetworkService") :: ModuleScript)

local clientFolder = script.Parent.Parent
local InputManager = require(clientFolder.Input:WaitForChild("InputManager") :: ModuleScript)
local KiteCameraController = require(script.Parent:WaitForChild("KiteCameraController") :: ModuleScript)

local KiteFlightController = {}

local activeGlider: Model? = nil
local activeStats: any = nil
local flightConnection: RBXScriptConnection? = nil
local armConnection: RBXScriptConnection? = nil

local flightAlign: AlignOrientation? = nil
local flightLinearVel: LinearVelocity? = nil

local currentYaw = 0
local currentPitch = 0
local smoothedRoll = 0
local flightTime = 0
local MAX_STAMINA = 24.0
local currentStamina = MAX_STAMINA

local lastDashTime = -99
local isDashing = false
local wasOnGroundLaunch = false
local ikRight: IKControl? = nil
local ikLeft: IKControl? = nil

function KiteFlightController.init()
	InputManager.init()
	
	InputManager.onToggleLaunch(function()
		if activeGlider then
			KiteFlightController.requestRecall()
		else
			KiteFlightController.requestLaunch()
		end
	end)
	
	InputManager.onDash(function()
		KiteFlightController.triggerDash()
	end)
	
	InputManager.onSpaceAction(function()
		if activeGlider then
			KiteFlightController.triggerDash()
		else
			local player = Players.LocalPlayer
			local char = player and player.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if humanoid and (humanoid.FloorMaterial == Enum.Material.Air or humanoid:GetState() == Enum.HumanoidStateType.Freefall) then
				KiteFlightController.requestLaunch()
			end
		end
	end)
	
	NetworkService.Remotes.KiteAction.OnClientEvent:Connect(function(action: string, data: any)
		if action == "LaunchConfirmed" then
			local glider = data.glider :: Model?
			local stats = data.stats or KiteConfig.getKite(KiteConfig.DefaultKiteId)
			KiteFlightController.startGliding(glider, stats)
		elseif action == "RecallConfirmed" then
			KiteFlightController.stopGliding()
		end
	end)
end

function KiteFlightController.requestLaunch()
	if not activeGlider then
		NetworkService.sendKiteAction("RequestLaunch", {
			kiteId = KiteConfig.DefaultKiteId,
		})
	end
end

function KiteFlightController.requestRecall()
	if activeGlider then
		NetworkService.sendKiteAction("RequestRecall", {})
	end
end

function KiteFlightController.triggerDash()
	if not activeGlider or not activeStats then return end
	local now = os.clock()
	if (now - lastDashTime) >= activeStats.DashCooldown then
		lastDashTime = now
		isDashing = true
		NetworkService.sendKiteAction("Dash", {})
	end
end

function KiteFlightController.startGliding(glider: Model?, stats: any)
	activeGlider = glider
	activeStats = stats
	flightTime = 0
	currentStamina = MAX_STAMINA
	
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end
	
	wasOnGroundLaunch = (humanoid.FloorMaterial ~= Enum.Material.Air)
	humanoid.PlatformStand = true
	
	local rootAtt = hrp:FindFirstChild("RootAttachment") :: Attachment?
	if not rootAtt then
		rootAtt = Instance.new("Attachment")
		rootAtt.Name = "RootAttachment"
		rootAtt.Parent = hrp
	end
	
	local align = Instance.new("AlignOrientation")
	align.Name = "GliderAlignOrientation"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = rootAtt
	align.Responsiveness = 28
	align.MaxTorque = math.huge
	align.RigidityEnabled = false
	align.CFrame = hrp.CFrame
	align.Parent = hrp
	flightAlign = align
	
	local lvel = Instance.new("LinearVelocity")
	lvel.Name = "GliderLinearVelocity"
	lvel.Attachment0 = rootAtt
	lvel.MaxForce = math.huge
	lvel.RelativeTo = Enum.ActuatorRelativeTo.World
	lvel.VectorVelocity = hrp.CFrame.LookVector * stats.BaseSpeed
	lvel.Parent = hrp
	flightLinearVel = lvel
	
	local _, ry, _ = hrp.CFrame:ToOrientation()
	currentYaw = ry
	smoothedRoll = 0
	
	if wasOnGroundLaunch then
		currentPitch = math.rad(10)
		hrp.AssemblyLinearVelocity = (hrp.CFrame.LookVector * (stats.BaseSpeed * 0.9)) + Vector3.new(0, 28, 0)
	else
		currentPitch = math.rad(-4)
		hrp.AssemblyLinearVelocity = (hrp.CFrame.LookVector * stats.BaseSpeed) + Vector3.new(0, 6, 0)
	end
	
	KiteCameraController.setTargetKite(glider)
	
	-- Setup IK for hands to firmly grasp the ControlBar
	local bar = glider and glider:FindFirstChild("ControlBar")
	local gripR = bar and (bar:FindFirstChild("GripR") or bar)
	local gripL = bar and (bar:FindFirstChild("GripL") or bar)
	local rHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local lHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local rArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
	local lArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
	
	if humanoid and bar and rHand and rArm then
		local ikR = Instance.new("IKControl")
		ikR.Name = "GliderIK_Right"
		ikR.Type = Enum.IKControlType.Position
		ikR.Target = gripR
		ikR.EndEffector = rHand
		ikR.ChainRoot = rArm
		ikR.Weight = 1
		ikR.Parent = humanoid
		ikRight = ikR
	end
	if humanoid and bar and lHand and lArm then
		local ikL = Instance.new("IKControl")
		ikL.Name = "GliderIK_Left"
		ikL.Type = Enum.IKControlType.Position
		ikL.Target = gripL
		ikL.EndEffector = lHand
		ikL.ChainRoot = lArm
		ikL.Weight = 1
		ikL.Parent = humanoid
		ikLeft = ikL
	end
	
	if armConnection then
		armConnection:Disconnect()
		armConnection = nil
	end
	
	armConnection = RunService.Stepped:Connect(function()
		if not activeGlider then return end
		local p = Players.LocalPlayer
		local c = p and p.Character
		if not c then return end
		local hrpPart = c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrpPart then return end
		
		-- Aerodynamic parameters from current flight
		local yawIn, pitchIn = InputManager.getSteering()
		local curPos = hrpPart.Position
		local windVec = WindService.getWindAt(curPos)
		local windHeading = CFrame.Angles(0, currentYaw, 0)
		local crossWind = windVec.Unit:Dot(windHeading.RightVector)
		local curSpeed = activeStats and activeStats.BaseSpeed or 38
		local windFreq = 6.8 + (curSpeed * 0.1)
		
		-- 1. Waist & Torso: Lean forward into slipstream, lean into turns, sway in crosswinds, aerodynamic buffeting
		local waistJoint = c:FindFirstChild("Waist", true) :: any
		local leanRoll = -yawIn * math.rad(14)
		local windSwayRoll = -crossWind * math.rad(8)
		local buffetPitch = math.sin(flightTime * windFreq) * math.rad(2.0)
		local buffetRoll = math.cos(flightTime * (windFreq * 0.85)) * math.rad(2.2)
		local torsoLeanForward = math.rad(-10) + (currentPitch * 0.2)
		if waistJoint then
			waistJoint.Transform = CFrame.Angles(torsoLeanForward + buffetPitch, yawIn * math.rad(6), leanRoll + windSwayRoll + buffetRoll)
		end
		
		-- 2. Hips & Legs: Dynamic slipstream flutter (trailing backward like a hang-glider pilot in wind)
		local baseHipPitch = math.clamp(math.rad(28) - (currentPitch * 0.5), math.rad(12), math.rad(45))
		local flutterL = math.sin(flightTime * windFreq) * math.rad(5.5)
		local flutterR = math.sin((flightTime * windFreq) + 1.4) * math.rad(5.5)
		local driftL = math.cos(flightTime * (windFreq * 0.7)) * math.rad(3.0)
		local driftR = math.cos((flightTime * (windFreq * 0.7)) + 2.0) * math.rad(3.0)
		
		local rh = c:FindFirstChild("RightHip", true) :: any
		local lh = c:FindFirstChild("LeftHip", true) :: any
		local rk = c:FindFirstChild("RightKnee", true) :: any
		local lk = c:FindFirstChild("LeftKnee", true) :: any
		
		local kneeBendL = math.rad(18) + (flutterL * 0.4)
		local kneeBendR = math.rad(18) + (flutterR * 0.4)
		
		if lh then
			lh.Transform = CFrame.Angles(baseHipPitch + flutterL, driftL + (crossWind * math.rad(6)), math.rad(-6) + (leanRoll * 0.4))
		end
		if rh then
			rh.Transform = CFrame.Angles(baseHipPitch + flutterR, driftR + (crossWind * math.rad(6)), math.rad(6) + (leanRoll * 0.4))
		end
		if lk then
			lk.Transform = CFrame.Angles(kneeBendL, 0, 0)
		end
		if rk then
			rk.Transform = CFrame.Angles(kneeBendR, 0, 0)
		end
		
		-- 3. Head & Neck: Look ahead along flight path with subtle buffeting
		local neckJoint = c:FindFirstChild("Neck", true) :: any
		if neckJoint then
			local headPitch = math.rad(-14) - (currentPitch * 0.3)
			local headFlutter = math.sin(flightTime * 9) * math.rad(1.0)
			neckJoint.Transform = CFrame.Angles(headPitch, headFlutter + (yawIn * math.rad(5)), 0)
		end
		
		-- 4. Shoulders & Arms: Keep hands raised grasping overhead
		local rs = c:FindFirstChild("RightShoulder", true) :: any
		local ls = c:FindFirstChild("LeftShoulder", true) :: any
		if rs then
			rs.Transform = CFrame.Angles(math.rad(152), math.rad(-14), math.rad(16))
		end
		if ls then
			ls.Transform = CFrame.Angles(math.rad(152), math.rad(14), math.rad(-16))
		end
		local re = c:FindFirstChild("RightElbow", true) :: any
		local le = c:FindFirstChild("LeftElbow", true) :: any
		if re then re.Transform = CFrame.Angles(math.rad(18), 0, 0) end
		if le then le.Transform = CFrame.Angles(math.rad(18), 0, 0) end
	end)
	
	if flightConnection then
		flightConnection:Disconnect()
	end
	
	flightConnection = RunService.RenderStepped:Connect(function(dt: number)
		KiteFlightController.stepFlight(dt)
	end)
	
	print("[KiteFlightController] Soaring hang-glider flight active!")
end

function KiteFlightController.stopGliding()
	if flightConnection then
		flightConnection:Disconnect()
		flightConnection = nil
	end
	if armConnection then
		armConnection:Disconnect()
		armConnection = nil
	end
	if ikRight then
		ikRight:Destroy()
		ikRight = nil
	end
	if ikLeft then
		ikLeft:Destroy()
		ikLeft = nil
	end
	KiteCameraController.setTargetKite(nil)
	
	activeGlider = nil
	activeStats = nil
	isDashing = false
	
	local player = Players.LocalPlayer
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.AssemblyLinearVelocity = Vector3.zero
		end
	end
	
	if flightAlign then
		flightAlign:Destroy()
		flightAlign = nil
	end
	if flightLinearVel then
		flightLinearVel:Destroy()
		flightLinearVel = nil
	end
	
	print("[KiteFlightController] Glider stowed, returned to ground.")
end

function KiteFlightController.stepFlight(dt: number)
	if not activeGlider or not activeStats or not flightAlign or not flightLinearVel then
		return
	end
	
	flightTime += dt
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	
	local yawInput, pitchInput = InputManager.getSteering()
	
	local currentPos = hrp.Position
	local wind = WindService.getWindAt(currentPos)
	local windDir = wind.Unit
	local windSpeed = wind.Magnitude
	
	currentYaw -= (yawInput * activeStats.TurnRate * dt)
	
	currentPitch = math.clamp(
		currentPitch + (pitchInput * activeStats.PitchRate * dt),
		math.rad(-48),
		math.rad(38)
	)
	
	if math.abs(pitchInput) < 0.1 then
		local cruiseAngle = math.rad(-6)
		currentPitch = currentPitch + (cruiseAngle - currentPitch) * math.clamp(dt * 2.5, 0, 1)
	end
	
	local turnBank = -yawInput * math.rad(36)
	local headingForward = CFrame.Angles(0, currentYaw, 0).LookVector
	local headingRight = CFrame.Angles(0, currentYaw, 0).RightVector
	local crossWindDot = windDir:Dot(headingRight)
	local windLean = -crossWindDot * math.rad(12)
	local flutter = math.sin(flightTime * 6.5) * math.rad(1.2)
	
	local targetRoll = turnBank + windLean + flutter
	smoothedRoll = smoothedRoll + (targetRoll - smoothedRoll) * math.clamp(dt * 10, 0, 1)
	
	local flightRot = CFrame.Angles(0, currentYaw, 0)
		* CFrame.Angles(currentPitch, 0, smoothedRoll)
	
	flightAlign.CFrame = flightRot
	
	-- Launch acceleration ramp: starts at 5.5 studs/s, ramps to BaseSpeed over 1.6s
	local launchProgress = math.clamp(flightTime / 1.6, 0, 1)
	local baseTarget = activeStats.BaseSpeed
	local rampedBase = 5.5 + (baseTarget - 5.5) * launchProgress
	
	local forwardSpeed = rampedBase
	
	if currentPitch < 0 then
		local diveFactor = -currentPitch / math.rad(48)
		forwardSpeed += (diveFactor * (activeStats.MaxSpeed - baseTarget))
	elseif currentPitch > 0 then
		local climbFactor = currentPitch / math.rad(38)
		forwardSpeed = math.max(activeStats.MinSpeed, forwardSpeed - (climbFactor * 6.0))
	end
	
	local now = os.clock()
	if isDashing then
		if (now - lastDashTime) <= activeStats.DashDuration then
			forwardSpeed += activeStats.DashBoost
		else
			isDashing = false
		end
	end
	
	local headwindFactor = math.max(0, -headingForward:Dot(windDir))
	local tailwindFactor = math.max(0, headingForward:Dot(windDir))
	
	forwardSpeed += (tailwindFactor * windSpeed * 0.20)
	local thermalLift = (headwindFactor * windSpeed * 0.35) * activeStats.LiftEfficiency
	
	-- STRICTLY CLAMP SPEED TO MAXSPEED (12 studs/s max for Meadow Glider!)
	forwardSpeed = math.clamp(forwardSpeed, activeStats.MinSpeed, activeStats.MaxSpeed)
	
	local crosswind = wind - (headingForward * headingForward:Dot(wind))
	local driftVelocity = crosswind * 0.12
	
	-- Realistic glide physics: climbing trades excess forward speed, no infinite altitude gain!
	local excessSpeed = math.max(0, forwardSpeed - activeStats.MinSpeed)
	local verticalClimb = math.sin(currentPitch) * excessSpeed * 0.75
	local naturalSink = -2.6 -- Steady descent toward ground
	local verticalVelocity = naturalSink + verticalClimb + thermalLift
	
	-- Drain flight endurance
	currentStamina = math.max(0, currentStamina - dt)
	if currentStamina <= 0 then
		KiteFlightController.requestRecall()
		return
	end
	
	if flightTime < 0.6 and wasOnGroundLaunch then
		verticalVelocity = math.max(verticalVelocity, 14)
	end
	
	local forwardVector = flightRot.LookVector
	local velocity = (forwardVector * forwardSpeed) 
		+ Vector3.new(0, verticalVelocity, 0) 
		+ driftVelocity
	
	flightLinearVel.VectorVelocity = velocity
	
	KiteCameraController.setDashFOV(isDashing)
	KiteCameraController.update(dt)
	
	if flightTime > 1.2 then
		local excludeList = { character }
		local ringsFolder = Workspace:FindFirstChild("ActiveWeaveRings")
		if ringsFolder then table.insert(excludeList, ringsFolder) end
		local driftersFolder = Workspace:FindFirstChild("Drifters")
		if driftersFolder then table.insert(excludeList, driftersFolder) end
		
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = excludeList
		
		local groundRay = Workspace:Raycast(currentPos, Vector3.new(0, -3.2, 0), rayParams)
		if groundRay and velocity.Y < -0.5 then
			local hitPart = groundRay.Instance
			-- Only land on solid walkable ground (must have CanCollide = true and not be a weave ring)
			if hitPart and hitPart.CanCollide and not hitPart.Name:find("WindRing") then
				KiteFlightController.requestRecall()
			end
		end
	end
end

function KiteFlightController.isFlying(): boolean
	return activeGlider ~= nil
end

function KiteFlightController.addStamina(amount: number)
	currentStamina = math.clamp(currentStamina + amount, 0, MAX_STAMINA)
end

function KiteFlightController.getStaminaFraction(): number
	return currentStamina / MAX_STAMINA
end

function KiteFlightController.getActiveKite(): Model?
	return activeGlider
end

return KiteFlightController
