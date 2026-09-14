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
	_player.rig.attack(CharacterRig.AttackStyle.OVERHEAD)
	await _wait(4)
	await _shot("swing_overhead_wind")
	await _wait(9)
	await _shot("swing_overhead_hit")
	await _wait(30)

	_player.rig.attack(CharacterRig.AttackStyle.SIDE)
	await _wait(4)
	await _shot("swing_side_wind")
	await _wait(7)
	await _shot("swing_side_hit")
	await _wait(4)
	await _shot("swing_side_trail")

	# A plain attack() with no style throws one of the library's cuts, which is
	# what the attack button does; the two above force the procedural swings.
	await _place(-12.0)
	_player.rig.attack()
	await _wait(5)
	await _shot("swing_clip_wind")
	await _wait(6)
	await _shot("swing_clip_hit")
	await _wait(8)
	await _shot("swing_clip_recover")
	await _wait(40)

	# The crouch, standing and creeping. Built by hand: the library has none.
	await _place(8.0)
	Input.action_press("crouch")
	await _wait(20)
	await _shot("crouch_idle")
	Input.action_press("move_forward")
	await _wait(30)
	await _shot("crouch_walk")
	Input.action_release("move_forward")
	Input.action_release("crouch")
	await _wait(25)

	# The double-tapped dodge, which is the library's evade rather than the roll.
	await _place(4.0)
	Input.action_press("dash")
	await _wait(2)
	Input.action_release("dash")
	await _wait(2)
	Input.action_press("dash")
	await _wait(2)
	Input.action_release("dash")
	await _wait(6)
	await _shot("dodge_clip_a")
	await _wait(12)
	await _shot("dodge_clip_b")
	await _wait(40)

	# The slide, which has to be launched off a run.
	await _place(12.0)
	Input.action_press("move_forward")
	await _wait(45)
	Input.action_press("crouch")
	await _wait(8)
	await _shot("slide_a")
	await _wait(22)
	await _shot("slide_b")
	Input.action_release("crouch")
	Input.action_release("move_forward")
	await _wait(40)

	# The pull-up, over a block put there for it.
	var ledge := StaticBody3D.new()
	var block := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.1, 4.0)
	block.shape = box
	ledge.add_child(block)
	world.add_child(ledge)
	ledge.global_position = Vector3(6.0, 0.55, 16.0)

	_player.global_position = Vector3(6.0, 0.2, 18.5)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(30)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	await _wait(8)
	await _shot("climb_a", Vector3(2.8, 0.8, 3.0))
	await _wait(10)
	await _shot("climb_b", Vector3(2.8, 0.8, 3.0))
	await _wait(20)
	await _shot("climb_c", Vector3(2.8, 0.8, 3.0))
	ledge.queue_free()

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
