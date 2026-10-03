extends SceneTree

## The lands round the core ([Lands], [LandsPlaces], [Waystones], [LandsMood]).
##
##     godot --headless --path . --script res://tests/lands_test.gd
##
## Checks that the lands are there and meet the core without a step, that the
## floor is the ground that is drawn, that the old walls are gone (a hero walks
## out of the core), that a deep river holds him on its bank but a ford and a
## bridge take him over, that the travelling fires light and carry him, that
## the city's land gate is shut until the mist village's orcs are dead, and
## that each land has its own air.

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _world: World
var _player: Player


func _initialize() -> void:
	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await _wait(1)
	_player = _world.player()
	for creature in _world.find_children("*", "CharacterBody3D", true, false):
		if creature != _player:
			creature.queue_free()
	await _wait(10)

	var lands := Lands.current
	_check("the level has lands round its core", lands != null and lands.covers(200.0, 0.0))
	if lands == null:
		_finish()
		return
	var rim := lands.rim()
	_check("600 × 890 m of them", is_equal_approx(rim.z - rim.x, 600.0) and is_equal_approx(rim.w - rim.y, 890.0),
			"%s" % rim)
	_check("but not in the core", not lands.covers(0.0, 0.0) and not lands.covers(100.0, -300.0))

	# --- the seam ---------------------------------------------------------------
	var worst := 0.0
	var terrain := Terrain.current
	for z in range(-118, 178, 2):
		for side: float in [-1.0, 1.0]:
			worst = maxf(worst, absf(terrain.height_at(side * 120.0, float(z)) - lands.height_at(side * 120.0, float(z))))
	for x in range(-118, 118, 2):
		worst = maxf(worst, absf(terrain.height_at(float(x), 180.0) - lands.height_at(float(x), 180.0)))
	_check("the lands meet the core without a step", worst < 0.05, "worst %.2f m" % worst)

	# --- the floor is the drawn ground ----------------------------------------
	var space := _world.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var off := 0.0
	var tried := 0
	while tried < 60:
		var x := rng.randf_range(-295.0, 295.0)
		var z := rng.randf_range(-465.0, 415.0)
		if not lands.covers(x, z) or lands.water_at(x, z) > -INF:
			continue
		tried += 1
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 300.0, z), Vector3(x, -60.0, z))
		q.collision_mask = 1
		# only the ground: not the trees, the stones or what stands on it
		q.exclude = _not_ground()
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			off = INF
			break
		off = maxf(off, absf(float(hit.position.y) - lands.height_at(x, z)))
	# (a grid drawn in triangles is not quite the bilinear height between them)
	_check("the floor is the ground that is drawn", off < 0.15, "worst %.3f m" % off)

	# --- walking ---------------------------------------------------------------
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	var walker := _walker()
	# out of the core by its old west gate, where the wall was
	var gate: Array = lands.info.get("side_gates", {}).get("west", [124.0, 50.0])
	var out_to := Vector2(float(gate[0]) + 22.0, float(gate[1]))
	var got := await _walk(walker, Vector2(98.0, float(gate[1])), out_to, 600)
	_check("a hero walks out of the core, through where the wall was", got.distance_to(out_to) < 3.0,
			"stopped at %s" % got)
	# at the Black River, east of the core, where it is deep
	got = await _walk(walker, Vector2(-128.0, -160.0), Vector2(-172.0, -160.0), 600)
	_check("a deep river holds him on its bank", got.x > -152.0, "got to x %.1f" % got.x)
	for c: Dictionary in lands.crossings:
		var kind := String(c["kind"])
		if not kind in ["ford", "log_bridge", "arched_stone_bridge", "plank_bridge", "rope_bridge"]:
			continue
		var a: Vector3 = c["a"]
		var b: Vector3 = c["b"]
		var from := Vector2(a.x, a.z) + (Vector2(a.x, a.z) - Vector2(b.x, b.z)).normalized() * 2.0
		var to := Vector2(b.x, b.z) + (Vector2(b.x, b.z) - Vector2(a.x, a.z)).normalized() * 2.0
		got = await _walk(walker, from, to, 900)
		_check("over the %s (%s)" % [kind, c["key"]], got.distance_to(to) < 3.0, "stopped at %s, %.1f m short" % [got, got.distance_to(to)])

	# --- the fires ---------------------------------------------------------------
	var ways := _world.get_node_or_null("Waystones") as Waystones
	_check("the travelling fires are there", ways != null and ways.fires.size() >= 17, "%d" % (ways.fires.size() if ways else 0))
	if ways != null:
		_check("the village square's is lit from the start", "tp_core" in ways.lit_keys)
		var far := ""
		for key: String in ways.fires:
			if String(ways.fires[key]["region"]) == "devi":
				far = key
				break
		_check("a cold fire cannot be gone to", not ways.travel(walker, far))
		ways.light(far)
		_check("once lit it can", ways.travel(walker, far))
		var at: Vector3 = ways.fires[far]["at"]
		_check("and he is beside it", Vector2(walker.global_position.x, walker.global_position.z).distance_to(Vector2(at.x, at.z)) < 6.0)

	# --- the city's gate ---------------------------------------------------------
	var places := _world.get_node_or_null("LandsPlaces") as LandsPlaces
	_check("the lands' places are put up", places != null and int(places.counts.get("landmarks", 0)) > 30
			and int(places.counts.get("crossings", 0)) >= 7, "%s" % (places.counts if places else {}))
	if places != null:
		# Drawn as batches, not one node a box ([StaticBatch]); everything
		# under it carries a reach for [Graphics] to cap.
		var batched: Dictionary = places.counts.get("batched", {})
		_check("the places' boxes are drawn in batches",
				int(batched.get("pieces", 0)) > 500 and int(batched.get("batches", 0)) * 2 < int(batched.get("pieces", 0)),
				"%s" % batched)
		var unranged := 0
		var meshes := places.find_children("*", "GeometryInstance3D", true, false)
		for node in meshes:
			if not node.has_meta(&"designed_range"):
				unranged += 1
		_check("every one of them has a reach", meshes.size() > 0 and unranged == 0, "%d of %d" % [unranged, meshes.size()])
		var land_gate := places.get_node_or_null("LandGate")
		_check("the land gate is left out of them", land_gate != null and land_gate.get_child_count() > 0)
		var hidden := _world.get_node_or_null("Occluders")
		_check("the ground and the walls hide what is behind them",
				hidden != null and hidden.get_node_or_null("Ground") != null
				and int(Occluders.last_counts.get("boxes", 0)) > 50, "%s" % Occluders.last_counts)
		_check("the city's land gate is shut", places.land_gate_shut())
		places.open_land_gate()
		await _wait(2)
		_check("until the mist village is taken", not places.land_gate_shut())

	# --- the air ---------------------------------------------------------------
	var mood := _world.get_node_or_null("LandsMood") as LandsMood
	_check("the air knows the lands", mood != null and mood.region_at(0, 0) == 0 and mood.region_at(-230, -330) == 4
			and mood.region_at(220, 120) == 1 and mood.region_at(-220, 150) == 3)
	if mood != null:
		var w := mood.weights_at(-220.0, -330.0)
		var total := 0.0
		for v in w:
			total += v
		_check("and mixes them by where he is", is_equal_approx(total, 1.0) and w[4] > 0.9)
	_finish()


