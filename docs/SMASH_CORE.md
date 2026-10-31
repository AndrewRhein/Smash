# Realms Rumble: Smash-style core (controls, shield, dodges, recovery, respawn)

Implemented in `scripts/fighter.gd`, `scripts/gameplay/match_controller.gd`, `scripts/input/` and the character `.tres` files. Tests: `tests/test_smash_controls.gd`, plus menu and controller tests in `tests/test_menus.gd`. All timings are 60 Hz ticks.

## 1. Controls

| Action | Xbox controller | Player 1 keyboard | Player 2 keyboard |
|---|---|---|---|
| Move (partial stick = walk) | Left stick / D-pad | A / D | ← / → |
| Jump / double jump (hold = higher) | X or Y (or stick up, tap jump) | W / Space | ↑ / keypad 0 |
| Attack | A | F | K |
| Heavy (smash) | RB, or right stick (turns toward it) | R | I |
| Special: neutral / side / up / down | B + stick direction | G + direction | L + direction |
| Shield (hold) | LB, LT or RT | T | O |
| Spot dodge / roll | Shield + down / Shield + left or right | T + S / T + A or D | O + ↓ / O + ← or → |
| Air dodge (+ direction) | Shield in the air | T in the air | O in the air |
| Fast fall / drop through a thin platform | Stick down | S | ↓ |
| Pause / rematch | Start | Esc / Enter | Esc / Enter |
| Menus | D-pad or stick, A select, B back | Arrows, Enter, Esc | |

**Specials by direction** (`CharacterData.neutral_special / side_special / down_special / up_special`):

| | Neutral (B) | Side | Down | Up (recovery) |
|---|---|---|---|---|
| Gandalf | fireball (`special_2`) | lightning (`special_1`) | magic push (`special_3`) | wind rise (`special_up`) |
| Elon (playable) | orbital tractor (`special_2`) | thruster burst (`special_1`) | energy shield (`special_3`) | rocket boost (`special_up`, reuses the thruster poses) |
| Vader (test fixture only) | Force choke (`special_2`) | Force push (`special_1`) | Force guard (`special_3`) | Force leap (`special_up`) |

* **Direction rules:** a mostly-vertical stick picks up or down; otherwise a horizontal stick picks side and turns the fighter toward it. Lightning and Force push still aim with the vertical part of the stick, e.g. up-forward + B.
* **Tap jump:** on by default; switch it off in Settings. When it's off, the stick no longer jumps; the keyboard jump keys always do.

**Multiple controllers** (`ControllerAssignment`):
* **Assignment:** connected pads fill Player 1, then Player 2, in device order. Any device id works, and hot-plugging is detected. A pad keeps its player until it's unplugged, and extra pads still navigate menus.
* **Changing it:** Settings → Controllers lets you choose each player's pad, swap players, or go keyboard-only. It shows live "button pressed" indicators so you can tell which pad is which.
* **Mixing:** keyboard and a pad work together for the same player.

## 2. Shield
* **Raising it:** hold shield while grounded and free. Shields block every strike and projectile from any side; projectiles are destroyed. **Grabs (Force choke) go through shields.**
* **Health:** max 50. It drains 0.12 per tick while held (about 7 s) and regenerates 0.08 per tick while lowered. A hit removes `damage × 1.2`.
* **Shieldstun:** `damage × 0.8 + 2` ticks, during which you can't act. Pushback is `160 + 22 × damage` px/s.
* **Out of shield:** jump (instant), spot dodge (down), roll (left/right) or up special. Releasing shield gives 7 ticks of vulnerable drop lag.
* **Shield break** (health ≤ 0, from hits or holding too long): the fighter pops up and is dizzy (`shield_break`) for 180 ticks. They're fully vulnerable and can't act, then return with 37.5% shield.
* **Force guard** (Vader down special) is separate: it is front-only and blocks magic and projectiles.

## 3. Dodges (intangible = strikes, projectiles and grabs pass through)
| Dodge | Total | Intangible | Notes |
|---|---|---|---|
| Spot dodge | 26 | 3–17 | No movement; returns to shield if it's still held |
| Roll | 32 | 4–19 | Travels about 150 px, **stops at ledges**, ends facing back the way it came |
| Air dodge | 34 | 3–24 | With a direction: 620 px/s burst with no gravity for 18 ticks. Neutral: brief stall. One per airtime (restored on landing or when hit). Landing ends it |

## 4. Up special (recovery) and helpless
* **The moves:** Gandalf wind rise and Vader Force leap set the fighter's velocity on their first active tick (`MoveData.self_impulse`), rising about 280 px and 250 px. Each has a small hitbox on the way up.
* **Helpless:** if the move ends in the air (`helpless_after`), the fighter is helpless until it lands. They can drift and fast fall, but can't jump, attack, special or air dodge. Getting hit or landing clears it.

