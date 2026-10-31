extends Node2D
## Kevin's airstrike: a missile diving nose-down with a flame trail.
## Presentation only; the parent Projectile owns gameplay.
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	# Flame and smoke trail above the missile.
	for i in 6:
		var y := -30.0 - i * 11.0
		var r := 7.0 + i * 1.6 + sin(age * 30.0 + i) * 1.5
		var col := Color(1.0, 0.75 - i * 0.1, 0.2, 0.85 - i * 0.12) if i < 2 else Color(0.55, 0.55, 0.55, 0.45 - i * 0.06)
		draw_circle(Vector2(sin(age * 17.0 + i) * 2.0, y), r, col)
	# Body (pointing down).
	draw_rect(Rect2(-7, -26, 14, 32), Color(0.45, 0.5, 0.42))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 6), Vector2(7, 6), Vector2(0, 20)]), Color(0.75, 0.2, 0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -26), Vector2(-15, -32), Vector2(-7, -16)]), Color(0.35, 0.38, 0.33))
	draw_colored_polygon(PackedVector2Array([Vector2(7, -26), Vector2(15, -32), Vector2(7, -16)]), Color(0.35, 0.38, 0.33))
	draw_rect(Rect2(-7, -26, 14, 32), Color(0.15, 0.15, 0.15), false, 1.0)
	draw_rect(Rect2(-7, -8, 14, 3), Color(1, 0.85, 0.2))
