"""Local verification. Exit nonzero on any failed stage; never starts Studio."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

SRC = Path(__file__).resolve().parents[1]
ROOT = SRC.parent
LOCAL = SRC / 'tools' / '.local'

def run(label, args, log=None):
    print(f'\n{label}', flush=True)
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if log:
        log.write_text(result.stdout)
        lines = result.stdout.splitlines()
        print('\n'.join(lines[:20]))
        if len(lines) > 20:
            print(f'... {len(lines)} total lines; full report: {log}')
    else:
        print(result.stdout, end='')
    print(f'{label}: {"PASS" if result.returncode == 0 else "FAIL"}', flush=True)
    return result.returncode == 0

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--tests-only', action='store_true')
    mode.add_argument('--analyze-only', action='store_true')
    args = parser.parse_args()
    required = ['rojo'] + ([] if args.analyze_only else ['luau', 'luau-compile'])
    missing = [tool for tool in required if not shutil.which(tool)]
    if missing:
        raise SystemExit('Missing PATH tools: ' + ', '.join(missing))
    if not args.tests_only and not all((LOCAL / name).exists() for name in ['luau-lsp', 'globalTypes.d.luau']):
        raise SystemExit('Run python3 src/tools/setup.py first.')
    LOCAL.mkdir(exist_ok=True)
    files = sorted(path for folder in ['client', 'server', 'shared']
                   for path in (SRC / folder).rglob('*.luau'))
    results = []
    if not args.analyze_only:
        results.append(run('Luau compilation', ['luau-compile', '--null', *files]))
        for suite in ['server/Arena/tests/run.py', 'server/Arena/tests/carry.py',
                      'server/Arena/tests/geometry.py', 'server/Companion/tests/run.py',
                      'server/Base/tests/run.py']:
            results.append(run(suite, [sys.executable, SRC / suite, shutil.which('luau')]))
        results.append(run('Rojo build', ['rojo', 'build', ROOT / 'default.project.json',
                                         '-o', LOCAL / 'verification.rbxlx']))
    if not args.tests_only:
        mapped = run('Rojo sourcemap', ['rojo', 'sourcemap', ROOT / 'default.project.json',
                                      '--output', LOCAL / 'sourcemap.json'])
        results.append(mapped)
        if mapped:
            # Rojo filePaths are relative to the project root, so analysis must run there.
            production = [path for path in files if 'tests' not in path.relative_to(SRC).parts]
            results.append(run('Roblox type/lint analysis', [LOCAL / 'luau-lsp', 'analyze',
                '--platform=roblox', f'--definitions={LOCAL / "globalTypes.d.luau"}',
                f'--sourcemap={LOCAL / "sourcemap.json"}', *production], LOCAL / 'analysis.log'))
    print('\nVerification ' + ('PASSED' if all(results) else 'FAILED; see failed stages above.'))
    return 0 if all(results) else 1

if __name__ == '__main__':
    sys.exit(main())
