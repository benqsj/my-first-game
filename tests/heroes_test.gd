extends SceneTree

## The mage and the rogue: each spawns on his own rig and clips, the mage's
## charged cast throws a bolt and his held jump floats, the rogue's stabs cut
## with a blade in each hand.
##
##     godot --path . --headless --script res://tests/heroes_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	for path in ["res://sounds/tariel/swing_1.wav", "res://sounds/bow/draw.wav", "res://sounds/bow/release.wav",
			"res://sounds/tower-music/kind-of-year.mp3",
			"res://sounds/tariel/air_1.wav", "res://sounds/tariel/air_6.wav", "res://sounds/tariel/hit_1.wav",
			"res://sounds/assassin/swing_1.wav", "res://sounds/assassin/swing_4.wav",
			"res://sounds/assassin/hit_3.wav", "res://sounds/assassin/hurt_1.wav",
			"res://sounds/all/hurt_1.wav", "res://sounds/all/fall_1.wav", "res://sounds/all/block_1.wav",
			"res://sounds/all/loot_1.wav", "res://sounds/orc/roar_1.wav"]:
		_check("%s is there to play" % path.get_file(), load(path) is AudioStream)
	await _spawn(&"mage")
	await _check_mage()
	await _spawn(&"mage")
	await _check_steps("the mage")
	await _spawn(&"rogue")
	await _check_rogue()
	await _spawn(&"rogue")
	await _check_steps("the rogue")
	await _spawn(&"tariel")
	await _check_steps("Tariel")
	await _check_chain("Tariel")
	var trig := _player.rig as SkinnedRig
	_check("Tariel's sword has the new air and its bite", trig != null
			and trig.swing_sounds[0] == "res://sounds/tariel/air_1.wav"
			and trig.hit_sounds[0] == "res://sounds/tariel/hit_1.wav"
			and trig.hurt_sounds[0] == "res://sounds/all/hurt_1.wav")
	await _spawn(&"mage")
	await _check_chain("the mage")
	await _spawn(&"avtandil")
	await _check_chain("Avtandil")
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _spawn(id: StringName) -> void:
	if _world != null:
		_world.queue_free()
		await _wait(2)
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


