extends "res://tests/test_case.gd"
## Pope Leo: data, packed art, consistent sprite size, moves and art phases.
const LEO = preload("res://data/characters/leo.tres")
const Setup = preload("res://scripts/presentation/presentation_setup.gd")


func test_leo_directional_moves_resolve() -> void:
	assert_eq(LEO.resolve_attack(&"light", Vector2(0, -1), true, 1), &"light_up", "up tilt: Tome Lift")
	assert_eq(LEO.resolve_attack(&"light", Vector2(0, 1), true, 1), &"light_down", "down tilt: Key Sweep")
	assert_eq(LEO.resolve_attack(&"heavy", Vector2(0, -1), true, 1), &"heavy_up", "up smash: Monstrance")
	assert_eq(LEO.resolve_attack(&"light", Vector2(1, 0), false, 1), &"air_forward", "forward air: Flying Kick")
	assert_eq(LEO.resolve_attack(&"light", Vector2(0, -1), false, 1), &"air_up", "up air: Heavenward Fist")
	assert_eq(LEO.resolve_attack(&"light", Vector2(-1, 0), false, 1), &"light", "no back air -> light")
	assert_eq(LEO.special_for_direction(Vector2.ZERO), &"special_2", "B: Holy Tome")


func test_benediction_pushes_away_on_both_sides() -> void:
	var m: MatchController = await make_match()
	m.characters[1] = LEO
	m.rematch()
	await tree.physics_frame
	var g := m.get_fighter(1)
	var leo := m.get_fighter(2)
	place(leo, 640, 1)
	place(g, 600, 1)  # BEHIND Leo (Leo faces right)
	step(m, 2)
	p(m, 2).set_axis(Vector2(0, 1))
	p(m, 2).tap(&"special")
	step(m)
	p(m, 2).clear_axis()
	assert_eq(leo.move.id, &"special_3", "down B = Benediction")
	while g.damage == 0.0 and m.tick < 100:
		step(m)
	assert_true(g.damage > 0.0, "burst hits behind")
	assert_true(g.velocity.x < 0.0, "victim behind is pushed away (left), not toward Leo's facing")
