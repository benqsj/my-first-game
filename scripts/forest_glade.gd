class_name ForestGlade
extends Object

## The forest, low poly done richly (the user, 2026-10-23: the realistic look
## was not liked but its design was; "low poly, but high graphics, not a
## mini-game"). A deep old oak wood round a clearing of moss and mud; a ring
## of mossy stone arches, the ruin of a shrine, round the clearing, broken in
## places, its paving left in strips; two ornate gateways; gnarled oaks whose
## long boughs reach in over it all with vines hanging from them; a roof of
## leaves overhead with holes the sun comes down through, in shafts.
##
## Every shape is faceted and each face carries its own colour (a vertex
## colour), from `forest_lowpoly.glb` (Blender, `vepxis-art/world/forest_lowpoly.py`);
## the look is in the light: the shafts, the fog, shadows, the leaves lit
## through. Two shaders, `lp_solid.gdshader` and `lp_foliage.gdshader`.

const DIR := "res://assets/dungeon/forest_glade/"
const KIT := DIR + "forest_lowpoly.glb"
const OAKS := ["Oak0", "Oak1", "Oak2", "Oak3"]
## The shrine's ring of arches round the clearing.
const RING_R := 27.0
## The ruins a little over a man's scale: the arches 7 m to the top.
const RUIN_S := 1.3

const BEAM := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.95, 0.7, 1.0);
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


static func _solid(foot_dark := 0.35, glow := 0.0) -> ShaderMaterial:
	var key := "solid_%.2f_%.2f" % [foot_dark, glow]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(DIR + "lp_solid.gdshader")
	m.set_shader_parameter("foot_dark", foot_dark)
	m.set_shader_parameter("glow", glow)
	_mats[key] = m
	return m


