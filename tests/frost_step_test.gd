extends SceneTree

## The elf's Frost Step ([MageSkills]): she glides some eight metres ahead
## (not gone and out again: the user's word), freezing the ground as she goes; whatever crosses it is
## chilled ([Afflictions] "chill") and slowed for five seconds after. And her
## bolt (the user's word, 2026-10-07): a click no longer throws one at once,
## so they cannot be thrown as fast as arrows.
##
##     godot --path . --headless --script res://tests/frost_step_test.gd

const ARENA := "res://scenes/world/test_arena.tscn"
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	printerr("frost_step_test: start")
	root.get_node("Game").call(&"choose", &"elf_mage")
	var world: World = load(ARENA).instantiate()
	root.add_child(world)
	await _wait(30)
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	var hero := world.player()
	hero.immortal = true
	await _wait(30)
	var slot := -1
	for i in Player.SKILL_SLOTS:
		if hero.skill_in(i) == &"frost_step":
			slot = i
	_check("the elf has the Frost Step", slot >= 0)

	# Standing: back, away from what she faces, still facing it.
	var from := hero.global_position
	var ahead := -hero.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	_check("it goes", hero.use_skill(slot))
	await _wait(2)
	var moved := hero.global_position - from
	moved.y = 0.0
	_check("not there at once: she glides", moved.length() < 1.5, "%.2f m" % moved.length())
	await _wait(14)
	moved = hero.global_position - from
	moved.y = 0.0
	_check("half way along a quarter second in", moved.length() > 2.0 and moved.length() < 7.0,
			"%.2f m" % moved.length())
	await _wait(40)
	moved = hero.global_position - from
	moved.y = 0.0
	_check("and some eight metres on, straight back",
			moved.length() > 6.0 and moved.length() <= MageSkills.STEP_REACH + 0.6
			and moved.normalized().dot(-ahead) > 0.95, "%.2f m" % moved.length())
	var facing := -hero.global_basis.z
	facing.y = 0.0
	_check("still facing the way she was", facing.normalized().dot(ahead) > 0.95)
	_check("and done gliding", not hero.mage().gliding())
	var trail: FrostTrail = null
	for n in world.find_children("*", "FrostTrail", true, false):
		trail = n as FrostTrail
	_check("a strip of frost is left between", trail != null)
	_check("not again before its cooldown", not hero.use_skill(slot))

	# A creature on the frost is chilled; off it, it stays so for five seconds.
	var mid := from.lerp(hero.global_position, 0.5)
	var foe := panel.call_up("res://scenes/enemies/pack/ogre.tscn", false, mid + ahead.cross(Vector3.UP) * 9.0)
	await _wait(10)
	panel._hold(foe, true)
	foe.global_position = mid
	await _wait(20)
	var marks := Afflictions.of(foe, false)
	_check("what stands on the frost is chilled", marks != null and marks.is_chilled())
	foe.global_position = mid + ahead.cross(Vector3.UP) * 9.0
	await _wait(60 * 4)
	marks = Afflictions.of(foe, false)
	_check("and still is four seconds after leaving it", marks != null and marks.is_chilled())
	await _wait(80)
	marks = Afflictions.of(foe, false)
	_check("and not after five and a bit", marks == null or not marks.is_chilled())
	foe.queue_free()

	# Chilled, a body goes at the chill's pace (her own, running).
	var free_pace := await _pace(hero)
	Afflictions.of(hero).apply(&"chill", 3.0)
	var cold_pace := await _pace(hero)
	_check("chilled, she runs at %.0f %% of her pace" % (Afflictions.CHILL_SPEED * 100.0),
			absf(cold_pace / free_pace - Afflictions.CHILL_SPEED) < 0.08,
			"%.2f vs %.2f m/s" % [cold_pace, free_pace])
	await _wait(200)

	# Pushed some way: she glides that way, facing it.
	await _wait(60 * 4)
	Input.action_press("move_right")
	await _wait(3)
	var want := hero.get_movement_direction()
	var at := hero.global_position
	_check("it goes again, pushed to the side", hero.use_skill(slot))
	Input.action_release("move_right")
	await _wait(50)
	var went := hero.global_position - at
	went.y = 0.0
	var look := -hero.global_basis.z
	look.y = 0.0
	_check("pushed, she glides the way she is pushed, facing it",
			went.length() > 6.0 and went.normalized().dot(want) > 0.95 and look.normalized().dot(want) > 0.95,
			"%.2f m" % went.length())
	await _wait(60)

	# The bolt: a click let go at once is not thrown until it has gathered.
	var got: Array[float] = []
	var t0 := Time.get_ticks_msec()
	hero.arrow_loosed.connect(func(_p: float, _d: float, _c: bool) -> void:
		got.append((Time.get_ticks_msec() - t0) / 1000.0))
	for k in 48:
		Input.action_press("attack")
		await _wait(1)
		Input.action_release("attack")
		await _wait(4)
	await _wait(120)
	_check("a click is not thrown at once: it gathers %.2f s first" % hero.profile.min_draw,
			not got.is_empty() and got[0] >= hero.profile.min_draw - 0.05, str(got))
	var gaps := []
	for k in range(1, got.size()):
		gaps.append(got[k] - got[k - 1])
	var least := 99.0
	for g: float in gaps:
		least = minf(least, g)
	_check("clicking as fast as she can, no faster than one a second",
			got.size() >= 2 and least >= 0.95, "%d thrown, gaps %s" % [got.size(), str(gaps)])

	printerr("frost_step_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## How fast she gets over the ground running ahead for a second (m/s).
func _pace(hero: Player) -> float:
	Input.action_press("move_forward")
	await _wait(30)
	var a := hero.global_position
	await _wait(60)
	var b := hero.global_position
	Input.action_release("move_forward")
	await _wait(30)
	return Vector2(b.x - a.x, b.z - a.z).length()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	printerr("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
