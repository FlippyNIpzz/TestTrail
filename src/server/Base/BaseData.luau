--!strict
-- BaseData (Layer 1: Data Layer)
-- Purpose: Static configuration, constants, and type definitions for bases.

local BaseData = {}

BaseData.TOTAL_SPOTS = 14
BaseData.BASE_COUNT = 13
BaseData.PATHWAY_INDEX = 14 -- The 14th spot is reserved for the common pathway
BaseData.CIRCLE_RADIUS = 125
BaseData.CENTER_POSITION = Vector3.new(0, 0, 0)

export type BaseConfig = {
	Index: number,
	Position: Vector3,
	CFrame: CFrame,
	IsPathway: boolean,
}

return BaseData