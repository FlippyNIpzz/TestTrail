--!strict
-- Companion tab embedded in the existing Bag. All mutations are server validated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Parent.UITheme)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local UI = {}
local C = Theme.Colors
local make = Theme.Make
local state: any = { Ready = false, Owned = {} }
local selected: string? = nil
local donor: string? = nil
local fusing = false
local busy = false
local message = "Loading companions…"
local list: ScrollingFrame
local confirmation: any = nil
local updateDetails: (() -> ())? = nil
local render: () -> ()

local function find(id: string?): any
	for _, companion in ipairs(state.Owned) do if companion.Id == id then return companion end end
	return nil
end
local function label(parent: Instance, text: string, height: number)
	return make("TextLabel", parent, {
		Size = UDim2.new(1, -12, 0, height), BackgroundTransparency = 1,
		Text = text, TextWrapped = true, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
	})
end
local function button(parent: Instance, text: string, callback: () -> (), color: Color3?)
	local b = Theme.Button(parent, {
		Size = UDim2.new(1, -12, 0, 40), Text = text, TextSize = 14, TextWrapped = true,
		BackgroundColor3 = color or C.Navy, TextColor3 = C.Cream,
		Active = not busy, AutoButtonColor = not busy,
	})
	b.Activated:Connect(function() if not busy then callback() end end)
	return b
end
local function request(action: string, id: string?, secondId: string?)
	if busy then return end
	busy = true
	message = "Updating…"
	render()
	task.spawn(function()
		local ok, result = pcall(function() return Remotes.CompanionAction:InvokeServer(action, id, secondId) end)
		busy = false
		if ok and type(result) == "table" then
			state = result.State
			message = result.Message
			if result.Ok then confirmation = nil; donor = nil; fusing = false end
		else message = "Could not update inventory. Try again." end
		render()
	end)
end
local function statText(companion: any): string
	return ("Health %d  |  Charge %d  |  Damage %d  |  Speed %d"):format(
		companion.Stats.Health, companion.Stats.Charge, companion.Stats.Damage, companion.Stats.Speed)
end
render = function()
	if not list then return end
	updateDetails = nil
	for _, child in list:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	label(list, message, 38)
	if not state.Ready then
		button(list, "Retry loading", function() request("Get") end)
		return
	end
	if confirmation then
		label(list, confirmation.Text, 100)
		button(list, "Confirm", function() request(confirmation.Action, confirmation.Id) end, C.Shade)
		button(list, "Cancel", function() confirmation = nil; render() end)
		return
	end
	local current = find(selected)
	if current then
		label(list, current.TemplateId .. "  •  " .. current.Rarity .. "  •  " .. current.Element, 36)
		local progressLabel = label(list, "", 66)
		local valuesLabel = label(list, "", 60)
		local refreshDetails = function()
			local latest = find(selected)
			if not latest then return end
			progressLabel.Text = ("Level %d  |  XP %.1f / %d\nStat points: %s"):format(latest.Level, latest.XP, state.XPPerLevel, statText(latest))
			valuesLabel.Text = ("Health %.1f / %.1f   |   Stamina %.1f / %.1f\nDamage %.1f   |   Movement speed %.1f"):format(
				latest.Health, latest.Values.Health, latest.Charge, latest.Values.Charge, latest.Values.Damage, latest.Values.Speed)
		end
		updateDetails = refreshDetails
		refreshDetails()
		local isEquipped = state.EquippedId == current.Id
		if fusing and isEquipped then
			label(list, "KEEP: " .. current.TemplateId .. "\nChoose a same-rarity companion below to consume.", 52)
			local second = find(donor)
			if second and second.Id ~= current.Id and second.Rarity == current.Rarity then
				local preview = { Stats = {} }
				for name, value in pairs(current.Stats) do preview.Stats[name] = math.max(value, second.Stats[name]) end
				label(list, "CONSUME: " .. second.TemplateId .. " (" .. string.sub(second.Id, 1, 6) .. ")\nResult: " .. statText(preview)
					.. "\nLevel " .. math.max(current.Level, second.Level) .. " | XP 0\nThe second companion is permanently consumed.", 112)
				button(list, "Confirm fusion — consume second", function() request("Fuse", current.Id, second.Id) end, C.Shade)
			end
			button(list, "Cancel fusion", function() fusing = false; donor = nil; render() end)
		else
			button(list, if isEquipped then "Unequip" else "Equip", function()
				if isEquipped or state.EquippedId then
					confirmation = {
						Text = "Storing your equipped companion resets its overall level and XP to 0. Its stat points are preserved. Continue?",
						Action = if isEquipped then "Unequip" else "Equip", Id = current.Id,
					}
					render()
				else request("Equip", current.Id) end
			end)
			if isEquipped then
				for _, mode in { "Home", "Follow", "Fight" } do
					button(list, (if current.Mode == mode then "✓ " else "") .. mode, function() request("Mode", mode) end)
				end
				button(list, "Fuse with another " .. current.Rarity, function() fusing = true; donor = nil; render() end, C.Green)
			else label(list, "Equip this companion to keep it in a fusion.", 34) end
		end
	end
	label(list, if fusing then "SAME-RARITY FUSION PARTNERS" else "YOUR COMPANIONS (" .. #state.Owned .. ")", 34)
	local count = 0
	for _, companion in ipairs(state.Owned) do
		if not fusing or (current and companion.Rarity == current.Rarity and companion.Id ~= current.Id) then
			count += 1
			button(list, (if companion.Id == state.EquippedId then "[EQUIPPED] " else "") .. companion.TemplateId
				.. "  Lv " .. companion.Level .. "  #" .. string.sub(companion.Id, 1, 6), function()
				if fusing then donor = companion.Id else selected = companion.Id end
				render()
			end, if companion.Id == selected or companion.Id == donor then C.Green else C.Navy)
		end
	end
	if count == 0 then label(list, if fusing then "No other companions of this rarity." else "No companions owned.", 50) end
end
local function structure(snapshot: any): string
	local parts = { tostring(snapshot.Ready), snapshot.EquippedId or "" }
	for _, companion in ipairs(snapshot.Owned) do
		table.insert(parts, companion.Id .. companion.Mode .. tostring(companion.Level) .. statText(companion))
	end
	return table.concat(parts, "|")
end
function UI.Mount(parent: Instance): Frame
	local frame = make("Frame", parent, { Name = "CompanionTab", Position = UDim2.fromOffset(16, 94),
		Size = UDim2.new(1, -32, 1, -108), BackgroundTransparency = 1, Visible = false })
	list = make("ScrollingFrame", frame, { Name = "CompanionList", Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Well, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() })
	make("UIListLayout", list, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	make("UIPadding", list, { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) })
	Remotes.CompanionUpdated.OnClientEvent:Connect(function(nextState)
		local changed = structure(state) ~= structure(nextState)
		state = nextState
		if not selected then selected = state.EquippedId end
		if not find(selected) then selected = state.EquippedId; fusing = false; donor = nil end
		if frame.Visible and not busy then
			if changed then render() elseif updateDetails then updateDetails() end
		end
	end)
	frame:GetPropertyChangedSignal("Visible"):Connect(function() if frame.Visible then render() end end)
	request("Get")
	return frame
end
return UI
