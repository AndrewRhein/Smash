class_name GameApp
extends Node
## Application shell and entry scene (scenes/app.tscn):
##   Title -> Match -> (Pause | Result) -> Title.
## It instantiates scenes/main.tscn UNCHANGED for each match and only talks to
## its MatchController through public API, so gameplay and the presentation
## wiring inside main.tscn stay independent of the menus.

signal screen_changed(screen: StringName)

const MATCH_SCENE := preload("res://scenes/main.tscn")

var settings: GameSettings
var current_screen: StringName = &""
var match_root: Node
var match_controller: MatchController
var pause_menu: PauseMenu
var result_overlay: ResultOverlay
var _menu_layer: CanvasLayer
var _screen: MenuScreen


func _init(p_settings: GameSettings = null) -> void:
	settings = p_settings if p_settings != null else GameSettings.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure_actions()
	settings.load_from_disk()
	settings.apply_window()
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "Menus"
	_menu_layer.layer = 20
	add_child(_menu_layer)
	show_title()


# --- Menu screens -------------------------------------------------------------
func show_title() -> void:
	_end_match()
	_show_screen(TitleScreen.new(self), &"title")


func show_settings() -> void:
	_show_screen(SettingsScreen.new(self), &"settings")


func show_controls(back: Callable) -> void:
	_show_screen(ControlsScreen.new(self, back), &"controls")


func _show_screen(screen: MenuScreen, id: StringName) -> void:
	_clear_screen()
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


# --- Match lifecycle ----------------------------------------------------------
func start_match() -> void:
	_clear_screen()
	_end_match()
	match_root = MATCH_SCENE.instantiate()
	match_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Configure before _ready: main.gd starts the match when it enters the tree.
	var controller := match_root.get_node("Match") as MatchController
	controller.stock_count = settings.stocks
	add_child(match_root)
	match_controller = controller
	if settings.show_hitboxes:
		var overlay := match_root.get_node_or_null("DebugOverlay")
		if overlay != null:
			overlay.visible = true
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
