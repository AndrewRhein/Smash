# Realms Rumble: Godot 4 local platform fighter

A local two-player platform fighter: Gandalf vs. Darth Vader. This integration branch combines Claude's gameplay foundation with Gandalf's 14-animation pixel-art review pack and presentation effects. Vader, the arena and HUD retain temporary graphics. The final art milestone remains incomplete.

## Install and run

1. Install **Godot 4.3 or newer** (standard build, not .NET): https://godotengine.org/download/. Validated with 4.3-stable and 4.5-stable.
2. Clone this repository.
3. In Godot, choose **Import**, select `project.godot`, then press **F5**.

Command line: `godot --path .` (add `--headless --quit-after 400` for a non-interactive launch check).

## Controls

Smash-style. Full details: [`docs/SMASH_CORE.md`](docs/SMASH_CORE.md).

| Action | Xbox controller | Player 1 keyboard | Player 2 keyboard |
|---|---|---|---|
| Move | Left stick / D-pad | A / D | ← / → |
| Jump (again in the air = double jump) | X / Y (or stick up) | W / Space | ↑ / keypad 0 |
| Attack | A | F | K |
| Heavy (smash) attack | RB or right stick | R | I |
| Special (neutral / side / up = recovery / down) | B + direction | G + direction | L + direction |
| Shield · spot dodge · roll · air dodge | LB/LT/RT (+ down / left·right / in air) | T (+ S / A·D / in air) | O (+ ↓ / ←·→ / in air) |
| Fast fall / drop through thin platform | Stick down | S | ↓ |
| Pause / rematch | Start | Esc / Enter | Esc / Enter |
| Menus | D-pad/stick, A select, B back | Arrows, Enter, Esc | |
| Hitbox debug view | | F1 | |

Controllers: the first two connected are Players 1 and 2. Change, swap or check them in **Settings → Controllers**. Tap jump can be turned off in Settings.

## How a match works

* The game opens on a title screen: Start Match, stock count (1–5), Controls, Settings. See [`docs/MENUS.md`](docs/MENUS.md).
* Smash-style shield (it breaks if overused), dodges, an up-special recovery, a respawn platform, and off-screen bubbles when a fighter is launched beyond the screen.
* Three stocks each by default. Damage % increases knockback. Leaving the blast bounds on any side costs one stock.
* You respawn after 1 second with 2 seconds of flashing invulnerability.
* The last fighter with stocks wins. If both final stocks are lost on the same tick, the match is a **draw**.
* After the result, press **Enter** or **Start** to rematch with everything reset.
* Light attacks that connect can be cancelled into specials. The specials:
  * **Force choke** holds briefly and can be broken by hitting Vader.
  * **Force guard** blocks magic and projectiles from the front only.

## Tests

```bash
godot --headless --path . --import                         # once, builds the class cache
godot --headless --path . -s res://tests/run_tests.gd      # 67 gameplay, presentation + smoke tests, exit code 0 on success
godot --headless --path . -s res://tests/ko_report.gd      # tuning table: KO % per move
```

Results, the versions tested and manual-coverage limits are in [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md).

## Project layout

* `scripts/fighter.gd`: fighter state machine and move timeline
* `scripts/gameplay/`: match controller, stage, projectiles, combat math, debug overlay
* `scripts/data/`, `data/characters/*.tres`: typed movesets; `game_ids.gd` is the ID registry
* `scripts/input/`: InputMap setup and the per-player input adapter
* `scripts/presentation/`: sprite adapters and effects, plus temporary Vader, HUD and arena renderers
* `tests/`: headless test runner and tools

Documentation:

* [`docs/GAMEPLAY_API.md`](docs/GAMEPLAY_API.md): gameplay rules, data schema and the presentation contract
* [`docs/CODEX_INTEGRATION.md`](docs/CODEX_INTEGRATION.md): how final art plugs in
* [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md): what was tested and how

## Status

Gandalf has 14 integrated animations (70 playback frames); Vader still uses the temporary renderer because image generation was rejected without a specific cause. **The visual asset milestone is not done.** The combined runtime passes 67 headless tests on Godot 4.3 and 4.5. Not yet tested by humans or on Windows or controller hardware. See [integration status](docs/INTEGRATION_STATUS.md) for exact validation and limitations.
