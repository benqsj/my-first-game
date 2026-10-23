class_name SwampWade
extends Node3D

## The swamp's water under a hero's feet (the user's word, 2026-10-23: running
## through it felt like dry ground). In the pond: he is slowed by how deep he
## stands ([member Player.wade]), each footfall splashes (its own sound,
## droplets) and a soft ripple spreads from where he goes, a wake behind him.
## On the wet ground: a lighter splash, no slowing. Made by [SwampMere]; the
## pools are in this node's (the room's) frame.

const WADE: Array[String] = [
	"res://sounds/water/wade_1.wav", "res://sounds/water/wade_2.wav", "res://sounds/water/wade_3.wav",
	"res://sounds/water/wade_4.wav", "res://sounds/water/wade_5.wav", "res://sounds/water/wade_6.wav",
]
const WET: Array[String] = [
	"res://sounds/water/wet_1.wav", "res://sounds/water/wet_2.wav", "res://sounds/water/wet_3.wav",
	"res://sounds/water/wet_4.wav", "res://sounds/water/wet_5.wav", "res://sounds/water/wet_6.wav",
]
## A spreading ripple, soft, faint, broken by the water's own noise: water
## giving way, not a mark drawn on it.
const RIPPLE := """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;
// stirred water: soft broken patches spreading and fading, no clean ring
uniform float age = 0.0;
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float spread = mix(0.35, 1.0, sqrt(age));
	float inside = 1.0 - smoothstep(spread * 0.55, spread, r);
	float n = noise(c * 5.0 + seed) * 0.6 + noise(c * 11.0 - seed) * 0.4;
	float stir = smoothstep(0.45, 0.8, n) * inside;
	ALBEDO = vec3(0.70, 0.76, 0.74);
	ALPHA = stir * (1.0 - age) * 0.13;
}
"""

var pools: Array[Dictionary] = []
var noise: FastNoiseLite
var water_y: float = -0.12
var wet_y: float = -0.025

var _heroes: Array[Player] = []
var _seek: float = 0.0
var _steps := {}
var _wake := {}
var _ripple_shader: Shader
var _ripples: Array[MeshInstance3D] = []


func _ready() -> void:
	_ripple_shader = Shader.new()
	_ripple_shader.code = RIPPLE


func _physics_process(delta: float) -> void:
	_seek -= delta
	if _seek <= 0.0:
		_seek = 1.0
		_heroes.clear()
		for n in get_tree().root.find_children("*", "Player", true, false):
			if n is Player:
				_heroes.append(n as Player)
	for hero in _heroes:
		if not is_instance_valid(hero):
			continue
		_hero(hero, delta)
	_age(delta)


func _hero(hero: Player, delta: float) -> void:
	var at := to_local(hero.global_position)
	var deep := 0.0
	var wet := false
	for pl in pools:
		var r := SwampMere._into(pl, at.x, at.z, noise)
		if r >= 1.0:
			continue
		if float(pl["depth"]) < 0.5:
			wet = true
		else:
			var floor_y := SwampMere._height(at.x, at.z, pools, noise)
			deep = maxf(deep, clampf((water_y - floor_y) / 0.32, 0.0, 1.0))
	var was: float = hero.wade
	hero.wade = deep
	var fs := hero.footsteps
	if fs != null:
		if deep > 0.05:
			fs.sounds = WADE
		elif wet:
			fs.sounds = WET
		elif was > 0.05 or fs.sounds == WET:
			fs.sounds = []
		var n: int = fs.steps_played
		var last: int = int(_steps.get(hero.get_instance_id(), n))
		_steps[hero.get_instance_id()] = n
		if n != last and (deep > 0.05 or wet):
			_splash(at, deep)
	# the wake: a ripple now and then behind him while he moves in the pond
	var planar := Vector2(hero.velocity.x, hero.velocity.z).length()
	if deep > 0.05 and planar > 0.6:
		var t: float = float(_wake.get(hero.get_instance_id(), 0.0)) - delta
		if t <= 0.0:
			t = lerpf(0.42, 0.22, clampf(planar / 6.0, 0.0, 1.0))
			_ripple(Vector3(at.x, water_y + 0.01, at.z), lerpf(1.6, 2.6, clampf(planar / 6.0, 0.0, 1.0)))
		_wake[hero.get_instance_id()] = t


func _splash(at: Vector3, deep: float) -> void:
	var y := water_y if deep > 0.05 else wet_y
	var k := 1.0 if deep > 0.05 else 0.45
	SkillFx.particles(self, Vector3(at.x, y + 0.02, at.z), {
		"amount": int(10 * k) + 3, "life": 0.5, "one_shot": true, "explosiveness": 0.95, "add": false,
		"speed": Vector2(1.0, 2.4) * k, "dir": Vector3.UP, "spread": 35.0, "gravity": Vector3(0, -9.0, 0),
		"damping": 0.5, "size": Vector2(0.03, 0.06), "grow": 0.0, "sphere": 0.12,
		"colors": [Color(0.85, 0.9, 0.92, 0.0), Color(0.85, 0.9, 0.92, 0.55), Color(0.85, 0.9, 0.92, 0.0)],
	})
	if deep > 0.05:
		_ripple(Vector3(at.x, y + 0.012, at.z), 1.4)


func _ripple(at: Vector3, size: float) -> void:
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _ripple_shader
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	mat.set_shader_parameter("seed", randf() * 50.0)
	m.set_meta(&"age", 0.0)
	add_child(m)
	_ripples.append(m)


func _age(delta: float) -> void:
	for i in range(_ripples.size() - 1, -1, -1):
		var m := _ripples[i]
		var a: float = float(m.get_meta(&"age")) + delta / 1.1
		if a >= 1.0:
			m.queue_free()
			_ripples.remove_at(i)
			continue
		m.set_meta(&"age", a)
		(m.material_override as ShaderMaterial).set_shader_parameter("age", a)
