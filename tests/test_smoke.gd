extends "res://tests/test_case.gd"
## Loads the real main scene with real (unpressed) device input and runs it.


func test_main_scene_runs() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	_nodes.append(main)
	var m: MatchController = main.get_node("Match")
	assert_eq(m.fighters.size(), 2, "two fighters spawned")
	assert_eq(m.state, MatchController.MatchState.COUNTDOWN, "starts with countdown")
	for i in m.countdown_ticks + 60:
		await tree.physics_frame
	assert_eq(m.state, MatchController.MatchState.PLAYING, "playing after countdown")
	for f in m.fighters:
		assert_true(f.grounded, "%s landed on a platform" % f.character.id)
		assert_true(f.get_node_or_null("VisualRoot") != null, "VisualRoot attached")
	# Real keyboard events through the InputMap: P1 holds D (right).
	var gandalf := m.get_fighter(1)
	var x0 := gandalf.position.x
	_key(KEY_D, true)
	for i in 20:
		await tree.physics_frame
	_key(KEY_D, false)
	assert_true(gandalf.position.x > x0 + 40.0, "keyboard D moves player 1 right")
	assert_true(m.get_fighter(2).velocity.x == 0.0, "player 2 unaffected")
	_key(KEY_F1, true)
	_key(KEY_F1, false)
	await tree.process_frame
	assert_true(main.get_node("DebugOverlay").visible, "F1 toggles the hitbox overlay")
	# Force a result, then rematch with the real Enter key via main.gd.
	for f in m.fighters:
		f.stocks = 1
	m.get_fighter(2).position = Vector2(640, 3000)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(m.state, MatchController.MatchState.RESULT, "result reached")
	assert_eq(m.winner_player_id, 1, "player 1 wins")
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await tree.physics_frame
	assert_eq(m.state, MatchController.MatchState.COUNTDOWN, "Enter starts a rematch")
	assert_eq(m.get_fighter(2).stocks, 3, "stocks restored")


func _key(keycode: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
