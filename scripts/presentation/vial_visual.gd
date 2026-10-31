extends Node2D
## Dr. Sundar's thrown vial: a small spinning glass bottle with blue liquid.
## Presentation only; the parent Projectile owns gameplay.
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, age * 14.0, Vector2.ONE)
	draw_rect(Rect2(-5, -8, 10, 14), Color(0.85, 0.92, 1.0, 0.85))
	draw_rect(Rect2(-5, -1, 10, 7), Color(0.3, 0.6, 1.0, 0.95))
	draw_rect(Rect2(-3, -11, 6, 3), Color(0.55, 0.6, 0.7))
	draw_rect(Rect2(-5, -8, 10, 14), Color(1, 1, 1, 0.9), false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 3:
		draw_circle(Vector2(-10.0 - i * 7.0, sin(age * 20.0 + i) * 3.0), 2.0 - i * 0.5, Color(0.6, 0.85, 1.0, 0.6 - i * 0.18))
