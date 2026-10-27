class_name SwampMere
extends Object

## The swamp as the user chose it (2026-10-23, after four rounds): a wood
## of the nature kit's round green trees (gallery picks 23, 24, 26, 27) close
## round the clearing and inside its sides, one deep still pond on one side
## with only mud under it and a wet mud rim, wet ground (a skin of water over
## mud) on the other, mossy stones on the pond's shore. No bushes, flowers or
## plants in the water; mist only out among the trees, none where the fight
## is; round fireflies. The middle is open.
##
## IF THE USER SAYS THE SWAMP STUTTERS (2026-10-24; the project doc
## claude/swamp_room.md has the numbers): at Medium on an M1 the room is
## ~20 ms a frame against the forest's ~10, spread over many parts. In order:
## the far wood (_far_wood, ~3 ms), the reflection probe (~2 ms), the water
## (~2 ms), the near trees' shadows (~2 ms), the mud bed under the pools
## (~1.5 ms, _mud_skin covers it), the rain (_drizzle), the outer mist. Cutting
## the first three on Medium was tried (19833160) and the user liked it less
## (reverted): ask which setting he plays, cut on that setting only, show him.
## Measure with _shots_tmp/swamp_ai/perf6.gd, nothing else running.
## STILL TO DO: the water step sounds (sounds/water) are made in Python and
## sound bad (the user's word): replace with real free recordings, asking
## him before any download.
##
## Only the low poly swamp is left (2026-10-28, the user's word: the old one
## was built for nothing). The old smooth swamp, its looks (emerald, green,
## pale, willow, dead, black) and the pale marsh went; they are in git
## before that day. Tried and dropped: image-to-3D trees (Hunyuan3D-2 mini on
## the Mac, see vepxis-art/NOTES.md), cattails, lilies.

## How deep the hollows go at their deepest.
const DEPTH := 0.5
## The ground's mesh and collision step.
const STEP := 0.5

## The water in the room's own frame, as fractions of its width and length:
## [x, z, half-width, half-length, yaw, depth share]. The user's word
## (2026-10-23, rounds 4-6): one pond on one side, shallow (run over it, do
## not sink), and on the other wet ground, a skin of water over the mud
## filled out to its shores.
const POOLS := [
	[-0.25, 0.02, 0.21, 0.40, 0.12, 0.34],
	[0.25, 0.10, 0.20, 0.33, -0.2, 0.24],
	[0.24, -0.28, 0.18, 0.18, 0.5, 0.24],
	[0.10, -0.42, 0.13, 0.08, 0.3, 0.24],
]
## One water surface for the whole room, this far under the ground: it shows
## only where a hollow dips below it, so every pool is the same water, filled
## to its shore, with no seam where two meet (the user's word, 2026-10-23).
const SURFACE := -0.07

## The low poly swamp's look (the user's pick, 2026-10-25, "B"): the
## faceted water's colours and the mist out among the oaks.
const LOOK := {"shallow": Color(0.31, 0.33, 0.20), "deep": Color(0.11, 0.15, 0.08), "clarity": 0.28,
		"scum": 0.0, "gloss": 0.45, "mist": 0.3}
## Whether this build's swamp has the soft rain (about half the time).
static var raining := false
## For pictures: -1 the dice, 0 never, 1 always.
static var rain_force := -1


