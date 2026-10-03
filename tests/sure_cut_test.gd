extends SceneTree
## TARIEL_POLISH.md 11-13, driven by the game's inputs:
## - the running cut, locked on, lands on what it is thrown at — a tall orc,
##   a wolf, a puglin at his knee — straight ahead or a little to the side;
## - what may and may not be missed (`Player.sure_holds`): above, below and a
##   little aside is cut; well off to the side, out of reach or in its dodge
##   is not;
## - the Shadow Slide (skill 2): the running cut out of a slide, gone at
##   once (no standing, the sword never frozen), in to the orc 7 m off,
##   shadows shed behind him, the cut landing; at nothing, a longer slide;
## - the shadow a perfect dodge (and the slide) sheds has the figure in it
##   (it was copied off the hero's own hidden model: nothing to see);
## - Tariel's profile has the shadow.
##   Godot --headless --path . --script res://tests/sure_cut_test.gd
const WORLD := "res://scenes/world/greybox_world.tscn"
const ORC := "res://scenes/enemies/orc.tscn"
const WOLF := "res://scenes/enemies/wolf.tscn"
const PUGLIN := "res://scenes/enemies/puglin.tscn"

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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _home()
	await _frames(40)
	_check("on the mannequin", rig.on_mannequin())
	rig._wear_string(0)
	player.call(&"_set_weapons_stowed", false)
	await _frames(60)

	await _check_shadow()
	await _check_rules()
	await _check_run_cuts()
	await _check_thrust()

	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _home() -> void:
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 0.5, 26.0)
	player.rotation.y = 0.0
	player.camera_rig.rotation.y = 0.0
	await _frames(30)


func _fresh() -> void:
	player.stamina = player.max_stamina
	player.set("_dash_cooldown_timer", 0.0)
	player.set("_skill_ready_at", {})


func _fwd() -> Vector3:
	var f := -player.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func _put(scene: String, at: Vector3) -> Node3D:
	var ground := at
	var hit := player.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 20.0, at + Vector3.DOWN * 40.0, 1))
	if not hit.is_empty():
		ground = hit["position"]
	var c: Node3D = (load(scene) as PackedScene).instantiate()
	c.position = _world.to_local(ground + Vector3.UP * 0.05)
	_world.add_child(c)
	# kept where it is put: the checks are of what he does to it
	for key in ["sight_range", "speed", "roam_radius", "run_speed", "walk_speed"]:
		if c.get(key) != null:
			c.set(key, 0.0)
	c.look_at(Vector3(player.global_position.x, ground.y, player.global_position.z), Vector3.UP)
	return c


func _lock(c: Node3D) -> void:
	player.target = c


func _settle() -> void:
	for i in 240:
		if player.state == Player.State.GROUNDED and not player.is_committed():
			break
		await physics_frame
	await _frames(30)


func _health(c: Node3D) -> float:
	return float(c.get("health")) if is_instance_valid(c) else -1.0


## A trail started on him has his figure in it.
func _check_shadow() -> void:
	_check("Tariel's profile sheds the shadow", player.profile.shadow_dodge)
	var trail := ShadowTrail.start(player)
	await _frames(10)
	var seen := 0
	for copy: Dictionary in trail._copies:
		for m in (copy.node as Node).get_children():
			if m is MeshInstance3D and (m as MeshInstance3D).visible:
				seen += 1
	_check("the shadow is copied off the figure shown", trail._skeleton.is_visible_in_tree(),
			"(%s)" % player.get_path_to(trail._skeleton))
	_check("and has the figure in it", trail._copies.size() >= 1 and seen >= 3,
			"(%d copies, %d meshes shown)" % [trail._copies.size(), seen])
	await _frames(120)
	_check("and is gone after", player.get_node_or_null("ShadowTrail") == null)


## What a cut that does not miss misses, asked straight.
func _check_rules() -> void:
	var orc := _put(ORC, player.global_position + _fwd() * 2.0)
	var wolf := _put(WOLF, player.global_position + _fwd() * 2.0 + Vector3.RIGHT * 6.0)
	await _frames(20)
	var p := player.global_position
	var fwd := _fwd()
	var edge := PackedVector3Array([p + Vector3.UP * 1.2 + fwd * 0.4, p + Vector3.UP * 1.2 + fwd * 1.5])
	player.set("_sure_foe", orc)
	player.set("_sure_serial", rig.attack_serial)
	var ground_y := orc.global_position.y
	var r := Player._blade_radius(orc)
	var at := func(ahead: float, aside: float, up: float) -> void:
		orc.global_position = Vector3(p.x, ground_y + up, p.z) + fwd * ahead + player.global_basis.x * aside
	at.call(2.0, 0.0, 0.0)
	_check("straight ahead: cut", player.sure_holds(orc, edge))
	at.call(2.0, r * 0.4, 0.0)
	_check("a little aside (0.4 of its width): cut", player.sure_holds(orc, edge))
	at.call(2.0, r * 0.4, -1.5)
	_check("below him: cut", player.sure_holds(orc, edge))
	at.call(2.0, 0.0, 1.0)
	_check("above him: cut", player.sure_holds(orc, edge))
	at.call(2.0, r * 1.4, 0.0)
	_check("well aside (%.0f deg, its middle %.2f m off the line): missed" % [rad_to_deg(atan2(r * 1.4, 2.0)), r * 1.4],
			not player.sure_holds(orc, edge))
	at.call(5.5, 0.0, 0.0)
	_check("out of reach: missed", not player.sure_holds(orc, edge))
	at.call(-2.0, 0.0, 0.0)
	_check("behind him: missed", not player.sure_holds(orc, edge))
	player.set("_sure_serial", rig.attack_serial - 1)
	at.call(2.0, 0.0, 0.0)
	_check("a swing that is not the sure one: missed", not player.sure_holds(orc, edge))
	# a wolf, ahead, in its dodge
	player.set("_sure_foe", wolf)
	player.set("_sure_serial", rig.attack_serial)
	wolf.global_position = Vector3(p.x, wolf.global_position.y, p.z) + fwd * 1.8
	_check("a wolf ahead: cut", player.sure_holds(wolf, edge))
	wolf.set("_evading", 1.0)
	_check("a wolf ahead in its dodge: missed", not player.sure_holds(wolf, edge))
	player.set("_sure_foe", null)
	orc.queue_free()
	wolf.queue_free()
	await _frames(10)


