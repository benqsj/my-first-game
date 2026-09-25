class_name ArrowRain
extends Node3D

## Avtandil's Rain of Arrows: a volley of arrows coming down over a patch of
## ground — on what he has locked, following it, or ahead of him. Nothing marks
## the ground: what is seen is the arrow he sends up and the rain after it.
##
## The arrows are ordinary [Arrow]s — they sweep for what they cross, stick in
## what they hit and sink away — so a rain hurts exactly as arrows do: only the
## host's copies count for damage, every peer sees them all. Every peer builds
## the same rain from the same seed, so the arrows fall in the same places for
## everyone without one of them being sent over the wire.
##
## They come down a little slanted, from the archer's side, the way a volley
## shot high over a line would. A share of them (`aimed`) comes down on the
## bodies standing in the patch — the locked one above all — and the patch
## goes with the locked one while it falls, so running out from under it does
## not save it: spread evenly, a volley over a wolf would mostly miss the wolf.

## How wide the rain falls, in metres.
@export var radius: float = 3.8
## How many arrows, over how long, after how long.
@export var count: int = 36
@export var delay: float = 0.75
@export var duration: float = 1.3
## Where they come from: this high over the ground, and this far back towards
## the archer.
@export var height: float = 17.0
@export var lean_back: float = 3.0
@export var speed: float = 30.0
## The share of the arrows that come down on a body in the ring.
@export_range(0.0, 1.0) var aimed: float = 0.3

const WHISTLES: Array[String] = [
	"res://sounds/tariel/air_1.wav", "res://sounds/tariel/air_3.wav", "res://sounds/tariel/air_5.wav",
]

var _shooter: Node3D
var _scene: PackedScene
var _rng := RandomNumberGenerator.new()
var _damage: float = 10.0
var _crit_chance: float = 0.1
var _crit_damage: float = 2.0
var _clock: float = 0.0
var _sent: int = 0
var _next_whistle: float = 0.0
## What it was loosed at, if anything: the rain follows it.
var _follow: Node3D
## The bodies in the ring when the arrows start to fall.
var _marks: Array[Node3D] = []
## The arrows sent down so far, for the tests.
var arrows: Array[Node3D] = []


## Sets it going. `rain_seed` is the same on every peer, so the arrows are too.
func start(shooter: Node3D, scene: PackedScene, rain_seed: int, damage: float, crit_chance: float,
		crit_damage: float) -> void:
	_shooter = shooter
	_scene = scene
	_rng.seed = rain_seed
	_damage = damage
	_crit_chance = crit_chance
	_crit_damage = crit_damage
	_next_whistle = delay
	Sfx.warm(WHISTLES)


## Makes the rain fall on `who` wherever it goes while the arrows come down.
func follow(who: Node3D) -> void:
	_follow = who


func _process(delta: float) -> void:
	_clock += delta
	var end := delay + duration
	if _follow != null and is_instance_valid(_follow) and _clock < end:
		var at := _follow.global_position
		global_position = Vector3(at.x, global_position.y + (at.y - global_position.y) * 0.2, at.z)
	# The arrows, spread evenly over the fall.
	var due := int(ceil(float(count) * clampf((_clock - delay) / duration, 0.0, 1.0)))
	if due > 0 and _sent == 0:
		_find_marks()
		if _follow != null and is_instance_valid(_follow) and not _marks.has(_follow):
			_marks.push_front(_follow)
	while _sent < due:
		_drop()
		_sent += 1
	if _clock >= _next_whistle and _clock < end:
		_next_whistle += 0.3
		var at := global_position + Vector3(_rng.randf_range(-1.5, 1.5), 3.0, _rng.randf_range(-1.5, 1.5))
		Sfx.play(self, WHISTLES[_sent % WHISTLES.size()], null, at, 1.55, -12.0)
	if _clock > end + 1.2:
		queue_free()


## What stands in the ring: anything on the creatures' layer.
func _find_marks() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.9)
	query.collision_mask = 4
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body := hit["collider"] as Node3D
		if body != null and body != _shooter and body.has_method(&"take_hit") and not _marks.has(body):
			_marks.append(body)


## One arrow: somewhere in the ring — or on a body in it — dropped from high up
## and a little back towards the archer.
func _drop() -> void:
	var into := get_parent()
	if _scene == null or into == null:
		return
	var a := _rng.randf() * TAU
	var r := radius * sqrt(_rng.randf())
	var land := global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	# Drawn every time, so the seeded sequence is the same whatever is standing
	# in the ring on this peer.
	var on_mark := _rng.randf() < aimed
	var which := _rng.randi()
	if on_mark and not _marks.is_empty():
		var mark := _marks[which % _marks.size()]
		if is_instance_valid(mark):
			land = mark.global_position + Vector3.UP * 0.9 + Vector3(cos(a), 0.0, sin(a)) * 0.2
	var back := Vector3.ZERO
	if _shooter != null and is_instance_valid(_shooter):
		back = _shooter.global_position - global_position
		back.y = 0.0
		back = back.normalized() if back.length_squared() > 0.01 else Vector3.ZERO
	var scatter := Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.8, 0.8))
	var from := land + Vector3.UP * height + back * lean_back + scatter
	var arrow := _scene.instantiate() as Node3D
	if arrow == null:
		return
	arrow.set(&"linger", 5.0)
	arrow.set(&"lifetime", 3.0)
	arrow.set(&"wake_spread", 0.0)
	arrow.set(&"trail_width", 0.035)
	into.add_child(arrow)
	arrow.global_position = from
	var critical := _rng.randf() < _crit_chance
	arrow.call(&"launch", (land - from).normalized() * speed, _damage * (_crit_damage if critical else 1.0),
			critical, 6.0, _shooter)
	arrows.append(arrow)
