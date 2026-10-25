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
## * **BALL** (the user's word, 2026-10-25; three at once since, the elf's
##   ice chain's way: they come up out of the ground together, grind round
##   where they stand, then go one after another, each after the one before,
##   the ground torn where they roll as the orc's blade tears it): a great
##   ball of stone it tears out
##   of the ground with a swing along it and sends rolling after him, three
##   one after another. It comes on faster and faster and turns after him (so
##   far a breath, `BALL_TURN`) till it has gone by him; it bursts on him, on a
##   wall, or far off. A roll through it at the last moment clears it.

## * **TREE** (2026-10-25): its tree, near broken, thrown like a spear, the
##   snapped end first: it goes through whoever it meets, and stands where it
##   comes down, driven into the ground, the ground split out from it.

enum Kind { BIG, ROLL, SMALL, BALL, TREE }

const FILE := "res://assets/creatures/troll_rocks.glb"
const GRAVITY := 18.0
const BIG_R := 0.8
const SMALL_R := 0.4
const BIG_BLAST := 2.6
const ROLL_FAR := 16.0
const ROLL_SPEED := 9.0
const EARTH := Color(0.5, 0.44, 0.36)
const BALL_R := 1.05
const BALL_SPEED := Vector2(4.0, 10.0)
const BALL_SPEED_UP := 5.0
## How quickly it turns after him (rad/s), and for how long it may.
const BALL_TURN := 1.05
const BALL_HUNT := 4.5
const BALL_FAR := 36.0

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
## The ball: whom it rolls after, whether it has given up on him.
var target: Node3D
var _hunting: bool = true
var _rumble_in: float = 0.0
## The ball coming up out of the ground before it rolls (s left).
var _rising: float = 0.0
## The tree's size (its hand's scale and the troll's).
var _size: float = 1.0
const BALL_RISE := 0.45
## Rolled this far between the scars it tears in the ground (m).
const BALL_SCAR := 1.5
## The ball it goes after (the one gone before it), and how long it grinds
## round where it rose before it goes (s).
var follow: TrollRock
var _wait: float = 0.0
var _roll_time: float = 0.0
var _scar_in: float = 0.6
var _grind_in: float = 0.0


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


## Every peer: a great ball of stone come up out of the ground at `from`,
## rolling away along `way` after `after`.
static func roll_ball(into: Node, from: Vector3, way: Vector3, worth: float, by: Node3D, host: bool, id: int,
		after: Node3D, wait: float = 0.0, lead: TrollRock = null) -> TrollRock:
	if into == null:
		return null
	var r := TrollRock.new()
	r.kind = Kind.BALL
	r.damage = worth
	r.thrower = by
	r.hurts = host
	r.serial = id
	r.target = after
	r._rng.seed = id
	var flat := Vector3(way.x, 0.0, way.z)
	r._vel = (flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD) * BALL_SPEED.x
	r._rolling = true
	r._rising = BALL_RISE
	r._wait = wait
	r.follow = lead
	into.add_child(r)
	r.global_position = from + Vector3.DOWN * BALL_R * 0.9
	r._build()
	return r


## Every peer: its tree thrown from `from` at `velocity`.
static func javelin(into: Node, from: Vector3, velocity: Vector3, worth: float, by: Node3D, host: bool, id: int,
		size: float) -> TrollRock:
	if into == null:
		return null
	var r := TrollRock.new()
	r.kind = Kind.TREE
	r.damage = worth
	r.thrower = by
	r.hurts = host
	r.serial = id
	r._vel = velocity
	r._size = size
	r._rng.seed = id
	into.add_child(r)
	r.global_position = from
	r._build()
	r._aim_tree()
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
		_mat.set_shader_parameter("bright", 1.1)
	return _mat


