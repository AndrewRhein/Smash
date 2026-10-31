class_name OffscreenIndicators
extends Node2D
## TEMPORARY PLACEHOLDER: when a fighter is in play but outside the visible
## screen (there is no camera), draw a bubble at the nearest screen edge with
## an arrow toward them, their player number and distance to the blast line.

const MARGIN := 34.0
const RADIUS := 26.0

var match_controller: MatchController


func _ready() -> void:
	z_index = 150


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if match_controller == null or match_controller.stage == null:
		return
	var view := match_controller.stage.visible_rect
	var inner := view.grow(-MARGIN)
	for fighter in match_controller.fighters:
		if not is_instance_valid(fighter) or not fighter.is_in_play():
			continue
		var p := fighter.global_position + Vector2(0, -40)
		if view.has_point(p):
			continue
		var at := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
		var dir := (p - at).normalized()
		var col: Color = fighter.character.hud_color
		draw_circle(at, RADIUS, Color(0.03, 0.04, 0.08, 0.85))
		draw_arc(at, RADIUS, 0, TAU, 32, col, 3.0)
		var tip := at + dir * (RADIUS + 12.0)
		var side := dir.orthogonal() * 8.0
		draw_colored_polygon(PackedVector2Array([tip, at + dir * RADIUS + side, at + dir * RADIUS - side]), col)
		var font := ThemeDB.fallback_font
		draw_string(font, at + Vector2(-14, 7), "P%d" % fighter.player_id, HORIZONTAL_ALIGNMENT_CENTER, 28, 18, col)
