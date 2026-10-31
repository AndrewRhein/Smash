# The Twilight Citadel

One cohesive presentation set: an indigo dusk fortress backdrop, painted floating stone platforms with bronze trim and cyan crystals, compact player HUD panels, matching menu button/panel styling, and layered combat effects.

## Integration

`scenes/main.tscn` uses `citadel_arena.gd` and `citadel_hud.gd`. The HUD inherits the existing binding/status interface. Platform artwork reads `Stage.PLATFORMS`; the landing cap is drawn at each exact collision rectangle's top edge. The lower rocks are decorative, not additional terrain. Thin cyan undersides distinguish one-way ledges. No movement, hitboxes, damage, timing, input, stage collision, or menu logic changed. Menu changes are confined to `MenuStyle.theme()`.

The background and stone platform were generated with the built-in imagegen tool; immutable PNGs and import sidecars live in `art/arena/`. Source regions are explicit in the arena renderer. Ambient motes are deterministic and modest; tree pause freezes their clock. The background is darkened slightly for fighter readability.

VFX retain all 18 gameplay event mappings: blue-white lightning/charging, amber fire/impact sparks, violet Force effects, layered guard and respawn rings, jump/fizzle/KO particles, and existing melee trails. There is no screen shake or combat authority in the effects. The projectile core stays within its existing 14px radius; translucent flame trails are decorative.

## Validation and limits

Windows Godot 4.7.2: clean final import; 79 tests pass, including menu flow, pause, rematch, and two new presentation regressions. Rendered with OpenGL Compatibility on NVIDIA GTX 1650. `tools/capture_citadel.gd` manually steps the real match and captures arena, lightning, fireball, guard, staff impact and choke; short-lived effects are frozen at the capture tick so PNG encoding time cannot erase them. `tools/capture_presentation_alignment.gd` captures both heavy contacts and recovery facing both directions. These are discrete visual checks, not human playtesting or performance benchmarks. Original real-time capture script stopped after its first screenshot locally; it is not claimed as a completed capture run.

Vader remains explicitly temporary. A fresh requested generation attempt was rejected at output moderation with category `other`, request ID `e0956dc2-48b6-4e2c-a50c-41740f90c981`; the user directed us to skip him if blocked. No unrelated character is substituted. Gandalf's late heavy recovery still changes grip and needs polish. Audio, controller hardware testing and Windows export validation remain outside this pass.

See TEST_REPORT.md for local test details. The PR's existing CI matrix checks Godot 4.3 and 4.5.
