class_name SkyTemple
extends Object

## (No grass and no flowers on it: the user's word, 2026-10-23; ferns,
## bushes and stones only.)
## The island in the sky as the user chose it (2026-10-23, from the concept
## pictures: the second's round temple floor, the first's sea of cloud): a
## round arena of old paving on a red-brown floating rock, a ring of ionic
## columns, some broken, torn red banners, a shrine at the far end with a
## knight in stone, grass and ferns on the rim, little islets round about.
##
## The models are `assets/dungeon/sky_temple/sky_temple.glb`, made by
## `vepxis-art/world/sky_temple.py` (Blender, run in the background); the
## statue is the knight baked into one mesh (`statue.res`,
## `_shots_tmp/sky/bake_statue.gd`). The paving is one shader on a disc.
## How much grows on the rim follows the graphics setting.

const KIT := "res://assets/dungeon/sky_temple/sky_temple.glb"
const STATUE := "res://assets/dungeon/sky_temple/statue.res"
## Radii (m): the paving, the ring the columns stand on, the unseen wall.
const PAVING_R := 21.6
const COLUMN_R := 24.8
const WALL_R := 28.6
const SHRINE_Z := -28.6
const WALL_H := 12.0
## The walk round the paving, and the floor's top there (the feet stand on
## what is drawn: the user's word, 2026-10-23, they sank into it).
const WALK_TOP := 0.13
const WALK_R := 27.2
## The islets (sky_temple.py) and how wide each one's top is.
const ISLETS := 8
const ISLET_R: Array[float] = [9.0, 7.5, 6.0, 8.0, 6.5, 5.0, 11.0, 10.0]

