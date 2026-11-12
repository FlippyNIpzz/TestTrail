--!strict
-- InventoryUI (Layer 1: Presentation Layer)
-- Bag launcher, resource cards, and companion tab.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("UITheme"))
local CompanionUI = require(script.Parent.Companion.CompanionUI)

local function getRemotesModule(): ModuleScript
	local shared = ReplicatedStorage:WaitForChild("Shared", 10)
	local remotesItem = shared and (shared:FindFirstChild("Remotes") or shared:WaitForChild("Remotes", 5))
	if remotesItem then
		if remotesItem:IsA("ModuleScript") then
			return remotesItem
		elseif remotesItem:IsA("Folder") then
			local child = remotesItem:FindFirstChild("Remotes") or remotesItem:WaitForChild("Remotes", 3)
			if child and child:IsA("ModuleScript") then
				return child
			end
		end
		return remotesItem :: any
	end
	error("[InventoryUI]: Could not locate Remotes module under ReplicatedStorage.Shared")
end

local Remotes = require(getRemotesModule())

local C = Theme.Colors
local make = Theme.Make

local InventoryUI = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui: ScreenGui? = nil
local launcherButton: TextButton? = nil
local inventoryPanel: Frame? = nil
local backdrop: TextButton? = nil
local itemsList: ScrollingFrame? = nil
local statusLabel: TextLabel? = nil
local emptyNotice: TextLabel? = nil

local currentInventory: { [string]: number } = {}
local isOpen = false

-- ITEM DEFINITION METADATA

type ItemMeta = {
	DisplayName: string,
	Category: "Ore" | "Bar" | "Item",
	BadgeText: string,
	BadgeColor: Color3,
	Description: string,
}

local ITEM_METADATA: { [string]: ItemMeta } = {
	IronOre = {
		DisplayName = "Iron Ore", Category = "Ore",
		BadgeText = "ORE", BadgeColor = C.Bronze,
		Description = "Raw smelting ore. Walk near Forge to deposit.",
	},
	RefinedIronOre = {
		DisplayName = "Refined Iron Bar", Category = "Bar",
		BadgeText = "BAR", BadgeColor = C.Silver,
		Description = "Refined metal bar. Ready for building & upgrades.",
	},
	Scrap = {
		DisplayName = "Scrap Metal", Category = "Ore",
		BadgeText = "SCRAP", BadgeColor = C.Navy,
		Description = "Salvaged mechanical pieces.",
	},
}

local function getItemMeta(itemId: string): ItemMeta
	if ITEM_METADATA[itemId] then
		return ITEM_METADATA[itemId]
	end

	local isRefined = string.find(itemId, "Refined") ~= nil
	local isOre = string.find(itemId, "Ore") ~= nil

	return {
		DisplayName = itemId,
		Category = if isRefined then "Bar" elseif isOre then "Ore" else "Item",
		BadgeText = if isRefined then "BAR" elseif isOre then "ORE" else "ITEM",
		BadgeColor = if isRefined then C.Silver elseif isOre then C.Bronze else C.Navy,
		Description = if isOre then "Raw mineral ore." else "Resource item.",
	}
end

-- RENDERING & REFRESH

local function updateLauncherBadge()
	if not launcherButton then return end
	local totalItems = 0
	for _, count in pairs(currentInventory) do
		totalItems += count
	end
	launcherButton.Text = ("🎒 BAG (%d) [B]"):format(totalItems)
end

