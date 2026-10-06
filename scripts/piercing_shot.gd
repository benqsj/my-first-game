class_name PiercingShot
extends Node3D

## Avtandil's Piercing Arrow: one arrow loosed flat and fast that does not
## stop in the first body it meets. Everything on its line is struck and thrown
## back; only the ground or a wall ends it.
##
## It looks like a great shot of wind, after Ironeye's Single Shot in Elden
## Ring Nightreign ([WindBlast]): white shards burst off the bow and the
## archer is thrown back a step, the camera jolts; the arrow goes as a white
## streak with speed lines racing beside it; bands of air wind round the line
## and open out behind it, and a wall of mist is left hanging along it for a
## second before it thins. Its wind is wide: anything within `blast_radius`
## of the line is struck, not only what the arrow itself goes through.
## Nothing is blue and nothing lights anything.
##
## Every peer flies the same shot from the same numbers (it is sent to all of
## them by [method Player.net_piercing]); only the host's `take_hit` and
## `react` count, as with every arrow.

## Air: near white, a breath of blue-grey, never a colour of its own.
const AIR := Color(0.9, 0.94, 0.97)
const CORE := Color(1.0, 0.99, 0.96)
const DUST := Color(0.66, 0.6, 0.5)
## How far either side of the line the blast still strikes.
const BLAST_RADIUS := 1.1
## How far down the line the bands and the mist go, and how often.
const BLAST_REACH := 30.0
## How long each stretch of the tornado is.
const TWIST_LEN := 3.0
## The gap left between one stretch of the tornado and the next, so it comes
## in gusts here and there rather than one unbroken tube.
const TWIST_GAP := Vector2(1.2, 3.4)
const MIST_EVERY := 1.6

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
var _next_mist: float = 0.8
var _band_n: int = 0


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
	add_to_group(&"missile")


## For a creature watching it come ([Wolf]).
func flight() -> Array:
	if _done:
		return []
	return [_start + _dir * _travel, _dir * _speed, _shooter]


func _ready() -> void:
	top_level = true
	_arrow = _make_arrow()
	add_child(_arrow)
	# The arrow goes as a white streak: the wake is the last few metres of it.
	_wake = SkillFx.rod(self, _start, _start, WindBlast.AIR, 0.012, 1.2)
	_wake_mat = _wake.material_override as StandardMaterial3D
	_wake_mat.albedo_color.a = 0.45
	var into := get_parent()
	WindBlast.release(into, _start, _dir)
	WindBlast.speed_lines(into, _start, _dir, 14.0)
	_next_ring = TWIST_LEN
	_draw_at(_start)


## Soft air: pale, see-through, spreading as it goes — not a spark.
static func _puff(into: Node, at: Vector3, dir: Vector3, count: int, speed: Vector2, spread: float,
		size: Vector2, life: float) -> void:
	if into == null:
		return
	SkillFx.particles(into, at, {
		"amount": count, "life": life, "one_shot": true, "explosiveness": 0.9,
		"speed": speed, "dir": dir, "spread": spread, "damping": 3.0, "size": size, "grow": 0.7,
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
	var into := get_parent()
	# Bands of air winding round the line as the arrow passes, opening out;
	# mist left hanging behind it.
	# A tornado of air laid down behind the arrow, stretch by stretch: each
	# stretch spins about the line and opens out, the funnel widening the
	# further it goes; a band of air opens round it now and then.
	while _travel >= _next_ring and _next_ring < BLAST_REACH:
		var fade := 1.0 - _next_ring / BLAST_REACH
		var at := _start + _dir * (_next_ring - TWIST_LEN)
		var r0 := 0.18 + 0.02 * _next_ring
		WindBlast.twister(into, at, _dir, TWIST_LEN + 0.4, r0, r0 * 2.6 + 0.4,
				0.7 + 0.4 * fade, float(_band_n) * 1.3)
		if _band_n % 4 == 2:
			WindBlast.band(into, at, _dir, r0, r0 * 3.0 + 0.6, 0.5, float(_band_n) * 2.1)
		_band_n += 1
		_next_ring += TWIST_LEN + randf_range(TWIST_GAP.x, TWIST_GAP.y)
	while _travel >= _next_mist and _next_mist < BLAST_REACH:
		var fade := 1.0 - _next_mist / BLAST_REACH
		WindBlast.mist(into, _start + _dir * _next_mist, 3, 0.8 + 0.9 * fade,
				Vector2(1.4, 2.2 + 1.4 * fade), 1.4 + 0.8 * fade)
		_next_mist += MIST_EVERY
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
	# The wind round the arrow: whatever stands within the blast's radius of
	# this stretch of the line.
	var capsule := CapsuleShape3D.new()
	capsule.radius = BLAST_RADIUS
	capsule.height = from.distance_to(to) + BLAST_RADIUS * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	var mid := (from + to) * 0.5
	var y := _dir
	var x := y.cross(_up()).normalized()
	q.transform = Transform3D(Basis(x, y, x.cross(y)), mid)
	q.collision_mask = 4
	q.exclude = exclude
	for hit in space.intersect_shape(q, 16):
		var body := hit["collider"] as Node3D
		var rid: RID = hit["rid"]
		if body != null and body.has_method(&"take_hit") and not _struck.has(rid):
			exclude.append(rid)
			_struck.append(rid)
			var at := body.global_position + Vector3.UP * 0.9
			_strike(body, mid + _dir * _dir.dot(at - mid))
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
	# A gust through it: air bursting on out the far side, a band round it.
	_puff(into, at, _dir, 24, Vector2(2.0, 6.0), 55.0, Vector2(0.18, 0.36), 0.5)
	WindBlast.band(into, at, _dir, 0.4, 1.6, 0.4, randf() * TAU, 4.2)
	Blood.spill(into, at, _dir, what)
	if not _decides():
		return
	what.call(&"take_hit", _damage, at, _dir, _critical, false, _shooter)
	if not is_instance_valid(what) or what.get(&"is_dead") == true:
		return
	if what.has_method(&"react"):
		what.call(&"react", &"knock", _shooter, _dir * _knock)


func _draw_at(at: Vector3) -> void:
	_arrow.global_transform = Transform3D(Basis.looking_at(_dir, _up()), at)
	# The streak: the last few metres of air it went through.
	SkillFx.place_rod(_wake, at - _dir * minf(4.0, at.distance_to(_start)), at)


func _up() -> Vector3:
	return Vector3.RIGHT if absf(_dir.dot(Vector3.UP)) > 0.95 else Vector3.UP


func _end(at: Vector3, hit_world: bool) -> void:
	_done = true
	_arrow.hide()
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
