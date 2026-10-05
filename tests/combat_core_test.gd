extends SceneTree

## The shared combat core: every creature takes its blows through a
## [HurtboxComponent]; a boss steps through its [BossPhase]s as its health
## falls and starts over when let go; in PvP a hero is a foe to another hero
## of another side, and a hero's blow on him is scaled by `pvp_damage_scale`.
##
##     godot --path . --headless --script res://tests/combat_core_test.gd

var _failures := 0


func _initialize() -> void:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(2)
	var hero := world.player()
	var enemies := world.get_node("Enemies")

	# --- One door for every creature --------------------------------------------
	var ark: Arkdeva = null
	var orc: OrcWarrior = null
	var wolf: Wolf = null
	var fighter: Fighter = null
	for node in _all(enemies):
		if node is Arkdeva and ark == null:
			ark = node
		elif node is OrcWarrior and orc == null:
			orc = node
		elif node is Wolf and wolf == null:
			wolf = node
		elif node is Fighter and fighter == null:
			fighter = node
	for w in root.get_tree().get_nodes_in_group(&"wolf"):
		if wolf == null and w is Wolf:
			wolf = w
	_check(ark != null and orc != null, "Arkdeva and an orc are in the world")
	for who: Node3D in [ark, orc, wolf, fighter]:
		if who == null:
			continue
		var before: float = who.get(&"health")
		who.call(&"take_hit", 10.0, who.global_position + Vector3.UP, Vector3.FORWARD, false, true, hero)
		_check(who.get_node_or_null(^"Hurtbox") is HurtboxComponent, "%s has its hurtbox" % who.name)
		_check(float(who.get(&"health")) < before, "%s: a hit through take_hit still bites (%.1f -> %.1f)"
				% [who.name, before, float(who.get(&"health"))])

	# --- Boss phases --------------------------------------------------------------
	if ark != null:
		var two := BossPhase.new()
		two.hp_threshold = 0.66
		two.phase_animation = &"STAMP"
		two.speed_multiplier = 1.5
		two.armour_multiplier = 1.25
		two.new_attacks_array = [&"COMBO", &"SPIT_TWO"]
		var three := BossPhase.new()
		three.hp_threshold = 0.33
		three.speed_multiplier = 2.0
		three.armour_multiplier = 2.0
		three.new_attacks_array = [&"NO_SUCH_MOVE"]
		# given out of order on purpose: read highest threshold first
		ark.phases = [three, two]
		ark.health = ark.max_health
		var close := ark.close_speed
		var chase := ark.chase_speed
		var pdef := ark.p_def
		var mdef := ark.m_def
		var seen: Array[int] = []
		ark.phase_changed.connect(func(i: int, _p: BossPhase) -> void: seen.append(i))
		ark.health = ark.max_health * 0.7
		ark.take_hit(1.0, ark.global_position, Vector3.FORWARD, false, true, hero)
		_check(ark.phase_index == -1, "above 66 %% it is not in a stage yet (%d)" % ark.phase_index)
		ark.health = ark.max_health * 0.6
		ark.take_hit(1.0, ark.global_position, Vector3.FORWARD, false, true, hero)
		_check(ark.current_phase() == two, "at 60 % it steps into the second stage")
		_check(is_equal_approx(ark.close_speed, close * 1.5) and is_equal_approx(ark.chase_speed, chase * 1.5),
				"quicker by its multiplier (%.2f / %.2f)" % [ark.close_speed, ark.chase_speed])
		_check(is_equal_approx(ark.p_def, pdef * 1.25) and is_equal_approx(ark.m_def, mdef * 1.25),
				"harder to hurt by its multiplier (p.def %.1f)" % ark.p_def)
		_check(ark.act == Arkdeva.Act.STAMP, "it opens the stage with its stamp (act %d)" % ark.act)
		_check(Array(ark._phase_attacks) == [Arkdeva.Act.COMBO, Arkdeva.Act.SPIT_TWO], "its new attacks are known by name")
		var picked := false
		ark._start(Brute.ACT_NONE, 0.0)
		for i in 40:
			if ark._choose_phase_attack(1.0):
				picked = true
				break
		_check(picked and ark.act == Arkdeva.Act.COMBO, "close in, a new attack it throws is the combo, not the spit (act %d)" % ark.act)
		ark._start(Brute.ACT_NONE, 0.0)
		ark.health = ark.max_health * 0.05
		ark.take_hit(1.0, ark.global_position, Vector3.FORWARD, false, true, hero)
		_check(ark.current_phase() == three, "at 5 % it is in the last stage")
		_check(is_equal_approx(ark.p_def, pdef * 2.0), "and its stages do not stack (p.def %.1f)" % ark.p_def)
		_check(ark._phase_attacks.is_empty(), "an attack it does not have is left out")
		_check(Array(seen) == [1, 0], "each stage told once, in order (%s)" % [seen])
		ark._reset_phases()
		_check(ark.phase_index == -1 and is_equal_approx(ark.p_def, pdef)
				and is_equal_approx(ark.close_speed, close), "let go of, it starts over")
		ark.phases = []

	# --- PvP ----------------------------------------------------------------------
	var other: Player = load("res://scenes/player/player.tscn").instantiate()
	other.name = "Other"
	world.add_child(other)
	other.global_position = hero.global_position + Vector3(1.2, 0.0, 0.0)
	await _wait(3)
	Player.pvp_mode = false
	_check(not hero.is_hostile_to(other), "out of PvP a hero is no foe")
	_check(not hero._foes().has(other), "and not lockable")
	var health := other.health
	other.hurtbox().take(_blow(hero, other, 40.0))
	_check(is_equal_approx(other.health, health), "and his blade does nothing (%.1f)" % other.health)
	Player.pvp_mode = true
	_check(hero.is_hostile_to(other) and other.is_hostile_to(hero), "in PvP heroes are foes")
	_check(hero._foes().has(other), "and lockable")
	_check(hero.is_hostile_to(ark) if ark != null else true, "a creature is a foe all the same")
	hero.team = 2
	other.team = 2
	_check(not hero.is_hostile_to(other), "but never of the same side")
	other.team = 3
	_check(hero.is_hostile_to(other), "of another side, again")
	hero.pvp_damage_scale = 0.5
	other.health = other.max_health
	var full := other.health
	other.hurtbox().take(_blow(hero, other, 40.0))
	await _wait(2)
	var taken := full - other.health
	var whole := Defence.against(40.0, other.p_def, other.m_def, false)
	_check(taken > 0.0, "his blade bites another side's hero (%.1f)" % taken)
	_check(taken < whole * 0.75, "at his pvp_damage_scale, not whole (%.1f of %.1f)" % [taken, whole])
	Player.pvp_mode = false
	other.queue_free()

	print("" if _failures == 0 else "\n%d check(s) FAILED." % _failures)
	if _failures == 0:
		print("\nAll checks passed.")
	quit(1 if _failures > 0 else 0)


func _blow(from: Player, to: Player, damage: float) -> HitInfo:
	var hit := HitInfo.make(damage, to.global_position + Vector3.UP, Vector3.FORWARD, false, true, from)
	hit.by_blade = true
	hit.serial = 7
	return hit


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all(child))
	return out


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print("  %s - %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
