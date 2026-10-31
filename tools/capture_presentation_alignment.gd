extends SceneTree
## Render both heavy contact windows through the real match and debug overlay.
var main: Node
var match_controller: MatchController
var output: String

func _initialize() -> void:
    output = OS.get_cmdline_user_args()[0]
    DirAccess.make_dir_recursive_absolute(output)
    _run.call_deferred()

func _run() -> void:
    root.size = Vector2i(1280, 720)
    main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    match_controller = main.get_node("Match")
    match_controller.auto_step = false
    for input in match_controller.inputs:
        input.scripted = true
    for i in range(100):
        match_controller.step()
    main.get_node("DebugOverlay").visible = true
    var fighter := match_controller.get_fighter(1)
    var opponent := match_controller.get_fighter(2)
    for facing in [1, -1]:
        fighter.position = Vector2(640, 546)
        opponent.position = Vector2(1000, 546)
        fighter.set_facing(facing)
        match_controller.inputs[0].tap(&"heavy")
        for i in range(49):
            match_controller.step()
            var snap := fighter.get_presentation_snapshot()
            if snap.current_move_id == &"heavy" and snap.move_tick in [16, 19, 35]:
                fighter.visual_root._process(0.0)
                await process_frame
                await RenderingServer.frame_post_draw
                var path := output.path_join("heavy_%d_tick_%d.png" % [facing, snap.move_tick])
                root.get_texture().get_image().save_png(path)
                print(path)
    quit()
