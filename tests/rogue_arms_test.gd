extends SceneTree

## The assassin fights by what he holds (the user's word, 2026-10-05): a
## blade in each hand (two knives, or a short sword and a knife) and he
## fights with both — the lab's TWO BLADES string and the two-handed heavy
## blows; one blade, and as he did, one-handed, the heavy ones too. Alone,
## the heavy one is gathered and then slid in on what it is thrown at,
## wherever it has got to, the blows coming when he is there.
##
##     godot --path . --headless --script res://tests/rogue_arms_test.gd

var _failures := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1


func _initialize() -> void:
	Engine.max_fps = Engine.physics_ticks_per_second
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"rogue")
	var world: Node3D = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var player: Player = world.call("player")
	player.immortal = true
	var rig := player.rig as SkinnedRig
	var foe: Node3D = null
	for n in world.find_children("*", "CharacterBody3D", true, false):
		if foe == null and String(n.name).begins_with("Puglin"):
			foe = n
		elif n != player:
			(n as Node3D).global_position += Vector3(0, -80, 0)
			n.set_physics_process(false)
	var at := Vector3(6, 0, 36)
	at.y = Terrain.current.height_at(at.x, at.z)
	var looks := [
		["two knives", {"w": "dagger", "o": "dagger"}, true],
		["a short sword and a knife", {"w": "aw_shortsword_obsidian", "o": "aw_dagger_obsidian"}, true],
		["one knife", {"w": "dagger", "o": "none"}, false],
	]
	for l: Array in looks:
		var look := PolysplitLook.default_look(&"rogue", "m")
		look.merge(l[1], true)
		player.set_look(look)
		player.set_face(rig.faces.find(SkinnedRig.CUSTOM))
		for i in 20:
			await physics_frame
		var two: bool = l[2]
		_check("%s: %s" % [l[0], "both hands" if two else "one hand"], rig.on_mannequin()
				and (rig.moves.get("kind", &"") == &"dual") == two and rig.call(&"two_blades") == two,
				String(rig.moves.get("kind", &"")))
		# the pace of what he holds: knives quick, a short sword slower
		var pace: float = rig.arms_pace()
		var want := 1.0 if l[0] != "a short sword and a knife" else 1.0 / 1.2
		_check("  the pace of his arms", absf(pace - want) < 0.01, "x%.2f" % pace)
		if two:
			_check("  the TWO BLADES string", rig.flurry.size() >= 4 and rig.flurry[0] == &"DG_Slash_Out", str(rig.flurry))
			# his own cuts at his own pace on the mannequin too (they were at
			# its 1.1, half his speed)
			player.global_position = at
			Input.action_press("attack")
			await physics_frame
			Input.action_release("attack")
			for i in 3:
				await physics_frame
			_check("  his knife cuts at his own pace", rig._act_clip == &"DG_Slash_Out"
					and absf(rig._anim.speed_scale - 1.85 * pace) < 0.05,
					"%s x%.2f" % [rig._act_clip, rig._anim.speed_scale])
			for i in 60:
				await physics_frame
		if not two:
			_check("  one knife: always the whole three-cut string", rig._strings.size() == 1 and rig.flurry.size() >= 3,
					str(rig.flurry))
		_check("  the heavy blows %s" % ("with both" if two else "with the one"),
				rig.heavy[0]["clip"] == (&"DG_Dual_Combo" if two else &"DG_Axe_Three"), String(rig.heavy[0]["clip"]))
	# The bag: every knife and short sword, in every style, for either hand.
	var bag := player._inventory
	if bag != null:
		var blades: Array[String] = bag._blades()
		_check("the bag holds his blades", blades.size() >= 9 and blades.has("aw_dagger_bone") and blades.has("aw_dagger_ornate"),
				str(blades))
		bag._hold_blade("aw_dagger_ornate", true)
		for i in 10:
			await physics_frame
		_check("a knife put in his left hand: both hands", rig.moves.get("kind", &"") == &"dual"
				and String(rig.get_look().get("o", "")) == "aw_dagger_ornate", String(rig.moves.get("kind", &"")))
		_check("the bag has the empty left hand", blades.has("none"))
		bag._use(blades.find("none"))
		for i in 10:
			await physics_frame
		_check("his left hand emptied: one hand", rig.moves.get("kind", &"") != &"dual", String(rig.moves.get("kind", &"")))
	else:
		_check("the bag", false, "no Inventory on the player")
	# Alone: gathered, then slid in on it where it has gone meanwhile.
	player.global_position = at
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	var spot := at + Vector3(0, 0.05, -3.0)
	foe.global_position = spot
	foe.set_physics_process(false)
	player.target = foe
	for i in 70:
		await physics_frame
	Input.action_press("block")
	await physics_frame
	Input.action_release("block")
	# it steps off to one side while he gathers
	var moved := spot + Vector3(2.2, 0, -1.5)
	var gap_at_release := -1.0
	var closest := INF
	var serial: int = rig.attack_serial
	for i in 120:
		await physics_frame
		if i == 10:
			foe.global_position = moved
		if rig.wind_left() <= 0.0 and gap_at_release < 0.0:
			gap_at_release = Vector2(foe.global_position.x - player.global_position.x, foe.global_position.z - player.global_position.z).length()
		closest = minf(closest, Vector2(foe.global_position.x - player.global_position.x, foe.global_position.z - player.global_position.z).length())
	_check("slid in on it where it had gone", closest < 1.5, "%.2f m at the release, %.2f m closest" % [gap_at_release, closest])
	_check("and cut it on arriving", rig.attack_serial - serial >= 1, "%d blows" % (rig.attack_serial - serial + 1))
	print("rogue_arms_test: %s" % ("all checks passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
