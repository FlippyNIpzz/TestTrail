--!strict
-- Titan's Awakening Arena Mode
-- Mini-boss that roams the arena targeting players and companions, executing telegraphed Ground Slam shockwaves.

local Players = game:GetService("Players")
local Geometry = require(script.Parent.Parent.ArenaGeometry)
local ModeTypes = require(script.Parent.ModeTypes)

local TitanAwakening = {}
local currentContext: ModeTypes.ModeContext? = nil

local bossModel: Model? = nil
local bossPrimary: BasePart? = nil
local isProcedural = false

local nextSlamTime = 0
local slamCharging = false
local slamChargeEndTime = 0
local slamIndicator: BasePart? = nil

local MOVE_SPEED = 10.0
local SLAM_COOLDOWN = 8.0
local SLAM_CHARGE_DURATION = 1.5
local SLAM_RADIUS = 16.0
local SLAM_DAMAGE = 25.0

local function createProceduralTitan(context: ModeTypes.ModeContext): Model
	local model = Instance.new("Model")
	model.Name = "TitanGolem"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(4, 6, 3)
	root.Color = Color3.fromRGB(110, 115, 125)
	root.Material = Enum.Material.Slate
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.5, 2, 2)
	head.Color = Color3.fromRGB(80, 150, 160)
	head.Material = Enum.Material.Neon
	head.Anchored = true
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false

	root.Parent = model
	head.Parent = model
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 1500
	humanoid.Health = 1500
	humanoid.Parent = model

	local bounds = context.Bounds
	local startPos = Geometry.Surface(bounds, bounds.Position, 0, 3.5)
	root.CFrame = CFrame.new(startPos)
	head.CFrame = CFrame.new(startPos + Vector3.new(0, 4, 0))

	model:SetAttribute("ArenaMode", "TitanAwakening")
	model.Parent = context.BossesFolder
	return model
end

local function findOrCreateBoss(context: ModeTypes.ModeContext)
	-- Check if a template boss was already spawned by Arena.luau from ServerStorage
	for _, child in context.BossesFolder:GetChildren() do
		if child:IsA("Model") then
			local prim = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
			if prim then
				bossModel = child
				bossPrimary = prim
				isProcedural = false
				return
			end
		end
	end

	-- Procedural fallback if no authored boss template was present in ServerStorage
	local model = createProceduralTitan(context)
	bossModel = model
	bossPrimary = model.PrimaryPart
	isProcedural = true
end

local function findNearestTarget(bounds: BasePart, bossPos: Vector3): Vector3?
	local nearestTarget: Vector3? = nil
	local nearestDist = math.huge

	-- 1. Check players
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then continue end
		if not Geometry.Contains(bounds, root.Position) then continue end

		local dist = (root.Position - bossPos).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearestTarget = root.Position
		end
	end

	-- 2. Check companions
	local gameFolder = workspace:FindFirstChild("Game")
	local compContainer = gameFolder and gameFolder:FindFirstChild("Companions")
	if compContainer then
		for _, companion in compContainer:GetChildren() do
			if not companion:IsA("Model") then continue end
			local compHumanoid = companion:FindFirstChildWhichIsA("Humanoid")
			local primary = companion.PrimaryPart or companion:FindFirstChildWhichIsA("BasePart")
			if not compHumanoid or compHumanoid.Health <= 0 or not primary then continue end
			if not Geometry.Contains(bounds, primary.Position) then continue end

			local dist = (primary.Position - bossPos).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearestTarget = primary.Position
			end
		end
	end

	return nearestTarget
end

local function executeGroundSlam(context: ModeTypes.ModeContext, bossPos: Vector3)
	local bounds = context.Bounds

	-- Visual blast flash
	local shockwave = Instance.new("Part")
	shockwave.Name = "TitanShockwave"
	shockwave.Shape = Enum.PartType.Cylinder
	shockwave.Size = Vector3.new(0.3, SLAM_RADIUS * 2, SLAM_RADIUS * 2)
	shockwave.CFrame = CFrame.new(bossPos) * CFrame.Angles(0, 0, math.rad(90))
	shockwave.Color = Color3.fromRGB(60, 200, 220)
	shockwave.Material = Enum.Material.Neon
	shockwave.Transparency = 0.2
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.CanTouch = false
	shockwave.CanQuery = false
	shockwave.Parent = context.HazardsFolder

	task.delay(0.3, function()
		if shockwave and shockwave:IsDescendantOf(workspace) then shockwave:Destroy() end
	end)

	-- Damage players in range (dropping their carried ore)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then continue end
		if not Geometry.Contains(bounds, root.Position) then continue end

		local dist = (root.Position - bossPos).Magnitude
		if dist <= SLAM_RADIUS then
			humanoid:TakeDamage(SLAM_DAMAGE)
		end
	end

	-- Damage companions in range
	local gameFolder = workspace:FindFirstChild("Game")
	local compContainer = gameFolder and gameFolder:FindFirstChild("Companions")
	if compContainer then
		for _, companion in compContainer:GetChildren() do
			if not companion:IsA("Model") then continue end
			local compHumanoid = companion:FindFirstChildWhichIsA("Humanoid")
			local primary = companion.PrimaryPart or companion:FindFirstChildWhichIsA("BasePart")
			if not compHumanoid or compHumanoid.Health <= 0 or not primary then continue end
			if not Geometry.Contains(bounds, primary.Position) then continue end

			local dist = (primary.Position - bossPos).Magnitude
			if dist <= SLAM_RADIUS then
				compHumanoid:TakeDamage(SLAM_DAMAGE)
			end
		end
	end
