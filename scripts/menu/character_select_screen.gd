class_name CharacterSelectScreen
extends MenuScreen
## Smash-style character select. Both players pick at the same time with their
## own controls (own controller or own half of the keyboard):
##   left/right  move your cursor        A / F / K  lock in
##   B / G / L   un-ready (or leave when nobody is ready)
##   Start / Enter  fight once both are ready (Enter also locks in the next
##   player, for one-keyboard play)      Esc  back to the title
## The roster comes from CharacterRoster, so new characters appear automatically.

const RANDOM := &"random"
const PLAYER_COLORS := {1: Color(0.35, 0.75, 1.0), 2: Color(1.0, 0.36, 0.32)}

var inputs: Array[PlayerInput] = []
var options: Array = []                 # roster ids + RANDOM
var cursor: Dictionary = {1: 0, 2: 1}   # player_id -> option index
var is_ready: Dictionary = {1: false, 2: false}
var cards: Array[PanelContainer] = []
var _player_name: Dictionary = {}
var _player_detail: Dictionary = {}
var _player_portrait: Dictionary = {}
var _player_status: Dictionary = {}
var _prompt: Label


func build() -> void:
	options = CharacterRoster.ids()
	options.append(RANDOM)
	for player_id in [1, 2]:
		var pick: StringName = app.settings.last_pick(player_id)
		cursor[player_id] = maxi(options.find(pick), 0)
		var player_input := PlayerInput.new(player_id)
		player_input.reset_edges()  # the button that opened this screen is not a pick
		inputs.append(player_input)
	column.add_theme_constant_override("separation", 14)
	column.add_child(MenuStyle.label("CHOOSE YOUR FIGHTER", 46, MenuStyle.GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	for id: StringName in options:
		var card := _make_card(id)
		cards.append(card)
		row.add_child(card)
	var players := HBoxContainer.new()
	players.alignment = BoxContainer.ALIGNMENT_CENTER
	players.add_theme_constant_override("separation", 80)
	column.add_child(players)
	for player_id in [1, 2]:
		players.add_child(_make_player_panel(player_id))
	_prompt = MenuStyle.label("", 22, MenuStyle.GOLD)
	column.add_child(_prompt)
	column.add_child(MenuStyle.label(
		"Move: stick / D-pad · A/D · ←/→     Lock in: A · F · K     Back: B · G · L     Fight: Start / Enter     Menu: Esc",
		15, MenuStyle.MUTED))
	_refresh()


func _make_card(id: StringName) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 170)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(box)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(96, 96)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if id != RANDOM:
		tex.texture = CharacterRoster.portrait(id)
	box.add_child(tex)
	if tex.texture == null:
		box.remove_child(tex)
		tex.queue_free()
		box.add_child(MenuStyle.label("?" if id == RANDOM else _display_name(id).substr(0, 1), 64, MenuStyle.MUTED))
	box.add_child(MenuStyle.label("Random" if id == RANDOM else _display_name(id), 18))
	return card


func _make_player_panel(player_id: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 210)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := MenuStyle.label("PLAYER %d" % player_id, 20, PLAYER_COLORS[player_id])
	box.add_child(head)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	box.add_child(line)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(110, 110)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.add_child(tex)
	var text := VBoxContainer.new()
	line.add_child(text)
	var name_label := MenuStyle.label("", 26, MenuStyle.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(name_label)
	var detail := MenuStyle.label("", 15, MenuStyle.MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(detail)
	var status := MenuStyle.label("", 20, MenuStyle.MUTED)
	box.add_child(status)
	_player_portrait[player_id] = tex
	_player_name[player_id] = name_label
	_player_detail[player_id] = detail
	_player_status[player_id] = status
	return panel


# --- Input ----------------------------------------------------------------------
func _process(_delta: float) -> void:
	if is_queued_for_deletion():
		return
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
		elif not is_ready[pid] and (frame.is_pressed(&"left") or frame.is_pressed(&"right")):
			move_cursor(pid, -1 if frame.is_pressed(&"left") else 1)


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


func move_cursor(player_id: int, step: int) -> void:
	cursor[player_id] = wrapi(cursor[player_id] + step, 0, options.size())
	if app.audio != null:
		app.audio.play_ui("move")
	_refresh()


func set_ready(player_id: int, value: bool) -> void:
	if app.audio != null and is_ready[player_id] != value:
		app.audio.play_ui("confirm" if value else "back")
	is_ready[player_id] = value
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


# --- View -------------------------------------------------------------------------
func _refresh() -> void:
	for i in cards.size():
		var border := Color(0.25, 0.3, 0.42)
		var width := 2
		var who: Array = []
		for player_id in [1, 2]:
			if cursor[player_id] == i:
				who.append(player_id)
		if who.size() == 1:
			border = PLAYER_COLORS[who[0]]
			width = 4
		elif who.size() == 2:
			border = Color(0.85, 0.55, 1.0)  # both players on the same card
			width = 5
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.1, 0.12, 0.2) if who.is_empty() else Color(0.16, 0.18, 0.3)
		box.border_color = border
		box.set_border_width_all(width)
		box.set_corner_radius_all(6)
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		cards[i].add_theme_stylebox_override("panel", box)
	for player_id in [1, 2]:
		var id: StringName = options[cursor[player_id]]
		_player_portrait[player_id].texture = null if id == RANDOM else CharacterRoster.portrait(id)
		_player_name[player_id].text = "Random" if id == RANDOM else _display_name(id)
		_player_detail[player_id].text = "Picked when the match starts." if id == RANDOM else _details(id)
		var status: Label = _player_status[player_id]
		status.text = "READY!" if is_ready[player_id] else "Choose…"
		status.add_theme_color_override("font_color", MenuStyle.GOLD if is_ready[player_id] else MenuStyle.MUTED)
	if _prompt != null:
		_prompt.text = "Press Start / Enter to fight!" if both_ready() else ""


func _display_name(id: StringName) -> String:
	var data := CharacterRoster.load_character(id)
	return data.display_name if data != null else String(id)


func _details(id: StringName) -> String:
	var data := CharacterRoster.load_character(id)
	var e := CharacterRoster.entry(id)
	var lines := PackedStringArray([e.get("tagline", "")])
	for pair in [["B", data.neutral_special], ["Side B", data.side_special], ["Up B", data.up_special], ["Down B", data.down_special]]:
		var move := data.get_move(pair[1])
		if move != null:
			lines.append("%s: %s" % [pair[0], move.label()])
	if e.get("art", "") == "placeholder":
		lines.append("(placeholder art)")
	return "\n".join(lines)
