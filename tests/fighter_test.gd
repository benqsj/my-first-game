extends SceneTree

## Imps and puglins: how many there are and where; that a band is roused
## together, that its blows land and only a whole combo floors him, that his
## sword reaches down to a puglin, that they die and are cleared away and let a
## man who runs off go. How each fights is `imp_test.gd` and `puglin_test.gd`.
##
##     godot --path . --headless --script res://tests/fighter_test.gd

var _failures := 0
var _struck: Array[float] = []


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.creature_think_distance = 0.0
	var player: Player = world.player()
	# The blows are what is being checked, not the dying.
	player.immortal = true
	player.struck.connect(func(damage: float, _blocked: bool) -> void: _struck.append(damage))
	var enemies := world.get_node("Enemies")

	# --- The bands ------------------------------------------------------------
	var imps: Array[Fighter] = []
	var puglins: Array[Fighter] = []
	var bands := {}
	for node in enemies.get_children():
		var f := node as Fighter
		if f == null:
			continue
		if f.name.begins_with("Imp"):
			imps.append(f)
		elif f.name.begins_with("Puglin"):
			puglins.append(f)
		bands[f.band] = int(bands.get(f.band, 0)) + 1
	_check("twenty imps", imps.size() == 20, "%d" % imps.size())
	_check("ten puglins", puglins.size() == 10, "%d" % puglins.size())
	var imp_sizes := []
	var pug_sizes := []
	for i in World.CAMPS.size():
		var n: int = bands.get(StringName("camp_%d" % i), 0)
		match World.CAMPS[i][0]:
			&"imp":
				imp_sizes.append(n)
			&"puglin":
				pug_sizes.append(n)
	_check("imp bands are 2, 2, 3, 3 ...", imp_sizes == [2, 2, 3, 3, 2, 2, 3, 3], str(imp_sizes))
	_check("puglin bands are 3, 3, 4", pug_sizes == [3, 3, 4], str(pug_sizes))
	var smallest := 99
	for size in imp_sizes + pug_sizes:
		smallest = mini(smallest, size)
	_check("no creature stands alone", smallest >= 2, "smallest band %d" % smallest)

	# Nothing stands inside a rock, a trunk or a wall, and there is ground under all.
	var space := world.get_world_3d().direct_space_state
	var buried := []
	var floating := []
	for f in imps + puglins:
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.3
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, f.global_position + Vector3.UP * 0.9)
		query.collision_mask = 1
		query.exclude = [f.get_rid()]
		var hits := space.intersect_shape(query, 4)
		if not hits.is_empty():
			buried.append("%s in %s" % [f.name, (hits[0]["collider"] as Node).name])
		var down := PhysicsRayQueryParameters3D.create(f.global_position + Vector3.UP,
				f.global_position + Vector3.DOWN * 3.0, 1)
		if space.intersect_ray(down).is_empty():
			floating.append(String(f.name))
	_check("no creature starts inside anything", buried.is_empty(), str(buried))
	_check("every creature has ground under it", floating.is_empty(), str(floating))

	# Everything else out of the way, so the fight below is one on one.
	for node in enemies.get_children():
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -50.0, 0.0)

	# --- Roused by a player, with its band --------------------------------------
	var pug: Fighter = puglins[0]
	var mate: Fighter = null
	for f in puglins:
		if f != pug and f.band == pug.band:
			mate = f
	for f in [pug, mate]:
		f.global_position = f._home + Vector3.UP * 0.3
		f.set_physics_process(true)
	player.global_position = pug.camp_centre + Vector3(0.0, 0.3, 9.0)
	await _wait(40)
	_check("a player in sight rouses it", pug.mode != Fighter.Mode.GUARD, "mode %d" % pug.mode)
	_check("and the rest of its band", mate.mode != Fighter.Mode.GUARD, "mode %d" % mate.mode)

	# --- Its blows land ------------------------------------------------------------
	_struck.clear()
	for i in 60 * 20:
		await physics_frame
		if not _struck.is_empty():
			break
	_check("the band's blows reach the player", not _struck.is_empty(), "%d" % _struck.size())
	for f in [pug, mate]:
		f.set_physics_process(false)
		f.global_position += Vector3(0.0, -50.0, 0.0)

	# --- Only a whole combo puts him down (his side of it) ------------------------
	player.state = Player.State.GROUNDED
	await _wait(60)
	var downed_early := false
	var downed := false
	for b in 3:
		player.receive_blow(8.0, pug, b, 3, 777)
		await _wait(3)
		if b < 2:
			downed_early = downed_early or player.state == Player.State.DOWNED
		downed = downed or player.state == Player.State.DOWNED
	_check("a single blow of a combo does not knock him down", not downed_early)
	_check("the last blow of a combo that landed whole knocks him down", downed, "state %d" % player.state)
	await _wait(50)
	var lying_at := player.global_position
	Input.action_press("move_forward")
	await _wait(30)
	Input.action_release("move_forward")
	_check("on the ground the stick does not move him",
			player.global_position.distance_to(lying_at) < 0.15,
			"%.2f m" % player.global_position.distance_to(lying_at))
	_check("and nothing hits him while he is down", player.is_invulnerable)
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	_check("a roll gets him straight up off the ground", player.state == Player.State.DASHING,
			"state %d" % player.state)
	await _wait(60)

	# A blow thrown into a roll finds nobody.
	_struck.clear()
	player.state = Player.State.DODGING
	player.receive_blow(8.0, pug, 0, 3, 999)
	await _wait(2)
	player.state = Player.State.GROUNDED
	_check("a blow thrown into a dodge does not land", _struck.is_empty())

	# --- Cut down, and cleared away ----------------------------------------------
	pug.global_position = pug._home + Vector3.UP * 0.3
	# Whatever it was doing when it was put aside (a ball takes no arrow) is over.
	pug._start(Fighter.Act.NONE)
	# Stood there to be cut: nothing of its own thrown back.
	pug.set(&"roll_every", Vector2(999.0, 999.0))
	pug.set(&"_next_roll", 999.0)
	Puglin._bands.erase(pug.band)
	pug.set(&"throw_range", Vector2.ZERO)
	pug.attack_cost = 9999.0
	pug.set_physics_process(true)
	await _wait(10)
	var before_arrow := pug.health
	pug.take_hit(10.0, pug.global_position + Vector3.UP, Vector3.FORWARD, false, true, player)
	_check("an arrow hurts it", pug.health < before_arrow)
	var first := pug.health
	for swing in 60:
		if pug.is_dead:
			break
		await _swing_at(player, pug)
		await _wait(20)
	_check("his sword reaches down to a puglin", pug.health < first, "%.0f -> %.0f" % [first, pug.health])
	_check("enough cuts kill a puglin", pug.is_dead, "health %.0f" % pug.health)
	_check("a dead puglin is out of the target list", not player._targetable(pug))
	var gone := false
	for i in 60 * 7:
		await physics_frame
		if not is_instance_valid(pug):
			gone = true
			break
	_check("and its body is cleared away", gone)

	# --- The imp is quick, the puglin hard to kill -----------------------------------
	var other := puglins[3]
	_check("the imp is the faster of the two", imps[1].chase_speed > other.chase_speed and imps[1].speed > other.speed)
	_check("the puglin takes more killing", other.max_health > imps[1].max_health and other.p_def > imps[1].p_def)

	# --- A player who runs off is let go ---------------------------------------
	other.global_position = other._home + Vector3.UP * 0.3
	other.set_physics_process(true)
	player.global_position = other.camp_centre + Vector3(0.0, 0.3, 6.0)
	await _wait(120)
	player.global_position = other.camp_centre + Vector3(0.0, 0.3, other.leash_radius + 15.0)
	await _wait(300)
	_check("past its ground it gives up and goes home", other.mode == Fighter.Mode.RETURN or other.mode == Fighter.Mode.GUARD,
			"mode %d" % other.mode)

	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


## Stands the knight at arm's length facing it and throws one cut, holding the
## creature in place for the swing unless it is meant to be free to dodge.
func _swing_at(player: Player, f: Fighter, hold: bool = true) -> void:
	var spot := f.global_position
	player.global_position = spot + Vector3(0.0, 0.1, 1.3)
	player.velocity = Vector3.ZERO
	var aim := spot - player.global_position
	player.rotation.y = atan2(-aim.x, -aim.z)
	await physics_frame
	player.rig.attack()
	for i in 20:
		if hold:
			f.global_position = Vector3(spot.x, f.global_position.y, spot.z)
			f.velocity = Vector3.ZERO
		await physics_frame


func _until_idle(f: Fighter) -> void:
	for i in 400:
		if f.act == Fighter.Act.NONE:
			return
		await physics_frame


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
