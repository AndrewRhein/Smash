extends "res://tests/test_case.gd"
## Stocks, blast bounds, result, draw and rematch.


func _blast(f: Fighter) -> void:
	f.position = Vector2(640, 2000)


func test_blast_bounds_on_all_sides() -> void:
	var m: MatchController = await make_match(0, 9)
	var g := m.get_fighter(1)
	var b := m.stage.blast_bounds
	var outside := [
		Vector2(b.position.x - 5, 300), Vector2(b.end.x + 5, 300),
		Vector2(640, b.position.y - 5), Vector2(640, b.end.y + 5),
	]
	var expected := g.stocks
	for pos: Vector2 in outside:
		g.position = pos
		g.velocity = Vector2.ZERO
		step(m)
		expected -= 1
		assert_eq(g.stocks, expected, "KO beyond %s" % str(pos))
		step(m, Fighter.RESPAWN_DELAY_TICKS + 1)
		assert_true(g.is_in_play(), "respawned")


func test_one_stock_loss_per_blast_exit() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	_blast(g)
	for i in Fighter.RESPAWN_DELAY_TICKS - 5:
		step(m)
		g.position = Vector2(640, 2000)  # stays outside while waiting to respawn
	assert_eq(g.stocks, 2, "exactly one stock lost")
	assert_eq(g.state, Fighter.State.KO, "waiting to respawn")


func test_respawn_platform_resets_and_is_invulnerable() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	g.damage = 77.0
	g.shield_health = 3.0
	p(m, 1).set_held(&"jump", true)  # held through the KO: must not jump on respawn
	g.cooldowns[&"special_1"] = 50
	_blast(g)
	step(m, Fighter.RESPAWN_DELAY_TICKS + 1)
	assert_eq(g.state, Fighter.State.RESPAWN, "respawned on the platform")
	assert_eq(g.position, m.stage.respawn_point(1), "at the respawn platform")
	assert_eq(g.facing, 1, "player 1 faces the stage")
	assert_eq(g.damage, 0.0, "damage reset")
	assert_eq(g.shield_health, Fighter.SHIELD_MAX, "shield restored")
	assert_true(g.cooldowns.is_empty(), "cooldowns cleared")
	assert_eq(g.jump_buffer, 0, "no jump buffered through respawn")
	var y := g.position.y
	step(m, 60)
	assert_eq(g.position.y, y, "hovers while the player holds the old button")
	assert_true(not g.is_hittable() and g.get_presentation_snapshot().on_respawn_platform, "untouchable on the platform")
	p(m, 1).set_held(&"jump", false)
	step(m)
	p(m, 1).tap(&"jump")
	step(m)
	assert_eq(g.state, Fighter.State.JUMP, "jump leaves the platform")
	assert_true(g.velocity.y <= -g.character.jump_velocity + 30.0, "platform jump is a full grounded jump")
	assert_eq(g.air_jumps_left, 1, "double jump still available")
	assert_true(g.invulnerable_remaining > 100, "invulnerable for a while after leaving")


func test_respawn_platform_times_out() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	_blast(g)
	step(m, Fighter.RESPAWN_DELAY_TICKS + 1)
	step(m, Fighter.RESPAWN_PLATFORM_MAX_TICKS + 1)
	assert_true(g.state != Fighter.State.RESPAWN, "platform expires without input")
	assert_true(g.position.y > m.stage.respawn_point(1).y, "falls after the platform expires")


func test_ko_effect_is_on_screen() -> void:
	var m: MatchController = await make_match(0, 9)
	var g := m.get_fighter(1)
	var seen := []
	g.effect_requested.connect(func(id: StringName, pos: Vector2, _d: Vector2, payload: Dictionary) -> void:
		if id == GameIds.EFFECT_BLAST_KO:
			seen.append([pos, payload.exit_side]))
	var b := m.stage.blast_bounds
	for pos: Vector2 in [Vector2(b.end.x + 5, 300), Vector2(b.position.x - 5, 300), Vector2(640, b.position.y - 5), Vector2(640, b.end.y + 5)]:
		g.position = pos
		step(m)
		step(m, Fighter.RESPAWN_DELAY_TICKS + 2)
	assert_eq(seen.size(), 4, "four KOs")
	var sides := []
	for e in seen:
		assert_true(m.stage.visible_rect.has_point(e[0]), "KO burst at %s is on screen" % str(e[0]))
		sides.append(e[1])
	assert_eq(sides, ["right", "left", "top", "bottom"], "exit side reported")

