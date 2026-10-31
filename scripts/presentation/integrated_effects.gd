extends "res://scripts/presentation/placeholder_effects.gd"
## Retains main.gd's PlaceholderEffects-compatible binding interface.
const Effect = preload("res://scripts/presentation/combat_effect.gd")
const MAP := {
    &"hit_spark": &"hit", &"guard_block": &"force_guard", &"blast_ko": &"burst",
    &"respawn": &"respawn", &"double_jump": &"jump_ring", &"projectile_fizzle": &"fizzle",
    &"choke_release": &"hit", &"staff_swing": &"staff_strike", &"heavy_staff_swing": &"heavy_staff",
    &"lightning_telegraph": &"charge", &"lightning_bolt": &"lightning", &"fireball_cast": &"cast_flash",
    &"magic_push": &"magic_push", &"saber_swing": &"saber_slash", &"heavy_saber_swing": &"heavy_saber",
    &"force_push": &"force_push", &"force_choke": &"force_choke", &"force_guard": &"force_guard",
}
var _match: MatchController
var _active_visuals: Array[Dictionary] = []

func bind(controller: MatchController) -> void:
    _match = controller
    super.bind(controller)

func _on_fighter_spawned(fighter: Fighter) -> void:
    # New actor instances begin a new match, including zero-countdown rematches.
    # Stock respawns reuse the existing fighter and do not emit this signal.
    if fighter.player_id == 1:
        _clear_visuals()
    super._on_fighter_spawned(fighter)

func _on_match_state_changed(state: MatchController.MatchState) -> void:
    if state == MatchController.MatchState.COUNTDOWN:
        _clear_visuals()

func _clear_visuals() -> void:
    for entry in _active_visuals:
        if is_instance_valid(entry.node):
            entry.node.queue_free()
    _active_visuals.clear()

func _on_effect_requested(id: StringName, at: Vector2, direction: Vector2, payload: Dictionary) -> void:
    if not MAP.has(id):
        push_warning("Unmapped gameplay effect: %s" % id)
        return
    var settings := {"duration": 0.3, "length": 120.0}
    if payload.has("duration_ticks"):
        settings.duration = maxf(0.05, float(payload.duration_ticks) / 60.0)
    if id == &"lightning_bolt":
        # The effect starts at hand x+30; the hitbox ends at x+227.
        settings.length = 197.0
        settings.duration = 8.0 / 60.0
    elif id == &"fireball_cast":
        settings.duration = 5.0 / 60.0
    elif id == &"blast_ko":
        settings.duration = 0.7
    var owner_id := int(payload.get("player_id", 1))
    var owner: Fighter = _match.get_fighter(owner_id)
    if id == &"force_guard" and is_instance_valid(owner) and owner.move != null:
        settings.duration = float(owner.move.startup_ticks + owner.move.active_ticks) / 60.0
    var effect := Effect.new()
    add_child(effect)
    effect.setup(MAP[id], at, direction, settings)
    _active_visuals.append({"node": effect, "kind": id, "owner_id": owner_id,
        "victim_id": int(payload.get("victim_id", 0)), "move_id": str(payload.get("move_id", "")),
        "offset": at - owner.global_position if is_instance_valid(owner) else Vector2.ZERO})

func _process(_delta: float) -> void:
    if not is_instance_valid(_match):
        return
    for i in range(_active_visuals.size() - 1, -1, -1):
        var entry: Dictionary = _active_visuals[i]
        var effect = entry.node
        if not is_instance_valid(effect):
            _active_visuals.remove_at(i)
            continue
        var owner: Fighter = _match.get_fighter(int(entry.owner_id))
        var attached: bool = entry.kind in [&"force_choke", &"force_guard", &"lightning_telegraph"]
        if attached and (not is_instance_valid(owner) or owner.move == null):
            effect.queue_free()
            _active_visuals.remove_at(i)
            continue
        if attached and entry.move_id != "" and str(owner.move.id) != entry.move_id:
            effect.queue_free()
            _active_visuals.remove_at(i)
            continue
        if entry.kind == &"force_choke" and int(entry.victim_id) > 0:
            var victim: Fighter = _match.get_fighter(int(entry.victim_id))
            if not is_instance_valid(victim) or victim.state != Fighter.State.HELD:
                effect.queue_free()
                _active_visuals.remove_at(i)
                continue
            effect.global_position = victim.global_position + Vector2(0, -60)
        elif attached and is_instance_valid(owner):
            effect.global_position = owner.global_position + entry.offset
        var can_freeze: bool = entry.kind not in [&"projectile_fizzle", &"blast_ko", &"respawn"]
        effect.set_frozen(can_freeze and is_instance_valid(owner) and owner.hitstop_remaining > 0 and _match.state == MatchController.MatchState.PLAYING)

func _draw() -> void:
    pass
