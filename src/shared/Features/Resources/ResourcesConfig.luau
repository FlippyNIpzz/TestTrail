--!strict

return {
    Definitions = {
        ["resource.ore"] = { CollectionMode = "Carried", UnitWeight = 1,
            SpawnLifetimeSeconds = 60, DropExpires = false,
            -- Server templates match Development.ResourceModelPreviews.
            -- Variants change appearance only: every cluster is one resource.ore.
            PickupAssets = {
                { Kind = "ProjectPath", ExpectedClass = "Model",
                    Path = { "ServerStorage", "ResourceModels", "OreCluster" } },
                { Kind = "ProjectPath", ExpectedClass = "Model",
                    Path = { "ServerStorage", "ResourceModels", "OreClusterWide" } },
                { Kind = "ProjectPath", ExpectedClass = "Model",
                    Path = { "ServerStorage", "ResourceModels", "OreClusterJagged" } },
            } },
    },
    -- Verified against the current Studio arena hierarchy; change when retheming.
    Zones = {
        ["zone.arena"] = {
            Enabled = true,
            SurfacePath = { "Workspace", "World", "Arena", "BasicArena", "Floor" },
            MinDelaySeconds = 2, MaxDelaySeconds = 5,
            MaxActive = 30, PlacementAttempts = 12, EdgeMargin = 3,
            Weights = { ["resource.ore"] = 1 },
        },
    },
    Carrying = { Unlimited = true, VisualLimit = 20, Position = "AboveHead" },
    Movement = {
        OutsideArenaSpeed = 16, ArenaBaseSpeed = 16, MinimumArenaSpeed = 4,
        ResourceThreshold = 30, -- Total carried units, not inventory or visible clusters.
        ArenaZoneId = "zone.arena", -- Reuse this zone's SurfacePath and floor shape.
        ArenaHeight = 64, BelowSurfaceTolerance = 6,
    },
    OwnerPickupCooldownSeconds = 3,
    -- Movement/visual defaults above are example values, not fixed design requirements.
}
