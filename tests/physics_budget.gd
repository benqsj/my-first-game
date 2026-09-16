extends SceneTree

## Says where the physics tick goes, by taking things out of the world one at a
## time and reading what the tick drops by.
##
##     godot --path . --headless --script res://tests/physics_budget.gd
##
## The companion to `draw_budget.gd`, and the one that matters more: a frame the
## renderer is late with is a slow frame, but a frame the *physics* is late with
## is a stutter, because the step cannot be skipped.
##
## `TIME_PHYSICS_PROCESS` covers the whole step — the solver, the queries every
## `move_and_slide` makes, and every `_physics_process` script in the tree. So a
## creature's AI shows up here alongside the colliders it is walking past, which
## is right: both of them are what has to happen before the frame can be drawn.
##
## **Every configuration gets its own freshly loaded world.** The first version
## of this reused one, and the numbers were nonsense: walking the knight into the
## wood to take a reading leaves eight wolves chasing him, and every measurement
## after that is of a fight rather than of the thing being measured. A level load
## is a second; a misleading profile costs rather more than that.
##
## Reported as a median of a long run, never a mean. One slow tick while a level
## settles is not what is being looked for.

const WORLD := "res://scenes/world/greybox_world.tscn"
## Where the knight stands while it is measured. Out on the open ground east of
## the greybox core, which is the ordinary case — not the worst one.
const STAND := Vector3(20.0, 0.3, 20.0)
## And the two worst ones: in among the trees, and at the house — which the wood
## now grows right up to, on top of the forty-odd hulls the house itself carries.
const IN_THE_WOOD := Vector3(-56.0, 0.3, -30.0)
const AT_THE_HOUSE := Vector3(-16.0, 0.3, -13.0)

const SETTLE := 40
const TICKS := 120

## label -> what to switch off before measuring, and where to stand.
const RUNS: Array[Array] = [
	["everything on, out in the open", "", 0],
	["everything on, in among the trees", "", 1],
	["everything on, at the house", "", 2],
	["  with the creatures not thinking, at the house", "creatures", 2],
	["  with the trunks not collidable, at the house", "trunks", 2],
	["  with the house's own hulls off, at the house", "house", 2],
	["  with the creatures not thinking", "creatures", 0],
	["  with the trunks not collidable, in the trees", "trunks", 1],
	["  with the settlement not collidable", "village", 0],
]


func _initialize() -> void:
	print("")
	var baseline := [0.0, 0.0, 0.0]
	for run: Array in RUNS:
		var spot: int = run[2]
		var here: float = await _run(run[0] as String, run[1] as String, spot, baseline[spot])
		if (run[1] as String).is_empty():
			baseline[spot] = here
	quit()


## Loads the level, switches one thing off, and measures. The world is freed
## afterwards, so nothing carries into the next reading.
func _run(label: String, without: String, spot: int, against: float) -> float:
	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	await process_frame
	var player: Player = (world as World).player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	match without:
		"creatures":
			var creatures := world.get_node_or_null("Enemies")
			if creatures != null:
				# The level puts far creatures to sleep on its own; switching that
				# off too is what makes this measure *all* of them.
				(world as World).creature_think_distance = 0.0
				for node in creatures.get_children():
					(node as Node3D).set_physics_process(false)
		"trunks":
			_layers(world.get_node_or_null("Forest"), 0)
		"village":
			_layers(world.get_node_or_null("Level/Village"), 0)
		"house":
			_layers(world.get_node_or_null("Level/House"), 0)
			_layers(world.get_node_or_null("Level/Cart"), 0)
		"forest":
			var forest := world.get_node_or_null("Forest")
			if forest != null:
				forest.queue_free()
				await process_frame

	var median := await _tick(player, [STAND, IN_THE_WOOD, AT_THE_HOUSE][spot])
	if against > 0.0:
		print("%-48s %6.2f ms   (%+.2f)" % [label, median, median - against])
	else:
		print("%-48s %6.2f ms" % [label, median])
		if label.begins_with("everything"):
			_report(world)

	# Taken down *now*, not queued. A queued free leaves the level's thousand-odd
	# static bodies in the physics server for another frame or two, and with a
	# world loaded per configuration those pile up until the later readings are
	# measuring the wreckage of the earlier ones.
	root.remove_child(world)
	world.free()
	await process_frame
	await physics_frame
	return median


func _layers(under: Node, layer: int) -> void:
	if under == null:
		return
	for node in under.find_children("*", "StaticBody3D", true, false):
		(node as StaticBody3D).collision_layer = layer


## The median tick, in milliseconds, with the knight walking on the spot at
## `where`. Walking rather than standing: a body that is not moving does not ask
## the physics server anything.
func _tick(player: Player, where: Vector3) -> float:
	player.global_position = where
	player.velocity = Vector3.ZERO
	for i in SETTLE:
		await physics_frame

	var ticks: Array[float] = []
	for i in TICKS:
		player.velocity.x = 3.0
		player.velocity.z = 3.0
		await physics_frame
		ticks.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	ticks.sort()
	return ticks[ticks.size() / 2]


func _report(world: Node3D) -> void:
	var forest := world.get_node_or_null("Forest")
	var village := world.get_node_or_null("Level/Village")
	var creatures := world.get_node_or_null("Enemies")
	print("    %d trunk bodies, %d building bodies, %d creatures" % [
			forest.find_children("*", "StaticBody3D", true, false).size() if forest != null else 0,
			village.find_children("*", "StaticBody3D", true, false).size() if village != null else 0,
			creatures.get_child_count() if creatures != null else 0])
