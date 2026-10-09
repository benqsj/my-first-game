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
## Round 3 (2026-10-09, the user's word):
## * falls: a heavy blow throws him down by itself, a light one only
##   staggers him, but the close of a long string fells him;
## * gait: it trots after him, and runs once he plainly runs from it, each
##   clip at about its own pace;
## * from afar: 8-14 m off it leaps at him, 12-22 m it runs at him and
##   springs; both follow him and throw him down;
## * the roll-catch answers a roll; a swing follows him till late, then is
##   locked; a lone heavy blow's aftershock;
## * slide: a held swing, him backed off and aside during the hold, slides
##   at him as it lets go and throws him down; rolled through (i-frames at
##   its blow), it misses.
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
	var parts := ["strings", "raging", "sides", "steady", "stance", "rings", "falls", "gait", "afar", "catch",
			"track", "slide"]
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


const LIGHT_OK := [OgreFighter.SWEEP, OgreFighter.CHOP, OgreFighter.BACKHAND, OgreFighter.WIDE, OgreFighter.LOW,
		OgreFighter.KICK, OgreFighter.LUNGE]


## Its moves held out of the way (the leaps, the pound, the great blow).
func _hold_off(ogre: OgreFighter, keep: Array = []) -> void:
	for n: String in ["_leap_slam_wait", "_run_slam_wait", "_lunge_wait", "_pound_wait", "_heavy_wait"]:
		if not keep.has(n):
			ogre.set(n, 99.0)


func _falls() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.2))
	# Strings of two, each closed by a finisher: the close's own rule tried
	# often (it is 3 and 4 in the game).
	ogre.string_most = 2
	ogre.finisher_from = Vector2i(2, 2)
	var start := hero.global_position
	var recent: Array = []
	var downs: Array = []
	var staggers := [0]
	var light_downs := 0
	var was_down := false
	var serial := -1
	var info := [0, false]
	hero.struck.connect(func(_d: float, blocked: bool) -> void:
		if not blocked and LIGHT_OK.has(ogre.act) and not (ogre._closing and ogre._finishes()):
			staggers[0] += 1)
	for f in 50 * 60:
		await physics_frame
		_hold_off(ogre)
		if ogre.act_serial != serial:
			serial = ogre.act_serial
			recent.append([f, ogre.act])
		while not recent.is_empty() and f - int(recent[0][0]) > 90 and recent.size() > 1:
			recent.pop_front()
		info = [ogre._string_count, ogre._closing and ogre._finishes()]
		var down := hero.state == Player.State.DOWNED
		if down and not was_down:
			var acts: Array = []
			for r: Array in recent:
				acts.append(int(r[1]))
			downs.append([ogre.act, info[0], info[1], acts])
			if LIGHT_OK.has(ogre.act):
				light_downs += 1
		was_down = down
		if not down:
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
			var to := ogre.global_position - hero.global_position
			hero.rotation.y = atan2(-to.x, -to.z)
	var bad: Array = []
	for d: Array in downs:
		if LIGHT_OK.has(int(d[0])) and not bool(d[2]):
			bad.append(d)
	_check("a light swing never throws him down, unless it closes a long string", bad.is_empty(),
			"%d downs, wrong: %s" % [downs.size(), bad])
	_check("a light swing staggers him", staggers[0] > 0, "%d staggers" % staggers[0])
	var heavy_downs := 0
	for d: Array in downs:
		if OgreFighter.SWINGS.has(int(d[0])) and bool(OgreFighter.SWINGS[int(d[0])][2]):
			heavy_downs += 1
	_check("a heavy one throws him down by itself", heavy_downs > 0, str(downs))
	_check("the close of a long string fells him, light or not", ogre.finishers_made > 0 and light_downs > 0,
			"%d finishers, %d by a light close" % [ogre.finishers_made, light_downs])
	await _done(a[0])


