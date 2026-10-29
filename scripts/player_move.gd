class_name PlayerMove
extends RefCounted

## Moving: the walk and run, jumps, evades, slides, glides, crouching, landing.
## Taken out of player.gd (2026-10-28) so the hero is in parts; every
## function takes the hero as `me` and works on it as it did before. [Player]
## keeps a one-line function of the same name for each one called from
## outside this file (other scripts, the rig, signals, the hero himself).

static func _process_locomotion(me: Player, delta: float) -> void:
	var direction := PlayerMove.get_movement_direction(me)
	var walking := Input.is_action_pressed("walk")
	me.sprinting = me._wants_sprint(direction, walking)
	me.jog_speed = me.run_speed * me.jog_share
	var speed := me.walk_speed if walking else (me.run_speed * me.sprint_share if me.sprinting else me.jog_speed)
	if me._crouching:
		speed = me.crouch_speed
	# Water to the knee holds the legs back (the user's word, 2026-10-23:
	# running through the swamp's water felt like dry ground).
	if me.wade > 0.0:
		speed *= lerpf(1.0, me.wade_speed_scale, clampf(me.wade, 0.0, 1.0))
	# Nobody aims at a sprint. Holding the string costs most of the run, which is
	# what makes choosing when to draw a decision rather than a formality.
	if me._drawing:
		speed *= me.draw_speed_scale
	# Behind a raised shield he does not run: the guard is paid for with pace,
	# the same way the draw is. Going on at it he may jog (`guard_run_speed`,
	# the user's word 2026-10-04: a little faster, never his whole pace);
	# walking, backing off or stepping aside he walks.
	if me.is_blocking:
		var cap := me.walk_speed
		if not Input.is_action_pressed("walk") and PlayerMove._guard_ahead(me, direction):
			cap = me.guard_run_speed
		speed = minf(speed, cap)
	# And nobody runs out of the *second* swing. The first one keeps whatever it
	# was thrown at — a charge that turns into a shuffle the instant the button
	# goes down reads as slow motion, not as weight — and so does anything thrown
	# in the air, where the arc is the jump's and not the sword's. What follows is
	# damped, which is where the weight belongs: standing there hitting something
	# is not a way to cross ground.
	if me._now() < me._coat_until or me._now() < me.cast_walk_until or me._now() < me._drink_until:
		# Coating the blade (or a spell's gesture, or a flask) he walks on — slowed to a
		# walk, legs walking — rather than sliding along in a standing pose.
		speed = minf(speed, me.walk_speed)
	elif me.is_committed() and not me._free_swing:
		speed = me.committed_speed(speed)
	elif me.is_committed() and me.is_on_floor():
		# The first cut out of a run keeps its run only for a step: eased down
		# to the swing's pace over `free_swing_ease`, so the charge lands in a
		# lunge instead of the whole cut gliding on at a run with legs running
		# under a body that is swinging.
		# (a running cut keeps the whole of it till its blade cuts, and all
		# the while it is held wound up)
		if not me._cut_charging:
			var eased := clampf((me._game_t - me._swing_t0 - me._ease_delay) / maxf(me._free_ease, 0.01), 0.0, 1.0)
			speed = lerpf(speed, me.committed_speed(speed), eased)
	# A skill shot is taken standing: from the draw to the release he does not
	# walk (turning to the shot is still the controller's).
	if me._root_timer > 0.0:
		speed = 0.0
	# On his knee from a broken guard: no walking it along (it slid him across
	# the ground the way the stick pushed).
	var knelt := me._now() < me._crumpled_until
	if knelt:
		speed = 0.0
		direction = Vector3.ZERO
	var on_floor := me.is_on_floor()
	var horizontal := Vector3(me.velocity.x, 0.0, me.velocity.z)
	# The sprint costs only while it is a sprint: on the ground, faster than
	# the jog (not slowed by a swing, the draw, the shield).
	if me.sprinting and on_floor and speed > me.jog_speed + 0.05:
		me._spend(me.sprint_stamina * delta)
	elif me.sprinting and speed <= me.jog_speed:
		me.sprinting = false

	# A ledge met in mid-air is taken without asking, so running at a wall and
	# jumping is enough to get over it. A face too tall to be mantled is caught
	# hold of instead — which is what makes a house something to go up rather
	# than something to bounce off.
	if not on_floor:
		if me._try_climb():
			return
		if me._try_catch_wall(direction):
			return

	if on_floor:
		# Climbing costs speed, dropping gives a little back.
		speed *= PlayerMove._slope_factor(me, direction)
		# on a puglin's mud he slides: little grip to start or stop
		var grip := MudBall.grip_at(me.get_tree(), me.global_position)
		if direction.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, me.ground_deceleration * grip * delta)
		else:
			horizontal = horizontal.move_toward(direction * speed, me.ground_acceleration * grip * delta)
		PlayerMove._aim_body(me, direction, delta)
		if me._bitten() and me._glide_left <= 0.0:
			# The swing held in its bite holds the body too: no gliding on
			# under a blade that has stopped, and the step waits for it.
			horizontal *= Player.BITE_GLIDE
		elif me._shade_phase == 1:
			# The slide: straight in at its own pace, facing where it goes.
			horizontal = me._shade_dir * me._shade_pace_now
			me.rotation.y = atan2(-me._shade_dir.x, -me._shade_dir.z)
		elif me._glide_left > 0.0:
			horizontal = PlayerMove._glide(me, delta)
		elif me._step_left > 0.0:
			me._step_left -= delta
			horizontal = me._step_velocity
			if me._step_left <= 0.0:
				horizontal = me._step_velocity * 0.15
		elif me._cut_charging:
			# Wound up, running in: at what he picked, else the way he is pushed.
			var aim := me._charge_aim(direction)
			if not aim.is_zero_approx():
				var pace := me.run_speed * float(me._charge_spec.get("pace", 1.0))
				# (from the pace he had, not what the stick left of it: the
				# skill runs in without it)
				# (never faster than the charge's own pace: out of the sprint,
				# faster since 2026-10-23, he settles to it at once)
				horizontal = Vector3(me.velocity.x, 0.0, me.velocity.z).limit_length(pace).move_toward(aim * pace, me.ground_acceleration * delta)
				me._air_speed_cap = minf(me._air_speed_cap, pace)
				me.rotation.y = lerp_angle(me.rotation.y, atan2(-aim.x, -aim.z), 1.0 - exp(-me.lock_turn_speed * delta))
	else:
		# In the air the stick steers the arc rather than driving it: the jump
		# keeps the speed it launched with and control only redirects it.
		if direction.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, me.air_drag * delta)
		else:
			horizontal = horizontal.move_toward(direction * speed,
					me.ground_acceleration * me.air_control * delta)
		PlayerMove._aim_body(me, direction, delta)
		var cap := maxf(me._air_speed_cap, speed)
		if horizontal.length() > cap:
			horizontal = horizontal.limit_length(cap)

	# A flip or a lunge carries him as far as its own clip goes.
	# (not while a heavy blow is still being gathered, nor in the slide after:
	# he edges and slides in by his own way, `_creep_in`, `_glide`)
	if me.rig != null and me.rig.has_method(&"carrying") and bool(me.rig.call(&"carrying")) and me._glide_left <= 0.0 \
			and not (me.rig.has_method(&"wind_left") and float(me.rig.call(&"wind_left")) > 0.0):
		horizontal = me.rig.get(&"carry_velocity")
		if me._bitten():
			horizontal *= Player.BITE_GLIDE

	# The slide: nothing but the slide moves him.
	if me._shade_phase == 1:
		horizontal = me._shade_dir * me._shade_pace_now
	# The elf's Frost Step: she glides, and nothing else moves her
	# ([method MageSkills.glide_velocity]).
	if me._mage != null and me._mage.gliding():
		horizontal = me._mage.glide_velocity(delta)

	me.velocity.x = horizontal.x
	me.velocity.z = horizontal.z

	# Vertical movement.
	if not on_floor:
		me.velocity.y -= PlayerMove._current_gravity(me) * delta
		PlayerMove._levitate(me, delta)
	else:
		me._levitating = false
		me._levitate_left = me.profile.levitation if me.profile != null else 0.0

	if me._jump_buffer_timer > 0.0 and (on_floor or me._coyote_timer > 0.0):
		PlayerMove._do_jump(me)


