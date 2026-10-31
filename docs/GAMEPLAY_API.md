# Realms Rumble: gameplay API and presentation contract (v1)

This document describes what is **actually implemented** on `claude/gameplay-core`.
It is the contract between gameplay (`scripts/fighter.gd`, `scripts/gameplay/`,
`scripts/data/`, `scripts/input/`, `data/characters/`) and presentation
(`scripts/presentation/` and the final art that Codex adds).

Validated engine: **Godot 4.3-stable** (minimum) and **Godot 4.5-stable**. See `docs/TEST_REPORT.md`.

---

## 1. Architecture at a glance

| Piece | File | Role |
|---|---|---|
| `Fighter` (CharacterBody2D) | `scripts/fighter.gd` | Movement, explicit state machine, move timeline, hit reception, presentation signals and snapshot |
| `MatchController` (Node2D) | `scripts/gameplay/match_controller.gd` | Fixed tick order, input sampling, hit collection and resolution, projectiles, choke holds, blast KOs, result, rematch |
| `Stage` (Node2D) | `scripts/gameplay/stage.gd` | Platforms (collision only), spawn points, blast bounds, physics layer constants |
| `Projectile` (Node2D) | `scripts/gameplay/projectile.gd` | Owned projectile state; moved by the match |
| `CombatMath` | `scripts/gameplay/combat_math.gd` | Knockback, hitstun and hitstop formulas, overlap tests |
| `DebugOverlay` | `scripts/gameplay/debug_overlay.gd` | Hitbox/hurtbox drawing, toggled with F1 |
| `CharacterData` / `MoveData` / `HitboxData` / `ProjectileData` | `scripts/data/*.gd` | Typed resources with `validate()` |
| `GameIds` | `scripts/data/game_ids.gd` | **Single source of truth** for character, move, animation, effect and damage-type IDs |
| `PlayerInput` / `InputFrame` / `InputSetup` | `scripts/input/*.gd` | Per-player adapter over InputMap actions, plus a scripted mode for tests |
| Placeholder presentation | `scripts/presentation/*.gd` | Temporary vector art, VFX, HUD and arena |

Scene (`scenes/main.tscn`):

```
Main (main.gd)
├── ArenaBackground   (PlaceholderArena, z_index -100)   ← presentation, replaceable
├── Stage             (Stage)                            ← gameplay geometry
├── Match             (MatchController)
│   ├── Projectiles   (created at runtime)
│   └── Fighter1_gandalf / Fighter2_vader (created at runtime, re-created on rematch)
│       ├── BodyShape (CollisionShape2D capsule, terrain only)
│       └── VisualRoot (PlaceholderFighterVisual or CharacterData.visual_scene)
├── Effects           (PlaceholderEffects, z_index 100)  ← presentation, replaceable
├── DebugOverlay      (DebugOverlay, z_index 200)
└── HUD               (PlaceholderHud, CanvasLayer)      ← presentation, replaceable
```

## 2. Coordinates and facing

* Godot 2D: **+X right, +Y down**. Units are pixels, px/s and px/s².
* A fighter's **origin is the feet center** (ground contact point). The main platform's top surface is y = 546.
* `facing` is `+1` (right) or `-1` (left). The CharacterBody2D is **never** flipped with a negative scale.
* Hurtboxes (`CharacterData.hurtbox`, a `Rect2`) and hitbox/projectile offsets are authored **facing right** relative to the origin. At runtime `x` is mirrored: a point is `origin + Vector2(local.x * facing, local.y)`, and a rect becomes `x' = -(x + w)` when facing left.
* **Knockback angle:** degrees. 0 = straight forward (in the attacker's or projectile's direction), 90 = straight up, negative = downward. World direction = `Vector2(cos(a) * sign, -sin(a))`.
* **Aim** (aimable moves only: Gandalf lightning, Vader Force push): when the move starts, holding up adds `+aim_angle_deg`, holding down adds `-aim_angle_deg`. Hitbox offsets rotate about `aim_pivot` (in facing-right space) and the aim is added to the knockback angle. Aimable moves must use circle hitboxes (validated).
* Collision geometry never comes from sprite size. `VisualRoot` transform, scale and offsets have no effect on physics or combat (tested).

