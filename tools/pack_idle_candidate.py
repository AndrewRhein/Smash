"""Reproduce the Gandalf idle review atlas from the retained generated source.

Pillow required. This explicitly handles the source's 1254px uneven grid;
it is not a generic automatic sprite extractor. Run from project root:
python tools/pack_idle_candidate.py art/source_candidates/gandalf_idle_v01.png
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw


def pack(source: Path, root: Path) -> None:
    image = Image.open(source).convert("RGBA")
    if image.size != (1254, 1254):
        raise ValueError("This extraction recipe expects the reviewed 1254x1254 source")
    out = root / "art/characters/gandalf"
    out.mkdir(parents=True, exist_ok=True)
    preview_dir = root / "art/previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    frames = []
    recipe = []
    # A fixed scale preserves relative proportions. Never scale each pose to fit.
    scale = 112 / 510
    for index in range(8):
        row, column = divmod(index, 4)
        left, right = round(column * 1254 / 4), round((column + 1) * 1254 / 4)
        crop = image.crop((left, row * 627, right, (row + 1) * 627))
        # Remove the source's low-alpha colored fringe. Keep original untouched.
        crop.putalpha(crop.getchannel("A").point(lambda a: 255 if a >= 160 else 0))
        resized = crop.resize((round(crop.width * scale), round(crop.height * scale)), Image.Resampling.NEAREST)
        frame = Image.new("RGBA", (192, 192))
        # Source feet baseline is y=582 for all eight poses, verified from alpha.
        offset = (96 - round(157 * scale), 160 - round(582 * scale))
        frame.alpha_composite(resized, offset)
        frames.append(frame)
        recipe.append({"source_rect": [left, row * 627, right - left, 627], "source_pivot": [157, 582]})
    atlas = Image.new("RGBA", (768, 384))
    for i, frame in enumerate(frames):
        atlas.alpha_composite(frame, ((i % 4) * 192, (i // 4) * 192))
    # One shared palette prevents per-frame palette flicker and keeps assets small.
    indexed_atlas = atlas.quantize(colors=96, method=Image.Quantize.FASTOCTREE,
                                   dither=Image.Dither.NONE)
    atlas = indexed_atlas.convert("RGBA")
    frames = [atlas.crop((i % 4 * 192, i // 4 * 192,
                         (i % 4 + 1) * 192, (i // 4 + 1) * 192)) for i in range(8)]
    indexed_atlas.save(out / "idle.png", optimize=True)
    metadata = {"status": "review_candidate", "animation_id": "idle", "columns": 4, "rows": 2,
                "cell": [192, 192], "pivot": [96, 160], "fps": 8, "loop": True,
                "alpha_cutoff": 160, "palette_colors": 96, "fixed_scale": scale, "source_frames": recipe}
    (out / "idle.json").write_text(json.dumps(metadata, indent=2) + "\n")
    previews = []
    for frame in frames:
        canvas = Image.new("RGBA", (384, 384), (27, 34, 49, 255))
        draw = ImageDraw.Draw(canvas)
        draw.line((0, 320, 384, 320), fill=(72, 95, 120), width=1)
        canvas.alpha_composite(frame.resize((384, 384), Image.Resampling.NEAREST))
        previews.append(canvas.convert("RGB"))
    previews[0].save(preview_dir / "gandalf_idle.gif", save_all=True, append_images=previews[1:],
                     duration=125, loop=0, disposal=2)
    contact = Image.new("RGBA", (768, 384), (27, 34, 49, 255))
    contact.alpha_composite(atlas)
    contact.save(preview_dir / "gandalf_idle_contact.png")
    text = ['[gd_resource type="SpriteFrames" load_steps=10 format=3]', '',
            '[ext_resource type="Texture2D" path="res://art/characters/gandalf/idle.png" id="1"]', '']
    for i in range(8):
        text += [f'[sub_resource type="AtlasTexture" id="Frame_{i}"]', 'atlas = ExtResource("1")',
                 f'region = Rect2({i % 4 * 192}, {i // 4 * 192}, 192, 192)', '']
    text += ['[resource]', 'animations = [{', '"frames": [']
    text += [f'{{"duration": 1.0, "texture": SubResource("Frame_{i}")}}' + (',' if i < 7 else '') for i in range(8)]
    text += ['],', '"loop": true,', '"name": &"idle",', '"speed": 8.0', '}]', '']
    (out / "idle.tres").write_text('\n'.join(text))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--root", type=Path, default=Path('.'))
    args = parser.parse_args()
    pack(args.source, args.root)
