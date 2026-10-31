class_name CharacterSelectScreen
extends MenuScreen
## Smash-style character select for up to four players.
##
## Slots P1-P4 are OFF, HUMAN or CPU. P1 starts in; anyone else joins by
## pressing A (light) on their controller or half of the keyboard.
## Each human, with their own controls:
##   stick / D-pad   move the cursor (of the CPU you are holding, if any)
##   A               join / lock in (locks in the held CPU first)
##   B               un-ready -> remove the held CPU -> leave (P1: back to title)
##   Shield          hold a CPU's cursor: grabs an existing CPU, then the next,
##                   then adds a new CPU in a free slot (press again to cycle)
##   Heavy           change the held CPU's level (1-9)
##   Start / Enter   fight once 2+ fighters are in and everyone is ready
## Keyboard extras: Enter locks in the next player (adding keyboard P2 if only
## P1 is in) and starts the fight; Esc returns to the title.

const RANDOM := &"random"
const OFF := &"off"
const HUMAN := &"human"
const CPU := &"cpu"
const SLOTS := [1, 2, 3, 4]
const PLAYER_COLORS := {1: Color("4aa8ff"), 2: Color("ff5d5d"), 3: Color("ffcc3d"), 4: Color("5ee08a")}
const COLS := 5
const CARD := Vector2(138, 112)
const GAP := 10.0
const GRID_TOP := 86.0
const PANEL_TOP := 352.0
const PANEL := Vector2(304, 330)

var inputs: Array[PlayerInput] = []
var options: Array = []                         # roster ids + RANDOM
var cursor: Dictionary = {1: 0, 2: 1, 3: 0, 4: 0}
var is_ready: Dictionary = {1: false, 2: false, 3: false, 4: false}
var slot_type: Dictionary = {1: HUMAN, 2: OFF, 3: OFF, 4: OFF}
var cpu_level: Dictionary = {}                  # slot -> 1..9
## human slot -> CPU slot whose cursor they are holding.
var carrying: Dictionary = {}
var cards: Array[Control] = []
var _panels: Dictionary = {}
var _stat_range: Dictionary = {}
var _banner: _ReadyBanner
var _t := 0.0


func build() -> void:
	options = CharacterRoster.ids()
	options.append(RANDOM)
	for player_id in SLOTS:
		var pick: StringName = app.settings.last_pick(player_id)
		cursor[player_id] = maxi(options.find(pick), 0)
		var player_input := PlayerInput.new(player_id)
		player_input.reset_edges()  # the button that opened this screen is not a pick
		inputs.append(player_input)
	# Coming back from a match keeps the same lineup (humans and CPUs).
	for player_id: int in app.lineup:
		var entry: Dictionary = app.lineup[player_id]
		slot_type[player_id] = entry.get("type", OFF)
		if slot_type[player_id] == CPU:
			cpu_level[player_id] = entry.get("level", app.settings.cpu_level)
			is_ready[player_id] = true  # CPUs keep their pick; Shield picks them up to change it
	slot_type[1] = HUMAN if slot_type[1] == OFF else slot_type[1]
	_compute_stat_ranges()
	var bg := _Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var title := _text("CHOOSE YOUR FIGHTER", 38, MenuStyle.GOLD, Vector2(44, 18), Vector2(700, 56))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color("1b1006"))
	var sub := _text("%d fighters  ·  %d stocks  ·  up to 4 players" % [CharacterRoster.ids().size(), app.settings.stocks],
		14, Color("a9b6cc"), Vector2(740, 36), Vector2(500, 24))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for i in options.size():
		var row := i / COLS
		var col := i % COLS
		var in_row := mini(COLS, options.size() - row * COLS)
		var row_width := in_row * CARD.x + (in_row - 1) * GAP
		var card := _Card.new()
		card.screen = self
		card.index = i
		card.id = options[i]
		card.position = Vector2((1280.0 - row_width) / 2.0 + col * (CARD.x + GAP), GRID_TOP + row * (CARD.y + GAP))
		card.size = CARD
		card.pivot_offset = CARD / 2.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(card)
		cards.append(card)
	var row_width := SLOTS.size() * PANEL.x + (SLOTS.size() - 1) * 8.0
	for player_id: int in SLOTS:
		var panel := _PlayerPanel.new()
		panel.screen = self
		panel.player_id = player_id
		panel.position = Vector2((1280.0 - row_width) / 2.0 + (player_id - 1) * (PANEL.x + 8.0), PANEL_TOP)
		panel.size = PANEL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_panels[player_id] = panel
	_banner = _ReadyBanner.new()
	_banner.position = Vector2(0, 300)
	_banner.size = Vector2(1280, 64)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var help := _text("A join / lock in   ·   B back / leave   ·   Shield add CPU   ·   Heavy CPU level   ·   Start fight   ·   Keys: P1 F G R T · P2 K L I O",
		13, Color(0.66, 0.72, 0.82, 0.85), Vector2(0, 694), Vector2(1280, 20))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_refresh()


