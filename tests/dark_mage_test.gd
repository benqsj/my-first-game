extends SceneTree

## The dark elf mage's two skills ([DarkSkills], the user's word 2026-10-07):
## Dark Hands — a circle opens where she points and hands out of the ground
## hold what is in it ([ShadowHold]) and hurt it; Black Comets — a rift in
## the sky and six comets out of it, one where she pointed, the rest round it,
## each hurting what it falls near.
##
##     godot --path . --headless --script res://tests/dark_mage_test.gd

const ARENA := "res://scenes/world/test_arena.tscn"
const OGRE := "res://scenes/enemies/pack/ogre.tscn"
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	printerr("dark_mage_test: start")
	root.get_node("Game").call(&"choose", &"dark_mage")
	var world: World = load(ARENA).instantiate()
	root.add_child(world)
	await _wait(30)
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	var hero := world.player()
	hero.immortal = true
	await _wait(30)
	var grasp := -1
	var comets := -1
	for i in Player.SKILL_SLOTS:
		if hero.skill_in(i) == &"dark_grasp":
			grasp = i
		if hero.skill_in(i) == &"black_comets":
			comets = i
	_check("the dark elf mage has Dark Hands and Black Comets", grasp >= 0 and comets >= 0)
	hero.stamina = hero.max_stamina

	# Dark Hands on something ahead of her.
	var ahead := -hero.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var spot := hero.global_position + ahead * DarkSkills.AHEAD
	var foe := panel.call_up(OGRE, false, spot)
	await _wait(10)
	panel._hold(foe, true)
	foe.global_position = spot
	await _wait(5)
	var was := float(foe.get(&"health"))
	_check("it goes", hero.use_skill(grasp))
	await _wait(5)
	_check("a circle opens where she points", world.find_children("*", "ShadowGrasp", true, false).size() == 1)
	_check("nothing holds it yet", not ShadowHold.is_held(foe))
	await _wait(roundi(ShadowGrasp.WARN * 60.0) + 6)
	var hands := world.find_children("*", "ShadowHand", true, false).size()
	_check("hands come up out of the ground", hands >= ShadowGrasp.EMPTY + 2, "%d" % hands)
	_check("what is in it is held", ShadowHold.is_held(foe))
	_check("and hurt", float(foe.get(&"health")) < was, "%.0f -> %.0f" % [was, float(foe.get(&"health"))])
	# shoved, it does not go
	var held_at := foe.global_position
	foe.global_position += Vector3(0.8, 0.0, 0.0)
	await _wait(2)
	var off := foe.global_position - held_at
	off.y = 0.0
	_check("held, it cannot be moved over the ground", off.length() < 0.05, "%.2f m" % off.length())
	await _wait(roundi(ShadowGrasp.HOLD * 60.0) + 10)
	_check("let go after its time", not ShadowHold.is_held(foe))
	await _wait(90)
	_check("the hands are gone again", world.find_children("*", "ShadowHand", true, false).is_empty())
	_check("not again before its cooldown", not hero.use_skill(grasp))

	# Black Comets: one where she points, the rest round it.
	hero.stamina = hero.max_stamina
	var foes: Array[Node3D] = [foe]
	for k in 2:
		var side := ahead.cross(Vector3.UP) * (2.5 if k == 0 else -2.5)
		var f := panel.call_up(OGRE, false, spot + side)
		await _wait(5)
		panel._hold(f, true)
		f.global_position = spot + side
		foes.append(f)
	await _wait(10)
	var before: Array[float] = []
	for f in foes:
		before.append(float(f.get(&"health")))
	var seen: Dictionary = {}
	var aimed: Dictionary = {}
	var rifts := 0
	var locked := foes[1]
	hero.target = locked
	_check("Black Comets goes", hero.use_skill(comets))
	for t in 200:
		await physics_frame
		for c in world.find_children("*", "DarkComet", true, false):
			seen[c.get_instance_id()] = true
			if c.get(&"_quarry") == locked:
				aimed[c.get_instance_id()] = true
		rifts = maxi(rifts, world.find_children("*", "DarkRift", true, false).size())
	_check("a rift opens in the sky", rifts == 1)
	_check("six comets fall out of it", seen.size() == DarkSkills.COMETS, "%d" % seen.size())
	_check("two of them go at what she has locked", aimed.size() == DarkSkills.AIMED.size(), "%d" % aimed.size())
	var hurt := 0
	for i in foes.size():
		if is_instance_valid(foes[i]) and float(foes[i].get(&"health")) < before[i]:
			hurt += 1
	_check("they hurt what they fall near", hurt >= 2, "%d of %d" % [hurt, foes.size()])
	await _wait(60)
	_check("and are gone", world.find_children("*", "DarkComet", true, false).is_empty()
			and world.find_children("*", "DarkRift", true, false).is_empty())

	# Black Sun: what is round it is drawn in, then it bursts.
	var sun := -1
	for i in Player.SKILL_SLOTS:
		if hero.skill_in(i) == &"black_sun":
			sun = i
	_check("she has Black Sun", sun >= 0)
	for f in foes:
		if is_instance_valid(f):
			f.queue_free()
	await _wait(10)
	hero.target = null
	var centre := DarkSkills._ground(hero, hero.global_position + ahead * DarkSkills.AHEAD)
	var far := centre + ahead.cross(Vector3.UP) * 4.5
	var pulled := panel.call_up(OGRE, false, far)
	await _wait(10)
	pulled.global_position = far
	await _wait(5)
	hero.stamina = hero.max_stamina
	var hp := float(pulled.get(&"health"))
	_check("Black Sun goes", hero.use_skill(sun))
	await _wait(5)
	_check("a black sun hangs over where she points", world.find_children("*", "BlackSun", true, false).size() == 1)
	await _wait(roundi(BlackSun.PULL * 60.0) - 15)
	var gap := Vector2(pulled.global_position.x - centre.x, pulled.global_position.z - centre.z).length()
	_check("what is round it is drawn in", gap < 3.0, "%.2f m from it (was 4.5)" % gap)
	await _wait(40)
	_check("it has burst", world.find_children("*", "BlackSun", true, false).is_empty())
	_check("and hurt what it drew in", float(pulled.get(&"health")) < hp, "%.0f -> %.0f" % [hp, float(pulled.get(&"health"))])

	printerr("dark_mage_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	printerr("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
