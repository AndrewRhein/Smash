class_name GameApp
extends Node
## Application shell and entry scene (scenes/app.tscn):
##   Title -> Match -> (Pause | Result) -> Title.
## It instantiates scenes/main.tscn UNCHANGED for each match and only talks to
## its MatchController through public API, so gameplay and the presentation
## wiring inside main.tscn stay independent of the menus.

signal screen_changed(screen: StringName)

## Loaded on first use, NOT preloaded: preloading at parse time pulled the
## character .tres files in while CharacterData was still compiling, which left
## Gandalf/Elon attached to a half-loaded script (`is CharacterData` false).
const MATCH_SCENE_PATH := "res://scenes/main.tscn"
## Optional art-review scene from the art pipeline; the menu entry is hidden
## when it does not exist on this branch.
const ART_GALLERY_SCENE := "res://scenes/art_preview.tscn"

var settings: GameSettings
var current_screen: StringName = &""
var match_root: Node
var match_controller: MatchController
var pause_menu: PauseMenu
var result_overlay: ResultOverlay
var gallery_root: Node
var _gallery_bar: CanvasLayer
var _menu_layer: CanvasLayer
var audio: AudioDirector
var _screen: MenuScreen


func _init(p_settings: GameSettings = null) -> void:
	settings = p_settings if p_settings != null else GameSettings.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure_actions()
	settings.load_from_disk()
	settings.apply_window()
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	settings.apply_audio()
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void:
		if current_screen != &"match" or is_paused():
			audio.play_ui("move"))
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "Menus"
	_menu_layer.layer = 20
	add_child(_menu_layer)
	show_title()


# --- Menu screens -------------------------------------------------------------
func show_title() -> void:
	_end_match()
	_end_gallery()
	_show_screen(TitleScreen.new(self), &"title")


func show_character_select() -> void:
	_end_match()
	_end_gallery()
	_show_screen(CharacterSelectScreen.new(self), &"character_select")


func show_settings() -> void:
	_show_screen(SettingsScreen.new(self), &"settings")


func show_controllers() -> void:
	_show_screen(ControllersScreen.new(self, show_settings), &"controllers")


func show_controls(back: Callable) -> void:
	_show_screen(ControlsScreen.new(self, back), &"controls")


func _show_screen(screen: MenuScreen, id: StringName) -> void:
	_clear_screen()
	if audio != null:
		audio.play_music("menu")
	_screen = screen
	_menu_layer.add_child(screen)
	_set_screen(id)


func _clear_screen() -> void:
	if _screen != null:
		_menu_layer.remove_child(_screen)
		_screen.queue_free()
		_screen = null


func _set_screen(id: StringName) -> void:
	current_screen = id
	screen_changed.emit(id)


static func has_art_gallery() -> bool:
	return ResourceLoader.exists(ART_GALLERY_SCENE)


## Shows the art pipeline's preview scene (all character animations and
## effects, no combat) with a Back button; Esc also returns to the title.
func show_art_gallery() -> void:
	if not has_art_gallery():
		return
	_clear_screen()
	_end_match()
	_end_gallery()
	gallery_root = (load(ART_GALLERY_SCENE) as PackedScene).instantiate()
	add_child(gallery_root)
	_gallery_bar = CanvasLayer.new()
	_gallery_bar.layer = 40
	var back := MenuStyle.button("◀ Back to Menu (Esc)", show_title, 300)
	back.theme = MenuStyle.theme()
	back.position = Vector2(1280 - 300 - 24, 720 - 52 - 20)
	_gallery_bar.add_child(back)
	add_child(_gallery_bar)
	back.grab_focus.call_deferred()  # Controller users start on Back.
	_set_screen(&"gallery")


func _end_gallery() -> void:
	for node: Node in [_gallery_bar, gallery_root]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	gallery_root = null
	_gallery_bar = null


func _input(event: InputEvent) -> void:
	# Menu confirm/back clicks (never during live play).
	if audio == null or (current_screen == &"match" and not is_paused()):
		return
	if event.is_action_pressed(&"ui_accept"):
		audio.play_ui("confirm")
	elif event.is_action_pressed(&"ui_cancel"):
		audio.play_ui("back")


func _unhandled_input(event: InputEvent) -> void:
	if current_screen == &"gallery" and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		show_title()
		return
	# Controller safety net: if a menu is showing but nothing has focus (e.g.
	# after a mouse click elsewhere), any navigation input refocuses it.
	if _screen != null and is_instance_valid(_screen) and get_viewport().gui_get_focus_owner() == null:
		for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept"]:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				_screen.focus_first()
				return


# --- Match lifecycle ----------------------------------------------------------
## Starts a match. `picks` = one CharacterData per player (from the character
## select); empty = the last picks saved in settings.
func start_match(picks: Array[CharacterData] = []) -> void:
	_clear_screen()
	_end_match()
	_end_gallery()
	if picks.is_empty():
		for player_id in [1, 2]:
			var id := settings.last_pick(player_id)
			if not CharacterRoster.has(id):
				id = CharacterRoster.DEFAULT_PICKS[player_id - 1]
			picks.append(CharacterRoster.load_character(id))
	match_root = (load(MATCH_SCENE_PATH) as PackedScene).instantiate()
	match_root.set("character_override", picks)
	match_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Configure before _ready: main.gd starts the match when it enters the tree.
	var controller := match_root.get_node("Match") as MatchController
	controller.stock_count = settings.stocks
	add_child(match_root)
	match_controller = controller
	audio.bind_match(match_controller)
	if settings.show_hitboxes:
		var overlay := match_root.get_node_or_null("DebugOverlay")
		if overlay != null:
			overlay.visible = true
	var indicators := OffscreenIndicators.new()
	indicators.name = "OffscreenIndicators"
	indicators.match_controller = match_controller
	match_root.add_child(indicators)
	pause_menu = PauseMenu.new(self)
	add_child(pause_menu)
	result_overlay = ResultOverlay.new(self)
	add_child(result_overlay)
	result_overlay.bind(match_controller)
	_set_screen(&"match")


## Full restart from the pause menu (same as a rematch).
func restart_match() -> void:
	if pause_menu != null:
		pause_menu.resume()
	if match_controller != null:
		match_controller.rematch()


func set_paused(value: bool) -> void:
	get_tree().paused = value
	if audio != null:
		audio.set_paused_duck(value)
	if not value and match_controller != null:
		# Buttons pressed or released while paused must not register as fresh
		# presses (or leave stale edges) when play resumes.
		for player_input in match_controller.inputs:
			player_input.reset_edges()


func is_paused() -> bool:
	return get_tree().paused


func _end_match() -> void:
	if is_inside_tree():
		get_tree().paused = false
	for node: Node in [pause_menu, result_overlay, match_root]:
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	pause_menu = null
	result_overlay = null
	match_root = null
	match_controller = null


func quit_game() -> void:
	get_tree().quit()
