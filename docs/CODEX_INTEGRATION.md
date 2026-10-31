# Realms Rumble: integration notes for Codex (art and presentation)

The gameplay foundation is on `claude/gameplay-core` (base `main` @ `7a42a2e`). Gameplay owns timing, hits, projectiles, invulnerability and results. Presentation only listens. The full contract with exact signatures is in [`GAMEPLAY_API.md`](GAMEPLAY_API.md); this page is the practical checklist.

## Changed and added paths

| Path | Owner | What |
|---|---|---|
| `project.godot` | gameplay | Adds physics layer names and an explicit 60 Hz physics tick. Renderer, resolution and stretch are unchanged |
| `scenes/main.tscn` | shared | Scene skeleton: `ArenaBackground`, `Stage`, `Match`, `Effects`, `DebugOverlay`, `HUD` |
| `scripts/main.gd` | shared | Wiring only (input setup, binding the HUD/effects, F1, Enter rematch) |
| `scripts/fighter.gd` | gameplay | Rewritten: state machine, timeline, contract signals and snapshot |
| `scripts/gameplay/` | gameplay | `match_controller.gd`, `stage.gd`, `projectile.gd`, `combat_math.gd`, `debug_overlay.gd` |
| `scripts/data/` | gameplay | `game_ids.gd` (ID registry), `character_data.gd`, `move_data.gd`, `hitbox_data.gd`, `projectile_data.gd` |
| `scripts/input/` | gameplay | `input_setup.gd`, `player_input.gd`, `input_frame.gd` |
| `data/characters/gandalf.tres`, `vader.tres` | gameplay (Codex may set `visual_scene`) | Movesets and tuning |
| `scripts/presentation/` | **Codex** (temporary placeholders) | `placeholder_fighter_visual.gd`, `placeholder_projectile_visual.gd`, `placeholder_effects.gd`, `placeholder_hud.gd`, `placeholder_arena.gd` |
| `tests/` | gameplay | Runner, 61 tests, `ko_report.gd`, `capture_frames.gd` |
| `docs/GAMEPLAY_API.md`, `docs/TEST_REPORT.md`, this file, `README.md` | gameplay | Documentation |

Nothing under `art/` was created or edited. No concept art or final assets were generated.

## Animation IDs to author

These come from a single source of truth: `scripts/data/game_ids.gd`. Each move's `animation_id` in the `.tres` files is validated against that file.

* Shared, for both characters: `idle`, `walk`, `run`, `jump`, `fall`, `hurt`, `knockback`, `defeat`, `victory`
* Gandalf: `staff_strike`, `heavy_staff`, `lightning`, `fireball`, `magic_push`
* Vader: `saber_slash`, `heavy_saber`, `force_push`, `force_choke`, `force_guard`

Gameplay durations (startup/active/recovery) are in the move table in `GAMEPLAY_API.md` §7. Frame counts are up to you. `animation_requested(id, duration_ticks, loop)` tells you how long the gameplay timeline is, so stretch the clip or hold its last frame. The active window begins `startup_ticks` into the clip; read `move_tick` from the snapshot if you want to key the impact frame exactly.

## Effect IDs to author

`hit_spark`, `guard_block`, `blast_ko`, `respawn`, `double_jump`, `projectile_fizzle`, `choke_release`, `staff_swing`, `heavy_staff_swing`, `lightning_telegraph`, `lightning_bolt`, `fireball_cast`, `magic_push`, `saber_swing`, `heavy_saber_swing`, `force_push`, `force_choke`, `force_guard`. Payload fields are listed in `GAMEPLAY_API.md` §8. `force_choke` fires twice: once at move start (telegraph) and once on a successful grab, when the payload contains `victim_id`.

## Attaching final fighter art (SpriteFrames)