## A rock to hold or throw: the big ones `Boulder_n`, the small `Chunk_n`.
static func model(what: int, pick: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if what == Kind.TREE:
		mi.mesh = mesh("Tree")
	elif what == Kind.BALL:
		mi.mesh = mesh("Ball")
		mi.scale = Vector3.ONE * BALL_R
	elif what == Kind.SMALL:
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
	if kind == Kind.TREE:
		return 0.6
	return SMALL_R if kind == Kind.SMALL else (BALL_R if kind == Kind.BALL else BIG_R)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age > (12.0 if kind == Kind.BALL else 9.0):
		queue_free()
		return
	_trail(delta)
	if _rising > 0.0:
		_rise_up(delta)
		return
	if _wait > 0.0:
		_grind(delta)
		return
	if _rolling:
		_roll(delta)
		return
	var from := global_position
	_vel.y -= GRAVITY * delta
	var to := from + _vel * delta
	if kind == Kind.TREE:
		_aim_tree()
	else:
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
		if kind == Kind.TREE:
			_stick(at)
			return
		_shatter(at, n)
		return
	global_position = to


## The rolling one: along the ground, bouncing a little, at him.
func _roll(delta: float) -> void:
	if kind == Kind.BALL:
		_steer(delta)
	var from := global_position
	var to := from + _vel * delta
	_rolled += _vel.length() * delta
	if kind == Kind.BALL:
		_roll_time += delta
		_scar_in -= _vel.length() * delta
		if _scar_in <= 0.0:
			_scar_in = BALL_SCAR
			_scar(global_position + Vector3.DOWN * BALL_R * 0.9, 0.9)
	var axis := Vector3.UP.cross(_vel.normalized())
	if axis.length_squared() > 0.0001:
		_model.rotate(axis.normalized(), _vel.length() / _radius() * delta)
	if _hit_heroes(from, to):
		return
	var space := get_world_3d().direct_space_state
	# a wall, a pillar: it bursts on it
	var ahead := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + _vel.normalized() * (_radius() + _vel.length() * delta), 1))
	if not ahead.is_empty() and (ahead["normal"] as Vector3).y < 0.5:
		_shatter(ahead["position"], ahead["normal"])
		return
	# the ground under it: kept on it, a hop over a step
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(to + Vector3.UP * 1.5, to + Vector3.DOWN * 3.0, 1))
	if not down.is_empty():
		var g: Vector3 = down["position"]
		to.y = g.y + _radius() * 0.9 + absf(sin(_rolled * 1.7)) * (0.05 if kind == Kind.BALL else 0.12)
	global_position = to
	if _rolled >= (BALL_FAR if kind == Kind.BALL else ROLL_FAR):
		_shatter(global_position - Vector3.UP * _radius() * 0.8, Vector3.UP)


## The ball up out of the ground, turning as it comes, earth falling off it.
func _rise_up(delta: float) -> void:
	_rising -= delta
	var k := delta / BALL_RISE
	global_position += Vector3.UP * BALL_R * 1.8 * k
	var axis := Vector3.UP.cross(_vel.normalized())
	if axis.length_squared() > 0.0001:
		_model.rotate(axis.normalized(), 2.5 * delta)
	if _rising <= 0.0:
		_thud(global_position + Vector3.DOWN * BALL_R * 0.9, 1.0)


## The ball grinding round where it rose, waiting its turn: spun hard on the
## spot, the ground ground up under it; then away.
func _grind(delta: float) -> void:
	_wait -= delta
	if _hit_heroes(global_position, global_position + Vector3.UP * 0.01):
		return
	var axis := Vector3.UP.cross(_vel.normalized())
	if axis.length_squared() > 0.0001:
		_model.rotate(axis.normalized(), 9.0 * delta)
	_grind_in -= delta
	if _grind_in <= 0.0:
		_grind_in = 0.12
		var into := Blood.world_of(self)
		var at := global_position + Vector3.DOWN * BALL_R * 0.85
		SkillFx.burst(into, at - _vel.normalized() * 0.5, Color(0.46, 0.4, 0.32, 0.6), 6, Vector2(1.0, 3.0),
				(Vector3.UP - _vel.normalized()).normalized(), 40.0, Vector2(0.08, 0.16), Vector3(0, -3.0, 0), 0.7)
		SkillFx.burst(into, at, Color(0.26, 0.22, 0.17, 1.0), 4, Vector2(2.0, 4.0),
				(Vector3.UP - _vel.normalized()).normalized(), 35.0, Vector2(0.03, 0.06), Vector3(0, -12.0, 0), 0.6)
		Sfx.play(self, "res://sounds/ogre/step.wav", self, Vector3.DOWN * BALL_R, randf_range(0.4, 0.5), -6.0)
	if _wait <= 0.0:
		_vel = _vel.normalized() * BALL_SPEED.x * 1.5
		_scar(global_position + Vector3.DOWN * BALL_R * 0.9, 1.2)
		Sfx.play_any(self, ["res://sounds/ogre/club_ground_1.wav", "res://sounds/ogre/club_ground_3.wav"], self,
				randf_range(0.6, 0.7), 0.0)
		WindBlast.shake(self, 0.08, 0.3, 16.0)


