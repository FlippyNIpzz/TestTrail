--!strict
-- Pure rules shared by persistence, server actions and local regression tests.
local Config = require(script.Parent.CompanionData)
local Rules = {}

function Rules.IsNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Rules.RollStats(rarity: string, random: Random): { [string]: number }
	local rule = Config.Rarities[rarity]
	assert(rule, "Unknown rarity: " .. rarity)
	assert(rule.Min % 1 == 0 and rule.Max % 1 == 0 and rule.Budget % 1 == 0
		and rule.Min > 0 and rule.Max >= rule.Min
		and rule.Budget >= #Config.Stats * rule.Min and rule.Budget <= #Config.Stats * rule.Max,
		"Invalid rarity budget or stat bounds")
	local stats = {}
	for _, name in Config.Stats do stats[name] = rule.Min end
	for _ = 1, rule.Budget - #Config.Stats * rule.Min do
		local eligible = {}
		for _, name in Config.Stats do
			if stats[name] < rule.Max then table.insert(eligible, name) end
		end
		local name = eligible[random:NextInteger(1, #eligible)]
		stats[name] += 1
	end
	return stats
end

function Rules.Values(companion: Config.Companion): { [string]: number }
	local values = {}
	for _, name in Config.Stats do
		values[name] = companion.Stats[name] * Config.StatScale[name] * (1 + companion.Level * Config.LevelMultiplier)
	end
	return values
end

function Rules.Store(companion: Config.Companion)
	companion.Level = 0
	companion.XP = 0
	local values = Rules.Values(companion)
	companion.Health = math.min(companion.Health, values.Health)
	companion.Charge = math.min(companion.Charge, values.Charge)
end

function Rules.Fuse(first: Config.Companion, second: Config.Companion)
	assert(first.Id ~= second.Id and first.Rarity == second.Rarity, "Invalid fusion pair")
	for _, name in Config.Stats do first.Stats[name] = math.max(first.Stats[name], second.Stats[name]) end
	first.Level = math.max(first.Level, second.Level)
	first.XP = 0
end

function Rules.Recharge(companion: Config.Companion, power: number)
	local values = Rules.Values(companion)
	local chargeNeed = math.max(0, values.Charge - companion.Charge)
	local healthNeed = math.max(0, values.Health - companion.Health)
	local need = chargeNeed + healthNeed
	local used = math.min(power, need)
	-- Refill both proportionally before any power goes to XP.
	if need > 0 then
		companion.Charge += used * chargeNeed / need
		companion.Health += used * healthNeed / need
	end
	companion.XP += power - used
	local levels = math.floor(companion.XP / Config.XPPerLevel)
	companion.Level += levels
	companion.XP -= levels * Config.XPPerLevel
end

function Rules.Validate(raw: any): boolean
	if type(raw) ~= "table" or type(raw.Id) ~= "string" or raw.Id == ""
		or type(raw.TemplateId) ~= "string" or type(raw.Element) ~= "string"
		or not Config.Rarities[raw.Rarity] or not Config.Modes[raw.Mode] or type(raw.Stats) ~= "table" then return false end
	for _, name in Config.Stats do
		local n = raw.Stats[name]
		if not Rules.IsNumber(n) or n % 1 ~= 0 or n < Config.Rarities[raw.Rarity].Min or n > Config.Rarities[raw.Rarity].Max then return false end
	end
	for _, name in { "Level", "XP", "Health", "Charge" } do
		if not Rules.IsNumber(raw[name]) or raw[name] < 0 then return false end
	end
	return raw.Level % 1 == 0 and raw.XP < Config.XPPerLevel
end
return Rules
