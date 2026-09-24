extends SceneTree

## The marsh the map grew by, and the misty village in it.
##
##     godot --headless --script res://tests/marsh_test.gd
##
## Checks that the ground past the old south wall is there to be walked on, that
## the mere is wadeable rather than a hole or a wall, that the island and its
## houses are solid — as hulls, not as a trimesh per plank — and that standing
## in the village does not cost a physics tick more than standing anywhere else.

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

	var marsh := world.get_node_or_null("Marsh") as Marsh
	_check("the level has a marsh", marsh != null)
	if marsh == null:
		_finish()
		return
	var village := marsh.get_node_or_null("MistVillage") as MistVillage
	_check("and a village in it", village != null)

	# --- The song over the mere -----------------------------------------------
	var song := world.get_node_or_null("MarshSong") as MarshSong
	_check("the mere has its song", song != null)
	if song != null and village != null:
		var music := root.get_node_or_null("Music")
		_check("quieter than the music", music == null or song.volume_db < float(music.get("volume_db")),
				"%.1f dB" % song.volume_db)
		_check("silent away from the marsh", song.step == MarshSong.Step.WAITING and not song.is_inside())
		player.global_position = _find_open_water(marsh, village) + Vector3(0.0, 1.0, 0.0)
		await _wait(30)
		_check("the first passage plays on coming into the marsh",
				song.is_inside() and song.step == MarshSong.Step.FIRST, "step %d" % song.step)
		song.call("_on_finished")
		_check("then a pause of 5 to 10 s", song.step == MarshSong.Step.GAP
				and song.get("_gap_left") >= 5.0 and song.get("_gap_left") <= 10.0)
		song.set("_gap_left", 0.05)
		await _wait(10)
		_check("then the second", song.step == MarshSong.Step.SECOND, "step %d" % song.step)
		player.global_position = Vector3(20.0, 0.3, 20.0)
		await _wait(30)
		_check("it fades out on leaving and does not start again at once",
				not song.is_inside() and song.step == MarshSong.Step.DONE, "step %d" % song.step)

	# --- The map is bigger ---------------------------------------------------
	# The old south wall stood at z = -119.5. Run south across where it was.
	# Down the ride that comes out on the mere's north shore, where the wood
	# has been kept back — elsewhere along that line a trunk may well stand.
	player.global_position = Vector3(28.0, 0.3, -112.0)
	player.velocity = Vector3.ZERO
	await _settle(player)
	for i in 200:
		player.velocity.x = 0.0
		player.velocity.z = -7.0
		await physics_frame
	var blocker := ""
	if player.global_position.z > -124.0:
		var space := player.get_world_3d().direct_space_state
		var ahead := player.global_position + Vector3(0.0, 0.8, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				ahead, ahead + Vector3(0.0, 0.0, -2.0), 1))
		blocker = str(hit.get("collider")) if not hit.is_empty() else "nothing"
	_check("the old south wall is gone", player.global_position.z < -124.0,
			"stopped at z = %.1f against %s" % [player.global_position.z, blocker])
	await _settle(player)
	_check("and the ground carries on past it at the same height",
			player.is_on_floor() and absf(player.global_position.y) < 0.1,
			"y = %.3f" % player.global_position.y)

	# The south wall, past the bay at the far end of the map. Along its east
	# edge the bay's shore is dry land, so there is ground up to the wall.
	player.global_position = Vector3(116.0, 0.3, -446.0)
	player.velocity = Vector3.ZERO
	await _settle(player)
	for i in 90:
		player.velocity.z = -7.0
		await physics_frame
	_check("the map still ends somewhere", player.global_position.z > -455.5,
			"got to z = %.1f" % player.global_position.z)

	# --- The mere ------------------------------------------------------------
	# Out in open water between the shore and the island: the player stands on
	# the bed, which is below the surface, so they are wading.
	var wade := _find_open_water(marsh, village)
	player.global_position = wade + Vector3(0.0, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	await _settle(player)
	var bed := marsh.height_at(wade.x, wade.z)
	_check("the mere has a floor to wade on", player.is_on_floor()
			and absf(player.global_position.y - bed) < 0.25,
			"y = %.2f over a bed at %.2f" % [player.global_position.y, bed])
	_check("and it is under the water", player.global_position.y < marsh.water_level - 0.3,
			"feet at %.2f, water at %.2f" % [player.global_position.y, marsh.water_level])
	_check("but not over the player's head",
			marsh.water_level - player.global_position.y < 1.0,
			"%.2f m deep" % (marsh.water_level - player.global_position.y))

	# Wading is walking: the player can cross the mere.
	var from := player.global_position
	for i in 60:
		player.velocity.x = 0.0
		player.velocity.z = 5.0
		await physics_frame
	_check("the player can wade across it", player.global_position.distance_to(from) > 3.0,
			"moved %.2f m" % player.global_position.distance_to(from))

	# --- The island and its houses --------------------------------------------
	var shapes := {"hull": 0, "trimesh": 0}
	if village != null:
		for node in village.find_children("*", "CollisionShape3D", true, false):
			var shape := (node as CollisionShape3D).shape
			if shape is ConvexPolygonShape3D:
				shapes["hull"] += 1
			elif shape is ConcavePolygonShape3D:
				shapes["trimesh"] += 1
	_check("the houses, trees and rocks collide as hulls", shapes["hull"] >= 60,
			"%d hulls" % shapes["hull"])
	_check("and only the island's ground is a trimesh", shapes["trimesh"] == 1,
			"%d trimeshes" % shapes["trimesh"])

	var top := _island_ground(world, village)
	_check("there is island to stand on", top != Vector3.INF)
	if top != Vector3.INF:
		player.global_position = top + Vector3(0.0, 0.6, 0.0)
		player.velocity = Vector3.ZERO
		await _settle(player)
		_check("the island holds the player up", player.is_on_floor()
				and player.global_position.y > marsh.water_level + 0.5,
				"y = %.2f" % player.global_position.y)

	# And it can be got onto from the water, the way a player would: walk at it
	# and jump. The island's rim stands a metre or so out of the mere.
	if top != Vector3.INF:
		var shore := _water_beside(marsh, village, top)
		player.global_position = shore + Vector3(0.0, 0.8, 0.0)
		player.velocity = Vector3.ZERO
		await _settle(player)
		var toward := top - player.global_position
		player.camera_rig.rotation.y = atan2(-toward.x, -toward.z)
		Input.action_press("move_forward")
		for i in 240:
			if i % 25 == 5:
				Input.action_press("jump")
			elif i % 25 == 12:
				Input.action_release("jump")
			await physics_frame
			if player.is_on_floor() and player.global_position.y > marsh.water_level + 0.9:
				break
		Input.action_release("move_forward")
		Input.action_release("jump")
		await _settle(player)
		_check("the island can be climbed onto out of the water",
				player.global_position.y > marsh.water_level + 0.9,
				"from %.2f, got to y = %.2f" % [shore.y, player.global_position.y])
		player.camera_rig.rotation.y = 0.0

	# A house is solid: run at the middle of one and do not come out inside it.
	var house := _house_centre(village)
	if house != Vector3.INF:
		var out := Vector3(village.global_position.x - house.x, 0.0, village.global_position.z - house.z)
		var start := house + out.normalized() * 9.0
		player.global_position = start + Vector3(0.0, 2.5, 0.0)
		player.velocity = Vector3.ZERO
		await _settle(player)
		for i in 120:
			var toward := (house - player.global_position)
			toward.y = 0.0
			toward = toward.normalized() * 6.0
			player.velocity.x = toward.x
			player.velocity.z = toward.z
			await physics_frame
		var flat := Vector2(player.global_position.x - house.x, player.global_position.z - house.z)
		_check("a house cannot be walked into", flat.length() > 1.2,
				"%.2f m from its middle" % flat.length())

	# --- What it costs ---------------------------------------------------------
	if top != Vector3.INF:
		var there := await _tick_cost(player, top + Vector3(0.0, 0.6, 0.0))
		var away := await _tick_cost(player, Vector3(20.0, 0.3, 20.0))
		_check("a physics tick in the village costs what one anywhere else does",
				there < 6.0 and there < away * 2.5 + 0.5,
				"%.2f ms in the village, %.2f on the plain" % [there, away])

	_finish()


## A point over open water that is not the island: walked out from the middle of
## the mere until a ray down meets the marsh's own ground rather than the village.
func _find_open_water(marsh: Marsh, village: Node3D) -> Vector3:
	var space := (marsh.get_world_3d() as World3D).direct_space_state
	for step in range(8, 44, 2):
		for angle: float in [0.0, PI * 0.5, PI, PI * 1.5, PI * 0.25, PI * 0.75]:
			var at := marsh.mere_centre + Vector2(cos(angle), sin(angle)) \
					* marsh.mere_radii * (float(step) / 50.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					Vector3(at.x, 20.0, at.y), Vector3(at.x, -5.0, at.y)))
			if hit.is_empty():
				continue
			if village != null and village.is_ancestor_of(hit["collider"]):
				continue
			if marsh.height_at(at.x, at.y) < -0.8:
				return Vector3(at.x, marsh.height_at(at.x, at.y), at.y)
	return Vector3(marsh.mere_centre.x, -1.0, marsh.mere_centre.y + marsh.mere_radii.y * 0.8)


