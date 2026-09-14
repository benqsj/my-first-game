class_name Player
extends CharacterBody3D

## Placeholder third-person controller for greyboxing.
##
## Camera-relative WASD movement, gravity, jump (with coyote time + input
## buffering) and a dash / dodge roll with i-frames and a cooldown.
## The capsule mesh is a stand-in for the Blender knight models.

signal jumped
signal landed(impact_speed: float)
signal dash_started(direction: Vector3)
signal dash_ended
signal dodge_started(direction: Vector3)
signal dodge_ended
signal attack_started
signal block_changed(raised: bool)
signal slide_started
signal slide_ended
signal climb_started(ledge: Vector3)
signal wall_grabbed(normal: Vector3)
signal wall_released
signal weapons_stowed_changed(away: bool)
signal target_locked(who: Node3D)
signal target_lost
signal arrow_loosed(power: float, damage: float, critical: bool)

enum State { GROUNDED, AIRBORNE, DASHING, DODGING, SLIDING, CLIMBING, WALLCLIMB }

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
## How fast a jump bleeds off with no stick input, in m/s². Much gentler than
## the ground figure: a jump should carry you, not stop dead in mid-air.
@export var air_drag: float = 3.0
## How fast the body turns to face its movement direction at a full run.
@export var turn_speed: float = 12.0
## Turn rate while barely moving. Higher than `turn_speed` so a standing turn
## is crisp while a sprinting one still has to carve.
@export var turn_speed_still: float = 22.0
## Tallest ledge the player walks up without jumping. CharacterBody3D has no
## built-in stair stepping, so this is resolved manually in _step_up().
@export var max_step_height: float = 0.4
## How far ahead the step-up sweep reaches. Must exceed the capsule radius or
## the sweep lands on the ledge's edge instead of its top face.
@export var step_forward_probe: float = 0.55

@export_group("Slopes")
## Speed lost running straight up a slope at the steepest walkable angle.
@export_range(0.0, 0.9) var slope_climb_penalty: float = 0.35
## Speed gained running straight down one. Kept small so downhills do not turn
## into a luge run.
@export_range(0.0, 0.9) var slope_descend_bonus: float = 0.15
## Pull down a surface too steep to stand on, in m/s². This is what stops the
## player from parking on the side of a boulder.
@export var slide_acceleration: float = 26.0
## Drag along that surface while sliding, so the slide reaches a terminal speed.
@export var slide_friction: float = 1.5

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
## Terminal velocity. Without it a long drop builds up enough speed to tunnel
## through thin floors.
@export var max_fall_speed: float = 34.0
## Landing faster than this counts as a heavy landing.
@export var hard_landing_speed: float = 14.0
## Fraction of the run that survives a heavy landing, so a big drop costs you
## some momentum instead of letting you sprint straight out of it.
@export_range(0.0, 1.0) var hard_landing_grip: float = 0.55

@export_group("Dash")
@export var dash_speed: float = 11.0
@export var dash_duration: float = 0.45
@export var dash_cooldown: float = 0.22
## Invulnerability window measured from the start of the dash.
@export var dash_iframes: float = 0.3
## Dashes are ignored while airborne when false.
@export var allow_air_dash: bool = false
## Cut the roll short when it runs into a wall rather than grinding along it.
@export var dash_cancels_on_wall: bool = true
## A second tap inside this window turns the roll into the library's dodge —
## slower, wider, and animated rather than tumbled.
@export var double_tap_time: float = 0.28
@export var dodge_duration: float = 0.7
@export var dodge_speed: float = 8.5
## Invulnerability window measured from the start of the dodge. Longer than the
## roll's, because the dodge is the deliberate, committed one.
@export var dodge_iframes: float = 0.45

@export_group("Crouch")
## Speed while crouched. Creeping is the point of it.
@export var crouch_speed: float = 2.4
## Height of the capsule while crouched.
@export var crouch_height: float = 1.15

@export_group("Slide")
## A slide has to be launched off a run; below this it would just be a squat.
@export var slide_min_speed: float = 5.0
## How much of the entry speed the slide starts with. Above 1 it is a burst.
@export var slide_boost: float = 1.12
@export var slide_duration: float = 0.85
## How fast the slide bleeds off, in m/s².
@export var slide_drag: float = 8.0
## Height of the capsule while sliding, which is what lets the player under a
## low gap. Standing back up waits until there is room again.
@export var slide_height: float = 0.9
@export var slide_cooldown: float = 0.3

@export_group("Climb")
## Ledges this far above the feet and no higher can be pulled up onto. The
## floor of the band sits above max_step_height, so anything that can simply be
## walked up is not turned into a climb.
@export var climb_min_height: float = 0.55
@export var climb_max_height: float = 1.7
## How far in front of the body the ledge is felt for.
@export var climb_reach: float = 0.75
## How long the pull-up takes. The clip is stretched to match.
@export var climb_duration: float = 0.55
## Vertical room the top of the ledge needs before it counts as somewhere to
## stand rather than a slot to be wedged into.
@export var climb_headroom: float = 1.9

@export_group("Wall climb")
## Free climbing on faces too tall to be mantled — a house wall, a tower, the
## side of a boulder. Off leaves only the low pull-up.
@export var wall_climb_enabled: bool = true
## Faces steeper than this, measured from the horizontal, can be gripped. It has
## to sit above `floor_max_angle` or a walkable slope would be climbed rather
## than run up.
@export_range(0.0, 89.0) var wall_min_angle: float = 60.0
## How far in front of the chest a face is felt for.
@export var wall_grip_reach: float = 0.9
## Gap left between the capsule and the face it is hanging off. It is not just
## clearance: the body is narrow but what it carries is not, and a sword and a
## shield held against a wall go through it. The arms are solved onto the face,
## so hanging further off it costs nothing — the hands still land on the stone.
@export var wall_gap: float = 0.18
## Climbing pace up and down a face.
@export var wall_climb_speed: float = 2.1
## Pace sideways along one, which is quicker: a climber shuffles faster than
## they haul themselves upwards.
@export var wall_shimmy_speed: float = 2.4
## How fast the body swings round and settles against a face as it changes.
@export var wall_settle_speed: float = 14.0
## Push-off away from the face when jumping off it.
@export var wall_jump_back: float = 5.0
@export var wall_jump_up: float = 6.0
## How much wall there has to be above the grip before climbing is worth
## starting. Anything shorter is a mantle, and mantling is always tried first.
@export var wall_min_face: float = 1.0
## How long after letting go the face is ignored, so a jump off it is not
## caught by the same wall on the way past.
@export var wall_regrab_delay: float = 0.35

