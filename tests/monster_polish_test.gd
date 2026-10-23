extends SceneTree

## The minotaur and the butcher made over (2026-10-22, monster_polish_plan.md
## sessions 1-2), in the test arena:
##
## * the minotaur: a [PackBrute] now (a stance, a rage), its blows on its axe;
##   its charge catches him standing and fells him, a roll aside lets it by
##   and leaves it dazed; its axe into the ground sends a crack that fells him;
##   its combos (Mixamo's, UAL 2's) are there and play;
## * the butcher: his cleaver in his hand, seen, and his blows where it is;
##   his own Mixamo strings (2026-10-23), any of them again or another; his
##   hook (off now: the user's word) catches him from off and hauls him in, a roll slips it; his
##   three blows into the ground (enraged) crack it out at him; woken, he
##   roars his name.
##
##   godot --headless --path . --script res://tests/monster_polish_test.gd

const MINO := "res://scenes/enemies/minotaur.tscn"
const BUTCHER := "res://scenes/enemies/pack/pig_butcher.tscn"

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
	Input.action_release(&"dash")
	Input.action_release(&"move_left")
	world.queue_free()
	for i in 3:
		await process_frame


func _hold(hero: Player, at: Vector3) -> void:
	hero.global_position = Vector3(at.x, hero.global_position.y, at.z)
	hero.velocity.x = 0.0
	hero.velocity.z = 0.0


func _down(hero: Player) -> bool:
	return hero.state == Player.State.DOWNED


