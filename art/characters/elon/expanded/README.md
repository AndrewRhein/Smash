# Expanded Elon animation pack

The sixteen user-supplied sheets produce 104 playback frames. Original sheets remain in `sources`; `recipe.json` maps their supplied filenames, grids, scale and selected frame order. `manifest.json` records extraction bounds, alignment, source hashes and atlas checksum.

The Elon scene opts into longer phase sequences and cosmetic entrance/landing transitions. Attacks retain gameplay startup, contact and recovery timing. Landing cancels immediately for attacks or airborne states and freezes during hitstop. Other characters retain their existing presentation settings. Combat data and other artwork are unchanged.

## Source adjustments

- Walk omits its duplicate terminal neutral pose.
- Jump omits the first two poses with cropped boots.
- Hurt omits the initial neutral pose.
- Fall uses source frames 0, 1, 2, 1 as a loop, omitting the grounded pose.
- Four `_v2` sheets were edited with the built-in image generator, with transparency enabled. Originals are preserved. These remain generated pose sequences; some pose-to-pose variation remains.

### Repair prompts

Ion Jab: Remove the black background completely into true transparency. Keep all 8 poses, grid 4 columns x 2 rows, face costume body scale and identity. Correct ONLY the fully extended punches (top row column 4 and bottom row column 1): lower the forward punching arm to BELT/WAIST height rather than shoulder height, horizontal right. Keep body and feet positions unchanged. Preserve clean silhouette and silver cyan gauntlets. No glow background or effects. Do not clip any body part. Output same layout.

Rocket Hammer: Repair this eight-pose 4 column x 2 row transparent sprite sheet: hammer heads in top row columns 3 and 4 touch/cross the top canvas edge. Restore their missing top outlines and give all sprites generous transparent padding within evenly spaced cells. Keep ALL eight poses in exactly the same order, character identity, costume, hammer design, proportions and consistent scale. Scale the whole set uniformly smaller if needed to fit complete hammer heads; do not shrink individual figures differently. Preserve actual transparent background; no effects, ground, shadow, or glow.

Thruster Burst and Orbital Tractor, separately: Precise sprite-sheet edit. Preserve this 4-column x 2-row eight-pose character sheet, identical costume face proportions scale and foot placement. Change ONLY the extended arm in frame 4 (top row column 4) and frame 5 (bottom row column 1). Lower that extended forearm and palm so they point horizontally RIGHT at BELT HEIGHT, level with the belt buckle, not at chest or shoulder height. Keep the natural bent elbow, gauntlet and hand gesture. All other six poses unchanged. True transparent background, no effects, no shadows or backdrop. Keep all bodies and hands fully inside the canvas.

## Rebuild and review

Run from the project root:

```sh
godot --headless --path . -s res://tools/pack_elon_expanded.gd
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd
node tools/build_elon_gallery.mjs /absolute/path/animation-review.html
```

The standalone HTML review includes frame scrubbing, mirroring and playback speed. It previews attacks at even frame durations; gameplay uses the scene's phase mappings. Browser review was interrupted by the user; actual Godot captures were reviewed. Local Godot 4.7.2 validation: 137 tests passed, including nine Elon tests. Legacy Elon sources, atlas and portrait remain available unchanged.
