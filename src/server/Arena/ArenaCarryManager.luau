--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.ArenaData)
local Arena = require(script.Parent.Arena)
local Inventory = require(script.Parent.Parent.PlayerData.Inventory)
local Data = require(script.Parent.Parent.PlayerData.PlayerDataModule)
local World = require(script.Parent.Parent.Companion.CompanionWorld)
local Carry = {}
type PlayerState = {
	character: Model,
	humanoid: Humanoid,
	count: number,
	appliedSpeed: number?,
	healthConnection: RBXScriptConnection?,
	stack: Folder?,
}
local states: { [Player]: PlayerState } = {}
local connections: {RBXScriptConnection} = {}

local function release(state: PlayerState)
	if state.healthConnection then state.healthConnection:Disconnect() end
	if state.humanoid and state.appliedSpeed and state.humanoid.WalkSpeed == state.appliedSpeed then
		state.humanoid.WalkSpeed = Config.DefaultWalkSpeed
	end
	if state.stack then state.stack:Destroy(); state.stack = nil end
end

local function rebuildStack(state: PlayerState, character: Model, root: BasePart, count: number)
	if state.stack then state.stack:Destroy(); state.stack = nil end
	if count <= 0 then return end
	local stack = Instance.new("Folder")
	stack.Name = "CarriedOreStack"
	stack.Parent = character
	state.stack = stack
	local head = character:FindFirstChild("Head")
	local top = if head and head:IsA("BasePart") then head.Position.Y - root.Position.Y + head.Size.Y / 2 else 3
	for i = 1, math.min(count, Config.MaxVisibleStack) do
		local part = Instance.new("Part")
		part.Name = "Ore"
		part.Size = Vector3.new(1.5, 0.7, 1.5)
		part.Material = Enum.Material.Slate
		part.Color = Color3.fromRGB(155, 157, 166)
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Massless = true
		part.CFrame = root.CFrame * CFrame.new(0, top + 0.35 + (i - 1) * 0.75, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, part
		weld.Parent = part
		part.Parent = stack
		if i == math.min(count, Config.MaxVisibleStack) then
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(120, 30)
			gui.StudsOffset = Vector3.new(0, 1, 0)
			gui.MaxDistance = 100
			gui.Parent = part
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = tostring(count) .. " ore"
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0
			label.TextSize = 16
			label.Parent = gui
		end
	end
end

function Carry.Step()
	local bounds = World.Arena()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		local existingState: PlayerState? = states[player]
		if existingState and (existingState.character ~= character or existingState.humanoid ~= humanoid) then
			release(existingState)
			states[player] = nil
			existingState = nil
		end
		if not character or not root or not root:IsA("BasePart") or not humanoid then continue end
		local state: PlayerState
		if existingState then
			state = existingState
		else
			local newState: PlayerState = {character = character, humanoid = humanoid, count = -1}
			local previousHealth = humanoid.Health
			newState.healthConnection = humanoid.HealthChanged:Connect(function(health)
				local damaged = health < previousHealth
				previousHealth = health
				if damaged and player.Character == character then Arena.DropCarriedOre(player) end
			end)
			states[player] = newState
			state = newState
		end
		local count = 0
		if Data.GetProfile(player) then
			for _, amount in pairs(Inventory.GetOres(player)) do count += amount end
		end
		if state.count ~= count then
			state.count = count
			rebuildStack(state, character, root, count)
		end
		local inside = bounds ~= nil and World.InArena(bounds, root.Position)
		local speed = Config.DefaultWalkSpeed
		if inside and humanoid.Health > 0 then
			speed = math.min(speed, math.max(Config.MinimumCarrySpeed, speed - count * Config.SpeedPenaltyPerOre))
		end
		humanoid.WalkSpeed = speed
		state.appliedSpeed = speed
	end
end

function Carry.Stop()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for _, state in pairs(states) do release(state) end
	table.clear(states)
end

function Carry.Init()
	if #connections > 0 then return end
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then release(state); states[player] = nil end
	end))
	table.insert(connections, RunService.Heartbeat:Connect(Carry.Step))
	Carry.Step()
end
return Carry
