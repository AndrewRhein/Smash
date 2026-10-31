class_name PlaceholderHud
extends CanvasLayer
## TEMPORARY HUD: damage/stocks per player, match status, result and rematch
## prompt. Driven only by fighter/match signals (damage_changed, stocks_changed,
## match_state_changed, match_ended).

const CONTROLS_TEXT := "P1: A/D move  W jump  S down  F light  R heavy  G/T/V specials" \
	+ "    |    P2: ←/→ move  ↑ jump  ↓ down  K light  I heavy  L/O/M specials" \
	+ "    |    F1 hitboxes"

var _match: MatchController
var _player_labels: Dictionary = {}  # player_id -> Label
var _status: Label


func _ready() -> void:
	_status = _label(Vector2(340, 20), 22, Color(1, 0.88, 0.55))
	_status.size = Vector2(600, 30)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := _label(Vector2(20, 690), 13, Color(0.84, 0.86, 0.92))
	controls.text = CONTROLS_TEXT


func bind(match_controller: MatchController) -> void:
	_match = match_controller
	_match.fighter_spawned.connect(_on_fighter_spawned)
	_match.match_state_changed.connect(func(_s: MatchController.MatchState) -> void: _refresh_status())
	_match.match_ended.connect(func(_w: int) -> void: _refresh_status())


func _on_fighter_spawned(fighter: Fighter) -> void:
	var label: Label = _player_labels.get(fighter.player_id)
	if label == null:
		var x := 28.0 if fighter.player_id == 1 else 900.0
		label = _label(Vector2(x, 22), 24, fighter.character.hud_color)
		_player_labels[fighter.player_id] = label
	var update := func(_v: Variant = null) -> void:
		label.text = "%s   %d%%   STOCKS: %d" % [fighter.character.display_name.to_upper(), roundi(fighter.damage), fighter.stocks]
	fighter.damage_changed.connect(update)
	fighter.stocks_changed.connect(update)
	update.call()


func _process(_delta: float) -> void:
	if _match != null and _match.state == MatchController.MatchState.COUNTDOWN:
		_refresh_status()


func _refresh_status() -> void:
	match _match.state:
		MatchController.MatchState.COUNTDOWN:
			_status.text = "READY... %d" % ceili(_match.countdown_remaining / 30.0)
		MatchController.MatchState.PLAYING:
			_status.text = "REALMS RUMBLE • FIGHT!"
		MatchController.MatchState.RESULT:
			var result := "DRAW!"
			if _match.winner_player_id > 0:
				result = "%s WINS!" % _match.get_fighter(_match.winner_player_id).character.display_name.to_upper()
			_status.text = result + "   Enter / Start = rematch"
		_:
			_status.text = ""


func _label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label
