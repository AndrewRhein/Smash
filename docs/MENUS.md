# Realms Rumble: menus and app flow

The game starts in `scenes/app.tscn` (`GameApp`, `scripts/menu/game_app.gd`):

```
Title ──Start Match──▶ Match (scenes/main.tscn, unchanged)
  │                      │  Esc / Start ──▶ Pause: Resume · Restart Match · Controls · Main Menu
  ├─ Controls            │  match ends  ──▶ Result: Rematch · Main Menu  (Enter/Start = rematch, Esc = menu)
  ├─ Settings ─▶ Controllers (assign / swap pads)
  │                      ▼
  └─ Quit            Main Menu ──▶ Title
```

* **Separation from gameplay and art.** For every match the shell instances `scenes/main.tscn` as-is. Before adding it to the tree, it sets `Match.stock_count`. After that it only uses public `MatchController` API (`state`, `rematch()`, `inputs`, signals). Changes inside `main.tscn`/`main.gd`, such as the final-art wiring, need no menu changes. Opening `scenes/main.tscn` directly (F6) still runs a match without menus.
* **Pause** uses `SceneTree.paused`. The match subtree is `PROCESS_MODE_PAUSABLE`, so fighters, projectiles, effects, sprite animation and the HUD all freeze together, and the menus run with `PROCESS_MODE_ALWAYS`. Pausing is only allowed during the countdown or the fight. On resume, every player's input edges are reset, so a button pressed or released while paused never fires an attack. Controller **Start** pauses during play; in the result state it keeps its existing meaning (rematch).
* **Settings** are saved to `user://settings.cfg` when they change:
  * `stocks` (1–5)
  * `fullscreen`
  * `show_hitboxes`: start every match with the F1 overlay on
* **Controls screen** is generated from the live InputMap, so it always shows the real bindings.
* **Styling** is a temporary functional theme built in one place (`scripts/menu/menu_style.gd`). Final presentation can replace `MenuStyle.theme()` with a `.tres` Theme without touching menu logic.
* **Input**: menus use Godot's built-in `ui_*` actions (arrows/D-pad, Enter/Space/A, Esc/B). The new `pause_menu` action (Esc, controller Start on any pad) is registered in `scripts/input/input_setup.gd`.

Tests: `tests/test_menus.gd` (9 tests) drives the real shell with real key and controller events. It covers title → match, the stock selector and saving it, pause freeze and resume without leaked presses, Start = pause during play but rematch in the result state, pause restart and main menu (scene freed, tree unpaused), the controls sub-screen, the result buttons, saving settings, and the bindings shown on the controls screen.

## Controller support
* Every menu works with only a controller: D-pad or left stick to move, **A** (or Start) to select, **B** to go back, and ◀ ▶ to change options.
* Godot 4.3's built-in `ui_accept`/`ui_cancel` have no controller buttons, so `InputSetup.ensure_actions()` adds A/Start and B to them, on any pad.
* If nothing has focus (e.g. after a mouse click), the next D-pad, stick or A press restores focus.
* The Art Gallery opens with focus on its Back button.
* **Settings → Controllers** shows connected pads with live button indicators, and lets you assign each player's pad or swap them.
* **Settings → Tap jump** toggles whether pushing the stick up jumps. It's saved with the other settings.
