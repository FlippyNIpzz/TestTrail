--!strict

--[[
	PlayerDataTemplate.luau
	Layer: 1 (Data)
	Description: Defines the strict types and initial template for player save data.
]]

export type CardRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type CardStats = {
	Damage: number,
	Stamina: number,
	Health: number,
	Special: number,
}

export type CompanionCard = {
	Id: string,
	CardName: string,
	Rarity: CardRarity,
	Grade: number?, -- nil if unassigned, or 1-10 when graded
	Condition: number, -- 0 to 100 percentage
	Stats: CardStats,
}

export type CardPack = {
	Id: string,
	PackType: string,
	Sealed: boolean,
}

export type CompanionMode = "Home" | "Follow" | "Arena" | "ToBattle"

export type Companion = {
	Id: string,
	SourceCardId: string,
	Name: string,
	Level: number,
	CurrentHealth: number,
	MaxHealth: number,
	Mode: CompanionMode,
	Stats: CardStats,
}

export type BaseData = {
	Level: number,
	InspectorLevel: number,
	PlacedAssets: { [string]: string },
}

export type PermanentMultipliers = {
	LevelingSpeed: number,
	ScrapProcessingSpeed: number,
	BaseMovementSpeed: number,
	PackOdds: number,
}

export type PlayerData = {
	SchemaVersion: number,
	Cash: number,
	RebirthCount: number,
	Multipliers: PermanentMultipliers,
	Base: BaseData,
	Inventory: {
		CompanionCards: { [string]: CompanionCard },
		CardPacks: { [string]: CardPack },
	},
	Companions: {
		Owned: { [string]: Companion },
		ActiveId: string?,
	},
}

local PlayerDataTemplate = {}

PlayerDataTemplate.CURRENT_SCHEMA_VERSION = 1

PlayerDataTemplate.DEFAULT_DATA: PlayerData = {
	SchemaVersion = PlayerDataTemplate.CURRENT_SCHEMA_VERSION,
	Cash = 0,
	RebirthCount = 0,

	Multipliers = {
		LevelingSpeed = 1.0,
		ScrapProcessingSpeed = 1.0,
		BaseMovementSpeed = 1.0,
		PackOdds = 1.0,
	},

	Base = {
		Level = 1,
		InspectorLevel = 1,
		PlacedAssets = {},
	},

	Inventory = {
		CompanionCards = {},
		CardPacks = {},
	},

	Companions = {
		Owned = {},
		ActiveId = nil,
	},
}

return PlayerDataTemplate
