class_name PlayerTarget
extends RefCounted

## The lock-on: picking, switching and keeping a target, facing it.
## Taken out of player.gd (2026-10-28) so the hero is in parts; every
## function takes the hero as `me` and works on it as it did before. [Player]
## keeps a one-line function of the same name for each one called from
## outside this file (other scripts, the rig, signals, the hero himself).

## Takes the best target in front of the camera, or lets go of the one held.
static func _toggle_lock(me: Player) -> void:
	if me.target != null:
		PlayerTarget._drop_target(me)
		return
	var found := PlayerTarget._best_target(me)
	if found == null:
		return
	PlayerTarget._hold_target(me, found)


static func _hold_target(me: Player, who: Node3D) -> void:
	me.target = who
	me._last_target_at = who.global_position
	me.target_part = TargetPoints.default_index(who)
	me._flick_up = 0.0
	PlayerTarget._show_marker(me)
	me.target_locked.emit(me.target)


static func _drop_target(me: Player) -> void:
	if me.target == null:
		return
	me.target = null
	me._flick = 0.0
	PlayerTarget._show_marker(me)
	me.target_lost.emit()


## Puts the dot on the target, building it the first time it is needed. Built
## here rather than in the scene because it belongs to the lock, not to the body
## — and because a marker with nothing to mark is a node doing nothing.
static func _show_marker(me: Player) -> void:
	if me._marker == null:
		if me.target == null:
			return
		me._marker = TargetMarker.new()
		me._marker.name = "TargetMarker"
		me.add_child(me._marker)
		me._marker.aim_at = func() -> Vector3: return PlayerTarget._aim_point(me, me.target) if me.target != null else me.global_position
	me._marker.mark(me.target, me.camera)


## Moves the lock one part up (+1) or down (-1) the creature it is on.
static func _switch_part(me: Player, step: int) -> void:
	if me.target == null:
		return
	var parts := TargetPoints.of(me.target).size()
	me.target_part = clampi(me.target_part + step, 0, parts - 1)


## Swaps to the next target to one side of the one held. Which side is the sign
## of `towards`: negative for left, positive for right.
##
## Ordered by *angle round the camera* rather than by distance, so flicking
## right takes the next one along the line of the horizon — which is what the
## player means by it and what they can see before they do it.
static func _switch_target(me: Player, towards: float) -> void:
	if me.target == null or absf(towards) < 0.01:
		return
	var eye := me.camera.global_position
	var right := me.camera.global_transform.basis.x
	var held := PlayerTarget._bearing(me.target, eye, right)

	var best: Node3D = null
	var best_gap := INF
	for node in me._foes():
		var who := node as Node3D
		if who == null or who == me.target or not PlayerTarget._targetable(me, who):
			continue
		# How far from him, not from the camera behind him (which sits a
		# spring's length back and took 4-5 m off the reach).
		if me.global_position.distance_to(who.global_position) > me.lock_range:
			continue
		# Only what lies the way the stick was pushed, and the nearest of those.
		var gap := (PlayerTarget._bearing(who, eye, right) - held) * signf(towards)
		if gap <= 0.01 or gap >= best_gap:
			continue
		best_gap = gap
		best = who
	if best != null:
		PlayerTarget._hold_target(me, best)


## How far round to the right of the camera something sits, in radians.
static func _bearing(who: Node3D, eye: Vector3, right: Vector3) -> float:
	var to_them := who.global_position - eye
	return atan2(to_them.dot(right), to_them.dot(-right.cross(Vector3.UP)))


