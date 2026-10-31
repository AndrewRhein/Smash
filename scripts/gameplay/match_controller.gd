class_name MatchController
extends Node2D
## Owns the match: fighters, projectiles, the fixed tick order, hit resolution,
## blast-zone KOs, the single terminal result and rematch.
##
## Tick order (one call to step(), 60 Hz):
##   1. Sample every player's input (always, so edge detection stays coherent).
##   2. Fighters update in player-id order (movement, move timeline, spawns).
##   3. Projectiles move and expire.
##   4. Hits are COLLECTED from the post-movement state of everyone, then
##      APPLIED together (strikes first, grabs second), so neither player-id
##      order nor node order decides a trade.
##   5. Force-choke holds update (pulses, range checks, release).
##   6. Blast-bounds KOs, then the result check.
##
## Engine.time_scale is never touched: hitstop is per-fighter tick counting.

signal fighter_spawned(fighter: Fighter)
signal match_state_changed(state: MatchState)
## winner_player_id is 0 for a draw. Emitted exactly once per match.
signal match_ended(winner_player_id: int)

enum MatchState { NOT_STARTED, COUNTDOWN, PLAYING, RESULT }
const DRAW := 0

@export var stock_count: int = 3
## Ticks before control is given (fighters still fall into place).
@export var countdown_ticks: int = 90
## When false, the owner must call step() manually (tests).
@export var auto_step: bool = true

var stage: Stage
var characters: Array[CharacterData] = []
var inputs: Array[PlayerInput] = []
var fighters: Array[Fighter] = []
var projectiles: Array[Projectile] = []
var state: MatchState = MatchState.NOT_STARTED
var tick: int = 0
var countdown_remaining: int = 0
## -1 while undecided, 0 draw, otherwise the winning player_id.
var winner_player_id: int = -1

var _projectile_layer: Node2D
var _neutral_frame := InputFrame.new()


## Returns false (and reports errors) if any character data is invalid.
func setup(p_stage: Stage, p_characters: Array[CharacterData], p_inputs: Array[PlayerInput]) -> bool:
	stage = p_stage
	characters = p_characters
	inputs = p_inputs
	var ok := true
	for data in characters:
		for error in data.validate():
			push_error("Invalid character data: " + error)
			ok = false
	if _projectile_layer == null:
		_projectile_layer = Node2D.new()
		_projectile_layer.name = "Projectiles"
		add_child(_projectile_layer)
	return ok


## Starts (or restarts) a match from scratch. Rematch = start_match().
func start_match() -> void:
	_clear_actors()
	tick = 0
	winner_player_id = -1
	for i in characters.size():
		var player_id := i + 1
		var fighter := Fighter.new()
		fighter.setup(characters[i], player_id, stage.spawn_point(player_id), stock_count, inputs[i])
		fighter.projectile_requested.connect(_on_projectile_requested)
		add_child(fighter)
		fighters.append(fighter)
		inputs[i].reset_edges()
		fighter_spawned.emit(fighter)
	countdown_remaining = countdown_ticks
	_set_state(MatchState.COUNTDOWN if countdown_ticks > 0 else MatchState.PLAYING)


func rematch() -> void:
	start_match()


func get_fighter(player_id: int) -> Fighter:
	for fighter in fighters:
		if fighter.player_id == player_id:
			return fighter
	return null


func _physics_process(_delta: float) -> void:
	if auto_step:
		step()


func step() -> void:
	match state:
		MatchState.COUNTDOWN:
			for fighter in fighters:
				fighter.input.sample()  # keep edges coherent; presses are discarded
				fighter.physics_tick(_neutral_frame)
			countdown_remaining -= 1
			if countdown_remaining <= 0:
				_set_state(MatchState.PLAYING)
		MatchState.PLAYING:
			_step_playing()
		_:
			return
	tick += 1


func _step_playing() -> void:
	var frames: Array[InputFrame] = []
	for fighter in fighters:
		frames.append(fighter.input.sample())
	for i in fighters.size():
		fighters[i].physics_tick(frames[i])
	for projectile in projectiles.duplicate():
		projectile.physics_tick()
		if projectile.is_expired():
			_emit_owner_effect(projectile, GameIds.EFFECT_PROJECTILE_FIZZLE)
			_despawn_projectile(projectile)
		elif not stage.blast_bounds.has_point(projectile.global_position):
			_despawn_projectile(projectile)
	_resolve_hits()
	_update_holds()
	_check_blast_zones()
	_check_result()


