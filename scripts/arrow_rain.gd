class_name ArrowRain
extends Node3D

## Avtandil's Rain of Arrows: a volley of arrows coming down over a patch of
## ground — on what he has locked, following it, or ahead of him. What it
## throws off besides (off the bow, over the patch, where the arrows land) is
## [RainFx]'s, in the look picked there.
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
	"res://unverified/sounds/tariel/air_1.wav", "res://unverified/sounds/tariel/air_3.wav", "res://unverified/sounds/tariel/air_5.wav",
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
## What it throws off besides its arrows ([RainFx]): over the patch, and when
## the volley starts down.
var _fx: RainFx
var _fell: bool = false
var _settled: bool = false


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
	_fx = RainFx.cover(self, radius, delay, duration)
	# the shot up, off his bow, as it goes
	if shooter != null and is_instance_valid(shooter) and shooter.is_inside_tree():
		var rig: Variant = shooter.get(&"rig")
		var hand := shooter.global_position + Vector3.UP * 1.4
		if rig is Object and is_instance_valid(rig) and (rig as Object).has_method(&"bow_hand"):
			hand = (rig as Object).call(&"bow_hand")
		var toward := global_position - shooter.global_position
		toward.y = 0.0
		var up := (toward.normalized() * 0.3 + Vector3.UP).normalized() if toward.length_squared() > 0.01 else Vector3.UP
		RainFx.loosed(get_parent(), hand, up, shooter.global_position)


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
	if not _fell and _clock >= delay - 0.12 and _fx != null:
		_fell = true
		_fx.falling(global_position + Vector3.UP * height + _back() * lean_back, duration)
	if not _settled and _clock >= delay + duration * 0.55 and _fx != null:
		_settled = true
		_fx.settle()
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
	var back := _back()
	var scatter := Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.8, 0.8))
	var from := land + Vector3.UP * height + back * lean_back + scatter
	var arrow := _scene.instantiate() as Node3D
	if arrow == null:
		return
	arrow.set(&"linger", 5.0)
	arrow.set(&"lifetime", 3.0)
	arrow.set(&"wake_spread", 0.0)
	arrow.set(&"trail_width", 0.035)
	if RainFx.look == RainFx.GOLD:
		arrow.set(&"streak_tint", Color(1.0, 0.82, 0.4, 0.75))
	into.add_child(arrow)
	if arrow.has_signal(&"struck"):
		arrow.connect(&"struck", _on_struck)
	arrow.global_position = from
	var critical := _rng.randf() < _crit_chance
	arrow.call(&"launch", (land - from).normalized() * speed, _damage * (_crit_damage if critical else 1.0),
			critical, 6.0, _shooter)
	arrows.append(arrow)


## The way back towards the archer, flat (none once he is gone).
func _back() -> Vector3:
	if _shooter == null or not is_instance_valid(_shooter):
		return Vector3.ZERO
	var back := _shooter.global_position - global_position
	back.y = 0.0
	return back.normalized() if back.length_squared() > 0.01 else Vector3.ZERO


## One of the volley went into something: the ground kicks up ([RainFx]); a
## body bleeds on its own ([Blood], in the arrow).
func _on_struck(what: Node3D, where: Vector3, _critical: bool) -> void:
	if what != null and what.has_method(&"take_hit"):
		return
	RainFx.landed(get_parent() if is_inside_tree() else null, where)