## The enemy nearest the middle of the view, of those close enough and roughly
## in front. Angle first and distance second: what the player is looking at
## matters more than what happens to be nearest.
static func _best_target(me: Player) -> Node3D:
	var eye := me.camera.global_position
	var looking := -me.camera.global_transform.basis.z
	var widest := cos(deg_to_rad(me.lock_cone))
	var best: Node3D = null
	var best_score := -INF

	for node in me._foes():
		var who := node as Node3D
		if who == null or not PlayerTarget._targetable(me, who):
			continue
		var to_them: Vector3 = PlayerTarget._aim_point(me, who) - eye
		var seen := to_them.length()
		# Within reach of him, not of the camera a spring's length behind him:
		# measured from the camera, a creature 22 m off could not be locked.
		var range_to := me.global_position.distance_to(who.global_position)
		if range_to > me.lock_range or seen < 0.01:
			continue
		var facing := looking.dot(to_them / seen)
		if facing < widest:
			continue
		# Straight ahead beats close by, but not by so much that something on
		# the far side of the field wins for being centred.
		var score := facing - range_to / me.lock_range * 0.25
		if score > best_score:
			best_score = score
			best = who
	return best


## Whether something is worth holding on to. Anything that has died stops being
## a target the moment it does, which is what keeps the camera off a corpse.
static func _targetable(me: Player, who: Node3D) -> bool:
	if not is_instance_valid(who) or not who.is_inside_tree():
		return false
	if who.get("is_dead") == true:
		return false
	# a ghoul lying as dead among the dead ([GhoulFighter]) looks like one
	if who.get(&"playing_dead") == true:
		return false
	# a hero gone in his Vanish is not there to lock
	if who != me and who is Player and (who as Player).is_hidden():
		return false
	return true


## Where on a body the camera looks and an arrow goes: the middle of it rather
## than the floor it stands on.
static func _aim_point(me: Player, who: Node3D) -> Vector3:
	var points := TargetPoints.of(who)
	if who == me.target:
		return points[clampi(me.target_part, 0, points.size() - 1)]
	return points[TargetPoints.default_index(who)]


## Of the enemies that can be locked, the nearest to `spot`, within lock range
## of him; null if there are none.
static func _nearest_to(me: Player, spot: Vector3, hunting_only: bool = false) -> Node3D:
	var best: Node3D = null
	var closest := INF
	for node in me._foes():
		var who := node as Node3D
		if who == null or who == me.target or not PlayerTarget._targetable(me, who):
			continue
		if hunting_only and not PlayerTarget._hunting_me(me, who):
			continue
		if me.global_position.distance_to(who.global_position) > me.lock_range:
			continue
		var gap := spot.distance_squared_to(who.global_position)
		if gap < closest:
			closest = gap
			best = who
	return best


## Whether `who` is after him: roused and chasing or fighting him (a camp's
## band, a brute: its quarry him and its mode CHASE or FIGHT; a wolf: chasing
## or fighting, its quarry him). Something that keeps no such state counts.
static func _hunting_me(me: Player, who: Node3D) -> bool:
	if who is Wolf:
		var wolf := who as Wolf
		return (wolf.state == Wolf.State.CHASE or wolf.state == Wolf.State.FIGHT) and wolf._quarry() == me
	var quarry: Variant = who.get(&"_quarry")
	var mode: Variant = who.get(&"mode")
	if mode != null and (who is Fighter or who is Brute):
		return quarry == me and (int(mode) == Fighter.Mode.CHASE or int(mode) == Fighter.Mode.FIGHT)
	return true


## The arm's length: out to `camera_reach` (and `camera_reach_big` further
## while a great foe is fought), in at once to whatever is behind him, and
## back out from it at `camera_out_speed`, never a jump.
static func _tend_arm(me: Player, delta: float) -> void:
	me._big_view = move_toward(me._big_view, PlayerTarget._big_fight(me), delta * 0.8)
	var want := me.camera_reach + me.camera_reach_big * me._big_view
	var hit := me.spring_arm.get_hit_length()
	if hit < me.spring_arm.spring_length - 0.05:
		# something in the way: where it stops it, from there on out slowly
		me._arm_len = minf(me._arm_len, hit)
	me._arm_len = minf(me._arm_len + me.camera_out_speed * delta, want)
	if me._arm_len > want:
		me._arm_len = move_toward(me._arm_len, want, me.camera_out_speed * delta)
	me.spring_arm.spring_length = me._arm_len


