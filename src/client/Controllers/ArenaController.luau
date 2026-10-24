
local ArenaController = {}

-- INITIALIZE
function ArenaController.Initialize()
    -- Connect Arena events
    -- Prepare Arena interface
end

-- ENTER ARENA
function ArenaController.Enter()
    -- Request Arena entry from server
    return false
end

-- EXIT ARENA
function ArenaController.Exit()
    -- Request Arena exit from server
    return false
end

-- UPDATE ARENA STATUS
function ArenaController.UpdateStatus(data)
    -- Update Arena information on client
    return false
end

-- UPDATE EVENT TIMER
function ArenaController.UpdateEventTimer(timeRemaining)
    -- Display remaining Arena event time
    return false
end

return ArenaController
