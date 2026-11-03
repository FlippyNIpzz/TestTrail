"""Emit isolated AdminService policy tests for Studio loadstring; no live game changes."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
print('''
local clock = 100
local os = { clock = function() return clock end }
local Players = {}
local guid = 0
local HttpService = { GenerateGUID = function() guid += 1; return "token-" .. guid end }
local game = { CreatorType = Enum.CreatorType.User, CreatorId = 42,
 GetService = function(_, name) return if name == "Players" then Players else HttpService end }
local Config = { AdminUserIds = { 7, 8 }, AllowExperienceOwner = true, RequestIntervalSeconds = 0.35,
 StateIntervalSeconds = 0.5, ConfirmationLifetimeSeconds = 30,
 Toggles = { {Id="generation", Name="Generation", Adapter="ResourceGeneration", Warning="Existing pickups expire normally."} },
 ModelTargets = { {Id="plot", Name="Plot", Adapter="BaseStructure", PlotId="plot", Options={ {Id="base.level_1",Name="Style 1",Level=1},{Id="base.level_2",Name="Style 2",Level=2} }} } }
local enabled, style, owner, failModel = true, "base.level_1", 7, false
local calls = 0
local Spawner = { GetGenerationEnabled = function() return enabled end,
 SetGenerationEnabled = function(value) enabled = value; calls += 1; return true end }
local Base = { GetPurchasesEnabled = function() return true end, SetPurchasesEnabled = function() return true end,
 GetAdminModelState = function() return { Available=owner~=0,Current=style,OwnerUserId=owner,Level=1 } end,
 ReplaceAppearance = function(_, level)
  if failModel then return false,"ModelPreparationFailed" end
  style="base.level_" .. level; calls += 1; return true
 end }
local function player(id) return { UserId=id, Parent=Players, GetAttribute=function() return true end } end
local admin, other, outsider, creator = player(7), player(8), player(9), player(42)
local context = {GameConfig={Features={Resources=true,Base=true}}}
''')
source=(ROOT/'src/server/Features/Admin/AdminService.luau').read_text()
source=source.replace('require(script.Parent.AdminConfig)', 'Config')
source=source.replace('require(script.Parent.Parent.Resources.ResourcesSpawner)', 'Spawner')
source=source.replace('require(script.Parent.Parent.Inventory.InventoryService)', '{}')
source=source.replace('require(script.Parent.Parent.Base.BaseService)', 'Base')
print('local Service = (function()\n'+source+'\nend)()')
print((ROOT/'tests/admin.spec.luau').read_text())
