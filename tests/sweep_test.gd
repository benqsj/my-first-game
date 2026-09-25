extends SceneTree

## Blows land only where the weapon has been ([WeaponSweep]).
##
## For each creature and each kind of blow: the blow is thrown once with nobody
## near, and the path its weapon takes is recorded. Then a player is stood where
## the weapon went — he is struck — and just past the furthest it reached — he
## is not, even where the old rule (a reach and a cone in front) would have hit
## him.
##
##     godot --path . --headless --script res://tests/sweep_test.gd

var _failures := 0
var _struck: Array[float] = []
var _player: Player
var _world: World


func _initialize() -> void:
	_geometry()
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	_world = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(_world)
	await _wait(2)
	_world.creature_think_distance = 0.0
	_player = _world.player()
	_player.immortal = true
	_player.struck.connect(func(damage: float, _blocked: bool) -> void: _struck.append(damage))
	var enemies := _world.get_node("Enemies")
	var orc: OrcWarrior = null
	var great: OrcWarrior = null
	var ark: Arkdeva = null
	var wolf: Wolf = null
	var imp: Fighter = null
	for node in enemies.get_children():
		if node is OrcWarrior:
			if (node as OrcWarrior).great_axe:
				great = node
			else:
				orc = node
		elif node is Arkdeva:
			ark = node
		elif node is Wolf and wolf == null:
			wolf = node
		elif node is Fighter and imp == null:
			imp = node
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -60.0, 0.0)

	# An open, flat spot for every trial, well away from everything.
	var ground := _flat_spot()
	if orc != null:
		await _orc_trials(orc, ground, "orc")
	if great != null:
		await _orc_trials(great, ground, "great-axe orc")
	if ark != null:
		await _ark_trials(ark, ground)
	if wolf != null:
		await _wolf_trials(wolf, ground)
	if imp != null:
		await _imp_trials(imp, ground)
	_finish()


#region Geometry
func _geometry() -> void:
	var low := Vector3(0, WeaponSweep.BODY_LOW, 0)
	var high := Vector3(0, WeaponSweep.BODY_HIGH, 0)
	_check("a blade through the body touches it",
			WeaponSweep.touches(Vector3(-1, 1, 0), Vector3(1, 1, 0), 0.05, low, high))
	_check("a blade half a metre clear of it does not",
			not WeaponSweep.touches(Vector3(-1, 1, 0.9), Vector3(1, 1, 0.9), 0.05, low, high))
	_check("a blade over his head does not",
			not WeaponSweep.touches(Vector3(-1, 2.3, 0), Vector3(1, 2.3, 0), 0.05, low, high))
#endregion


#region Trials
## Throws a blow with `begin`, holding the creature still, for up to `frames`;
## returns every stretch its live sweeps took, frame by frame.
func _throw(who: Node3D, begin: Callable, sweeps: Callable, spot: Vector3, frames: int,
		done: Callable) -> Array:
	var path := []
	begin.call()
	for i in frames:
		who.global_position = Vector3(spot.x, who.global_position.y, spot.z)
		_player.velocity = Vector3.ZERO
		_player.global_position = Vector3(_hold.x, _player.global_position.y, _hold.z)
		await process_frame
		for sweep: WeaponSweep in sweeps.call():
			if not sweep._drawn.is_empty():
				path.append(sweep._drawn.duplicate())
				sweep._drawn = []
		if i > 5 and done.call():
			break
	await _wait(3)
	return path


var _hold := Vector3.ZERO


func _place(at: Vector3) -> void:
	_hold = at
	_player.global_position = at + Vector3.UP * 0.1
	_player.velocity = Vector3.ZERO


