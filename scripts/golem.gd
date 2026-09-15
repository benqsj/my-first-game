class_name Golem
extends CharacterBody3D

## A stone golem that trudges around its patch of ground.
##
## Unlike the knight and the wolf, this model is a single mesh with no joints
## at all, so there are no limbs to animate. What sells it as walking instead of
## sliding is the body itself: it rocks side to side in time with its steps and
## dips on each footfall, and it leans into turns. Everything else is the same
## wander any idle creature does — pick a spot, walk to it, wait, pick another.

@export_group("Movement")
@export var speed: float = 1.8
@export var acceleration: float = 4.0
@export var turn_speed: float = 5.0
## How far from where it started it will wander.
@export var roam_radius: float = 8.0
## Seconds it stands still between walks.
@export var rest_time: float = 2.5

## Tallest step it trudges up rather than into.
@export var step_height: float = 0.5
@export var step_probe: float = 0.7

@export_group("Gait")
## Distance covered per full two-step cycle, in metres.
@export var stride_length: float = 2.4
## How far it rocks side to side, in radians.
@export var sway: float = 0.09
## How far it dips on each footfall, in metres.
@export var stomp: float = 0.07
## How far it leans into a turn, in radians.
@export var lean: float = 0.12

@onready var body: Node3D = $Visuals

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _home: Vector3
var _target: Vector3
var _wait: float = 0.0
var _phase: float = 0.0
var _body_rest_y: float = 0.0
## The model's own orientation, which the sway is added to rather than
## replacing: writing the whole rotation each frame wiped out the 180° the
## model needs to face the way it walks.
var _body_rest_rotation: Vector3 = Vector3.ZERO
var _turn_rate: float = 0.0
var _rng := RandomNumberGenerator.new()
## The line this golem trudges along, as an offset from home.
var _beat: Vector3 = Vector3.ZERO


func _ready() -> void:
	_home = global_position
	_rng.randomize()
	if body != null:
		_body_rest_y = body.position.y
		_body_rest_rotation = body.rotation
		_settle_on_ground()
	_pick_target()
	# Only the host walks it. `_process` stays on everywhere: that is what
	# animates the body from the replicated position and velocity.
	set_physics_process(_decides())


## True when this peer is the one that decides things. Offline that is everyone,
## which is what keeps a solo game a single code path.
func _decides() -> bool:
	var net := get_node_or_null("/root/Net")
	return net == null or bool(net.call("is_host"))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _wait > 0.0:
		_wait -= delta
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	else:
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() < 1.2:
			_wait = rest_time
			_pick_target()
		else:
			var direction := to_target.normalized()
			var wanted := atan2(-direction.x, -direction.z)
			var before := rotation.y
			rotation.y = lerp_angle(before, wanted, 1.0 - exp(-turn_speed * delta))
			_turn_rate = angle_difference(before, rotation.y) / maxf(delta, 0.001)
			# Walk where it is looking, not where it is aiming to go: moving and
			# turning at once reads as trudging sideways.
			var facing := -global_transform.basis.z
			facing.y = 0.0
			var alignment := clampf(facing.normalized().dot(direction), 0.0, 1.0)
			velocity.x = move_toward(velocity.x, direction.x * speed * alignment, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed * alignment, acceleration * delta)

	StepUp.climb(self, delta, step_height, step_probe)
	move_and_slide()


func _process(delta: float) -> void:
	if body == null:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	_phase = wrapf(_phase + TAU * planar / maxf(stride_length, 0.01) * delta, 0.0, TAU)

	var moving := clampf(planar / maxf(speed, 0.01), 0.0, 1.0)
	body.position.y = _body_rest_y - absf(sin(_phase)) * stomp * moving
	body.rotation = _body_rest_rotation + Vector3(
			# Dips forward as the weight comes down, and leans into the turn.
			absf(sin(_phase)) * 0.05 * moving,
			0.0,
			sin(_phase) * sway * moving + clampf(_turn_rate, -1.0, 1.0) * lean)
	_turn_rate = lerpf(_turn_rate, 0.0, 1.0 - exp(-6.0 * delta))


## Drops the model so its feet rest on the ground rather than sinking into it.
func _settle_on_ground() -> void:
	var lowest := INF
	for m in body.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var in_body := body.global_transform.affine_inverse() * mi.global_transform
		lowest = minf(lowest, (in_body * mi.get_aabb()).position.y)
	if not is_inf(lowest):
		_body_rest_y -= lowest
		body.position.y = _body_rest_y


## Walks a beat: out to one end, turn, back to the other. Picking a fresh
## random spot every time never reads as patrolling — it reads as drifting.
func _pick_target() -> void:
	if _beat == Vector3.ZERO:
		var angle := _rng.randf() * TAU
		_beat = Vector3(cos(angle), 0.0, sin(angle)) * roam_radius
		_target = _home + _beat
	else:
		_target = _home + _beat if _target.distance_to(_home + _beat) > 0.1 else _home - _beat