@export_group("Target lock")
## How far off a target can be taken.
@export var lock_range: float = 26.0
## And how far round from where the camera is looking, in degrees. Wide, because
## the point of the button is not having to aim it.
@export_range(0.0, 180.0) var lock_cone: float = 70.0
## How much further than `lock_range` a target may get before it is let go. The
## gap between the two is what stops a lock flickering at the edge of its reach.
@export var lock_break_range: float = 34.0
## How fast the camera swings round onto a target and then keeps it there.
@export var lock_camera_speed: float = 6.0
## How far above the target the camera rides while locked, in degrees. Looking
## *down* on a fight is what shows the ground between the two of you; aimed flat
## at a target, that ground is a sliver and everything reads as a silhouette.
@export_range(0.0, 60.0) var lock_camera_tilt: float = 14.0
## How fast the body turns to face one. Quicker than a running turn: facing the
## thing you are fighting is not something to carve into.
@export var lock_turn_speed: float = 16.0

@export_group("Bow")
## How much of the run survives while the string is being held. An archer at a
## full sprint cannot aim, and being able to would make every other approach
## pointless.
@export_range(0.1, 1.0) var draw_speed_scale: float = 0.55
## Where the arrow leaves from, measured up the body.
@export var arrow_height: float = 1.35
## How far a shot drops, as a share of the world's gravity. Arrows are fast and
## an arc the player cannot read is not a skill shot, it is a guess.
@export_range(0.0, 1.0) var arrow_drop: float = 0.35
@export var arrow_scene: PackedScene

@export_group("Physics")
## Impulse scale applied to loose rigid bodies the capsule walks into. Zero
## makes the player pass them by without disturbing them.
@export var push_force: float = 2.5

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
## The model and its procedural animation, built in _ready() from whichever
## character is being played. Not `@onready`, because there is nothing under
## Visuals until the profile says what should be: the controller is the same
## code for all of them and the character is the thing that varies.
var rig: CharacterRig
## Who is being played. Taken from the Game autoload on spawn unless something
## has set it first, which is what the tests do.
var profile: CharacterProfile
@onready var _collider: CollisionShape3D = $CollisionShape3D

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
## Fastest the player may travel horizontally while airborne: whatever it left
## the ground with. Air control steers the jump, it does not accelerate it.
var _air_speed_cap: float = 0.0
## Downward speed going into the last move, kept so the landing knows how hard
## it was — move_and_slide() has already flattened velocity by then.
var _impact_speed: float = 0.0
## Normal of the steepest un-standable surface touched last tick, if any.
var _steep_normal: Vector3 = Vector3.ZERO
var _dodge_timer: float = 0.0
## When the dash button was last pressed, so a second tap can be told from a
## first one.
var _last_dash_press: float = -100.0
var _crouching: bool = false
var _slide_timer: float = 0.0
var _slide_cooldown_timer: float = 0.0
var _slide_direction: Vector3 = Vector3.ZERO
var _slide_speed: float = 0.0
## Standing height of the capsule and where its centre sits, so the slide can
## put both back when there is room again.
var _stand_height: float = 0.0
var _stand_centre: float = 0.0
## Radius of the capsule, which is what decides how far off a face the body
## hangs while climbing it.
var _stand_radius: float = 0.4
var _climb_timer: float = 0.0
var _climb_from: Vector3 = Vector3.ZERO
var _climb_to: Vector3 = Vector3.ZERO
## Outward normal of the face being climbed, and the point on it the chest is
## holding onto.
var _wall_normal: Vector3 = Vector3.ZERO
var _wall_point: Vector3 = Vector3.ZERO
## Smoothed climbing input, so the reaches do not snap when the stick does.
var _wall_drive: Vector2 = Vector2.ZERO
var _wall_cooldown_timer: float = 0.0
## What is being fought, if anything. Everyone can hold a target; what they do
## with it is the difference between a sword and a bow.
var target: Node3D = null
## How long the string has been held, and whether it is being held at all.
var _draw_timer: float = 0.0
var _drawing: bool = false
var _shot_timer: float = 0.0
var _shot_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_spawn_character()
	# The level has just loaded, so this is the moment the graphics setting has
	# something to be applied to. The world knows nothing about settings; the
	# thing that spawns into it asks for them.
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.call_deferred("apply_graphics")
	_jump_velocity = sqrt(2.0 * _gravity * jump_height)
	_air_speed_cap = run_speed

	# The capsule is resized by the slide, so it must not be shared with anything
	# else that happens to instance this scene.
	var capsule := _collider.shape as CapsuleShape3D
	if capsule != null:
		_collider.shape = capsule.duplicate()
		_stand_height = capsule.height
		_stand_centre = _collider.position.y
		_stand_radius = capsule.radius

	# Snap far enough to hug the stairs on the way down, matching the step-up.
	floor_snap_length = maxf(floor_snap_length, max_step_height)
	# Hold the run speed while climbing or descending a ramp instead of letting
	# the solver trade it for height, then layer our own slope cost on top.
	floor_constant_speed = true
	# Stop a wall from acting as a ramp when it is hit at a shallow angle, and
	# keep glancing hits sliding instead of catching.
	floor_block_on_wall = true
	wall_min_slide_angle = deg_to_rad(12.0)
	slide_on_ceiling = true
	# Room for a few contacts: floor plus wall plus a step edge in one tick.
	max_slides = 6
	safe_margin = 0.002
	# Leaving a moving platform hands its velocity over, but only upwards, so
	# riding one sideways does not fling the player.
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_UPWARD_VELOCITY

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
		if state == State.WALLCLIMB:
			rig.climb_drive(_wall_drive, velocity.length(), _wall_hold_distance())
		var planar := Vector3(velocity.x, 0.0, velocity.z).length()
		rig.animate(delta, planar, planar / maxf(walk_speed, 0.01), not is_on_floor(),
				state == State.DASHING, velocity.y, is_blocking)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_track_target(delta)
	if has_bow():
		_tick_bow(delta)

	# A pull-up is played out by hand: the body is carried along an arc that no
	# amount of velocity would produce, so nothing else runs while it does.
	if state == State.CLIMBING:
		_process_climb(delta)
		return

	# Hanging off a face is its own kind of movement — no gravity, no friction,
	# and the surface rather than the camera decides which way is forward — so it
	# runs its own move rather than falling through to the walking one.
	if state == State.WALLCLIMB:
		_process_wall_climb(delta)
		return

	_read_actions()

	if state == State.DASHING or state == State.DODGING:
		_process_dash(delta)
	elif state == State.SLIDING:
		_process_slide(delta)
	else:
		_process_locomotion(delta)

	_slide_off_steep_ground(delta)
	velocity.y = maxf(velocity.y, -max_fall_speed)
	_impact_speed = maxf(-velocity.y, 0.0)

	_step_up(delta)
	move_and_slide()
	_resolve_contacts()
	_update_floor_state()