func _gait() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 14.0))
	await physics_frame
	ogre._rouse(hero)
	var start := hero.global_position
	var trot := [0, 0]
	for f in 100:
		await physics_frame
		_hold_off(ogre)
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		var pace := Vector2(ogre.velocity.x, ogre.velocity.z).length()
		if f > 40 and ogre.act == Fighter.Act.NONE and pace > 1.0:
			trot[1] += 1
			if ogre._anim.current_clip() == ogre.trot_clip and absf(float(ogre._anim.get(&"_player").speed_scale) - 1.0) < 0.35:
				trot[0] += 1
	_check("coming at him it trots, at about the trot's own pace", trot[0] > trot[1] * 0.7, "%d of %d" % trot)
	# He runs from it, straight away at a sprint.
	var away := (hero.global_position - ogre.global_position)
	away.y = 0.0
	away = away.normalized()
	var ran := [0, 0]
	var gap := ogre._distance_to(hero)
	var pos := hero.global_position
	for f in 240:
		await physics_frame
		_hold_off(ogre)
		pos += away * 6.6 / 60.0
		hero.global_position = Vector3(pos.x, hero.global_position.y, pos.z)
		if f > 90:
			ran[1] += 1
			var pace := Vector2(ogre.velocity.x, ogre.velocity.z).length()
			if ogre.running_after and pace > 5.0 and ogre._anim.current_clip() == ogre.run_clip \
					and float(ogre._anim.get(&"_player").speed_scale) > 0.6 and float(ogre._anim.get(&"_player").speed_scale) < 1.35:
				ran[0] += 1
	_check("him running from it, it runs, at about the run's own pace", ran[0] > ran[1] * 0.6,
			"%d of %d (gap from %.1f)" % [ran[0], ran[1], gap])
	await _done(a[0])


func _afar() -> void:
	for which: int in [OgreFighter.LEAP_SLAM, OgreFighter.RUN_SLAM]:
		var a: Array = await _arena()
		var hero: Player = a[2]
		var off := 11.0 if which == OgreFighter.LEAP_SLAM else 18.0
		var ogre := _ogre(a, _ahead(hero, off))
		await physics_frame
		ogre._rouse(hero)
		var name := "the leap" if which == OgreFighter.LEAP_SLAM else "the run and spring"
		_hold_off(ogre)
		ogre.set("_leap_slam_wait" if which == OgreFighter.LEAP_SLAM else "_run_slam_wait", 0.0)
		var start := hero.global_position
		var began := false
		var downed := false
		var lift := 0.0
		var stepped := false
		var shocks := 0
		for f in 8 * 60:
			await physics_frame
			_hold_off(ogre, ["_leap_slam_wait"] if which == OgreFighter.LEAP_SLAM else ["_run_slam_wait"])
			if which == OgreFighter.RUN_SLAM:
				ogre._leap_slam_wait = 99.0
			began = began or ogre.act == which
			if ogre.act == which and ogre.body != null:
				lift = maxf(lift, ogre.body.position.y - ogre._body_rest_y)
				# A step aside as it comes: it follows him till it is committed.
				if not stepped and ogre._act_time > 0.05:
					stepped = true
					var side := (hero.global_position - ogre.global_position).cross(Vector3.UP).normalized()
					start += side * 1.5
			if hero.state == Player.State.DOWNED and began:
				downed = true
			if hero.state != Player.State.DOWNED:
				hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
			if downed and ogre.act != which:
				shocks = ogre.aftershocks_made
				break
		_check("%s from %.0f m: begun" % [name, off], began)
		_check("%s: up off the ground" % name, lift > 0.3, "%.2f m" % lift)
		_check("%s: it comes down on him, stepped aside, and throws him down" % name, downed,
				"ogre %.1f m from him" % ogre._distance_to(hero))
		_check("%s: the ground shakes again after it" % name, ogre.aftershocks_made > 0, str(shocks))
		await _done(a[0])


func _catch() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.0))
	ogre.sight_range = 0.0
	await physics_frame
	ogre._quarry = hero
	var gap := float(ogre._strike_from.get(OgreFighter.CATCH, 2.6))
	var to := hero.global_position - ogre.global_position
	ogre.global_position = hero.global_position - to.normalized() * gap
	ogre.rotation.y = atan2(-to.x, -to.z)
	var n := 0
	for i in 100:
		ogre._string_count = 1
		ogre._closing = false
		ogre._saw_roll = true
		ogre.stamina = ogre.max_stamina
		if ogre._next_in_string(OgreFighter.SWEEP) == OgreFighter.CATCH:
			n += 1
	_check("him rolled from under a blow, the next is mostly the roll-catch", n >= 45, "%d of 100" % n)
	ogre.act = OgreFighter.CATCH
	_check("the roll-catch is always held a roll's length", ogre._hold_of(OgreFighter.CATCH) >= ogre.catch_hold.x - 0.01,
			"%.2f s" % ogre._hold_of(OgreFighter.CATCH))
	ogre.act = Fighter.Act.NONE
	await _done(a[0])


