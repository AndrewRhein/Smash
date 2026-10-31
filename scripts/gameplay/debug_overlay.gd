class_name DebugOverlay
extends Node2D
## Toggleable (F1) gameplay debug drawing: hurtboxes (green), strike hitboxes
## (red), grab hitboxes (yellow), projectiles (orange), active guards (blue),
## invulnerable fighters (white hurtbox) and blast bounds. Reads gameplay state
## only; draws nothing when hidden.

var match_controller: MatchController


func _ready() -> void:
	visible = false


func toggle() -> void:
	visible = not visible


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if match_controller == null:
		return
	if match_controller.stage != null:
		draw_rect(match_controller.stage.blast_bounds, Color(1, 0.2, 0.8, 0.8), false, 3)
	for fighter in match_controller.fighters:
		if not fighter.is_in_play():
			continue
		var hurt_col := Color(1, 1, 1, 0.7) if fighter.invulnerable_remaining > 0 else Color(0.2, 1, 0.3, 0.8)
		draw_rect(fighter.get_hurtbox_world(), hurt_col, false, 2)
		draw_circle(fighter.global_position, 3, Color.WHITE)
		for hb: Dictionary in fighter.get_active_hitboxes():
			var col := Color(1, 0.9, 0.1, 0.45) if hb.data.kind == HitboxData.Kind.GRAB else Color(1, 0.1, 0.1, 0.45)
			if hb.shape == HitboxData.Shape.CIRCLE:
				draw_circle(hb.center, hb.radius, col)
			else:
				draw_rect(Rect2(hb.center - hb.size * 0.5, hb.size), col)
		if fighter.move != null and fighter.move.special_behaviour == GameIds.SPECIAL_GUARD \
				and fighter.move.is_active_tick(fighter.move_tick):
			var c := fighter.global_position + Vector2(0, -48)
			var a := 0.0 if fighter.facing > 0 else PI
			draw_arc(c, 56, a - PI * 0.5, a + PI * 0.5, 16, Color(0.3, 0.6, 1, 0.9), 3)
		if fighter.held_target != null:
			draw_line(fighter.global_position + Vector2(0, -50), fighter.held_target.global_position + Vector2(0, -50), Color(1, 0.9, 0.1), 2)
	for projectile in match_controller.projectiles:
		draw_circle(projectile.global_position, projectile.data.radius, Color(1, 0.55, 0.1, 0.5))
