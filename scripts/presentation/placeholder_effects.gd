class_name PlaceholderEffects
extends Node2D
## TEMPORARY PLACEHOLDER VFX. Listens to every fighter's effect_requested and
## draws simple vector shapes. Sits above the arena and fighters (z_index set in
## main.tscn), so effects are never hidden behind the opaque background.
## Unknown effect IDs fall back to a ring and warn once.

const DEFAULT_LIFE := 0.3
const COLORS := {1: Color(0.35, 0.78, 1.0), 2: Color(1.0, 0.25, 0.22)}

var _effects: Array[Dictionary] = []
var _warned: Dictionary = {}


func bind(match_controller: MatchController) -> void:
	match_controller.fighter_spawned.connect(_on_fighter_spawned)
	match_controller.match_state_changed.connect(_on_match_state_changed)


func _on_fighter_spawned(fighter: Fighter) -> void:
	fighter.effect_requested.connect(_on_effect_requested)


func _on_match_state_changed(state: MatchController.MatchState) -> void:
	if state == MatchController.MatchState.COUNTDOWN:
		_effects.clear()


func _on_effect_requested(effect_id: StringName, world_position: Vector2, direction: Vector2, payload: Dictionary) -> void:
	if not GameIds.EFFECT_IDS.has(effect_id) and not _warned.has(effect_id):
		_warned[effect_id] = true
		push_warning("PlaceholderEffects: unknown effect '%s'" % effect_id)
	var life := DEFAULT_LIFE
	if payload.has("duration_ticks"):
		life = maxf(float(payload.duration_ticks) / 60.0, 0.1)
	match effect_id:
		&"blast_ko": life = 0.7
		&"lightning_bolt": life = 0.18
		&"force_push", &"magic_push": life = 0.25
	_effects.append({
		"id": effect_id, "pos": to_local(world_position), "dir": direction,
		"life": life, "max": life, "payload": payload,
		"color": COLORS.get(int(payload.get("player_id", 1)), Color.WHITE),
	})


func _process(delta: float) -> void:
	for i in range(_effects.size() - 1, -1, -1):
		_effects[i].life -= delta
		if _effects[i].life <= 0.0:
			_effects.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for e in _effects:
		var t: float = 1.0 - e.life / e.max  # 0 -> 1
		var col: Color = e.color
		col.a = 1.0 - t
		var p: Vector2 = e.pos
		var d: Vector2 = e.dir if e.dir != Vector2.ZERO else Vector2.RIGHT
		match e.id:
			&"hit_spark":
				for k in 8:
					var a := TAU * k / 8.0
					draw_line(p, p + Vector2(cos(a), sin(a)) * (14.0 + 30.0 * t), Color(1, 1, 0.8, 1.0 - t), 3)
			&"guard_block":
				draw_arc(p, 30.0 + 10.0 * t, d.angle() - 1.2, d.angle() + 1.2, 16, Color(0.5, 0.8, 1, 1.0 - t), 5)
			&"blast_ko":
				draw_arc(p, 40.0 + 260.0 * t, 0, TAU, 48, col, 10)
			&"respawn":
				draw_arc(p + Vector2(0, -45), 60.0 * (1.0 - t) + 10.0, 0, TAU, 32, col, 3)
			&"lightning_telegraph":
				draw_circle(p, 6.0 + 10.0 * t, Color(0.7, 0.9, 1, 0.4 + 0.5 * t))
			&"lightning_bolt":
				_draw_bolt(p, d, 250.0, Color(0.85, 0.95, 1, 1.0 - t))
			&"force_push", &"magic_push":
				for k in 3:
					var r := 30.0 + 60.0 * t + k * 22.0
					draw_arc(p, r, d.angle() - 0.6, d.angle() + 0.6, 12, col, 3)
			&"force_choke":
				draw_arc(p, 26.0, 0, TAU, 24, Color(1, 0.3, 0.3, 0.7), 4)
			&"staff_swing", &"saber_swing", &"heavy_staff_swing", &"heavy_saber_swing":
				draw_arc(p + d * 10.0, 46.0, d.angle() - 1.4, d.angle() + 0.6, 16, col, 4)
			&"double_jump":
				draw_arc(p, 10.0 + 20.0 * t, 0, PI, 12, Color(1, 1, 1, 1.0 - t), 3)
			_:
				draw_arc(p, 12.0 + 24.0 * t, 0, TAU, 24, col, 3)


func _draw_bolt(origin: Vector2, dir: Vector2, length: float, col: Color) -> void:
	var normal := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([origin])
	for k in range(1, 9):
		var jitter := (randf() - 0.5) * 22.0
		pts.append(origin + dir * (length * k / 8.0) + normal * jitter)
	draw_polyline(pts, col, 4)
	draw_polyline(pts, Color(1, 1, 1, col.a), 1.5)
