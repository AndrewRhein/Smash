class_name PlaceholderProjectileVisual
extends Node2D
## TEMPORARY PLACEHOLDER ART for projectiles (VisualRoot of a Projectile).
## Drawn at the gameplay radius so the placeholder is also honest about reach.

var projectile: Projectile


func _ready() -> void:
	projectile = get_parent() as Projectile


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if projectile == null or projectile.data == null:
		return
	var r := projectile.data.radius
	var flicker := 0.85 + 0.15 * sin(float(projectile.ticks_remaining) * 0.9)
	var trail := -projectile.velocity.normalized() * r * 1.6
	draw_line(Vector2.ZERO, trail, Color(1.0, 0.45, 0.1, 0.5), r)
	draw_circle(Vector2.ZERO, r * flicker, Color(1.0, 0.5, 0.12))
	draw_circle(Vector2.ZERO, r * 0.55, Color(1.0, 0.92, 0.6))
