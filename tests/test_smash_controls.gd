extends "res://tests/test_case.gd"
## Shield, dodges, up special, directional specials, Xbox layout and
## multi-controller assignment.


# --- Shield --------------------------------------------------------------------
func _shield_face_off(m: MatchController) -> void:
	face_off(m)
	p(m, 2).set_held(&"shield", true)
	step(m, 2)


func test_shield_blocks_strike_with_stun_and_pushback() -> void:
	var m: MatchController = await make_match()
	await _shield_face_off(m)
	var v := m.get_fighter(2)
	assert_eq(v.state, Fighter.State.SHIELD, "holding shield on the ground raises it")
	var before := v.shield_health
	p(m, 1).tap(&"light")
	while v.shield_stun_remaining == 0 and m.tick < 200:
		step(m)
	assert_eq(v.damage, 0.0, "shield takes the hit instead of the fighter")
	assert_near(before - v.shield_health, 5.0 * Fighter.SHIELD_DAMAGE_MULTIPLIER, 1.0, "shield loses health")
	assert_true(v.velocity.x > 0.0, "pushed back away from the attacker")
	assert_eq(v.state, Fighter.State.SHIELD, "still shielding during shieldstun")
	assert_eq(v.shield_stun_remaining, int(5.0 * Fighter.SHIELD_STUN_PER_DAMAGE) + 2, "shieldstun from damage")


func test_shield_blocks_projectiles_from_behind() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	place(g, 600, 1)
	place(v, 700, 1)  # facing away from Gandalf
	p(m, 2).set_held(&"shield", true)
	step(m, 2)
	var fireball := g.character.get_move(&"special_2")
	m._on_projectile_requested(g, fireball, fireball.projectiles[0])
	step(m, 10)
	assert_eq(v.damage, 0.0, "shield covers every side, unlike Force guard")
	assert_eq(m.projectiles.size(), 0, "projectile destroyed on the shield")


func test_shield_drains_and_breaks_into_dizzy() -> void:
	var m: MatchController = await make_match()
	await _shield_face_off(m)
	var v := m.get_fighter(2)
	var ticks := 0
	while v.state == Fighter.State.SHIELD and ticks < 1000:
		step(m)
		ticks += 1
	assert_eq(v.state, Fighter.State.SHIELD_BREAK, "an over-held shield breaks")
	assert_near(ticks, Fighter.SHIELD_MAX / Fighter.SHIELD_DECAY_PER_TICK, 3.0, "lasts ~7 s of holding")
	assert_true(v.velocity.y < 0.0, "shield break pops the fighter up")
	# Dizzy: fully vulnerable and unable to act.
	p(m, 2).tap(&"jump")
	step(m, 30)
	assert_eq(v.state, Fighter.State.SHIELD_BREAK, "cannot act while dizzy")
	place(m.get_fighter(1), v.position.x - 60, 1, v.position.y)
	m.get_fighter(1).cooldowns.clear()
	p(m, 1).tap(&"light")
	step(m, 10)
	assert_true(v.damage > 0.0, "dizzy fighter takes real hits")


func test_shield_break_from_a_strong_hit_and_recovery() -> void:
	var m: MatchController = await make_match()
	await _shield_face_off(m)
	var v := m.get_fighter(2)
	v.shield_health = 5.0
	p(m, 1).tap(&"heavy")
	step(m, 40)
	assert_eq(v.state, Fighter.State.SHIELD_BREAK, "heavy breaks a weak shield")
	p(m, 2).set_held(&"shield", false)
	var guard := 0
	while v.state == Fighter.State.SHIELD_BREAK and guard < Fighter.SHIELD_BREAK_TICKS + 20:
		step(m)
		guard += 1
	assert_true(v.state != Fighter.State.SHIELD_BREAK, "dizzy ends")
	assert_near(v.shield_health, Fighter.SHIELD_AFTER_BREAK, 2.0, "shield returns partially")


func test_shield_regenerates_and_drop_has_lag() -> void:
	var m: MatchController = await make_match()
	await _shield_face_off(m)
	var v := m.get_fighter(2)
	v.shield_health = 20.0
	p(m, 2).set_held(&"shield", false)
	step(m)
	assert_eq(v.state, Fighter.State.LAG, "releasing shield has drop lag")
	assert_true(v.is_hittable() and not v.is_shielding(), "vulnerable during drop lag")
	step(m, Fighter.SHIELD_DROP_TICKS)
	assert_true(v.state in Fighter.FREE_STATES, "free after drop lag")
	var h := v.shield_health
	step(m, 100)
	assert_near(v.shield_health - h, 100 * Fighter.SHIELD_REGEN_PER_TICK, 0.5, "shield regenerates when lowered")


