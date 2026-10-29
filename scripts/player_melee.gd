class_name PlayerMelee
extends RefCounted

## Fighting with the blade: strings, heavy blows, ripostes, charges, kicks, shield bashes, sure blows.
## Taken out of player.gd (2026-10-28) so the hero is in parts; every
## function takes the hero as `me` and works on it as it did before. [Player]
## keeps a one-line function of the same name for each one called from
## outside this file (other scripts, the rig, signals, the hero himself).

#region Combat
## Throws a cut, and **commits to it**.
##
## The commitment is the point. An attack you can call off the instant it starts
## going wrong costs nothing to throw, so there is no reason not to throw it at
## every opportunity, and a fight becomes a mash. Souls games answer that by
## making the swing a decision you have already made: once it is out, it plays,
## and dodging, jumping and swinging again all have to wait. What that buys is
## the other half — reading an opponent's commitment and punishing it — which is
## the whole of the fight and the whole of what will matter in PvP.
##
## A press during a swing is remembered rather than eaten, so a flurry is one
## press per cut at the player's own rhythm instead of a timing test.
static func _attack(me: Player, heavy: bool = false) -> void:
	if not PlayerMelee.is_committed(me) and me.state == Player.State.GROUNDED and PlayerMelee._try_riposte(me):
		return
	if PlayerMelee.is_committed(me):
		if heavy:
			me._heavy_buffer = me.attack_buffer_time
		else:
			me._attack_buffer = me.attack_buffer_time
		return
	if me.state == Player.State.DASHING or me.state == Player.State.DODGING:
		# pressed in the roll: its own attack the moment he is up out of it
		if not heavy:
			me._roll_cut_asked = true
		return
	if me.state != Player.State.GROUNDED and me.state != Player.State.AIRBORNE:
		return
	# The sword away: one press draws it, and the cut goes as it comes out
	# (the press is kept till the draw is done). Off the ground, or with no
	# clip for it, the sword is simply in the hand (below).
	if me._rig_drawing() or (me.state == Player.State.GROUNDED and me.weapons_stowed() and me.rig.has_method(&"draw_time") \
			and float(me.rig.call(&"draw_time")) > 0.0):
		if not me._rig_drawing():
			me._set_weapons_stowed(false)
		if heavy:
			me._heavy_buffer = me.attack_buffer_time
		else:
			me._attack_buffer = me.attack_buffer_time
		return
	var cost := me.profile.attack_stamina if me.profile != null else 16.0
	if heavy:
		cost *= me.heavy_stamina
		# a heavy blow that is a skill of its own costs a share of the whole
		# (the assassin's rush in: a third, the user's word 2026-10-05)
		var pick := PlayerMelee._heavy_blow(me)
		if pick >= 0:
			var share := float((me.rig.get(&"heavy")[pick] as Dictionary).get("stamina_share", 0.0))
			if share > 0.0:
				cost = me.max_stamina * share
	# The first cut thrown at a run is the running cut ([method _run_cut_ready]).
	var run_cut := not heavy and PlayerMelee._run_cut_ready(me)
	if run_cut:
		cost *= me.run_cut_stamina
	# straight out of a roll: the roll's attack, a quick thrust
	var roll_cut := not heavy and not run_cut and PlayerMelee._roll_cut_ready(me)
	# what he holds sets what a blow costs (the assassin: two blades dearer,
	# one cheaper, [method SkinnedRogueRig.blow_stamina])
	if not heavy and me.rig != null and me.rig.has_method(&"blow_stamina"):
		cost = float(me.rig.call(&"blow_stamina", cost))
	if not me._spend(cost):
		me._attack_buffer = 0.0
		me._heavy_buffer = 0.0
		return
	# Which heavy blow, before the rig's string is ended by it.
	var blow := PlayerMelee._heavy_blow(me) if heavy else -1
	# A heavy blow out of the guard lowers the shield for as long as it lasts.
	if heavy and me.is_blocking:
		me.is_blocking = false
		me.block_changed.emit(false)
	# Swinging a sword that is on your back takes it off your back first. There
	# is no draw clip in the library, so the blade crosses back to the hand over
	# the same beat as the wind-up rather than being drawn during it.
	me._set_weapons_stowed(false)
	# Facing is part of the commitment: a cut thrown while running sideways round
	# something goes where the fighter is *pointed*, and the fighter points at
	# what he is fighting. It snaps here rather than easing, because the swing
	# starts now and an attack that turns into the target halfway through it is a
	# cut that misses.
	# (not the knight's charge: he runs on the way he is going, `follow_push`,
	# the user's word 2026-10-06)
	var free_charge := run_cut and bool((me.rig.call(&"run_cut_spec") as Dictionary).get("follow_push", false))
	if not free_charge:
		PlayerMelee._turn_to_target(me)
	# A rig that aims its cuts ([StrikeAim]) is turned to what it is thrown at
	# and every peer is told what that is: the host's copy of the swing is the
	# one that cuts.
	if PlayerMelee._aims_strikes(me):
		var foe := PlayerMelee._strike_candidate(me)
		if foe != null and foe != me.target and not free_charge:
			var to_them := foe.global_position - me.global_position
			to_them.y = 0.0
			if to_them.length_squared() > 0.0001:
				me.rotation.y = atan2(-to_them.x, -to_them.z)
		me.net_strike_at.rpc(foe.get_path() if foe != null else NodePath())
		# (a running cut steps in on the run itself, not by a step of its own)
		var reach := 0.0 if run_cut else me.strike_step_max
		me.rig.set(&"carry_scale", 1.0)
		if blow >= 0:
			var spec: Dictionary = me.rig.get(&"heavy")[blow]
			reach = float(spec.get("step", me.strike_step_max))
			# A blow that carries him (a flip) is made to land where the thing
			# stands, not a fixed distance on past it or short of it.
			if spec.has("travel") and foe != null:
				var gap := Vector2(foe.global_position.x - me.global_position.x,
						foe.global_position.z - me.global_position.z).length() - Player._body_radius(foe) - me.strike_close
				me.rig.set(&"carry_scale", clampf(gap / float(spec["travel"]), 0.35, 1.25))
				reach = 0.0
		me._step_in(foe, reach)
	# A swing out of a run, or out of a jump, keeps the speed it was thrown at.
	# Only the cuts after it are slowed: the first one is the one the player
	# committed their momentum to, and damping it turns a charge into a shuffle.
	var airborne := not me.is_on_floor()
	me._free_swing = me._swing_chain == 0 or airborne
	me._free_ease = me.run_cut_ease if run_cut else me.free_swing_ease
	me._whiff_counts = PlayerMelee._foe_within(me, me.whiff_near)
	me._swing_t0 = me._game_t
	me._swing_chain += 1
	# A cut thrown in the air is a **plunge**, and a plunge is owed its landing:
	# whatever it passes through on the way down, it finishes in the ground.
	me._plunging = airborne
	me.attack_started.emit()
	if me.rig != null:
		# In the air the blade comes down from over the head. Nothing else reads
		# as a jumping attack: a horizontal cut thrown off a jump is a man
		# swinging at the air he is passing through.
		var style := CharacterRig.AttackStyle.OVERHEAD if airborne else -1
		if blow >= 0 and not airborne:
			style = SkinnedRig.HEAVY + blow
		elif run_cut:
			style = SkinnedRig.RUN_CUT
		elif roll_cut:
			style = SkinnedRig.ROLL_CUT
		me.net_attack.rpc(style)
		if blow >= 0 and not airborne:
			PlayerMelee._heavy_begun(me, blow)
		if run_cut:
			PlayerMelee._mark_sure(me, PlayerMelee._sure_pick(me))
		elif me._sure_foe != null:
			me.net_sure_at.rpc(NodePath())
		PlayerMelee._commit(me, me.rig.swing_time())
		me._ease_delay = 0.0
		if blow >= 0 and not airborne:
			me._creep_in(me.rig.get(&"heavy")[blow])
		if run_cut and me.rig.has_method(&"holding_cut"):
			if bool(me.rig.call(&"holding_cut")):
				me._cut_charging = true
				me._charge_skill = false
				me._charge_spec = me.rig.call(&"run_cut_spec")
				me._charge_t0 = me._game_t
				me._charge_dir = Vector3(me.velocity.x, 0.0, me.velocity.z).normalized()
				me._charge_foe = PlayerMelee._charge_target(me)
				if bool(me._charge_spec.get("locked_only", false)):
					# (the knight's charge runs at what he is locked on, or
					# where he is pushed)
					me._charge_foe = me.target if me.target != null and me._targetable(me.target) else null
				PlayerMelee._commit(me, float(me._charge_spec.get("hold_max", me.run_cut_hold_max)) + 2.0)
			else:
				me._ease_delay = float(me.rig.call(&"time_to_cut"))
	me._attack_buffer = 0.0
	me._heavy_buffer = 0.0