Physics layers (`Stage.LAYER_*`): 1 `world` (solid main platform), 2 `fighters` (fighters never collide with each other), 3 `one_way_platforms`. Drop-through clears **only** the layer-3 bit of the fighter's mask for 12 ticks.

## 3. Tick model

* Everything runs at **60 Hz** (`physics/common/physics_ticks_per_second=60`) and **all gameplay timing is in integer ticks**. Rendering frame rate and animation playback never affect gameplay. `Engine.time_scale` is never touched.
* Fighters have **no `_physics_process`**. `MatchController.step()` is the only driver: it is called from `_physics_process` when `auto_step` is true, or directly by tests.

Order inside one `step()` while `PLAYING`:

1. Sample every `PlayerInput` once (rising edges are computed here).
2. `Fighter.physics_tick(frame)` for each fighter in player-id order: state logic, movement, `move_and_slide`, move timeline, projectile spawn requests.
3. Projectiles move. Expired or out-of-bounds projectiles are removed.
4. **Hit collection**: every active hitbox and projectile is tested against every other fighter's hurtbox using post-movement positions, **before any hit is applied**.
5. **Hit application**: at most one hit per victim per tick (priority below). All strikes apply first, then grabs.
6. Force-choke holds update (pulse damage, range checks, release).
7. Blast-bounds check (stock loss), then the result check.

During `COUNTDOWN` (90 ticks by default) fighters tick with a neutral input frame so they settle onto platforms. Inputs are still sampled, so a button held through the countdown is **not** treated as a press. `RESULT` freezes all gameplay.

### Simultaneous-hit priority (deterministic)

For each victim, all overlapping sources are "consumed": the attack instance records the victim, and projectiles are destroyed. Only the best source applies, chosen by:
strikes before grabs → higher damage → lower attacker `player_id` → melee before projectile → lower hitbox index.

**Trades:** if A and B hit each other on the same tick, both hits apply. Each fighter's hitstop becomes `max(incoming, outgoing)`, so the result does not depend on processing order. A grab only succeeds if its user was not interrupted by a strike on the same tick.

## 4. Fighter state machine

`Fighter.State`: `IDLE, WALK, RUN, JUMP, FALL, ATTACK, HITSTUN, HELD, KO, ELIMINATED, VICTORY`.
Snapshot names: `&"idle" &"walk" &"run" &"jump" &"fall" &"attack" &"hitstun" &"held" &"ko" &"eliminated" &"victory"`.

* **Free states** (`IDLE/WALK/RUN/JUMP/FALL`) are derived every tick from `grounded` and velocity. Grounded with |vx| < 20 px/s is IDLE, < 220 is WALK, otherwise RUN. Airborne with vy < 0 is JUMP, otherwise FALL. On a stick, partial deflection gives a lower target speed, so the fighter walks.
* **ATTACK**: runs the move timeline (below). Facing is locked. Horizontal control follows the move's `movement_policy`: FREE (full), SLOWED (35% target speed) or ROOTED (no input; friction/air drag only).
* **HITSTUN**: input is ignored and knockback is preserved. Only drag (air 1100 px/s², ground friction 1800 px/s²) and gravity act. When it reaches 0 the fighter returns to a free state.
* **HELD**: the Force-choke victim. Velocity is zero, there is no gravity and input is ignored. Released by the match (see §6).
* **KO**: the fighter has left the blast bounds and has stocks left. It is hidden and inert for 60 ticks, then respawns.
* **ELIMINATED**: no stocks left. Hidden and inert for the rest of the match. It cannot attack, be hit or lose more stocks.
* **VICTORY**: set on the winner when the match ends. Inert, so the victory visuals can never re-enable gameplay.

**Interruption rules:** a hit (or being grabbed) always ends the current move, including a choke hold in progress. There is no armor. A move in recovery can only be cancelled into its `cancel_into` moves (both lights can cancel into specials, and only after connecting). Recovery otherwise blocks every attack.