#region Character
## Hangs the chosen character's model under the body and takes their numbers.
##
## The controller is one piece of code for every character; what differs between
## them is a model, a weapon and a handful of figures. Keeping that in a profile
## resource rather than in four copies of this script is what makes the fourth
## character a file rather than a fork.
func _spawn_character() -> void:
	if profile == null:
		var game := get_node_or_null("/root/Game")
		profile = game.profile() if game != null else null
	if profile == null or profile.visuals == null:
		push_error("Player: no character to spawn.")
		return

	var body: Node3D = profile.visuals.instantiate()
	body.name = "Visuals"
	add_child(body)
	rig = body as CharacterRig

	run_speed = profile.run_speed
	walk_speed = profile.walk_speed
	dash_speed = profile.dash_speed
	dash_duration = profile.dash_duration
	dodge_speed = profile.dodge_speed
	dodge_duration = profile.dodge_duration


## True for a character who shoots rather than swings.
func has_bow() -> bool:
	return profile != null and profile.weapon == CharacterProfile.Weapon.BOW
#endregion


#region Locomotion
## Action buttons are polled rather than read from _unhandled_input() so that a
## press is never lost between physics ticks and so simulated input works.
func _read_actions() -> void:
	if Input.is_action_just_pressed("stow"):
		_set_weapons_stowed(not weapons_stowed())
	if Input.is_action_just_pressed("lock_on"):
		_toggle_lock()

	# The shield is only up while the button is held; rolling and sliding drop it.
	# A character with no shield has nothing to raise.
	var raised := Input.is_action_pressed("block") and state == State.GROUNDED \
			and (profile == null or profile.can_block)
	if raised:
		# Raising a shield that is on your back takes it off your back first.
		_set_weapons_stowed(false)
	if raised != is_blocking:
		is_blocking = raised
		block_changed.emit(is_blocking)

	if Input.is_action_just_pressed("jump"):
		# A ledge in reach turns the jump into a pull-up, so a wall a little too
		# tall to walk up is climbed rather than bounced off. Anything taller than
		# that is taken hold of and climbed instead.
		if not _try_climb() and not _try_wall_climb():
			_jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_pressed("dash"):
		_press_dash()
	# Held down at a run this is a slide; held down otherwise it is a crouch, and
	# the slide drops into one when it ends if the button is still down.
	_set_crouching(Input.is_action_pressed("crouch"))
	if Input.is_action_just_pressed("crouch"):
		_try_slide()
	# One button, two weapons: the sword goes on the press, the bow on the
	# release, because what the bow is worth is how long the press lasted.
	if not has_bow() and Input.is_action_just_pressed("attack"):
		_attack()


func _process_locomotion(delta: float) -> void:
	var direction := get_movement_direction()
	var speed := walk_speed if Input.is_action_pressed("walk") else run_speed
	if _crouching:
		speed = crouch_speed
	# Nobody aims at a sprint. Holding the string costs most of the run, which is
	# what makes choosing when to draw a decision rather than a formality.
	if _drawing:
		speed *= draw_speed_scale
	var on_floor := is_on_floor()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	# A ledge met in mid-air is taken without asking, so running at a wall and
	# jumping is enough to get over it. A face too tall to be mantled is caught
	# hold of instead — which is what makes a house something to go up rather
	# than something to bounce off.
	if not on_floor:
		if _try_climb():
			return
		if _try_catch_wall(direction):
			return

	if on_floor:
		# Climbing costs speed, dropping gives a little back.
		speed *= _slope_factor(direction)
		if direction.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, ground_deceleration * delta)
		else:
			horizontal = horizontal.move_toward(direction * speed, ground_acceleration * delta)
		# Locked on, the body keeps facing what it is fighting however it moves,
		# so the stick strafes round it and backs away from it instead of
		# turning to run. Otherwise it faces the way it is going, as ever.
		if target != null:
			_face_target(delta)
		elif not direction.is_zero_approx():
			_face_direction(direction, delta)
	else:
		# In the air the stick steers the arc rather than driving it: the jump
		# keeps the speed it launched with and control only redirects it.
		if direction.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, air_drag * delta)
		else:
			horizontal = horizontal.move_toward(direction * speed,
					ground_acceleration * air_control * delta)
		if target != null:
			_face_target(delta)
		elif not direction.is_zero_approx():
			_face_direction(direction, delta)
		var cap := maxf(_air_speed_cap, speed)
		if horizontal.length() > cap:
			horizontal = horizontal.limit_length(cap)

	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# Vertical movement.
	if not on_floor:
		velocity.y -= _current_gravity() * delta

	if _jump_buffer_timer > 0.0 and (on_floor or _coyote_timer > 0.0):
		_do_jump()


## Speed multiplier for running along `direction` on the current floor: below 1
## uphill, above 1 downhill, 1 on the flat or in the air.
func _slope_factor(direction: Vector3) -> float:
	if not is_on_floor() or direction.is_zero_approx():
		return 1.0
	var normal := get_floor_normal()
	if normal.y <= 0.001:
		return 1.0
	# Metres of height per metre travelled: the floor normal leans downhill, so
	# heading against it is a climb.
	var grade := -direction.dot(Vector3(normal.x, 0.0, normal.z)) / normal.y
	var steepest := tan(floor_max_angle)
	var t := clampf(grade / maxf(steepest, 0.01), -1.0, 1.0)
	return 1.0 - t * (slope_climb_penalty if t > 0.0 else slope_descend_bonus)


