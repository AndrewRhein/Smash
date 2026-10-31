# Visual direction and production gates

Branch: `codex/visuals`. Gameplay remains owned by Claude on its separate branch.

## Direction

Detailed side-view pixel art with readable silhouettes and restrained shading. Gandalf: slate-grey robes, silver beard, bent pointed hat, warm wood staff, icy blue magic. Vader: black armor separated by cool rim highlights, heavy cape, red saber. Preserve recognizable proportions rather than chibi exaggeration. Lighting comes from upper left; attack glows are separate overlays.

Target presentation: 1280x720. Start with 192x192 transparent animation cells, feet pivot (96,160), character height roughly 104–120 game pixels, nearest texture filtering. These are target asset specifications, not claims about generated source dimensions. Use larger cells with explicit pivots for attacks that need additional reach. Keep physics independent of visual bounds. Avoid nearest-neighbor downsampling until pixel clusters have been checked at target size.

## Production order

1. Validate an idle loop for each character, then one locomotion cycle and one light attack. Establish identity, silhouette, feet alignment and playback quality before mass production.
2. Expand to the shared idle/walk/run/jump/fall/hurt/knockback/defeat/victory states and the five character-specific move animation IDs in CLAUDE_HANDOFF.md.
3. Build separate background layers: sky and celestial body; distant mountains/castle and Imperial fortress; forest/waterfall and lava; foreground platform skins. Keep combat space lower contrast and avoid baked-in fighters, UI, projectiles or collision geometry.
4. Add separate magic/saber effects, impact flashes, restrained hit particles and respawn cues. Keep effects readable and subordinate to attack silhouettes.
5. Polish HUD portraits, damage typography, stock symbols and match results after the gameplay API is available.

## Integration

Use the version-1 presentation contract in CLAUDE_HANDOFF.md. Art attaches beneath VisualRoot; root stays feet-centered. Animation IDs and timing come from gameplay. Positive duration means match the authored animation to the gameplay duration, not change attack duration to fit the sprite count. Facing mirrors presentation around the pivot. Hitstop freezes presentation using the snapshot API. Visual assets never determine hits or hurtboxes.

## Acceptance gates

- Actual alpha transparency; no checkerboard painted into the image.
- Explicit source dimensions and cell layout; reject a sheet that cannot be divided into its declared uniform grid.
- No clipping, neighbor-frame bleed, floating feet, or unintended scale changes.
- Same costume, staff/saber hand, face/helmet and light direction throughout the cycle.
- Loop seam reviewed in motion at game size; attack anticipation, contact and recovery reviewed separately.
- Crisp readable pixels at intended scale; generated painterly detail is not automatically accepted as pixel art.
- Engine import and scene playback tested separately from PNG validation.
- Missing animations and untested steps remain labeled as such.

## Current status

The first eight-pose Gandalf idle candidate was generated with the built-in image tool. Prompt requested a 1024x1024 sheet in a 4x2 grid, transparent background, same three-quarter-right Gandalf, subtle breathing and cloth drift, feet aligned, restrained blue-grey shading, no scene/UI/text.

Actual output is 1254x1254 RGBA, which is not divisible into four equal-width columns. Alpha exists but faint edge artifacts and pose alignment require review. The candidate is NOT approved, integrated, or tested in Godot. No Godot executable was found in the current environment. Candidate source is retained locally at `art/source_candidates/gandalf_idle_v01.png`; binary source upload is pending. Do not reference this candidate from the runnable game yet.
