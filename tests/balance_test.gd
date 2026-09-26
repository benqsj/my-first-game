extends SceneTree

## The balance between heroes and creatures ([Defence], README "Balance"):
## p.def against blades, claws and arrows, m.def against spells, fire, poison
## and the wolf's claw wave. Tariel the slowest to kill and the slowest to die:
## the most health and p.def, the smallest cut and the lowest crit; three blows
## of a wolf the end of him, two of anyone else, one of nobody. The mage's bolt
## the heaviest single hit, then the hunter's arrow and the assassin's knife.
## A critical counted once. A wolf with twice the imp's p.def, and whole until
## it is down to half.
##
##     godot --path . --headless --script res://tests/balance_test.gd

const HEROES := ["tariel", "avtandil", "rogue", "mage"]

var _failures := 0


func _initialize() -> void:
	var profiles := {}
	for h: String in HEROES:
		profiles[h] = load("res://scenes/player/%s.tres" % h) as CharacterProfile
	var most_health := true
	var most_def := true
	var least_crit := true
	for h: String in HEROES:
		if h == "tariel":
			continue
		most_health = most_health and profiles["tariel"].max_health > profiles[h].max_health
		most_def = most_def and profiles["tariel"].p_def > profiles[h].p_def
		least_crit = least_crit and profiles["tariel"].crit_chance < profiles[h].crit_chance \
				and profiles["tariel"].crit_damage <= profiles[h].crit_damage
	_check("Tariel has the most health of the heroes", most_health)
	_check("and the most p.def", most_def)
	_check("and the lowest crit", least_crit)
	var mage: CharacterProfile = profiles["mage"]
	_check("the mage has the most m.def", mage.m_def > profiles["tariel"].m_def
			and mage.m_def > profiles["avtandil"].m_def and mage.m_def > profiles["rogue"].m_def)
	_check("and shoots with m.atk", mage.weapon == CharacterProfile.Weapon.STAFF
			and mage.shot_power() == mage.m_atk and mage.m_atk > 0.0)

	var wolf: Wolf = (load("res://scenes/enemies/wolf.tscn") as PackedScene).instantiate()
	var imp: Node = (load("res://scenes/enemies/imp.tscn") as PackedScene).instantiate()
	_check("a wolf has twice the imp's p.def", is_equal_approx(wolf.p_def, 2.0 * float(imp.get("p_def")))
			and wolf.p_def > 0.0, "%.0f vs %.0f" % [wolf.p_def, float(imp.get("p_def"))])
	_check("and less m.def than p.def: a beast, open to spells", wolf.m_def < wolf.p_def)
	imp.free()
	for h: String in HEROES:
		var p: CharacterProfile = profiles[h]
		var blow := Defence.taken(wolf.swipe_damage, p.p_def)
		var lives := 2 if h == "tariel" else 1
		_check("%s: %d blow(s) of a wolf leave him standing, %d are the end" % [h, lives, lives + 1],
				blow * lives < p.max_health and blow * (lives + 1) >= p.max_health,
				"%.1f a blow, %.0f health" % [blow, p.max_health])

	# The heaviest single hit on a wolf, crits aside: bolt, arrow, knife, sword.
	var worth := {}
	for h: String in HEROES:
		var p: CharacterProfile = profiles[h]
		var magic := p.weapon == CharacterProfile.Weapon.STAFF
		var full := p.shot_power() * (p.full_charge_bonus if magic else 1.0)
		worth[h] = Defence.against(full, wolf.p_def, wolf.m_def, magic)
	_check("on a wolf the mage's full bolt is the heaviest hit",
			worth["mage"] > worth["avtandil"] and worth["mage"] > worth["rogue"], "%s" % worth)
	_check("then the hunter's arrow and the assassin's knife, and Tariel's sword the least",
			worth["rogue"] > worth["tariel"] and worth["avtandil"] > worth["tariel"], "%s" % worth)
	# Kill speed on a wolf, from the measured swing and shot rates (README
	# "Balance"): Tariel the slowest.
	var rate := {"tariel": 1.05, "rogue": 1.4, "avtandil": 0.565, "mage": 0.24}
	var dps := {}
	for h: String in HEROES:
		var p: CharacterProfile = profiles[h]
		dps[h] = float(worth[h]) * float(rate[h]) * (1.0 + p.crit_chance * (p.crit_damage - 1.0))
	_check("Tariel kills a wolf the slowest", dps["tariel"] < dps["rogue"] and dps["tariel"] < dps["avtandil"]
			and dps["tariel"] < dps["mage"], "%s" % dps)
	var fastest := 0.0
	for h: String in HEROES:
		fastest = maxf(fastest, float(dps[h]))
	_check("and nobody more than twice as fast as he is", fastest < 2.0 * float(dps["tariel"]), "%s" % dps)
	wolf.free()

	# In the game: Tariel, three wolf blows; the claw wave through his m.def.
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(3)
	var player := world.player()
	player.immortal = false
	var w: Wolf = null
	var an_imp: Fighter = null
	for node in world.get_node("Enemies").get_children():
		if node is Wolf and w == null:
			w = node
		if node is Fighter and an_imp == null:
			an_imp = node
		(node as Node).set_physics_process(false)
	w.global_position = player.global_position + Vector3(0.0, 0.0, -1.5)
	var full := player.health
	player.receive_blow(70.0, w, 0, 2, 7, true)
	await _wait(20)
	_check("torn air is taken through m.def", is_equal_approx(full - player.health, Defence.taken(70.0, player.m_def)),
			"%.1f, want %.1f" % [full - player.health, Defence.taken(70.0, player.m_def)])
	player.health = full
	player.state = Player.State.GROUNDED
	var lefts: Array[float] = []
	for k in 3:
		player.receive_blow(w.swipe_damage, w, 0, 2, 10 + k)
		await _wait(30)
		lefts.append(player.health)
		if player.health > 0.0:
			player.state = Player.State.GROUNDED
			player.is_invulnerable = false
	_check("in the game, two of a wolf's blows leave Tariel standing", lefts[1] > 0.0 and lefts[0] < full,
			"%s of %.0f" % [lefts, full])
	_check("and its third is the end of him", lefts[2] <= 0.0, "%s" % [lefts])

	# A critical is counted once: the shooter made the damage a critical one.
	if an_imp != null:
		an_imp.global_position += Vector3(0.0, -60.0, 0.0)
		an_imp.health = an_imp.max_health
		var hp := an_imp.health
		an_imp.take_hit(30.0, an_imp.global_position, Vector3.UP, true, false, null)
		_check("a critical arrow is not made critical again", is_equal_approx(hp - an_imp.health,
				Defence.taken(30.0, an_imp.p_def)), "%.1f" % (hp - an_imp.health))
		hp = an_imp.health
		an_imp.take_hit(30.0, an_imp.global_position, Vector3.UP, false, false, null, true)
		_check("and a spell goes through its m.def", is_equal_approx(hp - an_imp.health,
				Defence.taken(30.0, an_imp.m_def)), "%.1f" % (hp - an_imp.health))
	# A hero's cut is his own p.atk, now and then a critical.
	var was := player.profile.crit_chance
	player.profile.crit_chance = 0.0
	_check("a cut is worth the hero's p.atk", is_equal_approx(float(player.cut_worth()[0]), player.profile.damage))
	player.profile.crit_chance = 1.0
	var crit := player.cut_worth()
	_check("and a critical one crit_damage times that", bool(crit[1])
			and is_equal_approx(float(crit[0]), player.profile.damage * player.profile.crit_damage))
	player.profile.crit_chance = 0.0

	# A wolf is whole until it is down to half.
	w.global_position += Vector3(0.0, -60.0, 0.0)
	await _wait(2)
	var centre := w.global_position + Vector3.UP * 1.0
	var edge := [centre + Vector3(-1.2, 0.2, 0.0), centre + Vector3(1.2, -0.2, 0.0)]
	w.health = w.max_health
	var cuts := 0
	while w.health > w.max_health * w.sever_below and cuts < 40:
		cuts += 1
		if not w._wound(player, edge, 100 + cuts):
			break
	_check("above half its health the blade only wounds it", w.rig.lost_parts() == 0 and cuts >= 2,
			"%d cuts, %d limbs off, %.0f health" % [cuts, w.rig.lost_parts(), w.health])
	_check("and each cut is taken through its p.def",
			is_equal_approx(w.max_health - Defence.taken(player.profile.damage, w.p_def) * cuts, w.health)
			or w.health <= w.max_health * w.sever_below)
	w.sever_chance = 1.0
	_check("at half, limbs come off", not w._wound(player, edge, 999)
			and w.rig.sever_along_edge(edge[0], edge[1], w.hit_tolerance) != "")
	player.profile.crit_chance = was
	_finish()


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("\n%s" % ("All checks passed." if _failures == 0 else "%d check(s) failed." % _failures))
	quit(1 if _failures else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
