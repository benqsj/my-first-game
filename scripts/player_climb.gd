class_name PlayerClimb
extends RefCounted

## Climbing: ledges and the pull-up, walls and wall climbing.
## Taken out of player.gd (2026-10-28) so the hero is in parts; every
## function takes the hero as `me` and works on it as it did before. [Player]
## keeps a one-line function of the same name for each one called from
## outside this file (other scripts, the rig, signals, the hero himself).

#region Climb
## Pulls the body up over a ledge in front of it, if there is one within reach
## and something to stand on when it gets there.
## What the hands and feet may take hold of or stand on in a climb: the world,
## not a creature (no pulling up onto an orc's shoulders, nor a wall made of a
## troll; the user's word, 2026-10-06).
static func _climb_mask(me: Player) -> int:
	return me.collision_mask & ~Player.ENEMY_LAYER & ~Player.HERO_LAYER


## Standing on a creature (come down on its head): slid off it, out the way
## it is from its middle (the user's word, 2026-10-06: no standing on them).
static func _slip_off_creatures(me: Player) -> void:
	if not me.is_on_floor():
		return
	for i in me.get_slide_collision_count():
		var hit := me.get_slide_collision(i)
		var who := hit.get_collider() as Node3D
		if who == null or not (who.is_in_group("enemy") or who.is_in_group("player")) \
				or hit.get_normal().dot(me.up_direction) < 0.3:
			continue
		var away := me.global_position - who.global_position
		away.y = 0.0
		if away.length_squared() < 0.0025:
			away = me.global_basis.z
		away = away.normalized()
		me.velocity.x = away.x * Player.CREATURE_SLIP_SPEED
		me.velocity.z = away.z * Player.CREATURE_SLIP_SPEED
		me.global_position += away * 0.05
		return


static func _try_climb(me: Player) -> bool:
	if me.state != Player.State.GROUNDED and me.state != Player.State.AIRBORNE:
		return false
	var landing := PlayerClimb._find_ledge(me)
	if landing == Vector3.ZERO:
		return false
	PlayerClimb._begin_mantle(me, landing)
	return true


## Hands the body over to the pull-up, wherever it was called from: off the
## ground, out of a jump, or off the top of a face that has just been climbed.
static func _begin_mantle(me: Player, landing: Vector3) -> void:
	if me.state == Player.State.WALLCLIMB and me.rig != null:
		me.rig.wall_climb(false)
	me._climb_from = me.global_position
	me._climb_to = landing
	me._climb_timer = me.climb_duration
	me.state = Player.State.CLIMBING
	me.velocity = Vector3.ZERO
	# A plunge only ends in `_land()`, and a mantle finishes standing without
	# ever passing through it — so a jump-attack that catches a ledge would hold
	# the commitment open forever. The pull-up takes the fall's place.
	me._plunging = false
	me._jump_buffer_timer = 0.0
	if me.rig != null:
		var take := randi() & 0x7fffffff
		me._take(take)
		me.rig.climb(me.climb_duration)
		me._take(-1)
		me.net_mantle.rpc(take)
	me.climb_started.emit(landing)