## A second attack button for a hero with no shield to raise (the assassin):
## his heavy blows ([member SkinnedRig.heavy]).
## A shield in his hand to raise: a hero who blocks, with a shield in his
## off hand (his look's; [method SkinnedRig.holds_shield]). Without one the
## block button raises nothing (no empty arm held up).
static func _shield_in_hand(me: Player) -> bool:
	if me.profile != null and not me.profile.can_block:
		return false
	return me.rig == null or not me.rig.has_method(&"holds_shield") or bool(me.rig.call(&"holds_shield"))


## A hero who would block but has no shield in hand, with more than one
## string (Tariel): the block button throws the other string, the one F6
## would pick (the user's word, 2026-10-04).
static func _other_string_ready(me: Player) -> bool:
	# the knight, who never raises a guard: both buttons cut ([GreatSword])
	if PlayerMelee._block_throws_string(me):
		return true
	return me.profile != null and me.profile.can_block and not me.has_bow() and not PlayerMelee._shield_in_hand(me) \
			and me.rig != null and me.rig.has_method(&"string_count") and int(me.rig.call(&"string_count")) > 1


## A hero with no guard whose block button is a second string of cuts, not
## a heavy blow (the knight's great sword, the user's word 2026-10-06).
static func _block_throws_string(me: Player) -> bool:
	return me.rig != null and not me.has_bow() and me.rig.has_method(&"block_throws_string") \
			and bool(me.rig.call(&"block_throws_string"))


## A cut from the string F6 picked (`other` false) or the other one, the
## string put on first on every peer.
static func _string_attack(me: Player, other: bool) -> void:
	# kept for the press held over (a draw first): it is still this string's
	me._buffer_other = other
	if not PlayerMelee.is_committed(me) and me.rig != null and me.rig.has_method(&"wear_other_string"):
		me.net_wear_string.rpc(other)
	PlayerMelee._attack(me)


static func _has_heavy(me: Player) -> bool:
	if me.profile == null or me.profile.can_block or me.has_bow() or me.rig == null or PlayerMelee._block_throws_string(me):
		return false
	var blows: Variant = me.rig.get(&"heavy")
	return blows is Array and not (blows as Array).is_empty()


## A hero with a shield throws his heavy blow out of his guard: the attack
## button with the shield up (the knight's leaping slam).
static func _guard_heavy(me: Player) -> bool:
	if me.profile == null or not me.profile.can_block or me.has_bow() or me.rig == null:
		return false
	var blows: Variant = me.rig.get(&"heavy")
	return blows is Array and not (blows as Array).is_empty()


