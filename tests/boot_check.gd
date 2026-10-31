extends SceneTree
## Fresh-process boot check (run by test_menus via OS.execute). The in-process
## test runner has every script preloaded, which hides load-order bugs such as
## character data bound to a half-compiled script. This script deliberately
## names NO game classes, so scripts load in the same order as a real launch:
## it opens the real app, goes through the character select with every roster
## character for Player 1, and checks each match starts with that character.
##   godot --headless --path . -s res://tests/boot_check.gd   -> exit 0 = OK

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var errors := PackedStringArray()
	app.call("show_character_select")
	await process_frame
	var options: Array = app.get("_screen").get("options")
	for i in options.size() - 1:  # every fighter (last option is Random)
		app.call("show_character_select")
		await process_frame
		var screen = app.get("_screen")
		screen.get("cursor")[1] = i
		screen.call("set_ready", 1, true)
		screen.call("set_ready", 2, true)
		screen.call("confirm")
		await process_frame
		var m = app.get("match_controller")
		var fighter = m.call("get_fighter", 1) if m != null else null
		if fighter == null or fighter.get("character") == null or fighter.get("character").get("id") != options[i]:
			errors.append("%s: match did not start with this character" % options[i])
	app.call("show_title")
	await process_frame
	for e in errors:
		printerr("BOOT CHECK: ", e)
	print("boot check: %s (%d fighters)" % ["OK" if errors.is_empty() else "FAILED", options.size() - 1])
	quit(0 if errors.is_empty() else 1)
