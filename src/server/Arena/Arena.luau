--!strict
-- Server-owned timed arena, ore collection, and per-mode boss template spawning.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(script.Parent.ArenaData)
local BaseManager = require(script.Parent.Parent.Base.BaseManager)
local Data = require(script.Parent.Parent.PlayerData.PlayerDataModule)
local Inventory = require(script.Parent.Parent.PlayerData.Inventory)
local World = require(script.Parent.Parent.Companion.CompanionWorld)
local MoltenSurge = require(script.Parent.Modes.MoltenSurge)
local MeteorShower = require(script.Parent.Modes.MeteorShower)
local TitanAwakening = require(script.Parent.Modes.TitanAwakening)
local ModeTypes = require(script.Parent.Modes.ModeTypes)

local Arena = {}
local random = Random.new()
local runtime: Folder? = nil
local ores: Folder? = nil
local drops: Folder? = nil
local bosses: Folder? = nil
local hazards: Folder? = nil
local activeHandler: any = nil
local modeHandlers: { [string]: any } = {}
if MoltenSurge then modeHandlers["MoltenSurge"] = MoltenSurge end
if MeteorShower then modeHandlers["MeteorShower"] = MeteorShower end
if TitanAwakening then modeHandlers["TitanAwakening"] = TitanAwakening end
local connection: RBXScriptConnection? = nil
local leaving: RBXScriptConnection? = nil
local modeIndex = 0
local endsAt = 0
local nextSpawn = 0
local nextPickup = 0
local lastCollection: { [Player]: number } = {}
local registered: { [BasePart]: string } = {}
local dropInfo: { [BasePart]: {Amount: number, Owner: number, UnlockAt: number, ExpiresAt: number} } = {}

function Arena.HasPlacedForge(player: Player): boolean
	local base = BaseManager.GetBaseForPlayer(player)
	if not base or base.Player ~= player or not base.Model or not base.Model:IsDescendantOf(workspace) then return false end
	local assets = base.Model:FindFirstChild("PlacedAssets")
	local forge = assets and assets:FindFirstChild("Zone1")
	return forge ~= nil and (forge:IsA("BasePart") or (forge:IsA("Model") and forge:FindFirstChildWhichIsA("BasePart", true) ~= nil))
end

-- All future weapons/mining handlers must use this gate before touching arena ore.
function Arena.CanInteractWithOre(player: Player, ore: BasePart): (boolean, string?)
	if not registered[ore] or (ore.Parent ~= ores and ore.Parent ~= drops) then return false, "Ore is unavailable." end
	local dropped = dropInfo[ore]
	if dropped and player.UserId == dropped.Owner and workspace:GetServerTimeNow() < dropped.UnlockAt then
		return false, "You cannot reclaim your dropped ore yet."
	end
	if player.Parent ~= Players or not Data.GetProfile(player) then return false, "Player data is not ready." end
	if not Arena.HasPlacedForge(player) then return false, "Place a forge in your base first." end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	local bounds = World.Arena()
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return false, "Character is unavailable." end
	if not bounds or not World.InArena(bounds, root.Position) or not World.InArena(bounds, ore.Position) then return false, "Enter the arena first." end
	if (root.Position - ore.Position).Magnitude > Config.InteractionDistance then return false, "Ore is too far away." end
	return true, nil
end

function Arena.TryCollectOre(player: Player, ore: BasePart): (boolean, string?)
	local allowed, reason = Arena.CanInteractWithOre(player, ore)
	if not allowed then return false, reason end
	local now = os.clock()
	if now - (lastCollection[player] or -math.huge) < Config.CollectionCooldown then return false, "Please wait." end
	local oreId = registered[ore]
	-- Claim before awarding; no yielding between validation, claim, and inventory mutation.
	registered[ore] = nil
	lastCollection[player] = now
	local dropped = dropInfo[ore]
	local amount = if dropped then dropped.Amount else (if Config.Ores[oreId] then Config.Ores[oreId].Amount else 1)
	Inventory.AddItem(player, oreId, amount)
	ore:Destroy()
	return true, nil
end

-- Server polling covers stationary players, new spawns, and forge placement/removal.
-- Pick the nearest eligible ore; claims and cooldown remain in TryCollectOre.
function Arena.CollectNearbyOre()
	for _, player in Players:GetPlayers() do
		if os.clock() - (lastCollection[player] or -math.huge) < Config.CollectionCooldown then continue end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not Arena.HasPlacedForge(player) then continue end
		local nearest: BasePart? = nil
		local nearestDistance = math.huge
		for ore in pairs(registered) do
			local distance = (root.Position - ore.Position).Magnitude
			if distance <= Config.InteractionDistance and distance < nearestDistance
				and Arena.CanInteractWithOre(player, ore) then
				nearest, nearestDistance = ore, distance
			end
		end
		if nearest then Arena.TryCollectOre(player, nearest) end
	end
