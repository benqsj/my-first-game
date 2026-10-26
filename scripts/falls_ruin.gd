class_name FallsRuin
extends Object

## The waterfall ruins ("ჩანჩქერის ნანგრევები"), low poly done richly (the
## Higgsfield concept "falls_A", 2026-10-26): an old temple's terrace on a
## cliff ledge right beside a great waterfall. Worn pale flags with moss and
## earth where some are gone; the arched colonnade on the left with ivy off
## its cornice and two heroes' statues by it; broken columns, low broken
## walls along the edges, round green trees, wet rocks; a wooden stair down
## off the near corner; the falls pouring past on the left from a high red
## cliff into the gorge far below, its spray drifting up over the edge.
##
## The shapes are `falls_lowpoly.glb` (Blender, `vepxis-art/world/falls_lowpoly.py`);
## the falls, the cliffs, the gorge and the peaks are [TerracePlaces]'s.

const KIT := "res://assets/dungeon/falls_ruin/falls_lowpoly.glb"

static var _kit: Node3D


static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	if _kit == null or not is_instance_valid(_kit):
		_kit = (load(KIT) as PackedScene).instantiate() as Node3D
		_dress(_kit)
	TerracePlaces._ready_kit()
	var hw := w * 0.5
	var hl := l * 0.5
	var slab := d._solid(room, ForestGlade._solid(0.0), Vector3(w + 4.0, 1.0, l + 4.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	for piece in ["FRBase", "FRFloor"]:
		var f := _piece(room, piece, Vector3.ZERO, 0.0)
		if f is GeometryInstance3D:
			(f as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._bounds(room, w, l)
	_ruins(room, hw, hl, rng)
	_falls(d, room, w, l, rng)


static func _dress(kit: Node3D) -> void:
	for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Leaves":
					mi.set_surface_override_material(s, TerracePlaces._foliage(0.06))
				"Flags", "Base":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.9))
				"Rock":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.45))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.25))


static func _piece(parent: Node3D, piece: String, at: Vector3, yaw: float, s: float = 1.0) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("FallsRuin: no piece " + piece)
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	parent.add_child(n)
	return n


