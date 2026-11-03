"""Economy regression tests against actual Luau source and mocked Roblox services.
Usage: python3 tests/run_economy.py /path/to/luau
"""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
modules = [
    ("PlayerDataConfig", "shared/Features/PlayerData/PlayerDataConfig.luau"),
    ("PlayerDataHelpers", "shared/Features/PlayerData/PlayerDataHelpers.luau"),
    ("PlayerDataTemplate", "shared/Features/PlayerData/PlayerDataTemplate.luau"),
    ("CurrencyConfig", "shared/Features/Currency/CurrencyConfig.luau"),
    ("InventoryConfig", "shared/Features/Inventory/InventoryConfig.luau"),
    ("CurrencyHelpers", "shared/Features/Currency/CurrencyHelpers.luau"),
    ("InventoryHelpers", "shared/Features/Inventory/InventoryHelpers.luau"),
    ("PlayerDataSchema", "server/Features/PlayerData/PlayerDataSchema.luau"),
    ("PlayerDataService", "server/Features/PlayerData/PlayerDataService.luau"),
    ("CurrencyService", "server/Features/Currency/CurrencyService.luau"),
    ("InventoryService", "server/Features/Inventory/InventoryService.luau"),
    ("UIService", "server/Features/UI/UIService.luau"),
]
source = '''
local Players = {}
local guid = 0
local game = { GetService = function(_, name)
    if name == "Players" then return Players end
    if name == "RunService" then return { IsStudio = function() return true end } end
    if name == "HttpService" then return { GenerateGUID = function() guid += 1; return "test-guid-" .. guid end } end
    return { Shared = {} }
end }
local task = { wait = coroutine.yield, delay = function() end }
local warn = function() end
'''
for name, relative in modules:
    code = (ROOT / "src" / relative).read_text()
    code = re.sub(r"local (\w+) = require\(([^\n]+)\)",
                  lambda m: f"local {m[1]} = " + re.search(r"([A-Za-z0-9_]+)$", m[2])[1], code)
    source += f"\nlocal {name} = (function()\n{code}\nend)()\n"
source += (ROOT / "tests/economy.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="tycoon-economy-") as directory:
    bundle = Path(directory) / "economy.luau"
    bundle.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(bundle)], check=True)
