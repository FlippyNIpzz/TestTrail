--!strict
-- Coordinates screen menus without coupling their presentation modules.
local UserInputService = game:GetService("UserInputService")
local Controller = {}
local activeClose: (() -> ())? = nil

function Controller.Open(close: () -> ())
	if activeClose and activeClose ~= close then activeClose() end
	activeClose = close
end

function Controller.Release(close: () -> ())
	if activeClose == close then activeClose = nil end
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if activeClose then activeClose() end
	end
end)

return Controller