func _text(value: String, font_size: int, color: Color, pos: Vector2, box: Vector2) -> Label:
	var l := Label.new()
	l.text = value
	l.position = pos
	l.size = box
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- Slots ----------------------------------------------------------------------
func active_slots() -> Array:
	return SLOTS.filter(func(pid: int) -> bool: return slot_type[pid] != OFF)


func is_cpu(player_id: int) -> bool:
	return slot_type[player_id] == CPU


## A human (or the keyboard's P2) takes a free slot.
func join(player_id: int) -> void:
	if slot_type[player_id] == HUMAN:
		return
	_drop_carrier_of(player_id)
	slot_type[player_id] = HUMAN
	is_ready[player_id] = false
	cpu_level.erase(player_id)
	_panels[player_id].changed_at = _t
	_play("confirm")
	_refresh()


func leave(player_id: int) -> void:
	carrying.erase(player_id)
	_drop_carrier_of(player_id)
	slot_type[player_id] = OFF
	is_ready[player_id] = false
	cpu_level.erase(player_id)
	_play("back")
	_refresh()


## Adds a CPU in the first free slot (held by `by`). With no free slot, picks
## up the first CPU nobody is holding. Returns the CPU's slot, or -1.
func add_cpu(by: int) -> int:
	for pid: int in SLOTS:
		if slot_type[pid] == OFF:
			slot_type[pid] = CPU
			cpu_level[pid] = app.settings.cpu_level
			is_ready[pid] = false
			cursor[pid] = maxi(options.find(app.settings.last_pick(pid)), 0)
			carrying[by] = pid
			_panels[pid].changed_at = _t
			_play("confirm")
			_refresh()
			return pid
	for pid: int in SLOTS:
		if slot_type[pid] == CPU and not carrying.values().has(pid):
			is_ready[pid] = false
			carrying[by] = pid
			_play("move")
			_refresh()
			return pid
	return -1


## Shield: hold the next CPU's cursor. Grabs an existing CPU first, then
## the next one, then adds a new CPU in a free slot, then wraps around.
func cycle_cpu(by: int) -> int:
	var current: int = carrying.get(by, -1)
	var free_cpus: Array = SLOTS.filter(func(pid: int) -> bool:
		return slot_type[pid] == CPU and (not carrying.values().has(pid) or carrying.get(by) == pid))
	var after: Array = free_cpus.filter(func(pid: int) -> bool: return pid > current)
	if current < 0 and not free_cpus.is_empty():
		return _carry(by, free_cpus[0])
	if current >= 0 and not after.is_empty():
		return _carry(by, after[0])
	if SLOTS.any(func(pid: int) -> bool: return slot_type[pid] == OFF):
		carrying.erase(by)
		return add_cpu(by)
	return _carry(by, free_cpus[0]) if not free_cpus.is_empty() else -1


func _carry(by: int, cpu_slot: int) -> int:
	carrying[by] = cpu_slot
	_play("move")
	_refresh()
	return cpu_slot


