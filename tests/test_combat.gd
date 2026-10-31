extends "res://tests/test_case.gd"
## Melee timing, hit-once, mirroring, knockback, hitstun, hitstop, cooldowns.
## Gandalf light: startup 5, active 4 (move ticks 5-8), recovery 12, total 21.


func test_no_damage_before_startup_ends() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	p(m, 1).tap(&"light")
	var hit_at := -1
	for i in 10:
		step(m)
		if v.damage > 0.0:
			hit_at = g.move_tick
			break
	assert_eq(hit_at, 5, "first damage on the first active tick (move tick 5)")
	assert_eq(v.damage, 5.0, "light damage")


func test_no_damage_after_active_window() -> void:
	var m: MatchController = await make_match()
	face_off(m, 400)
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	p(m, 1).tap(&"light")
	step(m, 10)
	assert_eq(g.move_tick, 9, "in recovery")
	for i in 15:
		place(v, 660, -1)  # stand inside the (inactive) hitbox area every tick
		step(m)
	assert_eq(v.damage, 0.0, "recovery frames deal no damage")


func test_hitbox_hits_target_only_once() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	# Heavy has two hitboxes over 6 active ticks; keep the victim inside both.
	p(m, 1).tap(&"heavy")
	for i in 70:
		v.position = Vector2(660, GROUND_Y)
		v.velocity = Vector2.ZERO
		step(m)
	assert_eq(v.damage, g.character.get_move(&"heavy").damage, "one hit per attack instance")


func test_mirrored_hitboxes() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	# Facing right with the victim on the left: no hit.
	place(g, 600, 1)
	place(v, 540, 1)
	step(m, 2)
	p(m, 1).tap(&"light")
	step(m, 25)
	assert_eq(v.damage, 0.0, "facing away does not hit")
	# Facing left with the same victim position: hits, knocks to the left.
	place(g, 600, -1)
	place(v, 540, 1)
	step(m, 2)
	p(m, 1).tap(&"light")
	var vx := 0.0
	for i in 10:
		step(m)
		if v.damage > 0.0:
			vx = v.velocity.x
			break
	assert_eq(v.damage, 5.0, "mirrored hitbox hits")
	assert_true(vx < 0.0, "knockback mirrored to the left")
	var hb: Dictionary = {}
	g.move = g.character.get_move(&"light")
	g.state = Fighter.State.ATTACK
	g.move_tick = 5
	hb = g.get_active_hitboxes()[0]
	assert_near(hb.center.x, g.position.x - 46.0, 0.01, "offset.x mirrored around the root")


func test_more_damage_more_knockback() -> void:
	var m: MatchController = await make_match()
	var low := await _launch_speed(m, 0.0)
	m.rematch()
	await tree.physics_frame
	var high := await _launch_speed(m, 80.0)
	assert_true(low > 0.0, "knockback at 0%")
	assert_true(high > low * 1.5, "more damage, more knockback (%.0f vs %.0f)" % [high, low])


func _launch_speed(m: MatchController, start_damage: float) -> float:
	face_off(m)
	var v := m.get_fighter(2)
	v.damage = start_damage
	p(m, 1).tap(&"light")
	for i in 10:
		step(m)
		if v.damage > start_damage:
			return v.velocity.length()
	return 0.0


func test_hitstun_preserves_knockback() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var v := m.get_fighter(2)
	v.damage = 60.0
	p(m, 1).tap(&"heavy")
	for i in 30:
		step(m)
		if v.state == Fighter.State.HITSTUN:
			break
	var launch_vx := v.velocity.x
	assert_true(launch_vx > v.character.max_speed, "launched faster than run speed")
	p(m, 2).set_held(&"left", true)  # steer back toward the attacker
	var hitstun_ticks := v.hitstun_remaining
	for i in mini(hitstun_ticks, 20):
		step(m)
		assert_true(v.velocity.x > v.character.max_speed * 0.5, "input does not erase knockback (tick %d, vx=%.0f)" % [i, v.velocity.x])
	assert_true(v.velocity.x > 0.0, "still moving away during hitstun")


func test_hitstop_freezes_attacker_and_victim() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	p(m, 1).tap(&"light")
	while v.damage == 0.0:
		step(m)
	var expected := CombatMath.hitstop_ticks(5.0)
	assert_eq(v.hitstop_remaining, expected, "victim hitstop")
	assert_eq(g.hitstop_remaining, expected, "attacker hitstop")
	var v_pos := v.position
	var g_tick := g.move_tick
	step(m, expected)
	assert_eq(v.position, v_pos, "victim frozen during hitstop")
	assert_eq(g.move_tick, g_tick, "attacker timeline frozen during hitstop")
	step(m)
	assert_true(v.position != v_pos, "victim moves after hitstop")
	assert_eq(g.move_tick, g_tick + 1, "attacker resumes after hitstop")


