
local CompanionBehavior = {}

-- SET COMPANION MODE
function CompanionBehavior.SetMode(player, mode)
    -- Validate mode: Base, Follow, Arena
    -- Update companion behavior
    return false
end

-- BASE MODE
function CompanionBehavior.Base(player)
    -- Return companion to base
    return false
end

-- FOLLOW MODE
function CompanionBehavior.Follow(player)
    -- Follow owner
    return false
end

-- ARENA MODE
function CompanionBehavior.Arena(player)
    -- Roam Arena and search for targets
    return false
end

-- UPDATE MOVEMENT
function CompanionBehavior.UpdateMovement(player)
    -- Apply movement behavior
    -- Respect Speed and Stamina
    return false
end

-- GET MODE
function CompanionBehavior.GetMode(player)
    -- Return active mode
    return nil
end

return CompanionBehavior
