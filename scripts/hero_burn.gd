class_name HeroBurn
extends Node3D

## A hero alight (a skeleton archer's burning arrow, [BowFighter]; an imp's
## fireball, [Imp]) for `left` seconds. Made on every peer by the thrower's
## rpc; the hero's own peer, which owns his health, takes `dps` off it.
## Rolling does not put it out; it burns down.
##
## One fire on all of him (the user, 2026-10-27: not a ball of flame on his
## chest, nor little flames hanging in the air near him): his body itself
## glows and flickers with fire crawling up it (an overlay on every mesh of
## his), one sheet of flame rises off him from hips to shoulders and follows
## him as he bends, thin smoke over him, a few sparks, a warm flickering
## light. It flares up when it catches and dies down at the end.

const TICK := 0.5
const FIRE_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform float strength = 1.0;
varying vec3 wpos;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.4);
	float n = noise(wpos * vec3(5.0, 2.6, 5.0) - vec3(0.0, TIME * 3.2, 0.0)) * 0.65
			+ noise(wpos * vec3(11.0, 6.0, 11.0) - vec3(0.0, TIME * 5.5, 0.0)) * 0.35;
	float lick = smoothstep(0.52, 0.8, n);
	vec3 col = mix(vec3(0.8, 0.12, 0.0), vec3(1.0, 0.5, 0.1), lick);
	ALBEDO = col * (lick * 0.3 + rim * (0.06 + lick * 0.6)) * strength;
}
"""

static var _shader: Shader

var left: float = 0.0
var dps: float = 6.0
var _tick: float = 0.0
var _age: float = 0.0
var _skeleton: Skeleton3D
var _low: int = -1
var _high: int = -1
var _skin: ShaderMaterial
var _strength: float = 0.0
var _meshes: Array[GeometryInstance3D] = []
var _sheet: GPUParticles3D
var _smoke: GPUParticles3D
var _sparks: GPUParticles3D
var _light: OmniLight3D


## Sets `hero` alight for `seconds` (renewed, never shortened).
static func ignite(hero: Node3D, seconds: float, burn_dps: float) -> void:
	if hero == null or not is_instance_valid(hero) or bool(hero.get("is_dead")):
		return
	var burn := hero.get_node_or_null(^"HeroBurn") as HeroBurn
	if burn == null:
		burn = HeroBurn.new()
		burn.name = "HeroBurn"
		hero.add_child(burn)
	burn.left = maxf(burn.left, seconds)
	burn.dps = burn_dps


func _ready() -> void:
	var hero := get_parent() as Node3D
	var found := hero.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		_skeleton = found[0] as Skeleton3D
		_low = _bone_like(["pelvis", "hips", "spine_01"])
		_high = _bone_like(["neck", "spine_03", "spine2"])
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FIRE_SHADER
	_skin = ShaderMaterial.new()
	_skin.shader = _shader
	_skin.set_shader_parameter(&"strength", 0.0)
	for node in hero.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g.is_in_group(&"no_burn") or not g.is_visible_in_tree() or g.material_overlay != null:
			continue
		if not (g is MeshInstance3D) or (g as MeshInstance3D).skeleton == NodePath():
			continue
		g.material_overlay = _skin
		_meshes.append(g)
	# one sheet of flame up him, hips to shoulders
	_sheet = SkillFx.particles(self, hero.global_position + Vector3.UP, {
		"amount": 64, "life": 0.6, "speed": Vector2(0.3, 0.8), "spread": 15.0,
		"gravity": Vector3(0, 2.6, 0), "size": Vector2(0.24, 0.42), "box": Vector3(0.22, 0.34, 0.14),
		"grow": 0.2, "tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": true,
		"colors": [Color(1.0, 0.75, 0.3, 0.0), Color(1.0, 0.55, 0.12, 0.9), Color(0.95, 0.28, 0.03, 0.7),
				Color(0.6, 0.08, 0.0, 0.3), Color(0.2, 0.02, 0.0, 0.0)],
	})
	_sheet.fixed_fps = 0
	_sheet.interpolate = false
	_smoke = SkillFx.particles(self, hero.global_position + Vector3.UP * 1.6, {
		"amount": 14, "life": 1.3, "speed": Vector2(0.3, 0.6), "spread": 15.0,
		"gravity": Vector3(0, 0.6, 0), "size": Vector2(0.2, 0.35), "sphere": 0.18, "grow": 0.6,
		"add": false,
		"colors": [Color(0.15, 0.12, 0.1, 0.0), Color(0.18, 0.15, 0.13, 0.28), Color(0.3, 0.28, 0.27, 0.0)],
	})
	_sparks = SkillFx.particles(self, hero.global_position + Vector3.UP * 1.0, {
		"amount": 10, "life": 0.7, "speed": Vector2(0.5, 1.3), "spread": 35.0,
		"gravity": Vector3(0, 0.8, 0), "size": Vector2(0.02, 0.035), "box": Vector3(0.2, 0.5, 0.2),
		"add": true,
		"colors": [Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.45, 0.08, 0.8), Color(1.0, 0.3, 0.05, 0.0)],
	})
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.48, 0.14)
	_light.omni_range = 3.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_follow()


func _bone_like(keys: Array) -> int:
	for key: String in keys:
		for b in _skeleton.get_bone_count():
			if _skeleton.get_bone_name(b).to_lower().contains(key):
				return b
	return -1


func _bone_at(bone: int, fallback: Vector3) -> Vector3:
	if _skeleton == null or bone < 0:
		return fallback
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).origin


## The sheet of flame on his trunk as he stands or bends.
func _follow() -> void:
	var hero := get_parent() as Node3D
	if hero == null:
		return
	var low := _bone_at(_low, hero.global_position + Vector3.UP * 0.95)
	var high := _bone_at(_high, hero.global_position + Vector3.UP * 1.5)
	var mid := low.lerp(high, 0.45)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		mid += (cam.global_position - mid).normalized() * 0.08
	_sheet.global_position = mid
	var up := high - low
	if up.length_squared() > 0.01:
		var y := up.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		_sheet.global_basis = Basis(x, y, x.cross(y))
	_smoke.global_position = high + Vector3.UP * 0.3
	_sparks.global_position = mid
	_light.global_position = mid + Vector3.UP * 0.1


func _process(delta: float) -> void:
	_age += delta
	var hero := get_parent() as Node3D
	left -= delta
	_follow()
	var out := hero == null or left <= 0.0 or bool(hero.get("is_dead"))
	_sheet.emitting = not out
	_smoke.emitting = not out
	_sparks.emitting = not out
	var flare := 1.0 + 0.6 * clampf(1.0 - _age / 0.35, 0.0, 1.0)
	var glow := 0.0 if out else clampf(minf(_age * 6.0, left * 1.5), 0.0, 1.0) * flare
	_strength = move_toward(_strength, glow, delta * 3.0)
	_skin.set_shader_parameter(&"strength", _strength)
	if out:
		_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 4.0)
		if left < -1.2 or (hero != null and bool(hero.get("is_dead"))):
			queue_free()
		return
	_light.light_energy = (0.9 + 0.35 * sin(_age * 21.0) * sin(_age * 6.3)) * flare
	if not hero.is_multiplayer_authority():
		return
	_tick += delta
	if _tick < TICK:
		return
	_tick -= TICK
	if hero.has_method(&"_take_damage"):
		hero.call(&"_take_damage", dps * TICK)


func _exit_tree() -> void:
	for g in _meshes:
		if is_instance_valid(g) and g.material_overlay == _skin:
			g.material_overlay = null
