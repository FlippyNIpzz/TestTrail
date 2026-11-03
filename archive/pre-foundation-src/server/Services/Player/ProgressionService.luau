--!strict

--[[
	ProgressionService.luau
	Layer: 3 (State & Manager)
	Description: Manages player cash, level-ups, and rebirth progression
	             according to shared configurations.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProgressionConfig = require(Shared:WaitForChild("Configs"):WaitForChild("ProgressionConfig") :: ModuleScript)

local Server = ServerScriptService:WaitForChild("Server")
local PlayerDataService = require(Server:WaitForChild("Services"):WaitForChild("Player"):WaitForChild("PlayerDataService") :: ModuleScript)

local ProgressionService = {}

-- GET CASH
function ProgressionService.GetCash(player: Player): number
	local data = PlayerDataService.Get(player)
	return if data then data.Cash else 0
end

-- ADD CASH
function ProgressionService.AddCash(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end

	return PlayerDataService.Update(player, function(data)
		data.Cash += amount
	end)
end

-- REMOVE CASH (Transaction safe)
function ProgressionService.RemoveCash(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end

	local data = PlayerDataService.Get(player)
	if not data or data.Cash < amount then
		return false
	end

	return PlayerDataService.Update(player, function(session)
		session.Cash -= amount
	end)
end

-- CHECK REBIRTH ELIGIBILITY
function ProgressionService.CanRebirth(player: Player): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end

	if not ProgressionConfig.Rebirth.Enabled then
		return false, "Rebirth is currently disabled"
	end

	if data.Base.Level < ProgressionConfig.Rebirth.RequiredLevel then
		return false, string.format("Base must reach Level %d to Rebirth", ProgressionConfig.Rebirth.RequiredLevel)
	end

	return true, nil
end

-- EXECUTE REBIRTH
function ProgressionService.Rebirth(player: Player): boolean
	local canRebirth, reason = ProgressionService.CanRebirth(player)
	if not canRebirth then
		if reason then
			warn(string.format("[ProgressionService] %s failed to Rebirth: %s", player.Name, reason))
		end
		return false
	end

	return PlayerDataService.Update(player, function(data)
		data.RebirthCount += 1

		-- Scale permanent bonuses (e.g. +10% speed & pack odds per rebirth)
		data.Multipliers.PackOdds += 0.1
		data.Multipliers.BaseMovementSpeed += 0.05
		data.Multipliers.LevelingSpeed += 0.15

		-- Apply configured reset rules
		if ProgressionConfig.Rebirth.ResetCash then
			data.Cash = 0
		end

		if ProgressionConfig.Rebirth.ResetBaseLevel then
			data.Base.Level = ProgressionConfig.Rebirth.BaseResetLevel
			data.Base.InspectorLevel = 1
			data.Base.PlacedAssets = {}
		end

		if ProgressionConfig.Rebirth.ResetInventory then
			data.Inventory.CompanionCards = {}
			data.Inventory.CardPacks = {}
		end

		if ProgressionConfig.Rebirth.ResetCompanions then
			data.Companions.Owned = {}
			data.Companions.ActiveId = nil
		end
	end)
end

return ProgressionService