# =============================================================================
# Hit resolution
# =============================================================================
func _resolve_hits() -> void:
	var candidates: Array[Dictionary] = []
	for attacker in fighters:
		for hb: Dictionary in attacker.get_active_hitboxes():
			var data: HitboxData = hb.data
			var is_grab := data.kind == HitboxData.Kind.GRAB
			for victim in fighters:
				if victim == attacker or not victim.is_hittable():
					continue
				if is_grab and (victim.grab_immunity_remaining > 0 or attacker.held_target != null):
					continue
				if not attacker.can_hit(victim, data, tick):
					continue
				if not CombatMath.shape_overlaps_rect(hb, victim.get_hurtbox_world()):
					continue
				candidates.append({
					"attacker": attacker, "victim": victim, "move": attacker.move,
					"instance": attacker.attack_instance, "grab": is_grab,
					"source_x": attacker.global_position.x, "direction_sign": attacker.facing,
					"aim": attacker.aim_angle_deg, "projectile": null, "order": hb.index,
				})
	for projectile in projectiles:
		for victim in fighters:
			if victim == projectile.owner_fighter or not victim.is_hittable():
				continue
			if not CombatMath.shape_overlaps_rect(projectile.get_hit_shape(), victim.get_hurtbox_world()):
				continue
			candidates.append({
				"attacker": projectile.owner_fighter, "victim": victim, "move": projectile.move,
				"instance": -1, "grab": false, "source_x": projectile.global_position.x,
				"direction_sign": projectile.direction_sign, "aim": 0.0,
				"projectile": projectile, "order": 1000,
			})
	if candidates.is_empty():
		return
	# One hit per victim per tick. Every overlapping source is consumed (hit-once
	# bookkeeping / projectile destroyed); only the best one applies.
	var chosen: Array[Dictionary] = []
	for victim in fighters:
		var list: Array[Dictionary] = candidates.filter(func(c: Dictionary) -> bool: return c.victim == victim)
		if list.is_empty():
			continue
		list.sort_custom(_candidate_before)
		for c in list:
			if c.projectile != null:
				_despawn_projectile(c.projectile)
			else:
				c.attacker.register_hit(victim, tick)
		chosen.append(list[0])
	# Strikes resolve before grabs, so a grab never beats a simultaneous strike.
	for c in chosen:
		if not c.grab:
			_apply_strike(c)
	for c in chosen:
		if c.grab:
			_apply_grab(c)


## Deterministic priority: strikes before grabs, higher damage, lower attacker
## player_id, melee before projectile, lower hitbox index.
static func _candidate_before(a: Dictionary, b: Dictionary) -> bool:
	if a.grab != b.grab:
		return not a.grab
	if a.move.damage != b.move.damage:
		return a.move.damage > b.move.damage
	if a.attacker.player_id != b.attacker.player_id:
		return a.attacker.player_id < b.attacker.player_id
	return a.order < b.order


func _apply_strike(c: Dictionary) -> void:
	var victim: Fighter = c.victim
	var attacker: Fighter = c.attacker
	var move: MoveData = c.move
	var is_melee: bool = c.projectile == null
	if victim.is_guarding_against(move.damage_type, c.source_x):
		victim.hitstop_remaining = maxi(victim.hitstop_remaining, CombatMath.BLOCK_HITSTOP_TICKS)
		if is_melee:
			attacker.hitstop_remaining = maxi(attacker.hitstop_remaining, CombatMath.BLOCK_HITSTOP_TICKS)
		victim.request_effect(GameIds.EFFECT_GUARD_BLOCK, victim.local_to_world_point(Vector2(24, -50)),
			Vector2(victim.facing, 0), {"attacker_id": attacker.player_id, "move_id": String(move.id)})
		return
	var hitstop := CombatMath.hitstop_ticks(move.damage)
	victim.receive_hit(move, c.direction_sign, c.aim, attacker.player_id, hitstop)
	if is_melee:
		# Trades: each fighter ends with max(incoming, outgoing) hitstop,
		# independent of application order.
		attacker.hitstop_remaining = maxi(attacker.hitstop_remaining, hitstop)
		if attacker.attack_instance == c.instance:
			attacker.move_connected = true


func _apply_grab(c: Dictionary) -> void:
	var attacker: Fighter = c.attacker
	var victim: Fighter = c.victim
	# The grabber must still be in the same, uninterrupted move.
	if attacker.state != Fighter.State.ATTACK or attacker.attack_instance != c.instance:
		return
	if not victim.is_hittable():
		return
	attacker.held_target = victim
	attacker.move_connected = true
	victim.begin_held(attacker)
	attacker.request_effect(&"force_choke", victim.global_position + Vector2(0, -60), Vector2.UP,
		 {"victim_id": victim.player_id, "duration_ticks": c.move.active_ticks})


