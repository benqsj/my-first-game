extends SceneTree

## The orc, the ogre, the troll and the golem (2026-10-07, the user's picks),
## and the skeletons coming back together, in the test arena:
##
## * the blows of their own kinds on him: a kick through his shield ("guard"),
##   a shock along the ground he can jump ("ground"), a blow where he lies
##   ("stomp");
## * the orc: leaps at him from off and fells him; kicks through his shield
##   and goes in after it; rages at half its health;
## * the ogre: its pound sends a shock out that fells him; its great blow
##   winds up slowly and beats his guard down; it treads on him lying;
## * the troll: hurls a boulder that reaches him; its wounds close, but not
##   while it burns; its leap shakes the ground;
## * the golem: light blows do not stop it, a heavy one does; stone spikes
##   out of the ground reach him; cut down, it comes back together once;
## * a skeleton comes back together once too.
##
##   godot --headless --path . --script res://tests/brutes_test.gd

const ORC := "res://scenes/enemies/pack/orc.tscn"
const OGRE := "res://scenes/enemies/pack/ogre.tscn"
const TROLL := "res://scenes/enemies/pack/troll.tscn"
const GOLEM := "res://scenes/enemies/pack/golem.tscn"
const SKELETON := "res://scenes/enemies/pack/skeleton.tscn"

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
	panel._unhurt = false
	var hero := world.player()
	hero.immortal = true
	hero.call(&"_set_weapons_stowed", false)
	return [world, panel, hero]


func _ahead(hero: Player, d: float, side: float = 0.0) -> Vector3:
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	return hero.global_position + fwd * d + fwd.cross(Vector3.UP) * side


func _done(world: Node) -> void:
	Input.action_release("block")
	world.queue_free()
	for i in 3:
		await process_frame


func _hold(hero: Player, at: Vector3) -> void:
	hero.global_position = Vector3(at.x, hero.global_position.y, at.z)
	hero.velocity.x = 0.0
	hero.velocity.z = 0.0


func _face(hero: Player, foe: Node3D) -> void:
	var to := foe.global_position - hero.global_position
	hero.rotation.y = atan2(-to.x, -to.z)


