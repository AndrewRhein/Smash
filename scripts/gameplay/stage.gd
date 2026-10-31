class_name Stage
extends Node2D
## Gameplay geometry of the arena: platforms, spawn points and blast bounds.
## Contains no art; scripts/presentation/placeholder_arena.gd reads PLATFORMS to
## draw temporary visuals, and final arena art can do the same.

## Physics layer numbers (1-based, as used by set_collision_*_value).
const LAYER_WORLD := 1    ## Solid terrain (main platform).
const LAYER_FIGHTER := 2  ## Fighter bodies. Fighters do not collide with each other.
const LAYER_ONE_WAY := 3  ## Pass-through platforms (land from above, drop through).

## center, size, one_way. The main platform is solid; upper ones are one-way.
const PLATFORMS := [
	{"center": Vector2(640, 565), "size": Vector2(600, 38), "one_way": false},
	{"center": Vector2(435, 420), "size": Vector2(180, 20), "one_way": true},
	{"center": Vector2(845, 420), "size": Vector2(180, 20), "one_way": true},
	{"center": Vector2(640, 315), "size": Vector2(150, 18), "one_way": true},
]

## Feet positions. Index = player_id - 1.
@export var spawn_points: Array[Vector2] = [Vector2(440, 380), Vector2(840, 380)]
## A fighter whose root leaves this rectangle loses a stock. The viewport is
## 1280x720; bounds extend past it on all four sides.
@export var blast_bounds: Rect2 = Rect2(-300, -440, 1880, 1340)


func _ready() -> void:
	for def: Dictionary in PLATFORMS:
		add_child(_make_platform(def.center, def.size, def.one_way))


func _make_platform(center: Vector2, size: Vector2, one_way: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "OneWayPlatform" if one_way else "SolidPlatform"
	body.position = center
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(LAYER_ONE_WAY if one_way else LAYER_WORLD, true)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.one_way_collision = one_way
	body.add_child(shape)
	return body


func spawn_point(player_id: int) -> Vector2:
	return spawn_points[clampi(player_id - 1, 0, spawn_points.size() - 1)]
