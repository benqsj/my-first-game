class_name GoblinShot
extends Node3D

## What a goblin throws ([GoblinFighter], the user's pick, 2026-10-07): a
## stone, or now and then a bomb — a black pot with a spitting fuse.
##
## Thrown on an arc, it tumbles as it flies. **A stone** that meets a hero is a
## blow (`receive_blow`, a flinch at most); on the ground it cracks into chips
## and is gone. **A bomb** lands, rolls a little, its fuse fizzing faster and
## faster, and bursts after `FUSE`: every hero within `BLAST` takes the blast,
## the nearer the harder, thrown off his feet if he is close.
##
## **A boulder** is the troll's ([TrollFighter]): torn out of the ground and
## hurled, it throws down whoever it meets (a shield takes it, at a cost),
## and bursts into rubble where it lands.
##
## Made on every peer from the goblin's own message; only the host's lands
## blows (`hurts`).

enum Kind { STONE, BOMB, BOULDER }

const GRAVITY := 9.8
const FUSE := 1.0
const BLAST := 2.6
const STONE := Color(0.46, 0.43, 0.4)
const POT := Color(0.12, 0.11, 0.1)
const SPARK := Color(1.0, 0.62, 0.2)
const FIRE := Color(1.0, 0.5, 0.15)
const HERO_R := 0.45
const BOULDER_R := 0.75

var kind: int = Kind.STONE
## Thrown at the heroes (the creatures do not raise a shield to it).
var against_heroes: bool = true
var damage: float = 10.0
var hurts: bool = false
var thrower: Node3D = null
var serial: int = 0

var _vel: Vector3 = Vector3.ZERO
var _spin: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _landed_at: float = -1.0
var _done: bool = false
var _model: MeshInstance3D
var _fuse: GPUParticles3D
var _fuse_light: OmniLight3D


static func throw(into: Node, from: Vector3, velocity: Vector3, what: int, worth: float,
		by: Node3D, decides: bool, id: int) -> GoblinShot:
	var shot := GoblinShot.new()
	shot.name = "GoblinShot_%d" % id
	shot.kind = what
	shot.damage = worth
	shot.hurts = decides
	shot.thrower = by
	shot.serial = id
	into.add_child(shot)
	shot.global_position = from
	shot._vel = velocity
	shot._spin = Vector3(randf_range(-9, 9), randf_range(-5, 5), randf_range(-9, 9))
	shot._build()
	return shot


## The way it is going, for whoever watches it come (a shield raised to it).
func flight() -> Array:
	if _done or _landed_at >= 0.0:
		return []
	return [global_position, _vel, thrower]


func _build() -> void:
	_model = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if kind == Kind.BOULDER:
		var m := SphereMesh.new()
		m.radius = 0.42
		m.height = 0.76
		m.radial_segments = 7
		m.rings = 4
		_model.mesh = m
		mat.albedo_color = Color(0.4, 0.37, 0.33)
		mat.roughness = 1.0
		_model.scale = Vector3(1.1, 0.85, 1.0)
		_model.rotation = Vector3(randf(), randf(), randf()) * TAU
	elif kind == Kind.STONE:
		var m := SphereMesh.new()
		m.radius = 0.08
		m.height = 0.13
		m.radial_segments = 7
		m.rings = 4
		_model.mesh = m
		mat.albedo_color = STONE
		mat.roughness = 0.95
		_model.scale = Vector3(1.0, 0.8, 1.15)
	else:
		var m := SphereMesh.new()
		m.radius = 0.13
		m.height = 0.24
		m.radial_segments = 12
		m.rings = 6
		_model.mesh = m
		mat.albedo_color = POT
		mat.roughness = 0.55
		mat.metallic = 0.3
		var neck := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.035
		c.bottom_radius = 0.05
		c.height = 0.07
		neck.mesh = c
		neck.position = Vector3.UP * 0.12
		var nm := StandardMaterial3D.new()
		nm.albedo_color = Color(0.3, 0.22, 0.14)
		c.material = nm
		_model.add_child(neck)
		_fuse = SkillFx.particles(self, global_position, {
			"amount": 26, "life": 0.35, "one_shot": false, "explosiveness": 0.0,
			"speed": Vector2(0.6, 1.8), "dir": Vector3.UP, "spread": 50.0, "gravity": Vector3(0, -3, 0),
			"damping": 1.0, "size": Vector2(0.01, 0.025),
			"colors": [Color(1, 1, 0.8, 1), SPARK, Color(SPARK.r, SPARK.g, SPARK.b, 0.0)],
		})
		_fuse_light = OmniLight3D.new()
		_fuse_light.light_color = SPARK
		_fuse_light.light_energy = 0.8
		_fuse_light.omni_range = 1.8
		_fuse_light.shadow_enabled = false
		add_child(_fuse_light)
	(_model.mesh as PrimitiveMesh).material = mat
	add_child(_model)
	add_to_group(&"missile")


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _fuse != null and is_instance_valid(_fuse):
		_fuse.global_position = _model.global_position + _model.global_basis.y * 0.17
	if _landed_at >= 0.0:
		_lie(delta)
		return
	var from := global_position
	_vel.y -= GRAVITY * delta
	var to := from + _vel * delta
	_model.rotation += _spin * delta
	# A hero in its way (the host's).
	if hurts and kind != Kind.BOMB:
		for node in get_tree().get_nodes_in_group(&"player"):
			var hero := node as Node3D
			if hero == null or bool(hero.get("is_dead")):
				continue
			var low := hero.global_position + Vector3.UP * 0.3
			var high := hero.global_position + Vector3.UP * 1.7
			var pts := Geometry3D.get_closest_points_between_segments(from, to, low, high)
			if pts[0].distance_to(pts[1]) <= (BOULDER_R if kind == Kind.BOULDER else HERO_R):
				_strike_hero(hero, pts[0])
				return
	# The ground, a wall.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var at: Vector3 = hit["position"]
		global_position = at + (hit["normal"] as Vector3) * 0.1
		if kind != Kind.BOMB:
			_crack(at, hit["normal"])
		else:
			_land(hit["normal"])
		return
	global_position = to
	if _age > 6.0:
		queue_free()


