--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Features.Networking.NetworkingConfig)
local Feature = {}
function Feature.Initialize(_context: any) end
function Feature.Start()
    assert(ReplicatedStorage:WaitForChild(Config.FolderName, 10), "Server networking unavailable")
end
function Feature.Destroy() end
return Feature