func test_invulnerability_blocks_damage() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var v := m.get_fighter(2)
	v.invulnerable_remaining = 100
	p(m, 1).tap(&"light")
	step(m, 25)
	assert_eq(v.damage, 0.0, "invulnerable fighter takes no damage")
	assert_true(v.state != Fighter.State.HITSTUN, "no hitstun while invulnerable")


func test_recovery_blocks_attacks_and_holding_does_not_repeat() -> void:
	var m: MatchController = await make_match()
	face_off(m, 400)
	var g := m.get_fighter(1)
	var start_instance := g.attack_instance
	p(m, 1).set_held(&"light", true)
	step(m, 80)
	p(m, 1).set_held(&"light", false)
	step(m)
	assert_eq(g.attack_instance, start_instance + 1, "holding light attacks exactly once")
	# Early press during recovery: blocked and expires (buffer is 6 ticks).
	p(m, 1).tap(&"light")
	step(m, 11)
	var instance := g.attack_instance
	p(m, 1).tap(&"light")  # move tick 11, recovery
	for i in 15:
		step(m)
		assert_eq(g.attack_instance, instance, "no attack during or after recovery from an expired press")
	# Late press within the buffer: starts exactly when recovery ends.
	p(m, 1).tap(&"light")
	step(m, 18)
	assert_eq(g.move_tick, 17, "in recovery")
	p(m, 1).tap(&"light")
	for i in 3:
		step(m)
		assert_eq(g.attack_instance, instance + 1, "still recovering (tick %d)" % g.move_tick)
	step(m)
	assert_eq(g.attack_instance, instance + 2, "buffered attack starts on the first free tick")
	assert_eq(g.move_tick, 0, "new move begins at tick 0")


func test_cooldown_blocks_reuse() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(g, 600, 1)
	place(m.get_fighter(2), 300, 1)
	step(m, 2)
	var fireball := g.character.get_move(&"special_2")
	p(m, 1).tap(&"special_2")
	step(m, fireball.total_ticks() + 2)
	assert_true(g.state != Fighter.State.ATTACK, "fireball finished")
	var instance := g.attack_instance
	p(m, 1).tap(&"special_2")
	step(m, 3)
	assert_eq(g.attack_instance, instance, "special blocked by cooldown")
	step(m, fireball.cooldown_ticks)
	p(m, 1).tap(&"special_2")
	step(m)
	assert_eq(g.attack_instance, instance + 1, "special available after cooldown")


func test_cancel_into_special_only_on_hit() -> void:
	var m: MatchController = await make_match()
	face_off(m, 400)
	var g := m.get_fighter(1)
	p(m, 1).tap(&"light")
	step(m, 11)
	p(m, 1).tap(&"special_3")
	step(m)
	assert_eq(g.move.id, &"light", "whiffed light cannot cancel")
	m.rematch()
	await tree.physics_frame
	face_off(m)
	g = m.get_fighter(1)
	p(m, 1).tap(&"light")
	while m.get_fighter(2).damage == 0.0:
		step(m)
	step(m, 10)
	assert_true(g.move.is_recovery_tick(g.move_tick), "in light recovery")
	p(m, 1).tap(&"special_3")
	step(m)
	assert_eq(g.move.id, &"special_3", "connected light cancels into special")


func test_simultaneous_trade_is_symmetric() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	# Vader startup 6, Gandalf startup 5: press Vader one tick earlier to trade.
	p(m, 2).tap(&"light")
	step(m)
	p(m, 1).tap(&"light")
	for i in 10:
		step(m)
		if g.damage > 0.0 or v.damage > 0.0:
			break
	assert_eq(g.damage, 6.0, "Gandalf took Vader's slash")
	assert_eq(v.damage, 5.0, "Vader took Gandalf's strike")
	assert_eq(g.state, Fighter.State.HITSTUN, "Gandalf in hitstun")
	assert_eq(v.state, Fighter.State.HITSTUN, "Vader in hitstun")
	assert_eq(g.hitstop_remaining, v.hitstop_remaining, "trade hitstop is symmetric")


func test_multi_hit_hitbox_rehits_on_interval_only() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	# Author a multi-hit variant of the heavy: one hitbox over all 6 active
	# ticks that may re-hit every 2 of the attacker's move ticks.
	var data := _clone_character(g.character)
	var heavy := data.get_move(&"heavy")
	heavy.hitboxes = [heavy.hitboxes[1]]
	heavy.hitboxes[0].start_tick = 0
	heavy.hitboxes[0].duration_ticks = 0
	heavy.hitboxes[0].rehit_interval_ticks = 2
	assert_true(data.validate().is_empty(), "multi-hit variant is valid data")
	g.character = data
	p(m, 1).tap(&"heavy")
	for i in 90:
		v.position = Vector2(660, GROUND_Y)
		v.velocity = Vector2.ZERO
		step(m)
	# Active move ticks 16..21 -> hits on 16, 18, 20 even though hitstop froze
	# the attacker between them for many match ticks.
	assert_eq(v.damage, heavy.damage * 3.0, "three hits at a 2-tick interval")
