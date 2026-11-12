--!strict
-- Base progression and owner-only prompt visibility; all authorization remains server-side.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent.UITheme)
local UI = {}
local initialized = false
function UI.Init()
    if initialized then return end
    initialized = true
    local player = Players.LocalPlayer
    local screen = Instance.new("ScreenGui")
    screen.Name = "BaseUI"; screen.ResetOnSpawn = false; screen.DisplayOrder = 5
    screen.Parent = player:WaitForChild("PlayerGui")
    local launch = Theme.Button(screen, { Name = "BaseButton", Position = UDim2.fromOffset(18, 104),
        Size = UDim2.fromOffset(130, 38), Text = "BASE", BackgroundColor3 = Theme.Colors.Navy, TextColor3 = Theme.Colors.Cream })
    local panel = Theme.Panel(screen, { Name = "BasePanel", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.8), Visible = false,
        BackgroundColor3 = Theme.Colors.Panel })
    local limit = Instance.new("UISizeConstraint")
    limit.MaxSize = Vector2.new(500, 560); limit.Parent = panel
    local title = Theme.Make("TextLabel", panel, { Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -76, 0, 30),
        Text = "YOUR BASE", BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left }) :: TextLabel
    local close = Theme.Button(panel, { Position = UDim2.new(1, -52, 0, 14), Size = UDim2.fromOffset(34, 30), Text = "X" })
    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.fromOffset(18, 58); scroll.Size = UDim2.new(1, -36, 1, -140)
    scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = 5
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(); scroll.Parent = panel
    local details = Theme.Make("TextLabel", scroll, { Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Text = "Loading…", TextSize = 14, TextWrapped = true, BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }) :: TextLabel
    local upgrade = Theme.Button(panel, { Position = UDim2.new(0, 18, 1, -64), Size = UDim2.new(1, -36, 0, 46),
        Text = "Loading…", TextSize = 13, TextWrapped = true, BackgroundColor3 = Theme.Colors.Green, TextColor3 = Theme.Colors.Cream })
    local toast = Theme.Make("TextLabel", screen, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.94),
        Size = UDim2.new(0.85, 0, 0, 62), TextSize = 14, TextWrapped = true, Visible = false,
        BackgroundColor3 = Theme.Colors.Navy, TextColor3 = Theme.Colors.Cream }) :: TextLabel
    local busy = false
    local allowed = false
    local function refresh(action: string)
        if busy then return end
        busy = true
        local ok, result = pcall(function() return Remotes.BaseAction:InvokeServer(action) end)
        busy = false
        if ok and type(result) == "table" then
            title.Text = if result.Ready then ("BASE LEVEL %d"):format(result.Level) else "YOUR BASE"
            details.Text = result.Details; upgrade.Text = result.UpgradeText
            allowed = result.CanUpgrade == true
            upgrade.AutoButtonColor = allowed
            upgrade.BackgroundColor3 = if allowed then Theme.Colors.Green else Theme.Colors.Muted
        elseif not ok then
            allowed = false; details.Text = "Unable to load your base. Close and reopen to retry."
            upgrade.Text = "UNAVAILABLE"
        end
    end
    launch.Activated:Connect(function() panel.Visible = not panel.Visible; if panel.Visible then refresh("Get") end end)
    close.Activated:Connect(function() panel.Visible = false end)
    upgrade.Activated:Connect(function() if allowed then refresh("Upgrade") end end)
    local messageId = 0
    Remotes.BaseFeedback.OnClientEvent:Connect(function(success: boolean, message: string)
        messageId += 1
        local id = messageId
        toast.Text = message; toast.TextColor3 = if success then Theme.Colors.Cream else Theme.Colors.Gold
        toast.Visible = true
        task.delay(4, function() if messageId == id then toast.Visible = false end end)
    end)
    task.spawn(function()
        while screen.Parent do task.wait(2); if panel.Visible then refresh("Get") end end
    end)
    local function filter(instance: Instance)
        if not instance:IsA("ProximityPrompt") then return end
        local function apply()
            local owner = instance:GetAttribute("BaseOwnerUserId")
            if type(owner) == "number" and owner ~= player.UserId then instance.Enabled = false end
        end
        apply()
        instance:GetAttributeChangedSignal("BaseOwnerUserId"):Connect(apply)
        instance:GetPropertyChangedSignal("Enabled"):Connect(function() if instance.Enabled then apply() end end)
    end
    for _, instance in ipairs(workspace:GetDescendants()) do filter(instance) end
    workspace.DescendantAdded:Connect(filter)
end
return UI
