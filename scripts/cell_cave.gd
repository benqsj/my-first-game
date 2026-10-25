class_name CellCave
extends RefCounted

## The prisoners' room as cells cut into a cave (the user's word, 2026-10-25:
## a ceiling over it, really a cave's cells; Ashen's light, [method
## Dungeon._ashen_look]). High-end low poly as the forest and the crypt: the
## pieces in `cell_cave_lowpoly.glb` (Blender,
## `vepxis-art/world/cell_cave_lowpoly.py`), built in room space.
##
## A long cave under a low rough roof hung with stalactites; the sky shows
## through three holes in it, the light coming down through them in shafts.
## Four cells cut into each long wall, round-headed, barred with iron; straw,
## bones and buckets in them. Timber frames hold the roof up across the room,
## a torch on each post, chains and the orcs' rags hanging from the beams. The
## living man is in the second cell on the right ([RestSpot] frees him: his
## gate goes up).

const DIR := "res://assets/dungeon/cell_cave/"
const KIT := DIR + "cell_cave_lowpoly.glb"
## The same numbers as the Blender script's.
const WALL_X := 16.6
const BARS_X := 16.7
const CELLS := [16.0, 7.5, -1.0, -9.5]
const CELL_D := 3.4
const HOLES := [Vector3(-3.0, 12.0, 2.0), Vector3(4.0, 1.0, 2.3), Vector3(-2.0, -10.0, 1.9)]
## The living man's cell: the right wall, the second.
const LIVING := 1
## The timber frames across the room (z), their posts at ±POST_X.
const FRAMES := [11.75, 3.25, -5.25]
const POST_X := 14.8
const POST_H := 7.4

static var _kit: Node3D


## Builds it in `room`; gives back the living man's cell: {"at": where he
## sits, "gate": the bars that go up}.
static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> Dictionary:
	_ready_kit()
	# the floor walked on: a box at 0, the drawn rock over it (+0.01..+0.05)
	var slab := d._solid(room, TerracePlaces._solid(0.0), Vector3(w + 2.0, 1.0, l + 2.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	d._bounds(room, w, l)
	var ground := _piece(room, "PGround", Vector3.ZERO)
	_shadows(ground, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for name: String in ["PWallL", "PWallR", "PWallFar", "PWallNear", "PRoof"]:
		_shadows(_piece(room, name, Vector3.ZERO), GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED)
	var living := {}
	for k in CELLS.size():
		for side: float in [-1.0, 1.0]:
			var z: float = CELLS[k]
			var inside := Vector3(side * (BARS_X + CELL_D * 0.5), 0.0, z)
			if side > 0.0 and k == LIVING:
				var gate := _piece(room, "PGate", Vector3(side * BARS_X, 0.0, z))
				living = {"at": Vector3(side * (BARS_X + 1.3), 0.0, z), "gate": gate}
				_piece(room, "PStraw", inside + Vector3(side * 0.4, 0.0, 0.6), rng.randf_range(0.0, TAU))
				_piece(room, "PBucket", inside + Vector3(side * 0.9, 0.0, -1.0))
				continue
			_piece(room, "PBars", Vector3(side * BARS_X, 0.0, z))
			_piece(room, "PStraw", inside + Vector3(side * 0.3, 0.0, rng.randf_range(-0.5, 0.5)), rng.randf_range(0.0, TAU))
			# the dead in most of them
			if rng.randf() < 0.75:
				OrcSpoils._bone_heap(d, room, inside + Vector3(side * 0.2, 0.0, rng.randf_range(-0.4, 0.4)), rng)
			if rng.randf() < 0.5:
				_piece(room, "PBucket", inside + Vector3(side * 0.9, 0.0, rng.randf_range(-1.0, 1.0)))
	_frames(d, room, rng)
	OrcSpoils._materials()
	OrcSpoils._blood(d, room, w, l, 8, rng)
	TerracePlaces._motes(room, w, l, Color(0.86, 0.88, 0.92), 90)
	# the light's shafts: a white haze under each hole, lit where the sun gets
	# in (the hole's shaft leans with the sun: [method Dungeon._ashen_look])
	for hole: Vector3 in HOLES:
		TerracePlaces._haze(room, Vector3(hole.x - 1.2, 4.6, hole.y - 2.0), Vector3(hole.z * 3.0, 10.0, hole.z * 3.4), 0.022)
	return living


static func _frames(d: Dungeon, room: Node3D, rng: RandomNumberGenerator) -> void:
	for z: float in FRAMES:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(side * POST_X, 0.0, z)
			var post := _piece(room, "PPost", at, PI * 0.5)
			TerracePlaces._post_col(post, 0.3, POST_H)
			# a torch on the post, on the room's side
			var face := Vector3(-side * 0.24, 2.7, 0.0)
			_piece(room, "PSconce", at + face, 0.0 if side < 0.0 else PI)
			var tip := at + face + Vector3(-side * 0.3, 0.45, 0.0)
			CryptTomb._flames(room, tip, [Vector3.ZERO], Color(1.0, 0.62, 0.3), false, 1.6)
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.64, 0.36)
			lamp.light_energy = 3.2
			lamp.omni_range = 11.0
			lamp.position = tip + Vector3(-side * 0.3, 0.3, 0.0)
			# no shadow of its own: eight lamps each redrawing the place six
			# times over are the frame's cost ([Graphics])
			lamp.set_meta(&"designed_shadow", false)
			room.add_child(lamp)
		_piece(room, "PBeam", Vector3(0.0, POST_H + 0.24, z))
		# chains and rags off the beam, not over the middle's fight
		for k in 3:
			var x := rng.randf_range(4.0, 13.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			var long := rng.randf() < 0.4
			_piece(room, "PChainLong" if long else "PChain", Vector3(x, POST_H, z), rng.randf_range(0.0, TAU))
		if rng.randf() < 0.7:
			var x := rng.randf_range(6.0, 12.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			_piece(room, "PRag", Vector3(x, POST_H + 0.24, z + 0.25), PI * 0.5)


# ---------------------------------------------------------------- the kit
static func _ready_kit() -> void:
	if _kit != null and is_instance_valid(_kit):
		return
	_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in _kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Iron":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.5))
				"Wood", "Straw", "Cloth":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.0, 0.95))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.25, 0.92))


static func _piece(room: Node3D, piece: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("CellCave: no piece " + piece)
		return Node3D.new()
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	room.add_child(n)
	return n


static func _shadows(n: Node3D, how: GeometryInstance3D.ShadowCastingSetting) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
		if g is GeometryInstance3D:
			(g as GeometryInstance3D).cast_shadow = how
