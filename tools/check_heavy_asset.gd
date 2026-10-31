extends SceneTree
## Structural check for the revised atlas, independent of rendering.
func _initialize() -> void:
    var path := "res://art/characters/gandalf/heavy_staff.png"
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/gandalf/manifest.json"))
    var image := Image.new()
    assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
    assert(image.get_size() == Vector2i(1536, 256))
    assert(FileAccess.get_sha256(path) == manifest.animations.heavy_staff.sha256)
    for frame in range(6):
        var pose := image.get_region(Rect2i(frame * 256, 0, 256, 256))
        var bounds := pose.get_used_rect()
        assert(bounds.has_area())
        assert(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 256 and bounds.end.y < 256)
        for y in range(256):
            for x in range(256):
                var alpha := pose.get_pixel(x, y).a
                assert(alpha == 0.0 or alpha == 1.0)
    print("Heavy atlas: dimensions, six nonempty unclipped poses, binary alpha and manifest checksum PASS")
    quit()