## A heavy blow's blade has gone into the ground (see [signal SkinnedRig.slammed]):
## dust thrown up round it, a wave of broken earth running on the way he faces,
## the thump of it and the ground shaking under whoever is near. Every peer
## plays its own copy of the blow, so every peer sees and hears this.
static func _on_slammed(me: Player, at: Vector3, heft: float) -> void:
	var world := Blood.world_of(me)
	if world == null:
		return
	var ahead := -me.global_basis.z
	ahead.y = 0.0
	DustRing.burst(world, at, 1.1 + 0.2 * heft)
	if me.rig == null or me.rig.get(&"slam_spikes") != false:
		GroundFx.eruption(world, at, 0.8)
		GroundFx.wave(world, at, ahead.normalized(), 4.5, false, 0.9)
	ImpactFx.thud(me, at, true)
	WindBlast.shake(me, 0.18 * clampf(heft / 2.0, 1.0, 1.4), 0.4, 14.0)


## The button his heavy blow is on: the block button for a hero with no
## shield, the attack button for one who throws it out of his guard.
static func _heavy_button_down(me: Player) -> bool:
	if PlayerMelee._has_heavy(me):
		return Input.is_action_pressed("block")
	if PlayerMelee._guard_heavy(me):
		return Input.is_action_pressed("attack")
	return false


## A heavy blow just thrown: a counter if it comes out of a guard that has just
## held, and gathered while its button stays down.
static func _heavy_begun(me: Player, blow: int) -> void:
	if me.rig == null or not me.rig.has_method(&"charge_heavy"):
		return
	if PlayerMelee._guard_heavy(me) and me._now() - me._blocked_at <= me.guard_counter_window:
		me._blocked_at = -100.0
		me.counters_thrown += 1
		me.net_guard_counter.rpc(me.guard_counter_weight)
	if me._forced_heavy >= 0 or blow < 0 or not PlayerMelee._heavy_button_down(me):
		return
	var at := float(me.rig.call(&"heavy_charge_point"))
	if at <= 0.0:
		return
	me._hcharging = true
	me._hcharge_from = -1.0
	me._hcharge_serial = int(me.rig.get(&"attack_serial"))
	me.net_charge_heavy.rpc(at)


static func _tick_heavy_charge(me: Player, delta: float) -> void:
	if not me._hcharging:
		return
	if me.rig == null or int(me.rig.get(&"attack_serial")) != me._hcharge_serial or me.is_dead:
		# struck out of it, or something else begun: nothing to let go
		me._hcharging = false
		me.net_heavy_gather.rpc(false, 0.0)
		return
	var held := bool(me.rig.call(&"heavy_charge_held"))
	if held:
		if me._hcharge_from < 0.0:
			me._hcharge_from = me._game_t
			me.net_heavy_gather.rpc(true, 0.0)
		# the swing waits for him: so does his commitment to it
		me._commit_timer += delta
	var full := held and me._game_t - me._hcharge_from >= me.heavy_charge_max
	if PlayerMelee._heavy_button_down(me) and not full and me.state == Player.State.GROUNDED:
		return
	me._hcharging = false
	var share := 0.0
	if me._hcharge_from >= 0.0:
		share = clampf((me._game_t - me._hcharge_from) / me.heavy_charge_max, 0.0, 1.0)
		me.charges_let_go += 1
		me.last_charge = share
	me.net_let_heavy_go.rpc(1.0 + me.heavy_charge_bonus * share, share)


## A slide to throw off a sprint: this look has one ([method
## SkinnedRig.run_slide_index]) and its clip, and he has the ground under him.
static func _run_slide_ready(me: Player) -> bool:
	return not me.has_bow() and me.state == Player.State.GROUNDED and PlayerMelee._run_slide_slot(me) >= 0


## Where the sprint's slide is in the rig's heavy blows, or -1.
static func _run_slide_slot(me: Player) -> int:
	if me.rig == null or not me.rig.has_method(&"run_slide_index"):
		return -1
	return int(me.rig.call(&"run_slide_index"))


## Which heavy blow the string has come to: out of nothing a lunge (or, at a
## run, the flying flip); early in the string the spinning leap; later the
## three great cuts; at its end the whirling combo.
static func _heavy_blow(me: Player) -> int:
	if me._forced_heavy >= 0:
		return me._forced_heavy
	var count := (me.rig.get(&"heavy") as Array).size()
	# the sprint's slide, kept last, is never one the string comes to
	if PlayerMelee._run_slide_slot(me) >= 0:
		count -= 1
	var at: int = int(me.rig.call(&"flurry_position")) if me.rig.has_method(&"flurry_position") else -1
	var pace := Vector2(me.velocity.x, me.velocity.z).length()
	var pick := 0
	if at < 0:
		pick = 4 if pace > me.run_speed * 0.7 else 0
	elif at <= 1:
		pick = 1
	elif at <= 3:
		pick = 2
	else:
		pick = 3
	return mini(pick, count - 1)


static func _staggers_only(me: Player, blows: int) -> bool:
	return blows <= 1 and Player.STAGGERS_ONLY.has(me._blow_name) and not me._blow_held


## The big one down on its knee in reach and in front of it, if any.
static func _riposte_target(me: Player) -> Node3D:
	if me.has_bow() or me.weapons_stowed():
		return null
	for node in me.get_tree().get_nodes_in_group(&"enemy"):
		var b := node as PackBrute
		if b == null or not b.crit_open():
			continue
		var to := me.global_position - b.global_position
		to.y = 0.0
		if to.length() > me.crit_reach * b.visual_scale / 1.6:
			continue
		if to.length_squared() > 0.01 and b._forward().angle_to(to.normalized()) > deg_to_rad(80.0):
			continue
		return b
	return null


