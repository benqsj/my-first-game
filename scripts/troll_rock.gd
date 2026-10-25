class_name TrollRock
extends Node3D
## A rock the troll throws (the user's word, 2026-10-25: the boulder much
## cooler, with effects). Low poly, out of `troll_rocks.glb`
## (vepxis-art/creatures/troll_rocks.py), on every peer the same; the host's
## copy is the one that hurts.
##
## * **BIG**: torn out of the ground and thrown two-handed over its head. Dust
##   and grit trail behind it; where it comes down it bursts into pieces that
##   bounce away, the ground thrown up, the view shaken; whoever is within
##   `BIG_BLAST` is thrown down (more the nearer).
## * **ROLL**: bowled underhand; it comes down and rolls on along the ground at
##   him, bouncing, dust off it, for `ROLL_FAR` or till it meets a wall, and
##   bursts there. A jump or a roll aside clears it.
## * **SMALL**: a stone thrown one-handed, quick (three in a row): it staggers.

enum Kind { BIG, ROLL, SMALL }

const FILE := "res://assets/creatures/troll_rocks.glb"
const GRAVITY := 18.0
const BIG_R := 0.8
const SMALL_R := 0.4
const BIG_BLAST := 2.6
const ROLL_FAR := 16.0
const ROLL_SPEED := 9.0
const EARTH := Color(0.5, 0.44, 0.36)

static var _meshes: Dictionary = {}
static var _mat: ShaderMaterial

var kind: int = Kind.BIG
var damage: float = 40.0
var thrower: Node3D
var hurts: bool = false
var serial: int = 0
var _vel: Vector3 = Vector3.ZERO
var _spin: Vector3 = Vector3.ZERO
var _model: MeshInstance3D
var _age: float = 0.0
var _rolling: bool = false
var _rolled: float = 0.0
var _trail_in: float = 0.0
var _done: bool = false
var _rng := RandomNumberGenerator.new()
var _hit: Dictionary = {}


## Every peer: a rock of `what` thrown from `from` at `velocity`.
static func throw(into: Node, from: Vector3, velocity: Vector3, what: int, worth: float, by: Node3D,
		host: bool, id: int) -> TrollRock:
	if into == null:
		return null
	var r := TrollRock.new()
	r.kind = what
	r.damage = worth
	r.thrower = by
	r.hurts = host
	r.serial = id
	r._vel = velocity
	r._rng.seed = id
	into.add_child(r)
	r.global_position = from
	r._build()
	return r


static func mesh(name: String) -> Mesh:
	if _meshes.is_empty():
		var scene := load(FILE) as PackedScene
		if scene != null:
			var root := scene.instantiate()
			for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
				_meshes[String(mi.name)] = mi.mesh
			root.free()
	return _meshes.get(name, null)


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://assets/dungeon/forest_glade/lp_solid.gdshader")
		_mat.set_shader_parameter("foot_dark", 0.0)
		_mat.set_shader_parameter("bright", 2.1)
	return _mat


## A rock to hold or throw: the big ones `Boulder_n`, the small `Chunk_n`.
static func model(what: int, pick: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if what == Kind.SMALL:
		mi.mesh = mesh("Chunk_%d" % (pick % 6))
		mi.scale = Vector3.ONE * 2.2
	else:
		mi.mesh = mesh("Boulder_%d" % (pick % 3))
		mi.scale = Vector3.ONE * (1.25 if what == Kind.BIG else 1.05)
	mi.material_override = material()
	return mi


func _build() -> void:
	_model = model(kind, serial)
	_model.rotation = Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * TAU
	add_child(_model)
	_spin = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-3, 3), _rng.randf_range(-6, 6))
	add_to_group(&"missile")
	if kind != Kind.SMALL:
		Sfx.play(self, "res://sounds/ogre/whoosh_heavy.wav", self, Vector3.ZERO, 0.7, -2.0)


func _radius() -> float:
	return SMALL_R if kind == Kind.SMALL else BIG_R


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age > 9.0:
		queue_free()
		return
	_trail(delta)
	if _rolling:
		_roll(delta)
		return
	var from := global_position
	_vel.y -= GRAVITY * delta
	var to := from + _vel * delta
	_model.rotation += _spin * delta
	if _hit_heroes(from, to):
		return
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if not hit.is_empty():
		var at: Vector3 = hit["position"]
		var n: Vector3 = hit["normal"]
		if kind == Kind.ROLL and n.y > 0.6:
			# down on the ground: it rolls on at him
			_rolling = true
			global_position = at + Vector3.UP * BIG_R * 0.9
			var flat := Vector3(_vel.x, 0.0, _vel.z)
			_vel = flat.normalized() * maxf(flat.length(), ROLL_SPEED) if flat.length() > 0.1 else Vector3.ZERO
			_thud(at, 0.9)
			return
		_shatter(at, n)
		return
	global_position = to


