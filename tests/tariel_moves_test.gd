extends SceneTree
## Tariel's moves of TARIEL_POLISH.md, session 2, driven by the game's inputs:
## - the shield charge: the dash with the shield up is UAL 2's Shield_Dash,
##   it drives him in, and what it hits reels (its guard broken) and is hurt;
## - the running cut: the first cut at a run is Sword_Light_D, and the next
##   press goes on with the string's second blow (B);
## - the Rising Cut (skill 1): from standing he runs at the orc ahead with the
##   sword held back (Sword_UpperCut wound up) and cuts it near it; with
##   nothing ahead, a few strides and the cut;
## - the missed cut: a cut of the string that goes through nothing holds him
##   longer than one that lands, and the evade cannot break it off at once.
##   Godot --headless --path . --script res://tests/tariel_moves_test.gd
const WORLD := "res://scenes/world/greybox_world.tscn"
const ORC := "res://scenes/enemies/orc.tscn"

var _failures := 0
var _world: Node3D
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


func _initialize() -> void:
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
	rig._wear_string(0)
	player.call(&"_set_weapons_stowed", false)
	await _frames(60)

	await _check_bash()
	await _draw()
	await _check_run_cut()
	await _check_whiff()
	await _check_rising_cut()

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _fresh() -> void:
	player.stamina = player.max_stamina
	player.set("_dash_cooldown_timer", 0.0)


func _fwd() -> Vector3:
	var f := -player.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _creature(at: Vector3) -> Node3D:
	var ground := at
	var hit := player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1))
	if not hit.is_empty():
		ground = hit["position"]
	var c: Node3D = (load(ORC) as PackedScene).instantiate()
	c.position = _world.to_local(ground + Vector3.UP * 0.05)
	_world.add_child(c)
	c.set("sight_range", 0.0)
	# kept where it is put: the checks are of what he does to it
	c.set("speed", 0.0)
	c.set("roam_radius", 0.0)
	c.look_at(Vector3(player.global_position.x, ground.y, player.global_position.z), Vector3.UP)
	return c


func _settle() -> void:
	for i in 240:
		if player.state == Player.State.GROUNDED and not player.is_committed():
			break
		await physics_frame
	await _frames(30)


## The shield up, the dash: Shield_Dash, a drive in, the orc reeling and hurt.
func _check_bash() -> void:
	_fresh()
	var orc := _creature(player.global_position + _fwd() * 4.6)
	await _frames(20)
	var bashed: Array = []
	var from := player.global_position
	var at_bash: Array = []
	player.bashed.connect(func(who: Node3D) -> void:
		bashed.append(who)
		at_bash.append((player.global_position - from).dot(_fwd()))
		at_bash.append(who.global_position.distance_to(player.global_position)))
	var health := float(orc.get("health"))
	print("  orc at %.2f m, radius %.2f" % [orc.global_position.distance_to(from), Player._body_radius(orc)])
	Input.action_press("block")
	await _frames(6)
	_check("the shield is up", player.is_blocking)
	var off := orc.global_position - player.global_position
	print("  orc at the press: %.2f ahead, %.2f aside; facing %s" % [off.dot(_fwd()), off.dot(player.global_basis.x), str(_fwd())])
	await _tap("dash")
	await physics_frame
	var clip := rig._anim.current_animation
	_check("the dash behind the shield is Shield_Dash", clip == "Shield_Dash", "(%s)" % clip)
	_check("not an evade", player.state != Player.State.DASHING and player.state != Player.State.DODGING)
	var reeled := false
	for i in 50:
		if i == 30:
			Input.action_release("block")
		await physics_frame
		if orc.has_method(&"is_reeling") and bool(orc.call(&"is_reeling")):
			reeled = true
	var went := (player.global_position - from).dot(_fwd())
	_check("it drives him in and takes the orc on the way", at_bash.size() >= 2 and float(at_bash[0]) > 0.5,
			"(went %s, then %.2f m)" % [str(at_bash), went])
	_check("it takes the orc", bashed.has(orc), str(bashed))
	_check("the orc reels, its guard broken", reeled)
	_check("and is hurt", float(orc.get("health")) < health, "(%.0f -> %.0f)" % [health, float(orc.get("health"))])
	await _settle()
	# At nothing, it drives him on 2-3.5 m.
	_fresh()
	player.rotation.y = PI * 0.5
	await _frames(5)
	from = player.global_position
	Input.action_press("block")
	await _frames(6)
	await _tap("dash")
	await _frames(50)
	Input.action_release("block")
	went = (player.global_position - from).length()
	_check("at nothing it drives him on 2-3.5 m", went > 2.0 and went < 3.5, "(%.2f m)" % went)
	await _settle()
	player.rotation.y = 0.0
	# Without the shield up the dash is the evade, as ever.
	_fresh()
	await _tap("dash")
	await physics_frame
	_check("without the shield the dash is the evade", rig._anim.current_animation == "Sword_Dash",
			"(%s)" % rig._anim.current_animation)
	orc.queue_free()
	await _settle()


