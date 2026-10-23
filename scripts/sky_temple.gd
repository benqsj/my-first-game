class_name SkyTemple
extends Object

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
	for k in 6:
		var at := (_kit.get_node("Islet%d" % k) as Node3D).position
		_put(room, "Islet%d" % k, at)
		d._nature(room, ("CommonTree_%d" if k % 2 == 0 else "Pine_%d") % (1 + k % 5), at, 1.0 + float(k % 3) * 0.2,
				rng.randf_range(0.0, TAU), false)
	for ring in ["Curb", "Walk", "Edge"]:
		_put(room, ring, Vector3.ZERO)
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
			d._nature(room, ["Fern_1", "Grass_Common_Tall", "Grass_Wispy_Tall"][(k + j) % 3],
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
		stone.albedo_color = Color(0.70, 0.68, 0.63)
		stone.roughness = 0.9
		statue.material_override = stone
		statue.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.75), Vector3(0.0, 2.0, SHRINE_Z - 0.4))
		room.add_child(statue)
	_put(room, "CliffStairs", Vector3(0.0, 0.0, 28.5), PI)
	# grass, ferns and clover on the rim, a few rocks
	for k2 in int(160.0 * grow):
		var a2 := rng.randf_range(0.0, TAU)
		var rr := rng.randf_range(27.9, 30.6)
		var p2 := Vector3(sin(a2) * rr, 0.0, cos(a2) * rr)
		if absf(p2.x) < 2.5 and p2.z > 26.0:
			continue
		d._nature(room, ["Grass_Common_Tall", "Grass_Wispy_Tall", "Fern_1", "Grass_Common_Short", "Fern_1", "Fern_1", "Clover_1"][k2 % 7],
				p2, rng.randf_range(0.8, 1.3), rng.randf_range(0.0, TAU), false)
	for k3 in 10:
		var a3 := rng.randf_range(0.0, TAU)
		d._nature(room, "Rock_Medium_%d" % (1 + k3 % 3), Vector3(sin(a3) * 29.6, -0.2, cos(a3) * 29.6),
				rng.randf_range(0.6, 1.1), rng.randf_range(0.0, TAU), false)
	_clouds(room, rng)


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
	disc.position.y = 0.06
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(disc)


## One round floor under it all, and an unseen wall round the rim so nobody
## walks off the edge.
static func _floor_and_wall(room: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "SkyFloor"
	var floor_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 31.0
	cyl.height = 1.0
	floor_shape.shape = cyl
	floor_shape.position.y = -0.5
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


## Soft heaps of cloud round about, below the island's rim.
static func _clouds(room: Node3D, rng: RandomNumberGenerator) -> void:
	var sm := SphereMesh.new()
	sm.radial_segments = 12
	sm.rings = 7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.89, 0.86)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(0.22, 0.2, 0.2)
	mat.rim_enabled = true
	mat.rim = 0.35
	for k in 26:
		var a := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(55.0, 220.0)
		var c := Vector3(sin(a) * dist, rng.randf_range(-26.0, -8.0), cos(a) * dist)
		if c.z > 30.0 and absf(c.x) < 40.0:
			continue
		var size := rng.randf_range(6.0, 14.0)
		for j in rng.randi_range(5, 9):
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var r := size * rng.randf_range(0.7, 1.2)
			mi.scale = Vector3(r, r * 0.7, r)
			mi.position = c + Vector3(rng.randf_range(-1.5, 1.5) * size, rng.randf_range(0.0, 0.35) * size, rng.randf_range(-1.0, 1.0) * size)
			room.add_child(mi)
