--!strict
export type DrifterStats = {
	Id: string,
	DisplayName: string,
	Description: string,
	Rarity: "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary",
	Speed: number,
	WanderRadius: number,
	AltitudeMin: number,
	AltitudeMax: number,
	HoverBobAmplitude: number,
	HoverBobFrequency: number,
	CaptureRadius: number,
	CaptureCheckpoints: number,
	CaptureTimeLimit: number,
	ExpReward: number,
	BodyColor: Color3,
	WingColor: Color3,
}

local Drifters: { [string]: DrifterStats } = {
	Leafglider = {
		Id = "Leafglider",
		DisplayName = "Leafglider",
		Description = "A docile, leaf-winged airborne creature that floats along gentle meadow updrafts.",
		Rarity = "Common",
		Speed = 10,
		WanderRadius = 60,
		AltitudeMin = 30,
		AltitudeMax = 80,
		HoverBobAmplitude = 3.0,
		HoverBobFrequency = 0.5,
		CaptureRadius = 24,
		CaptureCheckpoints = 3,
		CaptureTimeLimit = 16,
		ExpReward = 20,
		BodyColor = Color3.fromRGB(168, 230, 150),
		WingColor = Color3.fromRGB(90, 195, 120),
	},
}

local DrifterConfig = {
	Catalog = Drifters,
}

function DrifterConfig.getDrifter(id: string): DrifterStats?
	return Drifters[id]
end

return table.freeze(DrifterConfig)
