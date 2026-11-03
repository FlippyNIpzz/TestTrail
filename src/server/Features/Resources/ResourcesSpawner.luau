--!strict
-- Server-owned generated pickups only. Collection and departure drops are separate.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Features.Resources.ResourcesConfig)
local ResourceHelpers = require(Shared.Features.Resources.ResourcesHelpers)
local TableHelpers = require(Shared.Features.PlayerData.PlayerDataHelpers)
local InsertService = game:GetService("InsertService")
local Spawner = {}
local zones: { [string]: any } = {}
local templates: { [string]: { Instance } } = {}
local folder: Folder? = nil
local random = Random.new()
local initialized = false
local generationEnabled = true

local function finite(value: any): boolean
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function positive(value: any): boolean return finite(value) and value > 0 end
local function resolve(path: any): Instance
    assert(type(path) == "table" and #path > 0, "Expected nonempty project path segments")
    local current: Instance = game
    for _, segment in path do
        assert(type(segment) == "string", "Project path segments must be strings")
        local child = current:FindFirstChild(segment)
        assert(child, "Missing project path: " .. table.concat(path, "."))
        current = child
    end
    return current
end
local function loadTemplate(id: string, asset: any): Instance
    assert(type(asset) == "table", id .. ": missing PickupAsset")
    local instance: Instance
    if asset.Kind == "Primitive" then
        assert(typeof(asset.Size) == "Vector3" and positive(asset.Size.X) and positive(asset.Size.Y) and positive(asset.Size.Z), id .. ": invalid primitive size")
        assert(typeof(asset.Color) == "Color3", id .. ": invalid primitive color")
        local part = Instance.new("Part")
        part.Size = asset.Size
        part.Color = asset.Color
        instance = part
    elseif asset.Kind == "ProjectPath" then
        instance = resolve(asset.Path):Clone()
    elseif asset.Kind == "AssetId" then
        assert(type(asset.Id) == "number" and positive(asset.Id) and asset.Id % 1 == 0, id .. ": invalid asset ID")
        local ok, result = pcall(InsertService.LoadAsset, InsertService, asset.Id)
        assert(ok, id .. ": asset loading failed: " .. tostring(result))
        instance = result
    else error(id .. ": unsupported PickupAsset.Kind") end
    -- Register immediately so failed validation is cleaned up by Initialize rollback.
    assert(instance, id .. ": pickup asset must be Archivable")
    templates[id] = templates[id] or {}
    table.insert(templates[id], instance)
    assert(asset.ExpectedClass == "Model" or asset.ExpectedClass == "BasePart", id .. ": invalid ExpectedClass")
    assert(instance:IsA(asset.ExpectedClass), id .. ": unexpected asset class")
    local parts = 0
    local all = instance:GetDescendants()
    table.insert(all, instance)
    for _, child in all do
        assert(not child:IsA("LuaSourceContainer"), id .. ": pickup assets cannot contain scripts")
        if child:IsA("BasePart") then
            child.Anchored = true
            child.CanCollide = false
            child.CanTouch = false -- Contact collection is implemented separately.
            child.CanQuery = true
            parts += 1
        end
    end
    assert(parts > 0, id .. ": asset has no parts")
    return instance
end
local function bounds(instance: any): (CFrame, Vector3)
    if instance:IsA("Model") then return instance:GetBoundingBox() end
    return instance.CFrame, instance.Size
end
local surfaceGeometry = ResourceHelpers.SurfaceGeometry
local function remove(zone: any, pickup: Instance)
    local record = zone.Active[pickup]
    if not record then return end
    zone.Active[pickup] = nil
    zone.Count -= 1
    record.Connection:Disconnect()
    pickup:Destroy()
end
function Spawner.Destroy()
    for _, zone in zones do
        local pickups = {}
        for pickup in zone.Active do table.insert(pickups, pickup) end
        for _, pickup in pickups do remove(zone, pickup) end
    end
    table.clear(zones)
    for _, variants in templates do
        for _, template in variants do template:Destroy() end
    end
    table.clear(templates)
    if folder then folder:Destroy(); folder = nil end
    initialized = false
    generationEnabled = true
end
function Spawner.Initialize()
    if initialized then return end
    local ok, failure = pcall(function()
        for id, definition in Config.Definitions do
            assert(type(id) == "string" and id:match("^resource%.[a-z][a-z0-9_]*$"), "Invalid resource ID")
            assert(positive(definition.SpawnLifetimeSeconds), id .. ": invalid SpawnLifetimeSeconds")
        end
        for id, config in Config.Zones do
            assert(type(config.Enabled) == "boolean", id .. ": missing Enabled")
            if not config.Enabled then continue end
            assert(positive(config.MinDelaySeconds) and positive(config.MaxDelaySeconds) and config.MaxDelaySeconds >= config.MinDelaySeconds, id .. ": invalid delay range")
            assert(positive(config.MaxActive) and config.MaxActive % 1 == 0, id .. ": invalid MaxActive")
            assert(positive(config.PlacementAttempts) and config.PlacementAttempts % 1 == 0, id .. ": invalid PlacementAttempts")
            assert(finite(config.EdgeMargin) and config.EdgeMargin >= 0, id .. ": invalid EdgeMargin")
            local surface = resolve(config.SurfacePath)
            assert(surface:IsA("BasePart"), id .. ": SurfacePath must identify a BasePart")
            surfaceGeometry(surface)
            local entries, total = {}, 0
            for resourceId, weight in config.Weights do
                assert(Config.Definitions[resourceId], id .. ": unknown resource " .. tostring(resourceId))
                assert(finite(weight) and weight >= 0, id .. ": invalid weight for " .. resourceId)
                total += weight
                assert(finite(total), id .. ": weight total overflow")
                if weight > 0 then
                    if not templates[resourceId] then
                        local definition = Config.Definitions[resourceId]
                        assert(not (definition.PickupAsset and definition.PickupAssets), resourceId .. ": use PickupAsset or PickupAssets, not both")
                        local assets = definition.PickupAssets or { definition.PickupAsset }
                        assert(type(assets) == "table" and #assets > 0, resourceId .. ": missing pickup assets")
                        local count = 0
                        for index in assets do
                            assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #assets, resourceId .. ": PickupAssets must be a dense array")
                            count += 1
                        end
                        assert(count == #assets, resourceId .. ": PickupAssets must be a dense array")
                        for _, asset in assets do loadTemplate(resourceId, asset) end
                    end
                    table.insert(entries, { Id = resourceId, Weight = weight })
                end
            end
            assert(total > 0, id .. ": weights require a positive entry")
            zones[id] = { Config = config, Surface = surface, Entries = entries, Total = total, Active = {}, Count = 0, NextAttempt = 0 }
        end
        if next(zones) then
            folder = Instance.new("Folder")
            folder.Name = "GeneratedResources"
            folder.Parent = workspace
        end
        TableHelpers.DeepFreeze(Config)
        initialized = true
    end)
    if not ok then Spawner.Destroy(); error("[Resources] " .. tostring(failure), 0) end
end
function Spawner.GetGenerationEnabled(): boolean return generationEnabled end
function Spawner.SetGenerationEnabled(enabled: boolean): (boolean, string?)
    if not initialized then return false, "Unavailable" end
    if type(enabled) ~= "boolean" then return false, "InvalidRequest" end
    if enabled and not generationEnabled then Spawner.Schedule(os.clock()) end
    generationEnabled = enabled
    return true
end
function Spawner.Schedule(now: number)
    for _, zone in zones do
        zone.NextAttempt = now + random:NextNumber(zone.Config.MinDelaySeconds, zone.Config.MaxDelaySeconds)
    end
end
function Spawner.Spawn(zoneId: string): (boolean, any)
    if not initialized then return false, "Unavailable" end
    if not generationEnabled then return false, "GenerationDisabled" end
    local zone = zones[zoneId]
    if not zone then return false, "UnknownZone" end
    if zone.Count >= zone.Config.MaxActive then return false, "AtCapacity" end
    if not zone.Surface:IsDescendantOf(workspace) or not folder or folder.Parent ~= workspace then return false, "WorldUnavailable" end
    local roll, resourceId = random:NextNumber(0, zone.Total), zone.Entries[#zone.Entries].Id
    for _, entry in zone.Entries do
        roll -= entry.Weight
        if roll < 0 then resourceId = entry.Id; break end
    end
    local variants = templates[resourceId]
    local template = variants[random:NextInteger(1, #variants)]
    local box, size = bounds(template)
    local surfaceFrame, surfaceSize = surfaceGeometry(zone.Surface)
    local halfX = surfaceSize.X / 2 - zone.Config.EdgeMargin - size.X / 2
    local halfZ = surfaceSize.Z / 2 - zone.Config.EdgeMargin - size.Z / 2
    if halfX < 0 or halfZ < 0 then return false, "NoValidPlacement" end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { zone.Surface }
    local ground = RaycastParams.new()
    ground.FilterType = Enum.RaycastFilterType.Include
    ground.FilterDescendantsInstances = { zone.Surface }
    -- Query all queryable geometry, including characters and other pickups.
    for _ = 1, zone.Config.PlacementAttempts do
        local center = surfaceFrame * CFrame.new(random:NextNumber(-halfX, halfX), surfaceSize.Y / 2 + size.Y / 2 + 0.05, random:NextNumber(-halfZ, halfZ))
        -- Every footprint corner must have this surface beneath it; this also
        -- keeps pickups inside circular floors and away from holes/edges.
        local supported = true
        for _, x in { -size.X / 2 - zone.Config.EdgeMargin, size.X / 2 + zone.Config.EdgeMargin } do
            for _, z in { -size.Z / 2 - zone.Config.EdgeMargin, size.Z / 2 + zone.Config.EdgeMargin } do
                local origin = center:PointToWorldSpace(Vector3.new(x, size.Y / 2 + 1, z))
                if not workspace:Raycast(origin, Vector3.new(0, -(size.Y + surfaceSize.Y + 2), 0), ground) then
                    supported = false
                end
            end
        end
        if not supported or #workspace:GetPartBoundsInBox(center, size, params) > 0 then continue end
        local pickup: any = template:Clone()
        local pivot = template:GetPivot()
        pickup:PivotTo(center * box:ToObjectSpace(pivot))
        pickup.Name = resourceId
        pickup:SetAttribute("ModelVariant", template.Name)
        pickup:SetAttribute("PreviewOnly", nil)
        pickup:SetAttribute("ResourceId", resourceId)
        pickup:SetAttribute("Quantity", 1)
        pickup:SetAttribute("ZoneId", zoneId)
        local expires = os.clock() + Config.Definitions[resourceId].SpawnLifetimeSeconds
        pickup:SetAttribute("ExpiresAt", workspace:GetServerTimeNow() + Config.Definitions[resourceId].SpawnLifetimeSeconds)
        local connection = pickup.Destroying:Connect(function()
            local record = zone.Active[pickup]
            if record then zone.Active[pickup] = nil; zone.Count -= 1; record.Connection:Disconnect() end
        end)
        zone.Active[pickup] = { Expires = expires, Connection = connection }
        zone.Count += 1
        pickup.Parent = folder
        return true, pickup
    end
    return false, "NoValidPlacement"
end
-- Execution owns the single heartbeat connection; this service owns pickup cleanup.
function Spawner.Step(now: number)
    for id, zone in zones do
        local expired = {}
        for pickup, record in zone.Active do if now >= record.Expires then table.insert(expired, pickup) end end
        for _, pickup in expired do remove(zone, pickup) end
        if now >= zone.NextAttempt then
            Spawner.Spawn(id)
            zone.NextAttempt = now + random:NextNumber(zone.Config.MinDelaySeconds, zone.Config.MaxDelaySeconds)
        end
    end
end
return Spawner