## 0..1: how great a foe he is fighting — the one locked on by its size, or
## a boss (or one as big) roused within reach of him.
static func _big_fight(me: Player) -> float:
	if me.target != null and is_instance_valid(me.target):
		return PlayerTarget._greatness(me.target)
	if me._now() - me._big_seen_at > 0.5:
		me._big_seen_at = me._now()
		me._big_near = false
		for node in me.get_tree().get_nodes_in_group(&"enemy"):
			var foe := node as Node3D
			if foe == null or not foe.visible or foe.get(&"is_dead") == true:
				continue
			if foe.global_position.distance_squared_to(me.global_position) > 18.0 * 18.0:
				continue
			var mode: Variant = foe.get(&"mode")
			if mode != null and int(mode) != Fighter.Mode.CHASE and int(mode) != Fighter.Mode.FIGHT:
				continue
			if PlayerTarget._greatness(foe) >= 0.99:
				me._big_near = true
				break
	return 1.0 if me._big_near else 0.0


static func _greatness(foe: Node3D) -> float:
	if foe.has_meta(&"boss_name"):
		return 1.0
	return clampf((Player._body_radius(foe) - 0.55) / 0.5, 0.0, 1.0)


## Keeps the camera on the target and lets go when there is nothing left to hold.
static func _track_target(me: Player, delta: float) -> void:
	if me.target == null:
		return
	if not PlayerTarget._targetable(me, me.target):
		# Killed (or gone): straight on to whichever of the rest stood nearest
		# it, so a fight with a pack does not need the lock taken again after
		# every kill. Only if there is one in reach, and only one that is
		# after him (not something far off minding its own ground, the user's
		# word 2026-10-06); otherwise let go.
		var next := PlayerTarget._nearest_to(me, me._last_target_at, true)
		if next != null:
			PlayerTarget._hold_target(me, next)
			return
		PlayerTarget._drop_target(me)
		return
	if me.global_position.distance_to(me.target.global_position) > me.lock_break_range:
		PlayerTarget._drop_target(me)
		return
	me._last_target_at = me.target.global_position
	PlayerTarget._show_marker(me)

	# The camera is swung round rather than snapped: a lock that jumps the view
	# is a lock that loses the player.
	var to_them := PlayerTarget._aim_point(me, me.target) - me.camera_rig.global_position
	if to_them.length_squared() < 0.01:
		return
	var weight := 1.0 - exp(-me.lock_camera_speed * delta)
	me.camera_rig.rotation.y = lerp_angle(me.camera_rig.rotation.y,
			atan2(-to_them.x, -to_them.z), weight)
	# Pitch: negative puts the camera up and looks down, which is the way to
	# watch a fight. Aiming straight at the target is not enough on its own —
	# the rig already sits above it, so a pure aim is nearly level and the
	# ground between the two disappears. `lock_camera_tilt` is what lifts it.
	var flat := Vector2(to_them.x, to_them.z).length()
	var aimed := atan2(to_them.y, flat) - deg_to_rad(me.lock_camera_tilt)
	# Locked on a high point (a great foe's head) from close by, the aim
	# looks steeply up and swung the camera down under him, into the ground
	# (the user's word, 2026-10-12): never lower than `lock_camera_floor`
	# over his feet.
	var floor_up := asin(clampf((me.camera_height - me.lock_camera_floor) / maxf(me.spring_arm.spring_length, 0.5), -1.0, 1.0))
	me.spring_arm.rotation.x = lerp_angle(me.spring_arm.rotation.x,
			clampf(aimed, deg_to_rad(me.min_pitch_deg), minf(deg_to_rad(me.max_pitch_deg), floor_up)),
			weight * 0.7)


## Turns the body to face the target instead of the way it is travelling, which
## is the whole difference between strafing round something and running past it.
static func _face_target(me: Player, delta: float) -> void:
	var to_them := PlayerTarget._aim_point(me, me.target) - me.global_position
	to_them.y = 0.0
	if to_them.length_squared() < 0.0001:
		return
	me.rotation.y = lerp_angle(me.rotation.y, atan2(-to_them.x, -to_them.z),
			1.0 - exp(-me.lock_turn_speed * delta))