## Surfaces past `floor_max_angle` are not standable, so gravity is redirected
## along them: the player slithers down instead of hanging on the side.
func _slide_off_steep_ground(delta: float) -> void:
	if is_on_floor() or _steep_normal == Vector3.ZERO:
		return

	var downhill := Vector3.DOWN.slide(_steep_normal)
	if downhill.is_zero_approx():
		return
	velocity += downhill.normalized() * slide_acceleration * delta
	# Nothing is gained by driving into the surface, and keeping that component
	# is what makes a body judder against a slope.
	var into := velocity.dot(_steep_normal)
	if into < 0.0:
		velocity -= _steep_normal * into
	velocity -= velocity.slide(_steep_normal) * clampf(slide_friction * delta, 0.0, 1.0)


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
	# Pivoting on the spot is instant-ish; at a sprint the turn has to carve.
	var pace := clampf(Vector3(velocity.x, 0.0, velocity.z).length() / maxf(run_speed, 0.01), 0.0, 1.0)
	var rate := lerpf(turn_speed_still, turn_speed, pace)
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rate * delta))


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
	# Whatever ground speed the jump was taken at is the budget for the arc.
	_air_speed_cap = maxf(Vector3(velocity.x, 0.0, velocity.z).length(), run_speed)
	state = State.AIRBORNE
	jumped.emit()
#endregion


#region Dash
## The dash button does two things depending on how it is pressed. One tap is
## the quick tumbling roll it has always been; a second tap inside
## `double_tap_time` upgrades the roll in progress into the library's dodge,
## which is slower, travels further and is animated rather than tumbled.
##
## The upgrade converts the roll rather than waiting to see which is coming,
## because holding the first press back until the window closed would put a
## visible stall on every single tap.
func _press_dash() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var doubled := now - _last_dash_press <= double_tap_time
	_last_dash_press = now

	if doubled and state == State.DASHING:
		_upgrade_to_dodge()
		return
	_try_dash()


func _try_dash() -> void:
	if state != State.GROUNDED and state != State.AIRBORNE:
		return
	if _dash_cooldown_timer > 0.0:
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


## Turns the roll already under way into the longer, animated dodge, keeping the
## direction it was thrown in.
func _upgrade_to_dodge() -> void:
	if rig != null and not rig.dodge_clip(dodge_duration):
		return  # No clip to upgrade to; the roll carries on as it is.
	state = State.DODGING
	_dodge_timer = dodge_duration
	_dash_cooldown_timer = dash_cooldown + dodge_duration
	is_invulnerable = dodge_iframes > 0.0
	dodge_started.emit(_dash_direction)


## Drives both evades. They differ in how long they last, how fast they travel
## and what the rig is doing, not in how the body is moved.
func _process_dash(delta: float) -> void:
	var dodging := state == State.DODGING
	var length := dodge_duration if dodging else dash_duration
	var left := _dodge_timer if dodging else _dash_timer
	var iframes := dodge_iframes if dodging else dash_iframes

	# Ease the evade out so it does not end with a hard velocity cut.
	var t := clampf(left / maxf(length, 0.001), 0.0, 1.0)
	var speed := (dodge_speed if dodging else dash_speed) * lerpf(0.55, 1.0, t)
	velocity.x = _dash_direction.x * speed
	velocity.z = _dash_direction.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	if iframes > 0.0 and length - left >= iframes:
		is_invulnerable = false

	# Going face-first into a wall should stop the evade, not scrape along it.
	if dash_cancels_on_wall and is_on_wall() and get_wall_normal().dot(_dash_direction) < -0.6:
		_end_dash()
		return

	if left <= 0.0:
		_end_dash()


func _end_dash() -> void:
	var dodging := state == State.DODGING
	is_invulnerable = false
	state = State.GROUNDED if is_on_floor() else State.AIRBORNE
	# Bleed off the evade so the player keeps a bit of momentum.
	velocity.x *= 0.4
	velocity.z *= 0.4
	if dodging:
		dodge_ended.emit()
	else:
		dash_ended.emit()
#endregion


#region Crouch
## Holds the body down, or lets it back up. Standing waits until there is room:
## under a low gap the crouch simply carries on.
func _set_crouching(down: bool) -> void:
	if state == State.SLIDING or state == State.CLIMBING:
		return
	# Taking hold of a wall drops the crouch on the way in, which is the one time
	# it is set from this state; nothing else may touch it while hanging.
	if state == State.WALLCLIMB and down:
		return
	# Wanting to stand and being able to are different things, so the body is
	# only up once the full capsule fits. `or` short-circuits, which is what
	# keeps the stand-up probe out of the way while the button is still held.
	var held := down or not _stand_up()
	if held == _crouching:
		return

	_crouching = held
	if held:
		_set_capsule(crouch_height)
	if rig != null:
		rig.crouch(held)


func is_crouching() -> bool:
	return _crouching


## Puts the sword and shield over the shoulder, or takes them back off it.
## Climbing does the same of its own accord and gives the choice back after.
func _set_weapons_stowed(away: bool) -> void:
	if rig == null or rig.weapons_stowed() == away:
		return
	rig.stow_weapons(away)
	weapons_stowed_changed.emit(away)


## True while the player has put the weapons away.
func weapons_stowed() -> bool:
	return rig != null and rig.weapons_stowed()
#endregion


#region Slide
## How tall the capsule is when the player is upright, read off the scene rather
## than exported so there is one place it is set.
func stand_height() -> float:
	return _stand_height


## Drops into a slide, which only makes sense off a run: it keeps the momentum
## that was already there, adds a little, and shrinks the capsule so the player
## goes under whatever a standing body would not.
func _try_slide() -> bool:
	if state != State.GROUNDED or _slide_cooldown_timer > 0.0:
		return false
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() < slide_min_speed:
		return false

	_slide_direction = horizontal.normalized()
	_slide_speed = horizontal.length() * slide_boost
	_slide_timer = slide_duration
	state = State.SLIDING
	_set_capsule(slide_height)
	if rig != null:
		rig.crouch(false)
		rig.slide(true)
	slide_started.emit()
	return true


func _process_slide(delta: float) -> void:
	_slide_speed = maxf(_slide_speed - slide_drag * delta, 0.0)
	velocity.x = _slide_direction.x * _slide_speed
	velocity.z = _slide_direction.z * _slide_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta

	# Held down, the slide keeps going as long as it is still going somewhere;
	# released, it ends there and then.
	var holding := Input.is_action_pressed("crouch")
	var spent := _slide_timer <= 0.0 or _slide_speed < slide_min_speed * 0.45
	if is_on_wall() or not is_on_floor() or spent or not holding:
		_end_slide()


