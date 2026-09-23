extends SceneTree

## The orc warriors and Arkdeva: how many and where, how tall, that every
## attack lands what it should, the orc's guard against a drawn bow, and that
## both die.
##
##     godot --path . --headless --script res://tests/boss_test.gd

var _failures := 0
var _struck: Array[float] = []
var _player: Player


func _initialize() -> void:
	# An archer, for the guard. The creatures' blows are the same on anybody.
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"avtandil")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(2)
	world.creature_think_distance = 0.0
	_player = world.player()
	_player.struck.connect(func(damage: float, _blocked: bool) -> void: _struck.append(damage))
	var enemies := world.get_node("Enemies")

	# --- Who and where -----------------------------------------------------------
	var orcs: Array[OrcWarrior] = []
	var arks: Array[Arkdeva] = []
	for node in enemies.get_children():
		if node is OrcWarrior:
			orcs.append(node)
		elif node is Arkdeva:
			arks.append(node)
	_check("two orc warriors", orcs.size() == 2, "%d" % orcs.size())
	_check("one Arkdeva", arks.size() == 1, "%d" % arks.size())
	if orcs.size() < 2 or arks.is_empty():
		_finish()
		return
	var ark := arks[0]
	_check("the orcs hold their ground together", orcs[0].band == orcs[1].band and not orcs[0].band.is_empty())
	_check("Arkdeva's band is its own", get_nodes_in_group_count(ark.band) == 1)
	var nearest := INF
	for node in enemies.get_children():
		if node != ark:
			nearest = minf(nearest, (node as Node3D).global_position.distance_to(ark.global_position))
	_check("and nothing else lives near it", nearest > 35.0, "%.0f m" % nearest)

	var orc_tall := _height(orcs[0])
	var ark_tall := _height(ark)
	_check("an orc is twice Tariel's height, about 3.8 m", orc_tall > 3.4 and orc_tall < 4.3, "%.2f m" % orc_tall)
	_check("Arkdeva is about nine metres", ark_tall > 8.0 and ark_tall < 10.0, "%.2f m" % ark_tall)

	var space := world.get_world_3d().direct_space_state
	for who: Brute in [orcs[0], orcs[1], ark]:
		var down := PhysicsRayQueryParameters3D.create(who.global_position + Vector3.UP,
				who.global_position + Vector3.DOWN * 3.0, 1)
		_check("%s has ground under it" % who.name, not space.intersect_ray(down).is_empty())

	for node in enemies.get_children():
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -50.0, 0.0)

	await _check_orc(orcs[0], orcs[1])
	await _check_arkdeva(ark)
	_finish()


func get_nodes_in_group_count(group: StringName) -> int:
	return root.get_tree().get_nodes_in_group(group).size()


func _finish() -> void:
	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


## Top of the head (or of the body) off the ground, at rest, in metres.
func _height(who: Node3D) -> float:
	var sk := who.find_child("Skeleton3D", true, false) as Skeleton3D
	var top := -INF
	for i in sk.get_bone_count():
		top = maxf(top, (sk.global_transform * sk.get_bone_global_rest(i).origin).y)
	# Bones stop at the last joint; a scythe or a horn carries on past it, so
	# the drawn mesh has its say too. (A skinned mesh's own box is in its
	# armature's units, which is why the bones are measured at all.)
	for node in who.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.get_parent() == null:
			continue
		if mesh.skeleton != NodePath("") and sk != null:
			top = maxf(top, (sk.global_transform * mesh.mesh.get_aabb()).end.y)
		else:
			top = maxf(top, (mesh.global_transform * mesh.mesh.get_aabb()).end.y)
	return top - who.global_position.y


