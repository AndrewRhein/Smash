extends Node2D
const Effect = preload("res://scripts/presentation/combat_effect.gd")

func effect_requested(effect_id: StringName, world_position: Vector2, direction: Vector2, payload: Dictionary = {}) -> Node2D:
    var effect := Effect.new()
    add_child(effect)
    effect.setup(effect_id, world_position, direction, payload)
    return effect

func clear_effects() -> void:
    for effect in get_children():
        effect.queue_free()

func set_frozen(value: bool) -> void:
    for effect in get_children():
        effect.set_frozen(value)
