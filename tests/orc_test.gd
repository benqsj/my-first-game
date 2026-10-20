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
	o._drawn = true
	o._taunt_wait = 999.0
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
	await _guard()
	await _bearing()
	await _pace()
	await _skyfall()
	await _kneel_death()
	await _names()
	await _pair()
	await _down_and_trap()
	await _stance()
	await _rage()
	await _arms()
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
	_check("eight combos made by hand, its counter, its trap and its fetch", o._hand_combos.size() == 11, str(o._hand_combos.size()))
	var ogre_clips: Array = []
	for what: int in o._moves_table:
		var clip := String((o._moves_table[what] as Array)[0])
		if clip.begins_with("CR_OG_") or clip in ["CR_Slash1", "CR_Slash3", "CR_Slash4", "CR_SwordDash", "CR_Heavy1",
				"CR_Heavy2", "CR_Heavy3", "CR_Heavy4", "CR_Kick", "CR_LightD", "CR_RegB"]:
			ogre_clips.append(clip)
	_check("none of its moves is the ogre's", ogre_clips.is_empty(), str(ogre_clips))
	_check("a blade in each hand from the first", o._second != null and o._second.visible)
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
	_check("harder blows while it lasts", o._blow_worth(OrcFighter.O_R2) > 1.05, str(o._blow_worth(OrcFighter.O_R2)))


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
	var o := _orc(12.0)
	o._throw_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	o.chase_speed = 0.0
	o.close_speed = 0.0
	o.speed = 0.0
	var t := [-1.0, -1.0, 0.0, true]
	var frame := [0]
	await _run_for(150, func() -> bool:
		frame[0] += 1
		if o.act == OrcFighter.O_THROW and t[0] < 0.0:
			t[0] = frame[0] / 60.0
		if o._thrown != null and o._throw_t < o._throw_flight:
			# how far its length has turned from where it left the hand
			var axis: Vector3 = (o._thrown.global_basis * o._thrown_tip_local).normalized()
			var first: Vector3 = (o._thrown_basis * o._thrown_tip_local).normalized()
			t[2] = maxf(t[2], rad_to_deg(axis.angle_to(first)))
		return _hits > 0)
	# (2026-10-15, the user's word: its own blade thrown, straight, a trail)
	_check("from far off its thrown blade finds him", o.throws_made >= 1 and o.throw_hits >= 1 and _hits >= 1,
			"%d throws, %d hits" % [o.throws_made, o.throw_hits])
	_check("turning end over end as it flies", t[2] > 120.0, "%.0f deg" % t[2])
	_check("and only staggers him", _falls == 0, "%d falls" % _falls)
	var blade_gone := o._held_blade() == null
	var h0 := _hits
	await _run_for(240, func() -> bool:
		frame[0] += 1
		if o.act == OrcFighter.O_FETCH and o._thrown != null and o._throw_t < o._throw_flight:
			t[3] = false
		if o._thrown == null and t[1] < 0.0 and o.fetches_made > 0:
			t[1] = frame[0] / 60.0
		return _hits > h0)
	_check("the blade out of its hand, then back in it", blade_gone and o._held_blade() != null)
	_check("it does not slide off after it till the blade has stopped", t[3] and t[1] > 0.0,
			"%.2f s from the throw to the catch" % (t[1] - t[0]))
	_check("it spins through him with it", o.fetches_made >= 1 and _hits > h0
			and o.hand_combos_made.has(o._combo_named(OrcFighter.FETCH_COMBO)),
			"%d fetches, hits %d -> %d" % [o.fetches_made, h0, _hits])
	# him gone further than `fetch_reach` from the blade: the spin misses
	await _arena()
	o = _orc(12.0)
	o._throw_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	o.attack_cooldown = Vector2(9.0, 9.0)
	o.chase_speed = 0.0
	o.close_speed = 0.0
	o.speed = 0.0
	var gone := false
	var spot := _hero.global_position
	for f in 300:
		await physics_frame
		if o._thrown != null and not gone:
			gone = true
			var side := (o.global_position - spot).cross(Vector3.UP).normalized()
			spot += side * 7.5
		if not gone:
			spot = _hero.global_position
		if _hero.state != Player.State.DOWNED:
			_hero.global_position = Vector3(spot.x, _hero.global_position.y, spot.z)
	var spun := o._spin_serial >= 0
	_check("him further than 5 m off: at the end of its turn it slides at him and the blow lands",
			o.fetches_made >= 1 and o._held_blade() != null and spun and o.throw_hits == 0 and _hits >= 1,
			"%d fetches, spun %s, hits %d, gap %.1f" % [o.fetches_made, spun, _hits, o._distance_to(_hero)])


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
					and o.act != OrcFighter.O_SKY and o.act != OrcFighter.O_SKYDIVE and o.act != OrcFighter.O_FETCH \
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


