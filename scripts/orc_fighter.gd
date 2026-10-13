class_name OrcFighter
extends PackBrute

## The orc (Polysplit's Biped Creatures, CREATURES_PACK.md): a falchion and
## a temper (the user's picks, 2026-10-07).
##
## * **The leap** ([PackBrute]): from off, it springs at him, falchion and
##   body, and comes down on him — down he goes.
## * **A boot through his shield.** He crouches behind his shield in front of
##   it (`kick_after` s of it): it kicks the shield aside (`CR_Kick`, a "guard"
##   blow: caught on the shield it beats his guard down, [method
##   Player._crumple]) and goes straight in after it with the falchion while
##   he is open.
## * **Rage** ([PackBrute]): cut to half its health it roars, glows red, comes
##   on quicker and hits harder, and the orcs about come at the roar.
## * **A duellist** (the user's word, 2026-10-13: polish the orc, combos,
##   half again as tall as a man): eight combos made by hand, Elden Ring's way
##   — quick strings of cuts, a low sweep and a cut from above (a jump, then a
##   roll), a butt of the head in the middle of a string, a great cut held
##   back a beat (a feint, `_holds`), and enraged a frenzy of five. From off
##   (`lunge_from`..`lunge_to`) it lunges at him, falchion first, and cuts down.
## * **Skills, each with its tell** (2026-10-13):
##   - **the war cry** (`OG_Battlecry`): him a way off and its kin about, it
##     stops and roars; it and every orc within `cry_range` are emboldened
##     for `cry_time` s — quicker on their feet and between blows, harder
##     blows, a red light on their chests — and come for him. A long opening.
##   - **the shoulder charge**: from `charge_from`..`charge_to` off it beats
##     its chest and grunts (`CR_Call`'s start), then drives at him shoulder
##     first (`CR_ShieldDash`): a "guard" blow that beats a shield down and
##     throws him off his feet. A roll to the side.
##   - **the thrown axe** (`CR_Throw`): him far off, or it waiting its turn in
##     a band, it hurls a hand axe at him, spinning ([GoblinShot] AXE): a
##     stagger; a shield takes it, a roll or a step aside lets it by.
##   - **punished**: a flask drunk or a spell cast within `punish_reach`, it is
##     at him at once — the lunge, the charge, the axe or a combo, by the gap.

@export_group("Kick")
@export var kick_clip: StringName = &"CR_Kick"
@export var kick_part: Vector3 = Vector3(1.25, 0.0, 0.9)
@export var kick_limbs: String = "R_knee_joint>R_toe_joint:0.14"
## How long he must hold his shield up in front of it before it kicks.
@export var kick_after: float = 0.35
@export var kick_cooldown: float = 3.0
@export var kick_share: float = 0.6

@export_group("Lunge")
## From how far it lunges at him (m), and how often.
@export var lunge_from: float = 4.5
@export var lunge_to: float = 7.5
@export var lunge_cooldown: Vector2 = Vector2(6.0, 10.0)
## Never nearer him than this at the end of it (m).
@export var lunge_stop: float = 1.9
@export_group("War cry")
@export var cry_range: float = 16.0
@export var cry_time: float = 12.0
@export var cry_cooldown: Vector2 = Vector2(26.0, 36.0)
@export var cry_harder: float = 1.2
@export var cry_quicker: float = 1.15
## Only with him at least this far off (m).
@export var cry_from: float = 4.5
## Where in its clip it roars (share).
@export var cry_at: float = 0.3
@export var cry_glow: Color = Color(1.0, 0.18, 0.06)
@export_group("Shoulder charge")
@export var charge_from: float = 7.0
@export var charge_to: float = 13.0
@export var charge_cooldown: Vector2 = Vector2(9.0, 14.0)
@export var charge_speed: float = 10.0
@export var charge_share: float = 0.9
## How near him its shoulder meets him (m, centre to centre).
@export var charge_meets: float = 2.1
## How long it drives on (s) before it gives up on meeting him.
@export var charge_time: float = 0.75
@export_group("Thrown axe")
@export var throw_from: float = 8.0
@export var throw_to: float = 18.0
@export var throw_cooldown: Vector2 = Vector2(7.0, 12.0)
## Waiting its turn in a band, it throws now and then (s between).
@export var throw_waiting: Vector2 = Vector2(5.0, 9.0)
@export var throw_share: float = 0.55
## Where in its clip the axe leaves its hand (share).
@export var throw_at: float = 0.25
@export var throw_hand: StringName = &"R_wrist_joint"
@export_group("Rage")
## The bone its second blade is held by while it rages, and how it is turned
## there against the right hand's hold.
@export var second_bone: String = "L_equip_joint"
@export var second_turn: Transform3D = Transform3D(Basis(Vector3.FORWARD, PI), Vector3.ZERO)
@export_group("Punish")
@export var punish_reach: float = 14.0
@export_group("Feints")
## How often its great cuts are held back a beat before they come down.
@export var feint_chance: float = 0.45

