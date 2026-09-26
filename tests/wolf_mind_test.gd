extends SceneTree

## The wolf's fighting mind ([WolfMind]): what intellect buys, a cunning wolf
## getting out of the knight's swings more than a dull one, its combos landing,
## backing off and coming again, the pack taking turns, a wolf with a leg gone
## crawling at him and lunging, one with no arms biting, and a cut limb coming
## to rest on the ground.
##
##     godot --path . --headless --script res://tests/wolf_mind_test.gd

var _failures := 0
var _struck: Array[float] = []
var _player: Player
var _world: World
var _wolves: Array[Wolf] = []
var _spot := Vector3.ZERO


func _initialize() -> void:
	# The wit table first, off the class alone.
	var dull := WolfMind.new(null, 0.2)
	var sharp := WolfMind.new(null, 0.9)
	_check("a cunning wolf sees a swing sooner", sharp.reaction() < dull.reaction(),
			"%.2f vs %.2f" % [sharp.reaction(), dull.reaction()])
	_check("and gets out of more of them", sharp.dodge_chance() > dull.dodge_chance() + 0.3)
	_check("and strings longer combos", sharp.combo_max() == 3 and dull.combo_max() == 1)

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
	for node in _world.get_node("Enemies").get_children():
		if node is Wolf:
			_wolves.append(node)
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -60.0, 0.0)
	_check("there are wolves enough for every trial", _wolves.size() >= 8, "%d" % _wolves.size())
	# Nothing dies here: the trials are about how they fight.
	for w in _wolves:
		w.corpse_linger = 9999.0
		w.limbs_before_death = 99
		w.max_health = 100000.0
		w.health = w.max_health
	_spot = _flat()

	_looks()
	await _dodging()
	await _missiles()
	await _tell()
	await _fighting()
	await _pack()
	await _crippled()
	await _disarmed()
	_finish()


## Coats and gaits: not all alike.
func _looks() -> void:
	var coats := {}
	var gaits := {}
	for w in _wolves:
		coats[w.rig.coat_name] = true
		gaits[w.rig.gait] = true
	_check("the wolves are not all one colour", coats.size() >= 2, str(coats.keys()))
	_check("some go on four legs, some on two", gaits.size() == 2, str(gaits.keys()))


## Arrows loosed at it: from far off it gets out of the way of most; coming in
## close, of few.
func _shots(wolf: Wolf, gap: float, shots: int) -> int:
	var dodged := 0
	for k in shots:
		_reset_player(_spot)
		wolf.global_position = _spot + Vector3(0.0, 0.3, -gap)
		wolf.velocity = Vector3.ZERO
		wolf._busy = 0.0
		wolf._judged.clear()
		await _wait(8)
		var arrow: Arrow = (load("res://scenes/props/arrow.tscn") as PackedScene).instantiate()
		_world.add_child(arrow)
		var from := _player.global_position + Vector3.UP * 1.5
		arrow.global_position = from
		var aim := (wolf.global_position + Vector3.UP * 0.9) - from
		arrow.launch(aim.normalized() * 60.0, 1.0, false, 0.0, _player)
		for i in 30:
			await physics_frame
			_hold_player()
			wolf.global_position.x = _spot.x
			if wolf._slipping > 0.0:
				dodged += 1
				break
		await _wait(20)
	return dodged


func _missiles() -> void:
	var wolf := _wolves[0]
	wolf.intellect = 0.7
	wolf.mind.intellect = 0.7
	_bring(wolf, _spot + Vector3(0.0, 0.0, -12.0))
	var charge := wolf.charge_speed
	wolf.charge_speed = 0.0
	var far := await _shots(wolf, 12.0, 20)
	var near := await _shots(wolf, 3.0, 20)
	wolf.charge_speed = charge
	_check("from far off it gets out of the way of most arrows", far >= 14, "%d of 20" % far)
	_check("and close in, of many too, though fewer", near >= 6 and near <= far, "%d of 20" % near)
	_park(wolf)


## Before a pounce, a tell: down low, eyes flaring.
func _tell() -> void:
	var wolf := _wolves[1]
	_bring(wolf, _spot + Vector3(0.0, 0.0, -30.0))
	wolf.set_physics_process(false)
	await _wait(5)
	var rig := wolf.rig
	var rest_y := rig._skeleton.get_bone_pose_position(rig._root_bone).y
	var base := rig._eye_mat.emission_energy_multiplier if rig._eye_mat != null else 1.0
	rig.lunge()
	var lowest := rest_y
	var brightest := base
	for i in 40:
		await process_frame
		wolf.rig.animate(1.0 / 60.0, 0.0, 0.0, 0.0)
		lowest = minf(lowest, rig._skeleton.get_bone_pose_position(rig._root_bone).y)
		if rig._eye_mat != null:
			brightest = maxf(brightest, rig._eye_mat.emission_energy_multiplier)
	_check("before a pounce it crouches down", rest_y - lowest > 0.1, "%.2f" % (rest_y - lowest))
	_check("and its eyes flare", brightest > base * 2.0, "%.1f -> %.1f" % [base, brightest])
	_park(wolf)


