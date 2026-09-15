extends SceneTree

## Headless checks for the second character: Avtandil, the bow, and the target
## lock that both characters share.
##
##     godot --path . --headless --script res://tests/archer_test.gd

const WORLD := "res://scenes/world/greybox_world.tscn"
const ARCHER := "res://scenes/player/avtandil.tres"
const KNIGHT := "res://scenes/player/tariel.tres"

var _failures := 0
var _world: Node3D
var _player: Player


func _initialize() -> void:
	# Chosen before the level is built rather than assigned to a node afterwards:
	# players are spawned into the world now, and the world asks `Game` who the
	# local one is. There is nothing to reach into until it has done that.
	var game := root.get_node_or_null("Game")
	if game != null:
		game.call("choose", &"avtandil")
	_world = load(WORLD).instantiate()
	root.add_child(_world)
	await _wait(2)
	_player = (_world as World).player()

	# The creatures wander and hunt; every check here is about the archer, so
	# the only one in the world is the one put there on purpose.
	for body in _world.find_children("*", "CharacterBody3D", true, false):
		if body != _player:
			body.queue_free()
	await _wait(2)

	await _check_character()
	await _check_lock()
	await _check_bow()
	await _check_damage()

	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


## --- The character itself -------------------------------------------------
func _check_character() -> void:
	_check("the archer spawns with his own rig", _player.rig is ArcherRig)
	_check("and carries a bow", _player.has_bow())
	_check("the bow is on the model",
			_player.rig.find_child("bow", true, false) != null)

	var knight := load(KNIGHT) as CharacterProfile
	var archer := load(ARCHER) as CharacterProfile
	_check("he runs faster than the knight", archer.run_speed > knight.run_speed,
			"%.1f vs %.1f m/s" % [archer.run_speed, knight.run_speed])
	_check("his roll carries further",
			archer.dash_speed * archer.dash_duration > knight.dash_speed * knight.dash_duration,
			"%.2f vs %.2f m" % [archer.dash_speed * archer.dash_duration,
					knight.dash_speed * knight.dash_duration])
	_check("and he crits more often", archer.crit_chance > knight.crit_chance,
			"%.0f%% vs %.0f%%" % [archer.crit_chance * 100.0, knight.crit_chance * 100.0])
	_check("the controller took his numbers",
			is_equal_approx(_player.run_speed, archer.run_speed),
			"%.1f m/s" % _player.run_speed)


