extends SceneTree

## What the creatures drop (GEAR_SETS.md §5.7): a hero starts with his own
## first arms and what he wears, the bag lists only what he has, a creature
## now and then drops a thing he has not got, and walking over it it is his.
##
##     godot --path . --headless --script res://tests/loot_test.gd -- [hero]

var _failures := 0


func _initialize() -> void:
	# the bag as it is in play, not everything at once
	Inventory.everything = false
	var args := OS.get_cmdline_user_args()
	var hero_id := StringName(args[0]) if not args.is_empty() else &"tariel"
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", hero_id)
	var world: World = load("res://scenes/world/greybox_world.tscn").instantiate()
	root.add_child(world)
	await _wait(2)
	world.creature_think_distance = 0.0
	var player := world.player()
	var enemies := world.get_node("Enemies")
	var imp: Node3D = null
	var ark: Arkdeva = null
	for node in enemies.get_children():
		(node as Node).set_physics_process(false)
		(node as Node3D).global_position += Vector3(0.0, -50.0, 0.0)
		if node is Fighter and imp == null:
			imp = node
		elif node is Arkdeva:
			ark = node
	await _wait(90)
	var bag := player.get_node_or_null("Inventory") as Inventory
	_check("he has a bag", bag != null)
	if bag == null:
		quit(1)
		return
	print("  hero %s, carries %s" % [hero_id, str(player._owned.keys())])
	_check("he carries what he started with", not player._owned.is_empty())
	var spare := 0
	for tab: int in Inventory.LOOT_TABS:
		bag._tab = tab
		spare += bag._items().size()
	print("  in the bag besides what he wears: %d" % spare)
	_check("nothing found yet: only what he started with is his", spare <= 1, "%d" % spare)
	var drop := LootDrop.of(player)
	_check("the world drops things", drop != null)
	_check("an imp drops now and then", imp != null and LootDrop.chance_of(imp) > 0.1 and LootDrop.chance_of(imp) < 0.5,
			"%.2f" % LootDrop.chance_of(imp) if imp != null else "")
	_check("a boss always", ark != null and LootDrop.chance_of(ark) == 1.0)

	# --- A thing on the ground, and walking over it ---------------------------
	var at := player.global_position - player.global_transform.basis.z * 4.0
	drop.net_loot(at, player.get_path(), 7)
	await _wait(2)
	var lying := root.find_children("Loot*", "LootItem", true, false)
	_check("something lies on the ground for him", lying.size() == 1, "%d" % lying.size())
	if lying.size() == 1:
		var thing := lying[0] as LootItem
		var key := String(thing.item.get("loot_key", ""))
		var name := String(thing.item.get("name", ""))
		var tab := int(thing.item.get("tab", 0))
		print("  dropped: %s (%s)" % [thing.item.get("name", ""), key])
		_check("a thing he has not got", key != "" and not player.owns(key))
		await _wait(60)
		player.global_position = thing.global_position
		await _wait(40)
		_check("walked over, it is his", player.owns(key))
		_check("and gone from the ground", not is_instance_valid(thing) or thing.is_queued_for_deletion())
		var hud := player.get_node_or_null("Hud") as PlayerHud
		_check("the HUD says what it was", hud != null and hud._found == name, hud._found if hud != null else "")
		bag._tab = tab
		var listed := bag._items().any(func(it: Dictionary) -> bool: return Inventory.key_of(it) == key)
		_check("and in his bag", listed)

	# --- A boss killed beside him drops something -----------------------------
	if ark != null:
		ark.global_position = player.global_position + Vector3(3.0, 0.0, 0.0)
		world._on_creature_died(ark)
		await _wait(2)
		var after := root.find_children("Loot*", "LootItem", true, false)
		_check("a boss killed beside him drops something", after.size() == 1, "%d" % after.size())

	# --- Everything found, nothing more drops ----------------------------------
	var rng := RandomNumberGenerator.new()
	var got := 0
	for i in 400:
		var item := bag.roll_loot(rng)
		if item.is_empty():
			break
		player.gain(String(item.loot_key))
		got += 1
	print("  found all the rest in %d drops" % got)
	_check("with everything found, nothing more", bag.roll_loot(rng).is_empty())
	quit(1 if _failures else 0)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s - %s %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failures += 1