## 5. Timing rules

| Rule | Value | Notes |
|---|---|---|
| Attack input | rising edge only | Holding a button never re-triggers |
| Attack buffer | 6 ticks | A press during the last 6 ticks of recovery/hitstop starts on the first free tick. Same-tick priority: special_1 > special_2 > special_3 > heavy > light |
| Jump buffer | 6 ticks | Cleared on hit, grab, KO, respawn and match end |
| Coyote time | 6 ticks | Grounded jump after walking off a ledge; does not consume the air jump |
| Air jumps | 1 | Restored on landing and respawn |
| Variable jump | release while rising caps vy at `-jump_release_velocity` (260) | A buffered press that has already been released becomes a short hop |
| Fast fall | press down while airborne and rising slower than 120 px/s | Max fall speed becomes `fast_fall_speed` |
| Drop-through | press down while standing on a one-way platform | 12 ticks with the one-way layer masked out; the solid main platform cannot be dropped through |
| Move timeline | startup `[0, s)`, active `[s, s+a)`, recovery `[s+a, total)` | `move_tick` is 0 on the tick the move starts; the fighter is free on the tick `move_tick` reaches `total` |
| Hitbox timing | `start_tick`/`duration_ticks` relative to the first active tick | Validation guarantees hitboxes never exist in startup or recovery |
| Hit once | per attack instance per victim | Multi-hit only when `rehit_interval_ticks > 0`, counted in the attacker's move ticks |
| Damage | `+move.damage` percent | |
| Knockback | `(base + growth * damage_after_hit) / victim.weight` px/s | `CombatMath.knockback_magnitude` |
| Hitstun | `move.hitstun_ticks + floor(kb * 0.02)`, max 70 | |
| Hitstop | `2 + floor(damage * 0.4)`, max 10; guard block 4 | Applies to the victim and to a melee attacker |
| Respawn | 60 ticks after KO, then 120 ticks of invulnerability | Flashing is visible in the placeholder; `invulnerable` is in the snapshot |
| Post-hit invulnerability | none in general | Hit-once per instance prevents juggling repeats. After a choke there is 90 ticks of **grab** immunity only |

**What hitstop freezes:** for the affected fighter only, everything is frozen: position, velocity, move timeline, hitstun, invulnerability, cooldowns, buffer expiry and `animation_tick`. Presses during hitstop are still recorded into the buffers. **Not frozen:** other fighters, projectiles, choke-hold checks, the match tick, countdown and respawn timers. Presentation should freeze the fighter's animation while `hitstop_remaining_ticks > 0`.

## 6. Specials with special rules

**Projectiles (Gandalf fireball).** Owner: the spawning fighter. Damage and knockback are attributed to its `player_id`. It spawns on the active tick given by `ProjectileData.spawn_tick`, at `offset` mirrored by the owner's facing, with `velocity` (540 px/s) and a 75-tick lifetime. It collides only with opposing hurtboxes (circle, r = 14) and ignores terrain. It is destroyed on its first hit or block, when its lifetime ends (`projectile_fizzle` effect), when it leaves the blast bounds, when its owner loses a stock, at match end and on rematch. Knockback is mirrored by the direction it was fired. Projectiles are not frozen by hitstop. The 80-tick cooldown means one fireball at a time.

**Force choke (Vader special_2, `special_behaviour = &"choke"`).** Startup 12 ticks. A GRAB circle is live for the first 8 active ticks. If nothing is grabbed, the move skips straight to its 20-tick recovery (whiff). If it grabs, the victim enters `HELD` for the rest of the 54-tick active window and takes 2% every 12 held ticks. When the active window ends the victim is launched with the move's knockback (70°). The hold breaks early, **without** a launch, if Vader is hit, grabbed or KO'd; if the victim is hit or KO'd; if the root distance exceeds 240 px; on rematch; or if any hold exceeds `Fighter.MAX_HELD_TICKS` (120) as a failsafe. After any release the victim gets 90 ticks of grab immunity, and the move has a 150-tick cooldown, so it cannot loop.

