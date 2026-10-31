extends SceneTree
## Deterministic extraction/packing; original supplied artwork remains immutable.
const BASE := "res://art/characters/elon/expanded/"
const CELL := 256
const PIVOT := Vector2i(128, 208)

func _initialize() -> void:
    var recipe: Array = JSON.parse_string(FileAccess.get_file_as_string(BASE + "recipe.json"))
    var packer = load("res://tools/pack_elon.gd").new()
    var atlas := Image.create(2048, 3840, false, Image.FORMAT_RGBA8)
    var records: Array = []
    var entries: PackedStringArray = []
    var resources := ""
    var animations: Dictionary = {}
    var index := 0
    for spec: Dictionary in recipe:
        var name: String = spec.id
        var path := BASE + "sources/" + name + ".png"
        if name in ["ion_jab", "rocket_hammer", "thruster_burst", "orbital_tractor"]:
            var revision := BASE + "sources/" + name + "_v2.png"
            if FileAccess.file_exists(revision):
                path = revision
        var poses: Array = packer.components(path, int(spec.columns), int(spec.rows))
        var height := float(spec.height)
        if name == "rocket_hammer" and path.ends_with("_v2.png"):
            height = 350.0
        var factor := 112.0 / height
        var order: Array = spec.order
        if order.is_empty():
            order = range(poses.size())
        var frame_entries: PackedStringArray = []
        var frame_ids: Array = []
        for source_index in order:
            var item: Dictionary = poses[int(source_index)]
            var pose: Image = item.image.duplicate()
            var rect: Rect2i = item.rect
            # Grounded feet are aligned; airborne hips stay at a fixed body origin.
            var source_pivot := Vector2(pose.get_width() * 0.5, pose.get_height())
            if name in ["jump", "fall", "knockback"]:
                # Anchor the torso rather than dragging tucked boots to the floor.
                source_pivot = Vector2(pose.get_width() * 0.46, height)
            else:
                var feet := Rect2i()
                for y in range(maxi(0, pose.get_height() - 12), pose.get_height()):
                    for x in pose.get_width():
                        if pose.get_pixel(x, y).a > 0:
                            feet = Rect2i(x, y, 1, 1) if not feet.has_area() else feet.merge(Rect2i(x, y, 1, 1))
                source_pivot.x = feet.get_center().x
            var size := Vector2i(roundi(pose.get_width() * factor), roundi(pose.get_height() * factor))
            pose.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
            var offset := PIVOT - Vector2i(roundi(source_pivot.x * factor), roundi(source_pivot.y * factor))
            assert(offset.x > 0 and offset.y > 0 and offset.x + size.x < CELL and offset.y + size.y < CELL, "Clipped packed pose: " + name)
            atlas.blit_rect(pose, Rect2i(Vector2i.ZERO, size), Vector2i(index % 8, index / 8) * CELL + offset)
            resources += '\n[sub_resource type="AtlasTexture" id="Pose_%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, 256, 256)\n' % [index, index % 8 * CELL, index / 8 * CELL]
            frame_entries.append('{"duration": 1.0, "texture": SubResource("Pose_%d")}' % index)
            frame_ids.append(index)
            records.append({"animation": name, "source": path.trim_prefix(BASE), "source_frame": source_index, "bounds": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "scale": factor, "pivot": [source_pivot.x, source_pivot.y], "offset": [offset.x, offset.y], "size": [size.x, size.y], "sha256": FileAccess.get_sha256(path)})
            index += 1
        animations[name] = frame_ids
        var loop: bool = name in ["idle", "walk", "run", "fall"]
        entries.append('{"name": &"%s", "loop": %s, "speed": %s, "frames": [%s]}' % [name, str(loop), str(spec.fps), ", ".join(frame_entries)])
    assert(atlas.save_png(BASE + "atlas.png") == OK)
    var resource := '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n[ext_resource type="Texture2D" path="%satlas.png" id="1"]\n' % [index + 2, BASE]
    resource += resources + '\n[resource]\nanimations = [\n' + ",\n".join(entries) + "\n]\n"
    FileAccess.open(BASE + "animations.tres", FileAccess.WRITE).store_string(resource)
    FileAccess.open(BASE + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify({"frames": records, "animations": animations, "playback_frames": index, "atlas_sha256": FileAccess.get_sha256(BASE + "atlas.png"), "pivot": [128, 208]}, "  ") + "\n")
    packer.free()
    print("Packed ", index, " playback frames across ", animations.size(), " animations")
    quit()
