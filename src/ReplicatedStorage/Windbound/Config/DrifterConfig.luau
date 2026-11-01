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
		Speed = 11,
		WanderRadius = 45,
		AltitudeMin = 30,
		AltitudeMax = 80,
		HoverBobAmplitude = 2.4,
		HoverBobFrequency = 0.55,
		CaptureRadius = 38,
		CaptureCheckpoints = 3,
		CaptureTimeLimit = 22,
		ExpReward = 25,
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
