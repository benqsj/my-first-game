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
## The hall's round window's stained glass (2026-10-26): its panes' own
## colours, lit through from behind, both faces.
const ROSE_GLASS := """
shader_type spatial;
render_mode cull_disabled, unshaded;
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * 1.35;
}
"""
const LP := "res://assets/dungeon/forest_glade/"
const STATUE := "res://assets/dungeon/sky_temple/statue.res"
## The heroes' statues, each baked as he stands (`_shots_tmp/bake_statues.gd`);
## each place its own heroes (the user's word, 2026-10-24: not the swordsman
## everywhere).
const STATUES := "res://assets/dungeon/statues/%s.res"
## The golden hall's look: "d" the open hall, the game's (the user's pick,
## 2026-10-24); "a" walled all round, "b" the orcs' dusk, "c" the bright
## white hall (the other looks shown, kept to choose from).
static var hall_look := ""
## Rain in the golden hall's storm (F1's board turns it on and off; the
## thunder and the lightning in the clouds go on either way).
static var hall_rain := true
## The golden hall's weather: "storm" (dark, thunder, lightning, rain if
## [member hall_rain]) or "sun" (the bright afternoon). F2's board.
static var hall_mood := "storm"

const PLACE_HEROES := {
	"lake": ["avtandil", "elf_mage", "rogue", "warrior"],
	"gold_hall": ["tariel", "mage"],
	"clouds": ["dark_mage", "dark_archer"],
	"fort": ["elf_archer", "dark_rogue"],
	"falls": ["warrior", "avtandil"],
}

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
uniform float wave = 0.45;
uniform float scale = 0.05;
uniform float speed = 0.5;
uniform float depth_reach = 9.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
varying vec3 wp;
varying float crest;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = sin(w.x * scale * 1.3 + TIME * speed) * 0.5 + sin(w.z * scale * 1.7 - TIME * speed * 0.8) * 0.35
			+ sin((w.x + w.z) * scale * 3.1 + TIME * speed * 1.4) * 0.15
			+ (vnoise(w.xz * 0.02 + vec2(TIME * 0.03, TIME * 0.02)) - 0.5) * 0.8;
	VERTEX.y += h * wave;
	crest = h;
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
	k = floor(k * 5.0) / 5.0;
	vec3 c = mix(shallow.rgb, deep.rgb, k);
	// slow patches of lighter and darker water drifting over it
	float drift = vnoise(wp.xz * 0.012 + vec2(TIME * 0.015, -TIME * 0.01));
	c *= 0.92 + 0.16 * floor(drift * 4.0) / 4.0;
	// the crests a little lighter, as the light catches them
	c = mix(c, c * 1.25 + vec3(0.04), smoothstep(0.35, 0.75, crest));
	// streaks of wind on the water, moving
	float wind = vnoise(vec2(wp.x * 0.05 + TIME * 0.12, wp.z * 0.012));
	c += vec3(0.05) * step(0.72, wind);
	float dist = length(VERTEX);
	c = mix(c, far_col.rgb, clamp((dist - 260.0) / 500.0, 0.0, 0.7));
	float fres = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), 3.0);
	c = mix(c, far_col.rgb, fres * 0.45);
	// a white line where it laps the shore
	float lap = 1.0 - smoothstep(0.15, 0.9, depth + 0.25 * sin(TIME * 1.2 + wp.x * 0.3 + wp.z * 0.2));
	c = mix(c, foam.rgb, lap * 0.85);
	// glints of the sun winking on it
	vec2 cell = floor(wp.xz * 0.7);
	float glint = step(0.992, hash(cell + floor(TIME * 1.5 + hash(cell) * 7.0)));
	ALBEDO = c;
	EMISSION = vec3(1.0, 0.97, 0.88) * glint * 1.6 * (1.0 - clamp(dist / 300.0, 0.0, 1.0));
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
static var _statues := {}


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
				"RoseGlass":
					mi.set_surface_override_material(s, _code("rose_glass", ROSE_GLASS))
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


static func _statue_mesh(hero: String = "") -> Mesh:
	if hero != "" and ResourceLoader.exists(STATUES % hero):
		if not _statues.has(hero):
			_statues[hero] = load(STATUES % hero) as Mesh
		return _statues[hero]
	if _statue == null and ResourceLoader.exists(STATUE):
		_statue = load(STATUE) as Mesh
	return _statue