const KICK := 112
## Its combos' moves (2026-10-10): Mixamo's great axe swings, its sword one-handed.
const O_HORIZ := 180
const O_BACK := 181
const O_DOWN := 182
const O_TWIN := 183
const O_SPIN := 184
## Its duellist's moves (2026-10-13).
const O_S1 := 185
const O_S2 := 186
const O_S3 := 187
const O_S4 := 188
const O_LUNGE := 190
const O_BUTT := 191
const O_POWER := 192
const O_LOW := 193
const O_DSLASH := 194
const O_CRY := 195
const O_BRACE := 196
const O_CHARGE := 197
const O_THROW := 198
const SOUNDS := "res://sounds/ogre/"
const ROAR_SOUND := SOUNDS + "roar_short.wav"
const GRUNTS := [SOUNDS + "grunt_1.wav", SOUNDS + "grunt_2.wav", SOUNDS + "grunt_3.wav"]
const WHOOSH := SOUNDS + "whoosh_light.wav"
const WHOOSH_HEAVY := SOUNDS + "whoosh_heavy.wav"
## Its voice: the ogre's, higher (a smaller throat).
const VOICE := 1.25
## Its combos, by name.
const LUNGE_COMBO := &"lunge"

var _shield_for: float = 0.0
var _kick_wait: float = 0.0
## The falchion goes in straight after the kick, for this long more.
var _follow_up: float = 0.0
var _lunge_wait: float = 3.0
var _lunge_speed: float = 0.0
var lunges_made: int = 0
var _cry_wait: float = 2.0
var _charge_wait: float = 3.0
var _throw_wait: float = 3.0
var _charge_speed: float = 0.0
var _charge_met: bool = false
var charge_hits: int = 0
## Host: emboldened for this much longer (the war cry).
var _bold_left: float = 0.0
var cries_made: int = 0
var charges_made: int = 0
var throws_made: int = 0
var punishes_made: int = 0
var bolds_taken: int = 0
## Host: his flask and his casts as last seen; how long it may still punish.
var _seen_casts: int = -1
var _punish_left: float = 0.0
## Every peer: the act its sounds were last made for, and its clock.
var _voiced_serial: int = -1
var _voiced_clock: float = 0.0
var _voiced_whoosh: int = 0
var _bold_light: OmniLight3D
var _bold_shown: float = 0.0
## Every peer: its second blade, out while it rages.
var _second: Node3D


