class_name PlaceBuild
extends RefCounted

## Places made again on the user's look round them (2026-10-21, F1's "Rooms"):
## the cave, the crypt, the swamp's water, the holy spring's fountain, and
## the storm path's wet. Built by [Dungeon] with its own helpers.

const POOL_SHADER := """
shader_type spatial;
render_mode cull_disabled;
// Still water lying in a hollow: its edge broken and soft (not a disc), dark
// and deep in the middle, a scum of green weed and duckweed drifting on it,
// slow rings, the sky in it.
uniform vec4 deep : source_color = vec4(0.02, 0.05, 0.04, 1.0);
uniform vec4 shallow : source_color = vec4(0.10, 0.13, 0.07, 1.0);
uniform vec4 weed : source_color = vec4(0.18, 0.26, 0.08, 1.0);
uniform float weed_amount = 0.6;
uniform float glow = 0.0;
// how much of the sky it gives back: little, or it lies there white as snow
uniform float shine = 0.1;
uniform vec4 glow_tint : source_color = vec4(0.2, 0.5, 0.7, 1.0);
varying vec3 lpos;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.3 + 3.1) * 0.3 + noise(p * 5.1 + 7.7) * 0.15; }
void vertex() { lpos = VERTEX; wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// the plane is 1 across: its own shape, ragged
	vec2 q = lpos.xz * 2.0;
	float r = length(q) + (fbm(wpos.xz * 0.25) - 0.5) * 0.55;
	if (r > 0.92) { discard; }
	float edge = smoothstep(0.55, 0.92, r);
	vec2 p = wpos.xz;
	// (2026-10-23, the user's word: not baked flat on the floor) a breeze's
	// slow small waves over it instead of rings laid out on a grid
	float ripple = noise(p * 2.2 + vec2(TIME * 0.35, TIME * 0.21)) * 0.6 + noise(p * 4.7 - vec2(TIME * 0.5, 0.0)) * 0.4;
	float scum = smoothstep(0.55, 0.75, fbm(p * 0.35 + vec2(TIME * 0.01, 0.0))) * weed_amount;
	float dots = step(0.82, noise(p * 6.0)) * weed_amount;
	vec3 c = mix(deep.rgb, shallow.rgb, edge);
	c = mix(c, weed.rgb * (0.8 + 0.4 * noise(p * 3.0)), max(scum, dots * 0.8));
	ALBEDO = c;
	EMISSION = glow_tint.rgb * glow * (1.0 - edge);
	float weedy = max(scum, dots);
	ROUGHNESS = mix(0.03, 0.9, weedy);
	// the sky given back more at a slant, as water does
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	SPECULAR = clamp(shine + fres * 0.45, 0.0, 1.0) * (1.0 - weedy);
	vec3 nw = normalize(vec3((noise(p * 1.3 + TIME * 0.15) - 0.5) * 0.08 + (ripple - 0.5) * 0.06,
			1.0, (noise(p * 1.3 - TIME * 0.12 + 5.0) - 0.5) * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	// its shore soft: the mud seen through the shallows
	ALPHA = (1.0 - smoothstep(0.62, 0.92, r)) * mix(0.96, 0.7, edge);
}
"""

const FOUNTAIN_WATER := """
shader_type spatial;
render_mode cull_disabled;
// The fountain's basin: clear, blue-green, light in it from below, rings
// running out from where the water falls in, sparkles.
uniform vec3 falls_at = vec3(0.0);
uniform float fall_r = 1.4;
uniform float used = 0.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
// in the surface's own space: the jet stands over its middle wherever the room is
void vertex() { wpos = VERTEX; }
void fragment() {
	vec2 d = wpos.xz - falls_at.xz;
	float r = length(d);
	float rings = sin(r * 5.0 - TIME * 3.0) * 0.5 + 0.5;
	rings *= exp(-max(r - fall_r, 0.0) * 0.35);
	vec3 c = mix(vec3(0.05, 0.3, 0.38), vec3(0.25, 0.65, 0.7), 0.4 + 0.3 * noise(wpos.xz * 0.8 + TIME * 0.2));
	float foam = smoothstep(fall_r + 0.4, fall_r - 0.1, r) * (0.6 + 0.4 * noise(wpos.xz * 6.0 + TIME * 2.0));
	ALBEDO = mix(mix(c, vec3(0.9, 0.97, 1.0), foam * 0.7), c * 0.6, used);
	EMISSION = vec3(0.1, 0.35, 0.45) * 0.6 * (1.0 - used * 0.7);
	float sparkle = step(0.985, noise(wpos.xz * 14.0 + TIME * 1.5));
	EMISSION += vec3(1.0) * sparkle * 2.0;
	ROUGHNESS = 0.04;
	SPECULAR = 0.6;
	vec3 nw = normalize(vec3(d.x, 0.0, d.y) / max(r, 0.01) * (rings - 0.5) * 0.25 + vec3(0.0, 1.0, 0.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALPHA = 0.88;
}
"""

