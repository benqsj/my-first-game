class_name PlayerBow
extends RefCounted

## The bow: drawing, aiming, loosing, the archer's arrow skills.
## Taken out of player.gd (2026-10-28) so the hero is in parts; every
## function takes the hero as `me` and works on it as it did before. [Player]
## keeps a one-line function of the same name for each one called from
## outside this file (other scripts, the rig, signals, the hero himself).

#region Bow
## Hold to draw, let go to loose. How long it was held is the whole of it: a
## tapped shot leaves at once and lands for a fraction, a held one takes a beat
## and lands for all of it. Nothing else about the shot changes, so the player
## is choosing between rate and weight rather than between two buttons.
static func _tick_bow(me: Player, delta: float) -> void:
	me._shot_timer = maxf(me._shot_timer - delta, 0.0)
	if me._draw_sound != null and not me._drawing:
		Sfx.stop(me._draw_sound)
		me._draw_sound = null
	# The block button draws too, for the fan of three ([method _fan_ready]).
	var fanning := PlayerBow._fan_ready(me) and Input.is_action_pressed("block")
	var holding := (Input.is_action_pressed("attack") or fanning) and not me.menu_open and not me.unarmed
	# Committed as well as rolling: the beat after the string goes belongs to the
	# shot that was just taken, and an archer who can start the next draw before
	# his arm has come down is an archer with no rate of fire to manage.
	var busy := (me.state != Player.State.GROUNDED and me.state != Player.State.AIRBORNE) or me.is_committed()
	# The bow is not drawn in the air (no shooting from a jump; the user's word,
	# 2026-10-05): a jump lets the string go unshot, as a roll does.
	# A step off a kerb (still within coyote time) keeps the draw.
	if me.state == Player.State.AIRBORNE and me._is_bow() and me._coyote_timer <= 0.0:
		busy = true

	if busy:
		# Rolling or climbing with a drawn bow is not a thing. The draw is lost,
		# not banked: it has to be earned again.
		me._drawing = false
		me._draw_timer = 0.0
	elif holding and not me._drawing:
		if me._shot_timer <= 0.0 and me.stamina > 0.0:
			me._drawing = true
			me._draw_timer = 0.0
			me._fan_draw = fanning and not Input.is_action_pressed("attack")
			me._set_weapons_stowed(false)
			if me._is_bow():
				me._draw_sound = Sfx.play(me, Player.DRAW_SOUND, me, Vector3.ZERO, 1.0, -12.0)
				me.net_creak.rpc()
	elif holding and me._drawing:
		me._draw_timer += delta
		# Held, a draw or a charge costs breath as it goes; run out and it goes.
		var drain := me.profile.draw_stamina if me.profile != null else 0.0
		if drain > 0.0:
			me._spend(drain * delta)
			if me.stamina <= 0.0:
				PlayerBow._loose_arrow(me)
	elif me._drawing:
		if me.profile != null and me._draw_timer < me.profile.min_draw:
			# let go too soon: it goes on gathering to its least, then goes
			me._draw_timer += delta
		else:
			PlayerBow._loose_arrow(me)

	if me.rig != null and me.rig.has_method(&"aim_bow"):
		me.rig.call(&"aim_bow", PlayerBow.draw_power(me) if me._drawing else 0.0, PlayerBow._aim_pitch(me))


## How far the string has come back, 0 to 1. Everything a shot is worth is this
## number, so it is the one the HUD would draw.
static func draw_power(me: Player) -> float:
	if me.profile == null or me.profile.draw_time <= 0.0:
		return 1.0
	# the bow in his hands draws quicker or slower than his own ([BowKinds])
	var full := me.profile.draw_time * BowKinds.draw(me)
	# The least gathering a spell must have ([member CharacterProfile.min_draw])
	# earns nothing: a click is still worth a click, only slower to come.
	var least := minf(me.profile.min_draw, full * 0.5)
	return clampf((me._draw_timer - least) / (full - least), 0.0, 1.0)


