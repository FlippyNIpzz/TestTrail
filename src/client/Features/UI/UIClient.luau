--!strict
-- Pixel-art economy HUD, inventory, live stats, and a read-only offer catalog.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Networking = require(Shared.Features.Networking.NetworkingHelpers)
local Config = require(Shared.Features.UI.UIConfig)
local QuantityRules = require(Shared.Features.Inventory.InventoryHelpers)
local Theme = require(script.Parent.UITheme)
local C = Theme.Colors
local Feature = {}
local initialized = false
local gui: ScreenGui? = nil
local connections: { RBXScriptConnection } = {}
local rows: { Instance } = {}
local rowConnections: { RBXScriptConnection } = {}
local generation = 0
local previousTouchControls: boolean? = nil
local function connect(signal: any, callback: any, row: boolean?)
    table.insert(if row then rowConnections else connections, signal:Connect(callback))
end
local make = Theme.Make
function Feature.Initialize(_context: any) initialized = true end
function Feature.Start()
    assert(initialized, "UI not initialized")
    if gui then return end
    generation += 1
    local current = generation
    local player = Players.LocalPlayer
    local getState = Networking.Get("UI.GetState") :: RemoteFunction
    local sell = Networking.Get("Inventory.Sell") :: RemoteFunction
    local activeTab = "Inventory"
    local screen = Instance.new("ScreenGui")
    screen.Name = "FoundationEconomy"; screen.ResetOnSpawn = false
    gui = screen
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    local wallet = Theme.Panel(screen, { Name = "Wallet", Position = UDim2.fromOffset(18, 18), Size = UDim2.new(0.6, 0, 0, 66), BackgroundColor3 = C.Panel })
    make("UISizeConstraint", wallet, { MaxSize = Vector2.new(340, 66) })
    make("TextLabel", wallet, { Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -28, 0, 16), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, TextColor3 = C.Muted, Text = "WALLET" })
    local balance = make("TextLabel", wallet, { Name = "Balance", Position = UDim2.fromOffset(14, 29), Size = UDim2.new(1, -28, 0, 26), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18, TextTruncate = Enum.TextTruncate.AtEnd, Text = "Loading..." })
    local toggle = Theme.Button(screen, { Name = "General", Position = UDim2.new(0, 18, 0.5, -26), Size = UDim2.fromOffset(148, 52), BackgroundColor3 = C.Navy, TextColor3 = C.Cream, Text = "GENERAL", TextSize = 18 })
    local shade = make("TextButton", screen, { Name = "MenuBackdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.4, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 2, Selectable = false })
    local panel = Theme.Panel(screen, { Name = "GeneralPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.84), BackgroundColor3 = C.Panel, Visible = false, ZIndex = 3 })
    make("UISizeConstraint", panel, { MaxSize = Vector2.new(740, 560) })
    local titlePlate = Theme.Panel(panel, { Name = "TitlePlate", Position = UDim2.fromOffset(16, -8), Size = UDim2.new(1, -80, 0, 48), BackgroundColor3 = C.Navy })
    local title = make("TextLabel", titlePlate, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), BackgroundTransparency = 1, TextColor3 = C.Cream, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Text = "INVENTORY" })
    local close = Theme.Button(panel, { Name = "Close", Position = UDim2.new(1, -54, 0, 10), Size = UDim2.fromOffset(40, 44), BackgroundColor3 = C.Shade, TextColor3 = C.Cream, Text = "X", TextSize = 18 })
    local tabs = make("Frame", panel, { Name = "GeneralTabs", Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 0, 44), BackgroundTransparency = 1 })
    local tabButtons: { [string]: TextButton } = {}
    for index, name in { "Inventory", "Stats", "Shop Offers" } do
        tabButtons[name] = Theme.Button(tabs, { Name = name, Position = UDim2.new((index - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, -6, 1, 0), Text = if name == "Shop Offers" then "OFFERS" else string.upper(name), TextSize = 16, BackgroundColor3 = C.Well })
    end
    local message = make("TextLabel", panel, { Name = "Feedback", Position = UDim2.fromOffset(18, 108), Size = UDim2.new(1, -36, 0, 44), BackgroundTransparency = 1, TextColor3 = C.Muted, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "Loading your inventory..." })
    local list = make("ScrollingFrame", panel, { Name = "Items", Position = UDim2.fromOffset(18, 160), Size = UDim2.new(1, -36, 1, -202), BackgroundColor3 = C.Well, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6, ScrollBarImageColor3 = C.Shade, BorderSizePixel = 0 })
    make("UIPadding", list, { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
    make("UIListLayout", list, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
    local capacity = make("TextLabel", panel, { Name = "Capacity", Position = UDim2.new(0, 18, 1, -34), Size = UDim2.new(1, -36, 0, 22), BackgroundTransparency = 1, TextColor3 = C.Muted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Text = "BAG  -- / --" })
    local function fitViewport()
        local short = workspace.CurrentCamera.ViewportSize.Y < 500
        panel.Size = if short then UDim2.fromScale(0.94, 0.96) else UDim2.fromScale(0.92, 0.84)
        tabs.Position = UDim2.fromOffset(16, if short then 48 else 56)
        tabs.Size = UDim2.new(1, -32, 0, 44)
        message.Position = UDim2.fromOffset(18, if short then 98 else 108)
        message.Size = UDim2.new(1, -36, 0, if short then 32 else 44)
        list.Position = UDim2.fromOffset(18, if short then 136 else 160)
        list.Size = UDim2.new(1, -36, 1, if short then -176 else -202)
    end
    fitViewport()
    connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fitViewport)
    local busy, refreshing = false, false
    local snapshot: any = nil
    local pending: any = nil
    local refresh: () -> ()
    local function clearRows()
        for _, connection in rowConnections do connection:Disconnect() end
        table.clear(rowConnections)
        for _, row in rows do row:Destroy() end
        table.clear(rows)
    end
    local lastSignature = ""
    local function render(force: boolean?)
        for name, button in tabButtons do
            button.BackgroundColor3 = if name == activeTab then C.Navy else C.Well
            button.TextColor3 = if name == activeTab then C.Cream else C.Ink
            button.Text = (if name == activeTab then "> " else "") .. (if name == "Shop Offers" then "OFFERS" else string.upper(name))
        end
        if not snapshot then return end
        local text = {}
        for _, currency in snapshot.Balances do table.insert(text, currency.Name .. ": " .. tostring(currency.Amount)) end
        balance.Text = table.concat(text, "  |  ")
        title.Text = string.upper(activeTab)
        capacity.Text = "BAG " .. snapshot.StackUnits .. "/" .. snapshot.MaxStackUnits .. "   UNIQUE " .. snapshot.UniqueCount .. "/" .. snapshot.MaxUniqueItems
        if not panel.Visible or busy then return end
        local keys = {}
        for _, item in snapshot.Stacks do table.insert(keys, item.Id .. ":" .. item.Quantity) end
        for _, item in snapshot.Unique do table.insert(keys, item.InstanceId) end
        for _, currency in snapshot.Balances do table.insert(keys, currency.Id .. ":" .. currency.Amount) end
        table.insert(keys, tostring(snapshot.UniqueCount))
        local signature = activeTab .. ":" .. table.concat(keys, "|")
        if not force and signature == lastSignature then return end
        local focused = game:GetService("UserInputService"):GetFocusedTextBox()
        if not force and focused and focused:IsDescendantOf(panel) then return end
        lastSignature = signature
        clearRows()
        local function info(text: string, order: number)
            table.insert(rows, make("TextLabel", list, { Size = UDim2.new(1, -12, 0, 88), BackgroundColor3 = C.Panel, TextColor3 = C.Ink, TextSize = 14, TextWrapped = true, LayoutOrder = order, Text = text }))
        end
        if activeTab == "Stats" then
            message.Text = "Your current balances and inventory capacity."
            for index, currency in snapshot.Balances do info(currency.Name .. ": " .. currency.Amount, index) end
            info("Stacked items: " .. snapshot.StackUnits .. " / " .. snapshot.MaxStackUnits, #snapshot.Balances + 1)
            info("Unique items: " .. snapshot.UniqueCount .. " / " .. snapshot.MaxUniqueItems, #snapshot.Balances + 2)
            return
        elseif activeTab == "Shop Offers" then
            message.Text = "Browse only — purchases are unavailable in this menu."
            if #Config.ShopOffers == 0 then
                info("No shop offers have been configured yet.", 1)
            else
                for index, offer in Config.ShopOffers do
                    if index > Config.MaxRows then break end
                    info(offer.ShopName .. " — " .. offer.Name .. "\n" .. offer.Description .. "\n" .. offer.PriceLabel, index)
                end
            end
            return
        end
        message.Text = "Choose an item and enter a whole-number quantity to sell."
        local shown = 0
        for _, item in snapshot.Stacks do
            shown += 1
            if shown > Config.MaxRows then break end
            local row = Theme.Panel(list, { Name = "InventoryRow", Size = UDim2.new(1, -12, 0, 134), BackgroundColor3 = C.Panel, LayoutOrder = shown })
            table.insert(rows, row)
            make("TextLabel", row, { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 26), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Ink, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd, Text = item.Name .. " x" .. item.Quantity })
            make("TextLabel", row, { Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 28), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted, TextSize = 12, TextWrapped = true, Text = if item.UnitPrice then item.UnitPrice .. " " .. item.CurrencyName .. " / each" else "Cannot sell this item" })
            if item.UnitPrice then
                local quantity = make("TextBox", row, { Name = "Quantity", Position = UDim2.fromOffset(12, 76), Size = UDim2.new(0.3, 0, 0, 44), BackgroundColor3 = C.Cream, Text = "1", ClearTextOnFocus = false, PlaceholderText = "Qty", TextSize = 16 })
                Theme.Edge(quantity)
                local button = Theme.Button(row, { Name = "Sell", Position = UDim2.new(0.34, 0, 0, 76), Size = UDim2.new(0.66, -12, 0, 44), BackgroundColor3 = C.Green, TextColor3 = C.Cream, Text = "SELL", TextSize = 16 })
                connect(button.Activated, function()
                    if busy or not snapshot or player:GetAttribute("DataReady") ~= true then return end
                    local amount = tonumber(quantity.Text)
                    if not QuantityRules.IsQuantity(amount) or amount > item.Quantity or amount > snapshot.MaxSellQuantity then
                        message.Text = "Enter a whole number from 1 to " .. math.min(item.Quantity, snapshot.MaxSellQuantity) .. "."; return
                    end
                    -- Preserve the same payload after a transport failure; retry cannot sell twice.
                    if pending and (pending.item ~= item.Id or pending.quantity ~= amount) then
                        message.Text = "Retry the previous item and quantity first to resolve its sale."; return
                    end
                    pending = pending or { item = item.Id, quantity = amount, id = snapshot.NextSellRequestId }
                    busy = true; button.Text = "SELLING..."
                    local transported, accepted, reason = pcall(function() return sell:InvokeServer(pending.item, pending.quantity, pending.id) end)
                    if gui ~= screen or current ~= generation then return end
                    busy = false
                    if not transported then message.Text = "Connection interrupted. Retry the same item and quantity."; button.Text = "RETRY"; return end
                    if reason ~= "TooManyRequests" then pending = nil end
                    button.Text = "SELL"
                    message.Text = if accepted then "Sale complete." else "Sale failed: " .. tostring(reason)
                    refresh()
                end, true)
            end
        end
        for _, item in snapshot.Unique do
            shown += 1
            if shown > Config.MaxRows then break end
            local row = make("TextLabel", list, { Size = UDim2.new(1, -12, 0, 70), BackgroundColor3 = C.Panel, TextColor3 = C.Ink, TextSize = 16, LayoutOrder = shown, TextWrapped = true, Text = item.Name .. " (unique item; cannot sell)" })
            table.insert(rows, row)
        end
        if shown == 0 then
            table.insert(rows, make("TextLabel", list, { Size = UDim2.new(1, -12, 0, 160), BackgroundTransparency = 1, TextColor3 = C.Ink, TextSize = 16, TextWrapped = true, Text = "YOUR BAG IS EMPTY\n\nCollect resources to get started." }))
        elseif shown > Config.MaxRows then message.Text = "Showing the first " .. Config.MaxRows .. " entries." end
    end
    refresh = function()
        if refreshing or busy or pending or player:GetAttribute("DataReady") ~= true then return end
        refreshing = true
        local transported, accepted, result = pcall(function() return getState:InvokeServer() end)
        refreshing = false
        if gui ~= screen or current ~= generation then return end
        if transported and accepted then
            if message.Text == "Could not refresh inventory. Retrying shortly." then
                message.Text = if activeTab == "Inventory" then "Choose an item and enter a whole-number quantity to sell." elseif activeTab == "Stats" then "Your current balances and inventory capacity." else "Browse only — purchases are unavailable in this menu."
            end
            snapshot = result; render()
        elseif panel.Visible then message.Text = "Could not refresh inventory. Retrying shortly." end
    end
    for name, button in tabButtons do
        connect(button.Activated, function()
            if busy then return end
            activeTab = name
            list.CanvasPosition = Vector2.zero
            render(true)
        end)
    end
    local function setOpen(open: boolean)
        panel.Visible = open
        shade.Visible = open
        if open then
            if previousTouchControls == nil then previousTouchControls = GuiService.TouchControlsEnabled end
            GuiService.TouchControlsEnabled = false
            render(true); task.spawn(refresh)
            if game:GetService("UserInputService"):GetLastInputType() == Enum.UserInputType.Gamepad1 then GuiService.SelectedObject = tabButtons[activeTab] end
        else
            if previousTouchControls ~= nil then GuiService.TouchControlsEnabled = previousTouchControls; previousTouchControls = nil end
            if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then GuiService.SelectedObject = toggle end
            clearRows()
        end
    end
    connect(toggle.Activated, function() setOpen(not panel.Visible) end)
    connect(close.Activated, function() setOpen(false) end)
    connect(shade.Activated, function() setOpen(false) end)
    connect(game:GetService("UserInputService").InputBegan, function(input: InputObject, processed: boolean)
        if processed or game:GetService("UserInputService"):GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.ButtonB and panel.Visible then setOpen(false) end
    end)
    connect(player:GetAttributeChangedSignal("DataReady"), function()
        if player:GetAttribute("DataReady") ~= true then setOpen(false); balance.Text = "Progress unavailable"; snapshot = nil; clearRows() end
    end)
    screen.Parent = player:WaitForChild("PlayerGui")
    task.spawn(function()
        while gui == screen and current == generation do refresh(); task.wait(Config.EconomyRefreshSeconds) end
    end)
end
function Feature.Destroy()
    if previousTouchControls ~= nil then GuiService.TouchControlsEnabled = previousTouchControls; previousTouchControls = nil end
    generation += 1
    for _, connection in connections do connection:Disconnect() end
    for _, connection in rowConnections do connection:Disconnect() end
    table.clear(connections); table.clear(rowConnections); table.clear(rows)
    if gui then gui:Destroy(); gui = nil end
    initialized = false
end
return Feature