#region Trials
## A wolf stood by him while he swings, again and again: how many it gets out of.
func _dodges(wolf: Wolf, swings: int) -> int:
	wolf.mind.intellect = wolf.intellect
	# Its limbs stay on for this: a head taken off ends the count, not a dodge.
	var tolerance := wolf.hit_tolerance
	wolf.hit_tolerance = -1.0
	_reset_player(_spot)
	_bring(wolf, _spot + Vector3(0.0, 0.0, -1.6))
	var dodged := 0
	var was := 0.0
	for s in swings:
		# Standing off, watching him: what it does next is only about his blade.
		wolf.mind._begin(WolfMind.Tactic.WAIT)
		wolf.mind._left = 999.0
		_face_player_to(wolf)
		Input.action_press("attack")
		await _wait(3)
		Input.action_release("attack")
		var serial_before: Variant = _player.rig.get("attack_serial")
		var saw := false
		for i in 50:
			await physics_frame
			_hold_player()
			# Only watching him: none of its own attacks in between.
			if wolf.mind.tactic != WolfMind.Tactic.WAIT:
				wolf.mind.tactic = WolfMind.Tactic.WAIT
			wolf.mind._left = 999.0
			if wolf._evading > 0.0 and was <= 0.0:
				dodged += 1
				saw = true
			was = wolf._evading
		# Back where it was, and whole again, for the next swing: a leg the
		# blade took would leave it unable to leap at all.
		wolf.rig._lost.clear()
		for at in wolf.rig._skeleton.find_children("*", "BoneAttachment3D", true, false):
			(at as Node3D).visible = true
		wolf._reeling = 0.0
		wolf.global_position = _spot + Vector3(0.0, 0.3, -1.6)
		wolf.velocity = Vector3.ZERO
		await _wait(20)
	wolf.hit_tolerance = tolerance
	_park(wolf)
	return dodged


func _dodging() -> void:
	var cunning := _wolves[0]
	var dull := _wolves[1]
	cunning.intellect = 0.95
	dull.intellect = 0.1
	var a := await _dodges(cunning, 12)
	var b := await _dodges(dull, 12)
	_check("a cunning wolf gets out of most of his swings", a >= 6, "%d of 12" % a)
	_check("a dull one out of fewer", b < a, "%d vs %d" % [b, a])


## Left to fight him: its blows land, and a clever one backs off and comes again.
func _fighting() -> void:
	var wolf := _wolves[2]
	wolf.intellect = 0.8
	wolf.mind.intellect = 0.8
	_reset_player(_spot)
	_bring(wolf, _spot + Vector3(0.0, 0.0, -5.0))
	_struck.clear()
	var tactics := {}
	var moves := {}
	var live := 0
	var nearest := INF
	var attacks := 0
	var was_busy := false
	for i in 60 * 20:
		await physics_frame
		_hold_player()
		tactics[wolf.mind.tactic] = true
		if wolf.is_busy() and not was_busy:
			attacks += 1
		was_busy = wolf.is_busy()
		for sw: WeaponSweep in wolf._sweeps:
			if not sw._drawn.is_empty():
				live += 1
				for part: Array in sw._drawn:
					var feet := _player.global_position
					var pts := Geometry3D.get_closest_points_between_segments(part[0], part[1],
							feet + Vector3.UP * 0.12, feet + Vector3.UP * 1.78)
					nearest = minf(nearest, pts[0].distance_to(pts[1]) - float(part[2]))
		if wolf.rig.is_moving_itself():
			moves[wolf.rig._anim.current_animation] = true
		if _player.state == Player.State.DOWNED:
			_player.state = Player.State.GROUNDED
			_player.is_invulnerable = false
	_check("its blows land on him", not _struck.is_empty(), "%d; %d moves, %d live frames, nearest %.2f m, safe %.1f, gap now %.1f" % [
			_struck.size(), attacks, live, nearest, _player._safe_until - _player._now(),
			wolf.global_position.distance_to(_player.global_position)])
	_check("it backs off, waits and comes again", (tactics.has(WolfMind.Tactic.RETREAT) or moves.has("WF_Hop_Back"))
			and tactics.has(WolfMind.Tactic.WAIT) and tactics.has(WolfMind.Tactic.STRIKE),
			"%s %s" % [str(tactics.keys()), str(moves.keys())])
	_check("it does not run away", wolf.state == Wolf.State.FIGHT or wolf.state == Wolf.State.CHASE,
			"state %d" % wolf.state)
	_park(wolf)