end

function TitanAwakening.Start(context: ModeTypes.ModeContext)
	TitanAwakening.Stop()
	currentContext = context
	local now = workspace:GetServerTimeNow()
	nextSlamTime = now + 4.0
	slamCharging = false
	slamChargeEndTime = 0
	findOrCreateBoss(context)
end

function TitanAwakening.Step(now: number, dt: number)
	local context = currentContext
	if not context then return end

	local primary = bossPrimary
	local model = bossModel
	if not primary or not primary:IsDescendantOf(workspace) or not model or not model:IsDescendantOf(workspace) then
		findOrCreateBoss(context)
		primary = bossPrimary
		model = bossModel
	end
	if not primary or not model then return end

	local bounds = context.Bounds
	local currentPos = primary.Position

	-- 1. Handle Ground Slam Charge / Execution
	if slamCharging then
		if slamIndicator and slamIndicator:IsDescendantOf(workspace) then
			local alpha = 1 - math.clamp((slamChargeEndTime - now) / SLAM_CHARGE_DURATION, 0, 1)
			slamIndicator.Size = Vector3.new(0.15, SLAM_RADIUS * 2 * alpha, SLAM_RADIUS * 2 * alpha)
		end

		if now >= slamChargeEndTime then
			slamCharging = false
			if slamIndicator and slamIndicator:IsDescendantOf(workspace) then
				slamIndicator:Destroy()
				slamIndicator = nil
			end
			executeGroundSlam(context, currentPos)
			nextSlamTime = now + SLAM_COOLDOWN
		end
		return -- Pauses during charging
	end

	-- Trigger new slam charge
	if now >= nextSlamTime then
		slamCharging = true
		slamChargeEndTime = now + SLAM_CHARGE_DURATION

		local indicator = Instance.new("Part")
		indicator.Name = "SlamIndicator"
		indicator.Shape = Enum.PartType.Cylinder
		indicator.Size = Vector3.new(0.15, 2, 2)
		indicator.CFrame = CFrame.new(currentPos) * CFrame.Angles(0, 0, math.rad(90))
		indicator.Color = Color3.fromRGB(255, 120, 20)
		indicator.Material = Enum.Material.Neon
		indicator.Transparency = 0.5
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.CanTouch = false
		indicator.CanQuery = false
		indicator.Parent = context.HazardsFolder
		slamIndicator = indicator
		return
	end

	-- 2. Roam towards nearest target
	local targetPos = findNearestTarget(bounds, currentPos)
	if targetPos then
		local delta = targetPos - currentPos
		local horizontal = Vector3.new(delta.X, 0, delta.Z)
		if horizontal.Magnitude > 3.0 then
			local moveDir = horizontal.Unit
			local stepDist = math.min(horizontal.Magnitude, MOVE_SPEED * dt)
			local newPos = currentPos + moveDir * stepDist
			local clamped = Geometry.Surface(bounds, newPos, 4, 3.5)

			local lookTarget = Vector3.new(targetPos.X, clamped.Y, targetPos.Z)
			local newCFrame = CFrame.lookAt(clamped, lookTarget)
			if model:IsA("Model") then
				model:PivotTo(newCFrame)
			else
				primary.CFrame = newCFrame
			end
		end
	end
end

function TitanAwakening.Stop()
	if slamIndicator and slamIndicator:IsDescendantOf(workspace) then
		slamIndicator:Destroy()
		slamIndicator = nil
	end
	if isProcedural and bossModel and bossModel:IsDescendantOf(workspace) then
		bossModel:Destroy()
	end
	bossModel = nil
	bossPrimary = nil
	isProcedural = false
	currentContext = nil
	slamCharging = false
	nextSlamTime = 0
	slamChargeEndTime = 0
end

return TitanAwakening