static func _foliage(sway := 0.08) -> ShaderMaterial:
	var key := "foliage_%.2f" % sway
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(DIR + "lp_foliage.gdshader")
	m.set_shader_parameter("sway", sway)
	_mats[key] = m
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
	# the floor: the faceted ground to look at, a flat slab under it to walk on
	var slab := d._solid(room, _solid(0.0), Vector3(w + 110.0, 1.0, l + 110.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	var floor_piece := _piece(room, "Ground", Vector3.ZERO, 0.0, 1.0)
	if floor_piece is GeometryInstance3D:
		(floor_piece as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._bounds(room, w, l)
	_ruin_ring(room, rng)
	# the gateways: one at the far side of the ring, one off to the left
	_gate(room, "Gate0", Vector3(0.0, 0.0, -RING_R - 3.0), PI)
	_gate(room, "Gate1", _on_ring(-PI * 0.62, RING_R + 2.5), -PI * 0.62 + PI)
	# the oaks: a close ring just past the arches, their long boughs (the
	# kit's +x) reaching in over the clearing, then the deep wood
	var n := 13
	for k in n:
		var a := float(k) / float(n) * TAU + rng.randf_range(-0.12, 0.12)
		var at := _on_ring(a, RING_R + rng.randf_range(5.0, 9.0))
		if absf(at.x) < 6.0 and at.z > 0.0:
			at.x += 9.0 * signf(at.x + 0.01)
		var to_mid := -at.normalized()
		_oak(room, OAKS[k % OAKS.size()], at, atan2(-to_mid.z, to_mid.x) + rng.randf_range(-0.35, 0.35),
				rng.randf_range(1.2, 1.5))
	for k in int(34.0 * grow):
		var at := _on_ring(rng.randf_range(0.0, TAU), RING_R + rng.randf_range(16.0, 46.0))
		_oak(room, OAKS[rng.randi_range(0, OAKS.size() - 1)], at, rng.randf_range(0.0, TAU),
				rng.randf_range(1.0, 1.5), k > 10)
	_floor_things(room, rng, grow)
	_paving(room, rng)
	_roof(room, rng, grow)
	_dust(room)
	_beams(room, rng)


static func _on_ring(a: float, r: float) -> Vector3:
	return Vector3(sin(a) * r, 0.0, cos(a) * r)


## The shaders onto the Blender shapes, by the names their materials were
## made with.
static func _dress_kit() -> void:
	for mi: MeshInstance3D in _kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var mat_name := String(mat.resource_name) if mat != null else ""
			match mat_name:
				"Leaves":
					mi.set_surface_override_material(s, _foliage(0.03 if mi.name.begins_with("Canopy") else 0.08))
				"Vines":
					mi.set_surface_override_material(s, _foliage(0.16))
				"Cap":
					mi.set_surface_override_material(s, _solid(0.0, 0.45))
				"Ground":
					var gm := _solid(0.0).duplicate() as ShaderMaterial
					gm.set_shader_parameter("bright", 2.0)
					gm.set_shader_parameter("roughness", 1.0)
					mi.set_surface_override_material(s, gm)
				"Bark":
					mi.set_surface_override_material(s, _solid(0.3))
				_:
					mi.set_surface_override_material(s, _solid(0.35))
		if mi.name.begins_with("Fern") or mi.name.begins_with("Shrooms"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	if n == null or far:
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


## The floor of the wood: faceted rocks at the arches' feet, ferns thick at
## the ring and under the oaks, stumps, a fallen trunk, little orange
## mushrooms in the moss. Nothing in the clearing's middle.
static func _floor_things(room: Node3D, rng: RandomNumberGenerator, grow: float) -> void:
	for k in int(34.0 * grow):
		var at := _on_ring(rng.randf_range(0.0, TAU), RING_R + rng.randf_range(-3.0, 12.0))
		_piece(room, "Rock%d" % (k % 4), at, rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.6))
	for k in int(130.0 * grow):
		var r := RING_R + rng.randf_range(-3.5, 14.0) if k % 7 else rng.randf_range(RING_R * 0.7, RING_R - 2.5)
		_piece(room, "Fern%d" % (k % 3), _on_ring(rng.randf_range(0.0, TAU), r), rng.randf_range(0.0, TAU),
				rng.randf_range(1.1, 1.9))
	for k in 5:
		_piece(room, "Stump%d" % (k % 2), _on_ring(rng.randf_range(0.0, TAU), RING_R + rng.randf_range(3.0, 10.0)),
				rng.randf_range(0.0, TAU), rng.randf_range(1.0, 1.5))
	for k in 2:
		_piece(room, "Log0", _on_ring(rng.randf_range(0.0, TAU), RING_R + rng.randf_range(4.0, 8.0)),
				rng.randf_range(0.0, TAU), 1.2)
	for k in int(46.0 * grow):
		_piece(room, "Shrooms%d" % (k % 3), _on_ring(rng.randf_range(0.0, TAU), RING_R + rng.randf_range(-1.5, 10.0)),
				rng.randf_range(0.0, TAU), rng.randf_range(1.0, 2.2))


## What is left of the shrine's paving: strips of broken slabs round under
## the arches, missing here and there.
static func _paving(room: Node3D, rng: RandomNumberGenerator) -> void:
	var n := 15
	for k in n:
		if rng.randf() < 0.22:
			continue
		var a := float(k) / float(n) * TAU + rng.randf_range(-0.08, 0.08)
		_piece(room, ["Flags0", "Flags1", "Flags2"][k % 3], _on_ring(a, RING_R - rng.randf_range(1.0, 3.0)),
				a + rng.randf_range(-0.1, 0.1), rng.randf_range(0.95, 1.15))


## The roof of leaves high over the clearing: faceted clumps, dense, with a
## few holes the sun comes down through.
static func _roof(room: Node3D, rng: RandomNumberGenerator, grow: float) -> void:
	var holes: Array[Vector2] = []
	for k in 9:
		holes.append(Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(2.0, RING_R * 0.85))
	for piece in ["Canopy0", "Canopy1"]:
		var src := _kit.get_node_or_null(piece) as MeshInstance3D
		if src == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = src.mesh
		var n := int(42.0 * clampf(grow, 0.7, 1.3))
		mm.instance_count = n
		var placed := 0
		var tries := 0
		while placed < n and tries < n * 6:
			tries += 1
			# (a ring of roof round an open middle: the sun comes down into
			# the clearing, the wood round it under the leaves)
			var p := Vector2.from_angle(rng.randf_range(0.0, TAU)) * lerpf(RING_R * 0.75, RING_R + 22.0, sqrt(rng.randf()))
			var open := false
			for h in holes:
				if p.distance_to(h) < 5.5:
					open = true
			if open:
				continue
			var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.9, 1.4))
			mm.set_instance_transform(placed, Transform3D(b, Vector3(p.x, rng.randf_range(16.0, 22.0), p.y)))
			placed += 1
		mm.visible_instance_count = placed
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _foliage(0.03)
		# (no shadow from the roof: the clearing lies in the sun, the wood
		# round it in the oaks' shade, a lit glade in a dark wood)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(mi)


## Dust drifting in the air, catching the light: soft round motes.
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
	for k in 7:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("seed", float(k) * 1.7)
		# (brighter where there is no volumetric fog to show the real shafts)
		var lit := 1.0 if Graphics.current == Graphics.Level.ULTRA else 1.8
		m.set_shader_parameter("strength", rng.randf_range(0.04, 0.08) * lit)
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
