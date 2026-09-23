extends SceneTree

## The wood's trunks: every collider is the trunk and no more, so the player
## can walk anywhere under the branches he can see through.
##
##     godot --path . --headless --script res://tests/forest_test.gd

var _failures := 0


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var forest := world.find_child("Forest", true, false) as Forest
	_check("there is a wood", forest != null)
	if forest == null:
		_finish()
		return
	var widest := 0.0
	var count := 0
	for body: StaticBody3D in forest._bodies.values():
		for owner_id in body.get_shape_owners():
			for k in body.shape_owner_get_shape_count(owner_id):
				var shape := body.shape_owner_get_shape(owner_id, k) as CylinderShape3D
				if shape != null:
					widest = maxf(widest, shape.radius)
					count += 1
	_check("the wood still has trunks to walk into", count > 300, "%d" % count)
	_check("no trunk collider is wider than the biggest trunk", widest < 1.5, "widest %.2f m" % widest)

	# Every species: its collider sits on the foot of its own trunk.
	for group in [Forest.CANOPY, Forest.HEDGEROW]:
		for model: Dictionary in group["models"]:
			var mesh := load(model["path"]) as Mesh
			var base: Array = forest._trunk_base(mesh)
			var box := mesh.get_aabb()
			var name := String(model["path"]).get_file()
			_check("%s: trunk %.2f thick at its foot" % [name, float(base[1])],
					float(base[1]) > 0.02 and float(base[1]) < box.size.x * 0.25 + 0.05)
	_finish()


func _finish() -> void:
	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
