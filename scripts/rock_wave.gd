class_name RockWave
extends Node3D

## The ground itself heaving up where a blow struck it and the heave running
## out all the way round (the ogre's great blow and its pounds; the user's word,
## 2026-10-11: "not spikes coming up one by one: the ground lifts itself", then
## "give the stones another look"). The ground round the blow breaks into
## crags of rock, ring on ring; as the front passes each is thrown up, tipped
## back, the crack under it glowing hot, chips of it flung off; it hangs a
## moment and drops back into its place, the glow dying, and is gone.
## All of it is a few [MultiMesh]es: the crags (three shapes), the glow under
## them, the chips.

## How quickly a crag is thrown up, how long it hangs there, how long it takes
## to drop back and settle, and how long it then lies flush before it is gone.
const RISE := 0.12
const HANG := 0.5
const DROP := 0.28
const LIE := 0.5
## The rings this wide (m, times `size`); a crag about this long round its
## ring; never more than this many on one ring.
const RING := 1.25
const ACROSS := 1.45
const MOST_ON_A_RING := 80
## How high a crag is thrown (m, times `size`): near the blow, at the edge.
const LIFT := Vector2(0.8, 0.3)
## How far it tips back (rad).
const TIP := 0.5
## How thick the rock is that breaks (m, times `size`).
const THICK := 0.5
## Chips flung off each crag as it goes up, how hard, and how they fall.
const CHIPS := 2
const FLING := Vector2(4.0, 8.0)
const FALL := 20.0
const PUFFS := 5
const PUFF_EVERY := 0.2
const SHAPES := 3

## The crags in each shape's MultiMesh, the glow under them, the chips.
var _crags: Array[MultiMeshInstance3D] = []
var _glow: MultiMeshInstance3D
var _chip_mm: MultiMeshInstance3D
## Each crag: [where it lies (top centre), its distance out, out (unit),
## [across, along, thick] size, how high it goes, how far it tips, its turn,
## its shape, its place in that shape's MultiMesh, its tint].
var _slabs: Array = []
## Each chip: [from, its velocity, when it is flung, its size, its turn axis].
var _chips: Array = []
var _shape_count: Array[int] = []
var _t: float = 0.0
var _pace: float = 22.0
var _radius: float = 10.0
var _size: float = 1.0
var _at := Vector3.ZERO
var _puff_t: float = 0.0
var _rng := RandomNumberGenerator.new()
static var _meshes: Array[Mesh] = []
static var _glow_mesh: Mesh = null
static var _material: StandardMaterial3D = null
static var _glow_material: StandardMaterial3D = null


## The ground heaving out from `at` to `radius` (m) at `pace` (m/s), its crags
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
	_shape_count.resize(SHAPES)
	_shape_count.fill(0)
	var ring := RING * _size
	var r0 := 0.45 * ring
	while r0 < _radius:
		var r1 := minf(r0 + ring, _radius)
		var mid := (r0 + r1) * 0.5
		var n := clampi(int(TAU * mid / (ACROSS * _size)), 4, MOST_ON_A_RING)
		var turn := _rng.randf() * TAU
		var arc := TAU * mid / float(n)
		for k in n:
			var a := turn + TAU * (float(k) + _rng.randf_range(-0.15, 0.15)) / float(n)
			var out := Vector3(sin(a), 0.0, cos(a))
			var near := clampf(mid / _radius, 0.0, 1.0)
			var lift := lerpf(LIFT.x, LIFT.y, near) * _size * _rng.randf_range(0.6, 1.3)
			var tip := TIP * _rng.randf_range(0.4, 1.15) * lerpf(1.0, 0.6, near)
			# cracks between them: a little short of the cell each way
			var dims := Vector3(arc * _rng.randf_range(0.8, 0.93), THICK * _size * _rng.randf_range(0.8, 1.25),
					(r1 - r0) * _rng.randf_range(0.78, 0.92))
			var shape := _rng.randi() % SHAPES
			var v := _rng.randf_range(0.82, 1.12)
			var tint := Color(v * _rng.randf_range(0.96, 1.04), v, v * _rng.randf_range(0.94, 1.02))
			var place := _at + out * (mid + _rng.randf_range(-0.08, 0.08) * ring)
			_slabs.append([place, mid, out, dims, lift, tip, _rng.randf_range(-0.12, 0.12), shape,
					_shape_count[shape], tint])
			_shape_count[shape] += 1
			# chips flung off it as it goes up
			for c in CHIPS:
				var side := out.cross(Vector3.UP).normalized() * _rng.randf_range(-0.4, 0.4)
				var vel := (out + side).normalized() * _rng.randf_range(1.0, 3.0) * sqrt(_size) \
						+ Vector3.UP * _rng.randf_range(FLING.x, FLING.y) * sqrt(_size) * lerpf(1.0, 0.6, near)
				var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
				if axis.length() < 0.1:
					axis = Vector3.RIGHT
				_chips.append([place + Vector3.UP * 0.2, vel, mid / _pace + RISE * 0.5,
						_size * _rng.randf_range(0.18, 0.38), axis.normalized()])
		r0 = r1
	for s in SHAPES:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _crag_mesh(s)
		mm.instance_count = _shape_count[s]
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _crag_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		_crags.append(mi)
	var gm := MultiMesh.new()
	gm.transform_format = MultiMesh.TRANSFORM_3D
	gm.use_colors = true
	gm.mesh = _crack_mesh()
	gm.instance_count = _slabs.size()
	_glow = MultiMeshInstance3D.new()
	_glow.multimesh = gm
	_glow.material_override = _crack_material()
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.use_colors = true
	cm.mesh = _crag_mesh(0)
	cm.instance_count = _chips.size()
	_chip_mm = MultiMeshInstance3D.new()
	_chip_mm.multimesh = cm
	_chip_mm.material_override = _crag_material()
	_chip_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chip_mm)
	for i in _chips.size():
		cm.set_instance_color(i, Color(0.8, 0.78, 0.76))
	_place()


