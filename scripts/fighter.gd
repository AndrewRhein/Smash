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

enum State {
	IDLE, WALK, RUN, JUMP, FALL, ATTACK, HITSTUN, HELD, KO, ELIMINATED, VICTORY,
	SHIELD, SHIELD_BREAK, DODGE, LAG, RESPAWN, LEDGE,
}
const STATE_NAMES := {
	State.IDLE: &"idle", State.WALK: &"walk", State.RUN: &"run", State.JUMP: &"jump",
	State.FALL: &"fall", State.ATTACK: &"attack", State.HITSTUN: &"hitstun",
	State.HELD: &"held", State.KO: &"ko", State.ELIMINATED: &"eliminated",
	State.VICTORY: &"victory", State.SHIELD: &"shield", State.SHIELD_BREAK: &"shield_break",
	State.DODGE: &"dodge", State.LAG: &"lag", State.RESPAWN: &"respawn",
	State.LEDGE: &"ledge",
}
enum DodgeKind { SPOT, ROLL, AIR }
const FREE_STATES := [State.IDLE, State.WALK, State.RUN, State.JUMP, State.FALL]

const TICK := 1.0 / 60.0
## Ticks after walking off a ledge during which a grounded jump is still allowed.
const COYOTE_TICKS := 6
## A jump/attack press is remembered for this many ticks (including its own).
const JUMP_BUFFER_TICKS := 6
const ATTACK_BUFFER_TICKS := 9
## Directional influence: holding the stick perpendicular to a launch bends it
## by up to this many degrees (Smash DI). Applied to launches of DI_MIN_KB+.
const DI_MAX_DEG := 15.0
const DI_MIN_KB := 250.0
## Landing during a normal aerial ends it with this much landing lag.
const AERIAL_LANDING_LAG := 6

# --- Ledges (Smash-style). Falling near a stage corner grabs it.
## Grab zone relative to the ledge corner, in "outside" units: x from the wall
## outward, y downward from the ledge top (feet position).
const LEDGE_GRAB_X := Vector2(-6.0, 56.0)
const LEDGE_GRAB_Y := Vector2(20.0, 120.0)
const LEDGE_INVULNERABLE_TICKS := 40
const LEDGE_MAX_HANG_TICKS := 300
## Ticks after letting go before the same fighter can grab again.
const LEDGE_REGRAB_TICKS := 36
## Inputs are ignored for this long after grabbing (so a held direction or a
## mashed button doesn't instantly act).
const LEDGE_ACTION_DELAY := 8
const LEDGE_JUMP_MULT := 1.05
const LEDGE_GETUP_LAG := 10

# --- Charged heavies: hold the heavy input to charge (up to 1 s, +40% damage).
const CHARGEABLE := [&"heavy", &"heavy_up", &"heavy_down"]
const CHARGE_MAX_TICKS := 60
const CHARGE_DAMAGE_BONUS := 0.4
## Light attacks (jab / tilts) that land can be cancelled into these in their
## recovery when the character's data does not list its own cancels.
const LIGHT_FAMILY := [&"light", &"light_up", &"light_down"]
const DEFAULT_LIGHT_CANCELS := [&"heavy", &"heavy_up", &"heavy_down",
	&"special_1", &"special_2", &"special_3", &"special_up"]
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
const MOVE_PRIORITY := [&"special", &"special_1", &"special_2", &"special_3", &"heavy", &"light"]

# --- Shield (Smash-style). Health is in "shield points"; hits subtract damage.
const SHIELD_MAX := 50.0
## Drain per tick while held (a full shield lasts ~7 s if never hit).
const SHIELD_DECAY_PER_TICK := 0.12
## Regeneration per tick while not shielding (~10 s from empty to full).
const SHIELD_REGEN_PER_TICK := 0.08
## Shield damage taken per point of move damage.
const SHIELD_DAMAGE_MULTIPLIER := 1.2
## Shieldstun = damage * this + 2 ticks (can't drop shield or act).
const SHIELD_STUN_PER_DAMAGE := 0.8
## Ticks of vulnerable lag after releasing shield.
const SHIELD_DROP_TICKS := 7
## Pushback on the shielder (px/s) = base + damage * per_damage.
const SHIELD_PUSHBACK_BASE := 160.0
const SHIELD_PUSHBACK_PER_DAMAGE := 22.0
## Shield break: popped upward, then dizzy (fully vulnerable) for this long.
const SHIELD_BREAK_TICKS := 180
const SHIELD_BREAK_POP := 760.0
const SHIELD_AFTER_BREAK := SHIELD_MAX * 0.375

