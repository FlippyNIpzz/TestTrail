--!strict
-- All balancing lives here. Rare+ budgets and gameplay rates are provisional.
local Config = {}
Config.Stats = { "Health", "Charge", "Damage", "Speed" }
Config.Rarities = {
	Common = { Budget = 30, Min = 5, Max = 10 },
	Rare = { Budget = 64, Min = 10, Max = 23 },
	Epic = { Budget = 110, Min = 20, Max = 40 },
	Legendary = { Budget = 180, Min = 35, Max = 65 },
}
Config.LevelMultiplier = 0.05 -- multiplier = 1 + level * this value
Config.XPPerLevel = 60
Config.StatScale = { Health = 10, Charge = 10, Damage = 1, Speed = 1.5 }
Config.AttackInterval = 1
Config.AttackChargeCost = 2
Config.AttackRange = 6
Config.ExhaustedSpeedMultiplier = 0.5
Config.StationRange = 14
Config.StationTransferRate = 13
Config.HomeWanderRadius = 5
Config.FollowOffset = Vector3.new(4, 0, 4)
Config.FollowTeleportDistance = 80
-- Stud-based traversal limits; dimensions are measured independently for each rig.
Config.StepHeight = 0.65
Config.JumpHeight = 3.5
Config.JumpLookAhead = 0.3
Config.PathJumpRequestLifetime = 0.75
Config.MaxDrop = 6
Config.MaxSlopeDegrees = 42
Config.Gravity = 60
Config.PathRetryInterval = 1.5
Config.PathTargetTolerance = 5
Config.MaxTravelPerSubstep = 0.5
Config.Modes = { Home = true, Follow = true, Fight = true }
export type Companion = {
	Id: string, TemplateId: string, Element: string, Rarity: string,
	Stats: { [string]: number }, Level: number, XP: number,
	Health: number, Charge: number, Mode: string,
}
return Config
