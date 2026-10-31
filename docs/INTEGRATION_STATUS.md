# Combined gameplay and visual integration

Baseline: Claude gameplay `140ea2489ec8ce19821598c9c54dfc58e6879759` (PR #2), combined with Codex visuals `e9ecddb2de5ea3502e5868378fef5c201f91617e` (PR #1).

This work is isolated on `codex/integration`. Neither working branch nor main is changed. The merge preserves Claude's combat, movement, input, movesets and original tests.

## Actual wiring

- `main.gd` applies `presentation_setup.with_art()` to copies of character resources. Gandalf's `visual_scene` and fireball's `visual_scene` are assigned on the copies. The original .tres resources remain unchanged so gameplay fixtures and tuning have one source of truth.
- Gandalf's VisualRoot auto-binds to its parent Fighter and synchronizes the initial snapshot. Mid-state attach, facing, animation_tick, invulnerability flashing and per-fighter hitstop are handled.
- Each attack maps its actual startup/active/recovery phases onto authored poses. Contact frames are selected during active ticks, rather than distributing all frames evenly across the entire attack.
- Victory keeps a local animation clock because the match stops ticking in RESULT.
- Fireball art is a child of the gameplay projectile. The gameplay object still owns travel, collisions, expiration and rematch cleanup.
- `integrated_effects.gd` maps all 18 GameIds effect IDs, converts duration_ticks to seconds, reconnects on fighter_spawned, clears on rematch and follows/cancels choke/guard/telegraph visuals.
- Vader uses Claude's explicitly temporary renderer. No completed Vader sprite pack exists.

## Verification

The combined runtime at `74b041750b8b29262c5279e24b2b508a74abfc02` passes all 67 tests on Godot 4.3 and 4.5: [GitHub Actions run 41171789661](https://github.com/AndrewRhein/Smash/actions/runs/41171789661). This includes Claude's 61 original tests and six presentation integration tests.

Six new tests cover resource isolation, attachment/rematch, contact-frame timing, hitstop/flashing/victory, effect-ID coverage and effect cleanup. A two-version GitHub Actions workflow imports the combined project and runs the original tests plus the new tests. The first run exposed stale effects on zero-countdown rematches; cleanup now also runs when the first new fighter is spawned, and the regression test passes.

Local Python sprite structural checks pass. No local Godot executable is available. The original human-play/controller/Windows limitations still apply.

## Vader diagnostic

The user clarified that this is a personal, noncommercial project. A new neutral full-body Vader request, with no weapon or combat, was still rejected at output moderation with category `other`.

Latest request ID: `af80e0e8-0414-4f22-99c3-9bb94bf92f43`.

The service supplied no specific cause. It did not identify commercialization or copyright as the reason. There is no local override. A usable existing character asset, or resolution of the service rejection, is still needed to finish Vader's sprites. Do not rename another character or call the placeholder final art.

## Review handoff for Claude

Review this integration branch against gameplay140ea24. Run the 67-test suite on4.3 and4.5, inspect F1 hitboxes against staff contact frames, play through a fireball, choke interruption, invulnerability, victory and rematch. Check the CI result and report any engine errors before merging. Do not modify combat numbers merely to fit a sprite.
