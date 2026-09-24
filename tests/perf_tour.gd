extends SceneTree

## A walk round the whole map, measuring what each place costs to draw and to
## simulate, at every graphics setting.
##
##     godot --path . --script res://tests/perf_tour.gd    # not --headless
##
## `draw_budget.gd` and `physics_budget.gd` take the level apart one piece at a
## time from a single spot; this is the other half — the same few numbers from
## every part of the map, so a place that has got dear shows up by name. The
## places are found from the level itself (the mist village, the pier, the orc
## camp), so they follow the level when it is moved about.
##
## Per place and setting: the median and 90th-percentile frame, draw calls, how
## many of those are the sun's shadow, and the primitives drawn. Then, at the
## same place, the physics tick with the knight walking — median, 90th and
## worst, because a stutter lives in the tail.
##
## Frame times are only comparable within one run on one machine: a laptop's
## thermal state and whatever else it is doing move them further than most of
## the changes being measured. Draw calls and primitives are exact.

const WORLD := "res://scenes/world/greybox_world.tscn"
const SETTLE := 40
const SAMPLES := 90
const TICKS := 180

var _world: Node3D
var _cam: Camera3D
var _player: Player


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var t0 := Time.get_ticks_msec()
	_world = load(WORLD).instantiate()
	var warmup := _world.get_node_or_null("PipelineWarmup")
	root.add_child(_world)
	# Graphics.apply works on the current scene; a --script run has none of its own.
	current_scene = _world
	await process_frame
	while warmup != null and is_instance_valid(warmup):
		await process_frame
	print("\nload + warm-up to the first frame: %d ms" % (Time.get_ticks_msec() - t0))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = (_world as World).player()

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 600.0
	_world.add_child(_cam)
	_cam.current = true

	var levels: Array = Graphics.Level.values()
	var names: Array = Graphics.Level.keys()
	print("\n%-24s %-7s %7s %7s %6s %7s %9s" % ["place", "gfx", "med ms", "p90", "draws", "shadow", "prims"])
	var physics: Array[String] = []
	for spot: Array in _spots():
		_player.global_position = (spot[2] as Vector3) + Vector3(0.0, 0.5, 0.0)
		_player.velocity = Vector3.ZERO
		_cam.global_position = spot[1]
		_cam.look_at(spot[2])
		for i in levels.size():
			Graphics.apply(self, levels[i])
			await _draw(spot[0] as String, String(names[i]).to_lower())
		Graphics.apply(self, Graphics.Level.HIGH)
		physics.append(await _tick(spot[0] as String, spot[2] as Vector3))

	print("\n%-24s %8s %8s %8s   (physics tick, knight walking)" % ["place", "median", "90th", "worst"])
	for line in physics:
		print(line)
	print("\nvideo memory %.0f MB (textures %.0f MB, buffers %.0f MB)" % [
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])
	quit()


## [name, camera, looking at]. The south of the map is found from its nodes.
func _spots() -> Array:
	var spots := [
		["spawn, to the wood", Vector3(4.0, 3.2, 14.0), Vector3(0.0, 1.2, 0.0)],
		["in the wood", Vector3(-56.0, 3.0, -30.0), Vector3(-40.0, 2.0, -60.0)],
		["the hamlet", Vector3(0.0, 3.0, 0.0), Vector3(-30.0, 2.0, 30.0)],
	]
	for path in ["Marsh/MistVillage", "Bay/Pier"]:
		var n := _world.get_node_or_null(path) as Node3D
		if n != null:
			var p := _centre(n)
			spots.append([String(path.get_file()), p + Vector3(0.0, 4.0, 40.0), p])
	for c in _world.get_node("Enemies").get_children():
		if c is OrcWarrior:
			var p := (c as Node3D).global_position
			spots.append(["orc camp", p + Vector3(8.0, 3.0, 12.0), p + Vector3(4.0, 0.0, 6.0)])
			break
	return spots


## The middle of what `node` draws. A model's own origin can be anywhere — the
## pier's is at the middle of the map — so it is found from its meshes.
func _centre(node: Node3D) -> Vector3:
	var box := AABB()
	var found := false
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		var here := visual.global_transform * visual.get_aabb()
		box = here if not found else box.merge(here)
		found = true
	if not found:
		return node.global_position
	var middle := box.get_center()
	middle.y = box.position.y
	return middle


func _draw(place: String, gfx: String) -> void:
	for i in SETTLE:
		await process_frame
	var frames: Array[float] = []
	var draws := 0.0
	var prims := 0.0
	var last := Time.get_ticks_usec()
	for i in SAMPLES:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	frames.sort()
	draws /= SAMPLES
	# The sun's share: the same view with its shadow switched off for a moment.
	var shadow := 0.0
	var sun := _world.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D
	if sun.shadow_enabled:
		sun.shadow_enabled = false
		for i in 8:
			await process_frame
		shadow = draws - Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sun.shadow_enabled = true
		for i in 8:
			await process_frame
	print("%-24s %-7s %7.2f %7.2f %6.0f %7.0f %9.0f" % [place, gfx, frames[SAMPLES / 2],
			frames[SAMPLES * 9 / 10], draws, shadow, prims / SAMPLES])


func _tick(place: String, at: Vector3) -> String:
	_player.global_position = at + Vector3(0.0, 0.5, 0.0)
	_player.velocity = Vector3.ZERO
	for i in SETTLE:
		await physics_frame
	var ticks: Array[float] = []
	for i in TICKS:
		# A slow square, so a wall is left behind rather than walked into.
		var leg := (i / 45) % 4
		var dir: Vector3 = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD][leg]
		_player.velocity.x = dir.x * 3.0
		_player.velocity.z = dir.z * 3.0
		await physics_frame
		ticks.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	ticks.sort()
	return "%-24s %8.2f %8.2f %8.2f" % [place, ticks[TICKS / 2], ticks[TICKS * 9 / 10], ticks[TICKS - 1]]
