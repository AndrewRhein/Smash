class_name GameFeel
extends Node2D
## Presentation-only "juice": screen shake scaled by knockback, smoke trails
## behind launched fighters, and a KO flash/burst. Reads fighter state; never
## changes gameplay. The shake moves the viewport's canvas transform, so HUD
## and menus on CanvasLayers stay still.

## Shake (px) per 1000 px/s of knockback, and caps.
const SHAKE_PER_KB := 9.0
const MAX_SHAKE := 16.0
const KO_SHAKE := 22.0
const SHAKE_DECAY := 0.86
## Launch speed (px/s) above which a smoke trail is drawn.
const TRAIL_SPEED := 650.0

var _match: MatchController
var _shake := 0.0
var _seen_hits: Dictionary = {}
var _puffs: Array[Dictionary] = []   # {pos, age, life, size, color}
var _bursts: Array[Dictionary] = []  # {pos, dir, age, color}
var _flash: ColorRect
var _rng := RandomNumberGenerator.new()


func bind(match_controller: MatchController) -> void:
	_match = match_controller
	_match.fighter_spawned.connect(_on_fighter_spawned)
	z_index = 5
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash)


func _on_fighter_spawned(fighter: Fighter) -> void:
	_seen_hits[fighter.player_id] = fighter.hit_counter
	var last := [fighter.stocks]
	fighter.stocks_changed.connect(func(stocks: int) -> void:
		if stocks < last[0]:
			_on_ko(fighter)
		last[0] = stocks)


func _on_ko(fighter: Fighter) -> void:
	_shake = maxf(_shake, KO_SHAKE)
	_flash.color.a = 0.4
	var center := Vector2(640, 360)
	var dir := (center - fighter.global_position).normalized()
	_bursts.append({"pos": fighter.global_position.clamp(Vector2(20, 20), Vector2(1260, 700)),
		"dir": dir, "age": 0.0, "color": fighter.character.hud_color})


func _process(delta: float) -> void:
	if _match == null:
		return
	for fighter: Fighter in _match.fighters:
		if not is_instance_valid(fighter):
			continue
		var seen: int = _seen_hits.get(fighter.player_id, 0)
		if fighter.hit_counter > seen:
			_seen_hits[fighter.player_id] = fighter.hit_counter
			_shake = maxf(_shake, minf(MAX_SHAKE, 1.5 + fighter.last_knockback / 1000.0 * SHAKE_PER_KB))
		elif fighter.hit_counter < seen:
			_seen_hits[fighter.player_id] = fighter.hit_counter  # rematch reset
		if fighter.state == Fighter.State.HITSTUN and fighter.velocity.length() > TRAIL_SPEED \
				and fighter.hitstop_remaining == 0 and fighter.visible:
			var body := fighter.global_position + Vector2(0, fighter.character.hurtbox.get_center().y)
			var hot := fighter.velocity.length() > 1300.0
			_puffs.append({"pos": body + Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6)),
				"age": 0.0, "life": 0.45, "size": _rng.randf_range(7.0, 12.0),
				"color": Color(1.0, 0.55, 0.25, 0.8) if hot else Color(0.85, 0.85, 0.9, 0.55)})
	for p in _puffs:
		p.age += delta
	_puffs = _puffs.filter(func(p: Dictionary) -> bool: return p.age < p.life)
	for b in _bursts:
		b.age += delta
	_bursts = _bursts.filter(func(b: Dictionary) -> bool: return b.age < 0.9)
	# Shake.
	var offset := Vector2.ZERO
	if _shake > 0.3:
		offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake
		_shake *= pow(SHAKE_DECAY, delta * 60.0)
	else:
		_shake = 0.0
	get_viewport().canvas_transform = Transform2D(0.0, offset)
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 2.2)
	queue_redraw()


func _exit_tree() -> void:
	if is_inside_tree():
		get_viewport().canvas_transform = Transform2D.IDENTITY


func _draw() -> void:
	for p in _puffs:
		var k: float = p.age / p.life
		var c: Color = p.color
		c.a *= 1.0 - k
		draw_circle(p.pos, p.size * (1.0 + k * 1.4), c)
	for b in _bursts:
		var k: float = b.age / 0.9
		var col: Color = b.color.lerp(Color.WHITE, 0.4)
		col.a = 1.0 - k
		# A cone of rays shooting back into the arena from the blast point.
		var base_angle: float = b.dir.angle()
		for i in 9:
			var a := base_angle + (i - 4) * 0.16
			var length := 120.0 + 520.0 * k * (1.0 - absf(i - 4) * 0.08)
			draw_line(b.pos, b.pos + Vector2.from_angle(a) * length, col, 10.0 * (1.0 - k) + 2.0)
		draw_circle(b.pos, 30.0 + 90.0 * k, Color(1, 1, 1, 0.5 * (1.0 - k)))
