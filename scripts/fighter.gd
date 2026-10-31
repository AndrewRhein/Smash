extends CharacterBody2D
class_name Fighter
signal knocked_out(fighter: Fighter)
var player_id := 1
var fighter_name := "Fighter"
var damage := 0.0
var stocks := 3
var facing := 1
var invulnerability := 0.0
var attack_cd := 0.0
var special_cd := 0.0
var spawn_point := Vector2.ZERO
var jump_was_down := false
const GRAVITY := 1700.0
func setup(id: int, label: String, spawn: Vector2) -> void:
    player_id = id
    fighter_name = label
    spawn_point = spawn
    position = spawn
    collision_layer = 2
    collision_mask = 1
    var cs := CollisionShape2D.new()
    var cap := CapsuleShape2D.new()
    cap.radius = 17.0
    cap.height = 76.0
    cs.shape = cap
    cs.position.y = -38.0
    add_child(cs)
func _physics_process(delta: float) -> void:
    attack_cd = maxf(0.0, attack_cd-delta)
    special_cd = maxf(0.0, special_cd-delta)
    invulnerability = maxf(0.0, invulnerability-delta)
    var left := KEY_A if player_id == 1 else KEY_LEFT
    var right := KEY_D if player_id == 1 else KEY_RIGHT
    var jump := KEY_W if player_id == 1 else KEY_UP
    var attack := KEY_F if player_id == 1 else KEY_K
    var special := KEY_G if player_id == 1 else KEY_L
    var axis := float(Input.is_key_pressed(right))-float(Input.is_key_pressed(left))
    if axis != 0: facing = int(sign(axis))
    velocity.x = move_toward(velocity.x, axis*360.0, 2200.0*delta)
    if not is_on_floor(): velocity.y += GRAVITY*delta
    elif velocity.y > 0: velocity.y = 0
    if Input.is_key_pressed(jump) and not jump_was_down and is_on_floor(): velocity.y = -700.0
    jump_was_down = Input.is_key_pressed(jump)
    if Input.is_key_pressed(attack) and attack_cd <= 0:
        attack_cd = 0.4
        _attack(false)
    if Input.is_key_pressed(special) and special_cd <= 0:
        special_cd = 1.7
        _attack(true)
    move_and_slide()
    if global_position.y > 950 or absf(global_position.x) > 1850: lose_stock()
    queue_redraw()
func _attack(is_special: bool) -> void:
    var foe: Fighter = get_parent().get_opponent(self)
    if foe == null or foe.invulnerability > 0: return
    var d := foe.global_position-global_position
    var reach := 175.0 if is_special else 105.0
    if absf(d.x) <= reach and absf(d.y) <= 115.0 and d.x*facing > -25.0:
        foe.take_hit(13.0 if is_special else 7.0, Vector2(facing*(650.0 if is_special else 420.0), -430.0))
    get_parent().spawn_attack_effect(global_position+Vector2(facing*(72 if is_special else 48),-42),player_id,is_special)
func take_hit(amount: float, impulse: Vector2) -> void:
    if invulnerability > 0: return
    damage += amount
    velocity = impulse*(1.0+damage/95.0)
    invulnerability = 0.38
func lose_stock() -> void:
    stocks -= 1
    if stocks <= 0:
        knocked_out.emit(self)
        return
    damage = 0
    position = spawn_point
    velocity = Vector2.ZERO
    invulnerability = 1.4
func _draw() -> void:
    var flash := invulnerability > 0 and int(Time.get_ticks_msec()/90)%2 == 0
    var robe := Color.WHITE if flash else (Color(0.46,0.58,0.72) if player_id == 1 else Color(0.12,0.13,0.17))
    if player_id == 1:
        draw_colored_polygon(PackedVector2Array([Vector2(-16,-8),Vector2(16,-8),Vector2(25,0),Vector2(-25,0)]),Color(0.25,0.29,0.37))
        draw_rect(Rect2(-15,-61,30,55),robe)
        draw_circle(Vector2(0,-68),13,Color(0.82,0.72,0.60))
        draw_colored_polygon(PackedVector2Array([Vector2(-17,-76),Vector2(0,-110),Vector2(18,-76)]),Color(0.47,0.52,0.61))
        draw_colored_polygon(PackedVector2Array([Vector2(-9,-58),Vector2(0,-39),Vector2(9,-58),Vector2(5,-28),Vector2(-5,-28)]),Color(0.9,0.88,0.8))
        draw_line(Vector2(-22,-10),Vector2(-25,-88),Color(0.55,0.36,0.18),5)
        draw_circle(Vector2(-25,-91),5,Color(0.45,0.85,1))
    else:
        draw_rect(Rect2(-16,-61,32,56),robe)
        draw_circle(Vector2(0,-70),16,Color(0.04,0.045,0.06))
        draw_colored_polygon(PackedVector2Array([Vector2(-17,-72),Vector2(-13,-88),Vector2(0,-97),Vector2(13,-88),Vector2(17,-72),Vector2(9,-58),Vector2(-9,-58)]),Color(0.025,0.03,0.04))
        draw_rect(Rect2(-8,-77,16,8),Color(0.18,0.2,0.23))
        draw_circle(Vector2(-5,-73),2,Color(1,0.08,0.08)); draw_circle(Vector2(5,-73),2,Color(1,0.08,0.08))
        draw_line(Vector2(14,-20),Vector2(42*facing,-105),Color(1,0.12,0.12),8)
        draw_line(Vector2(14,-20),Vector2(42*facing,-105),Color(1,0.75,0.75),2)
    draw_line(Vector2(-10,-5),Vector2(-15,0),Color(0.07,0.07,0.09),7)
    draw_line(Vector2(10,-5),Vector2(15,0),Color(0.07,0.07,0.09),7)
