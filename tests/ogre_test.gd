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
##   clip at about its own pace (2026-10-11: no trot — it runs at him, the
##   run at about its own pace);
## * from afar: 8-14 m off it leaps at him, 12-22 m it runs at him and
##   springs; both follow him and throw him down;
## * the roll-catch answers a roll; a swing follows him till late, then is
##   locked; no aftershock after its blows (off, 2026-10-11);
## * slide: a held swing, him backed off and aside during the hold, slides
##   at him as it lets go and throws him down; rolled through (i-frames at
##   its blow), it misses.
##
## Spacing (2026-10-11, the user's word: between its strings like Elden
## Ring's great ones):
## * between its strings it walks round him, backs off, stands watching, and
##   now and then roars at him, then breaks off all at once at him; it still
##   fights as hard (strings keep coming).
## * strain: a held swing is not frozen — its body trembles through the hold
##   and is still again after, a creak rises to the letting go; heavy swings
##   held about half the time, the side sweeps sometimes too, and a held side
##   sweep slides round at him if he backed off.
## * whirl: a heavy, grounded spin — its hips never bob up above standing
##   (the old clip rose 0.37 m and dropped), and it lands on him.
## * grab: its free hand closes on him — through a raised shield too — he is
##   lifted off the ground, held, and thrown down; rolled (i-frames at its
##   reach) it misses and gives up soon; behind a shield it reaches for him
##   in a free fight.
## * punish: him casting near it, it is at him at once — a swing in reach, a
##   lunge from 6 m, a leap from 11 m; drawing his bow a while at 6 m, a
##   lunge; left alone at 11 m it does not leap at once.
## * phase: enraged, its roar staggers him near it (not off his feet), the
##   view shaken hard; its club burns
##   and cracks glow in its skin.
## * bar: fighting him, its name and health across the bottom of his view
##   (none over its head); killed, "ENEMY FELLED".
## * death: slow — on its knees, over on its face, the ground's thud; then
##   ash as it sinks; a great enemy, it always drops something.
## * looks: no two alike — of ten, several skins, several arms, some with
##   blood round the mouth; the same name, the same ogre.
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
			"track", "slide", "outrun", "spacing", "strain", "whirl", "grab", "punish", "phase", "bar", "death", "looks"]
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
	# its strings alone (its hand-made combos: ogre_combo_test)
	ogre.combo_chance = Vector2.ZERO
	ogre.close_combo_chance = 0.0
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
	# its strings alone (its hand-made combos: ogre_combo_test)
	ogre.combo_chance = Vector2.ZERO
	ogre.close_combo_chance = 0.0
	# (its strings only: the pound and the great blow, single moves, come
	# more often since it keeps its distance between strings)
	ogre._pound_wait = 999.0
	ogre._heavy_wait = 999.0
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
			# (at its feet: his own fall's dust, thrown by its roar, is his)
			if (mi.mesh is TorusMesh or mi is DustRing) \
					and mi.global_position.distance_to(ogre.global_position) < 2.5:
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
	# a steadier sample of its strings (a light close is a weighed chance)
	ogre._rng.seed = 5
	# the strings alone here (its hand-made combos: ogre_combo_test)
	ogre.combo_chance = Vector2.ZERO
	ogre.close_combo_chance = 0.0
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
	for f in 80 * 60:
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
			var scale_now := float(ogre._anim.get(&"_player").speed_scale)
			if ogre._anim.current_clip() == ogre.run_clip and scale_now > 0.6 and scale_now < 1.35:
				trot[0] += 1
	_check("coming at him it runs (no trot), at about the run's own pace", trot[0] > trot[1] * 0.7, "%d of %d" % trot)
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
			if (ogre.running_after or ogre.runs_after) and pace > 5.0 and ogre._anim.current_clip() == ogre.run_clip \
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
		_check("%s: no unseen second burst after it" % name, ogre.aftershocks_made == 0, str(shocks))
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
		if hero.rig is SkinnedRig:
			(hero.rig as SkinnedRig).last_flinch = {}
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
			# felled, or (a heavy blow alone, the hero's side since 2026-10-10)
			# reeling on his feet: either way it caught him
			var hero_rig := hero.rig as SkinnedRig
			var reeled := hero_rig != null and String(hero_rig.last_flinch.get("clip", "")).begins_with("TR_Big_Side_Hit")
			downed = downed or hero.state == Player.State.DOWNED or reeled
		hero.is_invulnerable = false
		var slid := Vector2(ogre.global_position.x - from.x, ogre.global_position.z - from.z).length()
		match how:
			"off":
				_check("held, him backed off: planted through its hold", drift < 0.12, "%.2f m" % drift)
				_check("and it slides at him as it lets go", ogre.slides_made == 1 and slid > 2.5,
						"slid %d, %.1f m" % [ogre.slides_made, slid])
				_check("and its blow throws him down (or, alone, reels him)", downed, "ogre %.1f m from him" % ogre._distance_to(hero))
			"near":
				_check("held, him shuffling in reach: no glide, no rocking", drift < 0.12, "%.2f m" % drift)
				_check("and no slide, and it fells him", ogre.slides_made == 0 and downed,
						"slid %d, downed %s" % [ogre.slides_made, downed])
			"rolled":
				_check("held, slid at him, rolled through at its blow: it misses", ogre.slides_made == 1 and not downed,
						"slid %d, downed %s" % [ogre.slides_made, downed])
		await _done(a[0])


