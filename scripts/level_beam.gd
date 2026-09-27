class_name LevelBeam
extends Node3D

## A new level, seen and heard: light is sent down for the hero.
##
## 1. **The star** (0 – 0.4 s): a point of white light kindles high overhead and
##    drops towards him, growing, its four rays flaring.
## 2. **The beam** (0.35 – 0.7 s): a thread of light shoots down from the sky to
##    his feet and opens into a broad column — the way a ship's beam takes
##    someone up.
## 3. **It lands** (0.7 s): a flash; a burst of sparks is thrown out low; a
##    halo blooms round him.
## 4. **It stands** (to 3 s): wisps of light stream down the column; two ribbons
##    of light wind up round him; motes rise spiralling and glitter falls from
##    above. Nothing is drawn on the ground.
## 5. **It is taken up** (3 – 4 s): the column's foot lifts off the ground and
##    rises back into the sky, and the rest fades after it.
##
## A chime goes with it — a rising rush and five bells climbing a major chord —
## made here in code, as is everything: no textures, no sound files. Hung under
## the hero ([method on]) and following him upright; every peer makes its own
## ([Leveling] calls it on each), nothing replicated.

const LIFE := 4.0
const STAR_TIME := 0.4
const SHOOT_AT := 0.35
const LAND_AT := 0.7
const LIFT_AT := 3.0
const HEIGHT := 70.0

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
uniform float reach = 0.0;   // 0: nothing, 1: down to the ground
uniform float lift = 0.0;    // 0: standing on the ground, 1: gone up
uniform float height = 70.0;
uniform float sharpness = 1.6;
uniform float wisp = 0.5;

varying float along;
varying float around;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	along = clamp((VERTEX.y + height * 0.5) / height, 0.0, 1.0);
	around = atan(VERTEX.z, VERTEX.x);
}

void fragment() {
	float core = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), sharpness);
	float front = 1.0 - reach;
	float shown = smoothstep(front - 0.003, front + 0.003, along) * smoothstep(lift - 0.01, lift + 0.01, along);
	float high = 1.0 - smoothstep(0.1, 0.95, along);
	float head = exp(-pow((along - front) / 0.008, 2.0)) * (1.0 - reach) * 4.0;
	float tail = exp(-pow((along - lift) / 0.01, 2.0)) * step(0.001, lift) * 3.0;
	// Wisps streaming down, wound a little round the column.
	vec2 q = vec2(around * 1.6 + along * 6.0, along * height * 0.35 + TIME * 7.0);
	float w = noise(q) * 0.6 + noise(q * 2.3 + vec2(3.1, TIME * 4.0)) * 0.4;
	float stream = mix(1.0, 0.45 + 1.1 * w, wisp);
	float foot = 1.0;
	ALBEDO = tint.rgb;
	ALPHA = clamp(core * shown * (high * stream * foot + head + tail) * strength, 0.0, 1.0);
}
"""

## A glow facing the camera: the star (with rays) and the halo (without).
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float strength = 1.0;
uniform float rays = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	float g = pow(max(1.0 - d, 0.0), 3.0) + exp(-d * d * 60.0) * 1.5;
	float r = exp(-abs(p.x) * 40.0) * exp(-abs(p.y) * 2.5) + exp(-abs(p.y) * 40.0) * exp(-abs(p.x) * 2.5);
	float r2 = exp(-abs(p.x + p.y) * 30.0) * exp(-abs(p.x - p.y) * 5.0) + exp(-abs(p.x - p.y) * 30.0) * exp(-abs(p.x + p.y) * 5.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp((g + (r + r2 * 0.5) * rays) * strength, 0.0, 1.0);
}
"""

## A ribbon of light wound up round him; a streak runs up it.
const RIBBON_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform float strength = 1.0;
uniform float grown = 1.0;   // how far up it has wound, 0..1

