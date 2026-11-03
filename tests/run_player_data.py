"""Run pure profile and memory-session tests with an installed Luau CLI.
Usage: python3 tests/run_player_data.py /path/to/luau
Roblox services are mocked; this does not test real DataStores or Studio UI.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
modules = [
    ("Config", "shared/Features/PlayerData/PlayerDataConfig.luau"),
    ("Helpers", "shared/Features/PlayerData/PlayerDataHelpers.luau"),
    ("Template", "shared/Features/PlayerData/PlayerDataTemplate.luau"),
    ("Currency", "shared/Features/Currency/CurrencyConfig.luau"),
    ("Inventory", "shared/Features/Inventory/InventoryConfig.luau"),
    ("CurrencyRules", "shared/Features/Currency/CurrencyHelpers.luau"),
    ("InventoryRules", "shared/Features/Inventory/InventoryHelpers.luau"),
    ("Schema", "server/Features/PlayerData/PlayerDataSchema.luau"),
    ("Service", "server/Features/PlayerData/PlayerDataService.luau"),
]
source = '''
local Players = {}
local RunService = { IsStudio = function() return true end }
local game = { GetService = function(_, name)
    if name == "Players" then return Players end
    if name == "RunService" then return RunService end
    return { Shared = {} }
end }
local VendorForTests
local script = { Parent = { Vendor = { ProfileStore = "vendor" } } }
local require = function() return VendorForTests end
local task = { wait = coroutine.yield, delay = function() end }
local warn = function() end
'''
for name, relative in modules:
    code = (ROOT / "src" / relative).read_text()
    # Bind module dependencies to the actual source modules wrapped above.
    import re
    code = re.sub(r"local (\w+) = require\([^\n]+\)", lambda m: f"local {m[1]} = " + ({
        "CurrencyConfig": "Currency", "InventoryConfig": "Inventory",
        "TableHelpers": "Helpers", "CurrencyHelpers": "CurrencyRules", "InventoryHelpers": "InventoryRules",
        "Config": "Currency" if name == "CurrencyRules" else "Inventory" if name == "InventoryRules" else "Config",
    }.get(m[1], m[1])), code)
    source += f"\nlocal {name} = (function()\n{code}\nend)()\n"
source += (ROOT / "tests/player_data.spec.luau").read_text()
with tempfile.TemporaryDirectory(prefix="tycoon-player-data-") as directory:
    bundle = Path(directory) / "spec.luau"
    bundle.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "luau", str(bundle)], check=True)