func set_cpu_level(player_id: int, level: int) -> void:
	cpu_level[player_id] = clampi(level, CpuInput.MIN_LEVEL, CpuInput.MAX_LEVEL)
	app.settings.cpu_level = cpu_level[player_id]
	_play("move")
	_refresh()


func _drop_carrier_of(cpu_slot: int) -> void:
	for human: int in carrying.keys():
		if carrying[human] == cpu_slot:
			carrying.erase(human)


func _play(sound: String) -> void:
	if app.audio != null:
		app.audio.play_ui(sound)


# --- Input ----------------------------------------------------------------------
func _process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_t += delta
	for player_input in inputs:
		var frame := player_input.sample()
		_handle(player_input.player_id, frame)
		if is_queued_for_deletion():
			return
	for card in cards:
		card.queue_redraw()
	for panel: Control in _panels.values():
		panel.queue_redraw()
	_banner.visible = can_start()
	_banner.t = _t
	_banner.queue_redraw()


func _handle(pid: int, frame: InputFrame) -> void:
	if slot_type[pid] != HUMAN:
		# A controller on an empty (or CPU) port joins with A.
		if frame.is_pressed(&"light"):
			join(pid)
		return
	var target: int = carrying.get(pid, pid)
	if frame.is_pressed(&"light"):
		if target != pid:
			carrying.erase(pid)
		set_ready(target, true)
	elif frame.is_pressed(&"special"):
		if target != pid:
			if is_ready[target]:
				set_ready(target, false)
			else:
				leave(target)
		elif is_ready[pid]:
			set_ready(pid, false)
		elif pid != 1:
			leave(pid)
		elif not is_ready.values().has(true):
			app.show_title()
	elif frame.is_pressed(&"shield"):
		cycle_cpu(pid)
	elif frame.is_pressed(&"heavy") and is_cpu(target):
		set_cpu_level(target, wrapi(cpu_level.get(target, CpuInput.DEFAULT_LEVEL) + 1, CpuInput.MIN_LEVEL, CpuInput.MAX_LEVEL + 1))
	elif not is_ready[target] or (is_cpu(target) and target != pid):
		if is_ready[target] and (frame.is_pressed(&"left") or frame.is_pressed(&"right") or frame.is_pressed(&"up") or frame.is_pressed(&"down")):
			set_ready(target, false)  # moving a held CPU's cursor un-readies it
		if frame.is_pressed(&"left") or frame.is_pressed(&"right"):
			move_cursor(target, -1 if frame.is_pressed(&"left") else 1)
		elif frame.is_pressed(&"up") or frame.is_pressed(&"down"):
			move_row(target, -1 if frame.is_pressed(&"up") else 1)


func _unhandled_input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	# Keyboard-only conveniences. (Pad buttons are handled per player above.)
	if event is InputEventKey and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		app.show_title()
	elif event is InputEventKey and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if can_start():
			confirm()
			return
		for pid: int in active_slots():
			if not is_ready[pid]:
				carrying.erase(pid)
				_drop_carrier_of(pid)
				set_ready(pid, true)
				return
		if active_slots().size() < 2:
			join(2)  # one keyboard, two players
			set_ready(2, true)
	elif event is InputEventJoypadButton and event.is_action_pressed(InputSetup.ACTION_PAUSE) and can_start():
		get_viewport().set_input_as_handled()
		confirm()


## Left/right walk through the list (wrapping across rows).
func move_cursor(player_id: int, step: int) -> void:
	cursor[player_id] = wrapi(cursor[player_id] + step, 0, options.size())
	_moved(player_id)


## Up/down jump a row, keeping the column where possible.
func move_row(player_id: int, step: int) -> void:
	var rows := ceili(options.size() / float(COLS))
	var row := wrapi(cursor[player_id] / COLS + step, 0, rows)
	cursor[player_id] = mini(row * COLS + cursor[player_id] % COLS, options.size() - 1)
	_moved(player_id)


