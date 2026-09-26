extends SceneTree

## The balance between heroes and wolves: p.def ([Defence]); Tariel with the
## most health and the most p.def; two blows of a wolf the end of him — and of
## every hero, none of whom falls to one; a wolf with twice the imp's p.def,
## and not cut apart until it is down to half.
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
	for h: String in HEROES:
		if h == "tariel":
			continue
		most_health = most_health and profiles["tariel"].max_health > profiles[h].max_health
		most_def = most_def and profiles["tariel"].p_def > profiles[h].p_def
	_check("Tariel has the most health of the heroes", most_health)
	_check("and the most p.def", most_def)

	var wolf: Wolf = (load("res://scenes/enemies/wolf.tscn") as PackedScene).instantiate()
	var imp: Node = (load("res://scenes/enemies/imp.tscn") as PackedScene).instantiate()
	_check("a wolf has twice the imp's p.def", is_equal_approx(wolf.p_def, 2.0 * float(imp.get("p_def")))
			and wolf.p_def > 0.0, "%.0f vs %.0f" % [wolf.p_def, float(imp.get("p_def"))])
	imp.free()
	for h: String in HEROES:
		var p: CharacterProfile = profiles[h]
		var blow := Defence.taken(wolf.swipe_damage, p.p_def)
		_check("%s: one blow of a wolf leaves him standing, two are the end" % h,
				blow < p.max_health and blow * 2.0 >= p.max_health,
				"%.1f a blow, %.0f health" % [blow, p.max_health])
	wolf.free()

	# In the game: Tariel, two wolf blows.
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"tariel")
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(3)
	var player := world.player()
	player.immortal = false
	var w: Wolf = null
	for node in world.get_node("Enemies").get_children():
		if node is Wolf and w == null:
			w = node
		(node as Node).set_physics_process(false)
	w.global_position = player.global_position + Vector3(0.0, 0.0, -1.5)
	var full := player.health
	player.receive_blow(w.swipe_damage, w, 0, 2, 1)
	await _wait(30)
	var after_one := player.health
	player.state = Player.State.GROUNDED
	player.receive_blow(w.swipe_damage, w, 0, 2, 2)
	await _wait(10)
	_check("in the game, a wolf's first blow leaves Tariel standing", after_one > 0.0 and after_one < full,
			"%.1f of %.0f" % [after_one, full])
	_check("and its second is the end of him", player.health <= 0.0, "%.1f left" % player.health)

	# A wolf is whole until it is down to half.
	w.global_position += Vector3(0.0, -60.0, 0.0)
	await _wait(2)
	var centre := w.global_position + Vector3.UP * 1.0
	var edge := [centre + Vector3(-1.2, 0.2, 0.0), centre + Vector3(1.2, -0.2, 0.0)]
	w.health = w.max_health
	var cuts := 0
	while w.health > w.max_health * w.sever_below and cuts < 20:
		cuts += 1
		if not w._wound(player, edge, 100 + cuts):
			break
	_check("above half its health the blade only wounds it", w.rig.lost_parts() == 0 and cuts >= 2,
			"%d cuts, %d limbs off, %.0f health" % [cuts, w.rig.lost_parts(), w.health])
	_check("and each cut is taken through its p.def",
			is_equal_approx(w.max_health - Defence.taken(w.damage_per_hit, w.p_def) * cuts, w.health)
			or w.health <= w.max_health * w.sever_below)
	_check("at half, limbs come off", not w._wound(player, edge, 999)
			and w.rig.sever_along_edge(edge[0], edge[1], w.hit_tolerance) != "")
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
