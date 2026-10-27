class_name PortalLook
extends Node3D

## A dungeon's gate as it stands (the user's word, 2026-10-19: "ლამაზად
## გაკეთებული მოშავო მოიასამისფრო პორტალი"; 2026-10-20: more beautiful). A
## pointed arch of dark voussoirs on two posts, old letters (asomtavruli)
## burning violet down the posts, three square steps, a brazier of violet fire
## either side, shards of the same stone turning round it, and in the opening
## a slow black-and-violet whirl with a heat-haze shimmer round its rim. No
## ring on the ground.
##
## Built in code, the same for the five gates in the open world and the way
## out of a dungeon; `tint` gives each its own violet.

## The whirl's colour at its rim (its heart is near black).
@export var tint: Color = Color(0.55, 0.22, 0.95)
## What is on the other side, seen in the heart of the whirl (a dungeon's
## portals: a picture of the place they lead to, the user's word 2026-10-20).
@export var view: Texture2D
## The opening: its width and the height its arch springs from.
@export var span: float = 3.0
@export var spring: float = 3.4
## Only the whirl, no stones, letters, steps nor braziers (the rift the second
## wave comes out of: the user's word, 2026-10-27, no frame).
@export var bare: bool = false

var _lights: Array[OmniLight3D] = []
var _shards: Array[MeshInstance3D] = []
var _runes: Array[Label3D] = []
## Its stones, each [mesh, the node standing where it goes] until they are
## drawn as one ([method _merge_stones]).
var _stones: Array = []
## False: each stone its own mesh, as before (to measure against).
static var merge_stones: bool = true
var _t: float = 0.0

## The top of the opening (a pointed arch of two arcs, each of radius `span`).
var apex: float:
	get:
		return spring + span * 0.866

const VEIL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 rim : source_color = vec4(0.55, 0.22, 0.95, 1.0);
uniform float span = 3.0;
uniform float spring = 3.4;
uniform float tall = 6.0;
uniform float speed = 0.3;
uniform sampler2D view_tex : source_color, filter_linear_mipmap;
uniform float has_view = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

// How far inside the opening a point is, in metres (negative outside).
float inside(vec2 p) {
	float half = span * 0.5;
	if (p.y < spring) {
		return min(min(half - abs(p.x), p.y), 9.0);
	}
	float a = span - length(p - vec2(half, spring));
	float b = span - length(p - vec2(-half, spring));
	return min(min(a, b), half - abs(p.x) + 1.0);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * span, (1.0 - UV.y) * tall);
	float d = inside(p);
	if (d < 0.0) { discard; }
	float edge = 1.0 - clamp(d / (span * 0.42), 0.0, 1.0);
	vec2 c = p - vec2(0.0, tall * 0.48);
	float r = length(c / vec2(span * 0.5, tall * 0.5));
	float a = atan(c.y, c.x);
	// The whirl: noise in polar space, turning faster near the heart.
	float turn = TIME * speed + 1.8 / (r + 0.3);
	vec2 q = vec2(cos(a + turn), sin(a + turn)) * (1.3 + r * 2.4);
	float swirl = fbm(q * 1.7 + vec2(TIME * 0.11, 0.0));
	float arms = 0.5 + 0.5 * sin(a * 3.0 + turn * 2.4 + swirl * 5.5);
	float glow = smoothstep(0.1, 1.0, r) * (0.5 + 0.5 * arms) * (0.55 + 0.9 * swirl);
	vec3 deep = vec3(0.015, 0.0, 0.04);
	vec3 col = mix(deep, rim.rgb * 1.7, clamp(glow, 0.0, 1.0));
	// the place beyond, swimming in the heart of it
	if (has_view > 0.5) {
		vec2 vuv = UV + vec2(sin(a * 3.0 + TIME * 1.3), cos(a * 2.0 - TIME)) * 0.012 * r;
		vec3 pic = texture(view_tex, vuv).rgb;
		float show = (1.0 - smoothstep(0.35, 0.9, r)) * (0.85 + 0.1 * swirl);
		col = mix(col, pic * 1.08, show);
	}
	// Stars far in: a few specks drawn inwards.
	vec2 sp = vec2(a * 6.0, log(r + 0.05) * 6.0 + TIME * 1.2);
	float star = step(0.985, hash(floor(sp * 3.0))) * smoothstep(0.7, 0.1, r);
	col += vec3(0.85, 0.75, 1.0) * star * 1.4;
	// The rim: bright, flickering like lightning now and then.
	float flick = 0.75 + 0.25 * sin(TIME * 7.0 + a * 4.0) + step(0.97, noise(vec2(TIME * 3.0, a * 2.0))) * 1.2;
	col += rim.rgb * pow(edge, 3.0) * 2.2 * flick;
	ALBEDO = col;
	ALPHA = clamp(0.95 - pow(edge, 8.0) * 0.4, 0.0, 1.0);
}
"""

## A shimmer just round the opening: the air bent by what is in there.
const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.012;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 c = UV - vec2(0.5, 0.52);
	float r = length(c * vec2(1.0, 0.8));
	float band = smoothstep(0.5, 0.36, r) * smoothstep(0.2, 0.34, r);
	if (band < 0.01) { discard; }
	vec2 wob = vec2(sin(UV.y * 40.0 + TIME * 3.0), cos(UV.x * 37.0 - TIME * 2.6)) * strength * band;
	ALBEDO = texture(screen_tex, SCREEN_UV + wob).rgb;
	ALPHA = band;
}
"""

