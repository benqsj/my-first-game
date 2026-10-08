class_name GroundFx
extends Node3D

## What the big ones do to the ground, drawn the same in every window.
##
## * [method wave]: a run of stone thorns out of the ground along a line,
##   fanning wider the further it goes. Each row comes up a moment after the
##   one before, all of them hold, and then they fade away where they stand —
##   they do not sink back. Arkdeva's is long and thin; the orc's is squat
##   earth.
## * [method eruption]: rocks and grit flung up where a heavy blow lands.
## * [method shards]: the golem's (2026-10-08, the user's word: make its
##   spikes much better): the same rows as [method wave] — the host hurts by
##   the same numbers — but faceted stone, a crack opening along the ground
##   ahead of them, glowing the golem's amber, each row bursting up through it
##   with grit and dust, and the lot crumbling back into the ground at the
##   end instead of fading.
##
## Arkdeva's poison used to be here too; it is [Venom] now.
##
## All of it is looks. Who is hurt is decided by the host, from the same
## numbers ([method wave_front], [method wave_width]).

## How fast the front of a wave runs out, in metres a second.
const WAVE_SPEED := 25.0
## How long a wave stands once it is all up, and how long it takes to fade.
const WAVE_HOLD := 1.0
const WAVE_FADE := 0.45

enum Kind { WAVE, DEBRIS, SHARDS }

static var _thorn_mesh: Mesh
static var _spike_mesh: Mesh
static var _rock_mesh: Mesh
static var _shard_mesh: Mesh
static var _crack_shader: Shader

var _kind: int = Kind.WAVE
var _t: float = 0.0
var _end: float = 1.0
var _mm: MultiMesh
var _material: StandardMaterial3D
var _items: Array = []
var _base_y: float = 0.0
## The shards' crack, the rows still to burst up, and where the wave began.
var _crack_mat: ShaderMaterial
var _pace: float = WAVE_SPEED
var _rows: Array = []
var _from: Vector3 = Vector3.ZERO
var _ahead: Vector3 = Vector3.FORWARD
var _crumbled: bool = false
var _length: float = 0.0
var _glow: OmniLight3D


## Metres from the start the front of a wave has reached after `t` seconds.
static func wave_front(t: float) -> float:
	return t * WAVE_SPEED


## Width of a wave at `d` metres out.
static func wave_width(d: float, size: float = 1.0) -> float:
	return (0.7 + 0.32 * d) * size


static func wave(into: Node, from: Vector3, direction: Vector3, length: float,
		thin: bool, size: float = 1.0, pace: float = WAVE_SPEED) -> GroundFx:
	if into == null:
		return null
	var fx := GroundFx.new()
	fx._kind = Kind.WAVE
	fx._base_y = from.y
	var ahead := Vector3(direction.x, 0.0, direction.z).normalized()
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(from.x * 10.0), roundi(from.z * 10.0), roundi(length)))
	var last := 0.0
	var d := 0.8
	while d <= length:
		var width := wave_width(d, size)
		var n := 2 + floori(d * 0.7)
		for i in n:
			var off := (float(i) / float(n - 1) - 0.5) * width + rng.randf_range(-0.17, 0.17)
			var pos := from + ahead * (d + rng.randf_range(-0.15, 0.15)) + across * off
			var edge := absf(off) / maxf(width * 0.5, 0.01)
			var s := rng.randf_range(0.75, 1.3) * (1.15 - 0.4 * edge) * (0.85 + d / length * 0.5) * size
			var tall := s * rng.randf_range(0.9, 1.5)
			var delay := d / pace + rng.randf() * 0.05
			last = maxf(last, delay)
			# Leant outwards from where the wave started, more at the edges.
			var out := Vector3(pos.x - from.x, 0.0, pos.z - from.z)
			var angle := atan2(out.x, out.z)
			var lean := 0.12 + edge * 0.35
			var basis := Basis.from_euler(Vector3(cos(angle) * lean, rng.randf() * TAU, -sin(angle) * lean))
			basis = basis * Basis.from_scale(Vector3(s, tall, s))
			fx._items.append([Vector3(pos.x, from.y, pos.z), basis, delay, tall])
		d += 0.45
	fx._end = last + WAVE_HOLD + WAVE_FADE

	var mesh := _thorn() if thin else _spike()
	fx._mm = MultiMesh.new()
	fx._mm.transform_format = MultiMesh.TRANSFORM_3D
	fx._mm.mesh = mesh
	fx._mm.instance_count = fx._items.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = fx._mm
	fx._material = StandardMaterial3D.new()
	fx._material.albedo_color = Color8(0x8c, 0x7d, 0x6a) if thin else Color8(0x6d, 0x5f, 0x52)
	fx._material.roughness = 0.9
	mmi.material_override = fx._material
	mmi.custom_aabb = AABB(Vector3(-length - 4.0, -3.0, -length - 4.0), Vector3(length * 2.0 + 8.0, 8.0, length * 2.0 + 8.0))
	fx.add_child(mmi)
	fx.top_level = true
	into.add_child(fx)
	fx.global_position = from
	fx._place()
	DustRing.burst(into, from, 1.2 * size)
	return fx


