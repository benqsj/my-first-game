extends SceneTree
## A bot against the ogre (the user's word, 2026-10-12: the difficulty in
## numbers). Tariel through his own buttons, three ways: one who rolls in
## time ("good"), one who rolls late and half the time not at all ("bad"),
## one who cuts and cuts and rolls now and then ("greedy"). Each fight runs
## to a death or `LONGEST` s; what it prints is the measure.

const OGRE := "res://scenes/enemies/pack/ogre.tscn"
const LONGEST := 150.0
var _failed := 0
var _results := {}


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var styles: Array = ["good", "bad", "greedy"] if args.is_empty() else args
	var seed_of := 11
	for style: String in styles:
		_results[style] = await _duel(style, seed_of)
		seed_of += 7
	for style: String in _results:
		var r: Dictionary = _results[style]
		print("DUEL %-7s %s in %.0f s | hits on him %d, damage %.0f (%.1f x his health), flasks %d, rolls %d | ogre %.0f%% left, attack presses %d, its stamps %d | low %.1f s (down %.1f)" % [
			style, r.end, r.time, r.hits, r.damage, r.damage / r.full, r.flasks, r.rolls, r.ogre_left * 100.0, r.cuts, r.stamps, r.low, r.low_down])
	_check("each duel ran", _results.size() == styles.size())
	if _results.has("good") and _results.has("greedy"):
		var g: Dictionary = _results["good"]
		var gr: Dictionary = _results["greedy"]
		_check("greed costs: the greedy bot is hurt more for each second", gr.damage / maxf(gr.time, 1.0) > g.damage / maxf(g.time, 1.0),
				"%.1f against %.1f a second" % [gr.damage / maxf(gr.time, 1.0), g.damage / maxf(g.time, 1.0)])
	if _results.has("bad"):
		_check("a bot that rolls badly dies to it", (_results["bad"] as Dictionary).end == "died", str((_results["bad"] as Dictionary).end))
	print("ogre_duel_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _press(action: StringName) -> void:
	Input.action_press(action)


func _release_all() -> void:
	for a: StringName in [&"attack", &"dash", &"heal", &"move_forward", &"move_back", &"lock_on"]:
		Input.action_release(a)


func _duel(style: String, seed_of: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._wait_for_blow = false
	panel._unhurt = false
	var hero := world.player()
	hero.immortal = false
	hero.mend_rate = 0.0
	hero.call(&"_set_weapons_stowed", false)
	Controls.apply()
	var ahead := -hero.global_basis.z
	ahead.y = 0.0
	var ogre := panel.call_up(OGRE, false, hero.global_position + ahead.normalized() * 9.0) as OgreFighter
	await physics_frame
	ogre._rouse(hero)
	hero._hold_target(ogre)
	var r := {"end": "lived", "time": 0.0, "hits": 0, "damage": 0.0, "full": hero.max_health, "flasks": 0,
			"rolls": 0, "ogre_left": 1.0, "cuts": 0, "stamps": 0, "low": 0.0, "low_down": 0.0}
	hero.struck.connect(func(d: float, _b: bool) -> void:
		r.hits += 1
		r.damage += d)
	var t := 0.0
	var dodged_for := -1
	var last_health := hero.health
	var pressed := {}
	while t < LONGEST:
		# (this runs as the frame begins, before the bodies' own physics: what
		# is pressed here is read by him this same frame, and let go next)
		await physics_frame
		_release_all()
		t += 1.0 / 60.0
		if hero.is_dead:
			r.end = "died"
			break
		if ogre.is_dead:
			r.end = "won"
			break
		if hero.target == null:
			hero._hold_target(ogre)
		var gap := hero.global_position.distance_to(ogre.global_position)
		# the next blow coming at him, in seconds (INF if none)
		var next := INF
		if ogre._strikes_table.has(ogre.act):
			for m: float in ogre._blow_moments(ogre.act):
				if m - ogre._act_time > -0.02:
					next = minf(next, m - ogre._act_time)
		elif ogre.act == OgreFighter.GETOFF:
			next = ogre._getoff_at() - ogre._act_time
		var reach := float(ogre._strike_from.get(ogre.act, ogre.strike_off)) + 2.5
		var threat := next < INF and gap < reach + (8.0 if OgreFighter.FLIGHTS.has(ogre.act) else 0.0)
		# when to roll, by the style
		var roll_at := 0.18
		var roll_chance := 1.0
		match style:
			"bad":
				roll_at = 0.07
				roll_chance = 0.5
			"greedy":
				roll_at = 0.15
				roll_chance = 0.3
		if threat and next <= roll_at and next > 0.0 and dodged_for != ogre.act_serial * 100 + int(next * 10.0):
			dodged_for = ogre.act_serial * 100 + int(next * 10.0)
			if rng.randf() < roll_chance and hero.stamina > 20.0:
				_press(&"dash")
				r.rolls += 1
				continue
		# a flask, low and with a moment
		var low := hero.health < hero.max_health * 0.55 and hero.flasks_left > 0
		if low:
			r.low += 1.0 / 60.0
			if hero.state == Player.State.DOWNED:
				r.low_down += 1.0 / 60.0
		if low and (not threat or next > 0.9) and not hero.is_committed() and not hero.drinking():
			var before := hero.flasks_left
			_press(&"heal")
			await physics_frame
			if hero.flasks_left < before:
				r.flasks += 1
			continue
		if low:
			# wanting a flask: no more cutting till it is drunk
			if gap < 6.0 and not hero.drinking():
				_press(&"move_back")
			continue
		# in at it, and cutting when it is open (the greedy one always)
		var open := ogre.act == Fighter.Act.NONE or not threat or next > (0.25 if style == "greedy" else 0.7)
		if gap > 3.0:
			_press(&"move_forward")
		elif open and hero.stamina > (5.0 if style == "greedy" else 30.0):
			_press(&"attack")
			r.cuts += 1
	_release_all()
	r.time = t
	r.ogre_left = ogre.health / maxf(ogre.max_health, 1.0)
	r.stamps = ogre.getoffs_made
	world.queue_free()
	for i in 3:
		await process_frame
	return r
