extends SceneTree

## The goblin and the ghoul (2026-10-07, the user's picks), in the test arena:
##
## * gold: a creature cut down drops coins, and walking over them fills his
##   purse;
## * the goblin: its blow takes a share of his gold and it runs; cut down it
##   drops it back; alone it keeps off and throws; with another it goes round
##   to his back; hurt it runs and shrieks, and the others come;
## * the ghoul: its claws poison him; cut deep it screams into a frenzy; it
##   feeds on a corpse and is healed by it.
##
##   godot --headless --path . --script res://tests/goblin_ghoul_test.gd

const GOBLIN := "res://scenes/enemies/pack/goblin.tscn"
const GHOUL := "res://scenes/enemies/pack/ghoul.tscn"
const ORC := "res://scenes/enemies/pack/orc.tscn"

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


func _ahead(hero: Player, d: float, side: float = 0.0) -> Vector3:
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	return hero.global_position + fwd * d + fwd.cross(Vector3.UP) * side


func _done(world: Node) -> void:
	world.queue_free()
	for i in 3:
		await process_frame


func _hold(hero: Player, at: Vector3) -> void:
	hero.global_position = Vector3(at.x, hero.global_position.y, at.z)
	hero.velocity = Vector3.ZERO


func _frames(n: int, hero: Player, at: Vector3) -> void:
	for i in n:
		await physics_frame
		_hold(hero, at)


