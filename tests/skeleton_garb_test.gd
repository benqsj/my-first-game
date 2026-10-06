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


## His own breeches and boots are drawn apart now, as SkGarb_legs and
## SkGarb_feet on his skeleton; worn, they stand for `ps_bottom_*`.
func _tris(m: Mesh) -> int:
	var n := 0
	for k in m.get_surface_count():
		var arr := m.surface_get_arrays(k)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		n += floori(((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3.0)
	return n


func _own(skel: Skeleton3D, part: String) -> bool:
	var m := skel.get_node_or_null(SkeletonGarb.TAG + part) as MeshInstance3D
	return m != null and m.visible and not m.is_queued_for_deletion()


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
			not _shown(fig, "top_").is_empty() and _own(skel, "legs") and _own(skel, "feet")
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
		if String(c.name).begins_with(SkeletonGarb.TAG + "sk_") and (c as MeshInstance3D).is_visible_in_tree():
			on.append(String(c.name))
	_check("the three pieces are on his figure", on.size() == 3, str(on))
	_check("his own top is off under the coat, his breeches and boots on under the skirt",
			_shown(fig, "top_").is_empty() and not _shown(fig, "topbody").is_empty()
			and _own(skel, "legs") and _own(skel, "feet") and _shown(fig, "bottombody").is_empty(),
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
		return String(c.name).begins_with(SkeletonGarb.TAG + "sk_") and not c.is_queued_for_deletion())
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
	var pictures := 0
	for id: String in SkeletonGarb.PIECES:
		pictures += 1 if ResourceLoader.exists(Inventory.GARB_ART + id + ".png") else 0
	_check("each has a picture of its own", pictures == SkeletonGarb.PIECES.size(), "%d" % pictures)
	if not bag.is_empty():
		var inv := bag[0] as Inventory
		look = rig.call("get_look")
		look["sk_top"] = "sk_warrior_top"
		hero.set_look(look)
		var body: Dictionary = (inv._equipped()[1] as Array)[2]
		_check("the body's socket beside him shows what he wears", String(body.get("sk", "")) == "sk_warrior_top", str(body))
		inv._take_off_slot("sk_top")
		_check("clicked, it comes off", not (rig.call("get_look") as Dictionary).has("sk_top"))
		# his own clothes, piece by piece, beside the skeletons'
		var own: Array = inv._all_items().filter(func(it: Dictionary) -> bool: return it.has("own"))
		var with_pics := own.filter(func(it: Dictionary) -> bool: return ResourceLoader.exists(String(it.pic)))
		_check("his own coats, breeches and hats are things in the bag, each with its picture",
				own.size() >= 6 and with_pics.size() == own.size(), "%d, %d with pictures" % [own.size(), with_pics.size()])
		look = rig.call("get_look")
		look["sk_top"] = "sk_archer_top"
		hero.set_look(look)
		var items := inv._items()
		_check("what he wears is not in the bag", items.all(func(it: Dictionary) -> bool: return not it.get("worn", false)))
		for i in items.size():
			if String(items[i].get("own", "")) == "top" and String(items[i].key) != String(look.get("top", "")):
				inv._use(i)
				break
		var now: Dictionary = rig.call("get_look")
		_check("one of his own coats put on takes the skeleton's off", not now.has("sk_top")
				and String(now.get("top", "")) != String(look.get("top", "")), str(now.get("top")))
	for id: String in SkeletonGarb.PIECES:
		var cloth := SkeletonGarb.cloth_of(id)
		_check("%s: cloth only, no bones in it" % id, cloth != null and cloth.get_surface_count() >= 1)
	if not bag.is_empty():
		var inv2 := bag[0] as Inventory
		# a cloak and the like taken off from its socket, his top too
		look = rig.call("get_look")
		var cloaks: Array = (look.get("extras", []) as Array).filter(func(x: Variant) -> bool: return Inventory._is_cloth(String(x)))
		if not cloaks.is_empty():
			inv2._take_off_slot("cloak")
			var after: Array = rig.call("get_look").get("extras", [])
			_check("his cloak comes off from its socket", not after.has(cloaks[0]), str(after))
		inv2._take_off_slot("sk_top")
		_check("his own coat comes off from its socket, his bare body under it",
				_shown(fig, "top_").is_empty() and not _shown(fig, "topbody").is_empty())
	for id: String in ["sk_warrior_top", "sk_archer_bottom"]:
		var mesh := SkeletonGarb.cloth_of(id)
		var n := 0
		for k in mesh.get_surface_count():
			n += (mesh.surface_get_arrays(k)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		var whole := 0
		var src := (load(SkeletonGarb.KIT) as PackedScene).instantiate().find_child(String(SkeletonGarb.PIECES[id][1]), true, false) as MeshInstance3D
		for k in src.mesh.get_surface_count():
			whole += (src.mesh.surface_get_arrays(k)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		_check("%s: less of it worn than the kit has (no hands, no boots)" % id, n > 0 and n < whole, "%d of %d" % [n, whole])
	# his legs and feet apart: breeches without their feet, his boots alone
	look = rig.call("get_look")
	look.erase("bare_bottom")
	look.erase("feet")
	hero.set_look(look)
	for i in 3:
		await physics_frame
	var parts := skel.get_children().filter(func(c: Node) -> bool:
		return String(c.name) in [SkeletonGarb.TAG + "legs", SkeletonGarb.TAG + "feet"] and not c.is_queued_for_deletion())
	_check("his breeches and his boots are drawn apart", parts.size() == 2 and _shown(fig, "bottom").is_empty(),
			"%d parts, %s" % [parts.size(), _shown(fig, "bottom")])
	# every breeches of his: shoes cut up to the knee where they go so high
	var report := []
	var shoeless := []
	for m: MeshInstance3D in fig.find_children("ps_bottom_*", "MeshInstance3D", true, false):
		var f := SkeletonGarb._part_of(m.mesh, m.skin, skel, "feet")
		var l := SkeletonGarb._part_of(m.mesh, m.skin, skel, "legs")
		report.append("%s %d/%d%s" % [String(m.name).trim_prefix("ps_bottom_"), _tris(f), _tris(l),
				" tall" if f.get_meta(&"shaft", false) else ""])
		if _tris(f) == 0:
			shoeless.append(String(m.name))
	_check("each of his breeches has its shoes to cut away", shoeless.is_empty(), "%s | %s" % [shoeless, report])
	look = rig.call("get_look")
	look["sk_feet"] = "sk_archer_boots"
	hero.set_look(look)
	for i in 3:
		await physics_frame
	var feet_now := skel.get_children().filter(func(c: Node) -> bool:
		return not c.is_queued_for_deletion() and String(c.name) in [SkeletonGarb.TAG + "feet", SkeletonGarb.TAG + "sk_archer_boots"])
	_check("in the skeleton's boots, his own are off", feet_now.size() == 1
			and String(feet_now[0].name) == SkeletonGarb.TAG + "sk_archer_boots", str(feet_now.map(func(c: Node) -> String: return String(c.name))))
	# sandals and wraps made over his bare feet (UnderGarb)
	for kind: String in UnderGarb.FOOTWEAR:
		look = rig.call("get_look")
		look.erase("sk_feet")
		look["feet"] = kind
		hero.set_look(look)
		for i in 3:
			await physics_frame
		var shoes := skel.get_node_or_null(SkeletonGarb.TAG + "shoes") as MeshInstance3D
		_check("%s on his bare feet" % kind, shoes != null and shoes.mesh != null and shoes.mesh.get_surface_count() == 1
				and _tris(shoes.mesh) > 20 and _own(skel, "feet"), str(_tris(shoes.mesh)) if shoes != null else "none")
	print("skeleton_garb_test: %s" % ("all passed" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)
