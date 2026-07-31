class_name Player
extends CharacterBody3D

## Placeholder third-person controller for greyboxing.
##
## Camera-relative WASD movement, gravity, jump (with coyote time + input
## buffering) and a dash / dodge roll with i-frames and a cooldown.
## The capsule mesh is a stand-in for the Blender knight models.

signal jumped
signal landed
signal dash_started(direction: Vector3)
signal dash_ended
signal attack_started
signal block_changed(raised: bool)

enum State { GROUNDED, AIRBORNE, DASHING }

## Extra distance used when probing for an obstacle ahead of the capsule.
const STEP_PROBE_SKIN := 0.05
## How many forward samples the step-up sweep takes before giving up.
const STEP_PROBE_SAMPLES := 4

#region Exported tuning
@export_group("Movement")
## Speed while the walk modifier is held.
@export var walk_speed: float = 4.5
## Speed with no modifier held — running is the default gait.
@export var run_speed: float = 9.0
## How hard the character can change its ground velocity. High values are what
## keep a fast run from sliding on through a turn or a release.
@export var ground_acceleration: float = 60.0
@export var ground_deceleration: float = 75.0
## How much control the player keeps mid-air (0 = none, 1 = full).
@export_range(0.0, 1.0) var air_control: float = 0.35
## How fast the body turns to face its movement direction.
@export var turn_speed: float = 12.0
## Tallest ledge the player walks up without jumping. CharacterBody3D has no
## built-in stair stepping, so this is resolved manually in _step_up().
@export var max_step_height: float = 0.4
## How far ahead the step-up sweep reaches. Must exceed the capsule radius or
## the sweep lands on the ledge's edge instead of its top face.
@export var step_forward_probe: float = 0.55

@export_group("Jump")
## Apex height in metres, converted to an impulse using the project gravity.
@export var jump_height: float = 1.4
## Gravity is multiplied by this while falling, for a snappier arc.
@export var fall_gravity_multiplier: float = 1.5
## Gravity multiplier applied while the jump button is released early.
@export var low_jump_multiplier: float = 2.0
## Grace period after walking off a ledge during which jumping still works.
@export var coyote_time: float = 0.12
## How long a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.12

@export_group("Dash")
@export var dash_speed: float = 11.0
@export var dash_duration: float = 0.45
@export var dash_cooldown: float = 0.22
## Invulnerability window measured from the start of the dash.
@export var dash_iframes: float = 0.3
## Dashes are ignored while airborne when false.
@export var allow_air_dash: bool = false

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var invert_y: bool = false
@export_range(-89.0, 0.0) var min_pitch_deg: float = -60.0
@export_range(0.0, 89.0) var max_pitch_deg: float = 60.0
## Height of the camera pivot above the player's feet.
@export var camera_height: float = 1.5
## Higher values make the camera stick to the player more rigidly.
@export var camera_follow_speed: float = 22.0
#endregion

@onready var camera_rig: Node3D = $CameraRig
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
## The Tariel model and its procedural animation. Swap the scene under Visuals
## when the rigged Blender knight lands; the controller only calls animate().
@onready var rig: TarielRig = $Visuals as TarielRig

var state: State = State.AIRBORNE
var is_invulnerable: bool = false
## True while the block button is held and the shield is up.
var is_blocking: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _jump_velocity: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _was_on_floor: bool = true


