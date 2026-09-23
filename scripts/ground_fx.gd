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

enum Kind { WAVE, DEBRIS }

static var _thorn_mesh: Mesh
static var _spike_mesh: Mesh
static var _rock_mesh: Mesh

var _kind: int = Kind.WAVE
var _t: float = 0.0
var _end: float = 1.0
var _mm: MultiMesh
var _material: StandardMaterial3D
var _items: Array = []
var _base_y: float = 0.0


## Metres from the start the front of a wave has reached after `t` seconds.
static func wave_front(t: float) -> float:
	return t * WAVE_SPEED


## Width of a wave at `d` metres out.
static func wave_width(d: float, size: float = 1.0) -> float:
	return (0.7 + 0.32 * d) * size


static func wave(into: Node, from: Vector3, direction: Vector3, length: float,
		thin: bool, size: float = 1.0) -> GroundFx:
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
			var delay := d / WAVE_SPEED + rng.randf() * 0.05
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


static func eruption(into: Node, at: Vector3, size: float = 1.0) -> GroundFx:
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
	DustRing.burst(into, at, 0.9 * size)
	return fx


func _process(delta: float) -> void:
	_t += delta
	match _kind:
		Kind.WAVE, Kind.DEBRIS:
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
