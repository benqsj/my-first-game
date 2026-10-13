extends SceneTree
## The orc made over (2026-10-13, the user's word: polish it, combos, half
## again as tall as a man, skills): its size; its eight combos; the lunge from
## off; the war cry that emboldens its kin; the shoulder charge; the thrown
## axe; a band taking turns, no more than two on him at once; a flask punished;
## its stance broken; enraged, a second blade.
##   Godot --headless --path . --script res://tests/orc_test.gd

const ORC := "res://scenes/enemies/pack/orc.tscn"

var _failures := 0
var _world: World
var _panel: ArenaPanel
var _hero: Player
var _hits := 0
var _falls := 0
var _was_down := false


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
	_hero.max_health = 99999.0
	_hero.health = 99999.0
	_hits = 0
	_falls = 0
	_was_down = false
	_hero.struck.connect(func(_d: float, _b: bool) -> void:
		_hits += 1)


func _ahead(off: float, aside: float = 0.0) -> Vector3:
	var f := -_hero.global_basis.z
	f.y = 0.0
	f = f.normalized()
	return _hero.global_position + f * off + f.cross(Vector3.UP) * aside


func _orc(off: float, aside: float = 0.0) -> OrcFighter:
	var o := _panel.call_up(ORC, false, _ahead(off, aside)) as OrcFighter
	o.max_health = 99999.0
	o.health = 99999.0
	o._leap_wait = 999.0
	o._lunge_wait = 999.0
	o._cry_wait = 999.0
	o._charge_wait = 999.0
	o._throw_wait = 999.0
	return o


## Runs `frames` physics frames, him held where he stands (unless down).
func _run_for(frames: int, until: Callable = Callable()) -> void:
	var at := _hero.global_position
	for f in frames:
		await physics_frame
		var down := _hero.state == Player.State.DOWNED
		if down and not _was_down:
			_falls += 1
		_was_down = down
		if not down:
			_hero.global_position = Vector3(at.x, _hero.global_position.y, at.z)
		if until.is_valid() and until.call():
			return


func _run() -> void:
	(load("res://scripts/hit_feel.gd") as Script).set(&"frame_clock", true)
	print("orc_test")
	await _size()
	await _lunge()
	await _cry()
	await _charge()
	await _throw()
	await _turns()
	await _punish()
	await _stance()
	await _rage()
	print("orc_test: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _size() -> void:
	await _arena()
	var o := _orc(4.0)
	await _run_for(10)
	var sk := o._skeleton
	var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("head_joint"))
	var tall := head.origin.y - o.global_position.y
	_check("half again as tall as a man (head ~2.7 m)", tall > 2.5 and tall < 3.0, "%.2f m" % tall)
	_check("eight combos made by hand", o._hand_combos.size() == 8, str(o._hand_combos.size()))
	_check("its flat cuts bent down onto a man", o._stoops.size() >= 3, str(o._stoops))


func _lunge() -> void:
	await _arena()
	var o := _orc(6.5)
	o._lunge_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	await _run_for(180, func() -> bool: return _falls > 0)
	_check("from off it lunges at him and cuts him down", o.lunges_made >= 1 and _falls >= 1,
			"%d lunges, %d falls" % [o.lunges_made, _falls])


func _cry() -> void:
	await _arena()
	var o := _orc(7.0)
	var mate := _orc(12.0, 3.0)
	var far := _orc(40.0, 0.0)
	o._cry_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	var pace := mate.chase_speed
	await _run_for(150, func() -> bool: return o.cries_made > 0)
	await _run_for(5)
	_check("the war cry: it and its kin about emboldened", o.cries_made == 1 and o._bold_left > 0.0 and mate._bold_left > 0.0,
			"%d cries, %.1f / %.1f s" % [o.cries_made, o._bold_left, mate._bold_left])
	_check("quicker for it", mate.chase_speed > pace, "%.1f -> %.1f" % [pace, mate.chase_speed])
	_check("an orc far off is not", far._bold_left <= 0.0)
	_check("harder blows while it lasts", o._blow_worth(OrcFighter.O_S1) > 1.05, str(o._blow_worth(OrcFighter.O_S1)))


func _charge() -> void:
	await _arena()
	var o := _orc(10.5)
	o._charge_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	o.attack_cooldown = Vector2(9.0, 9.0)
	await _run_for(200, func() -> bool: return _falls > 0)
	_check("the shoulder charge: a tell, then it drives him off his feet", o.charges_made >= 1 and o.charge_hits >= 1 and _falls >= 1,
			"%d charges, %d met, %d falls" % [o.charges_made, o.charge_hits, _falls])


func _throw() -> void:
	await _arena()
	var o := _orc(14.0)
	o._throw_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	o.chase_speed = 0.0
	o.close_speed = 0.0
	o.speed = 0.0
	await _run_for(150, func() -> bool: return _hits > 0)
	_check("from far off a thrown axe finds him", o.throws_made >= 1 and _hits >= 1,
			"%d throws, %d hits" % [o.throws_made, _hits])
	_check("and only staggers him", _falls == 0, "%d falls" % _falls)


func _turns() -> void:
	await _arena()
	var orcs: Array = []
	for k in 4:
		var o := _orc(9.0, (float(k) - 1.5) * 3.0)
		o._lunge_wait = 0.0
		o._leap_wait = 0.0
		orcs.append(o)
	var most := 0
	var waited := 0
	var at := _hero.global_position
	for f in 60 * 12:
		await physics_frame
		if _hero.state != Player.State.DOWNED:
			_hero.global_position = Vector3(at.x, _hero.global_position.y, at.z)
		var near := 0
		for o: OrcFighter in orcs:
			if o.act != Fighter.Act.NONE and o._distance_to(_hero) < o.reach + 2.0 and o.act != PackBrute.LEAP \
					and o.act != OrcFighter.O_LUNGE and o.act != OrcFighter.O_THROW and o.act != OrcFighter.O_CRY:
				near += 1
		most = maxi(most, near)
	for o: OrcFighter in orcs:
		if o.turn_waited > 1.0:
			waited += 1
	_check("four orcs on him: no more than two at him at once", most <= 2, "%d at most" % most)
	_check("the rest wait their turn", waited >= 2, "%d waited" % waited)


func _punish() -> void:
	await _arena()
	var o := _orc(6.0)
	o.hand_combo_chance = Vector2.ZERO
	o.attack_cooldown = Vector2(9.0, 9.0)
	await _run_for(5)
	_hero.set(&"_drink_until", float(_hero.call(&"_now")) + 1.2)
	await _run_for(90, func() -> bool: return o.punishes_made > 0)
	await _run_for(2)
	_check("a flask drunk before it is punished at once", o.punishes_made >= 1
			and (o.lunges_made >= 1 or not o.hand_combos_made.is_empty() or o.act != Fighter.Act.NONE),
			"%d punishes, %d lunges, combos %s, act %d" % [o.punishes_made, o.lunges_made, o.hand_combos_made, o.act])


func _stance() -> void:
	await _arena()
	var o := _orc(3.0)
	for k in 8:
		o._add_stance(60.0)
		await _run_for(10)
	await _run_for(30)
	_check("enough heavy blows break its stance", o.stance_breaks >= 1, "%d breaks" % o.stance_breaks)


func _rage() -> void:
	await _arena()
	var o := _orc(5.0)
	o.health = o.max_health * 0.45
	await _run_for(240, func() -> bool: return o.raging)
	await _run_for(10)
	_check("enraged, a second blade in its left hand", o.raging and o._second != null and o._second.visible)
	_check("and the frenzy among its combos", o._combo_named(&"frenzy") >= 0)
