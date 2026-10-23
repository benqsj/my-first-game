class_name SwampWade
extends Node3D

## The swamp's water under a hero's feet (the user's word, 2026-10-23: running
## through it felt like dry ground; then: the pond shallow, run over it, a
## wave going off behind, and no stutter on stepping in). In the pond he is
## held back a little ([member Player.wade]), each footfall splashes (its own
## sound, droplets), and while he runs a wake spreads behind him in a V, as
## off a boat. On the wet ground: a lighter splash. Made by [SwampMere]; the
## pools are in this node's (the room's) frame.
##
## Cheap on purpose: the heroes come from the [World]'s list, the droplets
## from a few particle systems made once and moved, the wake from a pool of
## planes sharing one material (their age an instance uniform).

const WADE: Array[String] = [
	"res://sounds/water/wade_1.wav", "res://sounds/water/wade_2.wav", "res://sounds/water/wade_3.wav",
	"res://sounds/water/wade_4.wav", "res://sounds/water/wade_5.wav", "res://sounds/water/wade_6.wav",
]
const WET: Array[String] = [
	"res://sounds/water/wet_1.wav", "res://sounds/water/wet_2.wav", "res://sounds/water/wet_3.wav",
	"res://sounds/water/wet_4.wav", "res://sounds/water/wet_5.wav", "res://sounds/water/wet_6.wav",
]
## One wave of the wake: a soft crest across the hero's way, bowed back at
## its ends; laid one after another as he runs they open into a V.
const WAVE := """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;
instance uniform float age = 1.0;
instance uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	// x across his way, y along it (1 ahead, -1 behind)
	vec2 c = UV * 2.0 - 1.0;
	float spread = mix(0.25, 1.0, sqrt(age));
	// the crest: a bow whose ends trail back
	float bow = c.y + 1.4 * c.x * c.x - 0.35;
	float crest = exp(-pow(bow / (0.10 + 0.10 * age), 2.0));
	float wide = 1.0 - smoothstep(spread * 0.7, spread, abs(c.x));
	// the arms of the V carry the wave; behind him the water is calmer
	float arms = 0.35 + 0.65 * smoothstep(0.05, 0.5, abs(c.x));
	float n = smoothstep(0.25, 0.85, noise(c * 7.0 + seed) * 0.7 + noise(c * 15.0 - seed) * 0.3);
	ALBEDO = vec3(0.74, 0.80, 0.78);
	ALPHA = crest * wide * arms * n * (1.0 - age) * 0.18;
}
"""
const WAVES := 24
const SPLASHES := 4

var pools: Array[Dictionary] = []
var noise: FastNoiseLite

var _world: World
var _heroes: Array[Player] = []
var _seek: float = 0.0
var _steps := {}
var _wake := {}
var _waves: Array[MeshInstance3D] = []
var _wave_age: Array[float] = []
var _next_wave: int = 0
var _splashes: Array[GPUParticles3D] = []
var _next_splash: int = 0


func _ready() -> void:
	var n: Node = self
	while n != null and not (n is World):
		n = n.get_parent()
	_world = n as World
	var sh := Shader.new()
	sh.code = WAVE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)
	for i in WAVES:
		var m := MeshInstance3D.new()
		m.mesh = plane
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_waves.append(m)
		_wave_age.append(1.0)
	for i in SPLASHES:
		var p := SkillFx.particles(self, Vector3(0.0, -50.0, 0.0), {
			"amount": 12, "life": 0.5, "one_shot": true, "explosiveness": 0.95, "add": false, "free_after": 0.0,
			"speed": Vector2(1.0, 2.4), "dir": Vector3.UP, "spread": 35.0, "gravity": Vector3(0, -9.0, 0),
			"damping": 0.5, "size": Vector2(0.03, 0.06), "grow": 0.0, "sphere": 0.12,
			"colors": [Color(0.85, 0.9, 0.92, 0.0), Color(0.85, 0.9, 0.92, 0.55), Color(0.85, 0.9, 0.92, 0.0)],
		})
		p.emitting = false
		_splashes.append(p)


func _physics_process(delta: float) -> void:
	_seek -= delta
	if _seek <= 0.0:
		_seek = 1.0
		if _world != null:
			_heroes = _world.players()
	for hero in _heroes:
		if is_instance_valid(hero):
			_hero(hero, delta)
	_age(delta)


func _hero(hero: Player, delta: float) -> void:
	var at := to_local(hero.global_position)
	var deep := 0.0
	var wet := false
	var y := 0.0
	for pl in pools:
		if SwampMere._into(pl, at.x, at.z, noise) >= 0.97:
			continue
		var floor_y := SwampMere._height(at.x, at.z, pools, noise)
		var water_y: float = pl["water"]
		if water_y <= floor_y:
			continue
		y = water_y
		if float(pl["depth"]) < 0.4:
			wet = true
		else:
			deep = maxf(deep, clampf((water_y - floor_y) / 0.5, 0.0, 1.0))
	var was: float = hero.wade
	hero.wade = deep
	var fs := hero.footsteps
	if fs != null:
		if deep > 0.02:
			fs.sounds = WADE
		elif wet:
			fs.sounds = WET
		elif was > 0.02 or fs.sounds == WET:
			fs.sounds = []
		var n: int = fs.steps_played
		var id := hero.get_instance_id()
		var last: int = int(_steps.get(id, n))
		_steps[id] = n
		if n != last and (deep > 0.02 or wet):
			_splash(Vector3(at.x, y + 0.02, at.z), 1.0 if deep > 0.02 else 0.45)
	# the wake: a wave now and then while he runs in the pond
	var vel := Vector3(hero.velocity.x, 0.0, hero.velocity.z)
	var planar := vel.length()
	if deep > 0.02 and planar > 1.0:
		var id2 := hero.get_instance_id()
		var t: float = float(_wake.get(id2, 0.0)) - delta
		if t <= 0.0:
			t = lerpf(0.30, 0.14, clampf(planar / 6.0, 0.0, 1.0))
			var dir := global_transform.basis.inverse() * vel.normalized()
			_wave(Vector3(at.x, y + 0.01, at.z), dir, lerpf(1.8, 3.0, clampf(planar / 6.0, 0.0, 1.0)))
		_wake[id2] = t


func _splash(at: Vector3, k: float) -> void:
	var p := _splashes[_next_splash]
	_next_splash = (_next_splash + 1) % _splashes.size()
	p.position = at
	p.amount_ratio = k
	p.restart()


func _wave(at: Vector3, dir: Vector3, size: float) -> void:
	var i := _next_wave
	_next_wave = (_next_wave + 1) % _waves.size()
	var m := _waves[i]
	var yaw := atan2(dir.x, dir.z)
	m.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, 1.0, size * 0.8)), at)
	m.set_instance_shader_parameter(&"seed", randf() * 50.0)
	m.set_instance_shader_parameter(&"age", 0.0)
	m.visible = true
	_wave_age[i] = 0.0


func _age(delta: float) -> void:
	for i in _waves.size():
		if _wave_age[i] >= 1.0:
			continue
		var a := _wave_age[i] + delta / 1.3
		_wave_age[i] = a
		var m := _waves[i]
		if a >= 1.0:
			m.visible = false
			continue
		m.set_instance_shader_parameter(&"age", a)
		# the wave goes on outward as it fades
		m.scale = m.scale * (1.0 + delta * 0.9)
