extends SceneTree

## Somebody else's climb is seen (the user's word, 2026-10-22: the other
## player did not see the wall climb): a body this peer does not own takes the
## climbing pose when its replicated state says it is on a wall, moves its
## limbs to its replicated velocity, and lets go when the state does; a
## pull-up is played the same way. And no wall is climbed in a portal's rooms.
##
##     godot --headless --path . --script res://tests/net_climb_test.gd

var _failures := 0


func _initialize() -> void:
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(10)
	var other := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	other.name = "2"
	other.set_multiplayer_authority(2)
	world.add_child(other)
	other.global_position = world.player().global_position + Vector3(4.0, 0.5, 0.0)
	await _wait(20)
	_check("the other body is not this peer's", not other.is_multiplayer_authority())
	var rig := other.rig
	_check("it has a rig", rig != null)
	if rig == null:
		_finish()
		return
	other.net_state = Player.State.WALLCLIMB
	other.velocity = other.global_basis.y * 2.0
	await _wait(40)
	_check("on a wall by his state: the climbing pose", rig.is_wall_climbing())
	other.net_state = Player.State.AIRBORNE
	other.velocity = Vector3.ZERO
	await _wait(40)
	_check("let go by his state", not rig.is_wall_climbing())
	# and the portal's rooms: nothing to climb
	var hero := world.player()
	_check("walls are climbed out here", not hero._in_dungeon())
	var mark := Node.new()
	mark.add_to_group(&"dungeon")
	world.add_child(mark)
	_check("not in a portal's rooms", hero._in_dungeon() and not hero._try_wall_climb(Vector3.FORWARD))
	_finish()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


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
