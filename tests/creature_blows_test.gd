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
const SLOW := ["ogre", "golem", "zombie_m", "zombie_f"]

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
	for kind: String in kinds:
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
