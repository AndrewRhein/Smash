extends SceneTree
## Actual match captures for the replacement character, plus title/result.
var main: Node
var m: MatchController
var output: String

func _initialize() -> void:
    output = OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(output)
    _run.call_deferred()

func _run() -> void:
    root.size = Vector2i(1280, 720)
    main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    m = main.get_node("Match")
    m.auto_step = false
    for input in m.inputs:
        input.scripted = true
    reset()
    await shot("01_match")
    var moves := [&"light", &"heavy", &"special_1", &"special_2", &"special_3"]
    for slot: StringName in moves:
        reset()
        if slot == &"special_2":
            m.get_fighter(1).position.x = 650
        var move := m.get_fighter(2).character.get_move(slot)
        m.inputs[1].tap(slot)
        ticks(move.startup_ticks + 2)
        await shot(str(slot))
        main.get_node("DebugOverlay").visible = true
        await shot(str(slot) + "_hitboxes")
    reset()
    m.get_fighter(2).set_facing(1)
    m.inputs[1].tap(&"heavy")
    ticks(22)
    main.get_node("DebugOverlay").visible = true
    await shot("heavy_right_hitboxes")
    reset()
    m.get_fighter(1).stocks = 1
    m.get_fighter(1).position = Vector2(640, 3000)
    ticks(2)
    await shot("victory")
    root.remove_child(main)
    main.queue_free()
    var app: Node = load("res://scenes/app.tscn").instantiate()
    root.add_child(app)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join("title.png"))
    print("Captured title")
    app.show_controls(app.show_title)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(output.path_join("controls.png"))
    print("Captured controls")
    quit()

func reset() -> void:
    m.rematch()
    ticks(100)
    main.get_node("DebugOverlay").visible = false
    var g := m.get_fighter(1)
    var e := m.get_fighter(2)
    g.position = Vector2(500, 546)
    e.position = Vector2(760, 546)
    g.velocity = Vector2.ZERO
    e.velocity = Vector2.ZERO
    g.set_facing(1)
    e.set_facing(-1)

func ticks(count: int) -> void:
    for i in count:
        m.step()
        var effects := main.get_node("Effects")
        effects._process(1.0 / 60.0)
        for entry: Dictionary in effects._active_visuals:
            if is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion():
                entry.node._process(1.0 / 60.0)

func shot(label: String) -> void:
    for fighter in m.fighters:
        fighter.visual_root._process(0.0)
    for entry: Dictionary in main.get_node("Effects")._active_visuals:
        if is_instance_valid(entry.node):
            entry.node.set_process(false)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
    print("Captured ", label)