end

local function spawnFrame(bounds: BasePart, height: number): CFrame
	return CFrame.new(World.RandomArenaSurface(bounds, random, Config.SpawnInset, height))
end

function Arena.RegisterOre(ore: BasePart, id: string)
	registered[ore] = id
	ore.Destroying:Connect(function() registered[ore] = nil end)
end

local function resourceTemplate(id: string): Model?
	local scene = workspace:FindFirstChild("Game")
	local arena = scene and scene:FindFirstChild("Arena")
	local authored = arena and arena:FindFirstChild("Resource_Models")
	local stored = ServerStorage:FindFirstChild("ResourceModels")
	-- Keep sparse locations from masking a matching storage template.
	for _, folder in { authored, stored } do
		local candidate = folder and folder:FindFirstChild(id)
		if candidate and candidate:IsA("Model") and candidate.Archivable
			and candidate:FindFirstChildWhichIsA("BasePart", true) then return candidate end
	end
	return nil
end

function Arena.SpawnOreAt(bounds: BasePart, id: string, position: Vector3): BasePart?
	local folder = ores
	if not folder then return nil end
	local definition = Config.Ores[id]
	if not definition then return nil end
	local ore = Instance.new("Part")
	ore.Name = id
	ore.Shape = Enum.PartType.Ball
	ore.Size = Vector3.new(3, 3, 3)
	ore.Color = definition.Color
	ore.Material = Enum.Material.Slate
	ore.Anchored = true
	ore.CanCollide, ore.CanTouch, ore.CanQuery = false, false, false
	local clamped = World.ArenaSurface(bounds, position, 0, 1.5)
	ore.CFrame = CFrame.new(clamped)
	local template = resourceTemplate(id)
	if template then
		local model = template:Clone()
		local box, size = model:GetBoundingBox()
		local pivot = model:GetPivot()
		local surface = World.ArenaSurface(bounds, position, math.max(size.X, size.Z) / 2, 0)
		local bottom = Vector3.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
		model:PivotTo(pivot + (surface - bottom))
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			end
		end
		-- The invisible pickup root preserves the BasePart API and owns all visual cleanup.
		ore.Transparency = 1
		ore.CFrame = CFrame.new(surface + Vector3.new(0, 1.5, 0))
		model.Parent = ore
	end
	ore:SetAttribute("OreType", id)
	Arena.RegisterOre(ore, id)
	ore.Parent = folder
	return ore
end

