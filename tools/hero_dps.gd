extends SceneTree

## How hard each hero hits: every hero against the same creature (an imp, or
## with `boss` an orc warrior, a [Brute], made a dummy: it does not move or strike back, but keeps facing him unless he
## is hidden or it has lost him, as a creature would), for `SECONDS` each of
## cuts only, skills only, and both, from full stamina with the cooldowns
## ready, the stamina and the cooldowns then running as in play. What it lost
## a second is printed, and the cuts thrown, crits and backstabs seen.
## Not a pass/fail test: a measure to keep the heroes level as they change
## (the user's word, 2026-10-06).
##
##     godot --path . --headless --script res://tools/hero_dps.gd [-- boss] [tariel rogue ...]

const WORLD := "res://scenes/world/greybox_world.tscn"
const IMP := "res://scenes/enemies/imp.tscn"
const BOSS := "res://scenes/enemies/orc.tscn"
const HEROES: Array[StringName] = [&"tariel", &"warrior", &"amirani", &"rogue", &"avtandil", &"mage",
		&"elf_archer", &"elf_mage", &"dark_archer", &"dark_mage", &"dark_rogue"]
const SECONDS := 30.0
## How far in front of him it stands (from his middle to its).
const GAP := 1.9
const LOTS := 1000000.0

var _world: Node3D
var _player: Player
var _dummy: Node3D
var _home := Vector3.ZERO
var _rows: Array[String] = []
var _dummy_scene := IMP


func _initialize() -> void:
	await process_frame
	var only: Array[StringName] = []
	for a in OS.get_cmdline_user_args():
		if a == "boss":
			_dummy_scene = BOSS
		else:
			only.append(StringName(a))
	for id in (only if not only.is_empty() else HEROES):
		await _spawn(id)
		var row := "%-12s hp %4.0f" % [id, _player.max_health]
		for mode in ["cuts", "skills", "both"]:
			row += "  | " + await _bout(mode)
		_rows.append(row)
		print("ROW ", row)
	print("")
	print("What the %s lost a second over %.0f s (cuts only | skills only | both):" % [
			"orc warrior" if _dummy_scene == BOSS else "imp", SECONDS])
	for r in _rows:
		print(r)
	quit(0)


func _bout(mode: String) -> String:
	await _ready_up()
	_dummy = _make_dummy()
	await _wait(10)
	_player.call("_hold_target", _dummy)
	var cuts := bool(mode != "skills")
	var skills := bool(mode != "cuts")
	var start: float = _dummy.health
	var frames := int(SECONDS * Engine.physics_ticks_per_second)
	var serial: int = int(_player.rig.get(&"attack_serial")) if _player.rig.get(&"attack_serial") != null else 0
	var used := 0
	var pulled := 0
	for f in frames:
		if not is_instance_valid(_dummy):
			break
		# it stays where it is, and faces him unless it has lost him
		_dummy.global_position = _home
		_dummy.set(&"velocity", Vector3.ZERO)
		# its own physics is off (so it neither moves nor strikes): what it
		# would do each tick to feel the blades, done here
		if _dummy.has_method(&"_watch_blades"):
			_dummy.call(&"_watch_blades")
		# and it does nothing about them: no guard, no dodge, no reeling (a
		# reel would freeze on it, its physics off, and bite deeper)
		_dummy.set(&"act", 0)
		if not _player.is_hidden():
			var at := _player.global_position
			at.y = _home.y
			if at.distance_to(_home) > 0.1:
				_dummy.look_at(at, Vector3.UP)
		# he stays near it and turned to it (a skill that carries him off is
		# brought back)
		var off := _player.global_position - _home
		off.y = 0.0
		if off.length() > 4.0:
			_player.global_position = _home + off.normalized() * GAP + Vector3.UP * 0.05
			pulled += 1
		if not _player.is_committed():
			var way := _home - _player.global_position
			way.y = 0.0
			if way.length_squared() > 0.01:
				_player.rotation.y = atan2(-way.x, -way.z)
		# a skill first whenever one is ready (holding the cuts back for the
		# stamina it needs, as a player would), the cuts between
		var saving := false
		if skills:
			for slot in 4:
				var id := _player.skill_in(slot)
				if id == &"" or _player.skill_cooldown_left(slot) > 0.0:
					continue
				var cost := float(Player.SKILLS.get(id, {}).get("stamina", 0.0))
				if _player.stamina < cost:
					saving = true
					continue
				if f % 15 == 0 and _player.use_skill(slot):
					used += 1
					break
		if cuts and not saving and f % 6 == 0:
			Input.action_press("attack")
		await physics_frame
		Input.action_release("attack")
	var lost := start - float(_dummy.health) if is_instance_valid(_dummy) else start
	var thrown := (int(_player.rig.get(&"attack_serial")) - serial) if _player.rig.get(&"attack_serial") != null else -1
	if is_instance_valid(_dummy):
		_dummy.queue_free()
	await _wait(5)
	return "%-6s %5.1f/s (cuts %3d, skills %2d%s)" % [mode, lost / SECONDS, thrown, used,
			(", pulled back %d" % pulled) if pulled > 0 else ""]


func _make_dummy() -> Node3D:
	var fwd := -_player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := _player.global_position + fwd * GAP
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1))
	if not hit.is_empty():
		at = hit["position"]
	var c: Node3D = (load(_dummy_scene) as PackedScene).instantiate()
	c.position = _world.to_local(at + Vector3.UP * 0.05)
	_world.add_child(c)
	for k in ["speed", "chase_speed", "dash_chance", "sight_range"]:
		if k in c:
			c.set(k, 0.0)
	c.set("max_health", LOTS)
	c.set("health", LOTS)
	c.set_physics_process(false)
	_home = c.global_position
	# it does not see the blades coming (no guard or dodge started)
	if c.has_method(&"_watch_blades"):
		c.call(&"_watch_blades")
		var box := HurtboxComponent.of(c)
		if box != null:
			for link in box.swing_seen.get_connections():
				box.swing_seen.disconnect(link["callable"])
	c.look_at(Vector3(_player.global_position.x, _home.y, _player.global_position.z), Vector3.UP)
	return c


func _ready_up() -> void:
	for i in 200:
		if _player.state == Player.State.GROUNDED and not _player.is_committed():
			break
		await physics_frame
	_player._skill_ready_at.clear()
	_player.stamina = _player.max_stamina
	_player.health = _player.max_health
	_player.immortal = true
	_player.target = null
	# the same rolls for the crits every bout, so two runs compare
	var rng = _player.get(&"_shot_rng")
	if rng is RandomNumberGenerator:
		(rng as RandomNumberGenerator).seed = 7


func _spawn(id: StringName) -> void:
	if _world != null:
		_world.queue_free()
		await _wait(2)
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", id)
	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await _wait(40)
	_player = (_world as World).player()
	for body in _world.find_children("*", "CharacterBody3D", true, false):
		if body != _player:
			body.queue_free()
	await _wait(30)
	for i in 300:
		if _player.state == Player.State.GROUNDED and not _player.is_committed():
			break
		await physics_frame


func _wait(n: int) -> void:
	for i in n:
		await physics_frame
