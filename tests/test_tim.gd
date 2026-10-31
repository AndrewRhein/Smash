extends "res://tests/test_case.gd"
## Tim: LEGO castle trap, NYPD takedown grapple, slow drone.
const TIM = preload("res://data/characters/tim.tres")


func _tim_match() -> MatchController:
	var m: MatchController = await make_match()
	m.characters[1] = TIM
	m.rematch()
	await tree.physics_frame
	return m


func test_lego_castle_is_a_stationary_trap() -> void:
	var m := await _tim_match()
	var g := m.get_fighter(1)
	var tim := m.get_fighter(2)
	place(tim, 760, -1)
	place(g, 400, 1)
	step(m, 2)
	p(m, 2).set_axis(Vector2(0, 1))
	p(m, 2).tap(&"special")
	step(m)
	p(m, 2).clear_axis()
	assert_eq(tim.move.id, &"special_3", "down B = LEGO Castle Deployment")
	while m.projectiles.is_empty() and m.tick < 60:
		step(m)
	assert_eq(m.projectiles.size(), 1, "castle deployed")
	var castle: Projectile = m.projectiles[0]
	var at := castle.global_position
	step(m, 60)
	assert_eq(castle.global_position, at, "castle stays where it was built")
	assert_true(at.x < tim.position.x, "built in front of Tim (facing left)")
	g.position = Vector2(at.x - 10, GROUND_Y)
	step(m, 3)
	assert_eq(g.damage, TIM.get_move(&"special_3").damage, "walking into the castle hurts")
	assert_true(m.projectiles.is_empty(), "castle is used up by the hit")


func test_nypd_takedown_grabs_and_holds() -> void:
	var m := await _tim_match()
	var g := m.get_fighter(1)
	var tim := m.get_fighter(2)
	place(tim, 700, -1)
	place(g, 640, 1)
	step(m, 2)
	p(m, 2).set_axis(Vector2(-1, 0))
	p(m, 2).tap(&"special")
	step(m)
	p(m, 2).clear_axis()
	assert_eq(tim.move.id, &"special_1", "side B = NYPD Takedown")
	for i in 30:
		step(m)
		if g.state == Fighter.State.HELD:
			break
	assert_eq(g.state, Fighter.State.HELD, "takedown grabs")
	while g.state == Fighter.State.HELD and m.tick < 300:
		step(m)
	assert_eq(g.state, Fighter.State.HITSTUN, "then throws")
	assert_true(g.damage > TIM.get_move(&"special_1").damage, "hold damage plus throw")


func test_drone_is_slow_and_long_lived() -> void:
	var drone_data: ProjectileData = TIM.get_move(&"special_2").projectiles[0]
	var fireball: ProjectileData = GANDALF.get_move(&"special_2").projectiles[0]
	assert_true(drone_data.velocity.x < fireball.velocity.x, "drone flies slower than a fireball")
	assert_true(drone_data.lifetime_ticks > fireball.lifetime_ticks, "and lingers longer")
