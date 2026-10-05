class_name Lightning
extends Node3D

## Little forks of lightning: a crackle of jagged bolts round a point, gone in
## a flicker (the Stunning Arrow's charge, its release and a stun landing; the
## user's pick, 2026-10-05: lightning and sparks).

## The electric white-blue, and the white of a bolt's core.
const SPARK := Color(0.4, 0.72, 1.0)
const CORE := Color(0.92, 0.97, 1.0)

var _left: float = 0.1
var _mats: Array[StandardMaterial3D] = []


## `bolts` jagged forks out from `at`, each up to `reach` long, for `life`
## seconds; a few sparks thrown with them when `sparks`.
static func crackle(into: Node, at: Vector3, reach: float = 0.3, bolts: int = 3,
		life: float = 0.08, sparks: int = 0, color: Color = SPARK) -> void:
	if into == null or not into.is_inside_tree():
		return
	var zap := Lightning.new()
	zap._left = life
	into.add_child(zap)
	zap.global_position = at
	for b in bolts:
		zap._bolt(at, reach * randf_range(0.6, 1.0), color)
	if sparks > 0:
		SkillFx.burst(into, at, color, sparks, Vector2(1.5, 4.5), Vector3.UP, 180.0,
				Vector2(0.008, 0.018), Vector3(0, -5, 0), 0.3)


## One fork: four or five kinks out along a random way, a thin bright core in
## a fainter, wider glow; now and then a short branch off it.
func _bolt(from: Vector3, reach: float, color: Color) -> void:
	var way := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	if way.length_squared() < 0.01:
		way = Vector3.UP
	way = way.normalized()
	var side := way.cross(Vector3.UP if absf(way.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(way).normalized()
	var steps := randi_range(4, 5)
	var at := from
	for k in steps:
		var next := from + way * reach * float(k + 1) / steps \
				+ (side * randf_range(-1, 1) + up * randf_range(-1, 1)) * reach * 0.18
		_seg(at, next, color)
		if k == 1 and randf() < 0.6:
			var fork := next + (way + side * randf_range(-1.2, 1.2) + up * randf_range(-1.2, 1.2)).normalized() * reach * 0.35
			_seg(next, fork, color)
		at = next


func _seg(a: Vector3, b: Vector3, color: Color) -> void:
	var glow := SkillFx.rod(self, a, b, color, 0.011, 2.2)
	var core := SkillFx.rod(self, a, b, CORE, 0.003, 3.0)
	for mi in [glow, core]:
		if mi != null:
			_mats.append((mi as MeshInstance3D).material_override as StandardMaterial3D)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	# a flicker: on and off as it dies
	var on := 1.0 if fmod(_left, 0.04) > 0.012 else 0.35
	for m in _mats:
		m.albedo_color.a = on