void fragment() {
	float t = UV.x;
	float across = 1.0 - pow(abs(UV.y * 2.0 - 1.0), 1.5);
	float streak = pow(fract(t * 2.0 - TIME * 0.9), 3.0) * 1.6 + 0.25;
	float ends = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(grown - 0.12, grown, t));
	ALBEDO = tint.rgb;
	ALPHA = clamp(across * streak * ends * strength, 0.0, 1.0);
}
"""

static var _chime: AudioStreamWAV

var _age: float = 0.0
var _tint: Color
var _outer: ShaderMaterial
var _inner: ShaderMaterial
var _star: ShaderMaterial
var _halo: ShaderMaterial
var _ribbon_mat: ShaderMaterial
var _outer_mesh: MeshInstance3D
var _inner_mesh: MeshInstance3D
var _star_node: MeshInstance3D
var _halo_node: MeshInstance3D
var _ribbons: Node3D
var _light: OmniLight3D
var _motes: GPUParticles3D
var _glitter: GPUParticles3D
var _burst: GPUParticles3D
var _burst_done: bool = false


## Puts the light on `hero`. Returns it (for a test to watch).
static func on(hero: Node3D, tint: Color = Color(0.82, 0.9, 1.0)) -> LevelBeam:
	if hero == null or not hero.is_inside_tree():
		return null
	var old := hero.get_node_or_null(^"LevelBeam")
	if old != null:
		old.name = "LevelBeamOld"
		old.queue_free()
	var beam := LevelBeam.new()
	beam.name = "LevelBeam"
	hero.add_child(beam)
	beam._build(tint)
	return beam


func _build(tint: Color) -> void:
	_tint = tint
	top_level = true
	global_position = (get_parent() as Node3D).global_position
	_outer = _material(BEAM_SHADER, {&"tint": tint.lerp(Color(0.55, 0.75, 1.0), 0.4), &"height": HEIGHT, &"sharpness": 1.1, &"wisp": 0.9})
	_inner = _material(BEAM_SHADER, {&"tint": Color(1, 1, 1), &"height": HEIGHT, &"sharpness": 4.0, &"wisp": 0.5})
	_outer_mesh = _column(1.3, 1.1, _outer)
	_inner_mesh = _column(0.3, 0.26, _inner)

	_star = _material(GLOW_SHADER, {&"tint": Color(1.0, 0.98, 0.92), &"rays": 1.0})
	_star_node = _billboard(_star, 3.0)
	_halo = _material(GLOW_SHADER, {&"tint": tint.lerp(Color(1.0, 0.95, 0.8), 0.4), &"rays": 0.0})
	_halo_node = _billboard(_halo, 4.0)
	_halo_node.position = Vector3(0.0, 1.1, 0.0)

	_ribbon_mat = _material(RIBBON_SHADER, {&"tint": Color(1.0, 0.93, 0.72)})
	_ribbons = Node3D.new()
	add_child(_ribbons)
	for k in 2:
		var ribbon := MeshInstance3D.new()
		ribbon.mesh = _helix(0.85, 3.6, 2.25, 0.16, PI * k)
		ribbon.material_override = _ribbon_mat
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ribbons.add_child(ribbon)

	_light = OmniLight3D.new()
	_light.light_color = tint.lerp(Color(1, 1, 1), 0.5)
	_light.omni_range = 10.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 2.4, 0.0)
	add_child(_light)

	_motes = _particles(110, 1.8, false)
	var rise := _motes.process_material as ParticleProcessMaterial
	rise.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	rise.emission_ring_axis = Vector3.UP
	rise.emission_ring_radius = 1.0
	rise.emission_ring_inner_radius = 0.3
	rise.emission_ring_height = 0.2
	rise.direction = Vector3.UP
	rise.spread = 10.0
	rise.initial_velocity_min = 1.2
	rise.initial_velocity_max = 3.2
	rise.gravity = Vector3(0.0, 1.2, 0.0)
	rise.tangential_accel_min = 2.0
	rise.tangential_accel_max = 4.0
	rise.radial_accel_min = -0.8
	rise.radial_accel_max = -0.3

	_glitter = _particles(70, 1.5, false)
	var fall := _glitter.process_material as ParticleProcessMaterial
	fall.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	fall.emission_ring_axis = Vector3.UP
	fall.emission_ring_radius = 0.6
	fall.emission_ring_inner_radius = 0.0
	fall.emission_ring_height = 2.0
	fall.emission_shape_offset = Vector3(0.0, 9.0, 0.0)
	fall.direction = Vector3.DOWN
	fall.spread = 4.0
	fall.initial_velocity_min = 5.0
	fall.initial_velocity_max = 8.0
	fall.gravity = Vector3.ZERO
	fall.scale_min = 0.4
	fall.scale_max = 0.8

	_burst = _particles(60, 1.1, true)
	var out := _burst.process_material as ParticleProcessMaterial
	out.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	out.emission_sphere_radius = 0.4
	out.emission_shape_offset = Vector3(0.0, 0.2, 0.0)
	out.direction = Vector3(1.0, 0.15, 0.0)
	out.spread = 180.0
	out.flatness = 0.85
	out.initial_velocity_min = 4.0
	out.initial_velocity_max = 9.0
	out.damping_min = 5.0
	out.damping_max = 8.0
	out.gravity = Vector3(0.0, 0.6, 0.0)
	_burst.explosiveness = 1.0

	_sound()
	_apply(0.0)


func _material(code: String, params: Dictionary) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var m := ShaderMaterial.new()
	m.shader = shader
	for key: StringName in params:
		m.set_shader_parameter(key, params[key])
	return m


func _column(top: float, bottom: float, material: ShaderMaterial) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = HEIGHT
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 40
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(node)
	return node


func _billboard(material: ShaderMaterial, size: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 4.0
	add_child(node)
	return node


## A strip wound round the up axis: `turns` times over `rise` metres at
## `radius`, `width` tall; UV.x runs along it, UV.y across.
func _helix(radius: float, rise: float, turns: float, width: float, phase: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var steps := 140
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a := phase + t * turns * TAU
		# Narrowing a little as it climbs.
		var r := radius * lerpf(1.0, 0.7, t)
		var c := Vector3(cos(a) * r, 0.15 + t * rise, sin(a) * r)
		verts.append(c + Vector3(0.0, -width * 0.5, 0.0))
		verts.append(c + Vector3(0.0, width * 0.5, 0.0))
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh


## Soft round sparks, additive, facing the camera.
func _particles(amount: int, life: float, one_shot: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 16, 12))
	var pm := ParticleProcessMaterial.new()
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 0.95, 0.8, 0.8),
			Color(1, 0.9, 0.7, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = _tint.lerp(Color(1, 1, 1), 0.7)
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var soft := Gradient.new()
	soft.offsets = PackedFloat32Array([0.0, 0.12, 0.45, 1.0])
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
	dot.gradient = soft
	m.albedo_texture = dot
	quad.material = m
	p.draw_pass_1 = quad
	add_child(p)
	return p


func _process(delta: float) -> void:
	_age += delta
	var parent := get_parent() as Node3D
	if parent != null:
		global_position = parent.global_position
	_apply(_age)
	if _age >= LIFE:
		queue_free()


static func _ease_out(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - c, 3.0)


## Everything at `age` seconds.
func _apply(age: float) -> void:
	# 1. The star, falling from high up and growing, gone into the beam.
	var fall := _ease_out(age / STAR_TIME)
	_star_node.position = Vector3(0.0, lerpf(15.0, 4.5, fall), 0.0)
	_star_node.scale = Vector3.ONE * lerpf(0.6, 1.6, fall)
	var star_out := 1.0 - clampf((age - SHOOT_AT) / 0.35, 0.0, 1.0)
	_star.set_shader_parameter(&"strength", clampf(age / 0.08, 0.0, 1.0) * star_out * 1.4)
	_star.set_shader_parameter(&"rays", 1.0 + 0.6 * sin(age * 30.0))

	# 2. The beam: a thread shot down, then opened.
	var reach := _ease_out((age - SHOOT_AT) / (LAND_AT - SHOOT_AT))
	var open := _ease_out((age - LAND_AT + 0.05) / 0.35)
	var lift := clampf((age - LIFT_AT) / (LIFE - LIFT_AT - 0.1), 0.0, 1.0)
	lift = lift * lift
	var flash := exp(-pow((age - LAND_AT - 0.04) / 0.1, 2.0))
	var standing := 1.0 - clampf((age - LIFT_AT) / (LIFE - LIFT_AT), 0.0, 1.0)
	var breathe := 0.9 + 0.1 * sin(age * 7.0)
	for m: ShaderMaterial in [_outer, _inner]:
		m.set_shader_parameter(&"reach", reach)
		m.set_shader_parameter(&"lift", lift)
	var thread := lerpf(0.12, 1.0, open)
	_outer_mesh.scale = Vector3(thread * (1.0 + 0.3 * flash), 1.0, thread * (1.0 + 0.3 * flash))
	_inner_mesh.scale = Vector3(lerpf(0.4, 1.0, open), 1.0, lerpf(0.4, 1.0, open))
	_outer.set_shader_parameter(&"strength", (0.06 + 0.2 * open + 0.6 * flash) * breathe)
	_inner.set_shader_parameter(&"strength", (0.75 - 0.2 * open + 1.2 * flash) * breathe)

	# 3. It lands: the sparks, the halo, the flash.
	if age >= LAND_AT and not _burst_done:
		_burst_done = true
		_burst.restart()
		_burst.emitting = true
	var landed := clampf((age - LAND_AT) / 0.2, 0.0, 1.0)
	_halo.set_shader_parameter(&"strength", (0.45 * landed * standing + 1.2 * flash) * breathe)
	_halo_node.scale = Vector3.ONE * (1.0 + 0.4 * flash)
	_light.light_energy = (3.0 * landed * standing + 9.0 * flash)

	# 4. The ribbons winding up round him, and the motes.
	var grow := _ease_out((age - LAND_AT - 0.1) / 0.9)
	_ribbon_mat.set_shader_parameter(&"grown", grow)
	_ribbon_mat.set_shader_parameter(&"strength", grow * standing * 1.1)
	_ribbons.rotation.y = age * 2.2
	_motes.emitting = age > LAND_AT and age < LIFT_AT + 0.3
	_glitter.emitting = age > LAND_AT - 0.1 and age < LIFT_AT


## The chime, made once and kept: a rising rush of air under five bells
## climbing a major chord, and a soft high shimmer over them.
func _sound() -> void:
	if _chime == null:
		_chime = _make_chime()
	var player := AudioStreamPlayer3D.new()
	player.stream = _chime
	player.volume_db = -3.0
	player.unit_size = 8.0
	player.max_distance = 70.0
	player.position = Vector3(0.0, 1.5, 0.0)
	add_child(player)
	player.play()


static func _make_chime() -> AudioStreamWAV:
	var rate := 22050
	var length := 3.4
	var count := int(rate * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var bells := [[523.25, 0.55], [659.26, 0.67], [783.99, 0.79], [1046.5, 0.93], [1318.5, 1.1]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	for i in count:
		var t := float(i) / float(rate)
		# The rush: noise, softened, swelling as the beam comes down.
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.08)
		var rush := low * 0.5 * smoothstep(0.0, 0.5, t) * exp(-maxf(t - 0.6, 0.0) * 3.0)
		var v := rush
		for bell: Array in bells:
			var f := float(bell[0])
			var dt := t - float(bell[1])
			if dt < 0.0:
				continue
			var env := minf(dt / 0.004, 1.0) * exp(-dt * 2.2)
			v += (sin(TAU * f * dt) + 0.45 * sin(TAU * f * 2.0 * dt) + 0.2 * sin(TAU * f * 3.01 * dt)) * env * 0.13
		# The shimmer: a high chord, trembling, under it all.
		var pad := smoothstep(0.5, 1.2, t) * (1.0 - smoothstep(2.4, 3.3, t))
		var trem := 0.6 + 0.4 * sin(TAU * 6.0 * t)
		v += (sin(TAU * 1567.98 * t) + sin(TAU * 2093.0 * t) * 0.6 + sin(TAU * 2637.0 * t) * 0.4) * pad * trem * 0.025
		var s := int(clampf(v, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
