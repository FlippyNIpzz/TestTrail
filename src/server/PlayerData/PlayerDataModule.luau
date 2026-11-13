--!strict
-- PlayerDataModule (Layer 3: Manager Layer)
-- Manages player data sessions, persistence, and profile access.

local DataStoreService = game:GetService("DataStoreService")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local BaseProfile = require(script.Parent.Parent.Base.BaseProfile)

local Collection = require(script.Parent.Parent.Companion.CompanionCollection)

local PlayerDataModule = {}
PlayerDataModule.__index = PlayerDataModule

type PlayerDataSchema = PlayerData.PlayerDataSchema

local sessions: { [Player]: PlayerDataSchema } = {}
local playerStore = if PlayerData.PERSISTENCE_ENABLED then DataStoreService:GetDataStore(PlayerData.DATASTORE_NAME) else nil

function PlayerDataModule.InitializeProfile(player: Player): (PlayerDataSchema?, string?)
	if sessions[player] then return sessions[player], nil end
	local userId = player.UserId
	local key = "Player_" .. userId
	
	local success, result = pcall(function()
		if playerStore then
			return playerStore:GetAsync(key)
		end
		return nil
	end)
	
	if not success then
		warn(("[PlayerDataModule]: Error loading data for %s (%d): %s"):format(player.Name, userId, tostring(result)))
	end

	if not success then return nil, "Data load failed" end
	if player.Parent ~= game:GetService("Players") then return nil, "Player left" end
	if result ~= nil and type(result) ~= "table" then return nil, "Invalid profile" end

	local data: PlayerDataSchema
	if success and result and type(result) == "table" then
		data = {
			Cash = result.Cash or PlayerData.DEFAULT_DATA.Cash,
			Scrap = result.Scrap or PlayerData.DEFAULT_DATA.Scrap,
			Rebirths = result.Rebirths or PlayerData.DEFAULT_DATA.Rebirths,
			Level = result.Level or PlayerData.DEFAULT_DATA.Level,
			CompanionId = if type(result.CompanionId) == "string" then result.CompanionId else PlayerData.DEFAULT_DATA.CompanionId,
		}
	else
		data = {
			Cash = PlayerData.DEFAULT_DATA.Cash,
			Scrap = PlayerData.DEFAULT_DATA.Scrap,
			Rebirths = PlayerData.DEFAULT_DATA.Rebirths,
			Level = PlayerData.DEFAULT_DATA.Level,
			CompanionId = PlayerData.DEFAULT_DATA.CompanionId,
		}
	end
	
	local collection, collectionError = Collection.Load(result and result.Companions, result and result.CompanionId)
	if not collection then return nil, collectionError end
	data.Companions = collection
	local inventory: { [string]: number } = {}
	data.Inventory = inventory
	if result and type(result.Inventory) == "table" then
		for item, count in pairs(result.Inventory) do
			if type(item) == "string" and type(count) == "number" and count > 0 and count < math.huge and count % 1 == 0 then
				inventory[item] = count
			end
		end
	end
	data.Base = BaseProfile.Load(result and result.Base)
	sessions[player] = data
	return data, nil
end

function PlayerDataModule.SaveProfile(player: Player)
	if not playerStore then return end
	local data = sessions[player]
	if not data then return end
	
	local userId = player.UserId
	local key = "Player_" .. userId
	
	local success, err = pcall(function()
		playerStore:SetAsync(key, data)
	end)
	if not success then
		warn(("[PlayerDataModule]: Failed to save data for %s (%d): %s"):format(player.Name, userId, tostring(err)))
	end
end

function PlayerDataModule.RemoveProfile(player: Player)
	PlayerDataModule.SaveProfile(player)
	sessions[player] = nil
end

function PlayerDataModule.GetProfile(player: Player): PlayerDataSchema?
	return sessions[player]
end

function PlayerDataModule.Close()
	local pending = 0
	for player in pairs(sessions) do
		pending += 1
		task.spawn(function()
			PlayerDataModule.RemoveProfile(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end

return PlayerDataModule
