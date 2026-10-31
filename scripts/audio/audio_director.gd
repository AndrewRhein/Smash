class_name AudioDirector
extends Node
## Plays music, sound effects and character voice lines in response to game
## events. Purely presentation: it only listens to signals, never changes play.
##
## Audio is found by NAME, so adding a sound is just dropping a file in place
## (see docs/AUDIO.md). For a key like "sfx/hit_spark" it looks for
##   res://audio/sfx/hit_spark.ogg|.wav|.mp3   and variants hit_spark_1 .. _9
## and picks a random variant each time. Missing files are silently skipped,
## so the game runs with no audio at all.
##
## Buses: Master > Music, SFX, Voice (created at runtime if missing).

const ROOT := "res://audio/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const BUSES := [&"Music", &"SFX", &"Voice"]
const SFX_VOICES := 12
## Chance a fighter calls out a move, by move slot (specials always shout).
const VOICE_CHANCE := {&"light": 0.25, &"heavy": 0.7}
const VOICE_COOLDOWN_MS := 450
const MUSIC_FADE_SECONDS := 0.8
const PAUSE_DUCK_DB := -10.0

var _cache: Dictionary = {}           # key -> Array[AudioStream]
var _music: AudioStreamPlayer
var _music_key: String = ""
var _sfx: Array[AudioStreamPlayer2D] = []
var _ui: AudioStreamPlayer
var _voice: Dictionary = {}           # fighter instance id -> AudioStreamPlayer2D
var _voice_last_ms: Dictionary = {}   # fighter instance id -> msec
var _rng := RandomNumberGenerator.new()
## Every key requested (found or not); handy for tests and for listing what
## audio a build would use.
var requested: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	_ui = AudioStreamPlayer.new()
	_ui.bus = &"SFX"
	add_child(_ui)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		p.max_distance = 4000.0
		p.attenuation = 0.0  # pan only; no distance falloff
		add_child(p)
		_sfx.append(p)


static func ensure_buses() -> void:
	for bus: StringName in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")


## volume 0..10 (settings scale) for "Master", "Music", "SFX" or "Voice".
static func set_bus_volume(bus: StringName, volume: int) -> void:
	ensure_buses()
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(volume / 10.0, 0.0001, 1.0)))


# --- Lookup ---------------------------------------------------------------------
func streams(key: String) -> Array:
	if _cache.has(key):
		return _cache[key]
	var found: Array = []
	for suffix in [""] + range(1, 10).map(func(i: int) -> String: return "_%d" % i):
		for ext: String in EXTENSIONS:
			var path := "%s%s%s.%s" % [ROOT, key, suffix, ext]
			if ResourceLoader.exists(path):
				found.append(load(path))
				break
	_cache[key] = found
	return found


func has_audio(key: String) -> bool:
	return not streams(key).is_empty()


func _pick(key: String) -> AudioStream:
	requested.append(key)
	var list := streams(key)
	return null if list.is_empty() else list[_rng.randi() % list.size()]


## First key in `keys` that has audio (fallback chains like hit_heavy -> hit_spark).
func _pick_first(keys: Array) -> AudioStream:
	for key: String in keys:
		var s := _pick(key)
		if s != null:
			return s
	return null


# --- Playback -------------------------------------------------------------------
func play_sfx(keys: Variant, at: Vector2 = Vector2(640, 360), volume_db: float = 0.0) -> void:
	var stream := _pick_first(keys if keys is Array else [keys])
	if stream == null:
		return
	var player := _sfx[0]
	for p in _sfx:  # free voice, else the oldest
		if not p.playing:
			player = p
			break
	_sfx.erase(player)
	_sfx.append(player)
	player.stream = stream
	player.global_position = at
	player.volume_db = volume_db
	player.play()


func play_ui(key: String) -> void:
	var stream := _pick("ui/" + key)
	if stream != null:
		_ui.stream = stream
		_ui.play()