## The rolling one: along the ground, bouncing a little, at him.
func _roll(delta: float) -> void:
	var from := global_position
	var to := from + _vel * delta
	_rolled += _vel.length() * delta
	var axis := Vector3.UP.cross(_vel.normalized())
	if axis.length_squared() > 0.0001:
		_model.rotate(axis.normalized(), _vel.length() / BIG_R * delta)
	if _hit_heroes(from, to):
		return
	var space := get_world_3d().direct_space_state
	# a wall, a pillar: it bursts on it
	var ahead := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + _vel.normalized() * (BIG_R + _vel.length() * delta), 1))
	if not ahead.is_empty() and (ahead["normal"] as Vector3).y < 0.5:
		_shatter(ahead["position"], ahead["normal"])
		return
	# the ground under it: kept on it, a hop over a step
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3.UP * 1.5, to + Vector3.DOWN * 3.0, 1))
	if not down.is_empty():
		var g: Vector3 = down["position"]
		to.y = g.y + BIG_R * 0.9 + absf(sin(_rolled * 1.7)) * 0.12
	global_position = to
	if _rolled >= ROLL_FAR:
		_shatter(global_position - Vector3.UP * BIG_R * 0.8, Vector3.UP)


func _hit_heroes(from: Vector3, to: Vector3) -> bool:
	if not hurts:
		return false
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Node3D
		if hero == null or bool(hero.get("is_dead")) or _hit.has(hero):
			continue
		var low := hero.global_position + Vector3.UP * 0.3
		var high := hero.global_position + Vector3.UP * 1.7
		var pts := Geometry3D.get_closest_points_between_segments(from, to, low, high)
		if pts[0].distance_to(pts[1]) > _radius() + 0.35:
			continue
		# a roll's untouchable frames slip it
		if hero.has_method(&"is_evading") and bool(hero.call(&"is_evading")):
			continue
		_hit[hero] = true
		if hero.has_method(&"receive_blow"):
			hero.call(&"receive_blow", damage, thrower if is_instance_valid(thrower) else self, 0,
					3 if kind == Kind.SMALL else 1, serial)
		if kind == Kind.ROLL:
			# it rolls on over him
			return false
		_shatter(pts[0], -_vel.normalized())
		return true
	return false


## Every peer: dust and grit off it as it flies or rolls.
func _trail(delta: float) -> void:
	_trail_in -= delta
	if _trail_in > 0.0:
		return
	_trail_in = 0.05 if kind != Kind.SMALL else 0.09
	var into := Blood.world_of(self)
	if into == null:
		return
	var at := global_position + (Vector3.DOWN * BIG_R * 0.8 if _rolling else Vector3.ZERO)
	var big := kind != Kind.SMALL
	SkillFx.particles(into, at, {
		"amount": 5 if big else 2, "life": 0.9, "one_shot": true, "explosiveness": 0.9, "add": false,
		"speed": Vector2(0.2, 0.9), "dir": Vector3.UP, "spread": 90.0, "gravity": Vector3(0, 0.2, 0),
		"damping": 1.5, "size": Vector2(0.18, 0.4) * (1.0 if big else 0.5), "grow": 0.8, "sphere": 0.3,
		"colors": [Color(EARTH, 0.0), Color(EARTH, 0.35), Color(EARTH, 0.0)],
	})
	if big and _rng.randf() < 0.5:
		SkillFx.particles(into, at, {
			"amount": 2, "life": 0.6, "one_shot": true, "explosiveness": 1.0, "add": false,
			"speed": Vector2(0.5, 1.5), "dir": Vector3.DOWN, "spread": 60.0, "gravity": Vector3(0, -12, 0),
			"damping": 0.2, "size": Vector2(0.04, 0.07), "sphere": 0.3,
			"colors": [Color(0.3, 0.26, 0.21, 1.0), Color(0.28, 0.24, 0.2, 1.0), Color(0.28, 0.24, 0.2, 0.0)],
		})


