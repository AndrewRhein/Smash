class_name CpuInput
extends PlayerInput
## A simple computer player. It "presses buttons" through the same scripted
## input path tests use, so it obeys every gameplay rule a human does.
##
## Behaviour, in priority order every tick:
##   1. Ledge: wait a moment, then get up / ledge jump / roll in.
##   2. Recovery: off stage -> drift home, double jump, then up special.
##   3. Launched: DI toward the stage (survival DI).
##   4. Every reaction window: shield a nearby attack, attack when in range
##      (light / heavy / specials, sometimes jump attacks), throw a projectile
##      from mid range, otherwise walk toward the nearest opponent without
##      walking off the stage.
## Level 1-9 scales reaction time, aggression, shielding and accuracy.
## Randomness is seeded per player, so a match replays identically.

const MIN_LEVEL := 1
const MAX_LEVEL := 9
const DEFAULT_LEVEL := 5

var level: int = DEFAULT_LEVEL
var match_controller: MatchController
var _rng := RandomNumberGenerator.new()
var _cooldown := 0           # ticks until the next decision
var _walk_dir := 0.0         # held horizontal input between decisions
var _shield_ticks := 0
var _jump_lock := 0          # ticks before another recovery jump
var _ledge_wait := 0
var _queued: StringName = &""  # button to press after a jump
var _queued_delay := 0
var _jump_hold := 0         # ticks left holding jump (full hop)


func _init(id: int, p_level: int = DEFAULT_LEVEL) -> void:
	super(id, true)
	level = clampi(p_level, MIN_LEVEL, MAX_LEVEL)
	_rng.seed = 7919 * id + level


func bind(controller: MatchController) -> void:
	match_controller = controller


func reset_edges() -> void:
	release_all()
	_cooldown = 0
	_jump_hold = 0
	_queued_delay = 0
	_walk_dir = 0.0
	_shield_ticks = 0
	_queued = &""
	super.reset_edges()


func sample() -> InputFrame:
	_think()
	return super.sample()


## Ticks between decisions: ~24 at level 1, ~4 at level 9.
func reaction_ticks() -> int:
	return maxi(4, 26 - level * 2 - (level / 3) * 2)


func _skill() -> float:
	return float(level - MIN_LEVEL) / float(MAX_LEVEL - MIN_LEVEL)  # 0..1


func _think() -> void:
	_script_taps.clear()
	_script_held.clear()
	clear_axis()
	if match_controller == null or match_controller.state != MatchController.MatchState.PLAYING:
		return
	var me := match_controller.get_fighter(player_id)
	if me == null or not me.is_in_play():
		return
	_jump_lock = maxi(_jump_lock - 1, 0)
	var stage := _stage_rect()
	match me.state:
		Fighter.State.RESPAWN:
			if _rng.randf() < 0.05:
				tap(&"jump")
			return
		Fighter.State.LEDGE:
			_on_ledge(me)
			return
		Fighter.State.HITSTUN:
			if _skill() > 0.25:
				var home := signf(stage.get_center().x - me.position.x)
				set_axis(Vector2(home, -1.0).normalized())
			return
		Fighter.State.HELD, Fighter.State.SHIELD_BREAK:
			return
	if _off_stage(me, stage):
		_recover(me, stage)
		return
	var target := _nearest_opponent(me)
	if _jump_hold > 0:
		# Full hop toward the target (holding jump goes higher than a tap).
		_jump_hold -= 1
		set_held(&"jump", true)
		if target != null:
			set_axis(Vector2(signf(target.position.x - me.position.x), 0))
		return
	if _queued != &"":
		_queued_delay -= 1
		if _queued_delay <= 0:
			tap(_queued)
			_queued = &""
		elif target != null:
			set_axis(Vector2(signf(target.position.x - me.position.x), 0))
		return
	# Airborne and still below a higher target: double jump.
	if target != null and not me.grounded and me.air_jumps_left > 0 and me.velocity.y > -80.0 \
			and target.position.y < me.position.y - 40.0 and _jump_lock == 0:
		tap(&"jump")
		_jump_lock = 25
		set_axis(Vector2(signf(target.position.x - me.position.x), 0))
		return
	if _shield_ticks > 0:
		_shield_ticks -= 1
		set_held(&"shield", true)
		return
	if target == null:
		return
	_cooldown -= 1
	if _cooldown > 0:
		_hold_walk(me, stage)
		return
	_cooldown = reaction_ticks() + _rng.randi_range(0, reaction_ticks())
	_decide(me, target, stage)