## One blow three times: with nobody near (its path), with the player where it
## went, and with him just beyond it.
func _trial(label: String, who: Node3D, spot: Vector3, begin: Callable, sweeps: Callable,
		frames: int, done: Callable, old_reach: float, old_cone: float) -> void:
	var ahead := -who.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	# Far off to the side: nothing to meet.
	_place(spot + ahead.cross(Vector3.UP) * 40.0)
	await _ready_player()
	var path := await _throw(who, begin, sweeps, spot, frames, done)
	_check("%s: its weapon is followed while it strikes" % label, not path.is_empty())
	if path.is_empty():
		return
	# Where it went at body height, and how far out it ever got.
	var inside := Vector3.INF
	var best := INF
	var clear := _girth(who) + WeaponSweep.BODY_RADIUS
	var far := 0.0
	var far_dir := ahead
	for frame: Array in path:
		for part: Array in frame:
			for k in 9:
				var p: Vector3 = (part[0] as Vector3).lerp(part[1], k / 8.0)
				var rel := p - spot
				var h := rel.y
				rel.y = 0.0
				var out := rel.length() + float(part[2])
				if out > far:
					far = out
					far_dir = rel.normalized() if rel.length() > 0.01 else ahead
				var miss := absf(h - 1.0)
				if miss < best and rel.length() > clear:
					best = miss
					inside = p
	var side_dir := ahead.cross(Vector3.UP)
	_map(label, path, spot, ahead, side_dir)
	print("    %s: at body height it passes %.2f m ahead, %.2f m to the right" % [label,
			(inside - spot).dot(ahead), (inside - spot).dot(side_dir)])
	# Stood where the weapon passed at body height.
	await _ready_player()
	_place(Vector3(inside.x, spot.y, inside.z))
	_struck.clear()
	var again := await _throw(who, begin, sweeps, spot, frames, done)
	var nearest := INF
	var feet := _player.global_position
	for frame: Array in again:
		for part: Array in frame:
			var pts := Geometry3D.get_closest_points_between_segments(part[0], part[1],
					feet + Vector3.UP * WeaponSweep.BODY_LOW, feet + Vector3.UP * WeaponSweep.BODY_HIGH)
			nearest = minf(nearest, pts[0].distance_to(pts[1]) - float(part[2]))
	_check("%s: stood where it goes, he is struck" % label, not _struck.is_empty(),
			"blade %.2f m from body height there; this time it came %.2f m from his axis in %d frames; he is at %s, meant %s" % [
			best, nearest, again.size(), feet, inside])
	# Just beyond the furthest it ever got, the way it got there.
	await _ready_player()
	var gap := far + WeaponSweep.BODY_RADIUS + WeaponSweep.GRAZE + 0.2
	var beyond := spot + far_dir * gap
	_place(beyond)
	_struck.clear()
	await _throw(who, begin, sweeps, spot, frames, done)
	var old := gap <= old_reach and ahead.dot(far_dir) >= old_cone
	_check("%s: %.1f m off, just past its reach, he is not%s" % [label, gap,
			" (the old reach-and-cone would have hit him)" if old else ""], _struck.is_empty(), str(_struck))
	var lowest := INF
	for frame: Array in path:
		for part: Array in frame:
			for k in 9:
				var p: Vector3 = (part[0] as Vector3).lerp(part[1], k / 8.0)
				var rel := p - spot
				if Vector2(rel.x, rel.z).length() > clear:
					lowest = minf(lowest, rel.y - float(part[2]))
	print("    %s reaches %.2f m, and comes down to %.2f m off the ground out past its body" % [label, far, lowest])


## Where a player could stand and be struck by this blow, seen from above: the
## creature at O facing up the page, a cell every half metre.
func _map(label: String, path: Array, spot: Vector3, ahead: Vector3, side: Vector3) -> void:
	print("    where %s can land (O is it, facing up; # struck):" % label)
	for row in range(12, -5, -1):
		var line := "      "
		for col in range(-9, 10):
			var feet := spot + ahead * row * 0.5 + side * col * 0.5
			var low := feet + Vector3.UP * WeaponSweep.BODY_LOW
			var high := feet + Vector3.UP * WeaponSweep.BODY_HIGH
			var hit := false
			for f in path.size():
				var now: Array = path[f]
				var was: Array = path[f - 1] if f > 0 and (path[f - 1] as Array).size() == now.size() else now
				for i in now.size():
					for k in 4:
						var t := k / 3.0
						var a: Vector3 = (was[i][0] as Vector3).lerp(now[i][0], t)
						var b: Vector3 = (was[i][1] as Vector3).lerp(now[i][1], t)
						if WeaponSweep.touches(a, b, float(now[i][2]), low, high):
							hit = true
							break
					if hit:
						break
				if hit:
					break
			line += "O" if row == 0 and col == 0 else ("#" if hit else ".")
		print(line)


## How wide the creature's own body is: the player cannot stand inside it.
func _girth(who: Node3D) -> float:
	for node in who.get_children():
		var shape := node as CollisionShape3D
		if shape != null and shape.shape is CapsuleShape3D:
			return (shape.shape as CapsuleShape3D).radius
	return 0.5


func _ready_player() -> void:
	for i in 240:
		if _player.state != Player.State.DOWNED and not _player.is_invulnerable:
			break
		await physics_frame
	if _player.state == Player.State.DOWNED:
		_player.state = Player.State.GROUNDED
	_player.is_invulnerable = false
	_player._safe_until = 0.0
	await _wait(20)


func _flat_spot() -> Vector3:
	var space := _world.get_world_3d().direct_space_state
	for candidate in [Vector3(0, 0, -60), Vector3(20, 0, -80), Vector3(-30, 0, -120), Vector3(0, 0, -200)]:
		var ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 60.0, candidate + Vector3.DOWN * 60.0, 1)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			return hit.position
	return Vector3.ZERO


