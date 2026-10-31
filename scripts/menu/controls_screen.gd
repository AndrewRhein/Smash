class_name ControlsScreen
extends MenuScreen
## Read-only controls reference generated from the live InputMap, so it always
## matches the actual bindings (including any later overrides).

const JOY_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
}
const ROWS := [
	["Move left / right", [&"left", &"right"]],
	["Jump (hold = higher)", [&"jump"]],
	["Down: fast fall / drop through", [&"down"]],
	["Aim up (lightning, Force push)", [&"up"]],
	["Light attack", [&"light"]],
	["Heavy attack", [&"heavy"]],
	["Special 1  (Lightning / Force push)", [&"special_1"]],
	["Special 2  (Fireball / Force choke)", [&"special_2"]],
	["Special 3  (Magic push / Force guard)", [&"special_3"]],
]

var back_action: Callable
var back_button: Button


func _init(p_app: GameApp, p_back: Callable, p_overlay: bool = false) -> void:
	back_action = p_back
	super(p_app, p_overlay)


func build() -> void:
	column.add_child(MenuStyle.label("CONTROLS", 44, MenuStyle.GOLD))
	var panel := PanelContainer.new()
	column.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	for header in ["Action", "Player 1 (Gandalf)", "Player 2 (Vader)", "Controller"]:
		grid.add_child(_cell(header, MenuStyle.GOLD))
	for row: Array in ROWS:
		grid.add_child(_cell(row[0], MenuStyle.TEXT, true))
		grid.add_child(_cell(_keys_for(1, row[1])))
		grid.add_child(_cell(_keys_for(2, row[1])))
		grid.add_child(_cell(_joy_for(row[1])))
	grid.add_child(_cell("Pause", MenuStyle.TEXT, true))
	grid.add_child(_cell(_action_keys(InputSetup.ACTION_PAUSE)))
	grid.add_child(_cell(_action_keys(InputSetup.ACTION_PAUSE)))
	grid.add_child(_cell("Start"))
	grid.add_child(_cell("Rematch (after a match)", MenuStyle.TEXT, true))
	grid.add_child(_cell(_action_keys(InputSetup.ACTION_REMATCH)))
	grid.add_child(_cell(""))
	grid.add_child(_cell("Start"))
	grid.add_child(_cell("Hitbox debug view", MenuStyle.TEXT, true))
	grid.add_child(_cell(_action_keys(InputSetup.ACTION_DEBUG_HITBOXES)))
	grid.add_child(_cell(""))
	grid.add_child(_cell(""))
	column.add_child(MenuStyle.label("Controllers: first connected = Player 1, second = Player 2.", 16, MenuStyle.MUTED))
	back_button = add_button("Back", back_action)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not is_queued_for_deletion() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_action.call()


func _cell(text: String, color: Color = MenuStyle.MUTED, left: bool = false) -> Label:
	var l := MenuStyle.label(text, 18, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_CENTER
	return l


static func key_names(action: StringName) -> PackedStringArray:
	var names := PackedStringArray()
	if not InputMap.has_action(action):
		return names
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			var n := OS.get_keycode_string(code)
			if not names.has(n):
				names.append(n)
	return names


func _keys_for(player_id: int, buttons: Array) -> String:
	var parts := PackedStringArray()
	for b: StringName in buttons:
		parts.append_array(key_names(PlayerInput.action_name(player_id, b)))
	return " / ".join(parts)


func _action_keys(action: StringName) -> String:
	return " / ".join(key_names(action))


func _joy_for(buttons: Array) -> String:
	var parts := PackedStringArray()
	var stick := false
	for b: StringName in buttons:
		var action := PlayerInput.action_name(1, b)
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and JOY_NAMES.has(ev.button_index):
				var n: String = JOY_NAMES[ev.button_index]
				if not n.begins_with("D-pad") and not parts.has(n):
					parts.append(n)
			elif ev is InputEventJoypadMotion:
				stick = true
	if stick:
		parts.insert(0, "Left stick / D-pad")
	return " / ".join(parts)
