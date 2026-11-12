--!strict
-- Temporary testing balance. Boss names refer to ServerStorage.ArenaBosses templates.

export type OreConfig = {
	Color: Color3,
	Amount: number,
}

export type ArenaMode = {
	Name: string,
	Duration: number,
	SpawnInterval: number,
	MaxOres: number,
	Ores: { string },
	Bosses: { string },
}

export type ArenaConfig = {
	InteractionDistance: number,
	PickupScanInterval: number,
	DefaultWalkSpeed: number,
	CollectionCooldown: number,
	SpawnInset: number,
	SpeedPenaltyPerOre: number,
	MinimumCarrySpeed: number,
	DropPickupDelay: number,
	DropLifetime: number,
	MaxVisibleStack: number,
	Ores: { [string]: OreConfig },
	Modes: { ArenaMode },
}

local Config: ArenaConfig = {
	InteractionDistance = 6, -- Automatic pickup radius in studs.
	PickupScanInterval = 0.1,
	DefaultWalkSpeed = 16,
	CollectionCooldown = 0.3,
	SpawnInset = 6,
	SpeedPenaltyPerOre = 0.35,
	MinimumCarrySpeed = 8,
	DropPickupDelay = 4,
	DropLifetime = 60,
	MaxVisibleStack = 8,
	Ores = {
		IronOre = { Color = Color3.fromRGB(155, 157, 166), Amount = 1 },
		CopperOre = { Color = Color3.fromRGB(190, 112, 65), Amount = 1 },
		GoldOre = { Color = Color3.fromRGB(255, 204, 65), Amount = 1 },
		-- Molten Surge exclusive ores
		ObsidianOre = { Color = Color3.fromRGB(55, 35, 75), Amount = 1 },
		CinderOre = { Color = Color3.fromRGB(240, 105, 30), Amount = 1 },
		-- Meteor Shower exclusive ores
		MeteoricOre = { Color = Color3.fromRGB(65, 90, 125), Amount = 1 },
		AstralShard = { Color = Color3.fromRGB(245, 230, 155), Amount = 1 },
		-- Titan's Awakening exclusive ores
		TitanOre = { Color = Color3.fromRGB(50, 150, 160), Amount = 1 },
		PlatinumOre = { Color = Color3.fromRGB(220, 230, 245), Amount = 1 },
	},
	Modes = {
		{
			Name = "MoltenSurge",
			Duration = 120,
			SpawnInterval = 2.5,
			MaxOres = 25,
			Ores = { "CopperOre", "ObsidianOre", "ObsidianOre", "CinderOre" },
			Bosses = {},
		},
		{
			Name = "MeteorShower",
			Duration = 120,
			SpawnInterval = 3,
			MaxOres = 25,
			Ores = { "IronOre", "MeteoricOre", "MeteoricOre", "AstralShard" },
			Bosses = {},
		},
		{
			Name = "TitanAwakening",
			Duration = 120,
			SpawnInterval = 3.5,
			MaxOres = 20,
			Ores = { "GoldOre", "TitanOre", "PlatinumOre" },
			Bosses = { "StoneGolem" },
		},
	},
}

return Config
