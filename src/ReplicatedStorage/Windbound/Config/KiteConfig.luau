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
		Description = "A peaceful, handcrafted glider with a gentle glide ratio and relaxed soaring.",
		Tier = 1,
		BaseSpeed = 22,        -- Calm, relaxed cruise speed (down from 38)
		MaxSpeed = 42,         -- Controlled dive speed (down from 72)
		MinSpeed = 10,         -- Gentle flare/climb speed
		TurnRate = 2.8,        -- Smooth, controllable banking
		PitchRate = 2.4,       -- Gentle pitch control
		RollResponsiveness = 2.0,
		LiftEfficiency = 1.4,  -- Steady thermal catching
		DashBoost = 20,
		DashDuration = 0.7,
		DashCooldown = 2.5,
		MaxTetherLength = 300,
		ModelColor = Color3.fromRGB(116, 185, 255),
	},
	SwiftleafKite = {
		Id = "SwiftleafKite",
		DisplayName = "Swiftleaf Glider",
		Description = "An agile aerodynamic speed glider engineered for sharp banking and steep dives.",
		Tier = 2,
		BaseSpeed = 28,        -- Agile cruising speed (down from 46)
		MaxSpeed = 52,         -- High speed dive (down from 88)
		MinSpeed = 12,
		TurnRate = 3.6,        -- Responsive turns
		PitchRate = 3.0,
		RollResponsiveness = 2.6,
		LiftEfficiency = 1.6,
		DashBoost = 26,
		DashDuration = 0.75,
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
