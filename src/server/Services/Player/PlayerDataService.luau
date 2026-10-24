
local PlayerDataService = {}

-- DEFAULT PLAYER DATA
local DEFAULT_DATA = {
    PlayerLevel = 1,
    XP = 0,
    Cash = 0,
    RebirthLevel = 0,

    Base = {
        Level = 1,
        Facilities = {},
    },

    Inventory = {
        Resources = {},
        Items = {},
        Carriers = {},
    },

    CarriedResources = {},

    Companions = {
        Owned = {},
        Active = nil,
    },
}

-- ACTIVE PLAYER DATA
local playerData = {}

-- COPY DEFAULT DATA
local function DeepCopy(original)
    local copy = {}

    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = DeepCopy(value)
        else
            copy[key] = value
        end
    end

    return copy
end

-- LOAD PLAYER
function PlayerDataService.Load(player)
    local userId = player.UserId

    if playerData[userId] then
        return playerData[userId]
    end

    -- TODO: Load saved data from DataStore
    local data = DeepCopy(DEFAULT_DATA)

    playerData[userId] = data
    return data
end

-- GET PLAYER DATA
function PlayerDataService.Get(player)
    return playerData[player.UserId]
end

-- SAVE PLAYER
function PlayerDataService.Save(player)
    local data = PlayerDataService.Get(player)

    if not data then
        return false
    end

    -- TODO: Save data using Roblox DataStore
    return false
end

-- REMOVE PLAYER DATA
function PlayerDataService.Remove(player)
    playerData[player.UserId] = nil
end

return PlayerDataService
