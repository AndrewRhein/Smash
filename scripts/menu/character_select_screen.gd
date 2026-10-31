class_name CharacterSelectScreen
extends MenuScreen
## Smash-style character select. Both players pick at the same time with their
## own controls (own controller or own half of the keyboard):
##   stick / D-pad  move your cursor around the grid   A / F / K  lock in
##   B / G / L   un-ready (or leave when nobody is ready)
##   Start / Enter  fight once both are ready (Enter also locks in the next
##   player, for one-keyboard play)      Esc  back to the title
## The roster comes from CharacterRoster, so new characters appear automatically.

const RANDOM := &"random"
const PLAYER_COLORS := {1: Color("4aa8ff"), 2: Color("ff5d5d")}
const COLS := 5
const CARD := Vector2(138, 112)
const GAP := 10.0
const GRID_TOP := 86.0
const PANEL_TOP := 352.0

var inputs: Array[PlayerInput] = []
var options: Array = []                 # roster ids + RANDOM
var cursor: Dictionary = {1: 0, 2: 1}   # player_id -> option index
var is_ready: Dictionary = {1: false, 2: false}
var cards: Array[Control] = []
var _panels: Dictionary = {}
var _stat_range: Dictionary = {}
var _banner: _ReadyBanner
var _t := 0.0