## Running does not beat a held swing, the jump slam or a leap (the user's
## word, 2026-10-10): him running off at a hero's run (6.3 m/s) from the
## moment it begins — straight away, or across it — it still catches him;
## rolled through at its blow (i-frames), it misses.
func _outrun() -> void:
	var cases := [["held smash, run straight off", OgreFighter.SMASH, 0.0, false],
			["held smash, run across", OgreFighter.SMASH, 90.0, false],
			["jump slam, run straight off", OgreFighter.JUMP_SLAM, 0.0, false],
			["jump slam, run across", OgreFighter.JUMP_SLAM, 70.0, false],
			["the leap from 11 m, run across", OgreFighter.LEAP_SLAM, 90.0, false],
			["the leap from 11 m, run straight off", OgreFighter.LEAP_SLAM, 0.0, false],
			["jump slam, run off and rolled at its blow", OgreFighter.JUMP_SLAM, 0.0, true]]
	for c: Array in cases:
		var a: Array = await _arena()
		var hero: Player = a[2]
		var which: int = c[1]
		var ogre := _ogre(a, _ahead(hero, 3.0))
		ogre.sight_range = 0.0
		await physics_frame
		var to := hero.global_position - ogre.global_position
		to.y = 0.0
		var away := to.normalized()
		var reach := float(ogre._strike_from.get(which, ogre.strike_off))
		var off := 11.0 if which == OgreFighter.LEAP_SLAM else reach
		ogre.global_position = hero.global_position - away * off
		ogre.rotation.y = atan2(-to.x, -to.z)
		await physics_frame
		ogre._quarry = hero
		if which == OgreFighter.SMASH:
			ogre._holds[OgreFighter.SMASH] = [1.0, 0.6, 0.6, 0.22]
		elif ogre._holds.has(which):
			ogre._holds.erase(which)
		if hero.rig is SkinnedRig:
			(hero.rig as SkinnedRig).last_flinch = {}
		ogre._open(which)
		var run := away.rotated(Vector3.UP, deg_to_rad(float(c[2]))) * 6.3
		var blow := ogre._blow_moments(which)[0]
		var downed := false
		var ran := 0.0
		while ogre.act == which:
			await physics_frame
			_hold_off(ogre)
			if hero.state != Player.State.DOWNED and not downed:
				var at := hero.global_position + run / 60.0
				hero.global_position = at
				ran += run.length() / 60.0
			if bool(c[3]):
				hero.is_invulnerable = absf(ogre._act_time - blow) < 0.3
			var hero_rig := hero.rig as SkinnedRig
			var reeled := hero_rig != null and String(hero_rig.last_flinch.get("clip", "")).begins_with("TR_Big_Side_Hit")
			downed = downed or hero.state == Player.State.DOWNED or reeled
		hero.is_invulnerable = false
		if bool(c[3]):
			_check("%s: it misses" % c[0], not downed, "ran %.1f m" % ran)
		else:
			_check("%s: it still catches him" % c[0], downed, "ran %.1f m, ogre %.1f m from him" % [ran, ogre._distance_to(hero)])
		await _done(a[0])