## Plays a character line; a new line from the same fighter cuts off the old one.
func play_voice(fighter: Fighter, line: String, chance: float = 1.0, ignore_cooldown: bool = false) -> void:
	var id := fighter.get_instance_id()
	var now := Time.get_ticks_msec()
	if not ignore_cooldown and now - int(_voice_last_ms.get(id, -100000)) < VOICE_COOLDOWN_MS:
		return
	if _rng.randf() > chance:
		return
	var stream := _pick("voice/%s/%s" % [fighter.character.id, line])
	if stream == null:
		return
	var player: AudioStreamPlayer2D = _voice.get(id)
	if player == null or not is_instance_valid(player):
		player = AudioStreamPlayer2D.new()
		player.bus = &"Voice"
		player.max_distance = 4000.0
		player.attenuation = 0.0
		add_child(player)
		_voice[id] = player
	_voice_last_ms[id] = now
	player.stream = stream
	player.global_position = fighter.global_position
	player.play()


## Music loops; the same key keeps playing. Empty key = fade out.
func play_music(key: String) -> void:
	if key == _music_key:
		return
	_music_key = key
	var stream := _pick("music/" + key) if key != "" else null
	var tween := create_tween()
	if _music.playing:
		tween.tween_property(_music, "volume_db", -40.0, MUSIC_FADE_SECONDS * 0.5)
	tween.tween_callback(func() -> void:
		_music.stop()
		if stream != null:
			if "loop" in stream and not key.begins_with("victory"):
				stream.loop = true
			_music.stream = stream
			_music.volume_db = 0.0
			_music.play())


func current_music() -> String:
	return _music_key


func set_paused_duck(paused: bool) -> void:
	_music.volume_db = PAUSE_DUCK_DB if paused else 0.0


# --- Game events ----------------------------------------------------------------
func bind_match(match_controller: MatchController) -> void:
	match_controller.fighter_spawned.connect(_on_fighter_spawned)
	match_controller.match_state_changed.connect(_on_match_state)
	match_controller.match_ended.connect(_on_match_ended.bind(match_controller))
	for fighter in match_controller.fighters:
		_on_fighter_spawned(fighter)


func _on_fighter_spawned(fighter: Fighter) -> void:
	fighter.animation_requested.connect(_on_animation.bind(fighter))
	fighter.effect_requested.connect(_on_effect.bind(fighter))


func _on_match_state(state: MatchController.MatchState) -> void:
	match state:
		MatchController.MatchState.COUNTDOWN:
			play_music("battle")
			play_sfx(["announcer/ready"])
		MatchController.MatchState.PLAYING:
			play_music("battle")
			play_sfx(["announcer/go"])


func _on_match_ended(winner: int, match_controller: MatchController) -> void:
	play_music("victory")
	play_sfx(["announcer/draw"] if winner == MatchController.DRAW else ["announcer/game"])
	var fighter := match_controller.get_fighter(winner)
	if fighter != null:
		play_voice(fighter, "victory", 1.0, true)


func _on_animation(animation_id: StringName, _duration: int, _loop: bool, fighter: Fighter) -> void:
	var snap := fighter.get_presentation_snapshot()
	match snap.state:
		&"attack":
			var move_id: StringName = snap.current_move_id
			play_voice(fighter, String(move_id), VOICE_CHANCE.get(move_id, 1.0))
		&"hitstun":
			play_voice(fighter, "hurt_heavy" if animation_id == GameIds.ANIM_KNOCKBACK else "hurt", 0.6)
		&"jump":
			play_sfx(["sfx/jump"], fighter.global_position, -6.0)
		&"shield":
			play_sfx(["sfx/shield_up"], fighter.global_position, -8.0)
		&"dodge":
			play_sfx(["sfx/dodge"], fighter.global_position, -4.0)
		&"shield_break":
			play_voice(fighter, "dizzy", 1.0, true)


func _on_effect(effect_id: StringName, at: Vector2, _direction: Vector2, payload: Dictionary, fighter: Fighter) -> void:
	var keys: Array = ["sfx/%s" % effect_id]
	match effect_id:
		&"hit_spark":
			if payload.get("shield_break", false):
				keys = ["sfx/shield_break", "sfx/hit_heavy", "sfx/hit_spark"]
			elif float(payload.get("damage", 0.0)) >= 12.0:
				keys = ["sfx/hit_heavy", "sfx/hit_spark"]
		&"guard_block":
			if payload.get("shield", false):
				keys = ["sfx/shield_hit", "sfx/guard_block"]
		&"blast_ko":
			play_voice(fighter, "ko", 1.0, true)
		&"respawn":
			if payload.get("left_platform", false):
				return
	play_sfx(keys, at)
