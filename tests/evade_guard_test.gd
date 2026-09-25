extends SceneTree

## The evades' cover: no blow lands for the whole of a roll or a dodge — even
## one cut short by running into a body or a wall — and, for the heroes who
## shed a shadow on a perfect dodge (the assassin, Avtandil), none lands while
## the shadow is being shed ([member Player._safe_until], [const ShadowTrail.GUARD]).
##
##     godot --path . --headless --script res://tests/evade_guard_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"
const ORC := "res://scenes/enemies/orc.tscn"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	await process_frame
	for hero in [&"tariel", &"avtandil", &"rogue"]:
		await _spawn(hero)
		await _check_bump(String(hero))
		await _check_perfect(String(hero))
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


## Rolling straight into an orc: the roll is stopped by it, and still nothing
## lands until the roll would have ended.
func _check_bump(who: String) -> void:
	var orc := _creature(ORC, _ahead(1.3))
	orc.set("sight_range", 0.0)
	await _wait(10)
	_fresh()
	_check("%s: the roll goes" % who, _player.call(&"_start_evade", false))
	await _wait(5)
	var was := _player.health
	_player.receive_blow(20.0, orc, 0, 3, 11)
	await _wait(3)
	_check("%s: rolling into the orc, its blow does not land" % who, is_equal_approx(_player.health, was),
			"state %d, %.0f -> %.0f" % [_player.state, was, _player.health])
	# Well after: it lands again.
	await _wait(int(ShadowTrail.GUARD * 60.0) + 20)
	_fresh()
	was = _player.health
	_player.receive_blow(20.0, orc, 0, 3, 12)
	await _wait(3)
	_check("%s: afterwards blows land again" % who, _player.health < was, "%.0f -> %.0f" % [was, _player.health])
	orc.queue_free()
	await _wait(5)


## A perfect dodge: with the shadow, nothing lands while it is shed; without,
## only the evade itself is covered.
func _check_perfect(who: String) -> void:
	var orc := _creature(ORC, _ahead(6.0))
	orc.set("sight_range", 0.0)
	await _wait(10)
	_fresh()
	_player.call(&"_start_evade", false)
	await _wait(3)
	var was := _player.health
	_player.receive_blow(20.0, orc, 0, 3, 21)
	await _wait(3)
	_check("%s: the blow early in the roll is dodged" % who, is_equal_approx(_player.health, was))
	# The roll is over; the shadow (if any) is still being shed.
	await _wait(int((_player.dash_duration + 0.25) * 60.0))
	was = _player.health
	_player.receive_blow(20.0, orc, 0, 3, 22)
	await _wait(3)
	var shadow := _player.profile != null and _player.profile.shadow_dodge
	if shadow:
		_check("%s: while the shadow is shed, nothing lands" % who, is_equal_approx(_player.health, was),
				"%.0f -> %.0f" % [was, _player.health])
	else:
		_check("%s (no shadow): after the roll, blows land" % who, _player.health < was,
				"%.0f -> %.0f" % [was, _player.health])
	orc.queue_free()
	await _wait(int(ShadowTrail.GUARD * 60.0) + 10)


func _fresh() -> void:
	_player.health = _player.max_health
	_player.stamina = _player.max_stamina
	_player.set("_dash_cooldown_timer", 0.0)


func _creature(path: String, at: Vector3) -> Node3D:
	var ground := at
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1))
	if not hit.is_empty():
		ground = hit["position"]
	var c: Node3D = (load(path) as PackedScene).instantiate()
	# Placed before it enters the tree, so the ground it holds is here.
	c.position = _world.to_local(ground + Vector3.UP * 0.05)
	_world.add_child(c)
	# Kept where they are put: the test is of what the skills do to them.
	if c is Fighter:
		c.set("speed", 0.0)
		c.set("chase_speed", 0.0)
		c.set("dash_chance", 0.0)
		c.set("sight_range", 0.0)
	c.look_at(Vector3(_player.global_position.x, at.y, _player.global_position.z), Vector3.UP)
	return c


func _fwd() -> Vector3:
	var f := -_player.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _ahead(d: float) -> Vector3:
	return _player.global_position + _fwd() * d


## How far along the player's facing something is.
func _along(who: Node3D) -> float:
	return (who.global_position - _player.global_position).dot(_fwd())


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
	# On his feet before anything is asked of him.
	for i in 300:
		if _player.state == Player.State.GROUNDED and not _player.is_committed():
			break
		await physics_frame


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_failures += 1
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