func _orc_trials(orc: OrcWarrior, ground: Vector3, name: String) -> void:
	orc.global_position = ground + Vector3.UP * 0.3
	# His ground is wherever he is standing for the test, not the bay's water.
	orc.holds_the_water = false
	orc._water = null
	orc._water_found = true
	orc.camp_centre = ground
	orc._home = ground
	orc.leash_radius = 60.0
	orc.set_physics_process(true)
	orc.turn_speed = 0.0
	orc._cooldown = 999.0
	orc.rotation.y = 0.0
	await _wait(30)
	var spot := orc.global_position
	var idle := func() -> bool: return orc.act == Brute.ACT_NONE
	var sweeps := func() -> Array: return orc._sweeps
	for pick in [[OrcWarrior.Act.SWING, "swing"], [OrcWarrior.Act.BACKHAND, "backhand"],
			[OrcWarrior.Act.COMBO, "combo"]]:
		var what: int = pick[0]
		await _trial("%s %s" % [name, pick[1]], orc, spot, orc._open.bind(what), sweeps, 400, idle,
				orc.reach + 0.6, 0.3)
		await _until(idle)
	# Left to himself, from as far off as he opens (`reach`), he steps in and
	# his axe still finds a player who stands there.
	await _closes_in(orc, spot, orc.reach - 0.1, name)
	orc.set_physics_process(false)
	orc.global_position += Vector3(0.0, -60.0, 0.0)


func _ark_trials(ark: Arkdeva, ground: Vector3) -> void:
	ark.global_position = ground + Vector3.UP * 0.3
	ark.set_physics_process(true)
	ark.turn_speed = 0.0
	ark._cooldown = 999.0
	await _wait(30)
	var spot := ark.global_position
	var idle := func() -> bool: return ark.act == Brute.ACT_NONE
	var sweeps := func() -> Array: return ark._sweeps
	_check("Arkdeva's blades are read off its mesh", ark._blades.size() == 2, str(ark._blades.keys()))
	for pick in [[Arkdeva.Act.STRIKE_L, "Arkdeva left scythe"], [Arkdeva.Act.CHOP, "Arkdeva chop"],
			[Arkdeva.Act.STAMP, "Arkdeva stamp"]]:
		await _trial(pick[1], ark, spot, ark._begin.bind(pick[0]), sweeps, 400, idle,
				ark.strike_radius + 3.0 * ark.visual_scale, 0.3)
		await _until(idle)
	ark.set_physics_process(false)
	ark.global_position += Vector3(0.0, -60.0, 0.0)


func _wolf_trials(wolf: Wolf, ground: Vector3) -> void:
	wolf.global_position = ground + Vector3.UP * 0.3
	wolf.state = Wolf.State.FIGHT
	await _wait(40)
	var spot := wolf.global_position
	var start := func() -> void:
		wolf._swipe_count += 1
		# The same paw every time (it swaps paws with each swipe).
		wolf.rig._swipe_left = false
		wolf.rig.swipe()
		wolf._arm_claws(Wolf.SWIPE_LIVE, false)
	var over := func() -> bool: return not wolf.rig.is_swiping()
	var sweeps := func() -> Array: return wolf._sweeps
	await _trial("wolf swipe", wolf, spot, start, sweeps, 120, over, wolf.reach + 0.6, 0.25)
	wolf.global_position += Vector3(0.0, -60.0, 0.0)


func _imp_trials(imp: Fighter, ground: Vector3) -> void:
	imp.global_position = ground + Vector3.UP * 0.3
	imp.camp_centre = ground
	imp._home = ground
	imp.leash_radius = 60.0
	imp.set_physics_process(true)
	imp.set("turn_speed", 0.0)
	imp.chase_speed = 0.0
	imp.block_chance = 0.0
	imp.dash_chance = 0.0
	imp._cooldown = 999.0
	await _wait(30)
	var spot := imp.global_position
	var idle := func() -> bool: return imp.act == Fighter.Act.NONE
	var sweeps := func() -> Array: return imp._sweeps
	await _trial("%s combo" % imp.name, imp, spot, imp._begin_attack, sweeps, 400, idle, imp.reach + 0.5, 0.3)
	await _closes_in(imp, spot, imp.reach - 0.1, imp.name)
	imp.set_physics_process(false)
#endregion


func _closes_in(who: Node3D, spot: Vector3, gap: float, label: String) -> void:
	await _ready_player()
	who.set("turn_speed", 4.0)
	who.set("_cooldown", 0.0)
	var ahead := -who.global_transform.basis.z
	ahead.y = 0.0
	_place(spot + ahead.normalized() * gap)
	_struck.clear()
	for i in 900:
		_player.velocity = Vector3.ZERO
		_player.global_position = Vector3(_hold.x, _player.global_position.y, _hold.z)
		await physics_frame
		if not _struck.is_empty():
			break
	_check("%s opens from %.1f m, steps in, and lands" % [label, gap], not _struck.is_empty())
	who.set("turn_speed", 0.0)
	who.set("_cooldown", 999.0)
	await _until(func() -> bool: return int(who.get("act")) == 0)


func _until(done: Callable) -> void:
	for i in 600:
		if done.call():
			return
		await physics_frame


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
