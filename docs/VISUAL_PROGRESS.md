# Visual milestone: Gandalf idle review pipeline

## Delivered

- Eight-frame Gandalf idle atlas with 192x192 cells, 768x384 total, pivot (96,160).
- Common scale, common 96-color palette, nearest-neighbor resampling and explicit alpha cleanup.
- SpriteFrames resource with the `idle` ID, 8 fps and looping enabled.
- Standalone `scenes/art_preview.tscn` showing actual-size, enlarged and mirrored playback.
- Presentation adapter for the proposed signals, fixed-duration animations, facing and hitstop. No gameplay scripts changed.
- Reproducible extraction recipe and GIF preview.

## Validation performed

PNG structural validator passes: eight nonempty frames, none touching cell edges. All eight opaque foot baselines end at y=160; visible height is 112 pixels. Contact sheet was inspected. GIF was generated for temporal review; this does not establish a smooth loop. Godot is unavailable in this environment, so GDScript parsing, import and live scene playback are NOT tested. Gameplay integration remains pending Claude's implementation and exact snapshot getter name. Adapter currently assumes equal-duration frames; the included idle resource meets that assumption.

The generation source is still a review candidate: subtle idle poses may exhibit cloth/face changes that need manual refinement. No other animation is supplied; missing IDs deliberately warn and display idle. Do not interpret that fallback as a completed moveset.

Vader generation failed with an image-service output moderation block. No Vader artwork was created in this milestone. Do not substitute unrelated art without recording the change.

## Run/reproduce

Open `project.godot`, select `scenes/art_preview.tscn`, and run that scene (F6). The game's main scene is unchanged.

The processed atlas and resources are sufficient to run the preview. Reproduction additionally needs the original generated source placed at `art/source_candidates/gandalf_idle_v01.png`; it was shown in the conversation and retained locally, but is not required at runtime.

```
python -m pip install Pillow
python tools/pack_idle_candidate.py art/source_candidates/gandalf_idle_v01.png
python tools/validate_sprite_sheet.py art/characters/gandalf/idle.png --columns 4 --rows 2
```

Next acceptance gate: engine playback and temporal refinement, followed by locomotion and one light attack before expanding the animation list.