func _run() -> void:
	var only := OS.get_cmdline_user_args()
	if not only.is_empty():
		for name in only:
			if name == "golem_reform":
				await _reform(GOLEM, "the golem")
			elif name == "skel_reform":
				await _reform(SKELETON, "a skeleton")
			else:
				await call("_" + name)
		print("brutes_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
		quit(1 if _failed > 0 else 0)
		return
	await _kinds()
	await _orc_leap()
	await _orc_kick()
	await _rage()
	await _ogre_pound()
	await _ogre_heavy()
	await _ogre_stomp()
	await _troll_boulder()
	await _troll_regen()
	await _troll_leap()
	await _golem_steady()
	await _golem_spikes()
	await _reform(GOLEM, "the golem")
	await _reform(SKELETON, "a skeleton")
	print("brutes_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


## The kinds of blow, on him directly.
func _kinds() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var foe := Node3D.new()
	world.add_child(foe)
	var struck := []
	hero.struck.connect(func(d: float, b: bool) -> void: struck.append([d, b]))
	# A kick at his raised shield beats it down.
	Input.action_press("block")
	for i in 40:
		await physics_frame
	foe.global_position = hero.global_position - hero.global_basis.z * 1.5
	hero.last_guard_break = {}
	hero.receive_blow(10.0, foe, 0, 3, 77, false, &"guard")
	for i in 3:
		await physics_frame
	_check("a kick at his shield beats his guard down", not hero.last_guard_break.is_empty() and not hero.is_blocking,
			str(struck))
	Input.action_release("block")
	for i in 150:
		await physics_frame
	# The same kick at a shield, an ordinary blow: only blocked.
	Input.action_press("block")
	for i in 40:
		await physics_frame
	hero.stamina = hero.max_stamina
	hero.last_guard_break = {}
	hero.receive_blow(10.0, foe, 0, 3, 78)
	for i in 3:
		await physics_frame
	_check("an ordinary blow on it is only blocked", hero.last_guard_break.is_empty() and hero.is_blocking)
	# A shock along the ground: no shield takes it.
	struck.clear()
	hero.receive_blow(10.0, foe, 0, 1, 79, false, &"ground")
	for i in 3:
		await physics_frame
	_check("the ground's shock goes under his shield and fells him", hero.state == Player.State.DOWNED, str(struck))
	Input.action_release("block")
	for i in 200:
		await physics_frame
	# Off the ground, it misses him.
	hero.velocity.y = 6.0
	hero.state = Player.State.AIRBORNE
	for i in 4:
		await physics_frame
	struck.clear()
	var airborne := not hero.is_on_floor()
	hero.receive_blow(10.0, foe, 0, 1, 80, false, &"ground")
	for i in 2:
		await physics_frame
	_check("off the ground, the shock misses him", airborne and struck.is_empty(), str(struck))
	for i in 90:
		await physics_frame
	# Lying down: an ordinary blow passes over him, a stomp does not.
	hero.receive_blow(10.0, foe, 0, 1, 81)
	for i in 10:
		await physics_frame
	struck.clear()
	hero.receive_blow(10.0, foe, 0, 1, 82)
	for i in 2:
		await physics_frame
	var ordinary := struck.size()
	hero.receive_blow(10.0, foe, 0, 1, 83, false, &"stomp")
	for i in 2:
		await physics_frame
	_check("lying, an ordinary blow passes over him; a stomp lands", hero.state == Player.State.DOWNED
			and ordinary == 0 and struck.size() == 1, "%d, %s" % [ordinary, str(struck)])
	await _done(world)


## Waits up to `frames` for `cond`, holding him where he stands.
func _until(frames: int, hero: Player, at: Vector3, cond: Callable, look: Node3D = null) -> bool:
	for f in frames:
		await physics_frame
		if hero.state != Player.State.DOWNED:
			_hold(hero, at)
		if look != null:
			_face(hero, look)
		if cond.call():
			return true
	return false


func _orc_leap() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var orc := (a[1] as ArenaPanel).call_up(ORC, false, _ahead(hero, 8.0)) as OrcFighter
	orc._leap_wait = 0.0
	var leapt := [false]
	var down := await _until(360, hero, start, func() -> bool:
		if orc.act == PackBrute.LEAP:
			leapt[0] = true
		return leapt[0] and hero.state == Player.State.DOWNED, orc)
	_check("the orc leaps at him from off and fells him", down, "leapt %s, %.1f m off" % [leapt[0], orc._distance_to(hero)])
	await _done(world)


func _orc_kick() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var orc := (a[1] as ArenaPanel).call_up(ORC, false, _ahead(hero, 2.2)) as OrcFighter
	orc._leap_wait = 99.0
	hero.last_guard_break = {}
	Input.action_press("block")
	var kicked := [false]
	var broken := await _until(480, hero, start, func() -> bool:
		hero.stamina = hero.max_stamina
		if orc.act == OrcFighter.KICK:
			kicked[0] = true
		return not hero.last_guard_break.is_empty(), orc)
	_check("behind his shield, the orc kicks it aside", kicked[0] and broken)
	var after := [false]
	var serial := orc.act_serial
	await _until(120, hero, start, func() -> bool:
		if orc.act_serial != serial and orc.act >= Brawler.ATTACK_BASE and orc.act < Brawler.BIG_BASE:
			after[0] = true
		return after[0], orc)
	_check("and goes straight in after it", after[0])
	await _done(world)


func _rage() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var orc := (a[1] as ArenaPanel).call_up(ORC, false, _ahead(hero, 6.0)) as OrcFighter
	var mate := (a[1] as ArenaPanel).call_up(ORC, false, _ahead(hero, 14.0, 8.0)) as OrcFighter
	mate.sight_range = 0.0
	for i in 20:
		await physics_frame
	var pace0 := orc.chase_speed
	orc._rouse(hero)
	orc._leap_wait = 99.0
	orc.health = orc.max_health * 0.48
	var raged := await _until(240, hero, start, func() -> bool: return orc.raging, orc)
	_check("cut to half its health, the orc rages", raged and orc.chase_speed > pace0,
			"%.1f -> %.1f m/s" % [pace0, orc.chase_speed])
	_check("and the orcs about come at its roar", mate.mode == Fighter.Mode.CHASE or mate.mode == Fighter.Mode.FIGHT)
	await _done(world)


func _ogre_pound() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var ogre := (a[1] as ArenaPanel).call_up(OGRE, false, _ahead(hero, 4.0)) as OgreFighter
	ogre._pound_wait = 0.0
	ogre._heavy_wait = 99.0
	ogre.attacks.clear()
	var pounded := [false]
	var down := await _until(360, hero, start, func() -> bool:
		if ogre.act == OgreFighter.POUND:
			pounded[0] = true
		return pounded[0] and hero.state == Player.State.DOWNED, ogre)
	_check("the ogre's pound sends a shock out that fells him", down, "pounded %s" % pounded[0])
	await _done(world)


func _ogre_heavy() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var ogre := (a[1] as ArenaPanel).call_up(OGRE, false, _ahead(hero, 3.6)) as OgreFighter
	ogre._pound_wait = 99.0
	ogre._heavy_wait = 0.0
	var slow := ogre._move_length(OgreFighter.HEAVY)
	var plain := ogre._move_length(OgreFighter.STOMP)
	_check("the great blow's wind-up is drawn out", slow > plain + 0.5, "%.2f s against %.2f s" % [slow, plain])
	hero.last_guard_break = {}
	Input.action_press("block")
	var swung := [false]
	var broken := await _until(480, hero, start, func() -> bool:
		hero.stamina = hero.max_stamina
		if ogre.act == OgreFighter.HEAVY:
			swung[0] = true
		return swung[0] and not hero.last_guard_break.is_empty(), ogre)
	_check("and no shield holds it", broken, "swung %s" % swung[0])
	await _done(world)


func _ogre_stomp() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var ogre := (a[1] as ArenaPanel).call_up(OGRE, false, _ahead(hero, 3.0)) as OgreFighter
	ogre._pound_wait = 99.0
	ogre._heavy_wait = 99.0
	for i in 20:
		await physics_frame
	ogre._rouse(hero)
	var struck := []
	hero.struck.connect(func(d: float, b: bool) -> void: struck.append([d, b]))
	var foe := Node3D.new()
	world.add_child(foe)
	foe.global_position = ogre.global_position
	hero.receive_blow(5.0, foe, 0, 1, 5)
	hero.down_time = 6.0
	for i in 3:
		await physics_frame
	hero._down_timer = 6.0
	struck.clear()
	var stomped := [false]
	var hit := await _until(360, hero, start, func() -> bool:
		if ogre.act == OgreFighter.STOMP:
			stomped[0] = true
		return stomped[0] and struck.size() > 0, ogre)
	_check("him down, the ogre treads on him where he lies", hit, "stomped %s, %s" % [stomped[0], str(struck)])
	await _done(world)


func _troll_boulder() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var troll := (a[1] as ArenaPanel).call_up(TROLL, false, _ahead(hero, 12.0)) as TrollFighter
	troll._hurl_wait = 0.0
	troll._leap_wait = 99.0
	var struck := []
	hero.struck.connect(func(d: float, b: bool) -> void: struck.append([d, b]))
	var hurled := [false]
	var hit := await _until(420, hero, start, func() -> bool:
		if troll.act == TrollFighter.HURL:
			hurled[0] = true
		return hurled[0] and struck.size() > 0, troll)
	_check("the troll hurls a boulder that reaches him", hit, "hurled %s" % hurled[0])
	_check("and it throws him down", hero.state == Player.State.DOWNED)
	await _done(world)


func _troll_regen() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var troll := (a[1] as ArenaPanel).call_up(TROLL, false, _ahead(hero, 6.0)) as TrollFighter
	for i in 10:
		await physics_frame
	troll.sight_range = 0.0
	troll.health = troll.max_health * 0.5
	var h0 := troll.health
	for i in 120:
		await physics_frame
	_check("the troll's wounds close", troll.health > h0 + troll.max_health * 0.015 and troll.healing,
			"%.0f -> %.0f" % [h0, troll.health])
	Afflictions.of(troll).apply(&"burn", 3.0, hero, 0.0)
	for i in 5:
		await physics_frame
	var h1 := troll.health
	for i in 120:
		await physics_frame
	_check("not while it burns", troll.health <= h1 + 0.01 and not troll.healing, "%.0f -> %.0f" % [h1, troll.health])
	await _done(world)


func _troll_leap() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var troll := (a[1] as ArenaPanel).call_up(TROLL, false, _ahead(hero, 8.0)) as TrollFighter
	troll._hurl_wait = 99.0
	troll._leap_wait = 0.0
	var leapt := [false]
	var down := await _until(360, hero, start, func() -> bool:
		if troll.act == PackBrute.LEAP:
			leapt[0] = true
		return leapt[0] and hero.state == Player.State.DOWNED, troll)
	for i in 30:
		await physics_frame
	_check("the troll leaps at him, fells him, and the ground shakes where it lands", down and troll.quakes_made > 0,
			"leapt %s, %d quakes" % [leapt[0], troll.quakes_made])
	await _done(world)


func _golem_steady() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var golem := (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 6.0)) as GolemFighter
	for i in 20:
		await physics_frame
	golem.sight_range = 0.0
	var reeled := false
	for k in 2:
		golem._receive(15.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
		for i in 30:
			await physics_frame
			reeled = reeled or golem.act == Fighter.Act.REACT_KNOCK
	_check("light blows apart do not stop the golem", not reeled)
	golem._receive(60.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await physics_frame
	_check("a heavy one staggers it", golem.act == Fighter.Act.REACT_KNOCK)
	for i in 200:
		await physics_frame
	for k in 5:
		golem._receive(20.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
		await physics_frame
	_check("and so does a string of them", golem.act == Fighter.Act.REACT_KNOCK)
	await _done(world)


func _golem_spikes() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var golem := (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 8.0)) as GolemFighter
	golem._spikes_wait = 0.0
	var struck := []
	hero.struck.connect(func(d: float, b: bool) -> void: struck.append([d, b]))
	Input.action_press("block")
	var spiked := [false]
	var hit := await _until(420, hero, start, func() -> bool:
		hero.stamina = hero.max_stamina
		if golem.act == GolemFighter.SPIKES:
			spiked[0] = true
		return spiked[0] and hero.state == Player.State.DOWNED, golem)
	_check("the golem's stone spikes reach him under his shield and fell him", hit, "%s %s" % [spiked[0], str(struck)])
	await _done(world)


func _reform(scene: String, what: String) -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var f := (a[1] as ArenaPanel).call_up(scene, false, _ahead(hero, 6.0)) as Brawler
	for i in 20:
		await physics_frame
	f.sight_range = 0.0
	f.reform_chance = 1.0
	f.health = 1.0
	f._receive(50.0, f.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await physics_frame
	await process_frame
	_check("%s cut down comes apart, not dead" % what, f.act == Brawler.PIECES and not f.is_dead
			and not f.body.visible and not f._pieces.is_empty() and not f.is_in_group(&"enemy"))
	f._receive(50.0, f.global_position + Vector3.UP, Vector3.FORWARD, hero)
	_check("and in pieces nothing lands on it", f.act == Brawler.PIECES and not f.is_dead)
	var whole := false
	for i in int((f.reform_after + f.reform_time) * 60.0) + 60:
		await physics_frame
		if f.act != Brawler.PIECES:
			whole = true
			break
	for i in 3:
		await process_frame
	_check("its pieces gather and it stands again", whole and f.body.visible and f.health > f.max_health * 0.3
			and f.is_in_group(&"enemy") and f._pieces.is_empty(), "%.0f hp, whole %s, seen %s, enemy %s, %d pieces, act %d" % [
				f.health, whole, f.body.visible, f.is_in_group(&"enemy"), f._pieces.size(), f.act])
	for i in 120:
		await physics_frame
	f.health = 1.0
	f._receive(50.0, f.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await physics_frame
	_check("cut down again, it is dead for good", f.is_dead)
	await _done(world)
