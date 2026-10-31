extends SceneTree
## Deterministic presentation screenshots, with a real rendered viewport.
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
    await shot("01_arena")
    m.inputs[0].tap(&"special_1")
    ticks(23)
    await shot("02_lightning")
    reset()
    m.inputs[0].tap(&"special_2")
    ticks(22)
    await shot("03_fireball")
    reset()
    m.inputs[1].tap(&"special_3")
    ticks(6)
    await shot("04_guard")
    reset()
    var v := m.get_fighter(2)
    v.position.x = 630
    m.inputs[0].tap(&"heavy")
    ticks(21)
    await shot("05_impact")
    reset()
    m.inputs[1].tap(&"special_2")
    m.get_fighter(1).position.x = 640
    ticks(16)
    await shot("06_choke")
    quit()

func reset() -> void:
    m.rematch()
    ticks(100)
    m.get_fighter(1).position = Vector2(540, 546)
    m.get_fighter(2).position = Vector2(800, 546)
    m.get_fighter(1).set_facing(1)
    m.get_fighter(2).set_facing(-1)

func ticks(count: int) -> void:
    for i in count:
        m.step()
        var effects := main.get_node("Effects")
        effects._process(1.0 / 60.0)
        for entry: Dictionary in effects._active_visuals:
            if is_instance_valid(entry.node) and not entry.node.is_queued_for_deletion():
                entry.node._process(1.0 / 60.0)

func shot(label: String) -> void:
    # Screenshot encoding can take longer than a short effect's lifespan.
    # Freeze rendered effects at the manually stepped tick for the capture.
    for entry: Dictionary in main.get_node("Effects")._active_visuals:
        if is_instance_valid(entry.node):
            entry.node.set_process(false)
    for fighter in m.fighters:
        fighter.visual_root._process(0.0)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
    assert(error == OK)
    print("Captured ", label)