# --- Dodges. Intangible = hits pass through (incl. projectiles and grabs).
const SPOT_DODGE_TICKS := 26
const SPOT_DODGE_INTANGIBLE := Vector2i(3, 18)   # [start, end) dodge ticks
const ROLL_TICKS := 32
const ROLL_INTANGIBLE := Vector2i(4, 20)
const ROLL_MOVE := Vector2i(2, 22)               # ticks during which the roll travels
const ROLL_SPEED := 440.0
const AIR_DODGE_TICKS := 34
const AIR_DODGE_INTANGIBLE := Vector2i(3, 25)
const AIR_DODGE_SPEED := 620.0
## Directional air dodges ignore gravity for this many ticks and decay speed.
const AIR_DODGE_FLOAT_TICKS := 18
const AIR_DODGE_DECAY := 0.88

# --- Respawn platform: hover, invulnerable, until any input or timeout.
const RESPAWN_PLATFORM_MAX_TICKS := 180

var character: CharacterData
var player_id: int = 1
var input: PlayerInput
var spawn_point: Vector2 = Vector2.ZERO
## Where the respawn platform appears (set by the match from the stage).
var respawn_point: Vector2 = Vector2.ZERO

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
## Presentation-only countdown after a self-heal (snapshot "healing").
var heal_glow_remaining: int = 0
## Last stick direction sampled (for DI when hit).
var last_stick: Vector2 = Vector2.ZERO
## The current move started in the air (normal aerials auto-cancel on landing).
var move_started_airborne: bool = false
## Ledges of the stage and the shared claims (set by the match).
var ledges: Array[Dictionary] = []
var ledge_claims: Dictionary = {}
var ledge_index: int = -1
var ledge_ticks: int = 0
var ledge_regrab_remaining: int = 0
## Charged heavy: ticks charged so far, and whether the charge is being held now.
var charge_ticks: int = 0
var charging: bool = false
var _charge_applied: bool = false
var respawn_remaining: int = 0
var held_ticks: int = 0
var shield_health: float = SHIELD_MAX
var shield_stun_remaining: int = 0
var shield_break_remaining: int = 0
var lag_remaining: int = 0
var respawn_platform_remaining: int = 0

# Dodges / recovery
var dodge_kind: DodgeKind = DodgeKind.SPOT
var dodge_tick: int = 0
var dodge_dir: Vector2 = Vector2.ZERO
var dodge_counter: int = 0
## One air dodge per airtime (restored on landing, on being hit, on respawn).
var air_dodge_available: bool = true
## After an up special ends airborne: may only drift and fast fall until landing.
var helpless: bool = false

# Movement helpers
var jump_buffer: int = 0
var attack_buffer: int = 0
var attack_buffer_move: StringName = &""
## Facing to apply when the buffered move starts (side special / right-stick
## heavy); 0 = keep current facing.
var attack_buffer_facing: int = 0
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
var status_visual: Node2D


func setup(data: CharacterData, id: int, spawn: Vector2, stock_count: int, player_input: PlayerInput) -> void:
	character = data
	player_id = id
	spawn_point = spawn
	stocks = stock_count
	input = player_input
	respawn_point = spawn
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
	# Shield bubble / respawn platform / dizzy overlay (placeholder, presentation only).
	status_visual = PlaceholderStatusVisual.new()
	status_visual.name = "StatusVisual"
	add_child(status_visual)


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
	if state == State.RESPAWN:
		_tick_respawn(frame)
		if state == State.RESPAWN:
			_tick_timers()
			_update_animation()
			animation_tick += 1
			return
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
		State.SHIELD:
			_tick_shield(frame)
		State.SHIELD_BREAK:
			_tick_shield_break()
		State.DODGE:
			_tick_dodge(frame)
		State.LAG:
			_tick_lag(frame)
		State.LEDGE:
			_tick_ledge(frame)
		_:
			_tick_free(frame)
	if state != State.HELD and state != State.LEDGE:
		_apply_vertical(frame)
		move_and_slide()
		_after_move()
		if state in FREE_STATES:
			state = _locomotion_state()
		_try_grab_ledge()
	_tick_timers()
	_update_animation()
	animation_tick += 1


