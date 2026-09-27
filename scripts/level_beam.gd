class_name LevelBeam
extends Node3D

## A new level: the hero is taken up into a beam of light and set down again
## stronger — the way a ship's beam lifts someone off the ground.
##
## 1. **The beam opens** (0 – 0.8 s): high overhead a light opens, and a cone of
##    pale light spreads down from it to the ground round him, wide at the
##    foot, rings of light running up it.
## 2. **He is lifted** (0.8 – 2.6 s): his body rises off the ground, slowly, to
##    most of a metre, and hangs there turning a little; motes of light are
##    drawn up from the ground round him and gather into the beam; a pale glow
##    holds him; a deep choir-like chord swells under a rising rush of air.
## 3. **He is set down** (2.6 – 2.95 s): back on his feet with a deep, soft
##    boom that rolls away; the glow round him goes out. The HUD's "LEVEL UP"
##    comes up here.
## 4. **The beam closes** (to 3.7 s), drawn up and narrowed away into the sky.
##
## Nothing is drawn on the ground. Everything is made here in code — the cone's
## shader, the glows, the motes, the sound (made once, at load: [method warm]). Only his body (`Visuals`) is lifted,
## never his collider, so nothing about where he stands changes. Hung under the
## hero ([method on]); every peer makes its own ([Leveling] calls it on each).

const LIFE := 3.7
const OPEN := 0.8
const RISE_END := 2.3
const DROP_AT := 2.6
const LAND_AT := 2.95
## How high the light that opens overhead is, and the beam under it.
const HEIGHT := 14.0
const LIFT := 0.85

const CONE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
uniform float reach = 0.0;   // 0: nothing, 1: down to the ground
uniform float height = 14.0;
uniform float rings = 1.0;

varying float along;

void vertex() {
	along = clamp((VERTEX.y + height * 0.5) / height, 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	// A haze through it and brighter at its edges, like light in dust.
	float rim = pow(1.0 - facing, 2.0);
	float body = 0.22 + rim * 0.9;
	// Rings running up it.
	float band = pow(0.5 + 0.5 * sin(along * height * 1.6 - TIME * 7.0), 14.0) * rings;
	// Soft where it meets the ground, fading into the light overhead.
	float foot = smoothstep(0.0, 0.06, along);
	float top = 1.0 - smoothstep(0.75, 1.0, along) * 0.6;
	float front = 1.0 - reach;
	float shown = smoothstep(front - 0.02, front + 0.02, along);
	float edge = exp(-pow((along - front) / 0.02, 2.0)) * (1.0 - reach) * 2.0;
	ALBEDO = tint.rgb;
	ALPHA = clamp(((body + band * 0.8) * foot * top * shown + edge) * strength, 0.0, 1.0);
}
"""

## A glow turned to the camera.
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
	float g = pow(max(1.0 - d, 0.0), 2.5);
	float a = atan(p.y, p.x);
	float r = pow(max(0.0, sin(a * 8.0 + TIME * 1.5)), 12.0) * max(1.0 - d, 0.0) * rays;
	ALBEDO = tint.rgb;
	ALPHA = clamp((g + r) * strength, 0.0, 1.0);
}
"""

static var _sound_made: AudioStreamWAV

var _age: float = 0.0
var _tint: Color
var _cone: ShaderMaterial
var _cone_node: MeshInstance3D
var _opening: ShaderMaterial
var _hold: ShaderMaterial
var _hold_node: MeshInstance3D
var _light: OmniLight3D
var _drawn: GPUParticles3D
var _body: Node3D
var _body_y: float = 0.0
var _body_turn: float = 0.0


## Takes `hero` up into the light. Returns it (for a test to watch).
static func on(hero: Node3D, tint: Color = Color(0.72, 0.9, 1.0)) -> LevelBeam:
	if hero == null or not hero.is_inside_tree():
		return null
	var old := hero.get_node_or_null(^"LevelBeam") as LevelBeam
	if old != null:
		old.name = "LevelBeamOld"
		old._put_down()
		old.queue_free()
	var beam := LevelBeam.new()
	beam.name = "LevelBeam"
	hero.add_child(beam)
	beam._build(tint)
	return beam


func _build(tint: Color) -> void:
	_tint = tint
	top_level = true
	var hero := get_parent() as Node3D
	global_position = hero.global_position
	_body = hero.get_node_or_null(^"Visuals") as Node3D
	if _body != null:
		_body_y = _body.position.y
		_body_turn = _body.rotation.y

	var shader := Shader.new()
	shader.code = CONE_SHADER
	_cone = ShaderMaterial.new()
	_cone.shader = shader
	_cone.set_shader_parameter(&"tint", tint)
	_cone.set_shader_parameter(&"height", HEIGHT)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 1.6
	mesh.height = HEIGHT
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 48
	mesh.rings = 1
	_cone_node = MeshInstance3D.new()
	_cone_node.mesh = mesh
	_cone_node.material_override = _cone
	_cone_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone_node.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(_cone_node)

	_opening = _glow(tint.lerp(Color(1, 1, 1), 0.5), 0.6)
	var opening := _glow_node(_opening, 5.0)
	opening.position = Vector3(0.0, HEIGHT, 0.0)
	_hold = _glow(tint.lerp(Color(1, 1, 1), 0.3), 0.0)
	_hold_node = _glow_node(_hold, 3.2)

	_light = OmniLight3D.new()
	_light.light_color = tint
	_light.omni_range = 8.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 2.0, 0.0)
	add_child(_light)

	# Drawn up off the ground into the beam, closing in as they rise.
	_drawn = _particles(80, 1.8, false, tint.lerp(Color(1, 1, 1), 0.6), 0.07)
	var up := _drawn.process_material as ParticleProcessMaterial
	up.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	up.emission_ring_axis = Vector3.UP
	up.emission_ring_radius = 1.5
	up.emission_ring_inner_radius = 0.5
	up.emission_ring_height = 0.1
	up.direction = Vector3.UP
	up.spread = 5.0
	up.initial_velocity_min = 1.0
	up.initial_velocity_max = 2.4
	up.gravity = Vector3(0.0, 1.8, 0.0)
	up.radial_accel_min = -1.4
	up.radial_accel_max = -0.8
	up.tangential_accel_min = 0.6
	up.tangential_accel_max = 1.4

	_sound()
	_apply(0.0)


