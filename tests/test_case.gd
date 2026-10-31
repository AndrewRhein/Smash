extends RefCounted
## Base class for headless gameplay tests. Tests drive the REAL MatchController,
## Fighter and data resources with scripted PlayerInputs and manual step() calls
## (auto_step = false), so every tick is deterministic.

const GANDALF := preload("res://data/characters/gandalf.tres")
const VADER := preload("res://data/characters/vader.tres")
## Top surface of the main (solid) platform.
const GROUND_Y := 546.0

var tree: SceneTree
var failures: PackedStringArray = []
var _nodes: Array[Node] = []


# --- Fixtures -----------------------------------------------------------------
## Builds Stage + MatchController with scripted inputs. P1 = Gandalf, P2 = Vader.
func make_match(countdown: int = 0, stocks: int = 3) -> MatchController:
	var stage := Stage.new()
	tree.root.add_child(stage)
	var m := MatchController.new()
	m.auto_step = false
	m.countdown_ticks = countdown
	m.stock_count = stocks
	tree.root.add_child(m)
	_nodes.append_array([m, stage])
	var chars: Array[CharacterData] = [GANDALF, VADER]
	var inputs: Array[PlayerInput] = [PlayerInput.new(1, true), PlayerInput.new(2, true)]
	assert_true(m.setup(stage, chars, inputs), "setup with shipped data")
	m.start_match()
	# Let the physics server register the freshly added static platforms.
	await tree.physics_frame
	await tree.physics_frame
	return m


## Puts a fighter on the main platform at x, facing `facing`, fully at rest.
func place(f: Fighter, x: float, facing: int, y: float = GROUND_Y) -> void:
	f.position = Vector2(x, y)
	f.velocity = Vector2.ZERO
	f.set_facing(facing)
	f.invulnerable_remaining = 0
	f.grounded = y == GROUND_Y


## Standard melee range setup: Gandalf at 600 facing right, Vader at 660 facing left.
func face_off(m: MatchController, gap: float = 60.0) -> void:
	place(m.get_fighter(1), 600, 1)
	place(m.get_fighter(2), 600 + gap, -1)
	step(m, 2)


func step(m: MatchController, ticks: int = 1) -> void:
	for i in ticks:
		m.step()


func p(m: MatchController, player_id: int) -> PlayerInput:
	return m.inputs[player_id - 1]


func cleanup() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()


# --- Assertions -----------------------------------------------------------------
func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func assert_near(actual: float, expected: float, tolerance: float, msg: String) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s (expected %s ± %s, got %s)" % [msg, expected, tolerance, actual])