const STONE_SHADER := """
shader_type spatial;
uniform vec4 stone : source_color = vec4(0.11, 0.10, 0.13, 1.0);
uniform vec4 vein : source_color = vec4(0.55, 0.22, 0.95, 1.0);
varying vec3 wpos;
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 cell = floor(wpos * vec3(2.2, 3.0, 2.2));
	float n = hash(cell);
	ALBEDO = stone.rgb * (0.75 + 0.5 * n);
	ROUGHNESS = 0.7;
	SPECULAR = 0.4;
	// Faint violet veins that breathe with the gate.
	float v = smoothstep(0.982, 1.0, hash(floor(wpos * 9.0)));
	EMISSION = vein.rgb * v * (0.7 + 0.5 * sin(TIME * 1.3 + n * 6.0));
}
"""

## Asomtavruli, down the posts.
const RUNES := ["Ⴀ", "Ⴁ", "Ⴂ", "Ⴃ", "Ⴄ", "Ⴅ", "Ⴆ", "Ⴇ", "Ⴈ", "Ⴉ", "Ⴊ", "Ⴋ"]


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_t += delta
	for i in _lights.size():
		_lights[i].light_energy = (2.6 if i == 0 else 1.4) + sin(_t * (1.7 + float(i)) + float(i)) * 0.35 \
				+ sin(_t * 4.3 + float(i) * 2.0) * 0.12
	var n := _shards.size()
	for i in n:
		var a := _t * 0.35 + TAU * float(i) / float(n)
		var s := _shards[i]
		s.position = Vector3(cos(a) * (span * 0.5 + 1.6), apex * 0.55 + sin(_t * 0.9 + float(i) * 1.7) * 0.6
				+ float(i % 3) * 0.9, sin(a) * 1.1)
		s.rotation = Vector3(_t * 0.8 + float(i), _t * 1.1, 0.3)
	for i in _runes.size():
		_runes[i].modulate.a = 0.55 + 0.45 * sin(_t * 1.6 - float(i) * 0.5)


## One shader per kind of code, made once for every portal: made afresh each
## time, every portal that opened was compiled anew (2026-10-20).
static var _shaders: Dictionary = {}


static func _shared(code: String) -> Shader:
	var key := code.hash()
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = code
		_shaders[key] = shader
	return _shaders[key]


func _stone_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := _shared(STONE_SHADER)
	mat.shader = shader
	mat.set_shader_parameter("vein", tint)
	return mat


