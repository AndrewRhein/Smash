class_name Fighter
extends CharacterBody2D
## One fighter: movement, an explicit state machine and the attack timeline.
##
## Coordinates: the node origin is the feet center (ground contact). +X right,
## +Y down. `facing` is +1 (right) or -1 (left); the body is never flipped with
## negative scale. Hitboxes/hurtboxes are authored facing right and mirrored
## around the origin. All art lives under the VisualRoot child and never affects
## physics or combat.
##
## The fighter does not run its own _physics_process: MatchController calls
## physics_tick() once per 60 Hz tick in player order, then resolves hits for
## all fighters together, so results never depend on node processing order.

# --- Presentation contract v1 (see docs/GAMEPLAY_API.md) ---------------------
signal animation_requested(animation_id: StringName, duration_ticks: int, loop: bool)
signal facing_changed(facing: int)
signal effect_requested(effect_id: StringName, world_position: Vector2, direction: Vector2, payload: Dictionary)
signal damage_changed(damage: float)
signal stocks_changed(stocks: int)
signal eliminated(player_id: int)
# --- Gameplay-internal --------------------------------------------------------
## Asks the match to spawn a projectile. The match owns projectile lifetime.
signal projectile_requested(fighter: Fighter, move: MoveData, data: ProjectileData)

enum State { IDLE, WALK, RUN, JUMP, FALL, ATTACK, HITSTUN, HELD, KO, ELIMINATED, VICTORY }
const STATE_NAMES := {
	State.IDLE: &"idle", State.WALK: &"walk", State.RUN: &"run", State.JUMP: &"jump",
	State.FALL: &"fall", State.ATTACK: &"attack", State.HITSTUN: &"hitstun",
	State.HELD: &"held", State.KO: &"ko", State.ELIMINATED: &"eliminated",
	State.VICTORY: &"victory",
}
const FREE_STATES := [State.IDLE, State.WALK, State.RUN, State.JUMP, State.FALL]

const TICK := 1.0 / 60.0
## Ticks after walking off a ledge during which a grounded jump is still allowed.
const COYOTE_TICKS := 6
## A jump/attack press is remembered for this many ticks (including its own).
const JUMP_BUFFER_TICKS := 6
const ATTACK_BUFFER_TICKS := 6
## One-way platforms are ignored for this many ticks after a drop-through.
const DROP_THROUGH_TICKS := 12
const RESPAWN_DELAY_TICKS := 60
const RESPAWN_INVULNERABLE_TICKS := 120
## Locomotion animation thresholds on |velocity.x| (px/s) while grounded:
## below WALK -> idle, below RUN -> walk, otherwise run.
const WALK_SPEED_THRESHOLD := 20.0
const RUN_SPEED_THRESHOLD := 220.0
## Hits launching at or above this speed use "knockback", below it "hurt".
const KNOCKBACK_ANIM_THRESHOLD := 700.0
## Fast fall is allowed once rising slower than this (px/s).
const FAST_FALL_MAX_RISE := 120.0
## Horizontal decay during hitstun (px/s^2). Input never steers in hitstun.
const HITSTUN_AIR_DRAG := 1100.0
const HITSTUN_GROUND_FRICTION := 1800.0
const SLOWED_SPEED_FACTOR := 0.35
## Failsafe: nobody can be held longer than this, whatever the data says.
const MAX_HELD_TICKS := 120
## When several attack buttons are pressed on the same tick.
const MOVE_PRIORITY := [&"special_1", &"special_2", &"special_3", &"heavy", &"light"]

var character: CharacterData
var player_id: int = 1
var input: PlayerInput
var spawn_point: Vector2 = Vector2.ZERO

var state: State = State.FALL
var facing: int = 1
var damage: float = 0.0
var stocks: int = 3
var grounded: bool = false

# Attack state
var move: MoveData
var move_tick: int = -1
var attack_instance: int = 0
var move_connected: bool = false
var aim_angle_deg: float = 0.0
var hit_registry: Dictionary = {}       # victim instance id -> move_tick of last hit
var cooldowns: Dictionary = {}          # move id -> ticks remaining

# Timers (ticks)
var hitstun_remaining: int = 0
var hitstun_total: int = 0
var hitstop_remaining: int = 0
var invulnerable_remaining: int = 0
var grab_immunity_remaining: int = 0
var respawn_remaining: int = 0
var held_ticks: int = 0