func _spacing() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.2))
	ogre._taunt_wait = 0.0
	ogre._grab_wait = 99.0
	ogre.spacing_weights = Vector4(0.25, 0.15, 0.3, 0.3)
	# (a little longer than its own, so its breaking off shows in 40 s)
	ogre.spacing_time = Vector2(2.0, 3.0)
	var start := hero.global_position
	var backed := 0.0
	var strafed := 0.0
	var watched := 0.0
	var serial := -1
	var swings := 0
	for f in int(40.0 * 60.0):
		await physics_frame
		if hero.state != Player.State.DOWNED:
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if ogre.act == Fighter.Act.NONE and ogre._spacing != &"":
			var v := Vector3(ogre.velocity.x, 0.0, ogre.velocity.z)
			var fwd := ogre._forward()
			if v.dot(fwd) < -0.6:
				backed += 1.0 / 60.0
			if absf(v.dot(fwd.cross(Vector3.UP))) > 0.6:
				strafed += 1.0 / 60.0
			if ogre._spacing == &"watch" and v.length() < 0.2:
				watched += 1.0 / 60.0
		if ogre.act_serial != serial:
			serial = ogre.act_serial
			if ogre._strikes_table.has(ogre.act) or ogre.act == OgreFighter.GRAB:
				swings += 1
	_check("between its strings it walks round him", strafed > 1.0, "%.1f s" % strafed)
	_check("...backs off from him", backed > 0.5, "%.1f s" % backed)
	_check("...stands watching him", watched > 0.3, "%.1f s %s" % [watched, ogre.spacings_made])
	_check("...roars at him", ogre.taunts_made > 0, str(ogre.taunts_made))
	_check("...and breaks off all at once at him", ogre.bursts_made > 0, str(ogre.bursts_made))
	_check("it still fights hard", swings >= 10, "%d swings in 40 s" % swings)
	await _done(a[0])


func _strain() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.0))
	ogre.sight_range = 0.0
	await physics_frame
	_check("heavy swings held about half the time", absf(float(ogre._holds[OgreFighter.SMASH][0]) - 0.5) < 0.01,
			str(ogre._holds[OgreFighter.SMASH]))
	_check("the side sweeps held sometimes too", ogre._holds.has(OgreFighter.WIDE) and ogre._holds.has(OgreFighter.LOW))
	ogre._quarry = hero
	var to := hero.global_position - ogre.global_position
	to.y = 0.0
	ogre.rotation.y = atan2(-to.x, -to.z)
	ogre._holds[OgreFighter.SMASH] = [1.0, 0.7, 0.7, 0.22]
	ogre._open(OgreFighter.SMASH)
	var sh := ogre._shape(OgreFighter.SMASH)
	var top := float(sh[0]) * float(sh[1])
	var rest := ogre.body.position
	var shook := 0.0
	var after := 0.0
	while ogre.act == OgreFighter.SMASH:
		await physics_frame
		var d := ogre.body.position - rest
		var off := Vector2(d.x, d.z).length()
		if ogre._heard_clock > top + 0.05 and ogre._heard_clock < top + float(sh[2]):
			shook = maxf(shook, off)
		elif ogre._heard_clock > top + float(sh[2]) + 0.1:
			after = maxf(after, off)
	_check("held, its body trembles", shook > 0.004 * ogre.visual_scale, "%.4f m" % shook)
	_check("...and is still again after", after < 0.0005, "%.4f m" % after)
	_check("a creak rises to the letting go", ogre._strain_serial >= 0)
	# a held side sweep, him backed off and aside: it slides round at him
	await _done(a[0])
	a = await _arena()
	hero = a[2]
	ogre = _ogre(a, _ahead(hero, 3.0))
	ogre.sight_range = 0.0
	await physics_frame
	ogre._quarry = hero
	to = hero.global_position - ogre.global_position
	to.y = 0.0
	var away := to.normalized()
	ogre.rotation.y = atan2(-to.x, -to.z)
	ogre._holds[OgreFighter.WIDE] = [1.0, 0.6, 0.6, 0.2]
	var slid := ogre.slides_made
	ogre._open(OgreFighter.WIDE)
	var spot := hero.global_position + away * 3.0 + away.cross(Vector3.UP) * 1.0
	while ogre.act == OgreFighter.WIDE:
		await physics_frame
		hero.global_position = Vector3(spot.x, hero.global_position.y, spot.z)
	_check("a held side sweep slides round at him", ogre.slides_made > slid, str(ogre.slides_made - slid))
	await _done(a[0])


