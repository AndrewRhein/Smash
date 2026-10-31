# Realms Rumble: Claude gameplay implementation prompt

You are the gameplay engineer for Realms Rumble, a Godot 4 local two-player platform fighter. Work in https://github.com/AndrewRhein/Smash. Implement working code, tests, and a reviewable pull request; do not stop at advice or a design document.

## Source of truth and collaboration

The user is collaborating with ChatGPT/Codex on this same repository. Your assignment is the gameplay foundation: movement, combat, moveset data, match flow, input, and tests. Codex owns final pixel-art assets, animation asset assembly, arena artwork, presentation, and final integration. This division is a practical assignment, not a benchmark claim about model capabilities.

First inspect the current default branch, repository instructions, open pull requests if accessible, and this document. Record your base commit. Create a feature branch `claude/gameplay-core` (choose a new suffix if that branch already belongs to ongoing work). Do not force-push, merge your own PR, overwrite another contributor's work, or commit directly to main. If the repo has advanced since this prompt, preserve the newer work and describe any necessary adaptations.

The initial repository seed contains the starter ZIP's source files unchanged at repository root: `project.godot`, `scenes/main.tscn`, `scripts/main.gd`, `scripts/fighter.gd`, and `README.md`. The ZIP's concept PNG is not included in this text-only seed; it is reference art, not a playable sprite asset. No finished sprite animations currently exist. Do not claim the visual asset milestone is complete.

If you cannot access GitHub or execute code, state the specific limitation. Continue with the source files the user supplies. Deliver a full source ZIP with relative paths and a unified patch against the recorded baseline when possible. Include all new resources and tests. Never provide only isolated code snippets or pretend commits/tests happened. If you have no source access, request the starter ZIP before implementing; do not invent the existing code.

## Existing implementation and problems to fix

This is a small scaffold, not an established framework. `main.gd` constructs four solid platforms, two fighters, labels, and simple effects in code. `fighter.gd` extends CharacterBody2D and uses direct key polling, a capsule, and vector placeholder drawings. Existing controls: P1 A/D, W, F, G; P2 arrows, Up, K, L. There are three stocks, damage percentage, immediate distance-based melee, and basic respawning.

Static inspection found these issues; reproduce and verify them rather than treating them as tested runtime findings:

- Horizontal movement immediately moves velocity back toward the input speed after a hit; there is no hitstun to preserve knockback.
- Attacks apply hits immediately with a distance check; there are no startup/active/recovery phases or true hitboxes.
- Holding attack automatically retriggers after cooldown; define intentional press/buffer behavior.
- Both characters effectively share the same two attacks despite different labels.
- `lose_stock()` leaves an eliminated fighter active and outside bounds, allowing repeated decrements and repeated game-over signals.
- Game-over only changes title text; movement and combat continue and there is no rematch.
- Direct keyboard polling prevents a clean controller/rebinding layer.
- There is no animation system, top blast zone, or explicit match state.
- Effects are drawn on the parent underneath its children; their visibility needs checking against the opaque background.

Preserve the recognizable prototype and useful existing behavior, but refactor these small scripts where needed. Do not preserve flawed architecture merely for line-count stability.

## Ownership and scope

You may edit `scripts/fighter.gd`, `scripts/main.gd`, `scenes/main.tscn`, `project.godot`, README controls/setup sections, and add `scripts/gameplay/`, `scripts/data/`, `scripts/input/`, `data/characters/`, `tests/`, and gameplay documentation. Keep broad presentation redesign out of these edits. Put a small temporary presentation adapter under `scripts/presentation/` if needed for the contract below.

Do not replace or generate final artwork, edit `art/`, create concept illustrations, add online multiplayer, accounts, AI opponents, monetization, or a general-purpose engine framework. Do not add paid dependencies. Do not spend this milestone on menus or character selection beyond a functional start/rematch flow. Coordinate incompatible contract changes through documentation before changing another contributor's implementation.

The deliverable is a playable Gandalf-versus-Darth-Vader match with honest temporary graphics, architecture ready for final animations, and reproducible gameplay tests.

## Technical baseline

Use typed GDScript and Godot 4, Compatibility renderer, 1280 by 720. Start from the starter's documented Godot 4.3-or-newer baseline. Select and record the exact Godot version you actually validate, avoid undocumented newer-only APIs, and report whether minimum-version compatibility was tested. All runtime resources must be local and paths portable to Windows. Use 60 Hz physics; express attack timing in integer physics ticks. Keep runtime logic independent from rendered animation playback and display frame rate.