## True while the string is being held.
static func is_drawing(me: Player) -> bool:
	return me._drawing


## Lets the arrow go.
static func _loose_arrow(me: Player) -> void:
	var power := PlayerBow.draw_power(me)
	me._drawing = false
	me._draw_timer = 0.0
	me._shot_timer = me.profile.shot_cooldown if me.profile != null else 0.2
	me._spend(me.profile.attack_stamina if me.profile != null else 12.0)

	# Where the shot is pointed is decided *before* the body is turned onto the
	# target, so a shot loosed while running sideways goes at what is being
	# fought rather than past it.
	me._turn_to_target()
	var speed := lerpf(me.profile.arrow_speed_snap, me.profile.arrow_speed, power)
	# A tap is worth `snap_share` of a full draw and no less; the rest of the
	# scale is earned by holding.
	var carry := lerpf(me.profile.snap_share, 1.0, power)
	var critical := me._shot_rng.randf() < me.profile.crit_chance
	var damage := me.profile.shot_power() * BowKinds.atk(me) * carry * (me.profile.crit_damage if critical else 1.0)
	# The moment to let go: read off the rig before the loose resets it.
	var grade := int(me.rig.call(&"release_grade")) if me.rig != null and me.rig.has_method(&"release_grade") else 0
	var shaking := float(me.rig.call(&"shake")) if me.rig != null and me.rig.has_method(&"shake") else 0.0
	if grade == 1:
		damage *= me.perfect_release_bonus
	# Held all the way: the mage's full charge is a bigger bolt, and hits harder
	# than the draw's scale alone would make it.
	if power >= 0.97:
		damage *= me.profile.full_charge_bonus
	# The shot is thrown; now it has to be lived with. The string going is the
	# same kind of commitment a swing is — the difference is that the archer
	# chooses when, because the draw itself can be held or let go of.
	me._commit(me.loose_recovery)
	me.arrow_loosed.emit(power, damage, critical)

	# A spell is thrown with the staff, and leaves it from the crystal when the
	# staff comes through — a beat after the button, which the rig says.
	var lead := 0.0
	if me.rig != null and me.rig.has_method(&"cast_lead"):
		lead = float(me.rig.call(&"cast_lead"))
	if lead > 0.0:
		me.net_cast.rpc()
		await me.get_tree().create_timer(lead, false).timeout
		if not me.is_inside_tree() or me.state == Player.State.DOWNED:
			return
	var from := me.global_position + me.up_direction * me.arrow_height
	# Off the bow, where the arrow on the string was, when there is one: shot
	# from the fixed height it left from below the bow.
	if me.rig != null and me.rig.has_method(&"loose_point"):
		var nocked: Vector3 = me.rig.call(&"loose_point")
		if nocked.is_finite():
			from = nocked
	if me.rig != null and me.rig.has_method(&"spell_origin"):
		from = me.rig.call(&"spell_origin")
	var heading := PlayerBow._shot_heading(me, from, speed)
	if shaking > 0.0:
		var wander := deg_to_rad(me.release_spread) * shaking
		var across := heading.cross(me.up_direction)
		if across.length() > 0.01:
			heading = heading.rotated(across.normalized(), wander * me._shot_rng.randf_range(-1.0, 1.0))
		heading = heading.rotated(me.up_direction, wander * me._shot_rng.randf_range(-1.0, 1.0)).normalized()
	# Everywhere, not just here. A locked shot is told what it was loosed at,
	# which a bolt hunts.
	var quarry := NodePath()
	if me.target != null and me._targetable(me.target):
		quarry = me.target.get_path()
	if me._fan_draw:
		# Three, side by side across the shot (none of them hunting), each worth
		# `fan_share` of what the one would have been.
		me._fan_draw = false
		me._fan_ready_at = me._now() + me.fan_cooldown
		me._spend(me.fan_stamina)
		for k in [0, -1, 1]:
			var way := heading.rotated(me.up_direction, deg_to_rad(me.fan_spread) * float(k)).normalized()
			me.net_loose.rpc(from, way * speed, damage * me.fan_share, critical, NodePath(), power, grade == 1, 0.0, k != 0)
		return
	me.net_loose.rpc(from, heading * speed, damage, critical, quarry, power, grade == 1)


