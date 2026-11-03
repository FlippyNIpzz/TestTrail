--!strict
-- Layer 4: player lifecycle wiring. Service owns admission and profile rules.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Features.PlayerData.PlayerDataConfig)
local Service = require(script.Parent.PlayerDataService)
local Feature = {}
local initialized, started = false, false
local connections: { RBXScriptConnection } = {}
local generation = 0

function Feature.Initialize(context: any)
    if initialized then return end
    Service.Initialize(context)
    initialized = true
end
function Feature.Start()
    assert(initialized, "Initialize must run before Start")
    if started then return end
    started = true
    generation += 1
    local current = generation
    local function joined(player: Player)
        task.spawn(function()
            if not started or current ~= generation then return end
            local ok, success, reason = pcall(Service.Load, player)
            if (not ok or not success) and player.Parent == Players then
                warn("[PlayerData] Admission failed: " .. tostring(if ok then reason else success))
                player:Kick("Your saved data could not be loaded safely. Please wait a moment and rejoin.")
            end
        end)
    end
    table.insert(connections, Players.PlayerAdded:Connect(joined))
    table.insert(connections, Players.PlayerRemoving:Connect(function(player) Service.Release(player) end))
    for _, player in Players:GetPlayers() do joined(player) end
    game:BindToClose(function()
        if current ~= generation or not started then return end
        -- ProfileStore also binds shutdown and waits for its pending writes.
        local remaining = 0
        for _, player in Players:GetPlayers() do
            remaining += 1
            task.spawn(function() Service.Release(player); remaining -= 1 end)
        end
        local deadline = os.clock() + Config.ShutdownWaitSeconds
        while remaining > 0 and os.clock() < deadline do task.wait(0.1) end
    end)
end
function Feature.Destroy()
    started = false
    generation += 1
    for _, connection in connections do connection:Disconnect() end
    table.clear(connections)
    Service.Destroy()
    initialized = false
end
return Feature
