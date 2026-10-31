extends SceneTree
## Pack the reviewed imagegen source, without regenerating other animations.
## godot --headless --path . -s res://tools/pack_heavy_revision.gd
const SOURCE := "res://art/source_candidates/gandalf_heavy_v03.png"
const OUTPUT := "res://art/characters/gandalf/heavy_staff.png"
const SCALE := 0.44
const EDGES := [0, 350, 710, 1120, 1560, 1850, 2172]
const FEET := [165, 536, 868, 1308, 1660, 2010]

func _initialize() -> void:
    var source := Image.new()
    assert(source.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE)) == OK)
    var atlas := Image.create(1536, 256, false, Image.FORMAT_RGBA8)
    var records: Array = []
    for i in range(6):
        var rect := Rect2i(EDGES[i], 210, EDGES[i + 1] - EDGES[i], 340)
        var pose := source.get_region(rect)
        pose.resize(roundi(rect.size.x * SCALE), roundi(rect.size.y * SCALE), Image.INTERPOLATE_NEAREST)
        for y in pose.get_height():
            for x in pose.get_width():
                var color := pose.get_pixel(x, y)
                color.a = 1.0 if color.a >= 180.0 / 255.0 else 0.0
                pose.set_pixel(x, y, color)
        var offset := Vector2i(i * 256 + 128 + roundi((EDGES[i] - FEET[i]) * SCALE), 208 + roundi((210 - 544) * SCALE))
        atlas.blit_rect(pose, Rect2i(Vector2i.ZERO, pose.get_size()), offset)
        records.append({"source_box": [rect.position.x, 210, EDGES[i + 1], 550], "source_pivot": [FEET[i], 544], "scale": SCALE})
    assert(atlas.save_png(OUTPUT) == OK)
    var path := "res://art/characters/gandalf/manifest.json"
    var original := FileAccess.get_file_as_string(path)
    var manifest: Dictionary = JSON.parse_string(original)
    var record: Dictionary = manifest.animations.heavy_staff
    record.source = "gandalf_heavy_v03.png"
    record.frame_count = 6
    record.fps = 12
    record.frames = records
    record.sha256 = FileAccess.get_sha256(OUTPUT)
    record.known_issues = ["Recovery still changes grip between the last two poses; temporal polish pending."]
    record["packing_tool"] = "tools/pack_heavy_revision.gd"
    record["palette_colors"] = "RGBA revision; binary alpha"
    # Preserve all other recipes byte-for-byte (JSON parsing changes float precision).
    var begin := original.find('    "heavy_staff": {')
    var end := original.find('    "lightning": {', begin)
    assert(begin >= 0 and end > begin)
    var replacement := '    "heavy_staff": ' + JSON.stringify(record, "  ", false).replace("\n", "\n    ") + ",\n"
    FileAccess.open(path, FileAccess.WRITE).store_string(original.substr(0, begin) + replacement + original.substr(end))
    quit()
