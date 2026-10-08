extends SceneTree

## The old graveyard and the dead wood round Arkdeva's lairs ([NecroPlaces]).
##
##     godot --headless --script res://tests/necro_test.gd
##
## Checks that the graveyard's three pieces stand at our scale with their
## floors on the ground, that its walls stop a body and its gate lets one in,
## that the grass keeps off it, that the skeletons hold it, that the wood
## round each lair has gone over to dead trees (and not beyond its reach), and
## that the kit is in our colours and its tombs collide as boxes.

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0


func _initialize() -> void:
	var world: World = load(WORLD).instantiate()
	root.add_child(world)
	await _wait(3)
	var np := world.get_node_or_null("NecroPlaces") as NecroPlaces
	_check("the necro places are built", np != null)
	if np == null:
		_finish()
		return

	# --- the graveyard -------------------------------------------------------
	var yard := np.get_node_or_null("Graveyard") as Node3D
	_check("the graveyard is there", yard != null)
	var pieces := 0
	for piece in NecroPlaces.GRAVEYARD:
		var chunk := yard.get_node_or_null("Chunk_%s" % piece[0]) as Node3D if yard != null else null
		if chunk == null:
			continue
		pieces += 1
		_check("%s at the kit's scale" % piece[0], is_equal_approx(chunk.scale.x, NecroPlaces.KIT_SCALE))
	_check("all three pieces stand", pieces == NecroPlaces.GRAVEYARD.size(), "%d" % pieces)
	var space := world.get_world_3d().direct_space_state
	await _wait(2)
	# Into the walled yard across its north wall: something stops the ray.
	var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(96.0, 1.0, -140.0), Vector3(96.0, 1.0, -150.0)))
	_check("its walls stop a body", not across.is_empty())
	# In at the gate, along the track's last stretch: nothing in the way.
	var gate := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(62.0, 1.0, -157.0), Vector3(77.0, 1.0, -157.0)))
	_check("its gate lets one in", gate.is_empty(), str(gate.get("position", "")))
	_check("the grass keeps off it", NecroPlaces.blocks(Vector2(88.0, -158.0))
			and NecroPlaces.blocks(Vector2(90.0, -180.0)) and not NecroPlaces.blocks(Vector2(40.0, -158.0)))
	var skeletons := 0
	for body in world.get_node("Enemies").get_children():
		if String(body.name).begins_with("Skeleton") \
				and Vector2((body as Node3D).global_position.x, (body as Node3D).global_position.z) \
				.distance_to(Vector2(88.0, -158.0)) < 20.0:
			skeletons += 1
	_check("six skeletons keep it", skeletons == 6, "%d" % skeletons)
	# (out of the way of the ray that follows: the mage stands in the middle)
	for body in world.get_node("Enemies").get_children():
		if String(body.name).begins_with("Skeleton"):
			body.queue_free()
	await _wait(2)
	# Down onto the yard where the skeletons stand: the floor is the ground's,
	# not the kit's plinth (2.5 m up before it was sunk).
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(93.0, 6.0, -153.0), Vector3(93.0, -3.0, -153.0)))
	_check("the yard's floor is at the ground", not down.is_empty()
			and absf((down["position"] as Vector3).y - Terrain.height(93.0, -153.0)) < 0.3,
			str(down.get("position", "")))

	# --- the dead wood -------------------------------------------------------
	_check("a lair's core is all dead", NecroPlaces.dead_chance(NecroPlaces.LAIRS[0]) == 1.0
			and NecroPlaces.dead_chance(NecroPlaces.LAIRS[1] + Vector2(NecroPlaces.DEAD_CORE - 1.0, 0.0)) == 1.0)
	_check("and past its reach nothing is", NecroPlaces.dead_chance(
			NecroPlaces.LAIRS[0] + Vector2(0.0, NecroPlaces.DEAD_REACH + 1.0)) == 0.0)
	_check("dead trees are drawn", np.find_children("Dead_*", "MultiMeshInstance3D", true, false).size() >= 1)
	# A MultiMesh keeps its transforms in the renderer, and the headless one
	# keeps none: which trees went over is only there to read with a window.
	if DisplayServer.get_name() != "headless":
		_check("the wood round the lairs is dead", np.swapped > 60, "%d trees swapped" % np.swapped)
		var forest := world.get_node("Forest") as Forest
		var living_near := 0
		var living_far := 0
		for group in forest.get_children():
			if not String(group.name).begins_with("Canopy"):
				continue
			for node in group.find_children("*", "MultiMeshInstance3D", true, false):
				var mmi := node as MultiMeshInstance3D
				for i in mmi.multimesh.instance_count:
					var t := mmi.multimesh.get_instance_transform(i)
					var at := mmi.global_transform * t.origin
					var d := 1e9
					for lair in NecroPlaces.LAIRS:
						d = minf(d, Vector2(at.x, at.z).distance_to(lair))
					var alive := t.basis.get_scale().x > 0.01
					if alive and d < NecroPlaces.DEAD_CORE:
						living_near += 1
					if alive and d > NecroPlaces.DEAD_REACH and d < NecroPlaces.DEAD_REACH + 20.0:
						living_far += 1
		_check("no living tree in a lair's core", living_near == 0, "%d" % living_near)
		_check("the wood beyond its reach is alive", living_far > 20, "%d" % living_far)

	# --- our colours --------------------------------------------------------
	_check("the kit is in our colours", float(np.material.get_shader_parameter(&"ours")) == 1.0)
	_check("its tombs collide as boxes, filed by patch", yard != null
			and yard.find_children("Tombs_*", "StaticBody3D", false, false).size() >= 4)
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