# Movement helpers
var jump_buffer: int = 0
var attack_buffer: int = 0
var attack_buffer_move: StringName = &""
var coyote_remaining: int = 0
var air_jumps_left: int = 0
var jump_rising: bool = false
var fast_falling: bool = false
var drop_remaining: int = 0
var on_one_way: bool = false

# Hold links (Force choke)
var held_target: Fighter
var held_by: Fighter

# Presentation bookkeeping
var last_knockback: float = 0.0
var hit_counter: int = 0
var animation_id: StringName = &""
var animation_duration: int = 0
var animation_tick: int = 0
var _animation_key: String = ""
var visual_root: Node2D


func setup(data: CharacterData, id: int, spawn: Vector2, stock_count: int, player_input: PlayerInput) -> void:
	character = data
	player_id = id
	spawn_point = spawn
	stocks = stock_count
	input = player_input
	name = "Fighter%d_%s" % [id, data.id]
	position = spawn
	facing = 1 if spawn.x < 640.0 else -1
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(Stage.LAYER_FIGHTER, true)
	set_collision_mask_value(Stage.LAYER_WORLD, true)
	set_collision_mask_value(Stage.LAYER_ONE_WAY, true)
	floor_snap_length = 4.0
	var body := CollisionShape2D.new()
	body.name = "BodyShape"
	var capsule := CapsuleShape2D.new()
	capsule.radius = data.body_radius
	capsule.height = data.body_height
	body.shape = capsule
	body.position.y = -data.body_height * 0.5
	add_child(body)
	air_jumps_left = data.air_jumps
	# Resolve the initial animation before the VisualRoot exists, so an adapter
	# syncing from the snapshot in its own _ready() never sees an empty ID.
	_update_animation(true)
	_attach_visual()


func _attach_visual() -> void:
	if character.visual_scene != null:
		visual_root = character.visual_scene.instantiate() as Node2D
	if visual_root == null:
		visual_root = PlaceholderFighterVisual.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)


func _ready() -> void:
	# Announce the initial presentation state to adapters attached during setup.
	facing_changed.emit(facing)
	_update_animation(true)


# =============================================================================
# Per-tick update
# =============================================================================
func physics_tick(frame: InputFrame) -> void:
	match state:
		State.KO:
			respawn_remaining -= 1
			if respawn_remaining <= 0:
				_respawn()
			return
		State.ELIMINATED, State.VICTORY:
			return
	_record_buffers(frame)
	if hitstop_remaining > 0:
		# Hitstop freezes this fighter completely: position, velocity, move
		# timeline, hitstun, invulnerability, cooldowns and buffer expiry.
		# Presses during hitstop are still recorded above.
		hitstop_remaining -= 1
		return
	match state:
		State.HELD:
			velocity = Vector2.ZERO
			held_ticks += 1
		State.HITSTUN:
			_tick_hitstun()
		State.ATTACK:
			_tick_attack(frame)
		_:
			_tick_free(frame)
	if state != State.HELD:
		_apply_vertical(frame)
		move_and_slide()
		_after_move()
		if state in FREE_STATES:
			state = _locomotion_state()
	_tick_timers()
	_update_animation()
	animation_tick += 1


func _record_buffers(frame: InputFrame) -> void:
	if frame.is_pressed(&"jump"):
		jump_buffer = JUMP_BUFFER_TICKS
	for move_id: StringName in MOVE_PRIORITY:
		if frame.is_pressed(move_id):
			attack_buffer_move = move_id
			attack_buffer = ATTACK_BUFFER_TICKS
			break


func _tick_timers() -> void:
	jump_buffer = maxi(jump_buffer - 1, 0)
	attack_buffer = maxi(attack_buffer - 1, 0)
	if attack_buffer == 0:
		attack_buffer_move = &""
	invulnerable_remaining = maxi(invulnerable_remaining - 1, 0)
	grab_immunity_remaining = maxi(grab_immunity_remaining - 1, 0)
	if not grounded:
		coyote_remaining = maxi(coyote_remaining - 1, 0)
	for move_id: StringName in cooldowns.keys():
		cooldowns[move_id] -= 1
		if cooldowns[move_id] <= 0:
			cooldowns.erase(move_id)
	if drop_remaining > 0:
		drop_remaining -= 1
		if drop_remaining == 0:
			set_collision_mask_value(Stage.LAYER_ONE_WAY, true)


