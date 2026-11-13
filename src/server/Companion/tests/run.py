"""Run pure companion rules using a Luau CLI: python3 run.py /path/to/luau."""
from pathlib import Path
import subprocess
import sys
import re
import tempfile

root = Path(__file__).resolve().parents[1]
source = 'local Vector3 = {new = function(...) return {...} end}\n'
for name, filename in [('Config', 'CompanionData.luau'), ('Rules', 'CompanionRules.luau')]:
    code = (root / filename).read_text()
    code = code.replace('local Config = require(script.Parent.CompanionData)', 'local Config = Config')
    # Exported type declarations cannot be nested in a function in the CLI bundle.
    if name == 'Config':
        start = code.index('export type Companion = {')
        end = code.index('\n}', start) + 2
        code = code[:start] + code[end:]
    source += f'local {name} = (function()\n{code}\nend)()\n'
source += (root / 'tests/rules.spec.luau').read_text()
source += r"""
local now = 0
local os = {clock = function() return now end}
local workspace = {}
local task = {spawn = function() end}
local connection = {Connect = function() end}
local Players = {PlayerRemoving = connection}
local Runtime = {Heartbeat = connection}
local fakeStorage = {FindFirstChild = function() return nil end}
local guid = 0
local game = {GetService = function(_, name)
    if name == "Players" then return Players end
    if name == "RunService" then return Runtime end
    if name == "HttpService" then return {GenerateGUID = function() guid += 1; return tostring(guid) end} end
    return fakeStorage
end}
local Random = {new = function() return random end}
local Instance = {new = function() return {} end}
local profiles = {}
local Data = {GetProfile = function(player) return profiles[player] end}
local Remotes = {CompanionUpdated = {FireClient = function() end}}
local World = {Arena = function() return nil end}
"""
for name, filename in [('Collection', 'CompanionCollection.luau'), ('Manager', 'CompanionManager.luau')]:
    code = (root / filename).read_text()
    code = re.sub(r'local (\w+) = require\([^\n]+\)', lambda m: f'local {m[1]} = {m[1]}', code)
    source += f'local {name} = (function()\n{code}\nend)()\n'
source += (root / 'tests/actions.spec.luau').read_text()
source += r"""
local children = {}
fakeStorage.FindFirstChild = function(_, name) return children[name] end
local function folder(entries) return {FindFirstChild=function(_, name) return entries[name] end} end
local stored = folder({})
children.Assets = folder({Companions=stored})
assert(Collection.Templates() == stored)
local gallery = folder({})
children.Game = folder({Companions=folder({CompanionModelGallery=gallery})})
assert(Collection.Templates() == gallery)
local direct = folder({})
children.Game = folder({Companions=direct})
assert(Collection.Templates() == direct)
children.Game = nil; children.Assets = nil
assert(Collection.Templates() == nil)
print("PASS: companion gallery, direct templates, assets and missing-folder resolution")
"""

with tempfile.TemporaryDirectory(prefix='companion-rules-') as directory:
    bundle = Path(directory) / 'rules.luau'
    bundle.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(bundle)], check=True)

# Traversal and animation rules run as a separate actual-source bundle.
subprocess.run([sys.executable, str(root / 'tests/motion.py'),
                sys.argv[1] if len(sys.argv) > 1 else 'luau'], check=True)
subprocess.run([sys.executable, str(root / 'tests/rig.py'),
                sys.argv[1] if len(sys.argv) > 1 else 'luau'], check=True)
