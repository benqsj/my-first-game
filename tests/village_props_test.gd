extends SceneTree

## The village's props ([VillageProps]): every model named in the layout is in
## the kit, they are baked into a few meshes (not one node per prop), nothing
## solid stands on the villagers' street, the spawn, the gate, the quest
## givers or in a doorway, and the square's cobbles keep the grass off.
##
##     godot --headless --path . --script res://tests/village_props_test.gd

var _failures := 0


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(5)
	var props := world.get_node_or_null("Level/Village/Props") as VillageProps
	_check("the village has its props", props != null)
	if props == null:
		_finish()
		return

	# Every kind in the layout is a model in the kit.
	var scene := (load(VillageProps.SCENE) as PackedScene).instantiate()
	var kinds := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		kinds[StringName(node.name)] = true
	scene.free()
	var missing: Array[String] = []
	var placed := VillageProps.placements()
	for p: Array in placed:
		if not kinds.has(p[0]):
			missing.append(String(p[0]))
	_check("every prop's model is in the kit", missing.is_empty(), ", ".join(missing))

	# Baked: a handful of meshes for well over a hundred props.
	var meshes := props.find_children("*", "MeshInstance3D", false, false).size()
	_check("baked into few meshes", meshes <= 80 and placed.size() >= 120, "%d meshes for %d props" % [meshes, placed.size()])

	# Nothing solid where people have to walk.
	var space := world.get_world_3d().direct_space_state
	var body := props.get_node("PropsBody") as StaticBody3D
	var spots: Array[Vector3] = []
	for s: Vector3 in World.STREET:
		spots.append(s)
	for a in range(World.STREET.size() - 1):
		spots.append(((World.STREET[a] as Vector3) + (World.STREET[a + 1] as Vector3)) * 0.5)
	spots.append(Vector3(62.0, 0.0, 44.0))  # the spawn
	spots.append(Vector3(31.0, 0.0, 42.5))  # the gate
	for d: Array in VillageHouses.doors():
		var at: Vector2 = d[0] + (d[1] as Vector2) * 0.6
		spots.append(Vector3(at.x, 0.0, at.y))
	for node in world.find_children("*", "Node3D", true, false):
		if node is QuestGiver:
			spots.append((node as Node3D).global_position)
	var blocked: Array[String] = []
	var probe := SphereShape3D.new()
	probe.radius = 0.45
	for s in spots:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = probe
		q.transform = Transform3D(Basis.IDENTITY, Vector3(s.x, Terrain.height(s.x, s.z) + 0.9, s.z))
		q.collision_mask = 1
		for hit: Dictionary in space.intersect_shape(q, 8):
			if hit["rid"] == body.get_rid():
				blocked.append("(%.0f, %.0f)" % [s.x, s.z])
				break
	_check("the street, spawn, gate, doors and quest givers are clear", blocked.is_empty(), ", ".join(blocked))

	# The cobbles are laid and no grass grows through them.
	_check("the square is cobbled", props.get_node_or_null("Plaza") != null)
	var grass_on := 0
	var meadows := world.find_children("*", "Meadows", true, false)
	var no_ponds: Array[Marsh] = []
	if not meadows.is_empty():
		for p in 200:
			var at := VillageProps.PLAZA.position + Vector2(randf(), randf()) * VillageProps.PLAZA.size
			if not (meadows[0] as Meadows)._site(at, no_ponds, null, null).is_empty():
				grass_on += 1
	_check("no grass on the cobbles", grass_on == 0, "%d of 200" % grass_on)
	_finish()


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
