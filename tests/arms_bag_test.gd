extends SceneTree

## Every hero who fights with a blade takes his arms from the bag the same
## way (the user's word, 2026-10-06): one press puts a blade into the empty
## right hand, else the left, else in the left's place; a press on one he
## holds takes it off; a shield stays on his arm; a two-handed blade takes
## both hands. Archers and mages keep their bows and staves.
##
##     godot --path . --headless --script res://tests/arms_bag_test.gd -- <hero>

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	var hero := StringName(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else &"tariel"
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", hero)
	var world: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player: Player = world.call("player")
	player.immortal = true
	var rig := player.rig as SkinnedRig
	player.set_look(PolysplitLook.default_look(rig.polysplit_hero, "m"))
	player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
	for i in 20:
		await physics_frame
	var bag := player._inventory
	var blades: Array[String] = bag._blades()
	var shooter := player.profile.weapon != CharacterProfile.Weapon.MELEE
	_check("%s: blades in the bag" % hero, blades.is_empty() == shooter, "%d: %s" % [blades.size(), str(blades.slice(0, 6))])
	if shooter:
		print("arms_bag_test: %s" % ("all checks passed" if _failures == 0 else "%d FAILED" % _failures))
		quit(1 if _failures > 0 else 0)
		return
	var start: Dictionary = rig.get_look()
	var shield := PolysplitLook.kind(String(start.get("o", ""))) == &"shield"
	var one := ""
	var two := ""
	var both := ""
	for id: String in blades:
		if PolysplitLook.both_hands(id):
			if both == "":
				both = id
		elif one == "":
			one = id
		elif two == "" and bag._left_can(id, one):
			two = id
	bag._hands_empty()
	await _ticks(6)
	var lk: Dictionary = rig.get_look()
	_check("every blade off%s" % (", the shield kept" if shield else ""), String(lk["w"]) == "none"
			and (String(lk["o"]) == String(start["o"]) if shield else String(lk["o"]) == "none"), "%s / %s" % [lk["w"], lk["o"]])
	if one != "":
		bag._take_blade(one)
		await _ticks(6)
		lk = rig.get_look()
		_check("a blade: into the empty right hand", String(lk["w"]) == one, "%s / %s" % [lk["w"], lk["o"]])
		if two != "" and not shield:
			bag._take_blade(two)
			await _ticks(6)
			lk = rig.get_look()
			_check("another: into the left", String(lk["w"]) == one and String(lk["o"]) == two, "%s / %s" % [lk["w"], lk["o"]])
			bag._take_blade(two)
			await _ticks(6)
		elif two != "" and shield:
			bag._take_blade(two)
			await _ticks(6)
			lk = rig.get_look()
			_check("another, a shield on his arm: the right hand's place, the shield kept", String(lk["w"]) == two
					and String(lk["o"]) == String(start["o"]), "%s / %s" % [lk["w"], lk["o"]])
			one = two
		bag._take_blade(one)
		await _ticks(6)
		lk = rig.get_look()
		_check("the one he holds again: off", String(lk["w"]) == "none", "%s / %s" % [lk["w"], lk["o"]])
	if both != "":
		bag._take_blade(both)
		await _ticks(6)
		lk = rig.get_look()
		_check("a two-handed one: both hands", String(lk["w"]) == both and String(lk["o"]) == "none", "%s / %s" % [lk["w"], lk["o"]])
	print("arms_bag_test: %s" % ("all checks passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
