extends SceneTree

## The imp: its size and body, its own clips, and the way it fights — circling
## rather than walking into the sword, two of a band at a time, leaping in and
## springing out, getting out of the way of a cut instead of blocking it, thrown
## by a cut the way the blade went, and dying by its own clip.
##
##     godot --path . --headless --script res://tests/imp_test.gd

var _failures := 0
var _struck: Array[float] = []


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.creature_think_distance = 0.0
	var player: Player = world.player()
	player.immortal = true
	player.struck.connect(func(damage: float, _blocked: bool) -> void: _struck.append(damage))
	var enemies := world.get_node("Enemies")

	var imps: Array[Imp] = []
	for node in enemies.get_children():
		if node is Imp:
			imps.append(node as Imp)
	_check("the imps are Imps", imps.size() == 20, "%d" % imps.size())
	for node in enemies.get_children():
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -50.0, 0.0)

	# --- Size and body -----------------------------------------------------------
	var imp := imps[0]
	imp.global_position = imp._home + Vector3.UP * 0.3
	await _wait(10)
	var top := _top(imp)
	_check("it stands about 2.1 m, hair and all", top > 2.0 and top < 2.25, "%.2f m" % top)
	var cap := (imp.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	_check("its collider is its size", absf(cap.height - imp.body_height * imp.visual_scale) < 0.05
			and absf(cap.radius - imp.body_radius * imp.visual_scale) < 0.02,
			"h %.2f r %.2f" % [cap.height, cap.radius])
	var missing := []
	for what: int in Imp.MOVES:
		if not imp._anim.has_clip((Imp.MOVES[what] as Array)[0]):
			missing.append((Imp.MOVES[what] as Array)[0])
	for clip in [imp.walk_clip, imp.idle_clip, &"IP_Run", &"IP_Strafe_L", &"IP_Strafe_R", &"IP_Back", &"IP_Death"]:
		if not imp._anim.has_clip(clip):
			missing.append(clip)
	_check("every clip it plays is in its own file", missing.is_empty(), str(missing))
	var blows_ok := true
	for what: int in Imp.STRIKES:
		var moments := imp._blow_moments(what)
		if moments.is_empty() or moments[0] <= 0.05 or moments[moments.size() - 1] >= imp._move_length(what):
			blows_ok = false
	_check("each attack's blows fall inside the move", blows_ok)

	# --- Roused, it circles rather than walking into the sword -------------------
	for other in imps:
		if other != imp:
			other.set_physics_process(false)
	imp.set_physics_process(true)
	imp.evade_chance = 0.0
	player.global_position = imp.camp_centre + Vector3(0.0, 0.3, 10.0)
	var circled := false
	var sideways := 0.0
	var closest_idle := INF
	var kinds := {}
	_struck.clear()
	var sprang := false
	var circling_for := 0
	for i in 60 * 14:
		await physics_frame
		circling_for = circling_for + 1 if imp._tactic == Imp.Tactic.CIRCLE and imp.act == Fighter.Act.NONE else 0
		if circling_for > 40:
			circled = true
			var to_him := (player.global_position - imp.global_position)
			to_him.y = 0.0
			var v := Vector3(imp.velocity.x, 0.0, imp.velocity.z)
			sideways = maxf(sideways, absf(v.dot(to_him.normalized().cross(Vector3.UP))))
			closest_idle = minf(closest_idle, to_him.length())
		if Imp.STRIKES.has(imp.act):
			kinds[imp.act] = true
		if imp.act == Imp.HOP or imp.act == Imp.BACKFLIP:
			sprang = true
	_check("roused, it circles him", circled)
	_check("sideways, round him", sideways > 1.2, "%.2f m/s" % sideways)
	_check("off the end of his sword once it is circling", closest_idle > 2.2, "%.2f m" % closest_idle)
	_check("it goes in and its blows land", _struck.size() >= 1, "%d" % _struck.size())
	_check("with more than one kind of blow", kinds.size() >= 2, str(kinds.keys()))
	_check("and springs back out after", sprang)

	# --- A leap comes down on him ---------------------------------------------------
	await _until_idle(imp)
	var landed_near := false
	var jumped := 0.0
	for attempt in 6:
		await _until_idle(imp)
		var spot := player.global_position + Vector3(0.0, 0.0, -5.0)
		imp.global_position = Vector3(spot.x, imp.global_position.y, spot.z)
		imp.velocity = Vector3.ZERO
		imp._quarry = player
		imp.mode = Fighter.Mode.FIGHT
		await physics_frame
		imp._strike_from(5.0)
		if imp.act != Imp.POUNCE and imp.act != Imp.FLIP:
			continue
		var start := imp.global_position
		var land := imp._blow_moments(imp.act)[0]
		while imp.act == Imp.POUNCE or imp.act == Imp.FLIP:
			player.velocity = Vector3.ZERO
			await physics_frame
			if imp._act_time >= land:
				break
		jumped = Vector2(imp.global_position.x - start.x, imp.global_position.z - start.z).length()
		var gap := imp._distance_to(player)
		landed_near = gap < 2.0
		print("  leap: carried %.2f m, lands %.2f m off him" % [jumped, gap])
		break
	_check("a leap carries it across the gap", jumped > 2.5, "%.2f m" % jumped)
	_check("and comes down on him", landed_near)

	# --- It gets out of the way of a cut -------------------------------------------
	await _until_idle(imp)
	imp._cooldown = 5.0
	imp.evade_chance = 1.0
	imp.stamina = imp.max_stamina
	var health_before := imp.health
	var from_here := imp.global_position
	var evaded := false
	await _swing_at(player, imp, false)
	for i in 40:
		await physics_frame
		evaded = evaded or Imp.EVADES.has(imp.act)
	_check("a cut at it and it gets out of the way", evaded)
	_check("and the evade carries it off", imp.global_position.distance_to(from_here) > 1.3,
			"%.2f m" % imp.global_position.distance_to(from_here))
	_check("the cut finds nothing", is_equal_approx(imp.health, health_before),
			"%.0f -> %.0f" % [health_before, imp.health])
	_check("it never raises a guard", imp.block_chance == 0.0)

	# --- Cut, it is thrown the way the blade went --------------------------------
	await _until_idle(imp)
	imp.evade_chance = 0.0
	imp._cooldown = 5.0
	var hit_kind := -1
	var thrown := 0.0
	for attempt in 4:
		await _until_idle(imp)
		imp._cooldown = 5.0
		var before := imp.global_position
		var h := imp.health
		await _swing_at(player, imp, false)
		for i in 30:
			await physics_frame
			if Imp.HITS.has(imp.act):
				hit_kind = imp.act
		if imp.health < h:
			thrown = imp.global_position.distance_to(before)
			break
	_check("a cut that lands stops it with a hit clip", hit_kind != -1, "act %d" % hit_kind)
	_check("and throws it back", thrown > 0.4, "%.2f m" % thrown)

	# --- Two of a band go in at a time ---------------------------------------------
	var band: Array[Imp] = []
	for other in imps:
		if other.band == imps[2].band:
			band.append(other)
	for other in imps.slice(2, 5):
		if not band.has(other):
			band.append(other)
	band = band.slice(0, 3)
	imp.set_physics_process(false)
	imp.global_position += Vector3(0.0, -50.0, 0.0)
	var centre := band[0].camp_centre
	for k in band.size():
		var f := band[k]
		f.band = band[0].band
		f.camp_centre = centre
		f._home = centre + Vector3(k * 2.0 - 2.0, 0.0, 0.0)
		f.global_position = f._home + Vector3.UP * 0.3
		f.evade_chance = 0.0
		f.set_physics_process(true)
	player.global_position = centre + Vector3(0.0, 0.3, 7.0)
	var most := 0
	var crowd := INF
	for i in 60 * 12:
		await physics_frame
		var going := 0
		for f in band:
			if Imp.STRIKES.has(f.act) or f._tactic == Imp.Tactic.ENGAGE:
				going += 1
		most = maxi(most, going)
		for a in band:
			for b in band:
				if a != b:
					crowd = minf(crowd, a.global_position.distance_to(b.global_position))
	_check("never more than two of a band at him at once", most <= Imp.PACK and most >= 1, "%d" % most)
	_check("they keep from standing in each other", crowd > 0.7, "%.2f m" % crowd)

	# --- It dies by its own clip, and goes ------------------------------------------
	var dying := band[0]
	for f in band.slice(1):
		f.set_physics_process(false)
		f.global_position += Vector3(0.0, -50.0, 0.0)
	await _until_idle(dying)
	dying._receive(9999.0, dying.global_position + Vector3.UP, Vector3.FORWARD, player)
	await _wait(5)
	_check("killed, it plays its death", dying.is_dead and dying._anim.current_clip() == &"IP_Death")
	var gone := false
	for i in 60 * 8:
		await physics_frame
		if not is_instance_valid(dying):
			gone = true
			break
	_check("and its body is cleared away", gone)

	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


func _top(f: Node3D) -> float:
	var top := 0.0
	for m in f.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.get_parent() is HealthBar or mesh.get_parent().get_parent() is HealthBar:
			continue
		var here := f.global_transform.affine_inverse() * mesh.global_transform
		top = maxf(top, (here * mesh.get_aabb()).end.y)
	return top


func _swing_at(player: Player, f: Fighter, hold: bool = true) -> void:
	var spot := f.global_position
	player.global_position = spot + Vector3(0.0, 0.1, 1.6)
	player.velocity = Vector3.ZERO
	var aim := spot - player.global_position
	player.rotation.y = atan2(-aim.x, -aim.z)
	await physics_frame
	# his cut as the player throws it (the rig's attack() alone is only the
	# swing: the blade is the controller's, 2026-10-04)
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
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
