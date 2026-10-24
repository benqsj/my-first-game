class_name TerracePlaces
extends Object

## Four terraces, low poly done richly as the forest (the user, 2026-10-24:
## all four of the concept pictures liked, each to be its own place, in the
## stead of places that were there):
##
## * **lake** ("terrace") — a royal palace's marble terrace on a cliff over a
##   turquoise mountain lake: inlaid paving, a balustrade round it, bronze
##   knights at its corners, braziers, the palace's face behind the way in,
##   islands with pines, forested mountains round the water, mist on it.
## * **fort** ("rampart") — a mountain fortress's terrace: crenellated walls
##   and round towers on two sides, a gatehouse with red doors, the third side
##   a carved balustrade over a deep valley, snowy peaks far off, a low gold
##   afternoon sun.
## * **falls** ("mountain") — a ruined temple's terrace on a cliff: cracked
##   hexagonal slabs, broken columns, a fallen statue, the temple's portico,
##   gnarled trees leaning out over the edge, a waterfall down the red rock
##   across the gorge.
## * **clouds** ("throne", the orc lord's) — a palace terrace over a sea of
##   cloud: a two-storey colonnade of sandstone arches with red banners down
##   one side, the rest open over the drop behind a balustrade, domed
##   pavilions at the corners, the lord's throne on a dais at the far end.
##
## Every shape is faceted, each face its own colour (a vertex colour), from
## `terraces_lowpoly.glb` (Blender, `vepxis-art/world/terraces_lowpoly.py`);
## the forest's two shaders. Portals stand at (±9, −l/2+10), the way out at
## −l/2+15: kept clear (places_test).

const DIR := "res://assets/dungeon/terraces/"
const KIT := DIR + "terraces_lowpoly.glb"
const LP := "res://assets/dungeon/forest_glade/"
const STATUE := "res://assets/dungeon/sky_temple/statue.res"

## The lake's water: a wide sheet moved in slow waves, each facet lit flat
## (low poly water), turquoise near, the sky's colour at a glance, a glitter
## of sun on the crests.
const LAKE := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.42, 0.80, 0.76, 1.0);
uniform vec4 deep : source_color = vec4(0.08, 0.36, 0.46, 1.0);
uniform vec4 foam : source_color = vec4(0.92, 0.97, 0.96, 1.0);
uniform vec4 far_col : source_color = vec4(0.60, 0.78, 0.84, 1.0);
uniform float wave = 0.3;
uniform float scale = 0.05;
uniform float speed = 0.35;
uniform float depth_reach = 9.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
varying vec3 wp;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = sin(w.x * scale * 1.3 + TIME * speed) * 0.5 + sin(w.z * scale * 1.7 - TIME * speed * 0.8) * 0.35
			+ sin((w.x + w.z) * scale * 3.1 + TIME * speed * 1.4) * 0.15;
	VERTEX.y += h * wave;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// flat facets: each little triangle's normal as it lies (low poly water)
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = n;
	// how deep it is here: the ground behind it against the water
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	behind.xyz /= behind.w;
	float depth = clamp(VERTEX.z - behind.z, 0.0, 200.0);
	float k = 1.0 - exp(-depth / depth_reach);
	// in bands, as the land is
	k = floor(k * 5.0) / 5.0;
	vec3 c = mix(shallow.rgb, deep.rgb, k);
	float dist = length(VERTEX);
	c = mix(c, far_col.rgb, clamp((dist - 260.0) / 500.0, 0.0, 0.7));
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 3.0);
	c = mix(c, far_col.rgb, fres * 0.45);
	// a white line where it laps the shore
	float lap = 1.0 - smoothstep(0.15, 0.9, depth + 0.25 * sin(TIME * 1.2 + wp.x * 0.3 + wp.z * 0.2));
	c = mix(c, foam.rgb, lap * 0.85);
	ALBEDO = c;
	ALPHA = clamp(0.78 + k * 0.22 + lap, 0.0, 1.0);
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
"""

## The falling water: streaks running down it fast, white at its edges and
## foot, a little see-through at the sides.
const FALLS := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform vec4 water : source_color = vec4(0.62, 0.82, 0.92, 1.0);
uniform vec4 foam : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float speed = 1.6;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV;
	float s = vnoise(vec2(uv.x * 14.0, uv.y * 1.2 - TIME * speed)) * 0.6 + vnoise(vec2(uv.x * 34.0, uv.y * 3.0 - TIME * speed * 1.6)) * 0.4;
	float edge = smoothstep(0.32, 0.5, abs(uv.x - 0.5));
	float streak = step(0.56, s);
	vec3 c = mix(water.rgb, foam.rgb, clamp(streak * 0.8 + edge * 0.6, 0.0, 1.0));
	// in flat bands, as the low poly is
	c = floor(c * 7.0) / 7.0;
	ALBEDO = c;
	ROUGHNESS = 0.3;
	EMISSION = foam.rgb * 0.12 * streak;
	ALPHA = clamp(1.0 - edge * 0.55, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.35;
}
"""

