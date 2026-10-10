extends SceneTree
## The troll's, the golem's and the orc's combos made by hand ([PackBrute]
## `_hand_combos`, 2026-10-10): each runs its moves in order on a hero in front,
## its blows land, only its felling blow throws him down; enraged, a combo
## with a tail runs on; and left to its own mind, it opens them.
##   Godot --headless --path . --script res://tests/brute_combo_test.gd

const KINDS := {
	&"troll": "res://scenes/enemies/pack/troll.tscn",
	&"golem": "res://scenes/enemies/pack/golem.tscn",
	&"orc": "res://scenes/enemies/pack/orc.tscn",
}

var _failures := 0
var _world: World
var _panel: ArenaPanel
var _hero: Player
var _hits: Array = []
var _f := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _arena() -> void:
	if _world != null:
		_world.queue_free()
		for i in 3:
			await process_frame
	_world = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(_world)
	for i in 30:
		await physics_frame
	_panel = _world.get_node("ArenaPanel") as ArenaPanel
	_panel._clear()
	_panel._wait_for_blow = false
	_hero = _world.player()
	_hero.immortal = true
	_hits = []
	_hero.struck.connect(func(_d: float, _b: bool) -> void:
		_hits.append(_f))


func _brute(path: String, first: int) -> PackBrute:
	var ahead := -_hero.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var b := _panel.call_up(path, false, _hero.global_position + ahead * 3.0) as PackBrute
	b.max_health = 99999.0
	b.health = 99999.0
	b.stance = 0.0
	b.sight_range = 0.0
	b.hand_combo_chance = Vector2.ZERO
	await physics_frame
	var reach := float(b._strike_from.get(first, b.strike_off))
	b.global_position = _hero.global_position + ahead * reach
	var to := _hero.global_position - b.global_position
	b.rotation.y = atan2(-to.x, -to.z)
	b._quarry = _hero
	return b


func _run() -> void:
	(load("res://scripts/hit_feel.gd") as Script).set(&"frame_clock", true)
	print("brute_combo_test")
	for kind: StringName in KINDS:
		await _arena()
		var probe := await _brute(KINDS[kind], -1)
		var combos: Array = probe._hand_combos
		probe.queue_free()
		_check("%s: has combos" % kind, combos.size() >= 2, str(combos.size()))
		for i in combos.size():
			var c: Dictionary = combos[i]
			var moves: Array = c["moves"]
			await _arena()
			var b := await _brute(KINDS[kind], int(moves[0]))
			var at := _hero.global_position
			b.start_hand_combo(i)
			var acts: Array = []
			var down_at := -1
			_f = 0
			while _f < 60 * 9:
				await physics_frame
				_f += 1
				if b.act != Fighter.Act.NONE and (acts.is_empty() or acts[-1] != b.act):
					acts.append(b.act)
				if _hero.state != Player.State.DOWNED and down_at < 0:
					_hero.global_position = Vector3(at.x, _hero.global_position.y, at.z)
				if _hero.state == Player.State.DOWNED and down_at < 0:
					down_at = _f
				if b.act == Fighter.Act.NONE and _f > 60 and (down_at > 0 or acts.size() >= moves.size()):
					break
			var blows := 0
			for m: int in moves:
				blows += b._blow_moments(m).size()
			var name := "%s %s" % [kind, c["name"]]
			_check("%s: its moves in order" % name, acts.slice(0, moves.size()) == moves, "%s vs %s" % [acts, moves])
			_check("%s: its blows found him" % name, _hits.size() >= blows - 1, "%d of %d" % [_hits.size(), blows])
			_check("%s: down by its felling blow" % name, down_at > 0 and not _hits.is_empty() \
					and down_at >= int(_hits[_hits.size() - 1]) - 2, "down at %d, hits %s" % [down_at, _hits])
			b.queue_free()
		# enraged, a tail runs on
		for i in combos.size():
			if (combos[i] as Dictionary).has("rage"):
				await _arena()
				var r := await _brute(KINDS[kind], int((combos[i]["moves"] as Array)[0]))
				r.raging = true
				r.start_hand_combo(i)
				_check("%s: enraged, it runs longer" % kind,
						r._hand_moves.size() == (combos[i]["moves"] as Array).size() + (combos[i]["rage"] as Array).size(),
						str(r._hand_moves))
				r.queue_free()
				break
		# its own mind opens them
		await _arena()
		var m := await _brute(KINDS[kind], int((combos[0]["moves"] as Array)[0]))
		m.hand_combo_chance = Vector2(1.0, 1.0)
		m.sight_range = 30.0
		var at2 := _hero.global_position
		for i in 60 * 12:
			await physics_frame
			if _hero.state != Player.State.DOWNED:
				_hero.global_position = Vector3(at2.x, _hero.global_position.y, at2.z)
		_check("%s: left to itself, it opens its combos" % kind, m.hand_combos_made.size() >= 1, str(m.hand_combos_made))
		m.queue_free()
	print("brute_combo_test: %s" % ("All checks passed." if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