func _guard() -> void:
	await _arena()
	var o := _orc(3.0)
	o.hand_combo_chance = Vector2.ZERO
	await _run_for(10)
	o._start(Fighter.Act.BLOCK)
	var at := o.global_position + Vector3.UP * 1.5
	var bled := o._receive(20.0, at, Vector3.FORWARD, _hero)
	_check("a cut on its crossed blades is turned aside", not bled and o.parries_made == 1, "bled %s, %d parries" % [bled, o.parries_made])
	_check("and it answers at once with its counter", o.counters_made == 1 and o._hand_combo == o._combo_named(OrcFighter.COUNTER_COMBO),
			"%d counters, combo %d" % [o.counters_made, o._hand_combo])
	await _run_for(90)
	_check("the counter lands on him", _hits >= 1, "%d hits" % _hits)
	# three caught in a row: its guard broken
	var broke := false
	o.stamina = o.max_stamina
	for k in 5:
		o._start(Fighter.Act.BLOCK)
		o._receive(20.0, at, Vector3.FORWARD, _hero)
		if o.act == Fighter.Act.BREAK:
			broke = true
			break
	_check("cut after cut on its guard breaks it open", broke)


func _bearing() -> void:
	await _arena()
	var o := _orc(6.0)
	o._drawn = false
	await _run_for(30)
	_check("first roused, it draws both blades", o.act == OrcFighter.O_DRAW or o._drawn, "act %d" % o.act)
	o._taunt_wait = 0.0
	o.taunt_chance = 1.0
	_hero.state = Player.State.DOWNED
	var seen := false
	for f in 120:
		await physics_frame
		if o.act == OrcFighter.O_TAUNT:
			seen = true
			break
	_hero.state = Player.State.GROUNDED
	_check("him down, it twirls its blades at him", seen and o.taunts_made >= 1, "%d taunts" % o.taunts_made)
	o.rage_at = 0.0
	o.health = o.max_health * 0.15
	o._wary_wait = 0.0
	var backed := false
	var d0 := o._distance_to(_hero)
	for f in 300:
		await physics_frame
		if o.wary_made > 0:
			backed = true
	_check("badly hurt and alone, it backs off a while", backed, "%.1f -> %.1f m" % [d0, o._distance_to(_hero)])


## 2026-10-14 (the user's word): heavy swings seen coming, fast down; a breath
## between combos; the two-bladed thrust fells at once; no leaping in.
func _pace() -> void:
	await _arena()
	var o := _orc(3.0)
	o.hand_combo_chance = Vector2.ZERO
	await _run_for(10)
	var first := o._blow_moments(OrcFighter.O_L2)[0]
	_check("a cut wound up long enough to see", first >= o.windup_least - 0.06, "%.2f s" % first)
	# three paces (claude/orc_quality_plan.md phase 1): slow up, quick
	# through him, heavy after — the clip's own rate against each
	var rate := float((o._moves_table[OrcFighter.O_L2] as Array)[1])
	var length := o._move_length(OrcFighter.O_L2)
	var pace := func(t: float) -> float:
		return (o._clip_time(OrcFighter.O_L2, t + 0.01) - o._clip_time(OrcFighter.O_L2, t - 0.01)) / 0.02 / rate
	var up: float = pace.call(first * 0.3)
	var cut: float = pace.call(first)
	var after: float = pace.call((first + length) * 0.5 + 0.1)
	_check("and coming down faster than its clip", cut > 1.2 and up < 1.0,
			"up %.2f, cut %.2f" % [up, cut])
	_check("its follow-through heavy, slower than its clip", after < 0.95, "%.2f" % after)
	_check("it turns hard after him, then is locked before the blow",
			o._track_rate(OrcFighter.O_L2) > o.turn_speed * 0.5 and o._track_lock(OrcFighter.O_L2) >= 0.25,
			"%.2f, %.2f s" % [o._track_rate(OrcFighter.O_L2), o._track_lock(OrcFighter.O_L2)])
	o.start_hand_combo(o._combo_named(&"kick_cut"))
	var fell_at := -1.0
	var dw_at := -1.0
	var t := 0.0
	while o._hand_combo >= 0 and t < 8.0:
		await physics_frame
		t += 1.0 / 60.0
		if o.act == OrcFighter.O_DW1 and dw_at < 0.0:
			dw_at = t + o._blow_moments(OrcFighter.O_DW1)[0]
		if _hero.state == Player.State.DOWNED and fell_at < 0.0:
			fell_at = t
	_check("a breath after its combo before the next", o._cooldown >= o.combo_rest.x - 0.1, "%.2f s" % o._cooldown)
	_check("the two-bladed thrust throws him down as it lands", fell_at > 0.0 and absf(fell_at - dw_at) < 0.35,
			"blow %.2f, down %.2f" % [dw_at, fell_at])
	_check("its far opening slides in, no leap", OrcFighter.O_LUNGE == OrcFighter.O_LOW and o.leap_cooldown >= 30.0)


