extends SceneTree
## Dependency-free headless test runner.
##   godot --headless --path . --import
##   godot --headless --path . -s res://tests/run_tests.gd
## Optional filter: append `-- <substring>` to run matching tests only.
## Exit code 0 = all passed, 1 = failures.

const SUITES := [
	"res://tests/test_data.gd",
	"res://tests/test_menus.gd",
	"res://tests/test_input.gd",
	"res://tests/test_movement.gd",
	"res://tests/test_smash_controls.gd",
	"res://tests/test_audio.gd",
	"res://tests/test_leo.gd",
	"res://tests/test_sprite_characters.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_specials.gd",
	"res://tests/test_match.gd",
	"res://tests/test_presentation.gd",
	"res://tests/test_smoke.gd",
	"res://tests/test_visual_integration.gd",
	"res://tests/test_elon.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InputSetup.ensure_actions()
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	var passed := 0
	var failed: PackedStringArray = []
	for path: String in SUITES:
		var script: GDScript = load(path)
		for method: Dictionary in script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_") or (filter != "" and not test_name.contains(filter)):
				continue
			var suite: RefCounted = script.new()
			suite.tree = self
			await suite.call(test_name)
			suite.cleanup()
			await process_frame
			var label := "%s::%s" % [path.get_file().get_basename(), test_name]
			if suite.failures.is_empty():
				passed += 1
				print("  PASS  ", label)
			else:
				failed.append(label)
				print("  FAIL  ", label)
				for f in suite.failures:
					print("        - ", f)
	print("\n%d passed, %d failed" % [passed, failed.size()])
	quit(0 if failed.is_empty() and passed > 0 else 1)