## A character who can levitate (the mage) hangs in the air while the jump is
## held on the way down: the fall is held to `levitate_fall` until the
## profile's seconds of it run out, and they come back on landing.
static func _levitate(me: Player, delta: float) -> void:
	me._levitating = false
	if me.profile == null or me.profile.levitation <= 0.0 or me._levitate_left <= 0.0:
		return
	if me.velocity.y >= 0.0 or not Input.is_action_pressed("jump"):
		return
	me._levitating = true
	me._levitate_left = maxf(me._levitate_left - delta, 0.0)
	me.velocity.y = maxf(me.velocity.y, -me.profile.levitate_fall)


## Speed multiplier for running along `direction` on the current floor: below 1
## uphill, above 1 downhill, 1 on the flat or in the air.
static func _slope_factor(me: Player, direction: Vector3) -> float:
	if not me.is_on_floor() or direction.is_zero_approx():
		return 1.0
	var normal := me.get_floor_normal()
	if normal.y <= 0.001:
		return 1.0
	# Metres of height per metre travelled: the floor normal leans downhill, so
	# heading against it is a climb.
	var grade := -direction.dot(Vector3(normal.x, 0.0, normal.z)) / normal.y
	var steepest := tan(me.floor_max_angle)
	var t := clampf(grade / maxf(steepest, 0.01), -1.0, 1.0)
	return 1.0 - t * (me.slope_climb_penalty if t > 0.0 else me.slope_descend_bonus)


## Surfaces past `floor_max_angle` are not standable, so gravity is redirected
## along them: the player slithers down instead of hanging on the side.
static func _slide_off_steep_ground(me: Player, delta: float) -> void:
	if me.is_on_floor() or me._steep_normal == Vector3.ZERO:
		return

	var downhill := Vector3.DOWN.slide(me._steep_normal)
	if downhill.is_zero_approx():
		return
	me.velocity += downhill.normalized() * me.slide_acceleration * delta
	# Nothing is gained by driving into the surface, and keeping that component
	# is what makes a body judder against a slope.
	var into := me.velocity.dot(me._steep_normal)
	if into < 0.0:
		me.velocity -= me._steep_normal * into
	me.velocity -= me.velocity.slide(me._steep_normal) * clampf(me.slide_friction * delta, 0.0, 1.0)


