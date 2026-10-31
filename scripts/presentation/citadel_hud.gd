extends "res://scripts/presentation/placeholder_hud.gd"
## Match HUD: a card per player (portrait, name, big damage %, stock icons),
## an animated 3-2-1-GO countdown and a result banner. Presentation only; it
## reads the existing fighter/match signals.

const PLAYER_COLORS := {1: Color("4aa8ff"), 2: Color("ff5d5d"), 3: Color("ffd24a"), 4: Color("5ee08a")}
const CARD_SIZE := Vector2(330, 104)
const DAMAGE_WHITE := Color("fbf3e4")
const DAMAGE_RAMP := [Color("fbf3e4"), Color("ffe27a"), Color("ff9a3c"), Color("ff4a3a"), Color("b3122e")]

var damage_labels: Dictionary = {}
var stock_labels: Dictionary = {}
var name_labels: Dictionary = {}
var _cards: Dictionary = {}
var _portraits: Dictionary = {}
var _stock_boxes: Dictionary = {}
var _pop: Dictionary = {}          # player -> 0..1 pop amount after damage
var _last_damage: Dictionary = {}
var _big: Label                    # countdown / GO / GAME!
var _big_t := 10.0
var _big_text := ""
var _last_count := -1
var _t := 0.0
var _footer: Label
var _hint: Label


