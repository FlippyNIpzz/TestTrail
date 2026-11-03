--!strict

-- Layer 3: owns Upgrades rules and runtime state.
local Service = {}
local context: any = nil
function Service.Initialize(dependencies: any)
    context = dependencies
end
function Service.Destroy()
    context = nil
end
-- TODO: Define typed inputs and implement Purchase; never report placeholder success.
function Service.Purchase(...: any): (boolean, string)
    return false, "NotImplemented: Upgrades.Purchase"
end
return Service
