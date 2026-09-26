extends SceneTree

## Wolves against those who fight from afar — the hunter's arrows and the
## mage's bolts: most shots are got out of from far off and many close in, a
## bolt it gets out of does not come round after it, and on all fours it runs
## him down fast and ends the run with a leap, claws out.
##
##     godot --path . --headless --script res://tests/wolf_run_test.gd

const ARROW := "res://scenes/props/arrow.tscn"
const BOLT := "res://scenes/fx/spell_bolt.tscn"

var _failures := 0
var _struck: Array = []
var _player: Player
var _world: World
var _wolves: Array[Wolf] = []
var _spot := Vector3.ZERO


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	_world = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(_world)
	await _wait(2)
	_world.creature_think_distance = 0.0
	_player = _world.player()
	_player.immortal = true
	_player.struck.connect(func(damage: float, blocked: bool) -> void: _struck.append([damage, blocked]))
	for node in _world.get_node("Enemies").get_children():
		if node is Wolf:
			_wolves.append(node)
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -60.0, 0.0)
	for w in _wolves:
		w.corpse_linger = 9999.0
		w.limbs_before_death = 99
		w.max_health = 100000.0
		w.health = w.max_health
		w._claw_wait = 999.0
	_spot = _flat()

	await _missiles(ARROW, 60.0, "arrows")
	await _missiles(BOLT, 42.0, "the mage's bolts")
	await _bolt_shaken_off()
	await _run_and_leap()
	_finish()


## Shots at a wolf that is after him, from `gap` metres: how many it gets out of.
func _shots(wolf: Wolf, scene: String, speed: float, gap: float, shots: int) -> int:
	var dodged := 0
	for k in shots:
		_reset_player(_spot)
		wolf.global_position = _spot + Vector3(0.0, 0.3, -gap)
		wolf.velocity = Vector3.ZERO
		wolf._busy = 0.0
		wolf._judged.clear()
		await _wait(8)
		var shot: Arrow = (load(scene) as PackedScene).instantiate()
		_world.add_child(shot)
		var from := _player.global_position + Vector3.UP * 1.5
		shot.global_position = from
		var aim := (wolf.global_position + Vector3.UP * 0.9) - from
		shot.launch(aim.normalized() * speed, 1.0, false, 0.0, _player)
		if shot is SpellBolt:
			(shot as SpellBolt).hunt(wolf)
		for i in 90:
			await physics_frame
			_hold_player()
			wolf.global_position.x = _spot.x
			if wolf._slipping > 0.0:
				dodged += 1
				break
		await _wait(20)
		if is_instance_valid(shot):
			shot.queue_free()
	return dodged


func _missiles(scene: String, speed: float, what: String) -> void:
	var wolf := _wolves[0]
	_set_wit(wolf, 0.6)
	_bring(wolf, _spot + Vector3(0.0, 0.0, -12.0))
	var charge := wolf.charge_speed
	wolf.charge_speed = 0.0
	var far := await _shots(wolf, scene, speed, 12.0, 16)
	var near := await _shots(wolf, scene, speed, 3.5, 16)
	wolf.charge_speed = charge
	_check("from far off it gets out of the way of most of %s" % what, far >= 11, "%d of 16" % far)
	_check("and close in, of many too", near >= 5, "%d of 16" % near)
	_park(wolf)


## A bolt hunting a wolf that throws itself aside goes on straight and misses.
func _bolt_shaken_off() -> void:
	var wolf := _wolves[1]
	_set_wit(wolf, 0.6)
	wolf.missile_dodge_far = 10.0
	wolf.missile_dodge_near = 10.0
	var missed := 0
	for k in 6:
		_reset_player(_spot)
		_bring(wolf, _spot + Vector3(0.0, 0.0, -10.0))
		wolf.charge_speed = 0.0
		wolf._judged.clear()
		await _wait(8)
		var before := wolf.health
		var bolt: SpellBolt = (load(BOLT) as PackedScene).instantiate()
		_world.add_child(bolt)
		var from := _player.global_position + Vector3.UP * 1.5
		bolt.global_position = from
		bolt.launch(((wolf.global_position + Vector3.UP * 0.9) - from).normalized() * 42.0, 20.0, false, 0.0, _player)
		bolt.hunt(wolf)
		for i in 120:
			await physics_frame
			_hold_player()
		if wolf.health >= before:
			missed += 1
		if is_instance_valid(bolt):
			bolt.queue_free()
	_check("a bolt it throws itself aside from does not come round after it", missed >= 5, "%d of 6 missed" % missed)
	_park(wolf)


## On all fours after him from 20 m: fast, and the run ends in a leap that
## lands on him.
func _run_and_leap() -> void:
	var wolf: Wolf = null
	for w in _wolves:
		if w.rig.gait > 0.5:
			wolf = w
			break
	_check("there is a wolf that goes on all fours", wolf != null)
	if wolf == null:
		return
	_set_wit(wolf, 0.6)
	_reset_player(_spot)
	_bring(wolf, _spot + Vector3(0.0, 0.0, -20.0))
	_struck.clear()
	var fastest := 0.0
	var leapt := false
	var leapt_from := 0.0
	var highest := 0.0
	var ground_y := wolf.global_position.y
	for i in 60 * 6:
		await physics_frame
		_hold_player()
		var planar := Vector3(wolf.velocity.x, 0.0, wolf.velocity.z).length()
		if not leapt:
			fastest = maxf(fastest, planar)
		if wolf._leap_in >= 0.0 and not leapt:
			leapt = true
			leapt_from = wolf.global_position.distance_to(_player.global_position)
		if leapt:
			highest = maxf(highest, wolf.global_position.y - ground_y)
		if leapt and not _struck.is_empty():
			break
	_check("on all fours it runs him down fast", fastest > 7.5, "%.1f m/s" % fastest)
	_check("and ends the run with a leap", leapt and leapt_from > 2.5, "from %.1f m" % leapt_from)
	_check("off the ground", highest > 0.4, "%.2f m up" % highest)
	_check("its claws landing on him", not _struck.is_empty(), str(_struck))
	_park(wolf)


#region Helpers
func _set_wit(wolf: Wolf, wit: float) -> void:
	wolf.intellect = wit
	wolf.mind.intellect = wit


func _flat() -> Vector3:
	var space := _world.get_world_3d().direct_space_state
	for c in [Vector3(0, 0, -60), Vector3(20, 0, -80), Vector3(-30, 0, -120)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3.UP * 60, c + Vector3.DOWN * 60, 1))
		if not hit.is_empty():
			return hit.position
	return Vector3.ZERO


var _hold := Vector3.ZERO


func _reset_player(at: Vector3) -> void:
	_hold = at
	_player.global_position = at + Vector3.UP * 0.2
	_player.velocity = Vector3.ZERO
	if _player.state == Player.State.DOWNED:
		_player.state = Player.State.GROUNDED
	_player.is_invulnerable = false


func _hold_player() -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(_hold.x, _player.global_position.y, _hold.z)


func _bring(wolf: Wolf, at: Vector3) -> void:
	wolf.global_position = at + Vector3.UP * 0.3
	wolf.velocity = Vector3.ZERO
	wolf.state = Wolf.State.CHASE
	wolf._provoked = 30.0
	wolf._busy = 0.0
	wolf.set_physics_process(true)


func _park(wolf: Wolf) -> void:
	wolf.set_physics_process(false)
	wolf.global_position += Vector3(0.0, -60.0, 0.0)


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
#endregion
