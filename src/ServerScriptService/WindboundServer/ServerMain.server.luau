--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WindboundShared = ReplicatedStorage:WaitForChild("Windbound")
local GameConfig = require(WindboundShared.Config:WaitForChild("GameConfig") :: ModuleScript)
local WindService = require(WindboundShared.Modules:WaitForChild("WindService") :: ModuleScript)

local serverServices = script.Parent:WaitForChild("Services")
local KiteServerService = require(serverServices:WaitForChild("KiteServerService") :: ModuleScript)
local DrifterServerService = require(serverServices:WaitForChild("DrifterServerService") :: ModuleScript)

print("═════════════════════════════════════════════════")
print(string.format("  [WINDBOUND SERVER] v%s Initializing...  ", GameConfig.Version))
print("═════════════════════════════════════════════════")

-- Initialize Services
KiteServerService.init()
DrifterServerService.init()

local testWind = WindService.getWindAt(Vector3.zero)
print(string.format("[WINDBOUND SERVER] Wind system test: Origin wind = (%.1f, %.1f, %.1f), speed = %.1f studs/s",
	testWind.X, testWind.Y, testWind.Z, testWind.Magnitude))

print("[WINDBOUND SERVER] Kite & Drifter ecosystems live.")