func _record_buffers(frame: InputFrame) -> void:
	last_stick = frame.stick()
	if frame.is_pressed(&"jump"):
		jump_buffer = JUMP_BUFFER_TICKS
	for button: StringName in MOVE_PRIORITY:
		if not frame.is_pressed(button):
			continue
		attack_buffer_facing = 0
		match button:
			&"special":
				# One Special button: the stick picks neutral / side / up / down.
				attack_buffer_move = character.special_for_direction(frame.stick())
				if attack_buffer_move == character.side_special:
					attack_buffer_facing = _horizontal_sign(frame.stick())
			&"heavy":
				# The right stick's direction wins over the left stick's.
				var dir := Vector2(frame.smash_x, frame.smash_y)
				if dir == Vector2.ZERO:
					dir = frame.stick()
				attack_buffer_move = character.resolve_attack(&"heavy", dir, grounded, facing)
				# Smash turnaround: a heavy aimed behind you turns you around.
				if attack_buffer_move == &"heavy":
					attack_buffer_facing = _horizontal_sign(dir)
			&"light":
				attack_buffer_move = character.resolve_attack(&"light", frame.stick(), grounded, facing)
				# Forward tilts (and aerials with no dedicated back air) turn
				# toward the stick; a real back air keeps facing and hits behind.
				if attack_buffer_move in [&"light", &"air_neutral", &"air_forward"]:
					attack_buffer_facing = _horizontal_sign(frame.stick())
			_:
				attack_buffer_move = button
		attack_buffer = ATTACK_BUFFER_TICKS
		break


## -1/+1 when `dir` is a mostly-horizontal tilt past the digital threshold,
## otherwise 0 (keep the current facing).
static func _horizontal_sign(dir: Vector2) -> int:
	if absf(dir.x) < PlayerInput.DIGITAL_THRESHOLD or absf(dir.y) > absf(dir.x):
		return 0
	return 1 if dir.x > 0.0 else -1


func _tick_timers() -> void:
	heal_glow_remaining = maxi(heal_glow_remaining - 1, 0)
	ledge_regrab_remaining = maxi(ledge_regrab_remaining - 1, 0)
	jump_buffer = maxi(jump_buffer - 1, 0)
	attack_buffer = maxi(attack_buffer - 1, 0)
	if attack_buffer == 0:
		attack_buffer_move = &""
	invulnerable_remaining = maxi(invulnerable_remaining - 1, 0)
	if state != State.SHIELD and state != State.SHIELD_BREAK:
		shield_health = minf(shield_health + SHIELD_REGEN_PER_TICK, SHIELD_MAX)
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
	if frame.move_x != 0.0 and (grounded or not helpless):
		set_facing(1 if frame.move_x > 0.0 else -1)
	_apply_horizontal(frame.move_x * character.max_speed, frame.move_x != 0.0)
	if grounded and frame.is_held(&"shield") and not frame.is_pressed(&"jump"):
		_enter_shield()
		return
	if not grounded and frame.is_pressed(&"shield") and air_dodge_available and not helpless:
		_start_dodge(DodgeKind.AIR, frame.stick())
		return
	if grounded and on_one_way and frame.is_pressed(&"down"):
		_start_drop_through()
	elif not grounded and frame.is_pressed(&"down") and velocity.y > -FAST_FALL_MAX_RISE:
		fast_falling = true
		jump_rising = false
		velocity.y = maxf(velocity.y, character.fast_fall_speed)
	if helpless:
		return  # Special fall: drift and fast fall only.
	_try_jump()
	_try_start_buffered_move(frame, [])


