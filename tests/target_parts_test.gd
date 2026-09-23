extends SceneTree

## The lock on a big creature has parts (legs, belly, head) and a flick up or
## down moves between them; a small one has the one point it always had.
##
##     godot --path . --headless --script res://tests/target_parts_test.gd

var _failures := 0


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await physics_frame
	var player: Player = world.player()
	var big: Node3D = null
	var small: Node3D = null
	for e in get_nodes_in_group_sorted("enemy"):
		var name: String = (e.get_script() as Script).get_global_name() if e.get_script() != null else ""
		if big == null and name in ["OrcWarrior", "Arkdeva"]:
			big = e
		if small == null and name == "Fighter" and TargetPoints.of(e).size() == 1:
			small = e
	_check("there is a big creature to lock on to", big != null, "")
	if big == null:
		quit(1)
		return
	var parts := TargetPoints.of(big)
	_check("a big one has three parts", parts.size() == 3, "%d" % parts.size())
	if parts.size() == 3:
		_check("legs, then belly, then head, bottom to top",
				parts[0].y < parts[1].y and parts[1].y < parts[2].y,
				"%.2f %.2f %.2f" % [parts[0].y, parts[1].y, parts[2].y])
	if small != null:
		_check("a small one keeps a single point", TargetPoints.of(small).size() == 1, str(small.name))

	player.global_position = big.global_position + Vector3(0.0, 0.3, 5.0)
	player.call("_hold_target", big)
	_check("a lock lands on the belly", player.target_part == 1, "%d" % player.target_part)
	player.call("_switch_part", 1)
	_check("a flick up takes the head", player.target_part == 2, "%d" % player.target_part)
	var aim: Vector3 = player.call("_aim_point", big)
	_check("and the aim goes to the head", aim.distance_to(TargetPoints.of(big)[2]) < 0.01, "")
	player.call("_switch_part", 1)
	_check("there is nothing above the head", player.target_part == 2, "%d" % player.target_part)
	player.call("_switch_part", -1)
	player.call("_switch_part", -1)
	_check("two flicks down take the legs", player.target_part == 0, "%d" % player.target_part)
	await process_frame
	await process_frame
	var marker := player.find_child("TargetMarker", true, false) as TargetMarker
	_check("the mark is a third of what it was", marker != null and marker.size < 0.035, "")
	if marker != null:
		for i in 30:
			await process_frame
		_check("and it sits on the part the lock is on",
				marker.global_position.distance_to(TargetPoints.of(big)[0]) < 0.3,
				"%.2f m off" % marker.global_position.distance_to(TargetPoints.of(big)[0]))
	print("target_parts_test: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)


func get_nodes_in_group_sorted(group: String) -> Array[Node]:
	var out := get_nodes_in_group(group)
	out.sort_custom(func(a, b): return String(a.name) < String(b.name))
	return out


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