func _glow(colour: Color, rays: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = GLOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"tint", colour)
	m.set_shader_parameter(&"rays", rays)
	m.set_shader_parameter(&"strength", 0.0)
	return m


func _glow_node(material: ShaderMaterial, size: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 4.0
	add_child(node)
	return node


## Soft round sparks, additive, facing the camera.
func _particles(amount: int, life: float, one_shot: bool, colour: Color, size: float) -> GPUParticles3D:
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
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = colour
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
	var hero := get_parent() as Node3D
	if hero != null:
		global_position = hero.global_position
	_apply(_age)
	if _age >= LIFE:
		_put_down()
		queue_free()


func _exit_tree() -> void:
	_put_down()


## His body back where it belongs.
func _put_down() -> void:
	if _body != null and is_instance_valid(_body):
		_body.position.y = _body_y
		_body.rotation.y = _body_turn


static func _smooth(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Everything at `age` seconds.
func _apply(age: float) -> void:
	# 1. The light opening overhead, the cone spreading down.
	var opened := _smooth(age / 0.45)
	var reach := _smooth((age - 0.25) / (OPEN - 0.25))
	var closing := _smooth((age - LAND_AT) / (LIFE - LAND_AT))
	_cone.set_shader_parameter(&"reach", reach * (1.0 - closing))
	var hum := 0.85 + 0.15 * sin(age * 11.0)
	_cone.set_shader_parameter(&"strength", 0.55 * opened * hum * (1.0 - closing * 0.6))
	_cone.set_shader_parameter(&"rings", 1.0 - closing)
	var narrow := lerpf(1.0, 0.15, closing)
	_cone_node.scale = Vector3(narrow * lerpf(0.4, 1.0, reach), 1.0, narrow * lerpf(0.4, 1.0, reach))
	_opening.set_shader_parameter(&"strength", 1.2 * opened * (1.0 - closing))

	# 2. Up he goes, turning a little, and hangs; 3. down, fast, at the end.
	var up := _smooth((age - OPEN) / (RISE_END - OPEN))
	var down := clampf((age - DROP_AT) / (LAND_AT - DROP_AT), 0.0, 1.0)
	down = down * down
	var height := LIFT * up * (1.0 - down) + 0.04 * sin(age * 3.0) * up * (1.0 - down)
	if _body != null and is_instance_valid(_body):
		_body.position.y = _body_y + height
		_body.rotation.y = _body_turn + 0.35 * sin(up * PI) * (1.0 - down)
	_hold_node.position = Vector3(0.0, 1.0 + height, 0.0)
	_hold.set_shader_parameter(&"strength", 0.7 * up * (1.0 - down))
	_drawn.emitting = age > OPEN * 0.6 and age < DROP_AT

	_light.light_energy = 1.8 * opened * (1.0 - closing)


## The sound: made once and kept, and made early — at load, not at the first
## level, where making it would be a stall.
static func warm() -> void:
	if _sound_made == null:
		_sound_made = _make_sound()


func _sound() -> void:
	warm()
	var player := AudioStreamPlayer3D.new()
	player.stream = _sound_made
	player.volume_db = -2.0
	player.unit_size = 9.0
	player.max_distance = 70.0
	player.position = Vector3(0.0, 1.5, 0.0)
	add_child(player)
	player.play()


## Deep and grave, not bright: a low chord of open fifths on D (as voices or
## an organ would hold it — each note a few soft harmonics, two slightly
## apart so it beats and breathes) swelling while he is lifted, a rush of air
## climbing under it, and as he is set down a low boom — a drop in pitch and a
## dark tail of noise rolling away.
static func _make_sound() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 4.4)
	var data := PackedByteArray()
	data.resize(count * 2)
	# One cycle of a soft, dark wave: six harmonics falling off fast.
	var size := 512
	var table := PackedFloat32Array()
	table.resize(size)
	for i in size:
		var x := TAU * float(i) / float(size)
		var v := 0.0
		for n in range(1, 7):
			v += sin(x * n) / pow(float(n), 1.6)
		table[i] = v * 0.55
	var notes := PackedFloat32Array([73.42, 110.0, 146.83, 220.0, 293.66])
	var loud := PackedFloat32Array([1.0, 0.8, 0.6, 0.35, 0.18])
	var phases := PackedFloat32Array()
	phases.resize(notes.size() * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var air := 0.0
	var dark := 0.0
	var boom_phase := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var v := 0.0
		# The chord: in over the opening and the lift, held, gone as he lands.
		var chord := smoothstep(0.1, 2.2, t) * (1.0 - smoothstep(LAND_AT - 0.1, LAND_AT + 1.2, t))
		if chord > 0.0:
			var sum := 0.0
			for k in notes.size():
				for d in 2:
					var f := notes[k] * (1.0 + (0.004 if d == 1 else -0.004)) * (1.0 + 0.002 * sin(TAU * 0.3 * t + k))
					var p := phases[k * 2 + d] + f / float(rate)
					p -= floorf(p)
					phases[k * 2 + d] = p
					sum += table[int(p * size) % size] * loud[k]
			v += sum * chord * 0.075
		# The rush of air, climbing as he rises.
		var rising := smoothstep(OPEN * 0.5, RISE_END, t) * (1.0 - smoothstep(DROP_AT, LAND_AT, t))
		air = lerpf(air, rng.randf_range(-1.0, 1.0), 0.02 + 0.12 * rising)
		v += air * rising * 0.28
		# The boom: a low note falling, and a dark tail of noise.
		var dt := t - LAND_AT
		if dt >= 0.0:
			var fb := lerpf(95.0, 42.0, minf(dt / 0.35, 1.0))
			boom_phase += TAU * fb / float(rate)
			v += sin(boom_phase) * exp(-dt * 3.2) * 0.55
			dark = lerpf(dark, rng.randf_range(-1.0, 1.0), 0.05)
			v += dark * exp(-dt * 2.2) * 0.35 * minf(dt / 0.02, 1.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
