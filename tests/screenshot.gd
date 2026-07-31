extends SceneTree

## Renders the greybox world and writes a PNG next to the project.
## Run with:
##   godot --script res://tests/screenshot.gd -- user://shot.png

const WORLD := "res://scenes/world/greybox_world.tscn"


func _initialize() -> void:
	var path := "res://shot.png"
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		path = argv[0]

	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	var player: Player = world.get_node("Player")

	# Do not steal the cursor for a one-off capture.
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Let the player settle, then walk towards the stairs so the shot shows
	# the controller in motion rather than a T-pose on flat ground.
	player.global_position = Vector3(-6.0, 0.2, 6.0)
	player.camera_rig.rotation.y = deg_to_rad(-35.0)
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
	Input.action_release("move_forward")
	for i in 10:
		await process_frame

	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_png(path)
	print("saved %s (%d)" % [ProjectSettings.globalize_path(path), err])
	quit()
