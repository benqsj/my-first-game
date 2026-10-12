extends SceneTree
## The evade made Elden Ring's (the user's word, 2026-10-12): untouchable only
## at its start (a blow late in a roll lands); no way pushed, a step back;
## an attack out of a roll is its own quick thrust; off the ground a low
## blow passes under him.

var _failed := 0


class LowFoe extends Node3D:
	var low := true
	func weapon_tip_now() -> Vector3:
		return global_position + Vector3.UP * (0.15 if low else 1.3)


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _arena() -> Array:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._unhurt = false
	var hero := world.player()
	hero.mend_rate = 0.0
	hero.call(&"_set_weapons_stowed", false)
	var foe := LowFoe.new()
	world.add_child(foe)
	foe.global_position = hero.global_position + Vector3(0, 0, -3)
	return [world, panel, hero, foe]


func _done(world: Node) -> void:
	world.queue_free()
	for i in 3:
		await process_frame


func _hold_still(hero: Player) -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
		Input.action_release(a)


func _run() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var foe: LowFoe = a[3]
	foe.low = false
	# a roll: a blow early in it goes through air, one late in it lands
	Input.action_press(&"move_forward")
	await physics_frame
	var hp := hero.health
	hero._start_evade(false)
	Input.action_release(&"move_forward")
	for i in 5:
		await physics_frame
	hero.receive_blow(20.0, foe, 0, 1, 7001)
	await physics_frame
	_check("early in a roll, a blow goes through air", hero.health == hp, "%.0f -> %.0f" % [hp, hero.health])
	while hero._now() - hero._evade_started_at < hero.dash_iframes + 0.05:
		await physics_frame
	var still_rolling := hero.state == Player.State.DASHING
	hero.receive_blow(20.0, foe, 0, 1, 7002)
	await physics_frame
	_check("late in it, in its recovery, a blow lands", still_rolling and hero.health < hp,
			"rolling %s, %.0f -> %.0f" % [still_rolling, hp, hero.health])
	for i in 60:
		await physics_frame

	# no way pushed: a step back, facing as before, cheaper
	_hold_still(hero)
	for i in 400:
		await physics_frame
		if hero.state == Player.State.GROUNDED and not hero.is_committed() and i > 30:
			break
	hero.stamina = hero.max_stamina
	var at := hero.global_position
	var facing := -hero.global_basis.z
	hero._start_evade(false)
	var stepped := hero._backstepping
	for i in 40:
		await physics_frame
	var moved := hero.global_position - at
	moved.y = 0.0
	_check("no way pushed, a step back", stepped and moved.dot(facing) < -0.8 and moved.length() < 3.5,
			"back %.2f m" % -moved.dot(facing))
	_check("...still facing the same way", (-hero.global_basis.z).dot(facing) > 0.95)
	_check("...cheaper than a roll", hero.max_stamina - hero.stamina <= hero.backstep_stamina + 0.5 \
			or hero.stamina >= hero.max_stamina - hero.backstep_stamina, "%.0f" % hero.stamina)
	for i in 40:
		await physics_frame

	# an attack pressed in a roll: the roll's own thrust as he comes up
	hero.stamina = hero.max_stamina
	Input.action_press(&"move_forward")
	await physics_frame
	hero._start_evade(false)
	Input.action_release(&"move_forward")
	for i in 6:
		await physics_frame
	hero._attack(false)
	var clip := &""
	var frames := 6
	for i in 60:
		await physics_frame
		frames += 1
		var c: StringName = hero.rig.call(&"current_clip")
		if c == SkinnedRig.ROLL_ATTACK["clip"]:
			clip = c
			break
	_check("an attack pressed in a roll: its own quick thrust after it", clip == SkinnedRig.ROLL_ATTACK["clip"], str(hero.rig.call(&"current_clip")))
	# out of the landing, not after the getting up (the user's word 2026-10-13)
	var whole := int(ceil(hero.dash_duration * Engine.physics_ticks_per_second))
	_check("...straight out of the landing, before the roll's end", frames < whole, "%d frames of %d" % [frames, whole])
	for i in 90:
		await physics_frame
	# and an attack long after a roll is the plain string
	hero._attack(false)
	await physics_frame
	_check("long after a roll, the plain cut", hero.rig.call(&"current_clip") != SkinnedRig.ROLL_ATTACK["clip"],
			str(hero.rig.call(&"current_clip")))
	for i in 90:
		await physics_frame

	# off the ground: a low blow passes under him, a high one does not
	hp = hero.health
	hero.velocity.y = 6.0
	hero.state = Player.State.AIRBORNE
	for i in 8:
		await physics_frame
	var aloft := not hero.is_on_floor()
	foe.low = true
	hero.receive_blow(20.0, foe, 0, 1, 7003)
	await physics_frame
	_check("in the air, a low blow passes under him", aloft and hero.health == hp, "aloft %s %.0f -> %.0f" % [aloft, hp, hero.health])
	foe.low = false
	hero.receive_blow(20.0, foe, 0, 1, 7004)
	await physics_frame
	_check("...a high one does not", hero.health < hp, "%.0f -> %.0f" % [hp, hero.health])
	await _done(a[0])
	print("dodge_er_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