func _thud(at: Vector3, power: float) -> void:
	var into := Blood.world_of(self)
	GroundFx.weapon_dust(into, at, power)
	Sfx.play_any(self, ["res://sounds/ogre/club_ground_1.wav", "res://sounds/ogre/club_ground_3.wav"], self,
			randf_range(0.7, 0.8), 0.0)
	WindBlast.shake(self, 0.06 * power, 0.25, 16.0)


## It bursts: pieces bounce away, the ground thrown up; the big one throws
## down whoever is near.
func _shatter(at: Vector3, normal: Vector3) -> void:
	_done = true
	var into := Blood.world_of(self)
	var big := kind != Kind.SMALL
	var power := 1.6 if kind == Kind.BIG else (1.2 if kind == Kind.ROLL else 0.6)
	if into != null:
		GroundFx.weapon_dust(into, at, power)
		if big:
			GroundFx.eruption(into, at, 0.8 if kind == Kind.BIG else 0.6, false)
			SkillFx.particles(into, at + Vector3.UP * 0.4, {
				"amount": 18, "life": 1.8, "one_shot": true, "explosiveness": 0.95, "add": false,
				"speed": Vector2(1.0, 3.0), "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.4, 0),
				"damping": 1.8, "size": Vector2(0.6, 1.2), "grow": 0.9, "sphere": 0.5,
				"colors": [Color(EARTH, 0.0), Color(EARTH, 0.5), Color(EARTH, 0.0)],
			})
		HitFx.spawn(into, &"stone", at, normal, power)
		_pieces(into, at, 7 if kind == Kind.BIG else (5 if kind == Kind.ROLL else 3))
	ImpactFx.thud(self, at, big)
	Sfx.play_any(self, ["res://sounds/ogre/club_ground_2.wav", "res://sounds/ogre/club_ground_4.wav"], self,
			randf_range(0.65, 0.75) if big else 1.0, 2.0 if big else -4.0)
	WindBlast.shake(self, 0.16 if kind == Kind.BIG else 0.08, 0.4, 22.0)
	if hurts and kind == Kind.BIG:
		for node in get_tree().get_nodes_in_group(&"player"):
			var hero := node as Node3D
			if hero == null or _hit.has(hero) or bool(hero.get("is_dead")) or not hero.has_method(&"receive_blow"):
				continue
			var d := hero.global_position.distance_to(at)
			if d > BIG_BLAST or (hero.has_method(&"is_evading") and bool(hero.call(&"is_evading"))):
				continue
			var near := 1.0 - clampf(d / BIG_BLAST, 0.0, 1.0)
			hero.call(&"receive_blow", damage * lerpf(0.4, 0.85, near), thrower if is_instance_valid(thrower) else self,
					0, 1 if near > 0.4 else 3, serial + 1)
	queue_free()


## Every peer: its pieces flung out, a bounce, then sunk into the ground.
func _pieces(into: Node, at: Vector3, count: int) -> void:
	for i in count:
		var p := MeshInstance3D.new()
		p.mesh = mesh("Chunk_%d" % (i % 6))
		p.material_override = material()
		var s := _rng.randf_range(1.2, 2.2) * (1.0 if kind != Kind.SMALL else 0.6)
		p.scale = Vector3.ONE * s
		into.add_child(p)
		p.global_position = at + Vector3.UP * 0.3
		var a := _rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var v := out * _rng.randf_range(2.5, 5.5) + Vector3.UP * _rng.randf_range(3.0, 6.5)
		var spin := Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9), _rng.randf_range(-9, 9))
		var floor_y := at.y
		var state := {"v": v, "t": 0.0, "bounced": false}
		var fly := func(dt: float) -> void:
			if not is_instance_valid(p):
				return
			var vv: Vector3 = state["v"]
			vv.y -= GRAVITY * dt
			var np := p.global_position + vv * dt
			if np.y < floor_y + 0.08 * s:
				np.y = floor_y + 0.08 * s
				if not bool(state["bounced"]):
					state["bounced"] = true
					vv = Vector3(vv.x * 0.45, -vv.y * 0.3, vv.z * 0.45)
				else:
					vv = Vector3(vv.x * 0.6, 0.0, vv.z * 0.6)
			state["v"] = vv
			p.global_position = np
			p.rotation += spin * dt * (1.0 if np.y > floor_y + 0.1 else 0.2)
		var tw := p.create_tween()
		tw.tween_method(func(k: float) -> void:
			var last: float = state["t"]
			state["t"] = k
			fly.call(k - last), 0.0, 1.6, 1.6)
		tw.tween_interval(2.5)
		tw.tween_property(p, "position:y", p.position.y - 0.4, 1.2)
		tw.tween_callback(p.queue_free)
