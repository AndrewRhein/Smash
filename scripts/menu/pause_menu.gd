class_name PauseMenu
extends CanvasLayer
## In-match pause (Esc / controller Start) during the countdown or fight.
## Pausing uses SceneTree.paused, which freezes the match, fighters, effects
## and HUD together; this layer keeps processing (PROCESS_MODE_ALWAYS).
## Start in the RESULT state is left to the rematch handler in main.gd.

var app: GameApp
var panel: MenuScreen
var controls: ControlsScreen
var is_open: bool = false


func _init(p_app: GameApp) -> void:
	app = p_app
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		if event.is_action_pressed(InputSetup.ACTION_PAUSE) or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			if controls != null:
				_close_controls()
			else:
				resume()
		return
	if event.is_action_pressed(InputSetup.ACTION_PAUSE) and _can_pause():
		get_viewport().set_input_as_handled()
		open()


func _can_pause() -> bool:
	var m := app.match_controller
	return m != null and (m.state == MatchController.MatchState.COUNTDOWN or m.state == MatchController.MatchState.PLAYING)


func open() -> void:
	if is_open:
		return
	is_open = true
	app.set_paused(true)
	panel = _PausePanel.new(app, self)
	add_child(panel)


func resume() -> void:
	if not is_open:
		return
	_close_controls()
	is_open = false
	if panel != null:
		panel.queue_free()
		panel = null
	app.set_paused(false)


func _show_controls() -> void:
	panel.visible = false
	controls = ControlsScreen.new(app, _close_controls, true)
	add_child(controls)


func _close_controls() -> void:
	if controls == null:
		return
	controls.queue_free()
	controls = null
	if panel != null:
		panel.visible = true
		panel.focus_first()


class _PausePanel extends MenuScreen:
	var menu: PauseMenu

	func _init(p_app: GameApp, p_menu: PauseMenu) -> void:
		menu = p_menu
		super(p_app, true)

	func build() -> void:
		column.add_child(MenuStyle.label("PAUSED", 52, MenuStyle.GOLD))
		add_button("Resume", func() -> void: menu.resume())
		add_button("Restart Match", func() -> void: app.restart_match())
		add_button("Controls", func() -> void: menu._show_controls())
		add_button("Main Menu", func() -> void: app.show_title())
