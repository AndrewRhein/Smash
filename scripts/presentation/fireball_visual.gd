extends Node2D
## Lifetime, position and collisions belong entirely to the parent Projectile.
var age := 0.0

func _process(delta: float) -> void:
    age += delta
    var velocity: Vector2 = get_parent().get("velocity")
    rotation = velocity.angle()
    queue_redraw()

func _draw() -> void:
    for i in range(5):
        draw_circle(Vector2(-i * 7, 0), 13 - i * 2, Color(1.0, 0.2 + i * 0.08, 0.03, 1.0 - i * 0.17))
    draw_circle(Vector2.ZERO, 9.0 + sin(age * 25) * 1.5, Color(1.0, 0.78, 0.25))
    draw_circle(Vector2(2, -2), 5, Color(1.0, 0.97, 0.8))
