--!strict

--[[
	ProgressionConfig.luau
	Layer: 1 (Data)
	Description: Configuration rules, level thresholds, and rebirth multipliers.
]]

export type PlayerProgressionConfig = {
	StartingLevel: number,
	StartingXP: number,
	IncreasingXP: boolean,
	MaxLevel: number,
	XPFormula: (level: number) -> number,
}

export type BaseProgressionConfig = {
	StartingLevel: number,
	IndependentFromPlayerLevel: boolean,
	UpgradeRequiresCash: boolean,
	UpgradeRequiresMaterials: boolean,
	MaxLevel: number,
	UpgradeCosts: { [number]: number },
}

export type RebirthProgressionConfig = {
	Enabled: boolean,
	RequiredLevel: number,
	ResetPlayerLevel: boolean,
	ResetBaseLevel: boolean,
	PlayerResetLevel: number,
	BaseResetLevel: number,
	ResetInventory: boolean,
	ResetCompanions: boolean,
	ResetCash: boolean,
}

export type ProgressionConfigType = {
	Player: PlayerProgressionConfig,
	Base: BaseProgressionConfig,
	Rebirth: RebirthProgressionConfig,
}

local ProgressionConfig: ProgressionConfigType = {
	Player = {
		StartingLevel = 1,
		StartingXP = 0,
		IncreasingXP = true,
		MaxLevel = 100,
		XPFormula = function(level: number): number
			return math.floor(100 * (level ^ 1.5))
		end,
	},

	Base = {
		StartingLevel = 1,
		IndependentFromPlayerLevel = true,
		UpgradeRequiresCash = true,
		UpgradeRequiresMaterials = false,
		MaxLevel = 10,
		UpgradeCosts = {
			[1] = 100,
			[2] = 250,
			[3] = 500,
			[4] = 1000,
			[5] = 2500,
			[6] = 5000,
			[7] = 10000,
			[8] = 25000,
			[9] = 50000,
			[10] = 100000,
		},
	},

	Rebirth = {
		Enabled = true,
		RequiredLevel = 50,
		ResetPlayerLevel = true,
		ResetBaseLevel = true,
		PlayerResetLevel = 1,
		BaseResetLevel = 1,
		ResetInventory = false,
		ResetCompanions = false,
		ResetCash = true,
	},
}

return ProgressionConfig
