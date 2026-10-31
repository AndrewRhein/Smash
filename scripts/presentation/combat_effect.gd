extends Node2D
## Local, deterministic visual effects. No damage, movement or hitbox authority.
const IDS: Array[StringName] = [
    &"staff_strike", &"heavy_staff", &"lightning", &"fireball", &"magic_push",
    &"saber_slash", &"heavy_saber", &"force_push", &"force_choke", &"force_guard",
    &"hit", &"respawn", &"charge", &"burst", &"jump_ring", &"fizzle"
]
var effect_id: StringName = &"hit"
var age := 0.0
var duration := 0.35
var length := 120.0
var frozen := false
var elapsed_frame := -1
var local_points := PackedVector2Array()

func setup(id: StringName, at: Vector2, direction: Vector2, payload: Dictionary = {}) -> void:
    effect_id = id
    global_position = at
    rotation = direction.angle() if direction.length_squared() > 0.0 else 0.0
    duration = maxf(0.05, float(payload.get("duration", 0.35)))
    length = clampf(float(payload.get("length", 120.0)), 8.0, 600.0)
    z_index = 20
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    if not IDS.has(id):
        push_warning("Unknown effect ID: %s" % id)
        effect_id = &"hit"
    queue_redraw()

func set_frozen(value: bool) -> void:
    frozen = value

func _process(delta: float) -> void:
    if frozen:
        return
    age += delta
    if age >= duration:
        queue_free()
        return
    var tick := int(age * 24.0)
    if tick != elapsed_frame:
        elapsed_frame = tick
        var rng := RandomNumberGenerator.new()
        rng.seed = 1234 + tick
        local_points.clear()
        for i in range(9):
            local_points.append(Vector2(length * i / 8.0, 0.0 if i == 0 or i == 8 else rng.randf_range(-12.0, 12.0)))
    queue_redraw()

func _draw() -> void:
    var t := clampf(age / duration, 0.0, 1.0)
    var fade := 1.0 - t
    var blue := Color(0.35, 0.78, 1.0, fade)
    var white := Color(0.92, 0.98, 1.0, fade)
    var red := Color(1.0, 0.16, 0.25, fade)
    match effect_id:
        &"charge":
            draw_circle(Vector2.ZERO, 5 + t * 7, Color(0.3, 0.65, 1.0, 0.2 + t * 0.3))
            draw_circle(Vector2.ZERO, 2 + t * 3, Color(0.8, 0.95, 1.0, 0.6 + t * 0.4))
        &"burst":
            draw_arc(Vector2.ZERO, 16 + t * 150, 0, TAU, 32, blue, 5.0 * fade + 1)
        &"jump_ring":
            draw_arc(Vector2.ZERO, 8 + t * 28, 0, PI, 16, white, 2.0)
        &"fizzle":
            draw_circle(Vector2.ZERO, 10 * fade, Color(1.0, 0.55, 0.12, fade))
        &"lightning":
            if local_points.size() >= 2:
                draw_polyline(local_points, Color(0.12, 0.42, 1.0, fade * 0.35), 12.0)
                draw_polyline(local_points, blue, 5.0)
                draw_polyline(local_points, white, 2.0)
        &"fireball":
            # Attach this effect to a gameplay projectile for authoritative travel.
            for i in range(5):
                var radius := float(14 - i * 2) * (0.8 + sin(t * PI) * 0.2)
                draw_circle(Vector2(-i * 8, 0), radius, Color(1.0, 0.16 + i * 0.09, 0.04, fade * (1.0 - i * 0.15)))
            draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.88, 0.45, fade))
            draw_circle(Vector2(2, -2), 4.0, white)
        &"magic_push", &"force_push":
            var col := blue if effect_id == &"magic_push" else Color(0.7, 0.55, 0.95, fade)
            var center := Vector2(length * t * 0.65, 0)
            for i in range(3):
                draw_arc(center + Vector2(-i * 10, 0), 18.0 + t * 32.0, -1.1, 1.1, 12, col, float(3 - i))
        &"saber_slash", &"heavy_saber", &"staff_strike", &"heavy_staff":
            var saber := effect_id == &"saber_slash" or effect_id == &"heavy_saber"
            var heavy := effect_id == &"heavy_saber" or effect_id == &"heavy_staff"
            var col := red if saber else Color(0.82, 0.87, 0.92, fade * 0.7)
            var angle := -1.2 + t * 2.2
            var radius := 54.0 if heavy else 38.0
            draw_arc(Vector2.ZERO, radius, angle - 0.8, angle + 0.35, 14, col, 7.0 if heavy else 4.0)
            if saber:
                draw_arc(Vector2.ZERO, radius, angle - 0.55, angle + 0.3, 12, white, 2.0)
        &"force_choke":
            # Target-local visual only; gameplay controls hold duration and release.
            for i in range(3):
                var radius := 18.0 + i * 5.0 - sin(t * PI) * 5.0
                draw_arc(Vector2(0, (i - 1) * 7), radius, t * TAU, t * TAU + PI * 1.6, 18, Color(0.65, 0.46, 0.85, fade), 2.0)
        &"force_guard", &"respawn":
            var col := blue if effect_id == &"respawn" else Color(0.72, 0.6, 1.0, fade)
            draw_circle(Vector2.ZERO, 42, Color(col.r, col.g, col.b, fade * 0.08))
            draw_arc(Vector2.ZERO, 42, 0, TAU, 40, col, 2.0)
            draw_arc(Vector2.ZERO, 36, -1.3, 0.9, 18, white, 1.0)
        _:
            for i in range(8):
                var direction := Vector2.from_angle(i * TAU / 8.0)
                draw_line(direction * (3 + t * 15), direction * (12 + t * 25), white, 2.0)