static var _kit: Node3D
static var _mats := {}
static var _statue: Mesh


static func _solid(foot_dark := 0.25, bright := 1.0, rough := 0.85) -> ShaderMaterial:
	var key := "s_%.2f_%.2f_%.2f" % [foot_dark, bright, rough]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(LP + "lp_solid.gdshader")
	m.set_shader_parameter("foot_dark", foot_dark)
	m.set_shader_parameter("bright", bright)
	m.set_shader_parameter("roughness", rough)
	_mats[key] = m
	return m


static func _foliage(sway := 0.06) -> ShaderMaterial:
	var key := "f_%.2f" % sway
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load(LP + "lp_foliage.gdshader")
	m.set_shader_parameter("sway", sway)
	_mats[key] = m
	return m


static func _code(key: String, code: String) -> ShaderMaterial:
	if _mats.has(key):
		return _mats[key]
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	_mats[key] = m
	return m


static func _ready_kit() -> void:
	if _kit != null and is_instance_valid(_kit):
		return
	_kit = (load(KIT) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in _kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Pine", "Leaves":
					mi.set_surface_override_material(s, _foliage(0.05))
				"Cloth":
					mi.set_surface_override_material(s, _foliage(0.12))
				"Foam":
					mi.set_surface_override_material(s, _code("falls", FALLS))
				"Marble", "Inlay":
					mi.set_surface_override_material(s, _solid(0.12, 1.0, 0.55))
				"Bronze", "Gold":
					mi.set_surface_override_material(s, _solid(0.0, 1.1, 0.45))
				"Mount", "Valley", "Grout":
					mi.set_surface_override_material(s, _solid(0.0, 1.0, 1.0))
				"Cliff", "CliffRed":
					mi.set_surface_override_material(s, _solid(0.0, 1.1, 0.95))
				_:
					mi.set_surface_override_material(s, _solid(0.25))


static func _piece(room: Node3D, piece: String, at: Vector3, yaw: float = 0.0, s: float = 1.0,
		shadow: bool = true) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		push_warning("TerracePlaces: no piece " + piece)
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	if not shadow:
		for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
			if g is GeometryInstance3D:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(n)
	return n


## A box no one walks through, `size` at `at` (in `n`'s space).
static func _box(n: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position = at
	body.add_child(shape)
	n.add_child(body)


static func _post_col(n: Node3D, radius: float, tall: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = tall
	shape.shape = c
	shape.position.y = tall * 0.5
	body.add_child(shape)
	n.add_child(body)


## The floor: the paving to look at, a flat slab under it to walk on (its
## top at 0, the slabs' tops 0..+2 cm), the unseen walls round it.
static func _floor(d: Dungeon, room: Node3D, piece: String, w: float, l: float) -> void:
	var slab := d._solid(room, _solid(0.0), Vector3(w + 2.0, 1.0, l + 2.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	var f := _piece(room, piece, Vector3.ZERO)
	if f != null:
		for g in f.find_children("*", "GeometryInstance3D", true, false) + [f]:
			if g is GeometryInstance3D:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._bounds(room, w, l)


## A run of balustrade from `a` to `b` (on the floor), posts between, and
## `corner` pieces at its two ends.
static func _rail(room: Node3D, a: Vector3, b: Vector3, rail: String, post: String, every := 4.0) -> void:
	var along := b - a
	var length := along.length()
	var n := maxi(1, int(round(length / every)))
	var yaw := atan2(-along.z, along.x)
	for k in n:
		var t := (float(k) + 0.5) / float(n)
		var seg := _piece(room, rail, a + along * t, yaw, 1.0)
		if seg != null:
			seg.scale.x = length / float(n) / 4.0
	for k in n + 1:
		_piece(room, post, a + along * (float(k) / float(n)), yaw)
	# one wall along it, waist high
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5)
	room.add_child(holder)
	_box(holder, Vector3(length + 0.6, 1.3, 0.7), Vector3(0.0, 0.65, 0.0))


## Cut stone under an edge from `a` to `b`, its top at the floor, and great
## rocks below it down to `depth`.
static func _edge(room: Node3D, a: Vector3, b: Vector3, piece: String, out: Vector3, rocks: String,
		_depth: float, rng: RandomNumberGenerator) -> void:
	var along := b - a
	var length := along.length()
	var n := maxi(1, int(ceil(length / 8.0)))
	var yaw := atan2(-along.z, along.x)
	for k in n:
		var t := (float(k) + 0.5) / float(n)
		var e := _piece(room, piece, a + along * t + out * 0.4, yaw)
		if e != null:
			e.scale.x = length / float(n) / 8.0 * 1.02
	if rocks == "":
		return
	var m := maxi(2, int(length / 14.0))
	for k in m:
		var t := (float(k) + rng.randf()) / float(m)
		var at := a + along * t + out * 1.5
		at.y = -4.5 - rng.randf_range(0.0, 3.0)
		var crag := _crag(room, rocks, at, rng.randf_range(0.5, 0.8), rng.randf_range(0.0, TAU), 0.0, 0.0, false)
		# out past the edge's face: not under the floor where it shows
		if crag != null:
			var src := _kit.get_node_or_null(rocks) as MeshInstance3D
			var reach := maxf(src.mesh.get_aabb().size.x, src.mesh.get_aabb().size.z) * 0.5 * crag.scale.x
			crag.position += out * (reach * 0.55)


## A great rock `piece` at `at` (x, z) with its top at `at.y`, `s` its size,
## pushed out (away from the middle) till it is clear of the floor `w` by
## `l` when `clear` (rocks are big: the floor must not be under them).
static func _crag(room: Node3D, piece: String, at: Vector3, s: float, yaw: float, w := 0.0, l := 0.0,
		clear := true) -> Node3D:
	var src := _kit.get_node_or_null(piece) as MeshInstance3D
	if src == null:
		return null
	var box := src.mesh.get_aabb()
	var reach := maxf(box.size.x, box.size.z) * 0.5 * s
	var p := Vector3(at.x, at.y - (box.position.y + box.size.y) * s, at.z)
	if clear and w > 0.0:
		var out := Vector3(at.x, 0.0, at.z)
		out = out.normalized() if out.length() > 0.1 else Vector3.RIGHT
		var tries := 0
		while absf(p.x) - reach < w * 0.5 + 1.0 and absf(p.z) - reach < l * 0.5 + 1.0 and tries < 60:
			p += out * 2.0
			tries += 1
	return _piece(room, piece, p, yaw, s, false)


static func _statue_mesh() -> Mesh:
	if _statue == null and ResourceLoader.exists(STATUE):
		_statue = load(STATUE) as Mesh
	return _statue


## A knight in bronze (the hero's own shape, as the sky temple's) on a tall
## plinth.
static func _knight(room: Node3D, at: Vector3, yaw: float, bronze: bool) -> void:
	var p := _piece(room, "PostPlinth", at, yaw)
	if p != null:
		_box(p, Vector3(1.4, 3.0, 1.4), Vector3(0.0, 1.5, 0.0))
	var m := _statue_mesh()
	if m == null:
		_piece(room, "KnightBronze" if bronze else "KnightSand", at, yaw)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.23, 0.12) if bronze else Color(0.74, 0.62, 0.47)
	mat.metallic = 0.75 if bronze else 0.0
	mat.roughness = 0.42 if bronze else 0.85
	mi.material_override = mat
	var aabb := m.get_aabb()
	var k := 2.6 / maxf(aabb.size.y, 0.01)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), at + Vector3(0.0, 2.15 - aabb.position.y * k, 0.0))
	room.add_child(mi)


## A brazier of bronze on its stone foot, its fire and its light.
static func _brazier(d: Dungeon, room: Node3D, at: Vector3, bright := 3.0) -> void:
	var b := _piece(room, "Brazier", at)
	if b != null:
		_post_col(b, 0.9, 1.6)
	room.add_child(d._flame(at + Vector3(0.0, 1.5, 0.0), 2.2, 36))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.32)
	light.light_energy = bright
	light.omni_range = 14.0
	light.position = at + Vector3(0.0, 2.6, 0.0)
	room.add_child(d._fire_light(light))