#region The orc
func _check_orc(orc: OrcWarrior, mate: OrcWarrior) -> void:
	orc.global_position = orc._home + Vector3.UP * 0.3
	orc.set_physics_process(true)
	mate.global_position = mate._home + Vector3.UP * 0.3
	mate.set_physics_process(true)
	_player.global_position = orc._home + Vector3(0.0, 0.3, 40.0)
	await _wait(30)
	_check("his own axe clips drive his rig", orc._own != null and orc._own.has_animation(OrcWarrior.IDLE)
			and orc._own.has_animation(OrcWarrior.HEAVY_CLIP) and orc._own.has_animation(&"OR_Combo_2"))
	var sk := orc._skeleton
	var head := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin).y - orc.global_position.y
	var foot := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin).y - orc.global_position.y
	_check("standing, head up and feet down", head > 2.8 and foot < 0.7, "head %.2f foot %.2f" % [head, foot])
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand")).origin
	_check("the axe is in his right fist", orc._axe != null and orc._axe.global_position.distance_to(hand) < 0.8,
			"%.2f m" % (orc._axe.global_position.distance_to(hand) if orc._axe != null else -1.0))
	_check("the combos have their blows", (orc._blows[OrcWarrior.Act.COMBO] as PackedFloat32Array).size() == 2
			and (orc._blows[OrcWarrior.Act.COMBO_THREE] as PackedFloat32Array).size() == 3,
			"%s / %s" % [orc._blows[OrcWarrior.Act.COMBO], orc._blows[OrcWarrior.Act.COMBO_THREE]])
	_check("the overhead blow comes down partway through, not at the ends", orc._slam_at > 0.2 and orc._slam_at < 0.85,
			"%.2f" % orc._slam_at)

	# Roused, both of them, and he comes and fights.
	_player.global_position = orc.camp_centre + Vector3(0.0, 0.3, 8.0)
	await _wait(30)
	_check("a player in sight rouses him", orc.mode != Brute.Mode.GUARD)
	_check("and his mate", mate.mode != Brute.Mode.GUARD)
	mate.set_physics_process(false)
	mate.global_position += Vector3(0.0, -50.0, 0.0)
	_struck.clear()
	var attacked := false
	for i in 900:
		await physics_frame
		attacked = attacked or orc.act != Brute.ACT_NONE
		if not _struck.is_empty():
			break
	_check("he closes in and swings", attacked)
	_check("his axe lands", not _struck.is_empty(), str(_struck))
	await _stand_up()

	# The heavy combo from out of reach: the spikes carry to where the axe cannot.
	orc._cooldown = 999.0
	await _until_idle(orc)
	var spot := orc.global_position
	_player.global_position = spot + orc._forward() * 6.5 + Vector3.UP * 0.2
	_struck.clear()
	orc._begin(OrcWarrior.Act.HEAVY, OrcWarrior.HEAVY_CLIP, 1.0)
	var slammed := false
	for i in 400:
		orc.global_position = Vector3(spot.x, orc.global_position.y, spot.z)
		_player.velocity = Vector3.ZERO
		await physics_frame
		if orc._slammed and not slammed:
			print("  (slam: waves %d, player %.1f m off, state %d, invulnerable %s, y %.2f vs %.2f)" % [
					orc._waves.size(), _player.global_position.distance_to(spot), _player.state,
					_player.is_invulnerable, _player.global_position.y, orc._slam_point.y])
		slammed = slammed or orc._slammed
		if orc.act == Brute.ACT_NONE:
			break
	await _wait(20)
	_check("the heavy combo ends in the slam", slammed)
	var landed := orc._slam_point - spot
	_check("the spikes out of the ground reach six and a half metres off", _struck.has(orc.wave_damage),
			"%s; the axe came down %.1f m ahead, %.1f to the side" % [str(_struck),
			landed.dot(orc._forward()), landed.dot(orc._forward().cross(Vector3.UP))])
	_check("and nothing else did", _struck.size() == 1, str(_struck))
	await _stand_up()

	# The guard: only a drawn bow on him raises it.
	await _until_idle(orc)
	spot = orc.global_position
	_player.global_position = spot + orc._forward() * 12.0 + Vector3.UP * 0.2
	var aim := spot - _player.global_position
	_player.rotation.y = atan2(-aim.x, -aim.z)
	await _wait(10)
	_check("no bow, no guard", not orc.guarding)
	Input.action_press("attack")
	var guarded := false
	for i in 20:
		orc.global_position = Vector3(spot.x, orc.global_position.y, spot.z)
		_player.rotation.y = atan2(-aim.x, -aim.z)
		await physics_frame
		guarded = guarded or orc.guarding
	_check("a bow drawn on him raises his arm", guarded, "drawing %s" % _player.is_drawing())
	var before := orc.health
	orc.take_hit(20.0, orc.global_position + Vector3.UP * 2.2, Vector3.FORWARD, false, true, _player)
	var guarded_loss := before - orc.health
	var open_expected := 20.0 * (1.0 - orc.armour)
	_check("and an arrow does much less behind it",
			guarded_loss > 0.0 and guarded_loss < open_expected * 0.5,
			"%.1f, against %.1f open" % [guarded_loss, open_expected])
	# Turned away, the bow is no threat.
	_player.rotation.y = atan2(aim.x, aim.z)
	for i in 70:
		orc.global_position = Vector3(spot.x, orc.global_position.y, spot.z)
		_player.rotation.y = atan2(aim.x, aim.z)
		await physics_frame
	_check("a bow aimed elsewhere does not", not orc.guarding)
	Input.action_release("attack")
	await _wait(60)
	before = orc.health
	orc.take_hit(20.0, orc.global_position + Vector3.UP * 2.2, Vector3.FORWARD, false, true, _player)
	_check("open, an arrow does all of it, less his armour",
			is_equal_approx(before - orc.health, open_expected), "%.1f" % (before - orc.health))

	# And he dies.
	for i in 40:
		if orc.is_dead:
			break
		orc.take_hit(160.0, orc.global_position + Vector3.UP * 1.5, Vector3.FORWARD, false, true, _player)
		await _wait(2)
	_check("enough arrows kill an orc", orc.is_dead)
	await _wait(60)
	var hips := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips")).origin).y - orc.global_position.y
	_check("and he goes down", hips < orc.body_height * 0.5, "hips %.2f m up" % hips)
	var gone := false
	for i in 60 * 9:
		await physics_frame
		if not is_instance_valid(orc):
			gone = true
			break
	_check("and is cleared away", gone)
