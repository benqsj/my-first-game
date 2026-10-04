extends SceneTree
## The imp's blows land on a hero standing still (the user, 2026-10-04: they
## all but never did — the pounce and the flip came down after their window,
## the combo's claw before it and its mace short): every attack, thrown from
## its own gap, lands. And its legs keep a pace a body that size can keep
## (the user: "it moves its legs far too fast"): run, strafe and sneak played
## no faster than ×1.3.
##   Godot --headless --path . --script res://tests/imp_blows_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


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
	var fwd := -hero.global_basis.z
	var imp := panel.call_up("res://scenes/enemies/imp.tscn", false, hero.global_position + fwd * 6.0) as Imp
	imp.max_health = 99999.0
	imp.health = 99999.0
	var start := hero.global_position
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)

	# its legs, roused and coming round him
	var fastest := {}
	for f in 360:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if imp.act == 0:
			var clip := String(imp._anim.current_clip())
			if clip in ["IP_Run", "IP_Strafe_L", "IP_Strafe_R", "IP_Sneak"]:
				fastest[clip] = maxf(float(fastest.get(clip, 0.0)), imp._anim._player.speed_scale)
	print("  legs ", fastest)
	var worst := 0.0
	for c in fastest:
		worst = maxf(worst, float(fastest[c]))
	_check("its legs no faster than x1.3", not fastest.is_empty() and worst <= 1.3, str(fastest))

	var plan := [Imp.SWIPE, Imp.MACE, Imp.COMBO, Imp.SLAM, Imp.POUNCE, Imp.POUNCE, Imp.POUNCE, Imp.FLIP, Imp.FLIP,
			Imp.FLIP, Imp.SWIPE, Imp.MACE, Imp.COMBO, Imp.SLAM]
	var landed := {}
	var tried := {}
	for what: int in plan:
		# wait for it to stand, then put it where the blow is thrown from
		for i in 300:
			await physics_frame
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
			if imp.act == 0:
				break
		# and for him to be up (a string's last blow knocks him down) and
		# past the moment after it when nothing lands
		for i in 400:
			await physics_frame
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
			if hero.state != Player.State.DOWNED and hero._now() >= hero._safe_until \
					and not (hero.rig != null and hero.rig.is_down()):
				break
		for i in 20:
			await physics_frame
		var leap: bool = what == Imp.POUNCE or what == Imp.FLIP
		var gap := 5.0 if leap else 1.9
		imp.global_position = hero.global_position + fwd * gap
		imp.velocity = Vector3.ZERO
		imp._quarry = hero
		imp._cooldown = 99.0
		imp._tactic_left = 99.0
		var before: int = struck[0]
		imp._face(hero.global_position - imp.global_position, 1.0, 1000.0)
		if leap:
			var land := imp._blow_moments(what)[0]
			var travelled := imp._hips(imp._clip_of(what), imp._clip_time(what, land)).x
			var off := imp.land_off if what == Imp.POUNCE else imp.flip_land_off
			imp._begin(what)
			imp._stretch = clampf((gap - off) / maxf(travelled, 0.2), 0.3, 2.2)
		else:
			imp._begin(what)
		var serial := imp.act_serial
		while imp.act_serial == serial:
			await physics_frame
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		tried[what] = int(tried.get(what, 0)) + 1
		if struck[0] > before:
			landed[what] = int(landed.get(what, 0)) + 1
	var names := {Imp.SWIPE: "the claw", Imp.MACE: "the mace", Imp.COMBO: "the combo", Imp.SLAM: "the slam",
			Imp.POUNCE: "the pounce", Imp.FLIP: "the flip kick"}
	var all_tried := 0
	var all_landed := 0
	for what: int in names:
		var n: int = tried.get(what, 0)
		var got: int = landed.get(what, 0)
		all_tried += n
		all_landed += got
		_check("%s lands on him" % names[what], n > 0 and got >= 1, "%d of %d" % [got, n])
	# a blow that only grazes can pass him by now and then; not one in six
	_check("nearly all of them land", all_landed >= ceili(all_tried * 0.85), "%d of %d" % [all_landed, all_tried])
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