func _tick_free(frame: InputFrame) -> void:
	if frame.move_x != 0.0:
		set_facing(1 if frame.move_x > 0.0 else -1)
	_apply_horizontal(frame.move_x * character.max_speed, frame.move_x != 0.0)
	if grounded and on_one_way and frame.is_pressed(&"down"):
		_start_drop_through()
	elif not grounded and frame.is_pressed(&"down") and velocity.y > -FAST_FALL_MAX_RISE:
		fast_falling = true
		jump_rising = false
		velocity.y = maxf(velocity.y, character.fast_fall_speed)
	_try_jump()
	_try_start_buffered_move(frame, [])


func _tick_attack(frame: InputFrame) -> void:
	move_tick += 1
	if move_tick >= move.total_ticks():
		_end_move()
		_tick_free(frame)
		return
	# Choke whiff: grab window over without a grab -> straight to recovery.
	if move.whiff_to_recovery and held_target == null and move.is_active_tick(move_tick) \
			and move_tick - move.startup_ticks >= _grab_window_end():
		move_tick = move.startup_ticks + move.active_ticks
	if move_tick == move.startup_ticks and move.active_effect_id != &"":
		request_effect(move.active_effect_id, _effect_point(), aim_direction(), {"move_id": String(move.id)})
	if move.is_active_tick(move_tick):
		var active_tick := move_tick - move.startup_ticks
		for data: ProjectileData in move.projectiles:
			if data.spawn_tick == active_tick:
				projectile_requested.emit(self, move, data)
	match move.movement_policy:
		MoveData.MovementPolicy.FREE:
			_apply_horizontal(frame.move_x * character.max_speed, frame.move_x != 0.0)
		MoveData.MovementPolicy.SLOWED:
			_apply_horizontal(frame.move_x * character.max_speed * SLOWED_SPEED_FACTOR, frame.move_x != 0.0)
		MoveData.MovementPolicy.ROOTED:
			_apply_horizontal(0.0, false)
	# Recovery cancels are the only way to start a move before recovery ends.
	if move.is_recovery_tick(move_tick) and not move.cancel_into.is_empty() \
			and (move_connected or not move.cancel_requires_hit):
		_try_start_buffered_move(frame, move.cancel_into)


func _tick_hitstun() -> void:
	# Knockback is preserved: input is ignored, only drag/friction and gravity act.
	var decel := HITSTUN_GROUND_FRICTION if grounded else HITSTUN_AIR_DRAG
	velocity.x = move_toward(velocity.x, 0.0, decel * TICK)
	hitstun_remaining -= 1
	if hitstun_remaining <= 0:
		hitstun_remaining = 0
		state = _locomotion_state()


func _apply_horizontal(target_speed: float, has_input: bool) -> void:
	var rate: float
	if grounded:
		rate = character.ground_accel if has_input else character.ground_decel
	else:
		rate = character.air_accel if has_input else character.air_decel
	velocity.x = move_toward(velocity.x, target_speed, rate * TICK)


func _apply_vertical(frame: InputFrame) -> void:
	# Variable jump height: releasing jump while rising caps upward speed once.
	if jump_rising:
		if velocity.y >= 0.0:
			jump_rising = false
		elif not frame.is_held(&"jump") and velocity.y < -character.jump_release_velocity:
			velocity.y = -character.jump_release_velocity
			jump_rising = false
	if not grounded or velocity.y < 0.0:
		velocity.y += character.gravity * TICK
	var max_fall := character.fast_fall_speed if fast_falling else character.max_fall_speed
	velocity.y = minf(velocity.y, max_fall)


func _after_move() -> void:
	var was_grounded := grounded
	grounded = is_on_floor()
	on_one_way = false
	if grounded:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var collider := collision.get_collider() as CollisionObject2D
			if collider != null and collision.get_normal().y < -0.7 \
					and collider.get_collision_layer_value(Stage.LAYER_ONE_WAY):
				on_one_way = true
		air_jumps_left = character.air_jumps
		coyote_remaining = COYOTE_TICKS
		fast_falling = false
		if not was_grounded:
			jump_rising = false


