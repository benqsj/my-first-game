extends SceneTree

## Measures where the frame time goes, so a stutter can be pinned on something
## rather than guessed at.
##
## Every configuration is measured **in one process, back to back**. Separate
## runs are not comparable on a laptop: thermal state and whatever else the
## machine is doing move the numbers further than the thing being measured does.
##
## Frames are reported as a distribution, never as an average. A stutter is a
## tail problem, and the mean is exactly the statistic that hides it.
##
##   godot --path . --script res://tests/perf_probe.gd
##
## Rendering has to be on for any of this to mean anything, so it must *not* be
## run with --headless.

const WORLD := "res://scenes/world/greybox_world.tscn"
## Frames thrown away at the start of each phase: the first pass over a material
## compiles its pipeline, and switching things back on re-dirties the scene.
const WARMUP := 45
const SAMPLES := 260

var _world: Node3D
var _player: Player
var _field: GrassField


## Toggles from the command line, as `off:<name>`. `off:warmup` skips the
## pipeline warm-up; `off:short` stops after the opening stretches.
var _off := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("off:"):
			_off[arg.substr(4)] = true

	_world = load(WORLD).instantiate()
	# Switched off before the scene enters the tree: the warm-up does its work
	# from _ready onwards, and there is no later moment to catch it.
	var warmup := _world.get_node_or_null("PipelineWarmup") as PipelineWarmup
	if warmup != null and _off.has("warmup"):
		warmup.enabled = false

	var built := Time.get_ticks_msec()
	root.add_child(_world)
	_player = _world.get_node("Player")
	_field = _world.get_node_or_null("Level/Scatter") as GrassField

	await process_frame
	# It frees itself when it is done, so waiting on that is what measures it.
	while warmup != null and is_instance_valid(warmup):
		await process_frame
	var label := "OFF" if _off.has("warmup") else "on"
	print("\nstartup, pipeline warm-up %s: %d ms to first playable frame" % [
		label, Time.get_ticks_msec() - built])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Vsync would peg every frame to the refresh interval and hide how much work
	# is actually going on underneath it.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_player.global_position = Vector3(6.0, 0.2, 14.0)
	_player.velocity = Vector3.ZERO
	for i in 40:
		await physics_frame
	Input.action_press("move_forward")

	print("\ndraw calls %d, objects %d, nodes %d, video mem %.0f MB" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("\n%-22s %8s %8s %8s %8s %7s %8s" % [
		"configuration", "median", "90th", "99th", "worst", "hitch", "draws"])

	# What the player actually meets: the first stretch of play. If the pipeline
	# warm-up has done its job these are as flat as the settled ones below; if
	# it has not, this is where the stalls are.
	await _measure("first stretch of play")
	await _measure("second stretch")
	await _measure("third stretch")
	if _off.has("short"):
		Input.action_release("move_forward")
		quit()
		return

	# The baseline is re-measured between every toggle. Anything that drifts —
	# the machine warming up, the level streaming in — then shows as a moving
	# baseline instead of being mistaken for the effect of the toggle.
	await _measure("baseline")

	# The rig's script and the rig's *drawing* are separate costs and have to be
	# told apart: Tariel is 135 rigid parts, which is 135 draw calls.
	_player.rig.visible = false
	await _measure("  player hidden")
	_player.rig.visible = true
	await _measure("baseline")

	var enemies := _world.get_node_or_null("Enemies")
	if enemies != null:
		for enemy in enemies.get_children():
			(enemy as Node3D).visible = false
		await _measure("  enemies hidden")
		for enemy in enemies.get_children():
			(enemy as Node3D).visible = true
		await _measure("baseline")

		# A creature built out of rigid parts is one draw call per part, and the
		# directional light draws every one of them again per shadow split. If
		# the shadow pass is the cost, this is where it shows.
		_shadows(enemies, false)
		await _measure("  enemies cast no shadow")
		_shadows(enemies, true)
		await _measure("baseline")

	_shadows(_player.rig, false)
	await _measure("  player casts no shadow")
	_shadows(_player.rig, true)
	await _measure("baseline")

	var light := _find_light(_world)
	if light != null:
		var was_quality: int = ProjectSettings.get_setting(
				"rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 3)
		RenderingServer.directional_soft_shadow_filter_set_quality(
				RenderingServer.SHADOW_QUALITY_HARD)
		await _measure("  hard shadow filter")
		RenderingServer.directional_soft_shadow_filter_set_quality(was_quality)
		await _measure("baseline")

		var splits := light.directional_shadow_mode
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		await _measure("  one shadow split")
		light.directional_shadow_mode = splits
		await _measure("baseline")

		light.shadow_enabled = false
		await _measure("  no shadows at all")
		light.shadow_enabled = true

	if _field != null:
		_field.set_process(false)
		await _measure("  grass script off")
		_field.set_process(true)
		await _measure("baseline")

		_field.visible = false
		await _measure("  grass hidden")
		_field.visible = true
		await _measure("baseline")

	Input.action_release("move_forward")
	quit()


func _measure(label: String) -> void:
	for i in WARMUP:
		await process_frame

	var frames := PackedFloat32Array()
	frames.resize(SAMPLES)
	var worst := 0.0
	var turn := 0.0
	var draws := 0.0
	var last := Time.get_ticks_usec()
	for i in SAMPLES:
		await process_frame
		var now := Time.get_ticks_usec()
		frames[i] = (now - last) / 1000.0
		last = now
		worst = maxf(worst, frames[i])
		draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		# Keep the camera swinging so scenery keeps entering the frustum: a
		# stall that only happens when something new comes into view is exactly
		# the one worth catching.
		turn += 1.0
		_player.camera_rig.rotation.y = sin(turn * 0.02) * PI

	var sorted := frames.duplicate()
	sorted.sort()
	var median := _at(sorted, 0.5)
	var hitches := 0
	for ms in frames:
		if ms > median * 2.0:
			hitches += 1
	print("%-22s %7.2f%s %7.2f %7.2f %8.2f %7d %8d" % [
		label, median, "", _at(sorted, 0.9), _at(sorted, 0.99), worst, hitches, int(draws)])


func _shadows(root: Node, on: bool) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func _find_light(root: Node) -> DirectionalLight3D:
	for node in root.find_children("*", "DirectionalLight3D", true, false):
		return node as DirectionalLight3D
	return null


func _at(sorted: PackedFloat32Array, fraction: float) -> float:
	return sorted[clampi(int(sorted.size() * fraction), 0, sorted.size() - 1)]
