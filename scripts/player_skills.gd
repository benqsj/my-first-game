class_name PlayerSkills
extends RefCounted

## Skills: the slots, using one, the rising cut, the shade, the flask.
## Taken out of player.gd (2026-10-28) so the hero is in parts; every
## function takes the hero as `me` and works on it as it did before. [Player]
## keeps a one-line function of the same name for each one called from
## outside this file (other scripts, the rig, signals, the hero himself).

## Every skill he has, picked or not.
static func skill_choices(me: Player) -> PackedStringArray:
	var out := PackedStringArray()
	if me.profile != null:
		for id in me.profile.skills:
			if Player.SKILLS.has(StringName(id)):
				out.append(id)
	return out


## What is in the sockets: his picks if he has made them, else the first four.
static func _socketed(me: Player) -> PackedStringArray:
	if me.skill_picks.size() == Player.SKILL_SLOTS:
		return me.skill_picks
	var all := PlayerSkills.skill_choices(me)
	var out := PackedStringArray()
	for i in Player.SKILL_SLOTS:
		out.append(all[i] if i < all.size() else "")
	return out


## Puts skill `id` in `slot`; if it was in another socket, what was in `slot`
## goes there instead. Kept for this hero.
static func set_skill_slot(me: Player, slot: int, id: StringName) -> void:
	if slot < 0 or slot >= Player.SKILL_SLOTS or (id != &"" and not PlayerSkills.skill_choices(me).has(String(id))):
		return
	var picks := PlayerSkills._socketed(me)
	var was := picks.find(String(id))
	if was >= 0 and id != &"":
		picks[was] = picks[slot]
	picks[slot] = String(id)
	me.skill_picks = picks
	PlayerSkills._keep_picks(me)


static func _picks_key(me: Player) -> String:
	return me.profile.resource_path.get_file().get_basename() if me.profile != null else ""


static func _keep_picks(me: Player) -> void:
	var key := PlayerSkills._picks_key(me)
	if key == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(Player.PICKS_FILE)
	cfg.set_value("picks", key, me.skill_picks)
	cfg.save(Player.PICKS_FILE)


## His picks as he left them last time, if they still fit what he has.
static func _load_picks(me: Player) -> void:
	me.skill_picks = PackedStringArray()
	var key := PlayerSkills._picks_key(me)
	var cfg := ConfigFile.new()
	if key == "" or cfg.load(Player.PICKS_FILE) != OK:
		return
	var kept: Variant = cfg.get_value("picks", key, PackedStringArray())
	if not (kept is PackedStringArray) or (kept as PackedStringArray).size() != Player.SKILL_SLOTS:
		return
	var all := PlayerSkills.skill_choices(me)
	for id in (kept as PackedStringArray):
		if id != "" and not all.has(id):
			return
	me.skill_picks = kept


## The skill in `slot`, or `&""` for an empty one.
static func skill_in(me: Player, slot: int) -> StringName:
	if me.profile == null or slot < 0 or slot >= Player.SKILL_SLOTS:
		return &""
	var picks := PlayerSkills._socketed(me)
	var id := StringName(picks[slot]) if slot < picks.size() else &""
	return id if Player.SKILLS.has(id) else &""


## Seconds before the skill in `slot` can be used again (0 when it can).
static func skill_cooldown_left(me: Player, slot: int) -> float:
	var id := PlayerSkills.skill_in(me, slot)
	if id == &"":
		return 0.0
	return maxf(float(me._skill_ready_at.get(id, 0.0)) - me._now(), 0.0)


## Its whole cooldown, for the bar to draw the rest against.
static func skill_cooldown(me: Player, slot: int) -> float:
	var id := PlayerSkills.skill_in(me, slot)
	return float(Player.SKILLS[id]["cooldown"]) * me.skill_haste if id != &"" else 0.0


