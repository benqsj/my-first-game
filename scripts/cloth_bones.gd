class_name ClothBones
extends SkeletonModifier3D

## A cloak of real cloth on a model that came with its cloak as a mesh: the
## model's own cloak, textured as it was made, weighted to a grid of bones
## (`clk_<row>_<col>`, built by vepxis-art/tools/wr_build.py), and those bones
## hung here as one sheet of cloth.
##
## The same cloth as [ClothCape] (Verlet at a fixed 60 steps a second: speed,
## gravity, the air's drag towards a breeze; then the lengths along, across,
## the diagonals and every other row put back; pushed out of capsules round
## the body and the legs; drawn a little towards its drape), but instead of a
## sheet of its own it moves the bones the cloak's mesh is skinned to: each
## bone is put where its point is, turned as the cloth round it has turned.
## The top row is sewn on to the shoulders (it rides `anchor`).
##
## Runs after the clips have posed the skeleton (and after the legs'
## stride), so it hangs over the body as it actually stands. Purely for show:
## every peer hangs its own.

const STEP := 1.0 / 60.0
const GRAVITY := Vector3(0.0, -9.8, 0.0)
const ITERATIONS := 5

## The bone the cloak is sewn to.
var anchor_bone: String = "spine_03"
## How hard each row keeps its drape (0 the top .. 1 the hem): strong up
## by the shoulders, nearly free at the hem.
var hold_top: float = 0.35
var hold_hem: float = 0.02
## The air's drag, and how much the breeze moves it.
var drag: float = 0.9
var wind: float = 0.6
## Capsules the cloth is kept out of: [bone_a, bone_b, radius].
var colliders: Array = [
	["pelvis", "spine_02", 0.2], ["spine_02", "neck_01", 0.2],
	["thigh_l", "calf_l", 0.13], ["thigh_r", "calf_r", 0.13],
	["calf_l", "foot_l", 0.1], ["calf_r", "foot_r", 0.1],
	["upperarm_l", "lowerarm_l", 0.09], ["upperarm_r", "lowerarm_r", 0.09],
]

var _rows := 0
var _cols := 0
var _bones := PackedInt32Array()
var _anchor := -1
## Each point's rest in the anchor's rest frame, its rest basis in the
## skeleton, and the rest frame of the sheet round it.
var _rel := PackedVector3Array()
var _rest_basis: Array[Basis] = []
var _rest_frame: Array[Basis] = []
var _p := PackedVector3Array()
var _pp := PackedVector3Array()
var _links := PackedInt32Array()
var _lengths := PackedFloat32Array()
var _hold := PackedFloat32Array()
var _caps: Array = []
var _acc := 0.0
var _clock := 0.0
var _seed := 0.0
var _started := false
var _last_anchor := Vector3.ZERO
var _last_ms := -1
## How far the hem has travelled since the start, for the tests.
var hem_travel := 0.0


func _ready() -> void:
	active = true
	_seed = randf() * 100.0


## Finds the grid of bones; false when the skeleton has none.
func setup(skel: Skeleton3D) -> bool:
	var grid := {}
	for b in skel.get_bone_count():
		var n := skel.get_bone_name(b)
		if n.begins_with("clk_"):
			var parts := n.split("_")
			var r := int(parts[1])
			var c := int(parts[2])
			grid[Vector2i(r, c)] = b
			_rows = maxi(_rows, r + 1)
			_cols = maxi(_cols, c + 1)
	_anchor = skel.find_bone(anchor_bone)
	if grid.is_empty() or _anchor < 0 or grid.size() != _rows * _cols:
		return false
	var a_inv := skel.get_bone_global_rest(_anchor).affine_inverse()
	_bones.resize(_rows * _cols)
	_rel.resize(_rows * _cols)
	for r in _rows:
		for c in _cols:
			var k := r * _cols + c
			_bones[k] = grid[Vector2i(r, c)]
			var rest := skel.get_bone_global_rest(_bones[k])
			_rel[k] = a_inv * rest.origin
			_rest_basis.append(rest.basis.orthonormalized())
	var pts := PackedVector3Array()
	for k in _bones.size():
		pts.append(skel.get_bone_global_rest(_bones[k]).origin)
	for k in _bones.size():
		_rest_frame.append(_frame(pts, k))
	_hold.resize(_rows * _cols)
	for r in _rows:
		var t := float(r) / float(_rows - 1)
		for c in _cols:
			_hold[r * _cols + c] = lerpf(hold_top, hold_hem, pow(t, 0.7))
	for r in _rows:
		for c in _cols:
			var k := r * _cols + c
			if c + 1 < _cols:
				_link(pts, k, k + 1)
			if r + 1 < _rows:
				_link(pts, k, k + _cols)
				if c + 1 < _cols:
					_link(pts, k, k + _cols + 1)
				if c > 0:
					_link(pts, k, k + _cols - 1)
			if r + 2 < _rows:
				_link(pts, k, k + 2 * _cols)
			if c + 2 < _cols:
				_link(pts, k, k + 2)
	for cap: Array in colliders:
		var a := skel.find_bone(String(cap[0]))
		var b := skel.find_bone(String(cap[1]))
		if a >= 0 and b >= 0:
			_caps.append([a, b, float(cap[2])])
	return true