func _build() -> void:
	var stone := _stone_mat()
	var half := span * 0.5
	var post := 0.75
	var depth := 0.95
	# Three square steps.
	for k in 3:
		var w := span + 3.2 - float(k) * 0.7
		_box(stone, Vector3(w, 0.22, 2.6 - float(k) * 0.5), Vector3(0.0, 0.11 + float(k) * 0.22, 0.0))
	var base := 0.66
	# The posts: plinth, shaft, capital.
	for side: float in [-1.0, 1.0]:
		var x := side * (half + post * 0.5)
		_box(stone, Vector3(post * 1.4, 0.5, depth * 1.3), Vector3(x, base + 0.25, 0.0))
		_box(stone, Vector3(post, spring - 0.5, depth), Vector3(x, base + 0.5 + (spring - 0.5) * 0.5, 0.0))
		_box(stone, Vector3(post * 1.35, 0.32, depth * 1.25), Vector3(x, base + spring + 0.16, 0.0))
	# The arch: voussoirs round two arcs of radius `span`, springing at the posts.
	var ring := 0.7
	var count := 7
	for side: float in [-1.0, 1.0]:
		var centre := Vector2(-side * half, base + spring + 0.32)
		for k in count:
			# From the springing (angle 0 / 180) up to the apex (60 / 120).
			var t := (float(k) + 0.5) / float(count)
			var ang := deg_to_rad(lerpf(0.0, 60.0, t))
			if side < 0.0:
				ang = PI - ang
			var rr := span + ring * 0.5
			var at := Vector2(centre.x + cos(ang) * rr, centre.y + sin(ang) * rr)
			var piece := _box(stone, Vector3(ring, span * deg_to_rad(60.0) / float(count) * 1.02 + 0.06, depth),
					Vector3(at.x, at.y, 0.0))
			piece.rotation.z = ang
	var top := base + spring + 0.32 + span * 0.866
	_box(stone, Vector3(0.85, 1.25, depth * 1.15), Vector3(0.0, top + 0.55, 0.0))
	# Spires on the capitals, and the old letters down the posts.
	for side: float in [-1.0, 1.0]:
		var x := side * (half + post * 0.5)
		var spire := Node3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.24
		cone.height = 1.3
		cone.radial_segments = 4
		spire.position = Vector3(x, base + spring + 0.32 + 0.65, 0.0)
		spire.rotation.y = PI * 0.25
		add_child(spire)
		_stones.append([cone, spire])
		for k in (0 if bare else 4):
			for face: float in [-1.0, 1.0]:
				var rune := Label3D.new()
				rune.text = RUNES[(k * 3 + (0 if side < 0.0 else 7) + (0 if face > 0.0 else 2)) % RUNES.size()]
				rune.font_size = 72
				rune.pixel_size = 0.005
				rune.outline_size = 0
				rune.modulate = tint.lightened(0.35)
				rune.position = Vector3(x, base + 0.9 + float(k) * 0.62, face * (depth * 0.5 + 0.01))
				rune.rotation.y = 0.0 if face > 0.0 else PI
				rune.shaded = false
				add_child(rune)
				_runes.append(rune)

	var tall := apex + 0.05
	var veil_mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(span, tall)
	veil_mesh.mesh = quad
	var veil := ShaderMaterial.new()
	var veil_shader := _shared(VEIL_SHADER)
	veil.shader = veil_shader
	veil.set_shader_parameter("rim", tint)
	veil.set_shader_parameter("span", span)
	veil.set_shader_parameter("spring", spring + 0.32)
	veil.set_shader_parameter("tall", tall)
	if view != null:
		veil.set_shader_parameter("view_tex", view)
		veil.set_shader_parameter("has_view", 1.0)
	veil_mesh.material_override = veil
	veil_mesh.position = Vector3(0.0, base + tall * 0.5, 0.0)
	veil_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(veil_mesh)
	# The shimmer, a hand's breadth before the whirl.
	var haze := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(span + 2.6, tall + 2.0)
	haze.mesh = hq
	var haze_mat := ShaderMaterial.new()
	var haze_shader := _shared(HAZE_SHADER)
	haze_mat.shader = haze_shader
	haze.material_override = haze_mat
	haze.position = Vector3(0.0, base + tall * 0.5, 0.12)
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(haze)

	add_child(_motes(Vector3(0.0, base + tall * 0.5, 0.0), 64, 2.8, -1.7))
	_lights.append(_light(Vector3(0.0, base + tall * 0.45, 1.1), 9.0))
	# A brazier of violet fire either side.
	for side: float in ([] if bare else [-1.0, 1.0]):
		var x := side * (half + 2.3)
		_box(stone, Vector3(0.55, 1.1, 0.55), Vector3(x, 0.55, 0.6))
		var bowl := Node3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.42
		bm.bottom_radius = 0.18
		bm.height = 0.3
		bm.radial_segments = 8
		bowl.position = Vector3(x, 1.25, 0.6)
		add_child(bowl)
		_stones.append([bm, bowl])
		add_child(_fire(Vector3(x, 1.38, 0.6)))
		_lights.append(_light(Vector3(x, 1.9, 0.6), 5.0))
	# Shards turning round it.
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.06, 0.04, 0.09)
	shard_mat.emission_enabled = true
	shard_mat.emission = tint
	shard_mat.emission_energy_multiplier = 1.6
	shard_mat.metallic = 0.6
	shard_mat.roughness = 0.25
	for i in 6:
		var shard := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.62
		sm.radial_segments = 4
		sm.rings = 2
		shard.mesh = sm
		shard.material_override = shard_mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shard)
		_shards.append(shard)
	_merge_stones(stone)


