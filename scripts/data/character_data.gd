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
## Smash-style special mapping: one Special button + stick direction.
@export var neutral_special: StringName = &"special_1"
@export var side_special: StringName = &"special_2"
@export var down_special: StringName = &"special_3"
@export var up_special: StringName = &"special_up"


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
	for field in ["neutral_special", "side_special", "down_special", "up_special"]:
		if get_move(get(field)) == null:
			errors.append("%s: %s references unknown move '%s'" % [id, field, get(field)])
	return errors


## Move for the Attack ("light") or Heavy button given direction, Smash style:
## ground up/down = up/down tilt, air = aerials (forward/back relative to
## facing), heavy + up/down = up/down smash. Each falls back along a chain to
## the always-present light / heavy move.
func resolve_attack(button: StringName, stick: Vector2, grounded: bool, facing: int) -> StringName:
	var t := PlayerInput.DIGITAL_THRESHOLD
	var vertical := absf(stick.y) > absf(stick.x) and absf(stick.y) >= t
	var up := vertical and stick.y < 0.0
	var down := vertical and stick.y > 0.0
	var chain: Array = []
	if button == &"heavy":
		chain = [&"heavy_up"] if up else ([&"heavy_down"] if down else [])
		chain.append(&"heavy")
	elif grounded:
		chain = [&"light_up"] if up else ([&"light_down"] if down else [])
		chain.append(&"light")
	else:
		if up:
			chain = [&"air_up"]
		elif down:
			chain = [&"air_down"]
		elif absf(stick.x) >= t:
			chain = [&"air_forward"] if signf(stick.x) == float(facing) else [&"air_back"]
		chain.append_array([&"air_neutral", &"light"])
	for id: StringName in chain:
		if get_move(id) != null:
			return id
	return chain[-1]


## Move for the Special button given the stick direction (Smash rules):
## mostly-vertical input picks up/down, otherwise a horizontal input picks side.
func special_for_direction(stick: Vector2) -> StringName:
	if absf(stick.y) > absf(stick.x) and absf(stick.y) >= PlayerInput.DIGITAL_THRESHOLD:
		return up_special if stick.y < 0.0 else down_special
	if absf(stick.x) >= PlayerInput.DIGITAL_THRESHOLD:
		return side_special
	return neutral_special
