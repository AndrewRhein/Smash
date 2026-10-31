class_name PlaceholderStatusVisual
extends Node2D
## TEMPORARY PLACEHOLDER overlay for gameplay states every character shares:
## shield bubble (size/colour from shield health), respawn platform, dizzy
## stars after a shield break, and a shimmer while intangible (dodging).
## Reads only Fighter.get_presentation_snapshot(); final art may replace it.
## Lives as the Fighter's "StatusVisual" child, beside VisualRoot (not flipped).

const MIN_RADIUS := 20.0
const MAX_RADIUS := 60.0

var fighter: Fighter
var _t: float = 0.0


func _ready() -> void:
	fighter = get_parent() as Fighter
	z_index = 5


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if fighter == null or fighter.character == null:
		return
	var snap := fighter.get_presentation_snapshot()
	var center := Vector2(0, fighter.character.hurtbox.get_center().y)
	var tint: Color = fighter.character.hud_color
	if snap.shielding:
		var ratio := clampf(float(snap.shield_health) / float(snap.shield_max), 0.0, 1.0)
		var radius := lerpf(MIN_RADIUS, MAX_RADIUS, ratio)
		var col := tint.lerp(Color(1, 0.25, 0.2), 1.0 - ratio)
		draw_circle(center, radius, Color(col.r, col.g, col.b, 0.28))
		draw_arc(center, radius, 0, TAU, 40, Color(col.r, col.g, col.b, 0.85), 3.0)
		draw_arc(center + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.35, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.5), 2.0)
	if snap.on_respawn_platform:
		draw_rect(Rect2(-36, 0, 72, 6), Color(tint.r, tint.g, tint.b, 0.9))
		draw_rect(Rect2(-36, 0, 72, 6), Color(1, 1, 1, 0.8), false, 1.0)
		for i in 3:
			var y := 8.0 + i * 6.0 + fmod(_t * 20.0, 6.0)
			draw_line(Vector2(-24 + i * 6, y), Vector2(24 - i * 6, y), Color(tint.r, tint.g, tint.b, 0.35 - i * 0.1), 2.0)
	if snap.state == &"shield_break":
		var head := Vector2(0, fighter.character.hurtbox.position.y - 10)
		for i in 3:
			var a := _t * 5.0 + i * TAU / 3.0
			var p := head + Vector2(cos(a) * 22.0, sin(a) * 7.0)
			_star(p, 6.0, Color(1, 0.9, 0.3))
	if snap.get("held_visual", &"") == &"frozen":
		# Encased in ice, shivering.
		var r := fighter.character.hurtbox
		var shake := sin(_t * 60.0) * 1.5
		var ice := Rect2(Vector2(r.position.x - 8 + shake, r.position.y - 6), r.size + Vector2(16, 6))
		draw_rect(ice, Color(0.6, 0.85, 1.0, 0.45))
		draw_rect(ice, Color(0.85, 0.95, 1.0, 0.9), false, 2.0)
		for i in 4:
			var x := ice.position.x + 6 + i * (ice.size.x - 12) / 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, ice.position.y), Vector2(x + 3, ice.position.y), Vector2(x, ice.position.y + 9)]), Color(0.9, 0.97, 1.0, 0.9))
		draw_line(ice.position + Vector2(5, 8), ice.position + Vector2(14, 30), Color(1, 1, 1, 0.7), 2.0)
	if snap.get("charging", false):
		# Charging a heavy: a pulsing ring of light that grows with the charge.
		var r := fighter.character.hurtbox
		var k: float = snap.get("charge_ratio", 0.0)
		var glow_at := Vector2(0, r.get_center().y)
		var blink := 0.5 + 0.5 * sin(_t * (18.0 + 30.0 * k))
		draw_arc(glow_at, 34.0 + 10.0 * k, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 0.35 + 0.5 * blink), 2.0 + 3.0 * k)
		for i in 6:
			var ang := _t * 6.0 + i * TAU / 6.0
			var spark := glow_at + Vector2(cos(ang), sin(ang)) * (46.0 - 18.0 * fmod(_t * 3.0 + i * 0.3, 1.0))
			_star(spark, 3.0 + 3.0 * k, Color(1.0, 0.95, 0.6, 0.8))
	if snap.get("healing", false):
		# Rising green pluses and a soft glow.
		var r := fighter.character.hurtbox
		draw_rect(Rect2(r.position - Vector2(4, 4), r.size + Vector2(8, 8)), Color(0.4, 1.0, 0.5, 0.07))
		for i in 5:
			var k := fmod(_t * 0.9 + i * 0.2, 1.0)
			var p := Vector2(r.position.x + r.size.x * (0.1 + 0.2 * i), r.end.y - k * (r.size.y + 30))
			var c := Color(0.45, 1.0, 0.55, 1.0 - k)
			draw_rect(Rect2(p - Vector2(5, 1.5), Vector2(10, 3)), c)
			draw_rect(Rect2(p - Vector2(1.5, 5), Vector2(3, 10)), c)
	if snap.intangible:
		var r := fighter.character.hurtbox
		var rect := Rect2(Vector2(r.position.x - 4, r.position.y - 4), r.size + Vector2(8, 8))
		draw_rect(rect, Color(1, 1, 1, 0.18 + 0.12 * sin(_t * 40.0)))


func _star(p: Vector2, size: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var radius := size if k % 2 == 0 else size * 0.45
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(p + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, col)