static func _fan_ready(me: Player) -> bool:
	return me._is_bow() and me.profile != null and not me.profile.can_block and me._now() >= me._fan_ready_at
#endregion


## Where the shot goes.
##
## Down the line the **body** is facing, at the pitch the aim asks for. Not down
## the camera: the camera can be looking anywhere, and an arrow that leaves at
## forty degrees to the bow held on screen is an arrow the player cannot aim,
## however correct the maths behind it. `_face_aim()` is the other half — while
## the string is held the body turns onto the shot, so by the time it is loosed
## the two are the same line.
static func _shot_heading(me: Player, from: Vector3, speed: float = 40.0) -> Vector3:
	var wanted := PlayerBow._aim_direction(me, from, speed)
	var forward := -me.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return wanted
	forward = forward.normalized()
	# The pitch is the aim's; the bearing is the body's. Keeping the pitch is
	# what lets a shot be lofted or put into something below without the body
	# having to lean.
	var rise := clampf(wanted.y, -1.0, 1.0)
	return (forward * sqrt(maxf(1.0 - rise * rise, 0.0)) + Vector3.UP * rise).normalized()


## Where the shot is *asked* to go: at whatever is being fought, or at whatever
## the camera is pointing at when nothing is. What actually leaves the bow is
## `_shot_heading()`, which keeps this pitch and takes its bearing off the body.
##
## A locked shot leads its target. An arrow takes a beat to arrive and a wolf
## does not wait where it was standing, so aiming at where it *is* means a slow
## shot at a moving target is a miss the player did nothing wrong to earn. What
## the lock is for is not having to solve that by hand.
static func _aim_direction(me: Player, from: Vector3, speed: float = 40.0) -> Vector3:
	if me.target != null and me._targetable(me.target):
		var at := me._aim_point(me.target)
		var moving: Variant = me.target.get("velocity")
		if moving is Vector3:
			var flight := from.distance_to(at) / maxf(speed, 1.0)
			# Led along the ground only, and only for a body that is moving at
			# all: one held still (the arena's Hold still) keeps the velocity it
			# had, and a creature's fall or a step's bob sent the shot into the
			# ground short of it.
			var ground := Vector3((moving as Vector3).x, 0.0, (moving as Vector3).z)
			if me.target.is_physics_processing():
				at += ground * flight
			# And the drop over that flight, so the arc is aimed through rather
			# than along.
			at.y += 0.5 * me._gravity * PlayerBow._shot_drop(me) * flight * flight
		var to_them := at - from
		if to_them.length_squared() > 0.0001:
			return to_them.normalized()

	# Down the middle of the view, at whatever it lands on — so the arrow goes
	# where the crosshair is rather than parallel to it.
	var eye := me.camera.global_position
	var looking := -me.camera.global_transform.basis.z
	var space := me.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
			eye, eye + looking * me.lock_range * 2.0, me.collision_mask, [me.get_rid()])
	var hit := space.intersect_ray(query)
	var at := eye + looking * me.lock_range * 2.0
	if not hit.is_empty():
		var landed: Vector3 = hit["position"]
		# Anything this close under the crosshair is the ground at your feet.
		# Shooting at it is how an arrow ends up buried three paces away.
		if eye.distance_to(landed) > me.aim_min_range:
			at = landed
			# Through the drop, as a locked shot is: the arrow comes down on
			# what is under the crosshair rather than a hand below it.
			var flight := from.distance_to(at) / maxf(speed, 1.0)
			at.y += 0.5 * me._gravity * PlayerBow._shot_drop(me) * flight * flight
	var heading := at - from
	return heading.normalized() if heading.length_squared() > 0.0001 else looking