func _run() -> void:
	await _mino_made()
	await _mino_charge()
	await _mino_charge_rolled()
	await _mino_crack()
	await _mino_combos()
	await _butcher_cleaver()
	await _butcher_combos()
	await _butcher_side()
	await _butcher_hook()
	await _butcher_hook_rolled()
	await _butcher_slaughter()
	await _butcher_intro()
	print("monster_polish_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _mino_made() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var m := (a[1] as ArenaPanel).call_up(MINO, false, _ahead(hero, 9.0)) as Node3D
	for i in 10:
		await physics_frame
	_check("the minotaur is a PackBrute with a stance and a rage", m is MinotaurFighter
			and float(m.get(&"stance")) > 0.0 and float(m.get(&"rage_at")) > 0.0, m.get_class())
	var anim: SkeletonAnim = m.get(&"_anim")
	var have := true
	for c in [&"MN_Battlecry", &"MN_Combo2", &"MN_UHeavyCombo", &"MN_UPound", &"MN_ULay", &"MN_Headbutt"]:
		have = have and anim != null and anim.has_clip(c)
	_check("its new clips (Mixamo's, UAL 2's) are on it", have)
	var tip: Vector3 = m.call(&"_weapon_tip_at")
	var hand := m.global_position + Vector3.UP * 1.5
	_check("its blow is at the axe's head, well out from its hand", tip.distance_to(hand) > 1.0,
			"%.2f m" % tip.distance_to(hand))
	await _done(a[0])


func _mino_charge() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var spot := hero.global_position
	var m := (a[1] as ArenaPanel).call_up(MINO, false, _ahead(hero, 12.0)) as MinotaurFighter
	m.hand_combo_chance = Vector2.ZERO
	m.set(&"_charge_wait", 0.0)
	var downed := false
	for i in 420:
		if not _down(hero):
			_hold(hero, spot)
		downed = downed or _down(hero)
		if m.charges_landed > 0 and downed:
			break
		await physics_frame
	_check("its charge, roared first, catches him standing and fells him", m.charges_made >= 1
			and m.charges_landed >= 1 and downed, "made %d landed %d" % [m.charges_made, m.charges_landed])
	await _done(a[0])


func _mino_charge_rolled() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var spot := hero.global_position
	var m := (a[1] as ArenaPanel).call_up(MINO, false, _ahead(hero, 12.0)) as MinotaurFighter
	m.hand_combo_chance = Vector2.ZERO
	m.set(&"_charge_wait", 0.0)
	var rolled := 0
	var dazed := false
	for i in 420:
		if rolled == 0:
			_hold(hero, spot)
		if rolled == 0 and m.charge_state == MinotaurFighter.Charge.RUN \
				and hero.global_position.distance_to(m.global_position) < 4.2:
			rolled = 1
			Input.action_press(&"move_left")
			Input.action_press(&"dash")
		elif rolled > 0 and rolled < 12:
			rolled += 1
			if rolled == 12:
				Input.action_release(&"move_left")
				Input.action_release(&"dash")
		dazed = dazed or m.act == MinotaurFighter.M_DAZE
		if m.charges_missed > 0 and dazed:
			break
		await physics_frame
	_check("a roll aside lets the charge by, and it stands dazed after", m.charges_missed >= 1
			and m.charges_landed == 0 and dazed, "missed %d landed %d" % [m.charges_missed, m.charges_landed])
	await _done(a[0])


func _mino_crack() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var spot := hero.global_position
	var m := (a[1] as ArenaPanel).call_up(MINO, false, _ahead(hero, 5.0)) as MinotaurFighter
	m.set(&"_charge_wait", 999.0)
	m.global_position = _ahead(hero, 5.0)
	for i in 5:
		await physics_frame
	m.call(&"_face", spot - m.global_position, 1.0, 50.0)
	m._quarry = hero
	m.mode = Fighter.Mode.FIGHT
	m.set(&"_cooldown", 99.0)
	m.call(&"_begin", MinotaurFighter.M_POUND)
	for i in 240:
		if not _down(hero):
			_hold(hero, spot)
		if m.cracks_hurt > 0:
			break
		await physics_frame
	_check("its axe into the ground sends a crack along it that reaches him", m.cracks_made >= 1
			and m.cracks_hurt >= 1, "made %d hurt %d" % [m.cracks_made, m.cracks_hurt])
	await _done(a[0])


func _mino_combos() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var spot := hero.global_position
	var m := (a[1] as ArenaPanel).call_up(MINO, false, _ahead(hero, 4.0)) as MinotaurFighter
	m.set(&"_charge_wait", 999.0)
	var names := []
	for c: Dictionary in m.get(&"_hand_combos"):
		names.append(String(c["name"]))
	_check("its combos: Mixamo's three cuts and the pound, UAL 2's heavy string", names.has("three_and_pound")
			and names.has("heavy_string") and names.has("bull"), str(names))
	m.drill_combo = names.find("heavy_string")
	for i in 600:
		_hold(hero, spot)
		if m.hand_combos_made.size() > 0:
			break
		await physics_frame
	_check("UAL 2's heavy string played", m.hand_combos_made.has(names.find("heavy_string")),
			str(m.hand_combos_made))
	await _done(a[0])


func _butcher_cleaver() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var b := (a[1] as ArenaPanel).call_up(BUTCHER, false, _ahead(hero, 9.0)) as PigButcher
	for i in 10:
		await physics_frame
	var cleaver: Node3D = b.get(&"_cleaver")
	_check("the butcher holds his cleaver, seen", cleaver != null and cleaver.is_visible_in_tree())
	var parts: Array = b.call(&"_weapon_part")
	var ok := not parts.is_empty() and cleaver != null
	if ok:
		var mid: Vector3 = ((parts[0] as Array)[0] + (parts[0] as Array)[1]) * 0.5
		ok = mid.distance_to(cleaver.global_position) < 2.0
	_check("his blow is where the cleaver is", ok)
	await _done(a[0])


func _butcher_combos() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var spot := hero.global_position
	var b := (a[1] as ArenaPanel).call_up(BUTCHER, false, _ahead(hero, 4.0)) as PigButcher
	b.set(&"_hook_wait", 999.0)
	_check("his hook is off unless asked", not b.hook_on)
	var names := []
	for c: Dictionary in b.get(&"_hand_combos"):
		names.append(String(c["name"]))
	_check("his own strings: the sword string, the thrust, the leap, the low spin", names.has("sword_string")
			and names.has("thrust_cut") and names.has("leap_in") and names.has("low_spin")
			and not names.has("sweep_back"), str(names))
	_check("the same combo not held back from coming again", is_equal_approx(b.repeat_damp, 1.0))
	_check("no glide in, no sidestep, not the orc's fall from the sky", b.combo_slack < 0.6
			and b.close_speed <= 1.6 and b.sidestep_after == 0.0 and not b.call(&"_try_leap"))
	_check("his cleaver leaves the heroes' cut in the air", b.get(&"_arc") is BladeArc)
	_check("no kick at him behind his shield, no snap round between blows", b.kick_after > 1000.0
			and b.chain_snap == 0.0 and b.act_turn_most <= 240.0)
	b.drill_combo = names.find("sword_string")
	for i in 600:
		_hold(hero, spot)
		if b.hand_combos_made.size() > 0:
			break
		await physics_frame
	_check("Mixamo's sword string played", b.hand_combos_made.has(names.find("sword_string")),
			str(b.hand_combos_made))
	b.drill_combo = names.find("chop_and_split")
	for i in 900:
		_hold(hero, spot)
		if b.hand_combos_made.has(names.find("chop_and_split")) and b.act == Fighter.Act.NONE:
			break
		await physics_frame
	_check("dust off the ground where his cleaver goes in", b.ground_dusts > 0, "dusts %d" % b.ground_dusts)
	await _done(a[0])


## Him going round the butcher close by: the butcher spins on him, and the
## spin lands at his side (the user's word, 2026-10-23).
func _butcher_side() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var b := (a[1] as ArenaPanel).call_up(BUTCHER, false, _ahead(hero, 3.0)) as PigButcher
	b.set(&"_hook_wait", 999.0)
	b.hand_combo_chance = Vector2.ZERO
	for i in 120:
		await physics_frame
	for i in 900:
		var off := hero.global_position - b.global_position
		off.y = 0.0
		if off.length() > 0.1:
			var step := off.normalized().cross(Vector3.UP) + off.normalized() * clampf(2.6 - off.length(), -1.0, 1.0)
			hero.global_position += step * 5.0 / 60.0
		if b.spin_blows_landed > 0:
			break
		await physics_frame
	_check("him going round close by, he spins on him", b.side_spins > 0, "spins %d" % b.side_spins)
	_check("the spin lands at his side", b.spin_blows_landed > 0, "landed %d" % b.spin_blows_landed)
	await _done(a[0])


func _butcher_hook() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var spot := hero.global_position
	var b := (a[1] as ArenaPanel).call_up(BUTCHER, false, _ahead(hero, 11.0)) as PigButcher
	b.hand_combo_chance = Vector2.ZERO
	b.hook_on = true
	b.set(&"_hook_wait", 0.0)
	var start := hero.global_position.distance_to(b.global_position)
	var nearest := start
	for i in 480:
		if b.hooks_caught == 0:
			_hold(hero, spot)
		nearest = minf(nearest, hero.global_position.distance_to(b.global_position))
		if b.hooks_caught > 0 and b.hook_state == PigButcher.Hook.NONE:
			break
		await physics_frame
	_check("his hook catches him from off and hauls him in", b.hooks_caught >= 1 and nearest < start - 5.0,
			"caught %d, from %.1f to %.1f m" % [b.hooks_caught, start, nearest])
	await _done(a[0])


func _butcher_hook_rolled() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var spot := hero.global_position
	var b := (a[1] as ArenaPanel).call_up(BUTCHER, false, _ahead(hero, 11.0)) as PigButcher
	b.hand_combo_chance = Vector2.ZERO
	b.hook_on = true
	b.set(&"_hook_wait", 0.0)
	var rolled := 0
	for i in 420:
		if rolled == 0:
			_hold(hero, spot)
		if rolled == 0 and b.hook_state == PigButcher.Hook.OUT:
			rolled = 1
			Input.action_press(&"move_left")
			Input.action_press(&"dash")
		elif rolled > 0 and rolled < 14:
			rolled += 1
			if rolled == 14:
				Input.action_release(&"move_left")
				Input.action_release(&"dash")
		if b.hooks_thrown > 0 and b.hook_state == PigButcher.Hook.NONE and rolled > 0:
			break
		await physics_frame
	_check("a roll slips his hook", b.hooks_thrown >= 1 and b.hooks_caught == 0,
			"thrown %d caught %d" % [b.hooks_thrown, b.hooks_caught])
	await _done(a[0])


func _butcher_slaughter() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var spot := hero.global_position
	var b := (a[1] as ArenaPanel).call_up(BUTCHER, false, _ahead(hero, 4.0)) as PigButcher
	b.set(&"_hook_wait", 999.0)
	b.raging = true
	var names := []
	for c: Dictionary in b.get(&"_hand_combos"):
		names.append(String(c["name"]))
	_check("his combos: Mixamo's club string, UAL 2's sword string", names.has("cleaver_three")
			and names.has("butcher_string") and names.has("slaughter"), str(names))
	b.drill_combo = names.find("slaughter")
	for i in 900:
		if not _down(hero):
			_hold(hero, spot)
		if b.cracks_made >= 3 and b.cracks_hurt >= 1:
			break
		await physics_frame
	_check("enraged, three blows into the ground crack it out at him", b.cracks_made >= 3 and b.cracks_hurt >= 1,
			"made %d hurt %d" % [b.cracks_made, b.cracks_hurt])
	await _done(a[0])


func _butcher_intro() -> void:
	var a: Array = await _arena()
	var hero: Player = a[2]
	var b := (a[1] as ArenaPanel).call_up(BUTCHER, false, _ahead(hero, 9.0)) as PigButcher
	var roared := false
	for i in 60:
		roared = roared or b.act == PigButcher.B_INTRO
		await physics_frame
	_check("woken, he roars where he stands first", roared and bool(b.get(&"_introduced")))
	await _done(a[0])
