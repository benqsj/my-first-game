class_name PaleMarsh
extends Object

## The pale marsh (the user's pick B of the swamp concepts, 2026-10-25; the
## old swamp, [SwampMere], kept as it is, this a place of its own), made
## after the picture as closely as it goes (the user, the same day: "one to
## one as in the picture"): a long wet clearing running away from the way
## in, a channel of still water and puddles down its middle in brown mud,
## plank walks either side of it, moss-green ground with tufts of dry grass
## toward the trees; tall straight pale-grey trees with loose crowns of big
## rust-red leaves standing in rows down both sides, the far ones lost in
## white mist, dark firs at its far end; a small plank hut on stilts with a
## porch on the right. Ashen's pale light ([method Dungeon._marsh_look]).
##
## The ground's hollows, the water and the wading in it are the old swamp's
## ([SwampMere], [SwampWade]); the ground's colour is this place's own (no
## photographed mud: flat colours as the picture's); the trees, walks, hut
## and grass are low poly (`pale_marsh_lowpoly.glb`, Blender
## `vepxis-art/world/pale_marsh_lowpoly.py`).

const KIT := "res://assets/dungeon/pale_marsh/pale_marsh_lowpoly.glb"
## The water in the room's own frame, as fractions of its width and length:
## [x, z, half-width, half-length, yaw, depth share]: the channel down the
## middle, a little crooked, and puddles beside it.
const POOLS := [
	[0.00, 0.36, 0.07, 0.11, 0.05, 0.3],
	[0.02, 0.13, 0.05, 0.08, -0.08, 0.3],
	[-0.01, -0.10, 0.06, 0.09, 0.06, 0.3],
	[0.03, -0.34, 0.045, 0.07, -0.05, 0.28],
	[0.10, 0.20, 0.035, 0.03, 0.4, 0.2],
	[-0.09, -0.02, 0.03, 0.025, -0.3, 0.2],
	[0.12, -0.24, 0.03, 0.03, 0.2, 0.2],
]
const TREES := ["PTree0", "PTree1", "PTree2", "PTree3", "PTree4", "PTree5"]
## Where the plank walks run (x), either side of the channel.
const WALK_X := 6.2
## The hut: on the right, facing the clearing.
const HUT_AT := Vector3(10.6, 0.0, -2.0)
const HUT_S := 1.3

