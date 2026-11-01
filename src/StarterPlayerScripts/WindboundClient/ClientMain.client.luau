--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local localPlayer = Players.LocalPlayer
assert(localPlayer, "LocalPlayer must exist on client")

local WindboundShared = ReplicatedStorage:WaitForChild("Windbound")
local GameConfig = require(WindboundShared.Config:WaitForChild("GameConfig") :: ModuleScript)
local WindService = require(WindboundShared.Modules:WaitForChild("WindService") :: ModuleScript)

local controllers = script.Parent:WaitForChild("Controllers")
local KiteFlightController = require(controllers:WaitForChild("KiteFlightController") :: ModuleScript)
local DrifterClientController = require(controllers:WaitForChild("DrifterClientController") :: ModuleScript)
local UIController = require(controllers:WaitForChild("UIController") :: ModuleScript)

print("═════════════════════════════════════════════════")
print(string.format("  [WINDBOUND CLIENT] Initialized for %s  ", localPlayer.Name))
print(string.format("  Windbound v%s  ", GameConfig.Version))
print("═════════════════════════════════════════════════")

-- Initialize Controllers in sequence
KiteFlightController.init()
DrifterClientController.init()
UIController.init()

-- Hook ProximityPrompt for Launch Pad
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer == localPlayer and prompt.Name == "LaunchPrompt" then
		if not KiteFlightController.isFlying() then
			KiteFlightController.requestLaunch()
		else
			KiteFlightController.requestRecall()
		end
	end
end)

local localWind = WindService.getWindAt(Vector3.zero)
print(string.format("[WINDBOUND CLIENT] Local Wind Reading: (%.1f, %.1f, %.1f) - Speed: %.1f studs/s",
	localWind.X, localWind.Y, localWind.Z, localWind.Magnitude))

print("[WINDBOUND CLIENT] Complete Kite, Drifter, and HUD suite active.")
