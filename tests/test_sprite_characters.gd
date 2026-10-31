extends "res://tests/test_case.gd"
## Checks every character whose sprites come from tools/pack_character.py
## (registered in presentation_setup.CHARACTER_ART): complete art, matching
## atlas build, consistent body size, and attack poses that follow gameplay.
const Setup = preload("res://scripts/presentation/presentation_setup.gd")


func _ids() -> Array:
	return Setup.CHARACTER_ART.keys()


func test_art_contract_for_every_packed_character() -> void:
	assert_true(_ids().size() >= 2, "packed characters registered")
	for id: StringName in _ids():
		var data := CharacterRoster.load_character(id)
		assert_true(data != null and data.validate().is_empty(), "%s data valid" % id)
		var frames: SpriteFrames = load("res://art/characters/%s/animations.tres" % id)
		for anim in GameIds.SHARED_ANIMATION_IDS + GameIds.MECHANIC_ANIMATION_IDS:
			assert_true(frames.has_animation(anim), "%s has %s" % [id, anim])
		for move in data.moves:
			assert_true(frames.has_animation(move.animation_id), "%s move %s has art" % [id, move.id])
			assert_true(GameIds.MOVE_ANIMATION_IDS[id].has(move.animation_id), "%s %s registered in GameIds" % [id, move.animation_id])
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/%s/manifest.json" % id))
		assert_eq(FileAccess.get_sha256("res://art/characters/%s/atlas.png" % id), manifest.atlas_sha256, "%s atlas matches its build" % id)
		assert_true(Setup.with_art(data).visual_scene != null, "%s sprites attach" % id)
		assert_true(ResourceLoader.exists(CharacterRoster.portrait_path(id)), "%s portrait" % id)


func test_heads_are_the_same_size_in_every_frame() -> void:
	# The Elon lesson: bodies must not change size between sheets. The packer
	# sizes by head width; verify on the output (median per source sheet).
	for id: StringName in _ids():
		var atlas := (load("res://art/characters/%s/atlas.png" % id) as Texture2D).get_image()
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/characters/%s/manifest.json" % id))
		var by_sheet := {}
		for k in manifest.poses.size():
			var sheet: String = manifest.poses[k].pose.split(":")[0]
			by_sheet.get_or_add(sheet, []).append(_head_width(atlas, k))
		var medians: Array = by_sheet.values().map(func(v: Array) -> float:
			v.sort()
			return float(v[v.size() / 2]))
		medians.sort()
		assert_true(medians[-1] / maxf(medians[0], 1.0) < 1.15, "%s head widths per sheet %s" % [id, str(medians)])


func _head_width(atlas: Image, k: int) -> int:
	var cell := atlas.get_region(Rect2i((k % 8) * 256, (k / 8) * 256, 256, 256))
	var top := cell.get_used_rect().position.y
	var widths: Array[int] = []
	for y in range(top + 3, top + 12):
		var first := -1
		var last := -1
		for x in 256:
			if cell.get_pixel(x, y).a > 0.15:
				if first < 0:
					first = x
				last = x
		if first >= 0:
			widths.append(last - first)
	widths.sort()
	return widths[widths.size() / 2] if not widths.is_empty() else 0


func test_every_move_follows_its_art_phases() -> void:
	for id: StringName in _ids():
		var data := Setup.with_art(CharacterRoster.load_character(id))
		var m: MatchController = await make_match()
		m.characters[1] = data
		var specs := [[&"light", Vector2.ZERO], [&"heavy", Vector2.ZERO]]
		for dir in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
			specs.append([&"special", dir])
		for slot in [[&"light", Vector2(0, -1)], [&"light", Vector2(0, 1)], [&"heavy", Vector2(0, -1)]]:
			specs.append(slot)
		for spec in specs:
			m.rematch()
			await tree.physics_frame
			var e := m.get_fighter(2)
			place(m.get_fighter(1), 300, 1)
			place(e, 800, 1)
			step(m, 2)
			p(m, 2).set_axis(spec[1])
			p(m, 2).tap(spec[0])
			step(m)
			p(m, 2).clear_axis()
			if e.move == null:
				failures.append("%s %s %s starts no move" % [id, spec[0], spec[1]])
				continue
			var move := e.move
			while e.move != null and e.move == move:
				e.visual_root._process(0.0)
				var expected := 0 if e.move_tick < move.startup_ticks else (1 if move.is_active_tick(e.move_tick) else 2)
				assert_eq(e.visual_root.sprite.frame, expected, "%s %s pose follows phase" % [id, move.id])
				step(m)
			assert_true(e.visual_root.warned.is_empty(), "%s %s: no missing animations" % [id, move.id])
		cleanup()
