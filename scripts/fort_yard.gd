class_name FortYard
extends Object

## The fortress's yard ("ციხის ტერასა"), low poly done richly (the Higgsfield
## concept "fort_A", 2026-10-26): the inner yard of a mountain fortress on a
## cliff over a valley. Grey-blue curtain walls with merlons and a wall walk
## round three sides, a low crenellated parapet on the fourth over the
## valley, round towers with conical slate roofs at the corners, the
## gatehouse with its great wooden gate behind the way in, blue and gold
## banners; along the walls a stone well, spear racks, straw targets, a hay
## cart, the smith's lean-to with its anvil, barrels, crates and hay; a floor
## of big grey flags. The middle of the yard is left clear to fight in.
##
## The shapes are `fort_lowpoly.glb` (Blender, `vepxis-art/world/fort_lowpoly.py`);
## the valley far below, the crag and the peaks are [TerracePlaces]'s.

const KIT := "res://assets/dungeon/fort_yard/fort_lowpoly.glb"

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
	var floor_piece := _piece(room, "FYFloor", Vector3.ZERO, 0.0)
	if floor_piece is GeometryInstance3D:
		(floor_piece as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._bounds(room, w, l)
	_walls(room, hw, hl, rng)
	_yard(d, room, hw, hl, rng)
	_beyond(d, room, w, l, rng)


## The shaders onto the Blender shapes, by their materials' names.
static func _dress(kit: Node3D) -> void:
	for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Cloth":
					mi.set_surface_override_material(s, TerracePlaces._foliage(0.12))
				"Ember":
					var em := ForestGlade._solid(0.0).duplicate() as ShaderMaterial
					em.set_shader_parameter("glow", 2.2)
					em.set_shader_parameter("glow_col", Color(1.0, 0.45, 0.15))
					mi.set_surface_override_material(s, em)
				"Water":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.15))
				"Flags":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.9))
				"Iron":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.5))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.25))
		if mi.name in ["FYFloor", "FYBanner"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _piece(parent: Node3D, piece: String, at: Vector3, yaw: float, s: float = 1.0) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("FortYard: no piece " + piece)
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	parent.add_child(n)
	return n


static func _stop(n: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	n.add_child(body)


static func _round_stop(n: Node3D, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	shape.shape = c
	shape.position.y = h * 0.5
	body.add_child(shape)
	n.add_child(body)


## A run of wall from `a` to `b` in bays of about 10 m, its yard side
## turned by `yaw` (+z of the piece into the yard); `skip` a stretch left
## out round the middle (for the gate).
static func _run(room: Node3D, piece: String, a: Vector3, b: Vector3, yaw: float, rng: RandomNumberGenerator,
		stop: Vector3, skip := 0.0) -> void:
	var along := b - a
	var length := along.length()
	var dir := along / length
	var spans: Array = [[0.0, length]]
	if skip > 0.0:
		spans = [[0.0, length * 0.5 - skip * 0.5], [length * 0.5 + skip * 0.5, length]]
	for sp: Array in spans:
		var s0: float = sp[0]
		var s1: float = sp[1]
		var n := maxi(1, int(ceil((s1 - s0) / 10.0)))
		var bay := (s1 - s0) / float(n)
		for k in n:
			var at := a + dir * (s0 + bay * (float(k) + 0.5))
			var p := piece
			if piece == "FYWall":
				p = "FYWall%d" % rng.randi_range(0, 1)
			var seg := _piece(room, p, at, yaw)
			if seg != null:
				seg.scale.x = bay / 10.0 * 1.01
				_stop(seg, Vector3(10.2, stop.y, stop.z), Vector3(0.0, stop.y * 0.5, 0.0))


static func _walls(room: Node3D, hw: float, hl: float, rng: RandomNumberGenerator) -> void:
	var wall_stop := Vector3(10.0, 9.5, 2.4)
	# the far wall (its yard side toward +z), the left (toward +x), the near
	# one with the gate in its middle (toward -z), the low parapet on the
	# right over the valley (toward -x)
	_run(room, "FYWall", Vector3(-hw - 1.0, 0.0, -hl - 1.0), Vector3(hw + 1.0, 0.0, -hl - 1.0), 0.0, rng, wall_stop)
	_run(room, "FYWall", Vector3(-hw - 1.0, 0.0, hl + 1.0), Vector3(-hw - 1.0, 0.0, -hl - 1.0), PI * 0.5, rng, wall_stop)
	_run(room, "FYWall", Vector3(hw + 1.0, 0.0, hl + 1.0), Vector3(-hw - 1.0, 0.0, hl + 1.0), PI, rng, wall_stop, 12.0)
	_run(room, "FYParapet", Vector3(hw + 0.6, 0.0, -hl - 1.0), Vector3(hw + 0.6, 0.0, hl + 1.0), -PI * 0.5, rng,
			Vector3(10.0, 1.8, 1.1))
	var gate := _piece(room, "FYGate", Vector3(0.0, 0.0, hl + 1.0), PI)
	if gate != null:
		_stop(gate, Vector3(12.4, 10.0, 4.8), Vector3(0.0, 5.0, 0.0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var at := Vector3(sx * (hw + 1.5), 0.0, sz * (hl + 1.5))
			var to_mid := -at.normalized()
			var t := _piece(room, "FYTower", at, atan2(to_mid.x, to_mid.z))
			if t != null:
				_round_stop(t, 3.7, 12.0)


static func _yard(d: Dungeon, room: Node3D, hw: float, hl: float, rng: RandomNumberGenerator) -> void:
	# banners down the walls' inner faces
	for z: float in [-hl + 8.0, -hl + 20.0, hl - 20.0, hl - 8.0]:
		_piece(room, "FYBanner", Vector3(-hw + 0.05, 6.2, z), PI * 0.5)
	for x: float in [-hw + 6.0, -hw + 16.0, hw - 16.0, hw - 6.0]:
		_piece(room, "FYBanner", Vector3(x, 6.2, -hl + 0.05), 0.0)
	for x: float in [-4.6, 4.6]:
		_piece(room, "FYBanner", Vector3(x, 8.4, hl - 1.3), PI)
	# fires either side of the gate
	for x: float in [-7.8, 7.8]:
		TerracePlaces._brazier(d, room, Vector3(x, 0.0, hl - 2.4), 3.0)
	# the well, near the gate on the left
	var well := _piece(room, "FYWell", Vector3(-hw + 9.0, 0.0, hl - 9.0), rng.randf_range(0.0, TAU))
	if well != null:
		_round_stop(well, 1.5, 2.2)
	# the smith's lean-to against the left wall, far down
	var forge := _piece(room, "FYForge", Vector3(-hw + 2.7, 0.0, -hl + 12.0), PI * 0.5)
	if forge != null:
		_stop(forge, Vector3(5.0, 3.0, 3.0), Vector3(0.0, 1.5, -0.6))
	# spear racks along the left wall
	for z: float in [-3.0, 4.0]:
		var rack := _piece(room, "FYRack", Vector3(-hw + 1.6, 0.0, z), PI * 0.5)
		if rack != null:
			_stop(rack, Vector3(2.8, 2.2, 1.0), Vector3(0.0, 1.1, 0.0))
	# straw targets along the parapet on the right, facing the yard
	for z: float in [-6.0, 0.0, 6.0]:
		var tg := _piece(room, "FYTarget", Vector3(hw - 2.6, 0.0, z), -PI * 0.5 + rng.randf_range(-0.15, 0.15))
		if tg != null:
			_stop(tg, Vector3(1.6, 2.2, 0.9), Vector3(0.0, 1.1, 0.0))
	# the hay cart and hay by the gate on the right; hay by the forge
	var cart := _piece(room, "FYCart", Vector3(hw - 8.0, 0.0, hl - 5.0), 0.35)
	if cart != null:
		_stop(cart, Vector3(4.2, 2.0, 2.0), Vector3(0.6, 1.0, 0.0))
	for at: Vector3 in [Vector3(hw - 3.2, 0.0, hl - 3.5), Vector3(-hw + 3.0, 0.0, -hl + 5.0), Vector3(hw - 3.0, 0.0, -hl + 3.5)]:
		var hay := _piece(room, "FYHay", at, rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.2))
		if hay != null:
			_round_stop(hay, 1.2, 1.4)
	# barrels and crates in clusters at the corners
	for spot: Vector3 in [Vector3(-hw + 3.0, 0.0, hl - 3.5), Vector3(hw - 3.5, 0.0, -hl + 8.0), Vector3(-hw + 5.5, 0.0, -hl + 3.0)]:
		for k in 4:
			var at := spot + Vector3(rng.randf_range(-1.6, 1.6), 0.0, rng.randf_range(-1.6, 1.6))
			var piece := "FYBarrel" if k % 2 == 0 else "FYCrate"
			var thing := _piece(room, piece, at, rng.randf_range(0.0, TAU), rng.randf_range(0.95, 1.1))
			if thing != null:
				_round_stop(thing, 0.5, 1.0)
	d._circling_birds(room)
	TerracePlaces._motes(room, hw * 2.0, hl * 2.0, Color(1.0, 0.9, 0.7))


## Under and round it: the crag, the valley far below on the right, the
## peaks beyond ([TerracePlaces]'s pieces).
static func _beyond(_d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	for k in 8:
		TerracePlaces._crag(room, ["Cliff1", "Cliff0"][k % 2], Vector3(rng.randf_range(-hw, hw) * 0.4, -6.0, -hl + float(k) * l / 7.0),
				rng.randf_range(1.1, 1.4), rng.randf_range(0.0, TAU), 0.0, 0.0, false)
	TerracePlaces._piece(room, "FValley", Vector3(180.0, -95.0, -80.0), 0.3, 1.6, false)
	var grow := TerracePlaces._grow()
	for k in int(70 * grow):
		var at := Vector3(rng.randf_range(60.0, 320.0), -90.0, rng.randf_range(-260.0, 140.0))
		TerracePlaces._piece(room, "Pine%d" % (k % 3), at, rng.randf_range(0.0, TAU), rng.randf_range(2.0, 3.0), false)
	TerracePlaces._ring(room, ["Mount2", "Mount0"], 480.0, 620.0, [0.35, 0.8, 1.25, 1.7, 2.15, -0.1], -90.0, rng, 1.4, 2.0)
	TerracePlaces._ring(room, ["Mount1"], 330.0, 400.0, [0.6, 1.4, 2.0], -95.0, rng, 1.2, 1.5)
	TerracePlaces._haze(room, Vector3(200.0, -60.0, -80.0), Vector3(600.0, 60.0, 600.0), 0.004)