const PAVING := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float radius = 21.6;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * radius;
	float r = length(p);
	if (r > radius) { discard; }
	float a = atan(p.y, p.x) + 3.14159265;
	// courses round the middle, each cut into stones about 1.7 m long
	float course = 1.45;
	float ci = floor(r / course);
	float fr = fract(r / course);
	float n_st = max(6.0, floor(6.2831853 * (ci + 0.5) * course / 1.7));
	float sa = a / 6.2831853 * n_st + hash(vec2(ci, 3.0)) * 7.0;
	float si = floor(sa);
	float fa = fract(sa);
	float grout = min(min(fr, 1.0 - fr) * course, min(fa, 1.0 - fa) * 6.2831853 * max(r, 0.5) / n_st);
	float g = smoothstep(0.03, 0.09, grout);
	float h = hash(vec2(ci, si));
	vec3 stone = mix(vec3(0.60, 0.57, 0.51), vec3(0.76, 0.72, 0.64), h);
	stone *= 0.92 + 0.08 * texture(noise, wpos.xz * 0.35).r;
	// the carved bands
	float band = 0.0;
	band = max(band, 1.0 - smoothstep(0.18, 0.32, abs(r - 2.6)));
	band = max(band, 1.0 - smoothstep(0.18, 0.32, abs(r - 6.3)));
	band = max(band, 1.0 - smoothstep(0.18, 0.32, abs(r - 11.4)));
	band = max(band, 1.0 - smoothstep(0.18, 0.32, abs(r - 17.8)));
	stone = mix(stone, vec3(0.58, 0.55, 0.49), band * 0.8);
	stone = mix(stone, vec3(0.62, 0.58, 0.50), 1.0 - smoothstep(1.6, 1.75, r));
	vec3 col = mix(vec3(0.38, 0.36, 0.32), stone, g);
	// moss in the joints and in patches, more toward the edge
	float m = texture(noise, wpos.xz * 0.07).r;
	float moss = smoothstep(0.66, 0.78, m + r / radius * 0.16) * (1.0 - g * 0.5);
	moss = max(moss, (1.0 - g) * smoothstep(0.5, 0.62, m) * 0.8);
	col = mix(col, vec3(0.40, 0.52, 0.20), clamp(moss, 0.0, 1.0));
	// cracks
	float c = texture(noise, wpos.xz * 0.18 + 3.1).r;
	float crack = 1.0 - smoothstep(0.0, 0.012, abs(c - 0.5));
	col = mix(col, vec3(0.25, 0.24, 0.22), crack * 0.8 * step(0.4, texture(noise, wpos.xz * 0.03).r));
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = 0.85;
}
"""

static var _kit: Node3D


## Builds the island into `room` for dungeon `d`.
static func build(d: Dungeon, room: Node3D, rng: RandomNumberGenerator) -> void:
	if _kit == null or not is_instance_valid(_kit):
		_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	var grow := 1.0
	match Graphics.current:
		Graphics.Level.LOW:
			grow = 0.45
		Graphics.Level.MEDIUM:
			grow = 0.7
		Graphics.Level.ULTRA:
			grow = 1.6
	_put(room, "Island", Vector3.ZERO)
	for k in ISLETS:
		var at := (_kit.get_node("Islet%d" % k) as Node3D).position
		_put(room, "Islet%d" % k, at)
		_dress_islet(d, room, at, ISLET_R[k], k, rng, grow)
	for ring in ["Curb", "Walk", "Edge"]:
		var piece := _put(room, ring, Vector3.ZERO)
		if ring == "Walk":
			(piece as MeshInstance3D).material_override = _cobble_mat()
	_pebbles(d, room, rng, grow)
	_paving(room)
	_floor_and_wall(room)
	# the columns, gapped for the shrine and the way in
	var n := 32
	for k in n:
		var a := float(k) / float(n) * TAU
		var dir := Vector3(sin(a), 0.0, cos(a))
		if dir.z < -0.93 or dir.z > 0.985:
			continue
		var piece := "Column"
		if k % 9 == 4:
			piece = "ColumnBroken"
		elif k % 13 == 7:
			piece = "ColumnStump"
		var col := _put(room, piece, dir * COLUMN_R + Vector3(0.0, 0.13, 0.0), a)
		_solid_round(col, 0.62, 7.6)
		if k % 8 == 2 and piece == "Column":
			_put(room, "Banner", dir * (COLUMN_R - 0.7) + Vector3(0.0, 6.1, 0.0), a + PI)
		for j in int(roundf(2.0 * grow)):
			d._nature(room, "Fern_1",
					dir * (25.6 + float(j % 3) * 1.1) + Vector3(rng.randf_range(-0.6, 0.6), 0.13, rng.randf_range(-0.6, 0.6)),
					rng.randf_range(0.8, 1.2), rng.randf_range(0.0, TAU), false)
	# the shrine, its stairs down to the arena, the knight in it
	var shrine := _put(room, "Shrine", Vector3(0.0, 0.0, SHRINE_Z), PI)
	var block := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(9.4, WALL_H, 10.0)
	shape.shape = bs
	shape.position = Vector3(0.0, WALL_H * 0.5, -1.3)
	block.add_child(shape)
	shrine.add_child(block)
	for sx: float in [-1.0, 1.0]:
		_put(room, "ShrineColumn", Vector3(sx * 2.2, 1.9, SHRINE_Z + 2.6), 0.0, 1.1)
	if ResourceLoader.exists(STATUE):
		var statue := MeshInstance3D.new()
		statue.mesh = load(STATUE) as Mesh
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.56, 0.55, 0.52)
		stone.roughness = 0.9
		statue.material_override = stone
		statue.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * 2.1), Vector3(0.0, 2.0, SHRINE_Z - 0.6))
		room.add_child(statue)
	_put(room, "CliffStairs", Vector3(0.0, 0.0, 28.5), PI)
	# grass, ferns and clover on the rim, a few rocks
	for k2 in int(90.0 * grow):
		var a2 := rng.randf_range(0.0, TAU)
		var rr := rng.randf_range(27.9, 30.6)
		var p2 := Vector3(sin(a2) * rr, 0.0, cos(a2) * rr)
		if absf(p2.x) < 2.5 and p2.z > 26.0:
			continue
		d._nature(room, ["Fern_1", "Bush_Common", "Fern_1"][k2 % 3],
				p2, rng.randf_range(0.8, 1.3), rng.randf_range(0.0, TAU), false)
	for k3 in 10:
		var a3 := rng.randf_range(0.0, TAU)
		d._nature(room, "Rock_Medium_%d" % (1 + k3 % 3), Vector3(sin(a3) * 29.6, -0.2, cos(a3) * 29.6),
				rng.randf_range(0.6, 1.1), rng.randf_range(0.0, TAU), false)
	_cloud_sea(room)


static func _put(room: Node3D, piece: String, at: Vector3, yaw: float = 0.0, s: float = 1.0) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_error("sky temple: no " + piece)
		return Node3D.new()
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	room.add_child(n)
	return n


static func _paving(room: Node3D) -> void:
	var disc := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(PAVING_R * 2.0, PAVING_R * 2.0)
	disc.mesh = pm
	var sh := Shader.new()
	sh.code = PAVING
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("radius", PAVING_R)
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	nt.noise = fn
	nt.seamless = true
	m.set_shader_parameter("noise", nt)
	disc.material_override = m
	disc.position.y = WALK_TOP + 0.005
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(disc)


## One round floor under it all, and an unseen wall round the rim so nobody
## walks off the edge.
static func _floor_and_wall(room: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "SkyFloor"
	for part: Array in [[31.0, 0.0], [WALK_R, WALK_TOP]]:
		var floor_shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = float(part[0])
		cyl.height = 1.0
		floor_shape.shape = cyl
		floor_shape.position.y = float(part[1]) - 0.5
		body.add_child(floor_shape)
	var n := 40
	var seg := TAU * WALL_R / float(n) + 0.4
	for k in n:
		var a := float(k) / float(n) * TAU
		var s := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(seg, WALL_H, 1.0)
		s.shape = b
		s.transform = Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * WALL_R, WALL_H * 0.5, cos(a) * WALL_R))
		body.add_child(s)
	room.add_child(body)


static func _solid_round(n: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	s.shape = c
	s.position.y = height * 0.5
	body.add_child(s)
	n.add_child(body)


## The walk the columns stand on: the village's own cobbles (Poly Haven's,
## as in the town), worn, with moss in the joints toward the grass (the
## user's word, 2026-10-23: not a bare band; stones, pebbles on it).
const COBBLE := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float tiles = 0.42;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * tiles;
	vec3 c = texture(albedo_tex, uv).rgb;
	float m = texture(noise, wpos.xz * 0.05).r;
	float r = length(wpos.xz - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
	float moss = smoothstep(0.55, 0.75, m + smoothstep(24.0, 27.2, r) * 0.25);
	c = mix(c * vec3(0.95, 0.93, 0.9), c * vec3(0.55, 0.72, 0.38), moss * 0.7);
	ALBEDO = c;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = texture(rough_tex, uv).r;
}
"""

