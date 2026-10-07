class_name MoonWell
extends Node3D

## The elf's Moonwell ([ElfSkills]): a circle of moonlight laid on the ground
## at her feet for `SECONDS` — a ring of silver runes turning slowly, a soft
## pale light, motes of light rising out of it and a faint veil of light
## standing over its edge. Every `TICK` the host heals the heroes in it who
## are her friends (herself too) `SHARE` of their health over its whole time
## ([method Player.heal]), and chills the foes in it ([Afflictions] "chill").

const SECONDS := 6.0
const RADIUS := 5.0
const SHARE := 0.25
const TICK := 0.5
const CHILL := 0.8
const MOON := Color(0.78, 0.86, 1.0)
const SILVER := Color(0.92, 0.95, 1.0)
const FADE_IN := 0.4
const FADE_OUT := 0.7

var _caster: Player
var _age: float = 0.0
var _tick: float = 0.0
var _decal: Decal
var _inner: Decal
var _light: OmniLight3D
var _motes: GPUParticles3D
var _veil: MeshInstance3D
var _veil_mat: ShaderMaterial

static var _runes: Texture2D = null
static var _veil_shader: Shader = null

const VEIL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.8, 0.88, 1.0, 1.0);
uniform float strength = 0.0;
void fragment() {
	// bright at the ground, gone a little way up; streaks running up it
	float streak = 0.55 + 0.45 * sin(UV.x * 150.796 + TIME * 1.3) * sin(UV.x * 62.83 - TIME * 0.7);
	ALBEDO = color.rgb;
	ALPHA = clamp(pow(UV.y, 2.5) * streak * strength, 0.0, 1.0);
}
"""


## Every peer: the well at `at`, hers.
static func open(into: Node, at: Vector3, caster: Player) -> MoonWell:
	var w := MoonWell.new()
	w._caster = caster
	into.add_child(w)
	w.global_position = at
	w._build()
	return w


func _build() -> void:
	_decal = Decal.new()
	_decal.size = Vector3(RADIUS * 2.0, 1.6, RADIUS * 2.0)
	_decal.texture_albedo = runes()
	_decal.texture_emission = runes()
	_decal.emission_energy = 1.4
	_decal.modulate = Color(SILVER, 0.0)
	_decal.upper_fade = 0.4
	_decal.lower_fade = 0.3
	add_child(_decal)
	_decal.position = Vector3.UP * 0.3
	# a second, smaller turning the other way inside it
	_inner = Decal.new()
	_inner.size = Vector3(RADIUS * 1.1, 1.6, RADIUS * 1.1)
	_inner.texture_albedo = runes()
	_inner.texture_emission = runes()
	_inner.emission_energy = 1.0
	_inner.modulate = Color(MOON, 0.0)
	_inner.upper_fade = 0.4
	_inner.lower_fade = 0.3
	add_child(_inner)
	_inner.position = Vector3.UP * 0.3
	_light = OmniLight3D.new()
	_light.light_color = MOON
	_light.omni_range = RADIUS * 1.6
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_light.position = Vector3.UP * 1.6
	_motes = SkillFx.particles(self, global_position + Vector3.UP * 0.1, {"amount": 60, "life": 2.2,
			"speed": Vector2(0.3, 0.9), "dir": Vector3.UP, "spread": 12.0, "gravity": Vector3(0, 0.15, 0),
			"damping": 0.2, "size": Vector2(0.025, 0.06), "box": Vector3(RADIUS * 0.75, 0.05, RADIUS * 0.75),
			"colors": [Color(SILVER, 0.0), Color(SILVER, 1.0), Color(MOON, 0.0)]})
	if _veil_shader == null:
		_veil_shader = Shader.new()
		_veil_shader.code = VEIL_SHADER
	var tube := CylinderMesh.new()
	tube.top_radius = RADIUS * 0.96
	tube.bottom_radius = RADIUS * 0.98
	tube.height = 2.2
	tube.radial_segments = 48
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	_veil = MeshInstance3D.new()
	_veil.mesh = tube
	_veil_mat = ShaderMaterial.new()
	_veil_mat.shader = _veil_shader
	_veil.material_override = _veil_mat
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_veil)
	_veil.position = Vector3.UP * 1.1
	var into := get_parent()
	SkillFx.ring(into, global_position + Vector3.UP * 0.1, Vector3.UP, SILVER, 0.4, RADIUS, 0.45, 0.06, 2.5)
	SkillFx.flash(into, global_position + Vector3.UP * 0.5, SILVER, 1.0, 0.25, 2.0)


func _process(delta: float) -> void:
	_age += delta
	var k := clampf(_age / FADE_IN, 0.0, 1.0) * (1.0 - clampf((_age - SECONDS) / FADE_OUT, 0.0, 1.0))
	var pulse := 0.9 + 0.1 * sin(_age * 2.4)
	_decal.modulate.a = k * 0.95
	_decal.rotation.y = _age * 0.12
	_inner.modulate.a = k * 0.7 * pulse
	_inner.rotation.y = -_age * 0.2
	_light.light_energy = k * 1.4 * pulse
	_veil_mat.set_shader_parameter(&"strength", k * 0.5)
	if _age >= SECONDS and _motes.emitting:
		_motes.emitting = false
	if _age < SECONDS and multiplayer.is_server():
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_pour()
	if _age > SECONDS + FADE_OUT + 2.0:
		queue_free()


## The host, every `TICK`: friends in it healed, foes in it chilled.
func _pour() -> void:
	if _caster == null or not is_instance_valid(_caster):
		return
	var at := global_position
	for node in get_tree().get_nodes_in_group(&"player"):
		var p := node as Player
		if p == null or p.is_dead or p.get("net_dead") == true:
			continue
		if p != _caster and _caster.is_hostile_to(p):
			continue
		if not ElfSkills.within(p, at, RADIUS):
			continue
		p.heal(p.max_health * SHARE * TICK / SECONDS)
	for who in ElfSkills.foes_of(_caster):
		if ElfSkills.within(who, at, RADIUS):
			var marks := Afflictions.of(who)
			if marks != null:
				marks.apply(&"chill", CHILL, _caster)


## The runes: two rings with marks between them, a ring of small signs round
## the inside, and a faint star of lines across the middle. White on clear
## (and black under the clear).
static func runes() -> Texture2D:
	if _runes != null:
		return _runes
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var dx := (x - c) / c
			var dy := (y - c) / c
			var r := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var a := 0.0
			# the two rings at the rim and a thin one inside
			a = maxf(a, 1.0 - smoothstep(0.0, 0.012, absf(r - 0.96)))
			a = maxf(a, 1.0 - smoothstep(0.0, 0.008, absf(r - 0.86)))
			a = maxf(a, (1.0 - smoothstep(0.0, 0.006, absf(r - 0.6))) * 0.8)
			# signs between the rings: little bars and dots in a run round it
			if r > 0.87 and r < 0.95:
				var cell := fposmod(ang / TAU * 48.0, 1.0)
				var which := int(floor(ang / TAU * 48.0 + 48.0)) % 4
				var mid := absf(r - 0.91) / 0.04
				var mark := 0.0
				if which == 0:
					mark = 1.0 - smoothstep(0.1, 0.18, absf(cell - 0.5))
				elif which == 1:
					mark = (1.0 - smoothstep(0.12, 0.2, absf(cell - 0.5))) * (1.0 - smoothstep(0.3, 0.45, mid))
				elif which == 2:
					mark = (1.0 - smoothstep(0.3, 0.38, absf(cell - 0.5))) * (1.0 - smoothstep(0.0, 0.25, absf(mid - 0.55)))
				else:
					mark = 1.0 - smoothstep(0.0, 0.12, Vector2((cell - 0.5) * 1.2, mid * 0.5).length())
				a = maxf(a, mark * 0.9)
			# a crescent and star in a ring round the inside
			if r > 0.62 and r < 0.84:
				var cell2 := fposmod(ang / TAU * 8.0, 1.0)
				var p := Vector2((cell2 - 0.5) * 0.62 * TAU * 0.73, (r - 0.73) * 1.0)
				var moon := (1.0 - smoothstep(0.065, 0.075, p.length())) * smoothstep(0.05, 0.06, (p - Vector2(0.03, 0.0)).length())
				a = maxf(a, moon * 0.85)
			# a star of six faint lines through the middle
			if r < 0.6:
				var spoke := absf(sin(ang * 3.0))
				a = maxf(a, (1.0 - smoothstep(0.0, 0.02 / maxf(r, 0.05), spoke)) * 0.35 * (1.0 - r))
			# white only where it is drawn (black elsewhere), so the decal's
			# emission, which takes no alpha, lights only the runes
			var v := clampf(a, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, v))
	img.generate_mipmaps()
	_runes = ImageTexture.create_from_image(img)
	return _runes
