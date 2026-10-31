extends Node2D
## Presentation-only adapter for CLAUDE_HANDOFF contract version 1.
## Attach under VisualRoot; gameplay remains authoritative.
@export var frames: SpriteFrames
@export var pivot := Vector2(128, 208)
@export var physics_hz := 60.0
var sprite: AnimatedSprite2D
var fighter: Node
var warned: Dictionary = {}
var elapsed := 0.0
var requested_ticks := 0
var requested_loop := true
var active_id: StringName = &"idle"
var playback_speed := 1.0
var playback_paused := false
const PHASE_FRAMES := {
    &"staff_strike": [[0, 1, 2], [3], [4, 5]],
    &"heavy_staff": [[0, 1], [2, 3], [4, 5]],
    &"lightning": [[0, 1, 2], [3, 4], [5]],
    &"fireball": [[0, 1, 2], [3, 4], [5]],
    &"magic_push": [[0, 1, 2], [3, 4], [5]],
}

func _ready() -> void:
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite = AnimatedSprite2D.new()
    sprite.centered = false
    sprite.position = -pivot
    sprite.sprite_frames = frames
    add_child(sprite)
    animation_requested(&"idle", 0, true)
    if get_parent().has_method("get_presentation_snapshot"):
        bind_fighter(get_parent())

func bind_fighter(value: Node) -> void:
    if is_instance_valid(fighter):
        for pair in [[&"animation_requested", animation_requested], [&"facing_changed", facing_changed]]:
            if fighter.has_signal(pair[0]) and fighter.is_connected(pair[0], pair[1]):
                fighter.disconnect(pair[0], pair[1])
    fighter = value
    if not is_instance_valid(fighter):
        return
    if fighter.has_signal(&"animation_requested"):
        fighter.connect(&"animation_requested", animation_requested)
    if fighter.has_signal(&"facing_changed"):
        fighter.connect(&"facing_changed", facing_changed)
    if fighter.has_method("get_presentation_snapshot"):
        var snap: Dictionary = fighter.call("get_presentation_snapshot")
        var id: StringName = snap.get("animation_id", &"idle")
        var loop: bool = id in [&"idle", &"walk", &"run", &"fall"] or snap.get("state") == &"held"
        animation_requested(id, int(snap.get("animation_duration_ticks", 0)), loop)
        facing_changed(int(snap.get("facing", 1)))
        _process(0.0)

func facing_changed(direction: int) -> void:
    # Mirror the visual pivot, never the physics body.
    scale.x = absf(scale.x) * (1.0 if direction >= 0 else -1.0)

func animation_requested(animation_id: StringName, duration_ticks: int, loop: bool) -> void:
    requested_ticks = maxi(0, duration_ticks)
    requested_loop = loop
    elapsed = 0.0
    active_id = animation_id
    if frames == null or sprite == null:
        return
    if not frames.has_animation(active_id):
        if not warned.has(active_id):
            push_warning("Missing visual animation: %s; displaying idle candidate" % active_id)
            warned[active_id] = true
        active_id = &"idle"
    if frames.has_animation(active_id):
        sprite.animation = active_id
        sprite.frame = 0

func _process(delta: float) -> void:
    if playback_paused or frames == null or sprite == null or not frames.has_animation(active_id):
        return
    if is_instance_valid(fighter) and fighter.has_method("get_presentation_snapshot"):
        var snapshot: Dictionary = fighter.call("get_presentation_snapshot")
        facing_changed(int(snapshot.get("facing", 1)))
        var flashing: bool = bool(snapshot.get("invulnerable", false)) and int(snapshot.get("invulnerable_remaining_ticks", 0)) / 5 % 2 == 0
        modulate.a = 0.45 if flashing else 1.0
        # Gameplay freezes its animation_tick during hitstop. Terminal victory
        # needs a local clock because MatchController stops stepping at RESULT.
        if snapshot.get("state") == &"victory":
            if int(snapshot.get("hitstop_remaining_ticks", 0)) == 0:
                elapsed += delta * playback_speed
        else:
            elapsed = float(snapshot.get("animation_tick", 0)) / physics_hz
        if int(snapshot.get("move_tick", -1)) >= 0 and PHASE_FRAMES.has(active_id):
            var move: Resource = fighter.get("move")
            if move != null:
                sprite.frame = frame_for_move(int(snapshot.move_tick), int(move.get("startup_ticks")), int(move.get("active_ticks")), int(move.get("recovery_ticks")))
                return
    else:
        elapsed += delta * playback_speed
    var count := frames.get_frame_count(active_id)
    if count == 0:
        return
    var rate := frames.get_animation_speed(active_id)
    var index: int
    if requested_ticks > 0:
        index = mini(count - 1, int(elapsed * physics_hz / requested_ticks * count))
    else:
        index = int(elapsed * rate)
        index = index % count if requested_loop else mini(index, count - 1)
    sprite.frame = maxi(0, index)

func frame_for_move(tick: int, startup: int, active: int, recovery: int) -> int:
    var phase := 0
    var local_tick := tick
    var length := startup
    if tick >= startup + active:
        phase = 2
        local_tick = tick - startup - active
        length = recovery
    elif tick >= startup:
        phase = 1
        local_tick = tick - startup
        length = active
    var sequence: Array = PHASE_FRAMES[active_id][phase]
    var slot := clampi(int(float(local_tick) / maxi(1, length) * sequence.size()), 0, sequence.size() - 1)
    return int(sequence[slot])
