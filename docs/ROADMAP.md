# Realms Rumble: roadmap to a full game

This document covers where the game is, what a complete Smash-style game with a large roster needs, and the order to build it in. Each item says who is best placed to do it: **Gameplay** (Claude), **Art/Audio** (Codex/ChatGPT) or **You** (decisions and playtesting).

## Where we are (already built)
* **Core loop:** stocks, KOs on every side, respawn platform, results, rematch, pause. Off-screen bubbles show fighters beyond the screen.
* **Smash basics:**
  * Movement: walk/run, jump and double jump, fast fall, drop-through platforms.
  * Defence: shield with break and stun, spot dodge, rolls, air dodge.
  * Attacks: light, heavy (also on the right stick), 4 directional specials including a recovery move.
* **Characters:** a data-driven roster (`CharacterRoster`) and a character select screen. Gandalf and Elon have sprites; Vader has placeholder art.
* **Input:** Xbox layout, keyboard for two players, any number of controllers with assignment and hot-plug, controller-friendly menus.
* **Audio:** a working event-driven audio system with placeholder SFX and music. Voice lines are scripted in `docs/AUDIO.md` but not recorded yet.
* **Directional attacks (groundwork):** the game already understands up/down tilts, up/down smashes and all 5 aerials. Each character just needs those moves authored (see Phase 1).
* **Tests:** 120 automated tests on Godot 4.3 and 4.5.

## Phase 1: Full moveset per character (the biggest gameplay upgrade)
Smash characters have about 20 moves; ours have 7 (light, heavy, 4 specials, and a shared shield/dodge kit).

| Move | Input | Status |
|---|---|---|
| Jab (neutral attack) | A | ✅ `light` |
| Forward tilt | A + side | ✅ uses `light` (could get its own `light_side` slot) |
| **Up tilt / Down tilt** | A + up / down (ground) | 🟡 slots `light_up`, `light_down` ready; moves not authored |
| Forward smash | RB / right stick side | ✅ `heavy` |
| **Up smash / Down smash** | RB + up/down, right stick up/down | 🟡 `heavy_up`, `heavy_down` ready |
| **Aerials: neutral / forward / back / up / down** | A in the air (+ direction) | 🟡 `air_*` slots ready (fall back to `light` today) |
| Specials ×4 | B + direction | ✅ |
| **Grab, pummel, 4 throws** | LB+A or a grab button (Smash: R/ZR) | ⬜ new mechanic: grab box, held state (reuse the choke's HELD), throw directions |
| **Dash attack** | A while running | ⬜ one slot, easy once Phase 1 art exists |
| **Ledge grab, ledge options** (get-up, roll, jump, attack, drop) | Automatic near a ledge | ✅ see SMASH_CORE §7 |
| Landing lag for aerials | Automatic | ✅ 6 ticks (normal aerials end on landing) |

**Process per new move:**
* **Gameplay:** add it to the character's `.tres` (timings, hitboxes, knockback). The validator checks it.
* **Art:** a 3-pose (minimum) animation registered under the move's `animation_id`.
* **Audio:** an optional voice line and swing SFX.

**Effort:** about 13 new moves per character; the code is already in place.

## Phase 2: Roster scale (lots of characters)
* **Character template / checklist:** data, art, audio and select-screen entry in one folder per character. Already mostly convention-based; see `CharacterRoster` and `docs/AUDIO.md`.
* **Select screen at scale:** a grid layout with pages (the current row fits about 6), character stats and a preview animation, and colour/skin alternates (palette swaps).
* **Balance pipeline:** extend `tests/ko_report.gd` into a per-character report (KO %, frame data, range). Run it before adding each character.
* **Art pipeline:** one consistent sprite spec (scale by head size, feet pivot, 256-px cells) so new characters never come out a different size, like Elon's attacks did. Codex's packer plus a size check in tests.
* **Weight classes:** weight, fall speed, jump height and air speed already exist in data; tune per archetype.

## Phase 3: Modes and match options
* **Stage select:** multiple stages (data plus art), hazards on/off, an "omega" flat version.
* **Match rules:** stock or timed, time limit, handicap, items on/off.
* **CPU opponents (AI):** essential for solo play. Start with a simple state-based bot that uses the same `PlayerInput` interface.
* **Training mode:** CPU behaviours, damage display, frame data overlay (we already have F1 hitboxes).
* **Up to 4 players:** the engine is mostly player-count-agnostic. The HUD, spawn points and select screen need 4 slots.
* **Teams, free-for-all**, and later tournament/bracket mode.

## Phase 4: Presentation and feel
* **Camera:** a dynamic zoom/pan that keeps all fighters in view. This replaces the off-screen bubbles on larger stages.
* **Hit feel:** screen shake, a stronger hit flash, slow-mo on the final KO, KO star effects.
* **Animations:** shield/dodge/up-special art for every character (they fall back to idle today). More frames per animation.
* **Audio:** real music (menu, one per stage, victory themes per character), recorded voice lines, an announcer, impact SFX by move weight.
* **UI:** final theme, stock icons, damage % shake and colour as it rises, results screen with stats.

## Phase 5: Product polish
* **Controls:** a rebinding menu, per-player control profiles, and tap jump / tilt stick options. **Keyboard players need a separate "up" key** to do ground up-tilts, because W is both up and jump.
* **Settings:** resolution/window, vsync, colour-blind options, language.
* **Builds:** Windows/macOS/Linux exports, CI artifacts, a crash-free first-run check, and controller testing on real hardware.
* **Online play (big):** needs rollback netcode. Our deterministic 60 Hz tick and input-frame design makes this feasible later, but it's a large project.

## Suggested next 3 steps
1. **You:** a playtest session with two controllers. Note what feels off: jump height, speed, shield and KO percentages.
2. **Gameplay + Art:** author up/down tilts, up/down smashes and 5 aerials for Gandalf and Elon. Codex makes the poses; I add the data and tune it.
3. **Gameplay:** grabs/throws and ledge grab, then a basic CPU opponent for solo play.
