--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Manager = require(script.Parent.CompanionManager)
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
Manager.Init()
Remotes.CompanionAction.OnServerInvoke = function(player, action, id, secondId)
	return Manager.Action(player, action, id, secondId)
end
