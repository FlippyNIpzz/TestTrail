"""Emit an isolated Studio loadstring test bundle. Fixtures stay outside the DataModel.
python3 tests/run_bases.py > /tmp/tycoon-base-tests.luau
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def module(name, path, substitutions=None):
    code = (ROOT / 'src' / path).read_text()
    for old, new in (substitutions or {}).items():
        code = code.replace(old, new)
    print(f'local {name} = (function()\n{code}\nend)()')
print('''
local Players = {}
local workspace = Instance.new("Folder") -- Unparented sandbox, not the live Workspace.
workspace.Name = "Workspace"
local game = { GetService = function(_, name)
    if name == "Players" then return Players end
    return { Shared = {} }
end, FindFirstChild = function(_, name) if name == "Workspace" then return workspace end return nil end }
local storage = Instance.new("Folder")
storage.Name = "ServerStorage"
local originalFind = game.FindFirstChild
game.FindFirstChild = function(self, name)
    if name == "ServerStorage" then return storage end
    return originalFind(self, name)
end
local profiles, rejected = {}, false
local PlayerData = {}
''')
module('Tables', 'shared/Features/PlayerData/PlayerDataHelpers.luau')
print('''
function PlayerData.Get(player)
    if not profiles[player] then return false, "NotReady" end
    return true, Tables.DeepCopy(profiles[player])
end
function PlayerData.Update(player, callback)
    if not profiles[player] then return false, "NotReady" end
    local draft = Tables.DeepCopy(profiles[player])
    local ok, accepted, reason = pcall(callback, draft)
    if not ok then return false, "TransactionFailed" end
    if accepted == false then return false, reason end
    if rejected then return false, "InjectedCommitFailure" end
    profiles[player] = draft
    return true
end
''')
module('CurrencyConfig', 'shared/Features/Currency/CurrencyConfig.luau')
module('Currency', 'shared/Features/Currency/CurrencyHelpers.luau', {
    'require(script.Parent.CurrencyConfig)': 'CurrencyConfig',
    'require(script.Parent.Parent.PlayerData.PlayerDataHelpers)': 'Tables',
})
module('Config', 'shared/Features/Base/BaseConfig.luau')
module('Models', 'server/Features/Base/BaseModels.luau')
module('Service', 'server/Features/Base/BaseService.luau', {
    'require(Shared.Features.Base.BaseConfig)': 'Config',
    'require(Shared.Features.Currency.CurrencyHelpers)': 'Currency',
    'require(Shared.Features.PlayerData.PlayerDataHelpers)': 'Tables',
    'require(script.Parent.Parent.PlayerData.PlayerDataService)': 'PlayerData',
    'require(script.Parent.BaseModels)': 'Models',
})
print((ROOT / 'tests/bases.spec.luau').read_text())
