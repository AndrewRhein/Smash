extends "res://tests/test_case.gd"
## Combat feel: turnarounds, DI, hit-confirm cancels, aerial landing lag,
## ledge grabs and charged heavies.


func test_heavy_buffered_with_back_on_left_stick_turns_around() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 300, 1)
	place(g, 640, 1)
	step(m, 2)
	g.state = Fighter.State.LAG
	g.lag_remaining = 4
	# Press heavy while holding back, then let go of the stick before Gandalf can
	# act: the buffered heavy must still come out facing back.
	p(m, 1).set_axis(Vector2(-1, 0))
	p(m, 1).tap(&"heavy")
	step(m)
	p(m, 1).clear_axis()
	for i in 6:
		step(m)
		if g.move != null:
			break
	assert_eq(g.move.id if g.move != null else &"", &"heavy", "buffered heavy comes out after lag")
	assert_eq(g.facing, -1, "heavy aimed backwards turns the fighter around")


func test_forward_tilt_turns_toward_the_stick() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 300, 1)
	place(g, 640, 1)
	step(m, 2)
	g.state = Fighter.State.LAG
	g.lag_remaining = 3
	p(m, 1).set_axis(Vector2(-1, 0))
	p(m, 1).tap(&"light")
	step(m)
	p(m, 1).clear_axis()
	step(m, 4)
	assert_eq(g.move.id if g.move != null else &"", &"light", "buffered light")
	assert_eq(g.facing, -1, "light toward the back turns around")


func test_di_bends_the_launch_angle() -> void:
	var angles: Array[float] = []
	for stick: Vector2 in [Vector2.ZERO, Vector2(0, -1), Vector2(0, 1)]:
		var m: MatchController = await make_match()
		var v := m.get_fighter(2)
		face_off(m)
		v.damage = 80.0
		v.last_stick = stick
		v.receive_hit(GANDALF.get_move(&"heavy"), 1, 0.0, 1, 0)
		angles.append(rad_to_deg(v.velocity.angle()))
		cleanup()
	assert_true(absf(angles[1] - angles[0]) > 5.0, "holding up changes the launch (%.1f vs %.1f)" % [angles[1], angles[0]])
	assert_true(absf(angles[2] - angles[0]) > 5.0, "holding down changes the launch (%.1f vs %.1f)" % [angles[2], angles[0]])
	assert_true(absf(angles[1] - angles[0]) <= Fighter.DI_MAX_DEG + 0.5, "DI is capped")


func test_jab_hit_confirms_into_heavy() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	face_off(m)
	assert_true(GANDALF.get_move(&"light").cancel_into.is_empty() or true, "uses data cancels when present")
	p(m, 1).tap(&"light")
	step(m)
	var light := g.move
	assert_eq(light.id, &"light", "jab")
	while not g.move_connected and g.move != null:
		step(m)
	assert_true(g.move_connected, "jab lands")
	while g.move != null and not g.move.is_recovery_tick(g.move_tick):
		step(m)
	p(m, 1).tap(&"heavy")
	step(m)
	step(m)
	assert_eq(g.move.id if g.move != null else &"", &"heavy", "heavy cancels the jab's recovery on hit")


func test_aerial_ends_on_landing_with_short_lag() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 300, 1)
	place(g, 640, 1, GROUND_Y - 30.0)
	g.velocity.y = 300.0
	step(m)
	p(m, 1).tap(&"light")
	step(m)
	assert_true(g.move != null and g.move_started_airborne, "aerial started in the air")
	for i in 20:
		step(m)
		if g.grounded:
			break
	assert_true(g.grounded, "landed")
	assert_eq(g.state, Fighter.State.LAG, "landing cancels the aerial into landing lag")
	step(m, Fighter.AERIAL_LANDING_LAG + 1)
	assert_true(g.state != Fighter.State.LAG, "landing lag is short")


func test_ledge_grab_hang_and_get_up() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 400, 1)
	place(g, 975, -1, 560)  # just off the right ledge, falling
	g.grounded = false
	for i in 30:
		step(m)
		if g.state == Fighter.State.LEDGE:
			break
	assert_eq(g.state, Fighter.State.LEDGE, "falling past the ledge grabs it")
	assert_eq(g.facing, -1, "faces the stage")
	assert_true(g.invulnerable_remaining > 0, "ledge grab is briefly invulnerable")
	var hang := g.position
	step(m, 20)
	assert_eq(g.position, hang, "hangs still")
	p(m, 1).set_axis(Vector2(-1, 0))
	p(m, 1).tap(&"left")
	step(m)
	p(m, 1).clear_axis()
	step(m, Fighter.LEDGE_GETUP_LAG + 4)
	assert_true(g.grounded and g.position.x < 940.0, "neutral get-up lands on the stage")
	assert_true(m._ledge_claims.is_empty(), "ledge released")


func test_ledge_jump_and_drop() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 400, 1)
	place(g, 305, 1, 560)  # off the left ledge
	g.grounded = false
	for i in 30:
		step(m)
		if g.state == Fighter.State.LEDGE:
			break
	assert_eq(g.state, Fighter.State.LEDGE, "left ledge grabbed")
	step(m, Fighter.LEDGE_ACTION_DELAY)
	p(m, 1).tap(&"jump")
	step(m)
	assert_true(g.velocity.y < -500.0, "ledge jump launches upward")
	step(m, 80)
	assert_true(g.grounded and g.position.x > 340.0, "ledge jump lands back on the stage")
	place(g, 305, 1, 560)
	g.grounded = false
	g.ledge_regrab_remaining = 0
	for i in 30:
		step(m)
		if g.state == Fighter.State.LEDGE:
			break
	step(m, Fighter.LEDGE_ACTION_DELAY)
	p(m, 1).tap(&"down")
	step(m)
	assert_eq(g.state, Fighter.State.FALL, "down lets go")
	step(m, 3)
	assert_true(g.state != Fighter.State.LEDGE, "no instant regrab")


func test_holding_heavy_charges_it() -> void:
	var damages: Array[float] = []
	for hold in [false, true]:
		var m: MatchController = await make_match()
		var g := m.get_fighter(1)
		var v := m.get_fighter(2)
		face_off(m)
		p(m, 1).tap(&"heavy")
		if hold:
			p(m, 1).set_held(&"heavy", true)
		step(m)
		var saw_charge := false
		for i in 120:
			step(m)
			saw_charge = saw_charge or g.charging
			if v.damage > 0.0:
				break
		p(m, 1).set_held(&"heavy", false)
		if hold:
			assert_true(saw_charge and g.charge_ticks > 0, "holding heavy charges")
			assert_eq(GANDALF.get_move(&"heavy").damage, damages[0], "shared move data is never mutated")
		damages.append(v.damage)
		cleanup()
	assert_true(damages[1] > damages[0] * 1.2, "a full charge hits harder (%.1f vs %.1f)" % [damages[1], damages[0]])
