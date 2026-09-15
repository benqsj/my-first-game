extends SceneTree

## Renders just the crouch and the double-tapped dodge, which pose_shots covers
## too but only after twenty other shots — this one is for looking at those two
## while they are being tuned.
##   godot --path . --script res://tests/crouch_shots.gd -- /abs/output/dir

const WORLD := "res://scenes/world/greybox_world.tscn"

var _player: Player
var _camera: Camera3D
var _dir := "res://"


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_dir = argv[0]

	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	_player = (world as World).player()
	_camera = Camera3D.new()
	_camera.fov = 40.0
	world.add_child(_camera)

	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _place(10.0)

	await _shot("stand")
	Input.action_press("crouch")
	await _wait(25)
	await _shot("crouch")
	await _shot("crouch_back", Vector3(-2.0, 0.8, 3.0))
	Input.action_press("move_forward")
	await _wait(28)
	await _shot("crouch_walk")
	Input.action_release("move_forward")
	Input.action_release("crouch")
	await _wait(30)

	# One tap is the roll, two is the library's evade.
	await _place(4.0)
	Input.action_press("dash")
	await _wait(2)
	Input.action_release("dash")
	await _wait(2)
	Input.action_press("dash")
	await _wait(2)
	Input.action_release("dash")
	await _wait(8)
	await _shot("dodge_a")
	await _wait(14)
	await _shot("dodge_b")

	print("done")
	quit()


func _shot(name: String, offset := Vector3(2.6, 0.6, -3.2)) -> void:
	var focus := _player.global_position + Vector3.UP * 0.9
	_camera.global_position = focus + offset
	_camera.look_at(focus, Vector3.UP)
	_camera.current = true
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_dir, name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _place(z: float) -> void:
	_player.global_position = Vector3(6.0, 0.2, z)
	_player.velocity = Vector3.ZERO
	await _wait(30)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame
