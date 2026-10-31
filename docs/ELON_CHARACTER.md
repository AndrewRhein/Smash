# Elon Musk — fictional tech brawler

User-directed replacement for Vader in the default two-player match. This is a playful fictional character, not a claim about the real person. The Citadel, platforms, Gandalf sprites, shared combat art, and menu theme are preserved.

## Gameplay coordination for Claude

This request explicitly expands the earlier art-only assignment to a new playable character. New `elon.tres` and GameIds registrations define his own identity and animation/effect IDs. The default lineup, HUD identity, title portrait/subtitle and controls text now select Elon. Menu behavior, Fighter, MatchController and input bindings are unchanged. Vader data remains only for the existing regression fixtures; it is not selected by the app.

The first-pass kit reuses the established melee, aimed pulse, bounded hold and directional guard mechanics and retains their predecessor's tested timing/balance values. Internal `choke` and `guard` behavior names are engine primitives, not character lore. No combat values were changed merely to fit sprites. Any later balance revision belongs in a separate gameplay change.

| Slot / P2 key | Ability | Behavior | Startup / active / recovery | Damage |
|---|---|---|---|---|
| Light / K | Ion Jab | Gauntlet punch with a short ion extension | 6 / 4 / 13 | 6% |
| Heavy / I | Rocket Hammer | Slow silver powered-hammer strike | 20 / 6 / 30 | 16% |
| Special 1 / L | Thruster Burst | Aimable pressure pulse; high knockback, no projectile | 12 / 6 / 24 | 3% |
| Special 2 / O | Orbital Tractor | Targeting rings lock a nearby opponent, pulse damage, then launch; breaks on interruption or range | 12 / 54 / 20 | 2% per 12 held ticks + 4% release |
| Special 3 / M | Energy Shield | Brief forward hex shield blocks magic/projectiles, not melee or attacks from behind | 3 / 24 / 16 | — |

Movement and two jumps use the existing P2 controls. Special cooldowns are 60/150/120 ticks respectively. Orbital Tractor has an eight-tick grab window, whiffs into recovery, and grants post-release grab immunity. Presentation never applies damage or holds.

## Art production

Design reference: charcoal jacket, dark trousers and boots, brushed-silver cyan-lit gauntlets, exposed head with a stylized recognizable likeness. Separate movement and ability sheets use that same reference. Sources remain immutable; packing records source cells and alignment. All 14 required states have explicit artwork. Three authored poses per attack map to startup/contact/recovery. The movement cycles are a compact first pass, not high-frame-count animation.

The image prompts, atlas manifest and source files live under `art/characters/elon/`. Rebuild with `godot --headless --path . -s res://tools/pack_elon.gd`, then import. The packer isolates connected silhouettes, removes low-alpha halos, uses one scale per source sheet and aligns the boot footprint to the feet pivot. Source v02 lowers three contact arms to match the existing combat height. It checks pose counts and cell bounds, writes 27 poses to one atlas, derives a portrait from idle, and records a checksum.

## Validation

Windows Godot 4.7.2.stable.official.ed1daf0bf: 86 tests passed, 0 failed (79 prior + 7 new character tests). These cover the actual default roster/HUD/rematch, all animation IDs and attack phase timing, hitstop, strike damage, aimed/mirrored thruster hitboxes, bounded tractor hold and effect cleanup, and shield behavior. The original Vader fixtures remain unchanged to preserve historical coverage. The expected warn-once placeholder test still emits its deliberate warning.

`tools/capture_elon.gd` rendered the real match with OpenGL Compatibility: neutral stance, all five abilities with and without hitboxes, heavy facing both directions, victory, title and controls. A shield polygon triangulation error found during the first capture was fixed; the final capture completed without errors. The title's portrait display size and spacing were reduced to fit both portraits and the navigation hint at 1280x720; this changes layout only, not the existing Gandalf portrait file.

Known limits: two-pose walk/run/idle loops, single held airborne/reaction poses, and three-pose attacks. This is a complete playable first pass with room for temporal polish, not a high-frame-count finished animation set. No human controller playtest, balance certification, or exported-build testing is claimed. The CI matrix checks Godot 4.3 and 4.5 on the PR.
