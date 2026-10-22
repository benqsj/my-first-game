class_name Flyer
extends Fighter

## A small thing on wings in the orcs' palace, the second half of the run
## (the user's word, 2026-10-22): Quaternius' Ghost_Skull, about a thrown
## torch's size, throwing balls of blue soul; Dragon_Evolved the same size,
## throwing fire. Several come together. They keep off him in a ring, wheeling
## round him, never higher than a sword reaches, and now and then one stops,
## draws back and throws ([SpellBolt], against the heroes: rolled out of the
## way of, it flies on past). Close in, they back off — but not out of reach.
##
## The [Fighter]'s body otherwise: health and its bar, the blade's capsule,
## its death (it falls out of the air) and its band. Its clips are its own
## model's (`clip_source` is the model).

## How far off it keeps (m), and how fast it wheels round him (rad/s).
@export var keep: Vector2 = Vector2(5.5, 8.5)
@export var wheel: float = 0.45
## How high it flies over the floor (m, its body's foot): a sword's reach.
@export var hover: Vector2 = Vector2(0.95, 1.4)
@export var fly_speed: float = 4.2
## Between its throws (s), the draw-back before one leaves (s), how fast it
## flies, and its light.
@export var throw_every: Vector2 = Vector2(3.5, 6.5)
@export var throw_tell: float = 0.5
@export var bolt_speed: float = 13.0
@export var bolt_colour: Color = Color(0.45, 0.75, 1.0)
@export var throw_clip: StringName = &"Headbutt"
@export var bolt_scene: PackedScene = preload("res://scenes/fx/spell_bolt.tscn")
## Within this far it throws.
@export var throw_range: float = 16.0

var _floor_y: float = NAN
var _floor_in: float = 0.0
var _side: float = 1.0
var _angle: float = 0.0
var _throw_in: float = 2.0
var _telling: float = -1.0
var _bob: float = 0.0
var _height: float = 1.4


func _ready() -> void:
	super()
	# it flies: nothing pulls it down while it lives
	_gravity = 0.0
	_side = 1.0 if randf() < 0.5 else -1.0
	_throw_in = randf_range(1.5, throw_every.y)
	_bob = randf() * TAU
	_height = randf_range(hover.x, hover.y)
	_angle = randf() * TAU


func _think(delta: float) -> void:
	_quarry = _pick_quarry()
	_floor_in -= delta
	if _floor_in <= 0.0 or is_nan(_floor_y):
		_floor_in = 0.25
		_find_floor()
	_bob += delta
	var want := Vector3.ZERO
	if mode == Mode.GUARD:
		if _quarry != null and _distance_to(_quarry) < sight_range:
			_rouse(_quarry)
	elif _quarry == null:
		# lost him (out of its ground): back to its watch
		mode = Mode.GUARD
	elif act != Act.NONE:
		# struck, reeling: no steering of its own till it has
		want = Vector3(velocity.x, 0.0, velocity.z) * 0.9
	elif _quarry != null:
		mode = Mode.FIGHT
		var to := _quarry.global_position - global_position
		to.y = 0.0
		var gap := to.length()
		if gap > 0.01:
			_angle = atan2(-to.x, -to.z)
		_angle += wheel * _side * delta * (0.3 if _telling >= 0.0 else 1.0)
		var ring := clampf(gap, keep.x, keep.y)
		var spot := _quarry.global_position + Vector3(sin(_angle), 0.0, cos(_angle)) * ring
		var off := spot - global_position
		off.y = 0.0
		want = off.limit_length(1.0) * fly_speed * clampf(off.length() / 2.0, 0.0, 1.0)
		# too near: away, a little faster
		if gap < keep.x * 0.6:
			want += -to.normalized() * fly_speed * 0.8
		# never faster than a hero runs: it can be caught
		want = want.limit_length(fly_speed)
		_face(to, delta, turn_speed)
		_throwing(delta, gap)
	# held at its height over the floor, bobbing
	var y_want := global_position.y
	if not is_nan(_floor_y):
		y_want = _floor_y + _height + sin(_bob * 1.7) * 0.18
	want.y = clampf((y_want - global_position.y) * 3.0, -3.0, 3.0)
	velocity = velocity.move_toward(want, acceleration * 1.5 * delta)


func _find_floor() -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5,
			global_position + Vector3.DOWN * 8.0, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_floor_y = (hit["position"] as Vector3).y


## Now and then a throw: it slows, draws back (its clip), and lets go.
func _throwing(delta: float, gap: float) -> void:
	if _telling >= 0.0:
		_telling += delta
		if _telling >= throw_tell:
			_telling = -1.0
			if _quarry != null and is_instance_valid(_quarry):
				var from := global_position + Vector3.UP * body_height * 0.5 * visual_scale \
						+ (-global_transform.basis.z) * 0.3
				var aim := (_quarry.global_position + Vector3.UP * 1.1 - from).normalized()
				net_throw.rpc(from, aim * bolt_speed, _quarry.get_path())
		return
	_throw_in -= delta
	if _throw_in > 0.0 or gap > throw_range or not Fighter.claim_throw(_quarry):
		return
	_throw_in = randf_range(throw_every.x, throw_every.y)
	_telling = 0.0
	net_tell.rpc()


@rpc("authority", "call_local", "reliable")
func net_tell() -> void:
	if _anim != null and _anim.has_clip(throw_clip):
		_anim.play(throw_clip, 0.12, 1.0, 1.0, true)


@rpc("authority", "call_local", "reliable")
func net_throw(from: Vector3, flight: Vector3, quarry: NodePath) -> void:
	var into := Blood.world_of(self)
	if into == null or bolt_scene == null:
		return
	var bolt := bolt_scene.instantiate() as Node3D
	bolt.set(&"against_heroes", true)
	bolt.set(&"glow_colour", bolt_colour)
	into.add_child(bolt)
	bolt.global_position = from
	bolt.call(&"launch", flight, hit_damage, false, 0.0, self)
	var who := get_node_or_null(quarry) as Node3D
	if who != null and bolt.has_method(&"hunt"):
		bolt.call(&"hunt", who)


## Its wings beat whatever it does, faster on the move; the throw's clip plays
## out first.
func _play_locomotion(_delta: float) -> void:
	if _anim == null:
		return
	var now := _anim.current_clip()
	if now == throw_clip and _anim.clip_progress() < 1.0:
		return
	var pace := Vector2(velocity.x, velocity.z).length()
	var clip := walk_clip if pace > fly_speed * 0.6 else idle_clip
	_anim.play(clip, 0.25, 1.0)


## Dead, it drops out of the air.
func _die() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	super()