static func get_movement_direction(me: Player) -> Vector3:
	if me.menu_open:
		return Vector3.ZERO
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.is_zero_approx():
		return Vector3.ZERO

	# WASD is interpreted in the camera's yaw frame, not the world frame.
	var cam_basis := me.camera_rig.global_transform.basis
	var direction := cam_basis.x * input.x + cam_basis.z * input.y
	direction.y = 0.0
	return direction.normalized()


## Which way the body is pointed this frame, and the one rule everything else
## about fighting hangs off: **the character shoots and cuts where he is facing**,
## so where he is facing has to be somewhere the player chose.
##
## Four cases, in order:
##
## * **Mid-attack** — held on whatever it was thrown at. A swing does not steer.
## * **Drawing** — the body turns to the shot. Without this the bow points one
##   way and the arrow leaves another, which is the only thing worse than an
##   arrow you cannot see.
## * **Locked and running** — the body turns the way it is *going*. Strafing in
##   a circle is for holding ground; once the player is running they are going
##   somewhere, and a character sprinting sideways with his head over his
##   shoulder is not going there. Backing straight off is the exception: walking
##   away from something while watching it is a thing people do.
## * **Otherwise** — the way it is going, as ever.
static func _aim_body(me: Player, direction: Vector3, delta: float) -> void:
	if me.is_committed() and me._now() >= me._coat_until:
		return
	if me._drawing:
		PlayerMove._face_aim(me, delta)
		return
	if me.target != null:
		if not me.lock_run_turns or direction.is_zero_approx() \
				or (PlayerMove._backing_off(me, direction) and PlayerMove._watches_backing_off(me)) or PlayerMove._strafes_on_lock(me):
			me._face_target(delta)
			return
	if not direction.is_zero_approx():
		PlayerMove._face_direction(me, direction, delta)


## Backing off a target keeps him facing it only behind the shield, or
## walking (careful steps), or with the string drawn (that is [method _face_aim]'s
## before this is asked). Otherwise he turns and runs from it like any other
## way, the camera still on the target: a backpedal at a run is no way for a
## man to go (the user's word, 2026-10-02; for the bow too, 2026-10-04).
static func _watches_backing_off(me: Player) -> bool:
	# (the assassin too now runs from it, turned to the camera, the user's word
	# 2026-10-05; only his evade back is still a step facing it)
	return me.is_blocking or Input.is_action_pressed("walk")


## Whether `direction` is on ahead of him (the way he faces): behind the
## shield only that way does he jog.
static func _guard_ahead(me: Player, direction: Vector3) -> bool:
	if direction.is_zero_approx():
		return false
	var ahead := -me.global_basis.z
	ahead.y = 0.0
	return direction.normalized().dot(ahead.normalized()) > 0.7


## Locked on and stepping carefully — behind the raised shield, or walking
## (TARIEL_POLISH.md 10): every way he goes, forward, back or to either side,
## he keeps facing what he fights, his legs stepping the way he goes (the
## rig's strafe walks); only a run turns him the way he runs. The bow too,
## walking (AVTANDIL_POLISH 3; drawn he faces the shot anyway, [method _face_aim]).
static func _strafes_on_lock(me: Player) -> bool:
	return me.is_blocking or Input.is_action_pressed("walk")


## True when the stick is pointed away from what is being fought — backing off
## rather than breaking off.
static func _backing_off(me: Player, direction: Vector3) -> bool:
	if me.target == null:
		return true
	var to_them := me.target.global_position - me.global_position
	to_them.y = 0.0
	if to_them.length_squared() < 0.0001:
		return true
	return direction.dot(to_them.normalized()) < -0.35


## Turns the body onto the shot: at the target when there is one, down the
## camera otherwise. The arrow leaves along this, so this is the aim.
static func _face_aim(me: Player, delta: float) -> void:
	if me.target != null and me._targetable(me.target):
		me._face_target(delta)
		return
	var looking := -me.camera.global_transform.basis.z
	looking.y = 0.0
	if looking.length_squared() < 0.0001:
		return
	me.rotation.y = lerp_angle(me.rotation.y, atan2(-looking.x, -looking.z),
			1.0 - exp(-me.lock_turn_speed * delta))


static func _face_direction(me: Player, direction: Vector3, delta: float) -> void:
	# Pivoting on the spot is instant-ish; at a sprint the turn has to carve.
	var pace := clampf(Vector3(me.velocity.x, 0.0, me.velocity.z).length() / maxf(me.run_speed, 0.01), 0.0, 1.0)
	var rate := lerpf(me.turn_speed_still, me.turn_speed, pace)
	var target_yaw := atan2(-direction.x, -direction.z)
	me.rotation.y = lerp_angle(me.rotation.y, target_yaw, 1.0 - exp(-rate * delta))


