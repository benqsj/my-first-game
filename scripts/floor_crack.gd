class_name FloorCrack
extends Node3D
## The floor of the marble world breaks where a heavy blow comes down into it
## (2026-10-30, the user's word: when a boss or a hero strikes the floor it
## should crack). Called from [method GroundFx.weapon_dust] and
## [method GroundFx.eruption], so every ground blow that throws dust also
## breaks the floor, on every peer (both are drawn by every peer).
##
## The tiles round the blow buckle: the one struck is driven in, the ones
## round it are broken loose and stand tilted, their edges up; dark cracks
## run out between them (a decal kept a hand high so it does not climb
## anyone's feet). They lie [constant LIE] s and sink back into the floor.
## Not round: the slabs lie at random, more of them near the middle, and the
## cracks run out in a few uneven lines (no ring on the ground).

const LIE := 6.0
const SINK := 1.2
## Below this a blow only throws dust.
const LEAST := 0.9
## A blow this near a fresh one (metres, seconds) breaks no more floor.
const NEAR := 1.2
const FRESH := 0.4
const TOP := Color(0.55, 0.52, 0.48)
const SIDE := Color(0.36, 0.34, 0.31)
const CRACK_TEX := "res://assets/fx/crack/crack_%d.png"
const CRACK_N := "res://assets/fx/crack/crack_%d_n.png"
const LINE_TEX := "res://assets/fx/crack/crack_line_%d.png"
const LINE_N := "res://assets/fx/crack/crack_line_%d_n.png"
## Broken tiles thrown up round the blow (off: the user wants cracks only).
const SLABS := false
const RUN_OUT := 0.14

static var _slabs: Array[ArrayMesh] = []
static var _top: StandardMaterial3D
static var _side: StandardMaterial3D
static var _recent: Array = []

## [mesh instance, rest transform, rise (m)]
var _laid: Array = []
var _t := 0.0
var _decal: Decal
var _span := 1.0
## Long cracks this much of a floor's (a blade on a wall: shorter).
var _line_scale := 1.0
## [decal, length, width, delay]: long cracks running out
var _longs: Array = []
var _base_y := 0.0


## A blade struck a wall, a tree, a pillar, a rock at `where` (its face
## turned `normal`): the same cracks laid on it, smaller (the user,
## 2026-10-30: the floor's cracks on everything struck).
static func surface(into: Node, where: Vector3, normal: Vector3, power: float) -> FloorCrack:
	if into == null or not (into is Node3D) or not live():
		return null
	var now := Time.get_ticks_msec() / 1000.0
	_recent = _recent.filter(func(r: Array) -> bool: return now - float(r[1]) < FRESH)
	for r in _recent:
		if (r[0] as Vector3).distance_to(where) < 0.3:
			return null
	_recent.append([where, now])
	var it := FloorCrack.new()
	it.name = "SurfaceCrack"
	into.add_child(it)
	var up := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
	it.global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), where)
	it._line_scale = 0.35 * power
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(where.x * 20.0), roundi(where.y * 20.0), roundi(where.z * 20.0)))
	it._crack_decal(rng, 0.38 * power)
	return it


## Breaks the floor at `at` (on it, or a little above), `power` ~1 a club,
## ~1.6 a troll's slam.
static func at(into: Node, where: Vector3, power: float) -> FloorCrack:
	if into == null or not (into is Node3D) or power < LEAST:
		return null
	if not StoneCrack.live():
		return null
	var now := Time.get_ticks_msec() / 1000.0
	_recent = _recent.filter(func(r: Array) -> bool: return now - float(r[1]) < FRESH)
	for r in _recent:
		if (r[0] as Vector3).distance_to(where) < NEAR:
			return null
	_recent.append([where, now])
	var space := (into as Node3D).get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(where + Vector3.UP * 0.6, where + Vector3.DOWN * 3.0, 1))
	if down.is_empty():
		return null
	var floor_at: Vector3 = down["position"]
	var normal: Vector3 = down["normal"]
	if normal.y < 0.7:
		return null
	var it := FloorCrack.new()
	it.name = "FloorCrack"
	into.add_child(it)
	it.global_position = floor_at
	it._base_y = floor_at.y
	it._build(clampf(power, LEAST, 2.4), floor_at)
	return it


## Whether the floor breaks at all now (the marble world is on).
static func live() -> bool:
	return StoneCrack.live()


## A broken tile's shape, for others' flying grit ([GroundFx]'s eruption):
## not a box.
static func chunk() -> Mesh:
	_assets()
	return _slabs[1]


