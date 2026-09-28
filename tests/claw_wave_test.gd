extends SceneTree

## The wolf's claw wave ([WolfClaw], [ClawWave]): its clips are there, the tell
## is long enough to read (a paw raised over its head, the claws burning, the
## eyes flaring), a cunning wolf throws three waves in a combo and a dull one
## one, they land on a knight who stands there, a roll goes through them, a
## step aside gets out of the upright ones, a shield catches them, a wall
## breaks them, and it is thrown now and then, not all the time.
##
##     godot --path . --headless --script res://tests/claw_wave_test.gd

var _failures := 0
var _struck: Array = []
var _player: Player
var _world: World
var _wolf: Wolf
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
		if node is Wolf and _wolf == null:
			_wolf = node
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -60.0, 0.0)
	_wolf.corpse_linger = 9999.0
	_wolf.limbs_before_death = 99
	_wolf.max_health = 100000.0
	_wolf.health = _wolf.max_health
	_spot = _flat()

	_clips()
	await _stands_there()
	await _rolls()
	await _steps_aside()
	await _shield()
	await _wall()
	await _on_a_ledge()
	await _now_and_then()
	await _not_without_arms()
	_finish()


func _clips() -> void:
	var claw := _wolf.rig.claw
	_check("the claw clips are on the wolf", claw != null and claw.has_clips())
	_check("the rake raises one paw, the slam both", claw._paw.get(&"rake", "") in ["l", "r"]
			and claw._paw.get(&"slam", "") == "both", str(claw._paw))


## A cunning wolf, 7 m off a knight standing there: the tell, three waves, and
## they land.
func _stands_there() -> void:
	_set_wit(0.95)
	_reset_player(_spot)
	_bring(_wolf, _spot + Vector3(0.0, 0.0, -7.0))
	await _wait(10)
	_struck.clear()
	_wolf._claw_wait = 0.0
	_wolf.attack(&"claw_wave")
	var begun := _clock()
	var first_wave := -1.0
	var waves := {}
	var brightest := 0.0
	var eyes := 0.0
	var paw_high := -INF
	var rig := _wolf.rig
	var head_y := 0.0
	for i in 60 * 7:
		await physics_frame
		_hold_player()
		for w in _waves():
			if not waves.has(w):
				waves[w] = true
				if first_wave < 0.0:
					first_wave = _clock() - begun
		var b := rig.claw._beat(rig.claw._t) if rig.claw.active() else Vector2(-1, 0)
		if rig.claw.active() and rig.claw._blow == &"rake" and b.x == 1:
			var paw: String = rig.claw._paw[&"rake"]
			paw_high = maxf(paw_high, (rig._claw_tips[paw] as Node3D).global_position.y - _wolf.global_position.y)
			head_y = (rig._skeleton.global_transform * rig._skeleton.get_bone_global_pose(rig._head).origin).y \
					- _wolf.global_position.y
			for g: MeshInstance3D in rig._glints.values():
				if g.visible:
					brightest = maxf(brightest, (g.material_override as StandardMaterial3D).albedo_color.a)
			if rig._eye_mat != null:
				eyes = maxf(eyes, rig._eye_mat.emission_energy_multiplier / rig._eye_base)
	_check("before the first wave, a tell long enough to read", first_wave >= 0.9,
			"%.2f s" % first_wave)
	_check("in it the paw is raised over its head", paw_high > head_y, "paw %.2f, head %.2f" % [paw_high, head_y])
	_check("and its claws burn and its eyes flare", brightest > 0.5 and eyes > 3.0, "%.2f, x%.1f" % [brightest, eyes])
	_check("a cunning wolf throws three waves", waves.size() == 3, "%d" % waves.size())
	_check("and they land on him standing there", _struck.size() >= 3, str(_struck))


## Rolled through as each comes: nothing lands.
func _rolls() -> void:
	_set_wit(0.95)
	_reset_player(_spot)
	_bring(_wolf, _spot + Vector3(0.0, 0.0, -8.0))
	await _wait(10)
	_struck.clear()
	_wolf._claw_wait = 0.0
	_wolf.attack(&"claw_wave")
	var rolled := {}
	var landed := -1
	for i in 60 * 7:
		await physics_frame
		if landed < 0 and rolled.size() == 3 and _waves().is_empty():
			# The combo is done: what the wolf does with its claws next is not it.
			landed = _struck.size()
		for w: ClawWave in _waves():
			var gap := w.global_position.distance_to(_player.global_position + Vector3.UP)
			if not rolled.has(w) and gap < 3.6:
				rolled[w] = true
				_player.stamina = _player.max_stamina
				_player._try_dash(false, false, true)
		if _player.state != Player.State.DASHING and _player.state != Player.State.DODGING:
			_hold_player()
	_check("rolled through as each comes, none lands", rolled.size() == 3 and landed == 0,
			"%d rolled, %d landed" % [rolled.size(), landed])


## A step aside out of the upright ones (the rake, the slam), once they are
## thrown.
func _steps_aside() -> void:
	_set_wit(0.95)
	var hits := {}
	for blow: StringName in [&"rake", &"slam"]:
		_reset_player(_spot)
		_bring(_wolf, _spot + Vector3(0.0, 0.0, -8.0))
		await _wait(10)
		_struck.clear()
		var list: Array[StringName] = [blow]
		_wolf._claw_wait = 99.0
		_wolf._busy = WolfClaw.duration(list, 0.6)
		_wolf.rig.claw.begin(list, 0.6)
		var moved := false
		for i in 60 * 3:
			await physics_frame
			if not moved and not _waves().is_empty():
				moved = true
				_hold = _spot + Vector3(2.4, 0.0, 0.0)
				_player.global_position = _hold + Vector3.UP * 0.2
			_hold_player()
		hits[blow] = _struck.size()
	_check("a step aside gets out of the rake and the slam", hits[&"rake"] == 0 and hits[&"slam"] == 0, str(hits))


