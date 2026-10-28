class_name PlayerHurt
extends RefCounted

## Being struck: blows taken, guarding, falls and getting up, grabs, pins, bites and shoves.
## Taken out of player.gd (2026-10-28) so the hero is in parts; every
## function takes the hero as `me` and works on it as it did before. [Player]
## keeps a one-line function of the same name for each one called from
## outside this file (other scripts, the rig, signals, the hero himself).

## A creature landed a blow. Called on the host, which is the only peer whose
## creatures think; applied on the peer that drives this body, because that is
## the one that knows whether the shield was up or a roll was under way.
##
## `blow` of `blows` says where in its combo this one falls, and `combo` tells
## one combo from the next: the last blow of a combo that has landed every time
## puts him on the ground. Anything short of that is a flinch.
static func receive_blow(me: Player, damage: float, from: Node3D, blow: int = 0, blows: int = 1, combo: int = 0,
		magic: bool = false, how: StringName = &"") -> void:
	if from == null:
		return
	me._blow_shove_m = float(from.call(&"blow_shove_m")) if from.has_method(&"blow_shove_m") else 0.0
	# Off the ground, a low blow passes under his legs (a jump over a sweep).
	if how.is_empty() and not me.is_on_floor() and me.state != Player.State.DOWNED and me._low_blow(from):
		return
	var away := me.global_position - from.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = me.global_transform.basis.z
	# What kind of blow it is rides on the combo's key ([method _blow_kind]).
	var key := "%s#%d" % [from.get_path(), combo]
	# a blow that cuts his swing short (the troll with its tree, the user's
	# word 2026-10-25): marked on the key before its kind
	if from.has_method(&"blow_breaks_swing") and bool(from.call(&"blow_breaks_swing")):
		key += "^b"
	# A blow brought down on him from above (the attacker says so): he is
	# crushed down where he stands if it fells him ([method _fall_kind]).
	if how.is_empty() and from.has_method(&"blow_from_above") and bool(from.call(&"blow_from_above")):
		how = &"above"
	if not how.is_empty():
		key += "!" + String(how)
	# which blow it is, by name: a fall picked for it ([constant BLOW_FALLS])
	var named: StringName = StringName(from.call(&"blow_name")) if from.has_method(&"blow_name") else &""
	# the weapon itself met him (not only the blow's shock): "@w"
	if not named.is_empty() and WeaponSweep.motion_on(me).length() >= 0.5:
		named = StringName(String(named) + "@w")
	# held at the top of its wind-up, then brought down: "@h"
	if not named.is_empty() and from.has_method(&"blow_held") and bool(from.call(&"blow_held")):
		named = StringName(String(named) + "@h")
	me.net_blow.rpc_id(me.get_multiplayer_authority(), damage, PlayerHurt._swept(me, away.normalized()), from.global_position,
			key, blow, blows, magic, named)


## The way a blow throws him, from how the weapon was moving where it met him
## ([method WeaponSweep.motion_on]; the user's word, 2026-10-09: "every fall
## must follow the club's swing and its power, whatever way it goes"): the
## way along the ground leans from "away from the one who struck" over to the
## weapon's own sweep, the faster it went the more; its speed is the blow's
## force; how steeply it came down (or up) is its pitch. All three ride on
## the vector [method net_blow] gets: its flat part is the way, of length
## 1 + force, its y the pitch (-1 straight down .. 1 straight up).
static func _swept(me: Player, away: Vector3) -> Vector3:
	var sweep := WeaponSweep.motion_on(me)
	var speed := sweep.length()
	me.last_sweep = {}
	if speed < 0.5:
		return away
	var flat := Vector3(sweep.x, 0.0, sweep.z)
	var lean := clampf((flat.length() - me.sweep_lean_from) / me.sweep_lean_span, 0.0, me.sweep_lean_most)
	var way := away
	if flat.length_squared() > 0.0001:
		way = away.lerp(flat.normalized(), lean)
		if way.length_squared() < 0.0001:
			way = away
	var force := clampf((speed - me.sweep_force_from) / me.sweep_force_span, 0.0, 1.5)
	me.last_sweep = {"speed": speed, "force": force, "pitch": sweep.y / speed, "lean": lean}
	return way.normalized() * (1.0 + force) + Vector3.UP * clampf(sweep.y / speed, -1.0, 1.0)


## The kinds of blow the big creatures have ([PackBrute]), after the "!" of a
## combo's key:
## * "guard": a kick at the shield — caught on it, it beats the guard aside
##   ([method _crumple]); "crush" (the ogre's slow blow) the same.
## * "ground": a shock along the ground — off the ground (a jump) it misses,
##   and no shield takes it.
## * "stomp": a blow at him where he lies — it finds him on the ground (a roll
##   out still clears it), and no shield takes it.
## * "spike": stone out of the ground under him — no shield takes it.
## * "smash": the ogre's free hand swung down on him, into the ground — no
##   shield takes it (only a roll beats it).
static func _blow_kind(me: Player, combo: String) -> String:
	return combo.get_slice("!", 1) if combo.contains("!") else ""


## Whether his swing is held in a bite now ([SkinnedRig.in_hitstop]).
static func _bitten(me: Player) -> bool:
	return me.rig != null and me.is_committed() and me.rig.has_method(&"in_hitstop") and bool(me.rig.call(&"in_hitstop"))


