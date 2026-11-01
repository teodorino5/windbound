--!strict
local GameConfig = {
	Version = "0.1.0-alpha",
	DebugMode = true,
	
	WorldBounds = {
		MinY = -50,
		MaxY = 800,
		FlightCeiling = 500,
		FlightFloor = 5,
	},
	
	Wind = {
		BaseDirection = Vector3.new(1, 0, 0.35).Unit,
		BaseSpeed = 16,
		GustFrequency = 0.12,
		GustMagnitude = 8,
		TurbulenceScale = 0.004,
		MaxTurnDegrees = 30,
	},
	
	Tags = {
		Kite = "Windbound_Kite",
		Drifter = "Windbound_Drifter",
		WindCurrent = "Windbound_WindCurrent",
		LaunchPad = "Windbound_LaunchPad",
	},
	
	Network = {
		MaxKiteSyncRate = 30,
		MaxAllowedSpeedMargin = 1.35,
	},
}

return table.freeze(GameConfig)
