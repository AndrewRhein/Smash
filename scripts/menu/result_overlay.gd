class_name ResultOverlay
extends CanvasLayer
## Post-match choices under the HUD's result banner: Rematch or Main Menu.
## Enter / controller Start still trigger the existing rematch in main.gd;
## Esc / controller B returns to the title screen.

var app: GameApp
var box: HBoxContainer
var rematch_button: Button
var menu_button: Button


func _init(p_app: GameApp) -> void:
	app = p_app
	layer = 25
	var root := Control.new()
	root.theme = MenuStyle.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.position = Vector2(640 - 300, 612)  # bottom: never covers the stage or HUD banner
	box.size = Vector2(600, 56)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(box)
	rematch_button = MenuStyle.button("Rematch", _on_rematch, 260)
	menu_button = MenuStyle.button("Main Menu", func() -> void: app.show_title(), 260)
	box.add_child(rematch_button)
	box.add_child(menu_button)
	box.visible = false


func bind(match_controller: MatchController) -> void:
	match_controller.match_ended.connect(func(_w: int) -> void: show_choices())
	match_controller.match_state_changed.connect(func(state: MatchController.MatchState) -> void:
		if state != MatchController.MatchState.RESULT:
			hide_choices())


func show_choices() -> void:
	box.visible = true
	rematch_button.grab_focus()


func hide_choices() -> void:
	# Release focus so no menu button holds keyboard focus during play.
	if rematch_button.has_focus() or menu_button.has_focus():
		rematch_button.get_viewport().gui_release_focus()
	box.visible = false


func _on_rematch() -> void:
	if app.match_controller != null:
		app.match_controller.rematch()


func _unhandled_input(event: InputEvent) -> void:
	if box.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		app.show_title()
