--!strict
local Players = game:GetService("Players")
local Networking = require(game:GetService("ReplicatedStorage").Shared.Features.Networking.NetworkingHelpers)
local Service = require(script.Parent.AdminService)
local Feature = {}
local started = false
local remotes: { RemoteFunction } = {}
local removing: RBXScriptConnection? = nil
function Feature.Initialize(context: any)
    assert(context.GameConfig.Features.Networking and context.GameConfig.Features.PlayerData, "Admin requires Networking and PlayerData")
    Service.Initialize(context)
end
function Feature.Start()
    if started then return end
    for name, callback in { ["Admin.GetState"] = Service.GetState, ["Admin.Prepare"] = Service.Prepare, ["Admin.Commit"] = Service.Commit } do
        local remote = Networking.Get(name) :: RemoteFunction
        remote.OnServerInvoke = callback
        table.insert(remotes, remote)
    end
    removing = Players.PlayerRemoving:Connect(Service.Forget)
    started = true
end
function Feature.Destroy()
    for _, remote in remotes do remote.OnServerInvoke = nil end
    table.clear(remotes)
    if removing then removing:Disconnect(); removing = nil end
    Service.Destroy(); started = false
end
return Feature