## A pair: one at him, the other off, watching and throwing, in now and then.
func _pair() -> void:
	await _arena()
	var a := _orc(5.0, -2.0)
	var b := _orc(5.0, 2.0)
	for o: OrcFighter in [a, b]:
		o._throw_wait = 2.0
		o._lunge_wait = 3.0
		o._join_wait = 6.0
	var both := 0
	var one := 0
	var at := _hero.global_position
	for f in 60 * 16:
		await physics_frame
		if _hero.state != Player.State.DOWNED:
			_hero.global_position = Vector3(at.x, _hero.global_position.y, at.z)
		var on := 0
		for o: OrcFighter in [a, b]:
			if o.act != Fighter.Act.NONE and o._distance_to(_hero) < o.reach + 2.0 and o.act != OrcFighter.O_THROW:
				on += 1
		if on == 2:
			both += 1
		elif on == 1:
			one += 1
	_check("a pair: mostly one at him at a time", both < one / 3 + 1, "%d frames both, %d one" % [both, one])
	_check("and comes in now and then", a.joins_made + b.joins_made >= 1, "%d" % (a.joins_made + b.joins_made))


## 2026-10-14 (the user's word): him down, it does not wait for him to get
## up; struck at in its taunt it was waiting for it — out of the way and the
## heavy blow back; its blows hurt.
func _down_and_trap() -> void:
	await _arena()
	var o := _orc(3.0)
	o.hand_combo_chance = Vector2.ZERO
	o.stab_chance = 1.0
	o.taunt_chance = 0.0
	await _run_for(10)
	var foe := Node3D.new()
	_world.add_child(foe)
	foe.global_position = o.global_position
	_hero.receive_blow(5.0, foe, 0, 1, 77)
	_hero.down_time = 6.0
	await _run_for(3)
	_hero.set(&"_down_timer", 6.0)
	var hits0 := _hits
	await _run_for(240, func() -> bool: return _hits > hits0)
	_check("him down, it drives a blade down into him", o.stabs_made >= 1 and _hits > hits0,
			"%d stabs, %d hits" % [o.stabs_made, _hits - hits0])
	_hero.set(&"_down_timer", 0.0)
	await _arena()
	o = _orc(3.0)
	o.hand_combo_chance = Vector2.ZERO
	await _run_for(10)
	o._begin(OrcFighter.O_TAUNT)
	await _run_for(10)
	o._answer_swing(_hero)
	await _run_for(150, func() -> bool: return _falls > 0)
	_check("struck at in its taunt: out of the way and the heavy blow back", o.traps_sprung == 1 and _falls >= 1,
			"%d traps, %d falls" % [o.traps_sprung, _falls])
	_check("its blows hurt (60)", o.hit_damage >= 55.0, "%.0f" % o.hit_damage)