**Force guard (Vader special_3, `&"guard"`).** Startup 3, active 24, recovery 16, cooldown 120. During the active window only, hits whose `damage_type` is `magic` or `projectile` and whose source is on Vader's **front** side are negated. Projectiles are destroyed and a `guard_block` effect is emitted. Melee (staff and saber) and anything from behind still hit. It cannot be held indefinitely, and validation requires a guard to have a cooldown.

**Lightning (Gandalf special_1).** A 20-tick telegraph (`lightning_telegraph` effect at move start), then a 4-circle bolt reaching about 225 px for 8 active ticks (`lightning_bolt` effect). It can be aimed ±28°.

## 7. Data schema

All data lives in `data/characters/gandalf.tres` and `data/characters/vader.tres`, which can be edited in the Godot inspector. `MatchController.setup()` calls `CharacterData.validate()` and refuses invalid data, reporting a `push_error` for each problem.

**`CharacterData`**: `id` (`&"gandalf"`/`&"vader"`), `display_name`, `hud_color` (placeholder only), `visual_scene: PackedScene` (optional VisualRoot), `hurtbox: Rect2`, `body_radius`, `body_height`, `weight`, and movement tuning (`max_speed, ground_accel, ground_decel, air_accel, air_decel, gravity, max_fall_speed, fast_fall_speed, jump_velocity, double_jump_velocity, jump_release_velocity, air_jumps`). `moves: Array[MoveData]` must contain each of `light, heavy, special_1, special_2, special_3` exactly once.

**`MoveData`**: `id`, `animation_id`, `startup_ticks (≥1)`, `active_ticks (≥1)`, `recovery_ticks (≥0)`, `damage`, `damage_type` (`melee|magic|projectile`), `knockback_angle_deg`, `knockback_base`, `knockback_growth`, `hitstun_ticks`, `cooldown_ticks` (counted from move start; 0 = none), `movement_policy` (`FREE|SLOWED|ROOTED`), `cancel_into: Array[StringName]`, `cancel_requires_hit`, `aimable`, `aim_angle_deg`, `aim_pivot`, `hitboxes: Array[HitboxData]`, `projectiles: Array[ProjectileData]`, `start_effect_id`, `active_effect_id`, `special_behaviour` (`""|choke|guard`). Choke group: `whiff_to_recovery`, `hold_pulse_damage`, `hold_pulse_interval_ticks`, `hold_max_range`, `grab_immunity_ticks`. Guard group: `guard_damage_types`.

**`HitboxData`**: `shape` (`RECT|CIRCLE`), `kind` (`STRIKE|GRAB`), `offset`, `size` (rect), `radius` (circle), `start_tick`, `duration_ticks` (0 = until the end of the active phase), `rehit_interval_ticks` (0 = once per instance).

**`ProjectileData`**: `spawn_tick` (relative to the first active tick), `offset`, `velocity` (px/s, facing right), `lifetime_ticks`, `radius`, `visual_scene` (optional).

**Validation rejects:** startup or active below 1, negative recovery, cooldown or hitstun, negative damage or knockback, unknown animation, effect, damage-type or behaviour IDs, hitboxes or projectile spawns outside the active window, non-positive shapes, aimable non-circle hitboxes, GRAB hitboxes on non-choke moves, chokes without a GRAB hitbox, guards without damage types or a cooldown, moves with no hitbox or projectile (except guard), `cancel_into` references to missing moves, duplicate or missing slots, and an unknown character ID.

### Shipped first-pass moves

Ticks are startup/active/recovery (total). KO% is measured by `tests/ko_report.gd` from mid-stage against a victim that drifts back toward the stage and double-jumps once.