1. Build a scene, e.g. `scenes/presentation/gandalf_visual.tscn`, with a `Node2D` root and an `AnimatedSprite2D` child. Register one SpriteFrames animation per ID above.
2. Use the adapter script from `GAMEPLAY_API.md` §10 (or your own) on the root. It listens to `animation_requested` and `facing_changed`, syncs from `get_presentation_snapshot()` in `_ready()`, freezes on `hitstop_remaining_ticks > 0`, and warns once per missing ID.
3. Set `visual_scene` in `data/characters/gandalf.tres` (inspector: *CharacterData → visual_scene*). `Fighter` instances it as the `VisualRoot` child. With no scene set, it falls back to the placeholder.
4. Align art so the **feet center is at (0, 0)** of the VisualRoot and the character faces **right** when `scale.x = 1`. Flip by setting the VisualRoot's (or the sprite's) `scale.x`/`flip_h`. Never flip the Fighter.
5. You can scale and offset art freely. Hurtboxes and hitboxes stay as authored, which is tested. If the art's proportions change a lot, ask gameplay to adjust `hurtbox`/hitbox offsets in the `.tres` rather than resizing collision from sprites. Press F1 in-game to compare.

I verified this flow during development: a scene containing only an `AnimatedSprite2D` whose SpriteFrames had just `idle` was attached via `visual_scene`. It ran without errors, warned once per missing ID, and flipped only the VisualRoot.

Projectiles work the same way: set `ProjectileData.visual_scene` on the fireball (`gandalf.tres → moves[3] → projectiles[0]`). The visual's parent is the `Projectile`; read `velocity`, `data.radius` and `ticks_remaining` from it.

## Other presentation nodes

| Node in `main.tscn` | Replace with | Notes |
|---|---|---|
| `ArenaBackground` (`PlaceholderArena`) | Final arena art | Platform collision is in `Stage.PLATFORMS`; draw art to match those rects (main platform top y = 546). Keep z below fighters |
| `Effects` (`PlaceholderEffects`) | VFX system | `bind(match)` connects `fighter_spawned` → each fighter's `effect_requested`. Keep it above the arena; it is currently z_index 100 |
| `HUD` (`PlaceholderHud`, CanvasLayer) | Final HUD | Uses `damage_changed`, `stocks_changed`, `match_state_changed`, `match_ended`, `MatchController.countdown_remaining`/`winner_player_id`. Rebind on `fighter_spawned` (fighters are recreated on rematch) |
| `DebugOverlay` | Keep | Gameplay debug tool (F1) |

If you rename or replace these nodes, update the `@onready` paths in `scripts/main.gd`. `main.gd` expects `bind(match_controller)` on the effects and HUD nodes; keep that method or change the wiring.

## Required scene structure

* `Main` must contain a `Stage` node (script `Stage`) and a `Match` node (script `MatchController`). Fighters and projectiles are created at runtime under `Match`. Do not place them in the scene.
* Each Fighter gets `BodyShape` (gameplay) and `VisualRoot` (presentation) children at runtime.

## Remaining work and open items

* **Final art and presentation (Codex):** SpriteFrames for all IDs above, VFX for every effect ID, arena art, HUD, sound.
* **Playtesting:** none has been done with humans or physical controllers (see `TEST_REPORT.md`). Tuning is a first pass.
* **Design follow-ups worth discussing:** there is no recovery special or ledge grab (only a double jump), fireballs ignore terrain, and keyboard up and jump share a key (as in the starter), so aiming up on the keyboard also jumps.
* Character select and menus are out of scope. The match starts straight into a 1.5 s countdown.

## Departures from the handoff and why

* **Snapshot has extra fields** (`animation_id`, `animation_tick`, `animation_duration_ticks`, `invulnerable_remaining_ticks`, `aim_angle_deg`) beyond the required ones, to make mid-state attach and invulnerability flashing straightforward. All required fields are present with the documented types.
* **Gameplay-internal signal** `Fighter.projectile_requested` exists alongside the contract signals. It is not for presentation.
* **`MatchController` signals** (`fighter_spawned`, `match_state_changed`, `match_ended`) are additions the handoff left to the implementation.
* **InputMap actions are registered at runtime** by `InputSetup.ensure_actions()` rather than written into `project.godot`. They are still real InputMap actions, existing actions are never overwritten, and moving them into `project.godot` later needs no code change.
* **Force push is aimable** (±25°), like the lightning, to satisfy "directional". The lightning is "brief directional" through the same aim system.
* **Post-hit invulnerability:** there is no general post-hit invulnerability, because hit-once per attack instance already prevents repeat hits and general invulnerability would remove combos. A choke release grants grab-only immunity. Respawn grants full invulnerability.
* **Branch name** is the handoff's `claude/gameplay-core`. It did not exist before this work.