func _ready() -> void:
	super()
	_special(KICK, kick_clip, kick_part)
	# Not a blow that fells him by itself.
	_special_strike(KICK, kick_limbs, kick_share, 3)
	_kinds[KICK] = &"guard"
	_hand_move(O_HORIZ, &"CR_OG_Attack_Horizontal", Vector3(1.05, 0.1, 0.8), 0.6)
	_hand_move(O_BACK, &"CR_OG_Attack_Backhand", Vector3(1.05, 0.08, 0.62), 0.6)
	_hand_move(O_DOWN, &"CR_OG_Attack_Downward", Vector3(1.0, 0.05, 0.75), 1.15)
	_hand_move(O_TWIN, &"CR_OG_Combo_3", Vector3(1.05, 0.12, 0.9), 0.5, "", [0.372, 0.617])
	_hand_move(O_SPIN, &"CR_OG_Attack_360", Vector3(1.0, 0.0, 0.7), 1.2)
	# its combos made by hand ([PackBrute] `_hand_combos`)
	# the duellist's (2026-10-13): its own sword clips, quick
	_hand_move(O_S1, &"CR_Slash1", Vector3(1.0, 0.0, 0.62), 0.5)
	_hand_move(O_S2, &"CR_Slash2", Vector3(1.0, 0.05, 0.58), 0.5)
	_hand_move(O_S3, &"CR_Slash3", Vector3(1.0, 0.0, 0.55), 0.5)
	_hand_move(O_S4, &"CR_Slash4", Vector3(1.0, 0.0, 0.66), 0.6)
	_hand_move(O_LUNGE, &"CR_SwordDash", Vector3(0.5, 0.0, 0.5), 0.7)
	_hand_move(O_BUTT, &"CR_OG_Headbutt", Vector3(1.2, 0.12, 0.62), 0.4, "head_joint>head_joint:0.3")
	_hand_move(O_POWER, &"CR_OG_Power_Slash", Vector3(1.0, 0.3, 1.0), 1.1)
	_hand_move(O_LOW, &"CR_OG_Low_Slash", Vector3(1.1, 0.2, 0.7), 0.6)
	_hand_move(O_DSLASH, &"CR_OG_Downward_Slash", Vector3(1.0, 0.1, 0.78), 1.0)
	# its great cuts now and then held back at the top (a feint: a roll too
	# early is caught)
	for what: int in [O_POWER, O_DOWN, O_DSLASH, O_S2]:
		_holds[what] = [feint_chance, 0.3, 0.7, 0.22]
	_hand_combos = [
		{"name": &"three", "moves": [O_HORIZ, O_BACK, O_DOWN], "fells": [2], "weight": 1.0},
		{"name": &"twin_spin", "moves": [O_TWIN, O_SPIN], "fells": [1], "weight": 0.8, "rage": [O_DOWN]},
		{"name": &"quick", "moves": [O_S1, O_S2, O_S4], "fells": [2], "weight": 1.2, "rage": [O_S3]},
		{"name": &"low_high", "moves": [O_LOW, O_DSLASH], "fells": [1], "weight": 0.9},
		{"name": LUNGE_COMBO, "moves": [O_LUNGE, O_DSLASH], "fells": [1], "weight": 1.0, "far": true},
		{"name": &"butt", "moves": [O_S3, O_BUTT, O_DOWN], "fells": [2], "weight": 0.8},
		{"name": &"power", "moves": [O_S1, O_POWER], "fells": [1], "weight": 0.9},
		{"name": &"frenzy", "moves": [O_S1, O_S2, O_S3, O_S4, O_SPIN], "fells": [4], "weight": 1.4,
				"rage_only": true},
	]
	_lunge_wait = _rng.randf_range(2.0, lunge_cooldown.x)
	_special(O_CRY, &"CR_OG_Battlecry", Vector3(1.0, 0.0, 0.8))
	_special(O_BRACE, &"CR_Call", Vector3(1.0, 0.0, 0.7))
	_special(O_CHARGE, &"CR_ShieldDash", Vector3(0.75, 0.0, 0.7))
	_special(O_THROW, &"CR_Throw", Vector3(1.1, 0.0, 0.62))
	_cry_wait = _rng.randf_range(0.5, 3.0)
	_charge_wait = _rng.randf_range(3.0, charge_cooldown.x)
	_throw_wait = _rng.randf_range(2.0, throw_cooldown.x)
	Sfx.warm([ROAR_SOUND, WHOOSH, WHOOSH_HEAVY] + GRUNTS)
	# half again as tall as a man (the user's word, 2026-10-13): its flat
	# cuts bent down onto him ([method PackBrute._fit_stoops])
	_fit_stoops()