## Locked on, at a run, the running cut: at a tall orc, a wolf, a puglin, at
## the middle and a little aside. Then a wolf in its dodge, not touched.
func _check_run_cuts() -> void:
	var cases := [[ORC, 0.0], [ORC, 0.45], [WOLF, 0.0], [WOLF, 0.35], [PUGLIN, 0.0], [PUGLIN, 0.3]]
	for c in cases:
		await _run_cut_at(c[0], c[1], false)
	await _run_cut_at(WOLF, 0.0, true)


func _run_cut_at(scene: String, aside: float, dodging: bool) -> void:
	await _home()
	_fresh()
	var foe := _put(scene, player.global_position + _fwd() * 10.0 + player.global_basis.x * aside)
	await _frames(15)
	_lock(foe)
	var hp := _health(foe)
	Input.action_press("move_forward")
	var gap := 99.0
	var r := Player._blade_radius(foe)
	for i in 120:
		await physics_frame
		var to := foe.global_position - player.global_position
		to.y = 0.0
		gap = to.length() - r
		if gap < 2.4:
			break
	if dodging:
		foe.set("_evading", 2.0)
	await _tap("attack")
	await physics_frame
	var clip := rig.current_swing()
	var cut := false
	for i in 50:
		await physics_frame
		if dodging:
			foe.set("_evading", 2.0)
		if not rig.get_cutting_edge().is_empty():
			cut = true
	Input.action_release("move_forward")
	var name := scene.get_file().get_basename()
	if dodging:
		_check("%s in its dodge: the running cut misses" % name, is_equal_approx(_health(foe), hp),
				"(%s, %.0f -> %.0f)" % [clip, hp, _health(foe)])
	else:
		_check("%s %.2f m aside: the running cut (%s) lands" % [name, aside, clip],
				cut and _health(foe) < hp, "(from %.2f m; %.0f -> %.0f)" % [gap, hp, _health(foe)])
	player.target = null
	foe.queue_free()
	await _settle()


## Skill 2: the Shadow Slide: the running cut out of a slide, no stop in it.
func _check_thrust() -> void:
	await _home()
	_fresh()
	_check("skill 2 is the Shadow Slide", player.skill_in(1) == &"shadow_slide", "(%s)" % player.skill_in(1))
	var orc := _put(ORC, player.global_position + _fwd() * 7.0 + player.global_basis.x * 0.5)
	await _frames(20)
	var hp := _health(orc)
	var from := player.global_position
	_check("skill 2 goes", player.use_skill(1))
	await physics_frame
	_check("it is the running cut, Sword_Light_D", rig.current_swing() == &"Sword_Light_D", "(%s)" % rig.current_swing())
	var frames := 0
	var shadows := 0
	var stood := 0
	var froze := 0
	var last := player.global_position
	while int(player.get("_shade_phase")) == 1 and frames < 60:
		await physics_frame
		frames += 1
		var step := Vector2(player.global_position.x - last.x, player.global_position.z - last.z).length()
		last = player.global_position
		if step < 0.02:
			stood += 1
		if rig._anim.speed_scale <= 0.0:
			froze += 1
		var trail := player.get_node_or_null("ShadowTrail") as ShadowTrail
		if trail != null:
			shadows = maxi(shadows, trail._copies.size())
	var to := orc.global_position - player.global_position
	to.y = 0.0
	var gap := to.length() - Player._blade_radius(orc)
	_check("he goes at once and never stands in it", stood <= 1, "(%d frames standing)" % stood)
	_check("and the sword is never frozen", froze <= 2, "(%d frames frozen)" % froze)
	_check("the slide takes him in to it (0.5-1.6 m off)", gap > 0.5 and gap < 1.6 and frames < 30,
			"(%.2f m off after %d frames, went %.2f m)" % [gap, frames, (player.global_position - from).length()])
	_check("shadows shed behind him", shadows >= 3, "(%d)" % shadows)
	for i in 40:
		await physics_frame
	_check("the cut lands on the orc", _health(orc) < hp, "(%.0f -> %.0f)" % [hp, _health(orc)])
	_check("on cooldown", player.skill_cooldown_left(1) > 0.0)
	orc.queue_free()
	await _settle()
	# With nothing before him: further, about 8 m.
	await _home()
	_fresh()
	from = player.global_position
	_check("skill 2 at nothing", player.use_skill(1))
	for i in 90:
		await physics_frame
	var went := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
	_check("at nothing, a longer slide (7-10 m)", went > 7.0 and went < 10.0, "(%.2f m)" % went)
	await _settle()
