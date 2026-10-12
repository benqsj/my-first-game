extends SceneTree
## The ogre made harder (the user's word, 2026-10-12, souls-like): its stamp
## round itself when he is greedy or stands under it; a string's first swing
## wound up slowly, those after it as quick as ever; no stamina to run out of;
## its blows hard.

const OGRE := "res://scenes/enemies/pack/ogre.tscn"
var _failed := 0


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
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	hero.call(&"_set_weapons_stowed", false)
	return [world, panel, hero]


func _done(world: Node) -> void:
	world.queue_free()
	for i in 3:
		await process_frame


func _ogre(a: Array, off: float) -> OgreFighter:
	var hero: Player = a[2]
	var ahead := -hero.global_basis.z
	ahead.y = 0.0
	var ogre := (a[1] as ArenaPanel).call_up(OGRE, false, hero.global_position + ahead.normalized() * off) as OgreFighter
	ogre.max_health = 99999.0
	ogre.health = 99999.0
	ogre.stance = 0.0
	return ogre


func _cut(ogre: OgreFighter, hero: Player) -> void:
	var hit := HitInfo.make(15.0, ogre.global_position + Vector3.UP * 1.5, Vector3.FORWARD, false, true, hero)
	hit.by_blade = true
	ogre.receive_hit(hit)


## [damage, stance] a cut at `height` m up its body puts in.
func _part_cut(ogre: OgreFighter, hero: Player, height: float) -> Vector2:
	var h0 := ogre.health
	var s0 := ogre.stance_taken
	if hero.rig != null and hero.rig.get(&"cut_weight") != null:
		hero.rig.set(&"cut_weight", 1.6)
	var hit := HitInfo.make(15.0, ogre.global_position + Vector3.UP * height, Vector3.FORWARD, false, true, hero)
	hit.by_blade = true
	ogre.receive_hit(hit)
	return Vector2(h0 - ogre.health, ogre.stance_taken - s0)


func _run() -> void:
	# greed: three cuts in quick succession, and it stamps
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, 3.0)
	await physics_frame
	ogre._rouse(hero)
	ogre.spacing_time = Vector2.ZERO
	var start := hero.global_position
	for i in 20:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
	# wait for it to be free, then cut it thrice
	var waited := 0
	while ogre.act != Fighter.Act.NONE and waited < 600:
		await physics_frame
		waited += 1
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
	ogre._cooldown = 99.0
	for k in 3:
		_cut(ogre, hero)
		for i in 12:
			await physics_frame
			ogre._cooldown = 99.0
	var stamped := false
	var reeled := false
	var downed := false
	for i in 180:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		stamped = stamped or ogre.act == OgreFighter.GETOFF
		if stamped and hero.rig is SkinnedRig and not (hero.rig as SkinnedRig).last_flinch.is_empty():
			reeled = true
		downed = downed or hero.state == Player.State.DOWNED
		if stamped and ogre.act != OgreFighter.GETOFF:
			break
	_check("greedy, three cuts quick: it stamps round itself", stamped, "made %d" % ogre.getoffs_made)
	_check("...and it staggers him, not off his feet", stamped and not downed, "downed %s" % downed)
	await _done(a[0])

	# stood under it: it stamps
	a = await _arena()
	hero = a[2]
	ogre = _ogre(a, 1.6)
	await physics_frame
	ogre._rouse(hero)
	start = hero.global_position
	var made := false
	var most := 0.0
	var gaps := []
	for i in 60 * 6:
		await physics_frame
		if hero.state != Player.State.DOWNED:
			# hugging it: kept in close under it wherever it steps
			var away := hero.global_position - ogre.global_position
			away.y = 0.0
			var at := ogre.global_position + away.normalized() * 1.6
			hero.global_position = Vector3(at.x, hero.global_position.y, at.z)
		most = maxf(most, ogre._under_for)
		if i % 30 == 0:
			gaps.append("%.1f/%d" % [ogre._distance_to(hero), ogre.act])
		if ogre.getoffs_made > 0:
			made = true
			break
	_check("stood under it, it stamps", made, "under %.1f s at most; %s" % [most, gaps])
	await _done(a[0])

	# a string's first swing slow, the next as quick as ever
	a = await _arena()
	hero = a[2]
	ogre = _ogre(a, 3.0)
	ogre.sight_range = 0.0
	await physics_frame
	ogre._quarry = hero
	var plain := ogre._blow_moments(OgreFighter.SWEEP)[0]
	ogre._open(OgreFighter.SWEEP)
	var opened := ogre._blow_moments(OgreFighter.SWEEP)[0]
	_check("a string's first swing wound up slowly", opened >= ogre.opener_least - 0.02 and plain < opened,
			"%.2f s (plain %.2f)" % [opened, plain])
	ogre._begin_move(OgreFighter.CHOP, OgreFighter.SWEEP)
	var follows := ogre._blow_moments(OgreFighter.CHOP)[0]
	ogre.act = OgreFighter.CHOP
	_check("the swing it runs on into, as quick as ever", not ogre.act_opens and follows < 0.55,
			"%.2f s" % follows)
	_check("no stamina to run out of", ogre.attack_cost == 0.0)
	# where it is struck: low on the legs fills its stance more, high on the
	# head bites deeper
	ogre.stance = 99999.0
	var low := _part_cut(ogre, hero, 0.6)
	var mid := _part_cut(ogre, hero, 2.2)
	var high := _part_cut(ogre, hero, 4.0)
	_check("a cut on its legs fills its stance more", low.y > mid.y * 1.3, "%.1f against %.1f" % [low.y, mid.y])
	_check("a cut on its head bites deeper", high.x > mid.x * 1.2, "%.1f against %.1f" % [high.x, mid.x])
	# enraged: its overhead blows break the ground
	ogre.net_rage()
	var sp := ogre.speed
	ogre._begin_move(OgreFighter.SMASH)
	for i in 150:
		await physics_frame
		if ogre.rage_grounds > 0:
			break
	_check("enraged, an overhead blow breaks the ground", ogre.rage_grounds > 0, str(ogre.rage_grounds))
	# home again: calm, the club clean
	ogre._made_whole()
	await physics_frame
	_check("home and whole, it is calm again", not ogre.raging and absf(ogre.speed - sp / ogre.rage_pace) < 0.01,
			"raging %s, speed %.2f" % [ogre.raging, ogre.speed])
	_check("its blows hard (hit_damage 72)", ogre.hit_damage >= 70.0, str(ogre.hit_damage))
	await _done(a[0])
	print("ogre_greed_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