## Where the body would end up after mantling whatever is in front of it, or
## ZERO if there is nothing to mantle.
##
## Three questions, in the order that rules the most out soonest: is there a
## face to grab, does it have a top edge within reach, and is there room to
## stand on it.
static func _find_ledge(me: Player) -> Vector3:
	var facing := -me.global_transform.basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		return Vector3.ZERO
	facing = facing.normalized()

	var space := me.get_world_3d().direct_space_state
	var exclude: Array[RID] = [me.get_rid()]

	var chest := me.global_position + me.up_direction * me.climb_min_height
	var face := PhysicsRayQueryParameters3D.create(
			chest, chest + facing * me.climb_reach, PlayerClimb._climb_mask(me), exclude)
	if space.intersect_ray(face).is_empty():
		return Vector3.ZERO

	# Feel down for the top from above the tallest ledge that can be taken — at
	# the face itself first and then further in, so the top of something thin (a
	# fence rail) is found too, not only the ground beyond it.
	var hit := {}
	var rise := 0.0
	for reach: float in [0.4, 0.55, me.climb_reach]:
		var above := me.global_position + me.up_direction * (me.climb_max_height + 0.4) + facing * reach
		var top := PhysicsRayQueryParameters3D.create(
				above, above - me.up_direction * (me.climb_max_height + 0.4), PlayerClimb._climb_mask(me), exclude)
		hit = space.intersect_ray(top)
		if hit.is_empty():
			continue
		rise = ((hit.position as Vector3) - me.global_position).dot(me.up_direction)
		if rise >= me.climb_min_height and rise <= me.climb_max_height:
			break
		hit = {}
	if hit.is_empty():
		return Vector3.ZERO

	var lip: Vector3 = hit.position
	if (hit.normal as Vector3).dot(me.up_direction) < cos(me.floor_max_angle):
		return Vector3.ZERO  # The top is too steep to be a landing.

	# Far enough in from the edge that the capsule is not left overhanging it.
	var landing: Vector3 = lip + facing * 0.25
	me._vault_peak = -INF
	var headroom := PhysicsRayQueryParameters3D.create(
			landing + me.up_direction * 0.05, landing + me.up_direction * me.climb_headroom,
			PlayerClimb._climb_mask(me), exclude)
	if not space.intersect_ray(headroom).is_empty():
		return Vector3.ZERO
	# A thin top — a fence rail, the coping of a wall — is nowhere to stand: the
	# landing past its edge has nothing under it. Over it instead, to the
	# ground on the far side (a vault), rather than up into the air beyond it.
	var under := PhysicsRayQueryParameters3D.create(landing + me.up_direction * 0.3,
			landing - me.up_direction * 0.4, PlayerClimb._climb_mask(me), exclude)
	if space.intersect_ray(under).is_empty():
		var beyond := lip + facing * 1.1
		var down := PhysicsRayQueryParameters3D.create(beyond + me.up_direction * 0.3,
				beyond - me.up_direction * (rise + 2.0), PlayerClimb._climb_mask(me), exclude)
		var ground := space.intersect_ray(down)
		if ground.is_empty() or (ground.normal as Vector3).dot(me.up_direction) < cos(me.floor_max_angle):
			return Vector3.ZERO
		me._vault_peak = lip.y + 0.35
		return ground.position
	return landing


## Carries the body up and then in, rather than straight at the corner: a lerp
## between the two ends would drag it through the wall on the way.
static func _process_climb(me: Player, delta: float) -> void:
	me._climb_timer = maxf(me._climb_timer - delta, 0.0)
	var through := 1.0 - me._climb_timer / maxf(me.climb_duration, 0.001)
	var lift := smoothstep(0.0, 0.7, through)
	var reach := smoothstep(0.35, 1.0, through)

	var here := me._climb_from.lerp(me._climb_to, reach)
	here.y = lerpf(me._climb_from.y, me._climb_to.y, lift)
	if me._vault_peak > -INF:
		# Over the top in an arc, clear of the rail, and down the far side.
		here = me._climb_from.lerp(me._climb_to, smoothstep(0.0, 1.0, through))
		var base := lerpf(me._climb_from.y, me._climb_to.y, through)
		here.y = base + maxf(me._vault_peak - base, 0.0) * sin(PI * through)
	me.global_position = here
	me.velocity = Vector3.ZERO

	if me._climb_timer <= 0.0:
		me._vault_peak = -INF
		me.state = Player.State.GROUNDED
		me._was_on_floor = true
		me._coyote_timer = me.coyote_time
		me._air_speed_cap = me.run_speed
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
static func _grip_height(me: Player) -> float:
	return me._stand_height * 0.6


## How far the body's centre line sits off the face it is on.
static func _wall_hold_distance(me: Player) -> float:
	return me._stand_radius + me.wall_gap