## 5. Death and respawn
* **KO burst:** shown at the **screen edge** the fighter left through, clamped into `Stage.visible_rect`. The payload carries `exit_side` ("left", "right", "top" or "bottom"). Before this fix it was emitted at the off-screen blast line.
* **Respawn platform:** after 60 ticks the fighter respawns on a platform above the stage (`Stage.respawn_points`) facing the stage, with full shield and 0%. They're untouchable and hover until any input or 180 ticks pass, then stay invulnerable for 120 more ticks. A jump from the platform is a full grounded jump, and the double jump is kept. Buttons held through the KO don't count as input.
* **Off-screen bubbles:** there's no camera, so off-screen fighters get a "P1/P2" bubble at the nearest screen edge (`scripts/presentation/offscreen_indicators.gd`, added by the app shell).

## 6. Presentation additions (for the art side)
* **New states and snapshot names:**
  * `shield`, `shield_break`, `dodge`, `lag` (shield drop), `respawn`
  * The snapshot also gains `shielding`, `shield_health`, `shield_max`, `intangible`, `helpless` and `on_respawn_platform`.
* **New animation IDs** (`GameIds.MECHANIC_ANIMATION_IDS`, kept apart from the fully authored `SHARED_ANIMATION_IDS`):
  * Shared: `shield` (loop), `shield_break` (loop while dizzy), `spot_dodge` (26), `roll` (32), `air_dodge` (34).
  * Moves: `wind_rise` and `force_leap`.
  * Existing art adapters fall back to idle for missing IDs.
  * Helpless uses `fall`; lag and the respawn platform use `idle`.
* **Effects:** no new effect IDs, so existing mappings keep working.
  * A shield hit emits `guard_block` with payload `shield: true` and `shield_ratio`.
  * A shield break emits `hit_spark` with `shield_break: true`.
  * Leaving the respawn platform emits `respawn` with `left_platform: true`.
  * Up specials use `double_jump` as their start effect.
  * Dedicated IDs can be added later, together with mappings in `integrated_effects.gd`.
* **Placeholder overlay:** `PlaceholderStatusVisual` (the Fighter's `StatusVisual` child, beside VisualRoot) draws the shield bubble (it shrinks and reddens as health drops), the respawn platform, dizzy stars and a dodge shimmer. Final art can replace it.

## 7. Combat feel (turnarounds, DI, combos, ledges, charge)
All numbers are constants at the top of `scripts/fighter.gd`.
* **Turnarounds:** the facing used by an attack comes from the input *when the button was pressed*, even if the move comes out later from the buffer (after landing lag, shield drop or another move):
  * Heavy (RB / right stick / R): aimed behind you turns you around. The right stick wins over the left stick.
  * Light (forward tilt) toward the back turns around. In the air, a real `air_back` keeps your facing and hits behind; characters without one turn instead.
  * Side special turns toward the stick (as before).
* **Skid turns:** reversing direction on the ground brakes with accel + decel, so turning around while running is crisp instead of sliding.
* **Input buffer:** 9 ticks for attacks (was 6), so moves pressed slightly early still come out.
* **DI (directional influence):** when launched (knockback ≥ 250), the part of your stick perpendicular to the launch bends it by up to 15°. Hold up/in to survive longer.
* **Hit-confirm combos:** a jab or tilt that **lands** can cancel its recovery into any heavy or special (on top of each character's own `cancel_into`).
* **Aerial landing lag:** normal aerials end when you land, with 6 ticks of landing lag. Specials and recovery moves keep going.
* **Ledges:** `Stage.ledges()` gives the corners of solid platforms.
  * **Grab:** falling (or in a recovery move) near a corner grabs it. You get 40 ticks of invulnerability, your double jump and air dodge back, and helpless clears.
  * **Options:** after 8 ticks, jump to ledge jump, press up or toward the stage to get up, shield to roll in, attack to get-up attack, or press down or away to drop.
  * **Limits:** only one fighter per ledge. Auto-drop after 5 s, and you can't regrab for 36 ticks after letting go.
  * **Presentation:** the state is `ledge` and the animation is `fall`. The snapshot has `on_ledge`.
* **Charged heavies:** keep holding heavy (or the right stick) and `heavy`, `heavy_up` and `heavy_down` freeze just before their hitbox for up to 60 ticks.
  * A full charge deals +40% damage and +20% base knockback. The move is copied, so shared data is never mutated.
  * The snapshot has `charging` and `charge_ratio`, and the placeholder overlay draws a pulsing gold ring.
* **Game feel (presentation only, `scripts/presentation/game_feel.gd`):**
  * Screen shake scaled by knockback, plus a big shake and white flash on KO.
  * Smoke trails behind launched fighters (fire-coloured for very strong launches).
  * A KO ray burst at the blast point.
