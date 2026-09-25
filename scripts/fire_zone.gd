class_name FireZone
extends Node3D

## Where the Fire Arrow comes down: a ring of fire runs out from the point it
## struck, and the ground burns for `seconds`.
##
## Whatever stands in it catches — [Afflictions] "burn", kept up while it
## stays in the fire and for a little after it leaves — and the first time
## it catches it reacts ([method Brute.react] and kin). Every peer draws the
## same fire and sets the same creatures alight (the zone is made on each of
## them from the same numbers); only the host's burn costs health.
##
## Afterwards the ground is left scorched, glowing in cracks, and that fades.

const FIRE := Color(1.0, 0.45, 0.08)
const HOT := Color(1.0, 0.85, 0.45)
## How long a creature keeps burning once out of the fire.
const AFTERBURN := 1.5

var radius: float = 2.6
var seconds: float = 5.0
var dps: float = 12.0

var _shooter: Node3D
var _age: float = 0.0
var _tick: float = 0.0
var _caught: Dictionary = {}
var _running: bool = false

var _flames: GPUParticles3D
var _rim: GPUParticles3D
var _embers: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var _scorch: Decal

static var _glow_shader: Shader = null
static var _scorch_tex: Texture2D = null


func start(shooter: Node3D, zone_radius: float, burn_seconds: float, burn_dps: float) -> void:
	_shooter = shooter
	radius = zone_radius
	seconds = burn_seconds
	dps = burn_dps
	_running = true
	_build()


func _build() -> void:
	var into := get_parent()
	var at := global_position
	SkillFx.flash(into, at + Vector3.UP * 0.3, HOT, 1.4, 0.3, 4.0)
	SkillFx.ring(into, at + Vector3.UP * 0.1, Vector3.UP, FIRE, 0.2, radius + 0.4, 0.45, 0.06, 3.0)
	SkillFx.burst(into, at + Vector3.UP * 0.1, FIRE, 70, Vector2(2.0, 7.0), Vector3.UP, 50.0,
			Vector2(0.03, 0.07), Vector3(0, -5, 0), 0.9)
	var big := radius / 2.6
	_flames = SkillFx.particles(self, at, {
		"amount": int(90 * big), "life": 0.8, "speed": Vector2(0.4, 1.2), "spread": 10.0,
		"gravity": Vector3(0, 1.8, 0), "size": Vector2(0.45, 0.95), "ring": Vector2(0.0, radius * 0.95),
		"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false, "grow": 0.25,
		"colors": [Color(1.0, 0.62, 0.18, 0.0), Color(1.0, 0.5, 0.08, 0.95), Color(0.92, 0.2, 0.02, 0.85),
				Color(0.25, 0.03, 0.0, 0.0)],
	})
	_rim = SkillFx.particles(self, at, {
		"amount": int(70 * big), "life": 0.7, "speed": Vector2(0.5, 1.4), "spread": 8.0,
		"gravity": Vector3(0, 2.0, 0), "size": Vector2(0.55, 1.1), "ring": Vector2(radius * 0.8, radius),
		"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false, "grow": 0.25,
		"colors": [Color(1.0, 0.62, 0.18, 0.0), Color(1.0, 0.5, 0.08, 0.95), Color(0.92, 0.2, 0.02, 0.85),
				Color(0.25, 0.03, 0.0, 0.0)],
	})
	_embers = SkillFx.particles(self, at + Vector3.UP * 0.4, {
		"amount": int(60 * big), "life": 1.8, "speed": Vector2(0.8, 2.2), "spread": 25.0,
		"gravity": Vector3(0, 0.3, 0), "damping": 0.4, "size": Vector2(0.025, 0.055),
		"ring": Vector2(0.0, radius),
		"colors": [Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.35, 0.05, 1.0), Color(0.6, 0.1, 0.0, 0.0)],
	})
	_smoke = SkillFx.particles(self, at + Vector3.UP * 1.2, {
		"amount": int(16 * big), "life": 2.6, "speed": Vector2(0.4, 0.9), "spread": 20.0,
		"gravity": Vector3(0.1, 0.25, 0), "size": Vector2(0.9, 1.6), "ring": Vector2(0.0, radius * 0.8),
		"add": false, "grow": 0.35,
		"colors": [Color(0.14, 0.12, 0.1, 0.0), Color(0.14, 0.12, 0.1, 0.35), Color(0.3, 0.3, 0.3, 0.0)],
	})
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.15)
	_light.omni_range = radius * 3.5
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3.UP * 1.3
	# The ground: glowing where it burns, then a scorch that fades.
	_glow = MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2(radius * 2.1, radius * 2.1)
	_glow.mesh = disc
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW_CODE
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = _glow_shader
	_glow_mat.set_shader_parameter(&"heat", 0.0)
	_glow.material_override = _glow_mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_glow.position = Vector3.UP * 0.03
	_scorch = Decal.new()
	_scorch.size = Vector3(radius * 2.2, 1.5, radius * 2.2)
	_scorch.texture_albedo = _scorch_texture()
	_scorch.modulate = Color(1, 1, 1, 0.0)
	_scorch.cull_mask = 1
	add_child(_scorch)


