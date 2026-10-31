class_name InputFrame
extends RefCounted
## Immutable-by-convention snapshot of one player's input for one physics tick.
## `held` is the button state this tick; `pressed` is the rising edge (held now,
## not held on the previous sample). Gameplay only ever reads InputFrames, never
## the Input singleton, so tests can drive fighters with scripted frames.

const BUTTONS := [
	&"left", &"right", &"up", &"down", &"jump",
	&"light", &"heavy", &"special_1", &"special_2", &"special_3",
]

## Horizontal axis in [-1, 1] after dead zone (keyboard gives -1/0/1).
var move_x: float = 0.0
## Vertical axis in [-1, 1], positive = down (Godot convention).
var move_y: float = 0.0
var held_mask: int = 0
var pressed_mask: int = 0


static func bit(button: StringName) -> int:
	var index := BUTTONS.find(button)
	assert(index >= 0, "Unknown input button %s" % button)
	return 1 << index


func is_held(button: StringName) -> bool:
	return held_mask & bit(button) != 0


func is_pressed(button: StringName) -> bool:
	return pressed_mask & bit(button) != 0