func _tick_attack(frame: InputFrame) -> void:
	charging = _wants_charge(frame)
	if charging:
		charge_ticks += 1
		_apply_horizontal(0.0, false)
		return
	if charge_ticks > 0 and not _charge_applied:
		_apply_charge()
	move_tick += 1
	if move_tick >= move.total_ticks():
		_end_move()
		_tick_free(frame)
		return
	# Choke whiff: grab window over without a grab -> straight to recovery.
	if move.whiff_to_recovery and held_target == null and move.is_active_tick(move_tick) \
			and move_tick - move.startup_ticks >= _grab_window_end():
		move_tick = move.startup_ticks + move.active_ticks
	if move.self_impulse != Vector2.ZERO and move_tick == move.startup_ticks + move.self_impulse_tick:
		velocity = Vector2(move.self_impulse.x * facing, move.self_impulse.y)
		grounded = false
		jump_rising = false
		fast_falling = false
	if move.self_heal > 0.0 and move_tick == move.startup_ticks + move.self_heal_tick:
		damage = maxf(0.0, damage - move.self_heal)
		heal_glow_remaining = 45
		damage_changed.emit(damage)
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
	var cancels: Array = move.cancel_into
	if move_connected and LIGHT_FAMILY.has(move.id) and grounded:
		# Hit-confirm combos: a landed jab/tilt can always cancel into heavies and specials.
		cancels = cancels.duplicate()
		for id: StringName in DEFAULT_LIGHT_CANCELS:
			if not cancels.has(id):
				cancels.append(id)
	if move.is_recovery_tick(move_tick) and not cancels.is_empty() \
			and (move_connected or not move.cancel_requires_hit):
		_try_start_buffered_move(frame, cancels)


func _tick_hitstun() -> void:
	# Knockback is preserved: input is ignored, only drag/friction and gravity act.
	var decel := HITSTUN_GROUND_FRICTION if grounded else HITSTUN_AIR_DRAG
	velocity.x = move_toward(velocity.x, 0.0, decel * TICK)
	hitstun_remaining -= 1
	if hitstun_remaining <= 0:
		hitstun_remaining = 0
		state = _locomotion_state()


# =============================================================================
# Shield, dodges, lag, respawn platform
# =============================================================================
func _enter_shield() -> void:
	state = State.SHIELD
	shield_stun_remaining = 0
	fast_falling = false


func _tick_shield(frame: InputFrame) -> void:
	# Pushback slides out with ground friction; no walking while shielding.
	velocity.x = move_toward(velocity.x, 0.0, character.ground_decel * TICK)
	shield_health -= SHIELD_DECAY_PER_TICK
	if shield_health <= 0.0:
		_shield_break()
		return
	if shield_stun_remaining > 0:
		shield_stun_remaining -= 1
		return
	# Out-of-shield options (Smash): jump, spot dodge, roll, up special.
	if jump_buffer > 0:
		state = State.IDLE
		_try_jump()
		return
	if frame.is_pressed(&"down"):
		_start_dodge(DodgeKind.SPOT, Vector2.ZERO)
		return
	if frame.is_pressed(&"left") or frame.is_pressed(&"right"):
		_start_dodge(DodgeKind.ROLL, Vector2(-1 if frame.is_pressed(&"left") else 1, 0))
		return
	if attack_buffer > 0 and attack_buffer_move == character.up_special:
		state = State.IDLE
		_try_start_buffered_move(frame, [])
		return
	if not frame.is_held(&"shield"):
		state = State.LAG
		lag_remaining = SHIELD_DROP_TICKS


func _start_dodge(kind: DodgeKind, direction: Vector2) -> void:
	state = State.DODGE
	dodge_kind = kind
	dodge_tick = 0
	dodge_counter += 1
	dodge_dir = Vector2.ZERO
	fast_falling = false
	jump_rising = false
	match kind:
		DodgeKind.SPOT:
			velocity.x = 0.0
		DodgeKind.ROLL:
			dodge_dir = Vector2(signf(direction.x), 0)
		DodgeKind.AIR:
			air_dodge_available = false
			if direction.length() >= 0.35:
				dodge_dir = direction.normalized()
				velocity = dodge_dir * AIR_DODGE_SPEED
			else:
				velocity *= 0.25  # Neutral air dodge: brief stall in place.


