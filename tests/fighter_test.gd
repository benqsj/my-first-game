extends SceneTree

## Imps and puglins: how many there are and where, and that they block, dodge,
## break, attack, hit, go home and die.
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
	var imp := imps[0]
	var mate: Fighter = null
	for f in imps:
		if f != imp and f.band == imp.band:
			mate = f
	for f in [imp, mate]:
		f.global_position = f._home + Vector3.UP * 0.3
		f.set_physics_process(true)
	player.global_position = imp.camp_centre + Vector3(0.0, 0.3, 9.0)
	await _wait(40)
	_check("a player in sight rouses it", imp.mode != Fighter.Mode.GUARD, "mode %d" % imp.mode)
	_check("and the rest of its band", mate.mode != Fighter.Mode.GUARD, "mode %d" % mate.mode)
	mate.set_physics_process(false)
	mate.global_position += Vector3(0.0, -50.0, 0.0)

	# --- It attacks, and its blows land ------------------------------------------
	imp.block_chance = 0.0
	imp.dash_chance = 0.0
	_struck.clear()
	var attacked := false
	# Long enough for two combos: which blows it throws, and whether it opens
	# with one, is down to the dice (the global RNG, which any sound's pitch
	# also draws on), so one short combo is not a failure.
	for i in 900:
		await physics_frame
		attacked = attacked or imp.act == Fighter.Act.ATTACK
		if _struck.size() >= 2:
			break
	_check("it closes in and attacks", attacked)
	_check("the combo lands blows on the player", _struck.size() >= 2, "%d blows" % _struck.size())
	# Taken through the knight's p.def ([Defence]).
	_check("an imp's blow is worth what its scene says (40), through his p.def", not _struck.is_empty()
			and is_equal_approx(_struck[0], Defence.taken(imp.hit_damage, player.p_def)) and imp.hit_damage == 40.0,
			str(_struck))
	_check("the combo has several blows in it", imp._blows.size() >= 2, str(imp._blows))

	# --- Only a whole combo puts him down -----------------------------------------
	# The first blows of it were only flinches.
	_check("a single blow does not knock him down", _struck.size() < imp._blows.size()
			or player.state == Player.State.DOWNED, "%d of %d" % [_struck.size(), imp._blows.size()])
	var downed := false
	for i in 400:
		await physics_frame
		if player.state == Player.State.DOWNED:
			downed = true
			break
	_check("the last blow of a combo that landed whole knocks him down", downed,
			"%d blows landed of %d" % [_struck.size(), imp._blows.size()])
	# Lying there he goes nowhere, whatever the stick says.
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

	# A combo that is blocked part of the way through only ever flinches him.
	imp._cooldown = 0.0
	_struck.clear()
	var partial_down := false
	var attack_seen := false
	var guarding := false
	for i in 600:
		# Guard up (facing it) for the first blow only, then down for the rest.
		var aim := imp.global_position - player.global_position
		player.rotation.y = atan2(-aim.x, -aim.z)
		var want := imp.act == Fighter.Act.ATTACK and _struck.is_empty()
		if want != guarding:
			guarding = want
			if want:
				Input.action_press("block")
			else:
				Input.action_release("block")
		await physics_frame
		if player.state == Player.State.DOWNED:
			partial_down = true
		if imp.act == Fighter.Act.ATTACK:
			attack_seen = true
		if attack_seen and imp.act == Fighter.Act.NONE:
			break
	Input.action_release("block")
	_check("the first blow is caught on the shield", attack_seen and not _struck.is_empty(),
			"%d blows" % _struck.size())
	_check("a combo that was not taken whole never puts him down", not partial_down)

	# A blow thrown into a roll finds nobody.
	_struck.clear()
	player.state = Player.State.DODGING
	player.receive_blow(8.0, imp, 0, 3, 999)
	await _wait(2)
	player.state = Player.State.GROUNDED
	_check("a blow thrown into a dodge does not land", _struck.is_empty())
	_check("its guard is slow to come back", imp.stamina_regen <= 12.0 and imp.regen_delay >= 1.5)

	# --- Blocks a swing, and the guard costs stamina --------------------------------
	imp.block_chance = 1.0
	await _until_idle(imp)
	var health_before := imp.health
	var stamina_before := imp.stamina
	var blocked_seen := false
	var broke := false
	for swing in 8:
		await _swing_at(player, imp)
		blocked_seen = blocked_seen or imp.act == Fighter.Act.BLOCK
		for i in 30:
			await physics_frame
			blocked_seen = blocked_seen or imp.act == Fighter.Act.BLOCK
			broke = broke or imp.act == Fighter.Act.BREAK
		if broke:
			break
	_check("it raises its guard against a swing", blocked_seen)
	_check("cuts on the guard cost stamina, not health",
			imp.stamina < stamina_before, "stamina %.0f -> %.0f, health %.0f -> %.0f" % [
			stamina_before, imp.stamina, health_before, imp.health])
	_check("run out of stamina and the guard breaks", broke)
	var open_health := imp.health
	await _swing_at(player, imp)
	await _wait(25)
	_check("a broken guard lets the next cut in", imp.health < open_health,
			"%.0f -> %.0f" % [open_health, imp.health])

	# --- Dodges ----------------------------------------------------------------
	imp.block_chance = 0.0
	imp.dash_chance = 1.0
	imp.stamina = imp.max_stamina
	await _until_idle(imp)
	var dashed := false
	var from_here := imp.global_position
	await _swing_at(player, imp, false)
	for i in 30:
		await physics_frame
		dashed = dashed or imp.act == Fighter.Act.DASH
	_check("it throws itself aside from a swing", dashed)
	_check("and the dash moves it", imp.global_position.distance_to(from_here) > 1.0,
			"%.2f m" % imp.global_position.distance_to(from_here))

	# --- Arrows count --------------------------------------------------------
	imp.dash_chance = 0.0
	await _until_idle(imp)
	var before_arrow := imp.health
	imp.take_hit(10.0, imp.global_position + Vector3.UP, Vector3.FORWARD, false, true, player)
	_check("an arrow hurts it", imp.health < before_arrow)

	# --- It dies, and is cleared away ------------------------------------------
	for swing in 12:
		if imp.is_dead:
			break
		imp.stamina = 0.0
		await _swing_at(player, imp)
		await _wait(20)
	_check("enough cuts kill an imp", imp.is_dead, "health %.0f" % imp.health)
	_check("a dead imp is out of the target list", not player._targetable(imp))
	var gone := false
	for i in 60 * 7:
		await physics_frame
		if not is_instance_valid(imp):
			gone = true
			break
	_check("and its body is cleared away", gone)

	# --- The puglin hits harder, the imp is faster ---------------------------------
	var pug := puglins[0]
	pug.global_position = pug._home + Vector3.UP * 0.3
	pug.set_physics_process(true)
	pug.block_chance = 0.0
	pug.dash_chance = 0.0
	player.global_position = pug.camp_centre + Vector3(0.0, 0.3, 6.0)
	_struck.clear()
	for i in 600:
		await physics_frame
		if not _struck.is_empty():
			break
	_check("a puglin's blow lands", not _struck.is_empty())
	_check("and hits harder than an imp's", not _struck.is_empty() and _struck[0] > 8.0, str(_struck))
	_check("the imp is the faster of the two", imps[1].chase_speed > pug.chase_speed and imps[1].speed > pug.speed)
	_check("the puglin takes more killing", pug.max_health > imps[1].max_health)

	# --- A player who runs off is let go ---------------------------------------
	player.global_position = pug.camp_centre + Vector3(0.0, 0.3, 60.0)
	await _wait(240)
	_check("past its ground it gives up and goes home", pug.mode == Fighter.Mode.RETURN or pug.mode == Fighter.Mode.GUARD,
			"mode %d" % pug.mode)

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