## All its stones drawn as one mesh (each its own shadow and light passes
## before: ~30 a gate, the village's five gates 2000 draw calls). Each keeps
## its own collision where it stands; the stone's look is laid by world
## position, so nothing shows the join.
func _merge_stones(stone: Material) -> void:
	if _stones.is_empty():
		return
	if bare:
		_stones.clear()
		return
	if not merge_stones:
		for part: Array in _stones:
			var one := MeshInstance3D.new()
			one.mesh = part[0] as Mesh
			one.material_override = stone
			(part[1] as Node3D).add_child(one)
		_stones.clear()
		return
	var st := SurfaceTool.new()
	for part: Array in _stones:
		st.append_from(part[0] as Mesh, 0, (part[1] as Node3D).transform)
	var whole := MeshInstance3D.new()
	whole.name = "Stones"
	whole.mesh = st.commit()
	whole.material_override = stone
	add_child(whole)
	_stones.clear()


func _light(at: Vector3, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = tint.lightened(0.15)
	light.light_energy = 2.4
	light.omni_range = reach
	light.position = at
	# no shadow, whatever the graphics setting: three lamps a gate, each
	# redrawing all in its reach six times over, were 4-5 ms of the
	# village's frame (its five gates: 15 lamps, ~2000 draws)
	light.shadow_enabled = false
	light.set_meta(&"designed_shadow", false)
	add_child(light)
	return light


func _dot_mesh(size: float) -> QuadMesh:
	var dot := QuadMesh.new()
	dot.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dot.material = mat
	return dot


## Motes drifting in from round about and swallowed.
func _motes(at: Vector3, amount: int, radius: float, pull: float) -> GPUParticles3D:
	var motes := GPUParticles3D.new()
	motes.amount = amount
	motes.lifetime = 2.6
	motes.position = at
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = radius
	pm.radial_accel_min = pull
	pm.radial_accel_max = pull * 0.55
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(tint, 0.0))
	fade.add_point(0.3, Color(tint.lightened(0.35), 0.95))
	fade.set_color(fade.get_point_count() - 1, Color(tint, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	motes.process_material = pm
	motes.draw_pass_1 = _dot_mesh(0.07)
	motes.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	return motes


## Violet fire.
func _fire(at: Vector3) -> GPUParticles3D:
	var fire := GPUParticles3D.new()
	fire.amount = 44
	fire.lifetime = 0.8
	fire.position = at
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0.0, 0.5, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(tint.lightened(0.25), 0.9))
	fade.add_point(0.4, Color(tint, 0.6))
	fade.set_color(fade.get_point_count() - 1, Color(tint.darkened(0.4), 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	fire.process_material = pm
	fire.draw_pass_1 = _dot_mesh(0.14)
	return fire


## A block of its stone `size` at `at`: where it stands (turned as the
## caller turns it) and its collision now, its look with the rest at the end.
func _box(_mat: Material, size: Vector3, at: Vector3) -> Node3D:
	var mesh := Node3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.position = at
	add_child(mesh)
	_stones.append([box, mesh])
	if bare:
		return mesh
	# Solid, so the hero walks round the posts rather than through them.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	mesh.add_child(body)
	return mesh