## How hard a blow of `damage` shoves: the damage, up to `blow_heft_cap`.
static func _heft(me: Player, damage: float) -> float:
	return minf(damage, me.blow_heft_cap)


## A blow that got through shoves him back over the ground on his feet
## ([member reel_shove]): `base` m/s and more by the weapon's force, `share`
## of it; it dies away in [method _carry_push]. A new blow's shove takes the
## place of what is left of the last.
static func _shove(me: Player, away: Vector3, base: float, share: float) -> void:
	var way := Vector3(away.x, 0.0, away.z)
	if way.length_squared() < 0.0001:
		return
	var push := way.normalized() * minf(base + me.shove_force_gain * me._blow_force, me.shove_most) * share
	# a striker that strides on after the blow throws him that far (dying
	# away by `shove_friction`: v² = 2·f·d)
	if me._blow_shove_m > 0.0:
		var need := sqrt(2.0 * me.shove_friction * me._blow_shove_m)
		if push.length() < need:
			push = way.normalized() * need
	me._flinch_push = push


## The one who struck (the first part of a combo's key) held still a beat as
## the blow lands on him ([HitFeel]); on the peer that drives this body, as
## the shield's hold is.
static func _stop_striker(me: Player, combo: String, seconds: float) -> void:
	if not combo.begins_with("/"):
		return
	var striker := me.get_node_or_null(NodePath(combo.get_slice("#", 0))) as Node3D
	if striker != null and striker != me:
		HitFeel.hold(striker, seconds)


## His own view knocked along a blow that got through him and shaken
## ([ImpactFx.knock]): `how` = [knock, shake, seconds]. Only in his window.
static func _view_struck(me: Player, along: Vector3, how: Vector3) -> void:
	if how.x <= 0.0 or not me.is_multiplayer_authority() or me.camera == null or not me.camera.current:
		return
	ImpactFx.knock(me.camera, Vector3(along.x, 0.0, along.z), how.x, how.y, how.z)


## Down on the ground at the end of a fall's drop ([signal SkinnedRig.struck_ground]):
## the view thuds, dust off the ground.
static func _on_struck_ground(me: Player, at: Vector3) -> void:
	DustRing.burst(Blood.world_of(me), at + Vector3.UP * 0.05, 0.7)
	if me.is_multiplayer_authority() and me.camera != null and me.camera.current:
		ImpactFx.knock(me.camera, Vector3.DOWN, me.view_ground.x, me.view_ground.y, me.view_ground.z)


## Whether he is held still in a blow's bite now (his own rig's hit stop).
static func _held_in_bite(me: Player) -> bool:
	return me.rig != null and me.rig.has_method(&"in_hitstop") and bool(me.rig.call(&"in_hitstop"))


## The blow's shove carried on (every tick, on his feet): laid on his
## velocity after the controller has had its say, so the stick does not eat
## it, and dying away by `shove_friction`; held still with him in a bite.
static func _carry_push(me: Player, delta: float) -> void:
	if me._flinch_push == Vector3.ZERO:
		return
	if me.state != Player.State.GROUNDED and me.state != Player.State.AIRBORNE:
		me._flinch_push = Vector3.ZERO
		return
	if PlayerHurt._held_in_bite(me):
		return
	me.velocity.x += me._flinch_push.x
	me.velocity.z += me._flinch_push.z
	me._push_applied = me._flinch_push
	me._flinch_push = me._flinch_push.move_toward(Vector3.ZERO,
			me.shove_friction * delta * (1.0 if me.is_on_floor() else 0.3))


## Last tick's shove taken back off his velocity — as much of it as is still
## in it (a wall may have taken some) — so the controller works on his own.
static func _take_back_push(me: Player) -> void:
	if me._push_applied == Vector3.ZERO:
		return
	if me.state == Player.State.GROUNDED or me.state == Player.State.AIRBORNE:
		var dir := me._push_applied.normalized()
		var flat := Vector3(me.velocity.x, 0.0, me.velocity.z)
		var along := clampf(flat.dot(dir), 0.0, me._push_applied.length())
		me.velocity -= dir * along
	me._push_applied = Vector3.ZERO


static func _forget_combos_from(me: Player, combo: String) -> void:
	var attacker := combo.get_slice("#", 0)
	for key: String in me._combo_landed.keys():
		if key.get_slice("#", 0) == attacker:
			me._combo_landed.erase(key)


## Struck where he lies ("stomp", [method _blow_kind]): it lands whole, and
## keeps him down a moment longer — unless he rolls out first.
static func _stomped(me: Player, damage: float, away: Vector3) -> void:
	me.struck.emit(damage, false)
	var at := me.global_position + Vector3.UP * 0.3
	if me._take_damage(damage):
		return
	me.velocity += away * 1.5
	if not me._getting_up:
		me._down_timer = maxf(me._down_timer, 0.45)
	me.net_react.rpc(Player.Reaction.STOMPED, at, (away + Vector3.UP * 0.6).normalized())


## How hard a blow of `damage` that got through is: 0..1.
static func hit_heft(me: Player, damage: float) -> float:
	return clampf(damage / maxf(me.hit_heaviest, 0.01), 0.0, 1.0)


## Which side of him a blow going `away` (from whoever struck to him) came
## from: [enum SkinnedRig.From].
static func blow_side(me: Player, away: Vector3) -> int:
	var from := -Vector3(away.x, 0.0, away.z)
	var ahead := -me.global_basis.z
	var right := me.global_basis.x
	var f := from.dot(ahead)
	var r := from.dot(right)
	if absf(f) >= absf(r):
		return SkinnedRig.From.FRONT if f >= 0.0 else SkinnedRig.From.BACK
	return SkinnedRig.From.RIGHT if r > 0.0 else SkinnedRig.From.LEFT


