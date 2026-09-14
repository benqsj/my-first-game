extends SceneTree

## Renders the wall climb and a full stride, so both can be eyeballed.
##
## The stride is sampled right round one cycle from the side, because what makes
## a run read as a run is where the foot is over time, and a single frame says
## nothing about that.
##
## Run with (no --headless — the shots need a real framebuffer):
##   godot --script res://tests/climb_shots.gd -- /abs/output/dir

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
	# Nothing else in shot: a wolf wandering through the frame says nothing about
	# the stride and everything about where it happened to be standing.
	for body in world.find_children("*", "CharacterBody3D", true, false):
		if body != _player:
			body.queue_free()
	var scatter := world.get_node_or_null("Level/Scatter") as Node3D
	if scatter != null:
		scatter.visible = false

	# --- Gait, from the side, right round one cycle -------------------------
	# Driven on the spot rather than run past the camera: what is being looked at
	# is the shape of the cycle, and chasing a body across the ground at 9 m/s
	# only makes that harder to see.
	await _place(-24.0)
	_player.set_process(false)
	var side := Vector3(3.4, 0.05, 0.0)
	for pace: float in [_player.walk_speed, _player.run_speed]:
		var label := "walk" if pace < _player.run_speed else "run"
		# Long enough for the pose blends to reach the pace being asked for.
		for i in 120:
			await physics_frame
			_treadmill(pace)
		# One full cycle, evenly sampled.
		var frames := int(round(_player.rig.stride_span() / pace * 60.0))
		for shot in 8:
			await _shot("%s_%d" % [label, shot], side)
			for i in int(round(float(frames) / 8.0)):
				await physics_frame
				_treadmill(pace)
	_player.set_process(true)
	await _wait(30)

	# --- The wall climb -----------------------------------------------------
	var wall := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var face := BoxShape3D.new()
	face.size = Vector3(8.0, 5.0, 1.0)
	slab.shape = face
	wall.add_child(slab)
	# Drawn as well as collided with: a shot of a body hanging off nothing says
	# nothing about whether it is hanging off the wall properly.
	var skin := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = face.size
	skin.mesh = block
	wall.add_child(skin)
	world.add_child(wall)
	wall.global_position = Vector3(6.0, 2.5, 16.0)

	_player.global_position = Vector3(6.0, 0.2, 18.5)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(30)
	Input.action_press("move_forward")
	await _wait(40)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	await _wait(20)
	await _shot("grab", Vector3(3.6, 0.5, 1.1))
	await _shot("grab_side", Vector3(0.2, 0.5, 3.6))

	for i in 5:
		await _wait(16)
		await _shot("climb_%d" % i, Vector3(3.6, 0.5, 1.1))
	await _shot("climb_side", Vector3(2.0, -1.4, 2.4))

	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _wait(25)
	await _shot("shimmy", Vector3(3.6, 0.5, 1.1))
	Input.action_release("move_right")

	# Over the top.
	Input.action_press("move_forward")
	for i in 480:
		await physics_frame
		if _player.state == Player.State.CLIMBING:
			break
	await _shot("topout_a", Vector3(3.0, 1.0, 3.2))
	await _wait(14)
	await _shot("topout_b", Vector3(3.0, 1.0, 3.2))
	Input.action_release("move_forward")
	await _wait(30)
	await _shot("topout_c", Vector3(3.0, 1.0, 3.2))

	print("done")
	quit()


## Runs the rig as though the body were travelling at `speed` while it stands
## still, so a cycle can be looked at without chasing it across the ground.
func _treadmill(speed: float) -> void:
	_player.velocity = Vector3.ZERO
	_player.rig.animate(1.0 / 60.0, speed, speed / _player.walk_speed,
			false, false, 0.0, false)


func _shot(shot_name: String, offset := Vector3(2.5, 0.5, -3.0)) -> void:
	# Aimed after the frames are stepped, not before: at a run the body covers
	# enough ground in two frames to walk itself out of shot.
	for i in 2:
		await process_frame
	var focus := _player.global_position + Vector3.UP * 0.95
	_camera.global_position = focus + offset
	_camera.look_at(focus, Vector3.UP)
	_camera.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [_dir, shot_name]
	image.save_png(path)
	print("saved ", path)


func _place(z: float) -> void:
	_player.global_position = Vector3(6.0, 0.2, z)
	_player.velocity = Vector3.ZERO
	await _wait(30)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame
