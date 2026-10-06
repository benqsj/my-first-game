extends SceneTree

## The pack's fighting creatures hit what they swing at: in the test arena,
## a hero who stands still is struck by every attack each of them makes, and
## while he keeps cutting at it, it keeps coming (no long pauses, no swing
## dropped halfway). Counts only the attacks that ran their length.
##
##   godot --headless --path . --script res://tests/creature_blows_test.gd

const KINDS := ["skeleton", "skeleton_warrior", "orc", "goblin", "ogre", "troll", "ghoul", "golem",
		"zombie_m", "zombie_f"]
const SECONDS := 14.0
## (and the ghoul, which darts off after its swings and leaps in again)
const SLOW := ["ogre", "golem", "zombie_m", "zombie_f", "ghoul"]
## The archer: from afar it stands and every arrow strikes him; when he
## comes at it, it runs, turns, shoots and runs again.
const ARCHER := "skeleton_archer"
## The mage: from afar its bolts and bursts strike a hero standing still and
## it raises the dead; up close it blasts him off.
const MAGE := "skeleton_mage"

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# `-- orc ghoul` tries only those.
	var kinds: Array = Array(OS.get_cmdline_user_args()) if not OS.get_cmdline_user_args().is_empty() else KINDS
	if OS.get_cmdline_user_args().is_empty():
		kinds.append(ARCHER)
		kinds.append(MAGE)
	for kind: String in kinds:
		if kind == MAGE:
			for close in [false, true]:
				await _mage(close)
			continue
		if kind == ARCHER:
			for chase in [false, true]:
				await _archer(chase)
			continue
		for spam in [false, true]:
			await _duel(kind, spam)
	Input.action_release("attack")
	print("creature_blows_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _duel(kind: String, spam: bool) -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)
	await physics_frame
	var body := panel.call_up("res://scenes/enemies/pack/%s.tscn" % kind) as Brawler
	await physics_frame
	body.max_health = 99999.0
	body.health = 99999.0
	var start := hero.global_position
	var serial := -1
	var expected := 0
	var landed := 0
	var attacks := 0
	var s0 := 0
	var blows := 0
	for f in int(SECONDS * 60.0):
		await physics_frame
		hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		var to := body.global_position - hero.global_position
		hero.rotation.y = atan2(-to.x, -to.z)
		if spam:
			if f % 24 == 0:
				Input.action_press("attack")
			elif f % 24 == 3:
				Input.action_release("attack")
		if body.act_serial != serial:
			if blows > 0:
				expected += blows
				landed += mini(struck[0] - s0, blows)
			serial = body.act_serial
			blows = 0
			if body._strikes().has(body.act):
				attacks += 1
				blows = body._blow_moments(body.act).size()
				s0 = struck[0]
	Input.action_release("attack")
	var how := "while he cuts at it" if spam else "standing still"
	_check("%s, %s: every blow lands" % [kind, how], expected > 0 and landed == expected, "%d of %d" % [landed, expected])
	# The slow and heavy ones (an ogre, a golem, a shambling zombie) less often.
	var least := int(SECONDS / 3.0) if kind in SLOW else int(SECONDS / 2.0)
	_check("%s, %s: it keeps attacking" % [kind, how], attacks >= least, "%d attacks in %.0f s" % [attacks, SECONDS])
	world.queue_free()
	for i in 3:
		await process_frame


func _archer(chase: bool) -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	var struck := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void: struck[0] += 1)
	await physics_frame
	var start := hero.global_position
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var body := panel.call_up("res://scenes/enemies/pack/%s.tscn" % ARCHER, false,
			start + fwd * (9.0 if chase else 15.0)) as BowFighter
	var at := body.global_position
	var serial := -1
	var shots := 0
	var fled := 0
	var was_fleeing := false
	var moved := 0.0
	var hero_at := start
	for f in int(SECONDS * 60.0):
		await physics_frame
		if chase:
			var to := body.global_position - hero_at
			to.y = 0.0
			if to.length() > 2.0:
				hero_at += to.normalized() * 4.0 / 60.0
		hero.global_position = Vector3(hero_at.x, hero.global_position.y, hero_at.z)
		var face := body.global_position - hero.global_position
		hero.rotation.y = atan2(-face.x, -face.z)
		moved = maxf(moved, body.global_position.distance_to(at))
		if body._flee_left > 0.0 and not was_fleeing:
			fled += 1
		was_fleeing = body._flee_left > 0.0
		if body.act_serial != serial:
			serial = body.act_serial
			if body.act == BowFighter.SHOT:
				shots += 1
	# The last shot may still be in the air.
	for i in 40:
		await physics_frame
	if chase:
		_check("archer, he comes at it: it runs, turns and shoots, again and again", fled >= 3 and shots >= 3,
				"%d runs, %d shots" % [fled, shots])
		_check("archer, he comes at it: its arrows strike him", struck[0] >= shots - 1 and struck[0] > 0,
				"%d of %d" % [struck[0], shots])
	else:
		_check("archer, from afar: it stands and shoots", moved < 0.5 and shots >= 5,
				"%d shots, moved %.1f m" % [shots, moved])
		_check("archer, from afar: every arrow strikes him", struck[0] == shots, "%d of %d" % [struck[0], shots])
	world.queue_free()
	for i in 3:
		await process_frame


func _mage(close: bool) -> void:
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var panel := world.get_node("ArenaPanel") as ArenaPanel
	panel._clear()
	panel._wait_for_blow = false
	var hero := world.player()
	hero.immortal = true
	await physics_frame
	var start := hero.global_position
	var fwd := -hero.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var body := panel.call_up("res://scenes/enemies/pack/%s.tscn" % MAGE, false,
			start + fwd * (2.4 if close else 11.0)) as MageFighter
	var landed := {}
	var current := [0]
	hero.struck.connect(func(_d: float, _b: bool) -> void:
		landed[current[0]] = int(landed.get(current[0], 0)) + 1)
	var serial := -1
	var casts := {}
	for f in int(SECONDS * 60.0):
		await physics_frame
		if not close:
			hero.global_position = Vector3(start.x, hero.global_position.y, start.z)
		var face := body.global_position - hero.global_position
		hero.rotation.y = atan2(-face.x, -face.z)
		if body.act_serial != serial:
			serial = body.act_serial
			if MageFighter.SPELLS.has(body.act):
				casts[body.act] = int(casts.get(body.act, 0)) + 1
				current[0] = body.act
	for i in 90:
		await physics_frame
	if close:
		_check("mage, up close: it blasts him off", int(casts.get(MageFighter.BLAST, 0)) >= 1
				and int(landed.get(MageFighter.BLAST, 0)) >= 1, "%s cast, %s landed" % [casts, landed])
	else:
		_check("mage, from afar: bolts and bursts, and every one strikes him standing still",
				int(casts.get(MageFighter.BOLT, 0)) + int(casts.get(MageFighter.HEX, 0)) >= 3
				and int(landed.get(MageFighter.BOLT, 0)) >= int(casts.get(MageFighter.BOLT, 0)) - 1
				and int(landed.get(MageFighter.HEX, 0)) >= int(casts.get(MageFighter.HEX, 0)) - 1,
				"%s cast, %s landed" % [casts, landed])
		_check("mage, from afar: it raises the dead", body._standing_raised() >= 1, "%d standing" % body._standing_raised())
	world.queue_free()
	for i in 3:
		await process_frame