func _moved(player_id: int) -> void:
	_play("move")
	_panels[player_id].changed_at = _t
	_refresh()


func set_ready(player_id: int, value: bool) -> void:
	if slot_type[player_id] == OFF:
		join(player_id)
	if is_ready[player_id] != value:
		_play("confirm" if value else "back")
	is_ready[player_id] = value
	if value:
		_panels[player_id].ready_at = _t
	_refresh()


## Everyone who is in has locked in, and there are at least two fighters.
func can_start() -> bool:
	var active := active_slots()
	return active.size() >= 2 and active.all(func(pid: int) -> bool: return is_ready[pid])


## Kept for older callers: true when the match can start.
func both_ready() -> bool:
	return can_start()


## Starts the match with the chosen characters (random resolved now).
func confirm() -> void:
	if not can_start():
		return
	var picks: Array[CharacterData] = []
	var ports: Array[int] = []
	var cpus := {}
	app.lineup = {}
	for player_id: int in active_slots():
		var id: StringName = options[cursor[player_id]]
		if id == RANDOM:
			id = CharacterRoster.ids().pick_random()
		app.settings.set_last_pick(player_id, options[cursor[player_id]])
		picks.append(CharacterRoster.load_character(id))
		ports.append(player_id)
		if is_cpu(player_id):
			cpus[player_id] = cpu_level.get(player_id, CpuInput.DEFAULT_LEVEL)
		app.lineup[player_id] = {"type": slot_type[player_id], "level": cpu_level.get(player_id, 0)}
	app.settings.save_to_disk()
	app.start_match(picks, ports, cpus)


# --- Data for the view ------------------------------------------------------------
func _refresh() -> void:
	for card in cards:
		card.queue_redraw()
	for player_id: int in SLOTS:
		_panels[player_id].set_pick(options[cursor[player_id]])


func _compute_stat_ranges() -> void:
	for id: StringName in CharacterRoster.ids():
		var stats := stats_for(id)
		for key: String in stats:
			var r: Vector2 = _stat_range.get(key, Vector2(INF, -INF))
			_stat_range[key] = Vector2(minf(r.x, stats[key]), maxf(r.y, stats[key]))


## Raw stats used for the bars.
static func stats_for(id: StringName) -> Dictionary:
	var data := CharacterRoster.load_character(id)
	if data == null:
		return {}
	var power := 0.0
	for move in data.moves:
		power = maxf(power, move.damage + move.knockback_growth * 0.6)
	return {"POWER": power, "SPEED": data.max_speed, "WEIGHT": data.weight, "JUMP": data.jump_velocity + data.double_jump_velocity * 0.5}


## 0.18..1 bar fill for a stat relative to the roster.
func stat_fill(key: String, value: float) -> float:
	var r: Vector2 = _stat_range.get(key, Vector2(0, 1))
	if r.y - r.x < 0.001:
		return 0.6
	return lerpf(0.18, 1.0, (value - r.x) / (r.y - r.x))


static func display_name(id: StringName) -> String:
	if id == RANDOM:
		return "Random"
	var data := CharacterRoster.load_character(id)
	return data.display_name if data != null else String(id)


# =============================================================================
# Drawing helpers (inner classes keep this screen self-contained)
# =============================================================================
class _Backdrop extends Control:
	const ART := preload("res://art/arena/twilight_citadel.png")

	func _draw() -> void:
		draw_texture_rect(ART, Rect2(0, 0, 1280, 720), false, Color(0.32, 0.34, 0.45))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 340), Vector2(0, 340)]),
			PackedColorArray([Color(0.01, 0.02, 0.05, 0.85), Color(0.01, 0.02, 0.05, 0.85), Color(0.02, 0.03, 0.08, 0.35), Color(0.02, 0.03, 0.08, 0.35)]))
		draw_polygon(PackedVector2Array([Vector2(0, 340), Vector2(1280, 340), Vector2(1280, 720), Vector2(0, 720)]),
			PackedColorArray([Color(0.01, 0.02, 0.05, 0.2), Color(0.01, 0.02, 0.05, 0.2), Color(0.01, 0.02, 0.05, 0.7), Color(0.01, 0.02, 0.05, 0.7)]))
		draw_rect(Rect2(44, 72, 330, 3), Color("ffd36b"))
		draw_rect(Rect2(374, 73, 870, 1), Color(1, 0.83, 0.42, 0.35))