func _process(delta: float) -> void:
	if not _running:
		return
	_age += delta
	var burning := _age < seconds
	var k := clampf(_age / 0.4, 0.0, 1.0) * clampf((seconds - _age) / 0.8, 0.0, 1.0)
	_light.light_energy = k * (4.0 + 0.9 * sin(_age * 13.0) + 0.6 * sin(_age * 7.1))
	_glow_mat.set_shader_parameter(&"heat", k)
	_scorch.modulate.a = clampf(_age / 0.6, 0.0, 1.0) * clampf((seconds + 7.0 - _age) / 3.0, 0.0, 1.0)
	if burning:
		_catch(delta)
	elif _flames.emitting:
		_flames.emitting = false
		_rim.emitting = false
		_embers.emitting = false
		_smoke.emitting = false
	if _age > seconds + 7.0:
		queue_free()


## Everything standing in the fire burns.
func _catch(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	var centre := global_position
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var who := node as Node3D
		if who == null or who.get(&"is_dead") == true or not who.has_method(&"take_dot"):
			continue
		var gap := who.global_position - centre
		if absf(gap.y) > 2.0:
			continue
		gap.y = 0.0
		var br: Variant = who.get(&"body_radius")
		var reach := radius + (float(br) if br != null else 0.4) * 0.5
		if gap.length() > reach:
			continue
		var marks := Afflictions.of(who)
		if marks != null:
			marks.apply(&"burn", AFTERBURN, _shooter, dps)
		if not _caught.has(who):
			_caught[who] = true
			if _decides() and who.has_method(&"react"):
				who.call(&"react", &"burn", _shooter, Vector3.ZERO)


func _decides() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))


## A round dark scorch with ragged edges, made once.
static func _scorch_texture() -> Texture2D:
	if _scorch_tex == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.05
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var d := Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
				var ragged := d + n.get_noise_2d(x, y) * 0.25
				var a := clampf((1.0 - ragged) * 3.0, 0.0, 1.0) * 0.85
				img.set_pixel(x, y, Color(0.04, 0.03, 0.025, a))
		_scorch_tex = ImageTexture.create_from_image(img)
	return _scorch_tex


const GLOW_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float heat = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float edge = smoothstep(1.0, 0.8, d);
	float n = sin(p.x * 13.0 + TIME * 1.3) * sin(p.y * 11.0 - TIME * 1.1) * 0.5 + 0.5;
	float cracks = smoothstep(0.55, 0.9, n) * 0.8 + 0.25;
	vec3 c = mix(vec3(0.9, 0.18, 0.02), vec3(1.0, 0.6, 0.15), n);
	float a = edge * cracks * heat;
	ALBEDO = c * a * 1.6;
	ALPHA = a;
}
"""
