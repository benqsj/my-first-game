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
## * the troll: (its old boulder, switched on) reaches him; its wounds close,
##   but not while it burns; its leap; a great club in both hands, slow, a
##   missed swing leaves it reeling, wounds that slow it (2026-10-25);
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
	await _troll_stance()
	await _golem_steady()
	await _golem_spikes()
	await _troll_heavy()
	await _golem_fortress()
	await _golem_rhythm()
	await _golem_round3()
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
		# (2026-10-15: the orc's leap is its fall from the sky)
		if orc.act == PackBrute.LEAP or orc.act == OrcFighter.O_SKY:
			leapt[0] = true
		return leapt[0] and hero.state == Player.State.DOWNED, orc)
	_check("the orc leaps at him from off (out of the sky) and fells him", down, "leapt %s, %.1f m off" % [leapt[0], orc._distance_to(hero)])
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
		# felled, or (its shock alone, not the club: the hero's side since
		# 2026-10-10) reeling on his feet
		var hero_rig := hero.rig as SkinnedRig
		var reeled := hero_rig != null and String(hero_rig.last_flinch.get("clip", "")).begins_with("TR_Big_Side_Hit")
		return pounded[0] and (hero.state == Player.State.DOWNED or reeled), ogre)
	_check("the ogre's pound sends a shock out that catches him (fells or reels him)", down, "pounded %s" % pounded[0])
	await _done(world)