func build() -> void:
	options = CharacterRoster.ids()
	options.append(RANDOM)
	for player_id in [1, 2]:
		var pick: StringName = app.settings.last_pick(player_id)
		cursor[player_id] = maxi(options.find(pick), 0)
		var player_input := PlayerInput.new(player_id)
		player_input.reset_edges()  # the button that opened this screen is not a pick
		inputs.append(player_input)
	_compute_stat_ranges()
	var bg := _Backdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var title := _text("CHOOSE YOUR FIGHTER", 38, MenuStyle.GOLD, Vector2(44, 18), Vector2(700, 56))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color("1b1006"))
	var sub := _text("%d fighters  ·  %d stocks  ·  The Twilight Citadel" % [CharacterRoster.ids().size(), app.settings.stocks],
		14, Color("a9b6cc"), Vector2(740, 36), Vector2(500, 24))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rows := ceili(options.size() / float(COLS))
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
	assert(GRID_TOP + rows * (CARD.y + GAP) <= PANEL_TOP, "grid overlaps player panels")
	for player_id in [1, 2]:
		var panel := _PlayerPanel.new()
		panel.screen = self
		panel.player_id = player_id
		panel.position = Vector2(16 if player_id == 1 else 648, PANEL_TOP)
		panel.size = Vector2(616, 330)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_panels[player_id] = panel
	_banner = _ReadyBanner.new()
	_banner.position = Vector2(0, 470)
	_banner.size = Vector2(1280, 76)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var help := _text("Move: stick / D-pad · WASD · arrows     Lock in: A · F · K     Back: B · G · L     Fight: Start / Enter     Menu: Esc",
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


# --- Input ----------------------------------------------------------------------
func _process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_t += delta
	for player_input in inputs:
		var frame := player_input.sample()
		var pid := player_input.player_id
		if frame.is_pressed(&"light"):
			set_ready(pid, true)
		elif frame.is_pressed(&"special"):
			if is_ready[pid]:
				set_ready(pid, false)
			elif not is_ready[1] and not is_ready[2]:
				app.show_title()
				return
		elif not is_ready[pid]:
			if frame.is_pressed(&"left") or frame.is_pressed(&"right"):
				move_cursor(pid, -1 if frame.is_pressed(&"left") else 1)
			elif frame.is_pressed(&"up") or frame.is_pressed(&"down"):
				move_row(pid, -1 if frame.is_pressed(&"up") else 1)
	for card in cards:
		card.queue_redraw()
	for panel: Control in _panels.values():
		panel.queue_redraw()
	_banner.visible = both_ready()
	_banner.t = _t
	_banner.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if is_queued_for_deletion():
		return
	# Keyboard-only conveniences. (Pad A/B are handled per player above.)
	if event is InputEventKey and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		app.show_title()
	elif event is InputEventKey and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if both_ready():
			confirm()
		else:
			set_ready(1 if not is_ready[1] else 2, true)
	elif event is InputEventJoypadButton and event.is_action_pressed(InputSetup.ACTION_PAUSE) and both_ready():
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
	if app.audio != null:
		app.audio.play_ui("move")
	_panels[player_id].changed_at = _t
	_refresh()


func set_ready(player_id: int, value: bool) -> void:
	if app.audio != null and is_ready[player_id] != value:
		app.audio.play_ui("confirm" if value else "back")
	is_ready[player_id] = value
	if value:
		_panels[player_id].ready_at = _t
	_refresh()


func both_ready() -> bool:
	return is_ready[1] and is_ready[2]


## Starts the match with the chosen characters (random resolved now).
func confirm() -> void:
	if not both_ready():
		return
	var picks: Array[CharacterData] = []
	for player_id in [1, 2]:
		var id: StringName = options[cursor[player_id]]
		if id == RANDOM:
			id = CharacterRoster.ids().pick_random()
		app.settings.set_last_pick(player_id, options[cursor[player_id]])
		picks.append(CharacterRoster.load_character(id))
	app.settings.save_to_disk()
	app.start_match(picks)


# --- Data for the view ------------------------------------------------------------
func _refresh() -> void:
	for card in cards:
		card.queue_redraw()
	for player_id in [1, 2]:
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


## 0.15..1 bar fill for a stat relative to the roster.
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


static func specials_text(id: StringName) -> PackedStringArray:
	var lines := PackedStringArray()
	var data := CharacterRoster.load_character(id)
	if data == null:
		return lines
	for pair in [["B", data.neutral_special], ["→B", data.side_special], ["↑B", data.up_special], ["↓B", data.down_special]]:
		var move := data.get_move(pair[1])
		if move != null:
			lines.append("%s  %s" % [pair[0], move.label()])
	return lines


# =============================================================================
# Drawing helpers (inner classes keep this screen self-contained)
# =============================================================================
class _Backdrop extends Control:
	const ART := preload("res://art/arena/twilight_citadel.png")

	func _draw() -> void:
		draw_texture_rect(ART, Rect2(0, 0, 1280, 720), false, Color(0.32, 0.34, 0.45))
		# Darken top and bottom, tint each half with the player colour.
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 340), Vector2(0, 340)]),
			PackedColorArray([Color(0.01, 0.02, 0.05, 0.85), Color(0.01, 0.02, 0.05, 0.85), Color(0.02, 0.03, 0.08, 0.35), Color(0.02, 0.03, 0.08, 0.35)]))
		draw_polygon(PackedVector2Array([Vector2(0, 340), Vector2(700, 340), Vector2(580, 720), Vector2(0, 720)]),
			PackedColorArray([Color(0.1, 0.3, 0.7, 0.18), Color(0.1, 0.3, 0.7, 0.0), Color(0.1, 0.3, 0.7, 0.0), Color(0.1, 0.3, 0.7, 0.32)]))
		draw_polygon(PackedVector2Array([Vector2(700, 340), Vector2(1280, 340), Vector2(1280, 720), Vector2(580, 720)]),
			PackedColorArray([Color(0.7, 0.12, 0.12, 0.0), Color(0.7, 0.12, 0.12, 0.18), Color(0.7, 0.12, 0.12, 0.32), Color(0.7, 0.12, 0.12, 0.0)]))
		# Title bar underline.
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
		for pid in [1, 2]:
			if screen.cursor[pid] == index:
				who.append(pid)
		var hot := not who.is_empty()
		scale = Vector2.ONE * (1.06 if hot else 1.0)
		var r := Rect2(Vector2.ZERO, size)
		# Glow behind a selected card.
		for pid in who:
			var c: Color = PLAYER_COLORS[pid]
			for k in 3:
				c.a = 0.18 - k * 0.05
				draw_rect(r.grow(4 + k * 4), c, false, 4.0)
		draw_rect(r, Color(0.07, 0.09, 0.15) if not hot else Color(0.12, 0.15, 0.25))
		# Diagonal sheen.
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x * 0.55, 0), Vector2(size.x * 0.25, size.y), Vector2(0, size.y)]),
			PackedColorArray([Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.03)]))
		var art := Rect2(6, 4, size.x - 12, size.y - 30)
		if _portrait != null:
			draw_texture_rect(_portrait, art, false)
		else:
			var font := get_theme_default_font()
			var glyph := "?" if id == RANDOM else _name.substr(0, 1)
			draw_string(font, Vector2(0, art.get_center().y + 22), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 60,
				Color("ffd36b") if id == RANDOM else Color(0.6, 0.65, 0.78))
		# Name strip.
		draw_rect(Rect2(0, size.y - 26, size.x, 26), Color(0.02, 0.03, 0.06, 0.92))
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, size.y - 8), _name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
			Color("ffe9b0") if hot else Color(0.85, 0.88, 0.95))
		var border := Color(0.3, 0.35, 0.48)
		if who.size() == 1:
			border = PLAYER_COLORS[who[0]]
		elif who.size() == 2:
			border = Color("c48cff")
		draw_rect(r, border, false, 3.0 if hot else 1.0)
		# Player tokens.
		for pid in who:
			var tag := Rect2(4 if pid == 1 else size.x - 34, 4, 30, 18)
			draw_rect(tag, PLAYER_COLORS[pid])
			draw_string(font, tag.position + Vector2(0, 14), "P%d" % pid, HORIZONTAL_ALIGNMENT_CENTER, 30, 13, Color.WHITE)
			if screen.is_ready[pid]:
				draw_rect(r, Color(PLAYER_COLORS[pid], 0.15))