static func _tree(room: Node3D, piece: String, at: Vector3, yaw: float, s: float, solid := true) -> void:
	var n := _piece(room, piece, at, yaw, s)
	if n != null and solid:
		_post_col(n, 0.6, 6.0)


## Far mountains round about, out at `r0`..`r1`, along the bearings given
## (radians, 0 = −z, ahead), down to `base`.
static func _ring(room: Node3D, pieces: Array, r0: float, r1: float, bearings: Array, base: float,
		rng: RandomNumberGenerator, s0 := 1.0, s1 := 1.6) -> void:
	for a: float in bearings:
		var r := rng.randf_range(r0, r1)
		var at := Vector3(sin(a) * r, base, -cos(a) * r)
		_piece(room, String(pieces[rng.randi() % pieces.size()]), at, -a + rng.randf_range(-0.3, 0.3),
				rng.randf_range(s0, s1), false)


## Soft round motes of light in the air.
static func _motes(room: Node3D, w: float, l: float, tint: Color, amount := 160) -> void:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.position = Vector3(0.0, 4.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.5, 3.5, l * 0.5)
	pm.gravity = Vector3(0.0, -0.01, 0.0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.0))
	fade.add_point(0.5, Color(tint, 0.5))
	fade.set_color(fade.get_point_count() - 1, Color(tint, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = PlaceBuild.soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -5.0, -l) * 0.6, Vector3(w, 12.0, l) * 1.2)
	room.add_child(p)