## Places the body on top of a low ledge. The move itself lives in [StepUp],
## because the creatures need it too — a wolf that cannot follow you up a
## staircase is a wolf you beat by standing on a step.
static func _step_up(me: Player, delta: float) -> void:
	StepUp.climb(me, delta, me.max_step_height, me.step_forward_probe)


static func _current_gravity(me: Player) -> float:
	if me.velocity.y > 0.0:
		# Cutting the jump short pulls the player back down faster.
		return me._gravity * (me.low_jump_multiplier if not Input.is_action_pressed("jump") else 1.0)
	return me._gravity * me.fall_gravity_multiplier


static func _do_jump(me: Player) -> void:
	me.velocity.y = me._jump_velocity
	me._jump_buffer_timer = 0.0
	me._coyote_timer = 0.0
	# Whatever ground speed the jump was taken at is the budget for the arc.
	me._air_speed_cap = maxf(Vector3(me.velocity.x, 0.0, me.velocity.z).length(), me.run_speed)
	me.state = Player.State.AIRBORNE
	me.jumped.emit()
	me._move_sound(Player.MoveSound.JUMP)
#endregion


#region Dash
## The dash button. One tap is the hero's own evade — the knight's and the
## mage's roll, the hunter's step, the assassin's step. Evades chain: a press
## while one is going is kept and the next starts the moment it ends, and a
## press just after it ends ([member chain_grace]) follows on without waiting
## out the cooldown. So one can go on evading as long as the stamina lasts.
##
## For everyone but the assassin a second tap within `double_tap_time` of the
## first still upgrades the roll in progress into the library's longer dodge;
## a press later in the roll is the next roll.
##
## The assassin (`CharacterProfile.step_then_flip`) alternates: a step, then
## a twisting flip if another press follows, then a step again, and so on.
## With an enemy locked his steps keep facing it — backward too.
static func _press_dash(me: Player) -> void:
	var now := me._now()
	var alternating := me.profile != null and me.profile.step_then_flip
	var doubled := now - me._last_dash_press <= me.double_tap_time
	me._last_dash_press = now
	var landed := false
	if me.state == Player.State.DASHING or me.state == Player.State.DODGING:
		# The hunter has no double tap: his dodge comes of itself, sideways
		# on a lock ([method _start_evade]).
		# (a rig with no longer evade to turn it into takes the press as the
		# next evade instead)
		if not alternating and doubled and me.state == Player.State.DASHING and not me._is_bow() and PlayerMove._upgrade_to_dodge(me):
			return
		if not PlayerMove._evade_landed(me):
			me._evade_queued = true
			return
		# Feet already down: what is left of this one is only standing up out
		# of it, so the next starts now, with no pause between.
		me._evade_queued = false
		PlayerMove._end_dash(me)
		landed = true
	me._evade_queued = false
	var follows := landed or now <= me._chain_open_until
	me._evade_chain = me._evade_chain + 1 if follows else 0
	if not PlayerMove._start_evade(me, follows):
		me._evade_chain = 0


## Starts the evade that is next in the run: `chained` skips the cooldown.
static func _start_evade(me: Player, chained: bool) -> bool:
	var kind := Player.MoveSound.ROLL
	var started := false
	if me.profile != null and me.profile.step_then_flip:
		if me._evade_chain % 2 == 1:
			kind = Player.MoveSound.FLIP
			started = PlayerMove._start_flip(me, chained)
		else:
			kind = Player.MoveSound.STEP
			var locked := me.target != null and me._targetable(me.target)
			started = PlayerMove._try_dash(me, locked, true, chained)
	elif me._is_bow() and PlayerMove._sideways_on_lock(me):
		# The hunter, locked on and going left or right: straight into the
		# long dodge, as a double tap used to give; any other way, a roll.
		started = PlayerMove._try_dash(me, false, false, chained)
		if started:
			PlayerMove._upgrade_to_dodge(me)
	elif PlayerMove.get_movement_direction(me).is_zero_approx() and me.state == Player.State.GROUNDED:
		# no way pushed: a step back, still facing it
		started = PlayerMove._try_backstep(me, chained)
		if not started:
			started = PlayerMove._try_dash(me, false, false, chained)
	else:
		started = PlayerMove._try_dash(me, false, false, chained)
	if started:
		me._move_sound(kind)
	return started


## The step back: short and quick, untouchable only at its start, cheaper
## than a roll; he keeps facing the way he faced (the rig's `backstep`).
static func _try_backstep(me: Player, chained: bool) -> bool:
	if me.rig == null or not me.rig.has_method(&"backstep"):
		return false
	if me._dash_cooldown_timer > 0.0 and not chained:
		return false
	if not me._spend(me.backstep_stamina):
		return false
	if not bool(me.rig.call(&"backstep", me.backstep_time)):
		me.stamina += me.backstep_stamina
		return false
	me.net_evade.rpc(Player.Evade.BACKSTEP, Vector2.ZERO, me.backstep_time, me._dash_direction, -1)
	me._dash_direction = me.global_transform.basis.z
	me._dash_direction.y = 0.0
	me._dash_direction = me._dash_direction.normalized()
	me.state = Player.State.DASHING
	me._backstepping = true
	me._roll_cut_asked = false
	me._evade_started_at = me._now()
	me._evade_was_perfect = false
	me._dash_timer = me.backstep_time
	me._dash_cooldown_timer = me.dash_cooldown + me.backstep_time
	me.is_invulnerable = me.backstep_iframes > 0.0
	me._safe_until = maxf(me._safe_until, me._now() + me.backstep_iframes)
	me.dash_started.emit(me._dash_direction)
	return true