func _try_jump() -> void:
	if jump_buffer <= 0:
		return
	if grounded or coyote_remaining > 0:
		velocity.y = -character.jump_velocity
	elif air_jumps_left > 0:
		air_jumps_left -= 1
		velocity.y = -character.double_jump_velocity
		request_effect(GameIds.EFFECT_DOUBLE_JUMP, global_position, Vector2.UP, {})
	else:
		return
	jump_buffer = 0
	coyote_remaining = 0
	grounded = false
	jump_rising = true
	fast_falling = false


func _start_drop_through() -> void:
	# Only the one-way layer is masked out; the solid main platform stays solid.
	set_collision_mask_value(Stage.LAYER_ONE_WAY, false)
	drop_remaining = DROP_THROUGH_TICKS
	grounded = false
	on_one_way = false
	coyote_remaining = 0
	position.y += 2.0


func _locomotion_state() -> State:
	if grounded:
		var speed := absf(velocity.x)
		if speed < WALK_SPEED_THRESHOLD:
			return State.IDLE
		return State.WALK if speed < RUN_SPEED_THRESHOLD else State.RUN
	return State.JUMP if velocity.y < 0.0 else State.FALL


# =============================================================================
# Moves
# =============================================================================
func _try_start_buffered_move(frame: InputFrame, allowed: Array) -> void:
	if attack_buffer <= 0 or attack_buffer_move == &"":
		return
	if not allowed.is_empty() and not allowed.has(attack_buffer_move):
		return
	var next := character.get_move(attack_buffer_move)
	if next == null or cooldowns.has(next.id):
		return
	_start_move(next, frame)


func _start_move(next: MoveData, frame: InputFrame) -> void:
	attack_buffer = 0
	attack_buffer_move = &""
	move = next
	move_tick = 0
	attack_instance += 1
	move_connected = false
	hit_registry.clear()
	state = State.ATTACK
	if next.cooldown_ticks > 0:
		cooldowns[next.id] = next.cooldown_ticks
	aim_angle_deg = 0.0
	if next.aimable:
		if frame.move_y <= -PlayerInput.DIGITAL_THRESHOLD:
			aim_angle_deg = next.aim_angle_deg
		elif frame.move_y >= PlayerInput.DIGITAL_THRESHOLD:
			aim_angle_deg = -next.aim_angle_deg
	if next.start_effect_id != &"":
		request_effect(next.start_effect_id, _effect_point(), aim_direction(),
			{"move_id": String(next.id), "duration_ticks": next.startup_ticks})


func _end_move() -> void:
	move = null
	move_tick = -1
	aim_angle_deg = 0.0
	hit_registry.clear()
	if held_target != null:
		held_target.end_held(0)
		held_target = null
	state = _locomotion_state()


func _grab_window_end() -> int:
	var end := 0
	for hb: HitboxData in move.hitboxes:
		if hb.kind == HitboxData.Kind.GRAB:
			end = maxi(end, hb.start_tick + hb.resolved_duration(move.active_ticks))
	return end


## Unit vector of the current attack direction (facing + aim).
func aim_direction() -> Vector2:
	var a := deg_to_rad(aim_angle_deg)
	return Vector2(cos(a) * facing, -sin(a))


## Active hitboxes this tick in world space. Each entry:
## {index: int, data: HitboxData, shape: HitboxData.Shape, center: Vector2, size: Vector2, radius: float}
func get_active_hitboxes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state != State.ATTACK or move == null or not move.is_active_tick(move_tick):
		return result
	var active_tick := move_tick - move.startup_ticks
	for i in move.hitboxes.size():
		var hb := move.hitboxes[i]
		if active_tick < hb.start_tick or active_tick >= hb.start_tick + hb.resolved_duration(move.active_ticks):
			continue
		result.append({
			"index": i, "data": hb, "shape": hb.shape,
			"center": local_to_world_point(_aimed_offset(hb.offset)),
			"size": hb.size, "radius": hb.radius,
		})
	return result


func _aimed_offset(offset: Vector2) -> Vector2:
	if aim_angle_deg == 0.0:
		return offset
	# Rotate in facing-right space about the pivot; a negative rotation is
	# visually upward because +Y points down.
	return move.aim_pivot + (offset - move.aim_pivot).rotated(-deg_to_rad(aim_angle_deg))


## Local facing-right point -> world point, mirrored by facing.
func local_to_world_point(local: Vector2) -> Vector2:
	return global_position + Vector2(local.x * facing, local.y)


