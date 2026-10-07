class_name MageWind
extends Node3D

## The air that holds the mage up while she floats (the jump held): not light
## but the air itself, and the wind of it seen in pale streaks (the user's word, 2026-10-07: the spinning discs and
## wisps under her feet were not liked). Under her soles a column of air bent
## as heat bends it over a road, the world behind it wavering, thickest at her
## feet and gone a metre and a half down; and near the ground (within
## `REACH`) the push of it reaching the ground: rings of bent air running out
## over it from under her, stronger the lower she is, and a little dust
## thrown off along it when she is low.
##
## How much of it there is follows `amount`, which the rig sets every frame:
## none on the ground or in a plain jump, all of it while she floats.

var amount: float = 0.0

## How far down the push still reaches the ground.
const REACH := 3.2
## A ring every this long while it does.
const RING_EVERY := 0.42
const RING_LIFE := 0.95
## How wide a ring gets (radius, m), low over the ground; higher, a little wider.
const RING_WIDE := 2.2
## Dust thrown off below this height.
const DUST_UNDER := 1.6
const COLUMN := 1.6

const HAZE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float bend = 0.018;
uniform float depth = 1.6;
varying float h;
void vertex() {
	h = clamp(-VERTEX.y / depth, 0.0, 1.0);
}
float wave(vec2 p) {
	return sin(p.x) * sin(p.y * 1.3 + 1.7);
}
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float body = smoothstep(0.05, 0.65, facing);
	float along = smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.3, 1.0, h));
	float k = body * along * amount;
	vec2 p = vec2(UV.x * 31.4159, h * 14.0 - TIME * 7.5);
	vec2 q = vec2(UV.x * 37.6991 + 2.0, h * 18.0 - TIME * 10.0);
	vec2 off = vec2(wave(p) + 0.6 * wave(q), wave(p.yx * 1.3 + 4.0) * 0.7) * bend * k;
	vec3 behind = textureLod(screen_tex, SCREEN_UV + off, 0.0).rgb;
	// where the bent air turns away, a thin bright edge, as glass shows one
	float edge = (1.0 - smoothstep(0.15, 0.55, facing)) * smoothstep(0.02, 0.15, facing);
	float glint = 0.5 + 0.5 * sin(UV.x * 37.6991 + h * 10.0 - TIME * 8.0);
	ALBEDO = behind * (1.0 + 0.07 * k) + vec3(0.9, 0.96, 1.0) * edge * glint * 0.08 * along * amount;
	ALPHA = clamp(k * 2.2 + edge * along * amount * 0.6, 0.0, 1.0);
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float prog = 0.0;
uniform float strength = 0.0;
uniform float bend = 0.026;
void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float at = prog * 0.95;
	float width = 0.07 + 0.12 * prog;
	float ring = 1.0 - smoothstep(0.0, width, abs(r - at));
	// a second, fainter ring trailing inside it
	float inner = (1.0 - smoothstep(0.0, width * 0.8, abs(r - at * 0.62))) * 0.45;
	float fade = (1.0 - prog) * (1.0 - smoothstep(0.85, 1.0, r)) * smoothstep(0.0, 0.08, prog);
	float k = (ring + inner) * fade * strength;
	vec2 dir = r > 0.0001 ? d / (r * 0.5) : vec2(0.0);
	// the ground's UV runs across the screen near enough the way the ring does
	vec2 off = dir * bend * k * vec2(1.0, -0.6);
	vec3 behind = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb;
	ALBEDO = behind * (1.0 + 0.08 * k) + vec3(0.92, 0.96, 1.0) * ring * fade * strength * 0.1;
	ALPHA = clamp(k * 1.8, 0.0, 1.0);
}
"""

static var _haze_shader: Shader = null
static var _ring_shader: Shader = null

var _shown: float = 0.0
var _column: MeshInstance3D
var _haze: ShaderMaterial
var _rings: Array[MeshInstance3D] = []
var _ring_mats: Array[ShaderMaterial] = []
var _ring_age: Array[float] = []
var _next_ring: float = 0.0
var _probe: float = 0.0
var _ground := Vector3.INF
var _streaks: GPUParticles3D


func _ready() -> void:
	if _haze_shader == null:
		_haze_shader = Shader.new()
		_haze_shader.code = HAZE_SHADER
		_ring_shader = Shader.new()
		_ring_shader.code = RING_SHADER
	# the column of bent air: a cone from her soles down, open both ends
	var cone := CylinderMesh.new()
	cone.top_radius = 0.32
	cone.bottom_radius = 0.6
	cone.height = COLUMN
	cone.radial_segments = 24
	cone.rings = 6
	cone.cap_top = false
	cone.cap_bottom = false
	_column = MeshInstance3D.new()
	_column.mesh = cone
	_haze = ShaderMaterial.new()
	_haze.shader = _haze_shader
	_haze.set_shader_parameter(&"depth", COLUMN)
	_column.material_override = _haze
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the mesh's own middle is its middle: hung so its top is at her soles
	_column.position = Vector3(0.0, -COLUMN * 0.5 + 0.05, 0.0)
	_column.visible = false
	add_child(_column)
	_streaks = _make_streaks()
	add_child(_streaks)
	for i in 3:
		var quad := PlaneMesh.new()
		quad.size = Vector2(2.0, 2.0)
		var ring := MeshInstance3D.new()
		ring.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = _ring_shader
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.top_level = true
		ring.visible = false
		add_child(ring)
		_rings.append(ring)
		_ring_mats.append(mat)
		_ring_age.append(INF)


func _process(delta: float) -> void:
	_shown = move_toward(_shown, minf(amount, 1.0), delta / 0.3)
	var on := _shown > 0.01
	_column.visible = on
	if on:
		# keep the column upright under her whatever the figure leans
		_column.global_basis = Basis.IDENTITY
		_haze.set_shader_parameter(&"amount", _shown)
	_streaks.emitting = _shown > 0.3
	_streaks.amount_ratio = clampf(_shown, 0.0, 1.0)
	_tick_rings(delta)
	if not on:
		_ground = Vector3.INF
		return
	_probe -= delta
	if _probe <= 0.0:
		_probe = 0.08
		_ground = _find_ground()
	if not _ground.is_finite():
		return
	_next_ring -= delta
	if _next_ring <= 0.0 and _shown > 0.5:
		_next_ring = RING_EVERY
		_ring_out()


## The ground under her, if within `REACH`; INF if not.
func _find_ground() -> Vector3:
	if not is_inside_tree():
		return Vector3.INF
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.1
	var body := _body()
	var skip: Array[RID] = []
	var mask := 1
	if body != null:
		skip.append(body.get_rid())
		mask = body.collision_mask
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (REACH + 0.1), mask, skip)
	var hit := space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else Vector3.INF


func _body() -> CollisionObject3D:
	var n := get_parent()
	while n != null and not (n is CollisionObject3D):
		n = n.get_parent()
	return n as CollisionObject3D


## A ring of bent air sent out over the ground under her.
func _ring_out() -> void:
	var height := global_position.y - _ground.y
	var near := clampf(1.0 - height / REACH, 0.0, 1.0)
	for i in _rings.size():
		if _ring_age[i] < RING_LIFE:
			continue
		var ring := _rings[i]
		ring.global_position = _ground + Vector3.UP * 0.03
		ring.global_basis = Basis.IDENTITY
		var wide := RING_WIDE * lerpf(1.25, 1.0, near)
		ring.scale = Vector3(wide, 1.0, wide)
		ring.set_meta(&"strength", lerpf(0.25, 1.0, near) * _shown)
		_ring_age[i] = 0.0
		ring.visible = true
		break
	if height < DUST_UNDER:
		_dust(near)


## Dust (or what lies on the ground) pushed out from under her, low and pale.
func _dust(near: float) -> void:
	var into := get_tree().current_scene
	if into == null:
		return
	SkillFx.particles(into, _ground + Vector3.UP * 0.05, {"amount": int(lerpf(3.0, 9.0, near)), "life": 0.8,
			"one_shot": true, "explosiveness": 1.0, "speed": Vector2(0.8, 2.0) * lerpf(0.6, 1.0, near),
			"dir": Vector3.UP, "spread": 88.0, "gravity": Vector3(0, -0.6, 0), "damping": 2.5,
			"size": Vector2(0.18, 0.35), "box": Vector3(0.35, 0.02, 0.35), "add": false, "grow": 0.8,
			"colors": [Color(0.86, 0.84, 0.8, 0.0), Color(0.86, 0.84, 0.8, 0.22 * near), Color(0.86, 0.84, 0.8, 0.0)]})


func _tick_rings(delta: float) -> void:
	for i in _rings.size():
		if _ring_age[i] >= RING_LIFE:
			continue
		_ring_age[i] += delta
		var ring := _rings[i]
		if _ring_age[i] >= RING_LIFE:
			ring.visible = false
			continue
		var t := _ring_age[i] / RING_LIFE
		# out quick, then slowing
		_ring_mats[i].set_shader_parameter(&"prog", 1.0 - pow(1.0 - t, 2.2))
		_ring_mats[i].set_shader_parameter(&"strength", float(ring.get_meta(&"strength", 1.0)))


## The wind itself, seen: thin pale ribbons of air whirling round her legs
## and down and out from under her (each a trail, so it curves the way the air
## goes), not light: no glow, a pale line over the world.
func _make_streaks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.0
	p.local_coords = false
	p.trail_enabled = true
	p.trail_lifetime = 0.6
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3.UP * 0.55
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 0.7
	m.emission_ring_inner_radius = 0.45
	m.emission_ring_height = 0.5
	m.direction = Vector3.DOWN
	m.spread = 10.0
	m.initial_velocity_min = 0.15
	m.initial_velocity_max = 0.35
	m.gravity = Vector3(0, -0.5, 0)
	m.orbit_velocity_min = 1.2
	m.orbit_velocity_max = 1.6
	m.radial_velocity_min = 0.15
	m.radial_velocity_max = 0.4
	m.damping_min = 0.3
	m.damping_max = 0.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.2, Color(0.97, 0.99, 1.0, 0.55))
	ramp.add_point(0.65, Color(0.95, 0.98, 1.0, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.95, 0.98, 1.0, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	m.color_ramp = ramp_tex
	p.process_material = m
	var ribbon := RibbonTrailMesh.new()
	ribbon.shape = RibbonTrailMesh.SHAPE_CROSS
	ribbon.size = 0.03
	ribbon.sections = 12
	ribbon.section_length = 0.08
	var thin := Curve.new()
	thin.add_point(Vector2(0.0, 0.0))
	thin.add_point(Vector2(0.5, 1.0))
	thin.add_point(Vector2(1.0, 0.0))
	ribbon.curve = thin
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.use_particle_trails = true
	ribbon.material = mat
	p.draw_pass_1 = ribbon
	p.emitting = false
	return p
