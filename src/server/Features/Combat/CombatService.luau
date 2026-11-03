--!strict

-- Layer 3: owns Combat rules and runtime state.
local Service = {}
local context: any = nil
function Service.Initialize(dependencies: any)
    context = dependencies
end
function Service.Destroy()
    context = nil
end

return Service
