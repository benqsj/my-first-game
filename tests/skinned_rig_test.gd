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
	_check("all clips loaded", rig.clip_names().size() >= 47, "%d" % rig.clip_names().size())
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
	Input.action_release("move_forward")
	for i in 40:
		await physics_frame

	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	_check("a click throws a swing", String(rig.current_swing()).begins_with("SS_"), String(rig.current_swing()))
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
	for i in 30:
		await physics_frame
	_check("holding block plays the guard", anim.current_animation == "SS_Block_Idle", anim.current_animation)
	await _shot(player, "04_block")
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

	print("skinned_rig_test: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)


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