func _whirl() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 2.4))
	ogre.sight_range = 0.0
	for i in 20:
		await physics_frame
	ogre._quarry = hero
	var to := hero.global_position - ogre.global_position
	to.y = 0.0
	ogre.rotation.y = atan2(-to.x, -to.z)
	ogre._holds.erase(OgreFighter.WHIRL)
	var sk := ogre._skeleton
	var pel := sk.find_bone("pelvis_joint")
	var stand := (sk.global_transform * sk.get_bone_global_pose(pel).origin).y - ogre.global_position.y
	if hero.rig is SkinnedRig:
		(hero.rig as SkinnedRig).last_flinch = {}
	ogre._open(OgreFighter.WHIRL)
	var top := -INF
	var low := INF
	var hp := hero.health
	var hit := false
	while ogre.act == OgreFighter.WHIRL:
		await physics_frame
		var y := (sk.global_transform * sk.get_bone_global_pose(pel).origin).y - ogre.global_position.y
		# through the spin and its blow (standing up after it is no bob)
		if ogre._act_time <= ogre._blow_moments(OgreFighter.WHIRL)[0] + 0.4:
			top = maxf(top, y)
		low = minf(low, y)
		hit = hit or hero.state == Player.State.DOWNED or hero.health < hp \
				or (hero.rig is SkinnedRig and not (hero.rig as SkinnedRig).last_flinch.is_empty())
	_check("the whirl: through its spin its hips never bob up above standing", top - stand < 0.06,
			"standing %.2f, highest %.2f, lowest %.2f" % [stand, top, low])
	_check("the whirl: it lands on him", hit)
	await _done(a[0])


func _grab_once(how: String) -> Dictionary:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 2.6))
	ogre.sight_range = 0.0
	for i in 20:
		await physics_frame
	ogre._quarry = hero
	var to := hero.global_position - ogre.global_position
	to.y = 0.0
	ogre.rotation.y = atan2(-to.x, -to.z)
	if how == "shield":
		Input.action_press("block")
	var start := hero.global_position
	ogre._begin(OgreFighter.GRAB)
	var lift := 0.0
	var held := false
	var downed := false
	var length := 0.0
	var thrown_up := -1.0
	var neck_gap := 0.0
	var f := 0
	while f < 60 * 8:
		await physics_frame
		f += 1
		if how == "rolled":
			var ct := ogre._clip_time(OgreFighter.GRAB, ogre._act_time)
			hero.is_invulnerable = ogre.act == OgreFighter.GRAB and ct > ogre.grab_catch.x - 0.2 and ct < ogre.grab_catch.y + 0.2
		held = held or hero._held_by == ogre
		lift = maxf(lift, hero.global_position.y - start.y)
		if hero._held_by == ogre and hero._held_time > 0.1 and ogre._act_time < ogre._grab_marks().y:
			var skel := hero.rig.get(&"_skel") as Skeleton3D
			var nb := skel.find_bone("neck_01")
			var neck := skel.global_transform * skel.get_bone_global_pose(nb).origin
			neck_gap = maxf(neck_gap, neck.distance_to(ogre.grab_point()))
		if ogre.grab_throws > 0 and thrown_up < 0.0:
			thrown_up = hero.global_position.y - start.y
		downed = downed or hero.state == Player.State.DOWNED
		if ogre.act == OgreFighter.GRAB:
			length = ogre._act_time
		elif f > 30 and (downed or how == "rolled"):
			break
	Input.action_release("block")
	hero.is_invulnerable = false
	var out := {"caught": ogre.grabs_caught, "held": held, "lift": lift, "thrown": ogre.grab_throws,
			"thrown_up": thrown_up, "neck_gap": neck_gap,
			"downed": downed, "length": length, "free": hero._held_by == null}
	await _done(a[0])
	return out


