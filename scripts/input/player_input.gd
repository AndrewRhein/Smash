class_name PlayerInput
extends RefCounted
## Per-player input adapter. Reads InputMap actions named "p<id>_<button>"
## (see InputSetup) or, in scripted mode, values set by tests. Both sources go
## through the same edge detection, so gameplay sees identical InputFrames.
##
## sample() must be called exactly once per physics tick.

## Stick magnitude below this is treated as zero (on top of the action dead zone).
const AXIS_DEAD_ZONE := 0.25
## Stick deflection needed to count as a digital up/down press.
const DIGITAL_THRESHOLD := 0.5

var player_id: int
var scripted: bool = false

var _prev_held_mask: int = 0
var _script_held: Dictionary = {}   # StringName -> bool
var _script_taps: Dictionary = {}   # StringName -> true, held for one sample only
var _script_axis: Vector2 = Vector2.ZERO
var _script_axis_set: bool = false


func _init(id: int, use_script: bool = false) -> void:
	player_id = id
	scripted = use_script


static func action_name(id: int, button: StringName) -> StringName:
	return StringName("p%d_%s" % [id, button])


## --- Scripted input API (tests / replays) ----------------------------------
func set_held(button: StringName, value: bool) -> void:
	_script_held[button] = value


## Hold `button` for exactly the next sample.
func tap(button: StringName) -> void:
	_script_taps[button] = true


## Override the analog axis. Clear with clear_axis() to derive it from buttons.
func set_axis(axis: Vector2) -> void:
	_script_axis = axis
	_script_axis_set = true


func clear_axis() -> void:
	_script_axis_set = false


func release_all() -> void:
	_script_held.clear()
	_script_taps.clear()
	_script_axis_set = false


## Forget edge history: buttons held right now will not register as presses on
## the next sample. Used on respawn/rematch so held inputs do not leak.
func reset_edges() -> void:
	_prev_held_mask = _read_held_mask(_read_axis())


func sample() -> InputFrame:
	var frame := InputFrame.new()
	var axis := _read_axis()
	frame.move_x = axis.x
	frame.move_y = axis.y
	frame.held_mask = _read_held_mask(axis)
	frame.pressed_mask = frame.held_mask & ~_prev_held_mask
	_prev_held_mask = frame.held_mask
	_script_taps.clear()
	return frame


func _raw_held(button: StringName) -> bool:
	if scripted:
		return bool(_script_held.get(button, false)) or _script_taps.has(button)
	return Input.is_action_pressed(action_name(player_id, button))


func _read_axis() -> Vector2:
	var axis := Vector2.ZERO
	if scripted:
		if _script_axis_set:
			axis = _script_axis
		else:
			axis.x = float(_raw_held(&"right")) - float(_raw_held(&"left"))
			axis.y = float(_raw_held(&"down")) - float(_raw_held(&"up"))
	else:
		axis.x = Input.get_action_strength(action_name(player_id, &"right")) \
			- Input.get_action_strength(action_name(player_id, &"left"))
		axis.y = Input.get_action_strength(action_name(player_id, &"down")) \
			- Input.get_action_strength(action_name(player_id, &"up"))
	if absf(axis.x) < AXIS_DEAD_ZONE:
		axis.x = 0.0
	if absf(axis.y) < AXIS_DEAD_ZONE:
		axis.y = 0.0
	return axis.clamp(Vector2(-1, -1), Vector2(1, 1))


func _read_held_mask(axis: Vector2) -> int:
	var mask := 0
	for button: StringName in InputFrame.BUTTONS:
		var held: bool
		match button:
			&"left": held = axis.x <= -DIGITAL_THRESHOLD
			&"right": held = axis.x >= DIGITAL_THRESHOLD
			&"up": held = axis.y <= -DIGITAL_THRESHOLD
			&"down": held = axis.y >= DIGITAL_THRESHOLD
			_: held = _raw_held(button)
		if held:
			mask |= InputFrame.bit(button)
	return mask