## Comes out of the slide. Still holding the button leaves the player crouched
## rather than standing straight back up, which is also what happens under a low
## gap whether they asked for it or not.
func _end_slide() -> void:
	state = State.GROUNDED if is_on_floor() else State.AIRBORNE
	_slide_cooldown_timer = slide_cooldown
	if rig != null:
		rig.slide(false)
	slide_ended.emit()

	_crouching = false
	_set_crouching(Input.is_action_pressed("crouch"))


## Resizes the capsule about the feet, so shrinking it never lifts the body off
## the ground or drops it through it.
func _set_capsule(height: float) -> void:
	var capsule := _collider.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.height = height
	_collider.position.y = _stand_centre - (_stand_height - height) * 0.5


## True once the capsule is back to its standing size. False means something is
## in the way and the player has to stay down.
func _stand_up() -> bool:
	var capsule := _collider.shape as CapsuleShape3D
	if capsule == null or is_equal_approx(capsule.height, _stand_height):
		return true

	var crouched := capsule.height
	var crouched_centre := _collider.position.y
	_set_capsule(_stand_height)
	if not test_move(global_transform, Vector3.ZERO):
		return true

	capsule.height = crouched
	_collider.position.y = crouched_centre
	return false
#endregion


#region Climb
## Pulls the body up over a ledge in front of it, if there is one within reach
## and something to stand on when it gets there.
func _try_climb() -> bool:
	if state != State.GROUNDED and state != State.AIRBORNE:
		return false
	var landing := _find_ledge()
	if landing == Vector3.ZERO:
		return false
	_begin_mantle(landing)
	return true


## Hands the body over to the pull-up, wherever it was called from: off the
## ground, out of a jump, or off the top of a face that has just been climbed.
func _begin_mantle(landing: Vector3) -> void:
	if state == State.WALLCLIMB and rig != null:
		rig.wall_climb(false)
	_climb_from = global_position
	_climb_to = landing
	_climb_timer = climb_duration
	state = State.CLIMBING
	velocity = Vector3.ZERO
	_jump_buffer_timer = 0.0
	if rig != null:
		rig.climb(climb_duration)
	climb_started.emit(landing)


## Where the body would end up after mantling whatever is in front of it, or
## ZERO if there is nothing to mantle.
##
## Three questions, in the order that rules the most out soonest: is there a
## face to grab, does it have a top edge within reach, and is there room to
## stand on it.
func _find_ledge() -> Vector3:
	var facing := -global_transform.basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		return Vector3.ZERO
	facing = facing.normalized()

	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]

	var chest := global_position + up_direction * climb_min_height
	var face := PhysicsRayQueryParameters3D.create(
			chest, chest + facing * climb_reach, collision_mask, exclude)
	if space.intersect_ray(face).is_empty():
		return Vector3.ZERO

	# Feel down for the top from above the tallest ledge that can be taken.
	var above := global_position + up_direction * (climb_max_height + 0.4) + facing * climb_reach
	var top := PhysicsRayQueryParameters3D.create(
			above, above - up_direction * (climb_max_height + 0.4), collision_mask, exclude)
	var hit := space.intersect_ray(top)
	if hit.is_empty():
		return Vector3.ZERO

	var lip: Vector3 = hit.position
	var rise := (lip - global_position).dot(up_direction)
	if rise < climb_min_height or rise > climb_max_height:
		return Vector3.ZERO
	if (hit.normal as Vector3).dot(up_direction) < cos(floor_max_angle):
		return Vector3.ZERO  # The top is too steep to be a landing.

	# Far enough in from the edge that the capsule is not left overhanging it.
	var landing: Vector3 = lip + facing * 0.25
	var headroom := PhysicsRayQueryParameters3D.create(
			landing + up_direction * 0.05, landing + up_direction * climb_headroom,
			collision_mask, exclude)
	if not space.intersect_ray(headroom).is_empty():
		return Vector3.ZERO
	return landing


## Carries the body up and then in, rather than straight at the corner: a lerp
## between the two ends would drag it through the wall on the way.
func _process_climb(delta: float) -> void:
	_climb_timer = maxf(_climb_timer - delta, 0.0)
	var through := 1.0 - _climb_timer / maxf(climb_duration, 0.001)
	var lift := smoothstep(0.0, 0.7, through)
	var reach := smoothstep(0.35, 1.0, through)

	var here := _climb_from.lerp(_climb_to, reach)
	here.y = lerpf(_climb_from.y, _climb_to.y, lift)
	global_position = here
	velocity = Vector3.ZERO

	if _climb_timer <= 0.0:
		state = State.GROUNDED
		_was_on_floor = true
		_coyote_timer = coyote_time
		_air_speed_cap = run_speed
#endregion


#region Wall climb
## Free climbing. Where the mantle is one move that ends on top of something,
## this is a state the player lives in: the body hangs off a face, gravity is
## off, and the stick drives it up, down and along the surface until it reaches
## the top, climbs back down, or lets go.
##
## Everything is resolved against the face's own normal rather than the camera,
## so rounding a corner or following a wall that leans does not need the view to
## be re-aimed — which is what makes a building climbable as one surface instead
## of as four flat walls.

## Height up the body the grip is felt from. Roughly chest height, which is
## where a climber's hands are when their feet are on the same face.
func _grip_height() -> float:
	return _stand_height * 0.6


## How far the body's centre line sits off the face it is on.
func _wall_hold_distance() -> float:
	return _stand_radius + wall_gap


## Takes hold of whatever steep face is in front of the body. `direction` is the
## way to feel in, defaulting to whichever way the body is facing.
func _try_wall_climb(direction: Vector3 = Vector3.ZERO) -> bool:
	if not wall_climb_enabled or _wall_cooldown_timer > 0.0:
		return false
	if state != State.GROUNDED and state != State.AIRBORNE:
		return false

	var facing := direction
	if facing.is_zero_approx():
		facing = -global_transform.basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		return false
	facing = facing.normalized()

	var grip := _feel_wall(facing)
	if grip.is_empty():
		return false

	# Something with its top already in reach is a mantle, and a mantle is the
	# better move: it puts the player on top rather than leaving them hanging.
	var normal: Vector3 = grip["normal"]
	var above := global_position + up_direction * (_grip_height() + wall_min_face)
	if _scan_wall(above, -normal).is_empty():
		return false

	_grab_wall(grip["position"], normal)
	return true