func get_hurtbox_world() -> Rect2:
	return CombatMath.mirrored_rect(character.hurtbox, facing, global_position)


## Hit-once bookkeeping per attack instance. Multi-hit intervals are measured
## in this fighter's move ticks, which pause during hitstop, so hitstop can
## never produce extra hits.
func can_hit(victim: Fighter, hb: HitboxData) -> bool:
	var key := victim.get_instance_id()
	if not hit_registry.has(key):
		return true
	return hb.rehit_interval_ticks > 0 and move_tick - int(hit_registry[key]) >= hb.rehit_interval_ticks


func register_hit(victim: Fighter) -> void:
	hit_registry[victim.get_instance_id()] = move_tick


func is_in_play() -> bool:
	return state != State.KO and state != State.ELIMINATED and state != State.VICTORY


func is_hittable() -> bool:
	return is_in_play() and invulnerable_remaining <= 0


func is_guarding_against(damage_type: StringName, source_x: float) -> bool:
	if state != State.ATTACK or move == null or move.special_behaviour != GameIds.SPECIAL_GUARD:
		return false
	if not move.is_active_tick(move_tick) or not move.guard_damage_types.has(damage_type):
		return false
	# Front only: the source must be on (or exactly at) the facing side.
	return (source_x - global_position.x) * facing >= 0.0


# =============================================================================
# Being hit / held
# =============================================================================
## Applies a hit. Knockback is mirrored by `direction_sign`; `extra_angle_deg`
## adds the attacker's aim. Hitstop takes the max with any hitstop already set.
func receive_hit(hit_move: MoveData, direction_sign: int, extra_angle_deg: float, attacker_id: int, hitstop: int) -> void:
	if held_by != null:
		held_by.held_target = null
		held_by = null
		held_ticks = 0
	_interrupt_move()
	damage += hit_move.damage
	var kb := CombatMath.knockback_magnitude(hit_move, damage, character.weight)
	velocity = CombatMath.knockback_direction(hit_move.knockback_angle_deg + extra_angle_deg, direction_sign) * kb
	last_knockback = kb
	hitstun_total = CombatMath.hitstun_ticks(hit_move, kb)
	hitstun_remaining = hitstun_total
	hitstop_remaining = maxi(hitstop_remaining, hitstop)
	state = State.HITSTUN
	hit_counter += 1
	if velocity.y < 0.0:
		grounded = false
	_clear_buffers()
	fast_falling = false
	jump_rising = false
	damage_changed.emit(damage)
	_update_animation()
	request_effect(GameIds.EFFECT_HIT_SPARK, global_position + Vector2(0, character.hurtbox.get_center().y),
		velocity.normalized(), {"attacker_id": attacker_id, "victim_id": player_id,
		"move_id": String(hit_move.id), "damage": hit_move.damage, "knockback": kb})


## Adds damage without knockback (choke pulses).
func add_damage(amount: float) -> void:
	damage += amount
	damage_changed.emit(damage)


func begin_held(by: Fighter) -> void:
	_interrupt_move()
	held_by = by
	held_ticks = 0
	velocity = Vector2.ZERO
	state = State.HELD
	_clear_buffers()
	fast_falling = false
	jump_rising = false
	_update_animation()


func end_held(immunity_ticks: int) -> void:
	held_by = null
	held_ticks = 0
	grab_immunity_remaining = maxi(grab_immunity_remaining, immunity_ticks)
	if state == State.HELD:
		state = _locomotion_state()
		_update_animation()


func _interrupt_move() -> void:
	if state == State.ATTACK:
		_end_move()


func _clear_buffers() -> void:
	jump_buffer = 0
	attack_buffer = 0
	attack_buffer_move = &""


## Releases any hold link in either direction.
func break_hold_links() -> void:
	if held_target != null:
		held_target.end_held(0)
		held_target = null
	if held_by != null:
		held_by.held_target = null
		held_by = null
		held_ticks = 0


func _clear_combat_state() -> void:
	break_hold_links()
	move = null
	move_tick = -1
	aim_angle_deg = 0.0
	move_connected = false
	hit_registry.clear()
	cooldowns.clear()
	hitstun_remaining = 0
	hitstop_remaining = 0
	grab_immunity_remaining = 0
	_clear_buffers()
	fast_falling = false
	jump_rising = false
	if drop_remaining > 0:
		drop_remaining = 0
		set_collision_mask_value(Stage.LAYER_ONE_WAY, true)


