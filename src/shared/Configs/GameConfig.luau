
local GameConfig = {}

-- GAME IDENTITY
GameConfig.GameName = "NoGem"
GameConfig.CameraMode = "ThirdPerson"

-- SERVER SETTINGS
GameConfig.MaxPlayers = 13

-- BASE SETTINGS
GameConfig.MaxBases = 13
GameConfig.BasesPerPlayer = 1
GameConfig.AutoAssignBase = true

-- COMPANION SETTINGS
GameConfig.MaxActiveCompanions = 1

-- PLAYER DATA
GameConfig.PersistentData = true
GameConfig.AutoSave = true

-- GAMEPLAY
GameConfig.ArenaEnabled = true
GameConfig.RebirthEnabled = true

return GameConfig
