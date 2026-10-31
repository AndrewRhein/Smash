extends Node2D
## Elon's fictional gadgets. Visuals only; gameplay owns every hit and hold.
var effect_id: StringName
var age := 0.0
var duration := 0.2
var length := 152.0
var frozen := false

func setup(id: StringName, at: Vector2, direction: Vector2, payload: Dictionary = {}) -> void:
    effect_id = id
    global_position = at
    rotation = direction.angle() if direction.length_squared() > 0 else 0.0
    duration = maxf(0.05, float(payload.get("duration", 0.2)))
    length = float(payload.get("length", 152.0))
    z_index = 20
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
    queue_redraw()

func _draw() -> void:
    var t := clampf(age / duration, 0, 1)
    var fade := 1.0 - t
    var cyan := Color(0.25, 0.88, 1.0, fade)
    var white := Color(0.85, 0.98, 1.0, fade)
    match effect_id:
        &"ion_jab":
            # Hand x+30 to the jab's x+88 outer reach.
            draw_line(Vector2.ZERO, Vector2(58, 0), Color(0.2, 0.8, 1, fade * 0.18), 18)
            draw_line(Vector2(8, 0), Vector2(58, 0), white, 3)
            draw_arc(Vector2(48, 0), 10, -1.1, 1.1, 10, cyan, 2)
        &"rocket_hammer":
            draw_arc(Vector2(8, -8), 54, -1.7 + t, 0.6 + t, 18, Color(0.3, 0.8, 1, fade * 0.45), 6)
            for i in range(6):
                var p := Vector2(48, 0) + Vector2.from_angle(i * TAU / 6) * (8 + t * 20)
                draw_line(p, p + Vector2(5, 3), white, 2)
        &"thruster_burst":
            # Short forward pressure pulse, not a traveling projectile.
            var tip := Vector2(length * (0.25 + 0.75 * t), 0)
            draw_colored_polygon(PackedVector2Array([Vector2.ZERO, tip + Vector2(-18, -24 * fade), tip, tip + Vector2(-18, 24 * fade)]), Color(0.2, 0.75, 1, fade * 0.16))
            for i in range(3):
                var x := length * (0.3 + i * 0.3)
                draw_arc(Vector2(x, 0), 14 + i * 7, -1.0, 1.0, 12, cyan, 3 - i * 0.7)
            draw_line(Vector2.ZERO, Vector2(length, 0), Color(0.9, 0.97, 1, fade * 0.45), 2)
        &"orbital_tractor":
            # Rotation supplied by gameplay can point up: rings remain symmetric.
            for i in range(3):
                var radius := 19.0 + i * 6
                draw_arc(Vector2.ZERO, radius, age * 3 + i, age * 3 + i + TAU * 0.75, 24, cyan, 1.5)
            for i in range(4):
                var p := Vector2.from_angle(i * PI / 2 + age * 2) * 32
                draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), white, false, 1)
            draw_line(Vector2(-9, 0), Vector2(9, 0), Color(0.3, 0.9, 1, fade * 0.4), 1)
        &"energy_shield", &"shield_block":
            var ring := PackedVector2Array()
            for i in range(6):
                ring.append(Vector2.from_angle(i * TAU / 6) * 42)
            draw_colored_polygon(ring, Color(0.15, 0.65, 1, fade * 0.09))
            ring.append(ring[0])
            draw_polyline(ring, cyan, 3 if effect_id == &"shield_block" else 2)
            for i in range(6):
                var edge := Vector2.from_angle(i * TAU / 6) * 42
                draw_circle(edge, 2.5, white)
            draw_arc(Vector2.ZERO, 35, -1.1, 1.1, 18, white, 1)
