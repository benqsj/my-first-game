class_name ClothCape
extends MeshInstance3D

## A cape of cloth: a sheet of points hung from the back of the shoulders that
## swings with the body, trails behind a run, is kicked by the legs and ripples
## in a light wind. It stands in for the capes the models used to carry as
## rigid pieces (and Tariel's spring-bone chain).
##
## Verlet, at a fixed 60 steps a second: each point keeps its own speed, is
## pulled down, dragged by the air and pushed by the wind; then the sheet's
## lengths are put back (along, across, the diagonals and every other point
## down, for a little stiffness), the points are pushed out of capsules round
## the trunk and the legs, and each is drawn a little towards where it hangs
## at rest on the anchor bone — strongly at the top, not at all at the hem —
## so the cape keeps its drape and never flies off in pieces.
##
## Purely for show: every peer hangs its own from the pose it sees. Drawn as
## one double-sided sheet in world space, rebuilt every frame.
##
## The spec (see `SkinnedRig.capes`), in the Blender model's own coordinates
## (x the character's left, -y forward, z up) so it can be read straight off
## the build scripts:
##   bone      the bone it hangs from
##   left      the top left corner, right the top right
##   length    down to the hem, metres
##   spread    how much wider the hem is than the top (1.0 the same)
##   flare     how far the hem stands off the back at rest, metres
##   wrap      how far its sides come round the body, metres, so it has a
##             curve to it and is not a flat board seen from the side
##   cols, rows    the sheet's points
##   base, hem, trim   colours; `pattern` "plain", "tiger" or "runes"
##   hold      how hard it keeps its drape (0..1), `wind` how much it ripples
##   colliders [[bone_a, bone_b, radius], ...] capsules, bone to bone

const STEP := 1.0 / 60.0
const GRAVITY := Vector3(0.0, -9.8, 0.0)
const ITERATIONS := 6

var spec: Dictionary = {}
var _skel: Skeleton3D
var _bone: int = -1
var _cols: int = 6
var _rows: int = 9
## Where each point hangs at rest, in the anchor bone's frame.
var _rest: PackedVector3Array = PackedVector3Array()
var _p: PackedVector3Array = PackedVector3Array()
var _pp: PackedVector3Array = PackedVector3Array()
## Pairs of point indices and the length between them.
var _links: PackedInt32Array = PackedInt32Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _hold: PackedFloat32Array = PackedFloat32Array()
var _caps: Array = []
var _acc: float = 0.0
var _clock: float = 0.0
var _last_anchor: Vector3 = Vector3.ZERO
var _started: bool = false
var _imesh: ImmediateMesh
var _seed: float = 0.0
## How far the hem has travelled since the start, for the tests.
var hem_travel: float = 0.0


## Hangs the cape on `skel` from `spec`. False if the bone is not there.
func setup(skel: Skeleton3D, cape: Dictionary) -> bool:
	spec = cape
	_skel = skel
	_bone = skel.find_bone(String(cape.get("bone", "spine_02")))
	if _bone < 0:
		return false
	_cols = int(cape.get("cols", 6))
	_rows = int(cape.get("rows", 9))
	_seed = randf() * 100.0
	var left := _b2g(cape["left"])
	var right := _b2g(cape["right"])
	var length := float(cape.get("length", 1.0))
	var spread := float(cape.get("spread", 1.2))
	var flare := float(cape.get("flare", 0.08))
	var wrap := float(cape.get("wrap", 0.1))
	var mid := (left + right) * 0.5
	var back := Vector3(0.0, 0.0, -1.0)  # Blender +y, behind the character
	# The sheet at rest, in skeleton space, then in the bone's rest frame.
	var inv := skel.get_bone_global_rest(_bone).affine_inverse()
	_rest.resize(_cols * _rows)
	for j in _rows:
		var t := float(j) / float(_rows - 1)
		for i in _cols:
			var s := float(i) / float(_cols - 1)
			var top := left.lerp(right, s)
			var across := (top - mid) * lerpf(1.0, spread, t)
			var side := (2.0 * s - 1.0) * (2.0 * s - 1.0)
			var p := mid + across + Vector3.DOWN * length * t + back * flare * sqrt(t) \
					- back * wrap * side * lerpf(1.0, 0.55, t)
			_rest[j * _cols + i] = inv * p
	var hold := float(cape.get("hold", 0.5))
	_hold.resize(_cols * _rows)
	for j in _rows:
		var t := float(j) / float(_rows - 1)
		for i in _cols:
			_hold[j * _cols + i] = hold * pow(1.0 - t, 2.2) * 0.5
	for j in _rows:
		for i in _cols:
			var k := j * _cols + i
			if i + 1 < _cols:
				_link(k, k + 1)
			if j + 1 < _rows:
				_link(k, k + _cols)
				if i + 1 < _cols:
					_link(k, k + _cols + 1)
				if i > 0:
					_link(k, k + _cols - 1)
			if j + 2 < _rows:
				_link(k, k + 2 * _cols)
	for c: Array in cape.get("colliders", []):
		var a := skel.find_bone(String(c[0]))
		var b := skel.find_bone(String(c[1]))
		if a >= 0 and b >= 0:
			_caps.append([a, b, float(c[2])])
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	material_override = _material()
	return true


