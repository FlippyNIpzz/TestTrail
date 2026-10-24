
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Services = script.Parent.Services
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- NETWORK
local NetworkManager = require(
    Shared.Network.NetworkManager
)

-- PLAYER SYSTEM
local PlayerDataService = require(
    Services.Player.PlayerDataService
)

-- WORLD SYSTEMS
local BaseService = require(
    Services.Base.BaseService
)

local ArenaService = require(
    Services.Arena.ArenaService
)

local ArenaEventService = require(
    Services.Arena.ArenaEventService
)

local ResourceSpawner = require(
    Services.Resources.ResourceSpawner
)

-- SERVER INITIALIZATION
NetworkManager.Initialize()
BaseService.Initialize()
ArenaService.Initialize()
ArenaEventService.Initialize()
ResourceSpawner.Initialize()
ResourceSpawner.Start()

-- PLAYER JOIN
local function OnPlayerAdded(player)
    PlayerDataService.Load(player)

    local base = BaseService.Assign(player)

    if not base then
        return
    end

    player.CharacterAdded:Connect(function(character)
        BaseService.SpawnCharacter(player, character)
    end)

    if player.Character then
        BaseService.SpawnCharacter(player, player.Character)
    end
end

-- PLAYER LEAVE
local function OnPlayerRemoving(player)
    PlayerDataService.Save(player)
    BaseService.Release(player)
    PlayerDataService.Remove(player)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

for _, player in Players:GetPlayers() do
    OnPlayerAdded(player)
end

-- SERVER SHUTDOWN
game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        PlayerDataService.Save(player)
    end
end)