func _own_move(delta: float) -> bool:
	_kick_wait = maxf(_kick_wait - delta, 0.0)
	_lunge_wait = maxf(_lunge_wait - delta, 0.0)
	if drill_combo < 0:
		if _punish_left > 0.0 and _punish():
			return true
		if _try_cry() or _try_charge() or _try_throw():
			return true
	if _try_lunge():
		return true
	if drill_combo >= 0 and drill_combo == _combo_named(LUNGE_COMBO) and not _quarry_down():
		# practising its lunge: back off to lunge again
		mode = Mode.FIGHT
		var away := global_position - _quarry.global_position
		away.y = 0.0
		if away.length() < lunge_from + 1.0:
			var v := away.normalized() * speed * 1.5
			velocity.x = move_toward(velocity.x, v.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, v.z, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		_face(-away, delta, turn_speed)
		return true
	if _shielded(_quarry):
		_shield_for += delta
	else:
		_shield_for = 0.0
	var gap := _distance_to(_quarry)
	if _shield_for >= kick_after and _kick_wait <= 0.0 and gap <= reach + 0.3 and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(KICK)
		return true
	_follow_up = maxf(_follow_up - delta, 0.0)
	if _follow_up > 0.0 and gap <= reach + 1.2 and _cooldown <= 0.0:
		# In after it at once, before he has his guard back.
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin_attack()
		if act != Act.NONE:
			_follow_up = 0.0
		return true
	return super(delta)


## His shield up, and facing it.
func _shielded(who: Node3D) -> bool:
	if who == null or not (bool(who.get("net_blocking")) or bool(who.get("is_blocking"))):
		return false
	var his := -who.global_transform.basis.z
	his.y = 0.0
	var to_me := global_position - who.global_position
	to_me.y = 0.0
	return his.normalized().dot(to_me.normalized()) > 0.3


func _after(what: int) -> void:
	if what == O_BRACE and not is_dead and _decides():
		# out of its tell straight into the charge
		super(what)
		_begin_charge()
		return
	if what == KICK:
		_kick_wait = kick_cooldown * (0.6 if raging else 1.0)
		_shield_for = 0.0
		_follow_up = 1.6
	super(what)
	if what == KICK:
		_cooldown = 0.0


## Host: from off, now and then, it lunges at him falchion first and cuts down
## (its "far" combo), sped over the gap to its blow.
func _try_lunge() -> bool:
	var which := _combo_named(LUNGE_COMBO)
	var drilling := drill_combo >= 0
	if which < 0 or (drilling and drill_combo != which) or _quarry == null or _quarry_down():
		return false
	if (_lunge_wait > 0.0 and not drilling) or stamina < attack_cost or _cooldown > 0.0:
		return false
	var gap := _distance_to(_quarry)
	if gap < lunge_from or gap > lunge_to:
		return false
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001 and rad_to_deg(_forward().angle_to(to.normalized())) > 50.0:
		return false
	start_hand_combo(which)
	var until := _blow_moments(O_LUNGE)[0]
	var lands := float(_strike_from.get(O_LUNGE, strike_off))
	# it comes to where its blow lands, not into him
	_lunge_speed = maxf(gap - maxf(lands, lunge_stop), 0.0) / maxf(until - 0.05, 0.15)
	_lunge_wait = _rng.randf_range(lunge_cooldown.x, lunge_cooldown.y) * (0.6 if raging else 1.0)
	lunges_made += 1
	return true


func _combo_named(name: StringName) -> int:
	for i in _hand_combos.size():
		if (_hand_combos[i] as Dictionary)["name"] == name:
			return i
	return -1


func _extra_velocity(delta: float) -> Vector3:
	if act == O_CHARGE:
		if not _charge_met and _act_time <= charge_time and (_quarry == null or _distance_to(_quarry) > 1.5):
			if _quarry != null:
				_face(_quarry.global_position - global_position, delta, 2.0)
			return _forward() * _charge_speed
		return Vector3.ZERO
	if act == O_CRY or act == O_BRACE or act == O_THROW:
		return Vector3.ZERO
	if act == O_LUNGE and _lunge_speed > 0.0:
		if _act_time <= _blow_moments(O_LUNGE)[0] and (_quarry == null or _distance_to(_quarry) > lunge_stop):
			return _forward() * _lunge_speed
		_lunge_speed = 0.0
		return Vector3.ZERO
	return super(delta)


#region Skills (2026-10-13)
## Host: him a way off and its kin about (or it alone, fresh to the fight), it
## roars them on.
func _try_cry() -> bool:
	if _cry_wait > 0.0 or _bold_left > 0.0 or raging or stamina < attack_cost or _quarry_down():
		return false
	var gap := _distance_to(_quarry)
	if gap < cry_from * visual_scale / 1.6 or gap > sight_range:
		return false
	_cry_wait = _rng.randf_range(cry_cooldown.x, cry_cooldown.y)
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(O_CRY)
	return true


## Host: the roar's moment: it and its kin about emboldened, and on him.
func _cry() -> void:
	cries_made += 1
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var o := node as OrcFighter
		if o == null or o.is_dead or o.global_position.distance_to(global_position) > cry_range:
			continue
		o._embolden(cry_time)
		if _quarry != null and o != self:
			o._quarry = _quarry
			if o.mode == Mode.GUARD or o.mode == Mode.RETURN:
				o.mode = Mode.CHASE
	_send_cry()


func _send_cry() -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_cry.rpc()
	else:
		net_cry()


## Every peer: its roar heard and seen.
@rpc("authority", "call_local", "reliable")
func net_cry() -> void:
	Sfx.play(self, ROAR_SOUND, self, Vector3.UP * 2.0 * visual_scale, VOICE, 2.0)
	var head := global_position + Vector3.UP * 1.75 * visual_scale
	if _skeleton != null and _skeleton.find_bone("head_joint") >= 0:
		head = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("head_joint")).origin
	var into := Blood.world_of(self)
	SkillFx.flash(into, head, cry_glow, 0.6 * visual_scale, 0.3, 3.0)
	SkillFx.burst(into, head + _forward() * 0.3, Color(1.0, 0.85, 0.7, 0.5), 18, Vector2(2.0, 4.0), _forward(), 35.0,
			Vector2(0.04, 0.09), Vector3.ZERO, 0.5)
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var o := node as OrcFighter
		if o != null and not o.is_dead and o.global_position.distance_to(global_position) <= cry_range:
			o._show_bold(cry_time)


