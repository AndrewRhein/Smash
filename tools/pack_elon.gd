extends SceneTree
## Reproducible packing of immutable generated poses. No other artwork changes.
const BASE := "res://art/characters/elon/"
const CELL := 256
const PIVOT := Vector2i(128, 208)
var records: Array = []

func _initialize() -> void:
    var movement := components(BASE + "movement_source.png", 4, 3)
    var actions := components(BASE + "actions_v02.png", 3, 5)
    assert(movement.size() == 12, "Expected twelve movement poses")
    assert(actions.size() == 15, "Expected fifteen action poses")
    var atlas := Image.create(2048, 1024, false, Image.FORMAT_RGBA8)
    var movement_scale := 112.0 / float(movement[0].rect.size.y)
    var action_scale := 112.0 / float(actions[0].rect.size.y)
    var poses: Array[Image] = []
    for i in range(27):
        var item: Dictionary = movement[i] if i < 12 else actions[i - 12]
        var scale: float = movement_scale if i < 12 else action_scale
        var pose: Image = item.image
        # Feet origin uses the boot footprint, not a weapon-inclusive bounding box.
        var footprint := Rect2i()
        for y in range(maxi(0, pose.get_height() - 10), pose.get_height()):
            for x in range(pose.get_width()):
                if pose.get_pixel(x, y).a > 0:
                    footprint = Rect2i(x, y, 1, 1) if not footprint.has_area() else footprint.merge(Rect2i(x, y, 1, 1))
        var foot_x := footprint.get_center().x
        var foot_y := pose.get_height()
        var size := Vector2i(roundi(pose.get_width() * scale), roundi(pose.get_height() * scale))
        pose.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
        var offset := PIVOT - Vector2i(roundi(foot_x * scale), roundi(foot_y * scale))
        assert(offset.x > 0 and offset.y > 0 and offset.x + size.x < CELL and offset.y + size.y < CELL, "Pose clips cell")
        var frame := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
        frame.blit_rect(pose, Rect2i(Vector2i.ZERO, size), offset)
        poses.append(frame)
        atlas.blit_rect(frame, Rect2i(0, 0, CELL, CELL), Vector2i(i % 8, i / 8) * CELL)
        var rect: Rect2i = item.rect
        records.append({"source": "movement_source.png" if i < 12 else "actions_v02.png", "bounds": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "scale": scale, "source_pivot": [rect.position.x + foot_x, rect.position.y + foot_y]})
    assert(atlas.save_png(BASE + "atlas.png") == OK)
    # Portrait derived from the accepted idle sprite; no separate identity drift.
    var portrait := poses[0].get_region(Rect2i(103, 94, 54, 65))
    portrait.resize(106, 128, Image.INTERPOLATE_NEAREST)
    var portrait_canvas := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    portrait_canvas.blit_rect(portrait, Rect2i(0, 0, 106, 128), Vector2i(11, 0))
    assert(portrait_canvas.save_png(BASE + "portrait.png") == OK)
    var animations := {
        "idle": [0, 1], "walk": [2, 3], "run": [4, 5], "jump": [6], "fall": [7],
        "hurt": [8], "knockback": [9], "defeat": [10], "victory": [11],
        "ion_jab": [12, 13, 14], "rocket_hammer": [15, 16, 17], "thruster_burst": [18, 19, 20],
        "orbital_tractor": [21, 22, 23], "energy_shield": [24, 25, 26]
    }
    var resource := '[gd_resource type="SpriteFrames" load_steps=29 format=3]\n\n[ext_resource type="Texture2D" path="res://art/characters/elon/atlas.png" id="1"]\n'
    for i in range(27):
        resource += '\n[sub_resource type="AtlasTexture" id="Pose_%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, 256, 256)\n' % [i, i % 8 * CELL, i / 8 * CELL]
    var entries: PackedStringArray = []
    for name: String in animations:
        var frame_entries: PackedStringArray = []
        for index: int in animations[name]:
            frame_entries.append('{"duration": 1.0, "texture": SubResource("Pose_%d")}' % index)
        var loop: bool = name in ["idle", "walk", "run", "fall"]
        var speed := 2.0 if name == "idle" else (10.0 if name == "run" else 6.0)
        entries.append('{"name": &"%s", "loop": %s, "speed": %s, "frames": [%s]}' % [name, "true" if loop else "false", speed, ", ".join(frame_entries)])
    resource += '\n[resource]\nanimations = [\n' + ",\n".join(entries) + "\n]\n"
    FileAccess.open(BASE + "animations.tres", FileAccess.WRITE).store_string(resource)
    var manifest := {"character_id": "elon", "status": "first_pass_playable", "cell_size": [256, 256], "pivot": [128, 208], "unique_poses": 27, "animations": animations, "frames": records, "atlas_sha256": FileAccess.get_sha256(BASE + "atlas.png"), "known_limits": ["Two-pose locomotion loops", "Single held poses for airborne and reaction states", "Three-pose attacks; further temporal polish possible"]}
    FileAccess.open(BASE + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "  ", false) + "\n")
    print("Packed 27 authored poses into 14 states, plus portrait")
    quit()

func components(path: String, columns: int, rows: int) -> Array:
    var image := Image.new()
    assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
    image.convert(Image.FORMAT_RGBA8)
    var w := image.get_width()
    var h := image.get_height()
    var bytes := image.get_data()
    var visited := PackedByteArray()
    visited.resize(w * h)
    var found: Array = []
    for start in range(w * h):
        if visited[start] != 0 or bytes[start * 4 + 3] < 180:
            continue
        var pixels := PackedInt32Array([start])
        visited[start] = 1
        var cursor := 0
        var min_x := w
        var min_y := h
        var max_x := 0
        var max_y := 0
        while cursor < pixels.size():
            var p := pixels[cursor]
            cursor += 1
            var x := p % w
            var y := p / w
            min_x = mini(min_x, x)
            max_x = maxi(max_x, x)
            min_y = mini(min_y, y)
            max_y = maxi(max_y, y)
            for offset in [-w, w, -1, 1]:
                var next: int = p + offset
                if next < 0 or next >= w * h or (offset == -1 and x == 0) or (offset == 1 and x == w - 1):
                    continue
                if visited[next] == 0 and bytes[next * 4 + 3] >= 180:
                    visited[next] = 1
                    pixels.append(next)
        if pixels.size() < 2000:
            continue
        var rect := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
        var pose := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
        for p in pixels:
            pose.set_pixel(p % w - min_x, p / w - min_y, Color8(bytes[p * 4], bytes[p * 4 + 1], bytes[p * 4 + 2], 255))
        found.append({"image": pose, "rect": rect, "row": mini(rows - 1, int(float(rect.get_center().y) / h * rows))})
    found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return a.rect.position.x < b.rect.position.x if a.row == b.row else a.row < b.row)
    print(path, ": ", found.size(), " components")
    assert(found.size() == columns * rows, "Unexpected connected pose count")
    return found
