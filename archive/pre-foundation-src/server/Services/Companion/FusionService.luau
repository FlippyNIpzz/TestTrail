
local FusionService = {}

local CompanionService = require(
    script.Parent.CompanionService
)

-- VALIDATE FUSION
function FusionService.CanFuse(player, mainId, donorId)
    -- Verify ownership of both companions
    -- Prevent self-fusion
    -- Check fusion requirements
    return false
end

-- CALCULATE FUSION
function FusionService.Calculate(mainCompanion, donorCompanion)
    -- Select highest stat per slot:
    -- Health, Damage, Stamina, Speed
    -- Calculate combined level (formula TBD)
    return nil
end

-- EXECUTE FUSION
function FusionService.Fuse(player, mainId, donorId)
    -- Validate fusion
    -- Calculate resulting stats
    -- Update main companion
    -- Permanently consume donor companion
    return false
end

-- PREVIEW FUSION
function FusionService.Preview(player, mainId, donorId)
    -- Return projected fusion outcome
    -- Do not modify player data
    return nil
end

return FusionService
