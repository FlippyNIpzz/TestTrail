--!strict

--[[
	PlayerDataService.luau
	Layer: 3 (State & Manager)
	Description: Manages player data sessions, DataStore persistence (loading, saving, retrying),
	             reconciliation with schema updates, and auto-saving.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerDataTemplate = require(Shared:WaitForChild("Data"):WaitForChild("PlayerDataTemplate") :: ModuleScript)
local TableUtil = require(Shared:WaitForChild("Utility"):WaitForChild("TableUtil") :: ModuleScript)

export type PlayerData = PlayerDataTemplate.PlayerData

local PlayerDataService = {}

-- CONSTANTS
local DATA_STORE_NAME = "PlayerData_v1"
local MAX_RETRIES = 3
local RETRY_DELAY_SECONDS = 1
local AUTO_SAVE_INTERVAL_SECONDS = 300 -- 5 minutes

-- INTERNAL STATE
local playerDataStore: any = nil
local sessionData: { [number]: PlayerData } = {}
local isSaving: { [number]: boolean } = {}
local isAutoSaveRunning = false

-- Safe initialization of DataStore to prevent crashes when Studio API access is disabled
local success, result = pcall(function()
	return DataStoreService:GetDataStore(DATA_STORE_NAME)
end)

if success then
	playerDataStore = result
else
	warn(string.format("[PlayerDataService] Failed to access DataStore '%s': %s. Using in-memory sessions.", DATA_STORE_NAME, tostring(result)))
end

-- HELPER: Generate DataStore key
local function GetDataKey(userId: number): string
	return string.format("Player_%d", userId)
end

-- HELPER: Retry wrapper for DataStore requests
local function RetryAsync<T>(operation: () -> T): (boolean, T?)
	local lastError: any = nil

	for attempt = 1, MAX_RETRIES do
		local opSuccess, opResult = pcall(operation)

		if opSuccess then
			return true, opResult
		end

		lastError = opResult
		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY_SECONDS * attempt)
		end
	end

	return false, lastError
end

-- LOAD PLAYER DATA
function PlayerDataService.Load(player: Player): PlayerData?
	local userId = player.UserId

	if sessionData[userId] then
		return sessionData[userId]
	end

	local loadedData: PlayerData? = nil

	if playerDataStore then
		local dataKey = GetDataKey(userId)
		local fetchSuccess, fetchedData = RetryAsync(function()
			return playerDataStore:GetAsync(dataKey)
		end)

		if fetchSuccess and fetchedData ~= nil then
			-- Reconcile loaded data with the default template so any newly added keys exist
			TableUtil.Reconcile(fetchedData, PlayerDataTemplate.DEFAULT_DATA)
			loadedData = fetchedData :: PlayerData
		elseif not fetchSuccess then
			warn(string.format("[PlayerDataService] Error loading data for UserId %d: %s", userId, tostring(fetchedData)))
		end
	end

	-- If new player or DataStore is empty, create fresh copy from template
	if not loadedData then
		loadedData = TableUtil.DeepCopy(PlayerDataTemplate.DEFAULT_DATA)
	end

	sessionData[userId] = loadedData
	return loadedData
end

-- GET ACTIVE SESSION DATA
function PlayerDataService.Get(player: Player): PlayerData?
	return sessionData[player.UserId]
end

-- UPDATE ACTIVE SESSION DATA SAFELY
function PlayerDataService.Update(player: Player, updateFn: (data: PlayerData) -> ()): boolean
	local data = PlayerDataService.Get(player)
	if not data then
		warn(string.format("[PlayerDataService] Cannot update data for %s: session not found", player.Name))
		return false
	end

	updateFn(data)
	return true
end

-- SAVE PLAYER DATA
function PlayerDataService.Save(player: Player): boolean
	local userId = player.UserId
	local data = sessionData[userId]

	if not data then
		return false
	end

	if isSaving[userId] then
		return false
	end

	if not playerDataStore then
		-- In-memory mode (e.g. Studio without API access)
		return true
	end

	isSaving[userId] = true
	local dataKey = GetDataKey(userId)

	local saveSuccess, saveError = RetryAsync(function()
		playerDataStore:UpdateAsync(dataKey, function(_oldValue: any)
			-- Save the current active session snapshot
			return TableUtil.DeepCopy(data)
		end)
	end)

	isSaving[userId] = false

	if not saveSuccess then
		warn(string.format("[PlayerDataService] Failed to save data for %s (UserId: %d): %s", player.Name, userId, tostring(saveError)))
		return false
	end

	return true
end

-- REMOVE SESSION CACHE
function PlayerDataService.Remove(player: Player): ()
	sessionData[player.UserId] = nil
	isSaving[player.UserId] = nil
end

-- AUTO-SAVE LOOP
function PlayerDataService.StartAutoSave(customInterval: number?): ()
	if isAutoSaveRunning then
		return
	end
	isAutoSaveRunning = true

	local interval = customInterval or AUTO_SAVE_INTERVAL_SECONDS

	task.spawn(function()
		while isAutoSaveRunning do
			task.wait(interval)

			for _, player in Players:GetPlayers() do
				if player.Parent then
					PlayerDataService.Save(player)
					-- Stagger saves by 1 second to stay well within DataStore budget limits
					task.wait(1)
				end
			end
		end
	end)
end

return PlayerDataService