## Catches a face in mid-air. This is the move that makes jumping at a house
## work: nothing is pressed, the jump simply ends on the wall.
##
## It deliberately does not ask how fast the body is travelling into the face.
## By the time the capsule is *against* a wall, move_and_slide() has already
## cancelled the speed that drove it there, so a jump at a wall reads as having
## no interest in it — which is exactly the bug that made a run-up bounce off.
## What is asked instead is intent: the stick pointing at the face, or the body
## already touching one.
func _try_catch_wall(steer: Vector3) -> bool:
	if not wall_climb_enabled or _wall_cooldown_timer > 0.0:
		return false

	# Touching one is intent enough; otherwise the stick has to be pointing at it.
	if is_on_wall() and _try_wall_climb(-get_wall_normal()):
		return true
	if steer.is_zero_approx():
		return false
	return _try_wall_climb(steer)


## The face in front of the body, felt for the way a climber would: straight
## ahead first, then higher and lower, then round to either side.
##
## Scenery is not made of flat slabs. A window at chest height, a beam, the
## corner of a building — any of them would lose a single probe a wall that is
## plainly still there, and every one of them is a thing a player will try to
## climb.
func _feel_wall(facing: Vector3) -> Dictionary:
	for height: float in [_grip_height(), _stand_height * 0.3, _stand_height * 0.85]:
		var grip := _scan_wall(global_position + up_direction * height, facing)
		if not grip.is_empty():
			return grip

	var chest := global_position + up_direction * _grip_height()
	for sweep: float in [0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var grip := _scan_wall(chest, facing.rotated(up_direction, sweep))
		if not grip.is_empty():
			return grip
	return {}


## The face in front of `origin`, or an empty dictionary if there is nothing
## there worth holding onto.
func _scan_wall(origin: Vector3, facing: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
			origin, origin + facing * wall_grip_reach, collision_mask, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}

	var normal: Vector3 = hit["normal"]
	# Only faces too steep to walk up are worth gripping, and never a ceiling or
	# an overhang: there is nothing for the feet to push against on either.
	if absf(normal.dot(up_direction)) > cos(deg_to_rad(wall_min_angle)):
		return {}
	# The face has to be turned towards the body rather than brushed edge-on,
	# which is also what keeps the back side of a wall from being caught.
	if normal.dot(facing) > -0.35:
		return {}
	return {"position": hit["position"] as Vector3, "normal": normal}


func _grab_wall(point: Vector3, normal: Vector3) -> void:
	state = State.WALLCLIMB
	_wall_point = point
	_wall_normal = normal
	_wall_drive = Vector2.ZERO
	velocity = Vector3.ZERO

	# Stand off the face properly *now* rather than easing out to it. A grab
	# usually happens with the capsule already pressed against the wall, and the
	# body is narrower than the arms are long: a few frames spent too close is a
	# few frames with the hands inside the masonry. Moved rather than teleported,
	# so backing off a wall in a narrow gap stops at whatever is behind.
	var chest := global_position + up_direction * _grip_height()
	var gap := (_wall_point + _wall_normal * _wall_hold_distance()) - chest
	move_and_collide(_wall_normal * gap.dot(_wall_normal))
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	if is_blocking:
		is_blocking = false
		block_changed.emit(false)
	# Nothing else the body was doing survives taking hold of a wall.
	_set_crouching(false)
	if rig != null:
		rig.wall_climb(true)
	wall_grabbed.emit(normal)


func _process_wall_climb(delta: float) -> void:
	# Three ways off: let go and drop, push off backwards, or reach the top.
	if Input.is_action_just_pressed("crouch"):
		_release_wall(Vector3.ZERO)
		return
	if Input.is_action_just_pressed("jump"):
		_release_wall(_wall_normal * wall_jump_back + up_direction * wall_jump_up)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Read in the face's frame, not the camera's: forward on the stick is up the
	# wall however the view happens to be pointing.
	var drive := Vector2(input.x, -input.y)
	_wall_drive = _wall_drive.lerp(drive, 1.0 - exp(-14.0 * delta))

	# Checked before the move, because the face runs out at exactly the moment
	# there is somewhere to stand: losing it here is arriving, not falling.
	if drive.y > 0.1:
		var landing := _find_wall_top()
		if landing != Vector3.ZERO:
			_begin_mantle(landing)
			return

	var held := global_position
	var right := up_direction.cross(_wall_normal).normalized()
	var up_face := _wall_normal.cross(right).normalized()
	velocity = right * drive.x * wall_shimmy_speed + up_face * drive.y * wall_climb_speed
	move_and_slide()

	if not _hold_wall(delta):
		# Climbed off the end of the face with nowhere to go. Coming back to
		# where the hands still had something beats letting go of a wall that is
		# still there — a climber who runs out of holds stops, they do not drop.
		global_position = held
		velocity = Vector3.ZERO
		if not _hold_wall(delta):
			_release_wall(Vector3.ZERO)
			return

	# Climbing back down onto the ground steps off by itself.
	if drive.y < 0.0 and is_on_floor():
		_release_wall(Vector3.ZERO)


## Re-fits the body against the face and turns it to look at it. False means the
## face is gone and there is nothing left to hang off.
func _hold_wall(delta: float) -> bool:
	var chest := global_position + up_direction * _grip_height()
	var grip := _feel_wall(-_wall_normal)
	if grip.is_empty():
		return false

	_wall_point = grip["position"]
	var weight := 1.0 - exp(-wall_settle_speed * delta)
	_wall_normal = _wall_normal.slerp(grip["normal"] as Vector3, weight).normalized()

	# Only the distance to the face is corrected. Sliding along it is what the
	# stick is for, and pulling the body sideways would fight it.
	var wanted := (_wall_point + _wall_normal * _wall_hold_distance()) - chest
	var depth := _wall_normal * wanted.dot(_wall_normal)
	global_position += depth.limit_length(wall_shimmy_speed * delta + 0.02)

	rotation.y = lerp_angle(rotation.y, atan2(_wall_normal.x, _wall_normal.z), weight)
	return true


## Where the body would end up after pulling over the top of the face it is on,
## or ZERO while there is still wall above it.
func _find_wall_top() -> Vector3:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var facing := -_wall_normal
	var head := global_position + up_direction * (_stand_height + 0.55)

	# Still wall in front of the face? Then this is not the top of it, and any
	# floor found above would be one *inside* the building — mantling onto which
	# would post the player through the wall of the house they were climbing.
	if not _scan_wall(global_position + up_direction * (_stand_height * 0.95), facing).is_empty():
		return Vector3.ZERO

	# Feel down for a top face from above the head, a step in past the lip. How
	# far in has to clear the body's own standoff from the wall — probe any
	# closer and the ray comes down in front of the face it is looking for. The
	# nearest depth that works wins, so a ledge a plank wide still counts.
	for depth: float in [0.15, 0.45, 0.9]:
		var over := head + facing * (_wall_hold_distance() + depth)
		var top := PhysicsRayQueryParameters3D.create(
				over, over - up_direction * 1.3, collision_mask, exclude)
		var hit := space.intersect_ray(top)
		if hit.is_empty():
			continue
		if (hit["normal"] as Vector3).dot(up_direction) < cos(floor_max_angle):
			continue

		var landing: Vector3 = hit["position"]
		var headroom := PhysicsRayQueryParameters3D.create(
				landing + up_direction * 0.05, landing + up_direction * climb_headroom,
				collision_mask, exclude)
		if space.intersect_ray(headroom).is_empty():
			return landing
	return Vector3.ZERO


## Lets go of the face. `impulse` is whatever the body leaves with — nothing at
## all when it simply drops, or a push off the wall when it jumps.
func _release_wall(impulse: Vector3) -> void:
	state = State.AIRBORNE
	velocity = impulse
	_wall_normal = Vector3.ZERO
	_wall_drive = Vector2.ZERO
	_wall_cooldown_timer = wall_regrab_delay
	_air_speed_cap = maxf(Vector3(impulse.x, 0.0, impulse.z).length(), run_speed)
	if rig != null:
		rig.wall_climb(false)
	wall_released.emit()


## True while the body is hanging off a face.
func is_wall_climbing() -> bool:
	return state == State.WALLCLIMB
#endregion


#region Target lock
## Holding a target is the controller's business, not a weapon's: the knight
## circles what he is fighting and the archer shoots it, but both of them want
## the same thing from the button — pick the obvious enemy, keep the camera on
## it, and face it until told otherwise.
##
## Movement stays camera-relative while locked, which is what lets the player
## strafe round a target and back away from one without ever turning their back.


## Takes the best target in front of the camera, or lets go of the one held.
func _toggle_lock() -> void:
	if target != null:
		_drop_target()
		return
	var found := _best_target()
	if found == null:
		return
	target = found
	target_locked.emit(target)


func _drop_target() -> void:
	if target == null:
		return
	target = null
	target_lost.emit()


## The enemy nearest the middle of the view, of those close enough and roughly
## in front. Angle first and distance second: what the player is looking at
## matters more than what happens to be nearest.
func _best_target() -> Node3D:
	var eye := camera.global_position
	var looking := -camera.global_transform.basis.z
	var widest := cos(deg_to_rad(lock_cone))
	var best: Node3D = null
	var best_score := -INF

	for node in get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or not _targetable(who):
			continue
		var to_them: Vector3 = _aim_point(who) - eye
		var range_to := to_them.length()
		if range_to > lock_range or range_to < 0.01:
			continue
		var facing := looking.dot(to_them / range_to)
		if facing < widest:
			continue
		# Straight ahead beats close by, but not by so much that something on
		# the far side of the field wins for being centred.
		var score := facing - range_to / lock_range * 0.25
		if score > best_score:
			best_score = score
			best = who
	return best


## Whether something is worth holding on to. Anything that has died stops being
## a target the moment it does, which is what keeps the camera off a corpse.
func _targetable(who: Node3D) -> bool:
	if not is_instance_valid(who) or not who.is_inside_tree():
		return false
	if who.get("is_dead") == true:
		return false
	return true


## Where on a body the camera looks and an arrow goes: the middle of it rather
## than the floor it stands on.
func _aim_point(who: Node3D) -> Vector3:
	return who.global_position + Vector3.UP * 0.8


## Keeps the camera on the target and lets go when there is nothing left to hold.
func _track_target(delta: float) -> void:
	if target == null:
		return
	if not _targetable(target) \
			or global_position.distance_to(target.global_position) > lock_break_range:
		_drop_target()
		return

	# The camera is swung round rather than snapped: a lock that jumps the view
	# is a lock that loses the player.
	var to_them := _aim_point(target) - camera_rig.global_position
	if to_them.length_squared() < 0.01:
		return
	var weight := 1.0 - exp(-lock_camera_speed * delta)
	camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y,
			atan2(-to_them.x, -to_them.z), weight)
	# Pitch: negative puts the camera up and looks down, which is the way to
	# watch a fight. Aiming straight at the target is not enough on its own —
	# the rig already sits above it, so a pure aim is nearly level and the
	# ground between the two disappears. `lock_camera_tilt` is what lifts it.
	var flat := Vector2(to_them.x, to_them.z).length()
	var aimed := atan2(to_them.y, flat) - deg_to_rad(lock_camera_tilt)
	spring_arm.rotation.x = lerp_angle(spring_arm.rotation.x,
			clampf(aimed, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg)),
			weight * 0.7)


