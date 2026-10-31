class_name TitleScreen
extends MenuScreen
## Title / main menu: start a match, pick stock count, controls, settings, quit.

var start_button: Button
var stocks_button: CycleButton


func build() -> void:
	column.add_child(MenuStyle.label("REALMS RUMBLE", 64, MenuStyle.GOLD))
	column.add_child(MenuStyle.label("Gandalf  vs.  Darth Vader", 24, MenuStyle.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)
	start_button = add_button("Start Match", app.start_match)
	var stock_options := range(GameSettings.MIN_STOCKS, GameSettings.MAX_STOCKS + 1)
	stocks_button = CycleButton.new("Stocks", stock_options, stock_options.find(app.settings.stocks))
	stocks_button.value_changed.connect(func(_i: int) -> void:
		app.settings.stocks = stocks_button.value()
		app.settings.save_to_disk())
	add_focusable(stocks_button)
	add_button("Controls", func() -> void: app.show_controls(app.show_title))
	add_button("Settings", app.show_settings)
	if not OS.has_feature("web"):
		add_button("Quit", app.quit_game)
	column.add_child(MenuStyle.label("Arrows / D-pad to move  •  Enter / A to select  •  ◀ ▶ to change", 16, MenuStyle.MUTED))