## The attack, on a big one down on its knee before him: the critical.
static func _try_riposte(me: Player) -> bool:
	var b := PlayerMelee._riposte_target(me)
	if b == null or me.rig == null or not me.rig.has_method(&"riposte"):
		return false
	me._crit_on = b
	me._crit_left = me.crit_time
	me._crit_struck = false
	me._crit_from = me.global_position
	me.is_invulnerable = true
	me._attack_buffer = 0.0
	me._heavy_buffer = 0.0
	PlayerMelee._commit(me, me.crit_time)
	me.velocity = Vector3.ZERO
	me.net_riposte.rpc(me.crit_time)
	return true


## Through the critical: carried before it and turned to it over the first
## fifth, held there; the blade in at `crit_hit_at`.
static func _process_riposte(me: Player, delta: float) -> void:
	me._crit_left -= delta
	var b: PackBrute = me._crit_on as PackBrute if is_instance_valid(me._crit_on) else null
	me.velocity = Vector3.ZERO
	if b != null and is_instance_valid(b):
		var spot: Vector3 = b.crit_spot()
		var u := clampf((me.crit_time - me._crit_left) / (me.crit_time * 0.2), 0.0, 1.0)
		var at := me._crit_from.lerp(spot, u * u * (3.0 - 2.0 * u))
		me.global_position = Vector3(at.x, me.global_position.y, at.z)
		var to := b.global_position - me.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			me.rotation.y = lerp_angle(me.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-18.0 * delta))
		if not me._crit_struck and me.crit_time - me._crit_left >= me.crit_time * me.crit_hit_at:
			me._crit_struck = true
			me.crits_dealt += 1
			if me.multiplayer.has_multiplayer_peer() and not me.multiplayer.is_server():
				me.net_riposte_hit.rpc_id(1, b.get_path())
			else:
				me.net_riposte_hit(b.get_path())
			if me.camera != null and me.camera.current:
				ImpactFx.knock(me.camera, (b.global_position - me.global_position).normalized(), 0.12, 0.14, 0.45)
	if me._crit_left <= 0.0:
		me._crit_left = 0.0
		me._crit_on = null
		me.is_invulnerable = false


## Holds everything else off for `seconds`. Zero or a shorter time than is
## already left never shortens a commitment already running.
static func _commit(me: Player, seconds: float) -> void:
	if not me.attacks_commit:
		return
	me._commit_timer = maxf(me._commit_timer, seconds)


## True while an attack is playing out and nothing else may be started.
static func is_committed(me: Player) -> bool:
	return me._commit_timer > 0.0


## The end of a plunge: the blade goes into the ground and the man behind it
## has to get it back out.
##
## This is what the move is **paid for with**. A jumping attack that ends with
## the character back on his feet and ready costs nothing, so there would be no
## reason to throw anything else — and there would be nothing for an opponent to
## punish, which is the half that matters once there are two players. Burying
## the sword and pulling it out is the price, and it is the same price every
## Souls-like charges for the same move.
##
## Everything stops: the run, the input, and any way out of it, for
## `plunge_recovery`. The rig does the standing back up.
static func _plant_blade(me: Player) -> void:
	me._plunging = false
	me.velocity.x = 0.0
	me.velocity.z = 0.0
	PlayerMelee._commit(me, me.plunge_recovery)
	if me.rig != null:
		me.rig.plunge(me.plunge_recovery)
	# Where the blade went in: in front of the feet, which is where the arm put
	# it. Dust rather than a flash — a sword going into dirt throws dirt.
	var at := me.global_position - me.global_transform.basis.z * me.plunge_reach
	DustRing.burst(Blood.world_of(me), at, me.plunge_dust)
	me.blade_planted.emit(at)


## Puts the body on the target at once, without easing. Nothing to do when there
## is nothing being fought: a free swing goes where the fighter already faces.
static func _turn_to_target(me: Player) -> void:
	if me.target == null or not me._targetable(me.target):
		return
	var to_them := me._aim_point(me.target) - me.global_position
	to_them.y = 0.0
	if to_them.length_squared() > 0.0001:
		me.rotation.y = atan2(-to_them.x, -to_them.z)
#endregion


## What a cut that does not miss is thrown at: the locked target, else the
## nearest thing to fight ahead of the way he goes.
static func _sure_pick(me: Player) -> Node3D:
	if me.target != null and me._targetable(me.target):
		return me.target
	return PlayerMelee._charge_target(me)


## The swing just thrown does not miss `foe` (every peer is told); `margin`,
## if given, its reach past the blade's own instead of `sure_reach_margin`.
static func _mark_sure(me: Player, foe: Node3D, margin: float = -1.0) -> void:
	me.net_sure_at.rpc(foe.get_path() if foe != null else NodePath(), margin)


## The edge of his blade as `who` is to take it (what the creatures read,
## each for itself): the blade's own, or — a cut that does not miss, at what
## it was thrown at, while it cuts — that edge moved onto it, through where a
## cut is aimed at it ([method strike_point]).
static func cutting_edge_for(me: Player, who: Node3D) -> PackedVector3Array:
	var edge: PackedVector3Array = me.rig.get_cutting_edge() if me.rig != null else PackedVector3Array()
	if edge.is_empty() or who == null or who != me._sure_foe or not PlayerMelee.sure_holds(me, who, edge):
		return edge
	# Onto the line up its middle, at the blade's own height as near as it may
	# be: between a quarter of the way up to where a cut is aimed at it and
	# there (over a wolf, down to its back; under a tall orc's chest, up to it).
	var foot := who.global_position
	var top := maxf(PlayerMelee.strike_point(who).y, foot.y + 0.3)
	var axis := Geometry3D.get_closest_points_between_segments(edge[0], edge[1],
			foot, Vector3(foot.x, top, foot.z))
	var near: Vector3 = axis[0]
	var onto := Vector3(foot.x, clampf(near.y, lerpf(foot.y, top, 0.25), top), foot.z)
	var shift := onto - near
	return PackedVector3Array([edge[0] + shift, edge[1] + shift])


