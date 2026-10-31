class_name PlaceholderFighterVisual
extends Node2D
## TEMPORARY PLACEHOLDER ART. Vector silhouettes from the starter prototype,
## driven only through the presentation contract (signals + snapshot), exactly
## like a final AnimatedSprite2D adapter would be. Replace by setting
## CharacterData.visual_scene; see docs/CODEX_INTEGRATION.md.
##
## Lives as the fighter's "VisualRoot" child. It flips itself (scale.x = facing);
## the CharacterBody2D is never flipped.

var fighter: Fighter
var _anim_id: StringName = &"idle"
var _anim_duration: int = 0
var _warned: Dictionary = {}


func _ready() -> void:
	fighter = get_parent() as Fighter
	if fighter == null:
		push_warning("PlaceholderFighterVisual must be a child of a Fighter.")
		return
	fighter.animation_requested.connect(_on_animation_requested)
	fighter.facing_changed.connect(_on_facing_changed)
	# Synchronise from the snapshot so attaching mid-state works.
	var snap := fighter.get_presentation_snapshot()
	_on_facing_changed(snap.facing)
	_anim_id = snap.animation_id
	_anim_duration = snap.animation_duration_ticks


func _on_animation_requested(animation_id: StringName, duration_ticks: int, _loop: bool) -> void:
	if not GameIds.is_animation_id(animation_id) and not _warned.has(animation_id):
		_warned[animation_id] = true
		push_warning("PlaceholderFighterVisual: no placeholder pose for animation '%s' (%s); using idle." % [
			animation_id, fighter.character.id])
	_anim_id = animation_id
	_anim_duration = duration_ticks


func _on_facing_changed(facing: int) -> void:
	scale.x = float(facing)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if fighter == null:
		return
	var snap := fighter.get_presentation_snapshot()
	var progress := 0.0
	if _anim_duration > 0:
		progress = clampf(float(snap.animation_tick) / float(_anim_duration), 0.0, 1.0)
	var flash: bool = snap.invulnerable and int(snap.invulnerable_remaining_ticks / 5) % 2 == 0
	var hurt := _anim_id == GameIds.ANIM_HURT or _anim_id == GameIds.ANIM_KNOCKBACK
	var tilt := 0.0
	if _anim_id == GameIds.ANIM_KNOCKBACK:
		tilt = -0.5
	elif _anim_id == GameIds.ANIM_DEFEAT:
		tilt = -1.4
	draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
	if fighter.character.id == GameIds.CHARACTER_GANDALF:
		_draw_gandalf(flash, hurt, progress)
	else:
		_draw_vader(flash, hurt, progress)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _anim_id == GameIds.ANIM_VICTORY:
		# Counter the VisualRoot flip so text never renders mirrored.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale.x, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(-30, -130), "WIN!", HORIZONTAL_ALIGNMENT_CENTER, 60, 18, Color(1, 0.9, 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Weapon angle (radians, 0 = pointing forward, -PI/2 = up) for the current pose.
func _weapon_angle(progress: float, rest: float) -> float:
	match _anim_id:
		&"staff_strike", &"saber_slash", &"heavy_staff", &"heavy_saber":
			return lerpf(-2.0, 0.4, ease(progress * 1.6, 0.5))
		&"lightning", &"fireball", &"magic_push", &"force_push", &"force_choke":
			return -0.15
		&"victory":
			return -PI * 0.5
	return rest


func _draw_gandalf(flash: bool, hurt: bool, progress: float) -> void:
	var robe := Color.WHITE if flash else (Color(0.9, 0.5, 0.5) if hurt else Color(0.46, 0.58, 0.72))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -8), Vector2(16, -8), Vector2(25, 0), Vector2(-25, 0)]), Color(0.25, 0.29, 0.37))
	draw_rect(Rect2(-15, -61, 30, 55), robe)
	draw_circle(Vector2(0, -68), 13, Color(0.82, 0.72, 0.60))
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -76), Vector2(0, -110), Vector2(18, -76)]), Color(0.47, 0.52, 0.61))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -58), Vector2(0, -39), Vector2(9, -58), Vector2(5, -28), Vector2(-5, -28)]), Color(0.9, 0.88, 0.8))
	var angle := _weapon_angle(progress, -1.62)
	var hand := Vector2(14, -40)
	var tip := hand + Vector2(cos(angle), sin(angle)) * 62.0
	var butt := hand - Vector2(cos(angle), sin(angle)) * 26.0
	draw_line(butt, tip, Color(0.55, 0.36, 0.18), 5)
	draw_circle(tip, 5, Color(0.45, 0.85, 1))
	_draw_feet()


func _draw_vader(flash: bool, hurt: bool, progress: float) -> void:
	var armor := Color.WHITE if flash else (Color(0.4, 0.12, 0.14) if hurt else Color(0.12, 0.13, 0.17))
	draw_rect(Rect2(-16, -61, 32, 56), armor)
	draw_circle(Vector2(0, -70), 16, Color(0.04, 0.045, 0.06))
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -72), Vector2(-13, -88), Vector2(0, -97), Vector2(13, -88), Vector2(17, -72), Vector2(9, -58), Vector2(-9, -58)]), Color(0.025, 0.03, 0.04))
	draw_rect(Rect2(-8, -77, 16, 8), Color(0.18, 0.2, 0.23))
	draw_circle(Vector2(-5, -73), 2, Color(1, 0.08, 0.08))
	draw_circle(Vector2(5, -73), 2, Color(1, 0.08, 0.08))
	var angle := _weapon_angle(progress, -1.25)
	var hand := Vector2(14, -24)
	var tip := hand + Vector2(cos(angle), sin(angle)) * 88.0
	draw_line(hand, tip, Color(1, 0.12, 0.12), 8)
	draw_line(hand, tip, Color(1, 0.75, 0.75), 2)
	if _anim_id == &"force_guard":
		draw_arc(Vector2(10, -48), 52, -1.2, 1.2, 16, Color(0.5, 0.75, 1.0, 0.8), 4)
	_draw_feet()


func _draw_feet() -> void:
	draw_line(Vector2(-10, -5), Vector2(-15, 0), Color(0.07, 0.07, 0.09), 7)
	draw_line(Vector2(10, -5), Vector2(15, 0), Color(0.07, 0.07, 0.09), 7)
