#!/usr/bin/env python3
"""Reusable sprite packer for new fighters.

    python3 tools/pack_character.py art/characters/<id>/pack.json

Reads the character's source sheets (any mix of transparent PNG/WebP or flat
light backgrounds), cuts out every pose on a rows x cols grid, and writes
art/characters/<id>/{atlas.png, animations.tres, manifest.json, portrait.png}.

Sizing rules (the lesson from Elon's attacks growing 24%):
  * The reference pose (normally idle) is scaled to `idle_height` pixels.
  * Every other sheet is scaled so the character's HEAD is the same width as
    on the reference sheet (median over poses, robust to arms over the head).
  * Each pose is placed with its feet (bottom of the silhouette, centre of the
    lowest rows) on the shared pivot (128, 208) of a 256x256 cell.

Background removal for opaque sheets: neutral near-white pixels connected to
the border are background, plus enclosed neutral near-white pockets (gaps
between arms and body). Warm off-whites (robes, cloth) are kept.

Requires numpy, Pillow, scipy.
"""
import hashlib
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

CELL = 256
PIVOT = (128, 208)
COLS_IN_ATLAS = 8
LOOPING = {"idle", "walk", "run", "fall", "shield", "shield_break"}
SPEEDS = {"idle": 2.0, "walk": 6.0, "run": 10.0}


def load_mask(path):
    """RGBA image + boolean figure mask."""
    im = Image.open(path)
    rgba = np.asarray(im.convert("RGBA")).astype(np.int32)
    has_alpha = im.mode in ("RGBA", "LA") and rgba[..., 3].min() < 250
    if has_alpha:
        mask = rgba[..., 3] >= 128
    else:
        rgb = rgba[..., :3]
        mn, mx = rgb.min(2), rgb.max(2)
        sat = mx - mn
        warm = rgb[..., 0] - rgb[..., 2]
        cand = (mn >= 232) & (sat <= 10)
        lab, n = ndimage.label(cand)
        border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
        bg = np.isin(lab, list(border))
        # Enclosed pockets that look like the (neutral) background, not cloth.
        idx = np.arange(1, n + 1)
        mean_sat = ndimage.mean(sat, lab, idx)
        mean_warm = ndimage.mean(warm, lab, idx)
        size = ndimage.sum(cand, lab, idx)
        pockets = [i for i, s, w, z in zip(idx, mean_sat, mean_warm, size) if s <= 7 and w <= 4 and z >= 30]
        bg |= np.isin(lab, pockets)
        mask = ~bg
        # Peel 2 px of light, neutral anti-alias fringe left against the background.
        for _ in range(2):
            edge = mask & ~ndimage.binary_erosion(mask)
            fringe = edge & (mn >= 205) & (sat <= 12)
            mask &= ~fringe
        rgba[..., 3] = np.where(mask, 255, 0)
    mask = ndimage.binary_opening(mask, iterations=1)
    return rgba.astype(np.uint8), mask


def cut_poses(path, cols, rows, min_area=400):
    """Return poses (row-major): list of dicts {image (RGBA PIL), box}."""
    rgba, mask = load_mask(path)
    h, w = mask.shape
    lab, n = ndimage.label(mask)
    cells = {}
    for i, sl in enumerate(ndimage.find_objects(lab), start=1):
        area = int((lab[sl] == i).sum())
        if area < min_area:
            continue
        cy = (sl[0].start + sl[0].stop) / 2
        cx = (sl[1].start + sl[1].stop) / 2
        key = (min(rows - 1, int(cy / h * rows)), min(cols - 1, int(cx / w * cols)))
        cells.setdefault(key, []).append(i)
    poses = []
    for r in range(rows):
        for c in range(cols):
            ids = cells.get((r, c))
            if not ids:
                poses.append(None)  # empty grid cell
                continue
            m = np.isin(lab, ids)
            ys, xs = np.nonzero(m)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            crop = rgba[y0:y1, x0:x1].copy()
            crop[..., 3] = np.where(m[y0:y1, x0:x1], crop[..., 3], 0)
            poses.append({"image": Image.fromarray(crop, "RGBA"), "box": [int(x0), int(y0), int(x1 - x0), int(y1 - y0)],
                          "mask": m[y0:y1, x0:x1]})
    return poses


def head_width(pose, ref_height):
    """Median silhouette width a little below the top: the head."""
    m = pose["mask"]
    top = int(np.argmax(m.any(1)))
    widths = []
    for y in range(top + int(ref_height * 0.03), min(m.shape[0], top + int(ref_height * 0.12))):
        xs = np.nonzero(m[y])[0]
        if len(xs):
            widths.append(xs[-1] - xs[0])
    return float(np.median(widths)) if widths else 0.0


