class_name PlayerInput
extends RefCounted
## Per-player input adapter.
##
## Sources, merged every tick:
##   * Keyboard: InputMap actions "p<id>_<button>" (see InputSetup).
##   * Controller: the device ControllerAssignment gives this player, read
##     directly with the Xbox-style layout in InputSetup.JOY_BUTTONS.
##   * Scripted: values set by tests (replaces the two above).
## All sources go through the same edge detection, so gameplay sees identical
## InputFrames. sample() must be called exactly once per physics tick.

## Radial dead zone for analog sticks.
const STICK_DEAD_ZONE := 0.2
## Stick deflection needed to count as a digital up/down/left/right press.
const DIGITAL_THRESHOLD := 0.5
## Left stick pushed this far up counts as a jump when tap-jump is on.
const TAP_JUMP_THRESHOLD := 0.66
## Analog trigger travel that counts as holding shield.
const TRIGGER_THRESHOLD := 0.35
## Right stick deflection that triggers a heavy ("smash") attack.
const SMASH_STICK_THRESHOLD := 0.6

## Smash default: flicking the stick up also jumps. Keyboard jump keys always work.
static var tap_jump: bool = true

var player_id: int
var scripted: bool = false

var _prev_held_mask: int = 0
var _script_held: Dictionary = {}   # StringName -> bool
var _script_taps: Dictionary = {}   # StringName -> true, held for one sample only
var _script_axis: Vector2 = Vector2.ZERO
var _script_axis_set: bool = false
var _script_right_stick: Vector2 = Vector2.ZERO
var _has_action: Dictionary = {}    # cache: action -> bool


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


## Override the left-stick axis. Clear with clear_axis() to derive it from buttons.
func set_axis(axis: Vector2) -> void:
	_script_axis = axis
	_script_axis_set = true


func clear_axis() -> void:
	_script_axis_set = false


func set_right_stick(axis: Vector2) -> void:
	_script_right_stick = axis


func release_all() -> void:
	_script_held.clear()
	_script_taps.clear()
	_script_axis_set = false
	_script_right_stick = Vector2.ZERO


## Forget edge history: buttons held right now will not register as presses on
## the next sample. Used on respawn, rematch and unpause so held inputs do not leak.
func reset_edges() -> void:
	_prev_held_mask = _read_held_mask(_read_axis(), _read_right_stick())


func sample() -> InputFrame:
	var frame := InputFrame.new()
	var axis := _read_axis()
	var right := _read_right_stick()
	frame.move_x = axis.x
	frame.move_y = axis.y
	if absf(right.x) >= SMASH_STICK_THRESHOLD and absf(right.x) >= absf(right.y):
		frame.smash_x = 1 if right.x > 0.0 else -1
	elif absf(right.y) >= SMASH_STICK_THRESHOLD:
		frame.smash_y = 1 if right.y > 0.0 else -1
	frame.held_mask = _read_held_mask(axis, right)
	frame.pressed_mask = frame.held_mask & ~_prev_held_mask
	_prev_held_mask = frame.held_mask
	_script_taps.clear()
	return frame


# --- Sources -----------------------------------------------------------------
func _device() -> int:
	return -1 if scripted else ControllerAssignment.device_for(player_id)


func _action_held(button: StringName) -> bool:
	var action := action_name(player_id, button)
	if not _has_action.has(action):
		_has_action[action] = InputMap.has_action(action)
	return _has_action[action] and Input.is_action_pressed(action)


func _joy_button_held(button: StringName, device: int) -> bool:
	if device < 0:
		return false
	for joy_button: int in InputSetup.JOY_BUTTONS.get(button, []):
		if Input.is_joy_button_pressed(device, joy_button):
			return true
	if button == &"shield":
		for trigger: int in InputSetup.JOY_SHIELD_TRIGGERS:
			if Input.get_joy_axis(device, trigger) >= TRIGGER_THRESHOLD:
				return true
	return false


func _raw_held(button: StringName) -> bool:
	if scripted:
		return bool(_script_held.get(button, false)) or _script_taps.has(button)
	return _action_held(button) or _joy_button_held(button, _device())


static func _dead_zone(v: Vector2) -> Vector2:
	if v.length() < STICK_DEAD_ZONE:
		return Vector2.ZERO
	return v.limit_length(1.0)


func _stick_axis(device: int) -> Vector2:
	if device < 0:
		return Vector2.ZERO
	return _dead_zone(Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)))


func _read_axis() -> Vector2:
	var axis := Vector2.ZERO
	if scripted:
		if _script_axis_set:
			return _script_axis.clamp(Vector2(-1, -1), Vector2(1, 1))
		axis.x = float(_raw_held(&"right")) - float(_raw_held(&"left"))
		axis.y = float(_raw_held(&"down")) - float(_raw_held(&"up"))
		return axis
	var device := _device()
	# Keyboard and D-pad are digital; the stick is analog. Per component, the
	# larger magnitude wins so mixing sources never cancels out.
	var digital := Vector2(
		float(_action_held(&"right") or _joy_button_held(&"right", device))
			- float(_action_held(&"left") or _joy_button_held(&"left", device)),
		float(_action_held(&"down") or _joy_button_held(&"down", device))
			- float(_action_held(&"up") or _joy_button_held(&"up", device)))
	var stick := _stick_axis(device)
	axis.x = digital.x if absf(digital.x) >= absf(stick.x) else stick.x
	axis.y = digital.y if absf(digital.y) >= absf(stick.y) else stick.y
	return axis.clamp(Vector2(-1, -1), Vector2(1, 1))


func _read_right_stick() -> Vector2:
	if scripted:
		return _script_right_stick
	var device := _device()
	if device < 0:
		return Vector2.ZERO
	return _dead_zone(Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)))


func _read_held_mask(axis: Vector2, right: Vector2) -> int:
	var mask := 0
	for button: StringName in InputFrame.BUTTONS:
		var held: bool
		match button:
			&"left": held = axis.x <= -DIGITAL_THRESHOLD
			&"right": held = axis.x >= DIGITAL_THRESHOLD
			&"up": held = axis.y <= -DIGITAL_THRESHOLD
			&"down": held = axis.y >= DIGITAL_THRESHOLD
			&"jump":
				held = _raw_held(&"jump")
				if tap_jump and not scripted:
					held = held or _stick_axis(_device()).y <= -TAP_JUMP_THRESHOLD
			&"heavy":
				held = _raw_held(&"heavy") or right.length() >= SMASH_STICK_THRESHOLD
			_: held = _raw_held(button)
		if held:
			mask |= InputFrame.bit(button)
	return mask
