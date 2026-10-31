extends "res://tests/test_case.gd"
## AudioDirector: event -> sound-key mapping, file lookup, music flow.


func _director(m: MatchController) -> AudioDirector:
	var audio := AudioDirector.new()
	tree.root.add_child(audio)
	_nodes.append(audio)
	audio.bind_match(m)
	return audio


func test_placeholder_files_resolve_and_missing_are_skipped() -> void:
	var audio := AudioDirector.new()
	tree.root.add_child(audio)
	_nodes.append(audio)
	for key in ["sfx/hit_spark", "sfx/blast_ko", "sfx/shield_hit", "music/battle", "music/menu", "ui/confirm"]:
		assert_true(audio.has_audio(key), "%s found" % key)
	assert_true(not audio.has_audio("voice/gandalf/does_not_exist"), "missing key has no audio")
	audio.play_sfx(["sfx/does_not_exist"])  # must not error
	assert_true(AudioServer.get_bus_index(&"Voice") >= 0 and AudioServer.get_bus_index(&"Music") >= 0, "buses created")


func test_gameplay_events_request_voice_and_sfx() -> void:
	var m: MatchController = await make_match()
	var audio := _director(m)
	face_off(m)
	audio.requested.clear()
	p(m, 1).tap(&"special_2")  # Gandalf fireball: specials always call out
	step(m, 3)
	assert_true(audio.requested.has("voice/gandalf/special_2"), "special requests a voice line")
	audio.requested.clear()
	m.get_fighter(1).cooldowns.clear()
	m.get_fighter(2).position = Vector2(660, GROUND_Y)
	for i in 30:
		step(m)
	p(m, 1).tap(&"heavy")
	step(m, 30)
	assert_true(audio.requested.has("sfx/hit_heavy") or audio.requested.has("sfx/hit_spark"), "hits play impact sfx")
	audio.requested.clear()
	m.get_fighter(2).position = Vector2(640, 3000)
	step(m, 2)
	assert_true(audio.requested.has("voice/vader/ko") and audio.requested.has("sfx/blast_ko"), "KO plays voice + boom")


func test_shield_sounds() -> void:
	var m: MatchController = await make_match()
	var audio := _director(m)
	face_off(m)
	p(m, 2).set_held(&"shield", true)
	step(m, 2)
	assert_true(audio.requested.has("sfx/shield_up"), "raising shield")
	audio.requested.clear()
	p(m, 1).tap(&"light")
	step(m, 10)
	assert_true(audio.requested.has("sfx/shield_hit"), "hit on shield uses shield_hit")


func test_music_follows_match_flow() -> void:
	var m: MatchController = await make_match(30, 1)
	var audio := _director(m)
	m.rematch()
	assert_eq(audio.current_music(), "battle", "battle music during the countdown/fight")
	m.get_fighter(2).position = Vector2(640, 3000)
	step(m, 40)
	assert_eq(audio.current_music(), "victory", "victory sting on the result")
	assert_true(audio.requested.has("voice/gandalf/victory"), "winner's victory line")


func test_volume_settings_drive_buses() -> void:
	AudioDirector.set_bus_volume(&"Music", 0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "0 mutes")
	AudioDirector.set_bus_volume(&"Music", 10)
	assert_near(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), 0.0, 0.01, "10 = full")
	assert_true(not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "unmuted")
