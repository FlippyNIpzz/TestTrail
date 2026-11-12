--!strict
-- UITheme (Layer 1: Presentation Layer)
-- Native pixel UI style: crisp geometry, double-beveled borders, rivets, and arcade font.

local Theme = {}

Theme.Colors = {
	Ink = Color3.fromRGB(54, 42, 57),
	Panel = Color3.fromRGB(248, 181, 122),
	Light = Color3.fromRGB(255, 221, 157),
	Shade = Color3.fromRGB(174, 100, 91),
	Well = Color3.fromRGB(232, 157, 110),
	Gold = Color3.fromRGB(255, 203, 83),
	Navy = Color3.fromRGB(65, 76, 108),
	Cream = Color3.fromRGB(255, 237, 192),
	Muted = Color3.fromRGB(111, 68, 69),
	Green = Color3.fromRGB(78, 111, 85),
	Bronze = Color3.fromRGB(180, 110, 60),
	Silver = Color3.fromRGB(190, 200, 215),
}

function Theme.Make(className: string, parent: Instance?, properties: { [string]: any }?): any
	local object = Instance.new(className)
	if object:IsA("GuiObject") then
		object.BorderSizePixel = 0
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		object.Font = Enum.Font.Arcade
		object.TextSize = 16
		object.TextColor3 = Theme.Colors.Ink
	end
	if properties then
		for key, value in pairs(properties) do
			(object :: any)[key] = value
		end
	end
	if parent then
		object.Parent = parent
	end
	return object
end

function Theme.Edge(object: GuiObject, dark: boolean?)
	local c = Theme.Colors
	Theme.Make("UIStroke", object, {
		Name = "PixelOutline",
		Color = c.Ink,
		Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})
	Theme.Make("Frame", object, {
		Name = "TopBevel", Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, 2),
		BackgroundColor3 = if dark then Color3.fromRGB(128, 147, 174) else c.Light,
	})
	Theme.Make("Frame", object, {
		Name = "BottomBevel", Position = UDim2.new(0, 2, 1, -4),
		Size = UDim2.new(1, -4, 0, 2),
		BackgroundColor3 = if dark then c.Ink else c.Shade,
	})
end

function Theme.Panel(parent: Instance?, properties: { [string]: any }?): Frame
	local panel = Theme.Make("Frame", parent, properties)
	Theme.Edge(panel)

	-- Inset double border
	local inset = Theme.Make("Frame", panel, {
		Name = "InsetBorder", Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1,
	})
	Theme.Make("UIStroke", inset, {
		Color = Theme.Colors.Shade,
		Thickness = 2, LineJoinMode = Enum.LineJoinMode.Miter,
	})

	-- Corner gold rivets
	for _, corner in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
		local rivet = Theme.Make("Frame", panel, {
			Name = "CornerRivet",
			AnchorPoint = corner,
			Position = UDim2.new(corner.X, if corner.X == 0 then 2 else -2, corner.Y, if corner.Y == 0 then 2 else -2),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Theme.Colors.Gold,
		})
		Theme.Make("UIStroke", rivet, {
			Color = Theme.Colors.Ink,
			Thickness = 1, LineJoinMode = Enum.LineJoinMode.Miter,
		})
	end

	return panel
end

function Theme.Button(parent: Instance?, properties: { [string]: any }?): TextButton
	local button = Theme.Make("TextButton", parent, properties)
	button.AutoButtonColor = true
	local isDark = (properties and properties.BackgroundColor3 == Theme.Colors.Navy)
	Theme.Edge(button, isDark)
	return button
end

return Theme
