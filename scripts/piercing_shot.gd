class_name PiercingShot
extends Node3D

## Avtandil's Piercing Arrow: one arrow loosed flat and fast that does not
## stop in the first body it meets. Everything on its line is struck and thrown
## back; only the ground or a wall ends it.
##
## It looks like wind, not light: a real arrow with two pale streams of air
## spiralling round it, a thin wake of disturbed air behind, puffs of air
## thrown off along the way, a puff where it leaves the string and a gust
## where it strikes. Nothing is blue and nothing glows.
##
## Every peer flies the same shot from the same numbers (it is sent to all of
## them by [method Player.net_piercing]); only the host's `take_hit` and
## `react` count, as with every arrow.

## Air: near white, a breath of blue-grey, never a colour of its own.
const AIR := Color(0.9, 0.94, 0.97)
const CORE := Color(1.0, 0.99, 0.96)
const DUST := Color(0.66, 0.6, 0.5)
## The streams' radius round the shaft and how fast they wind (rad/s).
const SPIRAL_R := 0.16
const SPIRAL_SPIN := 28.0

var _shooter: Node3D
var _dir := Vector3.FORWARD
var _speed: float = 70.0
var _reach: float = 40.0
var _damage: float = 50.0
var _critical: bool = false
var _knock: float = 5.0
var _start := Vector3.ZERO
var _travel: float = 0.0
var _struck: Array[RID] = []
var _next_ring: float = 1.5
var _done: bool = false

var _arrow: Node3D
var _wake: MeshInstance3D
var _wake_mat: StandardMaterial3D
var _streams: Array[GPUParticles3D] = []
var _spin: float = 0.0


## Sets it going from `from` along `dir`.
func launch(from: Vector3, dir: Vector3, speed: float, reach: float, damage: float, critical: bool,
		shooter: Node3D, knock: float) -> void:
	_start = from
	_dir = dir.normalized()
	_speed = speed
	_reach = reach
	_damage = damage
	_critical = critical
	_shooter = shooter
	_knock = knock


func _ready() -> void:
	top_level = true
	_arrow = _make_arrow()
	add_child(_arrow)
	_wake = SkillFx.rod(self, _start, _start, AIR, 0.01, 0.25)
	_wake_mat = _wake.material_override as StandardMaterial3D
	_wake_mat.albedo_color.a = 0.35
	for k in 2:
		_streams.append(SkillFx.particles(self, _start, {
			"amount": 220, "life": 0.7, "speed": Vector2(0.0, 0.3), "spread": 180.0, "damping": 2.0,
			"size": Vector2(0.08, 0.16), "grow": 1.0, "add": false,
			"colors": [Color(1, 1, 1, 0.0), Color(AIR.r, AIR.g, AIR.b, 0.62), Color(AIR.r, AIR.g, AIR.b, 0.0)],
		}))
	# The puff off the string.
	var into := get_parent()
	_puff(into, _start, _dir, 22, Vector2(1.0, 3.0), 45.0, Vector2(0.18, 0.36), 0.5)
	_draw_at(_start)


## Soft air: pale, see-through, spreading as it goes — not a spark.
static func _puff(into: Node, at: Vector3, dir: Vector3, count: int, speed: Vector2, spread: float,
		size: Vector2, life: float) -> void:
	if into == null:
		return
	SkillFx.particles(into, at, {
		"amount": count, "life": life, "one_shot": true, "explosiveness": 0.9,
		"speed": speed, "dir": dir, "spread": spread, "damping": 3.0, "size": size, "grow": 1.2,
		"add": false,
		"colors": [Color(1, 1, 1, 0.0), Color(AIR.r, AIR.g, AIR.b, 0.55), Color(AIR.r, AIR.g, AIR.b, 0.0)],
	})