## A white haze lying in a box (no colour of its own, so the place keeps its).
static func _haze(room: Node3D, at: Vector3, size: Vector3, density: float) -> void:
	if Graphics.current == Graphics.Level.LOW:
		return
	var fog := FogVolume.new()
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fog.size = size
	fog.position = at
	var m := FogMaterial.new()
	m.density = density
	m.albedo = Color(0.95, 0.96, 0.97)
	m.emission = Color(0.0, 0.0, 0.0)
	m.height_falloff = 0.05
	m.edge_fade = 0.8
	fog.material = m
	room.add_child(fog)


static func _water(room: Node3D, at: Vector3, size: float, colours: Dictionary = {}) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var steps := 90 if Graphics.current >= Graphics.Level.HIGH else 50
	plane.subdivide_width = steps
	plane.subdivide_depth = steps
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	var m := _code("lake", LAKE).duplicate() as ShaderMaterial
	for k: String in colours:
		m.set_shader_parameter(k, colours[k])
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	room.add_child(mi)
	return mi


## The trees thinned on the lower settings.
static func _grow() -> float:
	match Graphics.current:
		Graphics.Level.LOW:
			return 0.45
		Graphics.Level.MEDIUM:
			return 0.7
		Graphics.Level.ULTRA:
			return 1.3
	return 1.0


static func build(d: Dungeon, room: Node3D, kind: String, w: float, l: float, rng: RandomNumberGenerator) -> void:
	_ready_kit()
	match kind:
		"lake":
			_lake(d, room, w, l, rng)
		"fort":
			_fort(d, room, w, l, rng)
		"falls":
			_falls(d, room, w, l, rng)
		"clouds":
			_clouds(d, room, w, l, rng)