static func _cobble_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = COBBLE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("albedo_tex", load("res://assets/village/ground/cobble_diff.jpg"))
	m.set_shader_parameter("normal_tex", load("res://assets/village/ground/cobble_nor.jpg"))
	m.set_shader_parameter("rough_tex", load("res://assets/village/ground/cobble_rough.jpg"))
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	nt.noise = fn
	nt.seamless = true
	m.set_shader_parameter("noise", nt)
	return m


## Pebbles and loose stones strewn on the walk, more round the columns' feet.
static func _pebbles(d: Dungeon, room: Node3D, rng: RandomNumberGenerator, grow: float) -> void:
	var names := ["Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3", "Pebble_Round_4", "Pebble_Round_5",
			"Pebble_Square_1", "Pebble_Square_2", "Pebble_Square_3", "Pebble_Square_4", "Pebble_Square_5",
			"RockPath_Round_Small_1", "RockPath_Round_Small_2", "RockPath_Square_Small_1"]
	for k in int(220.0 * grow):
		var a := rng.randf_range(0.0, TAU)
		var near_col := rng.randf() < 0.45
		var rr := COLUMN_R + rng.randf_range(-1.6, 1.6) if near_col else rng.randf_range(22.5, 27.0)
		if near_col:
			a = roundf(a / (TAU / 32.0)) * (TAU / 32.0) + rng.randf_range(-0.05, 0.05)
		var p := Vector3(sin(a) * rr, WALK_TOP - 0.02, cos(a) * rr)
		if absf(p.x) < 3.0 and p.z > 21.0:
			continue
		d._nature(room, names[rng.randi_range(0, names.size() - 1)], p, rng.randf_range(0.7, 1.6),
				rng.randf_range(0.0, TAU), false)


