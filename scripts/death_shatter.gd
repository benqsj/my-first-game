class_name DeathShatter
extends Node3D
## A fallen enemy goes the Elden Ring way: it breaks into shards that burst
## out of it and drift up and fade (ShardShatter's shard particles,
## [code]addons/ShardShatter[/code], MIT).
##
## (2026-10-15, the user's word: the shards seemed to come from somewhere
## else, and the whole body lighting up first was not liked.) The shards now
## come out of the body as it is posed — down on its knees, lying over — from
## points along its bones; nothing glows over it first: after `delay` it is
## gone at once, a short flash and its shards in its place.
##
## Lives in the world, not on the corpse, so the corpse can be cleared while
## its shards still fly. Every peer starts its own.

const SHARDS := preload("res://addons/ShardShatter/ShatterParticles.tscn")

## The shards' colour and light.
const GLOW := Color(1.0, 0.86, 0.6)
const EMBER := Color(1.0, 0.6, 0.22)
const SHARD_LIFE := 2.2
## Points laid along each bone (from its parent to it).
const ALONG := 3

var _body: WeakRef
var _delay := 0.0
var _time := 0.0
var _burst := false


## Breaks `body` (a corpse's visual root) into shards after `delay` seconds.
## Returns null when there is nothing to shatter.
static func start(from: Node, body: Node3D, delay: float = 0.0) -> DeathShatter:
	if from == null or body == null or not is_instance_valid(body):
		return null
	var world := Blood.world_of(from)
	if world == null:
		return null
	var it := DeathShatter.new()
	it.name = "DeathShatter"
	it._body = weakref(body)
	it._delay = maxf(delay, 0.0)
	world.add_child(it)
	return it


func _process(delta: float) -> void:
	if _burst:
		return
	_time += delta
	var body: Node3D = _body.get_ref()
	if body == null or not is_instance_valid(body):
		queue_free()
		return
	if _time >= _delay:
		_shatter(body)


## Where the body is now, as points along its bones (world space); its
## meshes' boxes where it has no skeleton.
static func body_points(body: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for node in body.find_children("*", "Skeleton3D", true, false):
		var skel := node as Skeleton3D
		if not skel.is_visible_in_tree():
			continue
		var xf := skel.global_transform
		for b in skel.get_bone_count():
			var at := xf * skel.get_bone_global_pose(b).origin
			var parent := skel.get_bone_parent(b)
			if parent < 0:
				out.append(at)
				continue
			var from := xf * skel.get_bone_global_pose(parent).origin
			for k in ALONG:
				out.append(from.lerp(at, float(k + 1) / float(ALONG)))
	if out.is_empty():
		for node in body.find_children("*", "MeshInstance3D", true, false):
			var g := node as MeshInstance3D
			if not g.is_visible_in_tree():
				continue
			var box := g.global_transform * g.get_aabb()
			for k in 8:
				out.append(box.position + box.size * Vector3(randf(), randf(), randf()))
	return out


## Hides the corpse and throws its shards out of it, where it is.
func _shatter(body: Node3D) -> void:
	_burst = true
	var points := body_points(body)
	body.visible = false
	if points.is_empty():
		points.append(body.global_position + Vector3.UP * 0.8)
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	var centre := box.get_center()
	var size := clampf(box.size.length() / 2.2, 0.5, 4.0)
	# the points, as the particles' own space sees them
	var img := Image.create(points.size(), 1, false, Image.FORMAT_RGBF)
	for i in points.size():
		var p := points[i] - centre
		img.set_pixel(i, 0, Color(p.x, p.y, p.z))

	var shards := SHARDS.instantiate() as GPUParticles3D
	add_child(shards)
	shards.global_position = centre
	shards.amount = clampi(int(230.0 * size), 170, 480)
	shards.lifetime = SHARD_LIFE
	shards.explosiveness = 0.92
	shards.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 12, 12))
	var m := (shards.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	shards.process_material = m
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	m.emission_point_texture = ImageTexture.create_from_image(img)
	m.emission_point_count = points.size()
	# out of it all at once, then hanging and drifting up as they fade
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.2 * size
	m.initial_velocity_max = 0.7 * size
	m.radial_velocity_min = 1.2 * size
	m.radial_velocity_max = 2.6 * size
	m.gravity = Vector3(0.0, 0.6, 0.0)
	m.damping_min = 2.2
	m.damping_max = 3.4
	m.scale_min = 0.32 * sqrt(size)
	m.scale_max = 0.75 * sqrt(size)
	var shard := shards.draw_pass_1 as PrimitiveMesh
	if shard != null and shard.material is StandardMaterial3D:
		var sm := (shard.material as StandardMaterial3D).duplicate() as StandardMaterial3D
		sm.albedo_color = GLOW
		sm.emission = EMBER
		sm.emission_energy_multiplier = 2.2
		var mesh := shard.duplicate() as PrimitiveMesh
		mesh.material = sm
		shards.draw_pass_1 = mesh
	shards.restart()
	shards.emitting = true

	# a breath of light where it was, gone at once
	var flash := OmniLight3D.new()
	flash.light_color = EMBER
	flash.omni_range = 3.5 * size
	flash.light_energy = 3.0
	flash.shadow_enabled = false
	add_child(flash)
	flash.global_position = centre
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(SHARD_LIFE + 0.5, false).timeout.connect(queue_free)
