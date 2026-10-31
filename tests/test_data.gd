extends "res://tests/test_case.gd"


func test_shipped_characters_validate() -> void:
	for c: CharacterData in [GANDALF, VADER]:
		var errors := c.validate()
		assert_true(errors.is_empty(), "%s validates: %s" % [c.id, ", ".join(errors)])
	assert_eq(GANDALF.id, &"gandalf", "stable gandalf id")
	assert_eq(VADER.id, &"vader", "stable vader id")


func test_move_animation_ids_match_registry() -> void:
	for c: CharacterData in [GANDALF, VADER]:
		var expected: Array = GameIds.MOVE_ANIMATION_IDS[c.id]
		var actual: Array = []
		for slot: StringName in GameIds.MOVE_SLOTS:
			actual.append(c.get_move(slot).animation_id)
		assert_eq(actual, expected, "%s animation ids in slot order" % c.id)


func test_validation_rejects_bad_timings() -> void:
	var m := _clone_move(GANDALF.get_move(&"light"))
	m.startup_ticks = 0
	m.recovery_ticks = -1
	var errors := m.validate(&"gandalf")
	assert_true(_contains(errors, "startup_ticks"), "zero startup rejected")
	assert_true(_contains(errors, "recovery_ticks"), "negative recovery rejected")


func test_validation_rejects_unknown_ids_and_refs() -> void:
	var c := _clone_character(GANDALF)
	var m := c.get_move(&"light")
	m.animation_id = &"moonwalk"
	m.start_effect_id = &"sparkles"
	m.cancel_into = [&"special_9"]
	m.damage_type = &"psychic"
	var errors := c.validate()
	assert_true(_contains(errors, "animation_id"), "unknown animation rejected")
	assert_true(_contains(errors, "unknown effect id"), "unknown effect rejected")
	assert_true(_contains(errors, "special_9"), "invalid cancel reference rejected")
	assert_true(_contains(errors, "damage_type"), "unknown damage type rejected")


func test_validation_rejects_hitbox_outside_active_window() -> void:
	var m := _clone_move(GANDALF.get_move(&"light"))
	m.hitboxes[0].start_tick = 2
	m.hitboxes[0].duration_ticks = 5  # active is 4 ticks
	assert_true(_contains(m.validate(&"gandalf"), "exceed active window"), "hitbox past active rejected")


func test_validation_requires_all_slots_and_guard_cooldown() -> void:
	var c := _clone_character(VADER)
	c.moves = c.moves.slice(0, 4)
	c.get_move(&"special_2").hitboxes.clear()
	var errors := c.validate()
	assert_true(_contains(errors, "missing required move 'special_3'"), "missing slot rejected")
	assert_true(_contains(errors, "GRAB"), "choke without grab rejected")
	var guard := _clone_move(VADER.get_move(&"special_3"))
	guard.cooldown_ticks = 0
	assert_true(_contains(guard.validate(&"vader"), "cooldown"), "guard without cooldown rejected")


func _contains(errors: PackedStringArray, needle: String) -> bool:
	for e in errors:
		if e.contains(needle):
			return true
	return false