class _PlayerPanel extends Control:
	var screen: CharacterSelectScreen
	var player_id := 1
	var pick: StringName
	var changed_at := -10.0
	var ready_at := -10.0
	var _frames: Dictionary = {}
	var _stats: Dictionary = {}
	var _specials := PackedStringArray()
	var _tagline := ""
	var _portrait: Texture2D

	func set_pick(id: StringName) -> void:
		if id == pick:
			return
		pick = id
		_frames = {} if id == RANDOM else CharacterRoster.showcase(id)
		_stats = {} if id == RANDOM else CharacterSelectScreen.stats_for(id)
		_specials = PackedStringArray() if id == RANDOM else CharacterSelectScreen.specials_text(id)
		_tagline = "Picked when the match starts" if id == RANDOM else CharacterRoster.entry(id).get("tagline", "")
		_portrait = null if id == RANDOM else CharacterRoster.portrait(id)

	func _draw() -> void:
		var t := screen._t
		var accent: Color = PLAYER_COLORS[player_id]
		var locked: bool = screen.is_ready[player_id]
		var left := player_id == 1
		var w := size.x
		var h := size.y
		var slant := 40.0
		var shape := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - slant, h), Vector2(0, h)]) if left \
			else PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(slant, h)])
		draw_colored_polygon(shape, Color(0.02, 0.03, 0.06, 0.82))
		var glow := accent
		glow.a = 0.28 if locked else 0.16
		var clear := accent
		clear.a = 0.0
		var art_side := Rect2(0 if left else w - 300, 0, 300, h)
		draw_polygon(PackedVector2Array([art_side.position, Vector2(art_side.end.x, 0), art_side.end, Vector2(art_side.position.x, h)]),
			PackedColorArray([glow, clear, clear, glow]) if left else PackedColorArray([clear, glow, glow, clear]))
		draw_rect(Rect2(0, 0, w, 4), accent)
		var outline := shape.duplicate()
		outline.append(shape[0])
		draw_polyline(outline, Color(accent, 0.6), 2.0, true)
		# Fighter render: idle loop, victory pose once locked in.
		var since_change := t - changed_at
		var anim := &"victory" if locked and _frames.has(&"victory") else &"idle"
		var frames: Array = _frames.get(anim, [])
		var floor_y := h - 18.0
		var art_cx := 150.0 if left else w - 150.0
		draw_set_transform(Vector2(art_cx, floor_y + 4), 0.0, Vector2(1, 0.22))
		draw_circle(Vector2.ZERO, 110.0, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not frames.is_empty():
			var tex: Texture2D = frames[int(t * 2.5) % frames.size()]
			var max_h := 290.0
			var k := minf(max_h / tex.get_height(), 300.0 / tex.get_width())
			var slide := (1.0 - ease(clampf(since_change / 0.22, 0.0, 1.0), 0.35)) * 60.0 * (-1.0 if left else 1.0)
			var draw_size := tex.get_size() * k
			# Drawn around the render's centre; Player 2 is mirrored to face the middle.
			draw_set_transform(Vector2(art_cx + slide, floor_y), 0.0, Vector2(1.0 if left else -1.0, 1.0))
			var rect := Rect2(Vector2(-draw_size.x / 2.0, -draw_size.y), draw_size)
			var alpha := clampf(since_change / 0.15, 0.0, 1.0)
			draw_texture_rect(tex, rect, false, Color(1, 1, 1, alpha))
			var flash := clampf(1.0 - (t - ready_at) / 0.35, 0.0, 1.0)
			if flash > 0.0 and locked:
				draw_texture_rect(tex, rect, false, Color(1, 1, 1, flash * 0.8))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var font0 := get_theme_default_font()
			draw_string(font0, Vector2(art_cx - 150, floor_y - 100), "?" if pick == RANDOM else "★", HORIZONTAL_ALIGNMENT_CENTER, 300, 140,
				Color(accent, 0.75))
		# Text column.
		var font := get_theme_default_font()
		var tx := 300.0 if left else 56.0
		var tw := 270.0
		draw_rect(Rect2(tx, 22, 38, 22), accent)
		draw_string(font, Vector2(tx, 39), "P%d" % player_id, HORIZONTAL_ALIGNMENT_CENTER, 38, 15, Color.WHITE)
		draw_string(font, Vector2(tx + 48, 39), "READY" if locked else "CHOOSING…", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color("ffd36b") if locked else Color(0.62, 0.68, 0.8))
		var title_text := CharacterSelectScreen.display_name(pick).to_upper()
		var name_size := 36 if title_text.length() <= 12 else 28
		draw_string_outline(font, Vector2(tx, 86), title_text, HORIZONTAL_ALIGNMENT_LEFT, tw + 40, name_size, 8, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(tx, 86), title_text, HORIZONTAL_ALIGNMENT_LEFT, tw + 40, name_size, Color("fff4dc"))
		draw_string(font, Vector2(tx, 110), _tagline, HORIZONTAL_ALIGNMENT_LEFT, tw, 14, Color(accent.lightened(0.35)))
		var y := 134.0
		for key: String in ["POWER", "SPEED", "WEIGHT", "JUMP"]:
			draw_string(font, Vector2(tx, y + 10), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.73, 0.83))
			var bar := Rect2(tx + 64, y, 180, 10)
			draw_rect(bar, Color(1, 1, 1, 0.08))
			if _stats.has(key):
				var fill := screen.stat_fill(key, _stats[key]) * clampf((t - changed_at) / 0.3, 0.0, 1.0)
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), accent)
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, 3)), Color(1, 1, 1, 0.35))
			y += 20.0
		y += 10.0
		for line in _specials:
			draw_string(font, Vector2(tx, y + 12), line, HORIZONTAL_ALIGNMENT_LEFT, tw, 13, Color(0.86, 0.89, 0.96))
			y += 19.0
		# Diagonal READY ribbon over the render.
		if locked:
			var pop := 1.0 + 0.25 * clampf(1.0 - (t - ready_at) / 0.2, 0.0, 1.0)
			draw_set_transform(Vector2(art_cx, h * 0.22), -0.12, Vector2(pop, pop))
			draw_rect(Rect2(-150, -24, 300, 48), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(-150, -20, 300, 40), accent)
			draw_string_outline(font, Vector2(-150, 13), "READY!", HORIZONTAL_ALIGNMENT_CENTER, 300, 32, 6, Color(0, 0, 0, 0.7))
			draw_string(font, Vector2(-150, 13), "READY!", HORIZONTAL_ALIGNMENT_CENTER, 300, 32, Color.WHITE)
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
		draw_string_outline(font, Vector2(0, h / 2.0 + 15), text, HORIZONTAL_ALIGNMENT_CENTER, 1280, 40, 10, Color(0.15, 0.02, 0, 0.9))
		draw_string(font, Vector2(0, h / 2.0 + 15), text, HORIZONTAL_ALIGNMENT_CENTER, 1280, 40, Color(1, 0.97, 0.85, pulse))
