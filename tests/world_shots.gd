extends SceneTree

## Photographs the level from a handful of fixed vantage points, so the wood, the
## hamlet and the skyline can be looked at without playing through to them.
##
##     godot --script res://tests/world_shots.gd -- /abs/output/dir
##
## Also prints what got built: how much of each thing the [Forest] planted, how
## many draw calls and triangles the view costs, and how long a frame took.

const WORLD := "res://scenes/world/greybox_world.tscn"

## label -> [camera position, what it is looking at, field of view]
const VANTAGES := {
	"aerial": [Vector3(0, 210, 210), Vector3(0, 0, 0), 55.0],
	"aerial_low": [Vector3(-60, 70, 90), Vector3(0, 0, 10), 60.0],
	"spawn": [Vector3(4, 3.2, 14), Vector3(0, 1.2, 0), 55.0],
	"treeline": [Vector3(6, 2.4, 34), Vector3(10, 4.0, 62), 60.0],
	"deep_wood": [Vector3(-58, 2.4, -14), Vector3(-84, 4.5, -34), 65.0],
	"glade_imp": [Vector3(-62, 2.6, -48), Vector3(-72, 1.2, -58), 50.0],
	"treeline_from_open": [Vector3(30, 4.0, 6), Vector3(-40, 8.0, -20), 62.0],
	"village_street": [Vector3(14, 3.0, 42), Vector3(90, 5.0, 43), 62.0],
	"village_above": [Vector3(26, 30, 4), Vector3(70, 2, 45), 55.0],
	"fields": [Vector3(48, 3.0, 12), Vector3(70, 4.0, 40), 62.0],
	"windmill": [Vector3(84, 5, 48), Vector3(96, 5, 62), 50.0],
	"gate_above": [Vector3(30, 42, 42), Vector3(30.01, 0, 42), 45.0],
	"horizon_east": [Vector3(70, 6, 10), Vector3(180, 26, 10), 65.0],
}

var _dir := "res://"
var _only := ""


func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		_dir = argv[0]
	# A second argument narrows it to the vantages whose names contain it. The
	# whole set is a slow thing to sit through when one corner is being worked on.
	if argv.size() > 1:
		_only = argv[1]
	DirAccess.make_dir_recursive_absolute(_dir)

	# Vsync pegs every frame to the refresh interval, and an unfocused window is
	# throttled harder still, which turns the settling frames into whole seconds.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_report(world)

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	# What the *renderer* took, asked of the rendering server rather than read
	# off the clock. Frame pacing in a script-driven run says nothing useful —
	# the window is not in focus, so the OS throttles how often it is presented,
	# and a wall-clock frame time measures the throttle instead of the scene.
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)

	# The first frames of a script-driven run have not drawn anything yet, and a
	# shot taken into that comes back black.
	for i in 30:
		await process_frame

	# A map of the whole level, drawn flat and with every distance cull switched
	# off. The perspective shot from on high is not this: half the map is beyond
	# anything's draw distance from up there, so it reads as though nothing was
	# ever planted out at the edges.
	if _only.is_empty():
		await _map(camera, world)

	for label: String in VANTAGES:
		if not _only.is_empty() and not label.contains(_only):
			continue
		var shot: Array = VANTAGES[label]
		camera.fov = shot[2]
		camera.position = shot[0]
		camera.look_at(shot[1])
		# Long enough for the level-of-detail and visibility fades to settle, so
		# a shot is not full of half-faded trees.
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png("%s/%s.png" % [_dir, label])
		print("%-16s draws=%-5d tris=%-9d gpu=%6.2f ms  cpu=%5.2f ms" % [label,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
				RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())])

	print("\nwrote %d shots to %s" % [VANTAGES.size() + 1, _dir])
	quit()


## Looks straight down at the level from above, orthographically, with nothing
## culled — so what is in the picture is what was placed.
func _map(camera: Camera3D, world: Node3D) -> void:
	var ranges: Array[float] = []
	var meshes := world.find_children("*", "GeometryInstance3D", true, false)
	for node in meshes:
		var mesh := node as GeometryInstance3D
		ranges.append(mesh.visibility_range_end)
		mesh.visibility_range_end = 0.0

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 250.0
	camera.far = 900.0
	camera.position = Vector3(0.0, 300.0, 0.0)
	camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/map.png" % _dir)
	print("%-18s draws=%-5d tris=%-9d  (everything, nothing culled)" % ["map",
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])

	for i in meshes.size():
		(meshes[i] as GeometryInstance3D).visibility_range_end = ranges[i]
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.rotation = Vector3.ZERO


## What the level actually built, as against what it was asked to.
func _report(world: Node3D) -> void:
	var forest := world.get_node_or_null("Forest") as Forest
	if forest != null:
		print("forest: ", forest.counts)
		print("forest nodes: ", forest.find_children("*", "MultiMeshInstance3D", true, false).size(),
				" multimeshes")
	var village := world.get_node_or_null("Level/Village")
	if village != null:
		var dressed := 0
		var hulls := 0
		for node in village.get_children():
			var building := node as Building
			if building != null:
				dressed += building.dressed
				hulls += building.hulls
		print("village: %d buildings, %d surfaces textured, %d hulls" % [
				village.get_child_count(), dressed, hulls])
	var enemies := world.get_node_or_null("Enemies")
	if enemies != null:
		var names := PackedStringArray()
		for node in enemies.get_children():
			names.append(node.name)
		print("creatures: ", names)
	print("")