static func _assets() -> void:
	if not _slabs.is_empty():
		return
	_top = StandardMaterial3D.new()
	_top.albedo_color = TOP
	_top.roughness = 0.9
	_side = StandardMaterial3D.new()
	_side.albedo_color = SIDE
	_side.roughness = 1.0
	# both faces drawn: the slab's faces are laid without caring which way
	# they wind (its top showed its dark underside)
	_top.cull_mode = BaseMaterial3D.CULL_DISABLED
	_side.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in 6:
		_slabs.append(_slab(rng))


## One broken tile: an uneven 5-7 sided slab a metre across, 0.35 thick, its
## top faceted from a middle a little raised; top and sides apart.
static func _slab(rng: RandomNumberGenerator) -> ArrayMesh:
	var n := rng.randi_range(5, 7)
	var ring: Array[Vector3] = []
	var a0 := rng.randf() * TAU
	for i in n:
		var a := a0 + TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(n)
		var r := rng.randf_range(0.36, 0.55)
		ring.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var mid := Vector3(rng.randf_range(-0.06, 0.06), 0.04, rng.randf_range(-0.06, 0.06))
	var top := PackedVector3Array()
	var top_n := PackedVector3Array()
	for i in n:
		var p := ring[i]
		var q := ring[(i + 1) % n]
		var f := (q - mid).cross(p - mid).normalized()
		if f.y < 0.0:
			f = -f
		for v in [mid, q, p]:
			top.append(v as Vector3)
			top_n.append(f)
	var sides := PackedVector3Array()
	var sides_n := PackedVector3Array()
	var down := Vector3.DOWN * 0.35
	for i in n:
		var p := ring[i]
		var q := ring[(i + 1) % n]
		var f := Vector3((p.x + q.x) * 0.5, 0.0, (p.z + q.z) * 0.5).normalized()
		for v in [p, q, q + down * 1.08, p, q + down * 1.08, p + down * 0.95]:
			sides.append(v as Vector3)
			sides_n.append(f)
	var mesh := ArrayMesh.new()
	for part in [[top, top_n], [sides, sides_n]]:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = part[0]
		arr[Mesh.ARRAY_NORMAL] = part[1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _top)
	mesh.surface_set_material(1, _side)
	return mesh


func _build(power: float, floor_at: Vector3) -> void:
	_assets()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(floor_at.x * 20.0), roundi(floor_at.y * 20.0), roundi(floor_at.z * 20.0)))
	var reach := 0.9 * power
	# (the user, 2026-10-30: cracks only, no tiles thrown up) the slabs below
	# are kept for later, not laid
	if not SLABS:
		_crack_decal(rng, reach)
		return
	# the struck one, driven in
	_lay(rng, Vector3.ZERO, 0.5 * power, -0.07 * power, rng.randf_range(4.0, 9.0), Vector3.ZERO)
	# the ones round it, broken loose: nearer the middle more of them, tilted
	# up on their outer edge
	var count := clampi(roundi(5.0 * power), 4, 11)
	for i in count:
		var a := rng.randf() * TAU
		var r := reach * sqrt(rng.randf_range(0.12, 1.0))
		var pos := Vector3(cos(a), 0.0, sin(a)) * r
		var away := pos.normalized()
		var size := rng.randf_range(0.3, 0.46) * power * (1.15 - r / reach * 0.4)
		var lift := rng.randf_range(0.06, 0.16) * power * (1.25 - r / reach * 0.8)
		var tilt := rng.randf_range(18.0, 38.0) * (1.2 - r / reach * 0.5)
		_lay(rng, pos, size, lift, tilt, away)
	_crack_decal(rng, reach)