func _strike_hero(hero: Node3D, at: Vector3) -> void:
	if hero.has_method(&"receive_blow"):
		hero.call(&"receive_blow", damage, self, 0, 1, serial)
	_crack(at, -_vel.normalized())


func _crack(at: Vector3, normal: Vector3) -> void:
	_done = true
	var into := Blood.world_of(self)
	if kind == Kind.BOULDER:
		HitFx.spawn(into, &"stone", at, normal, 1.4)
		GroundFx.eruption(into, at, 0.75)
		DustRing.burst(into, at, 1.0)
		ImpactFx.thud(self, at, true)
	else:
		HitFx.spawn(into, &"stone", at, normal, 0.6)
		DustRing.burst(into, at, 0.35)
	queue_free()


func _land(normal: Vector3) -> void:
	_landed_at = _age
	# A short roll on after it comes down.
	var roll := Vector3(_vel.x, 0.0, _vel.z) * 0.18
	_vel = roll
	_spin *= 0.4
	DustRing.burst(Blood.world_of(self), global_position, 0.3)
	if normal.y < 0.5:
		_vel = Vector3.ZERO


func _lie(delta: float) -> void:
	_vel = _vel.move_toward(Vector3.ZERO, 2.5 * delta)
	global_position += _vel * delta
	_model.rotation += _spin * delta * (_vel.length() * 2.0)
	var left := FUSE - (_age - _landed_at)
	# The fuse, faster and brighter as it goes down.
	if _fuse_light != null:
		_fuse_light.light_energy = 0.6 + 1.6 * (1.0 - left / FUSE) * (0.5 + 0.5 * sin(_age * lerpf(14.0, 40.0, 1.0 - left / FUSE)))
	if left <= 0.0:
		_burst()


func _burst() -> void:
	_done = true
	var at := global_position
	var into := Blood.world_of(self)
	SkillFx.flash(into, at + Vector3.UP * 0.3, FIRE, 2.2, 0.28, 4.0)
	SkillFx.light(into, at + Vector3.UP * 0.6, FIRE, 7.0, 9.0, 0.45)
	SkillFx.burst(into, at + Vector3.UP * 0.2, SPARK, 60, Vector2(4.0, 10.0), Vector3.UP, 85.0,
			Vector2(0.03, 0.08), Vector3(0, -9, 0), 0.7)
	SkillFx.ring(into, at + Vector3.UP * 0.08, Vector3.UP, FIRE, 0.3, BLAST, 0.32, 0.05, 3.0)
	DustRing.burst(into, at, 1.6)
	ImpactFx.thud(self, at, true)
	if hurts:
		for node in get_tree().get_nodes_in_group(&"player"):
			var hero := node as Node3D
			if hero == null or bool(hero.get("is_dead")) or not hero.has_method(&"receive_blow"):
				continue
			var d := hero.global_position.distance_to(at)
			if d > BLAST:
				continue
			var near := 1.0 - clampf(d / BLAST, 0.0, 1.0)
			# Close in, thrown down (a fell-blow); further, a flinch.
			hero.call(&"receive_blow", damage * lerpf(0.45, 1.0, near), self, 0, 1 if near > 0.55 else 3, serial)
	if _fuse != null and is_instance_valid(_fuse):
		_fuse.emitting = false
	queue_free()