class _Card extends Control:
	var screen: CharacterSelectScreen
	var index := 0
	var id: StringName
	var _portrait: Texture2D
	var _name := ""

	func _ready() -> void:
		_portrait = null if id == RANDOM else CharacterRoster.portrait(id)
		_name = CharacterSelectScreen.display_name(id)

	func _draw() -> void:
		var who: Array = []
		for pid: int in SLOTS:
			if screen.slot_type[pid] != OFF and screen.cursor[pid] == index:
				who.append(pid)
		var hot := not who.is_empty()
		scale = Vector2.ONE * (1.06 if hot else 1.0)
		var r := Rect2(Vector2.ZERO, size)
		for pid in who:
			var c: Color = PLAYER_COLORS[pid]
			for k in 3:
				c.a = 0.18 - k * 0.05
				draw_rect(r.grow(4 + k * 4), c, false, 4.0)
		draw_rect(r, Color(0.07, 0.09, 0.15) if not hot else Color(0.12, 0.15, 0.25))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x * 0.55, 0), Vector2(size.x * 0.25, size.y), Vector2(0, size.y)]),
			PackedColorArray([Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.03)]))
		var art := Rect2(6, 4, size.x - 12, size.y - 30)
		var font := get_theme_default_font()
		if _portrait != null:
			draw_texture_rect(_portrait, art, false)
		else:
			var glyph := "?" if id == RANDOM else _name.substr(0, 1)
			draw_string(font, Vector2(0, art.get_center().y + 22), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 60,
				Color("ffd36b") if id == RANDOM else Color(0.6, 0.65, 0.78))
		draw_rect(Rect2(0, size.y - 26, size.x, 26), Color(0.02, 0.03, 0.06, 0.92))
		draw_string(font, Vector2(0, size.y - 8), _name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
			Color("ffe9b0") if hot else Color(0.85, 0.88, 0.95))
		var border := Color(0.3, 0.35, 0.48)
		if who.size() == 1:
			border = PLAYER_COLORS[who[0]]
		elif who.size() > 1:
			border = Color("c48cff")
		draw_rect(r, border, false, 3.0 if hot else 1.0)
		# Player tokens: P1 top-left, P2 top-right, P3 bottom-left, P4 bottom-right.
		for pid: int in who:
			var x := 4.0 if pid % 2 == 1 else size.x - 38.0
			var y := 4.0 if pid <= 2 else size.y - 50.0
			var tag := Rect2(x, y, 34, 18)
			draw_rect(tag, PLAYER_COLORS[pid])
			var label := "CPU" if screen.is_cpu(pid) else "P%d" % pid
			draw_string(font, tag.position + Vector2(0, 14), label, HORIZONTAL_ALIGNMENT_CENTER, 34, 12, Color.WHITE)
			if screen.is_ready[pid]:
				draw_rect(r, Color(PLAYER_COLORS[pid], 0.12))