func _check_mage() -> void:
	var rig := _player.rig as SkinnedMageRig
	_check("the mage stands on his own rig", rig != null, str(_player.rig))
	if rig == null:
		return
	_check("with his clips", rig.clip_names().has("MG_Cast_1H") and rig.clip_names().has("MG_Float"),
			"%d clips" % rig.clip_names().size())
	_check("and fights from afar", _player.has_bow())
	_check("the air that carries him is under his feet", rig.get_node_or_null("Wind") is MageWind)
	_check("standing still he stands", String(rig._anim.current_animation) == "MG_Idle",
			String(rig._anim.current_animation))

	# Charge and throw.
	Input.action_press("attack")
	await _wait(50)
	_check("charging holds the gathering cast", String(rig._anim.current_animation) == SkinnedMageRig.CHARGE_CLIP,
			String(rig._anim.current_animation))
	Input.action_release("attack")
	var bolt: SpellBolt = null
	var crystal := rig.spell_origin()
	var waited := 0
	for i in 40:
		crystal = rig.spell_origin()
		await physics_frame
		waited += 1
		bolt = _find_bolt()
		if bolt != null:
			break
	_check("letting go throws a bolt, as the staff comes round", bolt != null and waited > 6,
			"after %d ticks" % waited)
	if bolt != null:
		_check("from the staff's crystal", bolt.global_position.distance_to(crystal) < 0.8,
				"%.2f m off it" % bolt.global_position.distance_to(crystal))
		var from := bolt.global_position
		var first := bolt.speed()
		var middle := 0.0
		var peak := 0.0
		var top := bolt._top_speed
		var went := Vector3.ZERO
		for i in 70:
			await physics_frame
			if not is_instance_valid(bolt) or bolt.is_fading() or bolt._spent:
				break
			if i == 20:
				middle = bolt.speed()
			peak = maxf(peak, bolt.speed())
			went = bolt.global_position - from
		if went != Vector3.ZERO:
			_check("it leaves slowly and gathers pace over the flight",
					first < top * 0.35 and middle < top * 0.7 and peak > top * 0.95,
					"%.1f, %.1f, then %.1f of %.1f m/s" % [first, middle, peak, top])
			_check("and, nothing locked, flies straight", went.length() > 8.0 and absf(went.y) < went.length() * 0.15,
					"%.1f m, %.2f m up" % [went.length(), went.y])
		else:
			_check("the bolt was still flying", false)
	await _wait(40)

	# Hunting: the bolt alone, high over everything, at a body 22 m off.
	var walked := await _hunt_case(Vector3(0.0, 0.0, 3.0), Vector3.ZERO, false, true)
	_check("a locked bolt follows a body walking across it, and hits", walked["hits"] == 1, str(walked))
	var loose := await _hunt_case(Vector3(0.0, 0.0, 3.0), Vector3.ZERO, false, false)
	_check("(an unlocked one misses it)", loose["hits"] == 0 and loose["faded"], str(loose))
	var dodged := await _hunt_case(Vector3.ZERO, Vector3(0.0, 0.0, 9.0), false, true)
	_check("one that breaks sideways at the last shakes it off", dodged["hits"] == 0 and dodged["let_go"], str(dodged))
	_check("and the bolt goes out once it is past", dodged["faded"], str(dodged))
	var rolled := await _hunt_case(Vector3.ZERO, Vector3.ZERO, true, true)
	_check("one rolling out of its way is gone through, not hit", rolled["hits"] == 0 and rolled["faded"], str(rolled))

	# And the controller: a lock is what it hunts.
	var dummy := _dummy()
	var ahead := -_player.global_transform.basis.z
	ahead.y = 0.0
	dummy.position = _player.global_position + ahead.normalized() * 12.0
	_world.add_child(dummy)
	await _wait(2)
	_player.call("_hold_target", dummy)
	Input.action_press("attack")
	await _wait(40)
	Input.action_release("attack")
	var hunting := false
	for i in 40:
		await physics_frame
		var found := _find_bolt()
		if found != null:
			hunting = hunting or found.is_hunting()
	await _wait(30)
	_check("a bolt thrown with a lock hunts what is locked", hunting)
	_check("and strikes it", int(dummy.get("hits")) >= 1, "%d hits" % int(dummy.get("hits")))
	_player.call("_drop_target")
	dummy.queue_free()
	await _wait(20)

	# A tapped jump plays his own jump clip, by how fast he is rising or falling.
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	var seen := ""
	var rising := -1.0
	var falling := -1.0
	for i in 150:
		await physics_frame
		if not _player.is_on_floor() and rig._anim.has_animation(SkinnedMageRig.JUMP_CLIP):
			seen = String(rig._anim.current_animation)
			var at := rig._anim.current_animation_position / rig._anim.get_animation(SkinnedMageRig.JUMP_CLIP).length
			if _player.velocity.y > 3.0 and rising < 0.0:
				rising = at
			if _player.velocity.y < -3.0:
				falling = at
		if _player.is_on_floor() and i > 10:
			break
	_check("in the air he plays his own jump", seen == String(SkinnedMageRig.JUMP_CLIP), seen)
	_check("its first half going up and its second coming down", rising >= 0.0 and rising < 0.45 and falling > 0.55,
			"%.2f up, %.2f down" % [rising, falling])
	await _wait(20)

	# The jump, and the float down.
	var ground := _player.global_position.y
	Input.action_press("jump")
	var peak := ground
	var slowest_fall := 0.0
	var floated := false
	for i in 200:
		await physics_frame
		peak = maxf(peak, _player.global_position.y)
		if _player.is_levitating():
			floated = true
			slowest_fall = minf(slowest_fall, _player.velocity.y)
		if _player.is_on_floor() and i > 20:
			break
	Input.action_release("jump")
	_check("he jumps high", peak - ground > 3.2, "%.2f m" % (peak - ground))
	_check("and, the jump held, floats down", floated and slowest_fall > -_player.profile.levitate_fall - 0.05,
			"falling at %.2f m/s at most while floating" % -slowest_fall)
	await _wait(30)