## Locked on something and pushing mostly left or right.
static func _sideways_on_lock(me: Player) -> bool:
	if me.target == null or not me._targetable(me.target) or me.menu_open:
		return false
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return absf(input.x) > 0.3 and absf(input.x) > absf(input.y)


## The assassin's flip on its own, as the second of a pair: the twisting flip
## the way he is pushing (or on the way he was going), turning to it.
static func _start_flip(me: Player, chained: bool) -> bool:
	var before := me._dash_direction
	if not PlayerMove._try_dash(me, false, false, chained):
		return false
	if PlayerMove.get_movement_direction(me).is_zero_approx() and not before.is_zero_approx():
		me._dash_direction = before
	PlayerMove._upgrade_to_dodge(me)
	return true


static func _try_dash(me: Player, keep_facing: bool = false, step: bool = false, chained: bool = false) -> bool:
	if me.state != Player.State.GROUNDED and me.state != Player.State.AIRBORNE:
		return false
	if me._dash_cooldown_timer > 0.0 and not chained:
		return false
	if not me.is_on_floor() and not me.allow_air_dash:
		return false
	if not me._spend(me.profile.roll_stamina if me.profile != null else 20.0):
		return false

	# Dash towards the stick/WASD input, or straight ahead when standing still.
	me._dash_direction = PlayerMove.get_movement_direction(me)
	if me._dash_direction.is_zero_approx():
		me._dash_direction = -me.global_transform.basis.z
	me._dash_direction.y = 0.0
	me._dash_direction = me._dash_direction.normalized()

	me.state = Player.State.DASHING
	me._evade_started_at = me._now()
	me._evade_was_perfect = false
	me._dash_timer = me.dash_duration
	me._dash_cooldown_timer = me.dash_cooldown + me.dash_duration
	me.is_invulnerable = me.dash_iframes > 0.0
	me._safe_until = maxf(me._safe_until, me._now() + me.dash_iframes)
	me._backstepping = false
	me._roll_cut_asked = false

	if not keep_facing:
		me.rotation.y = atan2(-me._dash_direction.x, -me._dash_direction.z)
	if me.rig != null:
		if step and me.rig.has_method(&"step_dodge"):
			# Which way the step goes, seen from the body: +x its right, -z ahead.
			var local := me.global_transform.basis.inverse() * me._dash_direction
			me.rig.call(&"step_dodge", Vector2(local.x, local.z), me.dash_duration)
			me.net_evade.rpc(Player.Evade.STEP, Vector2(local.x, local.z), me.dash_duration, me._dash_direction, -1)
		else:
			# An evade that cuts on the way (Tariel's dash) cannot be made
			# with the sword away: it comes to the hand as the dash goes.
			var moves: Variant = me.rig.get(&"moves")
			if moves is Dictionary and (moves as Dictionary).has("evade"):
				me._set_weapons_stowed(false)
			var take := randi() & 0x7fffffff
			me._take(take)
			me.rig.dodge(me.dash_duration)
			me._take(-1)
			me.net_evade.rpc(Player.Evade.ROLL, Vector2.ZERO, me.dash_duration, me._dash_direction, take)
	me.dash_started.emit(me._dash_direction)
	return true


## Turns the roll already under way into the longer, animated dodge, keeping the
## direction it was thrown in.
static func _upgrade_to_dodge(me: Player) -> bool:
	if me.stamina <= 0.0:
		return false  # Nothing left to stretch the roll into a dodge with.
	if me.profile != null and me.profile.step_then_flip:
		# A flip goes the way he is going, whichever way he was facing.
		me.rotation.y = atan2(-me._dash_direction.x, -me._dash_direction.z)
	var take := randi() & 0x7fffffff
	me._take(take)
	var clipped := me.rig == null or me.rig.dodge_clip(me.dodge_duration)
	me._take(-1)
	if not clipped:
		return false  # No clip to upgrade to; the roll carries on as it is.
	me.net_evade.rpc(Player.Evade.DODGE, Vector2.ZERO, me.dodge_duration, me._dash_direction, take)
	me._spend(me.profile.dodge_stamina if me.profile != null else 8.0)
	me.state = Player.State.DODGING
	me._dodge_timer = me.dodge_duration
	me._dash_cooldown_timer = me.dash_cooldown + me.dodge_duration
	me.is_invulnerable = me.dodge_iframes > 0.0
	me._safe_until = maxf(me._safe_until, me._now() + me.dodge_iframes)
	me.dodge_started.emit(me._dash_direction)
	return true


