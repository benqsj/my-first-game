extends SceneTree

## Headless checks for the second character: Avtandil, the bow, and the target
## lock that both characters share.
##
##     godot --path . --headless --script res://tests/archer_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"
const ARCHER := "res://scenes/player/avtandil.tres"
const KNIGHT := "res://scenes/player/tariel.tres"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	_world = load(WORLD).instantiate()
	_player = _world.get_node("Player")
	_player.profile = load(ARCHER) as CharacterProfile
	root.add_child(_world)
	await _wait(2)

	# The creatures wander and hunt; every check here is about the archer, so
	# the only one in the world is the one put there on purpose.
	for body in _world.find_children("*", "CharacterBody3D", true, false):
		if body != _player:
			body.queue_free()
	await _wait(2)

	await _check_character()
	await _check_lock()
	await _check_bow()
	await _check_damage()

	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


## --- The character itself -------------------------------------------------
func _check_character() -> void:
	_check("the archer spawns with his own rig", _player.rig is ArcherRig)
	_check("and carries a bow", _player.has_bow())
	_check("the bow is on the model",
			_player.rig.find_child("bow", true, false) != null)

	var knight := load(KNIGHT) as CharacterProfile
	var archer := load(ARCHER) as CharacterProfile
	_check("he runs faster than the knight", archer.run_speed > knight.run_speed,
			"%.1f vs %.1f m/s" % [archer.run_speed, knight.run_speed])
	_check("his roll carries further",
			archer.dash_speed * archer.dash_duration > knight.dash_speed * knight.dash_duration,
			"%.2f vs %.2f m" % [archer.dash_speed * archer.dash_duration,
					knight.dash_speed * knight.dash_duration])
	_check("and he crits more often", archer.crit_chance > knight.crit_chance,
			"%.0f%% vs %.0f%%" % [archer.crit_chance * 100.0, knight.crit_chance * 100.0])
	_check("the controller took his numbers",
			is_equal_approx(_player.run_speed, archer.run_speed),
			"%.1f m/s" % _player.run_speed)


