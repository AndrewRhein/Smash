# Realms Rumble: Godot 4 local platform fighter

A local two-player platform fighter: Gandalf vs. Darth Vader. This branch provides the gameplay foundation (movement, combat, movesets, match flow, input and tests) with **honest placeholder graphics**. Final pixel art and presentation will plug into the documented presentation contract.

## Install and run

1. Install **Godot 4.3 or newer** (standard build, not .NET): https://godotengine.org/download/. Validated with 4.3-stable and 4.5-stable.
2. Clone this repository.
3. In Godot, choose **Import**, select `project.godot`, then press **F5**.

Command line: `godot --path .` (add `--headless --quit-after 400` for a non-interactive launch check).

## Controls

| Action | Player 1 (Gandalf) | Player 2 (Darth Vader) | Controller |
|---|---|---|---|
| Move | A / D | ← / → | Left stick or D-pad |
| Jump / double jump (hold for higher) | W | ↑ | A |
| Down: fast fall, drop through thin platforms, aim down | S | ↓ | Stick / D-pad down |
| Aim up (lightning, Force push) | W | ↑ | Stick / D-pad up |
| Light attack | F | K | X |
| Heavy attack | R | I | Y |
| Special 1 (Gandalf: lightning, Vader: Force push) | G | L | B |
| Special 2 (Gandalf: fireball, Vader: Force choke) | T | O | RB |
| Special 3 (Gandalf: magic push, Vader: Force guard) | V | M | LB |
| Rematch (after a result) | Enter | Enter | Start |
| Toggle hitbox/hurtbox debug view | F1 | | |
| Pause menu (during a match) | Esc | Esc | Start |
| Menus: move / select / back | Arrows, Enter, Esc | | D-pad, A, B |

Controllers are assigned by connection order: the first pad is Player 1 and the second is Player 2. Keyboard and pads can be mixed. On some keyboards, two players pressing many keys at once can drop inputs (ghosting); that is a hardware limitation.

## How a match works

* The game opens on a title screen: Start Match, stock count (1–5), Controls, Settings. See [`docs/MENUS.md`](docs/MENUS.md).
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
godot --headless --path . -s res://tests/run_tests.gd      # 61 behaviour + smoke tests, exit code 0 on success
godot --headless --path . -s res://tests/ko_report.gd      # tuning table: KO % per move
```

Results, the versions tested and manual-coverage limits are in [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md).

## Project layout

* `scripts/fighter.gd`: fighter state machine and move timeline
* `scripts/gameplay/`: match controller, stage, projectiles, combat math, debug overlay
* `scripts/data/`, `data/characters/*.tres`: typed movesets; `game_ids.gd` is the ID registry
* `scripts/input/`: InputMap setup and the per-player input adapter
* `scripts/presentation/`: **temporary placeholder** art, VFX, HUD and arena
* `tests/`: headless test runner and tools

Documentation:

* [`docs/GAMEPLAY_API.md`](docs/GAMEPLAY_API.md): gameplay rules, data schema and the presentation contract
* [`docs/CODEX_INTEGRATION.md`](docs/CODEX_INTEGRATION.md): how final art plugs in
* [`docs/TEST_REPORT.md`](docs/TEST_REPORT.md): what was tested and how

## Status

Playable Gandalf-vs-Vader match with placeholder vector graphics (labelled "PLACEHOLDER ART"). **The visual asset milestone is not done:** there are no finished sprite animations yet. Not yet tested by humans or on Windows or controller hardware; see the test report.
