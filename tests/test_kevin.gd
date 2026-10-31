extends "res://tests/test_case.gd"
## Kevin: airstrike from the sky, lobbed talking cookie, shrimp-scampi heal.
const KEVIN = preload("res://data/characters/kevin.tres")


func _kevin_match() -> MatchController:
	var m: MatchController = await make_match()
	m.characters[1] = KEVIN
	m.rematch()
	await tree.physics_frame
	return m


func _special(m: MatchController, axis: Vector2) -> void:
	p(m, 2).set_axis(axis)
	p(m, 2).tap(&"special")
	step(m)
	p(m, 2).clear_axis()


func test_scampi_heals_and_clamps_at_zero() -> void:
	var m := await _kevin_match()
	var kev := m.get_fighter(2)
	place(kev, 760, -1)
	place(m.get_fighter(1), 400, 1)
	kev.damage = 30.0
	step(m, 2)
	_special(m, Vector2(0, 1))
	assert_eq(kev.move.id, &"special_3", "down B = Shrimp Scampi")
	while kev.move != null and m.tick < 120:
		step(m)
	assert_eq(kev.damage, 30.0 - KEVIN.get_move(&"special_3").self_heal, "eating heals")
	kev.damage = 5.0
	kev.cooldowns.clear()
	_special(m, Vector2(0, 1))
	var saw_glow := false
	while kev.move != null and m.tick < 300:
		step(m)
		saw_glow = saw_glow or kev.get_presentation_snapshot().healing
	assert_eq(kev.damage, 0.0, "never below 0%")
	assert_true(saw_glow, "snapshot shows the heal")


func test_airstrike_drops_from_the_sky_ahead() -> void:
	var m := await _kevin_match()
	var g := m.get_fighter(1)
	var kev := m.get_fighter(2)
	place(kev, 800, -1)
	place(g, 570, 1)
	step(m, 2)
	_special(m, Vector2(-1, 0))
	assert_eq(kev.move.id, &"special_1", "side B = Airstrike")
	while m.projectiles.is_empty() and m.tick < 60:
		step(m)
	var missile: Projectile = m.projectiles[0]
	assert_true(missile.global_position.y < kev.position.y - 400, "starts high in the sky")
	assert_true(missile.global_position.x < kev.position.x - 150, "lands well in front of Kevin")
	var hit := false
	for i in 60:
		step(m)
		if g.damage > 0.0:
			hit = true
			break
	assert_true(hit, "missile hits the fighter below")


func test_cookie_is_lobbed_in_an_arc() -> void:
	var m := await _kevin_match()
	var kev := m.get_fighter(2)
	place(kev, 800, -1)
	place(m.get_fighter(1), 300, 1)
	step(m, 2)
	_special(m, Vector2.ZERO)
	assert_eq(kev.move.id, &"special_2", "neutral B = Talking Cookie")
	while m.projectiles.is_empty() and m.tick < 60:
		step(m)
	var cookie: Projectile = m.projectiles[0]
	var v0 := cookie.velocity.y
	step(m, 10)
	assert_true(cookie.velocity.y > v0, "gravity pulls the cookie down")
	assert_true(cookie.velocity.x < 0.0, "thrown the way Kevin faces")
