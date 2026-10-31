extends SceneTree
## Tuning aid (not a pass/fail test). For every move, finds the lowest victim
## damage at which one hit from mid-stage KOs a victim that tries to recover
## (holds toward the stage and double-jumps once). Uses the real match code.
##   godot --headless --path . -s res://tests/ko_report.gd

const GANDALF := preload("res://data/characters/gandalf.tres")
const VADER := preload("res://data/characters/vader.tres")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Stage.new()
	root.add_child(stage)
	var m := MatchController.new()
	m.auto_step = false
	m.countdown_ticks = 0
	root.add_child(m)
	var chars: Array[CharacterData] = [GANDALF, VADER]
	var inputs: Array[PlayerInput] = [PlayerInput.new(1, true), PlayerInput.new(2, true)]
	m.setup(stage, chars, inputs)
	m.start_match()
	await physics_frame
	await physics_frame
	for attacker_id in [1, 2]:
		var data: CharacterData = chars[attacker_id - 1]
		for slot: StringName in GameIds.MOVE_SLOTS:
			var move := data.get_move(slot)
			if move.special_behaviour == GameIds.SPECIAL_GUARD:
				continue
			var ko_at := -1
			var kb0 := 0.0
			for dmg in range(0, 301, 5):
				m.rematch()
				var result := _trial(m, attacker_id, slot, float(dmg))
				if dmg == 0:
					kb0 = result.kb
				if result.ko:
					ko_at = dmg
					break
			print("%-8s %-10s %-13s dmg %5.1f  kb@0%% %5.0f  KO from %s" % [
				data.id, slot, move.animation_id, move.damage, kb0, ("%d%%" % ko_at) if ko_at >= 0 else ">300%"])
	quit(0)


func _trial(m: MatchController, attacker_id: int, slot: StringName, start_damage: float) -> Dictionary:
	var a := m.get_fighter(attacker_id)
	var v := m.get_fighter(3 - attacker_id)
	var move := a.character.get_move(slot)
	var gap := 60.0
	if move.special_behaviour == GameIds.SPECIAL_CHOKE:
		gap = 110.0
	elif slot == &"special_1" and a.character.id == &"gandalf":
		gap = 150.0
	elif slot == &"special_1":
		gap = 90.0
	for f: Fighter in [a, v]:
		f.velocity = Vector2.ZERO
		f.invulnerable_remaining = 0
	a.position = Vector2(640, 546)
	a.set_facing(1)
	v.position = Vector2(640 + gap, 546)
	v.set_facing(-1)
	m.step()
	m.step()
	v.damage = start_damage
	var vin: PlayerInput = m.inputs[v.player_id - 1]
	m.inputs[attacker_id - 1].tap(slot)
	var kb := 0.0
	var hit := false
	var jumped := false
	for i in 400:
		m.step()
		if v.state == Fighter.State.HITSTUN and not hit:
			hit = true
			kb = v.last_knockback
		if v.stocks < 3:
			return {"ko": true, "kb": kb}
		if hit and v.state != Fighter.State.HITSTUN and v.state != Fighter.State.HELD:
			vin.set_held(&"left" if v.position.x > 640 else &"right", true)
			if not jumped and v.velocity.y > 0.0 and v.position.y > 480.0:
				vin.tap(&"jump")
				jumped = true
		if hit and v.grounded and v.state != Fighter.State.HITSTUN:
			break
	vin.release_all()
	return {"ko": false, "kb": kb}
