# Local verification

No command here opens, connects to, or modifies Roblox Studio.

From `Scaffolding Tycoon/src`:

```sh
python3 tools/setup.py             # first-time analyzer download; macOS
python3 tools/verify.py            # compilation, tests, build, Roblox analysis
python3 tools/verify.py --tests-only
python3 tools/verify.py --analyze-only
```

From the repository root, prefix the paths with `src/`. Requires Python 3,
official `luau` / `luau-compile`, and `rojo` on PATH. Setup pins Luau LSP
1.70.1 and its Roblox definitions, verifies SHA-256 checksums, and caches
them in `.local/`. Once installed, verification needs no network connection.

All output lives in ignored `src/tools/.local/`, including `analysis.log`,
the generated sourcemap, and the verification place build. The existing
Rojo mappings exclude `src/tools`, so these tools are not shipped in the game.

The runner compiles every `.luau` under client/server/shared. It executes
the Arena collection, carrying, geometry, and companion regression harnesses
against current source. Geometry uses a minimal vector/scene mock; it verifies
the production formulas without pretending to reproduce Roblox physics.

Full analysis uses `luau-lsp analyze --platform=roblox`, the pinned definitions,
and a fresh Rojo sourcemap. The official `luau-analyze` does not accept the
same definition flags. Analysis runs from the repository root so Rojo's
relative module paths resolve correctly. Mock test fragments are compiled and
executed by their harnesses, rather than analyzed as standalone game modules.

A successful build is not a type-check pass. Full verification returns nonzero
if any stage fails, including existing project type errors. `--tests-only`
explicitly excludes full analysis. No diagnostic baseline is silently suppressed.
Existing dynamic require paths and optional-instance type errors may need
separate source fixes; details are in `analysis.log`.

Local tests do not prove physics, replication, DataStore persistence, or live
multiplayer behavior. Gameplay source changes sync through the user's existing
Rojo connection independently of these commands; verification does not gate sync.
