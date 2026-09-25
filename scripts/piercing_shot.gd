class_name PiercingShot
extends Node3D

## Avtandil's Piercing Arrow: one arrow drawn past full, loosed flat and fast,
## that does not stop in the first body it meets. Everything on its line is
## struck and thrown back; only the ground or a wall ends it.
##
## Every peer flies the same shot from the same numbers (it is sent to all of
## them by [method Player.net_piercing]); only the host's `take_hit` and
## `react` count, as with every arrow.

const WIND := Color(0.3, 0.82, 1.0)
const CORE := Color(1.0, 0.96, 0.85)

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

var _head: MeshInstance3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _swirl: GPUParticles3D


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
	_head = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.07
	cap.height = 1.0
	_head.mesh = cap
	_head.material_override = SkillFx.glow(CORE, 5.0)
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_head)
	_beam = SkillFx.rod(self, _start, _start, WIND, 0.035, 2.6)
	_beam_mat = _beam.material_override as StandardMaterial3D
	_swirl = SkillFx.particles(self, _start, {
		"amount": 90, "life": 0.45, "speed": Vector2(0.2, 0.8), "spread": 180.0, "damping": 3.0,
		"size": Vector2(0.03, 0.06), "sphere": 0.18,
		"colors": [Color(1, 1, 1, 1), WIND, Color(WIND.r, WIND.g, WIND.b, 0.0)],
	})
	# The shock off the bow.
	var into := get_parent()
	SkillFx.flash(into, _start, CORE, 0.45, 0.2, 4.0)
	SkillFx.ring(into, _start, _dir, WIND, 0.12, 1.5, 0.3, 0.03, 2.5)
	SkillFx.light(into, _start, WIND, 5.0, 6.0, 0.3)


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
	while _travel >= _next_ring:
		SkillFx.ring(get_parent(), _start + _dir * _next_ring, _dir, WIND, 0.1, 0.85, 0.35, 0.025, 2.2)
		_next_ring += 2.5
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
	SkillFx.burst(into, at, CORE, 40, Vector2(3.0, 9.0), _dir, 55.0, Vector2(0.03, 0.07), Vector3(0, -5, 0), 0.4)
	SkillFx.flash(into, at, CORE, 0.8, 0.22, 4.0)
	SkillFx.ring(into, at, _dir, WIND, 0.3, 2.2, 0.35, 0.03, 2.6)
	SkillFx.light(into, at, WIND, 6.0, 7.0, 0.35)
	Blood.splatter(into, at, _dir)
	if not _decides():
		return
	what.call(&"take_hit", _damage, at, _dir, _critical, false, _shooter)
	if not is_instance_valid(what) or what.get(&"is_dead") == true:
		return
	if what.has_method(&"react"):
		what.call(&"react", &"knock", _shooter, _dir * _knock)


func _draw_at(at: Vector3) -> void:
	var length := minf(3.2, at.distance_to(_start) + 0.1)
	SkillFx.place_rod(_head, at - _dir * length, at)
	SkillFx.place_rod(_beam, _start, at)
	_swirl.global_position = at


func _end(at: Vector3, hit_world: bool) -> void:
	_done = true
	_head.hide()
	_swirl.emitting = false
	if hit_world:
		var into := get_parent()
		SkillFx.burst(into, at, Color(0.6, 0.55, 0.45), 26, Vector2(1.0, 4.0), -_dir, 70.0,
				Vector2(0.05, 0.12), Vector3(0, -6, 0), 0.6)
		DustRing.burst(into, at, 0.6)
	var tw := create_tween()
	tw.tween_property(_beam_mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_interval(0.5)
	tw.tween_callback(queue_free)


func _decides() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))