func _ogre_heavy() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var ogre := (a[1] as ArenaPanel).call_up(OGRE, false, _ahead(hero, 3.6)) as OgreFighter
	ogre._pound_wait = 99.0
	ogre._heavy_wait = 0.0
	# (behind his shield it would reach for him instead — its grab — or open
	# its shield-breaking combo)
	ogre._grab_wait = 99.0
	ogre.combo_chance = Vector2.ZERO
	ogre.close_combo_chance = 0.0
	# (its spacing between strings is not what is tried here)
	ogre.spacing_time = Vector2.ZERO
	var slow := ogre._move_length(OgreFighter.HEAVY)
	var plain := ogre._move_length(OgreFighter.STOMP)
	_check("the great blow's wind-up is drawn out", slow > plain + 0.5, "%.2f s against %.2f s" % [slow, plain])
	hero.last_guard_break = {}
	Input.action_press("block")
	var swung := [false]
	var broken := await _until(960, hero, start, func() -> bool:
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


## Elden Ring's stance on the troll too: heavy blows fill it, it goes down
## on a knee, open to a critical.
func _troll_stance() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var troll := (a[1] as ArenaPanel).call_up(TROLL, false, _ahead(hero, 4.0)) as TrollFighter
	troll._rock_wait = 99.0
	troll._grab_wait = 99.0
	troll._leap_wait = 99.0
	for k in 8:
		troll._add_stance(60.0)
		for f in 10:
			await world.get_tree().physics_frame
	for f in 20:
		await world.get_tree().physics_frame
	_check("the troll's stance breaks under heavy blows, and it kneels open", troll.stance_breaks >= 1 and troll.crit_open(),
			"%d breaks, open %s" % [troll.stance_breaks, troll.crit_open()])
	await _done(world)


func _troll_boulder() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var troll := (a[1] as ArenaPanel).call_up(TROLL, false, _ahead(hero, 12.0)) as TrollFighter
	# the boulder over its head (its other rocks are its choice)
	troll.rock_pick = TrollRock.Kind.BIG
	troll._rock_wait = 0.0
	troll._grab_wait = 99.0
	troll._leap_wait = 99.0
	var struck := []
	hero.struck.connect(func(d: float, b: bool) -> void: struck.append([d, b]))
	var hurled := [false]
	var hit := await _until(420, hero, start, func() -> bool:
		if troll.act == TrollFighter.R_THROW:
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
	_check("the troll's wounds close", troll.health > h0 + troll.max_health * 0.005 and troll.healing,
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
	troll._rock_wait = 99.0
	troll._grab_wait = 99.0
	troll._leap_wait = 0.0
	var leapt := [false]
	var down := await _until(360, hero, start, func() -> bool:
		if troll.act == PackBrute.LEAP:
			leapt[0] = true
		return leapt[0] and hero.state == Player.State.DOWNED, troll)
	for i in 30:
		await physics_frame
	_check("the troll tackles him from off and fells him", down, "tackled %s" % leapt[0])
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
			reeled = reeled or golem.act == Fighter.Act.REACT_KNOCK or golem.act == GolemFighter.G_DAZE
	_check("light blows apart do not stop the golem", not reeled)
	golem._receive(60.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await physics_frame
	_check("a heavy one staggers it", golem.act in [Fighter.Act.REACT_KNOCK, GolemFighter.G_DAZE])
	for i in 200:
		await physics_frame
	for k in 5:
		golem._receive(20.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
		await physics_frame
	_check("and so does a string of them", golem.act in [Fighter.Act.REACT_KNOCK, GolemFighter.G_DAZE])
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


## 2026-10-15 (the user's word): the troll and the golem, each its own way.
## The troll (2026-10-25, the user's word: heavy, Elden Ring's, its own
## moves): bare-handed and slow, no hop aside, fists closed; its grab catches
## him and slams him down; at half its health it tears a tree out of the
## ground; his blows break the tree, and broken it leaves the troll open; a
## great swing that finds nothing leaves it reeling; a wound slows it.
func _troll_heavy() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var troll := (a[1] as ArenaPanel).call_up(TROLL, false, _ahead(hero, 16.0)) as TrollFighter
	troll._leap_wait = 999.0
	troll._rock_wait = 999.0
	troll._grab_wait = 999.0
	troll._rouse(hero)
	var top := 0.0
	for i in 240:
		await physics_frame
		_hold(hero, start)
		top = maxf(top, Vector2(troll.velocity.x, troll.velocity.z).length())
		if troll._distance_to(hero) < troll.reach:
			break
	_check("the troll comes on two feet, not fast", troll.run_clip == &"CR_TR_MutantRun" and top < 3.8, "%.1f m/s" % top)
	_check("it does not hop aside, its hands are fists", troll.dash_chance == 0.0 and troll._hand_fists.size() == 2
			and not troll.armed)
	# the grab
	troll._grab_wait = 0.0
	var caught := [false]
	var slammed := await _until(600, hero, start, func() -> bool:
		if troll._grabbed != null:
			caught[0] = true
		return caught[0] and hero.state == Player.State.DOWNED, troll)
	_check("its grab catches him and slams him down", slammed and troll.grabs_caught >= 1,
			"caught %s, %d grabs" % [caught[0], troll.grabs_made])
	troll._grab_wait = 999.0
	for i in 120:
		await physics_frame
	# half its health: the tree
	troll.health = troll.max_health * 0.5
	var armed := false
	for i in 600:
		await physics_frame
		_hold(hero, start)
		if troll.armed:
			armed = true
			break
	_check("at half its health it tears a tree out of the ground", armed and troll._tree != null
			and troll.idle_clip == &"CR_HeavyIdle", "uproots %d" % troll.uproots)
	troll.sight_range = 0.0
	troll._go_home()
	for i in 10:
		await physics_frame
	hero.global_position = troll.global_position + troll._forward() * 9.0
	troll._begin(TrollFighter.W_GREAT)
	var reeled := false
	for i in 400:
		await physics_frame
		if troll.act == TrollFighter.T_REEL:
			reeled = true
			break
	_check("a great swing that finds nothing leaves it reeling", reeled and troll.reels >= 1)
	for i in 60:
		await physics_frame
	var broke_open := false
	for k in 20:
		troll._wear_tree(0.08)
		await physics_frame
		if not troll.armed:
			break
	for i in 30:
		await physics_frame
	broke_open = troll.trees_broken == 1 and not troll.armed and troll.crit_open()
	_check("his blows break the tree, and it leaves the troll on its knee", broke_open,
			"broken %d, armed %s, open %s" % [troll.trees_broken, troll.armed, troll.crit_open()])
	var pace := troll.chase_speed
	var balance := troll.stance
	troll._wound(troll.global_position + Vector3.UP * 2.0, Vector3.FORWARD)
	_check("a wound slows it and weakens its balance", troll.chase_speed < pace and troll.stance < balance,
			"%.2f -> %.2f, %.0f -> %.0f" % [pace, troll.chase_speed, balance, troll.stance])
	await _done(world)


func _golem_fortress() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var golem := (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 14.0)) as GolemFighter
	_check("the golem never runs", golem.run_clip == &"" and golem.chase_speed <= 2.6)
	var shared := []
	var troll_clips := [&"CR_Punch1", &"CR_PunchL", &"CR_Hook", &"CR_Uppercut", &"CR_ZombieScratch", &"CR_ZombieBite"]
	for what: int in golem._moves_table:
		var clip: StringName = (golem._moves_table[what] as Array)[0]
		if clip in troll_clips or String(clip).begins_with("CR_OG_"):
			shared.append(clip)
	_check("none of its blows the troll's or the ogre's", shared.is_empty(), str(shared))
	for i in 20:
		await physics_frame
	golem.sight_range = 0.0
	var h0 := golem.health
	golem._receive(30.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	golem._receive(30.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	for i in 3:
		await physics_frame
	var hard := golem.hardened
	var h1 := golem.health
	golem._receive(20.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	var hard_cost := h1 - golem.health
	_check("under blows its stone hardens", hard, "poise %.0f" % golem._poise_taken)
	golem._receive(40.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await physics_frame
	var h2 := golem.health
	golem._receive(20.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	var open_cost := h2 - golem.health
	_check("then the shell bursts and it is open", golem.shells_burst >= 1 and open_cost > hard_cost * 2.0,
			"hard %.1f, open %.1f (from %.0f)" % [hard_cost, open_cost, h0])
	await _done(world)
	a = await _arena()
	world = a[0]
	hero = a[2]
	var start := hero.global_position
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 8.0)) as GolemFighter
	golem._wall_wait = 0.0
	golem._spikes_wait = 999.0
	golem.hand_combo_chance = Vector2.ZERO
	var walls := 0
	for i in 240:
		await physics_frame
		_hold(hero, start)
		walls = world.find_children("GolemWall*", "StaticBody3D", true, false).size()
		if walls > 0:
			break
	_check("it raises stone walls round him", golem.walls_raised >= 1 and walls >= 3, "%d walls" % walls)
	await _done(world)


## Round 2 (the user's word: more moves, not the same over and over, quick
## strings now and then): three paces, the quick strings, the counter, the
## ram from off, dazed and armoured again, its combos varied.
func _golem_rhythm() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	var golem := (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 3.2)) as GolemFighter
	var clips := {}
	for what: int in golem._strikes_table:
		clips[(golem._moves_table[what] as Array)[0]] = true
	_check("the golem has many blows of its own", clips.size() >= 14, "%d clips" % clips.size())
	var quick := golem._blow_moments(GolemFighter.G_SWAT)[0]
	var slow := golem._blow_moments(GolemFighter.G_HAMMER)[0]
	_check("quick blows and slow ones", quick < 0.55 and slow > 0.75, "swat %.2f s, hammer %.2f s" % [quick, slow])
	var rs: Array = (golem._hand_combos[golem._combo_index(&"rockslide")] as Dictionary)["moves"]
	var t := 0.0
	var gaps := []
	for what: int in rs:
		var ms := golem._blow_moments(what)
		gaps.append(t + ms[0])
		t += golem._move_length(what)
	var span := float(gaps[-1]) - float(gaps[0])
	_check("its quick string: four blows close together", span < 2.6, "%.2f s first to last" % span)
	for i in 20:
		await physics_frame
	golem._rouse(hero)
	golem._spikes_wait = 999.0
	golem._wall_wait = 999.0
	golem._far_wait = 999.0
	golem._counter_wait = 0.0
	golem._cooldown = 3.0
	for k in 3:
		golem._receive(6.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	var countered := false
	for i in 40:
		await physics_frame
		_hold(hero, start)
		if golem.act == GolemFighter.G_SHOVE:
			countered = true
			break
	_check("pressed, it answers at once", countered and golem.counters_made == 1)
	await _done(world)
	# the ram from off: it slides the gap
	a = await _arena()
	world = a[0]
	hero = a[2]
	start = hero.global_position
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 8.5)) as GolemFighter
	for i in 20:
		await physics_frame
	golem._rouse(hero)
	golem._spikes_wait = 999.0
	golem._wall_wait = 999.0
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)
	golem._face(hero.global_position - golem.global_position, 1.0, 50.0)
	golem.start_hand_combo(golem._combo_index(&"ram_far"))
	var top := 0.0
	var least := 99.0
	var at_blow := -1.0
	var blow_at := golem._blow_moments(GolemFighter.G_RAM)[0]
	for i in 100:
		await physics_frame
		_hold(hero, start)
		top = maxf(top, Vector2(golem.velocity.x, golem.velocity.z).length())
		least = minf(least, golem._distance_to(hero))
		if golem.act == GolemFighter.G_RAM and at_blow < 0.0 and golem._act_time >= blow_at:
			at_blow = golem._distance_to(hero)
	_check("from off it rams him, sliding the gap", top > 5.0 and struck[0] >= 1,
			"%.1f m/s, struck %d, closest %.2f, at the blow %.2f (reach %.2f)" % [top, struck[0], least, at_blow, golem.reach])
	await _done(world)
	# dazed as the shell bursts, armoured again after
	a = await _arena()
	world = a[0]
	hero = a[2]
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 8.0)) as GolemFighter
	for i in 20:
		await physics_frame
	golem.sight_range = 0.0
	golem._receive(60.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await physics_frame
	var dazed := golem.act == GolemFighter.G_DAZE
	var armoured := false
	for i in 260:
		await physics_frame
		armoured = armoured or golem.act == GolemFighter.G_ARMOUR
	_check("its shell burst it stands dazed, then flexes its stone back on", dazed and armoured)
	await _done(world)
	# its combos varied: against him standing, never one three times running
	a = await _arena()
	world = a[0]
	hero = a[2]
	start = hero.global_position
	hero.max_health = 1000000.0
	hero.health = hero.max_health
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 3.0)) as GolemFighter
	golem._spikes_wait = 999.0
	golem._wall_wait = 999.0
	golem._rouse(hero)
	for i in 60 * 40:
		await physics_frame
		_hold(hero, start)
		hero.health = hero.max_health
	var made: Array = golem.hand_combos_made
	var kinds := {}
	var run := 1
	var most := 1
	for i in made.size():
		kinds[made[i]] = true
		if i > 0:
			run = run + 1 if made[i] == made[i - 1] else 1
			most = maxi(most, run)
	var names := []
	for i in made:
		names.append(String((golem._hand_combos[i] as Dictionary)["name"]))
	_check("its combos varied", kinds.size() >= 3 and most < 3, ", ".join(names))
	await _done(world)


## Round 3 (the user's list): thorns where its fists come down, all round and
## far out; its kick's line of them; its fist thrown, him dragged back and the
## combo on him (a roll slips it); the thorn field; quick leaps; the maul.
func _golem_round3() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var start := hero.global_position
	hero.max_health = 1000000.0
	hero.health = hero.max_health
	var golem := (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 3.0)) as GolemFighter
	var leap := golem._blow_moments(GolemFighter.G_QUAKE)[0]
	var slam := golem._blow_moments(GolemFighter.G_SLAM)[0]
	_check("its leap and its fists down are quick now, still seen coming", leap < 1.6 and slam < 1.0 and slam > 0.45, "leap %.2f s, slam %.2f s" % [leap, slam])
	for i in 20:
		await physics_frame
	# thorns all round where its fists come down: him 3.5 m off is caught
	var before := golem.bursts_hurt
	hero.global_position = golem.global_position + golem._forward() * (1.6 + 3.2)
	start = hero.global_position
	golem._break_ground(false)
	for i in 40:
		await physics_frame
		_hold(hero, start)
	var spikes := world.find_children("*", "GroundFx", true, false).size()
	_check("thorns burst up all round where its fists come down, out past 4 m", golem.bursts_hurt > before
			and golem.burst_radius >= 4.5, "%d hurt, %d thorn bursts" % [golem.bursts_hurt - before, spikes])
	await _done(world)
	# its kick: a line of thorns from its foot
	a = await _arena()
	world = a[0]
	hero = a[2]
	start = hero.global_position
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 3.0)) as GolemFighter
	for i in 20:
		await physics_frame
	golem._rouse(hero)
	golem._face(hero.global_position - golem.global_position, 1.0, 50.0)
	golem._begin(GolemFighter.G_KICK)
	var ran := false
	for i in 90:
		await physics_frame
		_hold(hero, start)
		ran = ran or golem._runs.size() > 0
	_check("its kick runs thorns out from its foot", ran)
	await _done(world)
	# its fist thrown: caught, dragged back, the combo on him
	a = await _arena()
	world = a[0]
	hero = a[2]
	hero.max_health = 1000000.0
	hero.health = hero.max_health
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 12.0)) as GolemFighter
	for i in 20:
		await physics_frame
	golem._rouse(hero)
	golem._spikes_wait = 999.0
	golem._wall_wait = 999.0
	golem._far_wait = 999.0
	golem._field_wait = 999.0
	golem._fist_wait = 0.0
	var held := false
	var least := 99.0
	var combo := false
	for i in 400:
		await physics_frame
		held = held or hero._held_by == golem
		least = minf(least, golem._distance_to(hero))
		if golem._hand_combo >= 0 and StringName((golem._hand_combos[golem._hand_combo] as Dictionary)["name"]) == &"reel_in":
			combo = true
			break
	_check("its fist flies at him, catches him, drags him back and the combo is on him",
			golem.fists_thrown >= 1 and held and least < 4.0 and combo,
			"thrown %d, held %s, closest %.1f m, combo %s" % [golem.fists_thrown, held, least, combo])
	await _done(world)
	# a roll slips it
	a = await _arena()
	world = a[0]
	hero = a[2]
	start = hero.global_position
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 12.0)) as GolemFighter
	for i in 20:
		await physics_frame
	golem._rouse(hero)
	golem._spikes_wait = 999.0
	golem._wall_wait = 999.0
	golem._far_wait = 999.0
	golem._field_wait = 999.0
	golem._fist_wait = 0.0
	for i in 200:
		await physics_frame
		_hold(hero, start)
		hero.state = Player.State.DODGING
		hero.is_invulnerable = true
	hero.is_invulnerable = false
	hero.state = Player.State.GROUNDED
	_check("a roll slips its fist", golem.fists_thrown >= 1 and golem.fists_caught == 0)
	await _done(world)
	# the thorn field under him
	a = await _arena()
	world = a[0]
	hero = a[2]
	start = hero.global_position
	hero.max_health = 1000000.0
	hero.health = hero.max_health
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 8.0)) as GolemFighter
	for i in 20:
		await physics_frame
	golem._rouse(hero)
	golem._spikes_wait = 999.0
	golem._wall_wait = 999.0
	golem._far_wait = 999.0
	golem._fist_wait = 999.0
	golem._field_wait = 0.0
	var hurt0 := golem.bursts_hurt
	for i in 300:
		await physics_frame
		_hold(hero, start)
		hero.health = hero.max_health
	_check("the ground under him glows and bursts, following him", golem.fields_cast >= 1 and golem.bursts_hurt > hurt0,
			"%d cast, %d hurt" % [golem.fields_cast, golem.bursts_hurt - hurt0])
	await _done(world)
	# risen again, it fights with a maul
	a = await _arena()
	world = a[0]
	hero = a[2]
	start = hero.global_position
	golem = (a[1] as ArenaPanel).call_up(GOLEM, false, _ahead(hero, 6.0)) as GolemFighter
	for i in 20:
		await physics_frame
	golem.sight_range = 0.0
	golem.health = 1.0
	golem._receive(50.0, golem.global_position + Vector3.UP, Vector3.FORWARD, hero)
	for i in int((golem.reform_after + golem.reform_time) * 60.0) + 260:
		await physics_frame
		_hold(hero, start)
	var maul := golem.find_child("GolemMaul", true, false)
	var names := []
	for c: Dictionary in golem._hand_combos:
		names.append(String(c["name"]))
	_check("risen again, the stone flies into its hand: a maul, and the maul's strings", golem.armed and maul != null
			and golem._grip_learnt and names.has("maul_crush") and golem.idle_clip == &"CR_HeavyIdle",
			"armed %s, maul %s, grip %s, %s" % [golem.armed, maul != null, golem._grip_learnt, str(names)])
	# and its maul's blows land
	hero.max_health = 1000000.0
	hero.health = hero.max_health
	hero.global_position = golem.global_position + golem._forward() * 3.0
	start = hero.global_position
	golem.sight_range = 14.0
	golem._rouse(hero)
	golem._spikes_wait = 999.0
	golem._wall_wait = 999.0
	golem._far_wait = 999.0
	golem._field_wait = 999.0
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)
	var swung := {}
	for i in 60 * 14:
		await physics_frame
		_hold(hero, start)
		hero.health = hero.max_health
		if golem.act in GolemFighter.WEAPON_MOVES:
			swung[golem.act] = true
	_check("its maul's blows land on him", swung.size() >= 2 and struck[0] >= 3,
			"%d of its maul's moves, struck %d" % [swung.size(), struck[0]])
	await _done(world)