func _run() -> void:
	await _gold()
	await _theft()
	await _alone_throws()
	await _flank()
	await _cowardice()
	await _poison()
	await _frenzy()
	await _feeding()
	print("goblin_ghoul_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _piles(world: Node) -> Array:
	var out := []
	for n in Blood.world_of(world.get_node("CoinBank")).find_children("Coins_*", "Node3D", true, false):
		if n is Coins and not n.is_queued_for_deletion():
			out.append(n)
	return out


## Cut down, an orc drops coins; he walks over them and has them.
func _gold() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var purse := Purse.of(hero)
	_check("he has a purse, empty", purse != null and purse.gold == 0)
	var orc := (a[1] as ArenaPanel).call_up(ORC, false, _ahead(hero, 3.0)) as Fighter
	await _frames(10, hero, hero.global_position)
	orc.health = 1.0
	orc._receive(50.0, orc.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await _frames(40, hero, hero.global_position)
	var piles := _piles(world)
	_check("cut down, it drops coins", piles.size() == 1, "%d piles" % piles.size())
	if piles.is_empty():
		await _done(world)
		return
	var pile := piles[0] as Coins
	var worth := pile.amount
	var at := pile.global_position
	for i in 30:
		await physics_frame
		_hold(hero, at)
	_check("walking over them, they are his", purse.gold == worth and worth > 0, "%d of %d" % [purse.gold, worth])
	await _done(world)


## A goblin's blow takes a share of his gold and it runs with it; cut down,
## it drops it back.
func _theft() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var purse := Purse.of(hero)
	purse.give(100)
	var start := hero.global_position
	var gob := (a[1] as ArenaPanel).call_up(GOBLIN, false, _ahead(hero, 1.4)) as GoblinFighter
	(a[1] as ArenaPanel).call_up(GOBLIN, false, _ahead(hero, 4.0, 3.0))
	await _frames(15, hero, start)
	gob.steal_chance = 1.0
	gob._rouse(hero)
	gob._blow_reached(hero, 0)
	await _frames(2, hero, start)
	_check("its blow takes a share of his gold", purse.gold < 100 and gob.carried_gold == 100 - purse.gold,
			"he has %d, it %d" % [purse.gold, gob.carried_gold])
	var gap0 := gob._distance_to(hero)
	await _frames(90, hero, start)
	var gap1 := gob._distance_to(hero)
	_check("and it runs off with it", gap1 > gap0 + 3.0, "%.1f -> %.1f m" % [gap0, gap1])
	var carried := gob.carried_gold
	gob.health = 1.0
	gob._receive(50.0, gob.global_position + Vector3.UP, Vector3.FORWARD, hero)
	await _frames(40, hero, start)
	var most := 0
	for p: Coins in _piles(world):
		most = maxi(most, p.amount)
	_check("cut down, it drops what it took", most >= carried, "%d dropped, %d taken" % [most, carried])
	await _done(world)


## Alone, it keeps off and throws, and what it throws reaches him.
func _alone_throws() -> void:
	var a: Array = await _arena()
	var world: World = a[0]
	var hero: Player = a[2]
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)
	var start := hero.global_position
	var gob := (a[1] as ArenaPanel).call_up(GOBLIN, false, _ahead(hero, 8.0)) as GoblinFighter
	gob.bomb_chance = 0.0
	var thrown := 0
	var serial := -1
	var closest := 99.0
	for f in 600:
		await physics_frame
		_hold(hero, start)
		var to := gob.global_position - hero.global_position
		hero.rotation.y = atan2(-to.x, -to.z)
		if f > 60:
			closest = minf(closest, gob._distance_to(hero))
		if gob.act_serial != serial:
			serial = gob.act_serial
			if gob.act == GoblinFighter.THROW:
				thrown += 1
	_check("alone, it throws at him", thrown >= 2, "%d throws in 10 s" % thrown)
	_check("and the stones reach him", struck[0] >= 1, "%d struck" % struck[0])
	_check("and it keeps off him", closest > gob.cornered, "closest %.1f m" % closest)
	# A bomb: thrown, it lands and bursts by him.
	gob.bomb_chance = 1.0
	gob._throw_wait = 0.0
	var s0: int = struck[0]
	var burst := false
	for f in 360:
		await physics_frame
		_hold(hero, start)
		if struck[0] > s0:
			burst = true
			break
	_check("its bomb bursts by him and he feels it", burst)
	await _done(world)


## With another goblin by it, it goes round to his back.
func _flank() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var start := hero.global_position
	var g1 := (a[1] as ArenaPanel).call_up(GOBLIN, false, _ahead(hero, 4.0, -0.6)) as GoblinFighter
	var g2 := (a[1] as ArenaPanel).call_up(GOBLIN, false, _ahead(hero, 4.0, 0.6)) as GoblinFighter
	for g: GoblinFighter in [g1, g2]:
		g._throw_wait = 99.0
	var facing := hero.rotation.y
	var behind := false
	for f in 240:
		await physics_frame
		_hold(hero, start)
		hero.rotation.y = facing
		for g: GoblinFighter in [g1, g2]:
			g._throw_wait = 99.0
			if g._quarry != null and g._behind_him():
				behind = true
	_check("with another by it, a goblin gets round to his back", behind)
	await _done(a[0])


## Hurt, it runs and shrieks; a goblin off on its own comes at the shriek.
func _cowardice() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var start := hero.global_position
	var gob := (a[1] as ArenaPanel).call_up(GOBLIN, false, _ahead(hero, 3.0)) as GoblinFighter
	var far := (a[1] as ArenaPanel).call_up(GOBLIN, false, _ahead(hero, 22.0, 8.0)) as GoblinFighter
	far.sight_range = 0.0
	await _frames(20, hero, start)
	gob._rouse(hero)
	gob._throw_wait = 99.0
	gob.health = gob.max_health * 0.3
	var called := false
	var gap0 := gob._distance_to(hero)
	var top := gap0
	for f in 300:
		await physics_frame
		_hold(hero, start)
		gob._throw_wait = 99.0
		top = maxf(top, gob._distance_to(hero))
		if gob.act == GoblinFighter.CALL:
			called = true
	_check("hurt, it runs from him", top > gap0 + 3.0, "%.1f -> %.1f m" % [gap0, top])
	_check("and shrieks", called)
	_check("and the other comes at the shriek", far.mode == Fighter.Mode.CHASE or far.mode == Fighter.Mode.FIGHT,
			"mode %d" % far.mode)
	await _done(a[0])


## The ghoul's claws leave poison in him, and it eats at his health.
func _poison() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var start := hero.global_position
	(a[1] as ArenaPanel)._unhurt = false
	var ghoul := (a[1] as ArenaPanel).call_up(GHOUL, false, _ahead(hero, 6.0)) as GhoulFighter
	ghoul.sight_range = 0.0
	await _frames(10, hero, start)
	var poison := HeroPoison.of(hero)
	ghoul._blow_reached(hero, 0)
	await _frames(2, hero, start)
	_check("its claws poison him", poison != null and poison.stacks.size() == 1)
	var h0 := hero.health
	await _frames(120, hero, start)
	_check("and the poison eats at him", hero.health < h0 - 2.0, "%.0f -> %.0f" % [h0, hero.health])
	await _frames(int(ghoul.poison_time * 60.0), hero, start)
	_check("and wears off", not poison.poisoned())
	await _done(a[0])


## Cut deep, it screams and is in a frenzy: quicker, and a blow no longer
## knocks it about.
func _frenzy() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var start := hero.global_position
	var ghoul := (a[1] as ArenaPanel).call_up(GHOUL, false, _ahead(hero, 5.0)) as GhoulFighter
	await _frames(10, hero, start)
	var pace := ghoul.chase_speed
	ghoul._rouse(hero)
	ghoul.health = ghoul.max_health * 0.4
	var screamed := false
	for f in 180:
		await physics_frame
		_hold(hero, start)
		if ghoul.act == GhoulFighter.SCREAM:
			screamed = true
		if ghoul.frenzied:
			break
	_check("cut deep, it screams", screamed)
	_check("and is in a frenzy, quicker", ghoul.frenzied and ghoul.chase_speed > pace * 1.1,
			"%.1f -> %.1f m/s" % [pace, ghoul.chase_speed])
	ghoul._start(Fighter.Act.NONE)
	ghoul.react(&"knock", hero)
	_check("a knock no longer throws it", ghoul.act != Fighter.Act.REACT_KNOCK)
	await _done(a[0])


## Left alone by a corpse it feeds, and is healed by it.
func _feeding() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var start := hero.global_position
	var orc := (a[1] as ArenaPanel).call_up(ORC, false, _ahead(hero, 14.0, 4.0)) as Fighter
	orc.sight_range = 0.0
	await _frames(10, hero, start)
	orc.health = 1.0
	orc._receive(50.0, orc.global_position + Vector3.UP, Vector3.FORWARD, null)
	var ghoul := (a[1] as ArenaPanel).call_up(GHOUL, false, _ahead(hero, 14.0, -3.0)) as GhoulFighter
	ghoul.sight_range = 0.0
	await _frames(10, hero, start)
	ghoul.health = ghoul.max_health * 0.5
	var fed := false
	for f in 420:
		await physics_frame
		_hold(hero, start)
		if ghoul.act == GhoulFighter.FEED:
			fed = true
	_check("left alone by a corpse, it feeds", fed)
	_check("and is healed by it", ghoul.health > ghoul.max_health * 0.7,
			"%.0f of %.0f" % [ghoul.health, ghoul.max_health])
	_check("the corpse kept while it fed", is_instance_valid(orc), "")
	await _done(a[0])