## A knight in bronze (the hero's own shape, as the sky temple's) on a tall
## plinth.
static func _knight(room: Node3D, at: Vector3, yaw: float, bronze: bool, hero: String = "") -> void:
	var p := _piece(room, "PostPlinth", at, yaw)
	if p != null:
		_box(p, Vector3(1.4, 3.0, 1.4), Vector3(0.0, 1.5, 0.0))
	var m := _statue_mesh(hero)
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
			# the yard remade after the concept (2026-10-26) [FortYard]; the
			# first pass, `_fort`, kept
			FortYard.build(d, room, w, l, rng)
		"falls":
			# the ruins remade after the concept (2026-10-26) [FallsRuin];
			# the first pass, `_falls`, kept
			FallsRuin.build(d, room, w, l, rng)
		"clouds":
			_clouds(d, room, w, l, rng)
		"gold_hall":
			_gold_hall(d, room, w, l, rng)


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
	var heroes: Array = PLACE_HEROES["lake"]
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for k in corners.size():
		var c: Vector2 = corners[k]
		_knight(room, Vector3(c.x * (hw + 1.6), 0.0, c.y * (hl - 1.5) if c.y > 0 else -hl - 1.6), PI if c.y < 0 else 0.0,
				true, String(heroes[k % heroes.size()]))
	# a ward of light across the palace's doorway: no one goes back that way
	# (the user, 2026-10-24: the door as it was, a magic barrier in it)
	_ward(room, Vector3(0.0, 0.0, hl + 1.4), Vector2(7.2, 9.6))
	_boats(d, room, rng)
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
				var b := _piece(room, ["BenchMarble", "BenchRose", "BenchGreen"][rng.randi() % 3],
						Vector3(sx * (hw - 1.1), 0.0, z + 4.5), PI * 0.5)
				if b != null:
					_box(b, Vector3(2.8, 0.6, 0.7), Vector3(0.0, 0.3, 0.0))
		z += 9.0
	d._circling_birds(room)
	# mist lying on the water, motes of light on the terrace
	_haze(room, Vector3(0.0, lake_y + 4.0, -170.0), Vector3(520.0, 14.0, 520.0), 0.005)
	_motes(room, w, l, Color(1.0, 0.95, 0.82))
