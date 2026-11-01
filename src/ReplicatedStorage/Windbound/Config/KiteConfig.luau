--!strict
export type KiteStats = {
	Id: string,
	DisplayName: string,
	Description: string,
	Tier: number,
	BaseSpeed: number,
	MaxSpeed: number,
	MinSpeed: number,
	TurnRate: number,
	PitchRate: number,
	RollResponsiveness: number,
	LiftEfficiency: number,
	DashBoost: number,
	DashDuration: number,
	DashCooldown: number,
	MaxTetherLength: number,
	ModelColor: Color3,
}

local Kites: { [string]: KiteStats } = {
	MeadowKite = {
		Id = "MeadowKite",
		DisplayName = "Meadow Glider",
		Description = "A peaceful, handcrafted starter glider with a gentle glide ratio and relaxed soaring.",
		Tier = 1,
		BaseSpeed = 9.5,       -- Gentle starter cruise speed
		MaxSpeed = 12.0,      -- Strictly 12 studs/s max speed
		MinSpeed = 5.5,       -- Soft flare speed
		TurnRate = 2.0,       -- Calm, controllable steering
		PitchRate = 1.6,      -- Gentle pitch control
		RollResponsiveness = 1.5,
		LiftEfficiency = 1.2,
		DashBoost = 2.5,      -- Mild boost (strictly clamped to MaxSpeed 12)
		DashDuration = 0.6,
		DashCooldown = 2.5,
		MaxTetherLength = 300,
		ModelColor = Color3.fromRGB(116, 185, 255),
	},
	SwiftleafKite = {
		Id = "SwiftleafKite",
		DisplayName = "Swiftleaf Glider",
		Description = "An agile aerodynamic speed glider engineered for sharp banking and steeper dives.",
		Tier = 2,
		BaseSpeed = 13.0,
		MaxSpeed = 16.5,
		MinSpeed = 7.0,
		TurnRate = 2.8,
		PitchRate = 2.2,
		RollResponsiveness = 2.0,
		LiftEfficiency = 1.4,
		DashBoost = 3.5,
		DashDuration = 0.7,
		DashCooldown = 2.0,
		MaxTetherLength = 350,
		ModelColor = Color3.fromRGB(80, 220, 140),
	},
}

local KiteConfig = {
	DefaultKiteId = "MeadowKite",
	Catalog = Kites,
}

function KiteConfig.getKite(id: string): KiteStats?
	return Kites[id]
end

return table.freeze(KiteConfig)