| Character | Move | Animation | Ticks | Dmg | Type | Angle / base / growth | Hitstun | Cooldown | Policy | ≈KO% |
|---|---|---|---|---|---|---|---|---|---|---|
| Gandalf | light | `staff_strike` | 5/4/12 (21) | 5 | melee | 35° / 240 / 3.2 | 10 | – | SLOWED | 290 |
| Gandalf | heavy | `heavy_staff` | 16/6/26 (48) | 13 | melee | 40° / 420 / 7 | 16 | – | ROOTED | 120 |
| Gandalf | special_1 | `lightning` | 20/8/24 (52) | 10 | magic | 35° / 320 / 4.2 (aim ±28°) | 18 | 70 | ROOTED | 115 |
| Gandalf | special_2 | `fireball` | 14/2/20 (36) | 8 | projectile | 30° / 260 / 3.6 | 14 | 80 | SLOWED | 205 |
| Gandalf | special_3 | `magic_push` | 9/5/22 (36) | 4 | magic | 32° / 480 / 5.4 | 14 | 50 | ROOTED | 105 |
| Vader | light | `saber_slash` | 6/4/13 (23) | 6 | melee | 40° / 250 / 3.4 | 11 | – | SLOWED | 275 |
| Vader | heavy | `heavy_saber` | 20/6/30 (56) | 16 | melee | 38° / 420 / 6.2 | 18 | – | ROOTED | 95 |
| Vader | special_1 | `force_push` | 12/6/24 (42) | 3 | magic | 34° / 460 / 4 (aim ±25°) | 14 | 60 | ROOTED | 120 |
| Vader | special_2 | `force_choke` | 12/54/20 (86) | 4 + 2/12 ticks held | magic | 70° / 400 / 6.8 | 18 | 150 | ROOTED | 205 |
| Vader | special_3 | `force_guard` | 3/24/16 (43) | – | – | – | – | 120 | ROOTED | – |

Weights: Gandalf 0.95, Vader 1.12. These are first-pass numbers tuned with the KO report, not with human playtesting.

## 8. Presentation contract v1

### Fighter signals (exact GDScript)

```gdscript
signal animation_requested(animation_id: StringName, duration_ticks: int, loop: bool)
signal facing_changed(facing: int)
signal effect_requested(effect_id: StringName, world_position: Vector2, direction: Vector2, payload: Dictionary)
signal damage_changed(damage: float)
signal stocks_changed(stocks: int)
signal eliminated(player_id: int)
```

* `animation_requested` is emitted **only on transitions**: a change of animation ID, a new attack instance (so the same move twice re-requests) or a new hit while already in hitstun. It is never emitted every tick. It also fires once from `Fighter._ready()` with the initial state.
  * `duration_ticks == 0` means a looping or state-driven animation (locomotion, `held`, `defeat`, `victory`, `jump`).
  * `duration_ticks > 0` is the gameplay timeline the visual should follow: `move.total_ticks()` for attacks and the hitstun length for `hurt`/`knockback`. **Visual frame counts do not have to match.** Scale playback so the clip covers `duration_ticks / 60` seconds, or hold the last frame.
  * `loop` is true for idle/walk/run/fall/held and false otherwise.
* `facing_changed` is emitted when facing changes, and once on `_ready()`.
* `damage_changed`, `stocks_changed`, `eliminated` drive the HUD. **The match owns winner determination** (`MatchController.match_ended`).
* Gameplay never waits for `animation_finished`. Hitboxes, recovery, projectiles, invulnerability and results all come from ticks.

### Animation IDs (source of truth: `GameIds`)

Shared: `idle, walk, run, jump, fall, hurt, knockback, defeat, victory, shield, shield_break, spot_dodge, roll, air_dodge`.
Gandalf: `staff_strike, heavy_staff, lightning, fireball, magic_push, wind_rise`. Vader: `saber_slash, heavy_saber, force_push, force_choke, force_guard, force_leap`.
Shield, dodges, up specials, the respawn platform and their snapshot fields are described in [`SMASH_CORE.md`](SMASH_CORE.md).

Selection is driven by the state, so priority comes from the state machine: `defeat` (KO/eliminated) and `victory` (terminal) > `hurt` while HELD > `knockback` or `hurt` in HITSTUN > the move animation in ATTACK > locomotion. Within HITSTUN, `knockback` is used when launch speed is at least 700 px/s and `hurt` below that. Locomotion: `idle` below 20 px/s, `walk` below 220 px/s, otherwise `run` (grounded). In the air, `jump` while rising and `fall` otherwise. A double jump emits the `double_jump` effect but does not re-request `jump` if the fighter is already in JUMP.

