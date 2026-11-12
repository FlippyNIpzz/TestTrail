--!strict

local BaseProfile = require(script.Parent.Parent.Base.BaseProfile)
local PlayerData = {}

export type PlayerDataSchema = {
	Cash: number,
	Scrap: number,
	Rebirths: number,
	Level: number,
	CompanionId: string,
	Companions: any?,
	Inventory: { [string]: number }?,
	Base: BaseProfile.State?,
}

PlayerData.DEFAULT_DATA = {
	Cash = 100,
	Scrap = 0,
	Rebirths = 0,
	Level = 1,
	CompanionId = "ElectricCommon",
} :: PlayerDataSchema

PlayerData.DATASTORE_NAME = "PlayerSaveData_v1"
PlayerData.AUTOSAVE_INTERVAL = 300

return PlayerData