func test_grab_beats_shield_and_jump_out_of_shield() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	place(g, 650, 1)
	place(v, 760, -1)
	p(m, 1).set_held(&"shield", true)
	step(m, 2)
	p(m, 2).tap(&"special_2")  # Force choke
	for i in 30:
		step(m)
		if g.state == Fighter.State.HELD:
			break
	assert_eq(g.state, Fighter.State.HELD, "Force choke grabs through a shield")
	m.rematch()
	await tree.physics_frame
	g = m.get_fighter(1)
	face_off(m)
	p(m, 1).set_held(&"shield", true)
	step(m, 3)
	p(m, 1).tap(&"jump")
	step(m)
	assert_true(g.velocity.y < -500.0, "jump cancels shield immediately")


# --- Dodges --------------------------------------------------------------------
func test_spot_dodge_is_intangible_then_returns_to_shield() -> void:
	var m: MatchController = await make_match()
	await _shield_face_off(m)
	var v := m.get_fighter(2)
	p(m, 2).tap(&"down")
	step(m)
	assert_eq(v.state, Fighter.State.DODGE, "shield + down = spot dodge")
	step(m, Fighter.SPOT_DODGE_INTANGIBLE.x)
	assert_true(v.is_intangible(), "intangible during the dodge window")
	var x := v.position.x
	p(m, 1).tap(&"light")
	step(m, 10)
	assert_eq(v.damage, 0.0, "attack passes through the spot dodge")
	assert_near(v.position.x, x, 0.5, "spot dodge does not move")
	step(m, Fighter.SPOT_DODGE_TICKS)
	assert_eq(v.state, Fighter.State.SHIELD, "back in shield while it is held")


func test_roll_moves_turns_and_stops_at_ledge() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 400, 1)
	place(g, 640, 1)
	p(m, 1).set_held(&"shield", true)
	step(m, 2)
	p(m, 1).tap(&"right")
	step(m, Fighter.ROLL_TICKS + 2)
	assert_true(g.position.x > 640 + 120.0, "roll travels (%.0f px)" % (g.position.x - 640))
	assert_eq(g.facing, -1, "roll ends facing back toward where it started")
	place(g, 910, 1)
	g.state = Fighter.State.SHIELD
	step(m, 2)
	p(m, 1).tap(&"right")
	step(m, Fighter.ROLL_TICKS + 2)
	assert_true(g.grounded and g.position.x < 940.0, "rolls never carry you off the stage")


func test_air_dodge_directional_once_per_airtime() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 900, -1)
	place(g, 500, 1, 300)
	g.grounded = false
	step(m)
	p(m, 1).set_axis(Vector2(1, 0))
	p(m, 1).tap(&"shield")
	step(m)
	p(m, 1).clear_axis()
	assert_eq(g.state, Fighter.State.DODGE, "shield in the air = air dodge")
	assert_true(g.velocity.x > 300.0 and absf(g.velocity.y) < 50.0, "directional air dodge travels sideways")
	step(m, Fighter.AIR_DODGE_INTANGIBLE.x)
	assert_true(g.is_intangible(), "intangible")
	step(m, Fighter.AIR_DODGE_TICKS)
	p(m, 1).tap(&"shield")
	step(m)
	assert_true(g.state != Fighter.State.DODGE, "only one air dodge per airtime")
	step(m, 120)
	assert_true(g.grounded and g.air_dodge_available, "landing restores the air dodge")


# --- Up special, directional specials, right stick --------------------------------
func test_up_special_recovers_then_helpless_until_landing() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 400, 1)
	place(g, 1010, -1, 610)  # off the right ledge (outside ledge-grab range), below stage level
	g.grounded = false
	g.air_jumps_left = 0
	step(m)
	p(m, 1).set_axis(Vector2(0, -1))
	p(m, 1).tap(&"special")
	step(m)
	p(m, 1).clear_axis()
	assert_eq(g.move.id, &"special_up", "up + special = up special")
	var lowest_y := g.position.y
	var highest := g.position.y
	while g.state == Fighter.State.ATTACK:
		p(m, 1).set_held(&"left", true)
		step(m)
		highest = minf(highest, g.position.y)
	assert_true(lowest_y - highest > 200.0, "rises %.0f px" % (lowest_y - highest))
	assert_true(highest < GROUND_Y, "gets back above stage level")
	if not g.grounded:
		assert_true(g.helpless, "helpless after an airborne up special")
		p(m, 1).tap(&"special")
		step(m)
		p(m, 1).tap(&"jump")
		step(m)
		assert_true(g.state != Fighter.State.ATTACK and g.velocity.y > -500.0, "no specials or jumps while helpless")
	for i in 200:
		step(m)
		if g.grounded:
			break
	p(m, 1).set_held(&"left", false)
	assert_true(g.grounded and not g.helpless, "lands on stage and helpless clears")


