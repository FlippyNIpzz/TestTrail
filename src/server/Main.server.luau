--!strict
-- Main Server Execution Entry Point (Layer 4)

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

-- Require Managers (Layer 3)
local BaseManager = require(Server:WaitForChild("Base"):WaitForChild("BaseManager"))
local BaseAssetManager = require(Server:WaitForChild("Base"):WaitForChild("BaseAssetManager"))

local Arena = require(Server:WaitForChild("Arena"):WaitForChild("Arena"))

local function initializeServer()
	print("[MainServer]: Starting server initialization...")

	-- PlayerDataServer attaches player sessions.

	-- 2. Initialize the 13 base spots and zone placement structure
	if BaseManager.InitializeBases then
		BaseManager.InitializeBases()
	end

	-- 3. Initialize Base Assets (Forge processing & Charge Station power loops)
	if BaseAssetManager.Init then
		BaseAssetManager.Init()
	end

	Arena.Init()
	require(Server.Arena.ArenaCarryManager).Init()

	print("[MainServer]: All systems successfully initialized.")
end

initializeServer()