const WET_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
// Rain on him (the user's word, 2026-10-21: the wet not felt on him): a dark
// glossy film over his clothes and skin, beads that catch the light, drops
// running down.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
varying vec3 wpos;
varying vec3 lpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; lpos = VERTEX; }
void fragment() {
	vec2 cell = floor(vec2(lpos.x * 40.0 + lpos.z * 30.0, lpos.y * 26.0 + TIME * 0.6));
	float bead = step(0.93, hash(cell));
	ALBEDO = vec3(0.02, 0.025, 0.03);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	METALLIC = 0.0;
	ALPHA = 0.28 + bead * 0.35;
}
"""

static var _pool_shader: Shader
static var _wet_mat: ShaderMaterial


#region Water
## A pool of still water, `size` across, at `at`: ragged at its edge.
static func pool(room: Node3D, at: Vector3, size: Vector2, yaw: float, colours: Dictionary = {}) -> MeshInstance3D:
	if _pool_shader == null:
		_pool_shader = Shader.new()
		_pool_shader.code = POOL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _pool_shader
	for key: String in colours:
		mat.set_shader_parameter(key, colours[key])
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = mat
	m.scale = Vector3(size.x, 1.0, size.y)
	m.rotation.y = yaw
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(m)
	return m
#endregion


#region The cave
## A cave (the user's word, 2026-10-21: not the crystals out of the floor,
## not its floor, not where its stones lay — and one walked through them):
## a floor of damp rock; walls of great rocks leaning in; the roof with its one
## crack of daylight; stone teeth hanging from the roof and growing up only
## in clumps against the walls, every one solid; crystals in the walls,
## glowing; a still pool; glowing mushrooms; the middle clear to fight in.
static func cave(d: Dungeon, room: Node3D, i: int) -> void:
	var r := d._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	var rng := d._rng
	var ground := d._cave_mat.duplicate() as ShaderMaterial
	ground.set_shader_parameter("scale", 0.42)
	ground.set_shader_parameter("moss_amount", 0.25)
	ground.set_shader_parameter("wet", 0.8)
	ground.set_shader_parameter("fleck_glow", 1.5)
	ground.set_shader_parameter("rock_a", Color(0.24, 0.26, 0.33))
	ground.set_shader_parameter("rock_b", Color(0.09, 0.10, 0.14))
	d._solid(room, ground, Vector3(w + 30.0, 1.0, l + 30.0), Vector3(0.0, -0.5, 0.0))
	d._bounds(room, w, l)
	# the walls: great rocks all round, close, leaning in
	var per := 8.0
	for side in 4:
		var long := l if side < 2 else w
		var n := int(long / per) + 2
		for k in n:
			var along := -long * 0.5 - 4.0 + float(k) * per + rng.randf_range(-1.5, 1.5)
			var out := rng.randf_range(2.5, 4.5)
			var at := Vector3.ZERO
			match side:
				0: at = Vector3(-w * 0.5 - out, -1.0, along)
				1: at = Vector3(w * 0.5 + out, -1.0, along)
				2: at = Vector3(along, -1.0, -l * 0.5 - out)
				_: at = Vector3(along, -1.0, l * 0.5 + out)
			var rock := d._boulder(room, at, Vector3(rng.randf_range(11.0, 16.0), h + rng.randf_range(3.0, 8.0),
					rng.randf_range(9.0, 13.0)), rng.randf_range(0.0, TAU), d._cave_mat)
			rock.rotation.z = rng.randf_range(-0.12, 0.12)
	# the roof, one crack of daylight in it
	var gap := Vector3(rng.randf_range(-w * 0.1, w * 0.1), 0.0, -l * 0.12)
	for gx in 3:
		for gz in 3:
			var at := Vector3((float(gx) - 1.0) * w * 0.36, h + 1.0, (float(gz) - 1.0) * l * 0.36)
			if absf(at.x - gap.x) < w * 0.2 and absf(at.z - gap.z) < l * 0.2:
				continue
			var slab := d._boulder(room, at, Vector3(w * 0.45, 9.0, l * 0.45), rng.randf_range(0.0, TAU), d._cave_mat,
					true, false)
			d._hang(slab, h + 9.0)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 5.0
	cyl.height = h + 6.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	var bm := ShaderMaterial.new()
	bm.shader = d._beam_shader
	bm.set_shader_parameter("tint", Color(1.0, 0.9, 0.7))
	bm.set_shader_parameter("strength", 0.05)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(gap.x, (h + 6.0) * 0.5, gap.z)
	room.add_child(beam)
	var shaft := SpotLight3D.new()
	shaft.light_color = Color(1.0, 0.9, 0.72)
	shaft.light_energy = 5.0
	shaft.spot_range = h + 14.0
	shaft.spot_angle = 22.0
	shaft.position = Vector3(gap.x, h + 10.0, gap.z)
	shaft.rotation.x = -PI * 0.5
	room.add_child(shaft)
	# moss and pale grass where the daylight falls
	for k in 14:
		var a := rng.randf_range(0.0, TAU)
		var at := gap + Vector3(sin(a), 0.0, cos(a)) * rng.randf_range(0.5, 4.0)
		d._nature(room, ["Grass_Wispy_Short", "Fern_1", "Clover_1"][k % 3], at, rng.randf_range(0.7, 1.1),
				rng.randf_range(0.0, TAU), false)
	# teeth hanging from the roof
	for k in 22:
		var tall := rng.randf_range(1.5, 5.5)
		var tooth := CylinderMesh.new()
		tooth.top_radius = 0.04
		tooth.bottom_radius = rng.randf_range(0.35, 1.0)
		tooth.height = tall
		tooth.radial_segments = 7
		tooth.rings = 2
		var t := MeshInstance3D.new()
		t.mesh = tooth
		t.material_override = d._cave_mat
		t.rotation.x = PI
		t.position = Vector3(rng.randf_range(-w * 0.45, w * 0.45), h - tall * 0.5 + 1.5, rng.randf_range(-l * 0.45, l * 0.45))
		room.add_child(t)
	# teeth growing up: in clumps against the walls only, each clump solid
	var clumps := 10
	for k in clumps:
		var side := k % 4
		var along := rng.randf_range(-0.42, 0.42)
		var at := Vector3.ZERO
		match side:
			0: at = Vector3(-w * 0.5 + 1.6, 0.0, along * l)
			1: at = Vector3(w * 0.5 - 1.6, 0.0, along * l)
			2: at = Vector3(along * w, 0.0, -l * 0.5 + 1.6)
			_: at = Vector3(along * w, 0.0, l * 0.5 - 2.5)
		if side == 3 and absf(at.x) < 6.0:
			continue
		var most := 0.0
		for m in rng.randi_range(2, 4):
			var tall := rng.randf_range(1.2, 4.5) * (1.0 if m == 0 else 0.6)
			most = maxf(most, tall)
			var tooth := CylinderMesh.new()
			tooth.top_radius = 0.05
			tooth.bottom_radius = rng.randf_range(0.4, 0.9)
			tooth.height = tall
			tooth.radial_segments = 7
			tooth.rings = 2
			var t := MeshInstance3D.new()
			t.mesh = tooth
			t.material_override = d._cave_mat
			t.position = at + Vector3(rng.randf_range(-0.8, 0.8), tall * 0.5 - 0.1, rng.randf_range(-0.8, 0.8))
			t.rotation = Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
			room.add_child(t)
		d._post(room, at, 1.4, most)
	# a few great stones fallen against the walls, solid
	for k in 6:
		var x := (w * 0.5 - 3.0) * (1.0 if k % 2 == 0 else -1.0)
		var z := -l * 0.35 + floorf(float(k) / 2.0) * l * 0.32 + rng.randf_range(-3.0, 3.0)
		var size := rng.randf_range(2.4, 3.6)
		d._boulder(room, Vector3(x, -0.4, z), Vector3(size * 1.3, size, size * 1.1), rng.randf_range(0.0, TAU), d._cave_mat)
		d._post(room, Vector3(x, 0.0, z), size * 0.6, size)
	# crystals in the walls: clusters set into the rock, growing out of it
	var tints := [Color(0.3, 0.6, 1.0), Color(0.25, 0.85, 1.0), Color(0.62, 0.45, 1.0)]
	for k in 8:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := -l * 0.4 + floorf(float(k) / 2.0) * l * 0.26
		var at := Vector3(side * (w * 0.5 + 0.6), rng.randf_range(2.5, 6.0), z + rng.randf_range(-2.0, 2.0))
		_wall_crystals(d, room, at, -side, tints[k % tints.size()])
	# a still pool, faintly lit from under
	pool(room, Vector3(w * 0.22, 0.03, l * 0.2), Vector2(12.0, 9.0), rng.randf_range(0.0, TAU),
			{"deep": Color(0.01, 0.03, 0.06), "shallow": Color(0.05, 0.12, 0.18), "weed_amount": 0.0,
			"glow": 0.5, "glow_tint": Color(0.1, 0.4, 0.55)})
	for k in 10:
		var name: String = ["Mushroom_Brown", "Mushroom_Dark_Red", "Mushroom_Grey", "Mushroom_Red_Spotted"][k % 4]
		var x := (w * 0.45) * (1.0 if k % 2 == 0 else -1.0) + rng.randf_range(-1.0, 1.0)
		var shroom := d._prop(room, name, Vector3(x, 0.0, rng.randf_range(-l * 0.4, l * 0.4)), rng.randf_range(0.6, 1.4),
				rng.randf_range(0.0, TAU), false)
		if k % 3 == 0:
			d._glow(shroom, [Color(0.2, 0.9, 0.8), Color(0.5, 0.9, 0.3), Color(0.3, 0.6, 1.0)][k % 3])
	d._mist(room, w, l, 0.4, Color(0.45, 0.58, 0.85), 0.25)
	d._torch(room, Vector3(-w * 0.3, 2.8, l * 0.5 - 2.0))
	d._torch(room, Vector3(w * 0.3, 2.8, l * 0.5 - 2.0))
	d._motes(room, w, l, h)


## Crystals growing out of a wall at `at`, out along `out` (x), glowing `tint`.
static func _wall_crystals(d: Dungeon, room: Node3D, at: Vector3, out: float, tint: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint.darkened(0.5)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.15
	mat.metallic = 0.3
	for k in d._rng.randi_range(4, 7):
		var c := CylinderMesh.new()
		var tall := d._rng.randf_range(0.6, 1.8)
		c.top_radius = 0.02
		c.bottom_radius = d._rng.randf_range(0.1, 0.24)
		c.height = tall
		c.radial_segments = 6
		c.rings = 1
		var m := MeshInstance3D.new()
		m.mesh = c
		m.material_override = mat
		# lying out of the wall, fanned
		var tip := Vector3(out, d._rng.randf_range(-0.4, 0.6), d._rng.randf_range(-0.6, 0.6)).normalized()
		var side := tip.cross(Vector3.FORWARD).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		m.transform = Transform3D(Basis(side, tip, side.cross(tip)), at + tip * tall * 0.45
				+ Vector3(0.0, d._rng.randf_range(-0.5, 0.5), d._rng.randf_range(-0.5, 0.5)))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(m)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 1.8
	light.omni_range = 9.0
	light.position = at + Vector3(out * 1.2, 0.0, 0.0)
	room.add_child(light)
#endregion


#region The crypt
## The crypt (the user's word, 2026-10-21: lovelier — not cleaner: a place
## one likes to be in): Elden Ring's catacombs. A barrel vault on great
## arches; the dead in their niches down both walls, candles under them; down
## the middle, the tombs of the great on plinths, their stone likenesses lying
## on them; iron wheels of candles hanging; at the far end a shrine, its
## altar heaped with candles under a glowing window of stained light; warm
## light in pools, a cold air between, a thin mist low.
static func crypt(d: Dungeon, room: Node3D, i: int) -> void:
	var r := d._room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	var rng := d._rng
	var stone := d._wall_mat.duplicate() as ShaderMaterial
	stone.set_shader_parameter("stone", Color(0.40, 0.38, 0.35))
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.52, 0.49, 0.44)
	pale.roughness = 0.85
	var vault_mat := StandardMaterial3D.new()
	vault_mat.albedo_color = Color(0.30, 0.29, 0.27)
	vault_mat.roughness = 0.95
	vault_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	d._solid(room, d._floor_mat(i), Vector3(w + Dungeon.WALL_T * 2.0, 1.0, l + Dungeon.WALL_T * 2.0), Vector3(0.0, -0.5, 0.0))
	var spring := h * 0.55
	for side: float in [-1.0, 1.0]:
		d._solid(room, stone, Vector3(Dungeon.WALL_T, h + 4.0, l + Dungeon.WALL_T * 2.0),
				Vector3(side * (w + Dungeon.WALL_T) * 0.5, (h + 4.0) * 0.5, 0.0))
		d._solid(room, stone, Vector3(w + Dungeon.WALL_T * 2.0, h + 6.0, Dungeon.WALL_T),
				Vector3(0.0, (h + 6.0) * 0.5, side * (l + Dungeon.WALL_T) * 0.5))
	# the barrel vault, from the top of the walls: a half ellipse of stone
	_arch(d, room, vault_mat, w * 0.5, w * 0.5 * 0.55, spring, 0.0, l + 0.5, 0.5, 18)
	# its arches: a rib of pale stone across every bay, on a pier each side
	var step := 6.0
	var n := int(l / step)
	for k in n + 1:
		var z := -l * 0.5 + float(k) * step
		_arch(d, room, pale, w * 0.5 - 0.35, (w * 0.5 - 0.35) * 0.55, spring, z, 0.8, 0.75, 16)
		for side: float in [-1.0, 1.0]:
			var pier := BoxMesh.new()
			pier.size = Vector3(1.3, spring + 0.5, 1.3)
			d._deco(room, pale, pier, Vector3(side * (w * 0.5 - 0.65), (spring + 0.5) * 0.5, z))
			d._blocker(room, Vector3(1.3, h, 1.3), Vector3(side * (w * 0.5 - 0.65), h * 0.5, z))
			var cap := BoxMesh.new()
			cap.size = Vector3(1.7, 0.45, 1.7)
			d._deco(room, pale, cap, Vector3(side * (w * 0.5 - 0.65), spring + 0.4, z))
			# the dead in their niche, candles below it
			if k < n:
				var nz := z + step * 0.5
				var niche := d._necro_put(room, "EA_Bld_Tomb_Niche_Clean_Class_A_01c",
						Vector3(side * (w * 0.5 - 0.2), 0.0, nz), PI * 0.5 * -side, 2.2)
				if niche == null:
					var box := BoxMesh.new()
					box.size = Vector3(0.8, 2.2, 3.2)
					d._deco(room, pale, box, Vector3(side * (w * 0.5 - 0.4), 1.1, nz))
				d._candles(room, Vector3(side * (w * 0.5 - 1.5), 0.0, nz + rng.randf_range(-0.8, 0.8)), k % 2 == 0)
				if rng.randf() < 0.4:
					d._bones(room, Vector3(side * (w * 0.5 - 2.3), 0.0, nz + rng.randf_range(-1.2, 1.2)))
	# the tombs of the great down the middle, on plinths, their likeness on them
	# (kept off the way out at −l/2+15: places_test, 2026-10-24, found the last
	# tomb standing where the way out comes up)
	for k in 3:
		var z := l * 0.27 - float(k) * l * 0.2
		_tomb(d, room, Vector3(0.0, 0.0, z), stone, pale)
	# wheels of candles hanging between the tombs
	for k in 3:
		_candle_wheel(d, room, Vector3(0.0, h * 0.8, l * 0.17 - float(k) * l * 0.2), h)
	# the shrine at the far end
	_shrine(d, room, Vector3(0.0, 0.0, -l * 0.5 + 2.2), pale, stone, w, h)
	for k in 6:
		d._bones(room, Vector3(rng.randf_range(-w * 0.38, w * 0.38), 0.0, rng.randf_range(-l * 0.4, l * 0.42)))
	d._rubble_round(room, i, w, l)
	d._mist(room, w, l, 0.15, Color(0.55, 0.58, 0.6), 0.18)
	d._motes(room, w, l, h)
	for side: float in [-1.0, 1.0]:
		d._torch(room, Vector3(side * 3.5, 3.0, l * 0.5 - 0.6))


## Half an ellipse of stone blocks (`rx` across, `ry` up, from `y`), `long`
## deep at `z`, `thick` thick, in `n` pieces: a vault, or the rib of an arch.
static func _arch(d: Dungeon, room: Node3D, mat: Material, rx: float, ry: float, y: float, z: float, long: float,
		thick: float, n: int) -> void:
	for k in n:
		var t0 := PI * float(k) / float(n)
		var t1 := PI * float(k + 1) / float(n)
		var a := Vector2(rx * cos(t0), y + ry * sin(t0))
		var b := Vector2(rx * cos(t1), y + ry * sin(t1))
		var piece := BoxMesh.new()
		piece.size = Vector3(a.distance_to(b) + 0.08, thick, long)
		var m := d._deco(room, mat, piece, Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z))
		m.rotation.z = atan2(b.y - a.y, b.x - a.x)
		# its outer face outward: the slab sits on the curve's outside
		m.position += Vector3(sin(m.rotation.z), -cos(m.rotation.z), 0.0) * thick * 0.5


## A great one's tomb: a stepped plinth, the chest, his likeness in stone
## lying on the lid, hands on a sword; candles at its corners.
static func _tomb(d: Dungeon, room: Node3D, at: Vector3, stone: Material, pale: Material) -> void:
	var plinth := BoxMesh.new()
	plinth.size = Vector3(3.4, 0.35, 4.6)
	d._deco(room, stone, plinth, at + Vector3(0.0, 0.17, 0.0))
	var chest := BoxMesh.new()
	chest.size = Vector3(2.0, 1.0, 3.2)
	d._deco(room, pale, chest, at + Vector3(0.0, 0.85, 0.0))
	var lid := BoxMesh.new()
	lid.size = Vector3(2.3, 0.22, 3.5)
	d._deco(room, stone, lid, at + Vector3(0.0, 1.46, 0.0))
	# the likeness: body, head on a cushion, the sword down him
	var body := CapsuleMesh.new()
	body.radius = 0.32
	body.height = 2.1
	var bm := d._deco(room, pale, body, at + Vector3(0.0, 1.78, 0.1))
	bm.rotation.x = PI * 0.5
	bm.scale = Vector3(1.0, 1.0, 0.6)
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	d._deco(room, pale, head, at + Vector3(0.0, 1.85, -1.1))
	var sword := BoxMesh.new()
	sword.size = Vector3(0.08, 0.05, 1.5)
	d._deco(room, d._iron_mat, sword, at + Vector3(0.0, 2.02, 0.3))
	var guard := BoxMesh.new()
	guard.size = Vector3(0.45, 0.06, 0.07)
	d._deco(room, d._iron_mat, guard, at + Vector3(0.0, 2.04, -0.42))
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			d._candles(room, at + Vector3(cx * 1.5, 0.35, cz * 2.1), cx > 0.0 and cz > 0.0)
	d._blocker(room, Vector3(3.4, 2.0, 4.6), at + Vector3(0.0, 1.0, 0.0))


## An iron wheel of candles hanging on chains.
static func _candle_wheel(d: Dungeon, room: Node3D, at: Vector3, h: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 1.0
	ring.outer_radius = 1.12
	ring.rings = 20
	ring.ring_segments = 5
	d._deco(room, d._iron_mat, ring, at)
	for k in 3:
		var a := TAU * float(k) / 3.0
		var chain := CylinderMesh.new()
		chain.top_radius = 0.02
		chain.bottom_radius = 0.02
		chain.height = h + 2.0 - at.y
		d._deco(room, d._iron_mat, chain, at + Vector3(sin(a) * 1.05, chain.height * 0.5, cos(a) * 1.05))
	for k in 8:
		var a := TAU * float(k) / 8.0
		var candle := CylinderMesh.new()
		candle.top_radius = 0.05
		candle.bottom_radius = 0.06
		candle.height = 0.3
		var wax := StandardMaterial3D.new()
		wax.albedo_color = Color(0.85, 0.8, 0.68)
		d._deco(room, wax, candle, at + Vector3(sin(a) * 1.06, 0.16, cos(a) * 1.06))
		room.add_child(d._flame(at + Vector3(sin(a) * 1.06, 0.32, cos(a) * 1.06), 0.5, 6))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.68, 0.38)
	light.light_energy = 2.4
	light.omni_range = 12.0
	light.position = at + Vector3(0.0, 0.2, 0.0)
	room.add_child(d._fire_light(light))
	d._creaks.append(room.position + at)


## The shrine at the crypt's end: steps up to an altar heaped with candles, a
## tall arch behind it with a window of stained light, a statue each side.
static func _shrine(d: Dungeon, room: Node3D, at: Vector3, pale: Material, stone: Material, w: float, h: float) -> void:
	for k in 3:
		var stepb := BoxMesh.new()
		stepb.size = Vector3(10.0 - float(k) * 2.0, 0.25, 3.6 - float(k) * 0.9)
		d._deco(room, pale, stepb, at + Vector3(0.0, 0.125 + float(k) * 0.25, 0.4 - float(k) * 0.45))
	var altar := BoxMesh.new()
	altar.size = Vector3(3.0, 1.1, 1.2)
	d._deco(room, stone, altar, at + Vector3(0.0, 0.75 + 0.55, -0.6))
	for k in 5:
		d._candles(room, at + Vector3(-1.2 + float(k) * 0.6, 1.85, -0.6 + d._rng.randf_range(-0.2, 0.2)), k == 2)
	# the window: a tall pointed arch of light
	var glass := ShaderMaterial.new()
	glass.shader = d._glass_shader
	var pane := QuadMesh.new()
	pane.size = Vector2(3.2, 6.5)
	var gm := d._deco(room, glass, pane, at + Vector3(0.0, 5.0, -2.05))
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame := TorusMesh.new()
	frame.inner_radius = 1.6
	frame.outer_radius = 1.9
	frame.rings = 18
	var fm := d._deco(room, pale, frame, at + Vector3(0.0, 8.2, -2.0))
	fm.rotation.x = PI * 0.5
	for side: float in [-1.0, 1.0]:
		var jamb := BoxMesh.new()
		jamb.size = Vector3(0.35, 6.6, 0.4)
		d._deco(room, pale, jamb, at + Vector3(side * 1.75, 4.9, -2.0))
		# a statue: a hooded figure on a pedestal, hands on a sword
		var ped := BoxMesh.new()
		ped.size = Vector3(1.2, 1.2, 1.2)
		d._deco(room, stone, ped, at + Vector3(side * 4.2, 0.6, -1.0))
		var robe := CylinderMesh.new()
		robe.top_radius = 0.35
		robe.bottom_radius = 0.6
		robe.height = 2.6
		robe.radial_segments = 10
		d._deco(room, pale, robe, at + Vector3(side * 4.2, 2.5, -1.0))
		var hood := SphereMesh.new()
		hood.radius = 0.36
		hood.height = 0.8
		d._deco(room, pale, hood, at + Vector3(side * 4.2, 4.05, -1.0))
		d._blocker(room, Vector3(1.2, 4.0, 1.2), at + Vector3(side * 4.2, 2.0, -1.0))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.75, 0.6, 1.0)
	glow.light_energy = 2.0
	glow.omni_range = 12.0
	glow.position = at + Vector3(0.0, 4.0, 0.5)
	room.add_child(glow)
	d._blocker(room, Vector3(3.2, 2.0, 1.4), at + Vector3(0.0, 1.0, -0.6))
#endregion


#region The holy spring's fountain
## A fountain worth the name (the user's word, 2026-10-21): an eight-sided
## basin of pale stone on a step, its rim carved; in its middle a pillar with
## two bowls one over the other, water brimming from each and falling in
## sheets; a jet from the top; four spouts round the rim arching water in;
## the water clear and lit, rings where it falls, spray, sparkle.
static func fountain(d: Dungeon, holder: Node3D) -> Dictionary:
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.6, 0.58, 0.54)
	pale.roughness = 0.75
	var gold := d._gold_mat
	# the step and the basin
	var stepc := CylinderMesh.new()
	stepc.top_radius = 6.2
	stepc.bottom_radius = 6.4
	stepc.height = 0.3
	stepc.radial_segments = 8
	d._deco(holder, pale, stepc, Vector3(0.0, 0.15, 0.0))
	var wall := CylinderMesh.new()
	wall.top_radius = 5.3
	wall.bottom_radius = 5.5
	wall.height = 0.8
	wall.radial_segments = 8
	d._deco(holder, pale, wall, Vector3(0.0, 0.7, 0.0))
	var lip := TorusMesh.new()
	lip.inner_radius = 4.85
	lip.outer_radius = 5.45
	lip.rings = 8
	lip.ring_segments = 6
	var lm := d._deco(holder, pale, lip, Vector3(0.0, 1.1, 0.0))
	lm.rotation.y = PI / 8.0
	# carved panels round it: a gold rosette on each face
	for k in 8:
		var a := TAU * float(k) / 8.0 + PI / 8.0
		var ros := CylinderMesh.new()
		ros.top_radius = 0.22
		ros.bottom_radius = 0.22
		ros.height = 0.06
		var rm := d._deco(holder, gold, ros, Vector3(sin(a) * 5.43, 0.7, cos(a) * 5.43))
		rm.rotation = Vector3(PI * 0.5, a, 0.0)
	var sh := Shader.new()
	sh.code = FOUNTAIN_WATER
	var water := ShaderMaterial.new()
	water.shader = sh
	var surf := CylinderMesh.new()
	surf.top_radius = 5.0
	surf.bottom_radius = 5.0
	surf.height = 0.04
	surf.radial_segments = 8
	var sm := d._deco(holder, water, surf, Vector3(0.0, 0.95, 0.0))
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the pillar and its two bowls
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.35
	shaft.bottom_radius = 0.6
	shaft.height = 3.6
	shaft.radial_segments = 12
	d._deco(holder, pale, shaft, Vector3(0.0, 2.6, 0.0))
	for k in 2:
		var bowl := CylinderMesh.new()
		var rad := 2.2 if k == 0 else 1.2
		bowl.top_radius = rad
		bowl.bottom_radius = rad * 0.35
		bowl.height = 0.55
		bowl.radial_segments = 16
		var y := 2.4 if k == 0 else 4.1
		d._deco(holder, pale, bowl, Vector3(0.0, y, 0.0))
		var band := TorusMesh.new()
		band.inner_radius = rad - 0.06
		band.outer_radius = rad + 0.06
		band.rings = 24
		band.ring_segments = 5
		d._deco(holder, gold, band, Vector3(0.0, y + 0.27, 0.0))
		var inner := CylinderMesh.new()
		inner.top_radius = rad - 0.1
		inner.bottom_radius = rad - 0.1
		inner.height = 0.03
		inner.radial_segments = 16
		var im := d._deco(holder, water, inner, Vector3(0.0, y + 0.24, 0.0))
		im.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# its brim spilling over all round, in a falling sheet
		holder.add_child(_spill(Vector3(0.0, y + 0.25, 0.0), rad, 2.4 if k == 0 else 1.6))
	# a finial: a gold flame on the top
	var bud := SphereMesh.new()
	bud.radius = 0.28
	bud.height = 0.7
	d._deco(holder, gold, bud, Vector3(0.0, 4.75, 0.0))
	# the jet from the top, and the four spouts round the rim
	holder.add_child(_jet(Vector3(0.0, 5.0, 0.0), Vector3.UP, 5.5, 0.4, 90))
	for k in 4:
		var a := TAU * float(k) / 4.0
		var spout := BoxMesh.new()
		spout.size = Vector3(0.4, 0.4, 0.7)
		var sp := d._deco(holder, gold, spout, Vector3(sin(a) * 5.2, 1.35, cos(a) * 5.2))
		sp.rotation.y = a
		var dir := Vector3(-sin(a), 0.9, -cos(a)).normalized()
		holder.add_child(_jet(Vector3(sin(a) * 4.95, 1.4, cos(a) * 4.95), dir, 4.2, 0.08, 50))
	# spray and a glow over the water
	var mist := GPUParticles3D.new()
	mist.amount = 40
	mist.lifetime = 2.5
	mist.position = Vector3(0.0, 1.2, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 2.4
	pm.emission_ring_inner_radius = 0.4
	pm.emission_ring_height = 0.1
	pm.emission_ring_axis = Vector3.UP
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.0, 0.05, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.color = Color(0.8, 0.95, 1.0, 0.12)
	mist.process_material = pm
	var puff := QuadMesh.new()
	puff.size = Vector2(1.6, 1.6)
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	tex.gradient = g
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = tex
	puff.material = qm
	mist.draw_pass_1 = puff
	holder.add_child(mist)
	d._blocker(holder, Vector3(3.0, 5.0, 3.0), Vector3(0.0, 2.5, 0.0))
	return {"water": water}


## Water spilling over a bowl's brim all round, falling in a sheet.
static func _spill(at: Vector3, radius: float, fall: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(radius * 90.0)
	p.lifetime = sqrt(2.0 * fall / 9.8) + 0.1
	p.position = at
	p.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = radius + 0.04
	pm.emission_ring_inner_radius = radius
	pm.emission_ring_height = 0.02
	pm.emission_ring_axis = Vector3.UP
	pm.direction = Vector3.DOWN
	pm.spread = 4.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.particle_flag_align_y = true
	pm.color = Color(0.75, 0.92, 1.0, 0.55)
	p.process_material = pm
	p.draw_pass_1 = _drop_mesh(Vector2(0.06, 0.32))
	p.visibility_aabb = AABB(Vector3(-radius - 1.0, -fall - 1.0, -radius - 1.0), Vector3(radius * 2.0 + 2.0, fall + 2.0, radius * 2.0 + 2.0))
	return p


## A jet of water thrown along `dir`, falling back.
static func _jet(at: Vector3, dir: Vector3, speed: float, spread: float, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = speed / 9.8 * 2.0
	p.position = at
	p.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = spread * 0.2
	pm.direction = dir
	pm.spread = 6.0 if spread > 0.2 else 2.0
	pm.initial_velocity_min = speed * 0.92
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0.0, -9.8, 0.0)
	pm.particle_flag_align_y = true
	pm.color = Color(0.8, 0.95, 1.0, 0.6)
	p.process_material = pm
	p.draw_pass_1 = _drop_mesh(Vector2(0.07, 0.28))
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	return p


static var _soft_dot: Texture2D
static var _streak: Texture2D


## A soft round spot, bright in the middle, gone at its edge: for drops,
## splashes, fireflies (the user's word, 2026-10-23: no squares).
static func soft_dot() -> Texture2D:
	if _soft_dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft_dot = t
	return _soft_dot


## A falling drop's streak: soft at its sides, fading at both ends.
static func streak() -> Texture2D:
	if _streak == null:
		var img := Image.create(16, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var v := float(y) / 63.0
			var along := sin(v * PI) * (0.4 + 0.6 * v)
			for x in 16:
				var u := (float(x) + 0.5) / 16.0
				var across := pow(maxf(1.0 - absf(u - 0.5) * 2.0, 0.0), 1.5)
				img.set_pixel(x, y, Color(1, 1, 1, across * along))
		_streak = ImageTexture.create_from_image(img)
	return _streak


static func _drop_mesh(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = soft_dot()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	q.material = m
	return q
#endregion


#region The storm's wet
## Puddles in the hollows of the shelf, rings of the rain in them.
static func puddles(d: Dungeon, room: Node3D, w: float, l: float) -> void:
	for k in 9:
		var at := Vector3(d._rng.randf_range(-w * 0.4, w * 0.4), 0.025, d._rng.randf_range(-l * 0.42, l * 0.42))
		var m := pool(room, at, Vector2(d._rng.randf_range(2.5, 6.0), d._rng.randf_range(2.0, 4.5)),
				d._rng.randf_range(0.0, TAU), {"deep": Color(0.05, 0.06, 0.08), "shallow": Color(0.16, 0.17, 0.2),
				"weed_amount": 0.0, "shine": 0.25})
		m.set_meta(&"rain", true)


## The rain landing: small splashes all over the floor.
static func splashes(room: Node3D, w: float, l: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 700
	p.lifetime = 0.22
	p.position = Vector3(0.0, 0.05, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.5, 0.0, l * 0.5)
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.0, -8.0, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(0.8, 0.85, 0.95, 0.35)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	p.draw_pass_1 = _drop_mesh(Vector2(0.07, 0.07))
	p.visibility_aabb = AABB(Vector3(-w, -1, -l), Vector3(w * 2.0, 3.0, l * 2.0))
	room.add_child(p)
	return p


## The hero wet with rain: the film over him (or off again), drops running
## off him.
static func wet(hero: Player, on: bool) -> void:
	if _wet_mat == null:
		var sh := Shader.new()
		sh.code = WET_SHADER
		_wet_mat = ShaderMaterial.new()
		_wet_mat.shader = sh
	var body: Node3D = hero.rig as Node3D if hero.rig is Node3D else hero
	for g in body.find_children("*", "GeometryInstance3D", true, false):
		var geo := g as GeometryInstance3D
		if geo is GPUParticles3D or geo is Label3D:
			continue
		if on and geo.material_overlay == null:
			geo.material_overlay = _wet_mat
		elif not on and geo.material_overlay == _wet_mat:
			geo.material_overlay = null
	var drips := hero.get_node_or_null(^"RainDrips") as GPUParticles3D
	if on and drips == null:
		drips = GPUParticles3D.new()
		drips.name = "RainDrips"
		drips.amount = 18
		drips.lifetime = 0.6
		drips.position = Vector3(0.0, 1.0, 0.0)
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.3, 0.7, 0.2)
		pm.direction = Vector3.DOWN
		pm.spread = 5.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 1.5
		pm.gravity = Vector3(0.0, -9.8, 0.0)
		pm.color = Color(0.6, 0.68, 0.78, 0.3)
		drips.process_material = pm
		drips.draw_pass_1 = _drop_mesh(Vector2(0.012, 0.06))
		hero.add_child(drips)
		# and the rain bursting off his shoulders and head
		var hits := GPUParticles3D.new()
		hits.name = "RainHits"
		hits.amount = 14
		hits.lifetime = 0.2
		hits.position = Vector3(0.0, 1.75, 0.0)
		var hm := ParticleProcessMaterial.new()
		hm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		hm.emission_box_extents = Vector3(0.25, 0.05, 0.15)
		hm.direction = Vector3.UP
		hm.spread = 60.0
		hm.initial_velocity_min = 0.6
		hm.initial_velocity_max = 1.2
		hm.gravity = Vector3(0.0, -9.8, 0.0)
		hm.color = Color(0.6, 0.68, 0.78, 0.25)
		hits.process_material = hm
		hits.draw_pass_1 = _drop_mesh(Vector2(0.018, 0.03))
		drips.add_child(hits)
		hits.position = Vector3(0.0, 0.75, 0.0)
	elif not on and drips != null:
		drips.queue_free()
#endregion
