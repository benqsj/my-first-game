extends SceneTree
## The guard broken (the user's idea, 2026-10-04): a heavy blow on the shield
## taken with little stamina left beats the guard aside —
## - a heavy blow with the stamina full, or a light one with little left, is
##   only blocked;
## - a heavy one with little left: the blow lands whole, the stamina is gone,
##   he goes down on one knee (WR_Death, held), the view is thrown hard;
## - while he is down no guard can be raised and a second blow lands too; then
##   he gets up and can block again.
##   Godot --headless --path . --script res://tests/guard_break_test.gd

var _failures := 0
var _hero: Player
var _foe: Node3D
var _struck: Array = []


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
	_hero.struck.connect(func(d: float, b: bool) -> void: _struck.append([d, b]))
	await _wait(40)
	var rig := _hero.rig as SkinnedRig
	_check("the fall to one knee is on his mannequin", rig._anim.has_animation(SkinnedRig.CRUMPLE))
	_foe = Node3D.new()
	_foe.name = "Foe"
	world.add_child(_foe)

	var full_heavy := await _blow(1.0, 30.0)
	_check("a heavy blow, the stamina full: only blocked", full_heavy["blocked"] and not full_heavy["crumpled"],
			str(full_heavy))
	var low_light := await _blow(0.2, 4.0)
	_check("a light blow, little stamina left: only blocked", low_light["blocked"] and not low_light["crumpled"],
			str(low_light))
	var low_heavy := await _blow(0.2, 30.0, true)
	print("  broken ", low_heavy)
	_check("a heavy blow, little stamina left: the guard broken, the blow lands",
			not low_heavy["blocked"] and low_heavy["landed"] >= 20.0, "%.1f landed" % low_heavy["landed"])
	_check("the stamina gone", low_heavy["stamina"] == 0.0)
	_check("down on one knee", low_heavy["crumpled"] and low_heavy["clip"] == String(SkinnedRig.CRUMPLE), low_heavy["clip"])
	_check("the view thrown hard", low_heavy["view"])
	_check("heard and seen on every peer", low_heavy["felt"])
	_check("held on his knee, not fallen flat", low_heavy["held"] and low_heavy["frozen"],
			"%.2f s into the clip" % low_heavy["at"])
	_check("no guard while he is down", not low_heavy["guard_up"])
	_check("a second blow lands while he is down", low_heavy["second"], str(low_heavy["after"]))
	_check("and he stays down", low_heavy["still_down"])
	_check("he gets up and can block again", low_heavy["up_again"])

	Input.action_release("block")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


## A blow of `damage` from in front onto his raised shield, `share` of his
## stamina left. With `follow`, what comes after a broken guard.
func _blow(share: float, damage: float, follow: bool = false) -> Dictionary:
	Input.action_release("block")
	await _wait(150)
	_hero.velocity = Vector3.ZERO
	_hero.health = _hero.max_health
	Input.action_press("block")
	await _wait(40)
	_hero.stamina = _hero.max_stamina * share
	_hero._winded = false
	_foe.global_position = _hero.global_position - _hero.global_basis.z * 1.5
	var cam := _hero.camera
	if cam != null and cam.has_meta(&"nudge"):
		cam.remove_meta(&"nudge")
	_hero.last_guard_break = {}
	_struck.clear()
	var away := _hero.global_position - _foe.global_position
	away.y = 0.0
	_hero.net_blow(damage, away.normalized(), _foe.global_position, "%s#%d" % [_foe.get_path(), randi()], 0, 3)
	var rig := _hero.rig as SkinnedRig
	var got := {"blocked": _struck.size() > 0 and bool(_struck[0][1]),
			"landed": float(_struck[0][0]) if _struck.size() > 0 and not bool(_struck[0][1]) else 0.0,
			"stamina": _hero.stamina, "crumpled": rig.crumpled(), "clip": String(rig._anim.current_animation),
			"view": cam != null and cam.has_meta(&"nudge"), "felt": not _hero.last_guard_break.is_empty()}
	if not follow:
		return got
	# down on his knee: the clip stopped there, not fallen on
	await _wait(80)
	got["held"] = rig.crumpled()
	got["at"] = rig._anim.current_animation_position
	got["frozen"] = absf(rig._anim.current_animation_position - SkinnedRig.CRUMPLE_KNEE) < 0.12 \
			and rig._anim.speed_scale == 0.0
	got["guard_up"] = _hero.is_blocking
	_struck.clear()
	_hero.net_blow(6.0, away.normalized(), _foe.global_position, "%s#%d" % [_foe.get_path(), randi()], 0, 3)
	got["after"] = _struck.duplicate()
	got["second"] = _struck.size() > 0 and not bool(_struck[0][1])
	await _wait(5)
	got["still_down"] = rig.crumpled()
	await _wait(int(_hero.guard_crumple_time * 60.0) + 40)
	got["up_again"] = not rig.crumpled() and _hero.is_blocking
	return got