## A point in the water a little way from an island point, walked out from the
## village's middle or in towards it, whichever finds water first.
func _water_beside(marsh: Marsh, village: Node3D, on_island: Vector3) -> Vector3:
	var space := (marsh.get_world_3d() as World3D).direct_space_state
	var out := on_island - village.global_position
	out.y = 0.0
	out = out.normalized()
	for step in range(1, 30):
		for sign: float in [1.0, -1.0]:
			var at := on_island + out * sign * step * 0.5
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					at + Vector3(0.0, 30.0, 0.0), at + Vector3(0.0, -5.0, 0.0)))
			if hit.is_empty() or village.is_ancestor_of(hit["collider"]):
				continue
			if marsh.height_at(at.x, at.z) < marsh.water_level - 0.3:
				return Vector3(at.x, marsh.height_at(at.x, at.z), at.z)
	return on_island


## A point on the island's own ground (the trimesh), found by looking down.
func _island_ground(world: Node3D, village: Node3D) -> Vector3:
	if village == null:
		return Vector3.INF
	var space := (world.get_world_3d() as World3D).direct_space_state
	var middle := village.global_position
	for r in range(10, 26, 2):
		for k in 24:
			var a := TAU * k / 24.0
			var at := middle + Vector3(cos(a), 0.0, sin(a)) * r
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
					at + Vector3(0.0, 30.0, 0.0), at + Vector3(0.0, -5.0, 0.0)))
			if hit.is_empty():
				continue
			var body := hit["collider"] as Node
			if body != null and body.name.begins_with("island"):
				return hit["position"]
	return Vector3.INF


