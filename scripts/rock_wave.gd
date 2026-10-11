class_name RockWave
extends Node3D

## The ground itself heaving up where a blow struck it and the heave running
## out all the way round (the ogre's great blow and its pounds; the user's word,
## 2026-10-11: "not spikes coming up one by one: the ground lifts itself").
## The ground round the blow breaks into slabs, ring on ring; as the front
## passes each slab is thrown up and tipped back towards the blow, shows its
## broken earth sides, hangs a moment, and drops back flush into its place, a
## puff of grit off the front now and then. Near the blow they go up highest.
## All of it is one [MultiMesh] (one slab mesh, scaled to each cell).

## How quickly a slab is thrown up, how long it hangs there, how long it takes
## to drop back and settle, and how long it then lies flush before it is gone.
const RISE := 0.13
const HANG := 0.55
const DROP := 0.3
const LIE := 0.6
## The rings this wide (m, times `size`); a slab about this long round its
## ring; never more than this many on one ring.
const RING := 1.35
const ACROSS := 1.6
const MOST_ON_A_RING := 96
## How high a slab is thrown (m, times `size`): near the blow, at the edge.
const LIFT := Vector2(0.95, 0.35)
## How far it tips back (rad).
const TIP := 0.45
## How thick the ground is that breaks (m, times `size`).
const THICK := 0.45
const PUFFS := 6
const PUFF_EVERY := 0.2

var _mm: MultiMeshInstance3D
## Each slab: [where it lies (top centre), its distance out, out (unit),
## [across, along, thick] size, how high it goes, how far it tips, its turn].
var _slabs: Array = []
var _t: float = 0.0
var _pace: float = 22.0
var _radius: float = 10.0
var _size: float = 1.0
var _at := Vector3.ZERO
var _puff_t: float = 0.0
var _rng := RandomNumberGenerator.new()
static var _mesh: Mesh = null
static var _material: StandardMaterial3D = null


## The ground heaving out from `at` to `radius` (m) at `pace` (m/s), its slabs
## `size` times the plain; laid out by `seed_of` (the same on every peer).
static func spawn(into: Node, at: Vector3, radius: float, size: float = 1.0, pace: float = 22.0,
		seed_of: int = 0) -> RockWave:
	if into == null:
		return null
	var w := RockWave.new()
	w._at = at
	w._radius = maxf(radius, 1.0)
	w._size = maxf(size, 0.2)
	w._pace = maxf(pace, 1.0)
	w._rng.seed = seed_of * 7919 + 13
	into.add_child(w)
	w.global_position = Vector3.ZERO
	w._lay_out()
	return w


func _lay_out() -> void:
	var ring := RING * _size
	var r0 := 0.5 * ring
	var i := 0
	while r0 < _radius:
		var r1 := minf(r0 + ring, _radius)
		var mid := (r0 + r1) * 0.5
		var n := clampi(int(TAU * mid / (ACROSS * _size)), 4, MOST_ON_A_RING)
		var turn := _rng.randf() * TAU
		var arc := TAU * mid / float(n)
		for k in n:
			var a := turn + TAU * (float(k) + _rng.randf_range(-0.12, 0.12)) / float(n)
			var out := Vector3(sin(a), 0.0, cos(a))
			var near := clampf(mid / _radius, 0.0, 1.0)
			var lift := lerpf(LIFT.x, LIFT.y, near) * _size * _rng.randf_range(0.65, 1.25)
			var tip := TIP * _rng.randf_range(0.5, 1.1) * lerpf(1.0, 0.6, near)
			# cracks between them: a little short of the cell each way
			var dims := Vector3(arc * _rng.randf_range(0.86, 0.95), THICK * _size, (r1 - r0) * _rng.randf_range(0.84, 0.94))
			_slabs.append([_at + out * mid, mid, out, dims, lift, tip, _rng.randf_range(-0.08, 0.08)])
		r0 = r1
		i += 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _slab_mesh()
	mm.instance_count = _slabs.size()
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.material_override = _slab_material()
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mm)
	_place()


