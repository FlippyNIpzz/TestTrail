--!strict
-- Only the server's authorized projection can reveal the launcher/catalog.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local Input = game:GetService("UserInputService")
local Networking = require(game:GetService("ReplicatedStorage").Shared.Features.Networking.NetworkingHelpers)
local Theme = require(script.Parent.Parent.UI.UITheme)
local C = Theme.Colors
local Feature = {}
local initialized = false
local gui: ScreenGui? = nil
local connections: { RBXScriptConnection } = {}
local rowConnections: { RBXScriptConnection } = {}
local rows: { Instance } = {}
local previousTouch: boolean? = nil
local generation = 0
local function connect(signal: any, callback: any, row: boolean?)
    table.insert(if row then rowConnections else connections, signal:Connect(callback))
end
local function clearRows()
    for _, connection in rowConnections do connection:Disconnect() end
    table.clear(rowConnections)
    for _, row in rows do row:Destroy() end
    table.clear(rows)
end
function Feature.Initialize(_context: any) initialized = true end
function Feature.Start()
    assert(initialized, "Admin not initialized")
    if gui then return end
    generation += 1
    local current = generation
    local messages = {
        Forbidden = "You do not have admin permission.", NotReady = "Wait for your data session to be ready.",
        RateLimited = "Please wait a moment and try again.", StaleState = "The server changed. Review the updated state and try again.",
        AlreadySet = "That state is already active.", Unsupported = "This system is unavailable in this server.",
        UnapprovedModel = "That model is not on the approved list.", TargetUnavailable = "That base has no active owner or is unavailable.",
        OccupiedBuildings = "This base has buildings. Swapping its structure is blocked to preserve their placement.",
        ModelPreparationFailed = "The replacement could not be validated. The current model was kept.",
        ConfirmationExpired = "Confirmation expired. Review the action again.", InvalidConfirmation = "Confirmation is no longer valid. Review the action again.",
    }
    local function explain(code: any): string return messages[code] or tostring(code) end
    local player = Players.LocalPlayer
    local stateRemote = Networking.Get("Admin.GetState") :: RemoteFunction
    local prepareRemote = Networking.Get("Admin.Prepare") :: RemoteFunction
    local commitRemote = Networking.Get("Admin.Commit") :: RemoteFunction
    local screen = Instance.new("ScreenGui")
    screen.Name = "FoundationAdmin"; screen.ResetOnSpawn = false; screen.DisplayOrder = 50
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui = screen
    local make = Theme.Make
    local launcher = Theme.Button(screen, { Name = "AdminToggle", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 100), Size = UDim2.fromOffset(124, 44), BackgroundColor3 = C.Navy, TextColor3 = C.Cream, Text = "ADMIN", Visible = false })
    local shade = make("TextButton", screen, { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.35, Text = "", Visible = false, ZIndex = 2, Selectable = false })
    local panel = Theme.Panel(screen, { Name = "Panel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.9), BackgroundColor3 = C.Panel, Visible = false, ZIndex = 3 })
    make("UISizeConstraint", panel, { MaxSize = Vector2.new(780, 620) })
    make("TextLabel", panel, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -80, 0, 28), BackgroundTransparency = 1, Text = "ADMIN / THIS SERVER", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
    local close = Theme.Button(panel, { Name = "Close", Position = UDim2.new(1, -54, 0, 10), Size = UDim2.fromOffset(40, 44), BackgroundColor3 = C.Shade, TextColor3 = C.Cream, Text = "X" })
    local feedback = make("TextLabel", panel, { Name = "Feedback", Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 48), BackgroundTransparency = 1, TextColor3 = C.Muted, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "Session-only changes. Select an action to review it." })
    local list = make("ScrollingFrame", panel, { Name = "Controls", Position = UDim2.fromOffset(16, 112), Size = UDim2.new(1, -32, 1, -130), BackgroundColor3 = C.Well, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6, ScrollBarImageColor3 = C.Shade })
    make("UIPadding", list, { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
    make("UIListLayout", list, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
    local dialogShade = make("Frame", panel, { Name = "ConfirmationShade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, Visible = false, ZIndex = 10, Active = true })
    local dialog = Theme.Panel(dialogShade, { Name = "Confirmation", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.94, 0.94), BackgroundColor3 = C.Panel })
    make("UISizeConstraint", dialog, { MaxSize = Vector2.new(680, 350) })
    make("TextLabel", dialog, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 26), BackgroundTransparency = 1, Text = "CONFIRM CHANGE", TextSize = 18 })
    local summaryScroll = make("ScrollingFrame", dialog, { Name = "SummaryScroll", Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 1, -112), BackgroundTransparency = 1, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 4, BorderSizePixel = 0 })
    local summary = make("TextLabel", summaryScroll, { Name = "Summary", Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, TextWrapped = true, TextSize = 14, Text = "" })
    local confirm = Theme.Button(dialog, { Name = "Confirm", Position = UDim2.new(0.5, 6, 1, -56), Size = UDim2.new(0.5, -22, 0, 44), BackgroundColor3 = C.Green, TextColor3 = C.Cream, Text = "CONFIRM" })
    local cancel = Theme.Button(dialog, { Name = "Cancel", Position = UDim2.new(0, 16, 1, -56), Size = UDim2.new(0.5, -22, 0, 44), BackgroundColor3 = C.Navy, TextColor3 = C.Cream, Text = "CANCEL" })
    local function fitViewport()
        local compact = workspace.CurrentCamera.ViewportSize.Y < 500
        feedback.Position = UDim2.fromOffset(16, if compact then 42 else 58)
        feedback.Size = UDim2.new(1, if compact then -88 else -32, 0, if compact then 32 else 48)
        list.Position = UDim2.fromOffset(16, if compact then 82 else 112)
        list.Size = UDim2.new(1, -32, 1, if compact then -100 else -130)
    end
    fitViewport()
    connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fitViewport)
    local snapshot: any = nil
    local pending: any = nil
    local busy, fetching, uncertain = false, false, false
    local targetIndex = 1
    local renderedRevision = -1
    local render: () -> ()
    local refresh: () -> ()
    local function alive(): boolean return gui == screen and current == generation end
    local function open(value: boolean)
        panel.Visible = value; shade.Visible = value
        if value then
            if previousTouch == nil then previousTouch = GuiService.TouchControlsEnabled end
            GuiService.TouchControlsEnabled = false
            render()
            if Input:GetLastInputType() == Enum.UserInputType.Gamepad1 then GuiService.SelectedObject = close end
        else
            if previousTouch ~= nil then GuiService.TouchControlsEnabled = previousTouch; previousTouch = nil end
            if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then GuiService.SelectedObject = launcher end
        end
    end
    local function request(kind: string, id: string, value: any)
        if busy or pending or not snapshot then return end
        busy = true
        local transported, accepted, result = pcall(function() return prepareRemote:InvokeServer(kind, id, value, snapshot.Revision) end)
        if not alive() then return end
        busy = false
        if not transported then feedback.Text = "Connection interrupted. Review the action again."; return end
        if not accepted then feedback.Text = "Not applied: " .. explain(result); task.spawn(refresh); return end
        pending = result; uncertain = false; summary.Text = result.Description; summaryScroll.CanvasPosition = Vector2.zero
        confirm.Text = "CONFIRM"; cancel.Text = "CANCEL"; dialogShade.Visible = true
        GuiService.SelectedObject = cancel
    end
    local function label(parent: Instance, text: string, y: number, height: number, size: number?)
        return make("TextLabel", parent, { Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -24, 0, height), BackgroundTransparency = 1, TextWrapped = true, Text = text, TextSize = size or 14, TextXAlignment = Enum.TextXAlignment.Left })
    end
    render = function()
        if not snapshot or not panel.Visible or busy or pending then return end
        if renderedRevision == snapshot.Revision then return end
        renderedRevision = snapshot.Revision
        clearRows()
        local order = 0
        local function row(height: number, name: string): Frame
            order += 1
            local frame = Theme.Panel(list, { Name = name:gsub("[^%w_]", "_"), Size = UDim2.new(1, -12, 0, height), LayoutOrder = order, BackgroundColor3 = C.Panel })
            table.insert(rows, frame)
            return frame
        end
        label(row(42, "FeatureHeading"), "FEATURE CONTROLS", 6, 28, 16)
        for _, entry in snapshot.Features do
            local frame = row(110, entry.Id)
            label(frame, entry.Name, 8, 28, 16)
            label(frame, if not entry.Supported then "Unavailable in this server" elseif entry.Enabled then "Current state: ENABLED" else "Current state: DISABLED", 38, 22, 12)
            local button = Theme.Button(frame, { Name = "Toggle", Position = UDim2.new(0, 12, 1, -50), Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = if entry.Enabled then C.Shade else C.Green, TextColor3 = C.Cream, Text = if not entry.Supported then "UNAVAILABLE" elseif entry.Enabled then "DISABLE" else "ENABLE" })
            connect(button.Activated, function() if entry.Supported then request("Toggle", entry.Id, not entry.Enabled) end end, true)
        end
        label(row(42, "ModelHeading"), "MODEL CONTROLS", 6, 28, 16)
        if #snapshot.Models == 0 then label(row(70, "NoTargets"), "No model targets configured.", 10, 48); return end
        targetIndex = math.clamp(targetIndex, 1, #snapshot.Models)
        local target = snapshot.Models[targetIndex]
        local frame = row(152, "TargetSelector")
        label(frame, target.Name .. " (" .. targetIndex .. "/" .. #snapshot.Models .. ")", 8, 28, 16)
        label(frame, "Current: " .. target.Current .. (if target.Available then " | saved level " .. target.Level else " | no active owner"), 40, 52, 12)
        for _, direction in { -1, 1 } do
            local button = Theme.Button(frame, { Name = if direction == -1 then "PreviousTarget" else "NextTarget", Position = UDim2.new(if direction == -1 then 0 else 0.5, if direction == -1 then 12 else 4, 1, -54), Size = UDim2.new(0.5, -16, 0, 44), BackgroundColor3 = C.Navy, TextColor3 = C.Cream, Text = if direction == -1 then "< TARGET" else "TARGET >" })
            connect(button.Activated, function()
                if busy or pending then return end
                targetIndex = ((targetIndex - 1 + direction) % #snapshot.Models) + 1
                renderedRevision = -1; render()
            end, true)
        end
        for _, option in target.Options do
            local optionRow = row(76, option.Id)
            local button = Theme.Button(optionRow, { Name = "Replace", Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 50), BackgroundColor3 = if option.Id == target.Current then C.Navy else C.Green, TextColor3 = C.Cream, Text = option.Name .. (if option.Id == target.Current then " / ACTIVE" else " / APPLY"), TextSize = 14 })
            connect(button.Activated, function() if target.Available then request("Model", target.Id, option.Id) else feedback.Text = "Target unavailable: select an occupied base." end end, true)
        end
    end
    refresh = function()
        if fetching then return end
        fetching = true
        local transported, accepted, result = pcall(function() return stateRemote:InvokeServer() end)
        fetching = false
        if not alive() then return end
        if transported and accepted then
            snapshot = result; launcher.Visible = true; render()
        elseif transported and result == "Forbidden" then
            launcher.Visible = false; open(false); snapshot = nil; pending = nil; dialogShade.Visible = false; clearRows(); renderedRevision = -1
        elseif panel.Visible and result ~= "RateLimited" then feedback.Text = "State unavailable. Retrying shortly; no changes assumed." end
    end
    connect(launcher.Activated, function() open(not panel.Visible); if panel.Visible then task.spawn(refresh) end end)
    connect(close.Activated, function() open(false) end)
    connect(shade.Activated, function() open(false) end)
    connect(cancel.Activated, function()
        if busy or uncertain then return end
        pending = nil; dialogShade.Visible = false; render()
    end)
    connect(confirm.Activated, function()
        if busy or not pending then return end
        busy = true; confirm.Text = "WAIT..."
        local transported, accepted, result = pcall(function() return commitRemote:InvokeServer(pending.Token, pending.RequestId) end)
        if not alive() then return end
        busy = false
        if not transported or result == "RateLimited" then
            uncertain = true; confirm.Text = "RETRY"; cancel.Text = "PENDING"
            summary.Text = "Response unavailable. Retry this same action to resolve its result safely."
            return
        end
        pending = nil; uncertain = false; dialogShade.Visible = false; confirm.Text = "CONFIRM"
        feedback.Text = if accepted then "Success: change applied to this server." else "Not applied: " .. explain(result)
        renderedRevision = -1; task.spawn(refresh)
    end)
    connect(Input.InputBegan, function(input: InputObject, processed: boolean)
        if processed or Input:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.ButtonB and panel.Visible then
            if dialogShade.Visible and not busy and not uncertain then pending = nil; dialogShade.Visible = false; render() else open(false) end
        end
    end)
    screen.Parent = player:WaitForChild("PlayerGui")
    task.spawn(function()
        while alive() do refresh(); task.wait(if snapshot then 2 else 10) end
    end)
end
function Feature.Destroy()
    generation += 1
    if previousTouch ~= nil then GuiService.TouchControlsEnabled = previousTouch; previousTouch = nil end
    clearRows()
    for _, connection in connections do connection:Disconnect() end
    table.clear(connections)
    if gui then gui:Destroy(); gui = nil end
    initialized = false
end
return Feature