# =============================================================================
# Stocks / match flow (called by MatchController)
# =============================================================================
## Called once when the root leaves the blast bounds. Never goes below 0.
func blast_ko() -> void:
	if not is_in_play():
		return
	_clear_combat_state()
	stocks = maxi(stocks - 1, 0)
	velocity = Vector2.ZERO
	visible = false
	stocks_changed.emit(stocks)
	if stocks == 0:
		state = State.ELIMINATED
		_update_animation()
		eliminated.emit(player_id)
	else:
		state = State.KO
		respawn_remaining = RESPAWN_DELAY_TICKS
		_update_animation()


func _respawn() -> void:
	_clear_combat_state()
	position = spawn_point
	velocity = Vector2.ZERO
	grounded = false
	damage = 0.0
	air_jumps_left = character.air_jumps
	invulnerable_remaining = RESPAWN_INVULNERABLE_TICKS
	state = State.FALL
	visible = true
	if input != null:
		input.reset_edges()
	damage_changed.emit(damage)
	request_effect(GameIds.EFFECT_RESPAWN, global_position, Vector2.UP, {"duration_ticks": RESPAWN_INVULNERABLE_TICKS})
	_update_animation()


## Terminal state for the winner. Gameplay stays frozen; only visuals play.
func set_victory() -> void:
	_clear_combat_state()
	if state == State.KO:
		position = spawn_point
	velocity = Vector2.ZERO
	invulnerable_remaining = 0
	visible = true
	state = State.VICTORY
	_update_animation()


func set_facing(value: int) -> void:
	value = 1 if value >= 0 else -1
	if value != facing:
		facing = value
		facing_changed.emit(facing)


func request_effect(effect_id: StringName, world_position: Vector2, direction: Vector2, payload: Dictionary) -> void:
	payload["player_id"] = player_id
	effect_requested.emit(effect_id, world_position, direction, payload)


func _effect_point() -> Vector2:
	return local_to_world_point(Vector2(30.0, -55.0))


# =============================================================================
# Presentation
# =============================================================================
## Emits animation_requested only when the animation (or a new instance of the
## same move / hit) changes; never every tick.
func _update_animation(force: bool = false) -> void:
	var id: StringName
	var duration := 0
	var loop := true
	var token := ""
	match state:
		State.IDLE: id = GameIds.ANIM_IDLE
		State.WALK: id = GameIds.ANIM_WALK
		State.RUN: id = GameIds.ANIM_RUN
		State.JUMP:
			id = GameIds.ANIM_JUMP
			loop = false
		State.FALL: id = GameIds.ANIM_FALL
		State.ATTACK:
			id = move.animation_id
			duration = move.total_ticks()
			loop = false
			token = str(attack_instance)
		State.HITSTUN:
			id = GameIds.ANIM_KNOCKBACK if last_knockback >= KNOCKBACK_ANIM_THRESHOLD else GameIds.ANIM_HURT
			duration = hitstun_total
			loop = false
			token = str(hit_counter)
		State.HELD:
			id = GameIds.ANIM_HURT
		State.KO, State.ELIMINATED:
			id = GameIds.ANIM_DEFEAT
			loop = false
		State.VICTORY:
			id = GameIds.ANIM_VICTORY
			loop = false
	var key := "%s|%s" % [id, token]
	if key == _animation_key and not force:
		return
	_animation_key = key
	animation_id = id
	animation_duration = duration
	animation_tick = 0
	animation_requested.emit(id, duration, loop)


## Read-only state for presentation adapters (safe to call at any time).
func get_presentation_snapshot() -> Dictionary:
	return {
		"character_id": character.id,
		"player_id": player_id,
		"state": STATE_NAMES[state],
		"facing": facing,
		"velocity": velocity,
		"grounded": grounded,
		"current_move_id": move.id if move != null else &"",
		"move_tick": move_tick if move != null else -1,
		"damage": damage,
		"stocks": stocks,
		"invulnerable": invulnerable_remaining > 0,
		"hitstop_remaining_ticks": hitstop_remaining,
		"animation_id": animation_id,
		"animation_tick": animation_tick,
		"animation_duration_ticks": animation_duration,
		"invulnerable_remaining_ticks": invulnerable_remaining,
		"aim_angle_deg": aim_angle_deg,
	}