## A crag of broken rock: one unit across, along and thick, its top about 0 —
## a craggy top of grey stone, peaked and faceted, with earth on its rim, its
## broken sides darker down to an underside still red from the heat.
static func _crag_mesh(which: int) -> Mesh:
	if _meshes.size() == SHAPES:
		return _meshes[which]
	_meshes.clear()
	for s in SHAPES:
		_meshes.append(_build_crag(s))
	return _meshes[which]


static func _build_crag(which: int) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5113 + which * 977
	var earth := Color(0.4, 0.33, 0.25)
	var stone_hi := Color(0.58, 0.56, 0.53)
	var stone := Color(0.42, 0.4, 0.38)
	var stone_lo := Color(0.2, 0.18, 0.17)
	var hot := Color(0.55, 0.16, 0.05)
	var n := 7 + which
	# the rim, squared off towards a box and broken; an inner ring raised
	# into crags; a peak off the middle
	var rim: Array[Vector3] = []
	var inner: Array[Vector3] = []
	for k in n:
		var a := TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / float(n)
		var p := Vector3(cos(a), 0.0, sin(a))
		p = p / maxf(absf(p.x), absf(p.z)) * 0.5 * rng.randf_range(0.82, 1.0)
		p.y = rng.randf_range(-0.05, 0.03)
		rim.append(p)
		var q := Vector3(p.x * rng.randf_range(0.45, 0.65), rng.randf_range(0.04, 0.14), p.z * rng.randf_range(0.45, 0.65))
		inner.append(q)
	var peak := Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0.14, 0.22), rng.randf_range(-0.12, 0.12))
	for k in n:
		var j := (k + 1) % n
		# the rim band: earth at the edge, stone going up
		_tri(st, [rim[k], rim[j], inner[j]], [earth, earth, stone])
		_tri(st, [rim[k], inner[j], inner[k]], [earth, stone, stone])
		# the crags up to the peak
		var lit: Color = stone_hi if (k % 2 == 0) else stone
		_tri(st, [inner[k], inner[j], peak], [stone, stone, lit])
	# the broken sides, down to an underside, narrowing, red at the bottom
	for k in n:
		var j := (k + 1) % n
		var a := rim[k]
		var b := rim[j]
		var a2 := Vector3(a.x * 0.7, -1.0 + rng.randf_range(-0.1, 0.1), a.z * 0.7)
		var b2 := Vector3(b.x * 0.7, -1.0, b.z * 0.7)
		var am := (a + a2) * 0.5 + Vector3(a.x, 0.0, a.z) * 0.12
		var bm := (b + b2) * 0.5 + Vector3(b.x, 0.0, b.z) * 0.12
		_tri(st, [a, am, b], [stone, stone_lo, stone])
		_tri(st, [b, am, bm], [stone, stone_lo, stone_lo])
		_tri(st, [am, a2, bm], [stone_lo, hot, stone_lo])
		_tri(st, [bm, a2, b2], [stone_lo, hot, hot])
	var bottom := Vector3(0.0, -1.05, 0.0)
	for k in n:
		var j := (k + 1) % n
		var a2 := Vector3(rim[k].x * 0.7, -1.0, rim[k].z * 0.7)
		var b2 := Vector3(rim[j].x * 0.7, -1.0, rim[j].z * 0.7)
		_tri(st, [a2, bottom, b2], [hot, hot, hot])
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, points: Array, colors: Array) -> void:
	# wound so the faces look outward either way (the material shows both)
	for i in 3:
		st.set_color(colors[i])
		st.add_vertex(points[i])


