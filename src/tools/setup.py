"""Install pinned analysis tools locally; no Studio or global installation."""
import hashlib
from pathlib import Path
import platform
import urllib.request
import zipfile

LOCAL = Path(__file__).resolve().parent / '.local'
VERSION = '1.70.1'
ASSETS = {
    'luau-lsp.zip': (
        f'https://github.com/JohnnyMorganz/luau-lsp/releases/download/{VERSION}/luau-lsp-macos.zip',
        '7d3936e8dec6dc77547abd061d2e950da392562a5f94858b880f23dba50d84cd'),
    'globalTypes.d.luau': (
        f'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{VERSION}/scripts/globalTypes.d.luau',
        '2857efa8245485f8c25c19c018ee1ef9b46afab4efd2ea70fc3257cd3faf7080'),
}

def main():
    if platform.system() != 'Darwin':
        raise SystemExit('This pinned setup supports macOS only.')
    LOCAL.mkdir(exist_ok=True)
    for name, (url, checksum) in ASSETS.items():
        path = LOCAL / name
        data = path.read_bytes() if path.exists() else b''
        if hashlib.sha256(data).hexdigest() != checksum:
            print(f'Downloading {name}', flush=True)
            with urllib.request.urlopen(url, timeout=60) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != checksum:
                raise SystemExit(f'Checksum mismatch: {name}; refusing installation')
            path.write_bytes(data)
    with zipfile.ZipFile(LOCAL / 'luau-lsp.zip') as archive:
        binary = LOCAL / 'luau-lsp'
        binary.write_bytes(archive.read('luau-lsp'))
        binary.chmod(0o755)
    print(f'Luau LSP {VERSION} and matching Roblox definitions ready in {LOCAL}')

if __name__ == '__main__':
    main()