func _grab() -> void:
	var r := await _grab_once("plain")
	_check("grab: its hand closes on him", int(r.caught) == 1 and bool(r.held), str(r))
	_check("grab: he is lifted off the ground", float(r.lift) > 0.8, "%.2f m" % float(r.lift))
	_check("grab: held by the neck, in its palm", float(r.neck_gap) < 0.12, "%.2f m" % float(r.neck_gap))
	_check("grab: thrown down, on the ground at once", float(r.thrown_up) < 0.3, "%.2f m" % float(r.thrown_up))
	_check("grab: and thrown down", int(r.thrown) == 1 and bool(r.downed) and bool(r.free), str(r))
	r = await _grab_once("shield")
	_check("grab: a raised shield does not hold it", int(r.caught) == 1 and bool(r.downed), str(r))
	r = await _grab_once("rolled")
	_check("grab: rolled under, it misses and gives up soon", int(r.caught) == 0 and float(r.length) < 2.4, str(r))
	# behind a raised shield, in a free fight, it reaches for him
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.0))
	ogre._grab_wait = 0.0
	ogre._pound_wait = 99.0
	ogre._heavy_wait = 99.0
	Input.action_press("block")
	var start := hero.global_position
	var tried := false
	var guarded := false
	for f in 60 * 30:
		await physics_frame
		hero.stamina = hero.max_stamina
		guarded = guarded or hero.guarding()
		if hero.state != Player.State.DOWNED and hero._held_by == null:
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if ogre.grabs_made > 0:
			tried = true
			break
	Input.action_release("block")
	_check("grab: behind a shield it reaches for him", tried, "grabs %d, rolls %d, guarded %s, wait %.1f" % [ogre.grabs_made, ogre.grab_rolls, guarded, ogre._grab_wait])
	await _done(a[0])


func _punish_once(off: float, how: String) -> Array:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, off))
	ogre._leap_slam_wait = 99.0
	ogre._run_slam_wait = 99.0
	ogre._lunge_wait = 99.0
	ogre._pound_wait = 99.0
	ogre._heavy_wait = 99.0
	ogre._grab_wait = 99.0
	ogre.spacing_time = Vector2.ZERO
	var start := hero.global_position
	for i in 30:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		ogre.global_position = _ahead(hero, off)
		ogre.velocity = Vector3.ZERO
		ogre._cooldown = 99.0
	var acts := []
	var serial := ogre.act_serial
	for f in 60:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		ogre._cooldown = maxf(ogre._cooldown, 0.0) if ogre.act != Fighter.Act.NONE else 99.0
		if how == "cast" and f == 2:
			hero.net_casts += 1
		if how == "draw":
			hero._drawing = true
		if ogre.act_serial != serial:
			serial = ogre.act_serial
			acts.append(ogre.act)
		if ogre._charging and not acts.has(-2):
			acts.append(-2)
	hero._drawing = false
	var out := [acts, ogre.punishes_made]
	await _done(a[0])
	return out


func _punish() -> void:
	var r := await _punish_once(2.6, "cast")
	_check("punish: him casting in its reach, a swing at once", int(r[1]) == 1 and not (r[0] as Array).is_empty()
			and OgreFighter.SWINGS.has((r[0] as Array)[0]), str(r))
	r = await _punish_once(6.0, "cast")
	_check("punish: him casting 6 m off, a lunge", (r[0] as Array).has(OgreFighter.LUNGE), str(r))
	r = await _punish_once(11.0, "cast")
	_check("punish: him casting 11 m off, a leap", (r[0] as Array).has(OgreFighter.LEAP_SLAM), str(r))
	r = await _punish_once(6.0, "draw")
	_check("punish: him drawing his bow 6 m off, a lunge", (r[0] as Array).has(OgreFighter.LUNGE), str(r))
	r = await _punish_once(11.0, "none")
	_check("punish: left alone 11 m off, no leap at once", not (r[0] as Array).has(OgreFighter.LEAP_SLAM)
			and int(r[1]) == 0, str(r))


