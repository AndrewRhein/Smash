extends "res://tests/test_case.gd"


func test_ground_acceleration_and_deceleration() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	p(m, 1).set_held(&"right", true)
	step(m, 1)
	assert_true(g.velocity.x > 0.0 and g.velocity.x < g.character.max_speed, "accelerates, not instant")
	step(m, 20)
	assert_near(g.velocity.x, g.character.max_speed, 0.5, "reaches max speed")
	assert_eq(g.state, Fighter.State.RUN, "run state at full speed")
	p(m, 1).set_held(&"right", false)
	step(m, 30)
	assert_eq(g.velocity.x, 0.0, "decelerates to stop")
	assert_eq(g.state, Fighter.State.IDLE, "idle when stopped")


func test_variable_jump_height() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	var full := await _apex_height(m, g, 60)
	place(g, 600, 1)
	step(m, 3)
	var short := await _apex_height(m, g, 3)
	assert_true(full > short * 1.5, "holding jump goes higher (%.0f vs %.0f)" % [full, short])


func _apex_height(m: MatchController, g: Fighter, hold_ticks: int) -> float:
	var start := g.position.y
	var best := start
	p(m, 1).set_held(&"jump", true)
	for i in 80:
		if i == hold_ticks:
			p(m, 1).set_held(&"jump", false)
		step(m)
		best = minf(best, g.position.y)
	p(m, 1).set_held(&"jump", false)
	return start - best


func test_double_jump_and_reset_on_landing() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	p(m, 1).tap(&"jump")
	step(m, 10)
	assert_eq(g.air_jumps_left, 1, "air jump available after ground jump")
	p(m, 1).tap(&"jump")
	step(m)
	assert_eq(g.air_jumps_left, 0, "double jump consumed")
	assert_true(g.velocity.y < 0.0, "double jump launches upward")
	p(m, 1).tap(&"jump")
	step(m, 1)
	var vy := g.velocity.y
	step(m, 2)
	assert_true(g.velocity.y > vy, "no third jump")
	step(m, 120)
	assert_true(g.grounded, "landed")
	assert_eq(g.air_jumps_left, 1, "double jump restored on landing")


func test_jump_buffer_before_landing() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	g.position.y = GROUND_Y - 80
	g.grounded = false
	g.air_jumps_left = 0  # so the early press cannot be spent as a double jump
	var pressed := false
	var jumped := false
	for i in 60:
		if not pressed and g.velocity.y > 0.0 and g.position.y > GROUND_Y - 18.0:
			p(m, 1).set_held(&"jump", true)  # ~2 ticks before touching down, held for full height
			pressed = true
			assert_true(not g.grounded, "press happens while airborne")
		step(m)
		if pressed and g.velocity.y < -600.0:
			jumped = true
			break
	assert_true(pressed, "pressed before landing")
	p(m, 1).set_held(&"jump", false)
	assert_true(jumped, "buffered press became a full jump after landing")


func test_coyote_time() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 900, -1)
	# Run off the right edge of the main platform (x = 940).
	place(g, 930, 1)
	p(m, 1).set_held(&"right", true)
	var left_ground_at := -1
	for i in 30:
		step(m)
		if not g.grounded:
			left_ground_at = i
			break
	assert_true(left_ground_at >= 0, "walked off the ledge")
	step(m, 2)
	p(m, 1).tap(&"jump")
	step(m)
	assert_true(g.velocity.y < -600.0, "grounded-strength jump within coyote window")
	assert_eq(g.air_jumps_left, 1, "coyote jump does not consume the air jump")


func test_fast_fall() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	p(m, 1).set_held(&"jump", true)
	step(m, 24)  # near the apex of a full jump
	p(m, 1).set_held(&"jump", false)
	p(m, 1).tap(&"down")
	step(m)
	assert_true(g.fast_falling, "fast fall engaged")
	assert_near(g.velocity.y, g.character.fast_fall_speed, 1.0, "fast fall speed")


func test_drop_through_one_way_only() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 900, -1)
	# Land on the left one-way platform (top y = 410).
	place(g, 435, 1, 380)
	step(m, 30)
	assert_true(g.grounded and g.on_one_way, "standing on one-way platform")
	assert_near(g.position.y, 410.0, 1.0, "on top of the one-way platform")
	p(m, 1).tap(&"down")
	step(m, 40)
	assert_true(g.position.y > 500.0, "dropped through the one-way platform")
	step(m, 40)
	assert_near(g.position.y, GROUND_Y, 1.0, "landed on the solid main platform")
	p(m, 1).tap(&"down")
	step(m, 20)
	assert_near(g.position.y, GROUND_Y, 1.0, "main platform cannot be dropped through")
	assert_true(g.get_collision_mask_value(Stage.LAYER_WORLD), "world layer never disabled")


func test_one_way_platform_passable_from_below() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(m.get_fighter(2), 900, -1)
	place(g, 435, 1)
	step(m, 2)
	p(m, 1).set_held(&"jump", true)
	var best := g.position.y
	for i in 40:
		step(m)
		best = minf(best, g.position.y)
	p(m, 1).set_held(&"jump", false)
	assert_true(best < 410.0, "jumped up through one-way platform")
	step(m, 60)
	assert_near(g.position.y, 410.0, 1.0, "landed on top of it")