## Turns the body to face the target instead of the way it is travelling, which
## is the whole difference between strafing round something and running past it.
func _face_target(delta: float) -> void:
	var to_them := _aim_point(target) - global_position
	to_them.y = 0.0
	if to_them.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to_them.x, -to_them.z),
			1.0 - exp(-lock_turn_speed * delta))


## True while something is being fought.
func has_target() -> bool:
	return target != null
#endregion


#region Bow
## Hold to draw, let go to loose. How long it was held is the whole of it: a
## tapped shot leaves at once and lands for a fraction, a held one takes a beat
## and lands for all of it. Nothing else about the shot changes, so the player
## is choosing between rate and weight rather than between two buttons.
func _tick_bow(delta: float) -> void:
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	var holding := Input.is_action_pressed("attack")
	var busy := state != State.GROUNDED and state != State.AIRBORNE

	if busy:
		# Rolling or climbing with a drawn bow is not a thing. The draw is lost,
		# not banked: it has to be earned again.
		_drawing = false
		_draw_timer = 0.0
	elif holding and not _drawing:
		if _shot_timer <= 0.0:
			_drawing = true
			_draw_timer = 0.0
			_set_weapons_stowed(false)
	elif holding and _drawing:
		_draw_timer += delta
	elif _drawing:
		_loose_arrow()

	var archer := rig as ArcherRig
	if archer != null:
		archer.aim_bow(draw_power() if _drawing else 0.0, _aim_pitch())