## The Blender model's coordinates to the skeleton's (glTF, +y up).
static func _b2g(v: Variant) -> Vector3:
	var a: Array = v
	return Vector3(float(a[0]), float(a[2]), -float(a[1]))


## The middle of the hem, in the world.
func hem() -> Vector3:
	return _p[_p.size() - 1 - (_cols >> 1)] if not _p.is_empty() else global_position


func _link(a: int, b: int) -> void:
	_links.append(a)
	_links.append(b)
	_lengths.append(_rest[a].distance_to(_rest[b]))


func _anchor() -> Transform3D:
	return _skel.global_transform * _skel.get_bone_global_pose(_bone)


func _process(delta: float) -> void:
	if _skel == null or not is_instance_valid(_skel) or not _skel.is_inside_tree():
		return
	var frame := _anchor()
	if not _started or frame.origin.distance_to(_last_anchor) > 2.0:
		_reset(frame)
	var from := _last_anchor
	_last_anchor = frame.origin
	_acc = minf(_acc + delta, STEP * 4.0)
	var steps := int(_acc / STEP)
	for n in steps:
		_acc -= STEP
		_clock += STEP
		# The anchor between last frame's place and this one's, so a fast body
		# does not leave its cape a step behind in one jump.
		var along := float(n + 1) / float(steps)
		var f := frame
		f.origin = from.lerp(frame.origin, along)
		_step(f)
	_draw()


func _reset(frame: Transform3D) -> void:
	_p.resize(_rest.size())
	_pp.resize(_rest.size())
	for k in _rest.size():
		_p[k] = frame * _rest[k]
		_pp[k] = _p[k]
	_last_anchor = frame.origin
	_started = true


func _step(frame: Transform3D) -> void:
	var dt2 := STEP * STEP
	var damping := 0.02
	var drag := float(spec.get("drag", 0.6))
	var wind_amount := float(spec.get("wind", 1.0))
	# A light breeze that comes and goes, and a flutter that runs through it.
	var gust := 0.55 + 0.45 * sin(_clock * 0.9 + _seed) * sin(_clock * 0.37 + _seed * 2.0)
	var wind := Vector3(0.6, 0.0, 0.35).normalized() * 1.6 * gust * wind_amount
	var behind := frame.basis * Vector3(0.0, 0.0, -1.0)
	behind = behind.normalized()
	var floor_y := _skel.global_position.y + 0.02
	var n := _p.size()
	for j in range(1, _rows):
		for i in _cols:
			_move(j * _cols + i, j, i, wind, behind, drag, wind_amount, damping, dt2)
	# The top row is sewn on.
	for i in _cols:
		_p[i] = frame * _rest[i]
		_pp[i] = _p[i]
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
		_collide()
	# Its drape: each point drawn a little towards where it hangs at rest.
	for k in range(_cols, n):
		if _hold[k] > 0.0:
			_p[k] = _p[k].lerp(frame * _rest[k], _hold[k])
		if _p[k].y < floor_y:
			var q := _p[k]
			q.y = floor_y
			_p[k] = q
	hem_travel += _p[n - 1].distance_to(_pp[n - 1])


