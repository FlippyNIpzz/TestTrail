
local NetworkManager = {}

-- REMOTE EVENT NAMES
NetworkManager.Events = {
    Base = "BaseEvent",
    Arena = "ArenaEvent",
    Companion = "CompanionEvent",
    Inventory = "InventoryEvent",
    Resource = "ResourceEvent",
    Facility = "FacilityEvent",
    Progression = "ProgressionEvent",
}

-- REMOTE FUNCTION NAMES
NetworkManager.Functions = {
    GetPlayerData = "GetPlayerData",
    GetInventory = "GetInventory",
    GetBase = "GetBase",
    GetCompanions = "GetCompanions",
}

-- INITIALIZE NETWORK
function NetworkManager.Initialize()
    -- Server creates RemoteEvents and RemoteFunctions
    -- Store them in ReplicatedStorage
    return false
end

-- GET REMOTE EVENT
function NetworkManager.GetEvent(eventName)
    -- Retrieve existing RemoteEvent
    return nil
end

-- GET REMOTE FUNCTION
function NetworkManager.GetFunction(functionName)
    -- Retrieve existing RemoteFunction
    return nil
end

return NetworkManager
