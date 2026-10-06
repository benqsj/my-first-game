extends SceneTree

## The elf's Frost Spears ([MageSkills]): ten spears grow over her, go one
## after another at what she has locked and hurt it; with nothing to throw at
## they wait and then break; the skill waits out its cooldown.
##
##     godot --path . --headless --script res://tests/frost_spears_test.gd

const ARENA := "res://scenes/world/test_arena.tscn"
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Game").call(&"choose", &"elf_mage")
	var world: World = load(ARENA).instantiate()
	root.add_child(world)
	await _wait(30)
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	var hero := world.player()
	hero.immortal = true
	await _wait(30)
	_check("the elf has the Frost Spears in her first slot", hero.skill_in(0) == &"frost_spears", str(hero.skill_in(0)))

	# Nothing to throw at: they grow, wait, and break.
	_check("it goes", hero.use_skill(0))
	var most := 0
	var fastest := 0.0
	var legs := true
	Input.action_press("move_forward")
	for i in 100:
		await physics_frame
		most = maxi(most, _shown(hero))
		if i > 15 and i < 60:
			fastest = maxf(fastest, Vector2(hero.velocity.x, hero.velocity.z).length())
			legs = legs and bool(hero.rig.get(&"walk_under"))
	Input.action_release("move_forward")
	_check("moving as she raises her hand she walks, legs walking (no sliding)",
			fastest <= hero.walk_speed + 0.2 and fastest > 0.5 and legs,
			"%.2f m/s (walk %.2f), legs %s" % [fastest, hero.walk_speed, legs])
	_check("ten spears grow over her", most == MageSkills.SPEARS, "%d" % most)
	_check("she is not held while they hang", not hero.is_committed())
	_check("not again before its cooldown", not hero.use_skill(0))
	var waited := 0
	while hero.mage().spears_up() and waited < 60 * 10:
		await physics_frame
		waited += 1
	_check("with nothing to throw at they break after a while", not hero.mage().spears_up()
			and waited / 60.0 > MageSkills.HOLD_MAX - 0.5, "%.1f s" % (waited / 60.0))

	# Something locked: all ten go at it, and hurt it.
	hero._skill_ready_at.clear()
	var fwd := -hero.global_basis.z
	fwd.y = 0.0
	var foe := panel.call_up("res://scenes/enemies/pack/ogre.tscn", false, hero.global_position + fwd.normalized() * 13.0)
	await _wait(20)
	panel._hold(foe, true)
	var hp0 := float(foe.get("health"))
	hero.call("_hold_target", foe)
	_check("it goes again", hero.use_skill(0))
	var times: Array[float] = []
	var left := MageSkills.SPEARS
	var crown_ok := true
	for i in 420:
		await physics_frame
		if i == 20:
			# her body turned aside (running round it): the crescent stays turned at it
			hero.rotation.y += PI * 0.5
		if i == 50 and hero.mage().spears_up():
			var to := foe.global_position - hero.global_position
			to.y = 0.0
			var ahead := -hero.mage()._crown.global_basis.z
			ahead.y = 0.0
			crown_ok = ahead.normalized().dot(to.normalized()) > 0.95
		var now := 0
		for s: Variant in hero.mage()._spears:
			if s != null and is_instance_valid(s):
				now += 1
		if not hero.mage().spears_up():
			now = 0
		while left > now:
			times.append(i / 60.0)
			left -= 1
	_check("locked, the crescent is turned at it, not as her body", crown_ok)
	var lost := hp0 - float(foe.get("health"))
	# three, a breath, three, a breath, three and a fourth on its heels
	var gaps: Array[float] = []
	for k in range(1, times.size()):
		gaps.append(times[k] - times[k - 1])
	_check("thrown in the rhythm: three, a breath, three, a breath, three and one on its heels",
			gaps.size() == 9 and gaps[0] < 0.3 and gaps[1] < 0.3 and gaps[2] > 0.4 and gaps[5] > 0.4
			and gaps[2] < 0.7 and gaps[8] < 0.18, str(gaps))
	_check("all ten thrown at it", not hero.mage().spears_up())
	_check("and they hurt it (at least seven landed)", lost > 7.0 * 8.0, "%.1f off %.1f" % [lost, hp0])
	print("frost_spears_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _shown(hero: Player) -> int:
	var n := 0
	for s: Variant in hero.mage()._spears:
		if s != null and is_instance_valid(s) and (s as Node3D).visible:
			n += 1
	return n


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
