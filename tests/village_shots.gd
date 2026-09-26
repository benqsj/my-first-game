extends SceneTree

## Pictures of the village and the land behind it, for the round's work.
##     godot --path . --script res://tests/village_shots.gd -- /abs/dir [tag]

var _view: SubViewport


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var dir := argv[0] if argv.size() > 0 else "/tmp/village"
	var tag := argv[1] if argv.size() > 1 else "v"
	DirAccess.make_dir_recursive_absolute(dir)
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	for i in 10:
		await physics_frame
	var player := world.player()
	if player != null:
		player.set_physics_process(false)
		player.global_position = Vector3(60.0, 0.2, 20.0)
	_view = SubViewport.new()
	_view.size = Vector2i(1280, 720)
	_view.world_3d = root.get_viewport().find_world_3d()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var camera := Camera3D.new()
	camera.fov = 55.0
	camera.far = 900.0
	_view.add_child(camera)
	camera.current = true
	var views := [
		["over_the_village", Vector3(30.0, 32.0, 30.0), Vector3(78.0, 8.0, 100.0)],
		["hill_from_fence", Vector3(40.0, 0.0, 78.0), Vector3(72.0, 8.0, 106.0)],
		["in_the_firs", Vector3(46.0, 0.0, 90.0), Vector3(80.0, 0.0, 104.0)],
		["up_the_hill", Vector3(70.0, 0.0, 86.0), Vector3(76.0, 3.0, 114.0)],
		["from_the_top", Vector3(84.0, 0.0, 116.0), Vector3(60.0, 0.0, 50.0)],
		["from_south", Vector3(60.0, 16.0, -18.0), Vector3(66.0, 8.0, 70.0)],
	]
	for v: Array in views:
		var eye: Vector3 = v[1]
		var target: Vector3 = v[2]
		# Views given at 0 height stand a man's height over the ground there.
		if eye.y == 0.0:
			eye.y = Terrain.height(eye.x, eye.z) + 2.0
		if target.y == 0.0:
			target.y = Terrain.height(target.x, target.z) + 1.5
		v[1] = eye
		v[2] = target
		camera.position = v[1]
		camera.look_at(v[2], Vector3.UP if absf((v[2] - v[1]).normalized().y) < 0.95 else Vector3.FORWARD)
		for i in 25:
			await process_frame
		await RenderingServer.frame_post_draw
		_view.get_texture().get_image().save_png("%s/%s_%s.png" % [dir, tag, v[0]])
	print("village shots written to ", dir)
	quit()
