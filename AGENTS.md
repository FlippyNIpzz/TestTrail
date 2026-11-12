# Project agent instructions

These instructions apply to all future agent chats working in this project and to all project subdirectories. Follow them unless the user explicitly changes them.

## Code and verification

- Write and edit game code in the local project files. Rojo handles syncing to Roblox Studio.
- Do not use Roblox Studio to test or debug code. Do not start Play/Run sessions, run test scripts or command-bar snippets, or use Studio MCP execution tools for code verification.
- Use local compilation, static analysis, mock tests, and Rojo builds as appropriate. Follow `src/AGENTS.md` for the local verification commands.
- State what was checked locally and what still requires user-run Studio testing. Never claim local checks establish live physics, replication, DataStore, or multiplayer behavior.

## Roblox Studio and 3D work

- Use Roblox Studio only to interact with its built-in AI Assistant for managing 3D models and generating or modifying parts within Workspace.
- The Studio AI Assistant is responsible for those scene operations. Do not directly create, edit, move, or delete Studio instances through MCP scripts, the command bar, or manual scene-editing UI.
- Keep Assistant requests within the user's requested scene work and preserve existing authored content outside that scope.
- Do not ask the Studio AI Assistant to test or debug game code as a workaround for the testing restriction.
- If direct interaction with the Studio AI Assistant is unavailable, provide a copy-ready prompt for the user to submit. Do not substitute direct Studio scripting or scene editing.

## Instruction consistency

- These rules replace older project guidance or remembered workflows that call for agent-run Studio inspection, testing, or direct scene edits.
- Keep subdirectory instructions consistent with these boundaries.
