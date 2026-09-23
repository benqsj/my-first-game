extends SceneTree

## Photographs Arkdeva's poison: a gob in flight, the splash, the pool running
## out, and the pool drying up. Off-screen, so the window need not be visible.
##
##     godot --path . --script res://tests/venom_shots.gd -- /abs/output/dir

var _view: SubViewport


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var dir := argv[0] if argv.size() > 0 else "/tmp/venom"
	DirAccess.make_dir_recursive_absolute(dir)
	var world: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	_view = SubViewport.new()
	_view.size = Vector2i(1280, 720)
	_view.world_3d = root.get_viewport().find_world_3d()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var camera := Camera3D.new()
	camera.fov = 50.0
	_view.add_child(camera)
	camera.current = true
	camera.position = Vector3(26.0, 3.2, 26.0)
	camera.look_at(Vector3(20.0, 0.6, 19.0))
	for i in 20:
		await process_frame

	var from := Vector3(14.0, 5.0, 14.0)
	var to := Vector3(20.0, 0.0, 19.0)
	Venom.spit(world, from, to, 0.6, 2.4, 3.0)
	await _after(0.3)
	await _shot(dir, "v1_flight")
	await _after(0.35)
	await _shot(dir, "v2_splash")
	await _after(0.4)
	await _shot(dir, "v3_pool")
	await _after(1.3)
	await _shot(dir, "v4_pool_later")
	await _after(0.9)
	await _shot(dir, "v5_drying")
	# From above, the shape of it.
	Venom.pool(world, Vector3(20.0, 0.0, 19.0), 3.3, 3.5)
	camera.position = Vector3(20.0, 9.0, 21.5)
	camera.look_at(Vector3(20.0, 0.0, 19.0))
	await _after(0.8)
	await _shot(dir, "v6_pool_above")
	print("venom shots written to ", dir)
	quit()


func _after(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame


func _shot(dir: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	_view.get_texture().get_image().save_png("%s/%s.png" % [dir, label])
