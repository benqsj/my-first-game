extends SceneTree

## The ogre made over in Elden Ring's way (2026-10-08, the user's word: the
## same combo again and again; no hit-stop on the big ones but their stance;
## rage without rings at its feet), in the test arena:
##
## * against him standing still it runs strings: many kinds of swing, light
##   and heavy, strings of two and more, never one swing twice running in a
##   string; enraged, longer strings and as many kinds, not one swing over
##   and over;
## * from his side it sweeps round at him, from behind the backhand;
## * a blade does not hold it (no hit-stop), nor push it about;
## * its stance: heavy blows fill it faster than light ones; full, it goes
##   down on a knee, the first blow then is a critical (x`stance_crit`), and
##   it gets up; left alone its stance is whole again;
## * enraged: no ring at its feet.
##
##   godot --headless --path . --script res://tests/ogre_test.gd [-- <part>...]

const OGRE := "res://scenes/enemies/pack/ogre.tscn"

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	var parts := ["strings", "raging", "sides", "steady", "stance", "rings"]
	for part: String in parts:
		if only.is_empty() or only.has(part):
			await call("_" + part)
	print("ogre_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


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
	Input.action_release("attack")
	world.queue_free()
	for i in 3:
		await process_frame


func _ahead(hero: Player, d: float, side: float = 0.0) -> Vector3:
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	return hero.global_position + fwd * d + fwd.cross(Vector3.UP) * side


func _ogre(a: Array, at: Vector3) -> OgreFighter:
	var ogre := (a[1] as ArenaPanel).call_up(OGRE, false, at) as OgreFighter
	ogre.max_health = 99999.0
	ogre.health = 99999.0
	ogre.stance = 0.0
	return ogre


## Seconds of him standing still in front of it; the strings it ran, each a
## list of its swings.
func _watch(hero: Player, ogre: OgreFighter, seconds: float) -> Array:
	var start := hero.global_position
	var strings: Array = []
	var serial := -1
	var current: Array = []
	for f in int(seconds * 60.0):
		await physics_frame
		if hero.state != Player.State.DOWNED:
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
			var to := ogre.global_position - hero.global_position
			hero.rotation.y = atan2(-to.x, -to.z)
		if ogre.act_serial == serial:
			continue
		serial = ogre.act_serial
		if OgreFighter.SWINGS.has(ogre.act) or ogre.act == OgreFighter.POUND or ogre.act == OgreFighter.HEAVY:
			if ogre._string_count <= 1 and not current.is_empty():
				strings.append(current)
				current = []
			current.append(ogre.act)
		elif ogre.act == Fighter.Act.NONE and not current.is_empty():
			strings.append(current)
			current = []
	if not current.is_empty():
		strings.append(current)
	return strings


func _kinds_in(strings: Array) -> Dictionary:
	var kinds := {}
	for s: Array in strings:
		for m: int in s:
			kinds[m] = int(kinds.get(m, 0)) + 1
	return kinds


func _repeats(strings: Array) -> int:
	var n := 0
	for s: Array in strings:
		for i in range(1, s.size()):
			if s[i] == s[i - 1]:
				n += 1
	return n


func _longest(strings: Array) -> int:
	var most := 0
	for s: Array in strings:
		most = maxi(most, s.size())
	return most


func _strings() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.2))
	var strings := await _watch(hero, ogre, 45.0)
	var kinds := _kinds_in(strings)
	var light := 0
	var heavy := 0
	for m: int in kinds:
		if OgreFighter.SWINGS.has(m):
			if bool(OgreFighter.SWINGS[m][2]):
				heavy += 1
			else:
				light += 1
	var top := 0
	var total := 0
	for m: int in kinds:
		top = maxi(top, int(kinds[m]))
		total += int(kinds[m])
	_check("it runs strings of many swings, light and heavy", kinds.size() >= 6 and light >= 2 and heavy >= 2,
			"%d kinds (%d light, %d heavy): %s" % [kinds.size(), light, heavy, kinds])
	_check("strings of two and more", _longest(strings) >= 2, str(strings))
	_check("never the same swing twice running in a string", _repeats(strings) == 0, str(strings))
	_check("no swing is most of what it does", float(top) <= float(total) * 0.4, "%d of %d" % [top, total])
	await _done(a[0])


func _raging() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.2))
	await physics_frame
	ogre.net_rage()
	var strings := await _watch(hero, ogre, 40.0)
	var kinds := _kinds_in(strings)
	var top := 0
	var total := 0
	for m: int in kinds:
		top = maxi(top, int(kinds[m]))
		total += int(kinds[m])
	_check("enraged, its strings run longer", _longest(strings) >= 3, str(strings))
	_check("enraged, many kinds of swing, not one over and over", kinds.size() >= 5 and float(top) <= float(total) * 0.4,
			"%d kinds, the most %d of %d: %s" % [kinds.size(), top, total, kinds])
	await _done(a[0])


