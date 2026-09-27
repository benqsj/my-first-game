extends SceneTree

## The assassin's knife goes where the thing he cuts is: turned to it, stepped
## in to it, bent down to something short or lying on the ground — and his
## string of blows lands on a puglin standing a pace and a half off, which the
## sword combo's chest-high cuts used to go over.
##
##     godot --path . --headless --script res://tests/rogue_strike_test.gd

var _failures := 0


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"rogue")
	var world: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Player = world.call("player")
	player.immortal = true
	var land := Terrain.current
	var at := Vector3(6, 0, 36)
	at.y = land.height_at(at.x, at.z)
	player.global_position = at
	var foe: Node3D = null
	var wolf: Wolf = null
	for n in world.find_children("*", "CharacterBody3D", true, false):
		if foe == null and String(n.name).begins_with("Puglin"):
			foe = n
		elif wolf == null and n is Wolf:
			wolf = n
	for n in world.find_children("*", "CharacterBody3D", true, false):
		if n != player and n != foe and n != wolf:
			(n as Node3D).global_position += Vector3(0, -80, 0)
			n.set_physics_process(false)
	wolf.global_position += Vector3(0, -80, 0)
	wolf.set_physics_process(false)
	for i in 30:
		await physics_frame
	var rig := player.rig as SkinnedRig
	_check("his cuts are aimed", rig.strike_aim and rig._strike != null)
	_check("he stands square (DG_Stand)", rig.clips[&"idle"] == &"DG_Stand" and rig._anim.has_animation(&"DG_Stand"))

	# A puglin a pace and a half off, a little to one side of where he faces.
	var hold := at + Vector3(0.3, 0.05, -1.5)
	foe.global_position = hold
	var r: float = float(foe.get("body_radius")) * float(foe.get("visual_scale"))
	var h: float = float(foe.get("body_height")) * float(foe.get("visual_scale"))
	var reached := 0
	var turned := true
	var stepped := false
	var bent := 0.0
	for blow in rig.flurry.size():
		player.global_position = at
		player.velocity = Vector3.ZERO
		player.rotation.y = 0.5
		player._commit_timer = 0.0
		Input.action_press("attack")
		await physics_frame
		Input.action_release("attack")
		await physics_frame
		var to := hold - player.global_position
		to.y = 0.0
		turned = turned and (-player.global_transform.basis.z).dot(to.normalized()) > 0.95
		var best := INF
		for i in 26:
			await physics_frame
			foe.global_position = hold
			foe.set("velocity", Vector3.ZERO)
			stepped = stepped or player.global_position.distance_to(at) > 0.3
			bent = maxf(bent, rig._strike.weight)
			var e: PackedVector3Array = rig.get_cutting_edge()
			if e.is_empty():
				continue
			var near := Geometry3D.get_closest_points_between_segments(e[0], e[1],
					hold + Vector3.UP * r, hold + Vector3.UP * maxf(h - r, r))
			best = minf(best, near[0].distance_to(near[1]) - r)
		if best <= float(foe.get("hit_tolerance")):
			reached += 1
	_check("he turns to it for every blow", turned)
	_check("he steps in to it", stepped)
	_check("and bends down to it", bent > 0.9, "%.2f" % bent)
	_check("most of the string reaches it", reached >= rig.flurry.size() - 2,
			"%d of %d" % [reached, rig.flurry.size()])

	# A wolf down on its belly: the knife goes down to it.
	foe.global_position += Vector3(0, -80, 0)
	wolf.global_position = at + Vector3(0, 0.3, -1.6)
	wolf.set_physics_process(true)
	wolf.rig.detach("left leg")
	wolf.rig.detach("right leg")
	for i in 20:
		await physics_frame
	var lowest := INF
	player.global_position = at
	player._commit_timer = 0.0
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	for i in 26:
		await physics_frame
		var e: PackedVector3Array = rig.get_cutting_edge()
		if not e.is_empty():
			lowest = minf(lowest, minf(e[0].y, e[1].y) - at.y)
	_check("the knife goes down to a wolf on the ground", lowest < 0.5, "%.2f m" % lowest)

	# The heavy blows, on the other button: which one is what the string has
	# come to, and the ones that cut more than once cut more than once.
	wolf.global_position += Vector3(0, -80, 0)
	wolf.set_physics_process(false)
	foe.global_position = hold
	# Long enough after the last cut that the string has started again.
	for i in 80:
		await physics_frame
	await _press(player, "block")
	_check("out of nothing the heavy is the lunge", rig._act_clip == &"DG_Thrust_Slash" and rig.is_heavy(),
			String(rig._act_clip))
	var serial: int = rig.attack_serial
	for i in 70:
		await physics_frame
		foe.global_position = hold
	_check("and it cuts twice", rig.attack_serial == serial + 1, "%d" % (rig.attack_serial - serial))
	await _idle(player)
	await _press(player, "attack")
	await _idle(player)
	await _press(player, "block")
	_check("early in the string it is the spinning leap", rig._act_clip == &"DG_Spin_Flip_Kick",
			String(rig._act_clip))
	await _idle(player)
	for k in 5:
		await _press(player, "attack")
		await _idle(player)
	await _press(player, "block")
	_check("at the end of it the whirling combo", rig._act_clip == &"DG_Dual_Combo", String(rig._act_clip))
	await _idle(player)
	# A light cut's follow-through can be broken off by an evade; a heavy blow's cannot.
	await _press(player, "attack")
	var broke := false
	for i in 40:
		await physics_frame
		if rig.in_recovery():
			Input.action_press("dash")
			await physics_frame
			Input.action_release("dash")
			await physics_frame
			broke = player.state == Player.State.DASHING or player.state == Player.State.DODGING
			break
	_check("an evade breaks off a light cut's follow-through", broke)

	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


func _press(player: Player, action: String) -> void:
	player.stamina = player.max_stamina
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)
	await physics_frame


func _idle(player: Player) -> void:
	for i in 180:
		if not player.is_committed() and player.state == Player.State.GROUNDED:
			break
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
