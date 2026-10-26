class_name HolySpring
extends Object

## The holy spring ("წმინდა წყარო"), low poly as the forest (the user's
## concept on Higgsfield, "tye3", 2026-10-26): a glade in an autumn maple
## wood, open to the sky; in its middle an old stone fountain, its basin
## glowing pale, inside a low round wall of stacked blocks with gaps and
## steps at the near and far side; gold moss inside the wall, trodden earth
## round it, fallen leaves, grey boulders with moss on their backs,
## leaves drifting down through the sun.
##
## The shapes are `spring_lowpoly.glb` (Blender, `vepxis-art/world/spring_lowpoly.py`),
## lit with the forest's shaders ([ForestGlade]). Healing is [RestSpot]'s:
## this only builds the place and hands back the water and its light.

const KIT := "res://assets/dungeon/holy_spring/spring_lowpoly.glb"
const MAPLES := ["Maple0", "Maple1", "Maple2", "Maple3"]
## The round wall's middle line, its two gaps (toward -z and +z, the ways in
## and on), half a gap's width (radians).
const WALL_R := 8.6
const WALL_SEGS := 34
const GAP_HALF := 0.2
## The basin's wall round the fountain's foot: he stands at it to drink.
const BASIN_R := 3.05

const WATER := """
shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec4 deep : source_color = vec4(0.10, 0.42, 0.46, 1.0);
uniform vec4 shine : source_color = vec4(0.62, 0.98, 1.0, 1.0);
uniform float glow = 1.1;
uniform float used = 0.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// flat basins ripple out from the middle; the falling streams run down
	float flat_ = step(0.8, abs(NORMAL.y));
	float r = length(wp.xz);
	float ripple = 0.5 + 0.5 * sin(r * 7.0 - TIME * 1.6) * sin(atan(wp.z, wp.x) * 5.0 + TIME * 0.4);
	float fall = 0.5 + 0.5 * sin(wp.y * 9.0 + TIME * 7.0 + wp.x * 2.0);
	float lit = mix(fall, ripple, flat_);
	float on = 1.0 - used;
	vec3 c = mix(deep.rgb, shine.rgb, 0.35 + 0.4 * lit);
	ALBEDO = c * mix(0.5, 1.0, on);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	EMISSION = shine.rgb * glow * (0.35 + 0.45 * lit) * on;
	ALPHA = mix(0.92, 0.8, flat_);
}
"""

static var _kit: Node3D


