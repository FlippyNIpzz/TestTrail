
local BaseController = {}

-- INITIALIZE
function BaseController.Initialize()
    -- Connect base-related events
    -- Prepare Base GUI
end

-- REQUEST FACILITY PLACEMENT
function BaseController.PlaceFacility(facilityId, zoneId, position)
    -- Send placement request to server
    return false
end

-- REQUEST BASE UPGRADE
function BaseController.UpgradeBase()
    -- Request upgrade from server
    return false
end

-- GET BASE INFORMATION
function BaseController.GetBaseInfo()
    -- Request player's base data
    return nil
end

-- UPDATE BASE GUI
function BaseController.UpdateGUI(data)
    -- Refresh base level and facility information
    return false
end

return BaseController