func _link(pts: PackedVector3Array, a: int, b: int) -> void:
	_links.append(a)
	_links.append(b)
	_lengths.append(pts[a].distance_to(pts[b]))


## The sheet's own frame at point k: across it, down it, and out of it.
func _frame(pts: PackedVector3Array, k: int) -> Basis:
	var r := k / _cols
	var c := k % _cols
	var across := pts[r * _cols + mini(c + 1, _cols - 1)] - pts[r * _cols + maxi(c - 1, 0)]
	var down := pts[mini(r + 1, _rows - 1) * _cols + c] - pts[maxi(r - 1, 0) * _cols + c]
	var x := across.normalized()
	var y := (down - x * down.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or _bones.is_empty():
		return
	var now := Time.get_ticks_msec()
	var delta := 0.0 if _last_ms < 0 else float(now - _last_ms) / 1000.0
	_last_ms = now
	var to_world := skel.global_transform
	var frame := to_world * skel.get_bone_global_pose(_anchor)
	if not _started or frame.origin.distance_to(_last_anchor) > 2.0:
		_reset(frame)
	var from := _last_anchor
	_last_anchor = frame.origin
	_acc = minf(_acc + delta, STEP * 4.0)
	var steps := int(_acc / STEP)
	for n in steps:
		_acc -= STEP
		_clock += STEP
		var f := frame
		f.origin = from.lerp(frame.origin, float(n + 1) / float(steps))
		_step(skel, f)
	_apply(skel)


func _reset(frame: Transform3D) -> void:
	_p.resize(_rel.size())
	_pp.resize(_rel.size())
	for k in _rel.size():
		_p[k] = frame * _rel[k]
		_pp[k] = _p[k]
	_last_anchor = frame.origin
	_started = true


func _step(skel: Skeleton3D, frame: Transform3D) -> void:
	var dt2 := STEP * STEP
	var gust := 0.55 + 0.45 * sin(_clock * 0.9 + _seed) * sin(_clock * 0.37 + _seed * 2.0)
	var breeze := Vector3(0.6, 0.0, 0.35).normalized() * 1.4 * gust * wind
	var n := _p.size()
	for k in range(_cols, n):
		var v := (_p[k] - _pp[k]) / STEP
		var r := k / _cols
		var ripple := sin(_clock * 6.0 + float(r) * 0.9 + float(k % _cols) * 0.6 + _seed) \
				* 0.5 * wind * float(r) / float(_rows - 1)
		var acc := GRAVITY + (breeze - v) * drag + frame.basis.z.normalized() * ripple
		var np := _p[k] + (_p[k] - _pp[k]) * 0.985 + acc * dt2
		_pp[k] = _p[k]
		_p[k] = np
	for c in _cols:
		_p[c] = frame * _rel[c]
		_pp[c] = _p[c]
	for it in ITERATIONS:
		for l in _lengths.size():
			var a := _links[l * 2]
			var b := _links[l * 2 + 1]
			var d := _p[b] - _p[a]
			var span := d.length()
			if span < 0.00001:
				continue
			var diff := (span - _lengths[l]) / span
			var wa := 0.0 if a < _cols else 0.5
			var wb := 0.0 if b < _cols else 0.5
			var sum := wa + wb
			if sum <= 0.0:
				continue
			_p[a] += d * diff * (wa / sum)
			_p[b] -= d * diff * (wb / sum)
		_collide(skel)
	var floor_y := skel.global_position.y + 0.03
	for k in range(_cols, n):
		_p[k] = _p[k].lerp(frame * _rel[k], _hold[k])
		if _p[k].y < floor_y:
			_p[k].y = floor_y
	hem_travel += _p[n - 1].distance_to(_pp[n - 1])


func _collide(skel: Skeleton3D) -> void:
	var g := skel.global_transform
	for cap: Array in _caps:
		var a: Vector3 = g * skel.get_bone_global_pose(cap[0]).origin
		var b: Vector3 = g * skel.get_bone_global_pose(cap[1]).origin
		var rad: float = cap[2]
		var ab := b - a
		var ab2 := ab.length_squared()
		for k in range(_cols, _p.size()):
			var t := 0.0 if ab2 < 0.000001 else clampf((_p[k] - a).dot(ab) / ab2, 0.0, 1.0)
			var q := a + ab * t
			var d := _p[k] - q
			var dist := d.length()
			if dist < rad:
				_p[k] = q + (d / dist if dist > 0.00001 else Vector3.BACK) * rad


## Each bone where its point is, turned as the sheet round it has turned.
func _apply(skel: Skeleton3D) -> void:
	var inv := skel.global_transform.affine_inverse()
	var local := PackedVector3Array()
	local.resize(_p.size())
	for k in _p.size():
		local[k] = inv * _p[k]
	for k in _p.size():
		var turn := _frame(local, k) * _rest_frame[k].transposed()
		skel.set_bone_global_pose(_bones[k], Transform3D(turn * _rest_basis[k], local[k]))
