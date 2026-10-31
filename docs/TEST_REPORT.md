# Realms Rumble: gameplay test report

## Presentation revision (2026-10-31)

This revision also supplies the Twilight Citadel arena, textured platforms, HUD and VFX pass. See [CITADEL_PRESENTATION.md](CITADEL_PRESENTATION.md) for scope and rendered capture coverage. Final import was repeated with Windows file access allowed and completed without errors or warnings; a restricted repeat had also produced a safe-save error before that final run.

Based on main `333204e`: the existing suite has 77 tests, not 61. The historical results below describe the original gameplay milestone and are retained as such.

On Windows, Godot **4.7.2.stable.official.ed1daf0bf**: import completed cleanly with an isolated APPDATA folder; the full suite with two new presentation regressions reports **79 passed, 0 failed**, exit code 0. The expected unknown-placeholder-animation warning is intentional. An initial import could not write the normal editor profile; rerunning with the isolated profile resolved those errors.

Actual OpenGL Compatibility captures were rendered at heavy ticks 16, 19 and 35, facing both directions, using `tools/capture_presentation_alignment.gd`. Inspection confirms the high-forward pose in the first hitbox window and the extended low pose in the second. This is a discrete frame review, not human playtesting. Recovery grip continuity remains a known polish issue. Godot 4.3/4.5 validation is delegated to the existing PR CI matrix; local tests used 4.7.2 only.

All 15 existing PNG import sidecars were already tracked on the baseline. The new source image also has its import sidecar. Newer-engine rewrites of the existing imports are excluded from this change.

## Historical gameplay milestone

Branch `claude/gameplay-core`, based on `main` @ `7a42a2e`. Environment: Linux x86_64 cloud container with no GPU, no audio device and no physical controllers.

## Engine versions

| Version | Source | Used for | Result |
|---|---|---|---|
| **Godot 4.3-stable** (`4.3.stable.official.77dcf97d8`) | Official `Godot_v4.3-stable_linux.x86_64.zip`, SHA-512 checked against the release's `SHA512-SUMS.txt` | Primary: development, import, all tests, frame captures | 61/61 pass |
| **Godot 4.5-stable** (`4.5.stable.official.876b29033`) | Official `Godot_v4.5-stable_linux.x86_64.zip`, SHA-512 checked | Forward-compatibility check on a scratch copy of the final tree | Import clean, 61/61 pass |

4.3 is both the documented minimum and the primary validation target, so **minimum-version compatibility was tested**. No 4.4+ APIs are used. Opening the project in 4.4 or newer will generate `*.uid` files and may update `config/features`; that is expected.

## Commands

```bash
# 1. Import (also builds the global class cache needed by class_name scripts)
godot --headless --path . --import

# 2. Behaviour + smoke tests (exit code 0 = all pass, 1 = any failure)
godot --headless --path . -s res://tests/run_tests.gd
#    run a subset by name substring:
godot --headless --path . -s res://tests/run_tests.gd -- choke

# 3. Headless launch of the real main scene (parse/runtime check)
godot --headless --path . --quit-after 400

# 4. Tuning aid: KO percentage per move (prints a table, not pass/fail)
godot --headless --path . -s res://tests/ko_report.gd

# 5. Visual check: render key moments to PNG (needs a display or Xvfb + GL)
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s res://tests/capture_frames.gd -- /tmp/frames
```

## Automated results (actual output, Godot 4.3)

* Import: no errors or warnings.
* `--quit-after 400` headless launch: no errors or warnings.
* Test runner: **61 passed, 0 failed**, exit code 0. The only console output besides PASS lines is one *intentional* warning from `test_placeholder_tolerates_unknown_animation_ids`, which checks that the warn-once behaviour fires.

The tests drive the real `MatchController`, `Fighter`, `.tres` data and `PlayerInput`, with scripted input and manual `step()` calls. Nothing re-implements the formulas in a mock.