## Host: quicker and harder for `t` s.
func _embolden(t: float) -> void:
	if _bold_left <= 0.0:
		bolds_taken += 1
		speed *= cry_quicker
		chase_speed *= cry_quicker
		close_speed *= cry_quicker
		attack_cooldown *= 0.6
	_bold_left = maxf(_bold_left, t)


func _calm_down() -> void:
	speed /= cry_quicker
	chase_speed /= cry_quicker
	close_speed /= cry_quicker
	attack_cooldown /= 0.6


func _blow_worth(what: int) -> float:
	return super(what) * (cry_harder if _bold_left > 0.0 else 1.0)


## Every peer: a red light on its chest while it is emboldened.
func _show_bold(t: float) -> void:
	_bold_shown = maxf(_bold_shown, t)
	if _bold_light == null:
		_bold_light = OmniLight3D.new()
		_bold_light.light_color = cry_glow
		_bold_light.omni_range = 1.6 * visual_scale
		_bold_light.shadow_enabled = false
		add_child(_bold_light)
		_bold_light.position = Vector3(0.0, 1.35, 0.35) * visual_scale


## Host: from off it beats its chest, then drives at him shoulder first.
func _try_charge() -> bool:
	if _charge_wait > 0.0 or stamina < attack_cost or _cooldown > 0.0 or _quarry_down():
		return false
	var gap := _distance_to(_quarry)
	if gap < charge_from or gap > charge_to or not _facing_him(45.0):
		return false
	_charge_wait = _rng.randf_range(charge_cooldown.x, charge_cooldown.y) * (0.6 if raging else 1.0)
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(O_BRACE)
	return true


func _begin_charge() -> void:
	if _quarry == null:
		return
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	var gap := _distance_to(_quarry)
	_charge_speed = clampf((gap - 1.3) / maxf(charge_time * 0.8, 0.2), charge_speed * 0.6, charge_speed * 1.4)
	_charge_met = false
	charges_made += 1
	_cooldown = 0.0
	_begin(O_CHARGE)


## Host: its shoulder meets him, if he is before it and near enough: a blow
## that beats a shield down and throws him off his feet.
func _charge_into_him() -> void:
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length() > charge_meets * visual_scale / 1.6 or not _facing_him(55.0):
		return
	_charge_met = true
	if bool(_quarry.get("is_dead")) or not _quarry.has_method(&"receive_blow"):
		return
	charge_hits += 1
	_quarry.call(&"receive_blow", hit_damage * charge_share * _blow_worth(O_CHARGE), self, 0, 1,
			act_serial * 10 + 7, false, &"guard")


