class_name MenuStyle
extends RefCounted
## TEMPORARY functional menu styling, kept in one place so final presentation
## can replace it with a Theme resource without touching menu logic.

const GOLD := Color(1.0, 0.86, 0.5)
const TEXT := Color(0.9, 0.92, 0.97)
const MUTED := Color(0.62, 0.66, 0.76)
const PANEL := Color(0.05, 0.07, 0.13, 0.92)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 22
	# Slanted, translucent "fighting game" buttons; focus glows gold.
	var normal := _box(Color(0.05, 0.08, 0.14, 0.82), Color(1, 1, 1, 0.1), 1)
	var hover := _box(Color(0.1, 0.15, 0.25, 0.9), Color("baa574"), 1)
	var focus := _box(Color(1.0, 0.76, 0.3, 0.16), Color("ffd36b"), 2)
	var pressed := _box(Color("6b4a14"), GOLD, 2)
	for box: StyleBoxFlat in [normal, hover, focus, pressed]:
		box.skew = Vector2(0.18, 0)
		box.set_corner_radius_all(3)
		box.border_width_left = 5
		box.shadow_color = Color(0, 0, 0, 0.35)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 3)
	focus.border_width_left = 7
	focus.shadow_color = Color(1.0, 0.75, 0.25, 0.3)
	focus.shadow_size = 12
	focus.shadow_offset = Vector2.ZERO
	for state in ["normal", "disabled"]:
		_theme.set_stylebox(state, "Button", normal)
	_theme.set_stylebox("focus", "Button", focus)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_focus_color", "Button", Color("fff1c9"))
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	_theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.7))
	_theme.set_constant("outline_size", "Button", 4)
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	_theme.set_constant("outline_size", "Label", 3)
	var panel := _box(Color(0.04, 0.06, 0.11, 0.88), Color(1.0, 0.83, 0.42, 0.7), 1)
	panel.border_width_top = 3
	panel.shadow_color = Color(0, 0, 0, 0.4)
	panel.shadow_size = 10
	_theme.set_stylebox("panel", "PanelContainer", panel)
	return _theme


static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(6)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, on_pressed: Callable, min_width: float = 360.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 52)
	b.focus_mode = Control.FOCUS_ALL
	# Deferred: an action may free the screen that owns this button.
	b.pressed.connect(on_pressed, CONNECT_DEFERRED)
	return b