## At a run, the first cut is Sword_Light_D, the next press the string's B.
func _check_run_cut() -> void:
	_fresh()
	# Standing: the first cut is the string's A.
	await _tap("attack")
	await physics_frame
	_check("standing, the first cut is A", rig.current_swing() == Swordsman.STRING[0], "(%s)" % rig.current_swing())
	await _settle()
	await _frames(40)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(70)
	var pace := Vector2(player.velocity.x, player.velocity.z).length()
	_check("running", pace > player.run_speed * 0.75, "(%.1f m/s)" % pace)
	await _tap("attack")
	await physics_frame
	var first := rig.current_swing()
	_check("at a run the cut is Sword_Light_D", first == &"Sword_Light_D", "(%s)" % first)
	var cut := false
	var seen: Array[StringName] = [first]
	for i in 70:
		if i % 8 == 4 and seen.size() < 2:
			await _tap("attack")
		else:
			await physics_frame
		if not rig.get_cutting_edge().is_empty():
			cut = true
		var s := rig.current_swing()
		if s != &"" and s != seen[seen.size() - 1]:
			seen.append(s)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("it cuts", cut)
	_check("the next press is the string's B", seen.size() > 1 and seen[1] == Swordsman.STRING[1], str(seen))
	await _settle()


## The sword in the hand (put away of itself after a while at peace).
func _draw() -> void:
	if player.weapons_stowed():
		player.call(&"_set_weapons_stowed", false)
		await _frames(60)


## Frames from the press until he may move again, for a cut of A.
func _held_for() -> int:
	await _draw()
	await _tap("attack")
	for i in 60:
		if player.is_committed():
			break
		await physics_frame
	var n := 1
	while player.is_committed() and n < 300:
		await physics_frame
		n += 1
	return n


## A cut that misses holds him longer, and the evade waits for it.
func _check_whiff() -> void:
	await _frames(80)
	_fresh()
	var whiffs: Array = []
	player.whiffed.connect(func() -> void: whiffs.append(1))
	var alone := await _held_for()
	_check("with nothing about, a cut at the air is no miss", whiffs.is_empty(), "(%d)" % whiffs.size())
	await _settle()
	await _frames(80)
	_fresh()
	# Something behind him, out of reach of the cut.
	var behind := _creature(player.global_position - _fwd() * 4.8)
	await _frames(20)
	var missed := await _held_for()
	_check("with an orc about, a cut at the air is a miss", whiffs.size() == 1, "(%d)" % whiffs.size())
	_check("and holds him longer than one with nothing about", missed > alone + 6, "(%d vs %d frames)" % [missed, alone])
	await _settle()
	await _frames(80)
	_fresh()
	var orc := _creature(player.global_position + _fwd() * 1.4)
	await _frames(20)
	whiffs.clear()
	var landed := await _held_for()
	_check("a cut that lands is no miss", whiffs.is_empty(), "(%d)" % whiffs.size())
	_check("the miss holds him longer", missed > landed + 6, "(%d vs %d frames)" % [missed, landed])
	orc.queue_free()
	behind.queue_free()
	await _settle()
	await _frames(80)
	# Missed: the evade in its follow-through is refused till the drag is over.
	_fresh()
	behind = _creature(player.global_position - _fwd() * 4.8)
	await _frames(20)
	await _draw()
	await _tap("attack")
	var refused := false
	for i in 80:
		await physics_frame
		if player.call(&"_now") < float(player.get("_whiff_until")):
			await _tap("dash")
			refused = player.state != Player.State.DASHING and player.is_committed()
			break
	_check("while a miss drags, the evade waits", refused)
	behind.queue_free()
	await _settle()


## Skill 1: the Rising Cut, at an orc 8 m ahead, then at nothing.
func _check_rising_cut() -> void:
	await _frames(60)
	_fresh()
	_check("skill 1 is the Rising Cut", player.skill_in(0) == &"rising_cut", "(%s)" % player.skill_in(0))
	var orc := _creature(player.global_position + _fwd() * 8.0)
	orc.set("speed", 0.0)
	orc.set("roam_radius", 0.0)
	await _frames(20)
	var health := float(orc.get("health"))
	var from := player.global_position
	var off := orc.global_position - from
	off.y = 0.0
	await _tap("skill_1")
	await physics_frame
	_check("it is Sword_UpperCut", rig.current_swing() == &"Sword_UpperCut", "(%s)" % rig.current_swing())
	_check("wound up and held", bool(rig.call(&"holding_cut")))
	var held_for := 0
	while bool(rig.call(&"holding_cut")) and held_for < 200:
		await physics_frame
		held_for += 1
	var at := orc.global_position - player.global_position
	at.y = 0.0
	_check("he ran in at it (let go 1.5-3 m from it)", at.length() > 1.4 and at.length() < 3.0,
			"(%.2f m, after %d frames; went %.2f m)" % [at.length(), held_for, (player.global_position - from).length()])
	var cut := false
	for i in 40:
		await physics_frame
		if not rig.get_cutting_edge().is_empty():
			cut = true
	_check("the blade comes up", cut)
	_check("and the orc is hurt", float(orc.get("health")) < health, "(%.0f -> %.0f)" % [health, float(orc.get("health"))])
	_check("on cooldown", player.skill_cooldown_left(0) > 0.0)
	orc.queue_free()
	await _settle()
	# At nothing: a few strides, and the cut.
	player.set("_skill_ready_at", {})
	_fresh()
	from = player.global_position
	# (straight from the bar: a second tap of the key in the same run of
	# frames was not always seen by the input)
	_check("skill 1 again", player.use_skill(0))
	var n := 0
	while bool(rig.call(&"holding_cut")) and n < 200:
		await physics_frame
		n += 1
	var went := (player.global_position - from).length()
	_check("at nothing, a few strides (1-4 m) and the cut", went > 1.0 and went < 4.0 and n < 60,
			"(%.2f m, %d frames)" % [went, n])
	await _settle()