## The sea of cloud all round (the user's word, 2026-10-23: not balls, cloud,
## and clouds all round): one wide sheet, its top billowing (three noises in
## the vertex shader, its normals from the same), white and warm on the tops,
## blue-grey in the hollows, rising round the island so its rock goes down
## into it, sinking toward the horizon, drifting slowly. Finer on Ultra.
const CLOUD_SEA := """
shader_type spatial;
render_mode specular_disabled, cull_disabled, diffuse_lambert_wrap;
uniform sampler2D n1 : filter_linear_mipmap, repeat_enable;
uniform sampler2D n2 : filter_linear_mipmap, repeat_enable;
uniform float amp = 12.0;
uniform vec4 top_col : source_color = vec4(0.86, 0.84, 0.80, 1.0);
uniform vec4 low_col : source_color = vec4(0.46, 0.51, 0.64, 1.0);
varying float hgt;
float h_at(vec2 p) {
	float a = textureLod(n1, p * 0.0035 + vec2(TIME * 0.0012, 0.0), 0.0).r;
	float b = textureLod(n2, p * 0.011 - vec2(0.0, TIME * 0.002), 0.0).r;
	float c = textureLod(n2, p * 0.032 + vec2(TIME * 0.003, 0.0), 0.0).r;
	return smoothstep(0.18, 0.92, a * 0.6 + b * 0.32 + c * 0.08);
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(w.xz - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
	float h = h_at(w.xz);
	float near = 1.0 - smoothstep(35.0, 130.0, d);
	float far = smoothstep(500.0, 1300.0, d);
	// under the island itself it goes down out of sight, so it never shows through the floor
	float under = 1.0 - smoothstep(29.0, 33.0, d);
	VERTEX.y += h * amp + near * 5.0 - far * 40.0 - under * 30.0;
	hgt = h;
	float e = 6.0;
	float hx = h_at(w.xz + vec2(e, 0.0));
	float hz = h_at(w.xz + vec2(0.0, e));
	NORMAL = normalize(vec3(-(hx - h) * amp / e, 1.0, -(hz - h) * amp / e));
}
void fragment() {
	ALBEDO = mix(low_col.rgb, top_col.rgb, smoothstep(0.05, 0.85, hgt));
	ROUGHNESS = 1.0;
	RIM = 0.15;
	RIM_TINT = 0.8;
}
"""

static func _cloud_sea(room: Node3D) -> void:
	var subdiv := 360
	match Graphics.current:
		Graphics.Level.LOW:
			subdiv = 150
		Graphics.Level.MEDIUM:
			subdiv = 260
		Graphics.Level.ULTRA:
			subdiv = 520
	var pm := PlaneMesh.new()
	pm.size = Vector2(1800.0, 1800.0)
	pm.subdivide_width = subdiv
	pm.subdivide_depth = subdiv
	var sh := Shader.new()
	sh.code = CLOUD_SEA
	var m := ShaderMaterial.new()
	m.shader = sh
	for pair: Array in [["n1", 0.012, 3], ["n2", 0.02, 9]]:
		var nt := NoiseTexture2D.new()
		var fn := FastNoiseLite.new()
		fn.frequency = float(pair[1])
		fn.seed = int(pair[2])
		fn.fractal_octaves = 3
		nt.noise = fn
		nt.seamless = true
		nt.width = 512
		nt.height = 512
		m.set_shader_parameter(String(pair[0]), nt)
	var sea := MeshInstance3D.new()
	sea.name = "CloudSea"
	sea.mesh = pm
	sea.material_override = m
	sea.position.y = -15.0
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the billows rise past the flat plane's box
	sea.custom_aabb = AABB(Vector3(-900.0, -60.0, -900.0), Vector3(1800.0, 90.0, 1800.0))
	room.add_child(sea)


