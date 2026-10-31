extends "res://tests/test_case.gd"
## Menu shell (scenes/app.tscn): title, settings, controls, pause, result.
## Uses real InputEvents through the viewport so GUI focus/accept is exercised.

const TEST_SETTINGS := "user://test_menu_settings.cfg"


func _make_app() -> GameApp:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	var app := GameApp.new(GameSettings.new(TEST_SETTINGS))
	tree.root.add_child(app)
	_nodes.append(app)
	await _frames(2)
	return app


func cleanup() -> void:
	tree.paused = false
	super.cleanup()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _physics(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _key(keycode: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		ev.keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()


func _joy(button: int, device: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.device = device
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()


## Starts a match from the title with Enter and skips the countdown.
func _start(app: GameApp) -> MatchController:
	_key(KEY_ENTER)
	await _frames(2)
	var m := app.match_controller
	if m != null:
		m.countdown_remaining = 1
		await _physics(3)
	return m


func _force_result(m: MatchController) -> void:
	for f in m.fighters:
		f.stocks = 1
	m.get_fighter(2).position = Vector2(640, 3000)
	await _physics(3)


func test_title_starts_match_with_enter() -> void:
	var app := await _make_app()
	assert_eq(app.current_screen, &"title", "boots to the title screen")
	var title := app._screen as TitleScreen
	assert_true(title.start_button.has_focus(), "Start Match focused for keyboard/controller")
	var m := await _start(app)
	assert_eq(app.current_screen, &"match", "Enter on Start Match opens a match")
	assert_true(m != null and m.state == MatchController.MatchState.PLAYING, "match playing")
	assert_eq(m.get_fighter(1).stocks, 3, "default stock count")
	assert_true(app.get_node_or_null("Menus").get_child_count() == 0, "title removed during the match")


func test_stock_selector_persists_and_applies() -> void:
	var app := await _make_app()
	var title := app._screen as TitleScreen
	title.stocks_button.grab_focus()
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	await _frames(1)
	assert_eq(app.settings.stocks, 5, "right arrow raises stocks 3 -> 5")
	var reloaded := GameSettings.new(TEST_SETTINGS)
	reloaded.load_from_disk()
	assert_eq(reloaded.stocks, 5, "stock choice saved to disk")
	title.start_button.grab_focus()
	var m := await _start(app)
	for f in m.fighters:
		assert_eq(f.stocks, 5, "match uses chosen stock count")
	m.rematch()
	assert_eq(m.get_fighter(1).stocks, 5, "rematch keeps the chosen stock count")


func test_pause_freezes_and_resumes() -> void:
	var app := await _make_app()
	var m := await _start(app)
	var g := m.get_fighter(1)
	_key(KEY_ESCAPE)
	await _frames(1)
	assert_true(app.is_paused() and app.pause_menu.is_open, "Esc opens pause")
	var tick := m.tick
	await _physics(10)
	assert_eq(m.tick, tick, "match does not advance while paused")
	# A button pressed during pause must not fire an attack on resume.
	Input.action_press(&"p1_light")
	_key(KEY_ESCAPE)
	await _physics(5)
	Input.action_release(&"p1_light")
	assert_true(not app.is_paused(), "Esc resumes")
	assert_true(m.tick > tick, "match advances after resume")
	assert_eq(g.attack_instance, 0, "press made during pause does not leak into play")


func test_controller_start_pauses_but_rematches_in_result() -> void:
	var app := await _make_app()
	var m := await _start(app)
	_joy(JOY_BUTTON_START, 1)
	await _frames(1)
	assert_true(app.is_paused(), "Start pauses during play")
	_joy(JOY_BUTTON_START, 1)
	await _frames(1)
	assert_true(not app.is_paused(), "Start resumes")
	await _force_result(m)
	assert_eq(m.state, MatchController.MatchState.RESULT, "result reached")
	_joy(JOY_BUTTON_START, 0)
	await _frames(1)
	assert_eq(m.state, MatchController.MatchState.COUNTDOWN, "Start in result = rematch")
	assert_true(not app.is_paused(), "and does not open the pause menu")


func test_pause_menu_restart_and_main_menu() -> void:
	var app := await _make_app()
	var m := await _start(app)
	m.get_fighter(1).damage = 40.0
	await _physics(20)
	_key(KEY_ESCAPE)
	await _frames(1)
	_key(KEY_DOWN)  # Resume -> Restart Match
	_key(KEY_ENTER)
	await _frames(2)
	assert_true(not app.is_paused(), "restart unpauses")
	assert_eq(m.get_fighter(1).damage, 0.0, "restart resets the match")
	assert_eq(m.state, MatchController.MatchState.COUNTDOWN, "restart begins with the countdown")
	var old_root := app.match_root
	_key(KEY_ESCAPE)
	await _frames(1)
	for i in 3:
		_key(KEY_DOWN)  # -> Main Menu
	_key(KEY_ENTER)
	await _frames(2)
	assert_eq(app.current_screen, &"title", "back on the title screen")
	assert_true(not app.is_paused(), "tree unpaused on leaving the match")
	assert_true(not is_instance_valid(old_root), "match scene freed")
	assert_true(app.match_controller == null and app.pause_menu == null, "no match references left")


func test_pause_controls_subscreen() -> void:
	var app := await _make_app()
	await _start(app)
	_key(KEY_ESCAPE)
	await _frames(1)
	_key(KEY_DOWN)
	_key(KEY_DOWN)  # -> Controls
	_key(KEY_ENTER)
	await _frames(2)
	assert_true(app.pause_menu.controls != null, "controls shown inside pause")
	_key(KEY_ESCAPE)
	await _frames(2)
	assert_true(app.pause_menu.controls == null and app.pause_menu.is_open, "Esc backs out to the pause panel")
	assert_true(app.is_paused(), "still paused")


func test_result_overlay_rematch_and_menu() -> void:
	var app := await _make_app()
	var m := await _start(app)
	await _force_result(m)
	await _frames(1)
	var overlay := app.result_overlay
	assert_true(overlay.box.visible, "result choices shown")
	assert_true(overlay.rematch_button.has_focus(), "Rematch focused")
	_key(KEY_ENTER)
	await _frames(2)
	assert_eq(m.state, MatchController.MatchState.COUNTDOWN, "Enter rematches exactly once")
	assert_true(not overlay.box.visible, "choices hidden after rematch")
	assert_true(tree.root.gui_get_focus_owner() == null, "no menu button keeps focus during play")
	m.countdown_remaining = 1
	await _physics(3)
	await _force_result(m)
	await _frames(1)
	_key(KEY_ESCAPE)
	await _frames(2)
	assert_eq(app.current_screen, &"title", "Esc from result returns to the title")


func test_settings_screen_hitboxes_persist() -> void:
	var app := await _make_app()
	app.show_settings()
	await _frames(1)
	var screen := app._screen as SettingsScreen
	screen.hitbox_button.grab_focus()
	_key(KEY_RIGHT)
	await _frames(1)
	assert_true(app.settings.show_hitboxes, "hitbox setting toggled")
	var reloaded := GameSettings.new(TEST_SETTINGS)
	reloaded.load_from_disk()
	assert_true(reloaded.show_hitboxes, "setting saved")
	_key(KEY_ESCAPE)
	await _frames(2)
	assert_eq(app.current_screen, &"title", "Esc returns to the title")
	await _start(app)
	assert_true(app.match_root.get_node("DebugOverlay").visible, "hitboxes on at match start")


func test_controls_screen_reflects_input_map() -> void:
	var app := await _make_app()
	assert_true(ControlsScreen.key_names(&"p1_light").has("F"), "P1 light shows F")
	assert_true(ControlsScreen.key_names(&"p2_special").has("L"), "P2 special shows L")
	assert_true(ControlsScreen.key_names(InputSetup.ACTION_PAUSE).has("Escape"), "pause shows Escape")
	app.show_controls(app.show_title)
	await _frames(1)
	assert_eq(app.current_screen, &"controls", "controls screen open")
	_key(KEY_ESCAPE)
	await _frames(2)
	assert_eq(app.current_screen, &"title", "Esc returns to the title")


func test_art_gallery_entry_matches_available_art() -> void:
	var app := await _make_app()
	var title := app._screen as TitleScreen
	var has_button := false
	for child in title.column.get_children():
		if child is Button and child.text == "Art Gallery":
			has_button = true
	assert_eq(has_button, GameApp.has_art_gallery(), "Art Gallery listed only when the scene exists")
	if not GameApp.has_art_gallery():
		return
	app.show_art_gallery()
	await _frames(2)
	assert_eq(app.current_screen, &"gallery", "gallery open")
	assert_true(app.gallery_root != null and app.gallery_root.is_inside_tree(), "art preview scene loaded")
	_key(KEY_ESCAPE)
	await _frames(2)
	assert_eq(app.current_screen, &"title", "Esc returns to the title")
	assert_true(app.gallery_root == null, "gallery freed")
