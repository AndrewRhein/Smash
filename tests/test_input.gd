extends "res://tests/test_case.gd"
## Input routing through the real InputMap (not scripted mode).


func after_each() -> void:
	for action in InputMap.get_actions():
		Input.action_release(action)


func test_keyboard_actions_route_to_their_player() -> void:
	var p1 := PlayerInput.new(1)
	var p2 := PlayerInput.new(2)
	Input.action_press(&"p1_light")
	Input.action_press(&"p2_right")
	var f1 := p1.sample()
	var f2 := p2.sample()
	assert_true(f1.is_pressed(&"light"), "p1 light pressed")
	assert_true(not f2.is_pressed(&"light"), "p2 not affected by p1 light")
	assert_eq(f2.move_x, 1.0, "p2 moves right")
	assert_eq(f1.move_x, 0.0, "p1 does not move")
	after_each()


func test_original_bindings_preserved_and_nonoverlapping() -> void:
	var expected := {
		&"p1_left": KEY_A, &"p1_right": KEY_D, &"p1_jump": KEY_W, &"p1_light": KEY_F, &"p1_special": KEY_G,
		&"p2_left": KEY_LEFT, &"p2_right": KEY_RIGHT, &"p2_jump": KEY_UP, &"p2_light": KEY_K, &"p2_special": KEY_L,
	}
	for action: StringName in expected:
		assert_true(_keys(action).has(expected[action]), "%s keeps original key" % action)
	# No key may be shared between the two players.
	var p1_keys := {}
	for button: StringName in InputSetup.KEYBOARD_BUTTONS:
		for k in _keys(PlayerInput.action_name(1, button)):
			p1_keys[k] = true
	for button: StringName in InputSetup.KEYBOARD_BUTTONS:
		for k in _keys(PlayerInput.action_name(2, button)):
			assert_true(not p1_keys.has(k), "key %s not shared between players" % OS.get_keycode_string(k))


func test_joypads_are_device_assigned() -> void:
	ControllerAssignment.reset(true)
	ControllerAssignment.assign(1, 0)
	ControllerAssignment.assign(2, 1)
	var p1 := PlayerInput.new(1)
	var p2 := PlayerInput.new(2)
	p1.sample()
	p2.sample()
	var ev := InputEventJoypadButton.new()
	ev.device = 1
	ev.button_index = JOY_BUTTON_A  # A = attack (Smash layout)
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	assert_true(not p1.sample().is_pressed(&"light"), "controller 1 does not drive player 1")
	assert_true(p2.sample().is_held(&"light"), "controller 1 drives player 2")
	var release := ev.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -0.9
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	assert_true(p1.sample().move_x < -0.5, "controller 0 stick moves player 1")
	assert_eq(p2.sample().move_x, 0.0, "controller 0 stick does not move player 2")
	var center := stick.duplicate()
	center.axis_value = 0.0
	Input.parse_input_event(center)
	Input.flush_buffered_events()
	ControllerAssignment.reset()


func test_stick_dead_zone() -> void:
	var p1 := PlayerInput.new(1)
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.2
	Input.parse_input_event(stick)
	Input.flush_buffered_events()
	assert_eq(p1.sample().move_x, 0.0, "small stick drift ignored")
	var center := stick.duplicate()
	center.axis_value = 0.0
	Input.parse_input_event(center)
	Input.flush_buffered_events()


func test_held_button_is_one_press() -> void:
	var p1 := PlayerInput.new(1, true)
	p1.set_held(&"light", true)
	assert_true(p1.sample().is_pressed(&"light"), "first sample is a press")
	for i in 30:
		assert_true(not p1.sample().is_pressed(&"light"), "holding never re-presses")
	p1.reset_edges()
	assert_true(not p1.sample().is_pressed(&"light"), "reset_edges does not create a press")


func _keys(action: StringName) -> Array:
	var keys := []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			keys.append(ev.physical_keycode)
	return keys
