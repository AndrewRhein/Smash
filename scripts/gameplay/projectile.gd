class_name Projectile
extends Node2D
## A gameplay projectile owned by a fighter. Moved and collided by
## MatchController each tick (never by its own _physics_process). Damage and
## knockback come from `move`; credit goes to `owner_player_id`.
## Placeholder visuals live in the VisualRoot child.

const TICK := 1.0 / 60.0

var owner_fighter: Fighter
var owner_player_id: int = 0
var move: MoveData
var data: ProjectileData
var velocity: Vector2 = Vector2.ZERO
## +1/-1: knockback is mirrored by the direction the projectile was fired.
var direction_sign: int = 1
var ticks_remaining: int = 0
var visual_root: Node2D


func setup(owner: Fighter, owner_move: MoveData, projectile_data: ProjectileData) -> void:
	owner_fighter = owner
	owner_player_id = owner.player_id
	move = owner_move
	data = projectile_data
	direction_sign = owner.facing
	global_position = owner.local_to_world_point(data.offset)
	velocity = Vector2(data.velocity.x * direction_sign, data.velocity.y)
	ticks_remaining = data.lifetime_ticks
	name = "Projectile_p%d_%s" % [owner_player_id, owner_move.id]
	if data.visual_scene != null:
		visual_root = data.visual_scene.instantiate() as Node2D
	if visual_root == null:
		visual_root = PlaceholderProjectileVisual.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)


func physics_tick() -> void:
	global_position += velocity * TICK
	ticks_remaining -= 1


func is_expired() -> bool:
	return ticks_remaining <= 0


func get_hit_shape() -> Dictionary:
	return {"shape": HitboxData.Shape.CIRCLE, "center": global_position, "size": Vector2.ZERO, "radius": data.radius}
