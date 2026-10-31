extends Node2D
## Lifetime, position and collisions belong entirely to the parent Projectile.
var age := 0.0

func _process(delta: float) -> void:
    age += delta
    var velocity: Vector2 = get_parent().get("velocity")
    rotation = velocity.angle()
    queue_redraw()

func _draw() -> void:
    # Layered glow and tapered flickering ribbons; the bright core stays r<=14.
    for i in range(3):
        draw_circle(Vector2.ZERO, 18.0 + i * 4, Color(1.0, 0.32, 0.06, 0.055 / (i + 1)))
    for i in range(3):
        var wave := sin(age * 22 + i * 2) * 4
        var tail := PackedVector2Array([Vector2(-6, -8 + i * 5), Vector2(-28, -9 + i * 7 + wave), Vector2(-53 - i * 5, wave), Vector2(-25, 5 + i * 2), Vector2(4, 6)])
        draw_colored_polygon(tail, Color(1.0, 0.22 + i * 0.15, 0.04, 0.28 + i * 0.12))
    for i in range(5):
        draw_circle(Vector2(-i * 7, 0), 13 - i * 2, Color(1.0, 0.2 + i * 0.08, 0.03, 1.0 - i * 0.17))
    draw_circle(Vector2.ZERO, 9.0 + sin(age * 25) * 1.5, Color(1.0, 0.78, 0.25))
    draw_circle(Vector2(2, -2), 5, Color(1.0, 0.97, 0.8))