func _make_arrow() -> Node3D:
	var a := Node3D.new()
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.008
	cyl.bottom_radius = 0.008
	cyl.height = 0.82
	shaft.mesh = cyl
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("8a6a44")
	shaft.material_override = wood
	shaft.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	shaft.position = Vector3(0.0, 0.0, 0.43)
	a.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.02
	cone.height = 0.07
	head.mesh = cone
	head.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("b8c0c8")
	steel.metallic = 0.8
	steel.roughness = 0.3
	head.material_override = steel
	a.add_child(head)
	for c in a.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return a


func _physics_process(delta: float) -> void:
	if _done:
		return
	var step := minf(_speed * delta, _reach - _travel)
	var from := _start + _dir * _travel
	var to := from + _dir * step
	_sweep(from, to)
	if _done:
		return
	_travel += step
	_spin += SPIRAL_SPIN * delta
	while _travel >= _next_ring:
		# Air thrown off to the sides as it cuts through.
		_puff(get_parent(), _start + _dir * _next_ring, -_dir, 10, Vector2(0.6, 1.6), 80.0,
				Vector2(0.18, 0.34), 0.6)
		_next_ring += 2.0
	_draw_at(_start + _dir * _travel)
	if _travel >= _reach - 0.001:
		_end(_start + _dir * _travel, false)


## Everything between `from` and `to`: each body struck once, the flight going
## on through it; the world ends it.
func _sweep(from: Vector3, to: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = _struck.duplicate()
	if _shooter is CollisionObject3D:
		exclude.append((_shooter as CollisionObject3D).get_rid())
	for _i in 12:
		var ray := PhysicsRayQueryParameters3D.create(from, to, 5, exclude)
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			return
		var what := hit["collider"] as Node
		var at: Vector3 = hit["position"]
		if what != null and what.has_method(&"take_hit"):
			var rid: RID = hit["rid"]
			exclude.append(rid)
			_struck.append(rid)
			_strike(what as Node3D, at)
			continue
		# The ground or a wall.
		_draw_at(at)
		_end(at, true)
		return


func _strike(what: Node3D, at: Vector3) -> void:
	var into := get_parent()
	# A gust through it: air bursting on out the far side, a ring of it.
	_puff(into, at, _dir, 24, Vector2(2.0, 6.0), 55.0, Vector2(0.14, 0.3), 0.45)
	Blood.splatter(into, at, _dir)
	if not _decides():
		return
	what.call(&"take_hit", _damage, at, _dir, _critical, false, _shooter)
	if not is_instance_valid(what) or what.get(&"is_dead") == true:
		return
	if what.has_method(&"react"):
		what.call(&"react", &"knock", _shooter, _dir * _knock)


func _draw_at(at: Vector3) -> void:
	_arrow.global_transform = Transform3D(Basis.looking_at(_dir, _up()), at)
	# The wake: the last few metres of air it went through.
	SkillFx.place_rod(_wake, at - _dir * minf(6.0, at.distance_to(_start)), at)
	# Two streams winding round the shaft, half a turn apart.
	var side := _dir.cross(_up()).normalized()
	var up := side.cross(_dir).normalized()
	for k in _streams.size():
		var a := _spin + PI * float(k)
		_streams[k].global_position = at + _dir * 0.25 + (side * cos(a) + up * sin(a)) * SPIRAL_R


func _up() -> Vector3:
	return Vector3.RIGHT if absf(_dir.dot(Vector3.UP)) > 0.95 else Vector3.UP


func _end(at: Vector3, hit_world: bool) -> void:
	_done = true
	_arrow.hide()
	for p in _streams:
		p.emitting = false
	if hit_world:
		var into := get_parent()
		SkillFx.burst(into, at, DUST, 26, Vector2(1.0, 4.0), -_dir, 70.0,
				Vector2(0.05, 0.12), Vector3(0, -6, 0), 0.6)
		DustRing.burst(into, at, 0.6)
	var tw := create_tween()
	tw.tween_property(_wake_mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_interval(0.5)
	tw.tween_callback(queue_free)


func _decides() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))