## Builds the glade into `room`, `w` by `l` metres, the fountain under
## `spot`; gives back {"water": its material, "light": its light}.
static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator,
		spot: Node3D) -> Dictionary:
	if _kit == null or not is_instance_valid(_kit):
		_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	var water := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WATER
	water.shader = sh
	_dress(_kit, water)
	var grow := 1.0
	match Graphics.current:
		Graphics.Level.LOW:
			grow = 0.45
		Graphics.Level.MEDIUM:
			grow = 0.7
		Graphics.Level.ULTRA:
			grow = 1.3
	# the floor: the faceted ground to look at, a flat slab under it to walk on
	var slab := d._solid(room, ForestGlade._solid(0.0), Vector3(w + 110.0, 1.0, l + 110.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	var ground := _piece(room, "Ground", Vector3.ZERO, 0.0, 1.0)
	if ground is GeometryInstance3D:
		(ground as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._bounds(room, w, l)
	# the fountain, its basin a wall he cannot walk through
	_piece(spot, "Fountain", Vector3.ZERO, 0.0, 1.0)
	_piece(spot, "Streams", Vector3.ZERO, 0.0, 1.0)
	var basin := StaticBody3D.new()
	var bs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BASIN_R
	cyl.height = 1.2
	bs.shape = cyl
	bs.position.y = 0.6
	basin.add_child(bs)
	spot.add_child(basin)
	_ring_wall(room)
	_maples(room, rng, grow)
	_floor_things(room, rng, grow)
	# the spring's own light, pale, and a little over the bowl at the top
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.92, 1.0)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = Vector3(0.0, 1.6, 0.0)
	light.shadow_enabled = false
	spot.add_child(light)
	_motes(spot)
	_falling_leaves(room, w, l, grow)
	ForestGlade._dust(room)
	if Graphics.current != Graphics.Level.LOW:
		ForestGlade._haze(room)
	return {"water": water, "light": light}


## The shaders onto the Blender shapes, by their materials' names.
static func _dress(kit: Node3D, water: ShaderMaterial) -> void:
	for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Leaves":
					# lit through amber, not the oaks' green
					var lm := ForestGlade._foliage(0.06).duplicate() as ShaderMaterial
					lm.set_shader_parameter("backlight", Vector3(0.42, 0.24, 0.08))
					lm.set_shader_parameter("bright", 1.05)
					mi.set_surface_override_material(s, lm)
				"Water":
					mi.set_surface_override_material(s, water)
				"Cap":
					mi.set_surface_override_material(s, ForestGlade._solid(0.0, 0.15))
				"Ground":
					var gm := ForestGlade._solid(0.0).duplicate() as ShaderMaterial
					gm.set_shader_parameter("bright", 1.25)
					gm.set_shader_parameter("roughness", 1.0)
					mi.set_surface_override_material(s, gm)
				"Litter":
					mi.set_surface_override_material(s, ForestGlade._solid(0.0))
				"Bark":
					mi.set_surface_override_material(s, ForestGlade._solid(0.3))
				_:
					mi.set_surface_override_material(s, ForestGlade._solid(0.3))
		if mi.name.begins_with("Litter") or mi.name == "Streams":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _piece(parent: Node3D, piece: String, at: Vector3, yaw: float, s: float) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	parent.add_child(n)
	return n


static func _on_ring(a: float, r: float) -> Vector3:
	return Vector3(sin(a) * r, 0.0, cos(a) * r)


## The round wall and its stops: a box along each stretch of it, none in the
## two gaps (Blender's +y and -y, the game's -z and +z).
static func _ring_wall(room: Node3D) -> void:
	_piece(room, "RingWall", Vector3.ZERO, 0.0, 1.0)
	var body := StaticBody3D.new()
	room.add_child(body)
	var chord := TAU * WALL_R / float(WALL_SEGS) + 0.1
	for k in WALL_SEGS:
		# (in Blender's plane, the gaps at a quarter and three quarters round)
		var a := (float(k) + 0.5) / float(WALL_SEGS) * TAU
		var off := minf(absf(wrapf(a - PI * 0.5, -PI, PI)), absf(wrapf(a - PI * 1.5, -PI, PI)))
		if off < GAP_HALF:
			continue
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(chord, 1.3, 0.85)
		shape.shape = box
		var at := Vector3(cos(a) * WALL_R, 0.65, -sin(a) * WALL_R)
		# along the wall: its length across the line to the middle
		shape.transform = Transform3D(Basis(Vector3.UP, a + PI * 0.5), at)
		body.add_child(shape)


## The maples: a ring round the glade, its near and far side left open for
## the ways in and on, then the deep wood beyond the bounds.
static func _maples(room: Node3D, rng: RandomNumberGenerator, grow: float) -> void:
	var n := 12
	for k in n:
		var a := (float(k) + 0.5) / float(n) * TAU + rng.randf_range(-0.12, 0.12)
		var at := _on_ring(a, rng.randf_range(16.0, 22.0))
		if absf(at.x) < 7.0:
			at.x = 7.0 * signf(at.x + 0.01) + rng.randf_range(0.0, 2.0) * signf(at.x + 0.01)
		var s := rng.randf_range(1.0, 1.3)
		var tree := _piece(room, MAPLES[k % MAPLES.size()], at, rng.randf_range(0.0, TAU), s)
		if tree == null:
			continue
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.95 * s
		c.height = 8.0
		shape.shape = c
		shape.position.y = 4.0
		body.add_child(shape)
		tree.add_child(body)
	for k in int(46.0 * grow):
		var at := _on_ring(rng.randf_range(0.0, TAU), rng.randf_range(28.0, 64.0))
		_piece(room, MAPLES[rng.randi_range(0, MAPLES.size() - 1)], at, rng.randf_range(0.0, TAU), rng.randf_range(1.1, 1.6))


## Boulders with moss on their backs, stumps, and the fallen
## leaves lying everywhere, thickest under the trees.
static func _floor_things(room: Node3D, rng: RandomNumberGenerator, grow: float) -> void:
	for k in 22:
		var at := _on_ring(rng.randf_range(0.0, TAU), rng.randf_range(11.0, 30.0))
		if absf(at.x) < 5.0 and at.length() < 26.0:
			continue
		var piece := "Rock%d" % (k % 4)
		var s := rng.randf_range(0.9, 1.6)
		var rock := _piece(room, piece, at, rng.randf_range(0.0, TAU), s)
		if rock != null and at.length() < 26.0 and k % 4 in [1, 2]:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var c := CylinderShape3D.new()
			c.radius = (1.0 if k % 4 == 1 else 1.5) * s * 0.85
			c.height = 2.0
			shape.shape = c
			shape.position.y = 0.5
			body.add_child(shape)
			rock.add_child(body)
	# (no toadstools: the user's word, 2026-10-26)
	for k in 3:
		var at := _on_ring(rng.randf_range(0.6, TAU - 0.6), rng.randf_range(18.0, 24.0))
		_piece(room, "Stump%d" % (k % 2), at, rng.randf_range(0.0, TAU), rng.randf_range(1.0, 1.4))
	for k in int(90.0 * grow):
		var r := sqrt(rng.randf()) * 38.0
		if r < 3.6:
			r = 3.6 + rng.randf() * 4.0
		_piece(room, "Litter%d" % (k % 3), _on_ring(rng.randf_range(0.0, TAU), r), rng.randf_range(0.0, TAU),
				rng.randf_range(0.8, 1.3))


## Little lights rising off the water, slow: the spring is holy.
static func _motes(spot: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = Vector3(0.0, 0.9, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 2.3
	pm.emission_ring_inner_radius = 1.1
	pm.emission_ring_height = 0.05
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.gravity = Vector3(0.0, 0.12, 0.0)
	pm.initial_velocity_min = 0.15
	pm.initial_velocity_max = 0.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(0.6, 0.95, 1.0, 0.0))
	fade.add_point(0.3, Color(0.6, 0.95, 1.0, 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(0.6, 0.95, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = SkillFx.dot()
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 8, 8))
	spot.add_child(p)


## Maple leaves drifting down through the light, turning as they fall.
static func _falling_leaves(room: Node3D, w: float, l: float, grow: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = int(110.0 * grow)
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.position = Vector3(0.0, 11.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.6, 1.5, l * 0.6)
	pm.gravity = Vector3(0.25, -0.8, 0.1)
	pm.initial_velocity_max = 0.3
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.scale_min = 0.8
	pm.scale_max = 1.4
	var hues := Gradient.new()
	hues.set_color(0, Color(0.95, 0.62, 0.22))
	hues.add_point(0.4, Color(0.88, 0.42, 0.14))
	hues.add_point(0.75, Color(0.72, 0.22, 0.10))
	hues.set_color(hues.get_point_count() - 1, Color(0.98, 0.74, 0.3))
	var ramp := GradientTexture1D.new()
	ramp.gradient = hues
	pm.color_initial_ramp = ramp
	p.process_material = pm
	var leaf := _leaf_mesh(0.16)
	var lm := StandardMaterial3D.new()
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	lm.vertex_color_use_as_albedo = true
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.roughness = 1.0
	leaf.surface_set_material(0, lm)
	p.draw_pass_1 = leaf
	p.visibility_aabb = AABB(Vector3(-w, -14.0, -l), Vector3(w * 2.0, 18.0, l * 2.0))
	room.add_child(p)


## A flat maple leaf, five lobes, `size` across (for the falling leaves).
static func _leaf_mesh(size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	for lobe: Array in [[-2.3, 0.55], [-1.15, 0.86], [0.0, 1.0], [1.15, 0.86], [2.3, 0.55]]:
		for part: Array in [[-0.32, 0.42], [0.0, lobe[1]], [0.32, 0.42]]:
			var a: float = lobe[0] + part[0] + PI * 0.5
			pts.append(Vector2(cos(a), sin(a)) * float(part[1]) * size * 0.5)
	pts.append(Vector2(0.0, -0.12) * size * 0.5)
	st.set_normal(Vector3.BACK)
	for k in pts.size():
		var a := pts[k]
		var b := pts[(k + 1) % pts.size()]
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(a.x, a.y, 0.0))
		st.add_vertex(Vector3(b.x, b.y, 0.0))
	return st.commit()
