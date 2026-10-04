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
	# The billboard keeps the node's scale (without it the dot was drawn off a
	# 1 m quad whatever its size said), and at 12 m its quad is under half a
	# metre: the dot itself (a quarter of the quad) some 8-9 px at 1280 wide.
	var mat := marker.material_override as StandardMaterial3D if marker != null else null
	_check("the mark is small: its size counts, under 0.5 m at 12 m",
			mat != null and mat.billboard_keep_scale and marker.size + marker.grow_with_range * 12.0 < 0.5,
			"" if marker == null else "%.2f m" % (marker.size + marker.grow_with_range * 12.0))
	if marker != null:
		for i in 30:
			await process_frame
		_check("and it sits on the part the lock is on",
				marker.global_position.distance_to(TargetPoints.of(big)[0]) < 0.3,
				"%.2f m off" % marker.global_position.distance_to(TargetPoints.of(big)[0]))
	await _retarget_on_kill(player)
	print("target_parts_test: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)


## Three wolves round him, the lock on one: killed, the lock goes on to the
## one that stood nearest it, not to the one nearest him.
func _retarget_on_kill(player: Player) -> void:
	var wolves: Array[Wolf] = []
	for e in get_nodes_in_group_sorted("enemy"):
		if e is Wolf and wolves.size() < 3:
			wolves.append(e)
	for node in get_nodes_in_group("enemy"):
		(node as Node).set_physics_process(false)
		# Everything else well out of reach, under the ground.
		if not (node is Wolf and wolves.has(node as Wolf)):
			(node as Node3D).global_position += Vector3(0.0, -120.0, 0.0)
	_check("three wolves to fight", wolves.size() == 3, "%d" % wolves.size())
	if wolves.size() < 3:
		return
	var at := player.global_position
	wolves[0].global_position = at + Vector3(0.0, 0.0, -6.0)
	wolves[1].global_position = at + Vector3(4.0, 0.0, -7.5)
	wolves[2].global_position = at + Vector3(-2.5, 0.0, -2.0)
	await physics_frame
	player.call("_hold_target", wolves[0])
	await physics_frame
	wolves[0].call("_die")
	for i in 3:
		await physics_frame
	_check("killed, the lock goes on to the one that stood nearest it",
			player.target == wolves[1], str(player.target.name if player.target != null else "none"))
	wolves[1].call("_die")
	wolves[2].global_position = at + Vector3(0.0, 0.0, -60.0)
	for i in 3:
		await physics_frame
	_check("with none left in reach it lets go", player.target == null,
			str(player.target.name if player.target != null else "none"))


func get_nodes_in_group_sorted(group: String) -> Array[Node]:
	var out := get_nodes_in_group(group)
	out.sort_custom(func(a, b): return String(a.name) < String(b.name))
	return out


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
