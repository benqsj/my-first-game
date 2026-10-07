class_name QuakeRing
extends Node3D

## A shock run out along the ground from where a big one struck it (the
## ogre's club, the troll coming down from a leap: the user's pick,
## 2026-10-07): a low ring of dust and earth opening out at [constant SPEED]
## to `radius`, grit thrown up where it passes, the ground cracked where it
## began, and the view shaken for a hero it reaches.
##
## Looks only, the same in every window. Who it throws down is the host's
## ([PackBrute], [method front]): the hero on the ground when the front
## passes under him, unless he is off it (a jump) or rolling.

## How fast the front runs out, metres a second.
const SPEED := 9.0
const DUST := Color(0.55, 0.47, 0.38)
const EARTH := Color(0.34, 0.28, 0.22)

var radius: float = 4.0
var _t: float = 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _puffs: int = 0
var _shaken: Dictionary = {}


## Metres from the middle the front has reached after `t` seconds.
static func front(t: float) -> float:
	return t * SPEED


static func spawn(into: Node, at: Vector3, radius_: float) -> QuakeRing:
	if into == null:
		return null
	var q := QuakeRing.new()
	q.radius = radius_
	q.top_level = true
	into.add_child(q)
	q.global_position = at
	q._build()
	return q


func _build() -> void:
	var into := get_parent()
	# The ground broken where it was struck, and earth thrown up.
	GroundFx.eruption(into, global_position, 0.9 + radius * 0.08)
	DustRing.burst(into, global_position + Vector3.UP * 0.05, 1.1 + radius * 0.12)
	_crack()
	# The ring: a low torus of dust, flattened, opening out.
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.86
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 8
	_ring.mesh = t
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(DUST, 0.75)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.position = Vector3.UP * 0.12
	_ring.scale = Vector3(0.3, 0.6, 0.3)
	ImpactFx.thud(self, global_position, true)


## Cracks across the ground where it was struck: dark thin slabs laid out
## from the middle, fading after a while.
func _crack() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.1, 0.08, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var holder := Node3D.new()
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := 7 + roundi(radius)
	for i in n:
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.25, 0.25)
		var length := rng.randf_range(0.5, 0.9) * minf(radius * 0.45, 2.4)
		var at := 0.15
		var dir := Vector3(cos(a), 0.0, sin(a))
		# Each crack in two or three kinked runs.
		for k in 3:
			var piece := length / 3.0
			var bend := dir.rotated(Vector3.UP, rng.randf_range(-0.45, 0.45))
			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.045 * (1.0 - k * 0.25), 0.01, piece)
			mi.mesh = box
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			var mid := dir * at + bend * piece * 0.5
			mi.position = Vector3(mid.x, 0.015, mid.z)
			mi.basis = Basis.looking_at(bend, Vector3.UP)
			dir = bend
			at += 0.0
			# the next run starts where this one ends
			var end := mid + bend * piece * 0.5
			at = end.length()
			dir = end.normalized() if end.length() > 0.01 else bend
	var tw := holder.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	var r := minf(front(_t), radius)
	var done := clampf((front(_t) - radius) / 2.5, 0.0, 1.0)
	_ring.scale = Vector3(maxf(r, 0.3), 0.6 + r * 0.05, maxf(r, 0.3))
	_ring_mat.albedo_color.a = 0.75 * (1.0 - done) * (1.0 - 0.4 * r / maxf(radius, 0.1))
	# Grit thrown up where the front passes, a few times on the way out.
	var want := floori(r / maxf(radius / 3.0, 0.5))
	while _puffs < want and _puffs < 3:
		_puffs += 1
		var pr := radius * float(_puffs) / 3.0
		for k in 6:
			var a := TAU * (float(k) + randf() * 0.5) / 6.0
			DustRing.burst(get_parent(), global_position + Vector3(cos(a) * pr, 0.05, sin(a) * pr), 0.45)
	_shake(r)
	if done >= 1.0:
		queue_free()


## The view of a hero here shaken as the front passes under him.
func _shake(r: float) -> void:
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Player
		if hero == null or _shaken.has(hero) or not hero.is_multiplayer_authority():
			continue
		var d := Vector2(hero.global_position.x - global_position.x, hero.global_position.z - global_position.z).length()
		if d > r or d > radius + 2.0:
			continue
		_shaken[hero] = true
		var cam := hero.get_viewport().get_camera_3d()
		if cam != null:
			ImpactFx.knock(cam, Vector3.DOWN, 0.12 * (1.0 - d / (radius + 2.0)) + 0.05, 0.18, 0.35)
