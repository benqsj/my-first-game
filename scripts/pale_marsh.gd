class_name PaleMarsh
extends Object

## The pale marsh (the user's pick B of the swamp concepts, 2026-10-25; the
## old swamp, [SwampMere], kept as it is, this a place of its own): a misty
## marsh in a wood of tall thin pale-barked trees in rust, ochre and dull red
## leaf, standing in close groups all round, the far ones lost in white mist;
## a wide shallow dark pond on one side, wet mud with pools and duckboards on
## the other, an old hut on stilts at the edge, the middle open mud for the
## fight. Ashen's pale light ([method Dungeon._marsh_look]).
##
## The ground, its hollows, the water and the wading in it are the old
## swamp's ([SwampMere], [SwampWade]); the trees, boards and hut are low poly
## (`pale_marsh_lowpoly.glb`, Blender `vepxis-art/world/pale_marsh_lowpoly.py`).
## No bushes, flowers or anything growing in the water (the user's word,
## 2026-10-23); mist only out among the trees.

const KIT := "res://assets/dungeon/pale_marsh/pale_marsh_lowpoly.glb"
## The water in the room's own frame, as fractions of its width and length:
## [x, z, half-width, half-length, yaw, depth share]: the wide pond on the
## left, wet ground with pools on the right.
const POOLS := [
	[-0.25, 0.0, 0.22, 0.42, 0.08, 0.34],
	[0.26, 0.14, 0.17, 0.26, -0.2, 0.22],
	[0.22, -0.26, 0.15, 0.16, 0.5, 0.22],
	[0.06, 0.36, 0.10, 0.07, 0.2, 0.2],
]
const TREES := ["PTree0", "PTree1", "PTree2", "PTree3", "PTree4"]

static var _kit: Node3D


