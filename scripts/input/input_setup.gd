class_name InputSetup
extends RefCounted
## Input bindings, Smash-style.
##
## Keyboard bindings are registered as InputMap actions "p<id>_<button>"
## (physical keycodes, layout independent). An action that already exists
## (e.g. defined in project.godot or by a future rebinding menu) is left alone.
##
## Controllers are NOT bound per player in the InputMap: PlayerInput reads the
## pad that ControllerAssignment gives each player using JOY_BUTTONS below, so
## any device id, hot-plugging and 3+ connected pads work and one pad can never
## drive both fighters. Menus use Godot's built-in ui_* actions (any pad).

## Keyboard. Original starter keys kept (A/D, W, F, G and arrows, Up, K, L).
const KEYBOARD := {
	1: {
		&"left": [KEY_A], &"right": [KEY_D], &"up": [KEY_W], &"down": [KEY_S],
		&"jump": [KEY_W, KEY_SPACE], &"light": [KEY_F], &"special": [KEY_G],
		&"heavy": [KEY_R], &"shield": [KEY_T],
	},
	2: {
		&"left": [KEY_LEFT], &"right": [KEY_RIGHT], &"up": [KEY_UP], &"down": [KEY_DOWN],
		&"jump": [KEY_UP, KEY_KP_0], &"light": [KEY_K], &"special": [KEY_L],
		&"heavy": [KEY_I], &"shield": [KEY_O],
	},
}

## Xbox layout (Godot names: A bottom, B right, X left, Y top), like Smash's
## default: A attack, B special, X/Y jump, shoulders/triggers shield.
## RB is heavy (smash attack); the right stick also does heavies in its direction.
const JOY_BUTTONS := {
	&"left": [JOY_BUTTON_DPAD_LEFT], &"right": [JOY_BUTTON_DPAD_RIGHT],
	&"up": [JOY_BUTTON_DPAD_UP], &"down": [JOY_BUTTON_DPAD_DOWN],
	&"jump": [JOY_BUTTON_X, JOY_BUTTON_Y],
	&"light": [JOY_BUTTON_A],
	&"special": [JOY_BUTTON_B],
	&"heavy": [JOY_BUTTON_RIGHT_SHOULDER],
	&"shield": [JOY_BUTTON_LEFT_SHOULDER],
}
## Analog triggers that also shield (LT, RT).
const JOY_SHIELD_TRIGGERS := [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]

## Buttons that get keyboard actions (direct special slots are unbound).
const KEYBOARD_BUTTONS := [&"left", &"right", &"up", &"down", &"jump", &"light", &"heavy", &"special", &"shield"]

const ACTION_REMATCH := &"match_rematch"
const ACTION_DEBUG_HITBOXES := &"debug_toggle_hitboxes"
## Pause menu (scenes/app.tscn). Start doubles as rematch only in the result state.
const ACTION_PAUSE := &"pause_menu"


static func ensure_actions() -> void:
	for player_id: int in KEYBOARD:
		var keys: Dictionary = KEYBOARD[player_id]
		for button: StringName in KEYBOARD_BUTTONS:
			var action := PlayerInput.action_name(player_id, button)
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action)
			for keycode: int in keys.get(button, []):
				InputMap.action_add_event(action, _key(keycode))
	if not InputMap.has_action(ACTION_REMATCH):
		InputMap.add_action(ACTION_REMATCH)
		InputMap.action_add_event(ACTION_REMATCH, _key(KEY_ENTER))
		InputMap.action_add_event(ACTION_REMATCH, _key(KEY_KP_ENTER))
		InputMap.action_add_event(ACTION_REMATCH, _joy(JOY_BUTTON_START))
	if not InputMap.has_action(ACTION_PAUSE):
		InputMap.add_action(ACTION_PAUSE)
		InputMap.action_add_event(ACTION_PAUSE, _key(KEY_ESCAPE))
		InputMap.action_add_event(ACTION_PAUSE, _joy(JOY_BUTTON_START))
	if not InputMap.has_action(ACTION_DEBUG_HITBOXES):
		InputMap.add_action(ACTION_DEBUG_HITBOXES)
		InputMap.action_add_event(ACTION_DEBUG_HITBOXES, _key(KEY_F1))
	# Godot's built-in menu actions have no controller confirm/back by default:
	# A (and Start) confirm, B goes back, on any controller.
	_add_joy_once(&"ui_accept", JOY_BUTTON_A)
	_add_joy_once(&"ui_accept", JOY_BUTTON_START)
	_add_joy_once(&"ui_cancel", JOY_BUTTON_B)
	ControllerAssignment.refresh()


static func _add_joy_once(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return
	InputMap.action_add_event(action, _joy(button))


static func _key(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


## Any controller (device -1).
static func _joy(button: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	return ev
