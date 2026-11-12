--!strict
-- Server owns collection mutations, movement, stamina, healing and arena damage.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(script.Parent.Parent.PlayerData.PlayerDataModule)
local Config = require(script.Parent.CompanionData)
local Rules = require(script.Parent.CompanionRules)
local Collection = require(script.Parent.CompanionCollection)
local World = require(script.Parent.CompanionWorld)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Manager = {}
local sessions: {[Player]: any} = {}
local initialized = false
local container: Folder
local Bases: any
local Assets: any

local function collectionFor(player: Player): any
	local profile = Data.GetProfile(player)
	return profile and profile.Companions
end
local function equipped(player: Player): Config.Companion?
	local collection = collectionFor(player)
	return if collection then Collection.Find(collection, collection.EquippedId) else nil
end
function Manager.Snapshot(player: Player): any
	local collection = collectionFor(player)
	if not collection then return { Ready = false, Owned = {} } end
	local owned = {}
	for _, companion in ipairs(collection.Owned) do
		local copy = table.clone(companion)
		copy.Stats = table.clone(companion.Stats)
		copy.Values = Rules.Values(companion)
		table.insert(owned, copy)
	end
	return { Ready = true, Owned = owned, EquippedId = collection.EquippedId, XPPerLevel = Config.XPPerLevel }
end
local function publish(player: Player)
	local companion = equipped(player)
	local profile = Data.GetProfile(player)
	if profile then profile.CompanionId = if companion then companion.TemplateId else "" end
	player:SetAttribute("CompanionId", if companion then companion.TemplateId else "")
	player:SetAttribute("EquippedCompanionId", if companion then companion.Id else "")
	Remotes.CompanionUpdated:FireClient(player, Manager.Snapshot(player))
end
local function destroyModel(session: any)
	if session.Model then session.Model:Destroy() end
	session.Model = nil
	session.ModelId = nil
	session.Wander = nil
	session.NextWander = 0
	session.NeedsHomeTeleport = false
end
local function homePosition(player: Player): Vector3?
	if not Bases or not Assets then return nil end
	local base = Bases.GetBaseForPlayer(player)
	if not base then return nil end
	local station = Assets.GetChargeStationModel(player)
	local position = World.Position(station)
	return if position then position + Vector3.new(Config.HomeWanderRadius, 0, 0) else base.Position
end
local function spawn(player: Player, session: any, companion: Config.Companion)
	local templates = Collection.Templates()
	local template = templates and templates:FindFirstChild(companion.TemplateId)
	if not template or not template:IsA("Model") then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = if companion.Mode == "Home" then homePosition(player) else nil
	if not position and root and root:IsA("BasePart") then position = root.Position + Config.FollowOffset end
	if not position then position = homePosition(player) end
	if not position then return end
	local model = template:Clone()
	model.Name = "Companion_" .. player.UserId
	for _, item in model:GetDescendants() do
		if item:IsA("BaseScript") or item:IsA("ModuleScript") then item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanTouch = false
		end
	end
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("CompanionId", companion.TemplateId)
	model:SetAttribute("CollectionId", companion.Id)
	model:PivotTo(CFrame.new(World.Ground(model, position)))
	model.Parent = container
	session.Model, session.ModelId = model, companion.Id
end
local function defeat(player: Player, companion: Config.Companion)
	companion.Health = 0
	companion.Mode = "Home"
	local session = sessions[player]
	if session then
		session.NeedsHomeTeleport = true
		local home = homePosition(player)
		if home and session.Model then
			session.Model:PivotTo(CFrame.new(World.Ground(session.Model, home)))
			session.NeedsHomeTeleport = false
		end
	end
end

function Manager.Damage(player: Player, amount: number): boolean
	if not Rules.IsNumber(amount) or amount <= 0 then return false end
	local companion = equipped(player)
	if not companion or companion.Health <= 0 then return false end
	companion.Health = math.max(0, companion.Health - amount)
	if companion.Health == 0 then defeat(player, companion) end
	return true
end

-- Called only by trusted server reward systems, never exposed as a remote action.
function Manager.Grant(player: Player, templateId: string): (boolean, string)
	local collection = collectionFor(player)
	local templates = Collection.Templates()
	local template = templates and templates:FindFirstChild(templateId)
	local element, rarity = Collection.Identity(templateId)
	if not collection or not template or not template:IsA("Model") or not element or not rarity then return false, "Unknown companion" end
	local companion = Collection.Create(templateId)
	table.insert(collection.Owned, companion)
	publish(player)
	return true, companion.Id
