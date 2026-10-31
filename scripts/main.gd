extends Node2D
## Scene entry point: wires the stage, match controller and the (temporary)
## presentation nodes together. Gameplay lives in scripts/gameplay/ and
## scripts/fighter.gd; nothing here affects combat.

const CHARACTERS: Array[CharacterData] = [
	preload("res://data/characters/gandalf.tres"),
	preload("res://data/characters/elon.tres"),
]
const PresentationSetup = preload("res://scripts/presentation/presentation_setup.gd")

## Set by the app's character select before this scene enters the tree; when
## empty, the default lineup above is used (e.g. running main.tscn directly).
var character_override: Array[CharacterData] = []
## Port number per entry of character_override (empty = 1, 2, ...).
var player_ids: Array[int] = []
## player id -> CPU level 1-9 for computer-controlled fighters (absent = human).
var cpu_levels: Dictionary = {}

@onready var stage: Stage = $Stage
@onready var match_controller: MatchController = $Match
@onready var effects: PlaceholderEffects = $Effects
@onready var debug_overlay: DebugOverlay = $DebugOverlay
@onready var hud: PlaceholderHud = $HUD


func _ready() -> void:
	InputSetup.ensure_actions()
	effects.bind(match_controller)
	var feel := GameFeel.new()
	feel.name = "GameFeel"
	add_child(feel)
	feel.bind(match_controller)
	hud.bind(match_controller)
	debug_overlay.match_controller = match_controller
	var lineup: Array[CharacterData] = character_override if not character_override.is_empty() else CHARACTERS
	var inputs: Array[PlayerInput] = []
	var visual_characters: Array[CharacterData] = []
	for i in lineup.size():
		var player_id: int = player_ids[i] if i < player_ids.size() else i + 1
		if cpu_levels.has(player_id):
			inputs.append(CpuInput.new(player_id, int(cpu_levels[player_id])))
		else:
			inputs.append(PlayerInput.new(player_id))
		visual_characters.append(PresentationSetup.with_art(lineup[i]))
	if not match_controller.setup(stage, visual_characters, inputs):
		push_error("Character data failed validation; see errors above.")
		return
	for player_input in inputs:
		if player_input is CpuInput:
			(player_input as CpuInput).bind(match_controller)
	match_controller.start_match()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputSetup.ACTION_DEBUG_HITBOXES):
		debug_overlay.toggle()
	elif event.is_action_pressed(InputSetup.ACTION_REMATCH) \
			and match_controller.state == MatchController.MatchState.RESULT:
		match_controller.rematch()