## Everything on the world layer that is not the ground: trunks, stones, the
## places, the buildings.
func _not_ground() -> Array[RID]:
	var out: Array[RID] = []
	for body in _world.find_children("*", "StaticBody3D", true, false):
		if body is Lands or body is Terrain:
			continue
		if body.get_parent() is Marsh:
			continue
		out.append((body as StaticBody3D).get_rid())
	return out


func _walker() -> CharacterBody3D:
	var walker := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.8
	capsule.shape = cs
	capsule.position.y = 0.9
	walker.add_child(capsule)
	walker.floor_max_angle = _player.floor_max_angle
	walker.floor_snap_length = _player.floor_snap_length
	_world.add_child(walker)
	return walker


func _walk(walker: CharacterBody3D, from: Vector2, to: Vector2, frames: int) -> Vector2:
	walker.global_position = Vector3(from.x, Terrain.height(from.x, from.y) + 0.6, from.y)
	walker.velocity = Vector3.ZERO
	await physics_frame
	var speed := _player.run_speed
	for i in frames:
		await physics_frame
		var here := Vector2(walker.global_position.x, walker.global_position.z)
		var left := to - here
		if left.length() < 1.0:
			break
		var dir := Vector3(left.x, 0.0, left.y).normalized()
		walker.velocity.x = dir.x * speed
		walker.velocity.z = dir.z * speed
		walker.velocity.y = 0.0 if walker.is_on_floor() else walker.velocity.y - 20.0 / 60.0
		walker.move_and_slide()
	return Vector2(walker.global_position.x, walker.global_position.z)


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
