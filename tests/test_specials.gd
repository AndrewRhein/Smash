extends "res://tests/test_case.gd"
## Projectiles, Force choke, Force guard and aimed lightning.


func _fire_projectile(m: MatchController, owner: Fighter) -> Projectile:
	var fireball := owner.character.get_move(&"special_2")
	m._on_projectile_requested(owner, fireball, fireball.projectiles[0])
	return m.projectiles[-1]


func test_fireball_spawns_on_active_tick_and_expires() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(g, 300, 1)
	place(m.get_fighter(2), 200, 1)  # behind Gandalf, never in the path
	step(m, 2)
	var fireball := g.character.get_move(&"special_2")
	p(m, 1).tap(&"special_2")
	step(m, fireball.startup_ticks)
	assert_eq(m.projectiles.size(), 0, "no projectile during startup")
	step(m)
	assert_eq(m.projectiles.size(), 1, "projectile spawns on first active tick")
	var proj := m.projectiles[0]
	assert_eq(proj.owner_player_id, 1, "projectile owned by player 1")
	assert_true(proj.velocity.x > 0.0, "fired in facing direction")
	step(m, fireball.projectiles[0].lifetime_ticks)
	assert_eq(m.projectiles.size(), 0, "projectile removed after its lifetime")
	await tree.process_frame
	assert_true(not is_instance_valid(proj), "projectile node freed")


func test_fireball_hits_once_and_credits_owner() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	place(g, 400, 1)
	place(v, 700, -1)
	step(m, 2)
	var credits: Array = []
	v.effect_requested.connect(func(id: StringName, _p: Vector2, _d: Vector2, payload: Dictionary) -> void:
		if id == GameIds.EFFECT_HIT_SPARK:
			credits.append(payload.attacker_id))
	p(m, 1).tap(&"special_2")
	step(m, 80)
	assert_eq(v.damage, g.character.get_move(&"special_2").damage, "fireball damage applied once")
	assert_eq(credits, [1], "hit credited to player 1")
	assert_eq(m.projectiles.size(), 0, "projectile consumed by the hit")


func test_projectiles_removed_when_owner_loses_stock() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(g, 400, 1)
	place(m.get_fighter(2), 200, 1)
	step(m, 2)
	_fire_projectile(m, g)
	assert_eq(m.projectiles.size(), 1, "projectile in flight")
	g.position = Vector2(640, 2000)
	step(m)
	assert_eq(g.stocks, 2, "owner lost a stock")
	assert_eq(m.projectiles.size(), 0, "owner's projectiles cleaned up")


func _grab(m: MatchController) -> bool:
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	place(g, 650, 1)
	place(v, 760, -1)
	step(m, 2)
	p(m, 2).tap(&"special_2")
	for i in 30:
		step(m)
		if g.state == Fighter.State.HELD:
			return true
	return false


func test_force_choke_is_bounded_and_launches() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	var choke := v.character.get_move(&"special_2")
	assert_true(await _grab(m), "choke grabs a target in range")
	assert_eq(v.held_target, g, "link recorded on Vader")
	var held := 0
	while g.state == Fighter.State.HELD and held < 500:
		p(m, 1).set_held(&"light", true)  # mashing does nothing while held
		step(m)
		held += 1
	assert_true(held <= choke.active_ticks, "hold bounded by the active window (%d ticks)" % held)
	assert_eq(g.state, Fighter.State.HITSTUN, "full choke ends in a launch")
	assert_true(g.held_by == null and v.held_target == null, "links cleared")
	var pulses := floori(float(held) / choke.hold_pulse_interval_ticks)
	assert_eq(g.damage, pulses * choke.hold_pulse_damage + choke.damage, "pulse + release damage")
	assert_true(g.grab_immunity_remaining > 0, "grab immunity after release")


func test_force_choke_whiff_goes_to_recovery() -> void:
	var m: MatchController = await make_match()
	var v := m.get_fighter(2)
	place(m.get_fighter(1), 200, 1)
	place(v, 760, -1)
	step(m, 2)
	var choke := v.character.get_move(&"special_2")
	p(m, 2).tap(&"special_2")
	var ticks := 0
	while v.state == Fighter.State.ATTACK or ticks == 0:
		step(m)
		ticks += 1
	assert_true(ticks < choke.total_ticks() - 30, "whiffed choke ends early (%d ticks)" % ticks)


func test_force_choke_interrupted_when_vader_is_hit() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	assert_true(await _grab(m), "grabbed")
	step(m, 5)
	_fire_projectile(m, g)  # a fireball Gandalf had in flight
	for i in 15:
		step(m)
		if v.state == Fighter.State.HITSTUN:
			break
	assert_eq(v.state, Fighter.State.HITSTUN, "Vader interrupted by the hit")
	assert_true(g.state != Fighter.State.HELD, "Gandalf released")
	assert_true(g.held_by == null and v.held_target == null, "links cleared")
	assert_true(g.state != Fighter.State.HITSTUN, "interrupted choke does not launch")


