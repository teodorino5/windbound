--!strict
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local turbine = Workspace:WaitForChild("GreenwakeMeadows", 10)
	and Workspace.GreenwakeMeadows:WaitForChild("Props", 10)
	and Workspace.GreenwakeMeadows.Props:WaitForChild("SolarWindTurbine", 10)

if turbine then
	local rotor = turbine:WaitForChild("RotorAssembly", 5) :: Model?
	local hub = rotor and rotor:FindFirstChild("SpinnerHub") :: BasePart?
	
	if rotor and hub then
		local basePivot = rotor:GetPivot()
		local currentAngle = 0
		local ROTATION_SPEED = 1.2
		
		RunService.RenderStepped:Connect(function(dt)
			currentAngle += ROTATION_SPEED * dt
			rotor:PivotTo(basePivot * CFrame.Angles(0, 0, currentAngle))
		end)
	end
end