#region The lake
## (2026-10-24, the user on the first pass: the mountains out of the style,
## the lake not like a lake, trees in the air and in the water, bits of the
## terrace hanging in the air, everything one colour, no fires. Now: the
## land round the lake is one faceted piece from Blender — the promontory
## the terrace stands on, steep down into the water, the shores' beaches and
## stepped cliffs, islands, the woods standing on it as it lies; the floor
## cream with a slate border and rose rings, the pots terracotta, the
## palace's face with a slate cornice and a terracotta roof, blue banners.)
static func _lake(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	_floor(d, room, "LFloor", w, l)
	# the balustrade round three sides; the palace's face at the near end
	_rail(room, Vector3(-hw - 0.3, 0.0, hl), Vector3(-hw - 0.3, 0.0, -hl - 0.3), "BalusMarble", "PostMarble")
	_rail(room, Vector3(hw + 0.3, 0.0, -hl - 0.3), Vector3(hw + 0.3, 0.0, hl), "BalusMarble", "PostMarble")
	_rail(room, Vector3(-hw - 0.3, 0.0, -hl - 0.3), Vector3(hw + 0.3, 0.0, -hl - 0.3), "BalusMarble", "PostMarble")
	var face := _piece(room, "LFacade", Vector3(0.0, 0.0, hl + 2.2), PI)
	if face != null:
		_box(face, Vector3(34.0, 15.0, 2.0), Vector3(0.0, 7.5, 0.0))
	for sx: float in [-1.0, 1.0]:
		_rail(room, Vector3(sx * 17.2, 0.0, hl + 0.6), Vector3(sx * (hw + 0.3), 0.0, hl + 0.6), "BalusMarble", "PostMarble")
		# blue banners down the palace's face, either side of its arch
		for bx: float in [6.5, 12.5]:
			_piece(room, "BannerBlue", Vector3(sx * bx, 12.6, hl + 0.9), PI)
	# the knights at the corners; great bronze urns where the fires were
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_knight(room, Vector3(c.x * (hw + 1.6), 0.0, c.y * (hl - 1.5) if c.y > 0 else -hl - 1.6), PI if c.y < 0 else 0.0, true)
	for at: Vector3 in [Vector3(-19.0, 0.0, -hl + 5.0), Vector3(19.0, 0.0, -hl + 5.0), Vector3(-19.0, 0.0, hl - 12.0),
			Vector3(19.0, 0.0, hl - 12.0)]:
		var urn := _piece(room, "UrnBronze", at, rng.randf_range(0.0, TAU), 1.3)
		if urn != null:
			_post_col(urn, 0.9, 2.4)
	# the terrace's face of cut stone along its edges, on the promontory's rock
	_edge(room, Vector3(-hw - 0.6, 0.0, hl + 1.0), Vector3(-hw - 0.6, 0.0, -hl - 0.6), "EdgeMarble", Vector3.LEFT, "", 0.0, rng)
	_edge(room, Vector3(hw + 0.6, 0.0, -hl - 0.6), Vector3(hw + 0.6, 0.0, hl + 1.0), "EdgeMarble", Vector3.RIGHT, "", 0.0, rng)
	_edge(room, Vector3(-hw - 0.6, 0.0, -hl - 0.6), Vector3(hw + 0.6, 0.0, -hl - 0.6), "EdgeMarble", Vector3.FORWARD, "", 0.0, rng)
	# the land round the lake and its woods (one piece each), the water
	var land := _piece(room, "LLand", Vector3.ZERO, 0.0, 1.0, false)
	if land != null:
		for g in land.find_children("*", "GeometryInstance3D", true, false) + [land]:
			if g is GeometryInstance3D:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_piece(room, "LTrees", Vector3.ZERO, 0.0, 1.0, Graphics.current >= Graphics.Level.HIGH)
	var lake_y := -38.0
	_water(room, Vector3(0.0, lake_y, -160.0), 1000.0)
	# cypresses in terracotta pots down both sides, benches between them
	var z := -hl + 5.0
	while z < hl - 8.0:
		for sx: float in [-1.0, 1.0]:
			var pot := _piece(room, "PlanterMarble", Vector3(sx * (hw - 1.3), 0.0, z))
			if pot != null:
				_box(pot, Vector3(1.5, 1.2, 1.5), Vector3(0.0, 0.6, 0.0))
			_piece(room, "Cypress%d" % (absi(int(z)) % 2), Vector3(sx * (hw - 1.3), 0.95, z), rng.randf_range(0.0, TAU),
					rng.randf_range(0.85, 1.0))
			if z + 4.5 < hl - 8.0:
				var b := _piece(room, "BenchMarble", Vector3(sx * (hw - 1.1), 0.0, z + 4.5), PI * 0.5)
				if b != null:
					_box(b, Vector3(2.8, 0.6, 0.7), Vector3(0.0, 0.3, 0.0))
		z += 9.0
	d._circling_birds(room)
	# mist lying on the water, motes of light on the terrace
	_haze(room, Vector3(0.0, lake_y + 4.0, -170.0), Vector3(520.0, 14.0, 520.0), 0.005)
	_motes(room, w, l, Color(1.0, 0.95, 0.82))
#endregion


#region The fortress
static func _fort(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	_floor(d, room, "FFloor", w, l)
	# the wall down the left and across both ends, towers at the corners;
	# the right side open over the valley behind the balustrade
	var walls: Array = [
		[Vector3(-hw - 1.0, 0.0, hl), Vector3(-hw - 1.0, 0.0, -hl - 1.0)],
		[Vector3(-hw - 1.0, 0.0, -hl - 1.0), Vector3(hw + 1.0, 0.0, -hl - 1.0)],
		[Vector3(hw + 1.0, 0.0, hl + 1.0), Vector3(-hw - 1.0, 0.0, hl + 1.0)],
	]
	for pair: Array in walls:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		var along := b - a
		var n := int(ceil(along.length() / 8.0))
		var yaw := atan2(-along.z, along.x)
		for k in n:
			var at := a + along * ((float(k) + 0.5) / float(n))
			# a gate in the far wall, off to the left; the way in at the near one
			var gate: bool = (pair == walls[1] and k == 1) or (pair == walls[2] and k == int(n / 2.0))
			var piece := "FGate" if gate else "FWall"
			var seg := _piece(room, piece, at, yaw)
			if seg != null:
				if not gate:
					seg.scale.x = along.length() / float(n) / 8.0 * 1.01
				_box(seg, Vector3(8.2, 9.0, 2.2), Vector3(0.0, 4.5, 0.0))
	for at: Vector3 in [Vector3(-hw - 2.0, 0.0, -hl - 2.0), Vector3(-hw - 2.0, 0.0, hl + 2.0), Vector3(hw + 2.0, 0.0, -hl - 2.0)]:
		var t := _piece(room, "FTower", at, rng.randf_range(0.0, TAU))
		if t != null:
			_post_col(t, 3.5, 16.0)
	_piece(room, "FTowerTall", Vector3(-hw - 9.0, 0.0, -hl - 9.0), 0.4)
	_piece(room, "FTowerTall", Vector3(-hw - 12.0, 0.0, 6.0), 1.2)
	_rail(room, Vector3(hw + 0.4, 0.0, -hl - 0.2), Vector3(hw + 0.4, 0.0, hl + 0.2), "BalusSand", "PostSand")
	_edge(room, Vector3(hw + 0.7, 0.0, -hl - 2.0), Vector3(hw + 0.7, 0.0, hl + 2.0), "EdgeSand", Vector3.RIGHT, "Cliff1", 60.0, rng)
	# the lord's banners down the walls' inner faces, fires by the gate,
	# a striped tent and stores in the yard's near corner
	var bz := -hl + 6.0
	while bz < hl - 4.0:
		_piece(room, "BannerLong", Vector3(-hw + 0.1, 7.6, bz), PI * 0.5)
		bz += 10.0
	for bx: float in [-hw + 6.0, -hw + 16.0, hw - 16.0]:
		_piece(room, "BannerLong", Vector3(bx, 7.6, -hl + 0.1), 0.0)
	var gate_x := -hw - 1.0 + 1.5 * (w + 2.0) / ceilf((w + 2.0) / 8.0)
	for gx: float in [gate_x - 4.6, gate_x + 4.6]:
		_brazier(d, room, Vector3(gx, 0.0, -hl + 2.2), 3.2)
	var tent := _piece(room, "FTent", Vector3(hw - 5.5, 0.0, hl - 6.5), 0.4)
	if tent != null:
		_post_col(tent, 2.6, 4.0)
	for k in 7:
		var at := Vector3(hw - 2.0 - rng.randf_range(0.0, 3.0), 0.0, hl - 12.0 - rng.randf_range(0.0, 5.0)) if k < 4 \
				else Vector3(-hw + 2.0 + rng.randf_range(0.0, 3.0), 0.0, -hl + 8.0 + rng.randf_range(0.0, 4.0))
		var thing := _piece(room, "Barrel" if k % 2 == 0 else "Crate", at, rng.randf_range(0.0, TAU))
		if thing != null:
			_post_col(thing, 0.5, 1.0)
	d._circling_birds(room)
	# pines in the corners by the walls
	for at: Vector3 in [Vector3(-hw + 3.0, 0.0, hl - 4.0), Vector3(-hw + 2.5, 0.0, hl - 11.0), Vector3(-hw + 3.0, 0.0, -hl + 3.0),
			Vector3(hw - 3.5, 0.0, hl - 3.5)]:
		_tree(room, "Pine%d" % rng.randi_range(0, 2), at, rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.15))
	# under it: the crag, the valley far below, the peaks beyond
	for k in 8:
		_crag(room, ["Cliff1", "Cliff0"][k % 2], Vector3(hw * 0.5, -5.0, -hl + float(k) * l / 7.0),
				rng.randf_range(1.0, 1.4), rng.randf_range(0.0, TAU), 0.0, 0.0, false)
	_piece(room, "FValley", Vector3(180.0, -95.0, -80.0), 0.3, 1.6, false)
	var grow := _grow()
	for k in int(70 * grow):
		var at := Vector3(rng.randf_range(60.0, 320.0), -90.0, rng.randf_range(-260.0, 140.0))
		_piece(room, "Pine%d" % (k % 3), at, rng.randf_range(0.0, TAU), rng.randf_range(2.0, 3.0), false)
	_ring(room, ["Mount2", "Mount0"], 480.0, 620.0, [0.35, 0.8, 1.25, 1.7, 2.15, -0.1], -90.0, rng, 1.4, 2.0)
	_ring(room, ["Mount1"], 330.0, 400.0, [0.6, 1.4, 2.0], -95.0, rng, 1.2, 1.5)
	_haze(room, Vector3(200.0, -60.0, -80.0), Vector3(600.0, 60.0, 600.0), 0.004)
	_motes(room, w, l, Color(1.0, 0.88, 0.62))
#endregion


#region The falls
static func _falls(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	_floor(d, room, "WFloor", w, l)
	# the earth under the broken slabs, brown (no grass)
	var earth := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 2.0, l + 2.0)
	earth.mesh = plane
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(0.36, 0.27, 0.19)
	em.roughness = 1.0
	earth.material_override = em
	earth.position.y = -0.06
	room.add_child(earth)
	# the cliff behind on the left, the portico against it, broken columns
	# round the edges, a fallen statue and stones lying about
	for k in 7:
		_crag(room, ["CliffRed1", "CliffRed0"][k % 2], Vector3(-hw - 2.0, rng.randf_range(10.0, 22.0), -hl + float(k) * l / 6.0),
				rng.randf_range(0.7, 1.0), rng.randf_range(0.0, TAU), w, l)
	# and the crag under it all
	for k in 6:
		_crag(room, ["CliffRed1", "CliffRed0"][k % 2], Vector3(rng.randf_range(-hw, hw) * 0.5, -5.0, -hl + float(k) * l / 5.0),
				rng.randf_range(1.0, 1.3), rng.randf_range(0.0, TAU), 0.0, 0.0, false)
	var por := _piece(room, "WPortico", Vector3(-hw + 1.0, 0.0, -2.0), -PI * 0.5)
	if por != null:
		_box(por, Vector3(9.0, 8.0, 4.0), Vector3(0.0, 4.0, -0.6))
	var cols := [Vector3(-hw + 1.5, 0.0, hl - 2.0), Vector3(-hw + 1.5, 0.0, -hl + 3.0), Vector3(hw - 1.2, 0.0, hl - 2.0),
			Vector3(hw - 1.2, 0.0, hl - 14.0), Vector3(hw - 1.2, 0.0, 0.0), Vector3(hw - 1.2, 0.0, -14.0),
			Vector3(-hw + 13.0, 0.0, -hl + 1.2), Vector3(hw - 13.0, 0.0, -hl + 1.2)]
	for k in cols.size():
		var piece := "ColRuin" if k % 3 == 0 else ("ColRuinBroken" if k % 3 == 1 else "ColRuinBroken2")
		var c := _piece(room, piece, cols[k], rng.randf_range(0.0, TAU))
		if c != null:
			_post_col(c, 0.75, 6.0)
	var fallen := _piece(room, "WFallen", Vector3(hw - 7.0, 0.0, 9.0), 0.7)
	if fallen != null:
		_box(fallen, Vector3(3.2, 1.0, 1.2), Vector3(0.0, 0.5, 0.0))
	for at: Vector3 in [Vector3(-hw + 5.0, 0.0, 14.0), Vector3(hw - 4.0, 0.0, -6.0), Vector3(4.0, 0.0, hl - 2.5)]:
		_piece(room, "WRubble", at, rng.randf_range(0.0, TAU))
	# a pier and half its arch still standing
	var arch := _piece(room, "WArchBroken", Vector3(-hw + 3.0, 0.0, -hl + 16.0), PI * 0.5)
	if arch != null:
		_post_col(arch, 0.85, 6.0)
	for at: Vector3 in [Vector3(-hw + 2.0, 0.0, 8.0), Vector3(-hw + 2.0, 0.0, -8.0), Vector3(hw - 2.0, 0.0, 20.0)]:
		_tree(room, "Cypress%d" % rng.randi_range(0, 1), at, rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.15))
	d._circling_birds(room)
	# broken rail along the open right side and the far end
	for k in 8:
		if rng.randf() < 0.35:
			continue
		var z := -hl + (float(k) + 0.5) * l / 8.0
		var seg := _piece(room, "BalusSand", Vector3(hw + 0.4, 0.0, z), PI * 0.5)
		if seg != null:
			seg.scale.x = rng.randf_range(0.6, 1.0)
	d._blocker(room, Vector3(0.8, 1.3, l + 2.0), Vector3(hw + 0.4, 0.65, 0.0))
	_edge(room, Vector3(hw + 0.7, 0.0, -hl - 1.0), Vector3(hw + 0.7, 0.0, hl + 1.0), "EdgeRuin", Vector3.RIGHT, "CliffRed0", 50.0, rng)
	_edge(room, Vector3(-hw - 1.0, 0.0, -hl - 0.7), Vector3(hw + 1.0, 0.0, -hl - 0.7), "EdgeRuin", Vector3.FORWARD, "CliffRed1", 50.0, rng)
	# the gnarled trees leaning out over the edge at two corners
	_tree(room, "TreeLean", Vector3(hw - 2.5, 0.0, hl - 6.0), PI * 0.0 + 0.2, 1.1)
	_tree(room, "TreeLean", Vector3(-hw + 3.0, 0.0, -hl + 7.0), PI * 0.8, 1.0)
	# across the gorge: the red rock wall, the waterfall down it, the river
	_piece(room, "WGorge", Vector3(40.0, -105.0, -30.0), 0.0, 1.0, false)
	var falls_at := Vector3(hw + 58.0, 34.0, -24.0)
	_crag(room, "CliffRed1", falls_at + Vector3(26.0, 3.0, 22.0), 1.6, 0.4, 0.0, 0.0, false)
	_crag(room, "CliffRed1", falls_at + Vector3(26.0, 6.0, -26.0), 1.6, 1.9, 0.0, 0.0, false)
	_crag(room, "CliffRed0", falls_at + Vector3(30.0, -1.0, 0.0), 1.5, 2.8, 0.0, 0.0, false)
	var fall := _piece(room, "WFalls", falls_at, -PI * 0.5, 1.4, false)
	if fall != null:
		fall.scale = Vector3(1.4, 1.6, 1.4)
	_water(room, Vector3(40.0, -95.0, -60.0), 900.0, {"shallow": Color(0.30, 0.62, 0.72), "deep": Color(0.12, 0.34, 0.46),
			"wave": 0.6})
	_spray(room, falls_at + Vector3(-4.0, -128.0, 0.0))
	_haze(room, falls_at + Vector3(-10.0, -100.0, 0.0), Vector3(120.0, 60.0, 120.0), 0.012)
	_ring(room, ["Mount0", "Mount2"], 420.0, 560.0, [-1.4, -0.7, 0.0, 0.7, 1.4, 2.0], -90.0, rng, 1.2, 1.7)
	_motes(room, w, l, Color(1.0, 0.95, 0.84))