## Whether the cut in hand, its edge at `edge`, cannot miss `who` now (see
## `sure_cone`).
static func sure_holds(me: Player, who: Node3D, edge: PackedVector3Array) -> bool:
	if who != me._sure_foe or me.rig == null or int(me.rig.get(&"attack_serial")) != me._sure_serial:
		return false
	if not me._targetable(who) or (who.has_method(&"is_evading") and bool(who.call(&"is_evading"))):
		return false
	if absf(who.global_position.y - me.global_position.y) > me.sure_rise:
		return false
	var to := who.global_position - me.global_position
	to.y = 0.0
	var d := to.length()
	var r := PlayerMelee._blade_radius(who)
	# (how far ahead of him the blade is: a blade drawn back behind him
	# reaches nothing in front)
	var ahead := -me.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var reach := 0.0
	for p in edge:
		reach = maxf(reach, (p - me.global_position).dot(ahead))
	if d - r > reach + (me._sure_margin if me._sure_margin >= 0.0 else me.sure_reach_margin):
		return false
	if d < maxf(r, 0.01):
		return true
	var facing := -me.global_basis.z
	facing.y = 0.0
	facing = facing.normalized()
	if facing.dot(to) < 0.0:
		return false
	var off := rad_to_deg(acos(clampf(facing.dot(to / d), -1.0, 1.0)))
	var side := absf(facing.cross(to).y)
	return off <= me.sure_cone or side <= r * me.sure_side


## Until a cut that does not miss starts cutting, he turns after what it is
## thrown at (the owner's; the turn goes out with the body).
static func _track_sure(me: Player, delta: float) -> void:
	if me._sure_foe == null or not is_instance_valid(me._sure_foe) or me.rig == null or not me._targetable(me._sure_foe):
		return
	if int(me.rig.get(&"attack_serial")) != me._sure_serial or not PlayerMelee.is_committed(me) or me._shade_phase == 1:
		return
	if not me.rig.has_method(&"time_to_cut"):
		return
	if not (bool(me.rig.call(&"holding_cut")) or float(me.rig.call(&"time_to_cut")) > 0.0):
		return
	if me._sure_foe.has_method(&"is_evading") and bool(me._sure_foe.call(&"is_evading")):
		return
	var to := me._sure_foe.global_position - me.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	var facing := -me.global_basis.z
	facing.y = 0.0
	if facing.normalized().dot(to.normalized()) < cos(deg_to_rad(me.sure_follow_cone)):
		return
	me.rotation.y = lerp_angle(me.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-me.sure_turn_speed * delta))


## How wide `who` is to a blade: what the creature's own blade test reads
## (a [Fighter]'s radius is drawn at its size, the others' as it is).
static func _blade_radius(who: Node3D) -> float:
	var r: Variant = who.get(&"body_radius")
	if r == null:
		return 0.45
	if who is Fighter:
		var s: Variant = who.get(&"visual_scale")
		return float(r) * maxf(float(s) if s != null else 1.0, 0.01)
	return float(r)
#endregion


## Anything to fight within `reach` metres.
static func _foe_within(me: Player, reach: float) -> bool:
	for node in me.get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who != null and me._targetable(who) and who.global_position.distance_to(me.global_position) <= reach:
			return true
	return false


## What a wound-up running cut runs at: the locked target, else the nearest
## thing to fight ahead of the way he is going within `run_cut_seek`.
static func _charge_target(me: Player, seek: float = -1.0) -> Node3D:
	if seek < 0.0:
		seek = me.run_cut_seek
	if me.target != null and me._targetable(me.target):
		return me.target
	var ahead := me.get_movement_direction()
	if ahead.is_zero_approx():
		ahead = -me.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var widest := cos(deg_to_rad(me.run_cut_seek_cone))
	var best: Node3D = null
	var best_d := INF
	for node in me.get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or not me._targetable(who):
			continue
		var to := who.global_position - me.global_position
		to.y = 0.0
		var d := to.length()
		if d > seek or d < 0.01 or ahead.dot(to / d) < widest:
			continue
		if d < best_d:
			best_d = d
			best = who
	return best


static func _charge_aim(me: Player, direction: Vector3) -> Vector3:
	if bool(me._charge_spec.get("follow_push", false)):
		# the knight's charge: on the way he was running, turned after the
		# push no faster than `CHARGE_TURN` (locked on, the push is towards
		# what he is locked on: he comes round to it in an arc, not drawn
		# straight at it, the user's word 2026-10-06)
		if me._charge_dir.is_zero_approx():
			me._charge_dir = -me.global_basis.z
			me._charge_dir.y = 0.0
			me._charge_dir = me._charge_dir.normalized()
		var want := direction
		var rate := Player.CHARGE_TURN
		# Running at about what he is locked on (not off the other way): drawn
		# on to it, so he does not go by it a step aside (the user's word).
		if me._charge_foe != null and is_instance_valid(me._charge_foe) and me._targetable(me._charge_foe):
			var to := me._charge_foe.global_position - me.global_position
			to.y = 0.0
			if to.length() > 0.5 and absf(me._charge_dir.angle_to(to.normalized())) < deg_to_rad(Player.CHARGE_ASSIST_CONE):
				want = to.normalized()
				rate = Player.CHARGE_ASSIST_TURN
		if not want.is_zero_approx():
			var turn := me._charge_dir.signed_angle_to(want, Vector3.UP)
			var most := rate * me.get_physics_process_delta_time()
			me._charge_dir = me._charge_dir.rotated(Vector3.UP, clampf(turn, -most, most)).normalized()
		return me._charge_dir
	if me._charge_foe != null and is_instance_valid(me._charge_foe) and me._targetable(me._charge_foe):
		var to := me._charge_foe.global_position - me.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			return to.normalized()
	if not direction.is_zero_approx():
		return direction
	if me._charge_skill:
		var ahead := -me.global_basis.z
		ahead.y = 0.0
		return ahead.normalized()
	return Vector3.ZERO


