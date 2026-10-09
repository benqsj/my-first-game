extends SceneTree
## Falls that follow the blow (the user's word, 2026-10-09; Tariel first):
## - felled from in front he is thrown back onto his back, and gets up off it;
## - a very heavy blow in front launches him: off the ground, carried back;
## - heavy from his left he is thrown over to his right (and gets up by the
##   throw's own clip), from his right to his left; lighter ones from a side
##   go over backwards or forwards;
## - from behind onto his face; a heavy blow on his head from above straight
##   down onto his stomach; a skill's blast throws him straight back;
## - he lies only a moment: on his feet again in about 3 s at most, off his
##   back with LayToIdle/KipUp, off his face with Mixamo's get-ups;
## - down on his knee (a broken guard), a second blow throws him down;
## - the weapon's own sweep leads: thrown the way it went, crushed by one
##   coming down, launched by one rising, further the harder it came.
##   Godot --headless --path . --script res://tests/fall_test.gd

var _failures := 0
var _hero: Player
var _foe: Node3D
var _serial := 500


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	await _wait(30)
	(world.get_node("ArenaPanel") as ArenaPanel)._clear()
	_hero = world.player()
	_hero.immortal = true
	_hero.call(&"_set_weapons_stowed", false)
	_foe = Node3D.new()
	# a striker that names its blow, as the ogre does (OgreFighter.blow_name)
	var naming := GDScript.new()
	naming.source_code = "extends Node3D\nvar named: StringName = &\"\"\nfunc blow_name() -> StringName:\n\treturn named\n"
	naming.reload()
	_foe.set_script(naming)
	world.add_child(_foe)
	var rig := _hero.rig as SkinnedRig
	_check("Tariel's falls follow the blow", rig != null and rig.falls_directional())

	var front := await _fell(Vector3(0, 0, -2), 12.0)
	_check("in front: thrown back", front["kind"] == SkinnedRig.Fall.BACK and front["moved"].z > 0.3, str(front))
	_check("lying on his back, up off it with a clip", front["on_back"] and front["up"] != &"", str(front))
	_check("on his feet again inside 3 s", front["up_in"] < 3.0, "%.2f s" % front["up_in"])

	var fly := await _fell(Vector3(0, 0, -2), 40.0)
	_check("a very heavy one in front: thrown back hard (the heavy fall)", fly["kind"] == SkinnedRig.Fall.BACK
			and fly["tier"] == 2, str(fly))
	_check("and carried well back", fly["moved"].z > 2.0, str(fly["moved"]))
	# up off his face at the get-up's own pace, near enough (the user's word,
	# 2026-10-09): longer than off his back
	_check("thrown, up again inside 5.5 s", fly["up_in"] < 5.5, "%.2f s" % fly["up_in"])
	var light := await _fell(Vector3(0, 0, -2), 3.0)
	_check("a light one: only dropped (the light fall)", light["tier"] == 0, str(light))

	var left := await _fell(Vector3(-2, 0, 0), 60.0)
	_check("heavy from his left: thrown over to his right", left["kind"] == SkinnedRig.Fall.LEFT and left["moved"].x > 0.4, str(left))
	_check("and up by the throw's own getting up (no clip laid on: no jump)", left["up"] == &"own", str(left["up"]))
	var right := await _fell(Vector3(2, 0, 0), 60.0)
	_check("heavy from his right: thrown over to his left", right["kind"] == SkinnedRig.Fall.RIGHT and right["moved"].x < -0.4, str(right))
	var side_light := await _fell(Vector3(2, 0, 0), 12.0)
	_check("lighter from a side: over backwards or forwards, never folded to the side",
			side_light["kind"] == SkinnedRig.Fall.BACK or side_light["kind"] == SkinnedRig.Fall.FORWARD, str(side_light))
	var back := await _fell(Vector3(0, 0, 2), 12.0)
	_check("from behind: onto his face, forward", back["kind"] == SkinnedRig.Fall.FORWARD and back["moved"].z < -0.4
			and not back["on_back"], str(back))
	_check("face down: up off his face with a clip of its own", back["up"] != &"", str(back["up"]))
	var crush := await _fell(Vector3(0, 0, -2), 60.0, &"crush")
	_check("a heavy blow on his head: straight down onto his stomach", crush["kind"] == SkinnedRig.Fall.CRUSH
			and not crush["on_back"], str(crush))
	var crush_light := await _fell(Vector3(0, 0, -2), 12.0, &"crush")
	_check("a lighter one from above falls by its side (here thrown back)", crush_light["kind"] == SkinnedRig.Fall.BACK,
			str(crush_light))
	for got: Dictionary in [left, right, back, crush]:
		# off his face takes a little longer: a push up off the ground
		var most := 3.2 if got["on_back"] else 5.5
		_check("up again inside %.1f s (%s)" % [most, got["clip"]], got["up_in"] < most, "%.2f s" % got["up_in"])

	# the get-up begun where its pose is likest how he lies, blended in
	_check("the get-up begun from the pose likest how he lay", not (back.get("weighed", {}) as Dictionary).is_empty()
			and not (crush.get("weighed", {}) as Dictionary).is_empty(), str(back.get("weighed")))

	# the falls the user picked per blow (Player.BLOW_FALLS)
	var smash := await _fell(Vector3(0, 0, -2), 40.0, &"", Vector3.ZERO, false, &"smash")
	_check("the ogre's smash in front: onto his face, thrown the blow's way (10)", smash["number"] == 10
			and smash["moved"].z > 0.3, str(smash))
	var slam := await _fell(Vector3(0, 0, -2), 40.0, &"", Vector3.ZERO, false, &"leap_slam")
	_check("its leap slam: onto his face the way he faces, not turned (10)", slam["number"] == 10
			and slam["faced"] > 0.9 and slam["moved"].z < -0.3, str(slam))
	var cleave_back := await _fell(Vector3(0, 0, 2), 40.0, &"", Vector3.ZERO, false, &"cleave")
	_check("its cleave from behind: folded over to a side as he stands (16)", cleave_back["number"] == 16
			and cleave_back["faced"] < -0.9, str(cleave_back))
	var smash_side := await _fell(Vector3(-2, 0, 0), 40.0, &"", Vector3.ZERO, false, &"smash")
	_check("its smash from a side: forward onto his stomach as he stands (27)",
			smash_side["number"] == 27 and not smash_side["on_back"] and absf(smash_side["faced"]) < 0.2
			and smash_side["moved"].z < -0.3, str(smash_side))
	var heavy := await _fell(Vector3(0, 0, -2), 40.0, &"", Vector3.ZERO, false, &"heavy")
	_check("its great blow: on his knees and forward, his face to it (24)", heavy["number"] == 24
			and heavy["faced"] > 0.9 and heavy["moved"].z < 0.1, str(heavy))
	var sweep := await _fell(Vector3(0, 0, -2), 12.0, &"", Vector3.ZERO, false, &"sweep")
	_check("a string's close (sweep): thrown back flying (5)", sweep["number"] == 5, str(sweep))
	var pound := await _fell(Vector3(0, 0, -2), 40.0, &"ground", Vector3.ZERO, false, &"pound")
	_check("in the pound's ring: over backwards (14)", pound["number"] == 14 and pound["faced"] > 0.9
			and pound["on_back"], str(pound))
	var pounded := await _fell(Vector3(0, 0, -2), 40.0, &"ground", Vector3(0, -20, 4), false, &"pound")
	_check("...the club itself on him: flat on his face (10)", pounded["number"] == 10, str(pounded))
	var unnamed := await _fell(Vector3(0, 0, -2), 12.0, &"", Vector3.ZERO, false, &"kick")
	_check("a blow with no fall picked falls by its kind", unnamed["number"] == 0, str(unnamed))

	# the weapon's own sweep ([WeaponSweep.motion_on]): its way, its power, its pitch
	var across := await _fell(Vector3(0, 0, -2), 12.0, &"", Vector3(40, 0, 0))
	_check("struck in front by a sweep to his right: thrown over to his right",
			across["kind"] == SkinnedRig.Fall.LEFT and across["moved"].x > 0.4, str(across))
	var down := await _fell(Vector3(0, 0, -2), 12.0, &"", Vector3(0, -45, 6))
	_check("a blow coming down steeply: crushed down", down["kind"] == SkinnedRig.Fall.CRUSH, str(down))
	var rising := await _fell(Vector3(0, 0, -2), 12.0, &"", Vector3(0, 24, 5))
	_check("a blow rising under him: launched", rising["kind"] == SkinnedRig.Fall.FLY and rising["rose"] > 0.3, str(rising))
	var soft := await _fell(Vector3(-2, 0, 0), 12.0, &"", Vector3(5, 0, 0))
	var hard := await _fell(Vector3(-2, 0, 0), 12.0, &"", Vector3(45, 0, 0))
	_check("the harder the sweep, the further he is thrown", hard["moved"].x > soft["moved"].x + 0.5,
			"%.2f vs %.2f m" % [hard["moved"].x, soft["moved"].x])

	# a skill's blast (no weapon): thrown straight back, flat or through the air
	var blast := await _fell(Vector3(0, 0, -2), 12.0, &"", Vector3.ZERO, true)
	_check("a skill's blast: thrown back onto his back, no fold", blast["kind"] == SkinnedRig.Fall.BACK, str(blast))
	var big_blast := await _fell(Vector3(-2, 0, 0), 60.0, &"", Vector3.ZERO, true)
	_check("a heavy blast from a side: thrown back through the air from it", big_blast["kind"] == SkinnedRig.Fall.FLY
			and big_blast["moved"].x > 1.0, str(big_blast))

	# down on his knee, then a second blow
	_hero.global_position = Vector3(0, _hero.global_position.y, 0)
	await _wait(20)
	_hero.call(&"_crumple", 10.0, Vector3(0, 0, 1))
	await _wait(30)
	_check("down on his knee", rig.crumpled())
	_foe.global_position = _hero.global_position + Vector3(2, 0, 0)
	_serial += 1
	_hero.receive_blow(6.0, _foe, 0, 3, _serial)
	await _wait(3)
	_check("a blow on him kneeling throws him down, the way it went",
			_hero.state == Player.State.DOWNED and rig.last_fall.get("kind", -1) in [SkinnedRig.Fall.BACK, SkinnedRig.Fall.FORWARD],
			str(rig.last_fall))

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _fell(from: Vector3, damage: float, how: StringName = &"", sweep: Vector3 = Vector3.ZERO,
		magic: bool = false, named: StringName = &"") -> Dictionary:
	_hero.global_position = Vector3(0, _hero.global_position.y, 0)
	_hero.rotation.y = 0.0
	_hero.velocity = Vector3.ZERO
	await _wait(40)
	var p0 := _hero.global_position
	_foe.global_position = p0 + from
	_serial += 1
	if sweep != Vector3.ZERO:
		_hero.set_meta(&"blow_sweep", [sweep, Engine.get_physics_frames()])
	elif _hero.has_meta(&"blow_sweep"):
		_hero.remove_meta(&"blow_sweep")
	_foe.set(&"named", named)
	_hero.receive_blow(damage, _foe, 0, 1, _serial, magic, how)
	var to_foe := _foe.global_position - _hero.global_position
	to_foe.y = 0.0
	var faced := (-_hero.global_basis.z).dot(to_foe.normalized())
	var rig := _hero.rig as SkinnedRig
	var rose := 0.0
	var frames := 0
	var lay := Vector3.ZERO
	while _hero.state == Player.State.DOWNED and frames < 400:
		await physics_frame
		frames += 1
		rose = maxf(rose, _hero.global_position.y - p0.y)
		if not rig.is_down() or rig._role == SkinnedRig.Role.DOWN:
			lay = _hero.global_position - p0
	while frames < 400 and rig.is_down():
		await physics_frame
		frames += 1
	var got := rig.last_fall.duplicate()
	got["moved"] = lay
	got["rose"] = rose
	got["up_in"] = frames / 60.0
	got["faced"] = faced
	got["number"] = got.get("number", 0)
	got["on_back"] = got.get("on_back", false)
	got["up"] = got.get("up", &"")
	got["tier"] = got.get("tier", -1)
	return got
