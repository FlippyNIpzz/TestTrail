--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.NetworkingConfig)
local Helpers = {}
function Helpers.Get(name: string): Instance
    local definition = Config.Remotes[name]
    assert(definition, "Unknown remote: " .. name)
    local folder = ReplicatedStorage:WaitForChild(Config.FolderName, 10)
    assert(folder, "Networking is unavailable")
    local remote = folder:WaitForChild(name, 10)
    assert(remote and remote.ClassName == definition.ClassName, "Missing or invalid remote: " .. name)
    return remote
end
return Helpers
