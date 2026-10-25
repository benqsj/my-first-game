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
## Other looks are kept in LOOKS ("emerald", "willow", "dead", "black") for
## trying; `variant` picks one. Tried and dropped: image-to-3D trees
## (Hunyuan3D-2 mini on the Mac, see vepxis-art/NOTES.md), cattails, lilies.

## How deep the hollows go at their deepest.
const DEPTH := 0.5
## The ground's mesh and collision step.
const STEP := 0.5

const WATER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
// Clear still water in a hollow (the user's word, 2026-10-21/23: not baked
// flat on the floor): what lies under it seen through it and bent a little,
// greener where it is deeper, its edge soft where the mud comes up to it, a
// breeze's small waves, the sky and the trees in it.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform vec4 shallow : source_color = vec4(0.62, 0.80, 0.78, 1.0);
uniform vec4 deep : source_color = vec4(0.10, 0.27, 0.28, 1.0);
// metres of water before it is all deep colour
uniform float clarity = 0.55;
uniform float wave = 0.035;
// how much of the sky it gives back
uniform float gloss = 0.55;
// a green film of duckweed and slime in patches on top (0 none)
uniform float scum = 0.0;
uniform vec4 scum_tint : source_color = vec4(0.36, 0.46, 0.14, 1.0);
// ripples from feet in the water (the user's word, 2026-10-23: real waves,
// not marks drawn on it): world x, z, seconds since, strength; each a ring
// of a few crests running out and dying, shown only in how the surface
// bends the light (no colour of its own)
uniform vec4 drops[32];
uniform int drop_count = 0;
uniform float drop_speed = 1.3;
// silt held in the water: muddy, not clear
uniform vec4 silt : source_color = vec4(0.40, 0.33, 0.21, 1.0);
uniform float silt_amount = 0.0;
// mud on the surface itself, patchy, and a very little green (the user's
// word, 2026-10-24: the surface muddier, textured, hardly any green)
uniform sampler2D mud_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float mud_cover = 0.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float waves(vec2 p) {
	return noise(p * 0.9 + vec2(TIME * 0.22, TIME * 0.13)) * 0.6
			+ noise(p * 2.3 - vec2(TIME * 0.31, -TIME * 0.17)) * 0.3
			+ noise(p * 5.7 + vec2(0.0, TIME * 0.5)) * 0.1;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float e = 0.08;
	float h0 = waves(p);
	vec2 slope = vec2((h0 - waves(p + vec2(e, 0.0))) / e, (h0 - waves(p + vec2(0.0, e))) / e) * wave;
	vec2 calm = slope;
	float lift = 0.0;
	for (int i = 0; i < drop_count; i++) {
		vec4 dr = drops[i];
		vec2 off = p - dr.xy;
		float dist = length(off);
		float front = dr.z * drop_speed;
		float x = dist - front;
		if (abs(x) > 1.2) { continue; }
		// a short packet of crests behind the front, fading as it spreads
		float k = 7.0;
		float g = exp(-x * x / 0.18) * step(x, 0.25);
		float amp = dr.w * exp(-dr.z * 1.1 / max(1.0, dr.w * 0.6)) / (1.0 + dist * 0.8) * smoothstep(0.0, 0.35, dist);
		float dh = amp * (k * cos(k * x) * g + sin(k * x) * g * (-2.0 * x / 0.18));
		slope -= (off / max(dist, 0.001)) * dh * 0.32;
		lift += amp * sin(k * x) * g;
	}
	// tipped too far the surface gives back the grass and the trees (green
	// blots): the ripples may tilt it only so much
	vec2 rip = slope - calm;
	float rl = length(rip);
	if (rl > 0.22) { rip *= 0.22 / rl; }
	slope = calm + rip;
	vec3 nw = normalize(vec3(slope.x, 1.0, slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	// how much water the eye looks through to the bottom
	float zb = texture(depth_tex, SCREEN_UV).r;
	vec4 b = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zb, 1.0);
	b.xyz /= b.w;
	float thick = max(VERTEX.z - b.z, 0.0);
	// what is under it bent by the breeze's waves, and only a little by the
	// ripples (bent far, it fetched the grass from beside the pond)
	vec2 bend = calm + clamp(slope - calm, vec2(-0.25), vec2(0.25)) * 0.25;
	vec2 bent = SCREEN_UV + bend * 0.04 * smoothstep(0.0, 0.4, thick);
	// not bent onto what stands in front of the water
	float zb2 = texture(depth_tex, bent).r;
	vec4 b2 = INV_PROJECTION_MATRIX * vec4(bent * 2.0 - 1.0, zb2, 1.0);
	b2.xyz /= b2.w;
	if (b2.z > VERTEX.z) { bent = SCREEN_UV; }
	vec3 under = textureLod(screen_tex, bent, 0.0).rgb;
	float t = 1.0 - exp(-thick / clarity);
	vec3 seen = under * mix(vec3(1.0), shallow.rgb, 0.45);
	// the silt clouding it, a little uneven
	float cloud = silt_amount * (0.8 + 0.2 * noise(p * 0.6)) * smoothstep(0.0, 0.08, thick);
	seen = mix(seen, silt.rgb * 0.75, cloud);
	// the water's own colour lit as the rest; what lies under it already lit
	ALBEDO = deep.rgb * t;
	EMISSION = seen * (1.0 - t * 0.9);
	ROUGHNESS = 0.02;
	METALLIC = 0.0;
	// more of the trees and the sky given back at a grazing look
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION *= 1.0 - fres * 0.5;
	SPECULAR = gloss;
	// a thin pale line where it meets the mud
	float lip = 1.0 - smoothstep(0.0, 0.05, thick);
	EMISSION += vec3(0.75, 0.85, 0.82) * lip * 0.04;
	// the film: drifting a little, thicker toward the shore
	float f = noise(p * 0.32 + vec2(TIME * 0.004, 0.0)) * 0.7 + noise(p * 1.7) * 0.3;
	float film = smoothstep(0.55, 0.72, f + (1.0 - smoothstep(0.0, 0.3, thick)) * 0.35) * scum
			* (1.0 - smoothstep(0.15, 0.6, thick));
	film *= 0.75 + 0.25 * noise(p * 9.0);
	ALBEDO = mix(ALBEDO, scum_tint.rgb * (0.8 + 0.4 * noise(p * 4.0)), film);
	EMISSION *= 1.0 - film;
	if (mud_cover > 0.0) {
		vec3 mt = texture(mud_tex, p * 0.16).rgb;
		float patch = smoothstep(0.3, 0.75, noise(p * 0.22) * 0.65 + noise(p * 0.9) * 0.35);
		float cover = mud_cover * (0.45 + 0.55 * patch) * smoothstep(0.0, 0.05, thick);
		float green = smoothstep(0.72, 0.9, noise(p * 0.5 + 17.0)) * 0.35;
		vec3 muck = mix(mt * vec3(0.78, 0.72, 0.62), mt * vec3(0.55, 0.68, 0.40), green);
		ALBEDO = mix(ALBEDO, muck, cover);
		EMISSION *= 1.0 - cover * 0.75;
		ROUGHNESS = mix(ROUGHNESS, 0.5, cover * 0.6);
	}
	// the ripples' crests a little lighter and wetter, their troughs darker,
	// so they read on the muddy skin too
	float lit = clamp(lift * 0.55, -0.3, 0.3);
	ALBEDO *= 1.0 + lit;
	EMISSION *= 1.0 + lit;
	ROUGHNESS = clamp(ROUGHNESS - abs(lit) * 0.6, 0.02, 1.0);
	ROUGHNESS = mix(ROUGHNESS, 0.85, film);
	SPECULAR = mix(SPECULAR, 0.2, film);
	ALPHA = smoothstep(0.0, 0.025, thick);
}
"""

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

## The swamp's looks (2026-10-23, round 2: the user wanted no flowers or
## grass in the water, a swamp's water colour, other trees). Set `variant`
## before a build. Trees are [scene, height in metres, weight]; "bare" ones
## lose their leaves.
const EA := "res://Prefabs/Nature/Tree/EA03_Nature_Tree_%s_PRE.prefab.scn"
const KIT := "res://assets/dungeon/swamp/kit/%s.glb"
const NAT := "res://glTF/%s.gltf"
const LOOKS := {
	# the same trees over deep emerald water, still as a mirror
	"emerald": {"shallow": Color(0.30, 0.46, 0.38), "deep": Color(0.02, 0.10, 0.08), "clarity": 0.20,
			"scum": 0.0, "gloss": 0.9, "mist": 0.3,
			"near": [["CommonTree_1", 11.0, 1], ["CommonTree_2", 11.0, 1], ["CommonTree_4", 12.0, 1],
					["CommonTree_5", 11.0, 1]],
			"far": [["CommonTree_1", 14.0, 1], ["CommonTree_2", 14.0, 1], ["CommonTree_4", 15.0, 1],
					["CommonTree_5", 14.0, 1]]},
	# the user's pick (2026-10-23, round 3: trees 23, 24, 26, 27 of the
	# gallery): the nature kit's round green trees over green murky water
	"green": {"shallow": Color(0.52, 0.45, 0.32), "deep": Color(0.16, 0.13, 0.08), "clarity": 0.28,
			"scum": 0.0, "gloss": 0.45, "mist": 0.3, "silt": 0.3, "mud": 0.12,
			"near": [["CommonTree_1", 11.0, 1], ["CommonTree_2", 11.0, 1], ["CommonTree_4", 12.0, 1],
					["CommonTree_5", 11.0, 1]],
			"far": [["CommonTree_1", 14.0, 1], ["CommonTree_2", 14.0, 1], ["CommonTree_4", 15.0, 1],
					["CommonTree_5", 14.0, 1]]},
	# the user's pick (2026-10-25): the green swamp as it was, its trees the
	# pale marsh's (tall thin grey trunks, big flat rust leaves, low poly,
	# [PaleMarsh]'s kit), a third more of them, they being thin
	"pale": {"shallow": Color(0.52, 0.45, 0.32), "deep": Color(0.16, 0.13, 0.08), "clarity": 0.28,
			"scum": 0.0, "gloss": 0.45, "mist": 0.3, "silt": 0.3, "mud": 0.12, "step": 0.72,
			"near": [["PTree0", 14.0, 1], ["PTree1", 16.0, 1], ["PTree2", 12.5, 1], ["PTree3", 17.5, 1],
					["PTree4", 15.0, 1], ["PTree5", 13.0, 1]],
			"far": [["PTreeFar", 16.0, 1]]},
	# (a look to show, 2026-10-25: the pale trees with green ones among them)
	"pale_mix": {"shallow": Color(0.52, 0.45, 0.32), "deep": Color(0.16, 0.13, 0.08), "clarity": 0.28,
			"scum": 0.0, "gloss": 0.45, "mist": 0.3, "silt": 0.3, "mud": 0.12, "step": 0.72,
			"near": [["PTree0", 14.0, 2], ["PTree1", 16.0, 2], ["PTree2", 12.5, 2], ["PTree3", 17.5, 2],
					["PTree4", 15.0, 2], ["PTree5", 13.0, 2], ["PTreeG0", 14.5, 2], ["PTreeG1", 16.5, 2],
					["PTreeG2", 13.0, 2]],
			"far": [["PTreeFar", 16.0, 1], ["PTreeFarG", 16.0, 1]]},
	# the user's pick (2026-10-25, "B"): low poly as the forest, its gnarled
	# oaks round the clearing, faceted ground and water (`low_poly`); the
	# water's colours here are the faceted water's
	"oak": {"shallow": Color(0.31, 0.33, 0.20), "deep": Color(0.11, 0.15, 0.08), "clarity": 0.28,
			"scum": 0.0, "gloss": 0.45, "mist": 0.3, "near": [], "far": []},
	# weeping willows over green murky water with duckweed on it
	"willow": {"shallow": Color(0.34, 0.40, 0.18), "deep": Color(0.09, 0.15, 0.06), "clarity": 0.16,
			"scum": 0.6, "gloss": 0.35, "mist": 0.18,
			"near": [["03b", 12.0, 3], ["03c", 12.0, 3], ["05a", 10.0, 2], ["DeadTree_1", 11.0, 1]],
			"far": [["03b", 15.0, 2], ["03c", 15.0, 2], ["01b", 15.0, 1], ["02b", 15.0, 1]]},
	# a drowned dead wood over brown tea water, stumps and fallen logs
	"dead": {"shallow": Color(0.42, 0.32, 0.16), "deep": Color(0.16, 0.10, 0.04), "clarity": 0.12,
			"scum": 0.0, "gloss": 0.22, "mist": 0.26,
			"near": [["DeadTree_1", 12.0, 3], ["DeadTree_2", 11.0, 3], ["CommonTree_Dead_1", 10.0, 1],
					["CommonTree_Dead_3", 10.0, 1], ["05a", 10.0, 1]],
			"far": [["DeadTree_3", 15.0, 1], ["DeadTree_4", 15.0, 1], ["01b", 14.0, 1], ["02c", 14.0, 1]]},
	# old gnarled trees and willows over still black water like a mirror
	"black": {"shallow": Color(0.12, 0.14, 0.10), "deep": Color(0.02, 0.03, 0.02), "clarity": 0.08,
			"scum": 0.15, "gloss": 0.45, "mist": 0.32,
			"near": [["05a", 11.0, 3], ["03b", 12.0, 2], ["DeadTree_2", 12.0, 2], ["03c", 12.0, 1]],
			"far": [["05a", 14.0, 2], ["03b", 15.0, 1], ["DeadTree_1", 15.0, 1], ["02b", 14.0, 1]]},
}
static var variant := "pale"
## The swamp low poly as the forest (the user's pick, 2026-10-25, "B"): the
## ground and the water faceted and coloured face by face, the forest's oaks,
## ferns, rocks and stumps. Off, the swamp as it was before ("pale"); F2's
## board switches it.
static var low_poly := true
## Whether this build's swamp has the soft rain (about half the time).
static var raining := false
## For pictures: -1 the dice, 0 never, 1 always.
static var rain_force := -1
## The trees' own colours made a little deeper and cooler for the swamp (the
## user's word, 2026-10-23: the trees a little another colour).
const LEAF_TINT := Color(0.66, 0.80, 0.62)
const BARK_TINT := Color(0.72, 0.70, 0.68)
static var _tinted := {}
static var _scenes := {}
static var _heights := {}
static var _water_shader: Shader


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
	_ground(room, ground, gw, gl, pools, noise)
	var lp := low_poly
	if lp:
		# the smooth ground kept only to walk on; the faceted one to look at,
		# fine where the fight is, coarse out under the far wood
		var walked := room.get_child(room.get_child_count() - 1)
		for mi in walked.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).visible = false
		_lp_ground(room, Rect2(-gw * 0.5, -gl * 0.5, gw, gl), 1.6, Rect2(), w, l, pools, noise, rng, 0.01)
		_lp_ground(room, Rect2(-210.0, -210.0, 420.0, 420.0), 5.0, Rect2(-gw * 0.5 + 6.0, -gl * 0.5 + 6.0,
				gw - 12.0, gl - 12.0), w, l, pools, noise, rng, -0.02)
	else:
		_mud_bed(d, room, gw, gl, pools, noise)
		_mud_skin(d, room, w, l, pools, noise)
	# the land on round it, flat, under the trees further off
	var far := 160.0
	for side in 4:
		var size := Vector3(far, 1.0, gl) if side < 2 else Vector3(gw + far * 2.0, 1.0, far)
		var at := Vector3((gw + far) * 0.5 * (-1.0 if side == 0 else 1.0), -0.5, 0.0) if side < 2 \
				else Vector3(0.0, -0.5, (gl + far) * 0.5 * (-1.0 if side == 2 else 1.0))
		var slab := d._solid(room, ground, size, at)
		if lp and slab != null:
			for mi in slab.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).visible = false
	d._bounds(room, w, l)
	# the water in each hollow
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = WATER
	var look: Dictionary = LOOKS["oak"] if lp else LOOKS.get(variant, LOOKS["green"])
	var water := ShaderMaterial.new()
	water.shader = _water_shader
	# drawn first of everything see-through: what is over the water (the
	# sword's arc, splashes, the rain) is drawn after it and so stays seen
	# (the user's word, 2026-10-24: the blade's trail lost over the water and
	# for a while after it)
	water.render_priority = -100
	water.set_shader_parameter("shallow", look["shallow"])
	water.set_shader_parameter("deep", look["deep"])
	water.set_shader_parameter("clarity", look["clarity"])
	water.set_shader_parameter("scum", look["scum"])
	water.set_shader_parameter("gloss", look["gloss"])
	water.set_shader_parameter("silt_amount", look.get("silt", 0.0))
	water.set_shader_parameter("mud_tex", d._photo_tex("mud"))
	water.set_shader_parameter("mud_cover", look.get("mud", 0.0))
	if lp:
		water = _lp_water(look)
	var plane := PlaneMesh.new()
	plane.size = Vector2(w + 16.0, l + 16.0)
	if lp:
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
			if lp:
				_lp_shore(room, pl, rng, grow, pools, noise)
			else:
				_dress_pool(room, pl, rng, grow, pools, noise)
	if lp:
		_oak_wood(room, w, l, rng, grow, pools)
	else:
		# the trees and the sky given back by the water
		var probe := ReflectionProbe.new()
		probe.size = Vector3(w + 30.0, 30.0, l + 30.0)
		probe.position = Vector3(0.0, 2.0, 0.0)
		probe.box_projection = false
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.max_distance = 120.0
		room.add_child(probe)
		_woods(d, room, w, l, rng, grow, look)
		_inner_trees(d, room, w, l, rng, look, pools)
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


static func _ground(room: Node3D, mat: Material, gw: float, gl: float, pools: Array[Dictionary],
		noise: FastNoiseLite) -> void:
	var nx := int(gw / STEP) + 1
	var nz := int(gl / STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for k in nz:
		for i in nx:
			heights[k * nx + i] = _height(-gw * 0.5 + i * STEP, -gl * 0.5 + k * STEP, pools, noise)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in nz:
		for i in nx:
			st.add_vertex(Vector3(-gw * 0.5 + i * STEP, heights[k * nx + i], -gl * 0.5 + k * STEP))
	for k in nz - 1:
		for i in nx - 1:
			var a := k * nx + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + nx)
	st.generate_normals()
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	body.add_child(mi)
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


## Under the water only mud and silt, never grass (the user's word,
## 2026-10-23): a skin of dark wet mud a little over the ground in each
## hollow and a little past the water's edge (a wet mud rim). Opaque, so
## the water sees it through the screen texture.
static func _mud_bed(d: Dungeon, room: Node3D, _gw: float, _gl: float, pools: Array[Dictionary],
		noise: FastNoiseLite) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = d._photo_tex("mud")
	mat.albedo_color = Color(0.56, 0.47, 0.35)
	mat.normal_enabled = d._photo_tex("mud_nor") != null
	mat.normal_texture = d._photo_tex("mud_nor")
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.22
	mat.roughness = 0.35
	# cut where the vertex share falls under a half: a smooth shore line
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := STEP * 0.5
	for pl in pools:
		var span: float = maxf(pl["a"], pl["b"]) * 1.45
		var c: Vector2 = pl["at"]
		var n := int(span * 2.0 / step) + 1
		var x0 := c.x - span
		var z0 := c.y - span
		var pts: Array[Vector3] = []
		var alp: Array[float] = []
		for k in n:
			for i in n:
				var x := x0 + i * step
				var z := z0 + k * step
				var h := _height(x, z, pools, noise)
				pts.append(Vector3(x, h + 0.012, z))
				alp.append(1.0 - smoothstep(SURFACE - 0.012, SURFACE + 0.004, h))
		for k in n - 1:
			for i in n - 1:
				var a := k * n + i
				var quad := [a, a + 1, a + n, a + 1, a + n + 1, a + n]
				if alp[a] + alp[a + 1] + alp[a + n] + alp[a + n + 1] <= 0.0:
					continue
				for q: int in quad:
					st.set_color(Color(1, 1, 1, alp[q]))
					st.set_normal(Vector3.UP)
					st.add_vertex(pts[q])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)


## The clearing's ground trodden to mud where the fight is (the user's word,
## 2026-10-24: the ground I stand on muddy, not the water): wet mud over most
## of it in broad soft-edged patches, the grass left at the edges, a little
## green in it. A skin a hair over the ground, cut by noise (opaque).
const MUD_SKIN := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D t_mud : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_mud : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cover = 0.7;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float n = noise(p * 0.07) * 0.55 + noise(p * 0.27) * 0.3 + noise(p * 1.4) * 0.15;
	float keep = n * COLOR.a + cover - 0.5;
	if (keep < 0.5) { discard; }
	vec2 uv = p * 0.22;
	vec3 m = texture(t_mud, uv).rgb;
	// wetter and darker deep in a patch, drier at its rim
	float wet = smoothstep(0.5, 0.75, keep);
	vec3 col = m * mix(vec3(0.78, 0.70, 0.58), vec3(0.55, 0.48, 0.38), wet);
	float green = smoothstep(0.78, 0.95, noise(p * 0.9 + 31.0)) * 0.3;
	col = mix(col, col * vec3(0.75, 1.0, 0.62), green);
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.55, wet);
	SPECULAR = 0.4;
	NORMAL_MAP = texture(n_mud, uv).rgb;
}
"""


static func _mud_skin(d: Dungeon, room: Node3D, w: float, l: float, pools: Array[Dictionary],
		noise: FastNoiseLite) -> void:
	var sh := Shader.new()
	sh.code = MUD_SKIN
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("t_mud", d._photo_tex("mud"))
	mat.set_shader_parameter("n_mud", d._photo_tex("mud_nor"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := STEP
	var nx := int(w / step) + 1
	var nz := int(l / step) + 1
	var pts: Array[Vector3] = []
	var alp: Array[float] = []
	for k in nz:
		for i in nx:
			var x := -w * 0.5 + i * step
			var z := -l * 0.5 + k * step
			var h := _height(x, z, pools, noise)
			pts.append(Vector3(x, h + 0.008, z))
			# less toward the clearing's edges
			var edge := minf(1.0 - absf(x) / (w * 0.5), 1.0 - absf(z) / (l * 0.5))
			# under the water too (the pond's bed is the same mud): no strip of
			# grass left between the two at the shore
			alp.append(smoothstep(0.0, 0.25, edge))
	for k in nz - 1:
		for i in nx - 1:
			var a0 := k * nx + i
			var quad := [a0, a0 + 1, a0 + nx, a0 + 1, a0 + nx + 1, a0 + nx]
			if alp[a0] + alp[a0 + 1] + alp[a0 + nx] + alp[a0 + nx + 1] <= 0.0:
				continue
			for q: int in quad:
				st.set_color(Color(1, 1, 1, alp[q]))
				st.set_normal(Vector3.UP)
				st.set_tangent(Plane(1, 0, 0, 1))
				st.add_vertex(pts[q])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)


## A point on a pool's shore (r = 1) or in it (r < 1), in metres.
static func _on(pl: Dictionary, ang: float, r: float) -> Vector3:
	var c := cos(pl["yaw"] as float)
	var s := sin(pl["yaw"] as float)
	var u := cos(ang) * (pl["a"] as float) * r
	var v := sin(ang) * (pl["b"] as float) * r
	return Vector3((pl["at"] as Vector2).x + u * c + v * s, 0.0, (pl["at"] as Vector2).y - u * s + v * c)


## A pool's shore: nothing growing in the water (the user's word), only
## mossy stones and a stump at the edge.
static func _dress_pool(room: Node3D, pl: Dictionary, rng: RandomNumberGenerator, grow: float,
		pools: Array[Dictionary], noise: FastNoiseLite) -> void:
	var size: float = pl["a"] + pl["b"]
	for k in int(size * 0.35 * grow) + 2:
		var at := _on(pl, rng.randf_range(0.0, TAU), rng.randf_range(0.92, 1.12))
		at.y = _height(at.x, at.z, pools, noise) - 0.12
		_place(room, KIT % ("Rock_Moss_%d" % rng.randi_range(1, 7)), at, rng.randf_range(0.0, TAU),
				rng.randf_range(0.5, 1.4))
	if rng.randf() < 0.7:
		var at2 := _on(pl, rng.randf_range(0.0, TAU), 1.02)
		at2.y = _height(at2.x, at2.z, pools, noise) - 0.1
		_place(room, KIT % "TreeStump_Moss", at2, rng.randf_range(0.0, TAU), rng.randf_range(1.2, 1.7))


## One of a kit's scenes put down whole.
static func _place(room: Node3D, path: String, at: Vector3, yaw: float, s: float) -> Node3D:
	var sc: PackedScene = _scenes.get(path) as PackedScene
	if sc == null:
		if not ResourceLoader.exists(path):
			return null
		sc = load(path) as PackedScene
		_scenes[path] = sc
	var n := sc.instantiate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	room.add_child(n)
	return n


## A tree of a look's list standing `h` metres tall.
static func _tree(d: Dungeon, room: Node3D, spec: Array, at: Vector3, yaw: float, k: float, solid: bool,
		poor: bool = false) -> void:
	var key: String = spec[0]
	if key.begins_with("PTree"):
		_kit_tree(room, key, float(spec[1]) * k, at, yaw, solid)
		return
	var path := ""
	# a tree not close to the fight: the poor copy (a seventh of the faces)
	var far_key := key.replace("CommonTree_", "FarTree_")
	if poor and key.begins_with("CommonTree_") and not key.begins_with("CommonTree_Dead") \
			and ResourceLoader.exists(KIT % far_key):
		path = KIT % far_key
	elif key.begins_with("CommonTree_Dead") or key.begins_with("Willow"):
		path = KIT % key
	elif key.begins_with("DeadTree") or key.begins_with("Twisted") or key.begins_with("CommonTree"):
		path = NAT % key
	else:
		path = EA % key
	var n := _place(room, path, at, yaw, 1.0)
	if n == null:
		return
	if not _heights.has(path):
		var ab := AABB()
		var first := true
		for g in n.find_children("*", "VisualInstance3D", true, false):
			var gi := g as VisualInstance3D
			var bb: AABB = (n.global_transform.affine_inverse() * gi.global_transform) * gi.get_aabb()
			ab = bb if first else ab.merge(bb)
			first = false
		_heights[path] = maxf(ab.end.y, 0.5)
	n.scale = Vector3.ONE * (float(spec[1]) * k / float(_heights[path]))
	if key.begins_with("DeadTree") or key.begins_with("CommonTree_Dead"):
		d._strip_leaves(n)
	_tint(n)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		if not solid:
			(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if solid:
		_trunk(n)


## A pale marsh tree (its kit, [PaleMarsh]) `h` metres tall.
static var _kit_heights := {}
static func _kit_tree(room: Node3D, key: String, h: float, at: Vector3, yaw: float, solid: bool) -> void:
	PaleMarsh._ready_kit()
	var n := PaleMarsh._piece(room, key, at, yaw)
	if not _kit_heights.has(key):
		var mi := n as MeshInstance3D
		_kit_heights[key] = maxf(mi.get_aabb().end.y if mi != null else h, 0.5)
	n.scale = Vector3.ONE * (h / float(_kit_heights[key]))
	if solid:
		TerracePlaces._post_col(n, 0.4 / n.scale.x, 6.0)
	else:
		for g in n.find_children("*", "GeometryInstance3D", true, false) + [n]:
			if g is GeometryInstance3D:
				(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Each surface's material swapped for a deeper, cooler copy (made once).
static func _tint(n: Node3D) -> void:
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var m := mi.get_active_material(k) as StandardMaterial3D
			if m == null:
				continue
			var t: StandardMaterial3D = _tinted.get(m) as StandardMaterial3D
			if t == null:
				t = m.duplicate() as StandardMaterial3D
				var leaf := m.resource_name.to_lower().contains("lea")
				t.albedo_color = m.albedo_color * (LEAF_TINT if leaf else BARK_TINT)
				_tinted[m] = t
			mi.set_surface_override_material(k, t)


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


static func _pick(list: Array, rng: RandomNumberGenerator) -> Array:
	var total := 0
	for e: Array in list:
		total += int(e[2])
	var r := rng.randi_range(1, total)
	for e: Array in list:
		r -= int(e[2])
		if r <= 0:
			return e
	return list[0]


## The trees round the clearing, two rows of the look's near trees, its far
## ones behind; round bushes at their feet.
static func _woods(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator, grow: float,
		look: Dictionary) -> void:
	# three rows close round the clearing, near one another (the user's word:
	# more trees), no bushes or flowers under them
	for row in 3:
		var out := 2.5 + float(row) * 6.0
		var step := (6.0 + float(row) * 1.2) * float(look.get("step", 1.0))
		for side in 4:
			var long := (l if side < 2 else w) + out * 2.0
			var n := int(long / step)
			for k in n:
				var along := -long * 0.5 + (float(k) + rng.randf_range(0.25, 0.75)) * step
				var at := Vector3.ZERO
				match side:
					0: at = Vector3(-w * 0.5 - out, 0.0, along)
					1: at = Vector3(w * 0.5 + out, 0.0, along)
					2: at = Vector3(along, 0.0, -l * 0.5 - out)
					_: at = Vector3(along, 0.0, l * 0.5 + out)
				if side == 3 and absf(at.x) < 7.0 and row == 0:
					continue
				at += Vector3(rng.randf_range(-1.5, 1.5), 0.0, rng.randf_range(-1.5, 1.5))
				_tree(d, room, _pick(look["near"], rng), at, rng.randf_range(0.0, TAU),
						rng.randf_range(0.85, 1.15) + float(row) * 0.1, row == 0)
	# the wood behind: many trees, cheap (the user's word, 2026-10-23: far
	# off they can be poor, only so that looking out one is in a wood)
	var more := 1.0 / float(look.get("step", 1.0))
	_far_wood(room, w, l, rng, look, int(260.0 * grow * more), 16.0, 95.0, 0.85, 1.3)
	# and further, bigger: the wood closing the view all round (no plain
	# and sky seen between the trunks)
	_far_wood(room, w, l, rng, look, int(170.0 * grow * more), 90.0, 170.0, 1.6, 2.4)
	# groves: a few trees standing close together here and there
	for g in 7:
		var a := rng.randf_range(0.0, TAU)
		var out := rng.randf_range(5.0, 13.0)
		var c := Vector3(sin(a) * (w * 0.5 + out), 0.0, cos(a) * (l * 0.5 + out))
		for k in rng.randi_range(3, 5):
			var at := c + Vector3(rng.randf_range(-2.6, 2.6), 0.0, rng.randf_range(-2.6, 2.6))
			_tree(d, room, _pick(look["near"], rng), at, rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.15), false)


## Trees far out drawn as one MultiMesh per kind and part: no shadows, no
## collision, the engine's own LODs, gone past `fade` metres.
static func _far_wood(room: Node3D, w: float, l: float, rng: RandomNumberGenerator, look: Dictionary,
		count: int, near: float, far: float, s_lo: float, s_hi: float) -> void:
	var kinds: Array = look["far"]
	var spots := []
	for k in kinds.size():
		spots.append([])
	for k in count:
		var a := rng.randf_range(0.0, TAU)
		var out := rng.randf_range(near, far)
		var at := Vector3(sin(a) * (w * 0.5 + out), 0.0, cos(a) * (l * 0.5 + out))
		var kind := rng.randi_range(0, kinds.size() - 1)
		var s := rng.randf_range(s_lo, s_hi)
		(spots[kind] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), at))
	for kind in kinds.size():
		var spec: Array = kinds[kind]
		if String(spec[0]).begins_with("PTree"):
			PaleMarsh._ready_kit()
			var src_mi := PaleMarsh._kit.get_node_or_null(String(spec[0])) as MeshInstance3D
			var top := src_mi.get_aabb().end.y if src_mi != null else float(spec[1])
			var where: Array[Transform3D] = []
			for t: Transform3D in spots[kind]:
				where.append(Transform3D(t.basis.scaled(Vector3.ONE * float(spec[1]) / maxf(top, 0.5)), t.origin))
			PaleMarsh._many(room, String(spec[0]), where)
			continue
		# the poor copies made for far off (vepxis-art/world/far_trees.py)
		var far_key := String(spec[0]).replace("CommonTree_", "FarTree_")
		var path := KIT % far_key if ResourceLoader.exists(KIT % far_key) else NAT % String(spec[0])
		var sc: PackedScene = _scenes.get(path) as PackedScene
		if sc == null:
			if not ResourceLoader.exists(path):
				continue
			sc = load(path) as PackedScene
			_scenes[path] = sc
		var src := sc.instantiate() as Node3D
		_tint(src)
		var ab := AABB()
		var first := true
		for g in src.find_children("*", "MeshInstance3D", true, false):
			var gi := g as MeshInstance3D
			var bb: AABB = gi.transform * gi.get_aabb()
			ab = bb if first else ab.merge(bb)
			first = false
		var base := float(spec[1]) / maxf(ab.end.y, 0.5)
		for g in src.find_children("*", "MeshInstance3D", true, false):
			var gi := g as MeshInstance3D
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = gi.mesh
			var list: Array = spots[kind]
			mm.instance_count = list.size()
			for i in list.size():
				var t: Transform3D = list[i]
				mm.set_instance_transform(i, Transform3D(t.basis.scaled(Vector3.ONE * base), t.origin) * gi.transform)
			# the tinted materials ride on a copy of the mesh's surfaces
			var tinted := gi.mesh.duplicate() as ArrayMesh
			if tinted != null:
				for k in tinted.get_surface_count():
					var mat := gi.get_active_material(k)
					if mat != null:
						tinted.surface_set_material(k, mat)
				mm.mesh = tinted
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			room.add_child(mmi)
		src.free()


## A wood's feel (the user's word, 2026-10-23): trees inside the clearing
## too, along its sides a few metres in, never in the water, the middle open.
static func _inner_trees(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator,
		look: Dictionary, pools: Array[Dictionary]) -> void:
	for side in 4:
		var long := (l if side < 2 else w) - 6.0
		var step := 7.0 * float(look.get("step", 1.0))
		for k in int(long / step):
			var along := -long * 0.5 + (float(k) + rng.randf_range(0.2, 0.8)) * step
			var inset := rng.randf_range(2.0, 5.5)
			var at := Vector3.ZERO
			match side:
				0: at = Vector3(-w * 0.5 + inset, 0.0, along)
				1: at = Vector3(w * 0.5 - inset, 0.0, along)
				2: at = Vector3(along, 0.0, -l * 0.5 + inset)
				_: at = Vector3(along, 0.0, l * 0.5 - inset)
			if side == 3 and absf(at.x) < 8.0:
				continue
			var dry := true
			for pl in pools:
				if _into(pl, at.x, at.z, null) < 1.35:
					dry = false
			if dry:
				_tree(d, room, _pick(look["near"], rng), at, rng.randf_range(0.0, TAU), rng.randf_range(0.8, 1.05), true)


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


## A trunk nobody walks through.
static func _trunk(n: Node3D) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 1.0
	c.height = 8.0
	shape.shape = c
	shape.position.y = 4.0
	body.add_child(shape)
	n.add_child(body)
