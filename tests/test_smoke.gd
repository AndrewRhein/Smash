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
	main.get_node("DebugOverlay").toggle()
	await tree.process_frame
	assert_true(main.get_node("DebugOverlay").visible, "debug overlay toggles on")
	# Force a result + rematch through the real scene wiring.
	for f in m.fighters:
		f.stocks = 1
	m.get_fighter(2).position = Vector2(640, 3000)
	await tree.physics_frame
	await tree.physics_frame
	assert_eq(m.state, MatchController.MatchState.RESULT, "result reached")
	m.rematch()
	await tree.physics_frame
	assert_eq(m.state, MatchController.MatchState.COUNTDOWN, "rematch restarts countdown")
	assert_eq(m.get_fighter(2).stocks, 3, "stocks restored")
