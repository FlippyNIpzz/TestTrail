--!strict

-- Foundation scaffold entry point. Gameplay remains unavailable until services are implemented.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Features.Game.GameConfig)
local Lifecycle = require(Shared.Features.Lifecycle.LifecycleHelpers)
local order = { "Networking", "PlayerData", "Currency", "Inventory", "Base", "Resources", "Facilities", "Upgrades", "UI", "Companion", "Combat", "Arena", "Rebirth", "Admin" }
local modules = {}
for _, name in order do
    if GameConfig.Features[name] then
        table.insert(modules, require(script.Parent.Features[name][name .. "Server"]))
    end
end
local destroy = Lifecycle.Run(modules, { GameConfig = GameConfig, Shared = Shared, Features = script.Parent.Features })
script.Destroying:Connect(destroy)
warn("[Foundation] Player sessions initialized. Gameplay services remain under construction.")