Prefer a small number of focused classes/resources over a monolith or elaborate framework. A simple explicit fighter state machine, a match controller, typed move resources, and an input adapter are enough. Use constants/enums for state and collision layers. Add comments for timing, coordinate conventions, and non-obvious behavior.

## Gameplay requirements

1. Movement: responsive horizontal acceleration/deceleration, air control, variable-height jump, double jump, short coyote-time and jump buffering, and fast fall. Expose tuning constants. Prevent jump buffers from leaking through respawn or match end. Upper platforms should support one-way landing and deliberate drop-through; the main platform stays solid. Avoid broad collision disabling that makes unrelated ground disappear.

2. Combat: light, heavy, and three distinct specials per character. Every move must define startup, active, and recovery durations; recovery blocks further attacks unless an explicit cancel rule permits one. Use local-space hitbox rectangles/circles with facing-aware offsets and distinct hurtboxes. An attack instance hits a target only once unless explicitly authored as multi-hit. Do not use visible sprite size as collision geometry.

3. Hits: percentage damage, documented damage-scaled knockback with angle/base/growth tuning, hitstun, brief hitstop, controlled post-hit invulnerability where appropriate, and clear interruption rules. Movement must not erase knockback during hitstun. Define whether hitstop freezes movement, timers, projectiles, and animation cues; implement consistently. Do not let global time changes break match timers or rematch. Resolve simultaneous collisions in a documented, predictable way rather than accidental player processing order.

4. Stocks/match: three stocks, configurable rectangular blast bounds on all four sides, one stock loss per elimination, respawn with cleared combat/projectile ownership state and visible temporary invulnerability, one terminal result, and a working rematch. Eliminated fighters cannot attack or lose negative stocks. Handle simultaneous final-stock KOs with a documented draw outcome. A rematch restores all timers, actors, stocks, damage, and UI.

5. Input: InputMap actions and a per-player adapter that can also consume scripted test input. Preserve original movement/light/special bindings; add nonoverlapping heavy, two additional specials, and drop-through bindings. Support two keyboard players and two independently assigned controllers without one controller moving both fighters. Include reasonable dead zones. Document actual controls. A full rebinding menu is unnecessary. Note keyboard ghosting as a hardware limitation only if relevant to testing.

6. Feedback: functional damage/stocks labels, match status, winner/draw, rematch instruction, basic attack/hit effects, and toggleable hitbox/hurtbox debug drawing. Ensure effects render above the background. Keep all temporary visual assets clearly labeled.

## Moveset data

Implement custom Resources or a similarly small validated data format, not character-specific branches scattered through the controller. Define stable character IDs `gandalf` and `vader`. Each move needs: stable ID, animation ID, startup/active/recovery ticks, damage, knockback angle/base/growth, hitstun, optional cooldown, movement lock/cancel policy, and one or more timed hitbox or projectile definitions. Document angle conventions and mirror behavior. Validate missing/negative timings, unknown effect IDs, and invalid references.

Provide these coherent first-pass moves; adjust numerical tuning through playtesting:

| Character | Move ID | Behavior | Animation ID |
|---|---|---|---|
| Gandalf | light | Quick staff strike | staff_strike |
| Gandalf | heavy | Slower, stronger staff sweep | heavy_staff |
| Gandalf | special_1 | Telegraph, then brief directional lightning | lightning |
| Gandalf | special_2 | Traveling fireball with finite lifetime | fireball |
| Gandalf | special_3 | Short-range magical push emphasizing knockback | magic_push |
| Vader | light | Quick lightsaber slash | saber_slash |
| Vader | heavy | Committed heavy saber strike | heavy_saber |
| Vader | special_1 | Directional Force push | force_push |
| Vader | special_2 | Finite, short-range interruptible Force choke | force_choke |
| Vader | special_3 | Brief defensive Force window with cooldown | force_guard |

Force choke must have a bounded duration, range checks, cleanup on interruption/death/rematch, and no permanent control lock. Force guard must have explicit timing and protected directions/damage types; it must not permit indefinite invulnerability. For projectiles define owner, collision, lifetime, damage attribution, and cleanup. Avoid unblockable loops and unlimited stuns.

## Shared presentation contract, version 1

Implement and document this seam so Codex can replace visuals without rewriting combat. Preserve these semantic names; document exact GDScript signatures in `docs/GAMEPLAY_API.md`.