## Uses the skill in `slot`, if there is one, it is ready and the body is free
## to. True if it went off.
static func use_skill(me: Player, slot: int) -> bool:
	var id := PlayerSkills.skill_in(me, slot)
	if id == &"" or me.is_dead or PlayerSkills.skill_cooldown_left(me, slot) > 0.0:
		return false
	if me.state != Player.State.GROUNDED or me.is_committed():
		return false
	var went := false
	match id:
		&"arrow_rain":
			went = me._arrow_rain()
		&"hunters_mark":
			went = me._hunters_mark()
		&"piercing_arrow":
			went = me._piercing_arrow()
		&"fire_arrow":
			went = me._fire_arrow()
		&"stun_arrow":
			went = me._stun_arrow()
		&"poison_blade":
			went = me._poison_blade()
		&"rising_cut":
			went = PlayerSkills._rising_cut(me)
		&"shadow_slide":
			went = PlayerSkills._shadow_slide(me)
		&"shadow_lance":
			went = PlayerSkills._shadow_slide(me, &"shadow_lance")
		&"shadow_step":
			went = me.rogue().shadow_step(float(Player.SKILLS[id]["stamina"]))
		&"vanish":
			went = me.rogue().vanish(float(Player.SKILLS[id]["stamina"]))
		&"challenge":
			went = TarielChallenge.cast(me)
		&"frost_spears":
			went = me.mage().frost_spears(float(Player.SKILLS[id]["stamina"]))
		&"frost_step":
			went = me.mage().frost_step(float(Player.SKILLS[id]["stamina"]))
		&"dark_grasp":
			went = me.dark().grasp(float(Player.SKILLS[id]["stamina"]))
		&"black_comets":
			went = me.dark().comets(float(Player.SKILLS[id]["stamina"]))
		&"black_sun":
			went = me.dark().sun(float(Player.SKILLS[id]["stamina"]))
		&"frost_nova":
			went = me.elf().nova(float(Player.SKILLS[id]["stamina"]))
		&"moonwell":
			went = me.elf().moonwell(float(Player.SKILLS[id]["stamina"]))
		&"moonfall":
			went = me.elf().moonfall(float(Player.SKILLS[id]["stamina"]))
	if not went:
		return false
	me._skill_ready_at[id] = me._now() + float(Player.SKILLS[id]["cooldown"]) * me.skill_haste
	me.net_casts += 1
	me.skill_used.emit(slot, id)
	return true


static func _rising_cut(me: Player) -> bool:
	if me.rig == null or not me.rig.has_method(&"has_cut") or not bool(me.rig.call(&"has_cut", "rising_cut")):
		return false
	if not me.is_on_floor():
		return false
	if not me._spend(float(Player.SKILLS[&"rising_cut"]["stamina"])):
		return false
	if me.is_blocking:
		me.is_blocking = false
		me.block_changed.emit(false)
	me._set_weapons_stowed(false)
	var foe := me._charge_target(me.rising_seek)
	if foe != null:
		var to := foe.global_position - me.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			me.rotation.y = atan2(-to.x, -to.z)
	me._free_swing = true
	me._swing_t0 = me._game_t
	me._swing_chain = 1
	me._free_ease = me.run_cut_ease
	me._whiff_counts = me._foe_within(me.whiff_near)
	me.attack_started.emit()
	me.net_attack.rpc(SkinnedRig.RISING_CUT)
	me._cut_charging = true
	me._charge_skill = true
	me._charge_spec = me.rig.call(&"cut_spec", "rising_cut")
	me._charge_t0 = me._game_t
	me._charge_foe = foe
	me._mark_sure(foe)
	me._commit(float(me._charge_spec.get("hold_max", me.run_cut_hold_max)) + 2.0)
	me._attack_buffer = 0.0
	return true


## `key` "shadow_lance": the Shadow Lance (Tariel's third skill, [Swordsman]
## `SHADOW_LANCE`): the same slide, the sword thrust out in front as it
## starts and held there, so the point is what runs into the thing; struck,
## the slide stops on it and the thrust is drawn back out.
static func _shadow_slide(me: Player, key: StringName = &"shadow_slide") -> bool:
	if me.rig == null or not me.rig.has_method(&"has_cut") or not bool(me.rig.call(&"has_cut", String(key))):
		return false
	if not me.is_on_floor():
		return false
	if not me._spend(float(Player.SKILLS[key]["stamina"])):
		return false
	if me.is_blocking:
		me.is_blocking = false
		me.block_changed.emit(false)
	me._set_weapons_stowed(false)
	var foe := me._charge_target(me.shade_seek)
	me._charge_spec = me.rig.call(&"cut_spec", String(key))
	var spec := me._charge_spec
	me._shade_lance = bool(spec.get("lance", false))
	me._shade_dir = -me.global_basis.z
	me._shade_dir.y = 0.0
	me._shade_left = float(spec.get("slide_blind", 8.0))
	if foe != null:
		var to := foe.global_position - me.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			me._shade_dir = to
		me._shade_left = clampf(to.length() - Player._blade_radius(foe) - float(spec.get("strike_gap", 1.0)),
				0.0, float(spec.get("slide_max", 7.0)))
	me._shade_dir = me._shade_dir.normalized()
	me.rotation.y = atan2(-me._shade_dir.x, -me._shade_dir.z)
	me._free_swing = false
	me._swing_t0 = me._game_t
	me._swing_chain = 1
	me._whiff_counts = me._foe_within(me.whiff_near)
	me.attack_started.emit()
	me.net_attack.rpc(SkinnedRig.SHADOW_LANCE if me._shade_lance else SkinnedRig.SHADOW_SLIDE)
	me._charge_foe = foe
	me._mark_sure(foe, float(spec.get("sure_margin", -1.0)))
	me._shade_phase = 1
	me._shade_t0 = me._game_t
	me._shade_gone = false
	me._shade_went = 0.0
	me._shade_pace_now = PlayerSkills._shade_pace_at(me, 0.0)
	# (as long as the slide takes, eased in, and the shadows' own fading)
	me.net_slide.rpc(me._shade_left / maxf(me.shade_speed, 0.1) + me.shade_ease * 0.5)
	me._commit(3.0)
	me._attack_buffer = 0.0
	return true