## The wound-up running cut, let go when he is near enough what he runs at,
## when he stops pushing with nothing to run at, at a second press, or when
## it has been held `run_cut_hold_max`. Broken off by anything that takes the
## clip off him (a blow).
static func _tick_charge(me: Player) -> void:
	if not me._cut_charging:
		return
	if me.rig == null or not bool(me.rig.call(&"holding_cut")):
		me._cut_charging = false
		return
	var held := me._game_t - me._charge_t0
	var spec := me._charge_spec
	var go := held >= float(spec.get("hold_max", me.run_cut_hold_max))
	var leap := false
	var lp: Dictionary = spec.get("leap", {})
	if me._charge_foe != null and is_instance_valid(me._charge_foe) and me._targetable(me._charge_foe):
		var to := me._charge_foe.global_position - me.global_position
		to.y = 0.0
		# (its body as a blade finds it: its own radius, not the drawn size)
		var r: Variant = me._charge_foe.get(&"body_radius")
		var radius := float(r) if r != null else 0.45
		# near enough, the blow goes by itself (the knight's: a leap only
		# on the jump button, `leap_on_jump`)
		var on_jump := bool(spec.get("leap_on_jump", false))
		var gap := float(spec.get("strike_gap", 0.9)) if on_jump else float(lp.get("gap", spec.get("strike_gap", 0.9)))
		var ahead := -me.global_basis.z
		ahead.y = 0.0
		var facing := to.length() < 0.01 \
				or ahead.normalized().dot(to.normalized()) > cos(deg_to_rad(Player.CHARGE_STRIKE_CONE))
		if to.length() - radius - 0.4 <= gap and (facing or not bool(spec.get("follow_push", false))):
			go = true
			leap = not lp.is_empty() and not on_jump
	elif me._charge_skill:
		# Nothing to run at: a few strides the way he faces, and the cut.
		go = go or held >= float(spec.get("blind_hold", 0.45))
	elif held >= 0.25 and me.get_movement_direction().is_zero_approx() and not bool(spec.get("hold_button", false)):
		go = true
	if bool(spec.get("hold_button", false)) and held >= 0.1 and not go:
		# The knight's charge: held as long as the attack button and the
		# push are; letting go of either lets the blow go where he is.
		go = not Input.is_action_pressed("attack") or me.get_movement_direction().is_zero_approx()
	if me._attack_buffer > 0.0 and held >= 0.12:
		me._attack_buffer = 0.0
		go = true
	if bool(spec.get("leap_on_jump", false)) and not lp.is_empty() and Input.is_action_just_pressed("jump"):
		# The knight's charge, the jump pressed: he leaps and brings the
		# blade down from the air (the user's word, 2026-10-06)
		go = true
		leap = true
	if go:
		me._cut_charging = false
		me.net_release_cut.rpc(leap)
		if leap and me.is_on_floor():
			# off the ground for as long as the leap takes to come down on it
			var air := clampf(float(me.rig.call(&"time_to_slam")), 0.2, 1.0)
			me.velocity.y = me._gravity * air * 0.5
			# on, not up: a lunge over the ground more than a hop
			var on := Vector3(me.velocity.x, 0.0, me.velocity.z)
			if on.length() > 0.5:
				var lunge := on.normalized() * float(spec.get("leap", {}).get("lunge", 0.0))
				me.velocity.x += lunge.x
				me.velocity.z += lunge.z
				me._air_speed_cap = maxf(me._air_speed_cap, Vector3(me.velocity.x, 0.0, me.velocity.z).length())
			me._quiet_landing_until = me._now() + air + 0.3
		me._commit_timer = 0.0
		PlayerMelee._commit(me, float(me.rig.get(&"_swing_commit")))
		me._swing_t0 = me._game_t
		# (let go where he is: the run given up at once, a step at most;
		# a leap carries the run into it)
		me._ease_delay = 0.0 if bool(spec.get("stop_on_release", false)) and not leap \
				else float(me.rig.call(&"time_to_cut"))


## A cut out of a run: on his feet, the first of a string, at a run, with the
## shield down, and a rig with a running cut.
## Straight out of an evade (within `roll_attack_window` of its end), on his
## feet, with the roll's attack to throw.
static func _roll_cut_ready(me: Player) -> bool:
	if me.state != Player.State.GROUNDED or not me.is_on_floor() or me.is_blocking or me._swing_chain != 0:
		return false
	if me._now() - me._evade_ended_at > me.roll_attack_window:
		return false
	return me.rig != null and me.rig.has_method(&"has_cut") and bool(me.rig.call(&"has_cut", "roll_attack"))


## Whether `from`'s blow now is low enough to pass under a jump: its weapon
## (where the creature can say, [method weapon_low]) under `jump_clear_low`
## over his feet.
static func _low_blow(me: Player, from: Node3D) -> bool:
	if not from.has_method(&"weapon_tip_now"):
		return false
	var tip: Vector3 = from.call(&"weapon_tip_now")
	return tip.y - me.global_position.y < me.jump_clear_low and tip.y < me.global_position.y + 0.2


