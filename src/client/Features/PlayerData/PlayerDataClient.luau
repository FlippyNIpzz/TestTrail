--!strict
-- Persistence status shares the pixel-art economy theme.
local Players = game:GetService("Players")
local Theme = require(script.Parent.Parent.UI.UITheme)
local Feature = {}
local connection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local initialized = false
function Feature.Initialize(_context: any) initialized = true end
function Feature.Start()
    assert(initialized, "Initialize must run before Start")
    if gui then return end
    local player = Players.LocalPlayer
    local screen = Instance.new("ScreenGui")
    screen.Name = "FoundationDataStatus"
    screen.ResetOnSpawn = false
    screen.DisplayOrder = 100
    local label = Theme.Make("TextLabel", screen, {
        Name = "DataStatus", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
        Size = UDim2.new(0.92, 0, 0, 76), BackgroundColor3 = Theme.Colors.Navy,
        TextColor3 = Theme.Colors.Cream, TextWrapped = true, TextSize = 14,
    })
    Theme.Make("UISizeConstraint", label, { MaxSize = Vector2.new(680, 76) })
    Theme.Make("UIPadding", label, { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) })
    Theme.Edge(label, true)
    local function refresh()
        local state = player:GetAttribute("DataStatus")
        label.Visible = state ~= "Ready"
        if state == "SaveFailed" then label.Text = "Saving is temporarily unavailable. Recent progress may not be preserved. Retrying…"
        elseif state == "Unavailable" then label.Text = "Your data session is unavailable. Please rejoin."
        else label.Text = "Loading your progress…" end
    end
    connection = player:GetAttributeChangedSignal("DataStatus"):Connect(function()
        refresh()
        if player:GetAttribute("DataStatus") == "Ready" and label.Text:find("Saving is temporarily", 1, true) then
            label.Text = "Saving recovered. Your progress was saved."
            label.Visible = true
            task.delay(4, function() if gui == screen then refresh() end end)
        end
    end)
    refresh()
    screen.Parent = player:WaitForChild("PlayerGui")
    gui = screen
end
function Feature.Destroy()
    if connection then connection:Disconnect(); connection = nil end
    if gui then gui:Destroy(); gui = nil end
    initialized = false
end
return Feature
