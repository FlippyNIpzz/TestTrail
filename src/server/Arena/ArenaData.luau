--!strict
-- Temporary testing balance. Boss names refer to ServerStorage.ArenaBosses templates.
return {
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
	},
	Modes = {
		{ Name = "Normal", Duration = 180, SpawnInterval = 3, MaxOres = 20,
			Ores = { "IronOre", "IronOre", "CopperOre" }, Bosses = {} },
		{ Name = "Rich", Duration = 120, SpawnInterval = 2, MaxOres = 30,
			Ores = { "IronOre", "CopperOre", "GoldOre" }, Bosses = { "StoneGolem" } },
		{ Name = "Boss", Duration = 90, SpawnInterval = 4, MaxOres = 15,
			Ores = { "CopperOre", "GoldOre" }, Bosses = { "IronGolem" } },
	},
}
