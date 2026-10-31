class_name HitboxData
extends Resource
## One timed hitbox of a move.
##
## Coordinates are local to the fighter root (feet center), authored as if the
## fighter faces RIGHT (+X). At runtime offset.x is multiplied by the fighter's
## facing (+1/-1), so authored shapes mirror around the root. Positive Y is down,
## so a hitbox at chest height has a negative Y offset.
##
## Timing is relative to the FIRST ACTIVE TICK of the owning move, so a hitbox can
## never exist during startup or recovery (MoveData.validate() enforces the
## window). These shapes are gameplay geometry only; never derive them from
## sprite size.

enum Shape { RECT, CIRCLE }
enum Kind {
	STRIKE, ## Normal damaging hit.
	GRAB,   ## Grab hitbox used by the "choke" special behaviour; deals no hit itself.
}

@export var shape: Shape = Shape.RECT
@export var kind: Kind = Kind.STRIKE
## Center of the shape, local space, authored facing right.
@export var offset: Vector2 = Vector2(40, -50)
## Full width/height for RECT.
@export var size: Vector2 = Vector2(40, 30)
## Radius for CIRCLE.
@export var radius: float = 20.0
## First active tick (0 = first tick of the move's active phase).
@export var start_tick: int = 0
## Number of ticks the hitbox exists. 0 = until the end of the active phase.
@export var duration_ticks: int = 0
## 0 = hits a given target at most once per attack instance (default).
## N > 0 = multi-hit: may hit the same target again every N ticks.
@export var rehit_interval_ticks: int = 0


func resolved_duration(active_ticks: int) -> int:
	return duration_ticks if duration_ticks > 0 else active_ticks - start_tick


func validate(active_ticks: int, context: String) -> PackedStringArray:
	var errors := PackedStringArray()
	if start_tick < 0:
		errors.append("%s: start_tick must be >= 0" % context)
	if duration_ticks < 0:
		errors.append("%s: duration_ticks must be >= 0" % context)
	if start_tick + resolved_duration(active_ticks) > active_ticks:
		errors.append("%s: hitbox ticks [%d, %d) exceed active window of %d ticks" % [
			context, start_tick, start_tick + resolved_duration(active_ticks), active_ticks])
	if shape == Shape.RECT and (size.x <= 0.0 or size.y <= 0.0):
		errors.append("%s: rect size must be positive" % context)
	if shape == Shape.CIRCLE and radius <= 0.0:
		errors.append("%s: circle radius must be positive" % context)
	if rehit_interval_ticks < 0:
		errors.append("%s: rehit_interval_ticks must be >= 0" % context)
	return errors