local function spawnOre(bounds: BasePart)
	local folder = ores
	if not folder then return end
	local mode = Config.Modes[modeIndex]
	if #folder:GetChildren() >= mode.MaxOres then return end
	local id = mode.Ores[random:NextInteger(1, #mode.Ores)]
	local position = World.RandomArenaSurface(bounds, random, Config.SpawnInset, 1.5)
	Arena.SpawnOreAt(bounds, id, position)
end

-- One bundle per ore type preserves quantities without spawning hundreds of parts.
function Arena.DropCarriedOre(player: Player): boolean
	local folder = drops
	local bounds = World.Arena()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not folder or not bounds or not root or not root:IsA("BasePart")
		or not World.InArena(bounds, root.Position) or not Data.GetProfile(player) then return false end
	local now = workspace:GetServerTimeNow()
	for id, amount in pairs(Inventory.GetOres(player)) do
		local ore = Instance.new("Part")
		ore.Name = id .. "Drop"
		ore.Size = Vector3.new(2, 2, 2)
		ore.Anchored = true
		ore.CanCollide, ore.CanTouch, ore.CanQuery = false, false, false
		local definition = Config.Ores[id]
		ore.Color = if definition then definition.Color else Color3.fromRGB(130, 130, 130)
		local scattered = root.Position + Vector3.new(random:NextNumber(-4, 4), 0, random:NextNumber(-4, 4))
		ore.CFrame = CFrame.new(World.ArenaSurface(bounds, scattered, math.sqrt(2), 1))
		ore:SetAttribute("OreType", id)
		ore:SetAttribute("Amount", amount)
		ore:SetAttribute("DroppedBy", player.UserId)
		ore:SetAttribute("OwnerPickupUnlockAt", now + Config.DropPickupDelay)
		if Inventory.RemoveItem(player, id, amount) then
			registered[ore] = id
			dropInfo[ore] = {Amount = amount, Owner = player.UserId,
				UnlockAt = now + Config.DropPickupDelay, ExpiresAt = now + Config.DropLifetime}
			ore.Destroying:Connect(function() registered[ore] = nil; dropInfo[ore] = nil end)
			ore.Parent = folder
		else
			ore:Destroy()
		end
	end
	return true
end

local function startMode(index: number, now: number, bounds: BasePart)
	modeIndex = index
	local mode = Config.Modes[index]
	endsAt = now + mode.Duration
	nextSpawn = now
	if ores then ores:ClearAllChildren() end
	if bosses then bosses:ClearAllChildren() end
	if hazards then hazards:ClearAllChildren() end

	if activeHandler and activeHandler.Stop then activeHandler.Stop() end
	activeHandler = modeHandlers[mode.Name]

	local state = runtime
	if state then
		state:SetAttribute("Mode", mode.Name)
		state:SetAttribute("ModeEndsAt", endsAt)
		state:SetAttribute("TimeRemaining", mode.Duration)
	end
	local templates = ServerStorage:FindFirstChild("ArenaBosses")
	for _, name in ipairs(mode.Bosses) do
		local template = templates and templates:FindFirstChild(name)
		if template and template:IsA("Model") and template:FindFirstChildWhichIsA("BasePart", true) then
			local boss = template:Clone()
			local box, size = boss:GetBoundingBox()
			local offset = boss:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
			boss:PivotTo(spawnFrame(bounds, offset))
			boss:SetAttribute("ArenaMode", mode.Name)
			boss.Parent = bosses
		else
			warn(("[Arena] Missing boss Model ServerStorage.ArenaBosses.%s; skipping boss."):format(name))
		end
	end

	if activeHandler and activeHandler.Start and runtime and ores and drops and bosses and hazards then
		local context: ModeTypes.ModeContext = {
			Bounds = bounds,
			RuntimeFolder = runtime,
			HazardsFolder = hazards,
			OresFolder = ores,
			DropsFolder = drops,
			BossesFolder = bosses,
			RegisterOre = Arena.RegisterOre,
			SpawnOreAt = Arena.SpawnOreAt,
		}
		activeHandler.Start(context)
	end
end

function Arena.Stop()
	if connection then connection:Disconnect(); connection = nil end
	if leaving then leaving:Disconnect(); leaving = nil end
	if activeHandler and activeHandler.Stop then activeHandler.Stop() end
	activeHandler = nil
	if runtime then runtime:Destroy() end
	runtime, ores, bosses, drops, hazards = nil, nil, nil, nil, nil
	table.clear(dropInfo)
	modeIndex = 0
	endsAt = 0
	nextSpawn = 0
	nextPickup = 0
	table.clear(registered)
	table.clear(lastCollection)
end

function Arena.Init()
	if connection then return end
	local folder = Instance.new("Folder")
	folder.Name = "RuntimeArena"
	folder.Parent = workspace
	runtime = folder

	local oresFolder = Instance.new("Folder")
	oresFolder.Name = "Ores"
	oresFolder.Parent = folder
	ores = oresFolder

	local dropsFolder = Instance.new("Folder")
	dropsFolder.Name = "Drops"
	dropsFolder.Parent = folder
	drops = dropsFolder

	local bossesFolder = Instance.new("Folder")
	bossesFolder.Name = "Bosses"
	bossesFolder.Parent = folder
	bosses = bossesFolder

	local hazardsFolder = Instance.new("Folder")
	hazardsFolder.Name = "Hazards"
	hazardsFolder.Parent = folder
	hazards = hazardsFolder

	folder:SetAttribute("Mode", "WaitingForArena")
	leaving = Players.PlayerRemoving:Connect(function(player) lastCollection[player] = nil end)
	connection = RunService.Heartbeat:Connect(function(dt: number)
		for ore, info in pairs(dropInfo) do
			if workspace:GetServerTimeNow() >= info.ExpiresAt then ore:Destroy() end
		end
		local bounds = World.Arena()
		if not bounds then
			if modeIndex ~= 0 then
				if activeHandler and activeHandler.Stop then activeHandler.Stop() end
				activeHandler = nil
				if drops then drops:ClearAllChildren() end
				table.clear(dropInfo)
				table.clear(registered)
				if ores then ores:ClearAllChildren() end
				if bosses then bosses:ClearAllChildren() end
				if hazards then hazards:ClearAllChildren() end
				modeIndex = 0
				endsAt = 0
				nextSpawn = 0
			end
			folder:SetAttribute("Mode", "WaitingForArena")
			folder:SetAttribute("TimeRemaining", 0)
			folder:SetAttribute("ModeEndsAt", 0)
			return
		end
		local now = workspace:GetServerTimeNow()
		if modeIndex == 0 or now >= endsAt then startMode(modeIndex % #Config.Modes + 1, now, bounds) end
		folder:SetAttribute("TimeRemaining", math.max(0, math.ceil(endsAt - now)))
		if now >= nextSpawn then
			nextSpawn = now + Config.Modes[modeIndex].SpawnInterval
			spawnOre(bounds)
		end
		if now >= nextPickup then
			nextPickup = now + Config.PickupScanInterval
			Arena.CollectNearbyOre()
		end
		if activeHandler and activeHandler.Step then
			activeHandler.Step(now, dt)
		end
	end)
end

return Arena
