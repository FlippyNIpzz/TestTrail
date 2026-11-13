"""Exercise actual base modules with local Roblox mocks; never opens Studio."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile

base = Path(__file__).resolve().parents[1]
src = base.parents[1]

def module(name, path):
    code = path.read_text()
    lines, depth, skipping = [], 0, False
    for line in code.splitlines():
        if line.startswith('export type '):
            skipping = True
        if skipping:
            depth += line.count('{') - line.count('}')
            if depth == 0:
                skipping = False
            continue
        lines.append(line)
    code = '\n'.join(lines)
    code = re.sub(r'local (\w+) = require\([^\n]+\)', lambda m: f'local {m[1]} = {m[1]}', code)
    return f'local {name} = (function()\n{code}\nend)()\n'

source = (base / 'tests/mocks.luau').read_text()
source += module('Config', src / 'shared/BaseConfig.luau')
source += module('Profile', base / 'BaseProfile.luau')
source += module('Catalog', base / 'BaseZoneCatalog.luau')
source += module('Assets', base / 'BaseAssetManager.luau')
source += (base / 'tests/slots.spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='base-slots-') as directory:
    bundle = Path(directory) / 'slots.luau'
    bundle.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(bundle)], check=True)

source = (base / 'tests/mocks.luau').read_text()
source += module('Config', src / 'shared/BaseConfig.luau')
source += module('Profile', base / 'BaseProfile.luau')
source += module('Catalog', base / 'BaseZoneCatalog.luau')
source += (base / 'tests/layout-mocks.luau').read_text()
source += module('BaseManager', base / 'BaseManager.luau')
source += (base / 'tests/layout.spec.luau').read_text()
with tempfile.TemporaryDirectory(prefix='base-layouts-') as directory:
    bundle = Path(directory) / 'layouts.luau'
    bundle.write_text(source)
    subprocess.run([sys.argv[1] if len(sys.argv) > 1 else 'luau', str(bundle)], check=True)