def feet(pose):
    m = pose["mask"]
    bottom = m.shape[0]
    rows = m[max(0, bottom - max(4, bottom // 40)):]
    xs = np.nonzero(rows.any(0))[0]
    return float((xs.min() + xs.max()) / 2), float(bottom)


def place(pose, scale):
    img = pose["image"]
    size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    small = img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    fx, fy = feet(pose)
    ox = round(PIVOT[0] - fx * scale)
    oy = round(PIVOT[1] - fy * scale)
    if ox < 0 or oy < 0 or ox + size[0] > CELL or oy + size[1] > CELL:
        raise SystemExit(f"pose does not fit the {CELL}px cell at scale {scale:.3f} (offset {ox},{oy} size {size})")
    cell = Image.new("RGBA", (CELL, CELL))
    cell.alpha_composite(small, (ox, oy))
    return cell


def main(spec_path):
    spec = json.load(open(spec_path))
    base = os.path.dirname(spec_path)
    sheets = {}
    for name, s in spec["sheets"].items():
        sheets[name] = cut_poses(os.path.join(base, s["file"]), s["cols"], s["rows"])
        found = sum(p is not None for p in sheets[name])
        print(f"{name}: {found} poses on a {s['cols']}x{s['rows']} grid")
    ref_sheet, ref_index = spec["reference"].split(":")
    ref_pose = sheets[ref_sheet][int(ref_index)]
    ref_h = ref_pose["box"][3]
    ref_head = np.median([head_width(p, ref_h) for p in sheets[ref_sheet] if p])
    if "head_width" in spec:
        # Preferred: every character's head is the same on-screen width, so
        # crouched and upright idle stances end up at a consistent body size.
        scales = {ref_sheet: spec["head_width"] / ref_head}
    else:
        scales = {ref_sheet: spec["idle_height"] / ref_h}
    for name, poses in sheets.items():
        if name in scales:
            continue
        typical_h = np.median([p["box"][3] for p in poses if p])
        heads = np.median([head_width(p, typical_h) for p in poses if p])
        scales[name] = scales[ref_sheet] * ref_head / heads
    print("scales:", {k: round(v, 4) for k, v in scales.items()})
    # Only poses referenced by animations go in the atlas, in first-use order.
    order, index_of = [], {}
    for frames in spec["animations"].values():
        for ref in frames:
            if ref not in index_of:
                sheet, i = ref.split(":")
                if sheets[sheet][int(i)] is None:
                    raise SystemExit(f"{ref} is an empty grid cell")
                index_of[ref] = len(order)
                order.append(ref)
    rows = (len(order) + COLS_IN_ATLAS - 1) // COLS_IN_ATLAS
    atlas = Image.new("RGBA", (CELL * COLS_IN_ATLAS, CELL * rows))
    records = []
    for k, ref in enumerate(order):
        sheet, i = ref.split(":")
        pose = sheets[sheet][int(i)]
        atlas.alpha_composite(place(pose, scales[sheet]), ((k % COLS_IN_ATLAS) * CELL, (k // COLS_IN_ATLAS) * CELL))
        records.append({"pose": ref, "source": spec["sheets"][sheet]["file"], "bounds": pose["box"], "scale": round(scales[sheet], 5)})
    out = base
    atlas.save(os.path.join(out, "atlas.png"))
    # Portrait: head and shoulders of the reference pose.
    ref_cell = place(ref_pose, scales[ref_sheet])
    bbox = ref_cell.getbbox()
    side = int((bbox[3] - bbox[1]) * 0.5)
    top = bbox[1] - 2
    fx = PIVOT[0]
    head_x = int(np.median(np.nonzero(np.asarray(ref_cell)[top + 6: top + 30, :, 3].max(0) > 0)[0]))
    portrait = ref_cell.crop((head_x - side // 2, top, head_x + side // 2, top + side)).resize((128, 128), Image.LANCZOS)
    portrait.save(os.path.join(out, "portrait.png"))
    # SpriteFrames resource.
    char_id = spec["id"]
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(order) + 2} format=3]', "",
             f'[ext_resource type="Texture2D" path="res://art/characters/{char_id}/atlas.png" id="1"]']
    for k in range(len(order)):
        lines += ["", f'[sub_resource type="AtlasTexture" id="Pose_{k}"]', 'atlas = ExtResource("1")',
                  f"region = Rect2({(k % COLS_IN_ATLAS) * CELL}, {(k // COLS_IN_ATLAS) * CELL}, {CELL}, {CELL})"]
    entries = []
    for name, frames in spec["animations"].items():
        fr = ", ".join('{"duration": 1.0, "texture": SubResource("Pose_%d")}' % index_of[r] for r in frames)
        entries.append('{"name": &"%s", "loop": %s, "speed": %s, "frames": [%s]}'
                       % (name, "true" if name in LOOPING else "false", SPEEDS.get(name, 6.0), fr))
    lines += ["", "[resource]", "animations = [", ",\n".join(entries), "]", ""]
    open(os.path.join(out, "animations.tres"), "w").write("\n".join(lines))
    manifest = {"character_id": char_id, "cell_size": [CELL, CELL], "pivot": list(PIVOT),
                "head_width": spec.get("head_width"), "scales": scales, "poses": records,
                "animations": {k: [index_of[r] for r in v] for k, v in spec["animations"].items()},
                "atlas_sha256": hashlib.sha256(open(os.path.join(out, "atlas.png"), "rb").read()).hexdigest()}
    open(os.path.join(out, "manifest.json"), "w").write(json.dumps(manifest, indent=2) + "\n")
    print(f"packed {len(order)} poses into {len(spec['animations'])} animations -> {out}")


if __name__ == "__main__":
    main(sys.argv[1])