## Brings the view towards level while the string is held.
##
## Only while there is nothing locked: a lock already points the camera at what
## is being shot at, and two things steering the same camera fight each other.
static func _level_camera(me: Player, delta: float) -> void:
	if not me._drawing or me.target != null:
		return
	me.spring_arm.rotation.x = lerp_angle(me.spring_arm.rotation.x,
			clampf(deg_to_rad(me.aim_camera_pitch), deg_to_rad(me.min_pitch_deg),
					deg_to_rad(me.max_pitch_deg)),
			1.0 - exp(-me.aim_camera_speed * delta))


## Closes the view in on the shot as the string comes back, and opens it
## again after (`draw_zoom_degrees`). Set outright from the resting field of
## view while it is in, so it never drifts; left alone at rest.
static func _draw_zoom(me: Player, delta: float) -> void:
	if me.camera == null or not me.camera.current or not me._is_bow():
		return
	if me._fov_rest < 0.0:
		me._fov_rest = me.camera.fov
	var want := me.draw_zoom_degrees * PlayerBow.draw_power(me) if me._drawing else 0.0
	var was := me._draw_zoom_now
	me._draw_zoom_now = lerpf(me._draw_zoom_now, want, 1.0 - exp(-me.draw_zoom_speed * delta))
	if me._draw_zoom_now < 0.02 and want <= 0.0:
		me._draw_zoom_now = 0.0
		if was > 0.0:
			me.camera.fov = me._fov_rest
		else:
			me._fov_rest = me.camera.fov
		return
	me.camera.fov = me._fov_rest - me._draw_zoom_now


## How far off the level the shot is aimed, in radians, for the rig to lean on.
## The same heading the arrow will leave on, so what the body does and what the
## arrow does are one number rather than two that happen to agree.
static func _aim_pitch(me: Player) -> float:
	var from := me.global_position + me.up_direction * me.arrow_height
	return asin(clampf(PlayerBow._shot_heading(me, from).y, -1.0, 1.0))
#endregion


## How much of the world's gravity the shot falls with.
static func _shot_drop(me: Player) -> float:
	if me.profile != null and me.profile.projectile_drop >= 0.0:
		return me.profile.projectile_drop
	return me.arrow_drop
#endregion


## Where a skill shot leaves from: the head of the arrow on the string, or the
## bow hand, or his chest, whichever the rig can say.
static func _arrow_tip(me: Player) -> Vector3:
	if me.rig != null and me.rig.has_method(&"arrow_tip"):
		return me.rig.call(&"arrow_tip")
	if me.rig != null and me.rig.has_method(&"bow_hand"):
		return me.rig.call(&"bow_hand")
	return me.global_position + me.up_direction * me.arrow_height


#region Fire Arrow
## Fire Arrow: the head catches as he draws, the arrow is lobbed to come down
## where he aims, and the ground there burns for `fire_time`.
static func _fire_arrow(me: Player) -> bool:
	if not me._is_bow():
		return false
	if not me._spend(float(Player.SKILLS[&"fire_arrow"]["stamina"])):
		return false
	me._drawing = false
	me._draw_timer = 0.0
	var at := PlayerBow._fire_point(me)
	PlayerBow._face_point(me, at)
	var nock := float(me.rig.call(&"nock_lead", 0.0, Player.FIRE_QUICK)) if me.rig != null and me.rig.has_method(&"nock_lead") else 0.3
	me._commit(nock + Player.FIRE_HOLD + 0.45)
	PlayerBow._root(me, nock + Player.FIRE_HOLD + 0.45)
	var damage := (me.profile.damage if me.profile != null else 30.0) * BowKinds.atk(me) * me.fire_share
	me.net_fire_arrow.rpc(at, damage)
	return true


## Where the fire goes: on what is locked in range, else ahead; on the ground.
static func _fire_point(me: Player) -> Vector3:
	var forward := -me.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var at := me.global_position + forward * me.fire_ahead
	var quarry := PlayerBow._skill_quarry(me, me.fire_range)
	if quarry != null:
		at = quarry.global_position + (me.global_position - quarry.global_position).normalized() * 0.4
	var space := me.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN * 20.0, 1))
	if not hit.is_empty():
		at = hit["position"]
	return at