func _decide(me: Fighter, target: Fighter, stage: Rect2) -> void:
	var dx := target.position.x - me.position.x
	var dy := target.position.y - me.position.y
	var dist := absf(dx)
	var toward := signf(dx) if dx != 0.0 else float(me.facing)
	var aggression := 0.35 + 0.6 * _skill()
	_walk_dir = 0.0
	# Defend: shield an attack that's about to land.
	if target.state == Fighter.State.ATTACK and dist < 120.0 and me.grounded \
			and _rng.randf() < 0.08 + 0.5 * _skill():
		_shield_ticks = _rng.randi_range(10, 20)
		set_held(&"shield", true)
		return
	# In range: attack.
	if dist < 85.0 and absf(dy) < 70.0 and _rng.randf() < aggression:
		_attack(me, target, toward, dy)
		return
	# Target above us and close: jump attack.
	if dist < 110.0 and dy < -70.0 and me.grounded and _rng.randf() < aggression:
		_jump_hold = 10
		_queued = &"light"
		_queued_delay = 8
		return
	# Mid range: projectile / special.
	if dist > 160.0 and dist < 420.0 and absf(dy) < 90.0 and me.facing == int(toward) \
			and _rng.randf() < 0.12 + 0.12 * _skill():
		tap(&"special")
		return
	# Otherwise move toward the opponent (sometimes jump to their platform).
	_walk_dir = toward
	if dy < -90.0 and me.grounded and absf(dx) < 220.0 and _rng.randf() < 0.6:
		_jump_hold = 14
	elif dy > 60.0 and me.grounded and me.on_one_way and _rng.randf() < 0.5:
		set_axis(Vector2(0, 1))  # drop through toward them
		_walk_dir = 0.0
		return
	_hold_walk(me, stage)


func _attack(me: Fighter, target: Fighter, toward: float, dy: float) -> void:
	var roll := _rng.randf()
	# Go for the finisher when the target is at high damage.
	if target.damage > 90.0 and _rng.randf() < 0.25 + 0.35 * _skill():
		set_axis(Vector2(toward, 0))
		tap(&"heavy")
		return
	if dy < -40.0:
		set_axis(Vector2(0, -1))
		tap(&"light")  # up tilt / up air
	elif roll < 0.5:
		set_axis(Vector2(toward, 0))
		tap(&"light")
	elif roll < 0.75:
		set_axis(Vector2(toward, 0))
		tap(&"heavy")
	elif roll < 0.88:
		set_axis(Vector2(toward, 0))
		tap(&"special")  # side special
	else:
		set_axis(Vector2(0, 1))
		tap(&"special")  # down special


func _hold_walk(me: Fighter, stage: Rect2) -> void:
	var dir := _walk_dir
	# Never walk off the main stage on purpose.
	if me.grounded and dir != 0.0:
		var ahead := me.position.x + dir * 40.0
		if ahead < stage.position.x + 10.0 or ahead > stage.end.x - 10.0:
			dir = 0.0
	if dir != 0.0:
		set_axis(Vector2(dir, 0))


func _on_ledge(me: Fighter) -> void:
	if me.ledge_ticks <= 1:
		_ledge_wait = _rng.randi_range(Fighter.LEDGE_ACTION_DELAY + 2, Fighter.LEDGE_ACTION_DELAY + 30 - level * 2)
	if me.ledge_ticks < _ledge_wait:
		return
	var toward := float(me.facing)
	match _rng.randi_range(0, 3):
		0:
			tap(&"jump")
		1:
			tap(&"shield")
		_:
			set_axis(Vector2(toward, 0))
			tap(&"right" if toward > 0.0 else &"left")


func _off_stage(me: Fighter, stage: Rect2) -> bool:
	if me.grounded:
		return false
	return me.position.x < stage.position.x - 4.0 or me.position.x > stage.end.x + 4.0 \
		or me.position.y > stage.position.y + 8.0


func _recover(me: Fighter, stage: Rect2) -> void:
	var home := signf(stage.get_center().x - me.position.x)
	set_axis(Vector2(home, 0))
	if me.helpless or me.state == Fighter.State.ATTACK:
		return
	var below := me.position.y - stage.position.y
	if me.velocity.y < 0.0 and below < 0.0:
		return  # still rising above the stage: just drift
	if me.air_jumps_left > 0 and _jump_lock == 0:
		tap(&"jump")
		_jump_lock = 20
		return
	if me.velocity.y > 0.0 and below > -40.0 and _jump_lock == 0:
		set_axis(Vector2(home * 0.3, -1.0))
		tap(&"special")  # up special
		_jump_lock = 20


func _nearest_opponent(me: Fighter) -> Fighter:
	var best: Fighter = null
	var best_d := INF
	for other: Fighter in match_controller.fighters:
		if other == me or not other.is_in_play() or other.state == Fighter.State.RESPAWN:
			continue
		var d := me.position.distance_squared_to(other.position)
		if d < best_d:
			best_d = d
			best = other
	return best


## Top surface of the main (solid) platform.
static func _stage_rect() -> Rect2:
	for def: Dictionary in Stage.PLATFORMS:
		if not def.one_way:
			return Rect2(def.center - def.size / 2.0, def.size)
	return Rect2(340, 546, 600, 38)