func _tick_dodge(frame: InputFrame) -> void:
	dodge_tick += 1
	match dodge_kind:
		DodgeKind.SPOT:
			velocity.x = 0.0
			if dodge_tick >= SPOT_DODGE_TICKS:
				_end_dodge(frame)
		DodgeKind.ROLL:
			if not _ground_ahead(int(dodge_dir.x)):
				velocity.x = 0.0  # Stop at the ledge (no rolling off the stage).
			elif dodge_tick >= ROLL_MOVE.x and dodge_tick < ROLL_MOVE.y:
				velocity.x = dodge_dir.x * ROLL_SPEED
			else:
				velocity.x = move_toward(velocity.x, 0.0, character.ground_decel * TICK)
			if dodge_tick >= ROLL_TICKS:
				set_facing(-int(dodge_dir.x))  # Rolls end facing back where you came from.
				_end_dodge(frame)
		DodgeKind.AIR:
			if dodge_dir != Vector2.ZERO and dodge_tick < AIR_DODGE_FLOAT_TICKS:
				velocity *= AIR_DODGE_DECAY
			else:
				_apply_horizontal(frame.move_x * character.max_speed, frame.move_x != 0.0)
			if dodge_tick >= AIR_DODGE_TICKS:
				_end_dodge(frame)


func _end_dodge(frame: InputFrame = null) -> void:
	state = _locomotion_state()
	if frame != null and grounded and frame.is_held(&"shield"):
		_enter_shield()


## True if there is floor directly below a point a short step ahead (rolls stop
## at ledges). A thin ray, not the capsule, so rounded body edges don't count.
func _ground_ahead(direction: int) -> bool:
	var from := global_position + Vector2(direction * 20.0, -6.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 24), collision_mask, [get_rid()])
	query.hit_from_inside = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _tick_lag(frame: InputFrame) -> void:
	velocity.x = move_toward(velocity.x, 0.0, character.ground_decel * TICK)
	lag_remaining -= 1
	if lag_remaining <= 0:
		state = _locomotion_state()
		if grounded and frame.is_held(&"shield"):
			_enter_shield()


func _tick_shield_break() -> void:
	# Dizzy: no control at all; fully vulnerable to attacks.
	var decel := HITSTUN_GROUND_FRICTION if grounded else HITSTUN_AIR_DRAG
	velocity.x = move_toward(velocity.x, 0.0, decel * TICK)
	shield_break_remaining -= 1
	if shield_break_remaining <= 0:
		shield_health = SHIELD_AFTER_BREAK
		state = _locomotion_state()


func _shield_break() -> void:
	shield_health = 0.0
	shield_stun_remaining = 0
	state = State.SHIELD_BREAK
	shield_break_remaining = SHIELD_BREAK_TICKS
	velocity = Vector2(0, -SHIELD_BREAK_POP)
	grounded = false
	_clear_buffers()
	request_effect(GameIds.EFFECT_HIT_SPARK, global_position + Vector2(0, -60), Vector2.UP,
		{"shield_break": true, "victim_id": player_id, "duration_ticks": SHIELD_BREAK_TICKS})
	_update_animation()


## A strike or projectile landed on the shield. Called by the match.
func receive_shield_hit(hit_move: MoveData, direction_sign: int, attacker_id: int, hitstop: int) -> void:
	shield_health -= hit_move.damage * SHIELD_DAMAGE_MULTIPLIER
	hitstop_remaining = maxi(hitstop_remaining, hitstop)
	if shield_health <= 0.0:
		_shield_break()
		return
	shield_stun_remaining = int(hit_move.damage * SHIELD_STUN_PER_DAMAGE) + 2
	velocity.x = direction_sign * (SHIELD_PUSHBACK_BASE + hit_move.damage * SHIELD_PUSHBACK_PER_DAMAGE)
	# guard_block doubles as the shield-hit effect (payload "shield": true).
	request_effect(GameIds.EFFECT_GUARD_BLOCK, global_position + Vector2(0, character.hurtbox.get_center().y),
		Vector2(-direction_sign, 0), {"shield": true, "attacker_id": attacker_id,
		"move_id": String(hit_move.id), "shield_ratio": shield_health / SHIELD_MAX})