## Rain of Arrows: one arrow up into the sky, and a moment later a volley down
## over a ring — on what is locked, if it is in reach, or ahead of him.
static func _arrow_rain(me: Player) -> bool:
	if not me._is_bow() or me.arrow_scene == null:
		return false
	if not me._spend(float(Player.SKILLS[&"arrow_rain"]["stamina"])):
		return false
	me._drawing = false
	me._draw_timer = 0.0
	var centre := PlayerBow._rain_centre(me)
	var lead := float(me.rig.call(&"sky_lead")) if me.rig != null and me.rig.has_method(&"sky_lead") else 0.0
	var toward := centre - me.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		me.rotation.y = atan2(-toward.x, -toward.z)
	# Stood still through the shot, until just after the string goes.
	me._commit(lead + 0.35 if lead > 0.0 else 0.55)
	var from := me.global_position + me.up_direction * me.arrow_height
	var up := (toward.normalized() * 0.3 + Vector3.UP).normalized() * 38.0
	var quarry := NodePath()
	if me.target != null and me._targetable(me.target) and centre.distance_to(me.target.global_position) < 3.0:
		quarry = me.target.get_path()
	me.net_arrow_rain.rpc(from, up, centre, randi(), quarry)
	return true


## Where the rain falls: on the locked target in reach, else ahead; on the
## ground under that point.
static func _rain_centre(me: Player) -> Vector3:
	var forward := -me.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var at := me.global_position + forward * me.rain_ahead
	if me.target != null and me._targetable(me.target):
		var off := me.target.global_position - me.global_position
		off.y = 0.0
		at = me.global_position + off.limit_length(me.rain_range)
	var space := me.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 12.0, at + Vector3.DOWN * 20.0, 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		at = hit["position"]
	return at


#region Piercing Arrow
## Piercing Arrow: the string held past full while the wind gathers on the
## head, then one arrow, flat and fast, through everything on its line.
static func _piercing_arrow(me: Player) -> bool:
	if not me._is_bow():
		return false
	if not me._spend(float(Player.SKILLS[&"piercing_arrow"]["stamina"])):
		return false
	me._drawing = false
	me._draw_timer = 0.0
	var quarry := PlayerBow._skill_quarry(me, me.pierce_reach)
	# Followed through the draw: body (and so the camera's lock) turn with it.
	me._pierce_quarry = quarry
	if quarry != null:
		PlayerBow._face_point(me, quarry.global_position)
	var nock := float(me.rig.call(&"nock_lead", 1.0)) if me.rig != null and me.rig.has_method(&"nock_lead") else 0.3
	me._commit(nock + me.pierce_hold + 0.45)
	PlayerBow._root(me, nock + me.pierce_hold + 0.45)
	var from := me.global_position + me.up_direction * me.arrow_height
	var dir := -me.global_transform.basis.z
	if quarry != null:
		dir = HuntingLight._aim_of(quarry) - from
	dir = dir.normalized()
	var critical := me._shot_rng.randf() < (me.profile.crit_chance if me.profile != null else 0.1)
	var damage := (me.profile.damage if me.profile != null else 30.0) * BowKinds.atk(me) * me.pierce_share \
			* ((me.profile.crit_damage if me.profile != null else 2.0) if critical else 1.0)
	me.net_piercing.rpc(dir, damage, critical)
	return true


## Through the Piercing Arrow's draw, keeps him turned on what it was drawn at
## — quickly, but not in a snap — so a quarry that leaps past him or behind
## him is still what the shot goes at. The lock camera follows it as ever.
static func _track_pierce(me: Player, delta: float) -> void:
	if me._pierce_quarry == null:
		return
	if not is_instance_valid(me._pierce_quarry) or not me.is_committed() or me.is_dead:
		me._pierce_quarry = null
		return
	var toward := me._pierce_quarry.global_position - me.global_position
	toward.y = 0.0
	if toward.length_squared() < 0.01:
		return
	var want := atan2(-toward.x, -toward.z)
	me.rotation.y = lerp_angle(me.rotation.y, want, 1.0 - exp(-14.0 * delta))


