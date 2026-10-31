class_name PlaceholderArena
extends Node2D
## TEMPORARY PLACEHOLDER ARENA ART (starter prototype shapes). Draws the
## background and the platform visuals from Stage.PLATFORMS; collision lives in
## scripts/gameplay/stage.gd. Codex replaces this node with final arena art.


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.035, 0.055, 0.11))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 470), Vector2(150, 270), Vector2(270, 440), Vector2(420, 240), Vector2(580, 450),
		Vector2(760, 300), Vector2(900, 445), Vector2(1080, 220), Vector2(1280, 460),
		Vector2(1280, 720), Vector2(0, 720)]), Color(0.10, 0.15, 0.27))
	draw_colored_polygon(PackedVector2Array([Vector2(1000, 80), Vector2(1025, 50), Vector2(1050, 80), Vector2(1025, 105)]), Color(0.6, 0.65, 0.8))
	var colors := [Color(0.34, 0.37, 0.43), Color(0.40, 0.48, 0.58), Color(0.48, 0.32, 0.34), Color(0.47, 0.43, 0.39)]
	for i in Stage.PLATFORMS.size():
		var def: Dictionary = Stage.PLATFORMS[i]
		var rect := Rect2(def.center - def.size * 0.5, def.size)
		draw_rect(rect, colors[i % colors.size()])
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(0.8, 0.83, 0.9), 4)
		if def.one_way:
			# Dashed underside marks a pass-through platform.
			for x in range(int(rect.position.x) + 6, int(rect.end.x) - 6, 18):
				draw_line(Vector2(x, rect.end.y), Vector2(x + 9, rect.end.y), Color(0.8, 0.83, 0.9, 0.5), 2)
	draw_string(ThemeDB.fallback_font, Vector2(1100, 712), "PLACEHOLDER ART", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.35))
