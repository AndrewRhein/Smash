extends "res://tests/test_case.gd"
## Up to four players (ports kept), CPU opponents, and the dynamic select screen.


func _match_with(ids: Array, ports: Array, cpus: Dictionary = {}, stocks: int = 2) -> MatchController:
	var stage := Stage.new()
	tree.root.add_child(stage)
	var m := MatchController.new()
	m.auto_step = false
	m.countdown_ticks = 0
	m.stock_count = stocks
	tree.root.add_child(m)
	_nodes.append_array([m, stage])
	var chars: Array[CharacterData] = []
	var inputs: Array[PlayerInput] = []
	for i in ids.size():
		chars.append(CharacterRoster.load_character(ids[i]))
		var port: int = ports[i]
		inputs.append(CpuInput.new(port, cpus[port]) if cpus.has(port) else PlayerInput.new(port, true))
	assert_true(m.setup(stage, chars, inputs), "setup")
	for player_input in inputs:
		if player_input is CpuInput:
			player_input.bind(m)
	m.start_match()
	await tree.physics_frame
	await tree.physics_frame
	return m


func test_four_fighters_spawn_apart_and_last_one_wins() -> void:
	var m := await _match_with([&"gandalf", &"elon", &"leo", &"tim"], [1, 2, 3, 4])
	assert_eq(m.fighters.size(), 4, "four fighters")
	var spots := {}
	for f in m.fighters:
		spots[f.position] = true
		assert_true(f.is_in_play(), "P%d in play" % f.player_id)
	assert_eq(spots.size(), 4, "four different spawn points")
	for pid in [1, 2, 4]:
		var f := m.get_fighter(pid)
		f.stocks = 1
		f.blast_ko()
	step(m)
	assert_eq(m.state, MatchController.MatchState.RESULT, "match ends with one survivor")
	assert_eq(m.winner_player_id, 3, "P3 wins")


func test_ports_are_kept() -> void:
	var m := await _match_with([&"gandalf", &"kevin"], [1, 3])
	assert_true(m.get_fighter(3) != null and m.get_fighter(2) == null, "P3 stays P3 (own controller and colour)")
	assert_eq(m.get_fighter(3).position, Stage.new().spawn_point(3), "P3 spawn point")


func test_cpu_attacks_a_standing_opponent() -> void:
	var m := await _match_with([&"gandalf", &"tim"], [1, 2], {2: 5}, 3)
	var dummy := m.get_fighter(1)
	for i in 60 * 20:
		step(m)
		if dummy.damage > 0.0:
			break
	assert_true(dummy.damage > 0.0, "the CPU walks over and lands hits")


func test_cpu_recovers_to_the_stage() -> void:
	var m := await _match_with([&"gandalf", &"leo"], [1, 2], {2: 7}, 3)
	var cpu := m.get_fighter(2)
	place(m.get_fighter(1), 500, 1)
	place(cpu, 1060, -1, 520)
	cpu.grounded = false
	cpu.air_jumps_left = 1
	var safe := false
	for i in 60 * 4:
		step(m)
		if cpu.state == Fighter.State.LEDGE or (cpu.grounded and cpu.position.x < 940.0):
			safe = true
			break
	assert_true(safe, "the CPU makes it back (ledge or stage)")
	assert_eq(cpu.stocks, 3, "without losing a stock")


func test_higher_level_cpu_reacts_faster() -> void:
	assert_true(CpuInput.new(1, 9).reaction_ticks() < CpuInput.new(1, 1).reaction_ticks(), "level 9 decides faster than level 1")


func test_select_screen_join_cpu_and_start() -> void:
	ControllerAssignment.reset(true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_four_players.cfg"))
	var app := GameApp.new(GameSettings.new("user://test_four_players.cfg"))
	tree.root.add_child(app)
	_nodes.append(app)
	await tree.process_frame
	await tree.process_frame
	app.show_character_select()
	await tree.process_frame
	var screen := app._screen as CharacterSelectScreen
	assert_eq(screen.active_slots(), [1], "only P1 starts in")
	assert_true(not screen.can_start(), "can't start alone")
	screen.join(3)
	var cpu := screen.add_cpu(1)
	assert_eq(cpu, 2, "a CPU fills the first free slot")
	assert_eq(screen.carrying.get(1), 2, "P1 holds the CPU's cursor")
	screen.set_cpu_level(2, 8)
	screen.cursor[2] = screen.options.find(&"kevin")
	screen.set_ready(2, true)
	screen.carrying.erase(1)
	screen.set_ready(1, true)
	assert_true(not screen.can_start(), "P3 joined but isn't ready")
	screen.set_ready(3, true)
	assert_true(screen.can_start(), "everyone ready")
	screen.confirm()
	await tree.process_frame
	var m := app.match_controller
	assert_eq(m.fighters.size(), 3, "three fighters")
	assert_true(m.get_fighter(2).input is CpuInput, "P2 is a CPU")
	assert_eq((m.get_fighter(2).input as CpuInput).level, 8, "with the chosen level")
	assert_eq(m.get_fighter(2).character.id, &"kevin", "playing the CPU's pick")
	assert_true(not (m.get_fighter(3).input is CpuInput), "P3 is human")
	assert_eq(app.lineup.size(), 3, "lineup remembered for the next visit")
	tree.paused = false
	ControllerAssignment.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_four_players.cfg"))


func test_practice_button_adds_a_cpu_opponent() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_four_players.cfg"))
	var app := GameApp.new(GameSettings.new("user://test_four_players.cfg"))
	tree.root.add_child(app)
	_nodes.append(app)
	await tree.process_frame
	app.show_practice_select()
	await tree.process_frame
	var screen := app._screen as CharacterSelectScreen
	assert_eq(screen.active_slots(), [1, 2], "P1 and a CPU")
	assert_true(screen.is_cpu(2), "P2 is a CPU")
	assert_true(screen.is_ready[2], "the CPU is ready on its last pick")
	screen.set_ready(1, true)
	assert_true(screen.can_start(), "P1 locks in and the practice match can start")
	assert_eq(screen.cycle_cpu(1), 2, "Shield grabs the existing CPU first")
	assert_eq(screen.cycle_cpu(1), 3, "again: adds a second CPU")
	assert_eq(screen.cycle_cpu(1), 4, "again: a third")
	assert_eq(screen.cycle_cpu(1), 2, "full: wraps to the first CPU")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_four_players.cfg"))
