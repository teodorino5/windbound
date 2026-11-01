--!strict
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local WindService = {}

function WindService.getWindAt(position: Vector3, timeOverride: number?): Vector3
	local t = timeOverride or workspace:GetServerTimeNow()
	local cfg = GameConfig.Wind
	local base = cfg.BaseDirection
	
	local noiseSample = math.noise(
		position.X * cfg.TurbulenceScale,
		position.Z * cfg.TurbulenceScale,
		t * 0.05
	)
	local angleShift = noiseSample * math.rad(cfg.MaxTurnDegrees)
	local cosA = math.cos(angleShift)
	local sinA = math.sin(angleShift)
	
	local horizontalDir = Vector3.new(
		base.X * cosA - base.Z * sinA,
		0,
		base.X * sinA + base.Z * cosA
	).Unit
	
	local gustWave = math.sin(t * cfg.GustFrequency * math.pi * 2) 
		+ 0.45 * math.sin(t * cfg.GustFrequency * 2.1 * math.pi)
	local currentSpeed = math.clamp(cfg.BaseSpeed + (gustWave * cfg.GustMagnitude), 6, 32)
	
	local thermalY = math.noise(position.X * 0.015, position.Z * 0.015, t * 0.12) * 2.5
	
	return (horizontalDir * currentSpeed) + Vector3.new(0, thermalY, 0)
end

function WindService.getWindSpeed(position: Vector3, timeOverride: number?): number
	return WindService.getWindAt(position, timeOverride).Magnitude
end

function WindService.getWindDirection(position: Vector3, timeOverride: number?): Vector3
	local wind = WindService.getWindAt(position, timeOverride)
	if wind.Magnitude > 0.001 then
		return wind.Unit
	end
	return GameConfig.Wind.BaseDirection
end

return table.freeze(WindService)