## Host: him far off, a hand axe hurled at him.
func _try_throw() -> bool:
	if _throw_wait > 0.0 or stamina < attack_cost or _cooldown > 0.0 or _quarry_down():
		return false
	var gap := _distance_to(_quarry)
	if gap < throw_from or gap > throw_to or not _facing_him(40.0):
		return false
	_throw_wait = _rng.randf_range(throw_cooldown.x, throw_cooldown.y)
	_begin_throw()
	return true


func _begin_throw() -> void:
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(O_THROW)


## Host, waiting its turn in a band ([method PackBrute._await_turn]): an axe
## at him now and then.
func _while_waiting(_delta: float) -> bool:
	if _punish_left > 0.0 and _punish():
		return true
	if _try_cry():
		return true
	if _throw_wait > 0.0 or act != Act.NONE or stamina < attack_cost or _quarry_down() or not _facing_him(30.0):
		return false
	_throw_wait = _rng.randf_range(throw_waiting.x, throw_waiting.y)
	_begin_throw()
	return true


## Host: the axe leaves its hand, onto where he will be.
func _release_axe() -> void:
	if _quarry == null:
		return
	throws_made += 1
	var from := global_position + Vector3.UP * 1.6 * visual_scale
	if _skeleton != null and _skeleton.find_bone(String(throw_hand)) >= 0:
		from = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(String(throw_hand))).origin
	var target := _quarry.global_position + Vector3.UP * 1.1
	var gap := Vector3(target.x - from.x, 0.0, target.z - from.z).length()
	var flight := clampf(gap / 19.0, 0.3, 0.95)
	if _quarry is CharacterBody3D:
		var v := (_quarry as CharacterBody3D).velocity
		target += Vector3(v.x, 0.0, v.z) * flight * 0.5
	var throw_v := (target - from) / flight + Vector3.UP * 0.5 * GoblinShot.GRAVITY * flight
	var id := act_serial * 100 + throws_made
	var worth := hit_damage * throw_share * _blow_worth(O_THROW)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_axe.rpc(from, throw_v, worth, id)
	else:
		net_axe(from, throw_v, worth, id)


@rpc("authority", "call_local", "reliable")
func net_axe(from: Vector3, v: Vector3, worth: float, id: int) -> void:
	GoblinShot.throw(Blood.world_of(self), from, v, GoblinShot.Kind.AXE, worth, self, _decides(), id)
	Sfx.play(self, WHOOSH, null, from, 1.3, -2.0)


func _facing_him(most: float) -> bool:
	var to := _quarry.global_position - global_position
	to.y = 0.0
	return to.length_squared() < 0.0001 or rad_to_deg(_forward().angle_to(to.normalized())) <= most


## Host: his flask at his lips, or a spell just cast (Elden Ring's punish).
func _watch_for_openings(delta: float) -> void:
	_punish_left = maxf(_punish_left - delta, 0.0)
	var hero := _quarry as Player
	if hero == null or hero.is_dead:
		return
	if _seen_casts >= 0 and hero.net_casts != _seen_casts:
		_punish_left = 1.0
	_seen_casts = hero.net_casts
	if hero.drinking():
		_punish_left = maxf(_punish_left, 0.5)


## Host: at him at once, by the gap.
func _punish() -> bool:
	var gap := _distance_to(_quarry)
	if gap > punish_reach or stamina < attack_cost or _quarry_down():
		return false
	_punish_left = 0.0
	_cooldown = 0.0
	# turned on him at once
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	var took := false
	if gap >= charge_from:
		_charge_wait = 0.0
		took = _try_charge() or _try_throw()
	elif gap >= lunge_from:
		_lunge_wait = 0.0
		took = _try_lunge()
	else:
		var keep := hand_combo_chance
		hand_combo_chance = Vector2.ONE
		took = _try_hand_combo(gap)
		hand_combo_chance = keep
		if not took:
			# no combo from here: a plain cut, at once
			_begin_attack()
			took = act != Act.NONE
	if took:
		punishes_made += 1
	return took


