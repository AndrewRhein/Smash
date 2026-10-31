extends Node2D
## The Twilight Citadel. Art reads authoritative platform rectangles.
const BACKDROP = preload("res://art/arena/twilight_citadel.png")
const STONE = preload("res://art/arena/citadel_platform.png")
var clock := 0.0

func _process(delta: float) -> void:
    clock += delta
    queue_redraw()

func _draw() -> void:
    draw_texture_rect(BACKDROP, Rect2(0, 0, 1280, 720), false)
    draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.04, 0.09, 0.18))
    for i in range(24):
        var x := fmod(i * 197.0 + sin(clock * 0.15 + i) * 16.0, 1280.0)
        var y := 180.0 + fmod(i * 83.0 - clock * (2.0 + i % 3) + 2000.0, 470.0)
        var alpha := 0.12 + 0.1 * sin(clock + i)
        draw_circle(Vector2(x, y), 1.2, Color(0.85, 0.78, 0.55, alpha))
    for definition: Dictionary in Stage.PLATFORMS:
        _platform(Rect2(definition.center - definition.size * 0.5, definition.size), definition.one_way)

func _platform(rect: Rect2, one_way: bool) -> void:
    var x := rect.position.x
    var y := rect.position.y
    var w := rect.size.x
    # Source regions remove transparent padding without modifying the asset.
    # Masonry is the solid body; the rocky underside is ornamental.
    var source := Rect2(26, 226, 2119, 332)
    var target := Rect2(x, y, w, 94)
    if one_way:
        source = Rect2(760, 226, 650, 190)
        target.size.y = rect.size.y + 8
    draw_texture_rect_region(STONE, target, source)
    # Exact landing edge, including the ends of every collision rectangle.
    draw_rect(Rect2(x, y, w, 2), Color("c7bda3"))
    if one_way:
        var bottom := rect.end.y + 7
        for i in range(3):
            draw_line(Vector2(x + 7, bottom + i * 2), Vector2(x + w - 7, bottom + i * 2), Color(0.3, 0.77, 0.9, 0.16 / (i + 1)), 2)
    else:
        draw_circle(Vector2(x + w * 0.5, y + 35), 12, Color(0.25, 0.8, 1.0, 0.04 + sin(clock * 1.5) * 0.015))
