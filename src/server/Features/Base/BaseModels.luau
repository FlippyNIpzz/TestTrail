--!strict
-- Template validation and positioning only; BaseService owns assignments and levels.
local InsertService = game:GetService("InsertService")
local Models = {}
function Models.Resolve(path: { string }): Instance
    assert(type(path) == "table" and #path > 0, "Base asset path is empty")
    local current: Instance = game
    for _, name in path do
        local child = current:FindFirstChild(name)
        assert(child, "Missing base path: " .. table.concat(path, "."))
        current = child
    end
    return current
end
function Models.Load(asset: any): Model
    assert(asset.ExpectedClass == "Model", "Base assets must declare ExpectedClass Model")
    local model: any
    if asset.Kind == "ProjectPath" then
        model = Models.Resolve(asset.Path):Clone()
    elseif asset.Kind == "AssetId" then
        assert(type(asset.Id) == "number" and asset.Id > 0 and asset.Id < math.huge and asset.Id % 1 == 0, "Invalid base asset ID")
        local ok, result = pcall(InsertService.LoadAsset, InsertService, asset.Id)
        assert(ok, "Base asset load failed: " .. tostring(result))
        model = result
    else error("Unsupported base asset kind") end
    assert(model, "Base asset must be Archivable")
    return model
end
function Models.Validate(model: Instance, floorName: string): BasePart
    assert(model:IsA("Model"), "Base template must be a Model")
    local floor = model:FindFirstChild(floorName, true)
    assert(floor and floor:IsA("BasePart"), "Base template missing floor: " .. floorName)
    assert(floor.CFrame.UpVector:Dot(Vector3.yAxis) > 0.999, "Base floor must use local Y as vertical")
    for _, instance in model:GetDescendants() do
        assert(not instance:IsA("LuaSourceContainer"), "Base structures cannot contain scripts")
        if instance:IsA("BasePart") then instance.Anchored = true end
    end
    return floor
end
function Models.Origin(floor: BasePart): CFrame
    return floor.CFrame * CFrame.new(0, -floor.Size.Y / 2, 0)
end
function Models.Create(template: Model, layout: any, origin: CFrame, player: Player, level: number): Model
    local model = template:Clone()
    local ok, failure = pcall(function()
        local floor = Models.Validate(model, layout.FloorName)
        local offset = Models.Origin(floor):ToObjectSpace(model:GetPivot())
        model:PivotTo(origin * offset)
        model.Name = "Structure"
        model:SetAttribute("OwnerUserId", player.UserId)
        model:SetAttribute("BaseLevel", level)
        model:SetAttribute("PlotLevel", level)
        model:SetAttribute("Unclaimed", false)
        model:SetAttribute("ModelType", layout.ModelType)
    end)
    if not ok then model:Destroy(); error(failure, 0) end
    return model
end
return Models
