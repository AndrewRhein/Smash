# Character visual pack — development build

This package contains the original game scaffold plus an independent art preview.
It is NOT a finished Gandalf-versus-Vader match. Claude owns the gameplay branch.

## Included

- Gandalf: 14 animation states, 70 playback frames from 67 distinct source poses.
- Transparent indexed PNG atlases, one shared palette, fixed scale within each source sequence, explicit feet pivots.
- A Godot SpriteFrames resource and a presentation adapter.
- Twelve procedural effect IDs covering staff, magic, saber, Force, impact and respawn.
- An interactive Godot art lab, per-animation GIFs, a montage, and an offline HTML gallery.
- Source sheets, explicit extraction recipes, structural tests and integration notes.

Vader artwork is missing: repeated requests were blocked by the image service. His manifest lists every required state with zero frames and no texture. No unrelated character is substituted.

## Preview without Godot

Open `art/previews/character_gallery.html` in a browser. It is self-contained and makes no network requests. You can pause, replay, change speed and mirror the sprites. Individual GIFs and `gandalf_all_states.gif` are also in that directory.

The downloadable ZIP includes source sheets and generated previews. A GitHub checkout contains the smaller runtime assets and tools; run `python tools/build_art_gallery.py` to create the offline gallery without source sheets or extra packages.

## Preview in Godot

Import `project.godot` into Godot 4.3 or newer. Open `scenes/art_preview.tscn` and press **F6**. Use the animation selector, replay, flip, pause and speed controls. Select and play any effect separately. The ordinary F5 main scene remains the original scaffold.

Godot is unavailable in the build environment. The PNG/resource checks pass, but engine parsing, live Godot playback, controller behavior and a Windows export have not been verified.

## Rebuild or check

```
python -m pip install Pillow numpy scipy
python tools/build_character_pack.py
python tools/build_art_gallery.py
python tools/verify_character_pack.py
```

The original source sheets are immutable inputs in `art/source_candidates/`. Rebuilding preserves no manual edits to derived atlases; make revisions in the recipe or use new versioned sources.

## Quality status

These are usable **review assets**, not certified final animation. Walk/run are four-pose cycles. Casting sequences use intentional held poses where generation lost the staff. Source-to-source costume/scale variation and action transitions still need temporal review and refinement. Sprite timing never defines hit timing.

See `docs/ART_INTEGRATION.md` and `docs/art_validation.json` for exact integration and verification status.
