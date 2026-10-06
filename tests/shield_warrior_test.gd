extends SceneTree

## The skeleton warrior ([ShieldFighter]) in the test arena: unprovoked it
## comes on with its shield down; a swing, an arrow or a blow raises it, and
## behind it it walks in, and it lowers it again once nothing comes; cuts at its front are caught on it and cuts from
## behind are not; the guard spent breaks; caught, it answers with the bash and
## the sword, both landing on a hero standing still; cut down, it breaks into
## its bones, which come to rest on the floor — as every skeleton does.
##
##   godot --headless --path . --script res://tests/shield_warrior_test.gd

const WARRIOR := "res://scenes/enemies/pack/skeleton_warrior.tscn"

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _arena() -> Array:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	return [world, panel, hero]


func _ahead(hero: Player, d: float) -> Vector3:
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	return hero.global_position + fwd.normalized() * d


func _done(world: Node) -> void:
	world.queue_free()
	for i in 3:
		await process_frame


func _run() -> void:
	await _raise()
	await _walk_in()
	await _shield()
	await _bash()
	for kind: String in ["skeleton_warrior", "skeleton", "skeleton_archer", "skeleton_mage"]:
		await _shatter(kind)
	print("shield_warrior_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


## Unprovoked, the shield down; an arrow loosed at it raises it before it
## lands (and is caught), a swing begun at it raises it, and with nothing
## more coming it goes down again.
func _raise() -> void:
	var a: Array = await _arena()
	var world: Node = a[0]
	var hero: Player = a[2]
	var body := (a[1] as ArenaPanel).call_up(WARRIOR, false, _ahead(hero, 9.0)) as ShieldFighter
	var start := hero.global_position
	var raised := 0
	var shield_clip := 0
	for f in 50:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if body.guarding:
			raised += 1
		if body._anim.current_clip() in [body.shield_walk_clip, body.shield_idle_clip]:
			shield_clip += 1
	_check("unprovoked, it comes on with the shield down", raised == 0 and shield_clip == 0,
			"%d raised, %d in a shield clip" % [raised, shield_clip])
	# An arrow at it.
	var health := body.health
	var arrow: Arrow = (load("res://scenes/props/arrow.tscn") as PackedScene).instantiate()
	world.add_child(arrow)
	var from := hero.global_position + Vector3.UP * 1.5
	arrow.global_position = from
	var aim := (body.global_position + Vector3.UP * 1.0) - from
	arrow.launch(aim.normalized() * 45.0, 20.0, false, 0.0, hero)
	var up_at := -1
	var caught := false
	for f in 40:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if up_at < 0 and body.guarding:
			up_at = f
		if body.act == Fighter.Act.BLOCK:
			caught = true
	_check("an arrow loosed at it raises the shield", up_at >= 0, "raised at frame %d" % up_at)
	_check("and is caught on it", caught and body.health >= health - 0.01,
			"health %.0f of %.0f" % [body.health, health])
	# Nothing more: down again.
	var down_at := -1.0
	for f in int((body.raise_hold + 1.5) * 60.0):
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if body.guarding:
			body._cooldown = 99.0
		elif down_at < 0.0:
			down_at = f / 60.0
	_check("with nothing more coming it lowers it", down_at >= 0.0, "down after %.2f s" % down_at)
	# A swing begun at it, from in front and near.
	body.global_position = _ahead(hero, 2.4)
	await physics_frame
	var to := body.global_position - hero.global_position
	hero.rotation.y = atan2(-to.x, -to.z)
	body._start(Fighter.Act.NONE)
	body._answer_swing(hero)
	_check("a swing begun at it raises the shield", body.guarding)
	await _done(world)


## Kept being shot at from 7 m off, it walks in behind the shield, not running.
func _walk_in() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var body := (a[1] as ArenaPanel).call_up(WARRIOR, false, _ahead(hero, 7.0)) as ShieldFighter
	var start := hero.global_position
	var shield_frames := 0
	var top := 0.0
	for f in 120:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		if f % 20 == 5:
			body._raise_shield(hero)
		if f > 30 and body.act == Fighter.Act.NONE and body._distance_to(hero) > body.reach + 0.2:
			top = maxf(top, Vector3(body.velocity.x, 0.0, body.velocity.z).length())
			if body._anim.current_clip() == body.shield_walk_clip:
				shield_frames += 1
	_check("walks in behind its shield", shield_frames > 30, "%d frames in CR_ShieldWalk" % shield_frames)
	_check("not running while it does", top <= body.shield_pace + 0.3, "top %.2f m/s" % top)
	await _done(a[0])


## Cuts at its front are caught, from behind they are not; spent, it breaks.
func _shield() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var body := (a[1] as ArenaPanel).call_up(WARRIOR, false, _ahead(hero, 1.6)) as ShieldFighter
	for i in 20:
		await physics_frame
	body.max_health = 9999.0
	body.health = 9999.0
	body._rouse(hero)
	body.mode = Fighter.Mode.FIGHT
	body._cooldown = 99.0
	body.velocity = Vector3.ZERO
	body.look_at(Vector3(hero.global_position.x, body.global_position.y, hero.global_position.z), Vector3.UP)
	var to_hero := hero.global_position - body.global_position
	var open_bled := body._receive(20.0, body.global_position + Vector3.UP, -to_hero, hero)
	_check("its shield down, a cut at its front gets through (and raises it)",
			open_bled and body.guarding, "health %.0f" % body.health)
	body._start(Fighter.Act.NONE)
	var front_ok := not body._receive(20.0, body.global_position + Vector3.UP, -to_hero, hero)
	_check("a cut at its front is caught on the shield", front_ok and body.act == Fighter.Act.BLOCK,
			"act %d stamina %.0f" % [body.act, body.stamina])
	# The hero round behind it.
	var behind := body.global_position - to_hero.normalized() * 1.5
	var keep := hero.global_position
	hero.global_position = Vector3(behind.x, hero.global_position.y, behind.z)
	body._start(Fighter.Act.NONE)
	var back_bled := body._receive(20.0, body.global_position + Vector3.UP, to_hero, hero)
	_check("a cut from behind gets through", back_bled, "health %.0f" % body.health)
	hero.global_position = keep
	body._start(Fighter.Act.NONE)
	var caught := 0
	for i in 12:
		if body.act == Fighter.Act.BREAK:
			break
		if not body._receive(20.0, body.global_position + Vector3.UP, -to_hero, hero):
			caught += 1
	_check("the guard spent, it breaks", body.act == Fighter.Act.BREAK, "%d caught first" % caught)
	await _done(a[0])


## Caught behind the shield, it answers: the bash, then the sword, both landing.
func _bash() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var body := (a[1] as ArenaPanel).call_up(WARRIOR, false, _ahead(hero, 1.8)) as ShieldFighter
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)
	var start := hero.global_position
	for i in 20:
		await physics_frame
	body._rouse(hero)
	body.counter_bash_chance = 1.0
	var seen := []
	var serial := -1
	var s0: int = struck[0]
	var landed := {}
	var caught := false
	for f in 360:
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		var to := body.global_position - hero.global_position
		hero.rotation.y = atan2(-to.x, -to.z)
		if not caught:
			# His swing begun at it (taken whenever it is free to raise).
			body._raise_shield(hero)
		if not caught and body.shield_up():
			caught = true
			body._receive(10.0, body.global_position + Vector3.UP, -to, hero)
		if body.act_serial != serial:
			serial = body.act_serial
			seen.append(body.act)
			s0 = struck[0]
		if body.act == ShieldFighter.BASH or body.act == ShieldFighter.FOLLOW:
			landed[body.act] = struck[0] - s0
		if seen.has(ShieldFighter.FOLLOW) and body.act != ShieldFighter.FOLLOW:
			break
	var at := seen.find(ShieldFighter.BASH)
	_check("caught, it answers with the bash and then the sword",
			at >= 0 and at + 1 < seen.size() and seen[at + 1] == ShieldFighter.FOLLOW, str(seen))
	_check("the bash lands", int(landed.get(ShieldFighter.BASH, 0)) >= 1, str(landed))
	_check("the sword after it lands", int(landed.get(ShieldFighter.FOLLOW, 0)) >= 1, str(landed))
	await _done(a[0])


