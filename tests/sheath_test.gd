extends SceneTree
## The sword put away in the scabbard the figure wears and drawn from it
## (`SkinnedRig` "The scabbard", [Sheath]):
## - the swordsman's scabbard is on his back, the fighter's at his hip;
## - put away, the blade lies in the scabbard; one press of attack draws it
##   and the first cut goes, with no second press;
## - out of the fight it goes back of its own accord.
##   Godot --headless --path . --script res://tests/sheath_test.gd
var _failures := 0
var player: Player
var rig: SkinnedRig


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


## How far the blade's middle is from the scabbard's box (0 inside it).
func _out_of_scabbard() -> float:
	var mesh := rig._sheath.get("mesh") as MeshInstance3D
	if mesh == null:
		return 99.0
	var box := mesh.global_transform * mesh.get_aabb()
	var mid := (rig._blade_base.global_position + rig._blade_tip.global_position) * 0.5
	if box.has_point(mid):
		return 0.0
	var near := mid.clamp(box.position, box.end)
	return near.distance_to(mid)


func _hand_to_grip() -> float:
	var w := rig._figure_skel.find_bone("R_wrist_joint")
	var hand := rig._figure_skel.global_transform * rig._figure_skel.get_bone_global_pose(w).origin
	return hand.distance_to(rig._blade_base.global_position)


func _wear(cls: String) -> void:
	player.set_look(PolysplitLook.dress(PolysplitLook.default_look(&"tariel", "m"), &"tariel", cls))
	player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
	await _frames(10)


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _frames(2)
	player = world.player()
	player.immortal = true
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	rig = player.rig as SkinnedRig
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.camera_rig.rotation.y = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(20)

	await _wear("fighter")
	_check("the fighter's scabbard is at his hip", rig.can_sheathe() and rig._sheath.get("where") == &"hips",
			str(rig._sheath.get("where")))
	await _wear("swordsman")
	_check("the swordsman's is on his back", rig.can_sheathe() and rig._sheath.get("where") == &"back",
			str(rig._sheath.get("where")))
	rig._wear_string(0)
	await _frames(30)
	_check("drawn to start with, in his fist", not player.weapons_stowed() and _hand_to_grip() < 0.25,
			"(%.2f m)" % _hand_to_grip())

	# put away by hand (the stow key)
	await _tap("stow")
	await physics_frame
	_check("put away with Kevin's clip", rig._anim.current_animation == "KV_SheatheBack01_R", rig._anim.current_animation)
	await _frames(70)
	_check("away: in the scabbard", rig.weapons_slung() >= 1.0 and _out_of_scabbard() < 0.05,
			"(slung %.2f, %.2f m out)" % [rig.weapons_slung(), _out_of_scabbard()])

	# one press: drawn, and the cut goes
	await _tap("attack")
	await physics_frame
	_check("one press draws it", rig.is_drawing() and rig._anim.current_animation == "KV_UnsheatheBack01_R",
			rig._anim.current_animation)
	var swung := false
	for i in 60:
		await physics_frame
		if rig.current_swing() == &"Sword_Regular_A":
			swung = true
			break
	_check("and the first cut goes without another press", swung)
	await _frames(3)
	_check("the sword is in his fist again", rig.weapons_slung() <= 0.0 and _hand_to_grip() < 0.25,
			"(slung %.2f, %.2f m)" % [rig.weapons_slung(), _hand_to_grip()])

	# out of the fight it goes back of its own accord
	var away := false
	for i in 60 * 10:
		await physics_frame
		if player.weapons_stowed():
			away = true
			break
	_check("out of the fight it goes back by itself", away)

	print("sheath_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