func _sides() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 2.6))
	await physics_frame
	# Him at its side and at its back: what it picks to open with.
	var picks := {&"side": {}, &"behind": {}}
	for where: StringName in picks:
		for i in 60:
			var to := hero.global_position - ogre.global_position
			var face := atan2(-to.x, -to.z)
			ogre.rotation.y = face + (deg_to_rad(90.0) if where == &"side" else PI)
			ogre._quarry = hero
			ogre._last_opener = -1
			var gap := float(ogre._strike_from.get(OgreFighter.WIDE if where == &"side" else OgreFighter.BACKHAND, 2.6))
			var pick := ogre._pick_opener(gap)
			(picks[where] as Dictionary)[pick] = int((picks[where] as Dictionary).get(pick, 0)) + 1
	var side: Dictionary = picks[&"side"]
	var behind: Dictionary = picks[&"behind"]
	var sweeps := int(side.get(OgreFighter.WIDE, 0)) + int(side.get(OgreFighter.LOW, 0))
	_check("at its side it mostly sweeps round at him", sweeps >= 30, str(side))
	_check("at its back, the backhand", int(behind.get(OgreFighter.BACKHAND, 0)) >= 30, str(behind))
	await _done(a[0])


func _steady() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 6.0))
	ogre.sight_range = 0.0
	for i in 20:
		await physics_frame
	_check("a blade does not hold it (no hit-stop on it)", HitFeel.hold_share(ogre) == 0.0, str(HitFeel.hold_share(ogre)))
	HitFeel.bite(ogre, 1.6)
	_check("bitten, it is not held", not HitFeel.is_held(ogre))
	ogre.velocity = Vector3.ZERO
	ogre._receive(20.0, ogre.global_position + Vector3.UP, Vector3.FORWARD, hero)
	var push := Vector2(ogre.velocity.x, ogre.velocity.z).length()
	_check("nor is it pushed about by a blow", push < 0.5, "%.2f m/s" % push)
	await _done(a[0])


func _stance() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := (a[1] as ArenaPanel).call_up(OGRE, false, _ahead(hero, 6.0)) as OgreFighter
	ogre.max_health = 99999.0
	ogre.health = 99999.0
	ogre.sight_range = 0.0
	for i in 20:
		await physics_frame
	# A light cut and a heavy blow of the same damage: the heavy fills more.
	var light := _stance_of(ogre, hero, 20.0, 1.0)
	var heavy := _stance_of(ogre, hero, 20.0, 1.6)
	_check("a heavy blow fills its stance faster than a light one", heavy > light * 2.0, "%.1f against %.1f" % [heavy, light])
	ogre.stance_taken = 0.0
	var cuts := 0
	while ogre.act != PackBrute.STANCE and cuts < 40:
		_cut(ogre, hero, 20.0, 1.6)
		cuts += 1
		await physics_frame
	_check("enough blows put it down on a knee", ogre.act == PackBrute.STANCE and ogre.stance_breaks == 1,
			"%d blows, act %d" % [cuts, ogre.act])
	for i in 30:
		await physics_frame
	var before := ogre.health
	_cut(ogre, hero, 20.0, 1.0)
	var crit := before - ogre.health
	var after := ogre.health
	_cut(ogre, hero, 20.0, 1.0)
	var plain := after - ogre.health
	_check("down, the first blow on it is a critical", ogre.crits_taken == 1 and crit > plain * (ogre.stance_crit - 0.3),
			"%.1f against %.1f" % [crit, plain])
	var up := false
	for i in 300:
		await physics_frame
		if ogre.act != PackBrute.STANCE:
			up = true
			break
	_check("and it gets up", up)
	ogre.stance_taken = 0.0
	_cut(ogre, hero, 20.0, 1.0)
	var taken := ogre.stance_taken
	for i in int((ogre.stance_rest + 0.5) * 60.0):
		await physics_frame
	_check("left alone, its stance is whole again", taken > 0.0 and ogre.stance_taken == 0.0,
			"%.1f, then %.1f" % [taken, ogre.stance_taken])
	await _done(a[0])


## One cut of his at it, his swing `weight` heavy.
func _cut(ogre: OgreFighter, hero: Player, damage: float, weight: float) -> void:
	if hero.rig != null and hero.rig.get(&"cut_weight") != null:
		hero.rig.set(&"cut_weight", weight)
	var hit := HitInfo.make(damage * weight, ogre.global_position + Vector3.UP * 1.5, Vector3.FORWARD, false, true, hero)
	hit.by_blade = true
	ogre.receive_hit(hit)


func _stance_of(ogre: OgreFighter, hero: Player, damage: float, weight: float) -> float:
	ogre.stance_taken = 0.0
	_cut(ogre, hero, damage, weight)
	var taken := ogre.stance_taken
	ogre.stance_taken = 0.0
	return taken


func _rings() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var ogre := (a[1] as ArenaPanel).call_up(OGRE, false, _ahead(hero, 5.0)) as OgreFighter
	for i in 10:
		await physics_frame
	ogre._pound_wait = 99.0
	ogre._heavy_wait = 99.0
	ogre.health = ogre.max_health * 0.45
	ogre._rouse(hero)
	var rings := 0
	var raged := false
	for i in 150:
		await physics_frame
		raged = raged or ogre.raging
		if ogre.act != PackBrute.RAGE:
			continue
		for node in world.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh is TorusMesh or mi is DustRing:
				rings += 1
	_check("enraged, no ring at its feet", raged and rings == 0, "raged %s, %d rings seen" % [raged, rings])
	await _done(world)