## Our weapons and gear on it (2026-10-14): a great axe in both hands, the
## warlord's pieces, and its blows still land with it.
func _arms() -> void:
	await _arena()
	var o := _panel.call_up(ORC, false, _ahead(3.5), {"arm_right": "greataxe", "arm_style": "black",
			"outfit": "Warlord", "cape": "Crimson cape"}) as OrcFighter
	o.max_health = 99999.0
	o.health = 99999.0
	for w in ["_leap_wait", "_lunge_wait", "_cry_wait", "_charge_wait", "_throw_wait", "_taunt_wait"]:
		o.set(w, 999.0)
	o._drawn = true
	var own := o.body.find_child("Orc_Sword", true, false) as MeshInstance3D
	var arm := o.body.find_child("Arm_ps_w_aw_greataxe_obsidian", true, false) as MeshInstance3D
	_check("the great axe in its hands, its falchion put away", arm != null and own != null and not own.visible)
	_check("and its left hand empty for it", o.arm_left == "none" and (o._second == null or not o._second.visible))
	_check("its reach the axe's", o.weapon_tip.x > 0.9 and o.weapon_tip.x < 1.6, str(o.weapon_tip))
	var worn := o.body.find_children("Wear_*", "MeshInstance3D", true, false)
	_check("the warlord's pieces worn", worn.size() == 3, str(worn.size()))
	_check("held as a great weapon: on its shoulder at rest, its own strings",
			o.grip == &"heavy" and o.idle_clip == &"CR_Shoulder" and o._combo_named(&"cleave") >= 0,
			"%s %s" % [o.grip, o.idle_clip])
	# the figure's weapon bone (weapon_r) is not the orc's: bound where it
	# hangs, under the right hand, not dropped to the hips
	var hips := 0
	for i in arm.skin.get_bind_count():
		hips += 1 if String(arm.skin.get_bind_name(i)) == "pelvis_joint" else 0
	_check("the axe in its hand, not at its hips", hips == 1, "%d bound to the pelvis" % hips)
	await _run_for(600, func() -> bool: return _hits > 0 or _falls > 0)
	_check("and its blows land with it", _hits > 0 or _falls > 0, "%d hits, %d falls" % [_hits, _falls])
	# a spear
	await _arena()
	var p := _panel.call_up(ORC, false, _ahead(4.0), {"arm_right": "spear"}) as OrcFighter
	p.max_health = 99999.0
	p.health = 99999.0
	for w in ["_leap_wait", "_lunge_wait", "_cry_wait", "_charge_wait", "_throw_wait", "_taunt_wait"]:
		p.set(w, 999.0)
	p._drawn = true
	_check("a spear held as a polearm", p.grip == &"pole" and p._combo_named(&"thrusts") >= 0, str(p.grip))
	await _run_for(600, func() -> bool: return _hits > 0 or _falls > 0)
	_check("and its thrusts land", _hits > 0 or _falls > 0, "%d hits, %d falls" % [_hits, _falls])
	# the board's second panel: the orc shown, not in the world's fight
	_panel._orc_pick = [0, 4, 0, 0, 4, 1]
	_panel._preview_orc()
	for i in 5:
		await process_frame
	var shown := _panel._preview._shown
	_check("the board shows the orc picked before it is called up", shown is OrcFighter
			and (shown as OrcFighter).arm_right == "greatsword" and not shown.is_in_group(&"enemy")
			and shown.process_mode == Node.PROCESS_MODE_DISABLED)
	_panel._preview.clear()


## 2026-10-15 (the user's word): up 20-30 m, hanging there 2-3 s, down feet
## first on him, the ground broken.
func _skyfall() -> void:
	await _arena()
	var o := _orc(12.0)
	o._leap_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	var ground := o.global_position.y
	var seen := [0.0, 0.0, 0.0, false]
	await _run_for(60 * 8, func() -> bool:
		var up := o.global_position.y - ground
		if up > seen[0]:
			seen[0] = up
			seen[2] = Vector2(o.global_position.x - _hero.global_position.x, o.global_position.z - _hero.global_position.z).length()
		if up > 8.0:
			seen[1] += 1.0 / 60.0
		if o.act == OrcFighter.O_SKYDIVE:
			seen[3] = true
		return seen[3] and o.act != OrcFighter.O_SKYDIVE)
	var top: float = seen[0]
	_check("it goes up high", o.skyfalls_made >= 1 and top >= 10.0 and top <= 16.0, "%.1f m" % top)
	_check("out in front of him the way it came, to be seen", seen[2] >= 18.0 and seen[2] <= 30.0, "%.1f m off" % seen[2])
	_check("and hangs there ~2 s", seen[1] >= 1.8 and seen[1] <= 3.6, "%.2f s above 8 m" % seen[1])
	_check("down blade first on him, fast: crushed, off his feet", o.sky_hits >= 1 and _falls >= 1,
			"%d hits, %d falls" % [o.sky_hits, _falls])
	_check("back on the ground, upright", absf(o.global_position.y - ground) < 0.6 and not o._sky_tilted,
			"%.2f" % (o.global_position.y - ground))
	# running from it does not save him (the user's word, 2026-10-15)
	await _arena()
	o = _orc(12.0)
	o._leap_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	var spot := _hero.global_position
	var side := (o.global_position - spot).cross(Vector3.UP).normalized()
	var ran := 0.0
	for f in 60 * 7:
		await physics_frame
		if o.act == OrcFighter.O_SKYDIVE and _hero.state != Player.State.DOWNED:
			spot += side * 6.0 / 60.0
			ran += 6.0 / 60.0
		if _hero.state != Player.State.DOWNED:
			_hero.global_position = Vector3(spot.x, _hero.global_position.y, spot.z)
		if o._sky_landed and o.act != OrcFighter.O_SKYDIVE:
			break
	_check("running from it does not save him", o.sky_hits >= 1, "ran %.1f m, %d hits" % [ran, o.sky_hits])
	# a dodge at the moment does
	await _arena()
	o = _orc(12.0)
	o._leap_wait = 0.0
	o.hand_combo_chance = Vector2.ZERO
	var dodged := false
	for f in 60 * 7:
		await physics_frame
		if not dodged and o.act == OrcFighter.O_SKYDIVE and o._act_time >= o.sky_hang - 0.02:
			dodged = true
			_hero.set("_safe_until", Time.get_ticks_msec() / 1000.0 + 0.45)
		if o._sky_landed and o.act != OrcFighter.O_SKYDIVE:
			break
	_check("a dodge as it comes down does", dodged and o.sky_hits == 0, "%d hits" % o.sky_hits)


