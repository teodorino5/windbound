--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local KiteCameraController = {}

local camera = Workspace.CurrentCamera :: Camera
local currentGlider: Model? = nil
local targetFOV = 70
local currentCamPos: Vector3? = nil

local BASE_DISTANCE = 14.0
local BASE_HEIGHT = 4.2
local LOOK_AHEAD = 14.0

function KiteCameraController.setTargetKite(glider: Model?)
	currentGlider = glider
	if glider then
		camera.CameraType = Enum.CameraType.Scriptable
		local player = Players.LocalPlayer
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			currentCamPos = hrp.Position - (hrp.CFrame.LookVector * BASE_DISTANCE) + Vector3.new(0, BASE_HEIGHT, 0)
			camera.CFrame = CFrame.lookAt(currentCamPos, hrp.Position + (hrp.CFrame.LookVector * LOOK_AHEAD))
		end
	else
		camera.CameraType = Enum.CameraType.Custom
		local player = Players.LocalPlayer
		if player and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		camera.FieldOfView = 70
		currentCamPos = nil
	end
end

function KiteCameraController.setDashFOV(isDashing: boolean)
	targetFOV = isDashing and 82 or 70
end

function KiteCameraController.update(dt: number)
	if not currentGlider then return end
	local player = Players.LocalPlayer
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end
	
	local rootCF = hrp.CFrame
	local rootPos = rootCF.Position
	local lookVec = rootCF.LookVector
	
	local idealPos = rootPos - (lookVec * BASE_DISTANCE) + Vector3.new(0, BASE_HEIGHT, 0)
	
	if not currentCamPos then
		currentCamPos = idealPos
	else
		local blend = math.clamp(dt * 10, 0, 1)
		currentCamPos = currentCamPos:Lerp(idealPos, blend)
	end
	
	local focusPoint = rootPos + (lookVec * LOOK_AHEAD)
	camera.CFrame = CFrame.lookAt(currentCamPos, focusPoint, rootCF.UpVector)
	
	if math.abs(camera.FieldOfView - targetFOV) > 0.1 then
		camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * math.clamp(dt * 8, 0, 1)
	end
end

return KiteCameraController