## How far the string has come back, 0 to 1. Everything a shot is worth is this
## number, so it is the one the HUD would draw.
func draw_power() -> float:
	if profile == null or profile.draw_time <= 0.0:
		return 1.0
	return clampf(_draw_timer / profile.draw_time, 0.0, 1.0)


## True while the string is being held.
func is_drawing() -> bool:
	return _drawing


## Lets the arrow go.
func _loose_arrow() -> void:
	var power := draw_power()
	_drawing = false
	_draw_timer = 0.0
	_shot_timer = profile.shot_cooldown if profile != null else 0.2

	var from := global_position + up_direction * arrow_height
	var speed := lerpf(profile.arrow_speed_snap, profile.arrow_speed, power)
	var heading := _aim_direction(from, speed)
	# A tap is worth `snap_share` of a full draw and no less; the rest of the
	# scale is earned by holding.
	var carry := lerpf(profile.snap_share, 1.0, power)
	var critical := _shot_rng.randf() < profile.crit_chance
	var damage := profile.damage * carry * (profile.crit_damage if critical else 1.0)

	# Loose in the world rather than under the body, so the arrow does not ride
	# the archer's own movement after it has left the string. `world_of` is the
	# same answer blood and severed limbs use for the same question.
	var into := Blood.world_of(self)
	if arrow_scene != null and into != null:
		var arrow: Node3D = arrow_scene.instantiate()
		into.add_child(arrow)
		arrow.global_position = from
		arrow.call("launch", heading * speed, damage, critical, _gravity * arrow_drop, self)
	arrow_loosed.emit(power, damage, critical)


## Where the shot goes: at whatever is being fought, or at whatever the camera
## is pointing at when nothing is.
##
## A locked shot leads its target. An arrow takes a beat to arrive and a wolf
## does not wait where it was standing, so aiming at where it *is* means a slow
## shot at a moving target is a miss the player did nothing wrong to earn. What
## the lock is for is not having to solve that by hand.
func _aim_direction(from: Vector3, speed: float = 40.0) -> Vector3:
	if target != null and _targetable(target):
		var at := _aim_point(target)
		var moving: Variant = target.get("velocity")
		if moving is Vector3:
			var flight := from.distance_to(at) / maxf(speed, 1.0)
			at += (moving as Vector3) * flight
			# And the drop over that flight, so the arc is aimed through rather
			# than along.
			at.y += 0.5 * _gravity * arrow_drop * flight * flight
		var to_them := at - from
		if to_them.length_squared() > 0.0001:
			return to_them.normalized()

	# Down the middle of the view, at whatever it lands on — so the arrow goes
	# where the crosshair is rather than parallel to it.
	var eye := camera.global_position
	var looking := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			eye, eye + looking * lock_range * 2.0, collision_mask, [get_rid()])
	var hit := space.intersect_ray(query)
	var at: Vector3 = hit["position"] if not hit.is_empty() else eye + looking * lock_range * 2.0
	var heading := at - from
	return heading.normalized() if heading.length_squared() > 0.0001 else looking


## How far off the level the shot is aimed, in radians, for the rig to lean on.
func _aim_pitch() -> float:
	var from := global_position + up_direction * arrow_height
	var heading := _aim_direction(from)
	return asin(clampf(heading.y, -1.0, 1.0))
#endregion


#region Combat placeholder
func _attack() -> void:
	if state != State.GROUNDED and state != State.AIRBORNE:
		return
	# Swinging a sword that is on your back takes it off your back first. There
	# is no draw clip in the library, so the blade crosses back to the hand over
	# the same beat as the wind-up rather than being drawn during it.
	_set_weapons_stowed(false)
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
	_dodge_timer = maxf(_dodge_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_slide_timer = maxf(_slide_timer - delta, 0.0)
	_slide_cooldown_timer = maxf(_slide_cooldown_timer - delta, 0.0)
	_wall_cooldown_timer = maxf(_wall_cooldown_timer - delta, 0.0)


## Reads back what the move actually hit: the steep ground the next tick has to
## slide off, a ceiling to stop dead against, and any loose body to shove.
func _resolve_contacts() -> void:
	_steep_normal = Vector3.ZERO
	var floor_cos := cos(floor_max_angle)

	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var normal := contact.get_normal()

		# Faces up, but not enough to stand on.
		var facing := normal.dot(up_direction)
		if facing > 0.05 and facing < floor_cos and facing > _steep_normal.dot(up_direction):
			_steep_normal = normal

		if push_force > 0.0:
			var body := contact.get_collider() as RigidBody3D
			if body != null:
				var push := -normal
				push.y = 0.0
				if not push.is_zero_approx():
					push = push.normalized()
					var into := velocity.dot(push)
					if into > 0.0:
						body.apply_impulse(push * into * push_force,
								contact.get_position() - body.global_position)

	if is_on_ceiling() and velocity.y > 0.0:
		velocity.y = 0.0


func _update_floor_state() -> void:
	var on_floor := is_on_floor()
	# States that run their own course own the state field until they are done.
	var held := state != State.GROUNDED and state != State.AIRBORNE

	if on_floor:
		_coyote_timer = coyote_time
		if not _was_on_floor:
			_land()
		if not held:
			state = State.GROUNDED
	elif not held:
		if _was_on_floor:
			# Walked off an edge: the arc keeps the speed it left with.
			_air_speed_cap = maxf(Vector3(velocity.x, 0.0, velocity.z).length(), run_speed)
		state = State.AIRBORNE

	_was_on_floor = on_floor


func _land() -> void:
	# Coming down hard costs some of the run — a drop should be felt.
	if _impact_speed > hard_landing_speed and state != State.DASHING:
		velocity.x *= hard_landing_grip
		velocity.z *= hard_landing_grip
	# The fall is over; anything left on the vertical axis only fights the floor
	# snap on the next tick.
	velocity.y = 0.0
	_air_speed_cap = run_speed
	landed.emit(_impact_speed)
	_impact_speed = 0.0


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
