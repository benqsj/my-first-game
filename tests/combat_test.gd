extends SceneTree

## Checks the things that were reported wrong: which way creatures face when
## they walk, that they cannot leave the ground, that the knight cannot walk
## through them, and that a swing takes off whatever limb it passed through.

var _camera: Camera3D
var _failures := 0


func _initialize() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	var world: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	var player: Player = world.get_node("Player")
	var wolf: Wolf = world.get_node("Enemies/Wolf1")
	var golem: Golem = world.get_node("Enemies/Golem1")
	var hunter: Wolf = world.get_node("Enemies/Wolf2")
	# Kept blind *and* still until its own section, and parked out on the far
	# plain: a second wolf wandering into the swings meant for the first one is
	# not what any of these checks are about, and blinding it alone still leaves
	# it prowling around its spawn, which is within reach of them.
	hunter.sight_range = 0.0
	var hunter_prowl := hunter.prowl_speed
	hunter.prowl_speed = 0.0
	hunter.global_position = Vector3(40.0, 0.5, 40.0)
	_camera = Camera3D.new()
	_camera.fov = 42.0
	world.add_child(_camera)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# --- Facing: the model's front should lead the way it travels ------------
	player.global_position = Vector3(0.0, 0.2, 26.0)
	await _facing_check("wolf", wolf, Vector3(6.0, 0.5, -6.0), Vector3(6.0, 0.0, 4.0))
	await _facing_check("golem", golem, Vector3(-6.0, 0.5, -6.0), Vector3(-6.0, 0.0, 4.0))

	# --- The arena is walled in ---------------------------------------------
	# The ground runs to x = 60 and the wall sits just inside it.
	wolf.global_position = Vector3(50.0, 0.5, 0.0)
	wolf.sight_range = 0.0
	wolf.prowl_speed = 0.0
	for i in 20:
		await physics_frame
	wolf.velocity = Vector3(30.0, 0.0, 0.0)
	for i in 90:
		await physics_frame
		wolf.velocity.x = 30.0
	_check("the wolf cannot run off the edge", wolf.global_position.x < 59.0 and wolf.global_position.y > -1.0,
			"at %v" % wolf.global_position)

	# --- The knight cannot walk through them --------------------------------
	golem.global_position = Vector3(6.0, 0.2, 10.0)
	golem.set_physics_process(false)
	player.global_position = Vector3(6.0, 0.2, 14.0)
	player.velocity = Vector3.ZERO
	player.camera_rig.rotation.y = 0.0
	for i in 20:
		await physics_frame
	Input.action_press("move_forward")
	for i in 80:
		await physics_frame
	Input.action_release("move_forward")
	var gap := player.global_position.distance_to(golem.global_position)
	_check("the knight is stopped by a golem", gap > 0.8, "gap %.2f m" % gap)

	# --- A swing takes the limb it passes through ---------------------------
	# The body has to still be there for everything checked below it and for the
	# screenshot at the end of the run, and it goes down partway through the
	# swings — so the linger is pinned open here, before it can start counting.
	# Clearing it away gets a check of its own once that screenshot is taken.
	wolf.corpse_linger = 1000.0
	wolf.global_position = Vector3(-14.0, 0.5, 20.0)
	player.global_position = Vector3(-14.0, 0.2, 21.6)
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	var before := wolf.rig.lost_parts()
	var styles := {}
	for swing in 8:
		wolf.global_position = player.global_position + Vector3(0.0, 0.2, -1.3)
		wolf.velocity = Vector3.ZERO
		var aim := wolf.global_position - player.global_position
		player.rotation.y = atan2(-aim.x, -aim.z)
		for i in 3:
			await physics_frame
		player.rig.attack()
		styles[player.rig.current_swing()] = true
		for i in 34:
			await physics_frame
	# Which limb goes is random, and taking the head ends it there and then, so
	# the count varies — what matters is that cuts land and it goes down.
	_check("swings take limbs off", wolf.rig.lost_parts() - before >= 1,
			"%d limbs" % (wolf.rig.lost_parts() - before))
	_check("the cuts are not all the same", styles.size() >= 3, "%d styles" % styles.size())
	_check("enough limbs put it down", wolf.is_dead)
	_check("the blade is bloodied", player.rig.blade_blood > 0.3, "%.2f" % player.rig.blade_blood)

	var limbs := 0
	for n in Blood.world_of(world).get_children():
		if n is SeveredLimb:
			limbs += 1
	_check("severed limbs drop into the world", limbs >= 1, "%d pieces" % limbs)
	var patches := 0
	for n in Blood.world_of(world).get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is QuadMesh:
			patches += 1
	_check("blood marks the ground", patches >= 3, "%d patches" % patches)

	# --- Severed limbs fall instead of hanging in the air --------------------
	var airborne := 0
	var landed := 0
	for n in Blood.world_of(world).get_children():
		if n is SeveredLimb:
			if (n as Node3D).global_position.y > 0.5:
				airborne += 1
			else:
				landed += 1
	_check("severed limbs end up on the ground", landed > 0 and airborne == 0,
			"%d down, %d still up" % [landed, airborne])

	# --- A corpse does not block the way ------------------------------------
	_check("a corpse stops blocking the player", wolf.collision_layer == 0)
	_check("a corpse stays on the ground", wolf.global_position.y > -1.0,
			"y %.2f" % wolf.global_position.y)

	# --- Health reads out ---------------------------------------------------
	_check("health drains as it is cut", wolf.health < wolf.max_health * 0.5,
			"%.0f / %.0f" % [wolf.health, wolf.max_health])

	# --- It chases and keeps chasing ----------------------------------------
	hunter.sight_range = 20.0
	hunter.prowl_speed = hunter_prowl
	# One of the cleared corridors: the scattered rocks are solid, and a chase
	# that starts wedged against one is not testing the chase.
	hunter.global_position = Vector3(6.0, 0.5, -14.0)
	player.global_position = Vector3(6.0, 0.2, -8.0)
	player.velocity = Vector3.ZERO
	for i in 40:
		await physics_frame
	# It closes 6 m in well under a second, so it may already be swinging.
	_check("it gives chase when approached",
			hunter.state == Wolf.State.CHASE or hunter.state == Wolf.State.FIGHT,
			"state %d" % hunter.state)
	hunter.global_position = Vector3(6.0, 0.5, -16.0)
	for i in 10:
		await physics_frame
	var closing := hunter.global_position.distance_to(player.global_position)
	for i in 150:
		await physics_frame
		if hunter.state == Wolf.State.FIGHT:
			break
	_check("it closes the distance", hunter.global_position.distance_to(player.global_position) < closing,
			"state %d" % hunter.state)

	# Run: it should follow.
	var gap_before := hunter.global_position.distance_to(player.global_position)
	for i in 120:
		player.global_position += Vector3(0.0, 0.0, 0.05)
		await physics_frame
	_check("it follows when the knight runs",
			hunter.global_position.distance_to(player.global_position) < gap_before + 3.0,
			"gap %.1f m" % hunter.global_position.distance_to(player.global_position))
	await _shot("%s/combat_severed.png" % dir, wolf, Vector3(2.4, 1.2, 2.8))

	# --- The body does not lie there forever --------------------------------
	# Cut the linger short rather than waiting out the real one: what is being
	# checked is that the body sinks and leaves, not how long it waits first.
	wolf.corpse_linger = 0.0
	wolf.corpse_sink_time = 0.25
	for i in 120:
		await physics_frame
		if not is_instance_valid(wolf):
			break
	_check("the corpse is cleared away", not is_instance_valid(wolf))

	# --- Creatures get about the world ---------------------------------------
	# The greybox staircase, at x = -10 and climbing towards -z. A hunter that
	# cannot follow you up six steps is one you beat by standing on a step.
	player.global_position = Vector3(-10.0, 1.6, -6.3)
	player.velocity = Vector3.ZERO
	var climber := _spawn_wolf(world, Vector3(-10.0, 0.4, 3.0))
	climber.sight_range = 40.0
	climber.lose_range = 60.0
	await _wait(10)
	var started := climber.global_position.y
	for i in 420:
		await physics_frame
		if climber.global_position.y > started + 1.2:
			break
	_check("a wolf follows the knight up the stairs",
			climber.global_position.y > started + 1.0,
			"climbed %.2f m" % (climber.global_position.y - started))
	climber.queue_free()

	# And they take up room: two of them cannot stand in the same place.
	var one := _spawn_wolf(world, Vector3(6.0, 0.4, 12.0))
	var two := _spawn_wolf(world, Vector3(6.35, 0.4, 12.0))
	for pair in [one, two]:
		pair.sight_range = 0.0
		pair.prowl_speed = 0.0
	player.global_position = Vector3(6.0, 0.2, 20.0)
	await _wait(90)
	_check("wolves get in each other's way",
			one.global_position.distance_to(two.global_position) > 0.8,
			"%.2f m apart" % one.global_position.distance_to(two.global_position))
	one.queue_free()
	two.queue_free()

	print("")
	print("All checks passed." if _failures == 0 else "%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


## Walks a creature to a point and compares where its model looks with where it
## went. Both models are authored facing their own +Z, and `Visuals` is the node
## holding the model, so the front is that node's +Z — not its -Z, which is the
## body's convention and the opposite thing.
func _facing_check(label: String, creature: Node3D, from: Vector3, to: Vector3) -> void:
	creature.global_position = from
	# Blind it and point its own patrol at the target: driving movement from
	# here as well would fight the creature's own decision every frame.
	creature.set("sight_range", 0.0)
	creature.set("rest_time", 0.0)
	creature.set("_wait", 0.0)
	for i in 20:
		await physics_frame
	var travelled := Vector3.ZERO
	for i in 150:
		var before := creature.global_position
		if creature is Wolf:
			creature.set("_prowl_target", to)
			creature.set("_prowl_timer", 99.0)
			creature.set("prowl_speed", 3.0)
		else:
			creature.set("_target", to)
			creature.set("_wait", 0.0)
		await physics_frame
		travelled += creature.global_position - before
	travelled.y = 0.0
	if travelled.length() < 0.5:
		_check("%s moved far enough to judge" % label, false, "%.2f m" % travelled.length())
		return
	var visuals := creature.get_node("Visuals") as Node3D
	var front := visuals.global_transform.basis.z.normalized()
	var alignment := front.dot(travelled.normalized())
	_check("%s walks forwards" % label, alignment > 0.7, "alignment %.2f" % alignment)


func _shot(path: String, target: Node3D, offset: Vector3) -> void:
	var focus := target.global_position + Vector3.UP * 0.8
	_camera.global_position = focus + offset
	_camera.look_at(focus, Vector3.UP)
	_camera.current = true
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _spawn_wolf(world: Node3D, where: Vector3) -> Wolf:
	var wolf: Wolf = load("res://scenes/enemies/wolf.tscn").instantiate()
	world.add_child(wolf)
	wolf.global_position = where
	return wolf


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