func _check_rogue() -> void:
	var rig := _player.rig as SkinnedRogueRig
	_check("the rogue stands on his own rig", rig != null, str(_player.rig))
	if rig == null:
		return
	_check("and swings rather than shoots", not _player.has_bow())
	_check("he runs at the hunter's pace", is_equal_approx(_player.run_speed, 5.9), "%.1f m/s" % _player.run_speed)
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	_check("a click is the first blow of the combo", String(rig.current_swing()) == "DG_Combo_1",
			String(rig.current_swing()))
	_check("and it whooshes", rig.find_children("*", "AudioStreamPlayer3D", true, false).size() > 0)
	var cut := false
	for i in 60:
		await physics_frame
		if not rig.get_cutting_edge().is_empty():
			cut = true
	_check("the knife cuts", cut)
	_check("one knife, in one hand", not rig.off_hand_blade and rig._arc_l == null)
	_check("the combo is eight blows, each one there", rig.flurry.size() == 8
			and rig.flurry.all(func(c: StringName) -> bool: return rig._anim.has_animation(c)))
	_check("his roll is a flip and his dodge a twisting one", rig.clips[&"roll"] == &"DG_Flip"
			and rig._anim.has_animation(&"DG_Flip") and rig._anim.has_animation(&"DG_Twist"))

	_check("his knife has its own sounds", rig.swing_sounds[0].begins_with("res://sounds/assassin/")
			and rig.hit_sounds[0].begins_with("res://sounds/assassin/")
			and rig.hurt_sounds[0] == "res://sounds/assassin/hurt_1.wav")
	var voices := rig.find_children("*", "AudioStreamPlayer3D", true, false).size()
	_player.net_blade_landed()
	_player.net_react(Player.Reaction.FLINCH, _player.global_position + Vector3.UP, Vector3.UP)
	_check("his knife is heard going in, and he is heard hurt",
			rig.find_children("*", "AudioStreamPlayer3D", true, false).size() + _player.find_children("*", "AudioStreamPlayer3D", false, false).size() >= voices + 2)
	await _wait(40)

	# The evades in a row: a step, then the flip, then a step again.
	await _wait(60)
	_player.stamina = _player.max_stamina
	_player._dash_cooldown_timer = 0.0
	await _tap_dash()
	await _wait(2)
	_check("a tap of the dash is a quick step", String(rig._act_clip).begins_with("DG_Dodge")
			and _player.state == Player.State.DASHING, String(rig._act_clip))
	await _wait(20)
	_check("holding the button no longer turns it into a flip", _player.state == Player.State.DASHING)
	await _tap_dash()
	var flip := await _until(func() -> bool: return _player.state == Player.State.DODGING, 40)
	_check("a second press follows the step with the flip", flip and String(rig._act_clip) == "DG_Twist",
			String(rig._act_clip))
	await _wait(20)
	await _tap_dash()
	var step := await _until(func() -> bool: return _player.state == Player.State.DASHING, 90)
	_check("and a third, after the flip, is a step again", step and String(rig._act_clip).begins_with("DG_Dodge"),
			String(rig._act_clip))
	await _wait(80)

	# Locked on, backing away: the same — a step back facing it, then the flip.
	var foe := _dummy()
	_world.add_child(foe)
	foe.global_position = _player.global_position - _player.global_transform.basis.z * 5.0
	_player.target = foe
	await _wait(30)
	_player.stamina = _player.max_stamina
	_player._dash_cooldown_timer = 0.0
	var facing := _player.rotation.y
	Input.action_press("move_back")
	await _wait(2)
	await _tap_dash()
	await _wait(2)
	_check("locked, backing off is a step first", _player.state == Player.State.DASHING
			and String(rig._act_clip).begins_with("DG_Dodge"), String(rig._act_clip))
	_check("still facing what he has locked", absf(angle_difference(_player.rotation.y, facing)) < 0.35,
			"turned %.2f rad" % angle_difference(_player.rotation.y, facing))
	await _wait(15)
	await _tap_dash()
	flip = await _until(func() -> bool: return _player.state == Player.State.DODGING, 40)
	Input.action_release("move_back")
	_check("and the flip after it", flip and String(rig._act_clip) == "DG_Twist", String(rig._act_clip))
	_player.target = null
	foe.queue_free()
	await _wait(90)
	_check("and he climbs", _player.profile.can_climb and rig._anim.has_animation(&"DG_Climb_Up"))


## Running a couple of seconds puts a footfall under each foot as it lands:
## a steady beat, two or three a second, and none standing still.
func _check_steps(who: String) -> void:
	var steps := _player.footsteps
	_check("%s has feet to hear" % who, steps != null)
	if steps == null:
		return
	var before := steps.steps_played
	await _wait(60)
	_check("%s standing makes no sound" % who, steps.steps_played == before)
	Input.action_press("move_forward")
	await _wait(40)
	before = steps.steps_played
	var start := Time.get_ticks_msec()
	await _wait(120)
	var heard := steps.steps_played - before
	Input.action_release("move_forward")
	var game_seconds := 120.0 / Engine.physics_ticks_per_second
	_check("%s running steps on each foot" % who, heard >= 3 and heard <= 12,
			"%d steps in %.1f s (%d ms real)" % [heard, game_seconds, Time.get_ticks_msec() - start])
	await _wait(30)


