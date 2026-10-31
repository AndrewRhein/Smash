extends "res://tests/test_case.gd"
const ELON = preload("res://data/characters/elon.tres")
const Setup = preload("res://scripts/presentation/presentation_setup.gd")
const Visual = preload("res://scripts/presentation/character_visual.gd")
const Effects = preload("res://scripts/presentation/integrated_effects.gd")
const Tech = preload("res://scripts/presentation/tech_effect.gd")

func _elon_match() -> MatchController:
    var m: MatchController = await make_match()
    m.characters[1] = Setup.with_art(ELON)
    m.rematch()
    await tree.physics_frame
    await tree.physics_frame
    return m

func test_elon_data_and_complete_visual_contract() -> void:
    assert_true(ELON.validate().is_empty(), "new kit validates")
    assert_eq(ELON.id, &"elon", "own identity")
    var frames: SpriteFrames = load("res://art/characters/elon/animations.tres")
    for id in GameIds.SHARED_ANIMATION_IDS + GameIds.MOVE_ANIMATION_IDS[&"elon"]:
        assert_true(frames.has_animation(id), "authored state %s" % id)
        assert_true(frames.get_frame_count(id) > 0, "nonempty state %s" % id)
    assert_true(ELON.visual_scene == null, "art wiring leaves original data unchanged")
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/elon/manifest.json"))
    assert_eq(FileAccess.get_sha256("res://art/characters/elon/atlas.png"), manifest.atlas_sha256, "atlas matches recorded source build")

func test_elon_is_live_roster_and_hud_survives_rematch() -> void:
    var main: Node = load("res://scenes/main.tscn").instantiate()
    tree.root.add_child(main)
    _nodes.append(main)
    var m: MatchController = main.get_node("Match")
    m.auto_step = false
    assert_eq(m.get_fighter(2).character.id, &"elon", "live P2 is Elon")
    assert_eq(m.get_fighter(2).visual_root.get_script(), Visual, "real sprite adapter, not placeholder")
    assert_eq(main.get_node("HUD").name_labels[2].text, "P2  /  ELON MUSK", "HUD reflects character resource")
    var old_id := m.get_fighter(2).visual_root.get_instance_id()
    m.rematch()
    assert_true(old_id != m.get_fighter(2).visual_root.get_instance_id(), "rematch builds new actor")
    assert_eq(main.get_node("HUD").name_labels[2].text, "P2  /  ELON MUSK", "HUD rebinds")

func test_elon_all_abilities_follow_phase_and_hitstop() -> void:
    var m: MatchController = await _elon_match()
    for slot: StringName in GameIds.MOVE_SLOTS:
        m.rematch()
        var e := m.get_fighter(2)
        place(m.get_fighter(1), 350, 1)
        place(e, 800, 1)
        var move := e.character.get_move(slot)
        p(m, 2).tap(slot)
        for i in range(move.total_ticks() + 2):
            step(m)
            e.visual_root._process(0.0)
            if e.move == null:
                continue
            var phase := 0 if e.move_tick < move.startup_ticks else (1 if move.is_active_tick(e.move_tick) else 2)
            var expected := [[0, 1, 2], [3, 4], [5, 6, 7]]
            if slot == &"heavy":
                expected = [[0, 1, 2, 3], [4], [5, 6, 7]]
            elif slot == &"special_3":
                expected = [[0, 1], [2, 3, 4], [5, 6, 7]]
            assert_true(e.visual_root.sprite.frame in expected[phase], "%s follows gameplay phase" % slot)
        assert_true(e.visual_root.warned.is_empty(), "no missing animations")
    p(m, 2).tap(&"heavy")
    step(m, 5)
    var e := m.get_fighter(2)
    e.visual_root._process(0.0)
    var before: int = e.visual_root.sprite.frame
    e.hitstop_remaining = 5
    step(m, 3)
    e.visual_root._process(0.2)
    assert_eq(e.visual_root.sprite.frame, before, "hitstop freezes Elon pose")

func test_elon_strikes_damage_once_at_contact() -> void:
    var m: MatchController = await _elon_match()
    for slot: StringName in [&"light", &"heavy", &"special_1"]:
        m.rematch()
        face_off(m, 60)
        var move := m.get_fighter(2).character.get_move(slot)
        p(m, 2).tap(slot)
        step(m, move.startup_ticks)
        assert_eq(m.get_fighter(1).damage, 0.0, "%s cannot hit in startup" % slot)
        step(m, move.active_ticks + 15)
        assert_eq(m.get_fighter(1).damage, move.damage, "%s delivers one hit" % slot)

