--!strict
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(script.Parent.CompanionData)
local Rules = require(script.Parent.CompanionRules)
local Collection = {}
local random = Random.new()

function Collection.Templates(): Instance?
    local scene = Workspace:FindFirstChild("Game")
    local companions = scene and scene:FindFirstChild("Companions")
    if companions then return companions:FindFirstChild("CompanionModelGallery") or companions end
    for _, service in { Workspace, ServerStorage } do
        local assets = service:FindFirstChild("Assets")
        local folder = assets and (assets:FindFirstChild("Companions") or assets:FindFirstChild("Companion"))
        if folder then return folder:FindFirstChild("CompanionModelGallery") or folder end
    end
    return nil
end

function Collection.Identity(templateId: string): (string?, string?)
	for rarity: string in pairs(Config.Rarities) do
		if string.sub(templateId, -#rarity) == rarity then
			return string.sub(templateId, 1, #templateId - #rarity), rarity
		end
	end
	return nil, nil
end

function Collection.Create(templateId: string): Config.Companion
	local element, rarity = Collection.Identity(templateId)
	assert(element and element ~= "" and rarity, "Template name must end with a configured rarity")
	local companion: Config.Companion = {
		Id = HttpService:GenerateGUID(false), TemplateId = templateId, Element = element, Rarity = rarity,
		Stats = Rules.RollStats(rarity, random), Level = 0, XP = 0, Health = 0, Charge = 0, Mode = "Follow",
	}
	local values = Rules.Values(companion)
	companion.Health, companion.Charge = values.Health, values.Charge
	return companion
end

-- Returns an error instead of overwriting malformed saved collections.
function Collection.Load(raw: any, legacyId: string?): (any?, string?)
	if raw ~= nil then
		if type(raw) ~= "table" or type(raw.Owned) ~= "table" then return nil, "Invalid companion collection" end
		local seen = {}
		for _, companion in ipairs(raw.Owned) do
			if not Rules.Validate(companion) or seen[companion.Id] then return nil, "Invalid saved companion" end
			local element, rarity = Collection.Identity(companion.TemplateId)
			if element ~= companion.Element or rarity ~= companion.Rarity then return nil, "Invalid companion identity" end
			seen[companion.Id] = true
			if companion.Id ~= raw.EquippedId then Rules.Store(companion) end
			local values = Rules.Values(companion)
			companion.Health = math.min(companion.Health, values.Health)
			companion.Charge = math.min(companion.Charge, values.Charge)
		end
		if raw.EquippedId ~= nil and not seen[raw.EquippedId] then return nil, "Invalid equipped companion" end
		return raw, nil
	end
	local templateId = legacyId
	if not templateId then
		local candidates = {}
		local folder = Collection.Templates()
		if folder then
			for _, template in folder:GetChildren() do
				local _, rarity = Collection.Identity(template.Name)
				if template:IsA("Model") and rarity == "Common" then table.insert(candidates, template.Name) end
			end
		end
		if #candidates == 0 then return nil, "No Common companion templates in Workspace or ServerStorage assets" end
		table.sort(candidates)
		templateId = candidates[random:NextInteger(1, #candidates)]
	end
	assert(templateId, "Starter template selection must produce an ID")
	local element, rarity = Collection.Identity(templateId)
	if not element or not rarity then return nil, "Unknown legacy companion" end
	local starter = Collection.Create(templateId)
	return { Owned = { starter }, EquippedId = starter.Id }, nil
end

function Collection.Find(collection: any, id: string?): (Config.Companion?, number?)
	for index, companion in ipairs(collection.Owned) do
		if companion.Id == id then return companion, index end
	end
	return nil, nil
end
return Collection
