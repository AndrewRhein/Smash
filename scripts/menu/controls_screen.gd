class_name ControlsScreen
extends MenuScreen
## Controls reference. Keyboard keys come from the live InputMap; controller
## buttons from InputSetup.JOY_BUTTONS, so the table always matches the game.

const JOY_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "View",
}
## [action label, keyboard buttons (or "" for a combo text), controller text]
const ROWS := [
	["Move / walk (tilt) / run", [&"left", &"right"], "Left stick / D-pad"],
	["Jump  (again in the air = double jump)", [&"jump"], "X / Y  (or stick up: tap jump)"],
	["Attack", [&"light"], "A"],
	["Heavy (smash) attack", [&"heavy"], "RB  or  right stick (any direction)"],
	["Special  — neutral / side / up / down", [&"special"], "B + stick direction"],
	["Up special = recovery (then helpless)", ["up", "special"], "Up + B"],
	["Shield (hold)", [&"shield"], "LB / LT / RT"],
	["Spot dodge", ["shield", "down"], "Shield + down"],
	["Roll", ["shield", "left/right"], "Shield + left/right"],
	["Air dodge", ["shield (in air)"], "Shield in the air (+ direction)"],
	["Fast fall / drop through platform", [&"down"], "Stick down"],
	["Jump out of shield", ["shield", "jump"], "Shield, then X / Y"],
]

var back_action: Callable
var back_button: Button


func _init(p_app: GameApp, p_back: Callable, p_overlay: bool = false) -> void:
	back_action = p_back
	super(p_app, p_overlay)


func build() -> void:
	column.add_theme_constant_override("separation", 8)
	column.add_child(MenuStyle.label("CONTROLS", 40, MenuStyle.GOLD))
	var panel := PanelContainer.new()
	column.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 3)
	panel.add_child(grid)
	for header in ["Action", "Player 1", "Player 2", "Xbox controller"]:
		grid.add_child(_cell(header, MenuStyle.GOLD))
	for row: Array in ROWS:
		grid.add_child(_cell(row[0], MenuStyle.TEXT, true))
		grid.add_child(_cell(_keys_for(1, row[1])))
		grid.add_child(_cell(_keys_for(2, row[1])))
		grid.add_child(_cell(row[2]))
	for row in [
			["Pause", _action_keys(InputSetup.ACTION_PAUSE), _action_keys(InputSetup.ACTION_PAUSE), "Start"],
			["Rematch (after a match)", _action_keys(InputSetup.ACTION_REMATCH), "", "Start / A"],
			["Menus: select / back", "Enter / Esc", "", "A / B"],
			["Hitbox debug view", _action_keys(InputSetup.ACTION_DEBUG_HITBOXES), "", ""]]:
		grid.add_child(_cell(row[0], MenuStyle.TEXT, true))
		for i in range(1, 4):
			grid.add_child(_cell(row[i]))
	column.add_child(MenuStyle.label("Gandalf — B: fireball · side: lightning · down: magic push · up: wind rise.   Vader — B: Force choke · side: Force push · down: Force guard · up: Force leap.", 15, MenuStyle.MUTED))
	column.add_child(MenuStyle.label("Controllers: first two connected pads are Players 1 and 2 (change in Settings → Controllers).", 15, MenuStyle.MUTED))
	back_button = add_button("Back", back_action)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not is_queued_for_deletion() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_action.call()


func _cell(text: String, color: Color = MenuStyle.MUTED, left: bool = false) -> Label:
	var l := MenuStyle.label(text, 16, color)
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


## Keys for real buttons are looked up; plain strings describe combos
## ("shield" + "down" -> "T + S").
func _keys_for(player_id: int, buttons: Array) -> String:
	var parts := PackedStringArray()
	for b in buttons:
		if b is StringName:
			parts.append(" / ".join(key_names(PlayerInput.action_name(player_id, b))))
		else:
			var text: String = b
			var words := PackedStringArray()
			for word in text.split(" ", false):
				var w := word.trim_prefix("(").trim_suffix(")")
				if w == "left/right":
					words.append("%s/%s" % [_first(player_id, &"left"), _first(player_id, &"right")])
				elif InputSetup.KEYBOARD_BUTTONS.has(StringName(w)):
					words.append(_first(player_id, StringName(w)))
				else:
					words.append(word)
			parts.append(" ".join(words))
	return " + ".join(parts)


func _first(player_id: int, button: StringName) -> String:
	var names := key_names(PlayerInput.action_name(player_id, button))
	return names[0] if not names.is_empty() else "?"


func _action_keys(action: StringName) -> String:
	return " / ".join(key_names(action))


static func joy_names(button: StringName) -> PackedStringArray:
	var names := PackedStringArray()
	for joy_button: int in InputSetup.JOY_BUTTONS.get(button, []):
		if JOY_NAMES.has(joy_button):
			names.append(JOY_NAMES[joy_button])
	return names
