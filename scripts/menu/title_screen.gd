class_name TitleScreen
extends MenuScreen
## Title / main menu: start a match, pick stock count, controls, settings, quit.

var start_button: Button
var stocks_button: CycleButton


## Portraits of every roster character that has one.
static func portraits() -> Array:
	return CharacterRoster.ids().map(func(id: StringName) -> String: return CharacterRoster.portrait_path(id))


func build() -> void:
	# Logo across the top, menu on the left, the fighter lineup on the right.
	var center := column.get_parent() as Control
	center.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	center.offset_left = 70
	center.offset_right = 470
	center.offset_top = 200
	center.offset_bottom = -40
	column.add_theme_constant_override("separation", 10)
	var lineup := _Lineup.new()
	lineup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lineup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lineup)
	move_child(lineup, 1)  # behind the menu, in front of the backdrop
	start_button = add_button("Start Match", app.show_character_select)
	var stock_options := range(GameSettings.MIN_STOCKS, GameSettings.MAX_STOCKS + 1)
	stocks_button = CycleButton.new("Stocks", stock_options, stock_options.find(app.settings.stocks))
	stocks_button.value_changed.connect(func(_i: int) -> void:
		app.settings.stocks = stocks_button.value()
		app.settings.save_to_disk())
	add_focusable(stocks_button)
	add_button("Controls", func() -> void: app.show_controls(app.show_title))
	add_button("Settings", app.show_settings)
	if GameApp.has_art_gallery():
		add_button("Art Gallery", app.show_art_gallery)
	if not OS.has_feature("web"):
		add_button("Quit", app.quit_game)
	var hint := MenuStyle.label("D-pad / arrows  ·  A / Enter select  ·  ◀ ▶ change", 14, MenuStyle.MUTED)
	column.add_child(hint)
	for child in column.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(340, 50)


## Logo + every fighter with sprite art standing in a lineup.
class _Lineup extends Control:
	var _renders: Array = []   # [frames Array, x, y, scale, phase]
	var _t := 0.0

	func _ready() -> void:
		var ids := CharacterRoster.ids().filter(func(id: StringName) -> bool:
			return not CharacterRoster.showcase(id).get(&"idle", []).is_empty())
		# Two staggered rows: back row smaller and higher.
		var n := ids.size()
		for i in n:
			var back := i % 2 == 1
			var x := 570.0 + (610.0 / maxf(1.0, n - 1)) * i
			_renders.append([CharacterRoster.showcase(ids[i])[&"idle"], x, 600.0 if back else 690.0, 0.95 if back else 1.15, i * 0.37])
		_renders.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var font := get_theme_default_font()
		# Logo with layered outline and a soft glow.
		var title := "REALMS RUMBLE"
		var pos := Vector2(0, 128)
		var pulse := 0.5 + 0.5 * sin(_t * 1.6)
		for k in 3:
			draw_string_outline(font, pos, title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 96, 26 - k * 7,
				Color(1.0, 0.6, 0.15, 0.08 + 0.05 * pulse) if k == 0 else Color(0.12, 0.05, 0.0, 0.9))
		draw_string(font, pos + Vector2(0, 4), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 96, Color(0.55, 0.25, 0.05))
		draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 96, Color("ffd36b"))
		draw_string(font, pos + Vector2(0, -38), title, HORIZONTAL_ALIGNMENT_CENTER, 1280, 96, Color(1, 1, 1, 0.0))
		var tagline := "%d  FIGHTERS   ·   LOCAL  VERSUS   ·   ONE  CITADEL" % CharacterRoster.ENTRIES.size()
		draw_string(font, Vector2(0, 166), tagline, HORIZONTAL_ALIGNMENT_CENTER, 1280, 16, Color(0.8, 0.84, 0.95, 0.85))
		draw_rect(Rect2(440, 178, 400, 2), Color(1.0, 0.83, 0.42, 0.6))
		# Fighters, gently breathing, with ground shadows.
		for r in _renders:
			var frames: Array = r[0]
			var tex: Texture2D = frames[int(_t * 2.0 + r[4] * 3.0) % frames.size()]
			var k: float = r[3] * 300.0 / maxf(tex.get_height(), 1.0) * 0.82
			var size := tex.get_size() * k
			var bob := sin(_t * 1.8 + r[4] * 4.0) * 2.0
			var feet := Vector2(r[1], r[2])
			draw_set_transform(feet + Vector2(0, 2), 0.0, Vector2(1, 0.2))
			draw_circle(Vector2.ZERO, size.x * 0.42, Color(0, 0, 0, 0.45))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var shade := 0.75 if r[2] < 650.0 else 1.0
			draw_texture_rect(tex, Rect2(feet - Vector2(size.x / 2.0, size.y + bob), size), false, Color(shade, shade, shade))