## 2026-10-15 (the user's word): no fall — down on its knees, out of reach,
## then it breaks into shards out of its own body (2026-10-20: lit up first).
func _kneel_death() -> void:
	await _arena()
	var o := _orc(5.0)
	o.hand_combo_chance = Vector2.ZERO
	await _run_for(20)
	var head := o._skeleton.find_bone("head_joint")
	var stood := (o._skeleton.global_transform * o._skeleton.get_bone_global_pose(head).origin).y - o.global_position.y
	o._die()
	await _run_for(int(60 * (o.kneel_at / o.kneel_rate + 0.3)))
	var knelt := (o._skeleton.global_transform * o._skeleton.get_bone_global_pose(head).origin).y - o.global_position.y
	_check("killed, it goes down on its knees, not over", knelt < stood * 0.85 and knelt > stood * 0.4,
			"head %.2f -> %.2f m" % [stood, knelt])
	_check("and nothing bumps into it", o.collision_layer == 0)
	var at := o.global_position
	await _run_for(int(60 * (o.kneel_for - o.kneel_at / o.kneel_rate)) + 6 + int(60 * DeathShatter.GLOW_TIME * 0.5))
	# (2026-10-20, the user's word) lit up first
	var lit := false
	if is_instance_valid(o) and o.body != null:
		for g in o.body.find_children("*", "GeometryInstance3D", true, false):
			lit = lit or (g as GeometryInstance3D).material_overlay != null
	_check("it lights up before it breaks", lit)
	await _run_for(int(60 * DeathShatter.GLOW_TIME * 0.5) + 6)
	var shards: Node3D = null
	for n in _world.find_children("DeathShatter*", "Node3D", true, false):
		shards = n
	var gone := not is_instance_valid(o) or not o.body.visible
	var from := -1.0
	if shards != null:
		for p in shards.find_children("*", "GPUParticles3D", true, false):
			from = Vector2((p as Node3D).global_position.x - at.x, (p as Node3D).global_position.z - at.z).length()
	_check("then it is gone, its shards out of its body where it knelt", gone and shards != null and from >= 0.0 and from < 1.5,
			"shards %s, %.2f m from it" % [shards != null, from])


## 2026-10-15: what the arena's four are called.
func _names() -> void:
	var titles := []
	for o: Array in ArenaPanel.ARENA_ORCS:
		titles.append(String((o[3] as Dictionary).get("title", "")))
	_check("two Warrior Orcs, the Orc Lord, the raider", titles == ["Warrior Orc", "Warrior Orc", "Orc Lord", "Orc Raider"],
			str(titles))
	var lord: Dictionary = ArenaPanel.ARENA_ORCS[2][3]
	_check("the lord bare-headed, its great sword black", lord.get("arm_style") == "black" and lord.get("hair", "") == ""
			and not str(OrcFighter.OUTFITS[lord.get("outfit")]["pieces"]).contains("hat"))
	_check("the warriors' swords bone", ArenaPanel.ARENA_ORCS[0][3]["arm_style"] == "bone"
			and ArenaPanel.ARENA_ORCS[1][3]["arm_style"] == "bone")