### Presentation snapshot

`Fighter.get_presentation_snapshot() -> Dictionary` is read-only and safe to call at any time, for example to synchronise an adapter attached in the middle of a state.

| Key | Type | Inactive value / notes |
|---|---|---|
| `character_id` | StringName | `&"gandalf"` / `&"vader"` |
| `player_id` | int | 1 or 2 |
| `state` | StringName | One of the state names in §4 |
| `facing` | int | +1 / -1 |
| `velocity` | Vector2 | px/s |
| `grounded` | bool | |
| `current_move_id` | StringName | `&""` when not attacking |
| `move_tick` | int | `-1` when not attacking |
| `damage` | float | percent |
| `stocks` | int | 0 when eliminated |
| `invulnerable` | bool | Respawn invulnerability |
| `hitstop_remaining_ticks` | int | 0 when not frozen; **freeze the animation while > 0** |
| `animation_id` | StringName | Last requested animation |
| `animation_tick` | int | Ticks since that request, excluding hitstop |
| `animation_duration_ticks` | int | As requested (0 = looping) |
| `invulnerable_remaining_ticks` | int | For flash timing |
| `aim_angle_deg` | float | 0 unless an aimable move was aimed |

### Effects (`effect_requested`)

`world_position` is in world space; `direction` is a unit vector (or `Vector2.ZERO`-safe). Every payload includes `player_id: int` (the emitting fighter). All payload values are plain `int/float/String/bool/Vector2`; there are no node references.

| Effect ID | Emitted by / when | Extra payload |
|---|---|---|
| `hit_spark` | Victim, on a hit; position = mid-hurtbox; direction = launch | `attacker_id:int, victim_id:int, move_id:String, damage:float, knockback:float` |
| `guard_block` | Guarding Vader, on a blocked hit | `attacker_id:int, move_id:String` |
| `blast_ko` | KO'd fighter; position clamped to the blast bounds; direction toward the stage | `stocks_before:int` |
| `respawn` | On respawn | `duration_ticks:int` (invulnerability) |
| `double_jump` | Air jump | – |
| `projectile_fizzle` | Owner, when a projectile's lifetime ends | `move_id:String` |
| `choke_release` | Vader, when a hold ends | `victim_id:int, launched:bool` |
| `staff_swing`, `saber_swing`, `lightning_telegraph`, `force_choke`, `force_guard` | Move start (`start_effect_id`); position = hand; direction = aim | `move_id:String, duration_ticks:int` (startup) |
| `heavy_staff_swing`, `heavy_saber_swing`, `lightning_bolt`, `fireball_cast`, `magic_push`, `force_push` | First active tick (`active_effect_id`) | `move_id:String` |
| `force_choke` (second use) | Vader, at the moment of a grab; position = victim | `victim_id:int, duration_ticks:int` (active window) |

### MatchController API

```gdscript
signal fighter_spawned(fighter: Fighter)                  # on every (re)spawn of actors, incl. rematch
signal match_state_changed(state: MatchController.MatchState)  # NOT_STARTED, COUNTDOWN, PLAYING, RESULT
signal match_ended(winner_player_id: int)                 # exactly once per match; 0 = draw

func setup(stage: Stage, characters: Array[CharacterData], inputs: Array[PlayerInput]) -> bool
func start_match() -> void       # also used for rematch: frees and recreates all actors
func rematch() -> void
func step() -> void              # one 60 Hz tick (manual when auto_step == false)
func get_fighter(player_id: int) -> Fighter
var state, tick, countdown_remaining, winner_player_id (-1 undecided, 0 draw), fighters, projectiles
```

**Draw:** if every remaining fighter loses its final stock on the same tick, `match_ended(0)` is emitted. Rematch frees all fighters and projectiles and re-creates them, so nothing persists: timers, stocks, damage, holds, cooldowns, buffers and input edges all reset. HUD and effects rebind through `fighter_spawned`.

