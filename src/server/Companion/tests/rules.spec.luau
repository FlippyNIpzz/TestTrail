-- Executed by run.py outside Studio; this is not a runtime Script.
local random = { NextInteger = function(_, minimum, maximum) return math.random(minimum, maximum) end }
math.randomseed(71)
for rarity, settings in pairs(Config.Rarities) do
	for _ = 1, 1000 do
		local stats = Rules.RollStats(rarity, random)
		local total = 0
		for _, name in Config.Stats do
			assert(stats[name] >= settings.Min and stats[name] <= settings.Max)
			total += stats[name]
		end
		assert(total == settings.Budget)
	end
end
local function companion(id, stats, level, xp)
	return { Id = id, TemplateId = "ElectricCommon", Element = "Electric", Rarity = "Common",
		Stats = stats, Level = level, XP = xp, Health = 10, Charge = 10, Mode = "Fight" }
end
local first = companion("a", {Health=10, Charge=5, Damage=8, Speed=7}, 2, 40)
local second = companion("b", {Health=5, Charge=10, Damage=7, Speed=8}, 5, 55)
Rules.Fuse(first, second)
assert(first.Stats.Health == 10 and first.Stats.Charge == 10 and first.Stats.Damage == 8 and first.Stats.Speed == 8)
assert(first.Level == 5 and first.XP == 0 and first.Id == "a" and first.Element == "Electric")
assert(Rules.Validate(first)) -- Fused total exceeds the original budget.
assert(not pcall(Rules.Fuse, first, first))
second.Rarity = "Rare"
assert(not pcall(Rules.Fuse, first, second))
Rules.Store(first)
assert(first.Level == 0 and first.XP == 0 and first.Stats.Health == 10 and first.Stats.Charge == 10)
first.Health, first.Charge = 90, 80
Rules.Recharge(first, 15)
assert(first.Health == 95 and first.Charge == 90 and first.XP == 0)
Rules.Recharge(first, 75)
assert(first.Health == 100 and first.Charge == 100 and first.Level == 1 and first.XP == 0)
first.Stats.Health = 0/0
assert(not Rules.Validate(first))
print("PASS: 4,000 stat rolls, fusion, budget overflow, identity, storage, recharge priority, XP, malformed data")
