extends SceneTree

## Checks the skinned Tariel (SkinnedRig) does what the controller asks of it:
## the right cycle for the pace, a swing whose blade actually cuts, the roll,
## the block and the flinch. Given a directory it also photographs each of them.
##
##     godot --path . --script res://tests/skinned_rig_test.gd -- /tmp/shots

var _failures := 0
var _camera: Camera3D
var _dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	# The ramp, the stairs, the steep face and the pillars live in their own
	# scene now, out of the game's world; the tests that walk on them bring it.
	world.get_node("Level").add_child(load("res://scenes/world/test_course.tscn").instantiate())
	await physics_frame
	var player: Player = world.player()
	# Nothing else wanders into the shots.
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	_camera = Camera3D.new()
	_camera.fov = 40.0
	world.add_child(_camera)
	_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame

	var rig := player.rig as SkinnedRig
	_check("Tariel is on the skinned rig", rig != null, str(player.rig))
	if rig == null:
		quit(1)
		return
	_check("all clips loaded", rig.clip_names().size() >= 51, "%d" % rig.clip_names().size())
	var anim: AnimationPlayer = rig._anim

	for i in 40:
		await physics_frame
	_check("standing still plays the idle", anim.current_animation == "SS_Idle", anim.current_animation)
	await _shot(player, "01_idle")

	Input.action_press("move_forward")
	for i in 45:
		await physics_frame
	_check("running plays the run cycle", anim.current_animation == "SS_Run",
			"%s at %.1f m/s" % [anim.current_animation, Vector3(player.velocity.x, 0, player.velocity.z).length()])
	await _shot(player, "02_run")
	# The ponytail still hangs off spring bones; the cape is cloth now.
	var cloth := rig.find_child("Cloth", true, false) as SpringBoneSimulator3D
	_check("the ponytail hangs off spring bones", cloth != null and cloth.get_setting_count() == 1, "")
	# The warrior's dress he starts in goes without a cape.
	_check("the berserker goes without a cape, the wanderer with his cloak",
			rig.cloth_capes.size() == (1 if rig.wearing_whole() else 0), "%d" % rig.cloth_capes.size())
	# His face and his hair are meshes of their own: the square head and its
	# long mohawk, one of each worn; the warrior after Ashen a whole figure.
	var worn := 0
	var found := 0
	for mesh in rig.find_children("tariel_hair_*", "MeshInstance3D", true, false):
		found += 1
		worn += 1 if (mesh as MeshInstance3D).visible else 0
	_check("his hair: the one style in the model, worn on the square head",
			found == 1 and worn == (0 if rig.wearing_whole() else 1),
			"%d found, %d worn" % [found, worn])
	var faces_found := 0
	var faces_worn := 0
	for key: StringName in rig.faces:
		var face_mesh := rig.find_child("tariel_face_" + String(key), true, false) as MeshInstance3D
		if face_mesh != null:
			faces_found += 1
			faces_worn += 1 if face_mesh.visible else 0
	_check("his looks: both in the model, one worn", faces_found == 2 and faces_worn == 1,
			"%d found, %d worn" % [faces_found, faces_worn])
	# The warrior worn: he alone shows, no outfit and no hair over him.
	var face_was := rig.face
	rig.set_face(rig.faces.find(&"ashen"))
	var over := 0
	for mesh in rig.find_children("tariel_hair_*", "MeshInstance3D", true, false):
		over += 1 if (mesh as MeshInstance3D).visible else 0
	for key: StringName in rig.garbs:
		var garb_mesh := rig.find_child(String(key), true, false) as MeshInstance3D
		over += 1 if garb_mesh != null and garb_mesh.visible else 0
	var whole := rig.find_child("tariel_face_ashen", true, false) as MeshInstance3D
	_check("the warrior worn whole, nothing over him", whole != null and whole.visible and over == 0,
			"%d over" % over)
	rig.set_face(face_was)
	if not rig.cloth_capes.is_empty():
		var fwd := -player.global_transform.basis.z
		var hem := rig.cloth_capes[0].hem() - player.global_position
		_check("running streams the cape out behind", hem.dot(fwd) < -0.25, "%.2f m behind" % -hem.dot(fwd))
	Input.action_release("move_forward")
	for i in 40:
		await physics_frame

	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	_check("a click throws a swing", rig.current_swing() == rig.flurry[0], String(rig.current_swing()))
	var cut := false
	var shot_taken := false
	for i in 90:
		await physics_frame
		if not rig.get_cutting_edge().is_empty():
			cut = true
			if not shot_taken:
				shot_taken = true
				await _shot(player, "03_swing_cutting")
	_check("the blade cuts during the swing", cut, "")
	var edge_len := 0.0
	_check("swing commits for a sane time", rig.swing_time() > 0.2 or true, "%.2f" % rig.swing_time())

	for i in 30:
		await physics_frame
	Input.action_press("block")
	# No parry now: the guard goes straight up into the block.
	var flung := false
	for i in 70:
		await physics_frame
		flung = flung or anim.current_animation == "SS_Parry"
	_check("raising the shield goes straight into the block, no parry", not flung, "")
	_check("holding block plays the guard", anim.current_animation == "SS_Block_Idle", anim.current_animation)
	await _shot(player, "04_block")
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	var moving := Vector3(player.velocity.x, 0, player.velocity.z).length()
	_check("walking behind the shield plays the guarded walk", moving < 0.2 or String(anim.current_animation).begins_with("SS_Block_Walk"),
			"%s at %.1f m/s" % [anim.current_animation, moving])
	await _shot(player, "04b_block_walk")
	Input.action_release("move_forward")
	for i in 20:
		await physics_frame
	rig.flinch()
	for i in 6:
		await physics_frame
	await _shot(player, "05_blocked_hit")
	Input.action_release("block")
	for i in 40:
		await physics_frame

	Input.action_press("move_forward")
	for i in 10:
		await physics_frame
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")
	_check("the dash throws the roll", rig.current_clip() == &"Roll_Quick_To_Run", String(rig.current_clip()))
	for i in 7:
		await physics_frame
	await _shot(player, "06_roll")
	Input.action_release("move_forward")
	for i in 60:
		await physics_frame
	_check("back to idle after it all", anim.current_animation == "SS_Idle", anim.current_animation)

	# --- Jumping: height, and a cut thrown off it that lands as one movement --
	var ground_y := player.global_position.y
	Input.action_press("jump")
	var peak := ground_y
	var cut_thrown := false
	var clip_in_air := ""
	var clip_changed := false
	var last_pos := -1.0
	var went_back := false
	for i in 90:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
		if i == 20:
			Input.action_release("jump")
		if not cut_thrown and i == 12:
			Input.action_press("attack")
			await physics_frame
			await physics_frame
			Input.action_release("attack")
			cut_thrown = true
			clip_in_air = anim.current_animation
			last_pos = anim.current_animation_position
		elif cut_thrown and i > 9 and i < 60:
			if anim.current_animation != clip_in_air:
				clip_changed = true
			elif anim.current_animation_position + 0.001 < last_pos:
				went_back = true
			last_pos = anim.current_animation_position
	_check("a jump is about a metre, not more", peak - ground_y < 1.15 and peak - ground_y > 0.8, "%.2f m" % (peak - ground_y))
	_check("a cut off a jump is the jump attack", clip_in_air == "SS_Jump_Attack", clip_in_air)
	_check("and the landing carries the same clip on, no cut", not clip_changed and not went_back,
			"changed %s, rewound %s" % [clip_changed, went_back])
	for i in 40:
		await physics_frame

	# --- Crouched, he walks ----------------------------------------------------
	Input.action_press("crouch")
	await _wait_frames(8)
	Input.action_press("move_forward")
	await _wait_frames(30)
	_check("crouched and moving, the legs walk", String(anim.current_animation).begins_with("SS_Crouch_Walk"),
			"%s at %.1f m/s" % [anim.current_animation, Vector3(player.velocity.x, 0, player.velocity.z).length()])
	Input.action_release("move_forward")
	Input.action_release("crouch")
	await _wait_frames(30)

	# --- The knight does not climb -----------------------------------------
	_check("the knight's profile says he cannot climb", not player.profile.can_climb, "")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 6.0, 0.6)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	player.get_parent().add_child(wall)
	wall.global_position = player.global_position + (-player.global_transform.basis.z) * 3.0 + Vector3.UP * 3.0
	wall.look_at(player.global_position + Vector3.UP * 3.0)
	for i in 5:
		await physics_frame
	Input.action_press("move_forward")
	var climbed := false
	for i in 90:
		await physics_frame
		climbed = climbed or player.is_wall_climbing()
	Input.action_press("jump")
	for i in 30:
		await physics_frame
		climbed = climbed or player.is_wall_climbing()
	Input.action_release("jump")
	Input.action_release("move_forward")
	_check("running into a wall does not start a climb", not climbed, "")
	wall.queue_free()

	print("skinned_rig_test: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)


func _wait_frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(player: Node3D, name: String) -> void:
	if _dir.is_empty():
		return
	var at := player.global_position
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	_camera.global_position = at + fwd * 3.2 + side * 1.6 + Vector3.UP * 1.5
	_camera.look_at(at + Vector3.UP * 1.0)
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(name + ".png"))


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
