--!strict
local Players = game:GetService("Players")

local RESCUE_ALTITUDE = 85
local SPAWN_RETURN_CFRAME = CFrame.new(-65, 164.5, 0)

task.spawn(function()
	while true do
		task.wait(0.35)
		for _, player in Players:GetPlayers() do
			local char = player.Character
			if char then
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				if hrp and humanoid and humanoid.Health > 0 then
					if hrp.Position.Y < RESCUE_ALTITUDE then
						hrp.AssemblyLinearVelocity = Vector3.zero
						hrp.AssemblyAngularVelocity = Vector3.zero
						hrp.CFrame = SPAWN_RETURN_CFRAME
						print(string.format("[WINDBOUND] %s caught by meadow updraft", player.Name))
					end
				end
			end
		end
	end
end)