#endregion


#region Arkdeva
func _check_arkdeva(ark: Arkdeva) -> void:
	ark.global_position = ark._home + Vector3.UP * 0.3
	ark.set_physics_process(true)
	_player.global_position = ark._home + Vector3(0.0, 0.3, 40.0)
	await _wait(20)
	_check("its limbs are found", ark._legs.size() == 4 and ark._arms.size() == 2,
			"%d legs %d arms" % [ark._legs.size(), ark._arms.size()])
	var sk := ark._skeleton
	var front := Vector3.ZERO
	for id in ["FL", "FR"]:
		front += sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Leg_%s_00" % id)).origin
	for id in ["BL", "BR"]:
		front -= sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Leg_%s_00" % id)).origin
	front.y = 0.0
	_check("its front legs are its front", front.normalized().dot(ark._forward()) > 0.9,
			"%.2f" % front.normalized().dot(ark._forward()))

	# Walking moves the legs.
	var leg := sk.find_bone("Leg_FL_00")
	var still := sk.get_bone_pose_rotation(leg)
	ark.velocity = ark._forward() * 1.5
	ark._walk = 1.0
	ark._phase = 1.0
	ark._animate(0.1)
	_check("walking swings the legs", sk.get_bone_pose_rotation(leg).angle_to(still) > 0.02)
	ark.velocity = Vector3.ZERO

	ark._cooldown = 999.0
	await _attack(ark, Arkdeva.Act.STAMP, 5.5, "the stamp", ark.stamp_damage)
	await _attack(ark, Arkdeva.Act.STRIKE_L, 5.2, "the left scythe", ark.strike_damage)
	await _attack(ark, Arkdeva.Act.STRIKE_R, 5.2, "the right scythe", ark.strike_damage)
	await _attack(ark, Arkdeva.Act.CHOP, 5.4, "the chop from over the top", ark.chop_damage)

	# The combo: close, the three scythes; far, only the thorns.
	await _stand_up()
	var spot := ark.global_position
	_player.global_position = spot + ark._forward() * 5.2 + Vector3.UP * 0.2
	_struck.clear()
	ark._begin(Arkdeva.Act.COMBO)
	var downed := false
	for i in 400:
		ark.global_position = Vector3(spot.x, ark.global_position.y, spot.z)
		_player.velocity = Vector3.ZERO
		await physics_frame
		downed = downed or _player.state == Player.State.DOWNED
		if ark.act == Brute.ACT_NONE:
			break
	_check("the combo's scythes land", _struck.size() >= 2, str(_struck))
	_check("all three, and he is floored", downed, str(_struck))
	await _stand_up()
	_player.global_position = spot + ark._forward() * 12.0 + Vector3.UP * 0.2
	_struck.clear()
	ark._begin(Arkdeva.Act.COMBO)
	for i in 400:
		ark.global_position = Vector3(spot.x, ark.global_position.y, spot.z)
		_player.velocity = Vector3.ZERO
		await physics_frame
		if ark.act == Brute.ACT_NONE:
			break
	await _wait(10)
	_check("the thorns reach twelve metres out, a hit of their own", _struck == [ark.thorn_damage], str(_struck))
	_player.global_position = spot + ark._forward() * 2.0 + ark.global_transform.basis.x * 14.0 + Vector3.UP * 0.2
	_struck.clear()
	# Held facing ahead: left to itself it would turn on him.
	var turn := ark.turn_speed
	ark.turn_speed = 0.0
	ark._begin(Arkdeva.Act.COMBO)
	for i in 400:
		ark.global_position = Vector3(spot.x, ark.global_position.y, spot.z)
		await physics_frame
		if ark.act == Brute.ACT_NONE:
			break
	ark.turn_speed = turn
	_check("but not off to the side", _struck.is_empty(), str(_struck))

	# Poison, spat forward.
	await _stand_up()
	_player.global_position = spot + ark._forward() * 16.0 + Vector3.UP * 0.2
	_struck.clear()
	ark._begin(Arkdeva.Act.SPIT_TWO)
	for i in 300:
		ark.global_position = Vector3(spot.x, ark.global_position.y, spot.z)
		_player.velocity = Vector3.ZERO
		await physics_frame
		if ark.act == Brute.ACT_NONE and ark._gobs.is_empty():
			break
	await _wait(10)
	_check("the poison flies forward and lands on him", _struck.has(ark.poison_damage), str(_struck))

	# It decides for itself, too.
	await _stand_up()
	ark._cooldown = 0.0
	_player.global_position = spot + ark._forward() * 6.0 + Vector3.UP * 0.2
	var seen := {}
	for i in 1500:
		_player.velocity = Vector3.ZERO
		await physics_frame
		if ark.act != Brute.ACT_NONE:
			seen[ark.act] = true
		if _player.state == Player.State.DOWNED:
			_player.state = Player.State.GROUNDED
			_player.is_invulnerable = false
		if seen.size() >= 3:
			break
	_check("left to itself it uses several attacks", seen.size() >= 2, str(seen.keys()))

	for i in 40:
		if ark.is_dead:
			break
		ark.take_hit(200.0, ark.global_position + Vector3.UP * 2.0, Vector3.FORWARD, false, true, _player)
		await _wait(2)
	_check("Arkdeva can be killed", ark.is_dead)
	await _wait(60)
	_check("and it collapses", ark._tilt.position.y < -0.5 * ark.visual_scale, "%.2f" % ark._tilt.position.y)


func _attack(ark: Arkdeva, what: int, gap: float, label: String, damage: float) -> void:
	await _stand_up()
	await _until_idle(ark)
	var spot := ark.global_position
	_player.global_position = spot + ark._forward() * gap + Vector3.UP * 0.2
	_struck.clear()
	ark._begin(what)
	for i in 300:
		ark.global_position = Vector3(spot.x, ark.global_position.y, spot.z)
		_player.velocity = Vector3.ZERO
		await physics_frame
		if ark.act == Brute.ACT_NONE:
			break
	_check("%s lands for %d" % [label, damage], _struck.has(damage), str(_struck))
#endregion


## Back on his feet and able to be hit, whatever the last check did to him.
func _stand_up() -> void:
	for i in 240:
		if _player.state != Player.State.DOWNED and not _player.is_invulnerable:
			break
		await physics_frame
	if _player.state == Player.State.DOWNED:
		_player.state = Player.State.GROUNDED
	_player.is_invulnerable = false
	await _wait(30)


func _until_idle(who: Brute) -> void:
	for i in 500:
		if who.act == Brute.ACT_NONE:
			return
		await physics_frame


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
