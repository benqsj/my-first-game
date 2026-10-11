class_name RockWave
extends Node3D

## Stone bursting up out of the ground and running out from where a blow
## struck it, all the way round (the ogre's great blow and its pounds, the
## user's word 2026-10-11: rock instead of a ring, and far out — 10, 20, 40 m).
## The stones rise as the front passes, stand a moment and sink back; a puff of
## grit off the front now and then. All of it is one [MultiMesh] (the golem's
## shard rows, one per way out, each with its own dust, choked the GPU at 40 m).

## How long a stone stands, how quickly it comes up and how long it takes
## going back down (s).
const RISE := 0.11
const HOLD := 0.85
const SINK := 0.55
## Stones about this far apart along the front and between fronts (m, times
## `size`), and never more than this many on one front.
const SPACING := 1.7
const MOST_ON_A_FRONT := 72
## Grit off the front: this many puffs round it, so often (s).
const PUFFS := 5
const PUFF_EVERY := 0.22

var _mm: MultiMeshInstance3D
## Each stone: [place, its distance out, its height, its basis].
var _stones: Array = []
var _t: float = 0.0
var _pace: float = 22.0
var _radius: float = 10.0
var _size: float = 1.0
var _at := Vector3.ZERO
var _puff_t: float = 0.0
var _rng := RandomNumberGenerator.new()
static var _material: StandardMaterial3D = null


## Stone out from `at` to `radius` (m) at `pace` (m/s), its stones `size`
## times the golem's; laid out by `seed_of` (the same on every peer).
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
	var step := SPACING * _size
	var d := 0.9 * _size
	while d <= _radius:
		var n := clampi(int(TAU * d / step), 5, MOST_ON_A_FRONT)
		var turn := _rng.randf() * TAU
		for i in n:
			var a := turn + TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / float(n)
			var out := Vector3(sin(a), 0.0, cos(a))
			var r := d + _rng.randf_range(-0.35, 0.35) * step
			var place := _at + out * r
			# bigger near where it struck, smaller out at the edge
			var tall := _size * _rng.randf_range(0.7, 1.35) * lerpf(1.6, 0.75, clampf(r / _radius, 0.0, 1.0))
			# leaning out, away from the blow, and turned at random
			var lean := Basis(out.cross(Vector3.UP).normalized(), -_rng.randf_range(0.15, 0.6))
			var b := lean * Basis(Vector3.UP, _rng.randf() * TAU)
			_stones.append([place, r, tall, b])
		d += step
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = GroundFx._shard()
	mm.instance_count = _stones.size()
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.material_override = _stone_material()
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mm)
	_place()


static func _stone_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		# earth, not the golem's grey-blue
		_material.albedo_color = Color(0.78, 0.66, 0.54)
		_material.roughness = 0.95
	return _material


func _process(delta: float) -> void:
	_t += delta
	_place()
	_puff_t -= delta
	var front := _t * _pace
	if _puff_t <= 0.0 and front <= _radius:
		_puff_t = PUFF_EVERY
		_puff(front)
	if _t > _radius / _pace + HOLD + SINK + 0.1:
		queue_free()


## Every stone where it is in its rise, stand and sink.
func _place() -> void:
	var mm := _mm.multimesh
	for i in _stones.size():
		var s: Array = _stones[i]
		var u := _t - float(s[1]) / _pace
		var h := 0.0
		var sink := 0.0
		if u > 0.0:
			# up with a little overshoot, then down into the ground again
			var k := clampf(u / RISE, 0.0, 1.0)
			h = k * (1.0 + 0.15 * sin(k * PI))
			if u > RISE + HOLD:
				sink = clampf((u - RISE - HOLD) / SINK, 0.0, 1.0)
		var tall := float(s[2])
		var scale := tall * maxf(h, 0.001)
		var place: Vector3 = s[0]
		place.y -= tall * 1.05 * sink * sink
		mm.set_instance_transform(i, Transform3D((s[3] as Basis).scaled(Vector3(scale, scale, scale)), place))


## Grit and dust thrown up off the front, a few places round it.
func _puff(front: float) -> void:
	var into := get_parent()
	for i in PUFFS:
		var a := _rng.randf() * TAU
		var at := _at + Vector3(sin(a), 0.0, cos(a)) * maxf(front, 0.5) + Vector3.UP * 0.2
		SkillFx.particles(into, at, {
			"amount": 8, "life": 0.9, "one_shot": true, "explosiveness": 0.8, "add": false,
			"speed": Vector2(0.6, 2.2), "dir": Vector3.UP, "spread": 70.0, "gravity": Vector3(0, -6.0, 0),
			"damping": 1.5, "size": Vector2(0.18, 0.4) * _size, "grow": 0.3, "sphere": 0.6 * _size,
			"colors": [Color(0.55, 0.49, 0.42, 0.0), Color(0.52, 0.47, 0.4, 0.5), Color(0.5, 0.45, 0.4, 0.0)],
		})
