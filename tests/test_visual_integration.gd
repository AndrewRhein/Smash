extends "res://tests/test_case.gd"
const Setup = preload("res://scripts/presentation/presentation_setup.gd")
const Visual = preload("res://scripts/presentation/character_visual.gd")
const Effects = preload("res://scripts/presentation/integrated_effects.gd")

func _art_match() -> MatchController:
    var match_controller: MatchController = await make_match()
    match_controller.characters[0] = Setup.with_art(match_controller.characters[0])
    match_controller.rematch()
    await tree.physics_frame
    await tree.physics_frame
    return match_controller

func test_art_configuration_does_not_mutate_gameplay_resources() -> void:
    var original := GANDALF
    var rendered := Setup.with_art(original)
    assert_true(original.visual_scene == null, "base fixture remains a placeholder")
    assert_true(rendered.visual_scene != null, "art scene registered on clone")
    assert_eq(rendered.hurtbox, original.hurtbox, "collision unchanged")
    for i in range(original.moves.size()):
        assert_eq(rendered.moves[i].total_ticks(), original.moves[i].total_ticks(), "move timing unchanged")
        assert_eq(rendered.moves[i].damage, original.moves[i].damage, "damage unchanged")
    assert_true(original.get_move(&"special_2").projectiles[0].visual_scene == null, "projectile source not mutated")
    assert_true(rendered.get_move(&"special_2").projectiles[0].visual_scene != null, "projectile art registered")

func test_art_auto_attaches_and_survives_rematch() -> void:
    var m: MatchController = await _art_match()
    var first = m.get_fighter(1).visual_root
    assert_true(first.get_script() == Visual, "final-art adapter replaces Gandalf placeholder")
    assert_eq(first.active_id, m.get_fighter(1).animation_id, "snapshot synchronized on attach")
    assert_true(m.get_fighter(2).visual_root is PlaceholderFighterVisual, "Vader remains honest placeholder")
    var first_id: int = first.get_instance_id()
    m.rematch()
    assert_true(m.get_fighter(1).visual_root.get_instance_id() != first_id, "new visual created on rematch")

func test_art_contact_frame_matches_active_ticks() -> void:
    var m: MatchController = await _art_match()
    face_off(m, 400)
    var g := m.get_fighter(1)
    var visual = g.visual_root
    p(m, 1).tap(&"light")
    for i in range(24):
        step(m)
        visual._process(0.0)
        if g.move == null:
            continue
        if g.move_tick < g.move.startup_ticks:
            assert_true(visual.sprite.frame < 3, "startup uses windup poses")
        elif g.move_tick < g.move.startup_ticks + g.move.active_ticks:
            assert_eq(visual.sprite.frame, 3, "contact pose appears during active window")
        else:
            assert_true(visual.sprite.frame >= 4, "recovery uses return poses")

func test_art_hitstop_flash_and_victory_clock() -> void:
    var m: MatchController = await _art_match()
    var g := m.get_fighter(1)
    var visual = g.visual_root
    g.hitstop_remaining = 5
    visual._process(0.0)
    var frame: int = visual.sprite.frame
    step(m, 3)
    visual._process(0.2)
    assert_eq(visual.sprite.frame, frame, "hitstop freezes the animation clock")
    g.invulnerable_remaining = 120
    visual._process(0.0)
    assert_near(visual.modulate.a, 0.45, 0.001, "respawn flash is visible")
    g.hitstop_remaining = 0
    g.set_victory()
    visual._process(0.4)
    assert_true(visual.sprite.frame > 0, "victory progresses when gameplay no longer ticks")

func test_art_effect_registry_covers_every_gameplay_id() -> void:
    for id in GameIds.EFFECT_IDS:
        assert_true(Effects.MAP.has(id), "mapping exists for %s" % id)

func test_heavy_contact_poses_follow_both_hitbox_windows() -> void:
    var m: MatchController = await _art_match()
    face_off(m, 400)
    var g := m.get_fighter(1)
    p(m, 1).tap(&"heavy")
    for i in range(49):
        step(m)
        g.visual_root._process(0.0)
        var snap := g.get_presentation_snapshot()
        if snap.current_move_id != &"heavy":
            continue
        var tick: int = snap.move_tick
        if tick >= 16 and tick <= 21:
            assert_eq(g.visual_root.sprite.frame, 2 if tick < 19 else 3, "high contact precedes extended low contact")
            assert_eq(g.get_active_hitboxes().size(), 1, "contact pose has an authoritative hitbox")

func test_cast_flash_and_lightning_extent() -> void:
    var m: MatchController = await _art_match()
    var effects = Effects.new()
    tree.root.add_child(effects)
    _nodes.append(effects)
    effects.bind(m)
    effects._on_effect_requested(&"fireball_cast", Vector2.ZERO, Vector2.RIGHT, {"player_id": 1})
    var flash = effects._active_visuals[-1].node
    assert_eq(flash.effect_id, &"cast_flash", "cast is distinct from projectile art")
    assert_near(flash.duration, 5.0 / 60.0, 0.001, "cast flash lasts five ticks")
    for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.RIGHT.rotated(deg_to_rad(-28.0))]:
        effects._on_effect_requested(&"lightning_bolt", Vector2(30, -55), direction, {"player_id": 1})
        var bolt = effects._active_visuals[-1].node
        assert_near(bolt.length, 197.0, 0.001, "bolt reach measured from hand")
        assert_near(bolt.rotation, direction.angle(), 0.001, "bolt respects facing and aim")

func test_art_effects_clear_on_rematch() -> void:
    var m: MatchController = await _art_match()
    var effects = Effects.new()
    tree.root.add_child(effects)
    _nodes.append(effects)
    effects.bind(m)
    m.rematch()
    m.get_fighter(1).request_effect(&"lightning_telegraph", Vector2.ZERO, Vector2.RIGHT, {"duration_ticks": 20})
    assert_eq(effects._active_visuals.size(), 1, "new fighter signal connected")
    m.rematch()
    assert_eq(effects._active_visuals.size(), 0, "rematch clears active effects")
