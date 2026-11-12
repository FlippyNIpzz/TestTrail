--!strict
-- Meteor Shower Arena Mode
-- Rains falling meteors from the sky that telegraph, crash into the arena, damage characters, and leave rich crater ore clusters.

local Players = game:GetService("Players")
local Geometry = require(script.Parent.Parent.ArenaGeometry)
local ModeTypes = require(script.Parent.ModeTypes)

type ActiveMeteor = {
	Reticle: BasePart,
	Projectile: BasePart,
	TargetPos: Vector3,
	StartPos: Vector3,
	StartTime: number,
	ImpactTime: number,
}

local MeteorShower = {}
local activeMeteors: { ActiveMeteor } = {}
local nextWaveTime = 0
local currentContext: ModeTypes.ModeContext? = nil
local random = Random.new()

local WAVE_INTERVAL = 4.5
local FALL_DURATION = 2.0
local RETICLE_RADIUS = 7.0
local BLAST_RADIUS = 13.0
local BLAST_DAMAGE = 25
local START_HEIGHT = 80.0

local function spawnMeteorWave(context: ModeTypes.ModeContext, now: number)
	local bounds = context.Bounds
	local count = random:NextInteger(2, 3)

	for _ = 1, count do
		local targetPos = Geometry.RandomSurface(bounds, random, 8, 0.08)
		local xOffset = random:NextNumber(-15, 15)
		local zOffset = random:NextNumber(-15, 15)
		local startPos = targetPos + Vector3.new(xOffset, START_HEIGHT, zOffset)

		-- Reticle on the ground
		local reticle = Instance.new("Part")
		reticle.Name = "MeteorReticle"
		reticle.Shape = Enum.PartType.Cylinder
		reticle.Size = Vector3.new(0.15, RETICLE_RADIUS * 2, RETICLE_RADIUS * 2)
		reticle.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, 0, math.rad(90))
		reticle.Color = Color3.fromRGB(255, 75, 20)
		reticle.Material = Enum.Material.Neon
		reticle.Transparency = 0.5
		reticle.Anchored = true
		reticle.CanCollide = false
		reticle.CanTouch = false
		reticle.CanQuery = false
		reticle.Parent = context.HazardsFolder

		-- Falling projectile
		local projectile = Instance.new("Part")
		projectile.Name = "MeteorProjectile"
		projectile.Shape = Enum.PartType.Ball
		projectile.Size = Vector3.new(3.5, 3.5, 3.5)
		projectile.CFrame = CFrame.new(startPos)
		projectile.Color = Color3.fromRGB(195, 60, 20)
		projectile.Material = Enum.Material.Slate
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Parent = context.HazardsFolder

		local meteor: ActiveMeteor = {
			Reticle = reticle,
			Projectile = projectile,
			TargetPos = targetPos,
			StartPos = startPos,
			StartTime = now,
			ImpactTime = now + FALL_DURATION,
		}
		table.insert(activeMeteors, meteor)
	end
end

local function handleImpact(context: ModeTypes.ModeContext, meteor: ActiveMeteor)
	local targetPos = meteor.TargetPos
	local bounds = context.Bounds

	-- Visual impact flash
	local flash = Instance.new("Part")
	flash.Name = "MeteorBlast"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(BLAST_RADIUS * 1.5, BLAST_RADIUS * 1.5, BLAST_RADIUS * 1.5)
	flash.CFrame = CFrame.new(targetPos)
	flash.Color = Color3.fromRGB(255, 150, 40)
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.3
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.Parent = context.HazardsFolder
	task.delay(0.25, function()
		if flash and flash:IsDescendantOf(workspace) then flash:Destroy() end
	end)

	-- Deal blast damage to players in radius (triggers carried ore drops)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then continue end
		if not Geometry.Contains(bounds, root.Position) then continue end

		local dist = (root.Position - targetPos).Magnitude
		if dist <= BLAST_RADIUS then
			humanoid:TakeDamage(BLAST_DAMAGE)
		end
	end

	-- Deal blast damage to companions
	local gameFolder = workspace:FindFirstChild("Game")
	local compContainer = gameFolder and gameFolder:FindFirstChild("Companions")
	if compContainer then
		for _, companion in compContainer:GetChildren() do
			if not companion:IsA("Model") then continue end
			local compHumanoid = companion:FindFirstChildWhichIsA("Humanoid")
			local primary = companion.PrimaryPart or companion:FindFirstChildWhichIsA("BasePart")
			if not compHumanoid or compHumanoid.Health <= 0 or not primary then continue end
			if not Geometry.Contains(bounds, primary.Position) then continue end

			local dist = (primary.Position - targetPos).Magnitude
			if dist <= BLAST_RADIUS then
				compHumanoid:TakeDamage(BLAST_DAMAGE)
			end
		end
	end

	-- Crater Harvest: spawn 2-3 fresh crater ores around blast site
	local oreCount = random:NextInteger(2, 3)
	for _ = 1, oreCount do
		local angle = random:NextNumber(0, 2 * math.pi)
		local dist = random:NextNumber(2.0, 5.0)
		local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local orePos = targetPos + offset
		local oreId = if random:NextNumber() <= 0.70 then "MeteoricOre" else "AstralShard"
		context.SpawnOreAt(bounds, oreId, orePos)
	end

	-- Cleanup meteor parts
	if meteor.Reticle:IsDescendantOf(workspace) then meteor.Reticle:Destroy() end
	if meteor.Projectile:IsDescendantOf(workspace) then meteor.Projectile:Destroy() end
end

function MeteorShower.Start(context: ModeTypes.ModeContext)
	MeteorShower.Stop()
	currentContext = context
	local now = workspace:GetServerTimeNow()
	nextWaveTime = now + 1.5
end

function MeteorShower.Step(now: number, _dt: number)
	local context = currentContext
	if not context then return end

	-- Spawn waves
	if now >= nextWaveTime then
		nextWaveTime = now + WAVE_INTERVAL
		spawnMeteorWave(context, now)
	end

	-- Update in-flight meteors
	local i = 1
	while i <= #activeMeteors do
		local meteor = activeMeteors[i]
		if not meteor.Projectile:IsDescendantOf(workspace) or not meteor.Reticle:IsDescendantOf(workspace) then
			table.remove(activeMeteors, i)
			continue
		end

		if now >= meteor.ImpactTime then
			handleImpact(context, meteor)
			table.remove(activeMeteors, i)
		else
			local alpha = math.clamp((now - meteor.StartTime) / FALL_DURATION, 0, 1)
			-- Smooth downward trajectory
			local currentPos = meteor.StartPos:Lerp(meteor.TargetPos, alpha)
			meteor.Projectile.CFrame = CFrame.new(currentPos)
			-- Pulsate reticle size slightly
			local pulse = 1 + 0.15 * math.sin(alpha * math.pi * 4)
			meteor.Reticle.Size = Vector3.new(0.15, RETICLE_RADIUS * 2 * pulse, RETICLE_RADIUS * 2 * pulse)
			i += 1
		end
	end
end

function MeteorShower.Stop()
	for _, meteor in activeMeteors do
		if meteor.Reticle and meteor.Reticle:IsDescendantOf(workspace) then meteor.Reticle:Destroy() end
		if meteor.Projectile and meteor.Projectile:IsDescendantOf(workspace) then meteor.Projectile:Destroy() end
	end
	table.clear(activeMeteors)
	currentContext = nil
	nextWaveTime = 0
end

return MeteorShower
