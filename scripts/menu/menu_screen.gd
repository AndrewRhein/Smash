class_name MenuScreen
extends Control
## Base for full-screen menus: a dark backdrop with a centered column.
## Subclasses fill `column` in build() and list their focusable buttons.

var app: GameApp
var column: VBoxContainer
var _first_focus: Control
## When true the backdrop is translucent (used over a paused match).
var overlay: bool = false


func _init(p_app: GameApp, p_overlay: bool = false) -> void:
	app = p_app
	overlay = p_overlay
	theme = MenuStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop: Control
	if overlay:
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.03, 0.06, 0.78)
		backdrop = dim
	else:
		backdrop = MenuBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	build()


## Override to add widgets to `column`.
func build() -> void:
	pass


func add_button(text: String, on_pressed: Callable) -> Button:
	var b := MenuStyle.button(text, on_pressed)
	column.add_child(b)
	if _first_focus == null:
		_first_focus = b
	return b


func add_focusable(control: Control) -> Control:
	column.add_child(control)
	if _first_focus == null:
		_first_focus = control
	return control


func focus_first() -> void:
	if _first_focus != null and is_inside_tree():
		_first_focus.grab_focus()


func _ready() -> void:
	focus_first.call_deferred()