## A ward of light filling a doorway (no one wants to go that way): a veil
## in the shape of its arch, deep blue in the middle, bright at its rim,
## lines of light rising through it, a slow ripple, sparks drifting up in it
## and a little blue light on the stone round it.
const WARD := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 deep : source_color = vec4(0.10, 0.28, 0.85, 1.0);
uniform vec4 rim : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.85, 0.5, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// how far inside the arch (1 at its middle line, 0 at its edge, < 0 outside)
float arch(vec2 uv) {
	vec2 q = vec2((uv.x - 0.5) * 2.0, 1.0 - uv.y);
	float top = 0.62;
	float d = q.y < top ? abs(q.x) : length(vec2(q.x, (q.y - top) / (1.0 - top)));
	return 1.0 - d;
}
void fragment() {
	vec2 uv = UV;
	float a = arch(uv);
	if (a < 0.0) { discard; }
	float t = TIME;
	// a slow ripple across it
	vec2 w = uv + vec2(sin(uv.y * 9.0 + t * 1.3) * 0.012, sin(uv.x * 7.0 - t) * 0.008);
	// lines of light rising
	float lines = pow(abs(sin(w.x * 46.0 + vnoise(vec2(w.x * 8.0, t * 0.3)) * 3.0)), 18.0);
	float rise = vnoise(vec2(w.x * 22.0, w.y * 3.0 - t * 0.9));
	lines *= smoothstep(0.35, 0.9, rise);
	// soft clouds of light moving in it
	float cloud = vnoise(w * vec2(5.0, 3.0) + vec2(0.0, -t * 0.35)) * 0.6 + vnoise(w * vec2(11.0, 7.0) + vec2(t * 0.2, 0.0)) * 0.4;
	// the bright rim, and a thin gold line inside it
	float edge = 1.0 - smoothstep(0.0, 0.12, a);
	float inner = smoothstep(0.10, 0.13, a) * (1.0 - smoothstep(0.13, 0.16, a));
	float breath = 0.85 + 0.15 * sin(t * 1.7);
	vec3 c = deep.rgb * (0.25 + 0.45 * cloud) + rim.rgb * (edge * 1.4 + lines * 0.9) + gold.rgb * inner * 0.8;
	// sparkles
	vec2 cell = floor(uv * vec2(28.0, 40.0) + vec2(0.0, -t * 3.0));
	c += rim.rgb * step(0.985, hash(cell)) * 1.2;
	ALBEDO = c * breath;
}
"""


static func _ward(room: Node3D, at: Vector3, size: Vector2) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _code("ward", WARD)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0.0, size.y * 0.5, 0.0)
	room.add_child(mi)
	# no one through it
	var block := Node3D.new()
	block.position = at
	room.add_child(block)
	_box(block, Vector3(size.x + 0.4, size.y, 0.8), Vector3(0.0, size.y * 0.5, 0.0))
	# its light on the stone round it
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.7, 1.0)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = at + Vector3(0.0, 3.0, -1.2)
	room.add_child(light)
	# sparks drifting up in it, soft and round
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = at + Vector3(0.0, 0.3, -0.2)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(size.x * 0.42, 0.2, 0.25)
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	var fade := Gradient.new()
	fade.set_color(0, Color(0.6, 0.85, 1.0, 0.0))
	fade.add_point(0.3, Color(0.7, 0.9, 1.0, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(0.6, 0.85, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.12, 0.12)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.vertex_color_use_as_albedo = true
	dm.albedo_texture = PlaceBuild.soft_dot()
	dot.material = dm
	p.draw_pass_1 = dot
	p.visibility_aabb = AABB(Vector3(-6, -1, -2), Vector3(12, 12, 4))
	room.add_child(p)


## Blood where they fell (the orcs' own stains, [OrcSpoils]): a pool at each
## spot and a smear dragged off it. The box short: decals tint feet.
static func _blood(room: Node3D, spots: Array, rng: RandomNumberGenerator) -> void:
	OrcSpoils._materials()
	for at: Vector3 in spots:
		for k in 2:
			var decal := Decal.new()
			decal.texture_albedo = OrcSpoils._blood_tex
			var s := rng.randf_range(2.4, 3.8)
			decal.size = Vector3(s * (1.0 if k == 0 else 0.6), 0.5, s * (1.0 if k == 0 else 2.2))
			# (the stain's own colour is near black: lifted to a deep red)
			decal.modulate = Color(2.0, 0.7, 0.65)
			var yaw := rng.randf_range(0.0, TAU)
			decal.position = at + (Vector3.ZERO if k == 0 else Vector3(sin(yaw), 0.0, cos(yaw)) * s * 0.9) + Vector3(0.0, 0.05, 0.0)
			decal.rotation.y = yaw
			decal.upper_fade = 0.3
			decal.lower_fade = 0.3
			room.add_child(decal)


## Boats out on the lake (the user's word, 2026-10-24): some afloat, two
## burning and smoking, wrecks and their planks drifting; few faces (seen
## far off), each bobbing on the swell.
static func _boats(_d: Dungeon, room: Node3D, rng: RandomNumberGenerator) -> void:
	var water := -38.0
	var list := [
		["Boat", Vector3(-60.0, water, -130.0), false], ["BoatSmall", Vector3(40.0, water, -110.0), false],
		["Boat", Vector3(70.0, water, -190.0), true], ["BoatSmall", Vector3(-30.0, water, -230.0), true],
		["Boat", Vector3(-150.0, water, -150.0), false], ["Wreck", Vector3(15.0, water, -160.0), true],
		["Wreck", Vector3(-80.0, water, -290.0), true], ["Wreck", Vector3(150.0, water, -150.0), false],
		["BoatSmall", Vector3(-120.0, water, -260.0), false],
	]
	for b: Array in list:
		var holder := Node3D.new()
		holder.position = b[1]
		holder.rotation.y = rng.randf_range(0.0, TAU)
		room.add_child(holder)
		var piece := String(b[0])
		var boat := _piece(holder, piece, Vector3(0.0, -0.5 if piece != "Wreck" else -0.1, 0.0), 0.0, 2.2, false)
		if boat != null:
			# a burnt one leans over, blackened
			if bool(b[2]) and piece != "Wreck":
				boat.rotation.z = rng.randf_range(0.15, 0.35)
		if bool(b[2]):
			_smoke(holder)
		# the swell under it
		var tw := holder.create_tween().set_loops()
		var t := rng.randf_range(2.6, 3.8)
		var tilt := rng.randf_range(0.03, 0.06)
		tw.tween_property(holder, "rotation:x", tilt, t).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(holder, "position:y", water + 0.15, t).set_trans(Tween.TRANS_SINE)
		tw.tween_property(holder, "rotation:x", -tilt, t).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(holder, "position:y", water - 0.15, t).set_trans(Tween.TRANS_SINE)


## Smoke going up off a burnt boat: soft round dark puffs, rising, spreading.
static func _smoke(holder: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = Vector3(0.0, 1.5, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.8
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0.35, 0.15, 0.0)
	pm.damping_min = 0.1
	pm.damping_max = 0.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(1.0, 1.0))
	var gt := CurveTexture.new()
	gt.curve = grow
	pm.scale_curve = gt
	var fade := Gradient.new()
	fade.set_color(0, Color(0.16, 0.15, 0.14, 0.0))
	fade.add_point(0.15, Color(0.18, 0.17, 0.16, 0.7))
	fade.set_color(fade.get_point_count() - 1, Color(0.45, 0.45, 0.46, 0.0))
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
	p.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 70, 60))
	holder.add_child(p)
#endregion


#region The golden hall
## The palace's great hall, after the sketch the user chose (2026-10-24):
## pale cut stone with gold trim, tall windows down the sides, a round window
## over the throne, two rows of cream columns with gilded capitals, the
## timber roof broken open so the sun comes down in shafts, a cream floor
## with rose lines and diamonds down the aisle, crimson banners, shields on
## the walls, the feast's tables left laid, two heroes' statues by the
## throne. No rubble on the floor (the user's word).
static func _gold_hall(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var hw := w * 0.5
	var hl := l * 0.5
	var h := 18.0
	var look := hall_look if hall_look != "" else "d"
	var white := look == "c"
	var open_side := look == "d"
	var orcs := look == "b"
	_floor(d, room, "HFloorT" if white else "HFloor", w, l)
	if not white:
		# a long crimson runner from the doors to the throne's steps
		var run := _piece(room, "HCarpet", Vector3(0.0, 0.0, 2.6), 0.0, 1.0, false)
		if run != null:
			run.scale.z = 47.0 / 48.0
	# the walls: windows down both sides, the round window over the throne,
	# the great doors behind the way in (look D: the left wall fallen)
	var pre := "HWallW" if white else "HWall"
	var walls := [
		[Vector3(-hw - 0.8, 0.0, -hl - 1.6), Vector3(-hw - 0.8, 0.0, hl + 1.6), PI * 0.5, "broken" if open_side else pre],
		[Vector3(hw + 0.8, 0.0, -hl - 1.6), Vector3(hw + 0.8, 0.0, hl + 1.6), -PI * 0.5, pre],
		[Vector3(-hw - 1.6, 0.0, -hl - 0.8), Vector3(hw + 1.6, 0.0, -hl - 0.8), 0.0, pre + "Rose"],
		[Vector3(-hw - 1.6, 0.0, hl + 0.8), Vector3(hw + 1.6, 0.0, hl + 0.8), PI, pre + "Door"],
	]
	for wl: Array in walls:
		var a: Vector3 = wl[0]
		var b: Vector3 = wl[1]
		var along := b - a
		var n := 7 if absf(along.z) > absf(along.x) else 5
		for k in n:
			var piece := String(wl[3])
			if piece == "broken":
				piece = "HWallBroken%d" % (k % 2)
			elif piece != pre and k != int(n / 2.0):
				piece = pre + "Plain"
			var seg := _piece(room, piece, a + along * ((float(k) + 0.5) / float(n)), float(wl[2]))
			if seg != null:
				seg.scale.x = along.length() / float(n) / 8.0 * 1.003
		var holder := Node3D.new()
		holder.position = (a + b) * 0.5
		room.add_child(holder)
		var size := Vector3(absf(along.x) + 1.6, h + Dungeon.BLOCK_H, absf(along.z) + 1.6)
		_box(holder, size, Vector3(0.0, size.y * 0.5, 0.0))
	# two rows of columns, beams across on them, the roof on the beams
	# (look D: the roof gone over the fallen side, the beams broken off)
	var roof_from := -4.0 if open_side else -hw - 2.0
	var zs: Array[float] = []
	var z := -hl + 4.0
	while z < hl - 2.0:
		zs.append(z)
		z += 8.0
	for cz: float in zs:
		for sx: float in [-1.0, 1.0]:
			var col := _piece(room, "HColumn", Vector3(sx * 14.0, 0.0, cz), rng.randf_range(0.0, TAU))
			if col != null:
				_post_col(col, 1.0, h)
		var x0 := roof_from - (rng.randf_range(2.0, 9.0) if open_side else 0.0)
		var x1 := hw + 1.5
		var beam := _piece(room, "HBeam", Vector3((x0 + x1) * 0.5, h - 0.6, cz), 0.0)
		if beam != null:
			beam.scale.x = (x1 - x0) / 48.0
			_both_sides(beam)
	# the roof's holes: the sun comes down there (the user's rule: never a
	# roof that keeps the sun off the whole floor)
	var holes := [Vector2(-12, 0), Vector2(4, 0), Vector2(-4, 16), Vector2(12, 16), Vector2(-12, 24)]
	# the stone on the columns: an architrave along each row, and over it the
	# stone wall that once ran up to the ceiling, still hanging from it in
	# places, broken off below (the user's word, 2026-10-24: stone in the
	# ceiling too, so one sees it was all stone once)
	var spans: Array[Vector2] = [Vector2(-hl, zs[0])]
	for k in zs.size() - 1:
		spans.append(Vector2(zs[k], zs[k + 1]))
	spans.append(Vector2(zs[zs.size() - 1], hl))
	for sx: float in [-1.0, 1.0]:
		for sp: Vector2 in spans:
			var mid := (sp.x + sp.y) * 0.5
			var span := sp.y - sp.x
			var arch := _piece(room, "HArchitrave", Vector3(sx * 14.0, 13.1, mid), PI * 0.5)
			if arch != null:
				arch.scale.x = span / 8.0 * 1.002
			var roofed := sx * 14.0 > roof_from
			var by_hole := false
			for hole: Vector2 in holes:
				if absf(hole.x - sx * 14.0) < 6.5 and absf(hole.y - mid) < 6.0:
					by_hole = true
			if not roofed or by_hole:
				continue
			var piece := "HAttic"
			if rng.randf() < 0.5:
				piece = "HAtticBroken%d" % (rng.randi() % 2)
			var att := _piece(room, piece, Vector3(sx * 14.0, h - 0.39, mid), PI * 0.5)
			if att != null:
				att.scale.x = span / 8.0 * 1.002
	var px := -hw + 2.0
	while px < hw:
		var pz := -hl + 4.0
		while pz < hl:
			var open := px < roof_from
			for hole: Vector2 in holes:
				if absf(hole.x - px) < 4.1 and absf(hole.y - pz) < 4.1:
					open = true
			if not open:
				# a coffered bay; one next to a hole broken off towards it
				# (its ragged side, the piece's -z, turned to the hole)
				var toward := Vector2.ZERO
				var near := 99.0
				for hole: Vector2 in holes:
					var dd := Vector2(hole.x - px, hole.y - pz)
					if absf(dd.x) < 8.5 and absf(dd.y) < 8.5 and dd.length() < near:
						near = dd.length()
						toward = dd
				if open_side and px < roof_from + 8.0 and (toward == Vector2.ZERO or near > 8.0):
					toward = Vector2(-8.0, 0.0)
				var broken := toward != Vector2.ZERO and (absf(toward.x) < 0.5 or absf(toward.y) < 0.5)
				var yaw := PI * 0.5 * float(rng.randi() % 4)
				if broken:
					yaw = atan2(-toward.x, -toward.y)
				var panel := _piece(room, ("HCeilBroken%d" % (rng.randi() % 2)) if broken else "HCeil",
						Vector3(px, h - 0.25, pz), yaw)
				if panel != null:
					_both_sides(panel)
			pz += 8.0
		px += 8.0
	# (no rubble or fallen beams on the floor: the user's word, 2026-10-24,
	# it looked bad)
	# banners down the columns, facing the aisle: the palace's crimson, or
	# (look B) the orcs' own hung over them
	for k in zs.size():
		if k % 2 == 1 and not orcs:
			continue
		for sx: float in [-1.0, 1.0]:
			if open_side and sx < 0.0:
				continue
			_piece(room, "OrcBanner" if orcs else "BannerLong", Vector3(sx * 13.1, 12.5, zs[k]), -sx * PI * 0.5)
	# shields on the walls between the windows
	for k in 7:
		var sz := -hl + (float(k) + 1.0) * l / 8.0
		for sx: float in [-1.0, 1.0]:
			if open_side and sx < 0.0:
				continue
			_piece(room, "HShield", Vector3(sx * (hw - 0.2), 6.0, sz), -sx * PI * 0.5, 1.2)
	# the feast's tables, left laid, between the columns and the walls (look
	# B: thrown over; look C: cypresses in marble pots between them)
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var tz := -hl + 14.0 + float(k) * 13.0 + rng.randf_range(-1.0, 1.0)
			var t := _piece(room, "HTableTipped" if orcs and rng.randf() < 0.6 else "HTable", Vector3(sx * 18.4, 0.0, tz),
					PI * 0.5 + rng.randf_range(-0.06, 0.06) + (rng.randf_range(-0.4, 0.4) if orcs else 0.0))
			if t != null:
				_box(t, Vector3(5.0, 1.2, 1.4), Vector3(0.0, 0.6, 0.0))
			if white:
				var pz2 := tz + 6.5
				if pz2 < hl - 6.0:
					var pot := _piece(room, "PlanterMarble", Vector3(sx * 18.4, 0.0, pz2))
					if pot != null:
						_box(pot, Vector3(1.5, 1.2, 1.5), Vector3(0.0, 0.6, 0.0))
					_piece(room, "Cypress%d" % (k % 2), Vector3(sx * 18.4, 0.95, pz2), rng.randf_range(0.0, TAU), 0.9)
	if orcs:
		_orc_camp(d, room, hw, hl, rng)
	# two great banners either side of the round window
	for sx: float in [-1.0, 1.0]:
		_piece(room, "OrcBanner" if orcs else "BannerLong", Vector3(sx * 6.0, 13.5, -hl + 0.15), 0.0, 1.4)
	# the throne on its dais under the round window, a hero's statue each side
	var dais := _piece(room, "CDais", Vector3(0.0, 0.0, -hl + 4.0), 0.0, 0.9)
	if dais != null:
		_box(dais, Vector3(12.0, 0.9, 6.0), Vector3(0.0, 0.45, 0.0))
		_box(dais, Vector3(2.4, 4.5, 2.0), Vector3(0.0, 2.2, -1.6))
	var heroes: Array = PLACE_HEROES["gold_hall"]
	for k in 2:
		var sx := -1.0 if k == 0 else 1.0
		_knight(room, Vector3(sx * 8.5, 0.0, -hl + 2.0), PI, false, String(heroes[k]))
	if open_side:
		# beyond the fallen wall: the crag the palace stands on, the valley far
		# below, the peaks
		for k in 6:
			_crag(room, ["Cliff1", "Cliff0"][k % 2], Vector3(-hw - 14.0, -4.0, -hl + float(k) * l / 5.0),
					rng.randf_range(0.9, 1.2), rng.randf_range(0.0, TAU), 0.0, 0.0, false)
		_piece(room, "FValley", Vector3(-180.0, -95.0, -40.0), PI + 0.3, 1.6, false)
	# now and then dust trickles down from the broken edges of the roof
	var edges: Array[Vector3] = []
	for hole: Vector2 in holes:
		for e: Vector2 in [Vector2(3.9, 0.0), Vector2(-3.9, 0.0), Vector2(0.0, 3.9), Vector2(0.0, -3.9)]:
			if hole.x + e.x > roof_from and absf(hole.x + e.x) < hw and absf(hole.y + e.y) < hl:
				edges.append(Vector3(hole.x + e.x, h - 0.3, hole.y + e.y))
	if open_side:
		for k in 5:
			edges.append(Vector3(roof_from, h - 0.3, -hl + 6.0 + float(k) * (l - 12.0) / 4.0))
	_dust_from_roof(room, edges)
	if open_side:
		_hall_storm_rain(room, hw, hl, l, roof_from, holes)
	# the light in the air: a warm haze the shafts show in, motes of dust
	_haze(room, Vector3(0.0, h * 0.45, 0.0), Vector3(w, h, l), 0.009 if orcs else 0.006)
	_motes(room, w, l, Color(1.0, 0.86, 0.6), 220)


## Dust trickling down now and then from one of `edges` (a broken roof's
## edge, high up): a thin stream of soft motes that falls and spreads, seen
## best where the sun's shafts come down. Each peer's own (only for the eye).
static func _dust_from_roof(room: Node3D, edges: Array[Vector3]) -> void:
	if edges.is_empty():
		return
	var streams: Array[GPUParticles3D] = []
	for k in 3:
		var p := GPUParticles3D.new()
		p.amount = 60
		p.lifetime = 5.0
		p.one_shot = true
		p.explosiveness = 0.35
		p.emitting = false
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.5, 0.05, 0.5)
		pm.direction = Vector3.DOWN
		pm.spread = 12.0
		pm.initial_velocity_min = 0.4
		pm.initial_velocity_max = 1.2
		pm.gravity = Vector3(0.0, -1.6, 0.0)
		pm.damping_min = 0.4
		pm.damping_max = 0.8
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.4
		pm.scale_min = 0.6
		pm.scale_max = 1.6
		var fade := Gradient.new()
		fade.set_color(0, Color(0.86, 0.80, 0.70, 0.0))
		fade.add_point(0.12, Color(0.86, 0.80, 0.70, 0.55))
		fade.set_color(fade.get_point_count() - 1, Color(0.86, 0.80, 0.70, 0.0))
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
		qm.vertex_color_use_as_albedo = true
		qm.albedo_texture = PlaceBuild.soft_dot()
		q.material = qm
		p.draw_pass_1 = q
		p.visibility_aabb = AABB(Vector3(-4.0, -20.0, -4.0), Vector3(8.0, 22.0, 8.0))
		room.add_child(p)
		streams.append(p)
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	room.add_child(timer)
	var turn := [0]
	timer.timeout.connect(func() -> void:
		var p := streams[turn[0] % streams.size()]
		turn[0] += 1
		if not is_instance_valid(p):
			return
		p.position = edges[randi() % edges.size()]
		p.restart()
		timer.wait_time = randf_range(2.5, 6.0))


## The storm's rain over the open hall (look D): over the fallen side and
## the valley, and down through the roof's holes; its sound with it. All of
## it in the "hall_rain" group, for [method set_hall_rain].
static func _hall_storm_rain(room: Node3D, hw: float, hl: float, l: float, roof_from: float, holes: Array) -> void:
	var rain := Node3D.new()
	rain.name = "HallRain"
	rain.add_to_group(&"hall_rain")
	room.add_child(rain)
	var x0 := -hw - 34.0
	_rain_box(rain, Vector3((x0 + roof_from) * 0.5, 22.0, 0.0), Vector3((roof_from - x0) * 0.5, 1.0, l * 0.5 + 10.0))
	for hole: Vector2 in holes:
		if hole.x > roof_from:
			_rain_box(rain, Vector3(hole.x, 22.0, hole.y), Vector3(4.0, 1.0, 4.0))
	var sound := AudioStreamPlayer.new()
	sound.stream = load(Dungeon.SND + "rain_loop.wav")
	sound.volume_db = -12.0
	sound.bus = &"Master"
	sound.autoplay = hall_rain and hall_mood == "storm"
	sound.finished.connect(sound.play)
	rain.add_child(sound)
	set_hall_rain(hall_rain, rain)


## The golden hall's weather (F2's board): the rain shown with it; the light
## is the dungeon's to redo ([method Dungeon._apply_phase]).
static func set_hall_mood(mood: String) -> void:
	hall_mood = mood
	set_hall_rain(hall_rain)


## Rain streaks falling from a box (`half` its half size) at `at`.
static func _rain_box(parent: Node3D, at: Vector3, half: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = clampi(int(half.x * half.z * 4.0 * 1.1), 60, 6000)
	p.lifetime = 1.1
	p.preprocess = 1.0
	p.position = at
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = half
	pm.direction = Vector3(0.2, -1.0, 0.08)
	pm.spread = 3.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 28.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.gravity = Vector3(0.0, -10.0, 0.0)
	pm.particle_flag_align_y = true
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.9)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.78, 0.82, 0.9, 0.2)
	qm.albedo_texture = PlaceBuild.streak()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.billboard_keep_scale = true
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-half.x - 4.0, -34.0, -half.z - 4.0), Vector3(half.x * 2.0 + 8.0, 38.0, half.z * 2.0 + 8.0))
	parent.add_child(p)


## The golden hall's rain on or off: `only` one rain node, else every one in
## the tree (F1's board).
static func set_hall_rain(on: bool, only: Node = null) -> void:
	hall_rain = on
	var nodes: Array = [only] if only != null else []
	if only == null and Engine.get_main_loop() is SceneTree:
		nodes = (Engine.get_main_loop() as SceneTree).get_nodes_in_group(&"hall_rain")
	on = on and hall_mood == "storm"
	for n: Variant in nodes:
		if not is_instance_valid(n):
			continue
		var rain := n as Node3D
		rain.visible = on
		for ch in rain.get_children():
			if ch is GPUParticles3D:
				(ch as GPUParticles3D).emitting = on
			elif ch is AudioStreamPlayer:
				if on and not (ch as AudioStreamPlayer).playing:
					(ch as AudioStreamPlayer).play()
				elif not on:
					(ch as AudioStreamPlayer).stop()


## The orcs in the hall (look B): their hide tents by the far walls, stakes
## round their camp, braziers down the aisle's sides, their loot heaped.
static func _orc_camp(d: Dungeon, room: Node3D, hw: float, hl: float, rng: RandomNumberGenerator) -> void:
	for at: Vector3 in [Vector3(-hw + 5.0, 0.0, hl - 9.0), Vector3(hw - 5.0, 0.0, -hl + 16.0)]:
		var tent := _piece(room, "FTent", at, rng.randf_range(0.0, TAU), 0.8)
		if tent != null:
			_post_col(tent, 2.2, 4.0)
	for k in 4:
		var sx := -1.0 if k % 2 == 0 else 1.0
		var bz := -hl + 18.0 + floorf(k / 2.0) * 18.0
		_brazier(d, room, Vector3(sx * 7.5, 0.0, bz), 3.4)
	for at: Vector3 in [Vector3(-hw + 9.0, 0.0, hl - 14.0), Vector3(hw - 9.0, 0.0, -hl + 22.0)]:
		var bar := _piece(room, "Barricade", at, rng.randf_range(-0.3, 0.3) + PI * 0.5)
		if bar != null:
			_box(bar, Vector3(6.0, 1.6, 1.2), Vector3(0.0, 0.8, 0.0))
	for k in 8:
		var sx := -1.0 if k < 4 else 1.0
		var at := Vector3(sx * rng.randf_range(16.5, 20.0), 0.0, rng.randf_range(-hl + 10.0, hl - 10.0))
		var thing := _piece(room, "Barrel" if k % 2 == 0 else "Crate", at, rng.randf_range(0.0, TAU))
		if thing != null:
			_post_col(thing, 0.5, 1.0)
#endregion


## A piece seen from above as well (the roof's boards are drawn for the
## eye under them; the sun's shadow wants their other side too).
static func _both_sides(n: Node3D) -> void:
	for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
		if g is GeometryInstance3D:
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED


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
		_knight(room, Vector3(sx * 12.0, 0.0, -hl + 1.5), PI, false,
				String((PLACE_HEROES["clouds"] as Array)[0 if sx < 0.0 else 1]))
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
