--!strict
-- InventoryUI (Layer 1: Presentation Layer)
-- Bag launcher, resource cards, and companion tab.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("UITheme"))
local Modal = require(script.Parent.ModalController)
local CompanionUI = require(script.Parent.Companion.CompanionUI)

local Remotes = require(ReplicatedStorage.Shared.Remotes)

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
local loaded = false
local loading = false
local loadFailed = false
local revision = 0
local retryButton: TextButton? = nil
local closePanel: () -> ()

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
	launcherButton.Text = if loaded then ("BAG (%d) [B]"):format(totalItems) else "BAG [B]"
end

local function renderItems()
	if not itemsList or not statusLabel or not emptyNotice then return end

	for _, child in ipairs(itemsList:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" and child ~= emptyNotice and child ~= retryButton then
			child:Destroy()
		end
	end

	local totalOres = 0
	local totalRefined = 0
	local totalCount = 0
	local hasAnyItem = false

	local ids = {}
	for itemId, count in pairs(currentInventory) do
		if count > 0 then table.insert(ids, itemId) end
	end
	table.sort(ids, function(a, b)
		local left, right = getItemMeta(a).DisplayName, getItemMeta(b).DisplayName
		return if left == right then a < b else left < right
	end)
	for order, itemId in ipairs(ids) do
		local count = currentInventory[itemId]
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
				Name = "ItemCard_" .. itemId, LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 100), BackgroundColor3 = C.Panel,
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
				Size = UDim2.new(1, -140, 0, 42), BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = meta.DisplayName,
				TextColor3 = C.Ink, TextSize = 14, TextWrapped = true,
			})

			make("TextLabel", card, {
				Name = "Description", Position = UDim2.fromOffset(10, 58),
				Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = meta.Description,
				TextColor3 = C.Muted, TextSize = 12,
				TextWrapped = true,
			})

			local pill = Theme.Panel(card, {
				Name = "Pill", AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0, 28), Size = UDim2.fromOffset(56, 32),
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
	emptyNotice.Text = if loading then "LOADING RESOURCES…"
		elseif loadFailed then "Could not load your resources.\n\nUse Retry below."
		elseif not loaded then "Waiting for player data…"
		else "YOUR BAG IS EMPTY\n\nWalk near ore nodes to gather resources, then near your Forge to smelt them!"
	if retryButton then retryButton.Visible = loadFailed and not loading end
	statusLabel.Text = if loaded then ("ORE %d  |  BARS %d  |  TOTAL %d"):format(totalOres, totalRefined, totalCount) else "Resources not loaded"
	updateLauncherBadge()
end

local function setOpen(open: boolean)
	if open then Modal.Open(closePanel) else Modal.Release(closePanel) end
	if screenGui then screenGui.DisplayOrder = if open then 10 else 5 end
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

closePanel = function() setOpen(false) end

local function loadInventory()
	if loading then return end
	if player:GetAttribute("DataReady") ~= true then renderItems(); return end
	loading = true
	loadFailed = false
	local startedRevision = revision
	renderItems()
	task.spawn(function()
		local success, initial = pcall(function() return Remotes.GetInventory:InvokeServer() end)
		loading = false
		-- A live update received during the request is newer than its snapshot.
		if revision == startedRevision then
			if success and type(initial) == "table" and player:GetAttribute("DataReady") == true then
				currentInventory = initial
				loaded = true
			else loadFailed = true end
		end
		renderItems()
	end)
end

-- INITIALIZATION

function InventoryUI.Init()
	if screenGui then return end

	local screen = Instance.new("ScreenGui")
	screenGui = screen
	screen.Name = "InventoryHUD"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui

	local launcher: TextButton = Theme.Button(screenGui, {
		Name = "InventoryLauncher", Position = UDim2.new(0, 18, 1, -74),
		Size = UDim2.fromOffset(150, 48), BackgroundColor3 = C.Navy,
		TextColor3 = C.Cream, Text = "🎒 BAG (0) [B]",
		TextSize = 16,
	})
	launcherButton = launcher

	launcher.Activated:Connect(function()
		setOpen(not isOpen)
	end)

	local shade: TextButton = make("TextButton", screenGui, {
		Name = "Backdrop", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Ink, BackgroundTransparency = 0.45,
		Text = "", AutoButtonColor = false,
		Visible = false, ZIndex = 2,
	})
	backdrop = shade

	shade.Activated:Connect(function()
		setOpen(false)
	end)

	local panel: Frame = Theme.Panel(screenGui, {
		Name = "InventoryModal", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.88, 0.76),
		BackgroundColor3 = C.Panel, Visible = false,
		ZIndex = 3,
	})
	inventoryPanel = panel

	make("UISizeConstraint", inventoryPanel, {
		MaxSize = Vector2.new(620, 560),
	})

	local titlePlate = Theme.Panel(inventoryPanel, {
		Name = "TitlePlate", Position = UDim2.fromOffset(16, -10),
		Size = UDim2.new(1, -76, 0, 48), BackgroundColor3 = C.Navy,
	})

	make("TextLabel", titlePlate, {
		Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 1, -8),
		BackgroundTransparency = 1, TextColor3 = C.Cream,
		TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "BACKPACK",
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
		Name = "StatusBar", Position = UDim2.fromOffset(16, 90),
		Size = UDim2.new(1, -32, 0, 36), BackgroundColor3 = C.Well,
	})

	statusLabel = make("TextLabel", statusBar, {
		Name = "StatusText", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Text = "Ores: 0  |  Refined: 0  |  Total Items: 0",
		TextColor3 = C.Ink, TextSize = 12, TextWrapped = true,
	})

	local scroll: ScrollingFrame = make("ScrollingFrame", inventoryPanel, {
		Name = "ItemsScroll", Position = UDim2.fromOffset(16, 134),
		Size = UDim2.new(1, -32, 1, -148), BackgroundColor3 = C.Well,
		BorderSizePixel = 0, ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Shade, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	})
	itemsList = scroll

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
	if not inventoryPanel then return end
	local companionTab = CompanionUI.Mount(inventoryPanel)
	retryButton = Theme.Button(itemsList, {
		Name = "RetryResources", Size = UDim2.new(1, -16, 0, 44), Text = "RETRY",
		BackgroundColor3 = C.Navy, TextColor3 = C.Cream, Visible = false,
	})
	assert(retryButton)
	retryButton.Activated:Connect(loadInventory)
	local resourcesTabButton = Theme.Button(inventoryPanel, {
		Name = "ResourcesTabButton", Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(0.5, -20, 0, 36), Text = "RESOURCES", TextSize = 12, TextWrapped = true,
		BackgroundColor3 = C.Navy, TextColor3 = C.Cream,
	})
	local companionsTabButton = Theme.Button(inventoryPanel, {
		Name = "CompanionsTabButton", Position = UDim2.new(0.5, 4, 0, 48),
		Size = UDim2.new(0.5, -20, 0, 36), Text = "COMPANIONS", TextSize = 12, TextWrapped = true,
		BackgroundColor3 = C.Navy, TextColor3 = C.Cream,
	})
	local function selectTab(companions: boolean)
		companionTab.Visible = companions
		statusBar.Visible = not companions
		if itemsList then itemsList.Visible = not companions end
		resourcesTabButton.BackgroundColor3 = if companions then C.Navy else C.Green
		companionsTabButton.BackgroundColor3 = if companions then C.Green else C.Navy
		resourcesTabButton.Text = if companions then "RESOURCES" else "[RESOURCES]"
		companionsTabButton.Text = if companions then "[COMPANIONS]" else "COMPANIONS"
	end
	resourcesTabButton.Activated:Connect(function() selectTab(false) end)
	companionsTabButton.Activated:Connect(function() selectTab(true) end)
	selectTab(false)

	-- Keyboard Shortcut (B or I)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.I then
			setOpen(not isOpen)
		end
	end)

	-- Real-time Replicated Events from Server
	Remotes.InventoryUpdated.OnClientEvent:Connect(function(newInventory: { [string]: number })
		revision += 1
		loaded = true
		loadFailed = false
		currentInventory = newInventory or {}
		renderItems()
	end)

	player:GetAttributeChangedSignal("DataReady"):Connect(function()
		if player:GetAttribute("DataReady") == true and not loaded then loadInventory() end
	end)
	loadInventory()
end

return InventoryUI
