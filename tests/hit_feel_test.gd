extends SceneTree
## The blade going in, felt by both ([HitFeel]), and the body leant into its
## run (`Player._lean`):
## - the hold grows with the blow: the dash's cut least, a light cut, the end
##   of a string and a heavy blow more;
## - Tariel's cut landing on an orc holds his swing and the orc's clips for the
##   same beat, he does not glide on meanwhile, and the orc is lit, then all
##   of it is let go;
## - running round in a circle he leans in; standing he is upright again.
##   Godot --headless --path . --script res://tests/hit_feel_test.gd
var _failures := 0
var player: Player
var rig: SkinnedRig


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _lit(node: Node) -> int:
	var n := 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_overlay as ShaderMaterial
		if m != null and m.shader != null and m.shader.code == HitFeel.SHADER:
			n += 1
	return n


func _dust(world: Node) -> int:
	var n := 0
	for c in world.find_children("*", "", true, false):
		if c is DustRing:
			n += 1
	return n


func _held(node: Node) -> int:
	return 1 if HitFeel.is_held(node) else 0


func _initialize() -> void:
	var dash := HitFeel.stop_for(0.6)
	var light := HitFeel.stop_for(1.0)
	var last := HitFeel.stop_for(1.35)
	var heavy := HitFeel.stop_for(1.8)
	_check("the hold grows with the blow", dash < light and light < last and last < heavy and heavy <= HitFeel.MAX_STOP,
			"(%.3f %.3f %.3f %.3f)" % [dash, light, last, heavy])

	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _frames(2)
	player = world.player()
	player.immortal = true
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	rig = player.rig as SkinnedRig
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	player.camera_rig.rotation.y = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(30)

	# --- an arrow in him rides the body you see, not the old hidden skeleton ---
	var skels := Arrow._shown_skeletons(player)
	var old_skel: Variant = rig._own.get("skel") if rig._own != null else null
	_check("arrows ride a shown skeleton", not skels.is_empty() and not skels.has(old_skel),
			"(%s)" % [skels.map(func(k: Skeleton3D) -> String: return "%s/%d bones" % [k.get_parent().name, k.get_bone_count()])])

	# --- the lean ---
	var rest := rig.transform.basis
	Input.action_press("move_forward")
	Input.action_press("move_left")
	var most := 0.0
	for i in 90:
		await physics_frame
		player.camera_rig.rotation.y += 0.03
		await process_frame
		most = maxf(most, rig.transform.basis.y.angle_to(Vector3.UP))
	Input.action_release("move_forward")
	Input.action_release("move_left")
	_check("leans into a run round a circle", most > 0.06, "(%.1f deg)" % rad_to_deg(most))
	await _frames(90)
	var off := rig.transform.basis.y.angle_to(rest.y)
	_check("upright again standing", off < 0.01, "(%.2f deg)" % rad_to_deg(off))
	_check("the lean leaves his size alone", absf(rig.transform.basis.get_scale().x - rest.get_scale().x) < 0.001)

	# --- pulling up out of a run kicks up dust ---
	player.camera_rig.rotation.y = 0.0
	Input.action_press("move_forward")
	await _frames(60)
	var before := _dust(world)
	Input.action_release("move_forward")
	var dust := 0
	for i in 12:
		await process_frame
		dust = maxi(dust, _dust(world) - before)
	_check("pulling up out of a run kicks up dust", dust > 0)
	await _frames(60)

	# --- the bite ---
	var orc: Node3D = load("res://scenes/enemies/orc.tscn").instantiate()
	world.get_node("Enemies").add_child(orc)
	orc.set(&"max_health", 100000.0)
	orc.set(&"health", 100000.0)
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	orc.global_position = player.global_position + Vector3(0.0, 0.0, -1.5)
	player.camera_rig.rotation.y = 0.0
	await _frames(20)
	var bitten := false
	var hero_held := false
	var orc_held := 0
	var orc_lit := 0
	var glide := 99.0
	var own := orc.get(&"_own") as AnimationPlayer
	var last_pos := -1.0
	var held_step := 99.0
	for i in 400:
		if i % 10 == 0:
			player.rotation.y = 0.0
			orc.global_position = player.global_position + Vector3(0.0, 0.0, -1.4)
			await _tap("attack")
		else:
			await physics_frame
		if rig.in_hitstop():
			hero_held = true
			orc_held = maxi(orc_held, _held(orc))
			if own != null and _held(orc) > 0:
				var pos := own.current_animation_position
				if last_pos >= 0.0:
					held_step = minf(held_step, absf(pos - last_pos))
				last_pos = pos
			orc_lit = maxi(orc_lit, _lit(orc))
			glide = minf(glide, Vector3(player.velocity.x, 0.0, player.velocity.z).length())
			bitten = true
		if bitten and not rig.in_hitstop():
			break
	_check("a cut bit", bitten)
	_check("his swing held", hero_held)
	_check("the orc's clips held with it", orc_held > 0 and held_step < 0.005, "(%.4f s a tick)" % held_step)
	_check("the orc lit", orc_lit > 0, "(%d meshes)" % orc_lit)
	_check("he does not glide on in the bite", glide < 1.0, "(%.2f m/s)" % glide)
	# the string may still be going (cuts asked for in the loop): let it end
	await _frames(30)
	while player.is_committed():
		await physics_frame
	await _frames(20)
	_check("the orc let go", _held(orc) == 0)
	_check("the light gone", _lit(orc) == 0)

	print("hit_feel_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
