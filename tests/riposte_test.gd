extends SceneTree
## The critical on a big one down on its knee (the user's pick, 2026-10-10,
## Elden Ring's): its stance broken, the attack before it is the critical —
## he is put before it, leaps and drives the blade in; it is a critical, worth
## far more than a cut, he takes nothing through it, and it gets up after.
## Behind it, or too far off, the attack is a plain cut.
##   Godot --headless --path . --script res://tests/riposte_test.gd [-- <hero>]

const OGRE := "res://scenes/enemies/pack/ogre.tscn"

var _failures := 0
var _world: World
var _panel: ArenaPanel
var _hero: Player


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _arena(hero: StringName) -> void:
	if _world != null:
		_world.queue_free()
		for i in 3:
			await process_frame
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", hero)
	_world = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(_world)
	for i in 30:
		await physics_frame
	_panel = _world.get_node("ArenaPanel") as ArenaPanel
	_panel._clear()
	_panel._wait_for_blow = false
	_hero = _world.player()
	_hero.immortal = true
	_hero.call(&"_set_weapons_stowed", false)
	for i in 20:
		await physics_frame


func _kneeling(off: float, behind: bool) -> OgreFighter:
	var ahead := -_hero.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var ogre := _panel.call_up(OGRE, false, _hero.global_position + ahead * off) as OgreFighter
	ogre.sight_range = 0.0
	ogre.max_health = 99999.0
	ogre.health = 99999.0
	await physics_frame
	ogre.global_position = _hero.global_position + ahead * off
	var to := _hero.global_position - ogre.global_position
	if behind:
		to = -to
	ogre.rotation.y = atan2(-to.x, -to.z)
	ogre._break_stance()
	for i in 20:
		await physics_frame
	return ogre


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var heroes: Array = [&"tariel", &"warrior", &"rogue"] if args.is_empty() else [StringName(args[0])]
	print("riposte_test")
	for hero: StringName in heroes:
		await _arena(hero)
		var ogre := await _kneeling(2.6, false)
		var was := ogre.health
		var hp := _hero.health
		_check("%s: down on its knee, open" % hero, ogre.crit_open(), "act %d" % ogre.act)
		_hero.call(&"_attack")
		var put := false
		for i in 60 * 2:
			await physics_frame
			if i == 30:
				var gap := _hero.global_position - ogre.crit_spot()
				gap.y = 0.0
				put = gap.length() < 0.3
			# a blow at him through it does nothing
			if i == 20:
				_hero.receive_blow(30.0, ogre, 0, 1, 5)
		_check("%s: the attack is the critical" % hero, _hero.crits_dealt == 1 and ogre.crits_taken == 1,
				"%d dealt, %d taken" % [_hero.crits_dealt, ogre.crits_taken])
		_check("%s: put before it" % hero, put, "")
		# a plain cut's worth (its own critical rolls aside: the least of a few)
		var cut := INF
		for n in 8:
			cut = minf(cut, float(_hero.cut_worth(ogre)[0]))
		_check("%s: worth far more than a cut" % hero, was - ogre.health > cut * 2.5,
				"%.0f vs a cut %.0f" % [was - ogre.health, cut])
		_check("%s: nothing landed on him through it" % hero, is_equal_approx(_hero.health, hp),
				"%.0f -> %.0f" % [hp, _hero.health])
		for i in 60 * 3:
			await physics_frame
		_check("%s: it gets up after" % hero, ogre.act != PackBrute.STANCE, "act %d" % ogre.act)
		ogre.queue_free()
		# behind it: a plain cut
		await _arena(hero)
		var back := await _kneeling(2.6, true)
		_hero.call(&"_attack")
		for i in 40:
			await physics_frame
		_check("%s: behind it, no critical" % hero, _hero.crits_dealt == 0, "%d" % _hero.crits_dealt)
		back.queue_free()
	print("riposte_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