## --- Target lock ----------------------------------------------------------
func _check_lock() -> void:
	_player.global_position = Vector3(6.0, 0.2, 12.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	var quarry := _wolf_at(Vector3(9.0, 0.5, 6.0))
	await _wait(20)

	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	_check("E takes the enemy in front", _player.target == quarry,
			"holding %s" % _player.target)

	await _wait(45)
	var facing := -_player.global_transform.basis.z
	var to_them := (quarry.global_position - _player.global_position)
	to_them.y = 0.0
	_check("the body turns to face it", facing.dot(to_them.normalized()) > 0.9,
			"%.2f" % facing.dot(to_them.normalized()))

	# The camera has to watch the fight from *above* it. Aimed the other way it
	# sits on the floor and looks up the target's nose, which is the one thing a
	# lock-on camera must never do.
	var eye := _player.camera.global_position
	var mark := quarry.global_position + Vector3.UP * 0.8
	_check("the camera looks down on the target, not up at it", eye.y > mark.y + 0.8,
			"camera at y=%.2f, target at y=%.2f" % [eye.y, mark.y])
	_check("and it is behind the player, not in front",
			(_player.global_position - eye).normalized().dot(to_them.normalized()) > 0.5,
			"%.2f" % (_player.global_position - eye).normalized().dot(to_them.normalized()))

	# Backing away has to keep him facing it, which is the whole point of a lock.
	var gap := _player.global_position.distance_to(quarry.global_position)
	Input.action_press("move_back")
	await _wait(30)
	Input.action_release("move_back")
	var facing_now := -_player.global_transform.basis.z
	var away := (quarry.global_position - _player.global_position)
	away.y = 0.0
	_check("backing off keeps him facing it",
			_player.global_position.distance_to(quarry.global_position) > gap + 0.5
					and facing_now.dot(away.normalized()) > 0.9,
			"gap %.1f -> %.1f, facing %.2f" % [gap,
					_player.global_position.distance_to(quarry.global_position),
					facing_now.dot(away.normalized())])

	# Sideways is a strafe, not a turn.
	Input.action_press("move_right")
	await _wait(30)
	Input.action_release("move_right")
	var strafed := -_player.global_transform.basis.z
	var still := (quarry.global_position - _player.global_position)
	still.y = 0.0
	_check("and going sideways strafes round it",
			strafed.dot(still.normalized()) > 0.9,
			"%.2f" % strafed.dot(still.normalized()))

	# Back to a known spot before the next lot: the checks above walked him
	# around, and which enemy is "to the left" depends on where he is standing.
	_player.global_position = Vector3(6.0, 0.2, 12.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	quarry.global_position = Vector3(9.0, 0.5, 6.0)
	quarry.sight_range = 0.0
	quarry.prowl_speed = 0.0
	await _wait(20)
	if _player.target == null:
		Input.action_press("lock_on")
		await _wait(3)
		Input.action_release("lock_on")
	await _wait(20)

	# The mark has to say *which*, or with two wolves in front of you the lock is
	# a guess.
	var marker := _player.find_child("TargetMarker", true, false) as Node3D
	_check("the marked enemy is shown", marker != null and marker.visible)
	# On the body, not over its head: the mark is meant to be on the thing being
	# fought.
	_check("and the mark sits on the one being fought",
			marker != null
					and Vector2(marker.global_position.x - quarry.global_position.x,
							marker.global_position.z - quarry.global_position.z).length() < 0.6
					and absf(marker.global_position.y - quarry.global_position.y - 0.85) < 0.3,
			"mark at %v, target at %v" % [marker.global_position if marker != null else Vector3.ZERO,
					quarry.global_position])

	# A second one to swap to.
	var other := _wolf_at(Vector3(2.0, 0.5, 6.0))
	other.sight_range = 0.0
	other.prowl_speed = 0.0
	await _wait(20)
	_player._switch_target(-1.0)
	await _wait(10)
	_check("a flick to the side takes the next enemy along", _player.target == other,
			"holding %s" % _player.target)
	_player._switch_target(1.0)
	await _wait(10)
	_check("and a flick back takes the first one again", _player.target == quarry)
	await _wait(20)
	_check("the mark moved with it",
			Vector2(marker.global_position.x - quarry.global_position.x,
					marker.global_position.z - quarry.global_position.z).length() < 0.6)
	other.queue_free()
	await _wait(5)

	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	_check("E again lets go", _player.target == null)
	await _wait(5)
	_check("and the mark goes with it", marker == null or not marker.visible)

	# A dead target is no target.
	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	_check("it can be taken again", _player.target == quarry)
	quarry.take_hit(1000.0, quarry.global_position, Vector3.UP)
	await _wait(10)
	_check("a dead one is let go of", _player.target == null)
	quarry.queue_free()
	await _wait(5)


## --- Drawing and loosing --------------------------------------------------
func _check_bow() -> void:
	_player.global_position = Vector3(6.0, 0.2, 12.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(20)

	Input.action_press("attack")
	await _wait(6)
	_check("holding the button draws the bow", _player.is_drawing())
	var early := _player.draw_power()
	await _wait(40)
	_check("and holding it longer draws it further", _player.draw_power() > early + 0.3,
			"%.2f -> %.2f" % [early, _player.draw_power()])
	_check("nothing is loosed while it is held", _arrows() == 0, "%d in the air" % _arrows())

	# Drawing costs most of the run.
	var held := _player.global_position
	Input.action_press("move_forward")
	await _wait(30)
	var drawn_pace := held.distance_to(_player.global_position) / 0.5
	Input.action_release("move_forward")
	_check("drawing slows him down", drawn_pace < _player.run_speed * 0.8,
			"%.1f of %.1f m/s" % [drawn_pace, _player.run_speed])

	Input.action_release("attack")
	await _wait(2)
	_check("letting go looses the arrow", _arrows() == 1, "%d in the air" % _arrows())
	_check("and the bow is no longer drawn", not _player.is_drawing())

	var flying := _first_arrow()
	var was := flying.global_position
	await _wait(6)
	_check("the arrow flies", flying == null or was.distance_to(flying.global_position) > 1.0)
	await _wait(120)

	# Tapping shoots quickly, and each tap is worth less than a full draw.
	var quick := 0
	for i in 4:
		Input.action_press("attack")
		await _wait(2)
		Input.action_release("attack")
		await _wait(14)
		quick += 1
	_check("tapping gets shots away quickly", _arrows() >= 3,
			"%d arrows from %d taps" % [_arrows(), quick])
	await _wait(60)


## --- What a shot is worth -------------------------------------------------
func _check_damage() -> void:
	# Shot from the same spot, at the same wolf, with only the draw changing.
	var snap := await _shoot_at(0.05)
	var full := await _shoot_at(1.2)
	_check("a snap shot lands for something", snap > 0.0, "%.0f" % snap)
	_check("a full draw lands for more than a snap shot", full > snap * 1.5,
			"%.0f vs %.0f" % [full, snap])

	var profile := load(ARCHER) as CharacterProfile
	_check("a snap shot is worth about what the profile says",
			absf(snap - profile.damage * profile.snap_share) < profile.damage * 0.6,
			"%.0f, expected near %.0f" % [snap, profile.damage * profile.snap_share])


## Shoots one wolf with the string held for `hold` seconds, and reports what the
## hit took off it. Crits are turned off so the number is the draw and nothing
## else — whether they happen at all is checked by their own odds elsewhere.
func _shoot_at(hold: float) -> float:
	var profile := _player.profile
	var was_crit := profile.crit_chance
	profile.crit_chance = 0.0

	_player.global_position = Vector3(6.0, 0.2, 14.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	var quarry := _wolf_at(Vector3(6.0, 0.5, 6.0))
	# Standing still, so what is measured is the draw and not where it wandered.
	quarry.sight_range = 0.0
	quarry.prowl_speed = 0.0
	await _wait(20)
	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	await _wait(20)

	var before := quarry.health
	Input.action_press("attack")
	await _wait(int(hold * 60.0) + 1)
	Input.action_release("attack")
	for i in 90:
		await physics_frame
		if quarry.health < before:
			break
	var taken := before - quarry.health
	quarry.queue_free()
	profile.crit_chance = was_crit
	await _wait(5)
	return taken


#region Scaffolding
func _wolf_at(where: Vector3) -> Wolf:
	var wolf: Wolf = load("res://scenes/enemies/wolf.tscn").instantiate()
	_world.add_child(wolf)
	wolf.global_position = where
	return wolf


func _arrows() -> int:
	return _world.find_children("*", "Arrow", true, false).size() \
			+ (root.find_children("*", "Arrow", true, false).size() \
			- _world.find_children("*", "Arrow", true, false).size())


func _first_arrow() -> Node3D:
	var found := root.find_children("*", "Arrow", true, false)
	return found[0] as Node3D if not found.is_empty() else null


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
#endregion
