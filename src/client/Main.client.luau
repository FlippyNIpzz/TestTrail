--!strict
-- Main Client Execution Entry Point (Layer 4)
-- Connects pixel-art economy HUD and initializes the inventory interface.

local Players = game:GetService("Players")

local Theme = require(script.Parent:WaitForChild("UITheme"))
local InventoryUI = require(script.Parent:WaitForChild("InventoryUI"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = Theme.Colors
local make = Theme.Make

local function initializeHUD()
	local screen = Instance.new("ScreenGui")
	screen.Name = "EconomyHUD"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	-- Wallet & Stats Panel (Top-Left)
	local wallet = Theme.Panel(screen, {
		Name = "WalletPanel",
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(260, 72),
		BackgroundColor3 = C.Panel,
	})

	make("TextLabel", wallet, {
		Name = "WalletHeader",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 16),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 12,
		TextColor3 = C.Muted,
		Text = "WALLET & PROGRESSION",
	})

	local statsLabel = make("TextLabel", wallet, {
		Name = "StatsLabel",
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -28, 0, 32),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		TextColor3 = C.Ink,
		Text = "CASH: $100  |  LVL 1",
	})

	local function refreshHUD()
		local cash = player:GetAttribute("Cash") or 100
		local scrap = player:GetAttribute("Scrap") or 0
		local level = player:GetAttribute("Level") or 1
		local carryingOre = player:GetAttribute("CarryingOre") or 0

		statsLabel.Text = ("CASH: $%d  |  SCRAP: %d\nLEVEL: %d  |  ORE: %d"):format(
			cash, scrap, level, carryingOre
		)
	end

	for _, attr in ipairs({ "Cash", "Scrap", "Level", "CarryingOre", "RefinedCount", "DataReady" }) do
		player:GetAttributeChangedSignal(attr):Connect(refreshHUD)
	end
	refreshHUD()
end

-- Initialize systems
initializeHUD()
InventoryUI.Init()
require(script.Parent:WaitForChild("BaseUI")).Init()

print("[MainClient]: HUD and Inventory UI systems initialized.")