## One point's move: its own speed, gravity, the air's drag towards the
## wind, and a ripple that grows down the sheet.
func _move(k: int, j: int, i: int, wind: Vector3, behind: Vector3, drag: float, wind_amount: float,
		damping: float, dt2: float) -> void:
	var v := (_p[k] - _pp[k]) / STEP
	var ripple := sin(_clock * 7.0 + float(j) * 0.9 + float(i) * 0.6 + _seed) \
			* 0.9 * wind_amount * float(j) / float(_rows - 1)
	var acc := GRAVITY + (wind - v) * drag + behind * ripple
	var np := _p[k] + (_p[k] - _pp[k]) * (1.0 - damping) + acc * dt2
	_pp[k] = _p[k]
	_p[k] = np


func _collide() -> void:
	if _caps.is_empty():
		return
	var g := _skel.global_transform
	for c: Array in _caps:
		var a: Vector3 = g * _skel.get_bone_global_pose(c[0]).origin
		var b: Vector3 = g * _skel.get_bone_global_pose(c[1]).origin
		var r: float = c[2]
		var ab := b - a
		var ab2 := ab.length_squared()
		for k in range(_cols, _p.size()):
			var t := 0.0 if ab2 < 0.000001 else clampf((_p[k] - a).dot(ab) / ab2, 0.0, 1.0)
			var q := a + ab * t
			var d := _p[k] - q
			var dist := d.length()
			if dist < r:
				_p[k] = q + (d / dist if dist > 0.00001 else Vector3.BACK) * r


func _draw() -> void:
	_imesh.clear_surfaces()
	var normals := PackedVector3Array()
	normals.resize(_p.size())
	for j in _rows:
		for i in _cols:
			var k := j * _cols + i
			var dx := _p[j * _cols + mini(i + 1, _cols - 1)] - _p[j * _cols + maxi(i - 1, 0)]
			var dy := _p[mini(j + 1, _rows - 1) * _cols + i] - _p[maxi(j - 1, 0) * _cols + i]
			var nrm := dy.cross(dx)
			normals[k] = nrm.normalized() if nrm.length_squared() > 0.0 else Vector3.UP
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in _rows - 1:
		for i in _cols - 1:
			var a := j * _cols + i
			var b := a + 1
			var c := a + _cols
			var d := c + 1
			var corners := [[a, i, j], [c, i, j + 1], [b, i + 1, j], [b, i + 1, j], [c, i, j + 1], [d, i + 1, j + 1]]
			for q: Array in corners:
				var k: int = q[0]
				_imesh.surface_set_normal(normals[k])
				_imesh.surface_set_uv(Vector2(float(q[1]) / float(_cols - 1), float(q[2]) / float(_rows - 1)))
				_imesh.surface_add_vertex(_p[k])
	_imesh.surface_end()


## New colours for the cloth (any of "base", "hem", "trim" in `colours`),
## painted at once.
func recolour(colours: Dictionary) -> void:
	for key in colours:
		spec[key] = colours[key]
	material_override = _material()


## The cloth's colours as a small texture: the ground colour, a band at the
## hem with a thin trim over it, and a tiger's stripes or a row of runes.
func _material() -> StandardMaterial3D:
	var w := 32
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base: Color = spec.get("base", Color(0.3, 0.1, 0.1))
	var hem: Color = spec.get("hem", base.darkened(0.3))
	var trim: Color = spec.get("trim", hem)
	var pattern := String(spec.get("pattern", "plain"))
	for y in h:
		var v := float(y) / float(h - 1)
		for x in w:
			var u := float(x) / float(w - 1)
			var c := base
			if pattern == "tiger":
				var wave := v * 9.0 + 0.35 * sin(u * TAU * 1.5 + v * 5.0) + 0.2 * sin(u * TAU * 3.0)
				var band := fposmod(wave, 1.0)
				var edge := absf(u - 0.5) * 2.0
				if band < 0.16 * (1.0 - 0.5 * edge) and v > 0.05:
					c = trim
			if v > 0.93:
				c = hem
			elif v > 0.905 and pattern != "tiger":
				c = trim
			if pattern == "runes" and v > 0.84 and v < 0.89:
				var cell := fposmod(u * 6.0, 1.0)
				var cy := (v - 0.865) / 0.025
				if absf(cell - 0.5) * 2.0 + absf(cy) < 0.9:
					c = trim
			img.set_pixel(x, y, c)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	return mat