## A blow that got through, shown (TARIEL_POLISH.md 9): which way it came
## from and how hard pick the flinch. `blow` is the blood's spray (the blow's
## way, a little up), its length 1 + how hard.
static func _flinch(me: Player, blow: Vector3) -> void:
	if me.rig == null:
		return
	if not me.rig.has_method(&"flinch_from"):
		me.rig.flinch()
		return
	var away := Vector3(blow.x, 0.0, blow.z)
	if blow.length() >= Player.BIG_STAGGER_SPRAY - 0.1 and me.rig.has_method(&"big_hit"):
		me.rig.call(&"big_hit", away.normalized() if away.length_squared() > 0.000001 else me.global_basis.z,
				PlayerHurt.blow_side(me, away))
		return
	var heft := clampf(blow.length() - 1.0, 0.0, 1.0)
	me.rig.call(&"flinch_from", away.normalized() if away.length_squared() > 0.000001 else me.global_basis.z,
			PlayerHurt.blow_side(me, away), heft)


## A heavy blow (as heavy as one that breaks a guard, [member
## guard_crumple_from]) landing just after an evade that ran out his stamina
## (the user's rule, 2026-10-04: the last of the stamina spent on a dodge,
## and the dodge mistimed — he came out of it before the blow): it drops him
## to his knee as a broken guard does ([method _crumple]). A dodge with breath
## left, or a light blow, is only a blow that lands.
static func _dodge_spent_out(me: Player, damage: float) -> bool:
	if not me._winded or PlayerHurt.block_strength(me, damage) < me.guard_crumple_from:
		return false
	if me.state == Player.State.DASHING or me.state == Player.State.DODGING:
		return false
	return me._now() - me._evade_ended_at <= me.dodge_mistime_window


## The guard broken (or, `shield` false, a dodge spent out): see
## [method _feel_guard_break].
static func _crumple(me: Player, damage: float, away: Vector3, shield: bool = true) -> void:
	me.is_blocking = false
	me.block_changed.emit(false)
	me._free_swing = false
	me.stamina = 0.0
	me._winded = true
	me._stamina_wait = me.stamina_empty_delay
	me.velocity += away * me.block_shove.y
	me._commit(me.guard_crumple_time)
	me._crumpled_until = me._now() + me.guard_crumple_time
	me.struck.emit(damage, false)
	var at := me.global_position + Vector3.UP * 1.2
	if me._take_damage(damage):
		me.velocity = away * (2.5 + PlayerHurt._heft(me, damage) * me.blow_shove * 0.5)
		return
	me.guard_broken.emit()
	# no shield in it (a dodge spent out) rides on the length: 2, not 1
	me.net_react.rpc(Player.Reaction.GUARD_BREAK, at, away.normalized() * (1.0 if shield else 2.0))


