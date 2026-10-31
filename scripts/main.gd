extends Node2D
## Scene entry point: wires the stage, match controller and the (temporary)
## presentation nodes together. Gameplay lives in scripts/gameplay/ and
## scripts/fighter.gd; nothing here affects combat.

const CHARACTERS: Array[CharacterData] = [
	preload("res://data/characters/gandalf.tres"),
	preload("res://data/characters/vader.tres"),
]

@onready var stage: Stage = $Stage
@onready var match_controller: MatchController = $Match
@onready var effects: PlaceholderEffects = $Effects
@onready var debug_overlay: DebugOverlay = $DebugOverlay
@onready var hud: PlaceholderHud = $HUD


func _ready() -> void:
	InputSetup.ensure_actions()
	effects.bind(match_controller)
	hud.bind(match_controller)
	debug_overlay.match_controller = match_controller
	var inputs: Array[PlayerInput] = [PlayerInput.new(1), PlayerInput.new(2)]
	if not match_controller.setup(stage, CHARACTERS, inputs):
		push_error("Character data failed validation; see errors above.")
		return
	match_controller.start_match()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputSetup.ACTION_DEBUG_HITBOXES):
		debug_overlay.toggle()
	elif event.is_action_pressed(InputSetup.ACTION_REMATCH) \
			and match_controller.state == MatchController.MatchState.RESULT:
		match_controller.rematch()
