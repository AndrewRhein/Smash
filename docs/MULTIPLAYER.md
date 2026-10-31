# Realms Rumble: 4 players and CPU opponents

## Joining (character select)
Up to four players, in ports P1–P4. **P1 is always in.** Every other port starts empty, showing "Press A to join".

| Who | How they join | Controls on the select screen |
|---|---|---|
| Controller | Press **A**. Each pad drives the port the Controllers screen gives it (pads fill P1→P4 in plug-in order). | Stick/D-pad move · A lock in · B back/leave · LB/LT/RT (shield) CPUs · RB (heavy) CPU level · Start fight |
| Keyboard P1 | Already in | A/D/W/S move · F lock in · G back · T CPUs · R CPU level |
| Keyboard P2 | Press **K** | arrows · K lock in · L back · O CPUs · I CPU level |

* **B:** un-readies you first. Pressed again it leaves the port (P1 returns to the title instead).
* **Fighting:** Start/Enter begins once **2+ fighters** are in and everyone, CPUs included, has locked in.
* **Enter on a keyboard:** locks in the next player. If only P1 is in, it adds keyboard P2.
* **Remembered lineup:** coming back from a match keeps the same lineup, with CPUs already locked in on their last pick.

## CPU players
* **Shield (add or pick a CPU):**
  * The first press grabs an existing CPU's cursor. Each further press moves to the next CPU, then adds a new CPU in a free port, then wraps around.
  * While you hold a CPU, your stick moves *its* cursor and A locks it in. B removes it (or un-readies it if it was locked).
  * Moving a locked CPU's cursor un-readies it.
* **Heavy (CPU level):** changes the held CPU's level from 1 to 9. The last level used becomes the default.
* **Practice vs CPU** (title screen): opens the select screen with a CPU already in P2.

### How the CPU plays (`scripts/input/cpu_input.gd`)
* **Inputs:** `CpuInput` is a `PlayerInput` that presses buttons through the scripted-input path, so it follows exactly the same rules as a human.
* **Priorities, every tick:**
  1. **Ledge:** waits, then gets up, ledge jumps or rolls in.
  2. **Recovery:** off stage, it drifts home, double jumps, then up specials.
  3. **Launched:** survival DI toward the stage.
  4. **Each reaction window:**
     * Shields attacks that are about to land.
     * Attacks in range: jab, tilt, heavy and specials, plus up attacks against targets above. It goes for heavies when the target is at high %.
     * Full hops and double jumps to reach targets on platforms, with a jump attack.
     * Throws projectiles from mid range.
     * Otherwise walks toward the nearest opponent without walking off the stage.
* **Level scaling:** level sets reaction time (about 24 ticks at level 1, 4 at level 9), aggression, how often it shields and how often it DIs.
* **Repeatable:** randomness is seeded per port, so matches are repeatable.

## Engine notes
* **Ports:** each fighter keeps its **port** (`PlayerInput.player_id`), so P3 stays P3 (own controller, colour, spawn) even if P2 is empty.
  * `GameApp.start_match(picks, ports, cpu_levels)` is the entry point. `main.gd` builds a `PlayerInput` or `CpuInput` per port.
* **Stage:** `Stage.spawn_points` and `respawn_points` have 4 entries. The last fighter with stocks wins, and a simultaneous final KO is a draw.
* **HUD:** 1–2 players use the top-corner cards. 3–4 players get a Smash-style row of cards along the bottom. CPUs are labelled "CPU <level>".
* **Controllers:** `ControllerAssignment.PLAYER_COUNT` is 4, and the Controllers screen lists all four ports.
