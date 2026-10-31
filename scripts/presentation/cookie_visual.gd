extends Node2D
## Kevin's talking cookie: a spinning chocolate-chip cookie with a face and a
## speech bubble. Presentation only; the parent Projectile owns gameplay.
const LINES := ["Eat me!", "Crunch time!", "Fresh baked!", "I'm delicious!", "Got milk?"]
var age := 0.0
var line := ""

func _ready() -> void:
	line = LINES[get_instance_id() % LINES.size()]

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, sin(age * 9.0) * 0.5, Vector2.ONE)
	draw_circle(Vector2.ZERO, 13.0, Color(0.36, 0.22, 0.1))
	draw_circle(Vector2.ZERO, 12.0, Color(0.85, 0.6, 0.3))
	for c: Vector2 in [Vector2(-7, -5), Vector2(6, -7), Vector2(-4, 7), Vector2(8, 5), Vector2(0, -10)]:
		draw_circle(c, 1.8, Color(0.3, 0.16, 0.08))
	draw_circle(Vector2(-3.5, -1.5), 2.2, Color.WHITE)
	draw_circle(Vector2(3.5, -1.5), 2.2, Color.WHITE)
	draw_circle(Vector2(-3.2, -1.2), 1.1, Color.BLACK)
	draw_circle(Vector2(3.8, -1.2), 1.1, Color.BLACK)
	draw_arc(Vector2(0, 2.5), 4.0, 0.2, PI - 0.2, 8, Color(0.3, 0.1, 0.05), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Speech bubble, upright (the projectile never rotates).
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	var box := Rect2(Vector2(-size.x / 2.0 - 5, -40), Vector2(size.x + 10, 17))
	draw_rect(box, Color(1, 1, 1, 0.95))
	draw_rect(box, Color(0.2, 0.2, 0.2), false, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -23), Vector2(4, -23), Vector2(0, -16)]), Color(1, 1, 1, 0.95))
	draw_string(font, Vector2(box.position.x + 5, -28), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.1, 0.05))
