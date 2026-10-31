extends SceneTree
## Fresh-process check of the load-order trap fixed in GameApp: a script that
## names GameApp before any character data is loaded must still get roster
## characters that are real CharacterData (this failed for Gandalf/Elon when
## GameApp preloaded the match scene).   exit 0 = OK

var app: GameApp


func _initialize() -> void:
	app = GameApp.new(GameSettings.new("user://boot_check_typed.cfg"))
	root.add_child(app)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var bad := PackedStringArray()
	for id: StringName in CharacterRoster.ids():
		if CharacterRoster.load_character(id) == null:
			bad.append(String(id))
	print("typed boot check: %s %s" % ["OK" if bad.is_empty() else "FAILED", bad])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://boot_check_typed.cfg"))
	quit(0 if bad.is_empty() else 1)
