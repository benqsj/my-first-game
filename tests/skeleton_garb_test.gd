extends SceneTree

## The skeletons' clothes from the bag on a hero's own figure
## ([SkeletonGarb]): put on, each is on his figure's skeleton and what it
## covers of his own is off (his top under the coat, his breeches under the
## skirt, his hat and hair under the helm); taken off, his own is back. The
## bag's Attire lists them.
##
##   godot --headless --path . --script res://tests/skeleton_garb_test.gd [-- <hero>]

var _failed := 0


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("%s  %s  %s" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _initialize() -> void:
	_run.call_deferred()


func _shown(fig: Node, prefix: String) -> Array[String]:
	var out: Array[String] = []
	for m: MeshInstance3D in fig.find_children("ps_" + prefix + "*", "MeshInstance3D", true, false):
		if m.visible:
			out.append(String(m.name))
	return out


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var who := StringName(args[0]) if not args.is_empty() else &"tariel"
	root.get_node("Game").call("choose", who)
	var world: World = load("res://scenes/world/test_arena.tscn").instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var hero := world.player()
	var rig: Node = hero.rig
	hero.set_face((rig.get("faces") as Array).find(&"custom"))
	var look: Dictionary = rig.call("get_look")
	look["hair"] = 3
	look["hat"] = "felted"
	hero.set_look(look)
	for i in 5:
		await physics_frame
	var fig: Node3D = rig.get("_figure")
	var skel: Skeleton3D = rig.get("_figure_skel")
	_check("%s: his own top, breeches, hat and hair on first" % who,
			not _shown(fig, "top_").is_empty() and not _shown(fig, "bottom_").is_empty()
			and not _shown(fig, "hat_").is_empty() and not _shown(fig, "hair").is_empty())

	look = rig.call("get_look")
	look["sk_head"] = "sk_warrior_helm"
	look["sk_top"] = "sk_mage_top"
	look["sk_bottom"] = "sk_archer_bottom"
	hero.set_look(look)
	for i in 5:
		await physics_frame
	var on := []
	for c in skel.get_children():
		if String(c.name).begins_with(SkeletonGarb.TAG) and (c as MeshInstance3D).is_visible_in_tree():
			on.append(String(c.name))
	_check("the three pieces are on his figure", on.size() == 3, str(on))
	_check("his own top and breeches are off, his bare body under them",
			_shown(fig, "top_").is_empty() and _shown(fig, "bottom_").is_empty()
			and not _shown(fig, "topbody").is_empty() and not _shown(fig, "bottombody").is_empty(),
			"%s %s" % [_shown(fig, "top"), _shown(fig, "bottom")])
	_check("his hat and hair are off under the helm", _shown(fig, "hat_").is_empty() and _shown(fig, "hair").is_empty(),
			"%s %s" % [_shown(fig, "hat_"), _shown(fig, "hair")])

	look = rig.call("get_look")
	for slot: String in SkeletonGarb.SLOTS:
		look.erase(slot)
	hero.set_look(look)
	for i in 5:
		await physics_frame
	var left := skel.get_children().filter(func(c: Node) -> bool:
		return String(c.name).begins_with(SkeletonGarb.TAG) and not c.is_queued_for_deletion())
	_check("taken off, they are gone and his own is back", left.is_empty()
			and not _shown(fig, "top_").is_empty() and not _shown(fig, "hat_").is_empty())

	var bag := root.find_children("*", "CanvasLayer", true, false).filter(func(n: Node) -> bool: return n is Inventory)
	var listed := 0
	if not bag.is_empty():
		var inv := bag[0] as Inventory
		inv._tab = Inventory.Tab.ATTIRE
		for item: Dictionary in inv._items():
			if item.has("sk"):
				listed += 1
	_check("the bag's Attire lists the nine pieces", listed == SkeletonGarb.PIECES.size(), "%d" % listed)
	print("skeleton_garb_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
