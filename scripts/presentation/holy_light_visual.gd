extends Node2D
## Pope Leo's Holy Tome projectile: a golden glowing orb with a cross glint.
## Presentation only; the parent Projectile owns travel, hits and lifetime.
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(age * 18.0) * 0.08
	var dir := 1.0
	var parent := get_parent()
	if parent != null and "velocity" in parent:
		dir = signf(parent.velocity.x) if parent.velocity.x != 0.0 else 1.0
	for i in range(4):
		draw_circle(Vector2(-dir * i * 8.0, 0), (12.0 - i * 2.5) * pulse, Color(1.0, 0.86, 0.4, 0.35 - i * 0.07))
	draw_circle(Vector2.ZERO, 11.0 * pulse, Color(1.0, 0.92, 0.55, 0.9))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 1.0, 0.92))
	var c := Color(1, 1, 1, 0.9)
	draw_line(Vector2(0, -15) * pulse, Vector2(0, 15) * pulse, c, 2.0)
	draw_line(Vector2(-10, -4) * pulse, Vector2(10, -4) * pulse, c, 2.0)