## 9. Input

Smash-style layout. Full table, controller assignment and tap jump: [`SMASH_CORE.md`](SMASH_CORE.md) §1.

* **Keyboard:** `InputSetup.ensure_actions()` registers `pN_<button>` actions for `left right up down jump light heavy special shield`. It never overrides an action that already exists.
  * P1: A/D, W or Space jump, S down, F attack, G special, R heavy, T shield.
  * P2: arrows, ↑ or keypad 0 jump, K attack, L special, I heavy, O shield.
  * The starter keys are preserved (A/D, W, F, G and ←/→, ↑, K, L). No key is shared between players (tested).
* **Controllers** are not in the InputMap per player. `PlayerInput` reads the pad that `ControllerAssignment` gives the player, using `InputSetup.JOY_BUTTONS` (Xbox layout):
  * A attack, B special, X/Y jump, RB heavy, LB/LT/RT shield.
  * Left stick or D-pad to move; the right stick does heavies toward its direction.
  * Radial stick dead zone 0.2; digital directions beyond 0.5; tap jump (stick up = jump) on by default.
* **Match actions:** `match_rematch` (Enter, Start), `pause_menu` (Esc, Start), `debug_toggle_hitboxes` (F1). Menus use `ui_*`, and `ensure_actions()` adds controller A/Start to `ui_accept` and B to `ui_cancel`.

`PlayerInput.new(player_id, scripted := false)`. `sample() -> InputFrame` must be called once per tick (the match does this).
* Scripted API for tests and replays: `set_held(button, bool)`, `tap(button)` (held for exactly one sample), `set_axis(Vector2)`, `clear_axis()`, `set_right_stick(Vector2)`, `release_all()`, `reset_edges()`.
* Buttons: `left right up down jump light heavy special shield`, plus direct-slot triggers `special_1 special_2 special_3` (unbound by default).
* `InputFrame.smash_x` carries the right-stick heavy direction.

## 10. Minimal final-art adapter example

Create `scenes/presentation/gandalf_visual.tscn` whose root is a `Node2D` named anything (it is renamed `VisualRoot`) containing an `AnimatedSprite2D`, attach the script below, and set `CharacterData.visual_scene` in `data/characters/gandalf.tres`. Gameplay does not change.

```gdscript
extends Node2D
## Final-art adapter: VisualRoot child of a Fighter.

@export var sprite: AnimatedSprite2D
var fighter: Fighter
var _play_speed := 1.0
var _warned := {}

func _ready() -> void:
	fighter = get_parent() as Fighter
	fighter.animation_requested.connect(_on_animation_requested)
	fighter.facing_changed.connect(func(f: int) -> void: scale.x = f)  # flip art only
	var snap := fighter.get_presentation_snapshot()                    # mid-state attach
	scale.x = snap.facing
	_on_animation_requested(snap.animation_id, snap.animation_duration_ticks, snap.animation_duration_ticks == 0)

func _on_animation_requested(id: StringName, duration_ticks: int, loop: bool) -> void:
	if not sprite.sprite_frames.has_animation(id):
		if not _warned.has(id):
			_warned[id] = true
			push_warning("%s: missing animation '%s'" % [fighter.character.id, id])
		id = &"idle"
	sprite.sprite_frames.set_animation_loop(id, loop)
	sprite.play(id)
	_play_speed = 1.0
	if duration_ticks > 0:  # stretch the clip over the gameplay timeline
		var clip_seconds := sprite.sprite_frames.get_frame_count(id) / sprite.sprite_frames.get_animation_speed(id)
		_play_speed = clip_seconds / (duration_ticks / 60.0)

func _process(_delta: float) -> void:
	var snap := fighter.get_presentation_snapshot()
	sprite.speed_scale = 0.0 if snap.hitstop_remaining_ticks > 0 else _play_speed  # freeze in hitstop
	modulate.a = 0.5 if snap.invulnerable and int(snap.invulnerable_remaining_ticks / 5) % 2 == 0 else 1.0
```
