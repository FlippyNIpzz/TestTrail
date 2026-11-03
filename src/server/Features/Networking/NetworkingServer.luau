--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Features.Networking.NetworkingConfig)
local Feature = {}
local owned: { Instance } = {}
local initialized = false
function Feature.Initialize(context: any)
    if initialized then return end
    local folder = ReplicatedStorage:FindFirstChild(Config.FolderName)
    if folder then assert(folder:IsA("Folder"), "Invalid remote folder")
    else
        folder = Instance.new("Folder")
        folder.Name = Config.FolderName
        folder.Parent = ReplicatedStorage
        table.insert(owned, folder)
    end
    for name, definition in Config.Remotes do
        if context.GameConfig.Features[definition.Feature] then
            local remote = folder:FindFirstChild(name)
            if remote then assert(remote.ClassName == definition.ClassName, "Invalid remote: " .. name)
            else
                remote = Instance.new(definition.ClassName)
                remote.Name = name
                remote.Parent = folder
                table.insert(owned, remote)
            end
        end
    end
    initialized = true
end
function Feature.Start() assert(initialized, "Networking not initialized") end
function Feature.Destroy()
    for index = #owned, 1, -1 do owned[index]:Destroy() end
    table.clear(owned)
    initialized = false
end
return Feature