func _ready() -> void:
	_status = _label(Vector2(440, 22), 16, Color("e9d6a6"))
	_status.size = Vector2(400, 24)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(Vector2(440, 46), 11, Color("8ea2bd"))
	subtitle.size = Vector2(400, 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.text = "T H E   T W I L I G H T   C I T A D E L"
	_big = _label(Vector2(0, 250), 120, Color("ffe9a8"))
	_big.size = Vector2(1280, 170)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.pivot_offset = Vector2(640, 85)
	_big.add_theme_constant_override("outline_size", 18)
	_big.add_theme_color_override("font_outline_color", Color("1a0d05"))
	_big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_big.add_theme_constant_override("shadow_offset_y", 6)
	_result = _label(Vector2(140, 430), 22, Color("ead5a4"))
	_result.size = Vector2(1000, 60)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer = _label(Vector2(30, 690), 12, Color(0.65, 0.71, 0.8, 0.8))
	_footer.text = "P1  A/D · W jump · F attack · R heavy · G special · T shield        P2  ←/→ · ↑ jump · K attack · I heavy · L special · O shield"
	_hint = _label(Vector2(1080, 690), 12, Color(0.65, 0.71, 0.8, 0.8))
	_hint.text = "ESC Pause   F1 Hitboxes"


## Cards: 1-2 players sit in the top corners (P2 mirrored); 3-4 players get a
## Smash-style row along the bottom of the screen.
func _make_card(player: int, index: int, count: int) -> void:
	var card_size := CARD_SIZE if count <= 2 else Vector2(296, 96)
	var mirrored := count <= 2 and index == 1
	var origin := Vector2(24 if index == 0 else 1280 - 24 - card_size.x, 18)
	if count > 2:
		var row_width := count * card_size.x + (count - 1) * 12.0
		origin = Vector2((1280.0 - row_width) / 2.0 + index * (card_size.x + 12.0), 720.0 - card_size.y - 30.0)
		_footer_visible(false)
	var card := _Card.new()
	card.accent = PLAYER_COLORS.get(player, Color.WHITE)
	card.mirrored = mirrored
	card.position = origin
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	_cards[player] = card
	var art := card_size.y - 28.0
	var portrait := TextureRect.new()
	portrait.position = Vector2(14.0 if not mirrored else card_size.x - 14.0 - art, 14)
	portrait.size = Vector2(art, art)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.flip_h = mirrored
	card.add_child(portrait)
	_portraits[player] = portrait
	var text_x := art + 24.0 if not mirrored else 16.0
	var text_w := card_size.x - art - 40.0
	var name_label := _card_label(card, Vector2(text_x, 8), 14 if count > 2 else 15, (PLAYER_COLORS.get(player, Color.WHITE) as Color).lightened(0.35), mirrored, text_w)
	name_labels[player] = name_label
	var damage_label := _card_label(card, Vector2(text_x, 22), 42 if count > 2 else 46, DAMAGE_WHITE, mirrored, text_w)
	damage_label.add_theme_constant_override("outline_size", 10)
	damage_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	damage_label.add_theme_constant_override("shadow_offset_y", 3)
	damage_label.pivot_offset = Vector2(text_w if mirrored else 0.0, 34)
	damage_labels[player] = damage_label
	var stocks := HBoxContainer.new()
	stocks.position = Vector2(text_x, card_size.y - 24.0)
	stocks.size = Vector2(text_w, 18)
	stocks.add_theme_constant_override("separation", 4)
	stocks.alignment = BoxContainer.ALIGNMENT_END if mirrored else BoxContainer.ALIGNMENT_BEGIN
	card.add_child(stocks)
	_stock_boxes[player] = stocks
	var stock_text := _card_label(card, Vector2(text_x, card_size.y - 24.0), 12, Color("d8c999"), mirrored, text_w)
	stock_text.visible = false  # kept for tests/tools that read the stock count
	stock_labels[player] = stock_text


func _footer_visible(value: bool) -> void:
	for node in [_footer, _hint]:
		if node != null:
			node.visible = value


func _card_label(card: Control, pos: Vector2, font_size: int, color: Color, mirrored: bool, width: float = 214.0) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, font_size + 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	l.add_theme_constant_override("outline_size", 4)
	card.add_child(l)
	return l


func _on_fighter_spawned(fighter: Fighter) -> void:
	var player := fighter.player_id
	if not _cards.has(player):
		_make_card(player, maxi(_match.fighters.find(fighter), 0), maxi(_match.characters.size(), 1))
	var tag := "P%d" % player
	if fighter.input is CpuInput:
		tag = "CPU %d" % (fighter.input as CpuInput).level
	name_labels[player].text = "%s  /  %s" % [tag, fighter.character.display_name.to_upper()]
	_portraits[player].texture = CharacterRoster.portrait(fighter.character.id)
	_last_damage[player] = fighter.damage
	var update := func(_value: Variant = null) -> void:
		_refresh_player(fighter)
	fighter.damage_changed.connect(update)
	fighter.stocks_changed.connect(update)
	update.call()


func _refresh_player(fighter: Fighter) -> void:
	var player := fighter.player_id
	var damage_label: Label = damage_labels[player]
	damage_label.text = "%d%%" % roundi(fighter.damage)
	damage_label.add_theme_color_override("font_color", damage_color(fighter.damage))
	if fighter.damage > _last_damage.get(player, 0.0):
		_pop[player] = clampf((fighter.damage - _last_damage.get(player, 0.0)) / 14.0, 0.35, 1.0)
	_last_damage[player] = fighter.damage
	stock_labels[player].text = "%d LIVES" % fighter.stocks
	var box: HBoxContainer = _stock_boxes[player]
	for child in box.get_children():
		child.queue_free()
	for i in fighter.stocks:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _portraits[player].texture
		icon.flip_h = (_cards[player] as _Card).mirrored
		box.add_child(icon)
	_cards[player].dimmed = fighter.stocks == 0


## White -> yellow -> orange -> red -> deep red as damage climbs (0..180%).
static func damage_color(damage: float) -> Color:
	var k := clampf(damage / 180.0, 0.0, 1.0) * (DAMAGE_RAMP.size() - 1)
	var i := mini(int(k), DAMAGE_RAMP.size() - 2)
	return (DAMAGE_RAMP[i] as Color).lerp(DAMAGE_RAMP[i + 1], k - i)


func _process(delta: float) -> void:
	_t += delta
	for player: int in _pop.keys():
		var label: Label = damage_labels[player]
		var amount: float = _pop[player]
		label.scale = Vector2.ONE * (1.0 + 0.45 * amount)
		label.rotation = sin(_t * 70.0) * 0.06 * amount
		_pop[player] = maxf(0.0, amount - delta * 4.0)
	if _match == null:
		return
	if _match.state == MatchController.MatchState.COUNTDOWN:
		var count := ceili(_match.countdown_remaining / 30.0)
		if count != _last_count and count > 0:
			_last_count = count
			_show_big(str(count), Color("ffe9a8"))
	_big_t += delta
	var k := clampf(_big_t / 0.7, 0.0, 1.0)
	_big.text = _big_text
	_big.scale = Vector2.ONE * lerpf(1.6, 1.0, ease(minf(_big_t / 0.18, 1.0), 0.4))
	_big.modulate.a = 1.0 if _big_text == "GAME!" else (1.0 - k * k)


func _show_big(text: String, color: Color) -> void:
	_big_text = text
	_big_t = 0.0
	_big.add_theme_color_override("font_color", color)


func _refresh_status() -> void:
	_result.text = ""
	match _match.state:
		MatchController.MatchState.COUNTDOWN:
			_status.text = "GET READY"
			_last_count = -1
		MatchController.MatchState.PLAYING:
			_status.text = "REALMS RUMBLE"
			_show_big("GO!", Color("8ef08a"))
		MatchController.MatchState.RESULT:
			_status.text = "MATCH OVER"
			_show_big("GAME!", Color("ffd36b"))
		_:
			_status.text = ""


## Slanted card backdrop in the player's colour.
class _Card extends Control:
	var accent := Color.WHITE
	var mirrored := false
	var dimmed := false:
		set(value):
			dimmed = value
			modulate = Color(1, 1, 1, 0.45) if value else Color.WHITE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var slant := 22.0
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - slant, h), Vector2(0, h)])
		if mirrored:
			pts = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(slant, h)])
		draw_colored_polygon(pts, Color(0.02, 0.035, 0.07, 0.9))
		# Accent glow band along the portrait side.
		var band_x := 0.0 if not mirrored else w - 104.0
		var band := Rect2(band_x, 0, 104, h)
		var c1 := accent
		c1.a = 0.38
		var c2 := accent
		c2.a = 0.0
		var cols := PackedColorArray([c1, c2, c2, c1]) if not mirrored else PackedColorArray([c2, c1, c1, c2])
		draw_polygon(PackedVector2Array([band.position, Vector2(band.end.x, band.position.y), band.end, Vector2(band.position.x, band.end.y)]), cols)
		# Top accent line and outline.
		draw_rect(Rect2(0, 0, w, 3), accent)
		pts.append(pts[0])
		draw_polyline(pts, Color(accent.r, accent.g, accent.b, 0.55), 1.5, true)
		# Portrait frame.
		var art := h - 28.0
		var px := 14.0 if not mirrored else w - 14.0 - art
		draw_rect(Rect2(px - 2, 12, art + 4, art + 4), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(px - 2, 12, art + 4, art + 4), accent, false, 2.0)
