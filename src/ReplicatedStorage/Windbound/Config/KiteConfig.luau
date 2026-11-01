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
		Description = "A handcrafted glider with balanced glide ratio and responsive thermal soaring.",
		Tier = 1,
		BaseSpeed = 38,
		MaxSpeed = 72,
		MinSpeed = 16,
		TurnRate = 3.6,        -- Fast, responsive steering
		PitchRate = 3.2,       -- Sharp climb and dive
		RollResponsiveness = 2.4,
		LiftEfficiency = 1.6,  -- Strong thermal catching
		DashBoost = 42,
		DashDuration = 0.75,
		DashCooldown = 2.8,
		MaxTetherLength = 300,
		ModelColor = Color3.fromRGB(116, 185, 255),
	},
	SwiftleafKite = {
		Id = "SwiftleafKite",
		DisplayName = "Swiftleaf Glider",
		Description = "An ultra-aerodynamic speed glider engineered for sharp banking, aerobatics, and steep dives.",
		Tier = 2,
		BaseSpeed = 46,
		MaxSpeed = 88,
		MinSpeed = 18,
		TurnRate = 4.8,        -- Razor-sharp agile turns
		PitchRate = 4.0,       -- Instant climb/dive response
		RollResponsiveness = 3.0,
		LiftEfficiency = 1.8,
		DashBoost = 55,
		DashDuration = 0.8,
		DashCooldown = 2.2,
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