func test_special_direction_mapping() -> void:
	var m: MatchController = await make_match()
	var expected := {
		1: {Vector2.ZERO: &"special_2", Vector2(1, 0): &"special_1", Vector2(-1, 0): &"special_1",
			Vector2(0, 1): &"special_3", Vector2(0, -1): &"special_up"},
		2: {Vector2.ZERO: &"special_2", Vector2(1, 0): &"special_1", Vector2(0, 1): &"special_3",
			Vector2(0, -1): &"special_up"},
	}
	for pid: int in expected:
		for dir: Vector2 in expected[pid]:
			m.rematch()
			await tree.physics_frame
			var f := m.get_fighter(pid)
			place(f, 640, 1 if pid == 1 else -1)
			place(m.get_fighter(3 - pid), 200 if pid == 2 else 1100, 1)
			step(m, 2)
			p(m, pid).set_axis(dir)
			p(m, pid).tap(&"special")
			step(m)
			p(m, pid).clear_axis()
			assert_eq(f.move.id if f.move != null else &"", expected[pid][dir], "P%d special %s" % [pid, dir])
			if dir.x != 0.0:
				assert_eq(f.facing, int(dir.x), "side special turns toward the stick")


func test_right_stick_heavy_turns_around() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	p(m, 1).set_right_stick(Vector2(-1, 0))
	step(m)
	p(m, 1).set_right_stick(Vector2.ZERO)
	assert_eq(g.move.id, &"heavy", "right stick does a heavy")
	assert_eq(g.facing, -1, "aimed with the right stick")


