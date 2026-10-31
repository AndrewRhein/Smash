class_name CharacterData
extends Resource
## A playable character: movement tuning, hurtbox and moveset.
## Instances live in data/characters/<id>.tres.

@export var id: StringName = &""
@export var display_name: String = ""
## Colour used by placeholder HUD/effects only.
@export var hud_color: Color = Color.WHITE
## Optional presentation scene instanced as the fighter's VisualRoot. When null,
## the placeholder vector visual is used. See docs/CODEX_INTEGRATION.md.
@export var visual_scene: PackedScene

@export_group("Body")
## Damageable area, local to the feet-center root, independent of art.
@export var hurtbox: Rect2 = Rect2(-18, -88, 36, 88)
## Physics capsule (terrain collision only).
@export var body_radius: float = 17.0
@export var body_height: float = 76.0
## Knockback divisor. > 1 = heavier (launched less).
@export var weight: float = 1.0

@export_group("Movement (px, px/s, px/s^2)")
@export var max_speed: float = 340.0
@export var ground_accel: float = 2600.0
@export var ground_decel: float = 3000.0
@export var air_accel: float = 1500.0
@export var air_decel: float = 500.0
@export var gravity: float = 1700.0
@export var max_fall_speed: float = 900.0
@export var fast_fall_speed: float = 1350.0
@export var jump_velocity: float = 720.0
@export var double_jump_velocity: float = 650.0
## Upward speed is capped to this when jump is released early (variable height).
@export var jump_release_velocity: float = 260.0
@export var air_jumps: int = 1

@export_group("Moves")
@export var moves: Array[MoveData] = []


func get_move(move_id: StringName) -> MoveData:
	for move in moves:
		if move != null and move.id == move_id:
			return move
	return null


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not GameIds.CHARACTER_IDS.has(id):
		errors.append("character: unknown id '%s'" % id)
	if hurtbox.size.x <= 0.0 or hurtbox.size.y <= 0.0:
		errors.append("%s: hurtbox must have positive size" % id)
	if weight <= 0.0:
		errors.append("%s: weight must be > 0" % id)
	if max_speed <= 0.0 or gravity <= 0.0 or jump_velocity <= 0.0:
		errors.append("%s: movement tuning must be positive" % id)
	if air_jumps < 0:
		errors.append("%s: air_jumps must be >= 0" % id)
	var seen := {}
	for move in moves:
		if move == null:
			errors.append("%s: null move entry" % id)
			continue
		if seen.has(move.id):
			errors.append("%s: duplicate move id '%s'" % [id, move.id])
		seen[move.id] = true
		errors.append_array(move.validate(id))
		for target in move.cancel_into:
			if get_move(target) == null:
				errors.append("%s/%s: cancel_into references unknown move '%s'" % [id, move.id, target])
	for slot: StringName in GameIds.MOVE_SLOTS:
		if not seen.has(slot):
			errors.append("%s: missing required move '%s'" % [id, slot])
	return errors
