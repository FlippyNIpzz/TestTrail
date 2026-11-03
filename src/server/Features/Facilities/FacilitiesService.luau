--!strict

-- Layer 3: owns Facilities rules and runtime state.
local Service = {}
local context: any = nil
function Service.Initialize(dependencies: any)
    context = dependencies
end
function Service.Destroy()
    context = nil
end
-- TODO: Define typed inputs and implement Deposit; never report placeholder success.
function Service.Deposit(...: any): (boolean, string)
    return false, "NotImplemented: Facilities.Deposit"
end

-- TODO: Define typed inputs and implement CollectOutput; never report placeholder success.
function Service.CollectOutput(...: any): (boolean, string)
    return false, "NotImplemented: Facilities.CollectOutput"
end

-- TODO: Define typed inputs and implement SelectRecipe; never report placeholder success.
function Service.SelectRecipe(...: any): (boolean, string)
    return false, "NotImplemented: Facilities.SelectRecipe"
end

-- TODO: Define typed inputs and implement ReconcileOffline; never report placeholder success.
function Service.ReconcileOffline(...: any): (boolean, string)
    return false, "NotImplemented: Facilities.ReconcileOffline"
end

-- TODO: Define typed inputs and implement Upgrade; never report placeholder success.
function Service.Upgrade(...: any): (boolean, string)
    return false, "NotImplemented: Facilities.Upgrade"
end
return Service