## --- Target lock ----------------------------------------------------------
func _check_lock() -> void:
	_player.global_position = Vector3(6.0, 0.2, 12.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	var quarry := _wolf_at(Vector3(9.0, 0.5, 6.0))
	await _wait(20)

	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	_check("E takes the enemy in front", _player.target == quarry,
			"holding %s" % _player.target)

	await _wait(45)
	var facing := -_player.global_transform.basis.z
	var to_them := (quarry.global_position - _player.global_position)
	to_them.y = 0.0
	_check("the body turns to face it", facing.dot(to_them.normalized()) > 0.9,
			"%.2f" % facing.dot(to_them.normalized()))

	# The camera has to watch the fight from *above* it. Aimed the other way it
	# sits on the floor and looks up the target's nose, which is the one thing a
	# lock-on camera must never do.
	var eye := _player.camera.global_position
	var mark := quarry.global_position + Vector3.UP * 0.8
	_check("the camera looks down on the target, not up at it", eye.y > mark.y + 0.8,
			"camera at y=%.2f, target at y=%.2f" % [eye.y, mark.y])
	_check("and it is behind the player, not in front",
			(_player.global_position - eye).normalized().dot(to_them.normalized()) > 0.5,
			"%.2f" % (_player.global_position - eye).normalized().dot(to_them.normalized()))

	# Backing away has to keep him facing it, which is the whole point of a lock.
	var gap := _player.global_position.distance_to(quarry.global_position)
	Input.action_press("move_back")
	await _wait(30)
	Input.action_release("move_back")
	var facing_now := -_player.global_transform.basis.z
	var away := (quarry.global_position - _player.global_position)
	away.y = 0.0
	_check("backing off keeps him facing it",
			_player.global_position.distance_to(quarry.global_position) > gap + 0.5
					and facing_now.dot(away.normalized()) > 0.9,
			"gap %.1f -> %.1f, facing %.2f" % [gap,
					_player.global_position.distance_to(quarry.global_position),
					facing_now.dot(away.normalized())])

	# Running sideways is going somewhere, and a man going somewhere faces it.
	# Holding ground and backing off both keep watching the target; a run does
	# not, because a character sprinting with his head over his shoulder is not
	# running anywhere.
	#
	# A fresh wolf that has never seen anyone, because the one above has been
	# hunting for two hundred ticks and a wolf already chasing does not stop
	# because its sight is taken away. Which way "right" points relative to
	# something that has walked round behind you is not a thing to assert on.
	quarry.queue_free()
	_drop_lock()
	quarry = _wolf_at(Vector3(9.0, 0.5, 6.0))
	quarry.sight_range = 0.0
	quarry.prowl_speed = 0.0
	_player.global_position = Vector3(6.0, 0.2, 12.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(10)
	await _take_lock()
	await _wait(25)
	Input.action_press("move_right")
	await _wait(35)
	var strafed := -_player.global_transform.basis.z
	var going := _player.get_movement_direction()
	Input.action_release("move_right")
	_check("running sideways turns him the way he is going",
			strafed.dot(going) > 0.9, "%.2f" % strafed.dot(going))

	# And shooting turns him straight back onto it. This is the other half of the
	# rule: movement is the player's, but an attack goes at what is being fought,
	# so running past something and loosing is not a free miss.
	Input.action_press("move_right")
	await _wait(20)
	Input.action_press("attack")
	await _wait(6)
	Input.action_release("attack")
	await _wait(2)
	Input.action_release("move_right")
	var shot := -_player.global_transform.basis.z
	var at_it := quarry.global_position - _player.global_position
	at_it.y = 0.0
	_check("and loosing turns him back onto the target",
			shot.dot(at_it.normalized()) > 0.9, "%.2f" % shot.dot(at_it.normalized()))
	# That arrow is not part of anything counted later.
	await _wait(40)
	await _clear_arrows()

	# Back to a known spot before the next lot: the checks above walked him
	# around, and which enemy is "to the left" depends on where he is standing.
	_player.global_position = Vector3(6.0, 0.2, 12.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	quarry.global_position = Vector3(9.0, 0.5, 6.0)
	quarry.sight_range = 0.0
	quarry.prowl_speed = 0.0
	await _wait(20)
	if _player.target == null:
		Input.action_press("lock_on")
		await _wait(3)
		Input.action_release("lock_on")
	await _wait(20)

	# The mark has to say *which*, or with two wolves in front of you the lock is
	# a guess.
	var marker := _player.find_child("TargetMarker", true, false) as Node3D
	_check("the marked enemy is shown", marker != null and marker.visible)
	# On the body, not over its head: the mark is meant to be on the thing being
	# fought.
	_check("and the mark sits on the one being fought",
			marker != null
					and Vector2(marker.global_position.x - quarry.global_position.x,
							marker.global_position.z - quarry.global_position.z).length() < 0.6
					and absf(marker.global_position.y - quarry.global_position.y - 0.85) < 0.3,
			"mark at %v, target at %v" % [marker.global_position if marker != null else Vector3.ZERO,
					quarry.global_position])

	# A second one to swap to.
	var other := _wolf_at(Vector3(2.0, 0.5, 6.0))
	other.sight_range = 0.0
	other.prowl_speed = 0.0
	await _wait(20)
	_player._switch_target(-1.0)
	await _wait(10)
	_check("a flick to the side takes the next enemy along", _player.target == other,
			"holding %s" % _player.target)
	_player._switch_target(1.0)
	await _wait(10)
	_check("and a flick back takes the first one again", _player.target == quarry)
	await _wait(20)
	_check("the mark moved with it",
			Vector2(marker.global_position.x - quarry.global_position.x,
					marker.global_position.z - quarry.global_position.z).length() < 0.6)
	other.queue_free()
	await _wait(5)

	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	_check("E again lets go", _player.target == null)
	await _wait(5)
	_check("and the mark goes with it", marker == null or not marker.visible)

	# A dead target is no target.
	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	_check("it can be taken again", _player.target == quarry)
	quarry.take_hit(1000.0, quarry.global_position, Vector3.UP)
	await _wait(10)
	_check("a dead one is let go of", _player.target == null)
	quarry.queue_free()
	await _wait(5)


## --- Drawing and loosing --------------------------------------------------
func _check_bow() -> void:
	_player.global_position = Vector3(6.0, 0.2, 12.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	await _wait(20)

	var down := _bow_hand_reach()
	Input.action_press("attack")
	await _wait(6)
	_check("holding the button draws the bow", _player.is_drawing())
	var early := _player.draw_power()
	# A fifth of a second in: the bow should be out at the target already, with
	# most of the draw still to come.
	await _wait(8)
	var lifted := _bow_hand_reach()
	var quarter := _player.draw_power()
	await _wait(32)
	_check("and holding it longer draws it further", _player.draw_power() > early + 0.3,
			"%.2f -> %.2f" % [early, _player.draw_power()])

	# The bow arm leads. An archer puts the bow on the target and *then* pulls;
	# an arm that comes up in step with the string spends the whole draw being
	# winched into place and at a quarter draw is still somewhere near the hip.
	var out := _bow_hand_reach()
	_check("the bow arm is up before the string has come back",
			lifted - down > (out - down) * 0.8,
			"%.2f of %.2f m out at %.0f%% draw" % [lifted - down, out - down, quarter * 100.0])
	_check("nothing is loosed while it is held", _arrows() == 0, "%d in the air" % _arrows())

	# Drawing costs most of the run.
	var held := _player.global_position
	Input.action_press("move_forward")
	await _wait(30)
	var drawn_pace := held.distance_to(_player.global_position) / 0.5
	Input.action_release("move_forward")
	_check("drawing slows him down", drawn_pace < _player.run_speed * 0.8,
			"%.1f of %.1f m/s" % [drawn_pace, _player.run_speed])

	await _check_string()

	Input.action_release("attack")
	await _wait(2)
	_check("letting go looses the arrow", _arrows() == 1, "%d in the air" % _arrows())
	_check("and the bow is no longer drawn", not _player.is_drawing())

	# The string going is a commitment the same way a swing is. The difference is
	# that the archer chooses *when*, because the draw itself can be held — but
	# once it is away he lives with it, and cannot roll out of the recovery.
	_check("the shot commits him to it", _player.is_committed())
	var stood := _player.state
	Input.action_press("dash")
	await _wait(2)
	Input.action_release("dash")
	_check("and he cannot roll out of the recovery", _player.state == stood,
			"state %d" % _player.state)

	var flying := _first_arrow()
	var was := flying.global_position
	await _wait(6)
	_check("the arrow flies", flying == null or was.distance_to(flying.global_position) > 1.0)
	await _check_visible_shot(flying)
	await _wait(120)

	# Tapping shoots quickly, and each tap is worth less than a full draw.
	var quick := 0
	for i in 4:
		Input.action_press("attack")
		await _wait(2)
		Input.action_release("attack")
		await _wait(14)
		quick += 1
	_check("tapping gets shots away quickly", _arrows() >= 3,
			"%d arrows from %d taps" % [_arrows(), quick])
	await _wait(60)


## --- The bow itself, at full draw -----------------------------------------
##
## Called with the string held back. Both halves have to run from their own horn
## to the hand pulling them and stop there. Aimed in the wrong frame they still
## *look* like a string from some angles — they just also trail off to somewhere
## near the archer's feet, which is what this catches.
func _check_string() -> void:
	var rig := _player.rig as ArcherRig
	var hand := rig.find_child("draw", true, false) as Node3D
	var arrow := rig.find_child("bow_arrow", true, false) as Node3D
	var worst := 0.0
	var longest := 0.0
	for tag in ["bow_string_u", "bow_string_l"]:
		var half := rig.find_child(tag, true, false) as Node3D
		if half == null:
			continue
		# The cord is built hanging down its own -Y and scaled to reach, so its
		# far end is one unit down in its own frame whatever the scale is.
		var tip := half.to_global(Vector3(0.0, -1.0, 0.0))
		worst = maxf(worst, tip.distance_to(hand.global_position))
		longest = maxf(longest, half.scale.y)
	_check("both halves of the string end on the drawing hand", worst < 0.12,
			"worst end is %.2f m off" % worst)
	# A bow is about a metre and a half tip to tip, so no half of its string can
	# be much over a metre without having been pointed at something else.
	_check("and neither half runs off somewhere else", longest < 1.0,
			"longest half is %.2f m" % longest)
	_check("there is an arrow on the string", arrow != null and arrow.visible)

	# How far the string actually comes back. A bow is drawn to the face; past
	# that it is not a longer draw, it is an arm coming out of its socket.
	var bow := rig.find_child("bow", true, false) as Node3D
	var pull := bow.global_position.distance_to(hand.global_position)
	_check("the string is drawn to the face, not past it",
			pull > 0.45 and pull < 0.85, "%.2f m from grip to hand" % pull)

	# And where the elbow ends up, which is the whole of whether it looks like
	# archery. Two bones and a pinned hand leave one thing free; solved without
	# choosing it, the upper arm points at the sky and the forearm folds back
	# down it — the hand is in the right place and the arm is a chicken wing.
	var shoulder := rig.find_child("shoulder_l", true, false) as Node3D
	var elbow := rig.find_child("upperarm_l_end", true, false) as Node3D
	var here := rig.to_local(elbow.global_position)
	var upper := here - rig.to_local(shoulder.global_position)
	# On its own side of the head, not across it. Reaching past the centre line
	# puts the hand under the far cheek, and what that reads as is an arm
	# wrapped round the archer's own neck.
	var skull := rig.find_child("head", true, false) as Node3D
	var at_hand := rig.to_local(hand.global_position)
	_check("the drawing hand anchors beside the jaw, not across the neck",
			at_hand.x < rig.to_local(skull.global_position).x + 0.03,
			"hand x %.2f, head x %.2f" % [at_hand.x, rig.to_local(skull.global_position).x])

	_check("the drawing elbow is behind the hand",
			here.z < rig.to_local(hand.global_position).z - 0.15,
			"elbow %.2f, hand %.2f" % [here.z, rig.to_local(hand.global_position).z])
	_check("and its upper arm is not pointing at the sky",
			upper.y < upper.length() * 0.75,
			"%.0f%% of the way to vertical" % (upper.y / maxf(upper.length(), 0.001) * 100.0))


## --- Whether a shot can be seen -------------------------------------------
##
## The arrow is eighteen millimetres across and crosses three quarters of a metre
## a tick. On its own it is never on screen where anyone is looking, which is
## what "I cannot see the arrow" means. What makes it readable is the air it
## cuts: a line down the flight path and a wider wake around it.
##
## And what it must *not* be is bright. A pass that lit the head and flared at
## both ends read as an explosion crossing the field, so the colours are checked
## for staying under white — past one they run into the glow pass.
func _check_visible_shot(flying: Node3D) -> void:
	if flying == null or not is_instance_valid(flying):
		_check("the shot cuts a line through the air", false, "no arrow to look at")
		return
	var streak := root.find_children("ArrowTrail", "MeshInstance3D", true, false)
	var wake := root.find_children("ArrowWake", "MeshInstance3D", true, false)
	_check("the shot cuts a line through the air", not streak.is_empty())
	_check("with a wider wake around it", not wake.is_empty())
	var hottest := 0.0
	for ribbon in streak + wake:
		var tint := (ribbon as SwordTrail).tint
		hottest = maxf(hottest, maxf(tint.r, maxf(tint.g, tint.b)))
	_check("and none of it glows", hottest <= 1.0,
			"brightest channel is %.2f" % hottest)
	_check("nothing flares at either end of the flight",
			root.find_children("ShotFlash*", "", true, false).is_empty())
	# It has to turn over in the air as well: a shaft that never rolls reads as a
	# decal sliding across the screen.
	var facing := flying.global_transform.basis.x
	await _wait(4)
	if is_instance_valid(flying):
		_check("and the shaft rolls as it goes",
				facing.angle_to(flying.global_transform.basis.x) > 0.05,
				"%.2f rad in four ticks" % facing.angle_to(flying.global_transform.basis.x))


## --- What a shot is worth -------------------------------------------------
func _check_damage() -> void:
	# Shot from the same spot, at the same wolf, with only the draw changing.
	var snap := await _shoot_at(0.05)
	var full := await _shoot_at(1.2)
	_check("a snap shot lands for something", snap > 0.0, "%.0f" % snap)
	_check("a full draw lands for more than a snap shot", full > snap * 1.5,
			"%.0f vs %.0f" % [full, snap])

	var profile := load(ARCHER) as CharacterProfile
	_check("a snap shot is worth about what the profile says",
			absf(snap - profile.damage * profile.snap_share) < profile.damage * 0.6,
			"%.0f, expected near %.0f" % [snap, profile.damage * profile.snap_share])


## Shoots one wolf with the string held for `hold` seconds, and reports what the
## hit took off it. Crits are turned off so the number is the draw and nothing
## else — whether they happen at all is checked by their own odds elsewhere.
func _shoot_at(hold: float) -> float:
	var profile := _player.profile
	var was_crit := profile.crit_chance
	profile.crit_chance = 0.0

	_player.global_position = Vector3(6.0, 0.2, 14.0)
	_player.rotation.y = 0.0
	_player.camera_rig.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	var quarry := _wolf_at(Vector3(6.0, 0.5, 6.0))
	# Standing still, so what is measured is the draw and not where it wandered.
	quarry.sight_range = 0.0
	quarry.prowl_speed = 0.0
	await _wait(20)
	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	await _wait(20)

	var before := quarry.health
	Input.action_press("attack")
	await _wait(int(hold * 60.0) + 1)
	Input.action_release("attack")
	for i in 90:
		await physics_frame
		if quarry.health < before:
			break
	var taken := before - quarry.health
	quarry.queue_free()
	profile.crit_chance = was_crit
	await _wait(5)
	return taken


#region Scaffolding
## How far in front of himself the bow hand is, in metres. The bow hangs off
## `hand_r` — the model's `*_l` nodes are on its -X side, so that is the archer's
## left — and the model faces its own +Z.
func _bow_hand_reach() -> float:
	var rig := _player.rig as Node3D
	var hand := rig.find_child("hand_r", true, false) as Node3D
	return rig.to_local(hand.global_position).z if hand != null else 0.0


func _wolf_at(where: Vector3) -> Wolf:
	var wolf: Wolf = load("res://scenes/enemies/wolf.tscn").instantiate()
	_world.add_child(wolf)
	wolf.global_position = where
	return wolf


## Presses E, or lets go of it — the button is a toggle, so taking a lock means
## knowing whether one is already held.
func _take_lock() -> void:
	if _player.target != null:
		return
	Input.action_press("lock_on")
	await _wait(3)
	Input.action_release("lock_on")
	await _wait(3)


func _drop_lock() -> void:
	_player.target = null


## Clears the sky. Arrows linger where they land, and a check that counts them
## has to start from none.
func _clear_arrows() -> void:
	for arrow in root.find_children("*", "Arrow", true, false):
		arrow.queue_free()
	await _wait(3)


func _arrows() -> int:
	return _world.find_children("*", "Arrow", true, false).size() \
			+ (root.find_children("*", "Arrow", true, false).size() \
			- _world.find_children("*", "Arrow", true, false).size())


func _first_arrow() -> Node3D:
	var found := root.find_children("*", "Arrow", true, false)
	return found[0] as Node3D if not found.is_empty() else null


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
#endregion