end

function Manager.Action(player: Player, action: any, id: any, secondId: any): any
	local function result(ok: boolean, message: string): any
		return { Ok = ok, Message = message, State = Manager.Snapshot(player) }
	end
	local collection = collectionFor(player)
	if not collection then return result(false, "Inventory is still loading.") end
	if action == "Get" then return result(true, "") end
	local session = sessions[player]
	if not session then return result(false, "Companion is still loading.") end
	if os.clock() - session.LastAction < 0.2 then return result(false, "Please wait a moment.") end
	session.LastAction = os.clock()
	if action == "Mode" then
		local companion = equipped(player)
		if type(id) ~= "string" or not Config.Modes[id] or not companion then return result(false, "Invalid mode.") end
		if companion.Health <= 0 and id ~= "Home" then return result(false, "Recover health at Home first.") end
		if id == "Fight" and not World.Arena() then return result(false, "Arena boundary is unavailable.") end
		companion.Mode = id
	elseif action == "Equip" or action == "Unequip" or action == "Fuse" then
		if type(id) ~= "string" then return result(false, "Choose a companion.") end
		local companion = Collection.Find(collection, id)
		if not companion then return result(false, "You do not own that companion.") end
		if action == "Equip" then
			if collection.EquippedId ~= id then
				local previous = equipped(player)
				if previous then Rules.Store(previous) end
				collection.EquippedId = id
				if companion.Health <= 0 then companion.Mode = "Home" end
				destroyModel(session)
			end
		elseif action == "Unequip" then
			if collection.EquippedId ~= id then return result(false, "That companion is already stored.") end
			Rules.Store(companion)
			collection.EquippedId = nil
			destroyModel(session)
		else
			if collection.EquippedId ~= id then return result(false, "Equip the companion you want to keep first.") end
			if type(secondId) ~= "string" or secondId == id then return result(false, "Choose a different companion to consume.") end
			local second, index = Collection.Find(collection, secondId)
			if not second or not index or companion.Rarity ~= second.Rarity then return result(false, "Fusion requires two owned companions of the same rarity.") end
			Rules.Fuse(companion, second)
			table.remove(collection.Owned, index)
		end
	else return result(false, "Unknown action.") end
	publish(player)
	return result(true, if action == "Fuse" then "Fusion complete. Second companion consumed." else "Updated.")
end

