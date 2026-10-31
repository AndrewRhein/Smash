extends SceneTree
## Visual check (not pass/fail): plays the real main scene with scripted input
## and saves PNG frames of key moments (moves, effects, choke, guard, KO, result,
## rematch). Needs a display or Xvfb and a GL renderer, e.g.:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tests/capture_frames.gd -- /tmp/frames
var main: Node
var m: MatchController
var out_dir := "user://frames"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	m = main.get_node("Match")
	_run.call_deferred()

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out_dir).path_join(name + ".png"))
	print("shot ", name, " tick=", m.tick, " state=", m.state)

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	for pi in m.inputs:
		pi.scripted = true
	var p1: PlayerInput = m.inputs[0]
	var p2: PlayerInput = m.inputs[1]
	await ticks(20)
	await shot("01_countdown")
	await ticks(80)
	await shot("02_fight")
	var g := m.get_fighter(1); var v := m.get_fighter(2)
	# Walk toward each other
	p1.set_held(&"right", true); p2.set_held(&"left", true)
	await ticks(35)
	p1.set_held(&"right", false); p2.set_held(&"left", false)
	await ticks(10)
	g.position.x = 590; v.position.x = 690
	await ticks(2)
	p1.tap(&"heavy")
	await ticks(18)
	await shot("03_heavy_hit")
	main.get_node("DebugOverlay").toggle()
	await ticks(40)
	g.position = Vector2(520, 546); v.position = Vector2(820, 546); g.set_facing(1); v.set_facing(-1)
	await ticks(3)
	p1.tap(&"special_1")
	await ticks(10)
	await shot("04_lightning_telegraph_debug")
	await ticks(12)
	await shot("05_lightning_bolt_debug")
	await ticks(60)
	g.position = Vector2(420, 546); v.position = Vector2(860, 546); g.set_facing(1); v.set_facing(-1)
	await ticks(3)
	p1.tap(&"special_2")
	await ticks(25)
	await shot("06_fireball_debug")
	await ticks(60)
	main.get_node("DebugOverlay").toggle()
	g.position = Vector2(650, 546); v.position = Vector2(760, 546); g.set_facing(1); v.set_facing(-1); v.cooldowns.clear()
	await ticks(3)
	p2.tap(&"special_2")
	await ticks(30)
	await shot("07_force_choke")
	await ticks(60)
	await shot("08_choke_release")
	await ticks(60)
	g.position = Vector2(600, 546); v.position = Vector2(700, 546); g.set_facing(1); v.set_facing(-1)
	v.cooldowns.clear(); g.cooldowns.clear()
	await ticks(3)
	p2.tap(&"special_3")
	await ticks(4)
	p1.tap(&"special_3")
	await ticks(10)
	await shot("09_guard_vs_push")
	await ticks(40)
	g.damage = 150.0
	g.position = Vector2(600, 546); v.position = Vector2(680, 546); g.set_facing(1); v.set_facing(-1)
	g.invulnerable_remaining = 0
	await ticks(3)
	p2.tap(&"heavy")
	await ticks(40)
	await shot("10_launch")
	await ticks(80)
	await shot("11_after_ko")
	await ticks(60)
	g.stocks = 1; g.damage = 200
	g.position = Vector2(640, 3000)
	await ticks(10)
	await shot("12_result")
	m.rematch()
	await ticks(20)
	await shot("13_rematch_countdown")
	quit(0)
