extends SceneTree

## Headless smoke test for the placeholder controller.
## Run with:
##   godot --headless --script res://tests/smoke_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0


func _initialize() -> void:
	var world: Node3D = load(WORLD).instantiate()
	root.add_child(world)
	var player: Player = world.get_node("Player")

	await _wait(30)
	_check("lands on the ground", player.is_on_floor())
	_check("rests at the correct height", absf(player.global_position.y) < 0.05,
			"y = %.3f" % player.global_position.y)

	# --- Camera-relative movement -------------------------------------------
	var start := player.global_position
	Input.action_press("move_forward")
	await _wait(40)
	Input.action_release("move_forward")
	var moved := player.global_position - start
	_check("W moves along the camera's forward axis", moved.z < -1.0 and absf(moved.x) < 0.2,
			"delta = %v" % moved)

	# Yaw the camera 90 degrees; W must now push the player along -X.
	await _settle(player)
	player.camera_rig.rotation.y = PI * 0.5
	start = player.global_position
	Input.action_press("move_forward")
	await _wait(40)
	Input.action_release("move_forward")
	moved = player.global_position - start
	_check("movement follows camera yaw", moved.x < -1.0 and absf(moved.z) < 0.2,
			"delta = %v" % moved)
	player.camera_rig.rotation.y = 0.0
	await _settle(player)

	# --- Jump ---------------------------------------------------------------
	var ground_y := player.global_position.y
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	await _wait(12)
	_check("jump leaves the ground", player.global_position.y > ground_y + 0.4,
			"y = %.3f" % player.global_position.y)
	await _wait(60)
	_check("jump returns to the ground", player.is_on_floor())

	# --- Dash ---------------------------------------------------------------
	# Stand in one of the cleared path corridors: the scattered rocks are solid
	# now, and a dash into scenery reads as a dash that never started.
	player.global_position = Vector3(6.0, 0.2, 12.0)
	player.velocity = Vector3.ZERO
	await _wait(30)
	Input.action_press("dash")
	await _wait(1)
	Input.action_release("dash")
	await _wait(2)
	var speed := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	_check("dash reaches dash speed", speed > player.walk_speed, "speed = %.2f" % speed)
	_check("dash grants i-frames", player.is_invulnerable)
	await _wait(40)
	_check("dash ends", player.state != Player.State.DASHING)
	_check("i-frames expire", not player.is_invulnerable)

	# --- Slope / stair traversal --------------------------------------------
	player.global_position = Vector3(-10.0, 0.2, 1.5)
	player.velocity = Vector3.ZERO
	await _wait(10)
	Input.action_press("walk")
	Input.action_press("move_forward")
	await _wait(120)
	Input.action_release("move_forward")
	Input.action_release("walk")
	_check("climbs the greybox stairs", player.global_position.y > 1.2,
			"stopped at %v" % player.global_position)

	# --- Ramp ---------------------------------------------------------------
	player.global_position = Vector3(10.0, 0.2, 2.0)
	player.velocity = Vector3.ZERO
	await _wait(10)
	Input.action_press("walk")
	Input.action_press("move_forward")
	await _wait(90)
	Input.action_release("move_forward")
	Input.action_release("walk")
	_check("walks up the ramp", player.global_position.y > 0.6,
			"stopped at %v" % player.global_position)
	await _settle(player)

	# --- Climbing costs speed -----------------------------------------------
	player.global_position = Vector3(10.0, 0.2, 2.0)
	player.velocity = Vector3.ZERO
	await _wait(10)
	Input.action_press("move_forward")
	await _wait(45)
	var uphill := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	Input.action_release("move_forward")
	_check("running uphill is slower than running on the flat", uphill < player.run_speed * 0.95,
			"%.2f of %.2f m/s" % [uphill, player.run_speed])
	await _settle(player)

	# --- A face too steep to stand on ---------------------------------------
	# Dropped onto the 55 degree slab, the player must end up at the bottom of
	# it rather than perched on the side.
	player.global_position = Vector3(16.0, 4.5, 2.0)
	player.velocity = Vector3.ZERO
	await _wait(120)
	_check("a steep face cannot be stood on", player.global_position.y < 0.6,
			"y = %.2f" % player.global_position.y)
	await _settle(player)

	# --- Falls are capped ---------------------------------------------------
	player.global_position = Vector3(0.0, 200.0, 26.0)
	player.velocity = Vector3.ZERO
	await _wait(180)
	_check("the fall reaches a terminal velocity",
			player.velocity.y > -player.max_fall_speed - 0.5 and player.velocity.y < -1.0,
			"%.1f m/s" % player.velocity.y)

	# --- A heavy landing costs momentum -------------------------------------
	# Air drag off, so what the landing takes is all that is being measured.
	var drag := player.air_drag
	player.air_drag = 0.0
	player.global_position = Vector3(0.0, 12.0, 26.0)
	player.velocity = Vector3(player.run_speed, 0.0, 0.0)
	var carried := player.velocity.x
	for i in 240:
		await physics_frame
		if player.is_on_floor():
			break
	var kept := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	_check("a heavy landing bleeds off speed", kept < carried * 0.95,
			"kept %.2f of %.2f m/s" % [kept, carried])
	player.air_drag = drag
	await _settle(player)

	# --- Walls are not climbed ----------------------------------------------
	player.global_position = Vector3(4.0, 0.2, 5.5)
	player.velocity = Vector3.ZERO
	await _wait(10)
	Input.action_press("move_forward")
	await _wait(60)
	Input.action_release("move_forward")
	_check("a tall pillar blocks the player", player.global_position.y < 0.3,
			"y = %.3f" % player.global_position.y)
	await _settle(player)

	# --- Dash cooldown ------------------------------------------------------
	Input.action_press("dash")
	await _wait(1)
	Input.action_release("dash")
	# Long enough for the roll itself to finish, still inside its cooldown.
	await _wait(int(player.dash_duration * 60.0) + 6)
	_check("the roll has finished before the retry", player.state != Player.State.DASHING)
	Input.action_press("dash")
	await _wait(1)
	Input.action_release("dash")
	await _wait(2)
	_check("dash respects its cooldown", player.state != Player.State.DASHING)

	# --- Camera rig ---------------------------------------------------------
	await _settle(player)
	var to_camera := player.camera.global_position - player.global_position
	_check("camera sits above the player", to_camera.y > 1.0, "y = %.2f" % to_camera.y)
	_check("camera sits behind the rig",
			player.camera.global_position.distance_to(player.camera_rig.global_position) > 1.0)
	_check("camera looks at the player",
			(-player.camera.global_basis.z).dot(-to_camera.normalized()) > 0.8)

	# --- Rocks are solid ----------------------------------------------------
	var rocks: Node3D = null
	var scatter := world.get_node_or_null("Level/Scatter")
	if scatter != null:
		for c in scatter.get_children():
			if (c as Node3D) != null and c.name.begins_with("Rocks"):
				rocks = c
				break
	if rocks == null:
		_check("a rock cluster exists to test", false)
	else:
		var top := rocks.global_position + Vector3.UP * 3.0
		player.global_position = top
		player.velocity = Vector3.ZERO
		await _wait(60)
		_check("the player lands on top of a rock instead of through it",
				player.is_on_floor() and player.global_position.y > 0.05,
				"y = %.3f" % player.global_position.y)

	# --- Grass reacts to the player -----------------------------------------
	var field := world.get_node_or_null("Level/Scatter") as GrassField
	var clump: Node3D = null
	if field != null:
		# The wind keeps every blade leaning a few degrees, and the creatures
		# flatten grass of their own accord — a wolf prowling past the test
		# clump is not what these checks are about. Both off, so what is
		# measured is the knight's own push and nothing else.
		field.wind_enabled = false
		field.enemy_reach_scale = 0.0
		# Long enough for anything already trampled to stand back up.
		await _wait(90)
		for c in field.get_children():
			var n := c as Node3D
			if n != null and n.name.begins_with("GrassClump"):
				clump = n
				break
	if clump == null:
		_check("a grass clump exists to test", false)
	else:
		var upright := clump.transform.basis.y.normalized()
		player.global_position = clump.global_position + Vector3(0.0, 0.2, 6.0)
		player.velocity = Vector3.ZERO
		await _wait(40)
		var at_rest := rad_to_deg(upright.angle_to(clump.transform.basis.y.normalized()))
		_check("grass stands upright when nothing is near", at_rest < 1.0, "%.1f deg" % at_rest)

		player.global_position = clump.global_position + Vector3(0.35, 0.2, 0.0)
		await _wait(30)
		var bent := rad_to_deg(upright.angle_to(clump.transform.basis.y.normalized()))
		_check("grass bends away when walked into", bent > 20.0, "%.1f deg" % bent)

		player.global_position = clump.global_position + Vector3(0.0, 0.2, 8.0)
		player.velocity = Vector3.ZERO
		await _wait(90)
		var back := rad_to_deg(upright.angle_to(clump.transform.basis.y.normalized()))
		_check("grass springs back up", back < 1.0, "%.1f deg" % back)

	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _settle(player: Player) -> void:
	for i in 120:
		await physics_frame
		if player.is_on_floor() and player.velocity.length() < 0.05:
			return


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
