# Local Luau verification

- Edit code in project source files only. Rojo handles syncing. Follow the repository-root `AGENTS.md`: Roblox Studio may be used only to interact with its AI Assistant for Workspace models and parts, never for code testing, debugging, or direct scene edits.
- Use `--!strict` for new production Luau modules.
- From `src`, run `python3 tools/verify.py` before finishing code changes. From the repository root use `python3 src/tools/verify.py`.
- This compiles all production/test Luau, runs mock-based regression suites, builds the Rojo project, and runs Roblox-aware type/lint analysis. It never opens Studio.
- `python3 tools/verify.py --tests-only` runs compilation, tests, and build without full analysis. Do not present this as a clean type check.
- `python3 tools/verify.py --analyze-only` runs the analyzer; it writes the complete report to `tools/.local/analysis.log` and returns failure on diagnostics. Existing diagnostics must be reported, not hidden or silenced with `any`/`nocheck` merely to pass.
- The official `luau` CLI executes tests. `luau-compile` checks syntax. Roblox-aware checking uses the project-local `luau-lsp analyze`, pinned Roblox definitions, and a fresh Rojo sourcemap. Do not pass `--defs` to the official `luau-analyze`.
- Tooling setup: `python3 tools/setup.py` downloads the pinned macOS analyzer and definitions with checksum verification. `luau`, `luau-compile`, Python 3, and `rojo` must be on PATH.
- Tool downloads and generated artifacts stay under ignored `tools/.local`, outside the Rojo source mappings. Do not modify the parent Rojo config for tooling.
- Mock tests execute actual source with simulated Roblox dependencies. Passing them does not establish physics, replication, DataStore, or live multiplayer behavior.