func _tick_respawn(frame: InputFrame) -> void:
	velocity = Vector2.ZERO
	invulnerable_remaining = RESPAWN_INVULNERABLE_TICKS  # Held while on the platform.
	respawn_platform_remaining -= 1
	var acted := frame.pressed_mask != 0 or frame.move_x != 0.0 or frame.move_y != 0.0
	if not acted and respawn_platform_remaining > 0:
		return
	# Leave the platform: a jump from it counts as a grounded jump.
	state = State.FALL
	coyote_remaining = COYOTE_TICKS
	request_effect(GameIds.EFFECT_RESPAWN, global_position, Vector2.DOWN, {"left_platform": true})


func _apply_horizontal(target_speed: float, has_input: bool) -> void:
	var rate: float
	if grounded:
		rate = character.ground_accel if has_input else character.ground_decel
		# Skid turn: reversing direction brakes hard, so turnarounds feel crisp.
		if has_input and velocity.x * target_speed < 0.0:
			rate += character.ground_decel
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
	if state == State.DODGE and dodge_kind == DodgeKind.AIR and dodge_tick < AIR_DODGE_FLOAT_TICKS \
			and dodge_dir != Vector2.ZERO:
		return  # Directional air dodge travels in a straight line, no gravity.
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
		helpless = false
		air_dodge_available = true
		if not was_grounded:
			jump_rising = false
			if state == State.DODGE and dodge_kind == DodgeKind.AIR:
				_end_dodge()  # Landing cancels the air dodge.
			elif state == State.ATTACK and move_started_airborne and move.self_impulse == Vector2.ZERO \
					and not String(move.id).begins_with("special") and held_target == null:
				# Normal aerials end on landing with a short landing lag.
				_end_move()
				state = State.LAG
				lag_remaining = AERIAL_LANDING_LAG
	elif state == State.SHIELD or (state == State.DODGE and dodge_kind != DodgeKind.AIR):
		# Pushed off a ledge while shielding / dodging.
		state = State.FALL


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
# Ledges
# =============================================================================
func _try_grab_ledge() -> void:
	if ledges.is_empty() or grounded or ledge_regrab_remaining > 0 or velocity.y < 0.0:
		return
	var recovering := state == State.ATTACK and move != null and move.helpless_after
	if not (state in [State.JUMP, State.FALL] or recovering):
		return
	for i in ledges.size():
		var ledge: Dictionary = ledges[i]
		var corner: Vector2 = ledge.point
		var side: int = ledge.side
		var out_x := (position.x - corner.x) * side  # distance outward from the wall
		var below := position.y - corner.y
		if out_x < LEDGE_GRAB_X.x or out_x > LEDGE_GRAB_X.y or below < LEDGE_GRAB_Y.x or below > LEDGE_GRAB_Y.y:
			continue
		if ledge_claims.get(i, player_id) != player_id:
			continue  # someone else is hanging there
		_grab_ledge(i)
		return


func _grab_ledge(i: int) -> void:
	if state == State.ATTACK:
		_end_move()
	var ledge: Dictionary = ledges[i]
	ledge_index = i
	ledge_claims[i] = player_id
	ledge_ticks = 0
	state = State.LEDGE
	velocity = Vector2.ZERO
	set_facing(-int(ledge.side))  # face the stage
	position = Vector2(ledge.point.x + ledge.side * (character.body_radius + 3.0),
		ledge.point.y - character.hurtbox.position.y * 0.82)
	invulnerable_remaining = maxi(invulnerable_remaining, LEDGE_INVULNERABLE_TICKS)
	helpless = false
	fast_falling = false
	jump_rising = false
	air_jumps_left = character.air_jumps
	air_dodge_available = true
	_clear_buffers()


func _release_ledge() -> void:
	if ledge_index >= 0:
		if ledge_claims.get(ledge_index, -1) == player_id:
			ledge_claims.erase(ledge_index)
		ledge_index = -1
		ledge_regrab_remaining = LEDGE_REGRAB_TICKS


