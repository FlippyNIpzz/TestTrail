--!strict
-- Inventory (Layer 3: Manager Layer)
-- Manages player backpack inventory (raw ores, refined materials, items) and replicates state to clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Data = require(script.Parent.PlayerDataModule)
local Inventory = {}

type InventoryMap = { [string]: number }
local playerInventories: { [number]: InventoryMap } = {}

local function updateAttributesAndReplicate(player: Player, inv: InventoryMap)
	local totalOre = 0
	local totalRefined = 0
	local totalItems = 0

	for item, count in pairs(inv) do
		totalItems += count
		if string.find(item, "Refined") then
			totalRefined += count
		elseif string.find(item, "Ore") or item == "Scrap" then
			totalOre += count
		end
	end

	player:SetAttribute("CarryingOre", totalOre)
	player:SetAttribute("RefinedCount", totalRefined)
	player:SetAttribute("InventoryCount", totalItems)

	-- Replicate full inventory dictionary to client
	Remotes.InventoryUpdated:FireClient(player, inv)
end

function Inventory.GetInventory(player: Player): InventoryMap
	local profile = Data.GetProfile(player)
	if profile and profile.Inventory then return profile.Inventory end
	local userId = player.UserId
	if not playerInventories[userId] then
		playerInventories[userId] = {}
	end
	return playerInventories[userId]
end

function Inventory.AddItem(player: Player, itemId: string, count: number)
	if count <= 0 then return end
	local inv = Inventory.GetInventory(player)
	inv[itemId] = (inv[itemId] or 0) + count
	updateAttributesAndReplicate(player, inv)
	print(("[Inventory]: %s received +%d %s (Current: %d)"):format(player.Name, count, itemId, inv[itemId]))
end

function Inventory.RemoveItem(player: Player, itemId: string, count: number): boolean
	if count <= 0 then return false end
	local inv = Inventory.GetInventory(player)
	local current = inv[itemId] or 0
	if current < count then
		return false
	end
	
	inv[itemId] = current - count
	if inv[itemId] <= 0 then
		inv[itemId] = nil
	end
	updateAttributesAndReplicate(player, inv)
	return true
end

function Inventory.GetItemCount(player: Player, itemId: string): number
	local inv = Inventory.GetInventory(player)
	return inv[itemId] or 0
end

function Inventory.GetOres(player: Player): { [string]: number }
	local inv = Inventory.GetInventory(player)
	local ores: { [string]: number } = {}
	for itemId, count in pairs(inv) do
		if (string.find(itemId, "Ore") or itemId == "Scrap") and not string.find(itemId, "Refined") and count > 0 then
			ores[itemId] = count
		end
	end
	return ores
end

function Inventory.HasAnyOre(player: Player): boolean
	local inv = Inventory.GetInventory(player)
	for itemId, count in pairs(inv) do
		if (string.find(itemId, "Ore") or itemId == "Scrap") and not string.find(itemId, "Refined") and count > 0 then
			return true
		end
	end
	return false
end

function Inventory.GiveStarterItems(player: Player)
	local inv = Inventory.GetInventory(player)
	if not inv["IronOre"] or inv["IronOre"] == 0 then
		Inventory.AddItem(player, "IronOre", 5)
		print(("[Inventory]: Granted 5 starter IronOre to %s for testing."):format(player.Name))
	end
end

function Inventory.Sync(player: Player)
	updateAttributesAndReplicate(player, Inventory.GetInventory(player))
end

function Inventory.ClearPlayer(player: Player)
	playerInventories[player.UserId] = nil
end

-- Bind RemoteFunction for client initial sync
Remotes.GetInventory.OnServerInvoke = function(player: Player)
	return Inventory.GetInventory(player)
end

Players.PlayerRemoving:Connect(function(player)
	Inventory.ClearPlayer(player)
end)

return Inventory
