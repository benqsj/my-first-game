extends SceneTree

## THE WARRIOR: a hero of his own on his own skeleton (the Knight of darkness'),
## the great sword in both hands.
##
## - he spawns on SkinnedWarriorRig with his own clips, and nothing follows
##   another hero's skeleton;
## - the sword is in his right fist and his left fist is on the hilt under it,
##   standing, walking and through his cuts;
## - his weight: slower to get going, to stop and to turn than Tariel;
## - attack runs his string, the other button his heavy blows, and a cut
##   reaches something in front of him.
##
##     godot --path . --headless --script res://tests/warrior_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	await _spawn(&"warrior")
	var rig := _player.rig as SkinnedWarriorRig
	_check("the warrior stands on his own rig", rig != null, str(_player.rig))
	if rig == null:
		_done()
		return
	var names := rig.clip_names()
	var missing: Array[String] = []
	for key: StringName in rig.clips:
		if not names.has(String(rig.clips[key])):
			missing.append("%s=%s" % [key, rig.clips[key]])
	for c: StringName in rig.flurry:
		if not names.has(String(c)):
			missing.append(String(c))
	for h: Dictionary in rig.heavy:
		if not names.has(String(h["clip"])):
			missing.append(String(h["clip"]))
	_check("with every clip his tables name", missing.is_empty(), str(missing))
	_check("on no one else's skeleton", rig.find_children("*", "FigureFollower", true, false).is_empty()
			and not rig.wearing_figure())
	_check("his skeleton has the root, the sword socket and the mannequin's bones",
			rig._skel.find_bone("root") >= 0 and rig._skel.find_bone("weapon_r") >= 0
			and rig._skel.find_bone("hand_l") >= 0 and rig._skel.find_bone("pelvis") >= 0)
	_check("his sword is found, and no shield", rig._sword_mesh != null and rig._sword_mesh.visible
			and not _player.profile.can_block)
	_check("the blade runs out of the fist along the socket", rig._blade_tip != null
			and rig._blade_base != null and rig._blade_tip.global_position.distance_to(
			rig._blade_base.global_position) > 1.1)
	# his weight
	_check("he is heavier than Tariel: slower to start, stop and turn",
			_player.ground_acceleration < 40.0 and _player.ground_deceleration < 50.0
			and _player.turn_speed < 10.0 and _player.run_speed < 5.6, "acc %.0f dec %.0f turn %.1f run %.1f" % [
			_player.ground_acceleration, _player.ground_deceleration, _player.turn_speed, _player.run_speed])
	# out of a fight: the sword on his shoulder, one hand on it
	await _wait(20)
	_check("out of a fight he stands with the sword on his shoulder", String(rig._anim.current_animation) == "WR_Rest",
			String(rig._anim.current_animation))
	_check("the blade over his right shoulder, pointing back", _on_shoulder(rig))
	# the cloak is cloth
	_check("his cloak hangs as cloth", rig.cloak != null and is_instance_valid(rig.cloak))
	var hem0 := rig.cloak.hem_travel if rig.cloak != null else 0.0
	Input.action_press("move_forward")
	await _wait(40)
	_check("walking out of a fight: the swagger, the sword still on the shoulder",
			["WR_RestWalk", "WR_Run"].has(String(rig._anim.current_animation)), String(rig._anim.current_animation))
	Input.action_release("move_forward")
	await _wait(60)
	_check("and the cloak swings with him", rig.cloak != null and rig.cloak.hem_travel - hem0 > 0.3,
			"%.2f m" % (rig.cloak.hem_travel - hem0 if rig.cloak != null else 0.0))
	_check("its bones hang below where they rest", rig.cloak != null and _cloak_sane(rig))
	# his string
	_player.stamina = _player.max_stamina
	var serial := rig.attack_serial
	Input.action_press("attack")
	await _wait(2)
	Input.action_release("attack")
	await _wait(8)
	var at := _player.global_position
	_check("attack throws the first of his string", String(rig._act_clip) == "WR_Combo_A"
			and rig.attack_serial == serial + 1, String(rig._act_clip))
	var worst := 0.0
	for i in 20:
		await physics_frame
		worst = maxf(worst, _off_hilt(rig))
	_check("through the cut the left hand stays on the hilt", worst < 0.2, "%.3f m off" % worst)
	_check("the cut carries him into it", _player.global_position.distance_to(at) > 0.15,
			"%.2f m" % _player.global_position.distance_to(at))
	_check("a blow puts him in the fighting stance", rig.in_fight())
	_grip(rig, "in the fight")
	await _wait(80)
	# on the move, the other string
	_player.stamina = _player.max_stamina
	Input.action_press("move_forward")
	await _wait(30)
	Input.action_press("attack")
	await _wait(2)
	Input.action_release("attack")
	await _wait(6)
	Input.action_release("move_forward")
	_check("on the move he throws his second string", String(rig._act_clip) == "WR_Combo2_A", String(rig._act_clip))
	await _wait(90)
	_player.stamina = _player.max_stamina
	Input.action_press("block")
	await _wait(2)
	Input.action_release("block")
	await _wait(6)
	var heavies: Array[String] = []
	for h: Dictionary in rig.heavy:
		heavies.append(String(h["clip"]))
	_check("the other button throws a heavy blow", heavies.has(String(rig._act_clip)) and rig.is_heavy(),
			String(rig._act_clip))
	await _wait(120)
	_done()


func _on_shoulder(rig: SkinnedWarriorRig) -> bool:
	var skel := rig._skel
	var sh := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("upperarm_r")).origin
	var tip := rig._blade_tip.global_position
	var back := _player.global_basis.z
	return tip.y > sh.y and (tip - sh).dot(back) > 0.3


func _cloak_sane(rig: SkinnedWarriorRig) -> bool:
	var skel := rig._skel
	var top := skel.find_bone("clk_0_4")
	var hem := skel.find_bone("clk_8_4")
	if top < 0 or hem < 0:
		return false
	var a := skel.get_bone_global_pose(top).origin
	var b := skel.get_bone_global_pose(hem).origin
	return b.y < a.y - 0.6 and a.distance_to(b) < 1.6


## How far the left fist is off the line of the blade (m).
func _off_hilt(rig: SkinnedWarriorRig) -> float:
	var skel := rig._skel
	var base := rig._blade_base.global_position
	var along := (rig._blade_tip.global_position - base).normalized()
	var hand := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hand_l")).origin
	var rel := hand - base
	return (rel - along * rel.dot(along)).length()


func _grip(rig: SkinnedWarriorRig, when: String) -> void:
	var skel := rig._skel
	var r := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hand_r")).origin
	var l := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("hand_l")).origin
	_check("%s: both hands on the hilt" % when, r.distance_to(l) < 0.26 and _off_hilt(rig) < 0.15,
			"hands %.3f apart, left %.3f off the blade's line" % [r.distance_to(l), _off_hilt(rig)])


func _spawn(id: StringName) -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", id)
	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await _wait(2)
	_player = (_world as World).player()
	for body in _world.find_children("*", "CharacterBody3D", true, false):
		if body != _player:
			body.queue_free()
	await _wait(30)


func _done() -> void:
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok    ", what)
	else:
		_failures += 1
		print("  FAIL  ", what, "  (", detail, ")")
