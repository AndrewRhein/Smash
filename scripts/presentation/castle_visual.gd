extends Node2D
## Tim's LEGO Castle: a little brick castle that pops up as a stationary trap.
## Presentation only; the parent Projectile owns gameplay (hit, lifetime).
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	var grow := clampf(age * 6.0, 0.0, 1.0)
	var fade := 1.0
	var parent := get_parent()
	if parent != null and "ticks_remaining" in parent:
		fade = clampf(parent.ticks_remaining / 30.0, 0.0, 1.0)
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1, grow))
	var wall := Color(0.78, 0.78, 0.8, fade)
	var dark := Color(0.5, 0.5, 0.55, fade)
	draw_rect(Rect2(-22, -26, 44, 26), wall)
	for x in [-26, 14]:
		draw_rect(Rect2(x, -40, 12, 40), wall)
		draw_rect(Rect2(x, -44, 4, 4), wall)
		draw_rect(Rect2(x + 8, -44, 4, 4), wall)
		draw_colored_polygon(PackedVector2Array([Vector2(x, -40), Vector2(x + 6, -52), Vector2(x + 12, -40)]), Color(0.85, 0.2, 0.15, fade))
		draw_line(Vector2(x + 6, -52), Vector2(x + 6, -60), dark, 1.0)
		draw_rect(Rect2(x + 6, -60, 7, 4), Color(0.2, 0.35, 0.85, fade))
	for row in 3:
		for col in 4:
			draw_rect(Rect2(-22 + col * 11 + (row % 2) * 5, -24 + row * 8, 10, 7), dark, false, 1.0)
	draw_rect(Rect2(-5, -12, 10, 12), Color(0.95, 0.7, 0.2, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