## The guard beaten aside, seen and heard on every peer ([method _crumple]).
static func _feel_guard_break(me: Player, at: Vector3, away: Vector3) -> void:
	me._interrupt_skill()
	var flat := Vector3(away.x, 0.0, away.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else me.global_basis.z
	if me.rig != null:
		if me.rig.has_method(&"guard_crumple"):
			me.rig.call(&"guard_crumple", me.guard_crumple_time, flat)
		else:
			me.rig.flinch()
	# the shield giving way: the block struck deep and loud, wood splitting,
	# a crunch under it and a deep rush of air; then his knee on the ground.
	# (A dodge spent out has no shield in it: the blow in flesh, the rush.)
	var shield := away.length() < 1.5
	var shield_at := at + (-flat) * 0.5
	if shield:
		Sfx.play(me, Player.BLOCK_SOUND, me, shield_at - me.global_position, randf_range(0.66, 0.72), -3.0)
		ImpactFx.strike(me, shield_at, &"wood", 2.0)
		ImpactFx.strike(me, shield_at, &"stone", 1.8)
	ImpactFx.thud(me, at, true)
	ImpactFx.rush(me, me, true, -6.0)
	me.get_tree().create_timer(me.guard_knee_after).timeout.connect(func() -> void:
		if is_instance_valid(me):
			PlayerHurt._knee_down_heard(me))
	PlayerHurt._rig_says(me, &"hurt")
	if shield:
		ParryFlash.burst(Blood.world_of(me), shield_at, -flat, 1.0)
	Blood.splatter(Blood.world_of(me), at, (flat + Vector3.UP * 0.3).normalized())
	for foot: Vector3 in (me.rig.call(&"foot_points") if me.rig != null and me.rig.has_method(&"foot_points") else [me.global_position]):
		SkidDust.kick(Blood.world_of(me), foot, flat, 1.0)
	if me.is_multiplayer_authority() and me.camera != null and me.camera.current:
		# hard: the whole view thrown and shaken
		ImpactFx.knock(me.camera, flat, me.guard_break_view.x, me.guard_break_view.y, me.guard_break_view.z)
	me.last_guard_break = {"at": at, "shield": shield}


static func _knee_down_heard(me: Player) -> void:
	if me.is_dead or me.rig == null or not me.rig.has_method(&"crumpled") or not bool(me.rig.call(&"crumpled")):
		return
	Sfx.play(me, Player.FALL_SOUND, me, Vector3.ZERO, randf_range(0.9, 1.0), -8.0)
	DustRing.burst(Blood.world_of(me), me.global_position, 0.35)


## How hard a blow of `damage` is, caught on the shield: 0..1.
static func block_strength(me: Player, damage: float) -> float:
	return clampf(damage / maxf(me.block_heaviest, 0.01), Player.BLOCK_LEAST, 1.0)


## How long a blow of `strength` on the shield holds both of them (seconds):
## a light one a breath, a heavy one about as long as a heavy cut's bite.
static func block_hold(me: Player, strength: float) -> float:
	return lerpf(0.035, 0.11, clampf(strength, 0.0, 1.0))


## A blow caught on his shield, felt (TARIEL_POLISH.md 8): on every peer the
## block's sound (deeper and louder the harder), sparks off the shield's face
## thrown back at whoever struck, the guard's jolt and the hold; in his own
## window the view knocked back and shaken. `blow` points back at the striker,
## its length the strength.
static func _feel_block(me: Player, at: Vector3, blow: Vector3) -> void:
	var strength := clampf(blow.length(), 0.0, 1.0)
	var back := blow.normalized() if blow.length_squared() > 0.000001 else -me.global_basis.z
	Sfx.play(me, Player.BLOCK_SOUND, me, at - me.global_position, randf_range(0.95, 1.05) * lerpf(1.06, 0.88, strength),
			lerpf(-15.0, -9.0, strength))
	ParryFlash.burst(Blood.world_of(me), at, back, lerpf(0.3, 0.75, strength))
	if me.rig != null:
		if me.rig.has_method(&"block_jolt"):
			me.rig.call(&"block_jolt", strength, -back)
		if me.rig.has_method(&"hitstop"):
			me.rig.call(&"hitstop", PlayerHurt.block_hold(me, strength))
	# his feet driven back along the ground: dirt off each heel, thrown the way
	# he slides
	var feet: Array = me.rig.call(&"foot_points") if me.rig != null and me.rig.has_method(&"foot_points") \
			else [me.global_position]
	for foot: Vector3 in feet:
		SkidDust.kick(Blood.world_of(me), foot, -back, strength)
	if me.is_multiplayer_authority() and me.camera != null and me.camera.current:
		# the view jolted back, away from the striker, and shaken: a blow felt
		ImpactFx.knock(me.camera, -back, lerpf(0.06, 0.16, strength), lerpf(0.05, 0.15, strength),
				lerpf(0.24, 0.42, strength))
	me.last_block_feel = {"strength": strength, "at": at}


## A sound of the rig's own (`hurt`), if it has it.
static func _rig_says(me: Player, what: StringName) -> void:
	if me.rig != null and me.rig.has_method(what):
		me.rig.call(what)


## The body hitting the ground, a moment after it starts to go over.
static func _thud(me: Player) -> void:
	me.get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_instance_valid(me):
			PlayerHurt._play_thud(me))


static func _play_thud(me: Player) -> void:
	if me.is_inside_tree():
		Sfx.play(me, Player.FALL_SOUND, me, Vector3.ZERO, randf_range(0.95, 1.05), -15.0)


## Off his feet. Everything else stops; he slides back with the blow and lies
## there, out of reach of anything else, until he gets up or rolls clear.
## The knockdown's spray length: 10.25 + the fall's kind + a quarter of the
## weapon's force (0..1.5) — how every peer learns both (the quarter's start
## keeps a whole number from rounding down under the float).
static func _fall_spray_length(me: Player) -> float:
	# the picked fall's number in the hundreds ([constant BLOW_FALLS])
	return 100.0 * me._down_number + 10.25 + float(me._down_kind) + clampf(me._blow_force, 0.0, 1.5) * 0.25


## Which way a blow that fells him throws him ([enum SkinnedRig.Fall], the
## user's word 2026-10-09): crushed down by one from above, thrown over to a
## side by one from that side, onto his face by one from behind; one in front
## throws him back, or, heavy enough, launches him through the air.
static func _fall_kind(me: Player, away: Vector3, _damage: float, how: String) -> int:
	# a blow that launches him (the troll's tree, thrown): back through the air
	if how == "launch":
		return SkinnedRig.Fall.FLY
	var heavy := me._blow_force >= SkinnedRig.FALL_TIERS.y
	# a skill's blast or a shock through the ground (no weapon in it): thrown
	# straight back from where it came, through the air if heavy, else flat
	# onto his back — never a fold (the user's word, 2026-10-09)
	if me._blow_area:
		return SkinnedRig.Fall.FLY if heavy else SkinnedRig.Fall.BACK
	# a heavy blow on his head from above: straight down onto his stomach;
	# a lighter one falls by the side it came from
	if heavy and (how == "crush" or how == "above" or me._blow_pitch <= me.sweep_crush_pitch):
		return SkinnedRig.Fall.CRUSH
	if me._blow_pitch >= me.sweep_rise_pitch and me._blow_force >= 0.3:
		return SkinnedRig.Fall.FLY
	match PlayerHurt.blow_side(me, away):
		SkinnedRig.From.BACK:
			return SkinnedRig.Fall.FORWARD
		SkinnedRig.From.LEFT, SkinnedRig.From.RIGHT:
			if heavy:
				return SkinnedRig.Fall.LEFT if PlayerHurt.blow_side(me, away) == SkinnedRig.From.LEFT else SkinnedRig.Fall.RIGHT
			# a lighter one from a side: over backwards, or forwards if it
			# carried him on the way he faces (no fold to the side)
			var facing := -me.global_basis.z
			facing.y = 0.0
			return SkinnedRig.Fall.FORWARD if away.dot(facing.normalized()) > 0.15 else SkinnedRig.Fall.BACK
	return SkinnedRig.Fall.FLY if me._blow_force >= me.fall_fly_force else SkinnedRig.Fall.BACK