## The golem's stone out of the ground, laid out as [method wave] lays its
## thorns (row by row, the same widths), drawn as faceted shards.
static func shards(into: Node, from: Vector3, direction: Vector3, length: float, size: float = 1.0,
		pace: float = WAVE_SPEED, glow: Color = Color(1.0, 0.62, 0.25)) -> GroundFx:
	if into == null:
		return null
	var fx := GroundFx.new()
	fx._kind = Kind.SHARDS
	fx._base_y = from.y
	fx._pace = pace
	fx._from = from
	var ahead := Vector3(direction.x, 0.0, direction.z).normalized()
	fx._ahead = ahead
	fx._length = length
	var across := Vector3(-ahead.z, 0.0, ahead.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(from.x * 10.0), roundi(from.z * 10.0), roundi(length)))
	var last := 0.0
	var d := 0.8
	while d <= length:
		var width := wave_width(d, size)
		var n := 2 + floori(d * 0.6)
		var row_delay := d / pace
		fx._rows.append([d, row_delay, false])
		for i in n:
			var off := (float(i) / float(maxi(n - 1, 1)) - 0.5) * width + rng.randf_range(-0.2, 0.2)
			var pos := from + ahead * (d + rng.randf_range(-0.18, 0.18)) + across * off
			var edge := absf(off) / maxf(width * 0.5, 0.01)
			# The middle of the run tallest, the edges and the start low.
			var s := rng.randf_range(0.8, 1.25) * (1.2 - 0.5 * edge) * (0.75 + d / length * 0.6) * size
			var tall := s * rng.randf_range(0.85, 1.45)
			var delay := row_delay + rng.randf() * 0.06
			last = maxf(last, delay)
			var out := Vector3(pos.x - from.x, 0.0, pos.z - from.z)
			var angle := atan2(out.x, out.z)
			var lean := 0.18 + edge * 0.45 + rng.randf_range(-0.08, 0.08)
			var basis := Basis.from_euler(Vector3(cos(angle) * lean, rng.randf() * TAU, -sin(angle) * lean))
			basis = basis * Basis.from_scale(Vector3(s * 1.35, tall, s * 1.35))
			var tone := rng.randf_range(0.82, 1.12)
			fx._items.append([Vector3(pos.x, from.y, pos.z), basis, delay, tall, Color(tone, tone * 0.98, tone * 0.95)])
			# Now and then a small one leaning in at its foot.
			if rng.randf() < 0.45:
				var foot := pos + across * rng.randf_range(-0.35, 0.35) * size + ahead * rng.randf_range(-0.3, 0.3) * size
				var small := s * rng.randf_range(0.35, 0.55)
				var b2 := Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6)))
				b2 = b2 * Basis.from_scale(Vector3(small, small * rng.randf_range(0.8, 1.3), small))
				fx._items.append([Vector3(foot.x, from.y, foot.z), b2, delay + 0.03, small, Color(tone * 0.9, tone * 0.88, tone * 0.85)])
		d += 0.45
	fx._end = last + WAVE_HOLD + 0.7

	fx._mm = MultiMesh.new()
	fx._mm.transform_format = MultiMesh.TRANSFORM_3D
	fx._mm.use_colors = true
	fx._mm.mesh = _shard()
	fx._mm.instance_count = fx._items.size()
	for i in fx._items.size():
		fx._mm.set_instance_color(i, (fx._items[i] as Array)[4])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = fx._mm
	fx._material = StandardMaterial3D.new()
	fx._material.vertex_color_use_as_albedo = true
	fx._material.vertex_color_is_srgb = true
	fx._material.albedo_color = Color(1, 1, 1)
	fx._material.roughness = 0.95
	fx._material.metallic_specular = 0.25
	mmi.material_override = fx._material
	mmi.custom_aabb = AABB(Vector3(-length - 4.0, -3.0, -length - 4.0), Vector3(length * 2.0 + 8.0, 8.0, length * 2.0 + 8.0))
	fx.add_child(mmi)
	fx.top_level = true
	into.add_child(fx)
	fx.global_position = from
	fx._add_crack(length, size, glow, rng)
	fx._glow = OmniLight3D.new()
	fx._glow.light_color = glow
	fx._glow.omni_range = 3.2 * size
	fx._glow.light_energy = 0.0
	fx._glow.shadow_enabled = false
	fx.add_child(fx._glow)
	fx._place()
	return fx