| Requirement from the handoff | Test(s) |
|---|---|
| No damage before startup / after active | `test_combat::test_no_damage_before_startup_ends`, `test_no_damage_after_active_window` |
| A hitbox cannot repeatedly hit a target | `test_combat::test_hitbox_hits_target_only_once` (+ authored multi-hit: `test_multi_hit_hitbox_rehits_on_interval_only`) |
| Mirrored hitboxes | `test_combat::test_mirrored_hitboxes` |
| More damage → more knockback | `test_combat::test_more_damage_more_knockback` |
| Hitstun preserves impulse | `test_combat::test_hitstun_preserves_knockback` (victim steers against the launch for 20 ticks) |
| Hitstop | `test_combat::test_hitstop_freezes_attacker_and_victim` |
| Invulnerability blocks damage | `test_combat::test_invulnerability_blocks_damage`, `test_match::test_respawn_resets_and_is_invulnerable` |
| Cooldowns and recovery hold; no auto-repeat; buffer | `test_combat::test_recovery_blocks_attacks_and_holding_does_not_repeat`, `test_cooldown_blocks_reuse`, `test_cancel_into_special_only_on_hit` |
| Simultaneous collisions | `test_combat::test_simultaneous_trade_is_symmetric` |
| Jump buffering, double-jump reset, coyote, variable jump, fast fall | `test_movement::*` |
| One-way platforms and drop-through; main platform solid | `test_movement::test_drop_through_one_way_only`, `test_one_way_platform_passable_from_below` |
| Projectile cleanup | `test_specials::test_fireball_spawns_on_active_tick_and_expires`, `test_fireball_hits_once_and_credits_owner`, `test_projectiles_removed_when_owner_loses_stock`, `test_match::test_rematch_resets_everything` |
| Force choke interruption, bounds, range, KO, loop prevention | `test_specials::test_force_choke_*`, `test_grab_immunity_prevents_choke_loop` |
| Guard expiry, front-only, damage types | `test_specials::test_force_guard_*` |
| Directional specials | `test_specials::test_lightning_telegraph_and_aim`, `test_force_push_is_directional` |
| One stock loss per blast exit; all four sides | `test_match::test_one_stock_loss_per_blast_exit`, `test_blast_bounds_on_all_sides` |
| No negative stocks; eliminated fighters inert | `test_match::test_no_negative_stocks_and_eliminated_is_inert` |
| Exactly one match result; frozen after | `test_match::test_exactly_one_result_and_frozen_after` |
| Simultaneous final KOs → draw | `test_match::test_simultaneous_final_ko_is_draw` |
| Complete rematch reset | `test_match::test_rematch_resets_everything`, `test_smoke::test_main_scene_runs` |
| Input routing for distinct players (keyboard + per-device joypads, dead zone) | `test_input::*` (synthetic `InputEventJoypadButton`/`Motion` with device 0/1) |
| Data validation | `test_data::*` |
| Presentation contract (signals on transitions, snapshot types, VisualRoot independence, plain payloads, warn-once) | `test_presentation::*` |
| Headless scene smoke test with real keyboard events (move, F1, Enter rematch) | `test_smoke::test_main_scene_runs` |

## Rendered visual check (performed and observed)

I ran `tests/capture_frames.gd` under Xvfb with Mesa's software OpenGL (`--rendering-driver opengl3`, Godot 4.3) and inspected the 13 PNG frames by eye. The script plays the **real main scene** using scripted `PlayerInput`s (not physical devices). Observed:

* Countdown "READY... 3" then "FIGHT!". Both fighters spawn and land on the upper one-way platforms.
* Fighters walk toward each other. Gandalf's heavy connects: a hit spark is drawn **above** the fighters and background, Vader turns red (hurt tint), and the HUD shows 13%.
* With the F1 overlay on: green hurtboxes, red lightning circles along the bolt, the orange fireball circle and the blast bounds. The lightning visual and its hitboxes line up.
* Force choke: Gandalf is held (tinted) with a choke ring, and the pulse damage ticks up in the HUD. The release frame shows him launched.
* Force guard versus Gandalf's magic push: push rings are visible and Vader's damage does not change (blocked).
* A launch at 166% plays the knockback pose. The KO decrements stocks, and the result screen shows "DARTH VADER WINS! Press Enter / Start for a rematch" with Vader's victory text. A rematch returns to the countdown with 0%/3 stocks.

Two presentation bugs were found this way and fixed: P2's HUD label overflowed the screen edge, and the victory text rendered mirrored when Vader faced left.

## Manual / interactive coverage: honest status

| Item | Status |
|---|---|
| Human playtesting with a keyboard (feel, responsiveness, fun) | **Untested.** No interactive display or keyboard is available in this environment |
| Physical controllers (two pads, device assignment, stick feel) | **Untested on hardware.** Routing is verified only with synthetic joypad events |
| Windows | **Untested.** Paths are relative `res://` with no case conflicts; no export was attempted |
| Keyboard ghosting with two players on one keyboard | **Untested.** It depends on the hardware; some keyboards may drop simultaneous presses such as W+F+arrow keys |
| Full match + rematch, drop-through, both facings, every special, visual feedback | **Automated pass** (behaviour tests) plus the **rendered visual check** above using scripted input. No human input |
| Audio | Not implemented (out of scope) |
| Balance / tuning | First pass only, using `tests/ko_report.gd` (measured KO% table in `docs/GAMEPLAY_API.md` §7). It needs human playtesting |

## Known limitations

* **No recovery special.** The brief fixes the moveset at light, heavy and three specials. The only way back from below the stage is the double jump, so horizontal launches below stage level are dangerous. Knockback angles and growth are tuned around this. Adding a recovery move or ledge grab is a design decision for a later milestone.
* Fireballs ignore terrain. This is deliberate and documented, but it can be revisited.
* The placeholder visuals are intentionally crude and are labelled "PLACEHOLDER ART".