## Turned on the blow's frame so the fall's clip throws him exactly the way
## the blow goes (each clip throws him one way of his own: back, forward, to
## a side): the turn is at most what lies between two sides (45°), and on
## the frame of the blow it reads as the blow wrenching him round.
static func _face_the_throw(me: Player, away: Vector3) -> void:
	var way := Vector3(away.x, 0.0, away.z)
	if way.length_squared() < 0.0001 or me._down_face == "keep":
		return
	way = way.normalized()
	var f := Vector3.ZERO
	if me._down_face == "foe":
		me.rotation.y = atan2(way.x, way.z)  # his face to the one who struck
		return
	# a clip that throws him slanting: turned the more so it goes the blow's way
	var slant := 0.0
	if me._down_number > 0 and me.rig != null and me.rig.has_method(&"numbered_slant"):
		slant = deg_to_rad(float(me.rig.call(&"numbered_slant", me._down_number)))
	match me._down_kind:
		SkinnedRig.Fall.BACK, SkinnedRig.Fall.FLY:
			f = -way
		SkinnedRig.Fall.FORWARD:
			f = way
		SkinnedRig.Fall.LEFT:
			f = Vector3.UP.cross(way)  # thrown to his right
		SkinnedRig.Fall.RIGHT:
			f = way.cross(Vector3.UP)  # thrown to his left
	if f.length_squared() > 0.0001:
		f = f.rotated(Vector3.UP, slant)
		me.rotation.y = atan2(-f.x, -f.z)


## The way the fall under way throws him, from how he faces (flat, unit).
static func _throw_way(me: Player) -> Vector3:
	var f := -me.global_basis.z
	f.y = 0.0
	f = f.normalized()
	match me._down_kind:
		SkinnedRig.Fall.FORWARD, SkinnedRig.Fall.CRUSH:
			return f
		SkinnedRig.Fall.LEFT:
			return f.cross(Vector3.UP)
		SkinnedRig.Fall.RIGHT:
			return Vector3.UP.cross(f)
	return -f


## The fall the user picked for the blow that came ([constant BLOW_FALLS]):
## [number, how he is turned], or [] for none.
static func _blow_fall(me: Player, away: Vector3) -> Array:
	if (me._blow_area and me._blow_name != &"pound") or not Player.BLOW_FALLS.has(me._blow_name):
		return []
	var sides: Dictionary = Player.BLOW_FALLS[me._blow_name]
	var side := "front"
	var from_it := me.global_position - me._blow_source
	from_it.y = 0.0
	if from_it.length_squared() < 0.0001:
		from_it = away
	match PlayerHurt.blow_side(me, from_it):
		SkinnedRig.From.BACK:
			side = "back"
		SkinnedRig.From.LEFT, SkinnedRig.From.RIGHT:
			side = "side"
	var picks: Array = sides.get(side, sides.get("any", []))
	if me._blow_weapon and sides.has("weapon"):
		picks = sides["weapon"]
	if picks.is_empty():
		return []
	return picks[randi() % picks.size()]


static func _show_rise(me: Player, up: StringName) -> void:
	if me.rig != null and "rise_want" in me.rig:
		me.rig.set(&"rise_want", up)
	if me.rig != null:
		if me.rig.has_method(&"rise"):
			# the body turned and set over to where he lies, so the
			# getting up starts from the way he fell
			var fix: Dictionary = me.rig.call(&"rise", me.get_up_time)
			if me.is_multiplayer_authority():
				if fix.has("yaw") and float(fix.get("blend", 0.0)) > 0.0:
					# over the get-up's blend in, so the pose he lies in
					# turns into its first one without a snap
					me._rise_turn = float(fix["yaw"])
					me._rise_shift = fix["shift"] as Vector3
					me._rise_left = float(fix["blend"])
				elif fix.has("yaw"):
					me.rotation.y += float(fix["yaw"])
					me.global_position += fix["shift"] as Vector3
				if fix.has("time") and me._getting_up:
					me._down_timer = float(fix["time"])
		else:
			me.rig.get_up(me.get_up_time)
	if me.rig != null and "rise_want" in me.rig:
		me.rig.set(&"rise_want", &"")