func test_force_choke_breaks_out_of_range_and_on_ko() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	assert_true(await _grab(m), "grabbed")
	v.position.x += 300.0
	step(m)
	assert_true(g.state != Fighter.State.HELD, "released when out of range")
	m.rematch()
	await tree.physics_frame
	g = m.get_fighter(1)
	v = m.get_fighter(2)
	assert_true(await _grab(m), "grabbed again after rematch")
	v.position = Vector2(640, 3000)
	step(m, 2)
	assert_eq(v.stocks, 2, "Vader KO'd")
	assert_true(g.state != Fighter.State.HELD and g.held_by == null, "KO releases the held fighter")


func test_grab_immunity_prevents_choke_loop() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	assert_true(await _grab(m), "grabbed")
	while g.state == Fighter.State.HELD:
		step(m)
	step(m, 40)
	v.cooldowns.clear()  # even ignoring cooldown, immunity blocks a regrab
	place(g, 650, 1)
	place(v, 760, -1)
	g.state = Fighter.State.IDLE
	p(m, 2).tap(&"special_2")
	step(m, 25)
	assert_true(g.state != Fighter.State.HELD, "immune fighter cannot be re-grabbed")


func test_force_guard_blocks_front_projectile_then_expires() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	place(g, 700, 1)
	place(v, 760, -1)
	step(m, 2)
	var guard := v.character.get_move(&"special_3")
	var blocks := []
	v.effect_requested.connect(func(id: StringName, _p: Vector2, _d: Vector2, _pl: Dictionary) -> void:
		if id == GameIds.EFFECT_GUARD_BLOCK:
			blocks.append(id))
	p(m, 2).tap(&"special_3")
	step(m, guard.startup_ticks + 1)
	_fire_projectile(m, g)
	step(m)
	assert_eq(v.damage, 0.0, "front projectile blocked")
	assert_eq(blocks.size(), 1, "guard_block effect")
	assert_eq(m.projectiles.size(), 0, "blocked projectile destroyed")
	step(m, guard.active_ticks + guard.recovery_ticks + CombatMath.BLOCK_HITSTOP_TICKS)
	assert_true(v.state != Fighter.State.ATTACK, "guard finished")
	assert_true(v.cooldowns.has(&"special_3"), "guard on cooldown")
	place(v, 760, -1)
	_fire_projectile(m, g)
	step(m, 2)
	assert_eq(v.damage, g.character.get_move(&"special_2").damage, "guard expired: projectile hits")


func test_force_guard_does_not_block_melee_or_back() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var v := m.get_fighter(2)
	face_off(m)
	p(m, 2).tap(&"special_3")
	step(m, 2)
	p(m, 1).tap(&"light")
	step(m, 8)
	assert_eq(v.damage, 5.0, "melee passes through Force guard")
	m.rematch()
	await tree.physics_frame
	g = m.get_fighter(1)
	v = m.get_fighter(2)
	place(g, 700, 1)
	place(v, 760, 1)  # facing away from Gandalf
	step(m, 2)
	p(m, 2).tap(&"special_3")
	step(m, 5)
	_fire_projectile(m, g)
	step(m)
	assert_true(v.damage > 0.0, "guard does not protect the back")


func test_lightning_telegraph_and_aim() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	place(g, 400, 1)
	place(m.get_fighter(2), 1000, -1)
	step(m, 2)
	var lightning := g.character.get_move(&"special_1")
	var effects := []
	g.effect_requested.connect(func(id: StringName, _p: Vector2, d: Vector2, _pl: Dictionary) -> void:
		effects.append([id, d]))
	p(m, 1).set_held(&"up", true)
	p(m, 1).tap(&"special_1")
	step(m)
	p(m, 1).set_held(&"up", false)
	assert_eq(effects[0][0], &"lightning_telegraph", "telegraph on the first tick")
	assert_eq(g.aim_angle_deg, lightning.aim_angle_deg, "aimed upward")
	step(m, lightning.startup_ticks)
	var boxes := g.get_active_hitboxes()
	assert_eq(boxes.size(), 4, "bolt hitboxes active")
	assert_true(boxes[-1].center.y < g.position.y - 55.0 - 50.0, "aimed bolt rises")
	assert_true(boxes[-1].center.x > g.position.x, "still forward")
	assert_eq(effects[-1][0], &"lightning_bolt", "bolt effect on the first active tick")
	assert_true(effects[-1][1].y < 0.0, "effect direction aimed up")


func test_force_push_is_directional() -> void:
	var m: MatchController = await make_match()
	var v := m.get_fighter(2)
	place(m.get_fighter(1), 200, 1)
	place(v, 760, -1)
	step(m, 2)
	var push := v.character.get_move(&"special_1")
	p(m, 2).set_held(&"up", true)
	p(m, 2).tap(&"special_1")
	step(m)
	p(m, 2).set_held(&"up", false)
	assert_eq(v.aim_angle_deg, push.aim_angle_deg, "push aimed up")
	step(m, push.startup_ticks)
	var far: Dictionary = v.get_active_hitboxes()[-1]
	assert_true(far.center.x < v.position.x, "push goes in facing direction (left)")
	assert_true(far.center.y < v.position.y - 48.0 - 30.0, "aimed push rises")