## Evades one after another: a press during a roll is the next roll, straight
## on, and a press just after one ends follows on without the cooldown.
func _check_chain(who: String) -> void:
	await _wait(30)
	_player.stamina = _player.max_stamina
	_player._dash_cooldown_timer = 0.0
	var starts: Array[int] = []
	var ends: Array[int] = []
	var frame := [0]
	var on_start := func(_d: Vector3) -> void: starts.append(frame[0])
	var on_end := func() -> void: ends.append(frame[0])
	_player.dash_started.connect(on_start)
	_player.dash_ended.connect(on_end)
	await _tap_dash()
	var first_clip := String(_player.rig._act_clip)
	await _wait(22)  # past the double tap, well inside the roll
	await _tap_dash()
	for i in 90:
		frame[0] += 1
		await physics_frame
		if starts.size() >= 2 and ends.size() >= 2:
			break
	_check("%s: a press during a roll is the next one" % who, starts.size() >= 2,
			"%d rolls" % starts.size())
	if starts.size() >= 2 and ends.size() >= 1:
		_check("%s: straight on from the first" % who, starts[1] - ends[0] <= 1,
				"ended %d, next %d" % [ends[0], starts[1]])
	_check("%s: each one his own" % who, first_clip != "" , first_clip)
	# Just after it ends, inside the grace: no cooldown to wait out.
	await _until(func() -> bool: return _player.state != Player.State.DASHING and _player.state != Player.State.DODGING, 60)
	await _wait(4)
	_player.stamina = _player.max_stamina
	var before := starts.size()
	await _tap_dash()
	_check("%s: pressed just after, it follows on at once" % who, starts.size() == before + 1,
			"cooldown %.2f" % _player._dash_cooldown_timer)
	_player.dash_started.disconnect(on_start)
	_player.dash_ended.disconnect(on_end)
	await _wait(60)


func _tap_dash() -> void:
	Input.action_press("dash")
	await physics_frame
	await physics_frame
	Input.action_release("dash")


func _until(done: Callable, frames: int) -> bool:
	for i in frames:
		if done.call():
			return true
		await physics_frame
	return done.call()


func _find_bolt() -> SpellBolt:
	for node in _world.find_children("*", "Node3D", true, false):
		if node is SpellBolt and not (node as SpellBolt).is_fading():
			return node
	return null


var _dummy_script: GDScript


## A body to throw at: a capsule on the enemies' layer that counts its hits and
## says, when told to, that it is rolling out of the way.
func _dummy() -> CharacterBody3D:
	if _dummy_script == null:
		_dummy_script = GDScript.new()
		_dummy_script.source_code = "extends CharacterBody3D\nvar hits := 0\nvar evading := false\n" \
				+ "func take_hit(_d: float, _at: Vector3, _b: Vector3, _c: bool = false, _h: bool = false, _f: Node3D = null) -> void:\n\thits += 1\n" \
				+ "func is_evading() -> bool:\n\treturn evading\n"
		_dummy_script.reload()
	var body := CharacterBody3D.new()
	body.set_script(_dummy_script)
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	body.add_child(shape)
	return body


## A bolt thrown at a body 22 m off, high in the air: the body walks at `walk`
## from the start, and at 8 m breaks at `dodge` or says it is `rolling`.
func _hunt_case(walk: Vector3, dodge: Vector3, rolling: bool, hunt: bool) -> Dictionary:
	var start := _player.global_position + Vector3.UP * 30.0
	var dummy := _dummy()
	# Placed before it is in the world: a body that appears at the origin for a
	# tick carries whoever is standing there along with it when it moves.
	dummy.position = start + Vector3(22.0, -0.8, 0.0)
	_world.add_child(dummy)
	dummy.velocity = walk
	await _wait(2)
	var bolt: SpellBolt = (load("res://scenes/fx/spell_bolt.tscn") as PackedScene).instantiate()
	_world.add_child(bolt)
	bolt.global_position = start
	bolt.launch(Vector3(42.0, 0.0, 0.0), 10.0, false, 0.0, _player)
	if hunt:
		bolt.hunt(dummy)
	var out := {"hits": 0, "faded": false, "let_go": false}
	for i in 150:
		await physics_frame
		dummy.global_position += dummy.velocity * (1.0 / 60.0)
		if not is_instance_valid(bolt):
			break
		out["faded"] = out["faded"] or bolt.is_fading()
		out["let_go"] = out["let_go"] or (hunt and not bolt.is_hunting())
		var gap := (dummy.global_position - bolt.global_position).length()
		if gap < 8.0:
			if dodge != Vector3.ZERO:
				dummy.velocity = dodge
			if rolling:
				dummy.set("evading", true)
	out["hits"] = int(dummy.get("hits"))
	dummy.queue_free()
	await _wait(2)
	return out


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
