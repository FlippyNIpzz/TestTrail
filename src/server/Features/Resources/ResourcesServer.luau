--!strict

-- Layer 4: explicit lifecycle only; no work starts on require.
local Players = game:GetService("Players")
local connections: { RBXScriptConnection } = {}
local RunService = game:GetService("RunService")
local heartbeat: RBXScriptConnection? = nil
local Feature = {}
local initialized = false
local started = false
local context: any = nil
local Service = require(script.Parent.ResourcesService)
function Feature.Initialize(dependencies: any)
    if initialized then return end
    context = dependencies
    Service.Initialize(dependencies)
    initialized = true
end
function Feature.Start()
    assert(initialized, "Initialize must run before Start")
    if started then return end
    table.insert(connections, Players.PlayerAdded:Connect(Service.Track))
    table.insert(connections, Players.PlayerRemoving:Connect(Service.Forget))
    for _, player in Players:GetPlayers() do Service.Track(player) end
    Service.Schedule(os.clock())
    heartbeat = RunService.Heartbeat:Connect(function() Service.Step(os.clock()) end)
    started = true
end
function Feature.Destroy()
    if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
    for _, connection in connections do connection:Disconnect() end
    table.clear(connections)
    Service.Destroy()
    context = nil
    started = false
    initialized = false
end
return Feature