const CLOUD := """
shader_type spatial;
render_mode specular_disabled, cull_back;
uniform vec4 top_col : source_color = vec4(0.86, 0.84, 0.80, 1.0);
uniform vec4 low_col : source_color = vec4(0.52, 0.56, 0.66, 1.0);
varying float up;
void vertex() { up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y; }
void fragment() {
	float t = smoothstep(-0.7, 0.75, up);
	ALBEDO = mix(low_col.rgb, top_col.rgb, t);
	ROUGHNESS = 1.0;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
"""

## Heaps of cloud round about, many, soft and round (the user's word,
## 2026-10-23: more of them, prettier): one draw of smooth balls, white on
## top and blue-grey under, in clusters with flat bellies; thick close under
## the rim, thinning out far off. More on Ultra, fewer on Low.
static func _clouds(room: Node3D, rng: RandomNumberGenerator) -> void:
	var count := 90
	match Graphics.current:
		Graphics.Level.LOW:
			count = 45
		Graphics.Level.MEDIUM:
			count = 70
		Graphics.Level.ULTRA:
			count = 140
	var xforms: Array[Transform3D] = []
	var made := 0
	var tries := 0
	while made < count and tries < count * 4:
		tries += 1
		var band := rng.randf()
		var dist := 0.0
		var y := 0.0
		if band < 0.35:
			dist = rng.randf_range(44.0, 80.0)
			y = rng.randf_range(-26.0, -13.0)
		elif band < 0.75:
			dist = rng.randf_range(70.0, 160.0)
			y = rng.randf_range(-28.0, -6.0)
		else:
			dist = rng.randf_range(160.0, 330.0)
			y = rng.randf_range(-24.0, 6.0)
		var a := rng.randf_range(0.0, TAU)
		var c := Vector3(sin(a) * dist, y, cos(a) * dist)
		# none across the way in, where the eye looks out
		if c.z > 20.0 and absf(c.x) < 45.0 and c.y > -12.0:
			continue
		var size := rng.randf_range(5.0, 11.0) * (1.0 + dist / 300.0)
		var balls := rng.randi_range(7, 13)
		for j in balls:
			var t := float(j) / float(balls - 1) - 0.5
			var r := size * rng.randf_range(0.55, 1.0) * (1.0 - absf(t) * 0.7)
			var at := c + Vector3(t * size * 3.6 + rng.randf_range(-0.4, 0.4) * size,
					r * 0.18 + rng.randf_range(0.0, 0.3) * size, rng.randf_range(-0.7, 0.7) * size)
			xforms.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.72, r)), at))
		made += 1
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 18
	sm.rings = 9
	var sh := Shader.new()
	sh.code = CLOUD
	var mat := ShaderMaterial.new()
	mat.shader = sh
	sm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Clouds"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mmi)


