extends SceneTree
## The knight's charge ([GreatSword] CHARGE, the user's word 2026-10-06):
## - at a sprint, the attack button held: the blade held back over his head
##   while he runs on; at a jog, an ordinary blow; the block button never;
## - let go of the attack button, or of the push: the blow comes down there,
##   a step at most, and the blade goes into the ground;
## - locked on to something: he runs at it and brings the blade down on it
##   by himself; the jump pressed while he charges: he leaps, the blade down
##   from the air.
##   Godot --headless --path . --script res://tests/great_sword_charge_test.gd
var _failures := 0
var player: Player
var rig: SkinnedRig
var foe: Node3D


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _release_all() -> void:
	for a in ["move_forward", "sprint", "attack", "block", "jump"]:
		Input.action_release(a)


## Runs ahead (at a sprint or not), presses `button` and holds it `hold`
## seconds, then lets go of `let_go`; what came of it.
func _charge(sprint: bool, button: String, hold: float, let_go: String, jump_at: float = -1.0,
		watch_turn: bool = false) -> Dictionary:
	player.stamina = player.max_stamina
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	await _frames(40)
	Input.action_press(button)
	await _frames(3)
	var out := {"charging": player._cut_charging, "clip": rig.current_swing(), "slam": false, "went": 0.0,
			"held_run": 0.0, "top": 0.0, "released_at": -1.0, "start_z": player.global_position.z}
	var y0 := player.global_position.y
	var was_v := Vector2.ZERO
	out["turn_rate"] = 0.0
	var t := 0.0
	var z := 0.0
	var z0 := player.global_position.z
	var let := false
	while t < hold + 2.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if jump_at > 0.0 and t >= jump_at and t < jump_at + 0.05:
			Input.action_press("jump")
		elif jump_at > 0.0 and t >= jump_at + 0.05:
			Input.action_release("jump")
		if not let and t >= hold and let_go != "":
			let = true
			Input.action_release(let_go)
			z = player.global_position.z
			out["held_run"] = absf(z - z0)
		if t > hold + 0.4:
			_release_all()
		if rig.current_swing() != &"":
			out["last"] = rig.current_swing()
		out["top"] = maxf(float(out["top"]), player.global_position.y - y0)
		if watch_turn and player._cut_charging:
			var v := Vector2(player.velocity.x, player.velocity.z)
			if v.length() > 1.0:
				if was_v != Vector2.ZERO:
					out["turn_rate"] = maxf(float(out.get("turn_rate", 0.0)),
							rad_to_deg(absf(was_v.angle_to(v))) * Engine.physics_ticks_per_second)
				was_v = v
		if float(out["released_at"]) < 0.0 and out["charging"] and not player._cut_charging:
			out["released_at"] = t
			out["run_to_release"] = absf(player.global_position.z - float(out["start_z"]))
		if rig._slam_done and not out["slam"]:
			out["slam_d"] = Vector2(player.global_position.x - foe.global_position.x,
					player.global_position.z - foe.global_position.z).length()
			_release_all()
		out["slam"] = out["slam"] or rig._slam_done
	if let:
		out["went"] = absf(player.global_position.z - z)
	_release_all()
	await _frames(60)
	return out


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"warrior")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _frames(2)
	player = world.player()
	player.immortal = true
	for e in world.get_node("Enemies").get_children():
		if foe == null and e is CharacterBody3D and String(e.name).to_lower().contains("orc"):
			foe = e
			continue
		e.queue_free()
	rig = player.rig as SkinnedRig
	player.set_look(PolysplitLook.default_look(&"warrior", "m"))
	player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	player.camera_rig.rotation.y = 0.0
	foe.global_position = Vector3(0.0, 0.5, 200.0)
	foe.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(60)
	rig._mode = 0
	rig._main_string = GreatSword.MODES[0]["strings"][0]
	rig._wear_string(rig._main_string)

	var r := await _charge(false, "attack", 0.6, "attack")
	_check("at a jog: no charge, an ordinary blow", not r["charging"] and r["clip"] != GreatSword.CHARGE["clip"],
			str(r["clip"]))
	r = await _charge(true, "block", 0.6, "block")
	_check("the block button at a sprint: no charge", not r["charging"], str(r["clip"]))
	r = await _charge(true, "attack", 1.2, "attack")
	print("    held: ran %.2f m; let go of the attack: on %.2f m" % [r["held_run"], r["went"]])
	_check("at a sprint the attack button held: the charge", r["charging"] and r["clip"] == GreatSword.CHARGE["clip"],
			str(r["clip"]))
	_check("held, he runs on (4-5 strides)", r["held_run"] > 5.0, "%.2f m" % r["held_run"])
	_check("let go of the attack: a step at most", r["went"] < 1.6, "%.2f m" % r["went"])
	_check("the blade into the ground", r["slam"])
	r = await _charge(true, "attack", 1.0, "move_forward")
	print("    let go of the push: on %.2f m" % r["went"])
	_check("let go of the push: a step at most", r["went"] < 1.6 and r["slam"], "%.2f m" % r["went"])

	r = await _charge(true, "attack", 3.0, "")
	print("    held on: let go by itself after %.2f s, %.2f m" % [float(r["released_at"]), float(r.get("run_to_release", 0.0))])
	_check("held on: 4-5 strides, then the blow by itself", float(r["released_at"]) > 0.9
			and float(r["released_at"]) < 1.6 and r["slam"], "%.2f s" % float(r["released_at"]))

	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	await _frames(30)
	foe.global_position = player.global_position + Vector3(0, 0, -11.0)
	player._hold_target(foe)
	r = await _charge(true, "attack", 3.0, "")
	_check("locked on: the blade down on it by himself", r.get("last", &"") == GreatSword.CHARGE["clip"] and r["slam"],
			str(r.get("last", &"")))
	print("    the blade into the ground %.2f m from its middle" % float(r.get("slam_d", -1.0)))
	_check("near enough to reach it", float(r.get("slam_d", 9.0)) < 3.2 and float(r.get("slam_d", 0.0)) > 1.0,
			"%.2f m" % float(r.get("slam_d", -1.0)))
	player._drop_target()

	# locked on to something off to the side: he runs on the way he is pushed
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	await _frames(30)
	foe.global_position = player.global_position + Vector3(9.0, 0, -9.0)
	player._hold_target(foe)
	r = await _charge(true, "attack", 1.0, "attack", -1.0, true)
	print("    locked on off to the side: turned %.0f degrees a second at most in the charge" % float(r["turn_rate"]))
	_check("locked on, he comes round in an arc, not drawn at it", float(r["turn_rate"]) < 75.0,
			"%.0f deg/s" % float(r["turn_rate"]))
	player._drop_target()

	# locked on to something a step aside of where he runs: drawn on to it,
	# and the blow comes down on it
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	await _frames(30)
	foe.global_position = player.global_position + Vector3(2.2, 0, -10.0)
	player._hold_target(foe)
	r = await _charge(true, "attack", 3.0, "")
	print("    locked on a step aside: %s, the blade down %.2f m from its middle" % [r.get("last", &""),
			float(r.get("slam_d", -1.0))])
	_check("locked on a step aside: the blow comes down on it", r.get("last", &"") == GreatSword.CHARGE["clip"]
			and float(r.get("slam_d", 9.0)) < 3.0, "%.2f m" % float(r.get("slam_d", -1.0)))
	player._drop_target()

	# the jump, then the attack button in the air: the leap's blow
	player.global_position = Vector3(0.0, 0.5, 26.0)
	await _frames(30)
	player.stamina = player.max_stamina
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(12)
	Input.action_press("attack")
	await _frames(2)
	Input.action_release("attack")
	var air_clip := rig.current_swing()
	rig._slam_done = false
	var slammed := false
	for i in 150:
		await physics_frame
		slammed = slammed or rig._slam_done
	_check("the jump attack is the leap's blow, into the ground", air_clip == GreatSword.JUMP_ATTACK["clip"] and slammed,
			"%s %s" % [air_clip, slammed])

	foe.global_position = Vector3(0.0, 0.5, 200.0)
	r = await _charge(true, "attack", 3.0, "", 0.7)
	print("    the jump: %s, up %.2f m" % [r.get("last", &""), float(r["top"])])
	_check("the jump pressed in the charge: he leaps", r.get("last", &"") == GreatSword.CHARGE["leap"]["clip"]
			and float(r["top"]) > 0.25 and float(r["top"]) < 0.6 and r["slam"], "%.2f m" % float(r["top"]))

	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