# --- Controllers -------------------------------------------------------------------
func _joy_button(device: int, button: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _joy_axis(device: int, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func test_xbox_layout_matches_smash() -> void:
	ControllerAssignment.reset(true)
	ControllerAssignment.assign(1, 0)
	var p1 := PlayerInput.new(1)
	p1.sample()
	var layout := {
		JOY_BUTTON_A: &"light", JOY_BUTTON_B: &"special", JOY_BUTTON_X: &"jump", JOY_BUTTON_Y: &"jump",
		JOY_BUTTON_RIGHT_SHOULDER: &"heavy", JOY_BUTTON_LEFT_SHOULDER: &"shield",
		JOY_BUTTON_DPAD_LEFT: &"left", JOY_BUTTON_DPAD_DOWN: &"down",
	}
	for button: int in layout:
		_joy_button(0, button, true)
		assert_true(p1.sample().is_pressed(layout[button]), "%s -> %s" % [button, layout[button]])
		_joy_button(0, button, false)
		p1.sample()
	for trigger in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		_joy_axis(0, trigger, 0.8)
		assert_true(p1.sample().is_held(&"shield"), "trigger %d shields" % trigger)
		_joy_axis(0, trigger, 0.0)
	_joy_axis(0, JOY_AXIS_RIGHT_X, -0.9)
	var f := p1.sample()
	assert_true(f.is_pressed(&"heavy") and f.smash_x == -1, "right stick = heavy toward it")
	_joy_axis(0, JOY_AXIS_RIGHT_X, 0.0)
	p1.sample()
	_joy_axis(0, JOY_AXIS_LEFT_Y, -0.9)
	assert_true(p1.sample().is_pressed(&"jump"), "tap jump: stick up jumps")
	_joy_axis(0, JOY_AXIS_LEFT_Y, 0.0)
	p1.sample()
	PlayerInput.tap_jump = false
	_joy_axis(0, JOY_AXIS_LEFT_Y, -0.9)
	var f2 := p1.sample()
	assert_true(not f2.is_held(&"jump") and f2.is_held(&"up"), "tap jump off: stick up is only up")
	_joy_axis(0, JOY_AXIS_LEFT_Y, 0.0)
	PlayerInput.tap_jump = true
	ControllerAssignment.reset()


func test_multiple_controllers_assignment() -> void:
	ControllerAssignment.reset(true)
	ControllerAssignment.assign(1, 3)
	ControllerAssignment.assign(2, 7)
	var p1 := PlayerInput.new(1)
	var p2 := PlayerInput.new(2)
	p1.sample()
	p2.sample()
	_joy_button(7, JOY_BUTTON_A, true)
	_joy_button(0, JOY_BUTTON_A, true)  # an unassigned third pad
	assert_true(p2.sample().is_pressed(&"light"), "pad 7 drives player 2 (any device id works)")
	assert_true(not p1.sample().is_held(&"light"), "player 1 ignores other pads")
	_joy_button(7, JOY_BUTTON_A, false)
	_joy_button(0, JOY_BUTTON_A, false)
	p1.sample()
	p2.sample()
	ControllerAssignment.swap_players()
	assert_eq(ControllerAssignment.device_for(1), 7, "swap moves pad 7 to player 1")
	assert_eq(ControllerAssignment.device_for(2), 3, "and pad 3 to player 2")
	ControllerAssignment.assign(1, 3)
	assert_eq(ControllerAssignment.device_for(2), 7, "assigning a pad already in use swaps the two")
	ControllerAssignment.reset()


func test_keyboard_and_controller_mix_for_one_player() -> void:
	ControllerAssignment.reset(true)
	ControllerAssignment.assign(1, 0)
	var p1 := PlayerInput.new(1)
	Input.action_press(&"p1_right")
	assert_eq(p1.sample().move_x, 1.0, "keyboard still works with a pad assigned")
	Input.action_release(&"p1_right")
	_joy_axis(0, JOY_AXIS_LEFT_X, -0.4)
	assert_near(p1.sample().move_x, -0.4, 0.01, "analog stick gives partial speed (walk)")
	_joy_axis(0, JOY_AXIS_LEFT_X, 0.1)
	assert_eq(p1.sample().move_x, 0.0, "stick drift inside the dead zone ignored")
	_joy_axis(0, JOY_AXIS_LEFT_X, 0.0)
	ControllerAssignment.reset()


# --- Directional attacks (framework) ---------------------------------------------
func _with_moves(base: CharacterData, extra: Dictionary) -> CharacterData:
	var c := _clone_character(base)
	var moves: Array[MoveData] = c.moves.duplicate()
	for id: StringName in extra:
		var m := _clone_move(c.get_move(extra[id]))
		m.id = id
		moves.append(m)
	c.moves = moves
	return c


func test_directional_attacks_fall_back_without_moves() -> void:
	var g: CharacterData = GANDALF
	assert_eq(g.resolve_attack(&"light", Vector2(0, -1), true, 1), &"light", "no up tilt -> light")
	assert_eq(g.resolve_attack(&"light", Vector2(-1, 0), false, 1), &"light", "no back air -> light")
	assert_eq(g.resolve_attack(&"heavy", Vector2(0, 1), true, 1), &"heavy", "no down smash -> heavy")


func test_directional_attacks_resolve_when_authored() -> void:
	var c := _with_moves(GANDALF, {&"light_up": &"light", &"air_back": &"light", &"air_neutral": &"light",
		&"heavy_down": &"heavy"})
	assert_true(c.validate().is_empty(), "optional slots are valid data: %s" % c.validate())
	assert_eq(c.resolve_attack(&"light", Vector2(0, -1), true, 1), &"light_up", "up + attack on the ground = up tilt")
	assert_eq(c.resolve_attack(&"light", Vector2(0, 1), true, 1), &"light", "no down tilt authored -> light")
	assert_eq(c.resolve_attack(&"light", Vector2(-1, 0), false, 1), &"air_back", "back air relative to facing")
	assert_eq(c.resolve_attack(&"light", Vector2(1, 0), false, 1), &"air_neutral", "no forward air -> neutral air")
	assert_eq(c.resolve_attack(&"light", Vector2(1, 0), false, -1), &"air_back", "mirrored facing")
	assert_eq(c.resolve_attack(&"heavy", Vector2(0, 1), true, 1), &"heavy_down", "down + heavy = down smash")


func test_directional_attack_from_input() -> void:
	var m: MatchController = await make_match()
	var c := _with_moves(GANDALF, {&"light_up": &"light", &"heavy_up": &"heavy"})
	m.characters[0] = c
	m.rematch()
	await tree.physics_frame
	face_off(m, 300)
	var g := m.get_fighter(1)
	p(m, 1).set_axis(Vector2(0, -1))
	p(m, 1).tap(&"light")
	step(m)
	p(m, 1).clear_axis()
	assert_eq(g.move.id, &"light_up", "up + A performs the up tilt")
	step(m, 60)
	p(m, 1).set_right_stick(Vector2(0, -1))
	step(m)
	p(m, 1).set_right_stick(Vector2.ZERO)
	assert_eq(g.move.id, &"heavy_up", "right stick up = up smash")
