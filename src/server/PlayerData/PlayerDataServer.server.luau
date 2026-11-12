--!strict
-- PlayerDataServer (Layer 4: Execution Layer)

local Players = game:GetService("Players")

local PlayerDataFolder = script.Parent
local Config = require(PlayerDataFolder:WaitForChild("PlayerData"))
local Data = require(PlayerDataFolder:WaitForChild("PlayerDataModule"))
local Inventory = require(PlayerDataFolder:WaitForChild("Inventory"))

local CompanionManager = require(script.Parent.Parent.Companion.CompanionManager)

local closing = false

local function joined(player: Player)
	local profile, reason = Data.InitializeProfile(player)
	if not profile then
		if player.Parent == Players then player:Kick("Unable to load your data. Please rejoin. " .. tostring(reason)) end
		return
	end

	CompanionManager.AttachPlayer(player)
	player:SetAttribute("CompanionId", profile.CompanionId)
	for _, name in {"Cash", "Scrap", "Level", "Rebirths"} do
		player:SetAttribute(name, (profile :: any)[name])
	end
	player:SetAttribute("DataReady", true)

	-- Give starter ores for testing the proximity walk-by forge deposit
	Inventory.GiveStarterItems(player)
	Inventory.Sync(player)
end

Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player: Player)
	CompanionManager.DetachPlayer(player)
	Data.RemoveProfile(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		joined(player)
	end)
end

task.spawn(function()
	while not closing do
		task.wait(Config.AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(function()
				Data.SaveProfile(player)
			end)
		end
	end
end)

game:BindToClose(function()
	closing = true
	if (Data :: any).Close then
		(Data :: any).Close()
	end
end)
