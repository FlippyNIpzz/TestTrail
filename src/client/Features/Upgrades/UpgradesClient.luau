--!strict

-- Layer 4: explicit lifecycle only; no work starts on require.
local Feature = {}
local initialized = false
local started = false
local context: any = nil
function Feature.Initialize(dependencies: any)
    if initialized then return end
    context = dependencies
    initialized = true
end
function Feature.Start()
    assert(initialized, "Initialize must run before Start")
    if started then return end
    -- TODO: Connect feature events here; delegate rules to the service.
    started = true
end
function Feature.Destroy()
    -- TODO: Disconnect owned connections and cancel owned tasks.
    context = nil
    started = false
    initialized = false
end
return Feature