static func _knock_down(me: Player, away: Vector3, damage: float, how: String = "") -> void:
	# how hard it was: the weapon's force, or the blow's weight, whichever is
	# the more — it picks a light fall (dropped) or a heavy one (thrown) and
	# how far ([method SkinnedRig.fall], the user's word 2026-10-09)
	me._blow_force = maxf(me._blow_force, PlayerHurt.hit_heft(me, damage) * me.fall_heft_force)
	me._down_kind = PlayerHurt._fall_kind(me, away, damage, how)
	# the fall picked for this blow, or by hand (the falls' review page)
	me._down_number = 0
	me._down_face = ""
	var picked := PlayerHurt._blow_fall(me, away) if how != "launch" else []
	if me.review_fall > 0:
		picked = [me.review_fall, me.review_face]
	if not picked.is_empty() and me.rig != null and me.rig.has_method(&"numbered_kind"):
		var kind := int(me.rig.call(&"numbered_kind", int(picked[0]), PlayerHurt.blow_side(me, away) == SkinnedRig.From.RIGHT))
		if kind >= 0:
			me._down_kind = kind
			me._down_number = int(picked[0])
			me._down_face = String(picked[1])
	PlayerHurt._face_the_throw(me, away)
	me._down_flying = me._down_kind == SkinnedRig.Fall.FLY and me.rig != null and me.rig.has_method(&"fall") \
			and bool(me.rig.call(&"falls_directional"))
	me.state = Player.State.DOWNED
	me._flinch_push = Vector3.ZERO
	me._push_applied = Vector3.ZERO
	me._down_timer = me.down_time + 0.8
	me._getting_up = false
	me._down_for = 0.0
	me.is_invulnerable = true
	if me.is_blocking:
		me.is_blocking = false
		me.block_changed.emit(false)
	me._commit_timer = 0.0
	me._root_timer = 0.0
	me._attack_buffer = 0.0
	# the harder the weapon came, the further it throws him ([method _swept])
	var shove := (2.5 + PlayerHurt._heft(me, damage) * me.blow_shove * 0.5) * (1.0 + 0.6 * me._blow_force)
	var directional := me.rig != null and me.rig.has_method(&"falls_directional") and bool(me.rig.call(&"falls_directional"))
	if directional and me._down_kind != SkinnedRig.Fall.BACK and me._down_kind != SkinnedRig.Fall.FLY:
		shove = me.fall_carried_shove + me.fall_force_shove * me._blow_force
	var thrown := away
	if me._down_face == "keep":
		thrown = PlayerHurt._throw_way(me)  # the way the fall throws him as he stands
		shove = minf(shove, me.fall_carried_shove + me.fall_force_shove * 0.3)
	elif me._down_face == "foe":
		shove = 0.0  # he folds forward at its feet, of himself
	# a light hero is thrown further ([member SkinnedRig.fall_carry])
	var carry := float(me.rig.get(&"fall_carry")) if me.rig != null and "fall_carry" in me.rig else 1.0
	me.velocity = thrown * shove * carry
	me._down_carry = carry
	if me._down_flying:
		var k := 1.0 + 0.25 * minf(me._blow_force, 1.5)
		me.velocity = away * me.fall_fly_push.x * k * carry + Vector3.UP * me.fall_fly_push.y * k
		if how == "launch":
			# thrown hard and high, and head over heels through the air
			me.velocity = away * me.fall_fly_push.x * 1.7 * carry + Vector3.UP * me.fall_fly_push.y * 1.35
			me.net_tumble.rpc(true)
		me._down_timer = 9.0  # till he comes down
	me._down_push = Vector3(me.velocity.x, 0.0, me.velocity.z)


static func _process_downed(me: Player, delta: float) -> void:
	# held still a beat as the felling blow lands ([member fell_stop]): the
	# throw waits for it, nothing dies away
	if PlayerHurt._held_in_bite(me):
		return
	me._down_for += delta
	if me._rise_left > 0.0:
		# set over to where the get-up begins, a share each frame ([method rise])
		var k := minf(delta / me._rise_left, 1.0)
		me.rotation.y += me._rise_turn * k
		me.global_position += me._rise_shift * k
		me._rise_turn *= 1.0 - k
		me._rise_shift *= 1.0 - k
		me._rise_left = maxf(me._rise_left - delta, 0.0)
	# the blow's shove dying away (slowly through the air), and whatever the
	# fall itself carries him by ([member SkinnedRig.fall_velocity])
	var airborne := not me.is_on_floor()
	# (a light hero's shove dies the quicker too: thrown `carry` times as far,
	# not its square)
	me._down_push = me._down_push.move_toward(Vector3.ZERO, (1.5 if airborne else 9.0) * delta * me._down_carry)
	var carried := Vector3.ZERO
	if me.rig != null and "fall_velocity" in me.rig:
		carried = me.rig.get(&"fall_velocity") as Vector3
	me.velocity.x = me._down_push.x + carried.x
	me.velocity.z = me._down_push.z + carried.z
	if not airborne and me.velocity.y <= 0.0:
		me.velocity.y = 0.0
	else:
		me.velocity.y -= me._gravity * delta
	me.move_and_slide()
	me._update_floor_state()
	# launched: lies once he has come down and been struck onto the ground
	if me._down_flying and me.is_on_floor() and me._down_for > 0.12:
		me._down_flying = false
		me._down_timer = 0.6 + me.fall_lie
	# a ghoul on him: down till he works free ([method _process_pinned])
	if me.pinned_by != null and PlayerHurt._process_pinned(me, delta):
		return

	# Fallen for good: no rolling out and no getting up — only the wait.
	if me.is_dead:
		me._respawn_left -= delta
		if me._respawn_left <= 0.0:
			me._respawn()
		return

	# The way up that is always open: a roll, the moment he has hit the ground.
	if me._down_for >= me.roll_out_after and Input.is_action_just_pressed("dash"):
		PlayerHurt._roll_out(me)
		return
	me._down_timer -= delta
	if me._down_timer > 0.0:
		return
	if not me._getting_up:
		me._getting_up = true
		me._down_timer = me.get_up_time
		var up: StringName = me.rig.call(&"rise_pick") if me.rig != null and me.rig.has_method(&"rise_pick") else &""
		me.net_rise.rpc(up)
	else:
		PlayerHurt._stand_up_from_down(me)