## Drives both evades. They differ in how long they last, how fast they travel
## and what the rig is doing, not in how the body is moved.
static func _process_dash(me: Player, delta: float) -> void:
	var dodging := me.state == Player.State.DODGING
	var length := me.dodge_duration if dodging else (me.backstep_time if me._backstepping else me.dash_duration)
	var left := me._dodge_timer if dodging else me._dash_timer
	var iframes := me.dodge_iframes if dodging else (me.backstep_iframes if me._backstepping else me.dash_iframes)

	# Ease the evade out so it does not end with a hard velocity cut.
	var t := clampf(left / maxf(length, 0.001), 0.0, 1.0)
	var speed := (me.dodge_speed if dodging else (me.backstep_speed if me._backstepping else me.dash_speed)) * lerpf(0.55, 1.0, t)
	# Where the clip puts the feet down, the travel stops: no skating on after
	# the landing.
	var land := PlayerMove._land_at(me, dodging)
	if land < 1.0:
		speed *= 1.0 - smoothstep(land - 0.1, land + 0.04, 1.0 - t)
	me.velocity.x = me._dash_direction.x * speed
	me.velocity.z = me._dash_direction.z * speed
	me.velocity.y = 0.0 if me.is_on_floor() else me.velocity.y - me._gravity * delta

	if iframes > 0.0 and length - left >= iframes:
		me.is_invulnerable = false

	# A press kept from earlier goes the moment the feet are down, rather than
	# waiting out the clip's recovery.
	if me._evade_queued and PlayerMove._evade_landed(me):
		PlayerMove._end_dash(me)
		return
	# So does an attack pressed in it: the roll's thrust comes straight out of
	# the landing, one move with it (the user's word 2026-10-13: it waited out
	# the getting up and read as a second press).
	if me._roll_cut_asked and PlayerMove._evade_landed(me):
		PlayerMove._end_dash(me)
		return

	# Going face-first into a wall should stop the evade, not scrape along it.
	if me.dash_cancels_on_wall and me.is_on_wall() and me.get_wall_normal().dot(me._dash_direction) < -0.6:
		PlayerMove._end_dash(me)
		return

	if left <= 0.0:
		PlayerMove._end_dash(me)


## Whether the evade under way has put the feet back down already (past its
## [method _land_at] point): from there on the next evade may cut in.
static func _evade_landed(me: Player) -> bool:
	var dodging := me.state == Player.State.DODGING
	if me.state != Player.State.DODGING and me.state != Player.State.DASHING:
		return false
	var land := PlayerMove._land_at(me, dodging)
	if land >= 1.0:
		return false
	var length := me.dodge_duration if dodging else (me.backstep_time if me._backstepping else me.dash_duration)
	var left := me._dodge_timer if dodging else me._dash_timer
	return 1.0 - left / maxf(length, 0.001) >= land + 0.02


## Where in this evade the feet land ([member CharacterProfile.dodge_land_at]).
static func _land_at(me: Player, dodging: bool) -> float:
	if me.profile == null or (me._backstepping and not dodging):
		return 1.0
	return me.profile.dodge_land_at if dodging else me.profile.dash_land_at


static func _end_dash(me: Player) -> void:
	var dodging := me.state == Player.State.DODGING
	me._evade_ended_at = me._now()
	me.is_invulnerable = false
	me._backstepping = false
	if me._roll_cut_asked:
		# an attack pressed during it: the roll's own, as soon as he is up
		me._roll_cut_asked = false
		me._attack_buffer = me.attack_buffer_time
		me._buffer_other = false
	me.state = Player.State.GROUNDED if me.is_on_floor() else Player.State.AIRBORNE
	# Bleed off the evade so the player keeps a bit of momentum — unless the
	# clip has already landed him, when there is none left to keep.
	var keep := 0.0 if PlayerMove._land_at(me, dodging) < 1.0 else 0.4
	me.velocity.x *= keep
	me.velocity.z *= keep
	if dodging:
		me.dodge_ended.emit()
	else:
		me.dash_ended.emit()
	me._chain_open_until = me._now() + me.chain_grace
	if me._evade_queued:
		# Pressed while this one was going: the next follows straight on.
		me._evade_queued = false
		me._evade_chain += 1
		if not PlayerMove._start_evade(me, true):
			me._evade_chain = 0
#endregion


## Drops into a slide, which only makes sense off a run: it keeps the momentum
## that was already there, adds a little, and shrinks the capsule so the player
## goes under whatever a standing body would not.
static func _try_slide(me: Player) -> bool:
	if me.state != Player.State.GROUNDED or me._slide_cooldown_timer > 0.0:
		return false
	var horizontal := Vector3(me.velocity.x, 0.0, me.velocity.z)
	if horizontal.length() < me.slide_min_speed:
		return false

	me._slide_direction = horizontal.normalized()
	me._slide_speed = horizontal.length() * me.slide_boost
	me._slide_timer = me.slide_duration
	me.state = Player.State.SLIDING
	PlayerMove._set_capsule(me, me.slide_height)
	if me.rig != null:
		me.rig.crouch(false)
		me.rig.slide(true)
	me.slide_started.emit()
	return true