## The crack under a crag, hot: a jagged star of bright fissures out from its
## middle, dark at their ends (it is added on, so dark is nothing).
static func _crack_mesh() -> Mesh:
	if _glow_mesh != null:
		return _glow_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 881
	var core := Color(1.0, 0.55, 0.15)
	var dim := Color(0.5, 0.12, 0.02)
	var none := Color(0.0, 0.0, 0.0)
	# a soft glow over the whole pit
	var n := 10
	for k in n:
		var a := TAU * float(k) / float(n)
		var b := TAU * float(k + 1) / float(n)
		for pc: Array in [[Vector3.ZERO, dim], [Vector3(cos(b), 0, sin(b)) * 0.55, none], [Vector3(cos(a), 0, sin(a)) * 0.55, none]]:
			st.set_color(pc[1])
			st.add_vertex(pc[0])
	# the fissures, each a thin broken line out, a little above the glow
	for k in 7:
		var a := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / 7.0
		var p := Vector3(0.0, 0.01, 0.0)
		var w := 0.07
		var bright := core
		for seg in 3:
			a += rng.randf_range(-0.5, 0.5)
			var q := p + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.14, 0.22)
			var side := Vector3(-sin(a), 0.0, cos(a)) * w
			var w2 := w * 0.6
			var side2 := Vector3(-sin(a), 0.0, cos(a)) * w2
			var next := bright.lerp(none, 0.45)
			for pc: Array in [[p - side, bright], [q + side2, next], [p + side, bright],
					[p - side, bright], [q - side2, next], [q + side2, next]]:
				st.set_color(pc[1])
				st.add_vertex(pc[0])
			p = q
			w = w2
			bright = next
	_glow_mesh = st.commit()
	return _glow_mesh


static func _crag_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.92
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


static func _crack_material() -> StandardMaterial3D:
	if _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.vertex_color_use_as_albedo = true
		_glow_material.vertex_color_is_srgb = true
		_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glow_material.no_depth_test = false
		_glow_material.albedo_color = Color(2.2, 2.2, 2.2)
	return _glow_material


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


## Every crag where it is: lying unbroken (not shown) till the front comes,
## thrown up and tipped back over its glowing crack, hanging, dropped back
## flush with a little bounce, lying there, then gone into the ground it is;
## and every chip in its flight.
func _place() -> void:
	var hidden := Basis().scaled(Vector3(0.001, 0.001, 0.001))
	var gm := _glow.multimesh
	for i in _slabs.size():
		var s: Array = _slabs[i]
		var mm := _crags[int(s[7])].multimesh
		var slot := int(s[8])
		var u := _t - float(s[1]) / _pace
		var dims: Vector3 = s[3]
		if u <= 0.0 or u > RISE + HANG + DROP + LIE:
			mm.set_instance_transform(slot, Transform3D(hidden, s[0]))
			gm.set_instance_transform(i, Transform3D(hidden, s[0]))
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
			lift = 1.0 - 0.2 * k * k
			tip = 1.0 - 0.3 * k
		elif u < RISE + HANG + DROP:
			var k := (u - RISE - HANG) / DROP
			# dropped back, a little bounce at the end
			lift = 0.8 * (1.0 - k * k) + 0.06 * sin(k * PI) * k
			tip = 0.7 * (1.0 - k)
		var out: Vector3 = s[2]
		var along := out.cross(Vector3.UP).normalized()
		var yaw := Basis(Vector3.UP, atan2(out.x, out.z) + float(s[6]))
		# its near edge up, as if pushed up from under the blow
		var bs := Basis(along, -float(s[5]) * tip) * yaw
		bs = bs * Basis.from_scale(dims)
		var place: Vector3 = s[0]
		place.y += float(s[4]) * lift + 0.02
		# lying back in its place it settles into the ground, crags and all
		if u > RISE + HANG + DROP:
			var k := (u - RISE - HANG - DROP) / LIE
			place.y -= dims.y * 0.3 * k * k
		mm.set_instance_transform(slot, Transform3D(bs, place))
		mm.set_instance_color(slot, s[9])
		# the crack under it glowing while it is up, dying as it drops
		var heat := clampf(u / (RISE * 0.6), 0.0, 1.0)
		if u > RISE + HANG:
			heat = clampf(1.0 - (u - RISE - HANG) / (DROP + 0.15), 0.0, 1.0)
		heat *= heat
		var foot := Vector3(dims.x, 1.0, dims.z) * 1.15
		gm.set_instance_transform(i, Transform3D(yaw * Basis.from_scale(foot), Vector3(place.x, _at.y + 0.04, place.z)))
		gm.set_instance_color(i, Color(heat, heat, heat, 1.0))
	var cm := _chip_mm.multimesh
	for i in _chips.size():
		var c: Array = _chips[i]
		var u := _t - float(c[2])
		var vel: Vector3 = c[1]
		var start: Vector3 = c[0]
		var at := start + vel * u + Vector3.DOWN * 0.5 * FALL * u * u
		if u <= 0.0 or at.y < _at.y - 0.1:
			cm.set_instance_transform(i, Transform3D(hidden, start))
			continue
		var sz := float(c[3])
		var spin := Basis(c[4] as Vector3, u * 9.0)
		cm.set_instance_transform(i, Transform3D(spin * Basis.from_scale(Vector3(sz, sz * 0.8, sz)), at))


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
			"colors": [Color(0.5, 0.47, 0.44, 0.0), Color(0.48, 0.45, 0.42, 0.5), Color(0.45, 0.43, 0.4, 0.0)],
		})
