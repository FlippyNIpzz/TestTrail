
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseConfig = require(
    ReplicatedStorage.Shared.Configs.BaseConfig
)

local BaseService = {}

local bases = {}
local assignedBases = {}

-- CREATE ALL BASES
function BaseService.Initialize()
    local existing = workspace:FindFirstChild("NoGemBases")
    if existing then
        existing:Destroy()
    end

    table.clear(bases)
    table.clear(assignedBases)

    local folder = Instance.new("Folder")
    folder.Name = "NoGemBases"
    folder.Parent = workspace

    for i = 1, BaseConfig.MaxBases do
        local angle = (2 * math.pi / BaseConfig.MaxBases) * (i - 1)

        local position = Vector3.new(
            math.cos(angle) * BaseConfig.CircleRadius,
            0,
            math.sin(angle) * BaseConfig.CircleRadius
        )

        local center = Vector3.new(0, 0, 0)
        local rotation = CFrame.lookAt(position, center)

        local base = Instance.new("Model")
        base.Name = "Base_" .. i
        base:SetAttribute("OwnerUserId", 0)
        base.Parent = folder

        -- BASE FLOOR
        local floor = Instance.new("Part")
        floor.Name = "Floor"
        floor.Size = Vector3.new(
            BaseConfig.Width,
            BaseConfig.FloorThickness,
            BaseConfig.Length
        )
        floor.CFrame = rotation * CFrame.new(0, 0.5, 0)
        floor.Anchored = true
        floor.Color = Color3.fromRGB(80, 80, 90)
        floor.Material = Enum.Material.Metal
        floor.Parent = base

        base.PrimaryPart = floor

        -- FRONT MARKER FACING ARENA
        local marker = Instance.new("Part")
        marker.Name = "FrontMarker"
        marker.Size = Vector3.new(BaseConfig.Width, 0.2, 2)
        marker.CFrame = floor.CFrame * CFrame.new(
            0,
            BaseConfig.FloorThickness / 2 + 0.1,
            -BaseConfig.Length / 2 + 1
        )
        marker.Anchored = true
        marker.CanCollide = false
        marker.Color = Color3.fromRGB(0, 170, 255)
        marker.Material = Enum.Material.Neon
        marker.Parent = base

        bases[i] = base
    end

    print("[BaseService] Created", #bases, "bases")
end

-- ASSIGN AVAILABLE BASE
function BaseService.Assign(player)
    if assignedBases[player.UserId] then
        return assignedBases[player.UserId]
    end

    for _, base in ipairs(bases) do
        if base:GetAttribute("OwnerUserId") == 0 then
            base:SetAttribute("OwnerUserId", player.UserId)
            assignedBases[player.UserId] = base

            base.Floor.Color = Color3.fromRGB(50, 160, 100)

            print("[BaseService] Assigned", base.Name, "to", player.Name)

            return base
        end
    end

    warn("[BaseService] No available base for", player.Name)
    return nil
end

-- GET PLAYER BASE
function BaseService.GetBase(player)
    return assignedBases[player.UserId]
end

-- CHECK OWNERSHIP
function BaseService.IsOwner(player, base)
    return base ~= nil
        and base:GetAttribute("OwnerUserId") == player.UserId
end

-- POSITION PLAYER ON BASE
function BaseService.SpawnCharacter(player, character)
    local base = BaseService.GetBase(player)
    if not base then
        return false
    end

    local root = character:WaitForChild("HumanoidRootPart", 10)
    if not root then
        return false
    end

    character:PivotTo(base.Floor.CFrame * CFrame.new(0, 5, 0))
    return true
end

-- LOAD SAVED BASE
function BaseService.LoadBase(player)
    -- TODO: Restore saved base facilities
    return false
end

-- REBUILD BASE
function BaseService.Rebuild(player)
    -- TODO: Reconstruct saved facility layout
    return false
end

-- RELEASE BASE
function BaseService.Release(player)
    local base = assignedBases[player.UserId]
    if not base then
        return false
    end

    base:SetAttribute("OwnerUserId", 0)
    base.Floor.Color = Color3.fromRGB(80, 80, 90)

    assignedBases[player.UserId] = nil

    print("[BaseService] Released", base.Name)
    return true
end

return BaseService
