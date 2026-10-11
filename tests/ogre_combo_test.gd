extends SceneTree
## The ogre's combos made by hand (OgreFighter.COMBOS, 2026-10-10): each runs
## its moves in order on a hero standing in front, every blow lands, only its
## felling blows throw him down (the ones before stagger him), and it breaks
## off once he is down. Its strings weighed swing by swing still come too.
##   Godot --headless --path . --script res://tests/ogre_combo_test.gd

const OGRE := "res://scenes/enemies/pack/ogre.tscn"

var _failures := 0
var _world: World
var _panel: ArenaPanel
var _hero: Player
var _hits: Array = []
var _f := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _arena() -> void:
	if _world != null:
		_world.queue_free()
		for i in 3:
			await process_frame
	_world = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(_world)
	for i in 30:
		await physics_frame
	_panel = _world.get_node("ArenaPanel") as ArenaPanel
	_panel._clear()
	_panel._wait_for_blow = false
	_hero = _world.player()
	_hero.immortal = true
	_hits = []
	_hero.struck.connect(func(_d: float, _b: bool) -> void:
		_hits.append(_f))


func _ogre(first: int) -> OgreFighter:
	var ahead := -_hero.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var ogre := _panel.call_up(OGRE, false, _hero.global_position + ahead * 3.0) as OgreFighter
	ogre.max_health = 99999.0
	ogre.health = 99999.0
	ogre.stance = 0.0
	ogre.sight_range = 0.0
	ogre.combo_chance = Vector2.ZERO
	await physics_frame
	var reach := float(ogre._strike_from.get(first, ogre.strike_off))
	ogre.global_position = _hero.global_position + ahead * reach
	var to := _hero.global_position - ogre.global_position
	ogre.rotation.y = atan2(-to.x, -to.z)
	ogre._quarry = _hero
	return ogre


