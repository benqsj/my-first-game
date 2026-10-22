extends SceneTree
## Spike traps in the floor of the portal's places ([SpikeTrap], 2026-10-22):
## - laid on open floor of a woken place, apart, off its middle;
## - they wake (glow, rattle) and come up now and then, only while the place
##   is fought in;
## - a hero on one is hurt, a creature on one too; one off it is not.
##   Godot --headless --path . --script res://tests/spike_trap_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	game.set(&"dungeon_id", 0)
	var world: World = load("res://scenes/world/dungeon.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await _wait(5)
	while world.get_node_or_null("PipelineWarmup") != null:
		await process_frame
	var d := world.get_node("Level/Rooms") as Dungeon
	var hero := world.player()
	var step := 2
	d._take_down(d.current)
	d._arrive_at(step, "crypt", "")
	await _wait(20)
	var c := d.centre(step)
	hero.global_position = c + Vector3(0, 0.3, float(d._room(step)["l"]) * 0.45)
	await _wait(10)
	# the creatures put far off, all but one goblin
	var gob: Node3D = null
	for body: Variant in d._room_foes[step]:
		if is_instance_valid(body):
			if gob == null and body is Fighter:
				gob = body
			else:
				(body as Node3D).global_position += Vector3(0, -60, 0)
				(body as Node).process_mode = Node.PROCESS_MODE_DISABLED
	d._wake(step)
	await _wait(5)
	if gob == null:
		gob = (load("res://scenes/enemies/imp.tscn") as PackedScene).instantiate() as Node3D
		world.get_node("Enemies").add_child(gob)
		gob.global_position = c + Vector3(0, 0.3, 8)
		await _wait(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var traps: Array[SpikeTrap] = []
	for n in d._room_nodes[step].get_children():
		if n is SpikeTrap:
			traps.append(n)
	if traps.is_empty():
		traps = SpikeTrap.lay(d, step, rng)
	_check("traps laid in the place", traps.size() >= 3, str(traps.size()))
	if traps.is_empty():
		_end()
		return
	var ok_spots := true
	for t in traps:
		var rel := t.global_position - c
		if Vector2(rel.x, rel.z).length() < 5.9 or absf(rel.y) > 0.5:
			ok_spots = false
	_check("on the floor, off the middle", ok_spots)
	var trap := traps[0]
	# (the creatures put out of the way count as gone: the place kept fought in)
	d.cleared[step] = false
	# the hero on it (not deathless: his life goes down), the goblin on another
	hero.immortal = false
	hero.max_health = 1000.0
	hero.health = 1000.0
	if gob != null and traps.size() > 1:
		gob.set_physics_process(false)
	var glow_seen := false
	var hp_before := hero.health
	var gob_before := float(gob.get(&"health")) if gob != null else 0.0
	for f in 480:
		d.cleared[step] = false
		hero.global_position = trap.global_position + Vector3.UP * 0.05
		hero.velocity = Vector3.ZERO
		if gob != null and traps.size() > 1:
			gob.global_position = traps[1].global_position + Vector3.UP * 0.05
		if trap._seams.emission_energy_multiplier > 1.0:
			glow_seen = true
		await physics_frame
		if trap.raised >= 1 and hero.health < hp_before and (gob == null or traps.size() < 2 or traps[1].raised >= 1):
			await _wait(10)
			break
	_check("it wakes with a glow before it comes up", glow_seen)
	_check("it comes up", trap.raised >= 1, str(trap.raised))
	_check("a hero on it is hurt", hero.health < hp_before, "%.0f -> %.0f" % [hp_before, hero.health])
	if gob != null and traps.size() > 1:
		_check("a creature on one is hurt too", float(gob.get(&"health")) < gob_before,
				"%.0f -> %.0f" % [gob_before, float(gob.get(&"health"))])
	# off it: not hurt
	hero.global_position = trap.global_position + Vector3(4.0, 0.05, 0.0)
	await _wait(20)
	var hp_off := hero.health
	var n0 := trap.raised
	for f in 400:
		d.cleared[step] = false
		hero.global_position = trap.global_position + Vector3(4.0, 0.05, 0.0)
		await physics_frame
		if trap.raised > n0:
			await _wait(30)
			break
	_check("off it: not hurt", hero.health >= hp_off - 0.01, "%.0f -> %.0f" % [hp_off, hero.health])
	# cleared: still
	d.cleared[step] = true
	var n1 := trap.raised
	await _wait(400)
	_check("still once the place is cleared", trap.raised == n1)
	_end()


func _end() -> void:
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)