## The crack the shards come up through: a jagged strip along the ground,
## dark with a glowing seam, opening a little ahead of the front.
func _add_crack(length: float, size: float, glow: Color, rng: RandomNumberGenerator) -> void:
	var across := Vector3(-_ahead.z, 0.0, _ahead.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 0.35
	var d := 0.0
	var wiggle := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_d := 0.0
	var first := true
	while d <= length + 0.01:
		wiggle = clampf(wiggle + rng.randf_range(-0.22, 0.22), -0.45, 0.45)
		var half := (0.1 + 0.05 * d / length + rng.randf_range(-0.03, 0.04)) * size
		var mid := _ahead * d + across * wiggle * size
		var l := mid - across * half + Vector3.UP * 0.025
		var r := mid + across * half + Vector3.UP * 0.025
		if not first:
			for v: Array in [[prev_l, 0.0, prev_d], [prev_r, 1.0, prev_d], [r, 1.0, d],
					[prev_l, 0.0, prev_d], [r, 1.0, d], [l, 0.0, d]]:
				st.set_uv(Vector2(float(v[1]), float(v[2])))
				st.add_vertex(v[0])
		first = false
		prev_l = l
		prev_r = r
		prev_d = d
		d += step
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _crack_shader == null:
		_crack_shader = Shader.new()
		_crack_shader.code = CRACK_SHADER
	_crack_mat = ShaderMaterial.new()
	_crack_mat.shader = _crack_shader
	_crack_mat.set_shader_parameter(&"glow", glow)
	_crack_mat.set_shader_parameter(&"front", 0.0)
	_crack_mat.set_shader_parameter(&"fade", 1.0)
	mi.material_override = _crack_mat
	mi.custom_aabb = AABB(Vector3(-length - 2.0, -1.0, -length - 2.0), Vector3(length * 2.0 + 4.0, 2.0, length * 2.0 + 4.0))
	add_child(mi)


const CRACK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 glow : source_color = vec3(1.0, 0.6, 0.25);
uniform float front = 0.0;
uniform float fade = 1.0;
void fragment() {
	// UV.y is metres along the run: open up to a little ahead of the front.
	float open = clamp((front - UV.y) * 2.5, 0.0, 1.0);
	float seam = 1.0 - abs(UV.x - 0.5) * 2.0;
	float hot = smoothstep(0.55, 1.0, seam) * clamp(1.0 - (front - UV.y) * 0.35, 0.25, 1.0);
	ALBEDO = mix(vec3(0.07, 0.055, 0.045), glow * 2.2, hot);
	ALPHA = open * fade * smoothstep(0.0, 0.35, seam) * 0.95;
}
"""


static func eruption(into: Node, at: Vector3, size: float = 1.0, dust_ring: bool = true) -> GroundFx:
	if into == null:
		return null
	var fx := GroundFx.new()
	fx._kind = Kind.DEBRIS
	fx._base_y = at.y
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in roundi(22 * size):
		var a := rng.randf() * TAU
		var out := rng.randf_range(1.2, 4.0) * size
		var velocity := Vector3(cos(a) * out, rng.randf_range(2.5, 5.5) * size, sin(a) * out)
		var s := rng.randf_range(0.05, 0.13) * size
		fx._items.append([at, velocity, s, Vector3(rng.randf(), rng.randf(), rng.randf()) * 8.0])
	fx._end = 1.4
	fx._mm = MultiMesh.new()
	fx._mm.transform_format = MultiMesh.TRANSFORM_3D
	fx._mm.mesh = _rock()
	fx._mm.instance_count = fx._items.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = fx._mm
	fx._material = StandardMaterial3D.new()
	fx._material.albedo_color = Color8(0x6d, 0x5f, 0x52)
	fx._material.roughness = 1.0
	mmi.material_override = fx._material
	mmi.custom_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	fx.add_child(mmi)
	fx.top_level = true
	into.add_child(fx)
	fx.global_position = Vector3.ZERO
	fx._place()
	if dust_ring:
		DustRing.burst(into, at, 0.9 * size)
	else:
		SkillFx.particles(into, at + Vector3.UP * 0.3, {
			"amount": 10, "life": 1.2, "one_shot": true, "explosiveness": 0.85, "add": false,
			"speed": Vector2(0.6, 2.0), "dir": Vector3.UP, "spread": 75.0, "gravity": Vector3(0, 0.2, 0),
			"damping": 1.5, "size": Vector2(0.45, 0.9), "grow": 0.3, "sphere": 0.4 * size,
			"colors": [Color(0.6, 0.55, 0.48, 0.0), Color(0.58, 0.53, 0.46, 0.4), Color(0.55, 0.5, 0.45, 0.0)],
		})
	return fx


func _process(delta: float) -> void:
	_t += delta
	match _kind:
		Kind.WAVE, Kind.DEBRIS:
			_place()
		Kind.SHARDS:
			_burst_rows()
			_place()
	if _t >= _end:
		queue_free()


func _place() -> void:
	match _kind:
		Kind.WAVE:
			var fade_from := _end - WAVE_FADE
			if _t > fade_from:
				_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_material.albedo_color.a = clampf((_end - _t) / WAVE_FADE, 0.0, 1.0)
			for i in _items.size():
				var it: Array = _items[i]
				var rise := clampf((_t - float(it[2])) / 0.1, 0.0, 1.0)
				var tall: float = it[3]
				var pos: Vector3 = it[0]
				# Below ground until its turn, then up to stand at full height.
				pos.y = lerpf(-1.3 * tall, -0.08 * tall, rise)
				pos.x -= global_position.x
				pos.z -= global_position.z
				_mm.set_instance_transform(i, Transform3D(it[1], pos))
		Kind.SHARDS:
			var crumble_from := _end - 0.7
			var front := _t * _pace + 0.9
			_crack_mat.set_shader_parameter(&"front", front)
			_crack_mat.set_shader_parameter(&"fade", clampf((_end - _t) / 0.7, 0.0, 1.0))
			if _glow != null:
				_glow.position = _ahead * minf(_t * _pace, _length) + Vector3.UP * 0.4
				_glow.light_energy = 1.4 * clampf(1.0 - (_t - crumble_from) / 0.4, 0.0, 1.0) if _t > crumble_from \
						else 1.4 * clampf(_t * 6.0, 0.0, 1.0)
			for i in _items.size():
				var it: Array = _items[i]
				var r := clampf((_t - float(it[2])) / 0.16, 0.0, 1.0)
				# Bursting up past its height and settling back (an ease out
				# that overshoots), then crumbling down into the ground.
				var c := 1.70158
				var up := 1.0 + (c + 1.0) * pow(r - 1.0, 3.0) + c * pow(r - 1.0, 2.0) if r > 0.0 else 0.0
				var tall: float = it[3]
				var pos: Vector3 = it[0]
				var sink := 0.0
				var shrink := 1.0
				if _t > crumble_from:
					var k := clampf((_t - crumble_from) / 0.7, 0.0, 1.0)
					sink = k * k * 1.1 * tall
					shrink = 1.0 - 0.35 * k
				pos.y = lerpf(-1.25 * tall, -0.06 * tall, up) - sink
				pos.x -= global_position.x
				pos.z -= global_position.z
				var b: Basis = it[1]
				_mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(shrink, shrink, shrink)), pos))
			if _t > crumble_from and not _crumbled:
				_crumbled = true
				_crumble()
		Kind.DEBRIS:
			_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if _t > _end - 0.4 else BaseMaterial3D.TRANSPARENCY_DISABLED
			_material.albedo_color.a = clampf((_end - _t) / 0.4, 0.0, 1.0)
			for i in _items.size():
				var it: Array = _items[i]
				var v: Vector3 = it[1]
				var pos: Vector3 = it[0] + v * _t + Vector3.DOWN * 4.9 * _t * _t
				pos.y = maxf(pos.y, _base_y + 0.03)
				var spin: Vector3 = it[3] * _t
				_mm.set_instance_transform(i, Transform3D(Basis.from_euler(spin).scaled(Vector3.ONE * float(it[2])), pos))


## Builds the shared meshes now rather than on the first slam.
static func prewarm() -> void:
	_thorn()
	_spike()
	_rock()
	_shard()


static func _thorn() -> Mesh:
	if _thorn_mesh == null:
		_thorn_mesh = _cone(0.09, 1.2)
	return _thorn_mesh


static func _spike() -> Mesh:
	if _spike_mesh == null:
		_spike_mesh = _cone(0.16, 0.8)
	return _spike_mesh


## A cone standing on its base at the origin, point up.
static func _cone(radius: float, tall: float) -> Mesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = tall
	cone.radial_segments = 5
	cone.rings = 1
	cone.cap_top = false
	# CylinderMesh is centred: lift it so the base sits at y = 0.
	var st := SurfaceTool.new()
	st.create_from(cone, 0)
	st.generate_normals()
	var raw := st.commit()
	var arrays := raw.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i].y += tall * 0.5
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _rock() -> Mesh:
	if _rock_mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		_rock_mesh = box
	return _rock_mesh


## Each row as it comes up: grit flung up off it and a puff of dust (no
## ring), and a crunch now and then.
func _burst_rows() -> void:
	var into := get_parent()
	var across := Vector3(-_ahead.z, 0.0, _ahead.x)
	for row: Array in _rows:
		if bool(row[2]) or _t < float(row[1]):
			continue
		row[2] = true
		var d := float(row[0])
		var at := _from + _ahead * d
		var width := wave_width(d)
		SkillFx.particles(into, at + Vector3.UP * 0.2, {
			"amount": 8, "life": 0.7, "one_shot": true, "explosiveness": 0.95, "add": false,
			"speed": Vector2(1.5, 4.5), "dir": Vector3.UP, "spread": 40.0, "gravity": Vector3(0, -12, 0),
			"damping": 0.5, "size": Vector2(0.05, 0.11), "box": across * width * 0.4 + Vector3(0.1, 0.05, 0.1),
			"colors": [Color(0.45, 0.4, 0.35, 1.0), Color(0.42, 0.37, 0.32, 1.0), Color(0.4, 0.36, 0.32, 0.0)],
		})
		SkillFx.particles(into, at + Vector3.UP * 0.25, {
			"amount": 5, "life": 1.1, "one_shot": true, "explosiveness": 0.8, "add": false,
			"speed": Vector2(0.4, 1.3), "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, 0.3, 0),
			"damping": 1.2, "size": Vector2(0.4, 0.8), "grow": 0.3,
			"box": across * width * 0.45 + Vector3(0.2, 0.1, 0.2),
			"colors": [Color(0.6, 0.55, 0.48, 0.0), Color(0.58, 0.53, 0.46, 0.35), Color(0.55, 0.5, 0.45, 0.0)],
		})
		if fmod(d, 1.8) < 0.45:
			ImpactFx.thud(self, at, d < 1.5)


## The end: chips of it spill off as it goes down.
func _crumble() -> void:
	var into := get_parent()
	for row: Array in _rows:
		var d := float(row[0])
		if fmod(d, 1.35) > 0.45:
			continue
		var at := _from + _ahead * d
		SkillFx.particles(into, at + Vector3.UP * 0.4, {
			"amount": 6, "life": 0.9, "one_shot": true, "explosiveness": 0.6, "add": false,
			"speed": Vector2(0.3, 1.4), "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -9, 0),
			"size": Vector2(0.05, 0.1), "sphere": 0.4 * wave_width(d) * 0.5,
			"colors": [Color(0.42, 0.38, 0.34, 1.0), Color(0.4, 0.36, 0.32, 0.0)],
		})


## A broken shard of stone: an uneven six-sided foot narrowing to a split
## point, flat-faced, dark at the foot and paler up to its broken top.
static func _shard() -> Mesh:
	if _shard_mesh != null:
		return _shard_mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var foot: Array[Vector3] = []
	var waist: Array[Vector3] = []
	var sides := 6
	for i in sides:
		var a := TAU * float(i) / float(sides) + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(0.14, 0.2)
		foot.append(Vector3(cos(a) * r, -0.05, sin(a) * r))
		waist.append(Vector3(cos(a + 0.15) * r * 0.62, 0.55, sin(a + 0.15) * r * 0.62))
	var tips: Array[Vector3] = [Vector3(0.03, 1.0, -0.01), Vector3(-0.04, 0.86, 0.04)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flat faces: each its own normal.
	st.set_smooth_group(-1)
	# The golem's own stone, dark at the foot, paler up to the break.
	var low := Color(0.22, 0.23, 0.26)
	var mid := Color(0.42, 0.44, 0.49)
	var high := Color(0.6, 0.63, 0.69)
	var tri := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		for v: Vector3 in [a, b, c]:
			st.set_color(low.lerp(mid, clampf(v.y / 0.55, 0.0, 1.0)) if v.y < 0.55 else mid.lerp(high, clampf((v.y - 0.55) / 0.45, 0.0, 1.0)))
			st.add_vertex(v)
	for i in sides:
		var j := (i + 1) % sides
		tri.call(foot[i], waist[i], foot[j])
		tri.call(foot[j], waist[i], waist[j])
		var tip: Vector3 = tips[0] if i < sides / 2 else tips[1]
		tri.call(waist[i], tip, waist[j])
	# Where the two halves of the point meet.
	tri.call(waist[0], tips[1], tips[0])
	tri.call(waist[sides / 2], tips[0], tips[1])
	st.generate_normals()
	_shard_mesh = st.commit()
	return _shard_mesh