## Takes hold of whatever steep face is in front of the body. `direction` is the
## way to feel in, defaulting to whichever way the body is facing.
static func _try_wall_climb(me: Player, direction: Vector3 = Vector3.ZERO) -> bool:
	if not me.wall_climb_enabled or me._wall_cooldown_timer > 0.0 or me._in_dungeon():
		return false
	if me.profile != null and not me.profile.can_climb:
		return false
	if me.state != Player.State.GROUNDED and me.state != Player.State.AIRBORNE:
		return false

	var facing := direction
	if facing.is_zero_approx():
		facing = -me.global_transform.basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		return false
	facing = facing.normalized()

	var grip := PlayerClimb._feel_wall(me, facing)
	if grip.is_empty():
		return false

	# Something with its top already in reach is a mantle, and a mantle is the
	# better move: it puts the player on top rather than leaving them hanging.
	var normal: Vector3 = grip["normal"]
	var above := me.global_position + me.up_direction * (PlayerClimb._grip_height(me) + me.wall_min_face)
	if PlayerClimb._scan_wall(me, above, -normal).is_empty():
		return false

	PlayerClimb._grab_wall(me, grip["position"], normal)
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
static func _try_catch_wall(me: Player, steer: Vector3) -> bool:
	if not me.wall_climb_enabled or me._wall_cooldown_timer > 0.0 or me._in_dungeon():
		return false

	# Touching one is intent enough; otherwise the stick has to be pointing at it.
	if me.is_on_wall() and PlayerClimb._try_wall_climb(me, -me.get_wall_normal()):
		return true
	if steer.is_zero_approx():
		return false
	return PlayerClimb._try_wall_climb(me, steer)