- Fighter root position is ground contact/feet center. Godot coordinates: positive X right, positive Y down. Facing is +1 right or -1 left. Hitboxes use local authored offsets mirrored around the fighter root.
- A `VisualRoot` Node2D child contains presentation only. Art scale and sprite offsets must not change physics/hurtboxes. Do not flip the entire CharacterBody2D with negative scale.
- Emit `animation_requested(animation_id: StringName, duration_ticks: int, loop: bool)` on animation-state transitions, not every tick. Duration 0 means looping/state-driven locomotion; positive duration specifies the gameplay timeline the presentation should follow.
- Emit `facing_changed(facing: int)` when facing changes.
- Emit `effect_requested(effect_id: StringName, world_position: Vector2, direction: Vector2, payload: Dictionary)` for VFX. Document payload fields; use plain numeric/string/vector values, not hidden node dependencies.
- Emit `damage_changed(damage: float)`, `stocks_changed(stocks: int)`, and `eliminated(player_id: int)` for match/HUD integration. Match owns winner determination and terminal state.
- Expose a read-only presentation snapshot getter containing character_id, player_id, state, facing, velocity, grounded, current_move_id, move_tick, damage, stocks, invulnerable, and hitstop_remaining_ticks. This lets the animation adapter synchronize and freeze/resume correctly even after it is attached mid-state. Document exact types and inactive values.
- Gameplay owns hit timing, state transitions, projectiles, invulnerability, and results. Never wait for `animation_finished` to activate a hitbox or release recovery.
- Shared animation IDs: idle, walk, run, jump, fall, hurt, knockback, defeat, victory, plus the move-specific IDs above. Explain the speed thresholds for walk/run and priorities for hurt/knockback/attacks. Death and victory visuals must not re-enable gameplay.
- The placeholder adapter must tolerate missing art/animation IDs and log a useful warning once. A later AnimatedSprite2D/SpriteFrames adapter should require only asset registration and presentation changes.
- Define a single source of truth for animation IDs and document it. Do not assume that a requested visual frame count equals attack duration. Final art may use 6–12 frames while gameplay timing differs.

These are proposed integration requirements to implement, not APIs that already exist in the starter. If an exact detail is impractical, document a minimal replacement and its migration mapping rather than silently diverging.

## Verification

Inspect tools and run the project with a real Godot executable if available. Fix parser/import/runtime errors. Include a dependency-free headless test runner or a small justified test dependency with exact setup. Test real gameplay code with scripted inputs, not duplicate formulas in a separate mock system.

Cover: attacks do no damage before startup or after active frames; a single hitbox cannot repeatedly hit a target; mirrored hitboxes behave correctly; more damage increases knockback under the same conditions; hitstun preserves impulse; invulnerability blocks damage; cooldowns and recovery hold; jump buffering and double-jump reset; projectile cleanup; Force choke interruption; guard expiry; one stock loss per blast exit; no negative stocks; exactly one match result; simultaneous final KOs; and complete rematch reset. Add input-routing checks for distinct players.

Run an import/parse check and a headless scene smoke test as well as behavior tests. A passing headless launch is not proof of enjoyable controls or working controllers. If interactive execution is possible, exercise a full match and rematch, platform drop-through, both facings, every special, and visual feedback. Record what was actually observed. Distinguish automated pass, manual pass, and untested. Do not claim hardware-controller or Windows testing without doing it.

## Workflow and deliverables

Work in sensible increments: fix match lifecycle/hitstun; establish input and combat data; implement the two movesets; connect the presentation seam; add regression tests; tune and document. Keep each increment runnable. Do not wait for final art. Give concise progress updates and proceed independently with routine technical decisions.

Deliver:

1. A feature branch and pull request against main, or source ZIP/patch if GitHub writes are unavailable.
2. Fully integrated source/resources for the playable match, not disconnected modules.
3. `docs/GAMEPLAY_API.md` with the actual presentation contract, data schema, coordinate conventions, state/timing rules, input actions, and a minimal adapter example.
4. `docs/TEST_REPORT.md` with Godot version, commands, actual outcomes, manual coverage, and untested limitations.
5. `docs/CODEX_INTEGRATION.md` listing changed paths, animation/effect IDs, how to attach final SpriteFrames, required scene nodes, remaining work, and any departures from this prompt.
6. README updates with installation, controls, test commands, debug toggle, and rematch instructions.

Keep the PR description concise: concrete behavior changes, testing evidence, limitations, and any integration risks. Report branch name, base and final commit IDs, and PR URL. Do not export a Windows build unless the engine/export templates are available and export succeeds; this is optional and secondary to source correctness. Never commit `.godot/`, credentials, local caches, or build binaries.

Begin by inspecting the repository, then implement. Do not respond with only a plan.
