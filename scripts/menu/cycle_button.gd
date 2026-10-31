class_name CycleButton
extends Button
## A button that cycles through options: left/right (keyboard, D-pad, stick)
## step through values; pressing advances. Emits value_changed(index).

signal value_changed(index: int)

var caption: String
var options: Array = []
var index: int = 0


func _init(p_caption: String, p_options: Array, start_index: int = 0) -> void:
	caption = p_caption
	options = p_options
	index = clampi(start_index, 0, options.size() - 1)
	custom_minimum_size = Vector2(360, 52)
	focus_mode = Control.FOCUS_ALL
	pressed.connect(func() -> void: step(1))
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		step(1)
		accept_event()


func step(delta: int) -> void:
	index = wrapi(index + delta, 0, options.size())
	_refresh()
	value_changed.emit(index)


func value() -> Variant:
	return options[index]


func _refresh() -> void:
	text = "%s:  ◀ %s ▶" % [caption, str(options[index])]
