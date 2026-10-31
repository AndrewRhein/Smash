extends "res://tests/test_case.gd"
## Dr. Sundar: cold-hands freeze grab, defibrillator stun, vial toss.
const SUNDAR = preload("res://data/characters/sundar.tres")


func _sundar_match() -> MatchController:
	var m: MatchController = await make_match()
	m.characters[1] = SUNDAR
	m.rematch()
	await tree.physics_frame
	return m


func test_cold_hands_freezes_then_throws() -> void:
	var m := await _sundar_match()
	var g := m.get_fighter(1)
	var doc := m.get_fighter(2)
	place(doc, 700, -1)
	place(g, 645, 1)
	step(m, 2)
	p(m, 2).set_axis(Vector2(-1, 0))
	p(m, 2).tap(&"special")
	step(m)
	p(m, 2).clear_axis()
	assert_eq(doc.move.id, &"special_1", "side B = Cold Hands")
	for i in 30:
		step(m)
		if g.state == Fighter.State.HELD:
			break
	assert_eq(g.state, Fighter.State.HELD, "cold hands grabs")
	assert_eq(g.get_presentation_snapshot().get("held_visual"), &"frozen", "victim is shown frozen in ice")
	while g.state == Fighter.State.HELD and m.tick < 300:
		step(m)
	assert_eq(g.state, Fighter.State.HITSTUN, "then thaws into a throw")
	assert_eq(g.get_presentation_snapshot().get("held_visual"), &"", "ice gone after release")
	assert_true(g.damage > SUNDAR.get_move(&"special_1").damage, "chill damage plus throw")


func test_defibrillator_stuns_longer_than_a_heavy() -> void:
	var defib: MoveData = SUNDAR.get_move(&"special_3")
	var heavy: MoveData = SUNDAR.get_move(&"heavy")
	assert_true(defib.hitstun_ticks > heavy.hitstun_ticks, "defibrillator shock locks the target longer")


func test_vial_toss_spawns_a_projectile() -> void:
	var m := await _sundar_match()
	var doc := m.get_fighter(2)
	place(doc, 760, -1)
	place(m.get_fighter(1), 400, 1)
	step(m, 2)
	p(m, 2).tap(&"special")
	step(m)
	assert_eq(doc.move.id, &"special_2", "neutral B = Vial Toss")
	while m.projectiles.is_empty() and m.tick < 60:
		step(m)
	assert_eq(m.projectiles.size(), 1, "vial thrown")
	var vial: Projectile = m.projectiles[0]
	var x0 := vial.global_position.x
	step(m, 5)
	assert_true(vial.global_position.x < x0, "flies the way Sundar faces")
