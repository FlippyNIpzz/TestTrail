--!strict
-- Single owner of player WalkSpeed. Owns character listeners; ResourcesServer owns
-- player entry/departure and the shared Heartbeat. No work starts on require.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Features.Resources.ResourcesConfig)
local Helpers = require(Shared.Features.Resources.ResourcesHelpers)
local Movement = {}
local tracked: { [Player]: any } = {}
local surface: BasePart? = nil
local getCount: ((Player) -> number)? = nil
local initialized = false
local function disconnect(connections: { RBXScriptConnection })
    for _, connection in connections do connection:Disconnect() end
    table.clear(connections)
end
function Movement.Initialize(readCarriedCount: (Player) -> number)
    if initialized then return end
    Helpers.ValidateMovement(Config.Movement)
    local zone = Config.Zones[Config.Movement.ArenaZoneId]
    assert(zone, "Movement.ArenaZoneId must reference a configured resource zone")
    local current: Instance = game
    for _, name in zone.SurfacePath do
        local child = current:FindFirstChild(name)
        assert(child, "Missing movement arena surface: " .. table.concat(zone.SurfacePath, "."))
        current = child
    end
    assert(current:IsA("BasePart"), "Movement arena surface must be a BasePart")
    Helpers.SurfaceGeometry(current)
    surface = current
    getCount = readCarriedCount
    initialized = true
end
function Movement.Refresh(player: Player)
    if not initialized or not tracked[player] then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    local arena = surface
    local inside = root ~= nil and root:IsA("BasePart") and arena ~= nil
        and arena:IsDescendantOf(workspace) and Helpers.IsInsideArena(arena, root.Position, Config.Movement)
    local count = if getCount then getCount(player) else 0
    local speed = Helpers.CalculateMovementSpeed(Config.Movement, inside == true, count)
    -- Avoid property churn and do not read client-supplied speed or carry attributes.
    if humanoid.WalkSpeed ~= speed then humanoid.WalkSpeed = speed end
    if player:GetAttribute("InArena") ~= (inside == true) then player:SetAttribute("InArena", inside == true) end
end
function Movement.Track(player: Player)
    assert(initialized, "Movement not initialized")
    if tracked[player] then return end
    local record = { Connections = {}, CharacterConnections = {}, RootConnection = nil }
    tracked[player] = record
    local function characterChanged(character: Model)
        disconnect(record.CharacterConnections)
        if record.RootConnection then record.RootConnection:Disconnect(); record.RootConnection = nil end
        local function componentsChanged()
            if tracked[player] ~= record or player.Character ~= character then return end
            if record.RootConnection then record.RootConnection:Disconnect(); record.RootConnection = nil end
            local root = character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then
                record.RootConnection = root:GetPropertyChangedSignal("CFrame"):Connect(function() Movement.Refresh(player) end)
            end
            Movement.Refresh(player)
        end
        table.insert(record.CharacterConnections, character.ChildAdded:Connect(componentsChanged))
        table.insert(record.CharacterConnections, character.ChildRemoved:Connect(componentsChanged))
        componentsChanged()
    end
    table.insert(record.Connections, player.CharacterAdded:Connect(characterChanged))
    table.insert(record.Connections, player.CharacterRemoving:Connect(function()
        disconnect(record.CharacterConnections)
        if record.RootConnection then record.RootConnection:Disconnect(); record.RootConnection = nil end
        player:SetAttribute("InArena", false)
    end))
    if player.Character then characterChanged(player.Character) end
end
function Movement.Untrack(player: Player)
    local record = tracked[player]
    if not record then return end
    tracked[player] = nil
    disconnect(record.Connections); disconnect(record.CharacterConnections)
    if record.RootConnection then record.RootConnection:Disconnect() end
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.WalkSpeed = Config.Movement.OutsideArenaSpeed end
    player:SetAttribute("InArena", nil)
end
function Movement.Step()
    -- Every server frame catches physics/network movement as well as teleports.
    for player in tracked do Movement.Refresh(player) end
end
function Movement.Destroy()
    local players = {}; for player in tracked do table.insert(players, player) end
    for _, player in players do Movement.Untrack(player) end
    surface = nil; getCount = nil; initialized = false
end
return Movement
