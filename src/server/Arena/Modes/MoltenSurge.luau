--!strict
-- Molten Surge Arena Mode
-- Spawns dynamic boiling lava pools across the arena floor that telegraph, erupt, damage players/companions, and crust over.

local Players = game:GetService("Players")
local Geometry = require(script.Parent.Parent.ArenaGeometry)
local ModeTypes = require(script.Parent.ModeTypes)

type PoolPhase = "Warning" | "Active" | "Cooling"

type LavaPool = {
	Part: BasePart,
	Center: Vector3,
	Radius: number,
	Phase: PoolPhase,
	PhaseEndsAt: number,
}

local MoltenSurge = {}
local activePools: { LavaPool } = {}
local nextSpawnTime = 0
local nextDamageCheck = 0
local currentContext: ModeTypes.ModeContext? = nil
local random = Random.new()

local SPAWN_INTERVAL = 4.0
local WARNING_DURATION = 1.5
local ACTIVE_DURATION = 6.0
local COOLING_DURATION = 1.5
local POOL_RADIUS = 6.5
local DAMAGE_INTERVAL = 0.5
local TICK_DAMAGE = 10

local function applyPhaseVisuals(pool: LavaPool)
	local part = pool.Part
	if pool.Phase == "Warning" then
		part.Color = Color3.fromRGB(240, 130, 20)
		part.Material = Enum.Material.Neon
		part.Transparency = 0.55
		part:SetAttribute("Phase", "Warning")
	elseif pool.Phase == "Active" then
		part.Color = Color3.fromRGB(255, 45, 0)
		part.Material = Enum.Material.Neon
		part.Transparency = 0.1
		part:SetAttribute("Phase", "Active")
	elseif pool.Phase == "Cooling" then
		part.Color = Color3.fromRGB(45, 45, 50)
		part.Material = Enum.Material.Basalt
		part.Transparency = 0.35
		part:SetAttribute("Phase", "Cooling")
	end
end

local function spawnLavaPool(context: ModeTypes.ModeContext, now: number)
	local bounds = context.Bounds
	local pos = Geometry.RandomSurface(bounds, random, 8, 0.08)

	local part = Instance.new("Part")
	part.Name = "LavaPool"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, POOL_RADIUS * 2, POOL_RADIUS * 2)
	part.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = context.HazardsFolder

	local pool: LavaPool = {
		Part = part,
		Center = pos,
		Radius = POOL_RADIUS,
		Phase = "Warning",
		PhaseEndsAt = now + WARNING_DURATION,
	}

	applyPhaseVisuals(pool)
	table.insert(activePools, pool)
end

local function damageNearbyCharacters(context: ModeTypes.ModeContext)
	local bounds = context.Bounds
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then continue end
		if not Geometry.Contains(bounds, root.Position) then continue end

		for _, pool in activePools do
			if pool.Phase ~= "Active" then continue end
			local dx = root.Position.X - pool.Center.X
			local dz = root.Position.Z - pool.Center.Z
			if dx * dx + dz * dz <= pool.Radius * pool.Radius then
				humanoid:TakeDamage(TICK_DAMAGE)
				break
			end
		end
	end

	-- Also damage any companions present in workspace inside the pool
	local companionsFolder = workspace:FindFirstChild("Game")
	local compContainer = companionsFolder and companionsFolder:FindFirstChild("Companions")
	if compContainer then
		for _, companion in compContainer:GetChildren() do
			if not companion:IsA("Model") then continue end
			local compHumanoid = companion:FindFirstChildWhichIsA("Humanoid")
			local primary = companion.PrimaryPart or companion:FindFirstChildWhichIsA("BasePart")
			if not compHumanoid or compHumanoid.Health <= 0 or not primary then continue end
			if not Geometry.Contains(bounds, primary.Position) then continue end

			for _, pool in activePools do
				if pool.Phase ~= "Active" then continue end
				local dx = primary.Position.X - pool.Center.X
				local dz = primary.Position.Z - pool.Center.Z
				if dx * dx + dz * dz <= pool.Radius * pool.Radius then
					compHumanoid:TakeDamage(TICK_DAMAGE)
					break
				end
			end
		end
	end
end

function MoltenSurge.Start(context: ModeTypes.ModeContext)
	MoltenSurge.Stop()
	currentContext = context
	local now = workspace:GetServerTimeNow()
	nextSpawnTime = now + 1.5
	nextDamageCheck = now
end

function MoltenSurge.Step(now: number, _dt: number)
	local context = currentContext
	if not context then return end

	-- Spawn new pool waves
	if now >= nextSpawnTime then
		nextSpawnTime = now + SPAWN_INTERVAL
		local count = random:NextInteger(2, 3)
		for _ = 1, count do
			spawnLavaPool(context, now)
		end
	end

	-- Update existing pools
	local i = 1
	while i <= #activePools do
		local pool = activePools[i]
		if not pool.Part or not pool.Part:IsDescendantOf(workspace) then
			table.remove(activePools, i)
			continue
		end

		if now >= pool.PhaseEndsAt then
			if pool.Phase == "Warning" then
				pool.Phase = "Active"
				pool.PhaseEndsAt = now + ACTIVE_DURATION
				applyPhaseVisuals(pool)
				i += 1
			elseif pool.Phase == "Active" then
				pool.Phase = "Cooling"
				pool.PhaseEndsAt = now + COOLING_DURATION
				applyPhaseVisuals(pool)
				i += 1
			else
				pool.Part:Destroy()
				table.remove(activePools, i)
			end
		else
			i += 1
		end
	end

	-- Check damage ticks
	if now >= nextDamageCheck then
		nextDamageCheck = now + DAMAGE_INTERVAL
		damageNearbyCharacters(context)
	end
end

function MoltenSurge.Stop()
	for _, pool in activePools do
		if pool.Part and pool.Part:IsDescendantOf(workspace) then
			pool.Part:Destroy()
		end
	end
	table.clear(activePools)
	currentContext = nil
	nextSpawnTime = 0
	nextDamageCheck = 0
end

return MoltenSurge
