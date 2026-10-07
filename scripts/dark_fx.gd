class_name DarkFx
extends RefCounted

## What the dark elf's spells are drawn with ([DarkSkills]): black fire that
## burns like fire but is darker than the ground it stands on, edged and cored
## in violet; the stuff her Dark Hands are made of ([ShadowHand]); the rock of
## her comets ([DarkComet]); and the marks they leave on the ground.
##
## Black fire is two flames in one: dark, ordinary (not added) tongues of flame
## laid over violet ones that are added, a little smaller, so the black reads
## against the light behind it.

## Violet: the edge of the black fire, the glow in the hands.
const VOID := Color(0.6, 0.28, 1.0)
## Its heart: where it is hottest.
const HOT := Color(0.92, 0.66, 1.0)
## The black of the fire and of the hands.
const INK := Color(0.035, 0.012, 0.05)

const FLAME := preload("res://assets/fx/tex/dark_flame.png")
const PUFF := preload("res://assets/fx/tex/dark_puff.png")
const RUNES := preload("res://assets/fx/tex/dark_runes.png")
const SPIKES := preload("res://assets/fx/tex/dark_spikes.png")
const CRACK := preload("res://assets/fx/tex/dark_crack.png")
const SHOCK := preload("res://assets/fx/tex/dark_shock.png")
const VEINS := preload("res://assets/fx/tex/dark_veins.png")
const ROCK := preload("res://assets/terrain_real/aerial_rocks_02_diff.jpg")

static var _flesh_shader: Shader
static var _rock_shader: Shader
static var _rock_meshes: Array[Mesh] = []
static var _chip_mesh: Mesh


## Black fire rising from `at` for `seconds` (0: one burst), over a `box` (half
## extents) or a ring `ring` (inner, outer radius). `size` scales the flames.
## Returns the two emitters (dark, violet), which stop and go by themselves.
static func black_fire(into: Node, at: Vector3, seconds: float, size: float = 1.0,
		spec: Dictionary = {}) -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	if into == null:
		return out
	var one := seconds <= 0.0
	var rate := float(spec.get("rate", 1.0))
	var shape := {}
	if spec.has("ring"):
		shape["ring"] = spec["ring"]
	else:
		shape["box"] = spec.get("box", Vector3(0.25, 0.05, 0.25) * size)
	var base := {"one_shot": one, "explosiveness": 0.85 if one else 0.0, "spin": true,
			"tex": FLAME, "dir": Vector3.UP, "spread": 12.0, "damping": 0.5}
	base.merge(shape)
	var glow := base.duplicate()
	glow.merge({"amount": maxi(roundi(14 * rate), 2), "life": 0.55, "speed": Vector2(1.0, 2.2) * size,
			"gravity": Vector3(0, 1.5, 0), "size": Vector2(0.35, 0.6) * size, "grow": 0.4, "add": true,
			"colors": [Color(HOT, 0.0), Color(HOT, 0.9), Color(VOID, 0.75), Color(VOID, 0.0)]}, true)
	var dark := base.duplicate()
	dark.merge({"amount": maxi(roundi(16 * rate), 2), "life": 0.75, "speed": Vector2(1.2, 2.6) * size,
			"gravity": Vector3(0, 2.0, 0), "size": Vector2(0.45, 0.8) * size, "grow": 0.5, "add": false,
			"colors": [Color(INK, 0.0), Color(INK, 0.95), Color(0.08, 0.03, 0.1, 0.7), Color(0.1, 0.05, 0.12, 0.0)]}, true)
	var g := SkillFx.particles(into, at, glow)
	var d := SkillFx.particles(into, at + Vector3.UP * 0.08 * size, dark)
	# the black over the violet
	d.sorting_offset = 1.0
	out.append(d)
	out.append(g)
	if not one:
		for p in out:
			_stop_after(p, seconds)
	return out


static func _stop_after(p: GPUParticles3D, seconds: float) -> void:
	var id := p.get_instance_id()
	p.get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		var q := instance_from_id(id) as GPUParticles3D
		if q == null:
			return
		q.emitting = false
		q.get_tree().create_timer(q.lifetime + 0.3, false).timeout.connect(q.queue_free))


## Dark smoke, a few soft puffs rising and swelling.
static func smoke(into: Node, at: Vector3, count: int, size: float, life: float, rise: float = 1.2,
		spread: float = 0.4) -> GPUParticles3D:
	return SkillFx.particles(into, at, {"amount": count, "life": life, "one_shot": true, "explosiveness": 0.8,
			"speed": Vector2(rise * 0.5, rise), "dir": Vector3.UP, "spread": 35.0, "damping": 1.2,
			"size": Vector2(0.7, 1.0) * size, "grow": 0.9, "add": false, "tex": PUFF, "spin": true,
			"sphere": spread,
			"colors": [Color(0.04, 0.02, 0.06, 0.0), Color(0.05, 0.025, 0.07, 0.75), Color(0.09, 0.06, 0.12, 0.0)]})


