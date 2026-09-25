extends SceneTree

## The land of the old square, no longer flat ([Terrain]).
##
##     godot --headless --script res://tests/terrain_test.gd
##
## Checks that there is relief worth the name, that it is dead level where
## things were put down on the old flat box, that the floor the bodies stand on
## is the ground that is drawn, that the tracks do not climb anything steep,
## that it meets the marsh strip without a step, that trees stand on it rather
## than in the air or under it, and that a hero can walk up a hill.

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0


func _initialize() -> void:
	var world: World = load(WORLD).instantiate()
	root.add_child(world)
	await _wait(1)
	var player: Player = world.player()
	for creature in world.find_children("*", "CharacterBody3D", true, false):
		if creature != player:
			creature.queue_free()
	await _wait(10)

	var land := Terrain.current
	_check("the level stands on terrain", land != null)
	if land == null:
		_finish()
		return
	var half := land.half_size

	# --- relief ---------------------------------------------------------------
	var top := -INF
	var low := INF
	var x := -half
	while x <= half:
		var z := -half
		while z <= half:
			var h := land.height_at(x, z)
			top = maxf(top, h)
			low = minf(low, h)
			z += 2.0
		x += 2.0
	_check("there are hills", top > 6.0, "highest %.1f m" % top)
	_check("and hollows", low < -1.0, "lowest %.1f m" % low)
	_check("but nothing mountainous", top < 16.0 and low > -6.0, "%.1f .. %.1f" % [low, top])

	# --- flat where things stand ----------------------------------------------
	var worst := 0.0
	for mark in world.get_node("SpawnPoints").get_children():
		var at := (mark as Node3D).global_position
		worst = maxf(worst, absf(land.height_at(at.x, at.z)))
	_check("the spawn is level with the old ground", worst < 0.03, "%.3f m" % worst)
	worst = 0.0
	var worst_at := ""
	var village := world.get_node_or_null("Level/Village") as Node3D
	if village != null:
		for mi in village.find_children("*", "MeshInstance3D", true, false):
			if "Fence" in str(mi.get_path()) or "Villager" in str(mi.get_path()):
				continue  # put down after, or walking about: both follow the ground
			var box := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			if box.size.x > 100.0 or box.size.z > 100.0:
				continue
			var at := box.get_center()
			if absf(land.height_at(at.x, at.z)) > worst:
				worst = absf(land.height_at(at.x, at.z))
				worst_at = str(mi.get_path()).get_slice("Village/", 1) + " " + str(at)
	_check("so is the settlement", worst < 0.05, "%.3f m at %s" % [worst, worst_at])
	var tower := world.get_node_or_null("Level/Tower") as Node3D
	if tower != null:
		_check("and the tower", absf(land.height_at(tower.global_position.x, tower.global_position.z)) < 0.05)
	worst = 0.0
	for camp: Array in World.CAMPS:
		var c: Vector2 = camp[1]
		if absf(c.x) < half and absf(c.y) < half:
			worst = maxf(worst, absf(land.height_at(c.x, c.y)))
	_check("and every camp", worst < 0.05, "%.3f m" % worst)

	# --- the floor is the ground ----------------------------------------------
	var space := world.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var off := 0.0
	var missed := 0
	for i in 300:
		var px := rng.randf_range(-half + 1.0, half - 1.0)
		var pz := rng.randf_range(-half + 1.0, half - 1.0)
		var ray := PhysicsRayQueryParameters3D.create(Vector3(px, 60.0, pz), Vector3(px, -30.0, pz))
		ray.collision_mask = land.collision_layer
		ray.exclude = []
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit["collider"] != land:
			# something else stands there (a house, a rock): look under it
			ray.exclude = [hit["rid"]] if not hit.is_empty() else []
			hit = space.intersect_ray(ray)
		if hit.is_empty():
			missed += 1
			continue
		if hit["collider"] == land:
			off = maxf(off, absf((hit["position"] as Vector3).y - land.height_at(px, pz)))
	_check("what is walked on is what is drawn", off < 0.12 and missed == 0,
			"%.3f m off, %d rays through" % [off, missed])

	# --- tracks ---------------------------------------------------------------
	var paths := world.get_node_or_null("Paths") as Paths
	var steepest := 0.0
	if paths != null:
		for line: PackedVector2Array in paths.tracks:
			for i in line.size() - 1:
				var a := line[i]
				var b := line[i + 1]
				var n := maxi(1, ceili(a.distance_to(b)))
				for k in n:
					var p := a.lerp(b, float(k) / n)
					var q := a.lerp(b, float(k + 1) / n)
					if absf(p.x) > half or absf(p.y) > half:
						continue
					var rise := absf(land.height_at(q.x, q.y) - land.height_at(p.x, p.y))
					steepest = maxf(steepest, rise / maxf(p.distance_to(q), 0.01))
	_check("no track climbs steeper than 1 in 4", steepest < 0.25, "%.2f" % steepest)

	# --- the seam with the marsh ----------------------------------------------
	worst = 0.0
	x = -half
	while x <= half:
		worst = maxf(worst, absf(land.height_at(x, -half + 0.5)))
		x += 3.0
	_check("it meets the marsh strip at its height", worst < 0.02, "%.3f m" % worst)

	# --- trees on the ground --------------------------------------------------
	# (Their drawn instances are not kept by a headless renderer; the trunks'
	# colliders are put down at the same height, and they are what one walks
	# into.)
	var floating := 0
	var buried := 0
	var trees := 0
	var forest := world.get_node_or_null("Forest") as Forest
	if forest != null:
		for body in forest.find_children("*", "StaticBody3D", true, false):
			var sb := body as StaticBody3D
			for owner_id in sb.get_shape_owners():
				var shape := sb.shape_owner_get_shape(owner_id, 0) as CylinderShape3D
				if shape == null:
					continue
				var at := sb.global_transform * sb.shape_owner_get_transform(owner_id).origin
				if absf(at.x) > half - 1.0 or absf(at.z) > half - 1.0:
					continue
				trees += 1
				# sunk by the forest's TRUNK_SINK, on purpose, so its cap is no lip
				var foot := at.y - shape.height * 0.5 + 1.5
				var ground := land.height_at(at.x, at.z)
				if foot > ground + 0.05:
					floating += 1
				elif foot < ground - 0.6:
					buried += 1
	_check("tree trunks stand on the ground", trees > 50 and floating == 0 and buried == 0,
			"%d looked at, %d floating, %d buried" % [trees, floating, buried])

	# --- a hero walks up a hill -------------------------------------------------
	var hill := Vector2.ZERO
	var best := -INF
	for f in land.features:
		# out in the open fields (east), not in the wood, where trunks are in the way
		var up := land.height_at(f.x, f.y)
		if up > best and f.x > 0.0 and absf(f.x) < half - 20.0 and absf(f.y) < half - 20.0:
			best = up
			hill = Vector2(f.x, f.y)
	var peak := land.height_at(hill.x, hill.y)
	var start := hill + Vector2(26.0, 0.0)
	# A capsule of the hero's size with his floor settings, walked by hand (the
	# hero himself answers only to input).
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var walker := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.8
	capsule.shape = cs
	capsule.position.y = 0.9
	walker.add_child(capsule)
	walker.floor_max_angle = player.floor_max_angle
	walker.floor_snap_length = player.floor_snap_length
	world.add_child(walker)
	walker.global_position = Vector3(start.x, land.height_at(start.x, start.y) + 0.5, start.y)
	var sunk := false
	var climbed := -INF
	var speed := player.run_speed
	for i in 480:
		await physics_frame
		var here := Vector2(walker.global_position.x, walker.global_position.z)
		var to := hill - here
		if to.length() < 1.5:
			break
		var dir := Vector3(to.x, 0.0, to.y).normalized()
		walker.velocity.x = dir.x * speed
		walker.velocity.z = dir.z * speed
		walker.velocity.y = 0.0 if walker.is_on_floor() else walker.velocity.y - 20.0 / 60.0
		walker.move_and_slide()
		var g := land.height_at(walker.global_position.x, walker.global_position.z)
		sunk = sunk or walker.global_position.y < g - 0.3
		climbed = maxf(climbed, walker.global_position.y)
	_check("a hero walks up the biggest hill", climbed > peak - 1.5 and not sunk,
			"reached %.1f m of %.1f, sunk %s" % [climbed, peak, sunk])

	# --- both looks -------------------------------------------------------------
	_check("the ground has its two looks", land.styles.size() == 2)
	land.set_style(1)
	var chunk := land.get_node_or_null("Chunk_0_0") as MeshInstance3D
	_check("and changes into the other", chunk != null and chunk.material_override == land.styles[1])
	land.set_style(0)
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
