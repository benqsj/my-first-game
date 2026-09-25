class_name FireShot
extends Node3D

## Avtandil's Fire Arrow in flight: an arrow with its head alight, lobbed so
## it comes down where he aimed, trailing fire and smoke. Where it lands — the
## ground, or something in the way — it starts a [FireZone].
##
## Every peer flies it (sent by [method Player.net_fire_arrow]); what it
## strikes on the way is hurt only on the host.

const FIRE := Color(1.0, 0.45, 0.08)
const HOT := Color(1.0, 0.85, 0.45)

var _shooter: Node3D
var _velocity := Vector3.ZERO
var _gravity: float = 9.8
var _damage: float = 20.0
var _zone := {}
var _done: bool = false
var _age: float = 0.0

var _arrow: Node3D
var _flame: GPUParticles3D
var _smoke: GPUParticles3D
var _glow: OmniLight3D


## Lobs it from `from` with `velocity`; `zone` is what the fire it lights is
## given ({radius, seconds, dps}).
func launch(from: Vector3, velocity: Vector3, gravity: float, damage: float, shooter: Node3D,
		zone: Dictionary) -> void:
	_velocity = velocity
	_gravity = gravity
	_damage = damage
	_shooter = shooter
	_zone = zone
	global_position = from
	add_to_group(&"missile")


## For a creature watching it come ([Wolf]).
func flight() -> Array:
	return [] if _done else [global_position, _velocity, _shooter]


func _ready() -> void:
	_arrow = Node3D.new()
	add_child(_arrow)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.007
	cyl.bottom_radius = 0.007
	cyl.height = 0.8
	shaft.mesh = cyl
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5a3a1e")
	shaft.material_override = wood
	shaft.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	shaft.position = Vector3(0.0, 0.0, 0.4)
	_arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.035
	s.height = 0.07
	head.mesh = s
	head.material_override = SkillFx.glow(HOT, 5.0)
	_arrow.add_child(head)
	_flame = SkillFx.particles(self, global_position, {
		"amount": 50, "life": 0.35, "speed": Vector2(0.2, 0.6), "spread": 40.0,
		"gravity": Vector3(0, 2.0, 0), "size": Vector2(0.14, 0.26), "sphere": 0.04,
		"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false, "grow": 0.2,
		"colors": [Color(1.0, 0.62, 0.18, 0.0), Color(1.0, 0.5, 0.08, 0.95), Color(0.92, 0.2, 0.02, 0.85),
				Color(0.25, 0.03, 0.0, 0.0)],
	})
	_smoke = SkillFx.particles(self, global_position, {
		"amount": 24, "life": 0.9, "speed": Vector2(0.1, 0.3), "spread": 60.0,
		"gravity": Vector3(0, 0.8, 0), "size": Vector2(0.15, 0.3), "add": false,
		"colors": [Color(0.2, 0.18, 0.16, 0.0), Color(0.2, 0.18, 0.16, 0.45), Color(0.3, 0.3, 0.3, 0.0)],
	})
	_glow = OmniLight3D.new()
	_glow.light_color = FIRE
	_glow.light_energy = 2.5
	_glow.omni_range = 5.0
	add_child(_glow)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	_velocity.y -= _gravity * delta
	var from := global_position
	var to := from + _velocity * delta
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if _shooter is CollisionObject3D:
		exclude.append((_shooter as CollisionObject3D).get_rid())
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 5, exclude))
	if not hit.is_empty():
		_land(hit["position"], hit["collider"] as Node)
		return
	global_position = to
	if _velocity.length_squared() > 0.0001:
		_arrow.look_at(to + _velocity, Vector3.UP)
	_glow.light_energy = 2.2 + 0.5 * sin(_age * 30.0)
	if _age > 6.0:
		_land(to, null)


func _land(at: Vector3, what: Node) -> void:
	_done = true
	var into := get_parent()
	if what != null and what.has_method(&"take_hit") and _decides():
		what.call(&"take_hit", _damage, at, _velocity.normalized(), false, false, _shooter)
	# The fire starts on the ground under where it came down.
	var ground := at
	var space := get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 6.0, 1))
	if not down.is_empty():
		ground = down["position"]
	var zone := FireZone.new()
	zone.name = "FireZone"
	into.add_child(zone)
	zone.global_position = ground
	zone.start(_shooter, float(_zone.get("radius", 2.6)), float(_zone.get("seconds", 5.0)),
			float(_zone.get("dps", 12.0)))
	_flame.emitting = false
	_smoke.emitting = false
	_arrow.hide()
	_glow.hide()
	get_tree().create_timer(1.2, false).timeout.connect(queue_free)


func _decides() -> bool:
	var net := get_node_or_null(^"/root/Net")
	return net == null or bool(net.call(&"is_host"))