class _PlayerPanel extends Control:
	var screen: CharacterSelectScreen
	var player_id := 1
	var pick: StringName
	var changed_at := -10.0
	var ready_at := -10.0
	var _frames: Dictionary = {}
	var _stats: Dictionary = {}
	var _tagline := ""

	func set_pick(id: StringName) -> void:
		if id == pick:
			return
		pick = id
		_frames = {} if id == RANDOM else CharacterRoster.showcase(id)
		_stats = {} if id == RANDOM else CharacterSelectScreen.stats_for(id)
		_tagline = "Picked when the match starts" if id == RANDOM else CharacterRoster.entry(id).get("tagline", "")

	func _draw() -> void:
		var t := screen._t
		var accent: Color = PLAYER_COLORS[player_id]
		var kind: StringName = screen.slot_type[player_id]
		var locked: bool = screen.is_ready[player_id]
		var w := size.x
		var h := size.y
		var font := get_theme_default_font()
		var shape := PackedVector2Array([Vector2(14, 0), Vector2(w, 0), Vector2(w - 14, h), Vector2(0, h)])
		var outline := shape.duplicate()
		outline.append(shape[0])
		if kind == OFF:
			draw_colored_polygon(shape, Color(0.02, 0.03, 0.06, 0.55))
			draw_polyline(outline, Color(accent, 0.25), 1.5, true)
			draw_string(font, Vector2(0, h * 0.42), "P%d" % player_id, HORIZONTAL_ALIGNMENT_CENTER, w, 64, Color(accent, 0.18))
			var pulse := 0.55 + 0.45 * sin(t * 4.0 + player_id)
			draw_string(font, Vector2(0, h * 0.62), "PRESS  A  TO  JOIN", HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(1, 1, 1, pulse))
			draw_string(font, Vector2(0, h * 0.62 + 26), "or Shield to add a CPU", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.65, 0.7, 0.8))
			return
		draw_colored_polygon(shape, Color(0.02, 0.03, 0.06, 0.85))
		var glow := accent
		glow.a = 0.3 if locked else 0.16
		var clear := Color(accent, 0.0)
		draw_polygon(PackedVector2Array([Vector2(14, 0), Vector2(w, 0), Vector2(w - 8, 230), Vector2(6, 230)]),
			PackedColorArray([clear, clear, glow, glow]))
		draw_rect(Rect2(14, 0, w - 14, 4), accent)
		draw_polyline(outline, Color(accent, 0.6), 2.0, true)
		# Header: port tag and status.
		var tag_text := "CPU" if kind == CPU else "P%d" % player_id
		draw_rect(Rect2(22, 12, 44, 22), accent)
		draw_string(font, Vector2(22, 29), tag_text, HORIZONTAL_ALIGNMENT_CENTER, 44, 15, Color.WHITE)
		var status := "READY" if locked else "CHOOSING…"
		var held_by := -1
		for human: int in screen.carrying:
			if screen.carrying[human] == player_id:
				held_by = human
		if kind == CPU:
			status = "LV %d  ·  %s" % [screen.cpu_level.get(player_id, CpuInput.DEFAULT_LEVEL), "READY" if locked else ("P%d choosing" % held_by if held_by > 0 else "waiting")]
		draw_string(font, Vector2(74, 29), status, HORIZONTAL_ALIGNMENT_LEFT, w - 90, 14, Color("ffd36b") if locked else Color(0.7, 0.75, 0.86))
		if kind == CPU:
			# Level pips.
			var level: int = screen.cpu_level.get(player_id, CpuInput.DEFAULT_LEVEL)
			for i in CpuInput.MAX_LEVEL:
				draw_rect(Rect2(w - 30 - (CpuInput.MAX_LEVEL - i) * 9, 40, 7, 7), accent if i < level else Color(1, 1, 1, 0.12))
		# Fighter render.
		var since_change := t - changed_at
		var anim := &"victory" if locked and _frames.has(&"victory") else &"idle"
		var frames: Array = _frames.get(anim, [])
		var floor_y := 222.0
		var cx := w / 2.0
		draw_set_transform(Vector2(cx, floor_y + 3), 0.0, Vector2(1, 0.2))
		draw_circle(Vector2.ZERO, 80.0, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not frames.is_empty():
			var tex: Texture2D = frames[int(t * 2.5) % frames.size()]
			var k := minf(172.0 / tex.get_height(), 250.0 / tex.get_width())
			var draw_size := tex.get_size() * k
			var slide := (1.0 - ease(clampf(since_change / 0.22, 0.0, 1.0), 0.35)) * 40.0
			# Left half faces right, right half faces left: everyone looks inward.
			var flip := 1.0 if player_id <= 2 else -1.0
			draw_set_transform(Vector2(cx - slide * flip, floor_y), 0.0, Vector2(flip, 1.0))
			var rect := Rect2(Vector2(-draw_size.x / 2.0, -draw_size.y), draw_size)
			draw_texture_rect(tex, rect, false, Color(1, 1, 1, clampf(since_change / 0.15, 0.0, 1.0)))
			var flash := clampf(1.0 - (t - ready_at) / 0.35, 0.0, 1.0)
			if flash > 0.0 and locked:
				draw_texture_rect(tex, rect, false, Color(1, 1, 1, flash * 0.8))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_string(font, Vector2(0, floor_y - 50), "?" if pick == RANDOM else "★", HORIZONTAL_ALIGNMENT_CENTER, w, 110, Color(accent, 0.75))
		# Name, tagline and compact stats.
		var title_text := CharacterSelectScreen.display_name(pick).to_upper()
		var name_size := 28 if title_text.length() <= 12 else 22
		draw_string_outline(font, Vector2(0, 258), title_text, HORIZONTAL_ALIGNMENT_CENTER, w, name_size, 8, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, 258), title_text, HORIZONTAL_ALIGNMENT_CENTER, w, name_size, Color("fff4dc"))
		draw_string(font, Vector2(0, 276), _tagline, HORIZONTAL_ALIGNMENT_CENTER, w, 12, accent.lightened(0.35))
		var keys := ["POWER", "SPEED", "WEIGHT", "JUMP"]
		for i in keys.size():
			var col := i % 2
			var row := i / 2
			var x := 26.0 + col * 136.0
			var y := 290.0 + row * 18.0
			draw_string(font, Vector2(x, y + 9), keys[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.68, 0.73, 0.83))
			var bar := Rect2(x + 52, y + 1, 72, 8)
			draw_rect(bar, Color(1, 1, 1, 0.08))
			if _stats.has(keys[i]):
				var fill := screen.stat_fill(keys[i], _stats[keys[i]]) * clampf((t - changed_at) / 0.3, 0.0, 1.0)
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), accent)
		if locked:
			var pop := 1.0 + 0.25 * clampf(1.0 - (t - ready_at) / 0.2, 0.0, 1.0)
			draw_set_transform(Vector2(cx, 120), -0.12, Vector2(pop, pop))
			draw_rect(Rect2(-120, -22, 240, 44), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(-120, -18, 240, 36), accent)
			draw_string_outline(font, Vector2(-120, 11), "READY!", HORIZONTAL_ALIGNMENT_CENTER, 240, 28, 6, Color(0, 0, 0, 0.7))
			draw_string(font, Vector2(-120, 11), "READY!", HORIZONTAL_ALIGNMENT_CENTER, 240, 28, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class _ReadyBanner extends Control:
	var t := 0.0

	func _draw() -> void:
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(0, 8), Vector2(1280, 0), Vector2(1280, h - 8), Vector2(0, h)]),
			PackedColorArray([Color(0.6, 0.05, 0.05, 0.92), Color(0.75, 0.45, 0.05, 0.92), Color(0.75, 0.45, 0.05, 0.92), Color(0.6, 0.05, 0.05, 0.92)]))
		draw_rect(Rect2(0, 2, 1280, 3), Color(1, 0.9, 0.5, 0.8))
		draw_rect(Rect2(0, h - 5, 1280, 3), Color(1, 0.9, 0.5, 0.8))
		var font := get_theme_default_font()
		var pulse := 0.8 + 0.2 * sin(t * 6.0)
		var text := "READY TO FIGHT!   PRESS START"
		draw_string_outline(font, Vector2(0, h / 2.0 + 13), text, HORIZONTAL_ALIGNMENT_CENTER, 1280, 36, 10, Color(0.15, 0.02, 0, 0.9))
		draw_string(font, Vector2(0, h / 2.0 + 13), text, HORIZONTAL_ALIGNMENT_CENTER, 1280, 36, Color(1, 0.97, 0.85, pulse))
