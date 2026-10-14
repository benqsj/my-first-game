class_name DeathShatter
extends Node3D
## A fallen enemy goes the Elden Ring way: its corpse glows over in pale gold,
## then breaks into shards that drift up and fade (ShardShatter's fade
## overlay and shard particles, [code]addons/ShardShatter[/code], MIT).
##
## Lives in the world, not on the corpse, so the corpse can be cleared while
## its shards still fly. Every peer starts its own.

const FADE_MAT := preload("res://addons/ShardShatter/FadeMaterial.tres")
const SHARDS := preload("res://addons/ShardShatter/ShatterParticles.tscn")

## The glow the corpse turns to, and the shards' light.
const GLOW := Color(1.0, 0.9, 0.66)
const EMBER := Color(1.0, 0.64, 0.24)
const SHARD_LIFE := 2.4

var _body: WeakRef
var _meshes: Array[WeakRef] = []
var _mat: ShaderMaterial
var _fade := 0.9
var _time := 0.0
var _burst := false


## Starts the glow on `body` (a corpse's visual root) over `fade` seconds.
## Returns null when there is nothing to shatter.
static func start(from: Node, body: Node3D, fade: float = 0.9) -> DeathShatter:
	if from == null or body == null or not is_instance_valid(body):
		return null
	var world := Blood.world_of(from)
	if world == null:
		return null
	var it := DeathShatter.new()
	it.name = "DeathShatter"
	it._body = weakref(body)
	it._fade = maxf(fade, 0.05)
	it._mat = FADE_MAT.duplicate() as ShaderMaterial
	it._mat.set_shader_parameter("progress", 0.0)
	it._mat.set_shader_parameter("color", GLOW)
	it._mat.set_shader_parameter("emission", EMBER)
	it._mat.set_shader_parameter("emission_multiplier", 1.6)
	for g in _geometry(body):
		g.material_overlay = it._mat
		it._meshes.append(weakref(g))
	world.add_child(it)
	return it


static func _geometry(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var todo: Array[Node] = [root]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).visible:
			out.append(n)
		todo.append_array(n.get_children())
	return out


func _process(delta: float) -> void:
	if _burst:
		return
	_time += delta
	var t := clampf(_time / _fade, 0.0, 1.0)
	# slow to start, so the corpse first warms, then whitens over
	_mat.set_shader_parameter("progress", t * t * (3.0 - 2.0 * t))
	_mat.set_shader_parameter("emission_multiplier", lerpf(1.6, 3.2, t))
	var body: Node3D = _body.get_ref()
	if body == null or not is_instance_valid(body):
		queue_free()
		return
	if t >= 1.0:
		_shatter(body)


## Hides the corpse and throws its shards from where it lay.
func _shatter(body: Node3D) -> void:
	_burst = true
	var box := AABB()
	var first := true
	for w in _meshes:
		var g := w.get_ref() as GeometryInstance3D
		if g == null or not is_instance_valid(g):
			continue
		var b := g.global_transform * g.get_aabb()
		box = b if first else box.merge(b)
		first = false
	body.visible = false
	if first:
		box = AABB(body.global_position - Vector3(0.5, 0.0, 0.5), Vector3(1.0, 1.0, 1.0))
	var size := clampf(box.size.length() / 2.2, 0.5, 4.0)

	var p := SHARDS.instantiate() as GPUParticles3D
	add_child(p)
	p.global_position = box.get_center()
	p.amount = clampi(int(160.0 * size), 110, 380)
	p.lifetime = SHARD_LIFE
	p.explosiveness = 0.7
	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = box.size * 0.42
	m.direction = Vector3.UP
	m.spread = 55.0
	m.initial_velocity_min = 0.3 * size
	m.initial_velocity_max = 1.0 * size
	m.gravity = Vector3(0.0, 0.55, 0.0)
	m.damping_min = 0.6
	m.damping_max = 1.4
	m.scale_min = 0.25 * sqrt(size)
	m.scale_max = 0.6 * sqrt(size)
	var shard := p.draw_pass_1 as PrimitiveMesh
	if shard != null and shard.material is StandardMaterial3D:
		var sm := shard.material as StandardMaterial3D
		sm.albedo_color = GLOW
		sm.emission = EMBER
		sm.emission_energy_multiplier = 2.6
	p.restart()
	p.emitting = true
	get_tree().create_timer(SHARD_LIFE + 0.5, false).timeout.connect(queue_free)