## The face in front of the body, felt for the way a climber would: straight
## ahead first, then higher and lower, then round to either side.
##
## Scenery is not made of flat slabs. A window at chest height, a beam, the
## corner of a building — any of them would lose a single probe a wall that is
## plainly still there, and every one of them is a thing a player will try to
## climb.
static func _feel_wall(me: Player, facing: Vector3) -> Dictionary:
	for height: float in [PlayerClimb._grip_height(me), me._stand_height * 0.3, me._stand_height * 0.85]:
		var grip := PlayerClimb._scan_wall(me, me.global_position + me.up_direction * height, facing)
		if not grip.is_empty():
			return grip

	var chest := me.global_position + me.up_direction * PlayerClimb._grip_height(me)
	for sweep: float in [0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var grip := PlayerClimb._scan_wall(me, chest, facing.rotated(me.up_direction, sweep))
		if not grip.is_empty():
			return grip
	return {}


## The face in front of `origin`, or an empty dictionary if there is nothing
## there worth holding onto.
static func _scan_wall(me: Player, origin: Vector3, facing: Vector3) -> Dictionary:
	var space := me.get_world_3d().direct_space_state
	var exclude: Array[RID] = [me.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
			origin, origin + facing * me.wall_grip_reach, PlayerClimb._climb_mask(me), exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}

	var normal: Vector3 = hit["normal"]
	# Only faces too steep to walk up are worth gripping, and never a ceiling or
	# an overhang: there is nothing for the feet to push against on either.
	if absf(normal.dot(me.up_direction)) > cos(deg_to_rad(me.wall_min_angle)):
		return {}
	# The face has to be turned towards the body rather than brushed edge-on,
	# which is also what keeps the back side of a wall from being caught.
	if normal.dot(facing) > -0.35:
		return {}
	return {"position": hit["position"] as Vector3, "normal": normal}


static func _grab_wall(me: Player, point: Vector3, normal: Vector3) -> void:
	me.state = Player.State.WALLCLIMB
	# Same as a mantle: catching a face mid-plunge never lands, so it must not
	# leave the plunge (and its endless commitment) behind.
	me._plunging = false
	me._wall_point = point
	me._wall_normal = normal
	me._wall_drive = Vector2.ZERO
	me.velocity = Vector3.ZERO

	# Stand off the face properly *now* rather than easing out to it. A grab
	# usually happens with the capsule already pressed against the wall, and the
	# body is narrower than the arms are long: a few frames spent too close is a
	# few frames with the hands inside the masonry. Moved rather than teleported,
	# so backing off a wall in a narrow gap stops at whatever is behind.
	var chest := me.global_position + me.up_direction * PlayerClimb._grip_height(me)
	var gap := (me._wall_point + me._wall_normal * PlayerClimb._wall_hold_distance(me)) - chest
	me.move_and_collide(me._wall_normal * gap.dot(me._wall_normal))
	me._jump_buffer_timer = 0.0
	me._coyote_timer = 0.0
	if me.is_blocking:
		me.is_blocking = false
		me.block_changed.emit(false)
	# Nothing else the body was doing survives taking hold of a wall.
	me._set_crouching(false)
	if me.rig != null:
		me.rig.wall_climb(true)
	me.wall_grabbed.emit(normal)


static func _process_wall_climb(me: Player, delta: float) -> void:
	# Three ways off: let go and drop, push off backwards, or reach the top.
	if Input.is_action_just_pressed("crouch"):
		PlayerClimb._release_wall(me, Vector3.ZERO)
		return
	if Input.is_action_just_pressed("jump"):
		PlayerClimb._release_wall(me, me._wall_normal * me.wall_jump_back + me.up_direction * me.wall_jump_up)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Read in the face's frame, not the camera's: forward on the stick is up the
	# wall however the view happens to be pointing.
	var drive := Vector2(input.x, -input.y)
	me._wall_drive = me._wall_drive.lerp(drive, 1.0 - exp(-14.0 * delta))

	# Checked before the move, because the face runs out at exactly the moment
	# there is somewhere to stand: losing it here is arriving, not falling.
	if drive.y > 0.1:
		var landing := PlayerClimb._find_wall_top(me)
		if landing != Vector3.ZERO:
			PlayerClimb._begin_mantle(me, landing)
			return

	var held := me.global_position
	var right := me.up_direction.cross(me._wall_normal).normalized()
	var up_face := me._wall_normal.cross(right).normalized()
	me.velocity = right * drive.x * me.wall_shimmy_speed + up_face * drive.y * me.wall_climb_speed
	me.move_and_slide()

	if not PlayerClimb._hold_wall(me, delta):
		# Climbed off the end of the face with nowhere to go. Coming back to
		# where the hands still had something beats letting go of a wall that is
		# still there — a climber who runs out of holds stops, they do not drop.
		me.global_position = held
		me.velocity = Vector3.ZERO
		if not PlayerClimb._hold_wall(me, delta):
			PlayerClimb._release_wall(me, Vector3.ZERO)
			return

	# Climbing back down onto the ground steps off by itself.
	if drive.y < 0.0 and me.is_on_floor():
		PlayerClimb._release_wall(me, Vector3.ZERO)


## Re-fits the body against the face and turns it to look at it. False means the
## face is gone and there is nothing left to hang off.
static func _hold_wall(me: Player, delta: float) -> bool:
	var chest := me.global_position + me.up_direction * PlayerClimb._grip_height(me)
	var grip := PlayerClimb._feel_wall(me, -me._wall_normal)
	if grip.is_empty():
		return false

	me._wall_point = grip["position"]
	var weight := 1.0 - exp(-me.wall_settle_speed * delta)
	me._wall_normal = me._wall_normal.slerp(grip["normal"] as Vector3, weight).normalized()

	# Only the distance to the face is corrected. Sliding along it is what the
	# stick is for, and pulling the body sideways would fight it.
	var wanted := (me._wall_point + me._wall_normal * PlayerClimb._wall_hold_distance(me)) - chest
	var depth := me._wall_normal * wanted.dot(me._wall_normal)
	me.global_position += depth.limit_length(me.wall_shimmy_speed * delta + 0.02)

	me.rotation.y = lerp_angle(me.rotation.y, atan2(me._wall_normal.x, me._wall_normal.z), weight)
	return true


## Where the body would end up after pulling over the top of the face it is on,
## or ZERO while there is still wall above it.
static func _find_wall_top(me: Player) -> Vector3:
	var space := me.get_world_3d().direct_space_state
	var exclude: Array[RID] = [me.get_rid()]
	var facing := -me._wall_normal
	var head := me.global_position + me.up_direction * (me._stand_height + 0.55)

	# Still wall in front of the face? Then this is not the top of it, and any
	# floor found above would be one *inside* the building — mantling onto which
	# would post the player through the wall of the house they were climbing.
	if not PlayerClimb._scan_wall(me, me.global_position + me.up_direction * (me._stand_height * 0.95), facing).is_empty():
		return Vector3.ZERO

	# Feel down for a top face from above the head, a step in past the lip. How
	# far in has to clear the body's own standoff from the wall — probe any
	# closer and the ray comes down in front of the face it is looking for. The
	# nearest depth that works wins, so a ledge a plank wide still counts.
	for depth: float in [0.15, 0.45, 0.9]:
		var over := head + facing * (PlayerClimb._wall_hold_distance(me) + depth)
		var top := PhysicsRayQueryParameters3D.create(
				over, over - me.up_direction * 1.3, PlayerClimb._climb_mask(me), exclude)
		var hit := space.intersect_ray(top)
		if hit.is_empty():
			continue
		if (hit["normal"] as Vector3).dot(me.up_direction) < cos(me.floor_max_angle):
			continue

		var landing: Vector3 = hit["position"]
		var headroom := PhysicsRayQueryParameters3D.create(
				landing + me.up_direction * 0.05, landing + me.up_direction * me.climb_headroom,
				PlayerClimb._climb_mask(me), exclude)
		if space.intersect_ray(headroom).is_empty():
			return landing
	return Vector3.ZERO


## Lets go of the face. `impulse` is whatever the body leaves with — nothing at
## all when it simply drops, or a push off the wall when it jumps.
static func _release_wall(me: Player, impulse: Vector3) -> void:
	me.state = Player.State.AIRBORNE
	me.velocity = impulse
	me._wall_normal = Vector3.ZERO
	me._wall_drive = Vector2.ZERO
	me._wall_cooldown_timer = me.wall_regrab_delay
	me._air_speed_cap = maxf(Vector3(impulse.x, 0.0, impulse.z).length(), me.run_speed)
	if me.rig != null:
		me.rig.wall_climb(false)
	me.wall_released.emit()
	if impulse.y > 0.0:
		me._move_sound(Player.MoveSound.JUMP)  # Pushed off the face, not let go.


## Somebody else's climb, as he climbs it (the user's word, 2026-10-22: the
## other player did not see the wall climb). His own wall_climb()/climb() are
## called from his physics, which runs only on his machine; here they follow
## the replicated state, and the drive on the wall (sideways, up) is read off
## his replicated velocity in his own frame (he faces the wall).
static func _show_net_climb(me: Player) -> void:
	if me.net_state != me._net_state_shown:
		if me.net_state == Player.State.WALLCLIMB:
			me.rig.wall_climb(true)
		elif me._net_state_shown == Player.State.WALLCLIMB:
			me.rig.wall_climb(false)
		# (the pull-up comes by its own call, [method net_mantle], with the
		# take he played)
		me._net_state_shown = me.net_state
	if me.net_state == Player.State.WALLCLIMB:
		var local := me.global_basis.inverse() * me.velocity
		var drive := Vector2(local.x, local.y) / maxf(me.wall_climb_speed, 0.01)
		me.rig.climb_drive(drive.limit_length(1.0), me.velocity.length(), PlayerClimb._wall_hold_distance(me))
