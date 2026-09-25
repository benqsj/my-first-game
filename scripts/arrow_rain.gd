class_name ArrowRain
extends Node3D

## Avtandil's Rain of Arrows: a ring on the ground where it will fall, and a
## moment later a volley of arrows coming down over it.
##
## The arrows are ordinary [Arrow]s — they sweep for what they cross, stick in
## what they hit and sink away — so a rain hurts exactly as arrows do: only the
## host's copies count for damage, every peer sees them all. Every peer builds
## the same rain from the same seed, so the arrows fall in the same places for
## everyone without one of them being sent over the wire.
##
## They come down a little slanted, from the archer's side of the ring, the way
## a volley shot high over a line would, and the ring stays lit while they fall
## so it is clear where not to stand. A share of them (`aimed`) comes down on
## the bodies standing in the ring when it starts to fall — spread evenly, a
## volley over a wolf would mostly miss the wolf.

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
const RING := Color(1.0, 0.86, 0.55)

var _shooter: Node3D
var _scene: PackedScene
var _rng := RandomNumberGenerator.new()
var _damage: float = 10.0
var _crit_chance: float = 0.1
var _crit_damage: float = 2.0
var _clock: float = 0.0
var _sent: int = 0
var _next_whistle: float = 0.0
var _ring: MeshInstance3D
var _disc: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _disc_mat: StandardMaterial3D
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


func _ready() -> void:
	_ring_mat = _glow(RING)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.09
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, 0.25, 1.0)
	_ring.position = Vector3.UP * 0.06
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_disc_mat = _glow(Color(RING, 0.0))
	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 48
	disc.rings = 1
	_disc.mesh = disc
	_disc.position = Vector3.UP * 0.04
	_disc.material_override = _disc_mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)


func _glow(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = colour
	m.no_depth_test = false
	return m


func _process(delta: float) -> void:
	_clock += delta
	var end := delay + duration
	# The ring: comes up at once, pulses while the arrows fall, fades after.
	var shown := clampf(_clock / 0.15, 0.0, 1.0) * (1.0 - clampf((_clock - end - 0.3) / 0.8, 0.0, 1.0))
	var pulse := 0.75 + 0.25 * sin(_clock * 12.0)
	_ring_mat.albedo_color = Color(RING, 0.85 * shown * pulse)
	_disc_mat.albedo_color = Color(RING, 0.13 * shown)
	# The arrows, spread evenly over the fall.
	var due := int(ceil(float(count) * clampf((_clock - delay) / duration, 0.0, 1.0)))
	if due > 0 and _sent == 0:
		_find_marks()
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
	arrow.set(&"linger", 2.5)
	arrow.set(&"lifetime", 3.0)
	arrow.set(&"wake_spread", 0.0)
	arrow.set(&"trail_width", 0.035)
	into.add_child(arrow)
	arrow.global_position = from
	var critical := _rng.randf() < _crit_chance
	arrow.call(&"launch", (land - from).normalized() * speed, _damage * (_crit_damage if critical else 1.0),
			critical, 6.0, _shooter)
	arrows.append(arrow)
