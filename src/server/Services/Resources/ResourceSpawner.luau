
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local ResourceConfig = require(
    Shared.Configs.ResourceConfig
)

local ArenaConfig = require(
    Shared.Configs.ArenaConfig
)

local ResourceSpawner = {}

local scrapFolder = nil
local running = false
local spawnSession = 0
local rng = Random.new()

-- INITIALIZE SPAWNER
function ResourceSpawner.Initialize()
    running = false
    spawnSession += 1

    local arena = workspace:WaitForChild("NoGemArena")

    local existing = arena:FindFirstChild("Scrap")
    if existing then
        existing:Destroy()
    end

    scrapFolder = Instance.new("Folder")
    scrapFolder.Name = "Scrap"
    scrapFolder.Parent = arena

    print("[ResourceSpawner] Initialized")
end

-- SPAWN RESOURCE
function ResourceSpawner.Spawn(resourceId, position)
    if not scrapFolder or not scrapFolder.Parent then
        return nil
    end

    if not ResourceConfig.Resources[resourceId] then
        return nil
    end

    if #scrapFolder:GetChildren() >= ResourceConfig.Spawning.MaxSpawned then
        return nil
    end

    local scrap = Instance.new("Part")
    scrap.Name = resourceId
    scrap.Size = Vector3.new(2, 2, 2)
    scrap.Position = position

    scrap.Anchored = true
    scrap.CanCollide = false

    scrap.Material = Enum.Material.Neon
    scrap.Color = Color3.fromRGB(0, 200, 255)

    scrap:SetAttribute("ResourceId", resourceId)
    scrap:SetAttribute("Amount", 1)

    scrap.Parent = scrapFolder

    return scrap
end

-- RANDOM SPAWN
function ResourceSpawner.SpawnRandom()
    local radius = math.max(
        0,
        ArenaConfig.Radius - ResourceConfig.Spawning.EdgeMargin
    )

    local angle = rng:NextNumber(0, math.pi * 2)
    local distance = math.sqrt(rng:NextNumber()) * radius

    local position = ArenaConfig.Center + Vector3.new(
        math.cos(angle) * distance,
        2.5,
        math.sin(angle) * distance
    )

    return ResourceSpawner.Spawn("Scrap", position)
end

-- REMOVE RESOURCE
function ResourceSpawner.Remove(resource)
    if resource and resource.Parent == scrapFolder then
        resource:Destroy()
        return true
    end

    return false
end

-- START SPAWNING
function ResourceSpawner.Start()
    if running or not ResourceConfig.Spawning.Enabled then
        return false
    end

    if not scrapFolder then
        return false
    end

    running = true
    spawnSession += 1

    local session = spawnSession

    -- INITIAL SCRAP
    for i = 1, ResourceConfig.Spawning.InitialCount do
        ResourceSpawner.SpawnRandom()
    end

    -- CONTINUOUS SPAWNING
    task.spawn(function()
        while running and session == spawnSession do
            task.wait(ResourceConfig.Spawning.Interval)

            if running and session == spawnSession then
                ResourceSpawner.SpawnRandom()
            end
        end
    end)

    print("[ResourceSpawner] Spawning started")
    return true
end

-- STOP SPAWNING
function ResourceSpawner.Stop()
    running = false
    spawnSession += 1
    return true
end

return ResourceSpawner
