extends "res://tests/test_case.gd"
## Presentation contract v1: signals, snapshot, VisualRoot independence.


func test_animation_requested_on_transitions_only() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	var log := []
	g.animation_requested.connect(func(id: StringName, d: int, loop: bool) -> void: log.append([id, d, loop]))
	step(m, 20)
	assert_eq(log.size(), 0, "no requests while idle")
	p(m, 1).tap(&"light")
	step(m, 30)
	var light := g.character.get_move(&"light")
	assert_eq(log[0], [&"staff_strike", light.total_ticks(), false], "move animation with gameplay duration")
	assert_eq(log[-1][0], &"idle", "back to idle")
	assert_eq(log.size(), 2, "exactly two transitions")
	log.clear()
	p(m, 1).set_held(&"right", true)
	step(m, 30)
	var ids := log.map(func(e: Array) -> StringName: return e[0])
	assert_eq(ids, [&"walk", &"run"], "walk then run while accelerating")
	assert_eq(log[1][1], 0, "locomotion duration 0")
	assert_true(log[1][2], "locomotion loops")


func test_same_move_twice_requests_twice() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	var count := [0]
	g.animation_requested.connect(func(id: StringName, _d: int, _l: bool) -> void:
		if id == &"staff_strike":
			count[0] += 1)
	p(m, 1).tap(&"light")
	step(m, 18)
	p(m, 1).tap(&"light")  # buffered: starts the tick recovery ends
	step(m, 10)
	assert_eq(count[0], 2, "new attack instance re-requests its animation")


func test_hurt_and_knockback_animation_and_hitstop_in_snapshot() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var v := m.get_fighter(2)
	var log := []
	v.animation_requested.connect(func(id: StringName, d: int, _l: bool) -> void: log.append([id, d]))
	p(m, 1).tap(&"light")
	while v.damage == 0.0:
		step(m)
	assert_eq(log[-1][0], &"hurt", "light hit at 0% plays hurt")
	assert_eq(log[-1][1], v.hitstun_total, "hurt duration = hitstun ticks")
	var snap := v.get_presentation_snapshot()
	assert_true(snap.hitstop_remaining_ticks > 0, "snapshot exposes hitstop")
	assert_eq(snap.state, &"hitstun", "snapshot state name")


func test_snapshot_fields_and_inactive_values() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var snap := g.get_presentation_snapshot()
	var required := {
		"character_id": TYPE_STRING_NAME, "player_id": TYPE_INT, "state": TYPE_STRING_NAME,
		"facing": TYPE_INT, "velocity": TYPE_VECTOR2, "grounded": TYPE_BOOL,
		"current_move_id": TYPE_STRING_NAME, "move_tick": TYPE_INT, "damage": TYPE_FLOAT,
		"stocks": TYPE_INT, "invulnerable": TYPE_BOOL, "hitstop_remaining_ticks": TYPE_INT,
	}
	for key: String in required:
		assert_true(snap.has(key), "snapshot has %s" % key)
		assert_eq(typeof(snap.get(key)), required[key], "type of %s" % key)
	assert_eq(snap.current_move_id, &"", "no move -> empty id")
	assert_eq(snap.move_tick, -1, "no move -> -1")
	assert_eq(snap.character_id, &"gandalf", "character id")


func test_facing_changed_and_visual_root_is_presentation_only() -> void:
	var m: MatchController = await make_match()
	face_off(m, 300)
	var g := m.get_fighter(1)
	var facings := []
	g.facing_changed.connect(func(f: int) -> void: facings.append(f))
	var hurt_right := g.get_hurtbox_world()
	p(m, 1).set_held(&"left", true)
	step(m, 2)
	assert_eq(facings, [-1], "facing_changed once")
	assert_eq(g.scale, Vector2.ONE, "body never flipped")
	var visual := g.get_node("VisualRoot") as Node2D
	assert_true(visual != null, "VisualRoot child exists")
	assert_eq(visual.scale.x, -1.0, "placeholder flips only the VisualRoot")
	var hurt_left := g.get_hurtbox_world()
	assert_eq(hurt_left.size, hurt_right.size, "hurtbox size unchanged by facing")
	visual.scale = Vector2(-3, 3)  # art scale/offset must not affect gameplay geometry
	visual.position = Vector2(50, -20)
	assert_eq(g.get_hurtbox_world(), hurt_left, "hurtbox independent of VisualRoot transform")


func test_effect_payloads_are_plain_values() -> void:
	var m: MatchController = await make_match()
	face_off(m)
	var payloads := []
	for f in m.fighters:
		f.effect_requested.connect(func(id: StringName, pos: Vector2, dir: Vector2, payload: Dictionary) -> void:
			payloads.append([id, pos, dir, payload]))
	p(m, 1).tap(&"light")
	step(m, 10)
	assert_true(payloads.size() >= 2, "swing + hit effects")
	for e in payloads:
		assert_true(GameIds.EFFECT_IDS.has(e[0]), "registered effect id %s" % e[0])
		for value in e[3].values():
			assert_true(typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_BOOL],
				"payload value %s is plain data" % str(value))
		assert_true(e[3].has("player_id"), "payload has player_id")


func test_placeholder_tolerates_unknown_animation_ids() -> void:
	var m: MatchController = await make_match()
	var g := m.get_fighter(1)
	var visual := g.get_node("VisualRoot") as PlaceholderFighterVisual
	assert_true(visual != null, "placeholder adapter attached when no visual_scene is set")
	g.animation_requested.emit(&"not_a_real_animation", 10, false)
	g.animation_requested.emit(&"not_a_real_animation", 10, false)
	assert_eq(visual._warned.size(), 1, "unknown id warned exactly once")
	g.animation_requested.emit(&"staff_strike", 21, false)
	assert_eq(visual._warned.size(), 1, "known ids never warn")
	step(m, 5)  # still draws/updates without errors
