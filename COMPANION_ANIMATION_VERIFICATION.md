# Companion rigs and animation

Implemented in CHAT, place 72056776360977, on 2026-10-27.

- Rigged all 16 ServerStorage.CompanionModels templates and all 16 Workspace.Development.CompanionModelGallery copies, preserving authored parts and world positions.
- Each rig has an anchored transparent CompanionRoot, 14 Motor6D joints, welded decorative parts, an AnimationController/Animator, and two native foot IKControls with knee poles. Other parts are unanchored, massless, and noncolliding.
- Original templates are retained in ServerStorage.CompanionModels_BeforeIK. The existing pre-redesign backup is untouched.
- Atomic model streaming and descendant arrival handling support streamed gallery models and future runtime clones.
- CompanionAnimation runs as cosmetic client presentation from Main.client.luau, independently of the disabled companion ownership/gameplay feature. It never moves the root or grants gameplay effects.
- Animation uses procedural joint poses; no uploaded Animation IDs are required. Existing movement code can move the model with PivotTo and Auto will detect horizontal root movement.

## Model attributes

| Attribute | Values / purpose |
| --- | --- |
| CompanionAnimationEnabled | false resets poses and disables IK; true resumes |
| CompanionAnimationState | Auto (default), Idle, Walk (in-place preview), Attack (looping cosmetic punch) |
| CompanionStride | stride distance, default 0.5 studs |
| CompanionStepHeight | foot lift, default 0.3 studs |
| CompanionWalkSpeed | reference movement speed, default 6 studs/second |

Select a gallery model and set CompanionAnimationState to Walk before pressing Play to preview walking in place. Auto uses idle poses while stationary. Attack is presentation only; gameplay must explicitly select/reset the state when combat is implemented.

## Live verification

- Playtested all 16 gallery models: nonzero idle body offsets, enabled foot IK, and two-segment chains on every model.
- Forced Walk and sampled changing shoulder angles and foot targets over time.
- Added a temporary 0.3-stud step under the left foot: target rose from approximately 7.553 to 7.840 studs; actual foot center reached 7.845 studs. Removed the step afterward.
- Disabled animation: body offset returned to zero and foot IK disabled. Re-enabled successfully.
- Forced Attack: right shoulder pose changed to approximately -1.321 radians. Restored Auto.
- Visually inspected gallery in Play mode: decorative parts remain attached.
- No animation script errors were reported. Existing unrelated asset 203785492 emits asset-type mismatch warnings.
- Returned Studio to Edit mode; temporary test attributes/parts did not persist.

Limitations: short legs support small height corrections (clamped -0.5 to +0.45 studs), not large ledges. Feet remain level rather than matching slope normals. Follow movement, equip/deployment, and combat timing remain pending in the existing feature scaffold. This is local Studio work, not a published experience update.

Reproduction helper: tools/RigCompanions.luau (run its contents in Studio Edit mode). Source: src/client/Features/Companion/CompanionAnimation.luau and startup wiring in src/client/Main.client.luau.
