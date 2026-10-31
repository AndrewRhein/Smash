extends "res://tests/test_case.gd"
## Pope Leo: data, packed art, consistent sprite size, moves and art phases.
const LEO = preload("res://data/characters/leo.tres")
const Setup = preload("res://scripts/presentation/presentation_setup.gd")


func _leo_match() -> MatchController:
	var m: MatchController = await make_match()
	m.characters[1] = Setup.with_art(LEO)
	m.rematch()
	await tree.physics_frame
	await tree.physics_frame
	return m


func test_leo_data_roster_and_art_contract() -> void:
	assert_true(LEO.validate().is_empty(), "Leo validates: %s" % LEO.validate())
	assert_true(CharacterRoster.has(&"leo"), "Leo is on the roster")
	var frames: SpriteFrames = load("res://art/characters/leo/animations.tres")
	for id in GameIds.SHARED_ANIMATION_IDS + GameIds.MECHANIC_ANIMATION_IDS + GameIds.MOVE_ANIMATION_IDS[&"leo"]:
		assert_true(frames.has_animation(id) and frames.get_frame_count(id) > 0, "Leo art for %s" % id)
	for move in LEO.moves:
		assert_true(frames.has_animation(move.animation_id), "move %s has art" % move.id)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/leo/manifest.json"))
	assert_eq(FileAccess.get_sha256("res://art/characters/leo/atlas.png"), manifest.atlas_sha256, "atlas matches its build")
	assert_true(LEO.visual_scene == null, "art is attached by presentation setup, data stays art-free")
	assert_true(Setup.with_art(LEO).visual_scene != null, "with_art attaches Leo's sprites")


func test_leo_sprite_size_is_consistent() -> void:
	# The Elon lesson: the body must not grow during attacks. Compare the
	# silhouette height of every standing frame with idle (weapons above the
	# head and crouches excluded by using frames whose poses stay upright).
	var atlas := (load("res://art/characters/leo/atlas.png") as Texture2D).get_image()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/leo/manifest.json"))
	var idle_h := _height(atlas, int(manifest.animations.idle[0]))
	for anim in ["palm_strike", "crosier_smash", "censer_swing", "holy_tome", "benediction", "key_sweep"]:
		for k in manifest.animations[anim]:
			var h := _height(atlas, int(k))
			assert_true(absf(h - idle_h) / idle_h < 0.12, "%s frame %d height %d vs idle %d" % [anim, k, h, idle_h])


func _height(atlas: Image, k: int) -> int:
	var cell := atlas.get_region(Rect2i((k % 8) * 256, (k / 8) * 256, 256, 256))
	return cell.get_used_rect().size.y


func test_leo_moves_follow_art_phases() -> void:
	var m: MatchController = await _leo_match()
	for spec in [[&"light", Vector2.ZERO], [&"heavy", Vector2.ZERO], [&"special", Vector2.ZERO],
			[&"special", Vector2(1, 0)], [&"special", Vector2(0, 1)], [&"light", Vector2(0, -1)],
			[&"light", Vector2(0, 1)], [&"heavy", Vector2(0, -1)]]:
		m.rematch()
		var e := m.get_fighter(2)
		place(m.get_fighter(1), 300, 1)
		place(e, 800, 1)
		step(m, 2)
		p(m, 2).set_axis(spec[1])
		p(m, 2).tap(spec[0])
		step(m)
		p(m, 2).clear_axis()
		assert_true(e.move != null, "%s %s starts a move" % spec)
		if e.move == null:
			continue
		var move := e.move
		while e.move != null and e.move == move:
			e.visual_root._process(0.0)
			var expected := 0 if e.move_tick < move.startup_ticks else (1 if move.is_active_tick(e.move_tick) else 2)
			assert_eq(e.visual_root.sprite.frame, expected, "%s pose follows its phase" % move.id)
			step(m)
		assert_true(e.visual_root.warned.is_empty(), "no missing animations for %s" % move.id)


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