## Dark cracks run out over the floor from the blow, sunk in it (a normal
## map), opening out in [constant RUN_OUT] s.
func _crack_decal(rng: RandomNumberGenerator, reach: float) -> void:
	# (the user, 2026-10-30) not the same each time: now a lone crack line
	# running out 1 to 7 m, now two, now the star as it was, now a big one
	var roll := rng.randf()
	# (the user: bigger cracks, now big, now small)
	var star := lerpf(0.6, 2.6, pow(rng.randf(), 1.3))
	var lines: Array = []
	if roll < 0.3:
		star *= 0.4
		lines = [_line_length(rng) * _line_scale]
	elif roll < 0.45:
		star *= 0.45
		lines = [_line_length(rng) * _line_scale, _line_length(rng) * _line_scale]
	elif roll < 0.8:
		for i in rng.randi_range(0, 2):
			lines.append(_line_length(rng) * _line_scale * 0.6)
	else:
		star = maxf(star, 1.8)
		for i in rng.randi_range(2, 3):
			lines.append(_line_length(rng) * _line_scale)
	_decal = Decal.new()
	_decal.texture_albedo = load(CRACK_TEX % rng.randi_range(1, 3)) as Texture2D
	_decal.texture_normal = load(CRACK_N % rng.randi_range(1, 3)) as Texture2D
	_decal.modulate = Color(0.5, 0.46, 0.42)
	_span = reach * 2.6 * star
	_decal.size = Vector3(_span * 0.3, 0.3, _span * 0.3)
	_decal.upper_fade = 0.3
	_decal.lower_fade = 0.3
	_decal.normal_fade = 0.5
	add_child(_decal)
	_decal.position = Vector3.UP * 0.05
	_decal.rotation.y = rng.randf() * TAU
	var way := rng.randf() * TAU
	for length in lines:
		var long := Decal.new()
		var kind := rng.randi_range(1, 3)
		long.texture_albedo = load(LINE_TEX % kind) as Texture2D
		long.texture_normal = load(LINE_N % kind) as Texture2D
		long.modulate = _decal.modulate
		long.size = Vector3(0.01, 0.3, 0.01)
		long.upper_fade = 0.3
		long.lower_fade = 0.3
		long.normal_fade = 0.5
		add_child(long)
		long.position = Vector3.UP * 0.05
		long.rotation.y = -way
		# its width grows a little with its length
		_longs.append([long, float(length), clampf(float(length) * 0.13, 0.25, 0.9), rng.randf_range(0.02, 0.08)])
		# the next one off another way (two: roughly opposite)
		way += PI + rng.randf_range(-0.9, 0.9) if lines.size() == 2 else rng.randf_range(1.2, 2.6)


## How far a lone crack runs: mostly a metre or three, now and then six or
## seven.
static func _line_length(rng: RandomNumberGenerator) -> float:
	return lerpf(1.2, 9.0, pow(rng.randf(), 1.5))


## A slab at `pos` (from the middle, on the floor), `size` across, its top
## `lift` above the floor (under it if less than 0), leant `tilt` degrees with
## its edge towards `away` up.
func _lay(rng: RandomNumberGenerator, pos: Vector3, size: float, lift: float, tilt: float, away: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _slabs[rng.randi_range(0, _slabs.size() - 1)]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if size > 0.25 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var axis := Vector3.UP.cross(away).normalized() if away.length_squared() > 0.001 \
			else Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)).normalized()
	var turn := Basis(axis, deg_to_rad(tilt)) * Basis(Vector3.UP, rng.randf() * TAU)
	turn = turn.scaled(Vector3(size, size * rng.randf_range(0.8, 1.1), size))
	var rest := Transform3D(turn, pos + Vector3.UP * lift)
	# it bursts up out of the floor and settles in a blink
	mi.transform = Transform3D(turn, pos + Vector3.DOWN * 0.3 * size)
	_laid.append([mi, rest, rng.randf_range(0.0, 0.05)])


func _process(delta: float) -> void:
	_t += delta
	for l in _laid:
		var mi := l[0] as MeshInstance3D
		var rest: Transform3D = l[1]
		var start := float(l[2])
		var k := clampf((_t - start) / 0.1, 0.0, 1.0)
		var over := sin(k * PI) * 0.06 * rest.basis.get_scale().x
		var t := rest
		if k < 1.0:
			t.origin = rest.origin + Vector3.UP * over - Vector3.UP * (1.0 - k) * 0.3 * rest.basis.get_scale().x
		if _t > LIE:
			var s := clampf((_t - LIE) / SINK, 0.0, 1.0)
			t.origin.y -= s * s * 0.5 * rest.basis.get_scale().x + s * 0.05
		mi.transform = t
	if _decal != null and _t < RUN_OUT + 0.05:
		var k := clampf(_t / RUN_OUT, 0.0, 1.0)
		var w := _span * lerpf(0.3, 1.0, 1.0 - (1.0 - k) * (1.0 - k))
		_decal.size = Vector3(w, 0.3, w)
	for l in _longs:
		var d := l[0] as Decal
		if _t > LIE:
			d.modulate.a = clampf(1.0 - (_t - LIE) / SINK, 0.0, 1.0)
		var k := clampf((_t - float(l[3])) / maxf(RUN_OUT * 2.0, float(l[1]) * 0.06), 0.0, 1.0)
		if k <= 0.0:
			continue
		var e := 1.0 - (1.0 - k) * (1.0 - k)
		# it runs out from the middle: grows along its way, moving out with it
		d.size = Vector3(float(l[1]) * e, 0.3, float(l[2]))
		var dir := Vector3(cos(-d.rotation.y), 0.0, sin(-d.rotation.y))
		d.position = dir * float(l[1]) * e * 0.5 + Vector3.UP * 0.05
	if _t > LIE and _decal != null:
		_decal.modulate.a = clampf(1.0 - (_t - LIE) / SINK, 0.0, 1.0)
	if _t > LIE + SINK:
		queue_free()
