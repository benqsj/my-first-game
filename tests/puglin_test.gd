extends SceneTree

## The puglin: small still, a band that walks as one, rolls at him as balls (all
## together, and again after a miss), that steel cannot get into, mud in his
## eyes, one three-cut combo, and a big blow that breaks the band up until it
## gathers again.
##
##     godot --path . --headless --script res://tests/puglin_test.gd

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
	var pugs: Array[Puglin] = []
	for node in enemies.get_children():
		if node is Puglin:
			pugs.append(node as Puglin)
	_check("the puglins are Puglins", pugs.size() == 10, "%d" % pugs.size())
	for node in enemies.get_children():
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -50.0, 0.0)

	# --- Still small, a sword in its fist, its own clips --------------------------
	var band: Array[Puglin] = []
	for p in pugs:
		if p.band == pugs[0].band:
			band.append(p)
	var one := band[0]
	one.global_position = one._home + Vector3.UP * 0.3
	await _wait(10)
	var top := _top(one)
	_check("it is as small as it was", top > 0.95 and top < 1.35, "%.2f m" % top)
	_check("a sword in its fist, not a stick", one.find_child("Puglin_Sword", true, false) != null
			and one.find_child("Puglin_Stick", true, false) == null)
	var missing := []
	for what: int in Puglin.MOVES:
		if not one._anim.has_clip((Puglin.MOVES[what] as Array)[0]):
			missing.append((Puglin.MOVES[what] as Array)[0])
	_check("every clip it plays is its own", missing.is_empty(), str(missing))
	var cuts := 0
	for what: int in Puglin.CUTS:
		cuts += one._blow_moments(what).size()
	_check("its combo is three cuts", cuts == 3 and (Puglin.STRIKES[Puglin.COMBO] as Array)[3] == 3, "%d" % cuts)
	_check("steel hardly gets in (p.def), fire does", Defence.taken(26.0, one.p_def) < 15.0 and one.m_def < 10.0)

	# --- The band walks as one --------------------------------------------------
	for p in band:
		p.global_position = p._home + Vector3.UP * 0.3
		p.set(&"roll_every", Vector2(999.0, 999.0))
		p.throw_range = Vector2.ZERO
		p.set_physics_process(true)
	Puglin._bands.clear()
	player.global_position = one.camp_centre + Vector3(0.0, 0.3, 11.0)
	var spread := 0.0
	var fastest := 0.0
	var last_c := Vector3.ZERO
	for i in 60 * 6:
		await physics_frame
		player.velocity = Vector3.ZERO
		if i < 180:
			continue
		for a in band:
			for b in band:
				spread = maxf(spread, a.global_position.distance_to(b.global_position))
		var c: Vector3 = Puglin._bands[one.band]["centre"]
		if last_c != Vector3.ZERO:
			fastest = maxf(fastest, Vector2(c.x - last_c.x, c.z - last_c.z).length() * 60.0)
		last_c = c
	_check("roused, the band keeps together", spread < 3.3, "%.2f m apart" % spread)
	_check("and comes on slowly", fastest <= one.bunch_speed + 0.05, "%.2f m/s" % fastest)
	var near_him := one.global_position.distance_to(player.global_position)
	_check("it stops short of him", near_him > 1.8 and near_him < 5.5, "%.2f m" % near_him)

	# --- They roll at him, all at once -------------------------------------------
	_struck.clear()
	var b0: Dictionary = Puglin._bands[one.band]
	b0["next_roll"] = 0.0
	player.global_position = Puglin._bands[one.band]["centre"] + Vector3(0.0, 0.3, 7.0)
	var all_rolling := false
	var spun := false
	var passes_again := false
	var was_turn := {}
	var dizzy := false
	var steel_in := false
	var fire_in := false
	var most_rolling := 0
	var knocked_out := false
	for i in 60 * 10:
		await physics_frame
		player.velocity = Vector3.ZERO
		var rolling := 0
		for p in band:
			if p.act == Puglin.ROLL:
				rolling += 1
				if not p.body.transform.basis.is_equal_approx(p._body_basis):
					spun = true
				if p._roll_phase == Puglin.Roll.TURN:
					was_turn[p] = true
				elif was_turn.has(p):
					passes_again = true
			if p.act == Puglin.DIZZY:
				dizzy = true
		all_rolling = all_rolling or rolling == band.size()
		most_rolling = maxi(most_rolling, rolling)
		if i == 5:
			print("  acts at the volley: ", band.map(func(p: Puglin) -> int: return p.act), " band ", band.size())
		if all_rolling and rolling > 0 and not fire_in:
			var p: Puglin = band[0] if band[0].act == Puglin.ROLL else band[band.size() - 1]
			if p.act == Puglin.ROLL:
				var h := p.health
				p._receive(26.0, p.global_position, Vector3.FORWARD, player)
				steel_in = p.health < h
				p._receive(10.0, p.global_position, Vector3.FORWARD, player, true)
				fire_in = p.health < h
				knocked_out = p.act != Puglin.ROLL
		if dizzy and all_rolling and i > 300:
			break
	_check("the whole band curls up and rolls at once", all_rolling, "at most %d of %d" % [most_rolling, band.size()])
	_check("each a ball, turning over as it goes", spun)
	_check("the balls find him", not _struck.is_empty(), "%d" % _struck.size())
	_check("a ball that is past him swings round and comes again", passes_again)
	_check("steel cannot get into a ball", not steel_in)
	_check("magic can, and knocks it out of its ball", fire_in and knocked_out)
	_check("uncurled it stands dizzy a moment", dizzy)

	# --- A big blow breaks the band up, and it gathers again ------------------------
	for p in band:
		await _until_idle(p)
	player.state = Player.State.GROUNDED
	for p in band:
		p.scatter_time = Vector2(2.0, 2.0)
	var b1: Dictionary = Puglin._bands[one.band]
	b1["state"] = Puglin.Band.GATHER
	await _wait(10)
	one._receive(60.0, one.global_position + Vector3.UP * 0.5, Vector3.FORWARD, player)
	var hopped := 0
	for i in 20:
		await physics_frame
		for p in band:
			if p.act == Puglin.HOP:
				hopped += 1
	_check("a big blow breaks the band up", int(b1["state"]) == Puglin.Band.SCATTER)
	_check("they hop off every way", hopped >= band.size(), "%d" % hopped)
	var gathered := false
	for i in 60 * 14:
		await physics_frame
		if int(b1["state"]) == Puglin.Band.GATHER:
			gathered = true
			break
	_check("and they gather again after", gathered, "state %d" % int(b1["state"]))
	# Two of them in one swing does the same.
	await _wait(30)
	b1["state"] = Puglin.Band.GATHER
	band[0]._receive(10.0, band[0].global_position, Vector3.FORWARD, player)
	band[1]._receive(10.0, band[1].global_position, Vector3.FORWARD, player)
	_check("one swing through two of them breaks them up too", int(b1["state"]) == Puglin.Band.SCATTER)

	# --- Mud in his eyes ------------------------------------------------------------
	for p in band:
		p.set_physics_process(false)
		p.global_position += Vector3(0.0, -50.0, 0.0)
	var thrower := band[0]
	thrower.global_position = thrower._home + Vector3.UP * 0.3
	thrower.set_physics_process(true)
	thrower.throw_range = Vector2(4.5, 13.0)
	thrower._next_throw = 0.0
	Puglin._bands.erase(thrower.band)
	thrower.band = &"alone_for_the_test"
	player.global_position = thrower.global_position + Vector3(0.0, 0.3, 8.0)
	player.state = Player.State.GROUNDED
	_struck.clear()
	var threw := false
	var held := false
	var flying := false
	var mudded := 0.0
	for i in 60 * 6:
		await physics_frame
		player.velocity = Vector3.ZERO
		threw = threw or thrower.act == Puglin.THROW
		if thrower.act == Puglin.THROW and thrower._throw_clock > 0.2 and thrower._throw_clock < thrower._throw_at:
			held = held or (thrower._held != null and thrower._held.visible)
		if not world.find_children("*", "MudBall", true, false).is_empty():
			flying = true
		mudded = maxf(mudded, ScreenMud.cover(self))
		if mudded > 0.02:
			# One lump is enough: no more thrown while it dries.
			thrower.throw_range = Vector2.ZERO
	_check("from off he throws mud at him", threw)
	_check("the lump is seen in its fist before it goes", held)
	_check("and in the air on its way", flying)
	_check("the mud hits him", not _struck.is_empty(), "%d" % _struck.size())
	_check("and gets well into his eyes", mudded > 0.2, "%.3f" % mudded)
	await _wait(60 * 8)
	_check("which clears after a few seconds", ScreenMud.cover(self) < 0.001, "%.3f" % ScreenMud.cover(self))

	# --- One combo, three cuts, all three floor him ---------------------------------
	thrower.throw_range = Vector2.ZERO
	await _until_idle(thrower)
	thrower._cooldown = 0.0
	thrower.stamina = thrower.max_stamina
	player.global_position = thrower.global_position + Vector3(0.0, 0.3, 1.2)
	player.state = Player.State.GROUNDED
	await _wait(10)
	_struck.clear()
	var combo := false
	var down := false
	var landed_at := []
	var n_struck := 0
	for i in 60 * 5:
		await physics_frame
		player.velocity = Vector3.ZERO
		combo = combo or Puglin.CUTS.has(thrower.act)
		if Puglin.CUTS.has(thrower.act) and _struck.size() != n_struck:
			n_struck = _struck.size()
			landed_at.append(snappedf(thrower._act_time, 0.01))
		down = down or player.state == Player.State.DOWNED
		if down:
			break
	_check("close in it cuts at him", combo)
	_check("its three cuts land and floor him", down, "%d cuts landed, at %s" % [_struck.size(), landed_at])

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


func _until_idle(f: Fighter) -> void:
	for i in 600:
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