# =============================================================================
# Force choke holds
# =============================================================================
func _update_holds() -> void:
	for attacker in fighters:
		var victim := attacker.held_target
		if victim == null:
			continue
		var move := attacker.move
		var in_choke := attacker.state == Fighter.State.ATTACK and move != null \
			and move.special_behaviour == GameIds.SPECIAL_CHOKE
		if not in_choke or victim.state != Fighter.State.HELD:
			_release_hold(attacker, false)
		elif move.is_recovery_tick(attacker.move_tick):
			_release_hold(attacker, true)  # full duration -> launch
		elif attacker.global_position.distance_to(victim.global_position) > move.hold_max_range \
				or victim.held_ticks > Fighter.MAX_HELD_TICKS:
			_release_hold(attacker, false)
		elif victim.held_ticks > 0 and victim.held_ticks % move.hold_pulse_interval_ticks == 0:
			victim.add_damage(move.hold_pulse_damage)


func _release_hold(attacker: Fighter, launch: bool) -> void:
	var victim := attacker.held_target
	var move := attacker.move
	attacker.held_target = null
	if victim == null:
		return
	var immunity := move.grab_immunity_ticks if move != null else 60
	victim.end_held(immunity)
	attacker.request_effect(GameIds.EFFECT_CHOKE_RELEASE, victim.global_position + Vector2(0, -60), Vector2.UP,
		{"victim_id": victim.player_id, "launched": launch})
	if launch and move != null:
		victim.receive_hit(move, attacker.facing, 0.0, attacker.player_id, CombatMath.hitstop_ticks(move.damage))


# =============================================================================
# Stocks and result
# =============================================================================
func _check_blast_zones() -> void:
	var bounds := stage.blast_bounds
	for fighter in fighters:
		if not fighter.is_in_play() or bounds.has_point(fighter.global_position):
			continue
		var at := Vector2(clampf(fighter.global_position.x, bounds.position.x, bounds.end.x),
			clampf(fighter.global_position.y, bounds.position.y, bounds.end.y))
		var toward_center := (bounds.get_center() - at).normalized()
		fighter.request_effect(GameIds.EFFECT_BLAST_KO, at, toward_center, {"stocks_before": fighter.stocks})
		_despawn_projectiles_of(fighter)
		fighter.blast_ko()


func _check_result() -> void:
	if state != MatchState.PLAYING:
		return
	var alive: Array[Fighter] = fighters.filter(func(f: Fighter) -> bool: return f.stocks > 0)
	if alive.size() > 1:
		return
	# Zero fighters left means the final stocks were lost on the same tick: draw.
	_end_match(alive[0].player_id if alive.size() == 1 else DRAW)


func _end_match(winner: int) -> void:
	if state == MatchState.RESULT:
		return
	winner_player_id = winner
	for projectile in projectiles.duplicate():
		_despawn_projectile(projectile)
	for fighter in fighters:
		if fighter.stocks > 0:
			fighter.set_victory()
	_set_state(MatchState.RESULT)
	match_ended.emit(winner)


func _set_state(value: MatchState) -> void:
	state = value
	match_state_changed.emit(state)


# =============================================================================
# Projectiles / cleanup
# =============================================================================
func _on_projectile_requested(owner: Fighter, move: MoveData, data: ProjectileData) -> void:
	var projectile := Projectile.new()
	_projectile_layer.add_child(projectile)
	projectile.setup(owner, move, data)
	projectiles.append(projectile)


func _despawn_projectile(projectile: Projectile) -> void:
	if not projectiles.has(projectile):
		return
	projectiles.erase(projectile)
	if projectile.get_parent() != null:
		projectile.get_parent().remove_child(projectile)
	projectile.queue_free()


func _despawn_projectiles_of(fighter: Fighter) -> void:
	for projectile in projectiles.duplicate():
		if projectile.owner_fighter == fighter:
			_despawn_projectile(projectile)


func _emit_owner_effect(projectile: Projectile, effect_id: StringName) -> void:
	if is_instance_valid(projectile.owner_fighter):
		projectile.owner_fighter.request_effect(effect_id, projectile.global_position,
			projectile.velocity.normalized(), {"move_id": String(projectile.move.id)})


func _clear_actors() -> void:
	for projectile in projectiles.duplicate():
		_despawn_projectile(projectile)
	projectiles.clear()
	for fighter in fighters:
		fighter.break_hold_links()
		remove_child(fighter)
		fighter.queue_free()
	fighters.clear()
	for player_input in inputs:
		if player_input.scripted:
			player_input.release_all()