## A shield held up towards it catches it.
func _shield() -> void:
	_set_wit(0.2)
	_reset_player(_spot)
	_bring(_wolf, _spot + Vector3(0.0, 0.0, -7.0))
	await _wait(10)
	_face_player_to(_wolf)
	_struck.clear()
	_wolf._claw_wait = 0.0
	_wolf.attack(&"claw_wave")
	Input.action_press("block")
	for i in 60 * 3:
		await physics_frame
		_hold_player()
		_face_player_to(_wolf)
	Input.action_release("block")
	_check("a shield catches it", _struck.size() == 1 and bool(_struck[0][1]), str(_struck))


## Thrown at a wall, it breaks on it.
func _wall() -> void:
	_park(_wolf)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 0.5)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.global_position = _spot + Vector3(0.0, 1.5, -5.0)
	var wave := ClawWave.throw(_world, _spot + Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, 0.0)
	# Unbroken it would fly on for more than a second.
	var gone_at := -1.0
	var start := _clock()
	for i in 60:
		await physics_frame
		if not is_instance_valid(wave):
			gone_at = _clock() - start
			break
	_check("a wall breaks it", gone_at > 0.0 and gone_at < 0.65, "gone after %.2f s" % gone_at)
	wall.queue_free()


## Him up on a ledge three metres over it: the waves are thrown up at him, not
## level under his feet, and they reach him.
func _on_a_ledge() -> void:
	_set_wit(0.95)
	var ledge := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 3.0)
	shape.shape = box
	ledge.add_child(shape)
	_world.add_child(ledge)
	ledge.global_position = _spot + Vector3(0.0, 1.5, 0.0)
	_reset_player(_spot + Vector3.UP * 3.05)
	_bring(_wolf, _spot + Vector3(0.0, 0.0, -7.5))
	await _wait(10)
	_struck.clear()
	_wolf._claw_wait = 0.0
	_wolf.attack(&"claw_wave")
	var steepest := -1.0
	for i in 60 * 6:
		await physics_frame
		_hold_player()
		for w in _waves():
			if not (w as ClawWave).ground:
				steepest = maxf(steepest, (w as ClawWave)._dir.y)
	_check("up on a ledge, the waves are thrown up at him", steepest > 0.15, "%.2f" % steepest)
	_check("and they reach him there", _struck.size() >= 1, str(_struck))
	ledge.queue_free()
	await _wait(2)


## Left to fight him from out of reach for 30 s: it throws the claws now and
## then, not all the time.
func _now_and_then() -> void:
	_set_wit(0.6)
	_reset_player(_spot)
	_bring(_wolf, _spot + Vector3(0.0, 0.0, -8.0))
	_wolf._claw_wait = 3.0
	var throws := 0
	var was := false
	for i in 60 * 30:
		await physics_frame
		# He keeps out of reach, as an archer would.
		var d := _wolf.global_position - _player.global_position
		d.y = 0.0
		if d.length() < 7.0:
			_hold = _hold - d.normalized() * (7.0 - d.length())
		_hold_player()
		if _player.state == Player.State.DOWNED:
			_player.state = Player.State.GROUNDED
			_player.is_invulnerable = false
		var now := _wolf.rig.is_clawing()
		if now and not was:
			throws += 1
		was = now
	_check("kept at a distance, it throws the claws now and then", throws >= 1 and throws <= 3,
			"%d in 30 s" % throws)
	_park(_wolf)


func _not_without_arms() -> void:
	_bring(_wolf, _spot + Vector3(0.0, 0.0, -7.0))
	_wolf._claw_wait = 0.0
	_wolf.rig.detach("left arm")
	_check("with an arm gone it throws no more", not _wolf.can_claw(7.0))
	_park(_wolf)


#region Helpers
func _set_wit(wit: float) -> void:
	_wolf.intellect = wit
	_wolf.mind.intellect = wit


func _waves() -> Array:
	var out := []
	for node in _world.get_children():
		if node is ClawWave and not (node as ClawWave).is_queued_for_deletion() and (node as ClawWave)._ending < 0.0:
			out.append(node)
	return out


func _clock() -> float:
	return Time.get_ticks_msec() / 1000.0


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
	_player._safe_until = 0.0


func _hold_player() -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(_hold.x, _player.global_position.y, _hold.z)


func _face_player_to(wolf: Wolf) -> void:
	var d := wolf.global_position - _player.global_position
	_player.rotation.y = atan2(-d.x, -d.z)


func _bring(wolf: Wolf, at: Vector3) -> void:
	# Whatever it was throwing in the last trial, done with.
	wolf.rig.claw.cancel()
	for w in _waves():
		(w as Node).queue_free()
	wolf.global_position = at + Vector3.UP * 0.3
	wolf.velocity = Vector3.ZERO
	wolf.state = Wolf.State.CHASE
	wolf._provoked = 30.0
	wolf._busy = 0.0
	# Only the claw wave here, not the leap at the end of a run.
	wolf._leap_wait = 999.0
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