## Every peer: the ground torn where it rolls (the orc's blade's crack: a
## dark split, dust and grit thrown up; a floor that keeps scars keeps it).
func _scar(at: Vector3, weight: float) -> void:
	var into := Blood.world_of(self)
	if into == null:
		return
	var crack := DarkFx.decal(into, at, DarkFx.CRACK, 1.9 * weight + _rng.randf_range(0.0, 0.5),
			Color(0.1, 0.08, 0.06, 1.0), 0.0, 0.9)
	crack.rotation.y = _rng.randf() * TAU
	var tw := crack.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(crack, "modulate:a", 0.0, 2.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(crack.queue_free)
	SkillFx.burst(into, at + Vector3.UP * 0.1, Color(0.46, 0.4, 0.32, 0.6), int(10 + 8 * weight),
			Vector2(1.2, 3.5), Vector3.UP, 75.0, Vector2(0.08, 0.16), Vector3(0, -2.0, 0), 0.9)
	SkillFx.burst(into, at + Vector3.UP * 0.1, Color(0.24, 0.2, 0.15, 1.0), int(5 + 5 * weight),
			Vector2(2.5, 5.5), Vector3.UP, 55.0, Vector2(0.03, 0.06), Vector3(0, -12.0, 0), 0.7)
	get_tree().call_group(&"ground_scars", &"scar", at, weight * 0.8)


## The ball: faster and faster, turned after him as far as it may, till it
## has gone by him or rolled so long; heard rumbling over the ground.
func _steer(delta: float) -> void:
	var speed := minf(_vel.length() + BALL_SPEED_UP * delta, BALL_SPEED.y)
	var way := _vel.normalized() if _vel.length_squared() > 0.0001 else Vector3.FORWARD
	if follow != null and (not is_instance_valid(follow) or follow._done):
		follow = null
	if follow != null:
		# after the one before it, along its line (quicker to turn, to keep on it)
		var lead := follow.global_position - global_position
		lead.y = 0.0
		if lead.length_squared() > 0.01:
			var t2 := clampf(way.signed_angle_to(lead.normalized(), Vector3.UP), -BALL_TURN * 2.2 * delta,
					BALL_TURN * 2.2 * delta)
			way = way.rotated(Vector3.UP, t2)
	elif _hunting and is_instance_valid(target) and _roll_time < BALL_HUNT and not bool(target.get("is_dead")):
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() < 2.5 or to.normalized().dot(way) < -0.2:
			_hunting = false  # it has gone by him: on it goes
		else:
			var turn := clampf(way.signed_angle_to(to.normalized(), Vector3.UP), -BALL_TURN * delta, BALL_TURN * delta)
			way = way.rotated(Vector3.UP, turn)
	_vel = way * speed
	_rumble_in -= delta
	if _rumble_in <= 0.0:
		_rumble_in = clampf(2.6 / maxf(speed, 1.0), 0.25, 0.6)
		Sfx.play(self, "res://sounds/ogre/step.wav", self, Vector3.DOWN * BALL_R, randf_range(0.45, 0.55), -2.0)
		WindBlast.shake(self, 0.02, 0.2, 9.0)


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
		if kind == Kind.BALL:
			_shatter(global_position - Vector3.UP * BALL_R * 0.5, -_vel.normalized())
			return true
		if kind == Kind.TREE:
			# on through him
			continue
		_shatter(pts[0], -_vel.normalized())
		return true
	return false


## Every peer, the tree in flight: earth and leaves shaken off its roots
## behind it, splinters off its snapped end, a rush of dust after it.
func _tree_trail(into: Node) -> void:
	var back := -_vel.normalized() if _vel.length_squared() > 0.0001 else Vector3.UP
	var roots := global_position + back * 1.3 * _size
	SkillFx.particles(into, roots, {
		"amount": 6, "life": 1.1, "one_shot": true, "explosiveness": 1.0, "add": false,
		"speed": Vector2(0.5, 2.0), "dir": back, "spread": 70.0, "gravity": Vector3(0, -9, 0),
		"damping": 0.5, "size": Vector2(0.05, 0.11), "sphere": 0.35,
		"colors": [Color(0.36, 0.27, 0.18, 1.0), Color(0.33, 0.25, 0.17, 1.0), Color(0.3, 0.23, 0.16, 0.0)],
	})
	if _rng.randf() < 0.6:
		SkillFx.particles(into, roots, {
			"amount": 3, "life": 1.6, "one_shot": true, "explosiveness": 1.0, "add": false,
			"speed": Vector2(0.3, 1.2), "dir": back, "spread": 90.0, "gravity": Vector3(0, -2.5, 0),
			"damping": 1.5, "size": Vector2(0.06, 0.1), "sphere": 0.4,
			"colors": [Color(0.42, 0.5, 0.25, 1.0), Color(0.38, 0.45, 0.22, 1.0), Color(0.35, 0.4, 0.2, 0.0)],
		})
	SkillFx.particles(into, global_position, {
		"amount": 3, "life": 0.8, "one_shot": true, "explosiveness": 1.0, "add": false,
		"speed": Vector2(0.2, 0.7), "dir": back, "spread": 60.0, "gravity": Vector3(0, 0.3, 0),
		"damping": 1.5, "size": Vector2(0.3, 0.6), "grow": 1.0, "sphere": 0.5,
		"colors": [Color(EARTH, 0.0), Color(EARTH, 0.3), Color(EARTH, 0.0)],
	})


## The tree along its flight, the snapped end first (its root end, +Y in
## the model, behind).
func _aim_tree() -> void:
	if _vel.length_squared() < 0.0001:
		return
	var y := -_vel.normalized()
	var x := y.cross(Vector3.UP)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	# a heavy shaft's shudder as it goes
	var wob := sin(_age * 22.0) * 0.06
	_model.global_basis = (Basis(x, y, z) * Basis(Vector3.RIGHT, wob)).scaled(Vector3.ONE * _size)


## Every peer: the tree down, driven into the ground where it came, standing
## there aslant, the ground split out ahead of it; whoever is near it thrown
## down (the host); a while, then down into the ground and gone.
func _stick(at: Vector3) -> void:
	_done = true
	var way := Vector3(_vel.x, 0.0, _vel.z)
	way = way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD
	global_position = at + _vel.normalized() * 0.6 * _size
	var into := Blood.world_of(self)
	if into != null:
		GroundFx.eruption(into, at, 1.0, false)
		GroundFx.weapon_dust(into, at, 1.8)
		HitFx.spawn(into, &"stone", at, Vector3.UP, 1.6)
		for deg in [-28.0, 0.0, 28.0]:
			GroundCrack.show(self, at, way.rotated(Vector3.UP, deg_to_rad(deg)), 4.5, 12.0)
		_scar(at, 1.4)
		RockWave.spawn(into, at + way * 0.8, 2.6, 0.7, 16.0, serial * 13 + 3)
		var crack := DarkFx.decal(into, at, DarkFx.CRACK, 4.2, Color(0.09, 0.07, 0.05, 1.0), 0.0, 0.92)
		crack.rotation.y = _rng.randf() * TAU
		var ctw := crack.create_tween()
		ctw.tween_interval(4.0)
		ctw.tween_property(crack, "modulate:a", 0.0, 2.5).set_ease(Tween.EASE_IN)
		ctw.tween_callback(crack.queue_free)
		SkillFx.burst(into, at + Vector3.UP * 0.2, Color(0.45, 0.39, 0.31, 0.65), 50, Vector2(2.0, 6.0), Vector3.UP, 80.0,
				Vector2(0.12, 0.3), Vector3(0, -1.5, 0), 1.5)
		if into is Node3D:
			scatter(into as Node3D, at, 9, Vector2(1.2, 2.4), Vector2(2.5, 6.0), Vector2(3.5, 7.0), way * 0.6, serial)
		# splinters off it, earth off its roots
		SkillFx.burst(into, global_position, Color(0.6, 0.47, 0.32, 1.0), 24, Vector2(2.0, 6.0), Vector3.UP, 100.0,
				Vector2(0.04, 0.1), Vector3(0, -12.0, 0), 1.0)
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.3, 0.6, 28.0)
	Sfx.play_any(self, ["res://sounds/ogre/club_ground_2.wav", "res://sounds/ogre/club_ground_4.wav"], self, 0.55, 6.0)
	if hurts:
		for node in get_tree().get_nodes_in_group(&"player"):
			var hero := node as Node3D
			if hero == null or _hit.has(hero) or bool(hero.get("is_dead")) or not hero.has_method(&"receive_blow"):
				continue
			if hero.global_position.distance_to(at) > 2.6 or (hero.has_method(&"is_evading") and bool(hero.call(&"is_evading"))):
				continue
			hero.call(&"receive_blow", damage * 0.7, thrower if is_instance_valid(thrower) else self, 0, 1, serial + 1)
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(self, "global_position", global_position + Vector3.DOWN * 2.5 * _size, 1.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## Every peer: dust and grit off it as it flies or rolls.
func _trail(delta: float) -> void:
	_trail_in -= delta
	if _trail_in > 0.0:
		return
	_trail_in = 0.05 if kind != Kind.SMALL else 0.09
	var into := Blood.world_of(self)
	if into == null:
		return
	if kind == Kind.TREE:
		_tree_trail(into)
		return
	var at := global_position + (Vector3.DOWN * _radius() * 0.8 if _rolling else Vector3.ZERO)
	var big := kind != Kind.SMALL
	SkillFx.particles(into, at, {
		"amount": 9 if kind == Kind.BALL else (5 if big else 2), "life": 0.9, "one_shot": true, "explosiveness": 0.9, "add": false,
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
	var power := 1.9 if kind == Kind.BALL else (1.6 if kind == Kind.BIG else (1.2 if kind == Kind.ROLL else 0.6))
	if into != null:
		GroundFx.weapon_dust(into, at, power)
		if big:
			GroundFx.eruption(into, at, 1.0 if kind == Kind.BALL else (0.8 if kind == Kind.BIG else 0.6), false)
			SkillFx.particles(into, at + Vector3.UP * 0.4, {
				"amount": 18, "life": 1.8, "one_shot": true, "explosiveness": 0.95, "add": false,
				"speed": Vector2(1.0, 3.0), "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.4, 0),
				"damping": 1.8, "size": Vector2(0.6, 1.2), "grow": 0.9, "sphere": 0.5,
				"colors": [Color(EARTH, 0.0), Color(EARTH, 0.5), Color(EARTH, 0.0)],
			})
		HitFx.spawn(into, &"stone", at, normal, power)
		_pieces(into, at, 10 if kind == Kind.BALL else (7 if kind == Kind.BIG else (5 if kind == Kind.ROLL else 3)))
	ImpactFx.thud(self, at, big)
	Sfx.play_any(self, ["res://sounds/ogre/club_ground_2.wav", "res://sounds/ogre/club_ground_4.wav"], self,
			randf_range(0.65, 0.75) if big else 1.0, 2.0 if big else -4.0)
	WindBlast.shake(self, 0.2 if kind == Kind.BALL else (0.16 if kind == Kind.BIG else 0.08), 0.4, 22.0)
	if hurts and (kind == Kind.BIG or kind == Kind.BALL):
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
	var small := kind == Kind.SMALL
	scatter(into as Node3D if into is Node3D else self, at, count,
			Vector2(1.2, 2.2) * (0.6 if small else 1.0), Vector2(2.5, 5.5), Vector2(3.0, 6.5), Vector3.ZERO, serial)


## Every peer: stone pieces thrown out from `at` (sizes `size`, out at
## `speed`, up at `up`, leant along `bias`, from within `spread` of it), each
## falling to the ground under it, a bounce, a while lying there, then down
## into the ground and gone (the user's word, 2026-10-25: they hung in the
## air; then, left lying, they stayed for good).
static func scatter(into: Node3D, at: Vector3, count: int, size: Vector2, speed: Vector2, up: Vector2,
		bias: Vector3 = Vector3.ZERO, seed: int = 0, spread: float = 0.0, lie: float = 2.0) -> void:
	if into == null or not into.is_inside_tree():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + count
	var ground_y := at.y - 1.5
	var down := into.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 8.0, 1))
	if not down.is_empty():
		ground_y = (down["position"] as Vector3).y
	for i in count:
		var p := MeshInstance3D.new()
		p.mesh = mesh("Chunk_%d" % (i % 6))
		p.material_override = material()
		var s := rng.randf_range(size.x, size.y)
		p.scale = Vector3.ONE * s
		into.add_child(p)
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		p.global_position = at + Vector3.UP * 0.3 + out * rng.randf_range(0.0, spread)
		var v := (out + bias).normalized() * rng.randf_range(speed.x, speed.y) + Vector3.UP * rng.randf_range(up.x, up.y)
		var spin := Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		var floor_y := ground_y
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
		tw.tween_interval(lie)
		# then down into the ground from where it lies (not from where it was
		# thrown: that lifted it back up into the air) and gone
		tw.tween_callback(func() -> void:
			if not is_instance_valid(p):
				return
			var sink := p.create_tween().set_parallel(true)
			sink.tween_property(p, "global_position:y", p.global_position.y - 0.45 * s, 1.0).set_ease(Tween.EASE_IN)
			sink.tween_property(p, "scale", p.scale * 0.4, 1.0).set_ease(Tween.EASE_IN)
			sink.chain().tween_callback(p.queue_free))
