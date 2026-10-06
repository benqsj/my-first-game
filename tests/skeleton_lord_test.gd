extends SceneTree

## The skeletons' lord ([SkeletonLord]) in the test arena: kept off, it takes
## the bow and its arrows strike him; come close, sword and shield again and
## its blows land; at half its health it takes the staff and raises the dead,
## casts from afar and blasts him off up close; cut down, it breaks into
## its bones. Each stance shows only its own arms.
##
##   godot --headless --path . --script res://tests/skeleton_lord_test.gd

const LORD := "res://scenes/enemies/pack/skeleton_lord.tscn"

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _shown(lord: SkeletonLord, mesh: String) -> bool:
	var m := lord.body.find_child(mesh, true, false) as MeshInstance3D
	return m != null and m.visible


func _run() -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)
	var start := hero.global_position
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var lord := panel.call_up(LORD, true, start + fwd * 15.0) as SkeletonLord
	lord.max_health = 2000.0
	lord.health = 2000.0
	await physics_frame
	lord._rouse(hero)
	_check("it starts with sword and shield", lord.stance == SkeletonLord.Stance.SWORD
			and _shown(lord, "Skeleton_Warrior_Sword") and not _shown(lord, "Skeleton_Archer_Bow"))

	# 1. Kept off: the bow.
	var shots := 0
	var serial := -1
	var s0: int = struck[0]
	for f in 60 * 12:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if lord.act_serial != serial:
			serial = lord.act_serial
			if lord.act == SkeletonLord.SHOT:
				shots += 1
	for i in 60:
		await physics_frame
	_check("kept off, it takes the bow", lord.stance == SkeletonLord.Stance.BOW
			and _shown(lord, "Skeleton_Archer_Bow") and not _shown(lord, "Skeleton_Warrior_Sword")
			and not _shown(lord, "Skeleton_Warrior_Shield"), "stance %d" % lord.stance)
	_check("and shoots, again and again", shots >= 4, "%d shots" % shots)
	_check("its arrows strike him", struck[0] - s0 >= shots - 1 and struck[0] > s0, "%d of %d" % [struck[0] - s0, shots])

	# 2. Close: sword and shield again, its blows landing.
	var near := lord.global_position - fwd * 2.6
	hero.global_position = Vector3(near.x, hero.global_position.y, near.z)
	var swung := 0
	s0 = struck[0]
	for f in 60 * 10:
		await physics_frame
		hero.global_position = Vector3(near.x, hero.global_position.y, near.z)
		if lord.act_serial != serial:
			serial = lord.act_serial
			if lord._strikes().has(lord.act):
				swung += 1
	_check("come close, sword and shield again", lord.stance == SkeletonLord.Stance.SWORD
			and _shown(lord, "Skeleton_Warrior_Sword") and _shown(lord, "Skeleton_Warrior_Shield"), "stance %d" % lord.stance)
	_check("and its blows land", swung >= 3 and struck[0] - s0 >= swung - 1, "%d swung, %d struck" % [swung, struck[0] - s0])

	# 3. At half its health: the staff, the dead raised, spells.
	lord.health = lord.max_health * 0.45
	var far := lord.global_position - fwd * 10.0
	var acts := {}
	for f in 60 * 14:
		await physics_frame
		var at := far if f < 60 * 9 else lord.global_position - fwd * 2.4
		hero.global_position = Vector3(at.x, hero.global_position.y, at.z)
		if lord.act_serial != serial:
			serial = lord.act_serial
			acts[lord.act] = int(acts.get(lord.act, 0)) + 1
	_check("at half its health it takes the staff", lord.stance == SkeletonLord.Stance.STAFF
			and _shown(lord, "Skeleton_Mage_Staff") and _shown(lord, "Skeleton_Warrior_Shield")
			and not _shown(lord, "Skeleton_Warrior_Sword"), "stance %d" % lord.stance)
	_check("and raises the dead", lord._standing_raised() >= 2, "%d standing" % lord._standing_raised())
	_check("casts from afar", acts.has(SkeletonLord.BOLT) or acts.has(SkeletonLord.HEX), str(acts))
	_check("and blasts him off up close", acts.has(SkeletonLord.BLAST), str(acts))

	# 4. Cut down: its bones.
	lord.health = 1.0
	lord._receive(80.0, lord.global_position + Vector3.UP, fwd, null)
	await physics_frame
	var pieces := 0
	for n in Blood.world_of(lord).get_children():
		if n is RigidBody3D and String(n.name).begins_with("Bone_"):
			pieces += 1
	_check("cut down, it breaks into its bones", pieces >= 12 and not lord.body.visible, "%d pieces" % pieces)

	print("skeleton_lord_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
