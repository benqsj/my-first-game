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

	# --- Landing does not hold the legs -------------------------------------
	# The library's landing is a second-long settle. Held while the player has
	# already run out of it, the legs stop striding and the body reads as
	# skating over the ground, so movement has to cut it short.
	player.global_position = Vector3(6.0, 0.2, 12.0)
	player.velocity = Vector3.ZERO
	await _settle(player)
	Input.action_press("move_forward")
	await _wait(40)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	for i in 180:
		await physics_frame
		if player.is_on_floor() and player.velocity.y <= 0.0:
			break
	await _wait(45)
	Input.action_release("move_forward")
	_check("running out of a landing lets go of the landing clip",
			player.rig.current_clip() != &"NinjaJump_Land",
			"still on %s" % player.rig.current_clip())
	await _settle(player)

	# --- Crouch -------------------------------------------------------------
	# The body settles before the pose does: the stride keeps unwinding for a
	# fraction of a second after the feet stop, and a standing height read off a
	# leg still coming out of a run is not a standing height.
	await _wait(25)
	var standing_boot := (player.rig.find_child("boot_l", true, false) as Node3D).global_position.y
	var standing_head := (player.rig.find_child("skull", true, false) as Node3D).global_position.y
	Input.action_press("crouch")
	await _wait(10)
	_check("crouch works from a standstill", player.is_crouching())
	_check("the crouch lowers the capsule",
			is_equal_approx(_capsule(player).height, player.crouch_height),
			"%.2f m" % _capsule(player).height)
	# The hips are dropped by however much the folded legs shorten, so the
	# boots have to end up exactly where they started — floating or sunk feet
	# is what a crouch built from a guessed depth looks like.
	var boot := player.rig.find_child("boot_l", true, false) as Node3D
	var head := player.rig.find_child("skull", true, false) as Node3D
	_check("the crouch leaves the boots on the ground",
			absf(boot.global_position.y - standing_boot) < 0.05,
			"moved %.3f m" % (boot.global_position.y - standing_boot))
	_check("the crouch actually lowers the body",
			standing_head - head.global_position.y > 0.25,
			"head down %.2f m" % (standing_head - head.global_position.y))
	var crouch_start := player.global_position
	Input.action_press("move_forward")
	await _wait(40)
	var crept := crouch_start.distance_to(player.global_position) / (40.0 / 60.0)
	_check("crouching slows the player to a creep", crept < player.walk_speed * 0.8,
			"%.2f m/s" % crept)
	Input.action_release("move_forward")
	Input.action_release("crouch")
	await _wait(15)
	_check("releasing crouch stands the player back up", not player.is_crouching()
			and is_equal_approx(_capsule(player).height, player.stand_height()))
	await _settle(player)

	# --- Double-tapped dodge ------------------------------------------------
	Input.action_press("dash")
	await _wait(1)
	Input.action_release("dash")
	await _wait(2)
	_check("one tap of dash is still the roll", player.state == Player.State.DASHING,
			"state = %d" % player.state)
	Input.action_press("dash")
	# Two frames, not one: `physics_frame` fires *before* the nodes' own
	# _physics_process, so a press made on resuming is not acted on until the
	# frame after, and checking any sooner reads the state from before it.
	await _wait(2)
	Input.action_release("dash")
	_check("a second tap upgrades it to the dodge", player.state == Player.State.DODGING,
			"state = %d" % player.state)
	_check("the dodge grants i-frames", player.is_invulnerable)
	await _wait(int(player.dodge_duration * 60.0) + 20)
	_check("the dodge ends", player.state != Player.State.DODGING)
	await _settle(player)

	# --- Slide --------------------------------------------------------------
	# The cleared corridor, same as the dash: a slide into scenery would end on
	# the wall rather than on its own terms.
	player.global_position = Vector3(6.0, 0.2, 12.0)
	player.velocity = Vector3.ZERO
	await _wait(30)
	Input.action_press("move_forward")
	await _wait(45)
	Input.action_press("crouch")
	await _wait(3)
	_check("crouch off a run starts a slide", player.state == Player.State.SLIDING,
			"state = %d" % player.state)
	_check("the slide lowers the capsule", _capsule(player).height <= player.slide_height + 0.01,
			"%.2f m" % _capsule(player).height)
	await _wait(int(player.slide_duration * 60.0) + 20)
	Input.action_release("crouch")
	Input.action_release("move_forward")
	await _wait(10)
	_check("the slide ends by itself", player.state != Player.State.SLIDING,
			"state = %d" % player.state)
	_check("the player stands back up",
			is_equal_approx(_capsule(player).height, player.stand_height()),
			"%.2f m" % _capsule(player).height)

	await _settle(player)
	Input.action_press("crouch")
	await _wait(3)
	Input.action_release("crouch")
	_check("a slide cannot be started from a standstill", player.state != Player.State.SLIDING)
	await _settle(player)

	# --- Ledge climb --------------------------------------------------------
	# Built rather than borrowed from the level: the check is about the height
	# band the mantle accepts, which wants a block of a known size.
	var ledge := StaticBody3D.new()
	var block := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.1, 4.0)
	block.shape = box
	ledge.add_child(block)
	world.add_child(ledge)
	ledge.global_position = Vector3(6.0, 0.55, 16.0)

	player.global_position = Vector3(6.0, 0.2, 18.5)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _settle(player)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	_check("a ledge in reach turns the jump into a climb",
			player.state == Player.State.CLIMBING, "state = %d" % player.state)
	await _wait(int(player.climb_duration * 60.0) + 30)
	_check("the climb ends on top of the ledge",
			player.global_position.y > 1.0 and player.global_position.z < 18.0,
			"at %v" % player.global_position)

	# Running at it and jumping has to work too, without the jump being the
	# thing that starts the climb: a ledge met in mid-air is taken as it comes.
	player.global_position = Vector3(6.0, 0.2, 21.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _settle(player)
	Input.action_press("move_forward")
	await _wait(24)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	# Let go once the ledge has been taken, or the run carries straight on over
	# the top of the block and off the far side before the check.
	await _wait(6)
	Input.action_release("move_forward")
	await _wait(int(player.climb_duration * 60.0) + 20)
	_check("running at a ledge in mid-air climbs it too",
			player.global_position.y > 1.0, "at %v" % player.global_position)
	await _wait(30)

	# Nothing in front: the jump has to stay a jump.
	player.global_position = Vector3(6.0, 0.2, 24.0)
	player.velocity = Vector3.ZERO
	await _settle(player)
	var flat_y := player.global_position.y
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	_check("open ground still jumps", player.state != Player.State.CLIMBING)
	await _wait(12)
	_check("that jump left the ground", player.global_position.y > flat_y + 0.4,
			"y = %.2f" % player.global_position.y)
	await _wait(90)
	ledge.queue_free()
	await _settle(player)

	# --- Wall climbing ------------------------------------------------------
	# The creatures are sent away first. They hunt on sight, and a wolf shoving
	# the knight off the wall it is holding is a real thing that happens in the
	# game — but it is not what these checks are about, and it does not happen
	# on the same frame twice.
	for creature in world.find_children("*", "CharacterBody3D", true, false):
		if creature != player:
			creature.queue_free()
	await _wait(2)

	# Built here for the same reason the ledge was: what is being checked is the
	# band of heights a face has to fall in, which wants a wall of a known size.
	var wall := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var face := BoxShape3D.new()
	face.size = Vector3(8.0, 5.0, 1.0)
	slab.shape = face
	wall.add_child(slab)
	world.add_child(wall)
	wall.global_position = Vector3(6.0, 2.5, 16.0)

	player.global_position = Vector3(6.0, 0.2, 18.5)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _settle(player)
	Input.action_press("move_forward")
	await _wait(40)
	_check("a wall too tall to mantle is not climbed by walking into it",
			player.global_position.y < 0.3, "y = %.2f" % player.global_position.y)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	_check("jumping at a tall face takes hold of it",
			player.state == Player.State.WALLCLIMB, "state = %d" % player.state)
	_check("the body faces the face it is on",
			(-player.global_transform.basis.z).dot(Vector3.FORWARD) > 0.9)

	# The same thing again, but with the jump taken early: the wall is met in
	# mid-air, nothing else is pressed, and the arc has to end on the face
	# rather than bouncing off it.
	player.global_position = Vector3(6.0, 0.2, 21.0)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _settle(player)
	Input.action_press("move_forward")
	await _wait(14)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	for i in 60:
		await physics_frame
		if player.state == Player.State.WALLCLIMB:
			break
	_check("jumping at a tall face in mid-air catches it",
			player.state == Player.State.WALLCLIMB, "state = %d" % player.state)
	Input.action_release("move_forward")
	await _wait(10)

	# And back to the ground for the rest, from the same spot as before.
	player.global_position = Vector3(6.0, 0.2, 18.5)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _settle(player)
	Input.action_press("move_forward")
	await _wait(40)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	_check("and from the ground it still takes hold",
			player.state == Player.State.WALLCLIMB, "state = %d" % player.state)

	var grabbed_at := player.global_position.y
	Input.action_release("move_forward")
	await _wait(30)
	_check("hanging still does not fall", absf(player.global_position.y - grabbed_at) < 0.1,
			"drifted %.2f m" % (player.global_position.y - grabbed_at))

	Input.action_press("move_forward")
	await _wait(45)
	_check("forward climbs the face", player.global_position.y > grabbed_at + 0.9,
			"y = %.2f" % player.global_position.y)
	var high := player.global_position.y
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _wait(30)
	_check("back climbs down again", player.global_position.y < high - 0.5,
			"y = %.2f" % player.global_position.y)
	Input.action_release("move_back")

	# Sideways along the face, which must not let go of it.
	var across := player.global_position.x
	Input.action_press("move_right")
	await _wait(30)
	Input.action_release("move_right")
	_check("sideways shuffles along the face without letting go",
			player.state == Player.State.WALLCLIMB and player.global_position.x > across + 0.5,
			"x moved %.2f m, state = %d" % [player.global_position.x - across, player.state])

	# All the way up and over the top.
	Input.action_press("move_forward")
	for i in 480:
		await physics_frame
		if player.state == Player.State.GROUNDED:
			break
	Input.action_release("move_forward")
	await _wait(10)
	_check("climbing to the top pulls the player onto it",
			player.global_position.y > 4.5 and player.is_on_floor(),
			"at %v, state = %d" % [player.global_position, player.state])

	# Letting go drops the player, and jumping off pushes away from the face.
	player.global_position = Vector3(6.0, 0.2, 18.5)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _settle(player)
	Input.action_press("move_forward")
	await _wait(40)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	Input.action_release("move_forward")
	_check("the face can be taken hold of a second time",
			player.state == Player.State.WALLCLIMB, "state = %d" % player.state)
	# Up out of reach of the ground first, or letting go lands the same frame it
	# starts and there is no fall to see.
	Input.action_press("move_forward")
	await _wait(60)
	Input.action_release("move_forward")
	var let_go_at := player.global_position.y
	Input.action_press("crouch")
	await _wait(4)
	Input.action_release("crouch")
	_check("crouch lets go of the face",
			player.state == Player.State.AIRBORNE and player.velocity.y < -0.1,
			"state = %d, velocity = %v" % [player.state, player.velocity])
	await _wait(45)
	_check("and the body drops once it has", player.global_position.y < let_go_at - 0.5,
			"fell %.2f m" % (let_go_at - player.global_position.y))
	await _settle(player)

	Input.action_press("move_forward")
	await _wait(40)
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	Input.action_release("move_forward")
	_check("back on the face", player.state == Player.State.WALLCLIMB,
			"state = %d" % player.state)
	var hung := player.global_position
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	_check("jumping off the face pushes away from it",
			player.state == Player.State.AIRBORNE and player.velocity.z > 1.0,
			"velocity = %v" % player.velocity)
	await _wait(20)
	_check("and it does not catch the same face on the way past",
			player.state != Player.State.WALLCLIMB
					and player.global_position.z > hung.z + 0.4,
			"at %v" % player.global_position)

	await _wait(120)
	wall.queue_free()
	await _settle(player)

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


func _capsule(player: Player) -> CapsuleShape3D:
	return (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D


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
