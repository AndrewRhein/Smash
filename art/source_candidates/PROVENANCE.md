# Generated source artwork

2026-10-31 revision: `gandalf_heavy_v03.png` was produced with the built-in imagegen edit tool using the shipped `heavy_staff.png` as its sole reference. The generated 2172x724 image is retained unchanged. `tools/pack_heavy_revision.gd` records extraction boxes, measured feet pivots, nearest-neighbor scale and binary alpha threshold. The final prompt is recorded in `gandalf_heavy_v03_prompt.txt`. No external API was used. The generated sheet did not preserve requested cell dimensions, so packing is explicit rather than trusting its layout.

All character sources were produced using the built-in image-generation tool in this conversation, with the original Gandalf idle sheet as the identity/style reference. No external API or paid service was invoked.

- gandalf_idle_v01.png: eight subtle idle poses, grey hat/robe/beard, staff, right-facing, 4 columns by2 rows.
- gandalf_movement_v01.png: four rows of four poses, walk/run/jump/fall.
- gandalf_staff_v01.png: quick staff strike and heavy staff attack, six poses each. Only the top/light row is used; overlapping heavy poses were rejected.
- gandalf_heavy_v02.png: replacement heavy staff attack, six poses in3 columns by2 rows.
- gandalf_specials_v01.png: lightning/fireball/magical push, six poses each. Lightning source pose4 and fireball source poses2/4 (zero-based) were rejected for losing the staff. Their slots hold valid adjacent poses instead.
- gandalf_reactions_v01.png: hurt/knockback/defeat/victory, four poses each.

Prompts requested true transparency, consistent identity, side view facing right, full figures within separate cells, no backgrounds/text/grid, and anticipation/contact/recovery where applicable. Generated dimensions/layout were not trusted; the build recipe stores measured source rectangles and explicit pivots.

Original PNGs are immutable. Low-alpha background fringes are removed in derived assets; connected-component segmentation separates overlapping bounding rectangles without copying neighboring figures. Shared-palette quantization is applied to all resulting Gandalf poses together.
