class_name GameSettings
extends RefCounted
## Player-facing settings persisted to a ConfigFile (user://settings.cfg).
## Unknown or out-of-range values on disk fall back to defaults.

const DEFAULT_PATH := "user://settings.cfg"
const MIN_STOCKS := 1
const MAX_STOCKS := 5

var path: String = DEFAULT_PATH
var stocks: int = 3
var fullscreen: bool = false
## Start every match with the F1 hitbox overlay visible (handy for playtests).
var show_hitboxes: bool = false


func _init(config_path: String = DEFAULT_PATH) -> void:
	path = config_path


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	stocks = clampi(int(cfg.get_value("match", "stocks", stocks)), MIN_STOCKS, MAX_STOCKS)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	show_hitboxes = bool(cfg.get_value("debug", "show_hitboxes", show_hitboxes))


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("match", "stocks", stocks)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("debug", "show_hitboxes", show_hitboxes)
	var err := cfg.save(path)
	if err != OK:
		push_warning("Could not save settings to %s (error %d)" % [path, err])


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
