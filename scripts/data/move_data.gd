class_name MoveData
extends Resource
## One attack/special. All timings are integer physics ticks at 60 Hz.
##
## Timeline (move_tick counts from 0 on the tick the move starts):
##   [0, startup)                         startup  - no hitboxes
##   [startup, startup+active)            active   - hitboxes/projectiles may exist
##   [startup+active, total)              recovery - no hitboxes, no new attacks
## total = startup + active + recovery. The fighter returns to free movement on
## the tick move_tick reaches total.
##
## Knockback angle convention: degrees, 0 = straight forward (the attacker's
## facing), 90 = straight up, negative = downward. Direction in Godot space is
## Vector2(cos(a) * facing, -sin(a)). Knockback magnitude (px/s):
##   (knockback_base + knockback_growth * victim_damage_after_hit) / victim_weight

enum MovementPolicy {
	FREE,   ## Normal horizontal control (facing locked during the move).
	SLOWED, ## Control at a reduced target speed.
	ROOTED, ## No horizontal input; momentum decays with friction/air drag.
}

@export var id: StringName = &""
## Name shown in menus (and the default voice-line text). Empty = derived
## from animation_id.
@export var display_name: String = ""
@export var animation_id: StringName = &""
@export var startup_ticks: int = 5
@export var active_ticks: int = 3
@export var recovery_ticks: int = 10
## Percent added to the victim.
@export var damage: float = 5.0
@export var damage_type: StringName = &"melee"
@export var knockback_angle_deg: float = 35.0
@export var knockback_base: float = 250.0
@export var knockback_growth: float = 8.0
## Base hitstun; the fighter adds a knockback-scaled amount (see Fighter).
@export var hitstun_ticks: int = 10
## Ticks after the move STARTS before it can be started again. 0 = none.
@export var cooldown_ticks: int = 0
@export var movement_policy: MovementPolicy = MovementPolicy.FREE
## Move IDs this move may cancel into during its recovery phase.
@export var cancel_into: Array[StringName] = []
## If true, cancel_into only applies after this attack instance connected.
@export var cancel_requires_hit: bool = true
## Aimable moves read vertical input on their first tick and rotate their
## hitboxes about aim_pivot by +/- aim_angle_deg. Aimable hitboxes must be circles.
@export var aimable: bool = false
@export var aim_angle_deg: float = 0.0
@export var aim_pivot: Vector2 = Vector2.ZERO
@export var hitboxes: Array[HitboxData] = []
@export var projectiles: Array[ProjectileData] = []
## Effect requested on the first tick of the move (e.g. a telegraph).
@export var start_effect_id: StringName = &""
## Effect requested on the first active tick.
@export var active_effect_id: StringName = &""
## &"" (none), &"choke" or &"guard". See GameIds.SPECIAL_BEHAVIOURS.
@export var special_behaviour: StringName = &""

@export_group("Recovery")
## Velocity SET on the fighter on active tick `self_impulse_tick` (authored
## facing right, x mirrored by facing). Zero = none. Used by up specials.
@export var self_impulse: Vector2 = Vector2.ZERO
@export var self_impulse_tick: int = 0
## If the move ends airborne, the fighter is helpless (can only drift and fast
## fall) until it lands. Prevents infinite recovery.
@export var helpless_after: bool = false

@export_group("Choke")
## If the grab window ends without a grab, skip straight to recovery.
@export var whiff_to_recovery: bool = false
## Damage applied to a held target every hold_pulse_interval_ticks.
@export var hold_pulse_damage: float = 0.0
@export var hold_pulse_interval_ticks: int = 12
## Hold breaks if root-to-root distance exceeds this many pixels.
@export var hold_max_range: float = 240.0
## Ticks the released target cannot be grabbed again (prevents choke loops).
@export var grab_immunity_ticks: int = 90

@export_group("Guard")
## Damage types negated from the FRONT while the guard is active.
@export var guard_damage_types: Array[StringName] = []


func label() -> String:
	return display_name if display_name != "" else String(animation_id).replace("_", " ").capitalize()


func total_ticks() -> int:
	return startup_ticks + active_ticks + recovery_ticks


