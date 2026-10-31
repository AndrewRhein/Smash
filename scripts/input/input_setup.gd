class_name InputSetup
extends RefCounted
## Registers the InputMap actions used by PlayerInput and the match flow.
##
## Actions are registered at runtime so the bindings live in one readable table.
## An action that already exists (e.g. defined later in project.godot or by a
## rebinding menu) is left untouched, so this never overrides user bindings.
##
## Keyboard bindings use physical keycodes (layout independent). Joypad events
## are bound to an explicit device: player 1 = joypad device 0, player 2 =
## joypad device 1 (Godot connection order), so one controller can never drive
## both fighters. Keyboard players and controllers can be mixed freely.

const STICK_DEAD_ZONE := 0.3

## Keyboard: original starter bindings preserved (A/D, W, F, G and arrows, Up,
## K, L); heavy, specials 2/3 and down/drop-through added without overlap.
const KEYBOARD := {
	1: {
		&"left": [KEY_A], &"right": [KEY_D], &"up": [KEY_W], &"down": [KEY_S],
		&"jump": [KEY_W], &"light": [KEY_F], &"heavy": [KEY_R],
		&"special_1": [KEY_G], &"special_2": [KEY_T], &"special_3": [KEY_V],
	},
	2: {
		&"left": [KEY_LEFT], &"right": [KEY_RIGHT], &"up": [KEY_UP], &"down": [KEY_DOWN],
		&"jump": [KEY_UP], &"light": [KEY_K], &"heavy": [KEY_I],
		&"special_1": [KEY_L], &"special_2": [KEY_O], &"special_3": [KEY_M],
	},
}

## Joypad buttons (Godot uses Xbox-style names: A bottom, B right, X left, Y top).
const JOY_BUTTONS := {
	&"left": [JOY_BUTTON_DPAD_LEFT], &"right": [JOY_BUTTON_DPAD_RIGHT],
	&"up": [JOY_BUTTON_DPAD_UP], &"down": [JOY_BUTTON_DPAD_DOWN],
	&"jump": [JOY_BUTTON_A], &"light": [JOY_BUTTON_X], &"heavy": [JOY_BUTTON_Y],
	&"special_1": [JOY_BUTTON_B], &"special_2": [JOY_BUTTON_RIGHT_SHOULDER],
	&"special_3": [JOY_BUTTON_LEFT_SHOULDER],
}

## Left stick: [axis, direction sign].
const JOY_AXES := {
	&"left": [JOY_AXIS_LEFT_X, -1.0], &"right": [JOY_AXIS_LEFT_X, 1.0],
	&"up": [JOY_AXIS_LEFT_Y, -1.0], &"down": [JOY_AXIS_LEFT_Y, 1.0],
}

const ACTION_REMATCH := &"match_rematch"
const ACTION_DEBUG_HITBOXES := &"debug_toggle_hitboxes"


static func ensure_actions() -> void:
	for player_id: int in KEYBOARD:
		var keys: Dictionary = KEYBOARD[player_id]
		for button: StringName in InputFrame.BUTTONS:
			var action := PlayerInput.action_name(player_id, button)
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action, STICK_DEAD_ZONE)
			for keycode: int in keys[button]:
				InputMap.action_add_event(action, _key(keycode))
			var device := player_id - 1
			for joy_button: int in JOY_BUTTONS[button]:
				var ev := InputEventJoypadButton.new()
				ev.button_index = joy_button
				ev.device = device
				InputMap.action_add_event(action, ev)
			if JOY_AXES.has(button):
				var motion := InputEventJoypadMotion.new()
				motion.axis = JOY_AXES[button][0]
				motion.axis_value = JOY_AXES[button][1]
				motion.device = device
				InputMap.action_add_event(action, motion)
	if not InputMap.has_action(ACTION_REMATCH):
		InputMap.add_action(ACTION_REMATCH)
		InputMap.action_add_event(ACTION_REMATCH, _key(KEY_ENTER))
		InputMap.action_add_event(ACTION_REMATCH, _key(KEY_KP_ENTER))
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		start.device = -1  # Any controller may request a rematch.
		InputMap.action_add_event(ACTION_REMATCH, start)
	if not InputMap.has_action(ACTION_DEBUG_HITBOXES):
		InputMap.add_action(ACTION_DEBUG_HITBOXES)
		InputMap.action_add_event(ACTION_DEBUG_HITBOXES, _key(KEY_F1))


static func _key(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev
