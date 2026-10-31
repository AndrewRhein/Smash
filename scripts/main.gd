extends Node2D
const FighterScript = preload("res://scripts/fighter.gd")
var gandalf: Fighter
var vader: Fighter
var left_hud: Label
var right_hud: Label
var title: Label
var effects: Array[Dictionary] = []
func _ready() -> void:
    _build_background()
    _platform(Vector2(640,565),Vector2(600,38),Color(0.34,0.37,0.43))
    _platform(Vector2(435,420),Vector2(180,20),Color(0.40,0.48,0.58))
    _platform(Vector2(845,420),Vector2(180,20),Color(0.48,0.32,0.34))
    _platform(Vector2(640,315),Vector2(150,18),Color(0.47,0.43,0.39))
    gandalf = FighterScript.new(); add_child(gandalf); gandalf.setup(1,"Gandalf",Vector2(440,380))
    vader = FighterScript.new(); add_child(vader); vader.setup(2,"Darth Vader",Vector2(840,380))
    gandalf.knocked_out.connect(_game_over.bind("DARTH VADER WINS"))
    vader.knocked_out.connect(_game_over.bind("GANDALF WINS"))
    _build_hud()
func _build_background() -> void:
    var bg := ColorRect.new(); bg.color=Color(0.035,0.055,0.11); bg.size=Vector2(1280,720); add_child(bg)
    var peaks := Polygon2D.new()
    peaks.polygon=PackedVector2Array([Vector2(0,470),Vector2(150,270),Vector2(270,440),Vector2(420,240),Vector2(580,450),Vector2(760,300),Vector2(900,445),Vector2(1080,220),Vector2(1280,460),Vector2(1280,720),Vector2(0,720)])
    peaks.color=Color(0.10,0.15,0.27); add_child(peaks)
    var moon := Polygon2D.new(); moon.polygon=PackedVector2Array([Vector2(1000,80),Vector2(1025,50),Vector2(1050,80),Vector2(1025,105)]); moon.color=Color(0.6,0.65,0.8); add_child(moon)
func _platform(pos: Vector2, size: Vector2, color: Color) -> void:
    var body := StaticBody2D.new(); body.position=pos; body.collision_layer=1; body.collision_mask=2
    var cs := CollisionShape2D.new(); var rect := RectangleShape2D.new(); rect.size=size; cs.shape=rect; body.add_child(cs)
    var art := Polygon2D.new(); art.polygon=PackedVector2Array([Vector2(-size.x/2,-size.y/2),Vector2(size.x/2,-size.y/2),Vector2(size.x/2,size.y/2),Vector2(-size.x/2,size.y/2)]); art.color=color; body.add_child(art)
    var edge := Line2D.new(); edge.points=PackedVector2Array([Vector2(-size.x/2,-size.y/2),Vector2(size.x/2,-size.y/2)]); edge.width=4; edge.default_color=Color(0.8,0.83,0.9); body.add_child(edge); add_child(body)
func _build_hud() -> void:
    left_hud=Label.new(); left_hud.position=Vector2(28,22); left_hud.add_theme_font_size_override("font_size",24); left_hud.add_theme_color_override("font_color",Color(0.55,0.8,1)); add_child(left_hud)
    right_hud=Label.new(); right_hud.position=Vector2(825,22); right_hud.add_theme_font_size_override("font_size",24); right_hud.add_theme_color_override("font_color",Color(1,0.48,0.43)); add_child(right_hud)
    title=Label.new(); title.position=Vector2(485,20); title.text="REALMS RUMBLE • FIRST DUEL"; title.add_theme_font_size_override("font_size",19); title.add_theme_color_override("font_color",Color(1,0.88,0.55)); add_child(title)
    var controls := Label.new(); controls.text="P1: A/D move  W jump  F staff  G lightning     |     P2: ←/→ move  ↑ jump  K saber  L Force"; controls.position=Vector2(175,680); controls.add_theme_font_size_override("font_size",15); controls.add_theme_color_override("font_color",Color(0.84,0.86,0.92)); add_child(controls)
func _process(delta: float) -> void:
    for i in range(effects.size()-1,-1,-1):
        effects[i].life-=delta
        if effects[i].life<=0: effects.remove_at(i)
    if is_instance_valid(gandalf) and is_instance_valid(vader):
        left_hud.text="GANDALF   %03d%%   STOCKS: %d" % [roundi(gandalf.damage),gandalf.stocks]
        right_hud.text="DARTH VADER   %03d%%   STOCKS: %d" % [roundi(vader.damage),vader.stocks]
    queue_redraw()
func get_opponent(f: Fighter) -> Fighter:
    return vader if f==gandalf else gandalf
func spawn_attack_effect(pos: Vector2, player: int, special: bool) -> void:
    var duration := 0.38 if special else 0.2
    effects.append({"pos":pos,"life":duration,"max":duration,"player":player,"special":special})
func _draw() -> void:
    for e in effects:
        var r: float=e.life/e.max
        var col := Color(0.3,0.75,1,r) if e.player==1 else Color(1,0.18,0.18,r)
        draw_arc(e.pos,(58.0 if e.special else 28.0)*(2.0-r),0,TAU,32,col,6 if e.special else 3,true)
func _game_over(_f: Fighter, message: String) -> void:
    title.text=message+"  •  RESTART THE GAME TO PLAY AGAIN"