func is_active_tick(move_tick: int) -> bool:
	return move_tick >= startup_ticks and move_tick < startup_ticks + active_ticks


func is_recovery_tick(move_tick: int) -> bool:
	return move_tick >= startup_ticks + active_ticks


func validate(character_id: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	var ctx := "%s/%s" % [character_id, id]
	if id == &"":
		errors.append("%s: missing move id" % ctx)
	if animation_id == &"" or not GameIds.all_animation_ids().has(animation_id):
		errors.append("%s: unknown animation_id '%s'" % [ctx, animation_id])
	if startup_ticks < 1:
		errors.append("%s: startup_ticks must be >= 1" % ctx)
	if active_ticks < 1:
		errors.append("%s: active_ticks must be >= 1" % ctx)
	if recovery_ticks < 0:
		errors.append("%s: recovery_ticks must be >= 0" % ctx)
	if cooldown_ticks < 0:
		errors.append("%s: cooldown_ticks must be >= 0" % ctx)
	if hitstun_ticks < 0:
		errors.append("%s: hitstun_ticks must be >= 0" % ctx)
	if damage < 0.0 or knockback_base < 0.0 or knockback_growth < 0.0:
		errors.append("%s: damage and knockback must be >= 0" % ctx)
	if not GameIds.DAMAGE_TYPES.has(damage_type):
		errors.append("%s: unknown damage_type '%s'" % [ctx, damage_type])
	if not GameIds.SPECIAL_BEHAVIOURS.has(special_behaviour):
		errors.append("%s: unknown special_behaviour '%s'" % [ctx, special_behaviour])
	for effect_id: StringName in [start_effect_id, active_effect_id]:
		if effect_id != &"" and not GameIds.EFFECT_IDS.has(effect_id):
			errors.append("%s: unknown effect id '%s'" % [ctx, effect_id])
	for i in hitboxes.size():
		var hb := hitboxes[i]
		if hb == null:
			errors.append("%s: hitbox %d is null" % [ctx, i])
			continue
		errors.append_array(hb.validate(active_ticks, "%s hitbox %d" % [ctx, i]))
		if aimable and hb.shape != HitboxData.Shape.CIRCLE:
			errors.append("%s hitbox %d: aimable moves require circle hitboxes" % [ctx, i])
		if hb.kind == HitboxData.Kind.GRAB and special_behaviour != GameIds.SPECIAL_CHOKE:
			errors.append("%s hitbox %d: GRAB hitboxes require the choke behaviour" % [ctx, i])
	for i in projectiles.size():
		if projectiles[i] == null:
			errors.append("%s: projectile %d is null" % [ctx, i])
			continue
		errors.append_array(projectiles[i].validate(active_ticks, "%s projectile %d" % [ctx, i]))
	if special_behaviour != GameIds.SPECIAL_GUARD and hitboxes.is_empty() and projectiles.is_empty():
		errors.append("%s: move has no hitboxes or projectiles" % ctx)
	if self_impulse_tick < 0 or self_impulse_tick >= active_ticks:
		errors.append("%s: self_impulse_tick outside active window" % ctx)
	if special_behaviour == GameIds.SPECIAL_CHOKE:
		var has_grab := false
		for hb in hitboxes:
			if hb != null and hb.kind == HitboxData.Kind.GRAB:
				has_grab = true
		if not has_grab:
			errors.append("%s: choke requires a GRAB hitbox" % ctx)
		if hold_pulse_interval_ticks < 1 or hold_max_range <= 0.0 or grab_immunity_ticks < 0:
			errors.append("%s: invalid choke hold parameters" % ctx)
	if special_behaviour == GameIds.SPECIAL_GUARD:
		if guard_damage_types.is_empty():
			errors.append("%s: guard must list guard_damage_types" % ctx)
		for t in guard_damage_types:
			if not GameIds.DAMAGE_TYPES.has(t):
				errors.append("%s: unknown guard damage type '%s'" % [ctx, t])
		if cooldown_ticks <= 0:
			errors.append("%s: guard requires a cooldown" % ctx)
	return errors
