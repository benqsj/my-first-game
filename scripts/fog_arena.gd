class_name FogArena
extends RefCounted

## The fog arena (the "isle" place; the user's pick A of the concept
## pictures, 2026-10-30): a round arena of marble flags ringed by columns
## under their architraves, a few broken, one fallen across the floor, on a
## high island in a sea of fog; its gate at the way in, steps down from it to
## a paved path through the pines, and the path on to four flights of stairs
## with landings over the fog, out to a fortress terrace on the near cliff;
## other islands with pines round about. One kit for all of it (the same
## marble, steps, balustrade and bronze torches), so the stairs and the arena
## are of a piece. High-end low poly as the forest: the pieces in
## `fog_arena_lowpoly.glb` (Blender, `vepxis-art/world/fog_arena_lowpoly.py`).
##
## For now only on F2's board (the user's word: a boss of the new pack is to
## be set in it later). The place is 64 by 64 only so that its round floor
## fits: an unseen wall stands round the rim ([method ThroneCourt._floor_and_rim],
## the same 30.6 m).

const KIT := "res://assets/dungeon/fog_arena/fog_arena_lowpoly.glb"
## The columns' foot (their base block is 4 m across) and how tall.
const COL_R := 2.0
const COL_H := 16.0
## The torches lit with a light of their own: the ones this near the middle.
const LIT_WITHIN := 46.0

static var _kit: Node3D


static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	_ready_kit()
	ThroneCourt._floor_and_rim(room)
	d._bounds(room, w, l)
	_piece(room, "VFloor", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_piece(room, "VArena")
	_piece(room, "VIsle")
	_piece(room, "VIsleTrees")
	_piece(room, "VPath")
	_piece(room, "VStairs")
	_piece(room, "VFar", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_piece(room, "VFarTrees", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# the columns and the fallen one's drums are walked into, not through
	for at: Vector3 in _points("VCols"):
		var post := Node3D.new()
		post.position = at
		room.add_child(post)
		TerracePlaces._post_col(post, COL_R, COL_H)
	for at: Vector3 in _points("VFallen"):
		d._blocker(room, Vector3(2.6, 2.6, 2.6), at)
	# the torches: a flame on each, a light only on the near ones
	for at: Vector3 in _points("VTorches"):
		room.add_child(d._flame(at, 0.9, 16))
		if Vector2(at.x, at.z).length() < LIT_WITHIN:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.62, 0.32)
			light.light_energy = 1.8
			light.omni_range = 10.0
			light.position = at + Vector3(0.0, 0.6, 0.0)
			room.add_child(d._fire_light(light))
	# far mountains round about, and the sea of fog under it all
	TerracePlaces._ready_kit()
	TerracePlaces._ring(room, ["Mount2", "Mount0"], 430.0, 600.0, [-2.6, -1.9, -1.2, -0.6, 0.0, 0.6, 1.2, 1.9, 2.6], -170.0,
			rng, 1.7, 2.5)
	d._cloud_layers(room, -50.0)
	d._circling_birds(room)
	TerracePlaces._motes(room, w, l, Color(1.0, 0.93, 0.78), 140)


## The places of a group of the kit's empties (torches, columns, drums).
static func _points(group: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var g := _kit.get_node_or_null(group) as Node3D
	if g == null:
		return out
	for c in g.get_children():
		if c is Node3D:
			out.append((c as Node3D).position)
	return out


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
				"Pine":
					mi.set_surface_override_material(s, TerracePlaces._foliage(0.04))
				"Marble":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.12, 1.0, 0.55))
				"Gold", "Bronze":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.1, 0.45))
				"Cliff":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.0, 1.1, 0.95))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.2))


static func _piece(room: Node3D, piece: String,
		shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("FogArena: no piece " + piece)
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D.IDENTITY
	if shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
			if g is GeometryInstance3D:
				(g as GeometryInstance3D).cast_shadow = shadow
	room.add_child(n)
	return n