## Four clever wolves on him: never more than two going in at once.
func _pack() -> void:
	_reset_player(_spot)
	var pack := _wolves.slice(3, 7)
	for k in pack.size():
		var w: Wolf = pack[k]
		w.intellect = 0.8
		w.mind.intellect = 0.8
		_bring(w, _spot + Vector3(cos(k * PI / 2.0), 0.0, sin(k * PI / 2.0)) * 4.0)
	var worst := 0
	for i in 60 * 8:
		await physics_frame
		_hold_player()
		var going := 0
		for w: Wolf in pack:
			if w.state == Wolf.State.FIGHT and (w.mind.tactic == WolfMind.Tactic.CLOSE):
				going += 1
		worst = maxi(worst, going)
		if _player.state == Player.State.DOWNED:
			_player.state = Player.State.GROUNDED
			_player.is_invulnerable = false
	_check("a clever pack takes turns: at most two close in at once", worst <= WolfMind.PACK_ATTACKERS,
			"%d" % worst)
	for w: Wolf in pack:
		_park(w)


## A leg off: down on its belly, it crawls at him and lunges; and the leg lands.
func _crippled() -> void:
	var wolf := _wolves[7]
	_reset_player(_spot)
	_bring(wolf, _spot + Vector3(0.0, 0.0, -5.0))
	await _wait(10)
	wolf.rig.detach("left leg")
	await _wait(10)
	var ys: Array[float] = []
	var hold := wolf.global_position
	for i in 40:
		await physics_frame
		wolf.global_position = hold
		wolf.velocity = Vector3.ZERO
		ys.append(wolf.rig._skeleton.get_bone_pose_position(wolf.rig._root_bone).y)
	var jump := 0.0
	for i in range(20, ys.size()):
		jump = maxf(jump, absf(ys[i] - ys[i - 1]))
	_check("down on its belly it lies still, not bobbing", jump < 0.02, "%.3f m a frame" % jump)
	_check("a leg off puts it down", wolf.is_crippled()
			and wolf.rig._anim.current_animation == String(WolfRig.DRAG), wolf.rig._anim.current_animation)
	var start := wolf.global_position.distance_to(_player.global_position)
	_struck.clear()
	var lunges := [0]
	wolf.attacked.connect(func() -> void: lunges[0] += 1)
	for i in 60 * 12:
		await physics_frame
		_hold_player()
		if not _struck.is_empty():
			break
	_check("it crawls at him", wolf.global_position.distance_to(_player.global_position) < start - 1.5 or not _struck.is_empty())
	_check("and lunges from the ground", lunges[0] > 0)
	_check("and it gets him", not _struck.is_empty())
	var piece: SeveredLimb = null
	for node in root.find_children("*", "", true, false):
		if node is SeveredLimb:
			piece = node
	_check("the leg that came off lies on the ground, not in the air", piece != null and piece._resting
			and absf(piece._lowest() - piece._ground_under()) < 0.05,
			"%s" % ("none" if piece == null else "%.2f over the ground" % (piece._lowest() - piece._ground_under())))
	_park(wolf)


## Both arms off: it bites.
func _disarmed() -> void:
	var wolf := _wolves[2]
	_reset_player(_spot)
	_bring(wolf, _spot + Vector3(0.0, 0.0, -4.0))
	wolf.rig.detach("left arm")
	wolf.rig.detach("right arm")
	_struck.clear()
	var bit := false
	for i in 60 * 10:
		await physics_frame
		_hold_player()
		bit = bit or wolf.rig._anim.current_animation == String(WolfRig.BITE)
		if not _struck.is_empty() and bit:
			break
	_check("with no arms it bites, and does not run", bit and wolf.state != Wolf.State.FLEE)
	_check("and the bite lands", not _struck.is_empty())
	_park(wolf)
#endregion


#region Helpers
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


func _face_player_to(wolf: Wolf) -> void:
	var d := wolf.global_position - _player.global_position
	_player.rotation.y = atan2(-d.x, -d.z)


func _bring(wolf: Wolf, at: Vector3) -> void:
	wolf.global_position = at + Vector3.UP * 0.3
	wolf.velocity = Vector3.ZERO
	wolf.state = Wolf.State.CHASE
	wolf._provoked = 30.0
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
