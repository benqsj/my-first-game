extends SceneTree

## The ground of the core ([GroundCover], and [Meadows]' sward out on the open
## ground): that it is laid, drawn as multimeshes that
## cast no shadow and stop at a distance, that only the fallen logs are solid
## and none of them is on the wolves' hill, that nothing lies in the village,
## and that the open sward keeps off the tracks and the square.
##
##     godot --headless --path . --script res://tests/ground_cover_test.gd

var _failures := 0


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	var meadows := world.get_node("Meadows") as Meadows
	await meadows.grown
	await _wait(2)
	var forest := world.get_node("Forest") as Forest

	for group in ["Ground Litter", "Ground Open", "Ground Logs"]:
		_check("%s grows" % group, int(forest.counts.get(group, 0)) > 0, str(forest.counts.get(group, 0)))
	var litter := int(forest.counts.get("Ground Litter", 0))
	var nodes := forest.get_node("Ground Litter").find_children("*", "MultiMeshInstance3D", true, false)
	var instances := 0
	var bad_draw := 0
	for n in nodes:
		var mm := n as MultiMeshInstance3D
		instances += mm.multimesh.instance_count
		if mm.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or mm.visibility_range_end <= 0.0:
			bad_draw += 1
	_check("every litter instance is drawn", instances == litter, "%d of %d" % [instances, litter])
	_check("litter casts no shadow and stops at a distance", bad_draw == 0, "%d nodes" % bad_draw)

	# Where things lie (the plan: a headless run keeps no multimesh transforms).
	var plan := GroundCover.plan(forest, World.VILLAGE)
	_check("the plan is what was planted", plan["litter"].size() == litter,
			"%d planned, %d planted" % [plan["litter"].size(), litter])
	var in_village := 0
	for list in ["litter", "open", "logs"]:
		for p: Array in plan[list]:
			if World.VILLAGE.has_point(Vector2(p[1], p[2])):
				in_village += 1
	_check("nothing lies in the village", in_village == 0, str(in_village))
	var on_hill := 0
	var solid_else := 0
	for p: Array in plan["logs"]:
		if forest._hill_wood(Vector2(p[1], p[2])) > 0.0:
			on_hill += 1
	for list in ["litter", "open"]:
		for p: Array in plan[list]:
			if p[5]:
				solid_else += 1
	_check("only the logs are solid", solid_else == 0, str(solid_else))
	_check("no fallen log on the wolves' hill", on_hill == 0, str(on_hill))

	# The open sward: there, and off the tracks and the square.
	_check("the sward grows on the open ground", int(meadows.counts.get("open sward", 0)) > 3000,
			str(meadows.counts.get("open sward", 0)))
	var field := world.get_node("Level/Scatter") as Node3D
	var tracks := world.get_node_or_null("Paths") as Paths
	var wrong := 0
	var low := meadows.sward
	for i in range(0, low.size(), GrassField.STRIDE):
		var at := field.to_global(Vector3(low[i], 0.0, low[i + 1]))
		var p := Vector2(at.x, at.z)
		if VillageProps.in_plaza(p) or (tracks != null and tracks.near(p, -0.6)):
			wrong += 1
	_check("no sward on the square or the middle of a track", wrong == 0, str(wrong))
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