## Builds the swamp into `room`, `w` by `l` metres.
static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var grow := 1.0
	match Graphics.current:
		Graphics.Level.LOW:
			grow = 0.5
		Graphics.Level.MEDIUM:
			grow = 0.75
		Graphics.Level.ULTRA:
			grow = 1.4
	var pools := _pools(w, l)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	# the ground: bright moss and grass, mud in patches, the hollows in it
	var ground := d._ground_mat()
	ground.set_shader_parameter("grass_a", Color(0.24, 0.36, 0.07))
	ground.set_shader_parameter("grass_b", Color(0.36, 0.48, 0.10))
	ground.set_shader_parameter("earth", Color(0.25, 0.17, 0.09))
	ground.set_shader_parameter("moss", Color(0.30, 0.44, 0.08))
	ground.set_shader_parameter("leaves", Color(0.26, 0.20, 0.09))
	ground.set_shader_parameter("path_amount", 0.0)
	ground.set_shader_parameter("bare_from", 0.46)
	ground.set_shader_parameter("mud", 1.0)
	var gw := w + 44.0
	var gl := l + 44.0
	# the smooth ground only to walk on (no mesh made for it); the faceted
	# one to look at, fine where the fight is, coarse out under the far wood
	_ground(room, gw, gl, pools, noise)
	_lp_ground(room, Rect2(-gw * 0.5, -gl * 0.5, gw, gl), 1.6, Rect2(), w, l, pools, noise, rng, 0.01)
	_lp_ground(room, Rect2(-210.0, -210.0, 420.0, 420.0), 5.0, Rect2(-gw * 0.5 + 6.0, -gl * 0.5 + 6.0,
			gw - 12.0, gl - 12.0), w, l, pools, noise, rng, -0.02)
	# the land on round it, flat, under the trees further off
	var far := 160.0
	for side in 4:
		var size := Vector3(far, 1.0, gl) if side < 2 else Vector3(gw + far * 2.0, 1.0, far)
		var at := Vector3((gw + far) * 0.5 * (-1.0 if side == 0 else 1.0), -0.5, 0.0) if side < 2 \
				else Vector3(0.0, -0.5, (gl + far) * 0.5 * (-1.0 if side == 2 else 1.0))
		var slab := d._solid(room, ground, size, at)
		if slab != null:
			for mi in slab.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).visible = false
	d._bounds(room, w, l)
	# the water in each hollow
	var look: Dictionary = LOOK
	var water := _lp_water(look)
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 16.0, l + 16.0)
	# facets of a metre and a bit, each lit flat
	plane.subdivide_width = int((w + 16.0) / 1.3)
	plane.subdivide_depth = int((l + 16.0) / 1.3)
	var sheet := MeshInstance3D.new()
	sheet.mesh = plane
	sheet.material_override = water
	sheet.position = Vector3(0.0, SURFACE, 0.0)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(sheet)
	for pl: Dictionary in pools:
		if float(pl["depth"]) >= 0.3:
			_lp_shore(room, pl, rng, grow, pools, noise)
	_oak_wood(room, w, l, rng, grow, pools)
	_outer_mist(room, w, l, rng, look["mist"])
	raining = rng.randf() < 0.5 if rain_force < 0 else rain_force == 1
	if raining:
		_drizzle(room, w, l)
	d._fireflies(room, w, l)
	# smaller (the user's word, 2026-10-23: the fireflies too big)
	var ff := room.get_child(room.get_child_count() - 1) as GPUParticles3D
	if ff != null and ff.draw_pass_1 is QuadMesh:
		(ff.draw_pass_1 as QuadMesh).size = Vector2(0.09, 0.09)
	# the water under the feet: slowed, splashing, a wake
	var wade := SwampWade.new()
	wade.name = "SwampWade"
	wade.pools = pools
	wade.noise = noise
	wade.water = water
	room.add_child(wade)


