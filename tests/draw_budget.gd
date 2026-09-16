extends SceneTree

## Says where the draw calls go, by taking things out of the level one at a time
## and reading what the count drops by.
##
##     godot --path . --script res://tests/draw_budget.gd
##
## Draw calls rather than frame time, because frame time cannot be measured here:
## the window is not in focus in a script-driven run, so the OS throttles how
## often it is presented, and Metal does not report GPU timestamps to Godot at
## all. Draw calls and triangles are counted by the renderer itself and mean the
## same thing whatever the window is doing — and a count that includes the shadow
## passes is exactly what is wanted, since that is where a forest goes wrong.

const WORLD := "res://scenes/world/greybox_world.tscn"
## Where it is measured from: standing at the spawn looking out over the meadow
## into the treeline, which is the busiest view in the level.
const FROM := Vector3(4.0, 3.2, 14.0)
const LOOK_AT := Vector3(0.0, 1.2, 0.0)

var _world: Node3D
var _camera: Camera3D


func _initialize() -> void:
	# Vsync pegs every frame to the refresh interval, and an unfocused window is
	# throttled harder still — which turns a dozen settling frames into seconds.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_camera = Camera3D.new()
	_camera.fov = 55.0
	_world.add_child(_camera)
	_camera.current = true
	_camera.position = FROM
	_camera.look_at(LOOK_AT)
	for i in 24:
		await process_frame

	var baseline := await _count("everything on")
	print("")

	# Each of these is switched off, measured, and put back, so the numbers are
	# against one baseline rather than against each other.
	for row: Array in [
		["the grass", "Level/Scatter"],
		["the wood's canopy", "Forest/Canopy"],
		["the undergrowth", "Forest/Undergrowth"],
		["the ground litter", "Forest/Litter"],
		["the stone clusters", "Level/Scatter"],
		["the hamlet", "Level/Village"],
		["the skyline", "Horizon"],
		["the creatures", "Enemies"],
	]:
		var node := _world.get_node_or_null(row[1] as NodePath) as Node3D
		if node == null:
			continue
		var only_rocks: bool = row[0] == "the stone clusters"
		var hidden := _hide(node, only_rocks)
		var off := await _count("  without %s" % row[0], baseline)
		for child in hidden:
			(child as Node3D).visible = true
		await _settle()

	print("")
	await _shadows(baseline)
	quit()


## Hides a subtree, or — for the stones, which share a node with the grass —
## only the children that are not the field's own chunks. Returns what it hid so
## it can be put back.
func _hide(node: Node3D, only_rocks: bool) -> Array:
	var hidden: Array = []
	if not only_rocks:
		if node.visible:
			node.visible = false
			hidden.append(node)
		return hidden
	for child in node.get_children():
		var mesh := child as Node3D
		if mesh != null and not (mesh is MultiMeshInstance3D) and mesh.visible:
			mesh.visible = false
			hidden.append(mesh)
	return hidden


## What the sun's shadow map costs, split by how many cascades it is cut into.
func _shadows(baseline: Array) -> void:
	var sun := _world.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D
	var was := sun.directional_shadow_mode
	for mode: Array in [
		[DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "  with 2 shadow splits"],
		[DirectionalLight3D.SHADOW_ORTHOGONAL, "  with 1 shadow split"],
	]:
		sun.directional_shadow_mode = mode[0]
		await _count(mode[1] as String, baseline)
	sun.directional_shadow_mode = was

	sun.shadow_enabled = false
	await _count("  with no shadows at all", baseline)
	sun.shadow_enabled = true

	var forest := _world.get_node_or_null("Forest") as Forest
	if forest != null:
		for node in forest.find_children("*", "MultiMeshInstance3D", true, false):
			(node as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		await _count("  with the wood casting no shadow", baseline)


func _settle() -> void:
	for i in 6:
		await process_frame


func _count(label: String, against: Array = []) -> Array:
	await _settle()
	await RenderingServer.frame_post_draw
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if against.is_empty():
		print("%-34s %6d draws   %9d tris" % [label, draws, tris])
	else:
		print("%-34s %6d draws   %9d tris   (%+d draws, %+d tris)" % [
				label, draws, tris, draws - against[0], tris - against[1]])
	return [draws, tris]