func _ready() -> void:
	_jump_velocity = sqrt(2.0 * _gravity * jump_height)

	# Snap far enough to hug the stairs on the way down, matching the step-up.
	floor_snap_length = maxf(floor_snap_length, max_step_height)

	# The camera rig lives in world space so that rotating the body never
	# drags the camera with it. It is re-positioned every frame in _process().
	camera_rig.top_level = true
	camera_rig.global_position = global_position + Vector3.UP * camera_height

	# Stop the spring arm from colliding with our own capsule.
	spring_arm.add_excluded_object(get_rid())

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		camera_rig.rotate_y(-motion.relative.x * mouse_sensitivity)
		camera_rig.rotation.y = wrapf(camera_rig.rotation.y, -PI, PI)

		var pitch_delta := -motion.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clampf(
			spring_arm.rotation.x + (pitch_delta if not invert_y else -pitch_delta),
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
		return

	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()
	elif event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()


func _process(delta: float) -> void:
	# Smooth follow keeps the camera stable even though the body only moves on
	# physics ticks. Framerate-independent exponential damping.
	var target := global_position + Vector3.UP * camera_height
	var weight := 1.0 - exp(-camera_follow_speed * delta)
	camera_rig.global_position = camera_rig.global_position.lerp(target, weight)

	if rig != null:
		var planar := Vector3(velocity.x, 0.0, velocity.z).length()
		rig.animate(delta, planar, planar / maxf(walk_speed, 0.01), not is_on_floor(),
				state == State.DASHING, velocity.y, is_blocking)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_read_actions()

	if state == State.DASHING:
		_process_dash(delta)
	else:
		_process_locomotion(delta)

	_step_up(delta)
	move_and_slide()
	_update_floor_state()


#region Locomotion
## Action buttons are polled rather than read from _unhandled_input() so that a
## press is never lost between physics ticks and so simulated input works.
func _read_actions() -> void:
	# The shield is only up while the button is held; dashing drops it.
	var raised := Input.is_action_pressed("block") and state != State.DASHING
	if raised != is_blocking:
		is_blocking = raised
		block_changed.emit(is_blocking)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("dash"):
		_try_dash()
	if Input.is_action_just_pressed("attack"):
		_attack()


func _process_locomotion(delta: float) -> void:
	var direction := get_movement_direction()
	var speed := walk_speed if Input.is_action_pressed("walk") else run_speed
	var on_floor := is_on_floor()

	# Horizontal movement.
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if direction.is_zero_approx():
		var decel := ground_deceleration if on_floor else ground_deceleration * air_control
		horizontal = horizontal.move_toward(Vector3.ZERO, decel * delta)
	else:
		var accel := ground_acceleration if on_floor else ground_acceleration * air_control
		horizontal = horizontal.move_toward(direction * speed, accel * delta)
		_face_direction(direction, delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Vertical movement.
	if not on_floor:
		velocity.y -= _current_gravity() * delta

	if _jump_buffer_timer > 0.0 and (on_floor or _coyote_timer > 0.0):
		_do_jump()


func get_movement_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.is_zero_approx():
		return Vector3.ZERO

	# WASD is interpreted in the camera's yaw frame, not the world frame.
	var cam_basis := camera_rig.global_transform.basis
	var direction := cam_basis.x * input.x + cam_basis.z * input.y
	direction.y = 0.0
	return direction.normalized()


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Places the body on top of a low ledge, the classic up -> forward -> down
## sweep. Any failed probe aborts and the obstacle stays a plain wall.
func _step_up(delta: float) -> void:
	if max_step_height <= 0.0 or not is_on_floor():
		return

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length_squared() < 0.0001:
		return
	var direction := horizontal.normalized()
	var from := global_transform
	var floor_cos := cos(floor_max_angle)

	# 1. Is a wall-like surface actually in the way this frame?
	var blocker := KinematicCollision3D.new()
	var reach := horizontal.length() * delta + STEP_PROBE_SKIN
	if not test_move(from, direction * reach, blocker):
		return
	if blocker.get_normal().dot(up_direction) > floor_cos:
		return  # A walkable slope: move_and_slide() already handles it.

	# 2. Is there room to lift the body?
	var lift := up_direction * max_step_height
	if test_move(from, lift):
		return
	var raised := from.translated(lift)

	# 3. Push outwards until the capsule has cleared the ledge, otherwise the
	#    downward probe catches the step's edge and reports an unwalkable
	#    normal. Land on the first sample that gives a real floor.
	var drop := KinematicCollision3D.new()
	for i in STEP_PROBE_SAMPLES:
		var ahead := direction * (step_forward_probe * float(i + 1) / STEP_PROBE_SAMPLES)
		if test_move(raised, ahead):
			return  # A real wall, not a ledge.

		var landing := raised.translated(ahead)
		if not test_move(landing, -lift, drop):
			continue  # Still hanging over the void: probe further out.
		if drop.get_normal().dot(up_direction) < floor_cos:
			continue  # Caught the edge: probe further out.

		if max_step_height - drop.get_travel().length() <= 0.001:
			return  # The surface is level with our feet, nothing to climb.

		global_transform = landing.translated(drop.get_travel())
		velocity.y = 0.0
		return


func _current_gravity() -> float:
	if velocity.y > 0.0:
		# Cutting the jump short pulls the player back down faster.
		return _gravity * (low_jump_multiplier if not Input.is_action_pressed("jump") else 1.0)
	return _gravity * fall_gravity_multiplier


func _do_jump() -> void:
	velocity.y = _jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	state = State.AIRBORNE
	jumped.emit()
#endregion


#region Dash
func _try_dash() -> void:
	if state == State.DASHING or _dash_cooldown_timer > 0.0:
		return
	if not is_on_floor() and not allow_air_dash:
		return

	# Dash towards the stick/WASD input, or straight ahead when standing still.
	_dash_direction = get_movement_direction()
	if _dash_direction.is_zero_approx():
		_dash_direction = -global_transform.basis.z
	_dash_direction.y = 0.0
	_dash_direction = _dash_direction.normalized()

	state = State.DASHING
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown + dash_duration
	is_invulnerable = dash_iframes > 0.0

	rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
	if rig != null:
		rig.dodge(dash_duration)
	dash_started.emit(_dash_direction)



func _process_dash(delta: float) -> void:
	# Ease the dash out so it does not end with a hard velocity cut.
	var t := clampf(_dash_timer / maxf(dash_duration, 0.001), 0.0, 1.0)
	var speed := dash_speed * lerpf(0.55, 1.0, t)
	velocity.x = _dash_direction.x * speed
	velocity.z = _dash_direction.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	if dash_iframes > 0.0 and dash_duration - _dash_timer >= dash_iframes:
		is_invulnerable = false

	if _dash_timer <= 0.0:
		_end_dash()


func _end_dash() -> void:
	is_invulnerable = false
	state = State.GROUNDED if is_on_floor() else State.AIRBORNE
	# Bleed off the dash so the player keeps a bit of momentum.
	velocity.x *= 0.4
	velocity.z *= 0.4
	dash_ended.emit()
#endregion


#region Combat placeholder
func _attack() -> void:
	if state == State.DASHING:
		return
	attack_started.emit()
	if rig != null:
		rig.attack()
	# TODO: promote this to a real attack state that locks movement and enables
	# the weapon hitbox for the active frames.
#endregion


#region Housekeeping
func _tick_timers(delta: float) -> void:
	_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)


func _update_floor_state() -> void:
	var on_floor := is_on_floor()

	if on_floor:
		_coyote_timer = coyote_time
		if not _was_on_floor:
			landed.emit()
		if state != State.DASHING:
			state = State.GROUNDED
	elif state != State.DASHING:
		state = State.AIRBORNE

	_was_on_floor = on_floor


func _toggle_fullscreen() -> void:
	var windowed := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if windowed else DisplayServer.WINDOW_MODE_WINDOWED)


func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
#endregion
