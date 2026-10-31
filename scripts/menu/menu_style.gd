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
	var normal := _box(Color(0.12, 0.15, 0.24), Color(0.25, 0.3, 0.42), 2)
	var focus := _box(Color(0.2, 0.22, 0.34), GOLD, 3)
	var hover := _box(Color(0.17, 0.2, 0.31), Color(0.45, 0.5, 0.65), 2)
	var pressed := _box(Color(0.28, 0.24, 0.16), GOLD, 3)
	for state in ["normal", "disabled"]:
		_theme.set_stylebox(state, "Button", normal)
	_theme.set_stylebox("focus", "Button", focus)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_focus_color", "Button", GOLD)
	_theme.set_color("font_hover_color", "Button", TEXT)
	_theme.set_color("font_pressed_color", "Button", GOLD)
	_theme.set_color("font_color", "Label", TEXT)
	_theme.set_stylebox("panel", "PanelContainer", _box(PANEL, Color(0.3, 0.34, 0.48), 2))
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
