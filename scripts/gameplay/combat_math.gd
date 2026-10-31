class_name CombatMath
extends RefCounted
## Pure combat formulas and overlap tests shared by fighters, projectiles, the
## match controller and the debug overlay. Tests call the real gameplay code;
## these helpers are documented here so tuning has one home.

## Extra hitstun ticks per px/s of knockback.
const HITSTUN_PER_KNOCKBACK := 0.02
const MAX_HITSTUN_TICKS := 70
## Hitstop (freeze) = base + damage * per_damage, clamped.
const HITSTOP_BASE_TICKS := 2
const HITSTOP_PER_DAMAGE := 0.4
const MAX_HITSTOP_TICKS := 10
## Hitstop applied to both sides when a guard blocks.
const BLOCK_HITSTOP_TICKS := 4


## (base + growth * damage_after_hit) / weight, in px/s.
static func knockback_magnitude(move: MoveData, victim_damage_after_hit: float, victim_weight: float) -> float:
	return (move.knockback_base + move.knockback_growth * victim_damage_after_hit) / maxf(victim_weight, 0.01)


## angle_deg: 0 = forward, 90 = up. direction_sign: +1 right / -1 left.
static func knockback_direction(angle_deg: float, direction_sign: int) -> Vector2:
	var a := deg_to_rad(angle_deg)
	return Vector2(cos(a) * direction_sign, -sin(a))


static func hitstun_ticks(move: MoveData, knockback: float) -> int:
	return mini(move.hitstun_ticks + int(knockback * HITSTUN_PER_KNOCKBACK), MAX_HITSTUN_TICKS)


static func hitstop_ticks(damage: float) -> int:
	return clampi(HITSTOP_BASE_TICKS + int(damage * HITSTOP_PER_DAMAGE), 0, MAX_HITSTOP_TICKS)


## Mirror a facing-right local rect around the root and move it to world space.
static func mirrored_rect(local: Rect2, facing: int, origin: Vector2) -> Rect2:
	var x := local.position.x if facing > 0 else -local.position.x - local.size.x
	return Rect2(origin + Vector2(x, local.position.y), local.size)


## shape: {"shape": HitboxData.Shape, "center": Vector2, "size": Vector2, "radius": float}
static func shape_overlaps_rect(shape: Dictionary, rect: Rect2) -> bool:
	if shape.shape == HitboxData.Shape.CIRCLE:
		return circle_overlaps_rect(shape.center, shape.radius, rect)
	var hb := Rect2(shape.center - shape.size * 0.5, shape.size)
	return hb.intersects(rect)


static func circle_overlaps_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) <= radius * radius
