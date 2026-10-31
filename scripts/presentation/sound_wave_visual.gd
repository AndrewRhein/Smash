extends Node2D
## Josh Groban's High Note projectile: expanding sound arcs and a music note.
## Presentation only; the parent Projectile owns travel, hits and lifetime.
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	var dir := 1.0
	var parent := get_parent()
	if parent != null and "velocity" in parent and parent.velocity.x != 0.0:
		dir = signf(parent.velocity.x)
	var a := 0.0 if dir > 0 else PI
	for i in range(3):
		var r := 8.0 + i * 7.0 + fmod(age * 40.0, 7.0)
		draw_arc(Vector2(-dir * 10.0, 0), r, a - 0.9, a + 0.9, 14, Color(0.75, 0.9, 1.0, 0.85 - i * 0.22), 3.0)
	# Eighth note.
	var c := Color(1.0, 0.95, 0.8)
	var bob := sin(age * 12.0) * 2.0
	draw_circle(Vector2(-4, 5 + bob), 5.0, c)
	draw_line(Vector2(0, 5 + bob), Vector2(0, -12 + bob), c, 2.0)
	draw_line(Vector2(0, -12 + bob), Vector2(7, -7 + bob), c, 2.0)
