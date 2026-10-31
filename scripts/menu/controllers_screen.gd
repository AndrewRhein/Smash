class_name ControllersScreen
extends MenuScreen
## Shows connected controllers and which player each one drives. Players can
## pick a pad with ◀ ▶ (or "Keyboard only"), swap players, and see a live
## "pressing" indicator to identify which physical pad is which.
## Rebuilds itself when controllers are plugged in or removed.

var back_action: Callable
var player_buttons: Dictionary = {}   # player_id -> CycleButton
var pad_labels: Dictionary = {}       # device -> Label
var _pads: Array = []
var _rebuilding: bool = false


func _init(p_app: GameApp, p_back: Callable) -> void:
	back_action = p_back
	super(p_app)


func build() -> void:
	_pads = Input.get_connected_joypads()
	column.add_child(MenuStyle.label("CONTROLLERS", 44, MenuStyle.GOLD))
	var hint := "No controllers detected - plug one in at any time." if _pads.is_empty() \
		else "Press any button on a pad to see which one it is."
	column.add_child(MenuStyle.label(hint, 18, MenuStyle.MUTED))
	for device: int in _pads:
		var name := Input.get_joy_name(device)
		var l := MenuStyle.label("Pad %d: %s" % [device, name if name != "" else "Controller"], 18)
		pad_labels[device] = l
		column.add_child(l)
	var options: Array = ["Keyboard only"]
	for device: int in _pads:
		options.append("Pad %d" % device)
	for player_id in range(1, ControllerAssignment.PLAYER_COUNT + 1):
		var current := ControllerAssignment.device_for(player_id)
		var index := 0 if current < 0 or not _pads.has(current) else _pads.find(current) + 1
		var b := CycleButton.new("Player %d" % player_id, options, index)
		b.custom_minimum_size = Vector2(420, 46)
		b.value_changed.connect(_on_player_changed.bind(player_id))
		player_buttons[player_id] = b
		add_focusable(b)
	add_button("Swap Players", _on_swap)
	column.add_child(MenuStyle.label("Keyboard controls also work for Players 1 and 2. A controller joins its port by pressing A on the character select.", 16, MenuStyle.MUTED))
	add_button("Back", back_action)


func _on_player_changed(index: int, player_id: int) -> void:
	ControllerAssignment.assign(player_id, -1 if index == 0 else int(_pads[index - 1]))
	_sync_buttons()


func _on_swap() -> void:
	ControllerAssignment.swap_players()
	_sync_buttons()


## Reflect current assignments (assigning one player can move the other).
func _sync_buttons() -> void:
	for player_id: int in player_buttons:
		var b: CycleButton = player_buttons[player_id]
		var current := ControllerAssignment.device_for(player_id)
		b.index = 0 if current < 0 or not _pads.has(current) else _pads.find(current) + 1
		b._refresh()


func _process(_delta: float) -> void:
	if _rebuilding:
		return
	if Input.get_connected_joypads() != _pads:
		# Hot-plug: rebuild the screen so the lists stay accurate.
		_rebuilding = true
		app.show_controllers.call_deferred()
		return
	for device: int in pad_labels:
		var active := false
		for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
				JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_START,
				JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			if Input.is_joy_button_pressed(device, button):
				active = true
		var owner := "unused"
		for player_id in range(1, ControllerAssignment.PLAYER_COUNT + 1):
			if ControllerAssignment.device_for(player_id) == device:
				owner = "Player %d" % player_id
		var l: Label = pad_labels[device]
		var name := Input.get_joy_name(device)
		l.text = "%sPad %d: %s  →  %s" % ["● " if active else "", device, name if name != "" else "Controller", owner]
		l.add_theme_color_override("font_color", MenuStyle.GOLD if active else MenuStyle.TEXT)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not is_queued_for_deletion() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_action.call()
