--!strict
-- Remotes (Layer 2: Network Layer)
-- Defines client-server communication remotes for gameplay features.
-- The server creates instances; the client waits for them to replicate.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local isServer = RunService:IsServer()

local remotesFolder: Folder
if isServer then
	local existing = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
	if not existing then
        local created = Instance.new("Folder")
        created.Name = "Remotes"
        created.Parent = ReplicatedStorage
        existing = created
	end
	remotesFolder = existing :: Folder
else
	remotesFolder = (ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 10)) :: Folder
	if not remotesFolder then
		error("[Remotes]: Client timed out waiting for ReplicatedStorage.Remotes folder.")
	end
end

local function getRemoteEvent(name: string): RemoteEvent
	if isServer then
		local event = remotesFolder:FindFirstChild(name) :: RemoteEvent?
		if not event then
            local created = Instance.new("RemoteEvent")
            created.Name = name
            created.Parent = remotesFolder
            event = created
		end
		return event :: RemoteEvent
	else
		local event = remotesFolder:FindFirstChild(name) or remotesFolder:WaitForChild(name, 10)
		return event :: RemoteEvent
	end
end

local function getRemoteFunction(name: string): RemoteFunction
	if isServer then
		local func = remotesFolder:FindFirstChild(name) :: RemoteFunction?
		if not func then
            local created = Instance.new("RemoteFunction")
            created.Name = name
            created.Parent = remotesFolder
            func = created
		end
		return func :: RemoteFunction
	else
		local func = remotesFolder:FindFirstChild(name) or remotesFolder:WaitForChild(name, 10)
		return func :: RemoteFunction
	end
end

local Remotes = {
	CompanionUpdated = getRemoteEvent("CompanionUpdated"),
	CompanionAction = getRemoteFunction("CompanionAction"),
	PurchaseZone = getRemoteEvent("PurchaseZone"), -- retained for compatibility; prompts handle purchases
	BaseAction = getRemoteFunction("BaseAction"),
	BaseFeedback = getRemoteEvent("BaseFeedback"),
	InventoryUpdated = getRemoteEvent("InventoryUpdated"),
	GetInventory = getRemoteFunction("GetInventory"),
}

return Remotes
