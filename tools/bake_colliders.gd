extends SceneTree

## Works out the convex hulls for the scenery once and writes them down.
##
##     godot --path . --headless --script res://tools/bake_colliders.gd
##
## Run it again whenever one of the models below is re-exported. Without a bake
## the game still runs — [SimpleCollision] falls back to bounding boxes — it
## just loses the shape of anything that has one, which for a sloped roof means
## the player standing on a block in mid-air above it.
##
## QuickHull over the house takes about a second, which is why this is a tool
## and not something `_ready()` does.

## Which model, which node in the world scene it is instanced under, and where
## the bake goes. The node path is what the hulls are keyed by, so it has to be
## the same node the [SimpleCollision] script sits on.
const MODELS := [
	{
		"scene": "res://scenes/world/greybox_world.tscn",
		"under": "Level/House",
		"into": "res://assets/house/house_hulls.tres",
	},
	{
		"scene": "res://scenes/world/greybox_world.tscn",
		"under": "Level/Cart",
		"into": "res://assets/uremi /cart_hulls.tres",
	},
]


func _initialize() -> void:
	var world: Node = load(MODELS[0]["scene"] as String).instantiate()
	for model in MODELS:
		_bake(world, model["under"] as String, model["into"] as String)
	world.free()
	quit()


func _bake(world: Node, under: String, into: String) -> void:
	var group := world.get_node_or_null(NodePath(under)) as Node3D
	if group == null:
		push_error("bake_colliders: no node at '%s'." % under)
		return

	var bake := ColliderBake.new()
	bake.source = under
	var started := Time.get_ticks_msec()
	for body in group.find_children("*", "StaticBody3D", true, false):
		var mesh := SimpleCollision._mesh_beside(body)
		if mesh == null:
			continue
		for node in body.find_children("*", "CollisionShape3D", true, false):
			var shape := node as CollisionShape3D
			# Cleaned and simplified: the hull of a plank does not need every
			# vertex of the plank, and the points are what gets saved.
			var hull := mesh.create_convex_shape(true, true)
			if hull == null or hull.points.size() < 4:
				continue
			bake.paths.append(String(group.get_path_to(shape)))
			bake.hulls.append(hull.points)

	var err := ResourceSaver.save(bake, into)
	if err != OK:
		push_error("bake_colliders: could not write '%s' (%d)." % [into, err])
		return
	var points := 0
	for hull in bake.hulls:
		points += hull.size()
	print("%s -> %s: %d hulls, %d points, %d ms" % [under, into,
			bake.hulls.size(), points, Time.get_ticks_msec() - started])
