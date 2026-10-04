extends SceneTree

## The village's buildings ([VillageHouses]): every one in the layout is in the
## glb and the json, drawn and standing on the ground, with a collider; none
## stands on the street, the square, the spawn, the gate or a quest giver; a
## house's door opens onto open ground; no two buildings overlap; nothing is
## left of the old kit but the windmill.
##
##     godot --headless --path . --script res://tests/village_houses_test.gd

var _failures := 0


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	for i in 5:
		await physics_frame
	var houses := world.get_node_or_null("Level/Village/Houses") as VillageHouses
	_check("the village has its houses", houses != null)
	if houses == null:
		_finish()
		return

	var info := VillageHouses.info()
	var missing: Array[String] = []
	var drawn := 0
	for entry: Array in VillageHouses.LAYOUT:
		var kind := String(entry[0])
		if not info.has(kind):
			missing.append(kind + " (json)")
		var node := houses.get_node_or_null(kind) as MeshInstance3D
		if node == null or node.mesh == null:
			missing.append(kind + " (model)")
		else:
			drawn += 1
	_check("every building is in the glb and the json", missing.is_empty(), ", ".join(missing))

	# On the ground: a house's floor at the ground under its middle.
	var floating: Array[String] = []
	for entry: Array in VillageHouses.LAYOUT:
		var node := houses.get_node_or_null(String(entry[0])) as Node3D
		if node == null:
			continue
		var g := Terrain.height(node.position.x, node.position.z)
		if absf(node.position.y - g) > 0.6:
			floating.append("%s %.2f vs %.2f" % [entry[0], node.position.y, g])
	_check("each stands on the ground", floating.is_empty(), ", ".join(floating))

	var body := houses.get_node_or_null("HousesBody") as StaticBody3D
	_check("they collide", body != null and body.get_child_count() >= VillageHouses.LAYOUT.size())

	# Open where people walk; the doors open onto open ground.
	var space := world.get_world_3d().direct_space_state
	var spots: Array = []
	for s: Vector3 in World.STREET:
		spots.append(["street", World.spread(s)])
	for m in world.find_children("Mark*", "Marker3D", true, false):
		spots.append(["spawn", (m as Node3D).global_position])
	spots.append(["the gate", Vector3(22.0, 0.0, 43.0)])
	spots.append(["the east gate", Vector3(117.0, 0.0, 50.5)])
	spots.append(["the square", Vector3(VillageProps.PLAZA.get_center().x, 0.0, VillageProps.PLAZA.get_center().y)])
	for node in world.find_children("*", "Node3D", true, false):
		if node is QuestGiver:
			spots.append(["quest giver", (node as Node3D).global_position])
	for d: Array in VillageHouses.doors(false):
		var at: Vector2 = d[0] + (d[1] as Vector2) * 1.0
		spots.append(["a door", Vector3(at.x, 0.0, at.y)])
	var probe := SphereShape3D.new()
	probe.radius = 0.4
	var shut: Array[String] = []
	for s: Array in spots:
		var at: Vector3 = s[1]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = probe
		q.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, Terrain.height(at.x, at.z) + 1.0, at.z))
		q.collision_mask = 1
		for hit: Dictionary in space.intersect_shape(q, 8):
			if body != null and hit["rid"] == body.get_rid():
				shut.append("%s (%.0f, %.0f)" % [s[0], at.x, at.z])
				break
	_check("the street, spawn, gates, square, quest givers and doors are open", shut.is_empty(), ", ".join(shut))

	# No two buildings on the same ground: no corner or middle of one inside
	# another's walls.
	var overlaps: Array[String] = []
	for a in VillageHouses.LAYOUT.size():
		var entry: Array = VillageHouses.LAYOUT[a]
		var data: Dictionary = info.get(String(entry[0]), {})
		if data.is_empty():
			continue
		var xf := VillageHouses.placed(entry)
		var hw: float = float(data["W"]) * 0.5
		var hd: float = float(data["D"]) * 0.5
		for c: Vector3 in [Vector3.ZERO, Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]:
			var p := xf * c
			var b := _owner_of(Vector2(p.x, p.z), a)
			if b >= 0:
				overlaps.append("%s in %s" % [entry[0], VillageHouses.LAYOUT[b][0]])
				break
	_check("no two buildings overlap", overlaps.is_empty(), ", ".join(overlaps))

	# Of the old kit only the windmill is left.
	var old: Array[String] = []
	for child in world.get_node("Level/Village").get_children():
		if child is Building and child.name != &"Windmill":
			old.append(String(child.name))
	_check("only the windmill is left of the old kit", old.is_empty(), ", ".join(old))
	_finish()


## Which layout entry's walls a point is inside (other than `skip`), or -1.
func _owner_of(at: Vector2, skip: int) -> int:
	for i in VillageHouses.LAYOUT.size():
		if i == skip:
			continue
		var entry: Array = VillageHouses.LAYOUT[i]
		var data: Dictionary = VillageHouses.info().get(String(entry[0]), {})
		if data.is_empty():
			continue
		var xf := VillageHouses.placed(entry)
		var local := xf.affine_inverse() * Vector3(at.x, xf.origin.y, at.y)
		var hw: float = float(data["W"]) * 0.5
		var hd: float = float(data["D"]) * 0.5
		if absf(local.x) <= hw and absf(local.z) <= hd:
			return i
	return -1


func _finish() -> void:
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label, ("  — " + detail) if detail != "" else "")