func _run() -> void:
	(load("res://scripts/hit_feel.gd") as Script).set(&"frame_clock", true)
	print("ogre_combo_test")
	for i in OgreFighter.COMBOS.size():
		var c: Dictionary = OgreFighter.COMBOS[i]
		var moves: Array = c["moves"]
		await _arena()
		var ogre := await _ogre(int(moves[0]))
		var at := _hero.global_position
		ogre.start_combo(i)
		var down_at := -1
		var acts: Array = []
		_f = 0
		while _f < 60 * 9:
			await physics_frame
			_f += 1
			for n: String in ["_leap_slam_wait", "_run_slam_wait", "_lunge_wait", "_pound_wait", "_heavy_wait", "_stomp_wait"]:
				ogre.set(n, 99.0)
			if ogre.act != Fighter.Act.NONE and (acts.is_empty() or acts[-1] != ogre.act):
				acts.append(ogre.act)
			if _hero.state != Player.State.DOWNED and down_at < 0:
				# kept where he stands till he falls (the shove aside)
				_hero.global_position = Vector3(at.x, _hero.global_position.y, at.z)
			if _hero.state == Player.State.DOWNED and down_at < 0:
				down_at = _f
			if ogre.act == Fighter.Act.NONE and _f > 60 and (down_at > 0 or acts.size() >= moves.size()):
				break
		# as it ran (a branch may have changed its close)
		moves = ogre.last_combo_moves
		var blows := 0
		for m: int in moves:
			blows += ogre._blow_moments(m).size()
		var name := String(c["name"])
		_check("%s: its moves in order" % name, acts.slice(0, moves.size()) == moves, "%s vs %s" % [acts, moves])
		_check("%s: every blow found him" % name, _hits.size() >= blows, "%d of %d" % [_hits.size(), blows])
		var last_fells := (ogre._combo_fells_at as Array).has(moves.size() - 1) or (c["fells"] as Array).has(moves.size() - 1)
		_check("%s: down only by its felling blow" % name,
				down_at > 0 and (not last_fells or _hits.size() > 0 and down_at >= int(_hits[_hits.size() - 1]) - 2),
				"down at %d, hits %s" % [down_at, _hits])
		_check("%s: counted" % name, ogre.combos_made == [i] and ogre.finishers_made == 1,
				"%s %d" % [ogre.combos_made, ogre.finishers_made])
		ogre.queue_free()
	# a perfect roll under its first blow: the next one still lands (the
	# user's word, 2026-10-10: after a perfect dodge the combo went through him)
	await _arena()
	var od := await _ogre(OgreFighter.OG_HORIZ)
	var at0 := _hero.global_position
	od.start_combo(0)
	var first: float = od._blow_moments(OgreFighter.OG_HORIZ)[0]
	var rolled := false
	var perfect := [false]
	_hero.perfect_dodged.connect(func() -> void: perfect[0] = true)
	_f = 0
	while _f < 60 * 6:
		await physics_frame
		_f += 1
		if not rolled and od.act == OgreFighter.OG_HORIZ and od._act_time >= first - 0.1:
			rolled = true
			_hero.set("_dash_cooldown_timer", 0.0)
			_hero.call(&"_start_evade", false)
		if rolled and _hero.state != Player.State.DASHING and _hero.state != Player.State.DODGING \
				and _hits.is_empty():
			# back where it swings, after the roll
			_hero.global_position = Vector3(at0.x, _hero.global_position.y, at0.z)
		if od.act == OgreFighter.OG_DOWN or od.act == Fighter.Act.NONE and _f > 60:
			break
	_check("a perfect roll under the first blow", perfect[0], "")
	_check("...and the next blow of the combo lands", not _hits.is_empty(), "%s" % [_hits])
	# the sliding whirl from well off (the user's word, 2026-10-11): it shoots
	# at him fast, as the heroes' glide, from 5 m and from 18 m alike, and
	# comes round on him as it gets there
	for off: float in [5.0, 12.0, 18.0]:
		await _arena()
		var sp := await _ogre(OgreFighter.OG_SPIN_SLIDE)
		var away := sp.global_position - _hero.global_position
		away.y = 0.0
		sp.global_position += away.normalized() * off
		var him := _hero.global_position
		var from := sp.global_position
		sp._open(OgreFighter.OG_SPIN_SLIDE)
		var last := from
		var top := 0.0
		_f = 0
		while _f < 60 * 4 and sp.act == OgreFighter.OG_SPIN_SLIDE:
			await physics_frame
			_f += 1
			if _hits.is_empty():
				_hero.global_position = Vector3(him.x, _hero.global_position.y, him.z)
			var step := Vector2(sp.global_position.x - last.x, sp.global_position.z - last.z).length() * 60.0
			top = maxf(top, step)
			last = sp.global_position
		var slid := Vector2(sp.global_position.x - from.x, sp.global_position.z - from.z).length()
		_check("the whirl from %.0f m: it slides at him fast" % off, slid > off * 0.8 and top > 12.0,
				"%.1f m, top %.1f m/s" % [slid, top])
		_check("...and comes round on him as it gets there", not _hits.is_empty(), "%s" % [_hits])
		sp.queue_free()
	# the great blow (2026-10-11): it turns after him through its glowing
	# wind-up and closes on him, so walking off does not beat it; the ground it
	# strikes bursts up in rock and throws down whoever is on it near
	await _arena()
	var hv := await _ogre(OgreFighter.HEAVY)
	hv._open(OgreFighter.HEAVY)
	var side := (hv.global_position - _hero.global_position).cross(Vector3.UP).normalized()
	var h0 := _hero.global_position
	var quakes0: int = hv.quakes_made
	_f = 0
	while _f < 60 * 5 and hv.act == OgreFighter.HEAVY:
		await physics_frame
		_f += 1
		# he walks off sideways and back through the wind-up, 4.5 m in all
		if _hits.is_empty():
			var u := clampf(float(_f) / 90.0, 0.0, 1.0)
			var to := h0 + side * 3.0 * u + (_hero.global_position - hv.global_position).normalized() * 1.5 * u
			_hero.global_position = Vector3(to.x, _hero.global_position.y, to.z)
	_check("the great blow follows him walking off", not _hits.is_empty(), "%s" % [_hits])
	_check("its ground bursts and shakes", hv.quakes_made > quakes0, "%d" % hv.quakes_made)
	hv.queue_free()
	# reading him before a combo's close
	await _arena()
	var rd := await _ogre(OgreFighter.OG_HORIZ)
	rd._saw_roll = true
	var after_roll: int = rd._read_him(OgreFighter.COMBOS[7]["branch"][2], OgreFighter.OG_DOWN)
	rd._saw_roll = false
	var stood: int = rd._read_him(OgreFighter.COMBOS[7]["branch"][2], OgreFighter.OG_DOWN)
	var away2 := rd.global_position - _hero.global_position
	away2.y = 0.0
	rd.global_position += away2.normalized() * 4.0
	var backed: int = rd._read_him(OgreFighter.COMBOS[8]["branch"][1], OgreFighter.OG_SPIN)
	_check("rolled under it: the overhead held for the end of his roll", after_roll == OgreFighter.OG_DOWN_HELD, str(after_roll))
	_check("stood: its close as made", stood == OgreFighter.OG_DOWN, str(stood))
	_check("backed off: the whirl slides at him", backed == OgreFighter.OG_SPIN_SLIDE, str(backed))
	rd.queue_free()
	# enraged, a combo runs on and its new close fells
	await _arena()
	var rg := await _ogre(OgreFighter.OG_HORIZ)
	rg.raging = true
	rg.start_combo(0)
	_check("enraged, it runs longer", rg.last_combo_moves.size() == 4 and rg._combo_fells_at == [3],
			"%s %s" % [rg.last_combo_moves, rg._combo_fells_at])
	rg.queue_free()
	# hugging it: one of its close combos
	await _arena()
	var hg := await _ogre(OgreFighter.OG_HEADBUTT)
	var aw := hg.global_position - _hero.global_position
	aw.y = 0.0
	hg.global_position = _hero.global_position + aw.normalized() * 0.9
	hg.close_combo_chance = 1.0
	var took: bool = hg._try_combo(hg._distance_to(_hero))
	var which := int(hg.combos_made[-1]) if not hg.combos_made.is_empty() else -1
	_check("hugging it: a close combo", took and which >= 0 and bool(OgreFighter.COMBOS[which].get("close", false)),
			"%s %d" % [took, which])
	hg.queue_free()
	# a held blow shows itself: the glint as it stops at the top
	await _arena()
	var gl := await _ogre(OgreFighter.OG_BACK)
	gl.start_combo(3)
	var glinted := false
	for i in 60 * 6:
		await physics_frame
		if gl.act == OgreFighter.OG_DOWN_HELD and gl._glint_serial == gl.act_serial:
			glinted = true
			break
	_check("a held blow glints as it stops", glinted, "")
	gl.queue_free()
	# a string still comes as it did
	await _arena()
	var o := await _ogre(OgreFighter.SWEEP)
	o.string_most = 3
	o._open(OgreFighter.SWEEP)
	for i in 60 * 6:
		await physics_frame
	_check("a string is no combo", o.combos_made.is_empty() and not o.moves_made.is_empty() and o.moves_made[0] == OgreFighter.SWEEP, "%s" % [o.moves_made])
	print("ogre_combo_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
