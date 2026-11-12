--!strict
-- BaseUtils.luau (Layer 2: Utility Layer)
-- File Path: src/server/Base/BaseUtils.luau

local scriptParent = script.Parent
local BaseData = require(scriptParent:WaitForChild("BaseData"))

local BaseUtils = {}

function BaseUtils.CalculateSpotTransform(index: number): (Vector3, CFrame)
	local angle = (index - 1) * (2 * math.pi / BaseData.TOTAL_SPOTS)
	local x = BaseData.CENTER_POSITION.X + BaseData.CIRCLE_RADIUS * math.cos(angle)
	local z = BaseData.CENTER_POSITION.Z + BaseData.CIRCLE_RADIUS * math.sin(angle)
	local position = Vector3.new(x, BaseData.CENTER_POSITION.Y, z)
	
	local lookCFrame = CFrame.lookAt(position, BaseData.CENTER_POSITION)
	
	return position, lookCFrame
end

return BaseUtils