## Violet motes, sparks off the fire.
static func embers(into: Node, at: Vector3, count: int, speed: Vector2, life: float = 0.9,
		spread: float = 180.0) -> GPUParticles3D:
	return SkillFx.particles(into, at, {"amount": count, "life": life, "one_shot": true, "explosiveness": 0.9,
			"speed": speed, "dir": Vector3.UP, "spread": spread, "gravity": Vector3(0, -3.0, 0), "damping": 1.5,
			"size": Vector2(0.025, 0.06), "grow": 0.2,
			"colors": [Color(1, 1, 1, 1), Color(HOT, 1.0), Color(VOID, 0.0)]})


## A mark projected on the ground under `at`: `tex` tinted `color`, glowing at
## `energy`, `size` across. Lies on whatever is under it, a slope or a step.
static func decal(into: Node, at: Vector3, tex: Texture2D, size: float, color: Color,
		energy: float = 2.0, dark: float = 0.0) -> Decal:
	var d := Decal.new()
	d.size = Vector3(size, 0.9, size)
	d.texture_albedo = tex
	d.texture_emission = tex
	d.emission_energy = energy
	d.modulate = color
	# how much of the ground under it the mark darkens (0: only its glow)
	d.albedo_mix = dark
	d.upper_fade = 0.6
	d.lower_fade = 0.3
	d.cull_mask = 1
	into.add_child(d)
	d.global_position = at + Vector3.UP * 0.15
	return d


## The stuff of the Dark Hands: as black as a hole, rimmed in violet that
## burns brighter at the edge, veins of it crawling under; `dissolve` (0..1)
## eats it away in burning flecks.
static func flesh() -> ShaderMaterial:
	if _flesh_shader == null:
		_flesh_shader = Shader.new()
		_flesh_shader.code = FLESH
	var m := ShaderMaterial.new()
	m.shader = _flesh_shader
	m.set_shader_parameter(&"veins", VEINS)
	m.set_shader_parameter(&"rim_color", VOID)
	return m


## The rock of a comet: black stone split with veins that glow violet.
static func rock_material() -> ShaderMaterial:
	if _rock_shader == null:
		_rock_shader = Shader.new()
		_rock_shader.code = ROCK_SHADER
	var m := ShaderMaterial.new()
	m.shader = _rock_shader
	m.set_shader_parameter(&"rock", ROCK)
	m.set_shader_parameter(&"veins", VEINS)
	m.set_shader_parameter(&"hot", VOID)
	return m


## One of a few rocks (a sphere broken by noise into flat facets), about 1 m
## across.
static func rock_mesh(which: int) -> Mesh:
	if _rock_meshes.is_empty():
		for k in 3:
			_rock_meshes.append(_make_rock(k * 37 + 11, 10 + 2 * k, 7 + k))
	return _rock_meshes[posmod(which, _rock_meshes.size())]


## A small chip of the same rock, for what flies off where it strikes.
static func chip_mesh() -> Mesh:
	if _chip_mesh == null:
		_chip_mesh = _make_rock(5, 6, 4)
	return _chip_mesh


static func _make_rock(rock_seed: int, around: int, down: int) -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = around
	sphere.rings = down
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = rock_seed
	noise.frequency = 1.6
	noise.fractal_octaves = 2
	var squash := Vector3(1.0, 0.82, 0.92)
	for i in verts.size():
		var p := verts[i]
		var n := noise.get_noise_3dv(p * 2.0)
		verts[i] = p * (1.0 + n * 0.55) * squash
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var raw := ArrayMesh.new()
	raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(raw, 0)
	# each face its own: flat, broken facets
	st.deindex()
	st.generate_normals()
	return st.commit()


const FLESH := """
shader_type spatial;
render_mode cull_back, specular_disabled;
uniform sampler2D veins : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 rim_color : source_color = vec4(0.6, 0.28, 1.0, 1.0);
uniform float rim_energy = 1.1;
uniform float dissolve = 0.0;
uniform float glow = 1.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float a = texture(veins, wpos.xy * 0.8 + vec2(0.0, TIME * 0.18)).r;
	float b = texture(veins, wpos.zy * 0.65 - vec2(TIME * 0.11, TIME * 0.05)).r;
	float v = max(a, b);
	if (v < dissolve) {
		discard;
	}
	float edge = dissolve > 0.001 ? 1.0 - smoothstep(dissolve, dissolve + 0.1, v) : 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	ALBEDO = vec3(0.012, 0.005, 0.018);
	ROUGHNESS = 0.5;
	EMISSION = rim_color.rgb * (rim * rim_energy * glow + pow(v, 6.0) * 0.9 * glow + edge * 7.0);
}
"""

const ROCK_SHADER := """
shader_type spatial;
uniform sampler2D rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D veins : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 hot : source_color = vec4(0.6, 0.28, 1.0, 1.0);
uniform float heat = 1.0;
varying vec3 lpos;
varying vec3 lnrm;
void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}
vec4 tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.yz * s) * w.x + texture(t, p.xz * s) * w.y + texture(t, p.xy * s) * w.z;
}
void fragment() {
	vec3 stone = tri(rock, lpos, lnrm, 1.3).rgb;
	float v = tri(veins, lpos + vec3(0.0, TIME * 0.05, 0.0), lnrm, 0.9).r;
	float crack = smoothstep(0.72, 0.93, v);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = stone * vec3(0.22, 0.19, 0.25);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	EMISSION = hot.rgb * (crack * 3.0 + rim * 0.25) * heat + vec3(1.0, 0.85, 1.0) * pow(crack, 6.0) * 2.0 * heat;
}
"""