static func _process_slide(me: Player, delta: float) -> void:
	me._slide_speed = maxf(me._slide_speed - me.slide_drag * delta, 0.0)
	me.velocity.x = me._slide_direction.x * me._slide_speed
	me.velocity.z = me._slide_direction.z * me._slide_speed
	me.velocity.y = 0.0 if me.is_on_floor() else me.velocity.y - me._gravity * delta

	# Held down, the slide keeps going as long as it is still going somewhere;
	# released, it ends there and then.
	var holding := Input.is_action_pressed("crouch")
	var spent := me._slide_timer <= 0.0 or me._slide_speed < me.slide_min_speed * 0.45
	if me.is_on_wall() or not me.is_on_floor() or spent or not holding:
		PlayerMove._end_slide(me)


## Comes out of the slide. Still holding the button leaves the player crouched
## rather than standing straight back up, which is also what happens under a low
## gap whether they asked for it or not.
static func _end_slide(me: Player) -> void:
	me.state = Player.State.GROUNDED if me.is_on_floor() else Player.State.AIRBORNE
	me._slide_cooldown_timer = me.slide_cooldown
	if me.rig != null:
		me.rig.slide(false)
	me.slide_ended.emit()

	me._crouching = false
	PlayerMove._set_crouching(me, Input.is_action_pressed("crouch"))


## One tick of the slide: on at what it goes at, turned to it, till he is
## there. Returns the pace to go at.
static func _glide(me: Player, delta: float) -> Vector3:
	me._glide_left -= delta
	var dir := me._glide_dir
	if is_instance_valid(me._glide_foe):
		var to := me._glide_foe.global_position - me.global_position
		to.y = 0.0
		var gap := to.length() - Player._body_radius(me._glide_foe) - me.strike_close
		if gap <= 0.05:
			PlayerMove._end_glide(me)
			return Vector3.ZERO
		dir = to.normalized()
		me.rotation.y = atan2(-dir.x, -dir.z)
		me._glide_dir = dir
		if gap < me.glide_speed * delta:
			PlayerMove._end_glide(me)
			return dir * gap / delta
	if me._glide_left <= 0.0:
		PlayerMove._end_glide(me)
	return dir * me.glide_speed


static func _end_glide(me: Player) -> void:
	me._glide_left = 0.0
	me._glide_foe = null
	# there: the blows now, not when the hold would have run out
	if me.rig != null and me.rig.has_method(&"end_hitstop"):
		me.rig.call(&"end_hitstop")


static func _update_floor_state(me: Player) -> void:
	var on_floor := me.is_on_floor()
	# States that run their own course own the state field until they are done.
	var held := me.state != Player.State.GROUNDED and me.state != Player.State.AIRBORNE

	if on_floor:
		me._coyote_timer = me.coyote_time
		if not me._was_on_floor:
			PlayerMove._land(me)
		if not held:
			me.state = Player.State.GROUNDED
	elif not held:
		if me._was_on_floor:
			# Walked off an edge: the arc keeps the speed it left with.
			me._air_speed_cap = maxf(Vector3(me.velocity.x, 0.0, me.velocity.z).length(), me.run_speed)
		me.state = Player.State.AIRBORNE

	me._was_on_floor = on_floor


static func _land(me: Player) -> void:
	# Coming down hard costs some of the run — a drop should be felt.
	if me._impact_speed > me.hard_landing_speed and me.state != Player.State.DASHING:
		me.velocity.x *= me.hard_landing_grip
		me.velocity.z *= me.hard_landing_grip
	# The fall is over; anything left on the vertical axis only fights the floor
	# snap on the next tick.
	me.velocity.y = 0.0
	me._air_speed_cap = me.run_speed
	if me._impact_speed >= me.land_sound_speed and me._now() > me._quiet_landing_until:
		me._move_sound(Player.MoveSound.LAND, clampf(
				inverse_lerp(me.land_sound_speed, me.hard_landing_speed, me._impact_speed), 0.0, 1.0))
	me.landed.emit(me._impact_speed)
	me._impact_speed = 0.0
	if me._plunging:
		me._plant_blade()


