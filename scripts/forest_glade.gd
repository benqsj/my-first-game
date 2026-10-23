class_name ForestGlade
extends Object

## The forest, realistic (the user's pick, 2026-10-23: concept "real 3", with
## the gates of "real 1"; the drawn, cartoon-like first build was not liked).
## A deep old oak wood round a clearing of moss and wet mud; a ring of mossy
## stone arches, the ruin of an old shrine, stands round the clearing, broken
## in places; two ornate gateways with steps; the gnarled oaks' boughs arch
## over it all and the sun comes down through the leaves in shafts.
##
## The shapes are `forest_ruins.glb` (Blender, `vepxis-art/world/forest_ruins.py`);
## the look is scanned textures and rocks, ferns, roots and stumps from
## Poly Haven (CC0), laid on by [code]real_surface.gdshader[/code] in world space.

const DIR := "res://assets/dungeon/forest_glade/"
const KIT := DIR + "forest_ruins.glb"
const TEX := DIR + "tex/"
const PH := DIR + "ph/"
const OAKS := ["Oak0", "Oak1", "Oak2", "Oak3"]
## The shrine's ring of arches round the clearing.
const RING_R := 27.0
## The ruins a little over a man's scale: the arches 7 m to the top.
const RUIN_S := 1.3

const BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.9, 1.0, 0.7, 1.0);
uniform float strength = 0.16;
uniform float seed = 0.0;
void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.6, UV.y);
	float pulse = 0.75 + 0.25 * sin(TIME * 0.35 + seed);
	float near = smoothstep(2.0, 10.0, length(VERTEX));
	ALBEDO = tint.rgb;
	ALPHA = pow(across, 1.8) * along * strength * pulse * near;
}
"""

static var _kit: Node3D
static var _mats := {}
static var _props := {}


static func _tex(id: String) -> Texture2D:
	return load(TEX + id + ".jpg") as Texture2D


static func _surface(base: String, moss_amount: float, scale: float, tint: Color, moss_low := 0.0) -> ShaderMaterial:
	var key := "%s_%.2f_%.2f_%.2f" % [base, moss_amount, scale, moss_low]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(DIR + "real_surface.gdshader")
	m.set_shader_parameter("base_col", _tex(base + "_Diffuse"))
	m.set_shader_parameter("base_nor", _tex(base + "_nor_gl"))
	m.set_shader_parameter("base_rough", _tex(base + "_Rough"))
	m.set_shader_parameter("moss_col", _tex("forest_ground_04_Diffuse"))
	m.set_shader_parameter("moss_nor", _tex("forest_ground_04_nor_gl"))
	m.set_shader_parameter("moss_amount", moss_amount)
	m.set_shader_parameter("scale", scale)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("moss_tint", Color(0.82, 0.9, 0.7))
	m.set_shader_parameter("moss_low", moss_low)
	_mats[key] = m
	return m


static func _leaves() -> ShaderMaterial:
	if _mats.has("leaves"):
		return _mats["leaves"]
	var m := ShaderMaterial.new()
	m.shader = load(DIR + "real_leaves.gdshader")
	m.set_shader_parameter("leaves", load(DIR + "leaves_oak.png"))
	m.set_shader_parameter("tint", Color(0.85, 0.95, 0.8))
	_mats["leaves"] = m
	return m


static func _vines() -> ShaderMaterial:
	if _mats.has("vines"):
		return _mats["vines"]
	var m := ShaderMaterial.new()
	m.shader = load(DIR + "real_leaves.gdshader")
	m.set_shader_parameter("leaves", load(DIR + "vines.png"))
	m.set_shader_parameter("tint", Color(0.8, 0.9, 0.72))
	m.set_shader_parameter("sway", 0.2)
	_mats["vines"] = m
	return m


## The small mushrooms' caps: a warm orange that holds a little light of its
## own in the dark under the trees (concept 3).
static func _caps() -> StandardMaterial3D:
	if _mats.has("caps"):
		return _mats["caps"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.42, 0.14)
	m.roughness = 0.45
	m.emission_enabled = true
	m.emission = Color(1.0, 0.45, 0.12)
	m.emission_energy_multiplier = 0.35
	m.rim_enabled = true
	m.rim = 0.4
	_mats["caps"] = m
	return m


static func _ground(w: float, l: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(DIR + "real_ground.gdshader")
	m.set_shader_parameter("moss_col", _tex("forest_ground_04_Diffuse"))
	m.set_shader_parameter("moss_nor", _tex("forest_ground_04_nor_gl"))
	m.set_shader_parameter("mud_col", _tex("mud_forest_Diffuse"))
	m.set_shader_parameter("mud_nor", _tex("mud_forest_nor_gl"))
	m.set_shader_parameter("leaf_col", _tex("forest_leaves_02_Diffuse"))
	m.set_shader_parameter("leaf_nor", _tex("forest_leaves_02_nor_gl"))
	m.set_shader_parameter("moss_tint", Color(0.5, 0.62, 0.4))
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	m.set_shader_parameter("patches", tex)
	m.set_shader_parameter("trodden_r", minf(w, l) * 0.3)
	return m


## Builds the clearing into `room`, `w` by `l` metres.
static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	if _kit == null or not is_instance_valid(_kit):
		_kit = (load(KIT) as PackedScene).instantiate() as Node3D
		_dress_kit()
	var grow := 1.0
	match Graphics.current:
		Graphics.Level.LOW:
			grow = 0.45
		Graphics.Level.MEDIUM:
			grow = 0.7
		Graphics.Level.ULTRA:
			grow = 1.4
	d._solid(room, _ground(w, l), Vector3(w + 110.0, 1.0, l + 110.0), Vector3(0.0, -0.5, 0.0))
	d._bounds(room, w, l)
	_ruin_ring(room, rng)
	# the gateways: one at the far side of the ring, one off to the left
	_gate(room, "Gate0", Vector3(0.0, 0.0, -RING_R - 3.0), PI)
	_gate(room, "Gate1", _on_ring(-PI * 0.62, RING_R + 2.5), -PI * 0.62 + PI)
	# the oaks: a close ring just past the arches, their boughs over the
	# clearing, then the deep wood out to the fog
	var n := 13
	for k in n:
		var a := float(k) / float(n) * TAU + rng.randf_range(-0.12, 0.12)
		var at := _on_ring(a, RING_R + rng.randf_range(5.0, 9.0))
		if absf(at.x) < 6.0 and at.z > 0.0:
			at.x += 9.0 * signf(at.x + 0.01)
		# the long boughs (the kit's +x) reaching in over the clearing
		var to_mid := -at.normalized()
		_oak(room, OAKS[k % OAKS.size()], at, atan2(-to_mid.z, to_mid.x) + rng.randf_range(-0.35, 0.35),
				rng.randf_range(1.2, 1.5))
	for k in int(34.0 * grow):
		var a := rng.randf_range(0.0, TAU)
		var at := _on_ring(a, RING_R + rng.randf_range(16.0, 46.0))
		_oak(room, OAKS[rng.randi_range(0, OAKS.size() - 1)], at, rng.randf_range(0.0, TAU),
				rng.randf_range(1.0, 1.5), k > 10)
	# the floor of the wood: scanned rocks, ferns, roots, stumps, logs
	_props_round(room, rng, grow)
	_paving(room, rng)
	_shrooms(room, rng, grow)
	_roof(room, rng, grow)
	_dust(room)
	_beams(room, rng)


## What is left of the shrine's paving: strips of broken slabs round under
## the arches, missing here and there, moss and earth between.
static func _paving(room: Node3D, rng: RandomNumberGenerator) -> void:
	var n := 15
	for k in n:
		if rng.randf() < 0.22:
			continue
		var a := float(k) / float(n) * TAU + rng.randf_range(-0.08, 0.08)
		_piece(room, ["Flags0", "Flags1", "Flags2"][k % 3], _on_ring(a, RING_R - rng.randf_range(1.0, 3.0)),
				a + rng.randf_range(-0.1, 0.1), rng.randf_range(0.95, 1.15))


## Little orange mushrooms in the moss: at the oaks' feet and the ruins'.
static func _shrooms(room: Node3D, rng: RandomNumberGenerator, grow: float) -> void:
	for k in int(46.0 * grow):
		var r := RING_R + rng.randf_range(-1.5, 10.0)
		_piece(room, ["Shrooms0", "Shrooms1", "Shrooms2"][k % 3], _on_ring(rng.randf_range(0.0, TAU), r),
				rng.randf_range(0.0, TAU), rng.randf_range(1.0, 2.2))


## The roof of leaves high over the clearing (concept 3 is dark under it):
## leaf cards lying near flat, dense, with gaps the sun comes down through.
static func _roof(room: Node3D, rng: RandomNumberGenerator, grow: float) -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(7.0, 7.0)
	qm.material = _leaves()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	var n := int(360.0 * clampf(grow, 0.7, 1.3))
	mm.instance_count = n
	# a few round holes in it: where the shafts come down
	var holes: Array[Vector2] = []
	for k in 5:
		holes.append(Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(4.0, RING_R * 0.7))
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 4:
		tries += 1
		var p := Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * (RING_R + 22.0)
		var open := false
		for h in holes:
			if p.distance_to(h) < 3.2:
				open = true
		if open:
			continue
		var b := Basis(Vector3.RIGHT, -PI * 0.5 + rng.randf_range(-0.35, 0.35))
		b = Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * b
		b = b.scaled(Vector3.ONE * rng.randf_range(0.8, 1.4))
		mm.set_instance_transform(placed, Transform3D(b, Vector3(p.x, rng.randf_range(15.0, 23.0), p.y)))
		placed += 1
	mm.visible_instance_count = placed
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	room.add_child(mi)


static func _on_ring(a: float, r: float) -> Vector3:
	return Vector3(sin(a) * r, 0.0, cos(a) * r)


## Materials onto the Blender shapes, by the names they were made with.
static func _dress_kit() -> void:
	for mi: MeshInstance3D in _kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var mat_name := String(mat.resource_name) if mat != null else ""
			if mi.name.begins_with("Flags"):
				var f := _surface("mossy_stone_wall", 0.85, 0.42, Color(0.86, 0.85, 0.8), 0.0)
				f.set_shader_parameter("patchy", 1.0)
				mi.set_surface_override_material(s, f)
				continue
			match mat_name:
				"Vines":
					mi.set_surface_override_material(s, _vines())
				"Cap":
					mi.set_surface_override_material(s, _caps())
				"Stem":
					var st := StandardMaterial3D.new()
					st.albedo_color = Color(0.78, 0.72, 0.6)
					st.roughness = 0.8
					mi.set_surface_override_material(s, st)
				"Bark":
					mi.set_surface_override_material(s, _surface("jolcham_oak_bark_01", 0.55, 0.32, Color(0.85, 0.8, 0.74), 2.5))
				"Leaves":
					mi.set_surface_override_material(s, _leaves())
				_:
					mi.set_surface_override_material(s, _surface("mossy_stone_wall", 0.75, 0.3, Color(0.92, 0.92, 0.88), 0.8))


static func _piece(room: Node3D, piece: String, at: Vector3, yaw: float, s: float) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	room.add_child(n)
	return n


static func _box(n: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position = at
	body.add_child(shape)
	n.add_child(body)


## The shrine's ring: bays of arches round the clearing, some fallen, some
## only a pillar, gaps where the wood has got in; the way in at the near
## side and the far gateway left open.
static func _ruin_ring(room: Node3D, rng: RandomNumberGenerator) -> void:
	var bays := 18
	for k in bays:
		var a := float(k) / float(bays) * TAU
		var at := _on_ring(a, RING_R)
		# the way in (the near side) and the far gate's gap
		if absf(at.x) < 7.0:
			continue
		var roll := rng.randf()
		var piece := "Arch0"
		if roll < 0.18:
			continue
		elif roll < 0.34:
			piece = "ArchBroken"
		elif roll < 0.46:
			piece = "PillarBroken"
		elif roll < 0.56:
			piece = "Pillar"
		elif roll < 0.78:
			piece = "Arch1"
		var n := _piece(room, piece, at, a, RUIN_S)
		if n == null:
			continue
		if piece.begins_with("Arch"):
			for sx: float in [-2.875, 2.875]:
				if piece == "ArchBroken" and sx > 0.0:
					_box(n, Vector3(1.4, 2.4, 1.4), Vector3(sx, 1.2, 0.0))
				else:
					_box(n, Vector3(1.4, 5.0, 1.4), Vector3(sx, 2.5, 0.0))
		else:
			_box(n, Vector3(1.5, 5.0 if piece == "Pillar" else 2.6, 1.5), Vector3(0.0, 1.3, 0.0))


static func _gate(room: Node3D, piece: String, at: Vector3, yaw: float) -> void:
	var n := _piece(room, piece, at, yaw, RUIN_S)
	if n != null:
		_box(n, Vector3(6.0, 6.0, 2.0), Vector3(0.0, 3.0, 0.3))


static func _oak(room: Node3D, piece: String, at: Vector3, yaw: float, s: float, far := false) -> void:
	var n := _piece(room, piece, at, yaw, s)
	if n == null:
		return
	if far:
		return
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 2.2 * s
	c.height = 10.0
	shape.shape = c
	shape.position.y = 5.0
	body.add_child(shape)
	n.add_child(body)


## A scanned prop from Poly Haven (made light: `_shots_tmp/forest/ph_light.py`), loaded once.
static func _prop(id: String) -> Node3D:
	if not _props.has(id):
		var path := PH + id + ".glb"
		_props[id] = (load(path) as PackedScene).instantiate() if ResourceLoader.exists(path) else null
	return _props[id]


static func _place(room: Node3D, id: String, at: Vector3, yaw: float, s: float, shadow := true) -> void:
	var src := _prop(id)
	if src == null:
		return
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	if not shadow:
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(n)


static func _props_round(room: Node3D, rng: RandomNumberGenerator, grow: float) -> void:
	# mossy rocks at the arches' feet and out in the wood
	for k in int(34.0 * grow):
		var at := _on_ring(rng.randf_range(0.0, TAU), RING_R + rng.randf_range(-3.5, 12.0))
		_place(room, ["rock_moss_set_01", "rock_moss_set_02", "boulder_01"][k % 3], at,
				rng.randf_range(0.0, TAU), rng.randf_range(1.2, 2.2))
	# ferns, thick at the ring and under the oaks, a few into the clearing
	for k in int(120.0 * grow):
		var r := RING_R + rng.randf_range(-4.0, 14.0) if k % 6 else rng.randf_range(RING_R * 0.6, RING_R - 3.0)
		_place(room, "fern_02", _on_ring(rng.randf_range(0.0, TAU), r), rng.randf_range(0.0, TAU),
				rng.randf_range(2.4, 3.8), false)
	# roots, stumps and a fallen trunk or two
	for k in int(12.0 * grow):
		_place(room, ["root_cluster_01", "root_cluster_02", "pine_roots", "single_root"][k % 4],
				_on_ring(rng.randf_range(0.0, TAU), RING_R + rng.randf_range(2.0, 10.0)), rng.randf_range(0.0, TAU),
				rng.randf_range(1.2, 2.0))
	for k in 4:
		_place(room, ["tree_stump_01", "tree_stump_02"][k % 2], _on_ring(rng.randf_range(0.0, TAU),
				RING_R + rng.randf_range(3.0, 9.0)), rng.randf_range(0.0, TAU), rng.randf_range(1.3, 1.8))
	for k in 2:
		_place(room, "dead_tree_trunk", _on_ring(rng.randf_range(0.0, TAU), RING_R + rng.randf_range(4.0, 8.0)),
				rng.randf_range(0.0, TAU), 1.4)


## Dust and seed-fluff drifting in the air, catching the light: soft round
## motes (a square one reads as a pixel, not a mote).
static func _dust(room: Node3D) -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 220
	dust.lifetime = 16.0
	dust.preprocess = 16.0
	dust.position = Vector3(0.0, 4.5, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(RING_R * 0.85, 4.0, RING_R * 0.85)
	pm.gravity = Vector3(0.0, -0.015, 0.0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.1
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.92, 0.7, 0.0))
	fade.add_point(0.5, Color(1.0, 0.92, 0.7, 0.55))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.92, 0.7, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	dust.process_material = pm
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = g
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = dot
	q.material = qm
	dust.draw_pass_1 = q
	dust.visibility_aabb = AABB(Vector3(-RING_R, -6.0, -RING_R), Vector3(RING_R * 2.0, 12.0, RING_R * 2.0))
	room.add_child(dust)


## Shafts of sun slanting down through the leaves into the clearing.
static func _beams(room: Node3D, rng: RandomNumberGenerator) -> void:
	var sh := Shader.new()
	sh.code = BEAM
	for k in 5:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("seed", float(k) * 1.7)
		m.set_shader_parameter("strength", rng.randf_range(0.04, 0.08))
		var width := rng.randf_range(2.0, 4.5)
		var length := 36.0
		var foot := _on_ring(rng.randf_range(0.0, TAU), rng.randf_range(0.0, RING_R * 0.8))
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(32.0)).rotated(Vector3.UP, deg_to_rad(-35.0))
		var holder := Node3D.new()
		holder.transform = Transform3D(tilt, foot)
		room.add_child(holder)
		for q in 2:
			var quad := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(width, length)
			quad.mesh = qm
			quad.material_override = m
			quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			quad.position = Vector3(0.0, length * 0.5, 0.0)
			quad.rotation.y = float(q) * PI * 0.5
			holder.add_child(quad)