## The forest's kind of ground (2026-10-25, the user's pick): big facets,
## each its own colour, the forest's palette: moss greens, brown mud trodden
## in the middle and round the water, dead leaves in patches; the hollows of
## the pools in it as in the smooth ground (that one kept to walk on).
## `area` in metres on the ground, facets `step` across, nothing inside
## `hole` (a finer ground there), `lift` over the smooth one.
## (a dull swamp moss, not the forest's bright one: the user's word, 2026-10-25)
const LP_MOSS := [Color(0.22, 0.27, 0.13), Color(0.25, 0.29, 0.14), Color(0.27, 0.31, 0.16), Color(0.23, 0.26, 0.14)]
const LP_MUD := [Color(0.33, 0.25, 0.17), Color(0.29, 0.22, 0.15), Color(0.37, 0.28, 0.19)]
## inside the clearing between the waters no bright moss (the user's word,
## 2026-10-25: the green between the waters spoils it): mud and a dull bog olive
const LP_BOG := [Color(0.27, 0.26, 0.15), Color(0.24, 0.24, 0.13), Color(0.30, 0.28, 0.17)]
const LP_LEAF := [Color(0.44, 0.32, 0.15), Color(0.50, 0.37, 0.17), Color(0.38, 0.28, 0.13)]
static func _lp_ground(room: Node3D, area: Rect2, step: float, hole: Rect2, w: float, l: float,
		pools: Array[Dictionary], noise: FastNoiseLite, rng: RandomNumberGenerator, lift: float) -> void:
	var nx := int(area.size.x / step) + 1
	var nz := int(area.size.y / step) + 1
	var pts: Array[Vector3] = []
	for k in nz:
		for i in nx:
			var x := area.position.x + float(i) * step
			var z := area.position.y + float(k) * step
			if i > 0 and i < nx - 1:
				x += rng.randf_range(-0.35, 0.35) * step
			if k > 0 and k < nz - 1:
				z += rng.randf_range(-0.35, 0.35) * step
			var h := _height(x, z, pools, noise) + rng.randf_range(-0.012, 0.012) * step
			pts.append(Vector3(x, h + lift, z))
	var patch := FastNoiseLite.new()
	patch.seed = rng.randi()
	patch.frequency = 0.06
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in nz - 1:
		for i in nx - 1:
			var a := k * nx + i
			if hole.has_area() and hole.has_point(Vector2((pts[a].x + pts[a + nx + 1].x) * 0.5,
					(pts[a].z + pts[a + nx + 1].z) * 0.5)):
				continue
			var tris := [[a, a + nx, a + 1], [a + 1, a + nx, a + nx + 1]] if (i + k) % 2 == 0 \
					else [[a, a + nx, a + nx + 1], [a, a + nx + 1, a + 1]]
			for t: Array in tris:
				var p0: Vector3 = pts[t[0]]
				var p1: Vector3 = pts[t[1]]
				var p2: Vector3 = pts[t[2]]
				var c := (p0 + p1 + p2) / 3.0
				var n := patch.get_noise_2d(c.x, c.z) * 0.5 + 0.5
				var wet := 9.0
				for pl in pools:
					wet = minf(wet, _into(pl, c.x, c.z, noise))
				var inside := absf(c.x) < w * 0.5 - 1.5 and absf(c.z) < l * 0.5 - 1.5
				var col: Color = LP_MOSS[int(n * 3.99)]
				if wet < 1.12 or (inside and n > 0.45):
					col = LP_MUD[int(fposmod(n * 7.0, 3.0))]
					if wet < 1.0:
						col = col.darkened(0.3)
				elif inside:
					col = LP_BOG[int(fposmod(n * 7.0, 3.0))]
				elif patch.get_noise_2d(c.x * 2.3 + 40.0, c.z * 2.3) > 0.35:
					col = LP_LEAF[int(fposmod(n * 5.0, 3.0))]
				col = col * rng.randf_range(0.94, 1.06)
				var nrm := (p1 - p0).cross(p2 - p0).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				# (wound so their fronts face up: drawn from above)
				for q: Vector3 in [p0, p2, p1]:
					st.set_color(col)
					st.set_normal(nrm)
					st.add_vertex(q)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := TerracePlaces._solid(0.0, 1.35, 1.0).duplicate() as ShaderMaterial
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)