local function renderItems()
	if not itemsList or not statusLabel or not emptyNotice then return end

	for _, child in ipairs(itemsList:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" and child ~= emptyNotice then
			child:Destroy()
		end
	end

	local totalOres = 0
	local totalRefined = 0
	local totalCount = 0
	local hasAnyItem = false

	for itemId, count in pairs(currentInventory) do
		if count > 0 then
			hasAnyItem = true
			totalCount += count
			local meta = getItemMeta(itemId)

			if meta.Category == "Ore" then
				totalOres += count
			elseif meta.Category == "Bar" then
				totalRefined += count
			end

			local card = Theme.Panel(itemsList, {
				Name = "ItemCard_" .. itemId,
				Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = C.Panel,
			})

			local badge = Theme.Panel(card, {
				Name = "Badge", Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(48, 38),
				BackgroundColor3 = meta.BadgeColor,
			})
			make("TextLabel", badge, {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Text = meta.BadgeText,
				TextColor3 = C.Cream, TextSize = 14,
			})

			make("TextLabel", card, {
				Name = "Title", Position = UDim2.fromOffset(66, 8),
				Size = UDim2.new(1, -140, 0, 20), BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = meta.DisplayName,
				TextColor3 = C.Ink, TextSize = 17,
			})

			make("TextLabel", card, {
				Name = "Description", Position = UDim2.fromOffset(66, 30),
				Size = UDim2.new(1, -140, 0, 16), BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = meta.Description,
				TextColor3 = C.Muted, TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})

			local pill = Theme.Panel(card, {
				Name = "Pill", AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(56, 32),
				BackgroundColor3 = C.Navy,
			})
			make("TextLabel", pill, {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Text = "x" .. tostring(count),
				TextColor3 = C.Cream, TextSize = 16,
			})
		end
	end

	emptyNotice.Visible = not hasAnyItem
	statusLabel.Text = ("Ores: %d  |  Refined: %d  |  Total Items: %d"):format(totalOres, totalRefined, totalCount)
	updateLauncherBadge()
end

local function setOpen(open: boolean)
	isOpen = open
	if inventoryPanel then
		inventoryPanel.Visible = open
	end
	if backdrop then
		backdrop.Visible = open
	end
	if open then
		renderItems()
	end
end

-- INITIALIZATION

function InventoryUI.Init()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InventoryHUD"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	launcherButton = Theme.Button(screenGui, {
		Name = "InventoryLauncher", Position = UDim2.new(0, 18, 1, -74),
		Size = UDim2.fromOffset(150, 48), BackgroundColor3 = C.Navy,
		TextColor3 = C.Cream, Text = "🎒 BAG (0) [B]",
		TextSize = 16,
	})

	launcherButton.Activated:Connect(function()
		setOpen(not isOpen)
	end)

	backdrop = make("TextButton", screenGui, {
		Name = "Backdrop", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink, BackgroundTransparency = 0.45,
		Text = "", AutoButtonColor = false,
		Visible = false, ZIndex = 2,
	})

	backdrop.Activated:Connect(function()
		setOpen(false)
	end)

	inventoryPanel = Theme.Panel(screenGui, {
		Name = "InventoryModal", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.88, 0.76),
		BackgroundColor3 = C.Panel, Visible = false,
		ZIndex = 3,
	})

	make("UISizeConstraint", inventoryPanel, {
		MaxSize = Vector2.new(620, 520), MinSize = Vector2.new(320, 360),
	})

	local titlePlate = Theme.Panel(inventoryPanel, {
		Name = "TitlePlate", Position = UDim2.fromOffset(16, -10),
		Size = UDim2.new(1, -76, 0, 48), BackgroundColor3 = C.Navy,
	})

	make("TextLabel", titlePlate, {
		Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 1, -8),
		BackgroundTransparency = 1, TextColor3 = C.Cream,
		TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🎒 BACKPACK INVENTORY",
	})

	local closeBtn = Theme.Button(inventoryPanel, {
		Name = "CloseButton", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, -10), Size = UDim2.fromOffset(44, 48),
		BackgroundColor3 = C.Shade, TextColor3 = C.Cream,
		Text = "X", TextSize = 20,
	})

	closeBtn.Activated:Connect(function()
		setOpen(false)
	end)

	local statusBar = Theme.Panel(inventoryPanel, {
		Name = "StatusBar", Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(1, -32, 0, 36), BackgroundColor3 = C.Well,
	})

	statusLabel = make("TextLabel", statusBar, {
		Name = "StatusText", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Text = "Ores: 0  |  Refined: 0  |  Total Items: 0",
		TextColor3 = C.Ink, TextSize = 14,
	})

	itemsList = make("ScrollingFrame", inventoryPanel, {
		Name = "ItemsScroll", Position = UDim2.fromOffset(16, 94),
		Size = UDim2.new(1, -32, 1, -108), BackgroundColor3 = C.Well,
		BorderSizePixel = 0, ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Shade, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})
	Theme.Edge(itemsList)

	make("UIListLayout", itemsList, {
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	})

	make("UIPadding", itemsList, {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
	})

	emptyNotice = make("TextLabel", itemsList, {
		Name = "EmptyNotice", Size = UDim2.new(1, -16, 0, 160),
		BackgroundTransparency = 1, TextColor3 = C.Muted,
		TextSize = 16, TextWrapped = true,
		Text = "YOUR BAG IS EMPTY\n\nWalk near ore nodes to gather resources,\nthen walk near your Forge to smelt them!",
		Visible = true,
	})

	-- Both categories share the existing Bag styling and launcher.
	local companionTab = CompanionUI.Mount(inventoryPanel)
	statusBar.Visible = false
	local resourcesTabButton = Theme.Button(inventoryPanel, {
		Name = "ResourcesTabButton", Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(0.5, -20, 0, 36), Text = "RESOURCES", TextSize = 14,
		BackgroundColor3 = C.Navy, TextColor3 = C.Cream,
	})
	local companionsTabButton = Theme.Button(inventoryPanel, {
		Name = "CompanionsTabButton", Position = UDim2.new(0.5, 4, 0, 48),
		Size = UDim2.new(0.5, -20, 0, 36), Text = "COMPANIONS", TextSize = 14,
		BackgroundColor3 = C.Navy, TextColor3 = C.Cream,
	})
	resourcesTabButton.Activated:Connect(function()
		companionTab.Visible = false
		if itemsList then itemsList.Visible = true end
	end)
	companionsTabButton.Activated:Connect(function()
		companionTab.Visible = true
		if itemsList then itemsList.Visible = false end
	end)

	-- Keyboard Shortcut (B or I)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.I then
			setOpen(not isOpen)
		elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
			setOpen(false)
		end
	end)

	-- Real-time Replicated Events from Server
	Remotes.InventoryUpdated.OnClientEvent:Connect(function(newInventory: { [string]: number })
		currentInventory = newInventory or {}
		renderItems()
	end)

	-- Initial Data Sync
	task.spawn(function()
		local success, initial = pcall(function()
			return Remotes.GetInventory:InvokeServer()
		end)
		if success and type(initial) == "table" then
			currentInventory = initial
			renderItems()
		end
	end)
end

return InventoryUI