## The ground's own colours (the picture's): moss green toward the trees,
## brown mud in the middle, dark and wet by the water.
const GROUND := """
shader_type spatial;
render_mode cull_back;
uniform vec4 moss : source_color = vec4(0.33, 0.37, 0.26, 1.0);
uniform vec4 moss_dry : source_color = vec4(0.42, 0.42, 0.31, 1.0);
uniform vec4 mud : source_color = vec4(0.34, 0.26, 0.20, 1.0);
uniform vec4 wet : source_color = vec4(0.22, 0.20, 0.19, 1.0);
uniform float mud_half = 5.5;
uniform vec2 centre = vec2(0.0);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz - centre;
	float n = noise(p * 0.18) * 0.6 + noise(p * 0.7) * 0.3 + noise(p * 2.3) * 0.1;
	// the trodden mud down the middle, its edge ragged
	float edge = mud_half + (n - 0.5) * 6.0 + sin(p.y * 0.11) * 1.5;
	float m = 1.0 - smoothstep(edge - 1.5, edge + 1.0, abs(p.x));
	vec3 g = mix(moss.rgb, moss_dry.rgb, smoothstep(0.45, 0.75, noise(p * 0.35 + 7.0)));
	vec3 c = mix(g, mud.rgb * (0.9 + 0.2 * n), m);
	// dark where the ground dips toward the water
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""

static var _kit: Node3D


static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	_ready_kit()
	var pools := _pools(w, l)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	var ground := ShaderMaterial.new()
	var gs := Shader.new()
	gs.code = GROUND
	ground.shader = gs
	ground.set_shader_parameter("centre", Vector2(room.global_position.x, room.global_position.z))
	var gw := w + 44.0
	var gl := l + 44.0
	SwampMere._ground(room, ground, gw, gl, pools, noise)
	var far := 160.0
	for side in 4:
		var size := Vector3(far, 1.0, gl) if side < 2 else Vector3(gw + far * 2.0, 1.0, far)
		var at := Vector3((gw + far) * 0.5 * (-1.0 if side == 0 else 1.0), -0.5, 0.0) if side < 2 \
				else Vector3(0.0, -0.5, (gl + far) * 0.5 * (-1.0 if side == 2 else 1.0))
		d._solid(room, ground, size, at)
	d._bounds(room, w, l)
	# the water: dark, still, giving back the white sky and the trees
	var water := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SwampMere.WATER
	water.shader = sh
	water.render_priority = -100
	water.set_shader_parameter("shallow", Color(0.30, 0.30, 0.29))
	water.set_shader_parameter("deep", Color(0.07, 0.08, 0.08))
	water.set_shader_parameter("clarity", 0.18)
	water.set_shader_parameter("scum", 0.0)
	water.set_shader_parameter("gloss", 0.75)
	water.set_shader_parameter("silt_amount", 0.25)
	water.set_shader_parameter("silt", Color(0.30, 0.26, 0.22))
	water.set_shader_parameter("mud_cover", 0.0)
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
	_walks(room, l, rng)
	var hut := _piece(room, "PHut", HUT_AT, 0.0, HUT_S)
	TerracePlaces._box(hut, Vector3(3.4, 4.4, 3.8), Vector3(0.0, 2.2, 0.0))
	_grass(room, w, l, pools, noise, rng)
	SwampMere._outer_mist(room, w, l, rng, 0.55)
	TerracePlaces._motes(room, w, l, Color(0.92, 0.92, 0.9), 100)
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


## The trees in rows down both sides of the clearing, as in the picture,
## reaching on far past it into the mist; across the far end too, and dark
## firs behind them there.
static func _woods(room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var far_at: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var row := 0
		var x := 13.0
		while x < 46.0:
			var step := 5.0 + float(row) * 0.5
			var z := l * 0.5 + 12.0
			while z > -l * 0.5 - 45.0:
				var at := Vector3(side * (x + rng.randf_range(-1.0, 1.0)), 0.0, z + rng.randf_range(-1.0, 1.0))
				# the hut's place left clear
				if at.distance_to(HUT_AT) > 4.5:
					if row < 3:
						_tree(room, at, rng, row < 2 and absf(at.z) < l * 0.5 + 2.0)
					else:
						far_at.append(_tf(at, rng))
				z -= step
			x += rng.randf_range(4.6, 6.0)
			row += 1
	# across the far end, beyond the way on, the rows closing in, then firs
	for k in 4:
		var z := -l * 0.5 - 6.0 - float(k) * 5.0
		var x := -12.0
		while x < 12.0:
			var at := Vector3(x + rng.randf_range(-1.0, 1.0), 0.0, z + rng.randf_range(-1.0, 1.0))
			if k == 0:
				_tree(room, at, rng, false)
			else:
				far_at.append(_tf(at, rng))
			x += rng.randf_range(3.5, 5.0)
	_many(room, "PTreeFar", far_at)
	var firs: Array[Transform3D] = []
	for k in 40:
		var at := Vector3(rng.randf_range(-40.0, 40.0), 0.0, -l * 0.5 - rng.randf_range(28.0, 70.0))
		firs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.9, 1.4)), at))
	_many(room, "PFir1", firs)
	# a few trees inside the edges, as the picture's near ones
	for at: Vector3 in [Vector3(-10.5, 0.0, 22.0), Vector3(10.8, 0.0, 19.0), Vector3(-11.5, 0.0, 6.0), Vector3(-10.2, 0.0, -11.0)]:
		_tree(room, at + Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6)), rng, true)


static func _tree(room: Node3D, at: Vector3, rng: RandomNumberGenerator, solid: bool) -> void:
	var t := _piece(room, String(TREES[rng.randi() % TREES.size()]), at,
			rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.15))
	if solid:
		TerracePlaces._post_col(t, 0.4 / t.scale.x, 6.0)


static func _tf(at: Vector3, rng: RandomNumberGenerator) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.9, 1.2)), at)


## The far trees as one MultiMesh (each its own a draw too many): `piece`'s
## mesh with its materials, at `where`, no shadows.
static func _many(room: Node3D, piece: String, where: Array[Transform3D]) -> void:
	var src := _kit.get_node_or_null(piece) as MeshInstance3D
	if src == null:
		src = _kit.find_child(piece, true, false) as MeshInstance3D
	if src == null or where.is_empty():
		return
	var mesh := (src.mesh as ArrayMesh).duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		mesh.surface_set_material(s, src.get_surface_override_material(s))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = where.size()
	for k in where.size():
		mm.set_instance_transform(k, where[k])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)


## The plank walks either side of the channel, in lengths with gaps, a
## little crooked; walked on (their tops at +0.22, a box under each).
static func _walks(room: Node3D, l: float, rng: RandomNumberGenerator) -> void:
	for side: float in [-1.0, 1.0]:
		var z := l * 0.5 - 2.0
		while z > -l * 0.5 + 4.0:
			var n := rng.randi_range(2, 4)
			for k in n:
				var at := Vector3(side * WALK_X + rng.randf_range(-0.15, 0.15), 0.0, z - 2.0)
				var b := _piece(room, "PWalk", at, rng.randf_range(-0.04, 0.04))
				TerracePlaces._box(b, Vector3(1.3, 0.22, 4.0), Vector3(0.0, 0.11, 0.0))
				z -= 4.0
			z -= rng.randf_range(2.0, 5.0)
	# the hut's own walk to it
	var hw := _piece(room, "PWalk", HUT_AT + Vector3(-5.2, 0.0, 0.6), PI * 0.5)
	TerracePlaces._box(hw, Vector3(1.3, 0.22, 4.0), Vector3(0.0, 0.11, 0.0))


## Tufts of dry grass on the moss toward the trees and along the banks, none
## in the water, none on the trodden mud where the fight is.
static func _grass(room: Node3D, w: float, l: float, pools: Array[Dictionary], noise: FastNoiseLite,
		rng: RandomNumberGenerator) -> void:
	var tufts: Array = [[] as Array[Transform3D], [] as Array[Transform3D], [] as Array[Transform3D]]
	var placed := 0
	var tries := 0
	while placed < 420 and tries < 4000:
		tries += 1
		var at := Vector3(rng.randf_range(-w * 0.5 - 10.0, w * 0.5 + 10.0), 0.0, rng.randf_range(-l * 0.5 - 10.0, l * 0.5 + 10.0))
		if absf(at.x) < 9.0 and absf(at.x) > 3.0 and rng.randf() < 0.85:
			continue
		if absf(at.x - WALK_X) < 1.0 or absf(at.x + WALK_X) < 1.0:
			continue
		if SwampMere._height(at.x, at.z, pools, noise) < -0.005:
			continue
		tufts[rng.randi() % 3].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(1.0, 1.7)), at))
		placed += 1
	for k in 3:
		_many(room, "PTuft%d" % k, tufts[k])


static func _no_shadow(n: Node3D) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
		if g is GeometryInstance3D:
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
				"Leaves":
					mi.set_surface_override_material(s, _leaves())
				"Grass":
					mi.set_surface_override_material(s, TerracePlaces._foliage(0.08))
				"Bark", "BarkDark", "Fir":
					mi.set_surface_override_material(s, TerracePlaces._solid(0.15, 1.0, 0.9))
				_:
					mi.set_surface_override_material(s, TerracePlaces._solid(0.05, 1.0, 0.9))


## The leaves as the picture's: their own rust, not lifted, a warm light
## through them from behind (the forest's foliage shader).
static var _leaf_mat: ShaderMaterial
static func _leaves() -> ShaderMaterial:
	if _leaf_mat == null:
		_leaf_mat = TerracePlaces._foliage(0.05).duplicate() as ShaderMaterial
		_leaf_mat.set_shader_parameter("bright", 1.0)
		_leaf_mat.set_shader_parameter("backlight", Vector3(0.22, 0.12, 0.09))
	return _leaf_mat


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
