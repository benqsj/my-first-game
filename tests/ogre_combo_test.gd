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
		var blows := 0
		for m: int in moves:
			blows += ogre._blow_moments(m).size()
		var name := String(c["name"])
		_check("%s: its moves in order" % name, acts.slice(0, moves.size()) == moves, "%s vs %s" % [acts, moves])
		_check("%s: every blow found him" % name, _hits.size() >= blows, "%d of %d" % [_hits.size(), blows])
		var last_fells := (c["fells"] as Array).has(moves.size() - 1)
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
	# the drawn-out whirl from well off: it slides at him through the turn,
	# not before it, and comes round on him as it gets there
	await _arena()
	var sp := await _ogre(OgreFighter.OG_SPIN_SLIDE)
	var away := sp.global_position - _hero.global_position
	away.y = 0.0
	sp.global_position += away.normalized() * 5.0
	var him := _hero.global_position
	var from := sp.global_position
	sp._open(OgreFighter.OG_SPIN_SLIDE)
	var span: Vector2 = sp._flight_span(OgreFighter.OG_SPIN_SLIDE)
	var before := -1.0
	_f = 0
	while _f < 60 * 4 and sp.act == OgreFighter.OG_SPIN_SLIDE:
		await physics_frame
		_f += 1
		if _hits.is_empty():
			_hero.global_position = Vector3(him.x, _hero.global_position.y, him.z)
		if before < 0.0 and sp._act_time >= span.x:
			before = Vector2(sp.global_position.x - from.x, sp.global_position.z - from.z).length()
	var slid := Vector2(sp.global_position.x - from.x, sp.global_position.z - from.z).length()
	_check("the whirl from afar slides at him through the turn", before < 0.6 and slid > 3.5,
			"%.2f m before the turn, %.2f in all" % [before, slid])
	_check("...and comes round on him", not _hits.is_empty(), "%s" % [_hits])
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