static func _stand_up_from_down(me: Player) -> void:
	me.state = Player.State.GROUNDED if me.is_on_floor() else Player.State.AIRBORNE
	me.is_invulnerable = false
	if me._kick_cut_due:
		PlayerHurt._kick_cut(me)


## Up and away in one move: the roll, thrown the way the stick points (or back
## out of the fight if it points nowhere), with the whole of it untouchable.
static func _roll_out(me: Player) -> void:
	PlayerHurt._stand_up_from_down(me)
	me.net_react.rpc(Player.Reaction.ROLL_OUT, Vector3.ZERO, Vector3.ZERO)
	me._dash_cooldown_timer = 0.0
	if me.get_movement_direction().is_zero_approx():
		me.rotation.y += PI
	me._try_dash()
#endregion


## A cut thrown at something out of the knife's reach steps in to it (no
## further than `reach`).
static func _step_in(me: Player, foe: Node3D, reach: float) -> void:
	me._step_left = 0.0
	if foe == null or reach <= 0.0 or not me.is_on_floor():
		return
	var to := foe.global_position - me.global_position
	to.y = 0.0
	var gap := to.length() - Player._body_radius(foe) - me.strike_close
	if gap <= 0.05 or to.length() < 0.01:
		return
	var go := minf(gap, reach)
	me._step_velocity = to.normalized() * go / me.strike_step_time
	me._step_left = me.strike_step_time


## A heavy blow wound up slowly (the assassin's, [member SkinnedRogueRig.WIND_HEAVY])
## edges him in over the gathering (its spec's `creep`, metres) ...
static func _creep_in(me: Player, spec: Dictionary) -> void:
	var creep := float(spec.get("creep", 0.0))
	var t := float(me.rig.call(&"wind_left")) if me.rig.has_method(&"wind_left") else 0.0
	if creep <= 0.0 or t <= 0.0 or not me.is_on_floor():
		return
	var ahead := -me.global_basis.z
	ahead.y = 0.0
	me._step_velocity = ahead.normalized() * creep / t
	me._step_left = t


static func _on_wound_up(me: Player, lunge: float) -> void:
	if lunge <= 0.0 or not me.is_on_floor():
		return
	var foe: Node3D = me._strike_foe if is_instance_valid(me._strike_foe) else (me.target if me.target != null and me._targetable(me.target) else null)
	var ahead := -me.global_basis.z
	ahead.y = 0.0
	var go := lunge / 3.0
	if foe != null:
		var to := foe.global_position - me.global_position
		to.y = 0.0
		if to.length() > 0.01:
			ahead = to
			go = clampf(to.length() - Player._body_radius(foe) - me.strike_close, 0.0, lunge)
	if go < 0.3:
		return
	ahead = ahead.normalized()
	var t := clampf(go / me.glide_speed, 0.06, me.glide_longest)
	# every peer: held coiled while he slides, and the dirt (no shadow trail:
	# the user's word, 2026-10-05)
	if me.rig != null and me.rig.has_method(&"hitstop"):
		me.rig.call(&"hitstop", t)
	var world := Blood.world_of(me)
	if world != null:
		SkidDust.kick(world, me.global_position, -ahead, 0.7)
	if not me.is_multiplayer_authority():
		return
	me.rotation.y = atan2(-ahead.x, -ahead.z)
	me._glide_foe = foe
	me._glide_dir = ahead
	me._glide_left = t
	me._step_left = 0.0
	# (his commitment waits on the hold by itself: see `_bitten`)


## Each tick on the ground with it on him: true while it holds him.
static func _process_pinned(me: Player, delta: float) -> bool:
	var by := me.pinned_by
	if by == null:
		return false
	if not is_instance_valid(by) or bool(by.get("is_dead")) or me.is_dead:
		me.pinned_by = null
		return false
	me._down_timer = maxf(me._down_timer, 0.5)
	if Input.is_action_just_pressed("lock_on") or Input.is_action_just_pressed("interact") \
			or Input.is_action_just_pressed("attack"):
		me.pin_struggle += Player.PIN_PRESS
	me.pin_struggle = maxf(me.pin_struggle - Player.PIN_EASE * delta, 0.0)
	if me.pin_struggle >= 1.0:
		PlayerHurt._kick_free(me, by)
	return true


## Worked free: the kick and the spring up (every peer sees it), the ghoul
## told on the host, and the cut after it due when he is up.
static func _kick_free(me: Player, by: Node3D) -> void:
	# pushed off: it backs off him and he gets up as he would (the user's
	# word, 2026-10-27: no spring-up kick, no cut after), nothing striking him
	# while he rises
	me.pinned_by = null
	me.pin_struggle = 0.0
	me._kicked_from = null
	me._kick_cut_due = false
	me._down_timer = minf(me._down_timer, 0.15)
	me._safe_until = me._now() + 1.6
	if by.has_method(&"net_kicked"):
		if me.multiplayer.has_multiplayer_peer():
			by.rpc_id(1, &"net_kicked", me.get_path())
		else:
			by.call(&"net_kicked", me.get_path())


## Up from the kick: turned on it and into a cut, untouchable through its
## start.
static func _kick_cut(me: Player) -> void:
	me._kick_cut_due = false
	me._safe_until = me._now() + Player.KICK_CUT_SAFE
	var by := me._kicked_from
	me._kicked_from = null
	if by != null and is_instance_valid(by):
		var to := by.global_position - me.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			me.rotation.y = atan2(-to.x, -to.z)
	me._attack()
