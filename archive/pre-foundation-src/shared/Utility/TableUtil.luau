--!strict

--[[
	TableUtil.luau
	Layer: 2 (Utility)
	Description: Pure table utility functions (DeepCopy, Reconcile).
]]

local TableUtil = {}

-- Performs a recursive deep copy of a table to ensure no shared memory references.
function TableUtil.DeepCopy<T>(original: T): T
	if type(original) ~= "table" then
		return original
	end

	local copy = {}
	for key, value in pairs(original :: any) do
		if type(value) == "table" then
			copy[key] = TableUtil.DeepCopy(value)
		else
			copy[key] = value
		end
	end

	return (copy :: any) :: T
end

-- Reconciles a target table against a template table.
-- If a key exists in the template but is missing in target, it is copied over.
-- Nested tables are recursively reconciled.
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any }): ()
	for key, templateValue in pairs(template) do
		if target[key] == nil then
			if type(templateValue) == "table" then
				target[key] = TableUtil.DeepCopy(templateValue)
			else
				target[key] = templateValue
			end
		elseif type(target[key]) == "table" and type(templateValue) == "table" then
			TableUtil.Reconcile(target[key], templateValue)
		end
	end
end

return TableUtil
