class_name TitleScreen
extends MenuScreen
## Title / main menu: start a match, pick stock count, controls, settings, quit.

var start_button: Button
var stocks_button: CycleButton


## Portraits of every roster character that has one.
static func portraits() -> Array:
	return CharacterRoster.ids().map(func(id: StringName) -> String: return CharacterRoster.portrait_path(id))


func build() -> void:
	# Keep both portraits and the navigation hint within the 720px viewport.
	column.add_theme_constant_override("separation", 10)
	var portraits := _portrait_row()
	if portraits != null:
		column.add_child(portraits)
	column.add_child(MenuStyle.label("REALMS RUMBLE", 64, MenuStyle.GOLD))
	column.add_child(MenuStyle.label("%d fighters · local versus" % CharacterRoster.ENTRIES.size(), 24, MenuStyle.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	column.add_child(spacer)
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
	column.add_child(MenuStyle.label("Arrows / D-pad to move  •  Enter / A to select  •  ◀ ▶ to change", 16, MenuStyle.MUTED))


## Character portraits from the art pipeline, shown only if they exist.
func _portrait_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	for path: String in portraits():
		if not ResourceLoader.exists(path):
			continue
		var image := TextureRect.new()
		image.texture = load(path)
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.custom_minimum_size = Vector2(64, 64)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(image)
	return row if row.get_child_count() > 0 else null