## The slide's pace now: eased in from standing over `shade_ease`.
static func _shade_pace(me: Player) -> float:
	return PlayerSkills._shade_pace_at(me, me._game_t - me._shade_t0)


static func _shade_pace_at(me: Player, since: float) -> float:
	var t := clampf(since / maxf(me.shade_ease, 0.01), 0.0, 1.0)
	return me.shade_speed * lerpf(0.25, 1.0, t * t * (3.0 - 2.0 * t))


## The slide and its cut let go (the owner's, on the physics clock).
static func _tick_shade(me: Player, delta: float) -> void:
	if me._shade_phase < 0:
		return
	if me.rig == null or (not me._shade_gone and not bool(me.rig.call(&"holding_cut"))):
		# broken off (a blow took the clip off him)
		me._shade_phase = -1
		return
	var foe := me._charge_foe if me._charge_foe != null and is_instance_valid(me._charge_foe) \
			and me._targetable(me._charge_foe) else null
	# On at what it was thrown at (followed, not led), unless it dodges.
	if foe != null and not (foe.has_method(&"is_evading") and bool(foe.call(&"is_evading"))):
		var to := foe.global_position - me.global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			me._shade_dir = me._shade_dir.slerp(to.normalized(), 1.0 - exp(-10.0 * delta)).normalized()
	var pace := PlayerSkills._shade_pace(me)
	me._shade_pace_now = pace
	if me._charge_spec.has("peak"):
		PlayerSkills._tick_shade_peak(me, foe, pace, delta)
		return
	# Let go as the blade will cut when he arrives: the ground he covers from
	# now to the cut.
	if not me._shade_gone and me._shade_left <= pace * float(me.rig.call(&"time_to_cut")) + 0.05:
		PlayerSkills._shade_let_go(me)
	me._shade_left -= pace * delta
	if me._shade_left <= 0.0:
		me._shade_phase = -1
		me.velocity.x = me._shade_dir.x * 4.0
		me.velocity.z = me._shade_dir.z * 4.0
		if not me._shade_gone:
			PlayerSkills._shade_let_go(me)


## A slide whose swing has a `peak` (the Shadow Slide, the Shadow Lance): the
## swing's peak — the blade come round or thrust out level ahead — falls on
## the slide's end, however long the slide (the user's word: never the blade
## off to the side, the swing unfinished, as the slide ends). The slide's end
## follows what it is thrown at; the swing is let go when what is left of the
## slide is what the swing takes at its own pace, and from then on is paced
## (`SkinnedRig.pace_to`) to reach its peak as the slide runs out: faster for
## a short slide, slower if the thing came on to meet him. Struck before the
## peak (a sweep coming round into it), the slide is cut to a last step and
## the swing hurried to its peak there; struck at it, the slide stops.
static func _tick_shade_peak(me: Player, foe: Node3D, pace: float, delta: float) -> void:
	var peak := float(me._charge_spec.get("peak", 0.2))
	var at := float(me.rig.call(&"_progress"))
	var serial := int(me.rig.get(&"attack_serial"))
	if foe != null:
		# the end of the slide where it is now (no further than it may go)
		var to := foe.global_position - me.global_position
		to.y = 0.0
		var want := to.length() - Player._blade_radius(foe) - float(me._charge_spec.get("strike_gap", 1.5))
		me._shade_left = clampf(want, 0.0, PlayerSkills._shade_reach_left(me))
	if me._landed_serial == serial:
		if me._shade_gone and at >= peak - 0.03:
			# at its peak, in it: the slide stops on it
			PlayerSkills._shade_end(me, 1.2)
			return
		me._shade_left = minf(me._shade_left, 0.3)
	# The swing's time to its peak: at its own pace, and at the quickest it
	# may be hurried to. A slide too short for it is slowed to it (a thing
	# close by, or one that came on to meet him): the slide ends with the
	# swing, never before it.
	var own := PlayerSkills._shade_to_peak(me)
	var quickest := own / Player.SHADE_HURRY
	if me._shade_left / maxf(pace, 0.1) < quickest:
		pace = me._shade_left / maxf(quickest, 0.01)
	me._shade_pace_now = pace
	var left_t := me._shade_left / maxf(pace, 0.1) if pace > 0.01 else quickest
	if not me._shade_gone and left_t <= own + 0.01:
		PlayerSkills._shade_let_go(me)
	if me._shade_gone:
		me.rig.call(&"pace_to", peak, maxf(left_t, quickest))
	me._shade_left -= pace * delta
	me._shade_went += pace * delta
	if me._shade_left <= 0.001 and (not me._shade_gone or at < peak - 0.01):
		# no ground left and the swing not there yet: it finishes where he is
		me._shade_left = 0.0
		return
	if me._shade_left <= 0.0:
		PlayerSkills._shade_end(me, 1.5 if me._shade_lance else 4.0)


