class_name MenuBackdrop
extends Control
## Full-screen menu background: the arena art, darkened, with a vignette,
## slow drifting light rays and embers. Presentation only.

const ART := preload("res://art/arena/twilight_citadel.png")
var _t := 0.0
var _embers: Array[Vector3] = []   # x, y, speed


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		_embers.append(Vector3(rng.randf_range(0, 1280), rng.randf_range(0, 720), rng.randf_range(12, 40)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Slow Ken Burns drift on the art.
	var zoom := 1.06 + 0.02 * sin(_t * 0.15)
	var drift := Vector2(sin(_t * 0.07) * 18.0, 0)
	var art_size := Vector2(1280, 720) * zoom
	draw_texture_rect(ART, Rect2((Vector2(1280, 720) - art_size) / 2.0 + drift, art_size), false, Color(0.42, 0.44, 0.58))
	# Light rays from the top.
	for i in 5:
		var x := 200.0 + i * 230.0 + sin(_t * 0.3 + i) * 30.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 30, -10), Vector2(x + 30, -10), Vector2(x + 180, 730), Vector2(x + 40, 730)]),
			Color(1.0, 0.85, 0.6, 0.025 + 0.012 * sin(_t * 0.8 + i * 1.7)))
	# Embers rising.
	for e in _embers:
		var y := fposmod(e.y - _t * e.z, 760.0) - 20.0
		var x := e.x + sin(_t * 0.9 + e.y) * 12.0
		draw_circle(Vector2(x, y), 1.6, Color(1.0, 0.7, 0.35, 0.35 + 0.25 * sin(_t * 3.0 + e.x)))
	# Vignette: darker edges, darkest at the bottom.
	var dark := Color(0.01, 0.015, 0.035, 0.85)
	var clear := Color(0.01, 0.015, 0.035, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 160), Vector2(0, 160)]), PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(0, 460), Vector2(1280, 460), Vector2(1280, 720), Vector2(0, 720)]), PackedColorArray([clear, clear, dark, dark]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(260, 0), Vector2(260, 720), Vector2(0, 720)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(1020, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(1020, 720)]), PackedColorArray([clear, dark, dark, clear]))
