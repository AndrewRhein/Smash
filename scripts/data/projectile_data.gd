class_name ProjectileData
extends Resource
## A projectile spawned by a move. Damage, knockback and damage type come from
## the owning MoveData so one move = one hit definition. Offsets and velocity are
## authored facing right and mirrored by the owner's facing at spawn time.
##
## Rules (see docs/GAMEPLAY_API.md):
## - Owner: the spawning Fighter. Damage/knockback are attributed to its player_id.
## - Collision: only opposing fighters' hurtboxes. Terrain is ignored (magic).
## - A projectile is destroyed on its first hit or block, when its lifetime
##   ends, when it leaves the blast bounds, when its owner loses a stock, and on
##   rematch. Projectiles are not frozen by hitstop.

## Tick of the owning move's active phase on which the projectile spawns.
@export var spawn_tick: int = 0
@export var offset: Vector2 = Vector2(36, -56)
## Pixels per second, authored facing right.
@export var velocity: Vector2 = Vector2(520, 0)
## Downward acceleration in px/s^2 (0 = straight line). Lobbed projectiles.
@export var gravity: float = 0.0
@export var lifetime_ticks: int = 75
@export var radius: float = 14.0
## Optional presentation scene used as the projectile's VisualRoot.
@export var visual_scene: PackedScene


func validate(active_ticks: int, context: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if spawn_tick < 0 or spawn_tick >= active_ticks:
		errors.append("%s: spawn_tick %d outside active window of %d ticks" % [context, spawn_tick, active_ticks])
	if lifetime_ticks <= 0:
		errors.append("%s: lifetime_ticks must be > 0" % context)
	if radius <= 0.0:
		errors.append("%s: radius must be > 0" % context)
	return errors