static func _run_cut_ready(me: Player) -> bool:
	if me.state != Player.State.GROUNDED or not me.is_on_floor() or me._swing_chain != 0 or me.is_blocking:
		return false
	if me.rig == null or not me.rig.has_method(&"has_run_cut") or not bool(me.rig.call(&"has_run_cut")):
		return false
	# (the knight's charge: only at a sprint, Shift held)
	var spec: Variant = me.rig.call(&"run_cut_spec") if me.rig.has_method(&"run_cut_spec") else {}
	if spec is Dictionary and bool((spec as Dictionary).get("sprint_only", false)) and not me.sprinting:
		return false
	# (and only off the attack button: the block button's string is its own)
	if spec is Dictionary and bool((spec as Dictionary).get("hold_button", false)) and me._buffer_other:
		return false
	return Vector2(me.velocity.x, me.velocity.z).length() > me.run_speed * me.run_cut_pace


## A hero with no shield and a bow, on his feet, a rig that kicks.
static func _can_kick(me: Player) -> bool:
	if me.profile == null or me.profile.can_block or not me.has_bow() or me.unarmed:
		return false
	if me.state != Player.State.GROUNDED or not me.is_on_floor() or me._kick_cool > 0.0 or PlayerMelee.is_committed(me):
		return false
	return me.rig != null and me.rig.has_method(&"kick")


## He turns to what he is locked on (or what is in front) and kicks it away:
## a draw in hand is let go of, unshot.
static func _kick(me: Player) -> void:
	if not me._spend(me.kick_stamina):
		return
	me._drawing = false
	me._draw_timer = 0.0
	me._set_weapons_stowed(false)
	var foe := me.target if me.target != null and me._targetable(me.target) else PlayerMelee._strike_candidate(me)
	var aim := me.get_movement_direction()
	if foe != null:
		aim = foe.global_position - me.global_position
	aim.y = 0.0
	if aim.length_squared() > 0.0001:
		me.rotation.y = atan2(-aim.x, -aim.z)
	var dir := -me.global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	me._kick_cool = me.kick_cooldown
	var secs := float(me.rig.call(&"kick_length", me.kick_rate, me.kick_from, me.kick_to))
	PlayerMelee._commit(me, secs)
	me.attack_started.emit()
	me.net_kick.rpc(dir)


## The foot out: the host takes what is in front of it.
static func _tick_kick(me: Player, delta: float) -> void:
	me._kick_cool = maxf(me._kick_cool - delta, 0.0)
	if me._kick_wait < 0.0:
		return
	me._kick_wait -= delta
	if me._kick_wait >= 0.0:
		return
	if not me._decides_here() or me.is_dead:
		return
	var widest := cos(deg_to_rad(me.kick_cone))
	for node in me.get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or not me._targetable(who):
			continue
		var to := who.global_position - me.global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d - Player._body_radius(who) > me.kick_reach or me._kick_dir.dot(to / d) < widest:
			continue
		var at := PlayerMelee.strike_point(who) - to / d * Player._body_radius(who)
		at.y = minf(at.y, me.global_position.y + 1.2)
		var worth := PlayerMelee.cut_worth(me)
		if who.has_method(&"take_hit"):
			who.call(&"take_hit", float(worth[0]) * me.kick_damage, at, me._kick_dir, false, false, me)
		if who.has_method(&"react"):
			var taken: Variant = who.get(&"shove_taken")
			var push := me.kick_push
			if taken is float and float(taken) > 0.01:
				push = me.kick_throw * 4.0 / float(taken)
			who.call(&"react", &"knock", me, me._kick_dir * push)
		me.net_kick_landed.rpc(who.get_path(), at)


## The shield up, on his feet, and a rig that charges with it.
static func _can_bash(me: Player) -> bool:
	if not me.is_blocking or me.state != Player.State.GROUNDED or not me.is_on_floor():
		return false
	return me.rig != null and me.rig.has_method(&"can_shield_bash") and bool(me.rig.call(&"can_shield_bash"))


## The charge behind the shield: he turns to what is in front (or what he is
## locked on) and drives in, the guard coming down for it.
static func _shield_bash(me: Player) -> void:
	if me._dash_cooldown_timer > 0.0:
		return
	if not me._spend((me.profile.roll_stamina if me.profile != null else 20.0) * me.bash_stamina):
		return
	me.is_blocking = false
	me.block_changed.emit(false)
	me._set_weapons_stowed(false)
	var foe := me.target if me.target != null and me._targetable(me.target) else PlayerMelee._strike_candidate(me)
	var aim := me.get_movement_direction()
	if foe != null:
		aim = foe.global_position - me.global_position
	aim.y = 0.0
	if aim.length_squared() > 0.0001:
		me.rotation.y = atan2(-aim.x, -aim.z)
	var dir := -me.global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	me._step_velocity = dir * me.bash_speed
	me._step_left = me.bash_travel
	me._free_swing = true
	me._swing_chain = 0
	me._dash_cooldown_timer = me.dash_cooldown + me.bash_time
	PlayerMelee._commit(me, me.bash_time)
	me.attack_started.emit()
	me.net_shield_bash.rpc(dir)


## The charge going: the host looks for what is in front of the shield.
static func _tick_bash(me: Player, delta: float) -> void:
	if me._bash_left <= 0.0:
		return
	me._bash_left -= delta
	if not me._decides_here() or me.is_dead:
		return
	var widest := cos(deg_to_rad(me.bash_cone))
	for node in me.get_tree().get_nodes_in_group("enemy"):
		var who := node as Node3D
		if who == null or me._bash_struck.has(who) or not me._targetable(who):
			continue
		var to := who.global_position - me.global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d - Player._body_radius(who) - 0.4 > me.bash_reach or me._bash_dir.dot(to / d) < widest:
			continue
		me._bash_struck.append(who)
		var at := PlayerMelee.strike_point(who) - to / d * Player._body_radius(who)
		var worth := PlayerMelee.cut_worth(me)
		if who.has_method(&"take_hit"):
			who.call(&"take_hit", float(worth[0]) * me.bash_damage, at, me._bash_dir, false, false, me)
		if who.has_method(&"react"):
			who.call(&"react", &"knock", me, me._bash_dir * me.bash_push)
		me.net_bash_landed.rpc(who.get_path(), at)
		me.bashed.emit(who)


