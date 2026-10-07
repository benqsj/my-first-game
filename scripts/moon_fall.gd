class_name MoonFall
extends Node3D

## The elf's Moonfall ([ElfSkills]): where she points, a circle of silver runes
## opens on the ground and draws in on itself for `WARN` — the warning; then a
## column of moonlight falls on it out of the sky, white at its heart, with a
## flash, a ring of light running out over the ground and silver sparks
## thrown up. Everything in `RADIUS` of it takes a heavy spell's blow and is
## stunned ([Stun]) for `STUN` (half as long a boss); a frozen one shatters.
## Every peer draws it; the host hurts and stuns.

const WARN := 0.7
const RADIUS := 3.0
const STUN := 1.5
const BEAM := 0.55
const HIGH := 34.0
const MOON := Color(0.78, 0.86, 1.0)
const SILVER := Color(0.94, 0.96, 1.0)

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.8, 0.88, 1.0, 1.0);
uniform float strength = 0.0;
void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float core = pow(facing, 2.2);
	// faint high up, full at the ground
	float down = mix(0.25, 1.0, smoothstep(0.0, 1.0, UV.y));
	ALBEDO = mix(color.rgb, vec3(1.0), core * 0.7) * (0.8 + 1.8 * core);
	ALPHA = clamp(core * down * strength, 0.0, 1.0);
}
"""

static var _beam_shader: Shader = null

var _caster: Player
var _damage: float = 0.0
var _critical := false
var _age: float = 0.0
var _fell := false
var _decal: Decal
var _closing: Decal
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _glow: OmniLight3D


## Every peer: it falls at `at`, hers, worth `damage`.
static func drop(into: Node, at: Vector3, caster: Player, damage: float, critical: bool) -> MoonFall:
	var m := MoonFall.new()
	m._caster = caster
	m._damage = damage
	m._critical = critical
	into.add_child(m)
	m.global_position = at
	m._build()
	return m


func _build() -> void:
	_decal = Decal.new()
	_decal.size = Vector3(RADIUS * 2.1, 2.0, RADIUS * 2.1)
	_decal.texture_albedo = MoonWell.runes()
	_decal.texture_emission = MoonWell.runes()
	_decal.emission_energy = 2.2
	_decal.modulate = Color(SILVER, 0.0)
	_decal.upper_fade = 0.4
	_decal.lower_fade = 0.3
	add_child(_decal)
	_decal.position = Vector3.UP * 0.4
	# the warning: a ring drawing in from the edge to nothing as it comes
	_closing = Decal.new()
	_closing.size = _decal.size
	_closing.texture_albedo = MoonWell.runes()
	_closing.texture_emission = MoonWell.runes()
	_closing.emission_energy = 2.0
	_closing.modulate = Color(MOON, 0.0)
	_closing.upper_fade = 0.4
	_closing.lower_fade = 0.3
	add_child(_closing)
	_closing.position = Vector3.UP * 0.4
	_glow = OmniLight3D.new()
	_glow.light_color = MOON
	_glow.omni_range = RADIUS * 3.0
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	add_child(_glow)
	_glow.position = Vector3.UP * 1.5
	SkillFx.particles(self, global_position + Vector3.UP * 0.1, {"amount": 30, "life": WARN, "one_shot": true,
			"explosiveness": 0.0, "speed": Vector2(0.6, 1.6), "dir": Vector3.UP, "spread": 8.0,
			"size": Vector2(0.02, 0.05), "box": Vector3(RADIUS * 0.7, 0.05, RADIUS * 0.7),
			"colors": [Color(SILVER, 0.0), Color(SILVER, 1.0), Color(MOON, 0.0)]})


func _process(delta: float) -> void:
	_age += delta
	if _age < WARN:
		var k := _age / WARN
		_decal.modulate.a = smoothstep(0.0, 0.3, k) * 0.95
		_decal.rotation.y = _age * 0.8
		var s := lerpf(1.0, 0.15, k)
		_closing.size = Vector3(RADIUS * 2.1 * s, 2.0, RADIUS * 2.1 * s)
		_closing.modulate.a = smoothstep(0.0, 0.2, k) * 0.8
		_closing.rotation.y = -_age * 1.6
		_glow.light_energy = k * 1.2
		return
	if not _fell:
		_fell = true
		_fall()
	var t := _age - WARN
	var k2 := 1.0 - clampf(t / BEAM, 0.0, 1.0)
	if _beam_mat != null:
		_beam_mat.set_shader_parameter(&"strength", k2 * k2 * 1.6)
		_beam.scale = Vector3(lerpf(1.0, 0.35, 1.0 - k2), 1.0, lerpf(1.0, 0.35, 1.0 - k2))
	_decal.modulate.a = k2 * 0.95
	_closing.modulate.a = 0.0
	_glow.light_energy = k2 * 6.0
	if t > BEAM + 1.0:
		queue_free()


## The moon's light falls: drawn on every peer, and the host deals it.
func _fall() -> void:
	if _beam_shader == null:
		_beam_shader = Shader.new()
		_beam_shader.code = BEAM_SHADER
	var tube := CylinderMesh.new()
	tube.top_radius = RADIUS * 0.75
	tube.bottom_radius = RADIUS * 0.55
	tube.height = HIGH
	tube.radial_segments = 32
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	_beam = MeshInstance3D.new()
	_beam.mesh = tube
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = _beam_shader
	_beam_mat.set_shader_parameter(&"color", MOON)
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
	_beam.position = Vector3.UP * HIGH * 0.5
	var into := get_parent()
	var at := global_position + Vector3.UP * 0.2
	SkillFx.flash(into, at + Vector3.UP * 0.8, SILVER, RADIUS * 0.9, 0.25, 4.0)
	SkillFx.ring(into, at, Vector3.UP, SILVER, 0.4, RADIUS * 2.2, 0.45, 0.08, 3.0)
	SkillFx.ring(into, at + Vector3.UP * 0.05, Vector3.UP, MOON, 0.2, RADIUS * 1.4, 0.6, 0.05, 2.0)
	SkillFx.burst(into, at, SILVER, 60, Vector2(3.0, 9.0), Vector3.UP, 55.0, Vector2(0.03, 0.07),
			Vector3(0, -7, 0), 0.9)
	SkillFx.particles(into, at, {"amount": 24, "life": 1.4, "one_shot": true, "explosiveness": 1.0,
			"speed": Vector2(3.0, 6.0), "dir": Vector3.UP, "spread": 88.0, "gravity": Vector3(0, -1.0, 0),
			"damping": 4.0, "size": Vector2(0.6, 1.1), "box": Vector3(0.5, 0.05, 0.5), "add": false, "grow": 0.8,
			"colors": [Color(0.9, 0.93, 1.0, 0.0), Color(0.9, 0.93, 1.0, 0.3), Color(0.9, 0.93, 1.0, 0.0)]})
	WindBlast.shake(self, 0.08, 0.25, 25.0)
	if multiplayer.is_server() and _caster != null and is_instance_valid(_caster):
		var stunned: Array = []
		for who in ElfSkills.foes_of(_caster):
			if not ElfSkills.within(who, global_position, RADIUS, 3.5):
				continue
			ElfSkills.hurt(who, _damage, _critical, _caster, who.global_position + Vector3.UP * 0.8)
			if who.get(&"is_dead") == true:
				continue
			if who.has_method(&"react"):
				who.call(&"react", &"stun", _caster, Vector3.ZERO)
			stunned.append(who)
		for who: Node3D in stunned:
			_caster.net_stunned.rpc(who.get_path(), STUN * (0.5 if ShadowGrasp.is_boss(who) else 1.0))
