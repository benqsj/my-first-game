extends SceneTree
## Tariel's slide off a sprint (the user's word, 2026-10-07): sprinting, the
## block button throws the warrior's slide (WR_Slide, lent on the mannequin)
## in place of raising the guard; it carries him on and its blade cuts. Not
## sprinting, the button is what it always was (no slide).
##   Godot --headless --path . --script res://tests/tariel_sprint_slide_test.gd
##   (windowed, `-- <dir>`: frames of the slide written there)
const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _world: Node3D
var _shots := ""
var player: Player
var rig: SkinnedRig


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## A press as the mouse gives it: an input event, so the game reads it
## "just pressed" on the physics frame that follows (Input.action_press from
## here is a frame out for that).
func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_shots = args[0]
		DirAccess.make_dir_recursive_absolute(_shots)
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await _frames(2)
	player = (_world as World).player()
	player.immortal = true
	for body in _world.find_children("*", "CharacterBody3D", true, false):
		if body != player:
			body.queue_free()
	rig = player.rig as SkinnedRig
	player.set_look(PolysplitLook.default_look(&"tariel", "m"))
	player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	player.camera_rig.rotation.y = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(40)
	_check("on the mannequin", rig.on_mannequin())
	_check("the slide is his, last of his heavy blows", rig.run_slide_index() == rig.heavy.size() - 1 \
			and rig.run_slide_index() > 0, "(%d of %d)" % [rig.run_slide_index(), rig.heavy.size()])
	player.call(&"_set_weapons_stowed", false)
	await _frames(60)

	await _check_slide()
	await _check_jog()

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check_slide() -> void:
	player.stamina = player.max_stamina
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(70)
	_check("sprinting", player.sprinting, "(%.1f m/s)" % Vector2(player.velocity.x, player.velocity.z).length())
	var from := player.global_position
	await _tap("block")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await physics_frame
	_check("the block button at a sprint: the slide", rig.current_clip() == &"WR_Slide", "(%s)" % rig.current_clip())
	_check("no guard raised", not player.is_blocking)
	var cut := false
	# filmed at a tenth of the pace, a picture every frame drawn, from his side
	var cam: Camera3D = null
	if _shots != "":
		Engine.time_scale = 0.1
		cam = Camera3D.new()
		cam.fov = 50.0
		_world.add_child(cam)
		cam.current = true
	for i in (300 if _shots != "" else 90):
		if not rig.get_cutting_edge().is_empty():
			cut = true
		if cam != null:
			var at := player.global_position + Vector3.UP * 0.8
			cam.look_at_from_position(at + player.global_basis.x * 4.2 + Vector3.UP * 0.6, at, Vector3.UP)
		if _shots != "":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(_shots.path_join("slide_%03d.png" % i))
		await physics_frame
	Engine.time_scale = 1.0
	if cam != null:
		cam.queue_free()
	var went := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
	_check("it carries him on", went > 2.0, "(%.1f m)" % went)
	_check("its blade cuts", cut)
	await _frames(60)


func _check_jog() -> void:
	player.stamina = player.max_stamina
	Input.action_press("move_forward")
	await _frames(50)
	_check("not sprinting", not player.sprinting)
	await _tap("block")
	await physics_frame
	_check("the block button not at a sprint: no slide", rig.current_clip() != &"WR_Slide", "(%s)" % rig.current_clip())
	Input.action_release("move_forward")
	await _frames(40)
