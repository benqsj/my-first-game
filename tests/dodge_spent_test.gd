extends SceneTree
## A dodge spent out (the user's rule, 2026-10-04): the last of his stamina
## spent on an evade, and a heavy blow lands just after it (he came out of it
## too early) — he goes down on one knee as when his guard breaks, the blow
## landing whole. Otherwise:
## - with stamina left after the evade: only a blow that lands (a flinch);
## - a light blow: only a flinch;
## - a blow inside the evade: it goes through empty air, as ever;
## - a heavy blow long after the evade: only a flinch.
##   Godot --headless --path . --script res://tests/dodge_spent_test.gd

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
	_foe = Node3D.new()
	_foe.name = "Foe"
	world.add_child(_foe)

	var spent := await _try(true, 30.0, 6)
	print("  spent ", spent)
	_check("the last stamina on a dodge, a heavy blow just after: down on one knee", spent["crumpled"], str(spent))
	_check("the blow lands whole", spent["landed"] >= 20.0, "%.1f" % spent["landed"])
	_check("no shield in it (no guard-break sounds)", spent["felt"] and not spent["shield"])
	var breath := await _try(false, 30.0, 6)
	_check("stamina left after the dodge: only a flinch", not breath["crumpled"] and breath["landed"] > 0.0, str(breath))
	var light := await _try(true, 4.0, 6)
	_check("a light blow: only a flinch", not light["crumpled"] and light["landed"] > 0.0, str(light))
	var inside := await _try(true, 30.0, -1)
	_check("a blow inside the dodge goes through empty air", not inside["crumpled"] and inside["landed"] == 0.0, str(inside))
	var late := await _try(true, 30.0, 90)
	_check("a heavy blow long after the dodge: only a flinch", not late["crumpled"] and late["landed"] > 0.0, str(late))
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


## An evade on the last of his stamina (`last`) or with plenty, then a blow of
## `damage` `after` frames after it ends (-1: while it is still going).
func _try(last: bool, damage: float, after: int) -> Dictionary:
	await _wait(200)
	var rig := _hero.rig as SkinnedRig
	_hero.velocity = Vector3.ZERO
	_hero.health = _hero.max_health
	var cost: float = _hero.profile.roll_stamina if _hero.profile != null else 20.0
	_hero.stamina = cost * 0.9 if last else _hero.max_stamina
	_hero._winded = false
	_hero.call(&"_press_dash")
	await _wait(2)
	var evading := _hero.state == Player.State.DASHING or _hero.state == Player.State.DODGING
	if after >= 0:
		for i in 240:
			if _hero.state != Player.State.DASHING and _hero.state != Player.State.DODGING:
				break
			await physics_frame
		await _wait(after)
	_foe.global_position = _hero.global_position - _hero.global_basis.z * 1.5
	_hero.last_guard_break = {}
	_struck.clear()
	var away := _hero.global_position - _foe.global_position
	away.y = 0.0
	_hero.net_blow(damage, away.normalized(), _foe.global_position, "%s#%d" % [_foe.get_path(), randi()], 0, 3)
	var got := {"evaded": evading, "winded": _hero._winded, "crumpled": rig.crumpled(),
			"landed": float(_struck[0][0]) if _struck.size() > 0 and not bool(_struck[0][1]) else 0.0,
			"felt": not _hero.last_guard_break.is_empty(), "shield": _hero.last_guard_break.get("shield", true)}
	return got