local function step(player: Player, session: any, dt: number)
	local companion = equipped(player)
	if not companion then destroyModel(session); return end
	if session.ModelId ~= companion.Id then destroyModel(session) end
	if not session.Model then spawn(player, session, companion) end
	local model = session.Model
	if not model then return end
	if companion.Health <= 0 and companion.Mode ~= "Home" then defeat(player, companion) end
	local position = model:GetPivot().Position
	local target: Vector3? = nil
	local victimPlayer: Player? = nil
	local victimHumanoid: Humanoid? = nil
	local arena = World.Arena()
	if companion.Mode == "Home" then
		local home = homePosition(player)
		if home and session.NeedsHomeTeleport then
			model:PivotTo(CFrame.new(World.Ground(model, home)))
			position = model:GetPivot().Position
			session.NeedsHomeTeleport = false
		end
		if home then
			local station = Assets.GetChargeStationModel(player)
			local center = World.Position(station) or home
			if os.clock() >= session.NextWander then
				local angle = math.random() * math.pi * 2
				session.Wander = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Config.HomeWanderRadius
				session.NextWander = os.clock() + 3
			end
			target = session.Wander or home
			if station and (position - center).Magnitude <= Config.StationRange then
				local state = Assets.GetChargeStationData(player)
				local amount = state and math.min(state.PowerStored, dt * Config.StationTransferRate) or 0
				if amount > 0 and Assets.TryConsumeCharge(player, amount) then Rules.Recharge(companion, amount) end
			end
		end
	elseif companion.Mode == "Follow" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			target = (root.CFrame * CFrame.new(Config.FollowOffset)).Position
			if (target - position).Magnitude > Config.FollowTeleportDistance then
				model:PivotTo(CFrame.new(World.Ground(model, target)))
				position = model:GetPivot().Position
			end
		end
	elseif companion.Mode == "Fight" and arena then
		target = World.ArenaSurface(arena, arena.Position, 0, 0)
		if World.InArena(arena, position) then
			local closest = math.huge
			for otherPlayer, otherSession in pairs(sessions) do
				if otherPlayer ~= player then
					local other = equipped(otherPlayer)
					local otherModel = otherSession.Model
					if other and other.Health > 0 and otherModel then
						local point = otherModel:GetPivot().Position
						local distance = (position - point).Magnitude
						if World.InArena(arena, point) and distance < closest then
							closest, target, victimPlayer, victimHumanoid = distance, point, otherPlayer, nil
						end
					end
				end
			end
			for _, otherPlayer in Players:GetPlayers() do
				local character = otherPlayer.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if otherPlayer ~= player and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0
					and not character:FindFirstChildOfClass("ForceField") then
					local distance = (position - root.Position).Magnitude
					if World.InArena(arena, root.Position) and distance < closest then
						closest, target, victimPlayer, victimHumanoid = distance, root.Position, nil, humanoid
					end
				end
			end
		end
	end
	local values = Rules.Values(companion)
	if target then
		local grounded = World.Ground(model, target)
		local delta = grounded - position
		local speed = values.Speed * (if companion.Charge <= 0 then Config.ExhaustedSpeedMultiplier else 1)
		if delta.Magnitude > 0.1 then
			local nextPosition = position + delta.Unit * math.min(delta.Magnitude, speed * dt)
			local facing = Vector3.new(delta.X, 0, delta.Z)
			model:PivotTo(if facing.Magnitude > 0.01 then CFrame.lookAt(nextPosition, nextPosition + facing) else CFrame.new(nextPosition))
		end
		if arena and companion.Mode == "Fight" and companion.Health > 0 and (victimPlayer or victimHumanoid)
			and World.InArena(arena, model:GetPivot().Position) and World.InArena(arena, target)
			and (model:GetPivot().Position - target).Magnitude <= Config.AttackRange and os.clock() >= session.NextAttack then
			session.NextAttack = os.clock() + Config.AttackInterval
			companion.Charge = math.max(0, companion.Charge - Config.AttackChargeCost)
			model:SetAttribute("LastAttackTime", os.clock())
			if victimPlayer then Manager.Damage(victimPlayer, values.Damage)
			elseif victimHumanoid then victimHumanoid:TakeDamage(values.Damage) end
		end
	end
	for name, value in pairs({ Mode = companion.Mode, Health = companion.Health, Charge = companion.Charge,
		MaxHealth = values.Health, MaxCharge = values.Charge, Level = companion.Level, XP = companion.XP }) do
		model:SetAttribute(name, value)
	end
end

function Manager.Init()
	if initialized then return end
	initialized = true
	container = Instance.new("Folder")
	container.Name = "RuntimeCompanions"
	container.Parent = workspace
	-- Resolve base modules asynchronously so profile loading does not wait for scene assets.
	task.spawn(function()
		Bases = require(script.Parent.Parent.Base.BaseManager)
		Assets = require(script.Parent.Parent.Base.BaseAssetManager)
	end)
	local elapsed, replication = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		replication += dt
		if elapsed < 0.1 then return end
		local stepTime = math.min(elapsed, 0.5)
		elapsed = 0
		for player, session in pairs(sessions) do
			local ok, err = pcall(step, player, session, stepTime)
			if not ok and not session.Warned then warn("[Companion] " .. tostring(err)); session.Warned = true end
			if replication >= 1 then publish(player) end
		end
		if replication >= 1 then replication = 0 end
	end)
	Players.PlayerRemoving:Connect(Manager.DetachPlayer)
end
function Manager.AttachPlayer(player: Player)
	if sessions[player] or not collectionFor(player) or player.Parent ~= Players then return end
	Manager.Init()
	sessions[player] = { LastAction = -math.huge, NextAttack = 0, NextWander = 0 }
	local companion = equipped(player)
	if companion and companion.Health <= 0 then defeat(player, companion) end
	publish(player)
end
function Manager.DetachPlayer(player: Player)
	local session = sessions[player]
	if session then destroyModel(session); sessions[player] = nil end
end
return Manager