#endregion


static func _end_seize(me: Player) -> void:
	var was := me.seized_by
	me.seized_by = null
	me.pin_struggle = 0.0
	if was != null and is_instance_valid(was) and was is PhysicsBody3D:
		me.remove_collision_exception_with(was)


## Each tick in its hands: true while it holds him.
static func _process_seized(me: Player, delta: float) -> bool:
	var by := me.seized_by
	if by == null:
		return false
	if not is_instance_valid(by) or bool(by.get("is_dead")) or me.is_dead or me.state == Player.State.DOWNED:
		PlayerHurt._end_seize(me)
		return false
	me.velocity.x = 0.0
	me.velocity.z = 0.0
	if me.is_on_floor():
		me.velocity.y = 0.0
	else:
		me.velocity.y -= me._gravity * delta
	me.move_and_slide()
	var to := by.global_position - me.global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		me.rotation.y = lerp_angle(me.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))
	# dazed in its hands, over and over (a bite's jolt breaks in on it)
	me._seize_look_in -= delta
	if me._seize_look_in <= 0.0:
		me._seize_look_in = 2.4
		me.net_seize_look.rpc(0)
	if Input.is_action_just_pressed("lock_on") or Input.is_action_just_pressed("interact") \
			or Input.is_action_just_pressed("attack"):
		me.pin_struggle += Player.SEIZE_PRESS
	me.pin_struggle = maxf(me.pin_struggle - Player.SEIZE_EASE * delta, 0.0)
	if me.pin_struggle >= 1.0:
		PlayerHurt._shove_free(me, by)
	return true


## Worked free: the hilt into it (every peer sees it), the zombie told on the
## host; untouchable through it, and a cut at it after.
static func _shove_free(me: Player, by: Node3D) -> void:
	PlayerHurt._end_seize(me)
	me._shoved = by
	me._shove_left = Player.SHOVE_TIME
	me._safe_until = maxf(me._safe_until, me._now() + Player.SHOVE_SAFE)
	me.net_shove.rpc()
	if by.has_method(&"net_shoved"):
		if me.multiplayer.has_multiplayer_peer():
			by.rpc_id(1, &"net_shoved", me.get_path())
		else:
			by.call(&"net_shoved", me.get_path())


## The shove played out where he stands, then the cut at it.
static func _process_shove(me: Player, delta: float) -> void:
	me._shove_left -= delta
	me.velocity.x = 0.0
	me.velocity.z = 0.0
	if not me.is_on_floor():
		me.velocity.y -= me._gravity * delta
	me.move_and_slide()
	if me._shove_left > 0.0:
		return
	var by := me._shoved
	me._shoved = null
	if by != null and is_instance_valid(by):
		var to := by.global_position - me.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			me.rotation.y = atan2(-to.x, -to.z)
	me._attack()
#endregion


## In the grip: drawn in to its hand over a moment, then hung from it by the
## neck, facing it; let go of if it is gone, dead, or holds on too long.
static func _process_held(me: Player, delta: float) -> void:
	me._held_left -= delta
	me._held_time += delta
	me.velocity = Vector3.ZERO
	var by := me._held_by
	if by == null or not is_instance_valid(by) or bool(by.get("is_dead")) or me._held_left <= 0.0 \
			or not by.has_method(&"grab_point"):
		me._held_by = null
		return
	PlayerHurt._hang(me)
	var to := by.global_position - me.global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		me.rotation.y = lerp_angle(me.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-14.0 * delta))


## Held: his neck put in its palm (from where his neck is on him now); run
## each physics tick and each drawn frame, so the grip does not lag its hand.
static func _hang(me: Player) -> void:
	var by := me._held_by
	if by == null or not is_instance_valid(by) or not by.has_method(&"grab_point"):
		return
	var hand: Vector3 = by.call(&"grab_point")
	var neck := Vector3.UP * Player.HELD_NECK
	var skel: Skeleton3D = me.rig.get(&"_skel") as Skeleton3D if me.rig != null else null
	if skel != null:
		var b := skel.find_bone("neck_01")
		if b >= 0:
			neck = skel.global_transform * skel.get_bone_global_pose(b).origin - me.global_position
	var want := hand - neck
	# out past its palm (its hand round his throat, not through him: the
	# user's word, 2026-10-12)
	if by.has_method(&"grab_out"):
		want += (by.call(&"grab_out") as Vector3) * Player.HELD_OUT
	# snatched up at once (drawn over a long moment it read as a slide)
	var u := clampf(me._held_time / 0.06, 0.0, 1.0)
	me.global_position = me._held_from.lerp(want, u)


## Host: a creature has him in its grip for `seconds` (it carries him by its
## [method grab_point] till it lets go: [method release_grab]).
static func grab_by(me: Player, by: Node3D, seconds: float) -> void:
	if me.multiplayer.has_multiplayer_peer():
		me.net_grabbed.rpc_id(me.get_multiplayer_authority(), by.get_path(), seconds)
	else:
		me.net_grabbed(by.get_path(), seconds)


## Host: let go (its blow, if any, comes after).
static func release_grab(me: Player) -> void:
	if me.multiplayer.has_multiplayer_peer():
		me.net_released.rpc_id(me.get_multiplayer_authority())
	else:
		me.net_released()