## The middle of the biggest house hull, at the height of the island's ground.
func _house_centre(village: Node3D) -> Vector3:
	if village == null:
		return Vector3.INF
	var best := Vector3.INF
	var biggest := 0.0
	for node in village.find_children("*", "CollisionShape3D", true, false):
		var shape := (node as CollisionShape3D).shape as ConvexPolygonShape3D
		if shape == null:
			continue
		var box := AABB()
		var first := true
		for p in shape.points:
			var w := (node as Node3D).global_transform * p
			if first:
				box = AABB(w, Vector3.ZERO)
				first = false
			else:
				box = box.expand(w)
		if box.size.x * box.size.z > biggest and box.size.y > 6.0:
			biggest = box.size.x * box.size.z
			best = box.get_center()
			best.y = box.position.y
	return best


func _tick_cost(player: Player, where: Vector3) -> float:
	player.global_position = where
	player.velocity = Vector3.ZERO
	await _wait(40)
	var ticks: Array[float] = []
	for i in 90:
		player.velocity.x = 1.5
		player.velocity.z = 1.5
		await physics_frame
		ticks.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	ticks.sort()
	return ticks[ticks.size() / 2]


func _settle(player: Player) -> void:
	for i in 120:
		await physics_frame
		if player.is_on_floor() and player.velocity.length() < 0.05:
			return


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