func _tick_ledge(frame: InputFrame) -> void:
	ledge_ticks += 1
	velocity = Vector2.ZERO
	var ledge: Dictionary = ledges[ledge_index]
	var toward := -int(ledge.side)
	if ledge_ticks >= LEDGE_MAX_HANG_TICKS:
		_drop_from_ledge()
		return
	if ledge_ticks < LEDGE_ACTION_DELAY:
		return
	var stick := frame.stick()
	if jump_buffer > 0:
		jump_buffer = 0
		_release_ledge()
		state = State.JUMP
		# Pop up to the ledge top first so the stage wall can't eat the drift.
		position.y = ledge.point.y - 2.0
		velocity = Vector2(toward * 260.0, -character.jump_velocity * LEDGE_JUMP_MULT)
		jump_rising = true
		return
	if frame.is_pressed(&"down") or (absf(stick.x) >= PlayerInput.DIGITAL_THRESHOLD and signf(stick.x) == -toward \
			and (frame.is_pressed(&"left") or frame.is_pressed(&"right"))):
		_drop_from_ledge()
		return
	var on_stage := Vector2(ledge.point.x + toward * (character.body_radius + 12.0), ledge.point.y)
	if frame.is_pressed(&"shield"):
		_release_ledge()
		position = on_stage
		grounded = true
		_start_dodge(DodgeKind.ROLL, Vector2(toward, 0))
		return
	if attack_buffer > 0 and attack_buffer_move != &"":
		_release_ledge()
		position = on_stage
		grounded = true
		state = State.IDLE
		attack_buffer_facing = 0
		attack_buffer_move = character.resolve_attack(&"light", Vector2.ZERO, true, facing) \
			if not String(attack_buffer_move).begins_with("special") else attack_buffer_move
		_try_start_buffered_move(frame, [])
		return
	if frame.is_pressed(&"up") or ((frame.is_pressed(&"left") or frame.is_pressed(&"right")) and signf(stick.x) == toward):
		_release_ledge()
		position = on_stage
		grounded = true
		state = State.LAG
		lag_remaining = LEDGE_GETUP_LAG
		invulnerable_remaining = maxi(invulnerable_remaining, LEDGE_GETUP_LAG)


func _drop_from_ledge() -> void:
	_release_ledge()
	state = State.FALL
	velocity = Vector2.ZERO


# =============================================================================
# Charged heavies
# =============================================================================
func _wants_charge(frame: InputFrame) -> bool:
	if _charge_applied or not grounded or not CHARGEABLE.has(move.id):
		return false
	if move_tick != maxi(move.startup_ticks - 2, 0) or charge_ticks >= CHARGE_MAX_TICKS:
		return false
	return frame.is_held(&"heavy") or frame.smash_x != 0 or frame.smash_y != 0


## Replaces the current move with a stronger copy (shared data is never mutated).
func _apply_charge() -> void:
	_charge_applied = true
	var bonus := CHARGE_DAMAGE_BONUS * float(charge_ticks) / CHARGE_MAX_TICKS
	var charged := move.duplicate() as MoveData
	charged.damage = move.damage * (1.0 + bonus)
	charged.knockback_base = move.knockback_base * (1.0 + bonus * 0.5)
	move = charged


# =============================================================================
# Moves
# =============================================================================
func _try_start_buffered_move(frame: InputFrame, allowed: Array) -> void:
	if attack_buffer <= 0 or attack_buffer_move == &"":
		return
	if not allowed.is_empty() and not allowed.has(attack_buffer_move):
		return
	var next := character.get_move(attack_buffer_move)
	if next == null or cooldowns.has(next.id) or helpless:
		return
	if attack_buffer_facing != 0:
		set_facing(attack_buffer_facing)
	_start_move(next, frame)


func _start_move(next: MoveData, frame: InputFrame) -> void:
	attack_buffer = 0
	attack_buffer_move = &""
	move = next
	move_tick = 0
	move_started_airborne = not grounded
	charge_ticks = 0
	charging = false
	_charge_applied = false
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
	if move != null and move.helpless_after and not grounded:
		helpless = true
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
	return is_in_play() and invulnerable_remaining <= 0 and not is_intangible() and state != State.RESPAWN


