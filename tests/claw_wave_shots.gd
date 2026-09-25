extends SceneTree

## Photographs the wolf's claw wave: the tell (the paw raised and held, the
## claws burning), each wave leaving the paw and in flight with the torn air
## behind it, and the slam's furrows. Off-screen.
##
##     godot --path . --script res://tests/claw_wave_shots.gd -- /abs/output/dir [side|behind]

var _view: SubViewport
var _dir: String
var _n := 0


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_dir = argv[0] if argv.size() > 0 else "/tmp/claw_wave"
	var angle := argv[1] if argv.size() > 1 else "side"
	DirAccess.make_dir_recursive_absolute(_dir)
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	world.creature_think_distance = 0.0
	var player := world.player()
	player.immortal = true
	var wolf: Wolf = null
	for e in world.get_node("Enemies").get_children():
		if e is Wolf and wolf == null:
			wolf = e
			continue
		e.queue_free()
	var spot := _flat(world)
	player.global_position = spot + Vector3.UP * 0.2
	wolf.global_position = spot + Vector3(0.0, 0.3, -8.0)
	wolf.intellect = 0.95
	wolf.mind.intellect = 0.95
	wolf.state = Wolf.State.CHASE
	wolf._provoked = 30.0
	wolf.charge_speed = 0.0
	wolf.fight_speed = 0.0
	wolf.set_physics_process(true)

	_view = SubViewport.new()
	_view.size = Vector2i(1280, 720)
	_view.world_3d = root.get_viewport().find_world_3d()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var camera := Camera3D.new()
	camera.fov = 55.0
	_view.add_child(camera)
	camera.current = true
	if angle == "behind":
		camera.position = spot + Vector3(1.3, 2.3, 3.6)
		camera.look_at(spot + Vector3(0.0, 1.3, -6.0))
	else:
		camera.position = spot + Vector3(6.5, 2.0, -2.5)
		camera.look_at(spot + Vector3(0.0, 1.2, -4.6))
	for i in 30:
		await physics_frame
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
	var d := wolf.global_position - player.global_position
	player.rotation.y = atan2(-d.x, -d.z) + PI

	wolf._claw_wait = 0.0
	wolf.attack(&"claw_wave")
	var claw := wolf.rig.claw
	var waves := {}
	var shot_hold := false
	var plan: Array = []
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 7000:
		await process_frame
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
		var now := (Time.get_ticks_msec() - start) / 1000.0
		if claw.active():
			var b := claw._beat(claw._t)
			if not shot_hold and claw._blow == &"rake" and b.x == 1 and b.y > 0.7:
				shot_hold = true
				await _shot("tell_%s" % angle)
		for node in world.get_children():
			if node is ClawWave and not waves.has(node):
				waves[node] = true
				var k := waves.size()
				plan.append([now + 0.05, "wave%d_leaves_%s" % [k, angle]])
				plan.append([now + 0.3, "wave%d_flight_%s" % [k, angle]])
				if k == 3:
					plan.append([now + 0.9, "slam_furrows_%s" % angle])
		for p: Array in plan.duplicate():
			if now >= float(p[0]):
				plan.erase(p)
				await _shot(String(p[1]))
	print("claw wave shots written to ", _dir)
	quit()


func _flat(world: Node3D) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	for c in [Vector3(0, 0, -60), Vector3(20, 0, -80), Vector3(-30, 0, -120)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3.UP * 60, c + Vector3.DOWN * 60, 1))
		if not hit.is_empty():
			return hit.position
	return Vector3.ZERO


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	_view.get_texture().get_image().save_png("%s/%02d_%s.png" % [_dir, _n, label])