## A slab of broken ground: one unit across, along and thick, its top at 0 —
## a top of earth a little uneven at the edges, its broken sides dark below.
static func _slab_mesh() -> Mesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var top := Color(0.4, 0.35, 0.28)
	var side_hi := Color(0.36, 0.29, 0.22)
	var side_lo := Color(0.2, 0.16, 0.12)
	# the top, eight points round, a touch domed and ragged
	var rim: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4421
	for k in 8:
		var a := TAU * float(k) / 8.0 + PI / 8.0
		var p := Vector3(cos(a), 0.0, sin(a))
		# squared off towards a box, edges broken
		p = p / maxf(absf(p.x), absf(p.z)) * 0.5 * rng.randf_range(0.9, 1.0)
		p.y = rng.randf_range(-0.04, 0.0)
		rim.append(p)
	var centre := Vector3(0.0, 0.03, 0.0)
	for k in 8:
		var j := (k + 1) % 8
		for v: Vector3 in [centre, rim[j], rim[k]]:
			st.set_color(top)
			st.add_vertex(v)
	# the broken sides, down to the underside, narrowing a little
	for k in 8:
		var j := (k + 1) % 8
		var a := rim[k]
		var b := rim[j]
		var a2 := Vector3(a.x * 0.85, -1.0, a.z * 0.85)
		var b2 := Vector3(b.x * 0.85, -1.0, b.z * 0.85)
		for pair: Array in [[a, side_hi], [b, side_hi], [b2, side_lo], [a, side_hi], [b2, side_lo], [a2, side_lo]]:
			st.set_color(pair[1])
			st.add_vertex(pair[0])
	st.generate_normals()
	_mesh = st.commit()
	return _mesh


static func _slab_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.97
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


func _process(delta: float) -> void:
	_t += delta
	_place()
	_puff_t -= delta
	var front := _t * _pace
	if _puff_t <= 0.0 and front <= _radius:
		_puff_t = PUFF_EVERY
		_puff(front)
	if _t > _radius / _pace + RISE + HANG + DROP + LIE + 0.1:
		queue_free()


## Every slab where it is: lying unbroken (not shown) till the front comes,
## thrown up and tipped back, hanging, dropped back flush with a little bounce,
## lying there, then gone into the ground it is.
func _place() -> void:
	var mm := _mm.multimesh
	for i in _slabs.size():
		var s: Array = _slabs[i]
		var u := _t - float(s[1]) / _pace
		var dims: Vector3 = s[3]
		if u <= 0.0 or u > RISE + HANG + DROP + LIE:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), s[0]))
			continue
		var lift := 0.0
		var tip := 0.0
		if u < RISE:
			var k := u / RISE
			lift = 1.0 - (1.0 - k) * (1.0 - k)
			tip = lift
		elif u < RISE + HANG:
			var k := (u - RISE) / HANG
			# hanging, sagging a little, the tip easing
			lift = 1.0 - 0.18 * k * k
			tip = 1.0 - 0.3 * k
		elif u < RISE + HANG + DROP:
			var k := (u - RISE - HANG) / DROP
			# dropped back, a little bounce at the end
			lift = 0.82 * (1.0 - k * k) + 0.06 * sin(k * PI) * k
			tip = 0.7 * (1.0 - k)
		var out: Vector3 = s[2]
		var along := out.cross(Vector3.UP).normalized()
		# tipped back towards the blow: its far edge up
		var b := Basis(along, -float(s[5]) * tip) * Basis(Vector3.UP, atan2(out.x, out.z) + float(s[6]))
		b = b.scaled(Vector3(dims.x, dims.y, dims.z))
		var place: Vector3 = s[0]
		place.y += float(s[4]) * lift + 0.02
		mm.set_instance_transform(i, Transform3D(b, place))


## Grit and dust thrown up off the front, a few places round it.
func _puff(front: float) -> void:
	var into := get_parent()
	for i in PUFFS:
		var a := _rng.randf() * TAU
		var at := _at + Vector3(sin(a), 0.0, cos(a)) * maxf(front, 0.5) + Vector3.UP * 0.3
		SkillFx.particles(into, at, {
			"amount": 10, "life": 1.0, "one_shot": true, "explosiveness": 0.8, "add": false,
			"speed": Vector2(0.8, 2.6), "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -6.0, 0),
			"damping": 1.5, "size": Vector2(0.25, 0.55) * _size, "grow": 0.35, "sphere": 0.8 * _size,
			"colors": [Color(0.55, 0.49, 0.42, 0.0), Color(0.52, 0.47, 0.4, 0.55), Color(0.5, 0.45, 0.4, 0.0)],
		})
