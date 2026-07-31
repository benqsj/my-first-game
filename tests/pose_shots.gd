extends SceneTree

## Renders Tariel in each animation state so the poses can be eyeballed.
## Run with:
##   godot --script res://tests/pose_shots.gd -- /abs/output/dir

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
	_player = world.get_node("Player")

	_camera = Camera3D.new()
	_camera.fov = 40.0
	world.add_child(_camera)

	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _place(16.0)

	await _shot("idle")

	Input.action_press("walk")
	Input.action_press("move_forward")
	await _wait(45)
	await _shot("walk_a")
	await _wait(14)
	await _shot("walk_b")

	Input.action_release("walk")
	await _wait(45)
	await _shot("run")

	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	await _wait(12)
	await _shot("jump")
	await _wait(60)

	Input.action_release("move_forward")
	await _place(0.0)

	# Shield down by default, up only while block is held.
	await _shot("shield_down")
	await _shot("shield_down_back", Vector3(-1.6, 0.6, 3.2))
	Input.action_press("block")
	await _wait(25)
	await _shot("block")
	Input.action_release("block")
	await _wait(25)

	# The two swings, caught at their wind-up and at the moment of impact.
	await _place(-4.0)
	_player.rig.attack(TarielRig.AttackStyle.OVERHEAD)
	await _wait(4)
	await _shot("swing_overhead_wind")
	await _wait(9)
	await _shot("swing_overhead_hit")
	await _wait(30)

	_player.rig.attack(TarielRig.AttackStyle.SIDE)
	await _wait(4)
	await _shot("swing_side_wind")
	await _wait(7)
	await _shot("swing_side_hit")
	await _wait(4)
	await _shot("swing_side_trail")

	# The dodge roll, sampled through the somersault.
	await _place(-8.0)
	Input.action_press("move_forward")
	await _wait(20)
	Input.action_press("dash")
	await _wait(1)
	Input.action_release("dash")
	await _wait(7)
	await _shot("roll_a")
	await _wait(7)
	await _shot("roll_b")
	await _wait(7)
	await _shot("roll_c")
	Input.action_release("move_forward")

	print("done")
	quit()


func _shot(name: String, offset := Vector3(2.5, 0.5, -3.0)) -> void:
	# Frame the character from a three-quarter angle, whatever it is doing.
	var focus := _player.global_position + Vector3.UP * 1.0
	_camera.global_position = focus + offset
	_camera.look_at(focus, Vector3.UP)
	_camera.current = true

	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	image.save_png(path)
	print("saved ", path)


## Drops the player on clear ground and lets it settle before a shot group.
func _place(z: float) -> void:
	_player.global_position = Vector3(6.0, 0.2, z)
	_player.velocity = Vector3.ZERO
	await _wait(30)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame
