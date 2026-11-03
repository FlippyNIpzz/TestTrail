
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaConfig = require(
    ReplicatedStorage.Shared.Configs.ArenaConfig
)

local ResourceDropService = require(
    script.Parent.Parent.Resources.ResourceDropService
)

local ArenaService = {}

local arenaModel = nil

-- INITIALIZE ARENA
function ArenaService.Initialize()

    -- Remove existing Arena
    local existing = workspace:FindFirstChild("NoGemArena")
    if existing then
        existing:Destroy()
    end

    -- Create Arena model
    local arena = Instance.new("Model")
    arena.Name = "NoGemArena"
    arena.Parent = workspace

    -- Create circular floor
    local floor = Instance.new("Part")
    floor.Name = "ArenaFloor"
    floor.Shape = Enum.PartType.Cylinder

    floor.Size = Vector3.new(
        1,
        ArenaConfig.Radius * 2,
        ArenaConfig.Radius * 2
    )

    floor.CFrame = CFrame.new(
        ArenaConfig.Center + Vector3.new(0, 0.5, 0)
    ) * CFrame.Angles(0, 0, math.rad(90))

    floor.Anchored = true
    floor.Material = Enum.Material.Metal
    floor.Color = Color3.fromRGB(45, 50, 60)
    floor.Parent = arena

    arena.PrimaryPart = floor

    -- Center marker
    local centerMarker = Instance.new("Part")
    centerMarker.Name = "CenterMarker"
    centerMarker.Shape = Enum.PartType.Cylinder
    centerMarker.Size = Vector3.new(0.2, 10, 10)

    centerMarker.CFrame = CFrame.new(
        ArenaConfig.Center + Vector3.new(0, 1.1, 0)
    ) * CFrame.Angles(0, 0, math.rad(90))

    centerMarker.Anchored = true
    centerMarker.CanCollide = false
    centerMarker.Material = Enum.Material.Neon
    centerMarker.Color = Color3.fromRGB(0, 170, 255)
    centerMarker.Parent = arena

    arenaModel = arena

    print("[ArenaService] Arena created successfully")
end

-- GET ARENA
function ArenaService.GetArena()
    return arenaModel
end

-- PLAYER ENTERS ARENA
function ArenaService.Enter(player)
    -- TODO: Register player inside Arena
    return false
end

-- PLAYER EXITS ARENA
function ArenaService.Exit(player)
    -- TODO: Remove player from Arena tracking
    return false
end

-- CHECK ARENA STATUS
function ArenaService.IsInside(player)
    -- TODO: Check player position
    return false
end

-- PLAYER DEFEATED
function ArenaService.OnPlayerDefeated(player)
    return ResourceDropService.Drop(player)
end

-- GET ARENA PLAYERS
function ArenaService.GetPlayers()
    -- TODO: Return players currently inside Arena
    return {}
end

return ArenaService