## The spray where the falls come down: soft round puffs rising.
static func _spray(room: Node3D, at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(8.0, 2.0, 8.0)
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0.0, -0.3, 0.0)
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.add_point(0.3, Color(1, 1, 1, 0.35))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(9.0, 9.0)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = PlaceBuild.soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 60, 60))
	room.add_child(p)
#endregion


#region The court over the clouds
static func _clouds(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	_floor(d, room, "CFloor", w, l)
	# the colonnade down the left: a bay every 5.9 m, banners on its piers
	var bay := 5.9
	var n := int(ceil((l + 2.0) / bay))
	for k in n:
		var z := -hl - 1.0 + (float(k) + 0.5) * (l + 2.0) / float(n)
		var a := _piece(room, "CArcade", Vector3(-hw - 1.0, 0.0, z), -PI * 0.5)
		if a != null:
			a.scale.x = (l + 2.0) / float(n) / bay
		if k % 2 == 0:
			_piece(room, "BannerLong", Vector3(-hw + 0.1, 8.6, z - (l + 2.0) / float(n) * 0.5), -PI * 0.5)
	d._blocker(room, Vector3(2.0, 14.0, l + 2.0), Vector3(-hw - 1.0, 7.0, 0.0))
	# behind the arcade, the gallery's back wall and floor
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.70, 0.60, 0.47)
	stone.roughness = 0.9
	d._solid(room, stone, Vector3(1.2, 14.0, l + 6.0), Vector3(-hw - 7.5, 7.0, 0.0), false)
	_piece(room, "CGallery", Vector3(-hw - 4.6, 0.0, 0.0))
	# the near end: arches across it, the way in through the middle one
	var m := int(ceil((w + 2.0) / bay))
	for k in m:
		var x := -hw - 1.0 + (float(k) + 0.5) * (w + 2.0) / float(m)
		var a := _piece(room, "CArcadeEnd", Vector3(x, 0.0, hl + 1.0), PI)
		if a != null:
			a.scale.x = (w + 2.0) / float(m) / bay
	d._blocker(room, Vector3(w + 2.0, 14.0, 2.0), Vector3(0.0, 7.0, hl + 1.0))
	# the right side and the far end open over the clouds behind a rail
	_rail(room, Vector3(hw + 0.4, 0.0, hl + 0.2), Vector3(hw + 0.4, 0.0, -hl - 0.4), "BalusSand", "PostSand")
	_rail(room, Vector3(hw + 0.4, 0.0, -hl - 0.4), Vector3(-hw - 0.4, 0.0, -hl - 0.4), "BalusSand", "PostSand")
	_edge(room, Vector3(hw + 0.7, 0.0, hl + 2.0), Vector3(hw + 0.7, 0.0, -hl - 0.7), "EdgeSand", Vector3.RIGHT, "CliffRed1", 70.0, rng)
	_edge(room, Vector3(hw + 0.7, 0.0, -hl - 0.7), Vector3(-hw - 8.0, 0.0, -hl - 0.7), "EdgeSand", Vector3.FORWARD, "CliffRed1", 70.0, rng)
	# domed pavilions at the open corners
	for at: Vector3 in [Vector3(hw + 2.5, 0.0, -hl - 2.5), Vector3(hw + 2.5, 0.0, hl + 2.5), Vector3(-hw - 4.0, 0.0, -hl - 3.0)]:
		var p := _piece(room, "CPavilion", at, 0.0)
		if p != null:
			_box(p, Vector3(3.6, 10.0, 3.6), Vector3(0.0, 5.0, 0.0))
	# the lord's throne on its dais at the far end, a brazier either side
	# (his guard come out of their fire: [LordFight], at ±6.5, −l/2+9)
	var dais := _piece(room, "CDais", Vector3(0.0, 0.0, -hl + 4.0), 0.0)
	if dais != null:
		_box(dais, Vector3(12.0, 0.9, 6.0), Vector3(0.0, 0.45, 0.0))
		_box(dais, Vector3(2.4, 4.5, 2.0), Vector3(0.0, 2.2, -1.6))
	for sx: float in [-1.0, 1.0]:
		_brazier(d, room, Vector3(sx * 7.6, 0.0, -hl + 4.5), 3.6)
		_knight(room, Vector3(sx * 12.0, 0.0, -hl + 1.5), 0.0, false)
	# cypresses in sandstone pots along the open side, urns between them
	var cz := -hl + 6.0
	while cz < hl - 4.0:
		var pot := _piece(room, "PlanterSand", Vector3(hw - 1.4, 0.0, cz))
		if pot != null:
			_box(pot, Vector3(1.5, 1.2, 1.5), Vector3(0.0, 0.6, 0.0))
		_piece(room, "Cypress%d" % (absi(int(cz)) % 2), Vector3(hw - 1.4, 0.95, cz), rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.05))
		cz += 10.0
	for at: Vector3 in [Vector3(hw + 2.5, 9.0, -hl - 2.5), Vector3(hw + 2.5, 9.0, hl + 2.5)]:
		_piece(room, "Banner", at + Vector3(-1.9, 0.0, 0.0), PI * 0.5)
	d._circling_birds(room)
	# the sea of cloud below, close under it (as the island's), rock under it
	d._cloud_layers(room, -40.0)
	for k in 6:
		_crag(room, ["CliffRed1", "CliffRed0"][k % 2], Vector3(rng.randf_range(-hw, hw) * 0.5, -6.0, rng.randf_range(-hl, hl) * 0.5),
				rng.randf_range(1.0, 1.4), rng.randf_range(0.0, TAU), 0.0, 0.0, false)
	_ring(room, ["Mount2", "Mount0"], 520.0, 700.0, [-0.8, -0.2, 0.5, 1.1, 1.7], -120.0, rng, 1.6, 2.2)
	_motes(room, w, l, Color(1.0, 0.92, 0.7), 200)
#endregion