## The body leant into what it is doing, over its feet: into a turn the
## faster and tighter it carves, forward as a run picks up, back as it pulls
## up. Laid on the model's own transform (the capsule stays upright), worked
## out from the turning and the replicated velocity, so every peer sees it.
static func _lean(me: Player, delta: float, planar: float, off_ground: bool) -> void:
	if me.rig == null:
		return
	if not me._lean_ready:
		me._lean_rest = me.rig.transform.basis
		me._lean_yaw = me.rotation.y
		me._lean_vel = me.velocity
		me._lean_ready = true
	var dt := maxf(delta, 0.0001)
	var yaw_rate := wrapf(me.rotation.y - me._lean_yaw, -PI, PI) / dt
	var flat := Vector3(me.velocity.x, 0.0, me.velocity.z)
	var accel := (flat - Vector3(me._lean_vel.x, 0.0, me._lean_vel.z)) / dt
	me._lean_yaw = me.rotation.y
	me._lean_vel = me.velocity
	var roll := 0.0
	var pitch := 0.0
	if not off_ground and not me.is_committed() and not me._bitten() and planar > 0.5:
		roll = clampf(yaw_rate * planar * me.turn_lean_rate, -me.turn_lean_max, me.turn_lean_max)
	if not off_ground and not me.is_committed():
		var ahead := -me.global_basis.z
		# Forward lean is a negative turn about the body's x.
		pitch = -clampf(accel.dot(ahead) * me.pace_lean_rate, -me.pace_lean_back, me.pace_lean_max)
	# Pulled up hard out of a run, or thrown back the other way: the feet dig
	# in and kick up a little dust.
	var was_pace := Vector3(me._lean_prev_flat.x, 0.0, me._lean_prev_flat.z).length()
	me._lean_prev_flat = flat
	if not off_ground and was_pace > me.skid_pace and accel.dot(me._lean_prev_dir) < -me.skid_brake \
			and Time.get_ticks_msec() - me._skid_at > 450:
		me._skid_at = Time.get_ticks_msec()
		var world := Blood.world_of(me)
		if world != null:
			DustRing.burst(world, me.global_position + me._lean_prev_dir * 0.35, me.skid_dust)
	if planar > 0.5:
		me._lean_prev_dir = flat / planar
	var k := 1.0 - exp(-me.lean_follow * delta)
	me._lean_roll = lerpf(me._lean_roll, roll, k)
	# Forward and back on a spring, a little under-damped: pulled up out of a
	# run he rocks back, a touch forward past upright on the way, and is still
	# (`pace_sway_stiffness`, `pace_sway_damping`).
	var pull := (pitch - me._lean_pitch) * me.pace_sway_stiffness - me._lean_pitch_speed * me.pace_sway_damping
	me._lean_pitch_speed += pull * minf(delta, 0.05)
	me._lean_pitch += me._lean_pitch_speed * minf(delta, 0.05)
	me._lean_pitch = clampf(me._lean_pitch, -me.pace_lean_back * 1.3, me.pace_lean_max * 1.3)
	me.rig.transform.basis = Basis.from_euler(Vector3(me._lean_pitch, 0.0, me._lean_roll)) * me._lean_rest
	PlayerMove._tumble_show(me, delta)


static func _tumble_show(me: Player, delta: float) -> void:
	if me.rig == null:
		return
	if not me._tumble_rest_got:
		me._tumble_rest_got = true
		me._tumble_rest_pos = me.rig.position
	if not me._tumble_on and me._tumble_angle == 0.0:
		return
	var in_air := not me.is_on_floor() if me.is_multiplayer_authority() else me.net_airborne
	if me._tumble_on:
		me._tumble_angle += Player.TUMBLE_SPEED * delta
		# down: the turn it is in finished quickly, then he lies as he fell
		if (not in_air and me._tumble_angle > 0.6) or me._tumble_angle > TAU * 2.0:
			me._tumble_on = false
	else:
		var to := ceilf(me._tumble_angle / TAU - 0.15) * TAU
		me._tumble_angle = move_toward(me._tumble_angle, to, Player.TUMBLE_SPEED * 2.0 * delta)
		if absf(me._tumble_angle - to) < 0.001:
			me._tumble_angle = 0.0
	var turn := Basis(Vector3.RIGHT, me._tumble_angle)
	me.rig.transform.basis = turn * me.rig.transform.basis
	me.rig.position = me._tumble_rest_pos + (Player.TUMBLE_PIVOT - turn * Player.TUMBLE_PIVOT)
	if me._tumble_angle == 0.0:
		me.rig.position = me._tumble_rest_pos


## Resizes the capsule about the feet, so shrinking it never lifts the body off
## the ground or drops it through it.
static func _set_capsule(me: Player, height: float) -> void:
	var capsule := me._collider.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.height = height
	me._collider.position.y = me._stand_centre - (me._stand_height - height) * 0.5


## True once the capsule is back to its standing size. False means something is
## in the way and the player has to stay down.
static func _stand_up(me: Player) -> bool:
	var capsule := me._collider.shape as CapsuleShape3D
	if capsule == null or is_equal_approx(capsule.height, me._stand_height):
		return true

	var crouched := capsule.height
	var crouched_centre := me._collider.position.y
	PlayerMove._set_capsule(me, me._stand_height)
	if not me.test_move(me.global_transform, Vector3.ZERO):
		return true

	capsule.height = crouched
	me._collider.position.y = crouched_centre
	return false
#endregion


#region Crouch
## Holds the body down, or lets it back up. Standing waits until there is room:
## under a low gap the crouch simply carries on.
static func _set_crouching(me: Player, down: bool) -> void:
	if me.state == Player.State.SLIDING or me.state == Player.State.CLIMBING:
		return
	# Taking hold of a wall drops the crouch on the way in, which is the one time
	# it is set from this state; nothing else may touch it while hanging.
	if me.state == Player.State.WALLCLIMB and down:
		return
	# Wanting to stand and being able to are different things, so the body is
	# only up once the full capsule fits. `or` short-circuits, which is what
	# keeps the stand-up probe out of the way while the button is still held.
	var held := down or not PlayerMove._stand_up(me)
	if held == me._crouching:
		return

	me._crouching = held
	if held:
		PlayerMove._set_capsule(me, me.crouch_height)
	if me.rig != null:
		me.rig.crouch(held)