static func _stun_arrow(me: Player) -> bool:
	if not me._is_bow():
		return false
	if not me._spend(float(Player.SKILLS[&"stun_arrow"]["stamina"])):
		return false
	me._drawing = false
	me._draw_timer = 0.0
	me._turn_to_target()
	# turned on with it through the draw and the hold, as the Piercing Arrow
	# is and as a drawn string is ([method _track_pierce])
	if me.target != null and me._targetable(me.target):
		me._pierce_quarry = me.target
	var nock := float(me.rig.call(&"nock_lead", Player.STUN_BRACE, Player.STUN_QUICK)) if me.rig != null and me.rig.has_method(&"nock_lead") else 0.3
	me._commit(nock + Player.STUN_HOLD + 0.45)
	PlayerBow._root(me, nock + Player.STUN_HOLD + 0.45)
	me.net_stun_draw.rpc(PlayerBow._aim_pitch(me))
	PlayerBow._stun_loose(me, nock + Player.STUN_HOLD, me._skill_serial)
	return true


## The stunning arrow let go when the draw and the hold are through (cut
## short if he is hit first, [method _interrupt_skill]).
static func _stun_loose(me: Player, after: float, serial: int) -> void:
	await me.get_tree().create_timer(after, false).timeout
	if serial != me._skill_serial or not me.is_inside_tree() or me.is_dead:
		return
	me._pierce_quarry = null
	var from := PlayerBow._arrow_tip(me)
	var speed := me.profile.arrow_speed if me.profile != null else 60.0
	# at the target, wherever it has stepped to while the shot was held, not
	# down the body's line as it was braced (the arrow follows it from there)
	var heading := PlayerBow._shot_heading(me, from, speed)
	if me.target != null and me._targetable(me.target):
		heading = PlayerBow._aim_direction(me, from, speed)
	var damage := (me.profile.shot_power() if me.profile != null else 30.0) * BowKinds.atk(me) * me.stun_share
	var quarry := NodePath()
	if me.target != null and me._targetable(me.target):
		quarry = me.target.get_path()
	me.net_loose.rpc(from, heading * speed, damage, false, quarry, 1.0, false, me.stun_chance)


#region Hunter's Mark
## Hunter's Mark: he points at the prey and a glint flies from his fingers
## onto it. For `mark_time` it is marked — the sigil over it, an outline, a
## ring on the ground — and every blow on it, anyone's, bites deeper.
static func _hunters_mark(me: Player) -> bool:
	if not me._is_bow():
		return false
	var quarry := PlayerBow._skill_quarry(me, me.mark_range)
	if quarry == null:
		return false
	if not me._spend(float(Player.SKILLS[&"hunters_mark"]["stamina"])):
		return false
	# On the run: he does not stop or turn; the string hand flicks out at the
	# prey and the glint goes ([method SkinnedArcherRig.point_mark]). A draw
	# under way is let down — that hand is busy.
	me._drawing = false
	me._draw_timer = 0.0
	me.net_hunters_mark.rpc(quarry.get_path())
	return true


## Stands him where he is for `seconds`: the way he was going stops now,
## rather than sliding out.
static func _root(me: Player, seconds: float) -> void:
	me._root_timer = maxf(me._root_timer, seconds)
	me.velocity.x = 0.0
	me.velocity.z = 0.0


## Something to aim a skill at: what is locked, if it is in `reach`, else the
## best thing in front.
static func _skill_quarry(me: Player, reach: float) -> Node3D:
	if me.target != null and me._targetable(me.target) and me.global_position.distance_to(me.target.global_position) <= reach:
		return me.target
	var best := me._best_target()
	if best != null and me.global_position.distance_to(best.global_position) <= reach:
		return best
	return null


static func _face_point(me: Player, at: Vector3) -> void:
	var toward := at - me.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.01:
		me.rotation.y = atan2(-toward.x, -toward.z)