## A cut of the string past its cut with nothing landed: it drags on
## (`whiff_recovery`), and the evade may not take him out of it till then.
static func _judge_whiff(me: Player) -> void:
	if me.rig == null or me._swing_serial0 < 0 or me._whiff_judged == me._swing_serial0 or me._plunging:
		return
	if not me.rig.has_method(&"in_recovery") or not me.rig.has_method(&"current_swing"):
		return
	if StringName(me.rig.call(&"current_swing")) == &"" or bool(me.rig.call(&"is_heavy")) \
			or not bool(me.rig.call(&"in_recovery")):
		return
	me._whiff_judged = me._swing_serial0
	if me._landed_serial >= me._swing_serial0 or not me._whiff_counts:
		return
	me._whiff_until = me._now() + me.whiff_recovery
	if me.attacks_commit:
		me._commit_timer += me.whiff_recovery
	if me.rig.has_method(&"overreach"):
		me.rig.call(&"overreach", me.whiff_recovery, me.whiff_slow)
	me.whiffed.emit()
#endregion


static func _aims_strikes(me: Player) -> bool:
	return me.rig != null and me.rig.get(&"strike_aim") == true


## The locked target if it is near enough to cut, or else the nearest enemy
## within `strike_assist_range` in front — in front of the way he is pushed, if
## he is, or of the way he faces.
static func _strike_candidate(me: Player) -> Node3D:
	if me.target != null and me._targetable(me.target) \
			and me.global_position.distance_to(me.target.global_position) < me.strike_assist_range + 1.5:
		return me.target
	var ahead := me.get_movement_direction()
	if ahead.is_zero_approx():
		ahead = -me.global_transform.basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	var widest := cos(deg_to_rad(me.strike_assist_cone))
	var best: Node3D = null
	var best_d := INF
	for node in me._foes():
		var who := node as Node3D
		if who == null or not me._targetable(who):
			continue
		var to := who.global_position - me.global_position
		to.y = 0.0
		var d := to.length()
		if d > me.strike_assist_range or d < 0.01 or ahead.dot(to / d) < widest:
			continue
		if d < best_d:
			best_d = d
			best = who
	return best


## Where on it a cut is aimed: its own answer if it has one, the middle of its
## body if it says how tall it is, else where a lock would sit.
static func strike_point(who: Node3D) -> Vector3:
	if who.has_method(&"strike_point"):
		return who.call(&"strike_point")
	var tall: Variant = who.get(&"body_height")
	if tall != null:
		var s: Variant = who.get(&"visual_scale")
		return who.global_position + Vector3.UP * float(tall) * (float(s) if s != null else 1.0) * 0.5
	var points := TargetPoints.of(who)
	return points[TargetPoints.default_index(who)]


static func _aim_strike(me: Player) -> void:
	if not PlayerMelee._aims_strikes(me):
		return
	var on := me._strike_foe != null and me._targetable(me._strike_foe)
	me.rig.call(&"aim_strike", PlayerMelee.strike_point(me._strike_foe) if on else Vector3.ZERO, on)
#endregion


## What a cut of this hero's blade is worth where it lands (host): p.atk, and
## `crit_chance` of the time a critical. [worth, critical]. On `target`, from
## behind it, the assassin's backstab: a critical worth his `backstab`
## ([RogueSkills]); the first cut out of his Vanish a sure critical.
static func cut_worth(me: Player, target: Node3D = null) -> Array:
	var worth: Array = [26.0, false] if me.profile == null else me.profile.cut(me._shot_rng)
	# Tariel without his shield cuts harder ([member CharacterProfile.bare_damage]),
	# hardest on his other string (the block button's)
	if me.shield_def_off() > 0.0:
		var other := me.rig.get(&"_worn_string") != null and int(me.rig.get(&"_worn_string")) != int(me.rig.get(&"_main_string"))
		worth[0] = float(worth[0]) * (me.profile.bare_other_damage if other else me.profile.bare_damage)
	# A heavy blow, or the last cut of a string, is worth more.
	if me.rig != null and me.rig.get(&"cut_weight") != null:
		worth[0] = float(worth[0]) * float(me.rig.get(&"cut_weight"))
	worth[0] = float(worth[0]) * me.dealt_scale
	# A perfect dodge answered (the quicker fight): the first cut to land after
	# it is the counter.
	if me.counter_ready():
		# (on a boss, a big one or another hero — a duel — not the whole of it)
		var big := target != null and (target is Player or HitFeel.is_big(target))
		worth[0] = float(worth[0]) * (me.as_counter_big if big else me.as_counter_power)
		me._counter_until_frame = -1
	if me.profile == null:
		return worth
	var crit_was := me.profile.crit_damage if bool(worth[1]) else 1.0
	var stab := RogueSkills.backstab_of(me.profile, target)
	if stab > 1.0 and RogueSkills.behind(me, target):
		# the backstab is the critical: a roll that came up critical too is not
		# counted twice
		worth[0] = float(worth[0]) / crit_was * stab
		worth[1] = true
		me._backstab_on = target
	elif me._rogue != null and (me._rogue.hiding or me._rogue.take_ambush()) and not bool(worth[1]):
		worth[0] = float(worth[0]) * me.profile.crit_damage
		worth[1] = true
	return worth
