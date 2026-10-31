"""Validate sprite-sheet structure; this does not certify animation quality.

Requires Pillow. Example:
python tools/validate_sprite_sheet.py art/source_candidates/gandalf_idle_v01.png --columns 4 --rows 2
"""
import argparse
import json
from pathlib import Path
from PIL import Image


def inspect(path: Path, columns: int, rows: int) -> dict:
    if columns < 1 or rows < 1:
        raise ValueError("Grid dimensions must be positive")
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        errors = []
        warnings = []
        if "A" not in image.getbands() and "transparency" not in image.info:
            errors.append("Source has no transparency channel or transparent palette entry")
        if alpha.getextrema()[0] == 255:
            errors.append("Source is entirely opaque")
        if image.width % columns or image.height % rows:
            errors.append("Image dimensions are not divisible by the declared grid")
        cells = []
        if not errors:
            width, height = image.width // columns, image.height // rows
            for row in range(rows):
                for column in range(columns):
                    region = alpha.crop((column * width, row * height,
                                         (column + 1) * width, (row + 1) * height))
                    bounds = region.point(lambda a: 255 if a >= 128 else 0).getbbox()
                    index = row * columns + column
                    cells.append({"index": index, "opaque_bounds": bounds})
                    if bounds is None:
                        errors.append(f"Frame {index} has no substantially opaque pixels")
                    elif bounds[0] == 0 or bounds[1] == 0 or bounds[2] == width or bounds[3] == height:
                        warnings.append(f"Frame {index} touches a cell edge; inspect clipping")
        return {"file": str(path), "size": list(image.size), "grid": [columns, rows],
                "errors": errors, "warnings": warnings, "frames": cells,
                "structural_pass": not errors,
                "animation_quality": "Requires visual playback review"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--columns", required=True, type=int)
    parser.add_argument("--rows", required=True, type=int)
    args = parser.parse_args()
    report = inspect(args.path, args.columns, args.rows)
    print(json.dumps(report, indent=2))
    raise SystemExit(0 if report["structural_pass"] else 1)