func test_no_negative_stocks_and_eliminated_is_inert() -> void:
	var m: MatchController = await make_match(0, 1)
	var g := m.get_fighter(1)
	var eliminated := []
	g.eliminated.connect(func(id: int) -> void: eliminated.append(id))
	_blast(g)
	step(m, 5)
	g.blast_ko()  # repeated calls must be ignored
	assert_eq(g.stocks, 0, "stocks floor at zero")
	assert_eq(eliminated, [1], "eliminated emitted once")
	assert_eq(g.state, Fighter.State.ELIMINATED, "eliminated state")
	assert_true(not g.is_hittable(), "eliminated fighter cannot be hit")
	assert_true(g.get_active_hitboxes().is_empty(), "eliminated fighter cannot attack")


func test_exactly_one_result_and_frozen_after() -> void:
	var m: MatchController = await make_match(0, 1)
	var results := []
	m.match_ended.connect(func(w: int) -> void: results.append(w))
	var v := m.get_fighter(2)
	_blast(v)
	step(m, 3)
	_blast(m.get_fighter(1))
	step(m, 60)
	assert_eq(results, [1], "one result: player 1 wins")
	assert_eq(m.state, MatchController.MatchState.RESULT, "match in result state")
	assert_eq(m.get_fighter(1).stocks, 1, "winner keeps its stock")
	assert_eq(m.get_fighter(1).state, Fighter.State.VICTORY, "winner in victory state")
	var g := m.get_fighter(1)
	var pos := g.position
	p(m, 1).tap(&"light")
	p(m, 1).set_held(&"right", true)
	step(m, 30)
	assert_eq(g.position, pos, "no movement after the result")
	assert_eq(g.move, null, "no attacks after the result")


func test_simultaneous_final_ko_is_draw() -> void:
	var m: MatchController = await make_match(0, 1)
	var results := []
	m.match_ended.connect(func(w: int) -> void: results.append(w))
	_blast(m.get_fighter(1))
	_blast(m.get_fighter(2))
	step(m, 10)
	assert_eq(results, [MatchController.DRAW], "draw reported once")
	assert_eq(m.winner_player_id, 0, "winner_player_id 0 = draw")
	for f in m.fighters:
		assert_eq(f.stocks, 0, "both eliminated")


func test_countdown_blocks_input() -> void:
	var m: MatchController = await make_match(30)
	var g := m.get_fighter(1)
	assert_eq(m.state, MatchController.MatchState.COUNTDOWN, "starts in countdown")
	p(m, 1).set_held(&"light", true)
	p(m, 1).set_held(&"right", true)
	step(m, 30)
	assert_eq(m.state, MatchController.MatchState.PLAYING, "fight begins")
	assert_eq(g.attack_instance, 0, "no attack during countdown")
	step(m, 5)
	assert_eq(g.attack_instance, 0, "button held through countdown is not a press")
	assert_true(g.velocity.x > 0.0, "held direction works once playing")


func test_rematch_resets_everything() -> void:
	var m: MatchController = await make_match(0, 1)
	var old := m.fighters.duplicate()
	var g := m.get_fighter(1)
	g.damage = 50.0
	m._on_projectile_requested(g, g.character.get_move(&"special_2"), g.character.get_move(&"special_2").projectiles[0])
	_blast(m.get_fighter(2))
	step(m, 2)
	assert_eq(m.state, MatchController.MatchState.RESULT, "match over")
	var spawned := []
	m.fighter_spawned.connect(func(f: Fighter) -> void: spawned.append(f))
	m.stock_count = 3
	m.rematch()
	await tree.process_frame
	for f in old:
		assert_true(not is_instance_valid(f), "old fighters freed")
	assert_eq(spawned.size(), 2, "fighter_spawned emitted for HUD/presentation rebinding")
	assert_eq(m.state, MatchController.MatchState.PLAYING, "playing again (countdown 0 in tests)")
	assert_eq(m.tick, 0, "match tick reset")
	assert_eq(m.winner_player_id, -1, "result cleared")
	assert_eq(m.projectiles.size(), 0, "projectiles cleared")
	for f in m.fighters:
		assert_eq(f.stocks, 3, "stocks restored")
		assert_eq(f.damage, 0.0, "damage restored")
		assert_eq(f.state, Fighter.State.FALL, "fresh state")
		assert_eq(f.position, m.stage.spawn_point(f.player_id), "at spawn")
		assert_true(f.cooldowns.is_empty() and f.held_target == null and f.held_by == null, "combat state clean")
	# The rematch is fully playable: result can happen again exactly once.
	var results := []
	m.match_ended.connect(func(w: int) -> void: results.append(w))
	for i in 3:
		_blast(m.get_fighter(1))
		step(m, Fighter.RESPAWN_DELAY_TICKS + 2)
	assert_eq(results, [2], "second match produced one result")