static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	_ready_kit()
	var pools := _pools(w, l)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	# the ground: grey-brown mud and dry ochre moss, no green to speak of
	var ground := d._ground_mat()
	ground.set_shader_parameter("grass_a", Color(0.34, 0.31, 0.22))
	ground.set_shader_parameter("grass_b", Color(0.42, 0.38, 0.26))
	ground.set_shader_parameter("earth", Color(0.27, 0.23, 0.18))
	ground.set_shader_parameter("moss", Color(0.32, 0.31, 0.21))
	ground.set_shader_parameter("leaves", Color(0.40, 0.25, 0.15))
	ground.set_shader_parameter("path_amount", 0.0)
	ground.set_shader_parameter("bare_from", 0.40)
	ground.set_shader_parameter("mud", 1.0)
	var gw := w + 44.0
	var gl := l + 44.0
	SwampMere._ground(room, ground, gw, gl, pools, noise)
	SwampMere._mud_bed(d, room, gw, gl, pools, noise)
	SwampMere._mud_skin(d, room, w, l, pools, noise)
	var far := 160.0
	for side in 4:
		var size := Vector3(far, 1.0, gl) if side < 2 else Vector3(gw + far * 2.0, 1.0, far)
		var at := Vector3((gw + far) * 0.5 * (-1.0 if side == 0 else 1.0), -0.5, 0.0) if side < 2 \
				else Vector3(0.0, -0.5, (gl + far) * 0.5 * (-1.0 if side == 2 else 1.0))
		d._solid(room, ground, size, at)
	d._bounds(room, w, l)
	# the water: dark, still, the pale sky in it
	var water := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SwampMere.WATER
	water.shader = sh
	water.render_priority = -100
	water.set_shader_parameter("shallow", Color(0.44, 0.45, 0.42))
	water.set_shader_parameter("deep", Color(0.08, 0.10, 0.10))
	water.set_shader_parameter("clarity", 0.24)
	water.set_shader_parameter("scum", 0.0)
	water.set_shader_parameter("gloss", 0.75)
	water.set_shader_parameter("silt_amount", 0.2)
	water.set_shader_parameter("mud_tex", d._photo_tex("mud"))
	water.set_shader_parameter("mud_cover", 0.06)
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 16.0, l + 16.0)
	var sheet := MeshInstance3D.new()
	sheet.mesh = plane
	sheet.material_override = water
	sheet.position = Vector3(0.0, SwampMere.SURFACE, 0.0)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(sheet)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(w + 30.0, 30.0, l + 30.0)
	probe.position = Vector3(0.0, 2.0, 0.0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.max_distance = 120.0
	room.add_child(probe)
	_woods(room, w, l, rng)
	_boards(room, w, l)
	# the old hut on stilts at the right edge, facing the clearing
	var hut := _piece(room, "PHut", Vector3(w * 0.5 - 3.2, 0.0, -l * 0.08), PI * 0.5)
	TerracePlaces._box(hut, Vector3(4.6, 4.6, 4.4), Vector3(0.0, 2.3, 0.4))
	SwampMere._outer_mist(room, w, l, rng, 0.55)
	TerracePlaces._motes(room, w, l, Color(0.92, 0.92, 0.9), 120)
	# the water under the feet: slowed, splashing, a wake
	var wade := SwampWade.new()
	wade.name = "SwampWade"
	wade.pools = pools
	wade.noise = noise
	wade.water = water
	room.add_child(wade)


static func _pools(w: float, l: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Array in POOLS:
		out.append({"at": Vector2(p[0] * w, p[1] * l), "a": p[2] * w, "b": p[3] * l, "yaw": p[4],
				"depth": p[5], "water": SwampMere.SURFACE})
	return out


## The pale trees: groups close round the clearing in three rows and a few
## inside its edges, then the far wood as one MultiMesh, lost in the mist.
static func _woods(room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	for row in 3:
		var out := 2.0 + float(row) * 5.5
		var step := 4.6 + float(row) * 1.0
		for side in 4:
			var long := (l if side < 2 else w) + out * 2.0
			var n := int(long / step)
			for k in n:
				var along := -long * 0.5 + (float(k) + rng.randf_range(0.2, 0.8)) * step
				var at := Vector3.ZERO
				match side:
					0: at = Vector3(-w * 0.5 - out, 0.0, along)
					1: at = Vector3(w * 0.5 + out, 0.0, along)
					2: at = Vector3(along, 0.0, -l * 0.5 - out)
					_: at = Vector3(along, 0.0, l * 0.5 + out)
				if side == 3 and absf(at.x) < 7.0 and row == 0:
					continue
				at += Vector3(rng.randf_range(-1.4, 1.4), 0.0, rng.randf_range(-1.4, 1.4))
				_tree(room, at, rng, row == 0)
	# a few groups inside the edges, clear of the portals and the way in
	for g: Vector3 in [Vector3(-0.42, 0.0, -0.18), Vector3(-0.40, 0.0, 0.30), Vector3(0.42, 0.0, 0.36),
			Vector3(-0.08, 0.0, -0.46)]:
		var c := Vector3(g.x * w, 0.0, g.z * l)
		for k in rng.randi_range(2, 3):
			_tree(room, c + Vector3(rng.randf_range(-1.8, 1.8), 0.0, rng.randf_range(-1.8, 1.8)), rng, true)
	_far_wood(room, w, l, rng, 380, 16.0, 120.0)


static func _tree(room: Node3D, at: Vector3, rng: RandomNumberGenerator, solid: bool) -> void:
	var t := _piece(room, String(TREES[rng.randi() % TREES.size()]), at, rng.randf_range(0.0, TAU),
			rng.randf_range(0.85, 1.15))
	if solid:
		TerracePlaces._post_col(t, 0.45 / t.scale.x, 6.0)
	else:
		for g in t.find_children("*", "GeometryInstance3D", true, false) + [t]:
			if g is GeometryInstance3D:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _far_wood(room: Node3D, w: float, l: float, rng: RandomNumberGenerator, count: int, near: float,
		far: float) -> void:
	var src := _kit.get_node_or_null("PTreeFar") as MeshInstance3D
	if src == null:
		src = _kit.find_child("PTreeFar", true, false) as MeshInstance3D
	if src == null:
		return
	var mesh := (src.mesh as ArrayMesh).duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, src.get_surface_override_material(s))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for k in count:
		var a := rng.randf_range(0.0, TAU)
		var out := rng.randf_range(near, far)
		var at := Vector3(sin(a) * (w * 0.5 + out), 0.0, cos(a) * (l * 0.5 + out))
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), at))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)


## Duckboards over the wet ground on the right: walked on (their tops at
## +0.18, a box under each run).
static func _boards(room: Node3D, w: float, l: float) -> void:
	for run: Array in [[Vector3(0.20, 0.0, 0.22), 0.1], [Vector3(0.20, 0.0, 0.10), 0.1], [Vector3(0.30, 0.0, -0.06), 1.35],
			[Vector3(0.24, 0.0, -0.22), 0.25], [Vector3(0.24, 0.0, -0.34), 0.25]]:
		var p: Vector3 = run[0]
		var at := Vector3(p.x * w, 0.0, p.z * l)
		var b := _piece(room, "PBoards", at, float(run[1]))
		TerracePlaces._box(b, Vector3(1.4, 0.2, 6.0), Vector3(0.0, 0.08, 0.0))


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
				"Leaves", "LeavesRed":
					mi.set_surface_override_material(s, TerracePlaces._foliage(0.05))
				"Bark", "BarkDark":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.2, 1.0, 0.9))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.1, 1.0, 0.95))


static func _piece(room: Node3D, piece: String, at: Vector3, yaw: float = 0.0, s: float = 1.0) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("PaleMarsh: no piece " + piece)
		var none := Node3D.new()
		room.add_child(none)
		return none
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	room.add_child(n)
	return n
