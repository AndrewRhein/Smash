class_name SettingsScreen
extends MenuScreen
## Settings saved to user://settings.cfg as soon as they change.

var fullscreen_button: CycleButton
var hitbox_button: CycleButton
var tap_jump_button: CycleButton
var volume_buttons: Dictionary = {}


func build() -> void:
	column.add_child(MenuStyle.label("SETTINGS", 44, MenuStyle.GOLD))
	var s := app.settings
	fullscreen_button = CycleButton.new("Fullscreen", ["Off", "On"], 1 if s.fullscreen else 0)
	fullscreen_button.value_changed.connect(func(i: int) -> void:
		s.fullscreen = i == 1
		s.apply_window()
		s.save_to_disk())
	add_focusable(fullscreen_button)
	hitbox_button = CycleButton.new("Hitboxes at match start", ["Off", "On"], 1 if s.show_hitboxes else 0)
	hitbox_button.value_changed.connect(func(i: int) -> void:
		s.show_hitboxes = i == 1
		s.save_to_disk())
	add_focusable(hitbox_button)
	column.add_child(MenuStyle.label("F1 toggles hitboxes during a match either way.", 16, MenuStyle.MUTED))
	tap_jump_button = CycleButton.new("Tap jump (stick up jumps)", ["Off", "On"], 1 if s.tap_jump else 0)
	tap_jump_button.value_changed.connect(func(i: int) -> void:
		s.tap_jump = i == 1
		s.apply_controls()
		s.save_to_disk())
	add_focusable(tap_jump_button)
	for bus in [[&"Master", "Volume"], [&"Music", "Music"], [&"SFX", "Effects"], [&"Voice", "Voices"]]:
		var b := CycleButton.new(bus[1], range(0, 11), s.volumes[bus[0]])
		b.value_changed.connect(func(i: int) -> void:
			s.volumes[bus[0]] = i
			s.apply_audio()
			s.save_to_disk()
			app.audio.play_ui("move"))
		add_focusable(b)
		volume_buttons[bus[0]] = b
	add_button("Controllers", app.show_controllers)
	add_button("Back", app.show_title)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not is_queued_for_deletion() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		app.show_title()