static func _post(n: Node3D, at: Vector3, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	shape.shape = c
	shape.position = at + Vector3(0.0, h * 0.5, 0.0)
	body.add_child(shape)
	n.add_child(body)


static func _stop(n: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	n.add_child(body)


static func _ruins(room: Node3D, hw: float, hl: float, rng: RandomNumberGenerator) -> void:
	# the colonnade on the left, facing the terrace, its statues either side
	var por := _piece(room, "FRPortico", Vector3(-hw + 1.4, 0.0, -4.0), PI * 0.5)
	if por != null:
		for x: float in [-5.4, -2.0, 2.0, 5.4]:
			_post(por, Vector3(x, 0.0, 0.0), 0.75, 7.0)
	var heroes: Array = TerracePlaces.PLACE_HEROES["falls"]
	for k in 2:
		TerracePlaces._knight(room, Vector3(-hw + 2.6, 0.0, -4.0 + (-11.0 if k == 0 else 11.0)), PI * 0.5, false, String(heroes[k]))
	# columns, whole and broken, round the edges
	var cols := [["FRCol", Vector3(hw - 1.6, 0.0, 20.0)], ["FRColBroken0", Vector3(hw - 1.6, 0.0, 4.0)],
			["FRColBroken1", Vector3(hw - 1.6, 0.0, -12.0)], ["FRCol", Vector3(-16.0, 0.0, -hl + 1.6)],
			["FRColBroken0", Vector3(16.0, 0.0, -hl + 1.6)], ["FRColBroken1", Vector3(-hw + 1.8, 0.0, 24.0)]]
	for c: Array in cols:
		var col := _piece(room, String(c[0]), c[1], rng.randf_range(0.0, TAU))
		if col != null:
			_post(col, Vector3.ZERO, 0.75, 6.0 if c[0] == "FRCol" else 3.0)
	# low broken walls along the open edges
	var walls := [[Vector3(hw + 0.3, 0.0, 27.0), PI * 0.5], [Vector3(hw + 0.3, 0.0, 12.0), PI * 0.5],
			[Vector3(hw + 0.3, 0.0, -4.0), PI * 0.5], [Vector3(hw + 0.3, 0.0, -20.0), PI * 0.5],
			[Vector3(-4.0, 0.0, -hl - 0.3), 0.0], [Vector3(6.0, 0.0, -hl - 0.3), 0.0],
			[Vector3(-12.0, 0.0, hl + 0.3), 0.0], [Vector3(10.0, 0.0, hl + 0.3), 0.0]]
	for k in walls.size():
		var wl: Array = walls[k]
		var seg := _piece(room, "FRWall%d" % (k % 2), wl[0], float(wl[1]) + (PI if k % 3 == 0 else 0.0))
		if seg != null:
			_stop(seg, Vector3(8.0, 1.4, 0.9), Vector3(0.0, 0.7, 0.0))
	# round green trees in the corners
	for t: Array in [["FRTree1", Vector3(hw - 4.0, 0.0, 26.0)], ["FRTree0", Vector3(-hw + 4.5, 0.0, 17.0)],
			["FRTree2", Vector3(hw - 3.5, 0.0, -27.0)], ["FRTree0", Vector3(-hw + 3.5, 0.0, -27.5)]]:
		var tree := _piece(room, String(t[0]), t[1], rng.randf_range(0.0, TAU), rng.randf_range(1.5, 1.8))
		if tree != null:
			_post(tree, Vector3.ZERO, 0.5, 4.0)
	# wet dark rocks along the falls' side, and the stair down the near corner
	for k in 7:
		var at := Vector3(-hw - rng.randf_range(0.5, 3.0), -0.3, -hl + 4.0 + float(k) * 9.0 + rng.randf_range(-2.0, 2.0))
		_piece(room, "FRRock%d" % (k % 3), at, rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.6))
	_piece(room, "FRStairs", Vector3(hw + 0.4, 0.0, hl - 6.0), PI * 0.5)


## The falls on the left from the high red cliff, the gorge below, the
## crags under the terrace and along its open sides, the peaks far off.
static func _falls(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	# the cliff the falls come over, high on the left
	for k in 8:
		TerracePlaces._crag(room, ["CliffRed1", "CliffRed0"][k % 2],
				Vector3(-hw - rng.randf_range(14.0, 20.0), rng.randf_range(10.0, 26.0), -hl - 30.0 + float(k) * (l + 60.0) / 7.0),
				rng.randf_range(1.3, 1.7), rng.randf_range(0.0, TAU), w + 2.0, l + 2.0)
	var falls_at := Vector3(-hw - 9.0, 44.0, -6.0)
	# the lip it pours over: a mass of rock behind and above it
	for k in 5:
		TerracePlaces._crag(room, ["CliffRed1", "CliffRed0"][k % 2],
				falls_at + Vector3(-rng.randf_range(8.0, 12.0), rng.randf_range(2.0, 10.0), -18.0 + float(k) * 9.0),
				rng.randf_range(1.4, 1.8), rng.randf_range(0.0, TAU), w + 2.0, l + 2.0)
	var fall := TerracePlaces._piece(room, "WFalls", falls_at, PI * 0.5, 1.0, false)
	if fall != null:
		fall.scale = Vector3(2.0, 2.4, 2.0)
	# the crags under the terrace
	for k in 7:
		TerracePlaces._crag(room, ["CliffRed1", "CliffRed0"][k % 2], Vector3(rng.randf_range(-hw, hw) * 0.5, -5.0, -hl + float(k) * l / 6.0),
				rng.randf_range(1.0, 1.3), rng.randf_range(0.0, TAU), 0.0, 0.0, false)
	TerracePlaces._edge(room, Vector3(hw + 0.9, 0.0, -hl - 1.0), Vector3(hw + 0.9, 0.0, hl + 1.0), "EdgeRuin", Vector3.RIGHT, "CliffRed0", 50.0, rng)
	TerracePlaces._edge(room, Vector3(-hw - 1.0, 0.0, -hl - 0.9), Vector3(hw + 1.0, 0.0, -hl - 0.9), "EdgeRuin", Vector3.FORWARD, "CliffRed1", 50.0, rng)
	TerracePlaces._piece(room, "WGorge", Vector3(-30.0, -105.0, 0.0), 0.0, 1.0, false)
	TerracePlaces._water(room, Vector3(-30.0, -95.0, 0.0), 900.0, {"shallow": Color(0.30, 0.62, 0.72), "deep": Color(0.12, 0.34, 0.46),
			"wave": 0.6})
	TerracePlaces._spray(room, Vector3(falls_at.x + 3.0, -98.0, falls_at.z))
	# its spray drifting up over the terrace's edge where it passes
	TerracePlaces._spray(room, Vector3(-hw - 6.0, -10.0, -6.0))
	TerracePlaces._haze(room, Vector3(-hw - 10.0, -20.0, -6.0), Vector3(60.0, 70.0, 80.0), 0.01)
	TerracePlaces._ring(room, ["Mount0", "Mount2"], 420.0, 560.0, [-1.4, -0.7, 0.0, 0.7, 1.4, 2.0], -90.0, rng, 1.2, 1.7)
	d._circling_birds(room)
	TerracePlaces._motes(room, w, l, Color(1.0, 0.95, 0.84))