## Cut down, it breaks into its bones, and they come to rest on the floor:
## every skeleton of the pack.
func _shatter(kind: String) -> void:
	var a: Array = await _arena()
	var world: Node = a[0]
	var hero: Player = a[2]
	var body := (a[1] as ArenaPanel).call_up("res://scenes/enemies/pack/%s.tscn" % kind, false,
			_ahead(hero, 2.5)) as Brawler
	for i in 20:
		await physics_frame
	var floor_y := body.global_position.y
	body.health = 1.0
	var to := body.global_position - hero.global_position
	body._receive(50.0, body.global_position + Vector3.UP, to, null)
	await physics_frame
	var pieces: Array = []
	for n in Blood.world_of(body).get_children():
		if n is RigidBody3D and String(n.name).begins_with("Bone_"):
			pieces.append(n)
	_check("%s, cut down, breaks into its bones" % kind, pieces.size() >= 12 and not body.body.visible,
			"%d pieces" % pieces.size())
	for i in 150:
		await physics_frame
	var low := 0
	var under := 0
	var still := 0
	for p: RigidBody3D in pieces:
		if not is_instance_valid(p):
			continue
		if p.global_position.y < floor_y + 0.6:
			low += 1
		if p.global_position.y < floor_y - 0.3:
			under += 1
		if p.linear_velocity.length() < 0.5:
			still += 1
	_check("%s: the bones lie on the floor" % kind, low >= pieces.size() - 2 and under == 0,
			"%d low, %d under, %d still of %d" % [low, under, still, pieces.size()])
	await _done(world)