func _run_act(delta: float) -> void:
	var was := act
	var t0 := _act_time - delta
	super(delta)
	if is_dead or not _decides() or act != was:
		return
	if was == O_CHARGE and not _charge_met and _quarry != null and _act_time <= charge_time + 0.1:
		_charge_into_him()
	elif was == O_CRY and _crossed(O_CRY, cry_at, t0):
		_cry()
	elif was == O_THROW and _crossed(O_THROW, throw_at, t0):
		_release_axe()


## Whether the act's clock passed the share `at` of its clip this frame.
func _crossed(what: int, at: float, t0: float) -> bool:
	var m: Array = _moves_table[what]
	var length := _anim.clip_length(m[0]) if _anim != null else 1.0
	var when := (at - float(m[2])) * length / maxf(float(m[1]), 0.01)
	return t0 < when and _act_time >= when


func _physics_process(delta: float) -> void:
	super(delta)
	if _decides():
		_watch_for_openings(delta)
		_cry_wait = maxf(_cry_wait - delta, 0.0)
		_charge_wait = maxf(_charge_wait - delta, 0.0)
		_throw_wait = maxf(_throw_wait - delta, 0.0)
	if _bold_left > 0.0 and _decides():
		_bold_left -= delta
		if _bold_left <= 0.0:
			_calm_down()


## Every peer: its voice and its blade's rush; the light on its chest.
func _process(delta: float) -> void:
	super(delta)
	if _bold_light != null:
		_bold_shown = maxf(_bold_shown - delta, 0.0)
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0)
		_bold_light.light_energy = 0.0 if is_dead or _bold_shown <= 0.0 else (0.8 + 0.6 * beat) * minf(_bold_shown, 1.0)
	if act_serial != _voiced_serial:
		_voiced_serial = act_serial
		_voiced_clock = 0.0
		_voiced_whoosh = 0
		if not is_dead and _strikes_table.has(act) and randf() < 0.45:
			Sfx.play_any(self, GRUNTS, self, VOICE * randf_range(0.95, 1.08), -4.0)
		if act == O_BRACE:
			Sfx.play_any(self, GRUNTS, self, VOICE * 0.9, 0.0)
	else:
		_voiced_clock += delta
	if is_dead or not _strikes_table.has(act):
		return
	var ms := _blow_moments(act)
	if _voiced_whoosh < ms.size() and _voiced_clock >= ms[_voiced_whoosh] - 0.12:
		var heavy := act in [O_DOWN, O_POWER, O_DSLASH, O_SPIN, O_CHARGE]
		Sfx.play(self, WHOOSH_HEAVY if heavy else WHOOSH, self, Vector3.UP * 1.4 * visual_scale,
				randf_range(1.15, 1.35), -5.0)
		_voiced_whoosh += 1


## Every peer: enraged it draws a second blade into its left hand (the user's
## word, 2026-10-13: rage looks).
func _glow_on() -> void:
	super()
	_draw_second(true)


func _glow_off() -> void:
	super()
	_draw_second(false)


func _draw_second(out: bool) -> void:
	if _second == null and out:
		_second = _make_second()
	if _second != null:
		_second.visible = out
#endregion


## Its falchion again, in its left hand: the right one's mesh, put where its
## skin binds it to the right hand, but on the left.
func _make_second() -> Node3D:
	if _skeleton == null or body == null:
		return null
	var blade: MeshInstance3D = null
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).contains("Sword") and mi.visible and mi.skin != null:
			blade = mi
			break
	if blade == null or _skeleton.find_bone(second_bone) < 0:
		return null
	var bind := Transform3D.IDENTITY
	var found := false
	for i in blade.skin.get_bind_count():
		var bone := blade.skin.get_bind_bone(i)
		var name := String(blade.skin.get_bind_name(i))
		if name == String(weapon_bone) or (bone >= 0 and _skeleton.get_bone_name(bone) == String(weapon_bone)):
			bind = blade.skin.get_bind_pose(i)
			found = true
			break
	if not found:
		return null
	var hold := BoneAttachment3D.new()
	hold.bone_name = second_bone
	_skeleton.add_child(hold)
	var copy := MeshInstance3D.new()
	copy.mesh = blade.mesh
	for k in blade.get_surface_override_material_count():
		copy.set_surface_override_material(k, blade.get_surface_override_material(k))
	copy.material_override = blade.material_override
	copy.transform = second_turn * bind
	hold.add_child(copy)
	return hold
