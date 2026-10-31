extends Node2D
## Tim's Counterterrorism Drone: a small quadcopter with spinning rotors and a
## blinking light. Presentation only; the parent Projectile owns gameplay.
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	queue_redraw()

func _draw() -> void:
	var bob := sin(age * 9.0) * 2.0
	var body := Color(0.22, 0.24, 0.28)
	draw_rect(Rect2(-12, -4 + bob, 24, 8), body)
	draw_rect(Rect2(-5, 3 + bob, 10, 4), Color(0.12, 0.13, 0.16))
	for x in [-16.0, 16.0]:
		draw_line(Vector2(x * 0.7, bob - 2), Vector2(x, bob - 7), body, 2.0)
		var spin := absf(sin(age * 50.0 + x))
		draw_line(Vector2(x - 8.0 * spin, bob - 8), Vector2(x + 8.0 * spin, bob - 8), Color(0.75, 0.8, 0.85, 0.8), 2.0)
	var blink := Color(1, 0.2, 0.2) if int(age * 4.0) % 2 == 0 else Color(0.3, 0.05, 0.05)
	draw_circle(Vector2(8, bob), 2.0, blink)