## An islet's top: a tree or two, bushes, flowers, grass, a rock; the big
## ones a grove and a broken column.
static func _dress_islet(d: Dungeon, room: Node3D, at: Vector3, r: float, k: int, rng: RandomNumberGenerator, grow: float) -> void:
	var trees := 1 if r < 7.0 else (2 if r < 9.5 else 3)
	for t in trees:
		var off := Vector3(rng.randf_range(-0.4, 0.4) * r, 0.0, rng.randf_range(-0.4, 0.4) * r)
		d._nature(room, ["CommonTree_%d", "Pine_%d", "CommonTree_%d"][(k + t) % 3] % (1 + (k + t) % 5), at + off,
				rng.randf_range(0.9, 1.4), rng.randf_range(0.0, TAU), false)
	for b in int((4.0 + r) * grow):
		var a := rng.randf_range(0.0, TAU)
		var rr := rng.randf_range(0.2, 0.85) * r
		d._nature(room, ["Bush_Common", "Fern_1"][b % 2],
				at + Vector3(sin(a) * rr, 0.0, cos(a) * rr), rng.randf_range(0.8, 1.3), rng.randf_range(0.0, TAU), false)
	d._nature(room, "Rock_Medium_%d" % (1 + k % 3), at + Vector3(r * 0.5, -0.2, -r * 0.3), rng.randf_range(0.5, 0.9),
			rng.randf_range(0.0, TAU), false)
	if r >= 9.0:
		_put(room, "ColumnBroken", at + Vector3(-r * 0.35, 0.0, r * 0.3), rng.randf_range(0.0, TAU), 0.8)


const FALL := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
void fragment() {
	float s = texture(noise, vec2(UV.x * 1.6, UV.y * 0.12 - TIME * 0.9)).r;
	float s2 = texture(noise, vec2(UV.x * 3.1 + 0.4, UV.y * 0.2 - TIME * 1.4)).r;
	float streak = smoothstep(0.38, 0.78, s * 0.6 + s2 * 0.4);
	ALBEDO = mix(vec3(0.42, 0.66, 0.74), vec3(0.93, 0.97, 1.0), streak);
	EMISSION = ALBEDO * 0.12;
	ROUGHNESS = 0.2;
	float side = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	ALPHA = (0.55 + 0.45 * streak) * side * COLOR.a;
}
"""

## Two falls of water off the island's sides, from springs in the cliff, and
## one off the big islet, down into the cloud.
static func _falls(room: Node3D, rng: RandomNumberGenerator) -> void:
	var sh := Shader.new()
	sh.code = FALL
	var m := ShaderMaterial.new()
	m.shader = sh
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.05
	fn.seed = rng.randi()
	nt.noise = fn
	nt.seamless = true
	m.set_shader_parameter("noise", nt)
	for a: float in [1.15, -2.2]:
		var dir := Vector3(sin(a), 0.0, cos(a))
		room.add_child(_fall_ribbon(dir * 32.4 + Vector3(0.0, -2.0, 0.0), dir, 2.2, -60.0, 2.6, m))
	var big := (_kit.get_node("Islet6") as Node3D).position
	var out := Vector3(1.0, 0.0, 0.3).normalized()
	room.add_child(_fall_ribbon(big + out * 11.7 + Vector3(0.0, -0.8, 0.0), out, 1.8, big.y - 55.0, 2.0, m))


static func _fall_ribbon(from: Vector3, out: Vector3, v: float, to_y: float, w: float, mat: Material) -> MeshInstance3D:
	var pts := PackedVector3Array()
	var t := 0.0
	var p := from
	while p.y > to_y and pts.size() < 200:
		p = from + out * v * t + Vector3(0.0, -4.9 * t * t, 0.0)
		pts.append(p)
		t += 0.06
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := out.cross(Vector3.UP).normalized()
	var along := 0.0
	var n := pts.size()
	for i in n:
		if i > 0:
			along += pts[i].distance_to(pts[i - 1])
		var a := clampf(1.0 - float(i) / float(maxi(n - 1, 1)), 0.0, 1.0)
		var half := w * 0.5 * (1.0 + float(i) * 0.01)
		st.set_color(Color(1, 1, 1, a * a))
		st.set_uv(Vector2(0.0, along / 4.0))
		st.add_vertex(pts[i] - side * half)
		st.set_color(Color(1, 1, 1, a * a))
		st.set_uv(Vector2(1.0, along / 4.0))
		st.add_vertex(pts[i] + side * half)
	for i in n - 1:
		var k := i * 2
		st.add_index(k)
		st.add_index(k + 1)
		st.add_index(k + 2)
		st.add_index(k + 1)
		st.add_index(k + 3)
		st.add_index(k + 2)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