## Dodge intangibility window (hits, projectiles and grabs pass through).
func is_intangible() -> bool:
	if state != State.DODGE:
		return false
	var window: Vector2i
	match dodge_kind:
		DodgeKind.SPOT: window = SPOT_DODGE_INTANGIBLE
		DodgeKind.ROLL: window = ROLL_INTANGIBLE
		_: window = AIR_DODGE_INTANGIBLE
	return dodge_tick >= window.x and dodge_tick < window.y


## Shield is up (blocks every strike and projectile from any side; grabs beat it).
func is_shielding() -> bool:
	return state == State.SHIELD


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
	_release_ledge()
	if held_by != null:
		held_by.held_target = null
		held_by = null
		held_ticks = 0
	_interrupt_move()
	damage += hit_move.damage
	var kb := CombatMath.knockback_magnitude(hit_move, damage, character.weight)
	var launch_dir := CombatMath.knockback_direction(hit_move.knockback_angle_deg + extra_angle_deg, direction_sign)
	if kb >= DI_MIN_KB and last_stick.length() >= PlayerInput.DIGITAL_THRESHOLD:
		# DI: the perpendicular part of the stick bends the launch angle.
		var perpendicular := Vector2(-launch_dir.y, launch_dir.x)
		var amount := clampf(last_stick.normalized().dot(perpendicular), -1.0, 1.0)
		launch_dir = launch_dir.rotated(deg_to_rad(DI_MAX_DEG) * amount)
	velocity = launch_dir * kb
	last_knockback = kb
	hitstun_total = CombatMath.hitstun_ticks(hit_move, kb)
	hitstun_remaining = hitstun_total
	hitstop_remaining = maxi(hitstop_remaining, hitstop)
	state = State.HITSTUN
	hit_counter += 1
	helpless = false
	air_dodge_available = true
	shield_stun_remaining = 0
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
	_release_ledge()
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
	_release_ledge()
	ledge_regrab_remaining = 0
	charge_ticks = 0
	charging = false
	move = null
	move_tick = -1
	aim_angle_deg = 0.0
	move_connected = false
	hit_registry.clear()
	cooldowns.clear()
	heal_glow_remaining = 0
	hitstun_remaining = 0
	hitstop_remaining = 0
	grab_immunity_remaining = 0
	shield_stun_remaining = 0
	shield_break_remaining = 0
	lag_remaining = 0
	helpless = false
	air_dodge_available = true
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
	position = respawn_point
	velocity = Vector2.ZERO
	grounded = false
	damage = 0.0
	shield_health = SHIELD_MAX
	air_jumps_left = character.air_jumps
	# Hover on the respawn platform facing the stage until the player acts.
	set_facing(1 if respawn_point.x < 640.0 else -1)
	state = State.RESPAWN
	respawn_platform_remaining = RESPAWN_PLATFORM_MAX_TICKS
	invulnerable_remaining = RESPAWN_INVULNERABLE_TICKS
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
		State.SHIELD:
			id = GameIds.ANIM_SHIELD
		State.SHIELD_BREAK:
			id = GameIds.ANIM_SHIELD_BREAK
		State.DODGE:
			match dodge_kind:
				DodgeKind.SPOT:
					id = GameIds.ANIM_SPOT_DODGE
					duration = SPOT_DODGE_TICKS
				DodgeKind.ROLL:
					id = GameIds.ANIM_ROLL
					duration = ROLL_TICKS
				_:
					id = GameIds.ANIM_AIR_DODGE
					duration = AIR_DODGE_TICKS
			loop = false
			token = "dodge%d" % dodge_counter
		State.LAG, State.RESPAWN:
			id = GameIds.ANIM_IDLE
		State.LEDGE:
			id = GameIds.ANIM_FALL
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
		"shielding": is_shielding(),
		"shield_health": shield_health,
		"shield_max": SHIELD_MAX,
		"intangible": is_intangible(),
		"helpless": helpless,
		"on_respawn_platform": state == State.RESPAWN,
		# Presentation hint while held by a grab, e.g. &"frozen" (Cold Hands).
		"healing": heal_glow_remaining > 0,
		"charging": charging,
		"charge_ratio": float(charge_ticks) / CHARGE_MAX_TICKS,
		"on_ledge": state == State.LEDGE,
		"held_visual": held_by.move.hold_visual if state == State.HELD and held_by != null and held_by.move != null else &"",
	}