func test_elon_tractor_holds_launches_and_clears_tech_effects() -> void:
    var m: MatchController = await _elon_match()
    var effects = Effects.new()
    tree.root.add_child(effects)
    _nodes.append(effects)
    effects.bind(m)
    m.rematch()
    face_off(m, 110)
    var g := m.get_fighter(1)
    p(m, 2).tap(&"special_2")
    step(m, 14)
    assert_eq(g.state, Fighter.State.HELD, "tractor locks target")
    var target_effects := 0
    for entry: Dictionary in effects._active_visuals:
        if entry.victim_id > 0:
            target_effects += 1
            assert_eq(entry.node.get_script(), Tech, "shared grab event selects tech renderer")
            assert_eq(entry.node.effect_id, &"orbital_tractor", "no Force-choke art for Elon")
    assert_eq(target_effects, 1, "one attached target lock")
    step(m, 80)
    assert_true(g.state != Fighter.State.HELD, "hold is bounded")
    assert_true(g.damage > 4, "tractor applies pulses and release damage")
    assert_true(g.held_by == null and m.get_fighter(2).held_target == null, "hold links clear")
    m.rematch()
    assert_eq(effects._active_visuals.size(), 0, "no stale effects on rematch")

func test_elon_shield_blocks_front_projectiles_but_not_melee() -> void:
    var m: MatchController = await _elon_match()
    face_off(m, 60)
    var e := m.get_fighter(2)
    var g := m.get_fighter(1)
    p(m, 2).tap(&"special_3")
    step(m, 5)
    var fireball := g.character.get_move(&"special_2")
    m._on_projectile_requested(g, fireball, fireball.projectiles[0])
    step(m, 3)
    assert_eq(e.damage, 0.0, "front projectile blocked")
    assert_eq(m.projectiles.size(), 0, "blocked projectile consumed")
    m.rematch()
    face_off(m, 60)
    p(m, 2).tap(&"special_3")
    step(m, 2)
    p(m, 1).tap(&"light")
    step(m, 9)
    assert_eq(m.get_fighter(2).damage, 5.0, "melee bypasses shield")

func test_elon_aim_and_mirroring_are_visual_only() -> void:
    var m: MatchController = await _elon_match()
    face_off(m, 400)
    var e := m.get_fighter(2)
    p(m, 2).set_held(&"up", true)
    p(m, 2).tap(&"special_1")
    step(m)
    p(m, 2).set_held(&"up", false)
    step(m, 12)
    e.visual_root._process(0.0)
    assert_eq(e.scale, Vector2.ONE, "physics actor is never flipped")
    assert_eq(e.visual_root.scale.x, -1.0, "sprite faces left")
    var far: Dictionary = e.get_active_hitboxes()[-1]
    assert_true(far.center.x < e.position.x and far.center.y < e.position.y - 60, "aimed thruster goes up and left")

func test_elon_expanded_pack_bounds_and_coverage() -> void:
    var scene: Node = load("res://scenes/presentation/elon_visual.tscn").instantiate()
    var frames: SpriteFrames = scene.frames
    assert_eq(frames.get_animation_names().size(), 16, "full pack plus entrance and landing")
    assert_eq(frames.get_frame_count(&"run"), 8, "eight run poses")
    assert_eq(frames.get_frame_count(&"jump"), 4, "clipped launch frames excluded")
    for id in GameIds.MOVE_ANIMATION_IDS[&"elon"]:
        assert_eq(frames.get_frame_count(id), 8, "eight attack poses")
    var base := "res://art/characters/elon/expanded/"
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "manifest.json"))
    assert_eq(FileAccess.get_sha256(base + "atlas.png"), manifest.atlas_sha256, "new atlas checksum")
    for record: Dictionary in manifest.frames:
        assert_true(record.offset[0] > 0 and record.offset[1] > 0, "leading padding")
        assert_true(record.offset[0] + record.size[0] < 256 and record.offset[1] + record.size[1] < 256, "trailing padding")
    scene.free()

func test_elon_entrance_landing_and_interrupts() -> void:
    var m: MatchController = await _elon_match()
    var e := m.get_fighter(2)
    var v = e.visual_root
    place(e, 800, 1)
    m.state = MatchController.MatchState.COUNTDOWN
    m.countdown_ticks = 90
    m.countdown_remaining = 60
    v._process(0.0)
    assert_eq(v.sprite.animation, &"entrance", "prep plays during countdown")
    assert_true(v.sprite.frame > 0, "countdown advances entrance")
    m.state = MatchController.MatchState.PLAYING
    v._process(0.0)
    assert_eq(v.sprite.animation, v.active_id, "gameplay immediately owns visuals after countdown")
    e.grounded = false
    v._process(0.0)
    e.grounded = true
    e.state = Fighter.State.IDLE
    v.animation_requested(&"idle", 0, true)
    v._process(0.08)
    assert_eq(v.sprite.animation, &"land", "landing overlay starts")
    var held_frame: int = v.sprite.frame
    e.hitstop_remaining = 4
    v._process(0.5)
    assert_eq(v.sprite.frame, held_frame, "landing freezes in hitstop")
    e.hitstop_remaining = 0
    p(m, 2).tap(&"light")
    step(m)
    v._process(0.0)
    assert_eq(v.sprite.animation, &"ion_jab", "attack cancels cosmetic landing without input delay")
    assert_eq(e.move.id, &"light", "landing adds no gameplay lag")