## How much further this slide may go (`slide_max` in all).
static func _shade_reach_left(me: Player) -> float:
	return maxf(float(me._charge_spec.get("slide_max", 7.0)) - me._shade_went, 0.0)


## The slide over: what is left of it carried on (m/s), the swing let go if it
## was not, and at its own pace again.
static func _shade_end(me: Player, carry: float) -> void:
	me._shade_phase = -1
	me.velocity.x = me._shade_dir.x * carry
	me.velocity.z = me._shade_dir.z * carry
	if not me._shade_gone:
		PlayerSkills._shade_let_go(me)
	me.rig.call(&"pace_own")


## Seconds from where the lance's clip is to its peak, let go now (at its rate).
static func _shade_to_peak(me: Player) -> float:
	var length := float(me.rig.get(&"_action_len"))
	var at := float(me.rig.call(&"_progress"))
	return maxf(length * (float(me._charge_spec.get("peak", 0.26)) - at), 0.0) \
			/ maxf(float(me.rig.get(&"_action_rate")), 0.01)


static func _shade_let_go(me: Player) -> void:
	me._shade_gone = true
	me.net_release_cut.rpc()
	me._commit_timer = 0.0
	me._commit(float(me.rig.get(&"_swing_commit")))
	me._swing_t0 = me._game_t


## A blow landed while a skill was being taken (every peer, from
## [method net_react]): whatever skill is under way stops here — no shot, no
## glint, no rain — and the string and the stance let go.
static func _interrupt_skill(me: Player) -> void:
	me._skill_serial += 1
	me._pierce_quarry = null
	me._root_timer = 0.0
	if me.rig != null and me.rig.has_method(&"cancel_skill_shot"):
		me.rig.call(&"cancel_skill_shot")
	if me._air_swirl != null and is_instance_valid(me._air_swirl):
		me._air_swirl.queue_free()
	me._air_swirl = null


## A flask drunk, on his own peer: too little to drink from, or busy, or off
## his feet, nothing. Every peer sees it ([method net_drink]); a creature that
## punishes a spell punishes this too (`net_casts`).
static func _drink(me: Player) -> bool:
	if me.flasks_left <= 0 or me.is_dead or me.state != Player.State.GROUNDED or me.is_committed() or me._drawing \
			or me._now() < me._crumpled_until or not me.is_on_floor():
		return false
	var length := 1.2
	if me.rig != null and me.rig.has_method(&"play_part"):
		var got := float(me.rig.call(&"play_part", Player.FLASK_CLIP, me.flask_rate, 0.0, 1.0, 0.12))
		if got > 0.0:
			length = got
			me.rig.set(&"walk_under", true)
	if me.is_blocking:
		me.is_blocking = false
		me.block_changed.emit(false)
	me.flasks_left -= 1
	me._commit(length)
	me._drink_until = me._now() + length
	me._drink_heal_at = me._now() + length * me.flask_heal_at
	me.net_casts += 1
	me.net_drink.rpc()
	return true


## Whether he is at a flask now.
static func drinking(me: Player) -> bool:
	return me._now() < me._drink_until


## Healed `amount` (the elf's Moonwell): the host asks, his own peer, where his
## health is kept, mends it and shows it.
static func heal(me: Player, amount: float) -> void:
	if amount <= 0.0 or me.is_dead:
		return
	me.net_heal.rpc_id(me.get_multiplayer_authority(), amount)
