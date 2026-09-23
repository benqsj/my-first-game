extends SceneTree

## The skinned Avtandil (SkinnedArcherRig): the right clip for each thing he
## does, and a photograph of each when given a directory.
##
##     godot --path . --script res://tests/skinned_archer_test.gd -- /tmp/shots

var _failures := 0
var _camera: Camera3D
var _view: SubViewport
var _dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else ""
	# Avtandil is chosen on the command line — `-- <dir> avtandil` — which the
	# Game autoload reads before the level asks it who to spawn.
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player: Player = world.player()
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	# Off-screen, so the photographs do not depend on the window being visible:
	# macOS stops redrawing a window that is behind others.
	_view = SubViewport.new()
	_view.size = Vector2i(1280, 720)
	_view.world_3d = root.get_viewport().find_world_3d()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_view.add_child(_camera)
	_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame

	var rig := player.rig as SkinnedArcherRig
	_check("Avtandil is on the skinned archer rig", rig != null, str(player.rig))
	if rig == null:
		quit(1)
		return
	var anim: AnimationPlayer = rig._anim
	player.global_position = Vector3(0.0, 0.2, 30.0)
	await _wait(40)
	_check("standing still plays his idle", anim.current_animation == "AV_Idle_01", anim.current_animation)
	await _shot(player, "a01_idle")

	Input.action_press("move_forward")
	await _wait(50)
	_check("at full pace he runs the straightened sprint", anim.current_animation == "AV_Sprint_Upright",
			"%s at %.1f m/s" % [anim.current_animation, _pace(player)])
	await _shot(player, "a02_sprint")
	Input.action_release("move_forward")
	await _wait(40)

	Input.action_press("attack")
	await _wait(45)
	_check("holding the button brings the bow up to the aim", anim.current_animation == "AV_Aim_Idle_01", anim.current_animation)
	await _shot(player, "a03_full_draw")
	Input.action_press("move_forward")
	await _wait(25)
	_check("walking with it drawn plays the aiming walk", String(anim.current_animation).begins_with("AV_Aim_Walk"),
			"%s at %.1f m/s" % [anim.current_animation, _pace(player)])
	await _shot(player, "a04_aim_walk")
	Input.action_release("move_forward")
	Input.action_release("attack")
	await _wait(4)
	await _shot(player, "a05_loose")
	await _wait(40)

	# Backing off and drawing: no standing draw clip may play while he moves,
	# or he slides across the ground for the length of it.
	Input.action_press("move_back")
	await _wait(15)
	Input.action_press("attack")
	var standing_draw_while_moving := 0
	for i in 40:
		await physics_frame
		if anim.current_animation == "AV_Nock_Draw" and _pace(player) > 0.3:
			standing_draw_while_moving += 1
	_check("drawing while backing off never plays the standing draw", standing_draw_while_moving == 0,
			"%d frame(s)" % standing_draw_while_moving)
	_check("and he walks back with it drawn", String(anim.current_animation).begins_with("AV_Aim_Walk"), anim.current_animation)
	Input.action_release("attack")
	Input.action_release("move_back")
	await _wait(40)

	Input.action_press("crouch")
	Input.action_press("move_forward")
	await _wait(30)
	_check("crouched and moving, he creeps", String(anim.current_animation).begins_with("AV_Crouch_Walk"),
			"%s at %.1f m/s" % [anim.current_animation, _pace(player)])
	await _shot(player, "a06_crouch_walk")
	Input.action_release("move_forward")
	Input.action_release("crouch")
	await _wait(40)

	Input.action_press("move_forward")
	await _wait(8)
	Input.action_press("dash")
	await _wait(2)
	Input.action_release("dash")
	await _wait(8)
	_check("the dash throws his dive", rig.current_clip() == &"AV_Dive_Forward", String(rig.current_clip()))
	await _shot(player, "a07_roll")
	Input.action_release("move_forward")
	await _wait(60)

	# --- A wall to climb ------------------------------------------------------
	# In a fixed open spot, facing a fixed way, so every run climbs the same wall.
	player.global_position = Vector3(-30.0, 0.3, 60.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _wait(20)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 12.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	wall.add_child(mesh)
	wall.collision_layer = 1
	world.add_child(wall)
	wall.global_position = Vector3(-30.0, 6.0, 57.0)
	await _wait(5)
	Input.action_press("move_forward")
	await _wait(25)
	Input.action_press("jump")
	await _wait(3)
	Input.action_release("jump")
	await _wait(15)
	_check("he takes hold of the wall", player.is_wall_climbing(), "at %v" % player.global_position)
	await _wait(20)
	_check("pushing up climbs", anim.current_animation == "AV_Climbing_Up_Wall",
			"%s, climb speed %.2f" % [anim.current_animation, rig._climb_speed])
	await _side_shot(player, "a08_climb_up")
	Input.action_release("move_forward")
	Input.action_press("move_right")
	await _wait(25)
	_check("pushing sideways shimmies", String(anim.current_animation).begins_with("AV_Shimmy"),
			"%s, on wall %s" % [anim.current_animation, player.is_wall_climbing()])
	await _side_shot(player, "a09_shimmy")
	Input.action_release("move_right")
	await _wait(20)
	_check("holding still hangs", anim.current_animation == "AV_Hanging_Idle", anim.current_animation)
	await _side_shot(player, "a10_hang")
	Input.action_press("crouch")
	await _wait(5)
	Input.action_release("crouch")
	await _wait(60)

	print("skinned_archer_test: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(_failures)


func _pace(p: CharacterBody3D) -> float:
	return Vector3(p.velocity.x, 0, p.velocity.z).length()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(player: Node3D, name: String, from_behind: bool = false) -> void:
	if _dir.is_empty():
		return
	var at := player.global_position
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	if from_behind:
		_camera.global_position = at - fwd * 3.0 + side * 2.2 + Vector3.UP * 1.6
	else:
		_camera.global_position = at + fwd * 3.2 + side * 1.6 + Vector3.UP * 1.9
	_camera.look_at(at + Vector3.UP * 1.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_view.get_texture().get_image().save_png(_dir.path_join(name + ".png"))


func _side_shot(player: Node3D, name: String) -> void:
	if _dir.is_empty():
		return
	var at := player.global_position
	_camera.global_position = at + Vector3(3.2, 0.6, 1.6)
	_camera.look_at(at + Vector3.UP * 0.9)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_view.get_texture().get_image().save_png(_dir.path_join(name + ".png"))


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
