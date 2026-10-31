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
## Smash "tap jump": pushing the stick up also jumps.
var tap_jump: bool = true
## Volumes 0..10 per audio bus.
var volumes: Dictionary = {&"Master": 8, &"Music": 6, &"SFX": 8, &"Voice": 9}
## Last character picks per player (select-screen cursor start).
var picks: Dictionary = {1: CharacterRoster.DEFAULT_PICKS[0], 2: CharacterRoster.DEFAULT_PICKS[1],
	3: &"random", 4: &"random"}
## Default level for newly added CPU players (1-9).
var cpu_level: int = CpuInput.DEFAULT_LEVEL


func _init(config_path: String = DEFAULT_PATH) -> void:
	path = config_path


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	stocks = clampi(int(cfg.get_value("match", "stocks", stocks)), MIN_STOCKS, MAX_STOCKS)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	show_hitboxes = bool(cfg.get_value("debug", "show_hitboxes", show_hitboxes))
	tap_jump = bool(cfg.get_value("controls", "tap_jump", tap_jump))
	for bus: StringName in volumes.keys():
		volumes[bus] = clampi(int(cfg.get_value("audio", String(bus).to_lower(), volumes[bus])), 0, 10)
	cpu_level = clampi(int(cfg.get_value("match", "cpu_level", cpu_level)), CpuInput.MIN_LEVEL, CpuInput.MAX_LEVEL)
	for player_id in [1, 2, 3, 4]:
		var pick := StringName(str(cfg.get_value("characters", "p%d" % player_id, picks[player_id])))
		if CharacterRoster.has(pick) or pick == &"random":
			picks[player_id] = pick
	apply_controls()


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("match", "stocks", stocks)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("debug", "show_hitboxes", show_hitboxes)
	cfg.set_value("controls", "tap_jump", tap_jump)
	for bus: StringName in volumes.keys():
		cfg.set_value("audio", String(bus).to_lower(), volumes[bus])
	cfg.set_value("match", "cpu_level", cpu_level)
	for player_id in [1, 2, 3, 4]:
		cfg.set_value("characters", "p%d" % player_id, String(picks[player_id]))
	var err := cfg.save(path)
	if err != OK:
		push_warning("Could not save settings to %s (error %d)" % [path, err])


func last_pick(player_id: int) -> StringName:
	return picks.get(player_id, CharacterRoster.DEFAULT_PICKS[0])


func set_last_pick(player_id: int, id: StringName) -> void:
	picks[player_id] = id


func apply_audio() -> void:
	for bus: StringName in volumes.keys():
		AudioDirector.set_bus_volume(bus, volumes[bus])


func apply_controls() -> void:
	PlayerInput.tap_jump = tap_jump


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