func _track() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.0))
	ogre.sight_range = 0.0
	await physics_frame
	ogre._quarry = hero
	var to := hero.global_position - ogre.global_position
	ogre.rotation.y = atan2(-to.x, -to.z)
	# A plain swing (a held one let go with him out of reach slides after him,
	# [method _slide]).
	ogre.slide_slack = 99.0
	ogre._open(OgreFighter.SMASH)
	var commit := ogre._commit_at(OgreFighter.SMASH)
	# He steps round it as it winds up.
	var centre := ogre.global_position
	var r := Vector2(to.x, to.z).length()
	var ang := atan2(to.z, to.x) + deg_to_rad(45.0)
	var spot := centre + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	var off_at_commit := 999.0
	var turned_after := 0.0
	var rot_at := 0.0
	while ogre.act == OgreFighter.SMASH and ogre._act_time < commit + 0.25:
		await physics_frame
		if ogre._act_time >= commit and off_at_commit > 900.0:
			var t := spot - ogre.global_position
			off_at_commit = rad_to_deg(absf(angle_difference(ogre.rotation.y, atan2(-t.x, -t.z))))
			rot_at = ogre.rotation.y
			# and again past the commit: too late, it is locked
			ang += deg_to_rad(45.0)
			spot = centre + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if off_at_commit < 900.0:
			turned_after = maxf(turned_after, rad_to_deg(absf(angle_difference(ogre.rotation.y, rot_at))))
		hero.global_position = Vector3(spot.x, hero.global_position.y, spot.z)
	_check("a swing follows him round through its wind-up", off_at_commit < 15.0, "%.1f deg off at the commit" % off_at_commit)
	_check("and is locked from its late commit on", turned_after < 3.0, "turned %.1f deg after" % turned_after)
	await _done(a[0])


## A held smash: planted through its wind-up and hold whatever he does (no
## glide, no rocking to and fro); him backed off 4 m and a step aside, it
## slides at him the moment it lets go and fells him; him still in reach, no
## slide and it fells him; rolled through at its blow (i-frames), it misses.
func _slide() -> void:
	for how: String in ["off", "near", "rolled"]:
		var a: Array = await _arena()
		var hero: Player = a[2]
		var ogre := _ogre(a, _ahead(hero, 3.0))
		ogre.sight_range = 0.0
		await physics_frame
		ogre._quarry = hero
		var to := hero.global_position - ogre.global_position
		to.y = 0.0
		var reach := float(ogre._strike_from.get(OgreFighter.SMASH, ogre.strike_off))
		var away := to.normalized()
		ogre.global_position = hero.global_position - away * reach
		ogre.rotation.y = atan2(-to.x, -to.z)
		await physics_frame
		ogre._holds[OgreFighter.SMASH] = [1.0, 0.6, 0.6, 0.22]
		ogre._open(OgreFighter.SMASH)
		var sp := ogre._slide_span(OgreFighter.SMASH)
		var near := hero.global_position
		var spot := near + away * 4.0 + away.cross(Vector3.UP) * 1.2
		var from := ogre.global_position
		var drift := 0.0
		var downed := false
		var blow := ogre._blow_moments(OgreFighter.SMASH)[0]
		var f := 0
		while ogre.act == OgreFighter.SMASH:
			await physics_frame
			f += 1
			_hold_off(ogre)
			if ogre.act == OgreFighter.SMASH and ogre._act_time < sp.x - 0.05:
				var d := from - ogre.global_position
				drift = maxf(drift, Vector2(d.x, d.z).length())
				if how == "near":
					# He shuffles about in front of it, in reach.
					var at := near - away * 0.4 * absf(sin(f * 0.4)) + away.cross(Vector3.UP) * 0.5 * sin(f * 0.4)
					hero.global_position = Vector3(at.x, hero.global_position.y, at.z)
				else:
					hero.global_position = Vector3(spot.x, hero.global_position.y, spot.z)
			if how == "rolled":
				hero.is_invulnerable = absf(ogre._act_time - blow) < 0.3
			downed = downed or hero.state == Player.State.DOWNED
		hero.is_invulnerable = false
		var slid := Vector2(ogre.global_position.x - from.x, ogre.global_position.z - from.z).length()
		match how:
			"off":
				_check("held, him backed off: planted through its hold", drift < 0.12, "%.2f m" % drift)
				_check("and it slides at him as it lets go", ogre.slides_made == 1 and slid > 2.5,
						"slid %d, %.1f m" % [ogre.slides_made, slid])
				_check("and its blow throws him down", downed, "ogre %.1f m from him" % ogre._distance_to(hero))
			"near":
				_check("held, him shuffling in reach: no glide, no rocking", drift < 0.12, "%.2f m" % drift)
				_check("and no slide, and it fells him", ogre.slides_made == 0 and downed,
						"slid %d, downed %s" % [ogre.slides_made, downed])
			"rolled":
				_check("held, slid at him, rolled through at its blow: it misses", ogre.slides_made == 1 and not downed,
						"slid %d, downed %s" % [ogre.slides_made, downed])
		await _done(a[0])