func _phase() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 3.0))
	ogre.max_health = 1000.0
	ogre.health = 400.0
	if hero.rig is SkinnedRig:
		(hero.rig as SkinnedRig).last_flinch = {}
	var start := hero.global_position
	var downed := false
	var shook := 0.0
	var after := -1
	for f in 60 * 6:
		await physics_frame
		if hero.state != Player.State.DOWNED:
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if ogre.rage_throws > 0 and after < 0:
			after = f
		if after >= 0:
			downed = downed or hero.state == Player.State.DOWNED
			var cam := hero.get_viewport().get_camera_3d()
			if cam != null:
				shook = maxf(shook, absf(cam.h_offset) + absf(cam.v_offset))
			if f - after > 50 and ogre.raging:
				break
	var reeled := hero.rig is SkinnedRig and not (hero.rig as SkinnedRig).last_flinch.is_empty()
	_check("phase: enraged, its roar staggers him, not off his feet", ogre.raging and ogre.rage_throws > 0 and reeled
			and not downed, "raging %s, throws %d, reeled %s, downed %s" % [ogre.raging, ogre.rage_throws, reeled, downed])
	_check("phase: the roar shakes the view hard", shook > 0.1, "%.2f" % shook)
	_check("phase: its club burns, cracks glow in its skin", ogre._club_fire != null and ogre._cracks != null)
	await _done(a[0])


func _bar() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 4.0))
	var hud := hero._hud
	var shown := false
	for f in 60 * 3:
		await physics_frame
		shown = shown or (hud != null and hud.boss_shown)
	_check("bar: fighting him, its bar across the bottom", shown and hud._boss == ogre, str(shown))
	_check("bar: none over its head", not ogre._health_bar.visible)
	ogre.health = 1.0
	ogre.max_health = 100.0
	var felled := false
	ogre.call(&"_die")
	for f in 60 * 2:
		await physics_frame
		felled = felled or (hud._felled.modulate.a > 0.5)
	_check("bar: killed, ENEMY FELLED", felled and not hud.boss_shown)
	await _done(a[0])


func _death() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var ogre := _ogre(a, _ahead(hero, 5.0))
	ogre.sight_range = 0.0
	for i in 10:
		await physics_frame
	ogre.call(&"_die")
	var clip := StringName()
	var landed_at := -1.0
	var t := 0.0
	while t < 9.0 and not ogre._ashed:
		await physics_frame
		t += 1.0 / 60.0
		if t < 0.5:
			clip = ogre._anim.current_clip()
		if ogre._death_landed and landed_at < 0.0:
			landed_at = t
	_check("death: slow, on its knees and over on its face", clip == &"CR_MG_Death" and landed_at > 1.5,
			"%s, down at %.1f s" % [clip, landed_at])
	_check("death: then ash as it sinks", ogre._ashed, "%.1f s" % t)
	_check("death: a great enemy, it always drops something", LootDrop.chance_of(ogre) >= 1.0)
	await _done(a[0])


func _looks() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var scene: PackedScene = load(OGRE)
	var skins := {}
	var arms := {}
	var bloody := 0
	var same := true
	for k in 10:
		var o := scene.instantiate() as OgreFighter
		o.name = "Ogre_%d" % k
		o.sight_range = 0.0
		world.add_child(o)
		o.global_position = _ahead(hero, 12.0, (float(k) - 4.5) * 2.5)
		skins[o.skin_index] = true
		arms[o.arm_index] = true
		bloody += 1 if o.bloody else 0
		var twin := scene.instantiate() as OgreFighter
		twin.name = o.name
		twin._pick_looks()
		same = same and twin.skin_index == o.skin_index and twin.arm_index == o.arm_index and twin.bloody == o.bloody
		twin.free()
	await physics_frame
	_check("looks: of ten, several skins and arms, some bloody", skins.size() >= 3 and arms.size() >= 2 and bloody >= 1,
			"skins %s, arms %s, bloody %d" % [skins.keys(), arms.keys(), bloody])
	_check("looks: the same name, the same ogre (every peer alike)", same)
	await _done(world)