## The faceted water (2026-10-25, the user's word: the water low poly as
## the ground): a sheet of small triangles each lit flat, rocked by a slow
## swell, murky olive in bands by how much water the eye looks through, a
## pale line where it laps the mud, glints of the sun; the feet's ripples
## lift the facets themselves.
const LP_WATER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
uniform vec4 shallow : source_color = vec4(0.46, 0.45, 0.29, 1.0);
uniform vec4 deep : source_color = vec4(0.14, 0.18, 0.10, 1.0);
uniform vec4 foam : source_color = vec4(0.80, 0.80, 0.68, 1.0);
uniform vec4 sky : source_color = vec4(0.66, 0.70, 0.66, 1.0);
uniform float wave = 0.014;
uniform float depth_reach = 0.09;
uniform vec4 drops[32];
uniform int drop_count = 0;
uniform float drop_speed = 1.3;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// barely stirring (the user's word, 2026-10-25: the water moved too much)
	float h = sin(w.x * 0.8 + TIME * 0.25) * 0.45 + sin(w.z * 1.05 - TIME * 0.2) * 0.35
			+ (vnoise(w.xz * 0.45 + vec2(TIME * 0.04, TIME * 0.03)) - 0.5) * 0.8;
	float lift = 0.0;
	for (int i = 0; i < drop_count; i++) {
		vec4 dr = drops[i];
		float dist = length(w.xz - dr.xy);
		float x = dist - dr.z * drop_speed;
		if (abs(x) > 1.2) { continue; }
		float amp = dr.w * exp(-dr.z * 1.1 / max(1.0, dr.w * 0.6)) / (1.0 + dist * 0.8);
		lift += amp * sin(7.0 * x) * exp(-x * x / 0.18) * step(x, 0.25);
	}
	VERTEX.y += h * wave + clamp(lift, -1.0, 1.0) * 0.03;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) { n = -n; }
	NORMAL = n;
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	behind.xyz /= behind.w;
	float depth = clamp(VERTEX.z - behind.z, 0.0, 50.0);
	float k = 1.0 - exp(-depth / depth_reach);
	k = floor(k * 4.0 + 0.5) / 4.0;
	vec3 c = mix(shallow.rgb, deep.rgb, k);
	// patches a little lighter and darker, drifting
	float drift = vnoise(wp.xz * 0.08 + vec2(TIME * 0.008, -TIME * 0.006));
	c *= 0.9 + 0.2 * floor(drift * 4.0) / 4.0;
	// each facet its own shade by how it leans (the low poly look)
	vec3 nw = normalize(cross(dFdx(wp), dFdy(wp)));
	if (nw.y < 0.0) { nw = -nw; }
	c *= 1.0 + clamp(dot(nw.xz, vec2(0.7, 0.5)) * 7.0, -0.22, 0.22);
	// the feet's rings and the wake as the old water has them (the user's
	// word, 2026-10-25: exactly as in the old swamp, no white marks): a
	// short packet of crests bending the surface, crests a little lighter
	// and wetter, troughs darker
	vec2 slope = vec2(0.0);
	float lift = 0.0;
	for (int i = 0; i < drop_count; i++) {
		vec4 dr = drops[i];
		vec2 off = wp.xz - dr.xy;
		float dist = length(off);
		float x = dist - dr.z * drop_speed;
		if (abs(x) > 1.2) { continue; }
		float k = 7.0;
		float g = exp(-x * x / 0.18) * step(x, 0.25);
		float amp = dr.w * exp(-dr.z * 1.1 / max(1.0, dr.w * 0.6)) / (1.0 + dist * 0.8) * smoothstep(0.0, 0.35, dist);
		float dh = amp * (k * cos(k * x) * g + sin(k * x) * g * (-2.0 * x / 0.18));
		slope -= (off / max(dist, 0.001)) * dh * 0.32;
		lift += amp * sin(k * x) * g;
	}
	slope = clamp(slope, vec2(-0.35), vec2(0.35));
	n = normalize(n + (VIEW_MATRIX * vec4(slope.x, 0.0, slope.y, 0.0)).xyz);
	NORMAL = n;
	float lit = clamp(lift * 0.55, -0.3, 0.3);
	c *= 1.0 + lit;
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 4.0);
	c = mix(c, sky.rgb * 0.6, fres * 0.3);
	// (no pale line where it meets the mud: the user's word, 2026-10-25)
	float lap = 0.0;
	vec2 cell = floor(wp.xz * 1.6);
	float glint = step(0.994, hash(cell + floor(TIME * 0.5 + hash(cell) * 7.0)));
	ALBEDO = c;
	EMISSION = vec3(1.0, 0.97, 0.88) * glint * 0.8;
	ROUGHNESS = clamp(0.25 - abs(lit) * 0.5, 0.04, 1.0);
	SPECULAR = 0.3;
	ALPHA = clamp(0.80 + k * 0.2 + lap, 0.0, 1.0) * smoothstep(0.0, 0.01, depth);
}
"""
static var _lp_water_shader: Shader
static func _lp_water(look: Dictionary) -> ShaderMaterial:
	if _lp_water_shader == null:
		_lp_water_shader = Shader.new()
		_lp_water_shader.code = LP_WATER
	var m := ShaderMaterial.new()
	m.shader = _lp_water_shader
	m.render_priority = -100
	m.set_shader_parameter("shallow", look["shallow"])
	m.set_shader_parameter("deep", look["deep"])
	return m


## The forest's kit ([ForestGlade]) made ready.
static func _glade_kit() -> void:
	if ForestGlade._kit == null or not is_instance_valid(ForestGlade._kit):
		ForestGlade._kit = (load(ForestGlade.KIT) as PackedScene).instantiate() as Node3D
		ForestGlade._dress_kit()


## A spot `out` metres past the clearing's edge, `t` (0..1) round it.
static func _round_edge(w: float, l: float, t: float, out: float) -> Vector3:
	var a := t * TAU
	var dir := Vector2(sin(a), cos(a))
	var to_side := minf(w * 0.5 / maxf(absf(dir.x), 0.001), l * 0.5 / maxf(absf(dir.y), 0.001))
	return Vector3(dir.x * (to_side + out), 0.0, dir.y * (to_side + out))


## The forest's oaks round the clearing (2026-10-25, the user's word: the
## forest's trees, beautifully): a close ring their long boughs reaching in
## over the clearing's edge, a second ring behind, a few young ones inside
## along the sides, the deep wood beyond drawn cheap; ferns, rocks, stumps,
## a fallen log and mushrooms at their feet, none in the clearing's middle.
static func _oak_wood(room: Node3D, w: float, l: float, rng: RandomNumberGenerator, grow: float,
		pools: Array[Dictionary]) -> void:
	_glade_kit()
	var oaks := ForestGlade.OAKS
	var ring := 24
	for k in ring:
		var t := (float(k) + rng.randf_range(-0.25, 0.25)) / float(ring)
		var at := _round_edge(w, l, t, rng.randf_range(4.0, 8.0))
		# the way in left open
		if at.z > l * 0.5 and absf(at.x) < 8.0:
			at.x += 10.0 * signf(at.x + 0.01)
		var s := rng.randf_range(0.6, 0.78)
		_oak(room, oaks[k % oaks.size()], at, _reach_in(at, rng), s, true)
	for k in int(26.0 * grow):
		var t := (float(k) + rng.randf_range(0.0, 1.0)) / (26.0 * grow)
		var at := _round_edge(w, l, t, rng.randf_range(14.0, 24.0))
		_oak(room, oaks[rng.randi_range(0, oaks.size() - 1)], at, _reach_in(at, rng), rng.randf_range(0.7, 0.95), false)
	# young oaks inside along the sides, on dry ground
	for side in 4:
		for k in 2:
			var along := (float(k) - 0.5) * (l if side < 2 else w) * 0.5 + rng.randf_range(-3.0, 3.0)
			var inset := rng.randf_range(2.5, 4.5)
			var at := Vector3.ZERO
			match side:
				0: at = Vector3(-w * 0.5 + inset, 0.0, along)
				1: at = Vector3(w * 0.5 - inset, 0.0, along)
				2: at = Vector3(along, 0.0, -l * 0.5 + inset)
				_: at = Vector3(along, 0.0, l * 0.5 - inset)
			if side == 3 and absf(at.x) < 9.0:
				continue
			var dry := true
			for pl in pools:
				if _into(pl, at.x, at.z, null) < 1.4:
					dry = false
			if dry:
				_oak(room, "Oak2", at, _reach_in(at, rng), rng.randf_range(0.36, 0.46), true)
	# the deep wood, one MultiMesh per oak
	var spots := [[], [], [], []]
	for k in int(150.0 * grow):
		var near := k % 2 == 0
		var at := _round_edge(w, l, rng.randf(), rng.randf_range(26.0, 60.0) if near else rng.randf_range(60.0, 150.0))
		var s := rng.randf_range(0.8, 1.05) if near else rng.randf_range(1.0, 1.5)
		(spots[rng.randi_range(0, 3)] as Array).append(
				Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), at))
	for i in 4:
		_many_oaks(room, oaks[i], spots[i])
	# the floor under the trees
	for k in int(120.0 * grow):
		var at := _round_edge(w, l, rng.randf(), rng.randf_range(-1.0, 22.0))
		ForestGlade._piece(room, "Fern%d" % (k % 3), at, rng.randf_range(0.0, TAU), rng.randf_range(1.1, 1.8))
	for k in int(26.0 * grow):
		var at := _round_edge(w, l, rng.randf(), rng.randf_range(-2.5, 14.0))
		if at.z > l * 0.5 and absf(at.x) < 7.0:
			continue
		ForestGlade._piece(room, "Rock%d" % (k % 4), at, rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.6))
	for k in 5:
		var at := _round_edge(w, l, rng.randf(), rng.randf_range(1.0, 9.0))
		ForestGlade._piece(room, "Stump%d" % (k % 2), at, rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.3))
	for k in 2:
		var at := _round_edge(w, l, rng.randf(), rng.randf_range(3.0, 10.0))
		ForestGlade._piece(room, "Log0", at, rng.randf_range(0.0, TAU), rng.randf_range(1.0, 1.3))
	for k in int(22.0 * grow):
		var at := _round_edge(w, l, rng.randf(), rng.randf_range(0.0, 12.0))
		ForestGlade._piece(room, "Shrooms%d" % (k % 3), at, rng.randf_range(0.0, TAU), rng.randf_range(1.0, 1.6))


## A yaw that turns an oak's long boughs (the kit's +x) in to the clearing.
static func _reach_in(at: Vector3, rng: RandomNumberGenerator) -> float:
	var to_mid := -at.normalized()
	return atan2(-to_mid.z, to_mid.x) + rng.randf_range(-0.4, 0.4)


static func _oak(room: Node3D, piece: String, at: Vector3, yaw: float, s: float, solid: bool) -> void:
	var n := ForestGlade._piece(room, piece, at, yaw, s)
	if n == null:
		return
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 2.0
		c.height = 10.0
		shape.shape = c
		shape.position.y = 5.0
		body.add_child(shape)
		n.add_child(body)
	elif n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Oaks far out: one MultiMesh, no shadows, no collision.
static func _many_oaks(room: Node3D, piece: String, where: Array) -> void:
	var src := ForestGlade._kit.get_node_or_null(piece) as MeshInstance3D
	if src == null or where.is_empty():
		return
	var mesh := src.mesh.duplicate() as ArrayMesh
	for s in mesh.get_surface_count():
		var m := src.get_surface_override_material(s)
		if m != null:
			mesh.surface_set_material(s, m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = where.size()
	for i in where.size():
		mm.set_instance_transform(i, where[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mmi)


## A pool's shore in the forest's stones: faceted rocks half in the mud, a
## stump at the edge.
static func _lp_shore(room: Node3D, pl: Dictionary, rng: RandomNumberGenerator, grow: float,
		pools: Array[Dictionary], noise: FastNoiseLite) -> void:
	_glade_kit()
	var size: float = pl["a"] + pl["b"]
	for k in int(size * 0.35 * grow) + 2:
		var at := _on(pl, rng.randf_range(0.0, TAU), rng.randf_range(0.95, 1.15))
		at.y = _height(at.x, at.z, pools, noise) - 0.08
		ForestGlade._piece(room, "Rock%d" % rng.randi_range(0, 3), at, rng.randf_range(0.0, TAU), rng.randf_range(0.6, 1.3))
	if rng.randf() < 0.7:
		var at2 := _on(pl, rng.randf_range(0.0, TAU), 1.05)
		at2.y = _height(at2.x, at2.z, pools, noise) - 0.05
		ForestGlade._piece(room, "Stump%d" % rng.randi_range(0, 1), at2, rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.1))


## The pools in metres, with their ragged edges' seeds.
static func _pools(w: float, l: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Array in POOLS:
		out.append({"at": Vector2(p[0] * w, p[1] * l), "a": p[2] * w, "b": p[3] * l, "yaw": p[4],
				"depth": p[5], "water": SURFACE})
	return out


## How far into a pool a point lies: 0 at its middle, 1 at its shore.
static func _into(pl: Dictionary, x: float, z: float, noise: FastNoiseLite) -> float:
	var dx := x - (pl["at"] as Vector2).x
	var dz := z - (pl["at"] as Vector2).y
	var c := cos(pl["yaw"] as float)
	var s := sin(pl["yaw"] as float)
	var u := (dx * c - dz * s) / (pl["a"] as float)
	var v := (dx * s + dz * c) / (pl["b"] as float)
	var r := sqrt(u * u + v * v)
	return r + (noise.get_noise_2d(x, z) * 0.22 if noise != null else 0.0)


## The ground's height: the hollows dug soft into it.
static func _height(x: float, z: float, pools: Array[Dictionary], noise: FastNoiseLite) -> float:
	var h := 0.0
	for pl in pools:
		var r := _into(pl, x, z, noise)
		if r < 1.35:
			h = minf(h, -DEPTH * float(pl["depth"]) * (1.0 - smoothstep(0.55, 1.3, r)))
	return h


static func _ground(room: Node3D, gw: float, gl: float, pools: Array[Dictionary],
		noise: FastNoiseLite) -> void:
	var nx := int(gw / STEP) + 1
	var nz := int(gl / STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for k in nz:
		for i in nx:
			heights[k * nx + i] = _height(-gw * 0.5 + i * STEP, -gl * 0.5 + k * STEP, pools, noise)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = nx
	hm.map_depth = nz
	hm.map_data = heights
	shape.shape = hm
	shape.scale = Vector3(STEP, 1.0, STEP)
	# the heightmap stands round its middle sample
	shape.position = Vector3((nx - 1) * STEP * 0.5 - gw * 0.5, 0.0, (nz - 1) * STEP * 0.5 - gl * 0.5)
	body.add_child(shape)
	room.add_child(body)


## A point on a pool's shore (r = 1) or in it (r < 1), in metres.
static func _on(pl: Dictionary, ang: float, r: float) -> Vector3:
	var c := cos(pl["yaw"] as float)
	var s := sin(pl["yaw"] as float)
	var u := cos(ang) * (pl["a"] as float) * r
	var v := sin(ang) * (pl["b"] as float) * r
	return Vector3((pl["at"] as Vector2).x + u * c + v * s, 0.0, (pl["at"] as Vector2).y - u * s + v * c)


## A soft rain: fewer, fainter streaks than the storm's.
static func _drizzle(room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	var amount := 2200
	match Graphics.current:
		Graphics.Level.LOW:
			amount = 900
		Graphics.Level.ULTRA:
			amount = 3400
	p.amount = amount
	p.lifetime = 1.2
	p.position = Vector3(0.0, 20.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.75, 1.0, l * 0.75)
	pm.direction = Vector3(0.08, -1.0, 0.04)
	pm.spread = 2.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.gravity = Vector3(0.0, -9.0, 0.0)
	pm.particle_flag_align_y = true
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.7)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.80, 0.85, 0.90, 0.16)
	qm.albedo_texture = PlaceBuild.streak()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.billboard_keep_scale = true
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -30, -l), Vector3(w * 2.0, 40.0, l * 2.0))
	room.add_child(p)


## Mist only out among the trees round the clearing (the user's word,
## 2026-10-23: none inside, where the fight is): soft layered cards in a band
## beyond the edges, a low one and a higher one, thicker further out.
static func _outer_mist(room: Node3D, w: float, l: float, rng: RandomNumberGenerator, thick: float) -> void:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Dungeon.MIST_SHADER
	mat.shader = sh
	mat.set_shader_parameter("tint", Color(0.82, 0.87, 0.82))
	mat.set_shader_parameter("thick", maxf(thick, 0.3) * 1.6)
	var hw := w * 0.5
	var hl := l * 0.5
	for k in 70:
		var side := k % 4
		var t := rng.randf_range(-0.7, 0.7)
		var out := rng.randf_range(5.0, 70.0)
		var at := Vector3.ZERO
		match side:
			0: at = Vector3(-hw - out, 0.0, t * (l + 40.0))
			1: at = Vector3(hw + out, 0.0, t * (l + 40.0))
			2: at = Vector3(t * (w + 40.0), 0.0, -hl - out)
			_: at = Vector3(t * (w + 40.0), 0.0, hl + out)
		at.y = 0.05 + rng.randf_range(0.0, 0.3)
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(rng.randf_range(18.0, 34.0), rng.randf_range(18.0, 34.0))
		m.mesh = plane
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = at
		m.rotation.y = rng.randf_range(0.0, TAU)
		room.add_child(m)

