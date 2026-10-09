extends SceneTree
## Falls that follow the blow (the user's word, 2026-10-09; Tariel first):
## - felled from in front he is thrown back onto his back, and gets up off it;
## - a very heavy blow in front launches him: off the ground, carried back;
## - from his left he goes over to his right, from his right to his left;
## - from behind onto his face; a crushing blow brings him down where he is;
## - he lies only a moment: on his feet again in about 3 s at most, off his
##   back with LayToIdle/KipUp, off his face with Mixamo's get-ups;
## - down on his knee (a broken guard), a second blow throws him down.
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
	world.add_child(_foe)
	var rig := _hero.rig as SkinnedRig
	_check("Tariel's falls follow the blow", rig != null and rig.falls_directional())

	var front := await _fell(Vector3(0, 0, -2), 12.0)
	_check("in front: thrown back", front["kind"] == SkinnedRig.Fall.BACK and front["moved"].z > 0.3, str(front))
	_check("lying on his back, up off it with a clip", front["on_back"] and front["up"] != &"", str(front))
	_check("on his feet again inside 3 s", front["up_in"] < 3.0, "%.2f s" % front["up_in"])

	var fly := await _fell(Vector3(0, 0, -2), 40.0)
	_check("a very heavy one: launched", fly["kind"] == SkinnedRig.Fall.FLY and fly["rose"] > 0.4, str(fly))
	_check("and carried well back", fly["moved"].z > 2.0, str(fly["moved"]))
	_check("launched, up again inside 3.5 s", fly["up_in"] < 3.5, "%.2f s" % fly["up_in"])

	var left := await _fell(Vector3(-2, 0, 0), 12.0)
	_check("from his left: over to his right", left["kind"] == SkinnedRig.Fall.LEFT and left["moved"].x > 0.4, str(left))
	var right := await _fell(Vector3(2, 0, 0), 12.0)
	_check("from his right: over to his left", right["kind"] == SkinnedRig.Fall.RIGHT and right["moved"].x < -0.4, str(right))
	var back := await _fell(Vector3(0, 0, 2), 12.0)
	_check("from behind: onto his face, forward", back["kind"] == SkinnedRig.Fall.FORWARD and back["moved"].z < -0.4
			and not back["on_back"], str(back))
	_check("face down: up off his face with a clip of its own", back["up"] != &"", str(back["up"]))
	var crush := await _fell(Vector3(0, 0, -2), 20.0, &"crush")
	_check("crushed: down where he stands", crush["kind"] == SkinnedRig.Fall.CRUSH, str(crush))
	for got: Dictionary in [left, right, back, crush]:
		# off his face takes a little longer: a push up off the ground
		var most := 3.2 if got["on_back"] else 3.3
		_check("up again inside %.1f s (%s)" % [most, got["clip"]], got["up_in"] < most, "%.2f s" % got["up_in"])

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
			_hero.state == Player.State.DOWNED and rig.last_fall.get("kind", -1) == SkinnedRig.Fall.RIGHT,
			str(rig.last_fall))

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _fell(from: Vector3, damage: float, how: StringName = &"") -> Dictionary:
	_hero.global_position = Vector3(0, _hero.global_position.y, 0)
	_hero.rotation.y = 0.0
	_hero.velocity = Vector3.ZERO
	await _wait(40)
	var p0 := _hero.global_position
	_foe.global_position = p0 + from
	_serial += 1
	_hero.receive_blow(damage, _foe, 0, 1, _serial, false, how)
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
	got["on_back"] = got.get("on_back", false)
	got["up"] = got.get("up", &"")
	return got
