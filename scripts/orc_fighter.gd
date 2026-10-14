class_name OrcFighter
extends PackBrute

## The orc (Polysplit's Biped Creatures, CREATURES_PACK.md): half again as
## tall as a man, a falchion in each hand — a raider, quick and dirty, nothing
## like the ogre (the user's word, 2026-10-13: "it must not look like the
## ogre's combos"; none of the ogre's clips is its own).
##
## * **Two blades** (`second_bone`): its falchion again in its left hand,
##   always; its cuts come from either hand and from both at once
##   (`_limbs` L / BOTH), strings that change hands Elden Ring's way.
## * **Its guard** (the Fighter's block, `block_clip` crossed blades): him
##   swinging at it within `react_range`, it may raise both blades; a cut
##   caught there is turned aside — he reels a breath — and it answers at
##   once with its counter. A heavy blow (his charged or heavy swing) or three
##   caught in a row (`block_cost`) breaks the guard open. A spell goes
##   through it; so does a blow from behind.
## * **Footwork** (`dash_chance`, `sidestep_*`): it steps aside from his
##   swings, and between its strings it circles and steps in and out.
## * **Dirty**: the hilt in his face (a "guard" blow), a boot through his
##   shield, the shoulder charge, the thrown axe.
## * **The leap** ([PackBrute]) and the leaping cuts (`Sword_Aerial`): from
##   off it is on him in one bound, both cuts on the way down.
## * **Rage** ([PackBrute]): cut to half its health it roars, glows red, comes
##   on quicker and hits harder; and the frenzy among its combos.
## * **Skills, each with its tell** (2026-10-13):
##   - **the war cry** (`SS_Power_Up`): it and every orc within `cry_range`
##     emboldened for `cry_time` s.
##   - **the shoulder charge**: `CR_Call`'s start as its tell, then
##     `CR_ShieldDash` driven at him.
##   - **the thrown axe** (`CR_Throw`, [GoblinShot] AXE): a stagger.
##   - **punished**: a flask drunk or a spell cast within `punish_reach`.
## * **Its bearing** (`taunt_*`): him down or drinking far off, it twirls its
##   blades at him (`SS_Sword_Play_Idle`) instead of rushing in; first roused,
##   it draws both (`KV_UnsheatheHips01_Both`). Badly hurt and alone it backs
##   off a while.

## Its part in a band (2026-10-13): "duelist" (in close, blades and
## guard), "skirmisher" (keeps `keep_off` m off him and throws, in only when
## he turns away or comes on), "chief" (bigger, roars its kin on more often).
@export var role: StringName = &"duelist"
## The skirmisher's distance from him (0: it comes in like any).
@export var keep_off: float = 0.0

@export_group("Kick")
@export var kick_clip: StringName = &"CR_KickL"
@export var kick_part: Vector3 = Vector3(1.1, 0.1, 0.8)
@export var kick_limbs: String = "L_knee_joint>L_toe_joint:0.15"
## How long he must hold his shield up in front of it before it kicks.
@export var kick_after: float = 0.35
@export var kick_cooldown: float = 3.0
@export var kick_share: float = 0.6

@export_group("Lunge")
## From how far it lunges at him (m), and how often.
@export var lunge_from: float = 4.0
@export var lunge_to: float = 7.0
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
@export var throw_from: float = 7.0
@export var throw_to: float = 18.0
@export var throw_cooldown: Vector2 = Vector2(4.5, 8.0)
## Waiting its turn in a band, it throws now and then (s between).
@export var throw_waiting: Vector2 = Vector2(3.5, 6.0)
@export var throw_share: float = 0.55
## Where in its clip the axe leaves its hand (share).
@export var throw_at: float = 0.25
@export var throw_hand: StringName = &"R_wrist_joint"
@export_group("Rage")
## The bone its second blade is held by while it rages, and how it is turned
## there against the right hand's hold.
@export var second_bone: String = "L_equip_joint"
@export var second_turn: Transform3D = Transform3D(Basis(Vector3.FORWARD, PI), Vector3.ZERO)
## The left blade's end, in its bone (the right's `weapon_tip`, turned).
@export var second_tip: Vector3 = Vector3(-1.1, 0.0, 0.0)
@export_group("Punish")
@export var punish_reach: float = 14.0
@export_group("Pace")
## The least time from a cut's start to its blow (s).
@export var windup_least: float = 0.62
## From the top of a drawn-out wind-up down to its blow this much quicker
## than its clip (heavy up, fast down).
@export var swing_snap: float = 1.35
## After a combo of its, so long before the next (s): his window to answer.
@export var combo_rest: Vector2 = Vector2(1.3, 2.0)
@export_group("Guard")
## The chance it raises its blades to his swing (the rest: a step aside, or
## it takes it), and how much of his blade's worth he feels turned aside.
@export var counter_chance: float = 1.0
## Its guard held no longer than this at a stretch (s).
@export var guard_most: float = 1.6
## After a string of its, the chance it steps out of reach, aside or back.
@export var sidestep_after: float = 0.45
@export_group("Turns")
## Waiting its turn in a pair (`pack_turns` 1), every so often it comes in for
## `join_for` s all the same, so now and then both are on him.
@export var join_every: Vector2 = Vector2(9.0, 15.0)
@export var join_for: float = 3.5
@export_group("Arms")
## What it holds (2026-10-14, the user's word: our weapons on the monsters
## too, picked on the arena's board): one of Polysplit's Advanced Weapons
## ([PolysplitLook] `AW`, worn on the mannequin's figure and skinned to the
## same bones) by name — "" its own falchion; on the left, "" the falchion
## again, "none" an empty hand. A weapon for both hands leaves the left empty.
@export var arm_right: String = ""
@export var arm_left: String = ""
## normal, ornate, obsidian, bone (black: obsidian's models, dull)
@export var arm_style: String = "obsidian"
## What it wears over its own gear (OUTFITS): "" its raider's straps and
## steel as they are.
@export var outfit: String = ""
## Its cape (CAPES): "" none.
@export var cape: String = ""
@export_group("Looks")
## Its chest this much wider across, each collarbone set out this far
## (skeleton units) — broader shoulders ([BulkModifier]).
@export var chest_width: float = 1.28
@export var shoulder_out: float = 0.09
## Its skin, paint and blood picked from its name; -1 each to pick (a scene
## or a test can set them).
@export var varied: bool = true
@export var force_skin: int = -1
@export var force_paint: int = -1
@export var force_blood: int = -1
@export var bloody_share: float = 1.0
@export_group("Down on him")
## Him down within reach, now and then it drives a blade down into him.
@export var stab_chance: float = 0.65
@export var stab_share: float = 0.7
@export_group("Bearing")
## How often it stands off and twirls its blades at him, him down or far.
@export var taunt_chance: float = 0.5
@export var taunt_cooldown: Vector2 = Vector2(10.0, 18.0)
## Under this share of its health, its kin gone, it backs off a while.
@export var wary_below: float = 0.22
@export var wary_for: float = 2.5
@export_group("Feints")
## How often its great cuts are held back a beat before they come down.
@export var feint_chance: float = 0.45

const KICK := 112
## Its moves (2026-10-13): none of them the ogre's. R right hand, L left,
## DW both.
const O_R2 := 180
const O_R5 := 181
const O_L1 := 182
const O_L2 := 183
const O_L4 := 184
const O_L5 := 185
const O_DW1 := 186
const O_DW2 := 187
const O_CROSS := 188
const O_LOW := 189
const O_HIGH := 190
const O_HILT := 191
const O_KICKL := 192
const O_AERA := 193
const O_AERB := 194
const O_LIGHTC := 199
const O_DRAW := 200
const O_TAUNT := 201
## Down on him where he lies (2026-10-14).
const O_STAB := 202
## A great weapon's blows (2026-10-14): Kevin's two-handed cuts, UAL 2's
## heavy ones, the slam; a polearm's thrusts and sweeps.
const O_H1 := 203
const O_H2 := 204
const O_H3 := 205
const O_H4 := 206
const O_HA := 207
const O_HB := 208
const O_HC := 209
const O_GP := 210
const O_P1 := 211
const O_P2 := 212
const O_P3 := 213
const O_P4 := 214
## Mixamo's great sword pack (2026-10-14, the user's word: two-handed blows
## and combos fine and telling): its combo slash, the power slash, the low
## slash, the downward one, the high spin.
const O_GSC := 215
const O_GSP := 216
const O_GSL := 217
const O_GSD := 218
const O_GSS := 219
const O_GSSL := 220
const O_GSCR := 221
## Its looks (2026-10-14, the user's word: another colour, blood, more on it):
## the skin's green, picked from its name.
## (the user kept two of six, 2026-10-14: the dark forest green with red
## bands, the swamp brown with the white skull — both bloodied)
const SKINS := [Color(0.20, 0.36, 0.13), Color(0.42, 0.36, 0.15)]
## Its war paint, with its skin: red bands across its eyes, a white skull.
const PAINTS := [&"red_bands", &"white_skull"]
## its slide in at him from off (the user's word, 2026-10-14: no leaping in;
## a sudden slide and a cut): Tariel's low cut, travelling, opens its far combo
const O_LUNGE := O_LOW
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
const COUNTER_COMBO := &"counter"
## Struck at in the middle of its taunt or its drawing: it was waiting for it.
const TRAP_COMBO := &"trap"

var _shield_for: float = 0.0
var _kick_wait: float = 0.0
## The falchion goes in straight after the kick, for this long more.
var _follow_up: float = 0.0
var _lunge_wait: float = 3.0
var _lunge_speed: float = 0.0
var lunges_made: int = 0
var parries_made: int = 0
var counters_made: int = 0
var guard_breaks: int = 0
var taunts_made: int = 0
var _taunt_wait: float = 4.0
var _drawn: bool = false
var _wary_left: float = 0.0
var _wary_wait: float = 0.0
var wary_made: int = 0
var _stand_for: float = 0.0
var _stand_wait: float = 0.0
var _guard_for: float = 0.0
var _join_left: float = 0.0
var _join_wait: float = 8.0
var _waited_seen: float = 0.0
var joins_made: int = 0
var stabs_made: int = 0
var traps_sprung: int = 0
var _trap_now: bool = false
var _stab_wait: float = 0.0
var skin_index: int = 0
var paint_index: int = 0
var bloody: bool = false
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
	# its arms first: their reach is what its blows are measured with
	_equip_arms()
	super()
	_special(KICK, kick_clip, kick_part)
	# Not a blow that fells him by itself.
	_special_strike(KICK, kick_limbs, kick_share, 3)
	_kinds[KICK] = &"guard"
	# broader at the shoulders (the user's word, 2026-10-14)
	if _skeleton != null and chest_width > 1.0:
		var bulk := BulkModifier.new()
		bulk.chest_width = chest_width
		bulk.shoulder_out = shoulder_out
		_skeleton.add_child(bulk)
		_skeleton.move_child(bulk, 0)
	# its left blade, always in hand (its own falchion again, unless it holds
	# another weapon there or none)
	if arm_left == "":
		_draw_second(true)
	var r := ""
	var l := "%s>%s@%s,%s,%s:%s" % [second_bone, second_bone, second_tip.x, second_tip.y, second_tip.z, weapon_radius]
	var both := "%s>%s@%s,%s,%s:%s|%s" % [weapon_bone, weapon_bone, weapon_tip.x, weapon_tip.y, weapon_tip.z,
			weapon_radius, l]
	_hand_move(O_R2, &"CR_Slash2", Vector3(1.0, 0.05, 0.72), 0.5, r)
	_hand_move(O_R5, &"CR_Slash5", Vector3(1.0, 0.0, 0.75), 0.5, r)
	_hand_move(O_L1, &"CR_SlashL1", Vector3(1.0, 0.0, 0.72), 0.5, l)
	_hand_move(O_L2, &"CR_SlashL2", Vector3(1.0, 0.05, 0.75), 0.5, l)
	_hand_move(O_L4, &"CR_SlashL4", Vector3(1.0, 0.1, 0.8), 0.55, l)
	_hand_move(O_L5, &"CR_SlashL5", Vector3(1.0, 0.0, 0.72), 0.5, l)
	_hand_move(O_DW1, &"CR_DW1", Vector3(1.0, 0.1, 0.85), 1.0, both)
	_hand_move(O_DW2, &"CR_DW2", Vector3(1.0, 0.1, 0.85), 1.0, both)
	_hand_move(O_CROSS, &"CR_CrossSlash", Vector3(1.15, 0.2, 0.72), 0.9, r)
	_hand_move(O_LOW, &"CR_LowAttack", Vector3(1.1, 0.2, 0.66), 0.6, r)
	_hand_move(O_HIGH, &"CR_HighAttack", Vector3(1.0, 0.15, 0.7), 1.0, r)
	_hand_move(O_HILT, &"CR_Hilt", Vector3(1.0, 0.05, 0.75), 0.35, "R_wrist_joint>R_wrist_joint:0.4")
	_kinds[O_HILT] = &"guard"
	_hand_move(O_KICKL, &"CR_KickL", Vector3(1.1, 0.1, 0.8), 0.45, "L_knee_joint>L_toe_joint:0.15")
	_kinds[O_KICKL] = &"guard"
	_hand_move(O_AERA, &"CR_AerialA", Vector3(0.75, 0.0, 1.0), 0.8, r)
	_hand_move(O_AERB, &"CR_AerialB", Vector3(1.0, 0.0, 0.95), 1.0, r)
	_peaks_move(O_LIGHTC, &"CR_LightCombo", Vector3(1.05, 0.05, 0.85), 0.45, r, 3)
	_special(O_DRAW, &"CR_DrawBoth", Vector3(1.0, 0.0, 1.0))
	_special(O_TAUNT, &"CR_SwordPlay", Vector3(1.15, 0.05, 0.42))
	# down into him where he lies: the leaping cut's last, the blade down
	_hand_move(O_STAB, &"CR_AerialB", Vector3(0.9, 0.0, 0.95), stab_share, r)
	_kinds[O_STAB] = &"stomp"
	_slow_to[O_STAB] = windup_least
	_snap[O_STAB] = swing_snap
	# every cut drawn back where he can see it (the user's word, 2026-10-14:
	# heavy swings, seen coming; too quick to answer): at least `windup_least`
	# from its start to its blow; the second of a string a little less
	for what: int in [O_R2, O_R5, O_L1, O_L2, O_L4, O_L5, O_DW1, O_DW2, O_CROSS, O_LOW, O_HIGH, O_HILT, O_KICKL,
			O_AERB, O_LIGHTC, KICK]:
		_slow_to[what] = windup_least
		_snap[what] = swing_snap
	for i in attacks.size():
		_slow_to[ATTACK_BASE + i] = windup_least
		_snap[ATTACK_BASE + i] = swing_snap
	# its plain two-bladed thrust throws him down by itself, as in its combos
	# (the user's word: two blades in him and he fell a second after)
	var dw: int = ATTACK_BASE + attacks.find(&"CR_DW1")
	if _strikes_table.has(dw):
		(_strikes_table[dw] as Array)[3] = 1
	# its heavier cuts now and then held at the top (a feint: a roll too early
	# is caught)
	for what: int in [O_HIGH, O_CROSS, O_DW2, O_R2]:
		_holds[what] = [feint_chance, 0.3, 0.65, 0.22]
	_hand_combos = [
		{"name": &"twin_flurry", "moves": [O_R2, O_L2, O_R5, O_L5, O_DW1], "fells": [4], "weight": 1.3},
		{"name": &"low_high", "moves": [O_LOW, O_HIGH], "fells": [1], "weight": 1.0},
		{"name": &"hilt", "moves": [O_R5, O_HILT, O_DW2], "fells": [2], "weight": 0.9},
		{"name": &"kick_cut", "moves": [O_L1, O_KICKL, O_DW1], "fells": [2], "weight": 0.9},
		{"name": &"cross", "moves": [O_L4, O_CROSS], "fells": [1], "weight": 1.0},
		{"name": &"light", "moves": [O_LIGHTC], "fells": [0], "weight": 0.8},
		{"name": LUNGE_COMBO, "moves": [O_LOW, O_DW2], "fells": [1], "weight": 1.0, "far": true},
		{"name": &"frenzy", "moves": [O_L1, O_R2, O_L2, O_R5, O_L5, O_DW2], "fells": [5], "weight": 1.5,
				"rage_only": true},
		{"name": COUNTER_COMBO, "moves": [O_DW1], "fells": [0], "weight": 0.0, "far": true},
		{"name": TRAP_COMBO, "moves": [O_DW2], "fells": [0], "weight": 0.0, "far": true},
	]
	if grip != &"blades":
		_grip_moves()
	_lunge_wait = _rng.randf_range(2.0, lunge_cooldown.x)
	_pick_looks()
	_wear_looks()
	_wear_outfit()
	_special(O_CRY, &"CR_GS_PowerUp" if grip == &"heavy" else &"CR_PowerUp", Vector3(1.1, 0.0, 0.8))
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
		if _spring_trap() or _try_stab(delta):
			return true
		if _try_draw() or _try_taunt(delta) or _wary(delta):
			return true
		if _keep_off(delta):
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
	var in_combo := _hand_combo >= 0
	super(what)
	if what == KICK:
		_cooldown = 0.0
	# a string done: now and then a step out of his reach, aside or back
	if in_combo and _hand_combo < 0 and not is_dead and _decides():
		# its breath between combos: his window (souls-like)
		_cooldown = maxf(_cooldown, _rng.randf_range(combo_rest.x, combo_rest.y))
		if act == Act.NONE and _quarry != null and _rng.randf() < sidestep_after:
			_step_aside(_rng.randf() < 0.5)


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
	# the low cut carries it in itself (shortened to the room, [method
	# _begin]); its wind-up steps it the rest of the way
	_lunge_speed = 0.0
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
	if _hand_combo >= 0 and _strikes_table.has(act) and _quarry != null:
		# a string's cut steps in (or back) to where it lands, through its
		# wind-up, so the string follows him
		var ms := _blow_moments(act)
		if not ms.is_empty() and _act_time < ms[0]:
			var off := _distance_to(_quarry) - float(_strike_from.get(act, strike_off))
			var pace := clampf(off / maxf(ms[0] - _act_time, 0.12), -2.5, 6.0)
			if absf(off) > 0.15:
				return super(delta) + _forward() * pace
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
		# waiting its turn, now and then it comes in for a while all the same
		_join_left = maxf(_join_left - delta, 0.0)
		if turn_waited > _waited_seen:
			_waited_seen = turn_waited
			_join_wait -= delta
			if _join_wait <= 0.0:
				_join_wait = _rng.randf_range(join_every.x, join_every.y)
				_join_left = join_for
				joins_made += 1
		if act == Act.BLOCK:
			_guard_for += delta
		elif _guard_for > 0.0:
			# out of its guard: at him, not standing about
			if _guard_for >= guard_most * 0.5 and not is_dead:
				_cooldown = 0.0
			_guard_for = 0.0
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
		_bold_light.light_energy = 0.0 if is_dead or _bold_shown <= 0.0 else (0.45 + 0.35 * beat) * minf(_bold_shown, 1.0)
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
		var heavy := act in [O_DW1, O_DW2, O_HIGH, O_CROSS, O_CHARGE, O_AERB]
		Sfx.play(self, WHOOSH_HEAVY if heavy else WHOOSH, self, Vector3.UP * 1.4 * visual_scale,
				randf_range(1.15, 1.35), -5.0)
		_voiced_whoosh += 1


## Every peer: its second blade, in its left hand from the first.
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


#region Its own (2026-10-13): two blades, guard and counter, footwork, bearing
## A move of several blows, its blows where its blade moves fastest (the
## last `most` of them in its part).
func _peaks_move(what: int, clip: StringName, part: Vector3, share: float, limbs: String, most: int) -> void:
	var peaks: Array = []
	if _anim != null:
		for p in _anim.measure_peaks(clip, PackedStringArray([String(weapon_bone)]), 0.3, 0.12):
			if p >= part.y + 0.02 and p <= part.z - 0.02:
				peaks.append(p)
	while peaks.size() > most:
		peaks.remove_at(0)
	_hand_move(what, clip, part, share / maxf(float(peaks.size()), 1.0) * 1.6, limbs, peaks)


## Host: a blow caught on its crossed blades is turned aside — he reels a
## breath — and it answers at once; a heavy one breaks its guard open.
func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	var guarding := act == Act.BLOCK and not is_dead and _decides()
	if guarding and not magic and from != null and _heavy_from(from) and _faces(from):
		# his heavy blow through its blades: the guard broken, and it bleeds
		guard_breaks += 1
		_start(Act.BREAK)
		guarding = false
	var bled := super(damage, at, blow, from, magic)
	if guarding and not bled and not is_dead and act == Act.BLOCK and from != null:
		parries_made += 1
		_turn_aside(from)
	return bled


func _faces(from: Node3D) -> bool:
	var to_them := from.global_position - global_position
	to_them.y = 0.0
	return _forward().dot(to_them.normalized()) > 0.0


func _heavy_from(from: Node3D) -> bool:
	var rig: Variant = from.get(&"rig")
	return rig is Object and (rig as Object).has_method(&"is_heavy") and bool((rig as Object).call(&"is_heavy"))


## Host: his blade turned aside — a reel of his — and its counter, at once.
func _turn_aside(from: Node3D) -> void:
	if from.has_method(&"receive_blow") and _distance_to(from) <= reach + 1.0:
		# barely a scratch: the jolt of his blade knocked away
		from.call(&"receive_blow", 1.0, self, 0, 3, act_serial * 10 + 3)
	if counter_chance <= 0.0 or _rng.randf() >= counter_chance or stamina < attack_cost * 0.5:
		return
	var which := _combo_named(COUNTER_COMBO)
	if which < 0:
		return
	counters_made += 1
	_quarry = from
	_cooldown = 0.0
	start_hand_combo(which)


## Host: a cut that carries it far over the ground (Tariel's travelling
## cuts) shortened to the room before him, so it does not run through him and
## out past; and none of them carries it sideways off him.
func _begin(what: int) -> void:
	super(what)
	if not _decides() or _quarry == null or not _strikes_table.has(what):
		return
	var ms := _blow_moments(what)
	if ms.is_empty():
		return
	var clip := _clip_of(what)
	var own := _hips(clip, _clip_time(what, ms[ms.size() - 1])).x - _hips(clip, _clip_time(what, 0.0)).x
	if own < 0.3:
		return
	var room := _distance_to(_quarry) - float(_strike_from.get(what, strike_off)) * 0.35 - 1.2
	_stretch = clampf(room / own, 0.0, 1.0)


func _carry(delta: float) -> Vector3:
	var v := super(delta)
	if _strikes_table.has(act):
		v -= _move_right * v.dot(_move_right)
	return v


## Its hilt and its kick are no swings to bend over (the rest as [PackBrute]).
func _stoop_skip(what: int) -> bool:
	return what == O_KICKL or what == KICK or super(what)


## Host: his swing begun at it: its guard, its step aside — but its guard
## not held on and on while he swings at the air (`guard_most` s, then it
## goes for him).
func _answer_swing(knight: Node3D) -> void:
	if act == Act.BLOCK and _guard_for >= guard_most:
		return
	# struck at in its taunt or its drawing: it was waiting for that — out of
	# the way, and the heavy blow back (the user's word, 2026-10-14)
	if (act == O_TAUNT or act == O_DRAW) and knight != null and not is_dead and _decides() \
			and _distance_to(knight) <= react_range + 1.0:
		_quarry = knight
		_trap_now = true
		traps_sprung += 1
		_step_aside(false)
		if act != Act.DASH:
			# no breath for a bound: straight at him
			_start(Act.NONE)
		return
	super(knight)


## Whose turn: its own while it has joined in (`_join_left`), else as the band.
func _my_turn() -> bool:
	if _join_left > 0.0 and _quarry != null:
		var on_him := 0
		for node in get_tree().get_nodes_in_group(&"enemy"):
			var o := node as OrcFighter
			if o != null and o != self and not o.is_dead and o._quarry == _quarry and o.act != Act.NONE \
					and o._distance_to(_quarry) < o.reach + 2.0:
				on_him += 1
		if on_him < 2:
			return true
	return super()


## Host: out of his reach in a bound, aside or back (its dash, [Fighter]).
func _step_aside(back: bool) -> void:
	if _quarry == null or stamina < dash_cost:
		return
	var to_me := global_position - _quarry.global_position
	to_me.y = 0.0
	if to_me.length_squared() < 0.0001:
		return
	var side := to_me.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_dash_dir = (to_me.normalized() * (1.0 if back else 0.3) + side * (0.25 if back else 0.9)).normalized()
	stamina -= dash_cost
	_regen_wait = regen_delay
	_face(-to_me, 1.0, 1000.0)
	_start(Act.DASH)


## Host: first roused near him, it draws both blades.
func _try_draw() -> bool:
	if _drawn:
		return false
	_drawn = true
	# not with him already in its face
	if _distance_to(_quarry) > sight_range or _distance_to(_quarry) < reach + 1.5 or _quarry_down():
		return false
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(O_DRAW)
	return true


## Host: him down, or drinking far off, it stands and twirls its blades at
## him instead of rushing in, now and then.
func _try_taunt(delta: float) -> bool:
	_taunt_wait = maxf(_taunt_wait - delta, 0.0)
	if _taunt_wait > 0.0 or raging:
		return false
	var hero := _quarry as Player
	var down := _quarry_down()
	var far_drink := hero != null and hero.drinking() and _distance_to(_quarry) > punish_reach
	if not down and not far_drink:
		return false
	_taunt_wait = _rng.randf_range(taunt_cooldown.x, taunt_cooldown.y)
	if _rng.randf() >= taunt_chance:
		return false
	taunts_made += 1
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(O_TAUNT)
	return true


## Host: badly hurt and no kin fighting with it, it backs off him a while
## (`wary_for` s, then not again for a good while), facing him.
func _wary(delta: float) -> bool:
	_wary_wait = maxf(_wary_wait - delta, 0.0)
	if _wary_left > 0.0:
		_wary_left -= delta
	elif raging or _wary_wait > 0.0 or health > max_health * wary_below or _quarry == null:
		return false
	else:
		for node in get_tree().get_nodes_in_group(&"enemy"):
			var o := node as OrcFighter
			if o != null and o != self and not o.is_dead and o._quarry == _quarry:
				return false
		_wary_left = wary_for
		_wary_wait = 14.0
		wary_made += 1
	var away := global_position - _quarry.global_position
	away.y = 0.0
	if away.length() > 7.0:
		return false
	var v := away.normalized() * speed
	velocity.x = move_toward(velocity.x, v.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, v.z, acceleration * delta)
	_face(-away, delta, turn_speed)
	return true
#endregion


#region The skirmisher
## Host: the skirmisher keeps `keep_off` off him, facing him, its axes
## coming; a bound back when he is on it; in to cut only now and then.
func _keep_off(delta: float) -> bool:
	if keep_off <= 0.0 or raging or _quarry_down():
		return false
	var gap := _distance_to(_quarry)
	if _try_throw():
		return true
	if gap >= keep_off:
		# far enough: it waits there, circling a little
		var to := _quarry.global_position - global_position
		to.y = 0.0
		var round_him := to.normalized().cross(Vector3.UP) * 0.8
		velocity.x = move_toward(velocity.x, round_him.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, round_him.z, acceleration * delta)
		_face(to, delta, turn_speed)
		mode = Mode.FIGHT
		return gap < keep_off + 4.0
	if gap < keep_off * 0.45 and stamina >= dash_cost and _rng.randf() < 0.04:
		_step_aside(true)
		return true
	# caught close, it stands and fights a while (as often as not)
	_stand_for = maxf(_stand_for - delta, 0.0)
	if _stand_for > 0.0:
		return false
	if gap <= reach + 0.4 and _stand_wait <= 0.0:
		_stand_wait = 1.5
		if _rng.randf() < 0.5:
			_stand_for = 2.5
			return false
	_stand_wait = maxf(_stand_wait - delta, 0.0)
	var away := global_position - _quarry.global_position
	away.y = 0.0
	var v := away.normalized() * speed * 1.2
	velocity.x = move_toward(velocity.x, v.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, v.z, acceleration * delta)
	_face(-away, delta, turn_speed)
	mode = Mode.FIGHT
	return true
#endregion


#region Down on him, its trap (2026-10-14)
## Host: its bound out of his swing done, the heavy blow back at once.
func _spring_trap() -> bool:
	if not _trap_now or act != Act.NONE:
		return false
	_trap_now = false
	var which := _combo_named(TRAP_COMBO)
	if which < 0 or _quarry_down():
		return false
	_cooldown = 0.0
	start_hand_combo(which)
	return true


## Host: him down within reach, now and then it drives a blade down into him
## (a "stomp" blow: only a man on the ground takes it) — not waiting for him
## to get up.
func _try_stab(delta: float) -> bool:
	_stab_wait = maxf(_stab_wait - delta, 0.0)
	if not _quarry_down() or _stab_wait > 0.0 or stamina < attack_cost:
		return false
	var gap := _distance_to(_quarry)
	var want := float(_strike_from.get(O_STAB, strike_off))
	if gap > want + 4.0:
		return false
	if gap > want + 0.4:
		# in to him
		mode = Mode.FIGHT
		_move_towards(_quarry.global_position, close_speed, delta)
		return true
	_stab_wait = 2.5
	if _rng.randf() >= stab_chance:
		return false
	stabs_made += 1
	mode = Mode.FIGHT
	_face(_quarry.global_position - global_position, 1.0, 50.0)
	_begin(O_STAB)
	return true
#endregion


#region Looks (2026-10-14)
func _pick_looks() -> void:
	if not varied:
		return
	skin_index = force_skin if force_skin >= 0 else posmod(hash(String(name) + "/skin"), SKINS.size())
	paint_index = force_paint if force_paint >= 0 else skin_index
	bloody = force_blood == 1 if force_blood >= 0 \
			else float(posmod(hash(String(name) + "/blood"), 1000)) / 1000.0 < bloody_share


## Every peer: its skin's green, its war paint, the blood on it and its blades.
func _wear_looks() -> void:
	if not varied or body == null:
		return
	var dress := body.get_node_or_null(^"Dress")
	var skin_mat: Material = PackCreature.material(String(dress.get(&"body"))) if dress != null else null
	# (the skirmisher and the chief keep the skins of their own palettes)
	if skin_mat != null and role == &"duelist":
		var mine := (skin_mat as ShaderMaterial).duplicate() as ShaderMaterial
		var c: Color = SKINS[skin_index]
		mine.set_shader_parameter(&"color1", Vector3(c.r, c.g, c.b))
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for i in mi.get_surface_override_material_count():
				if mi.get_surface_override_material(i) == skin_mat:
					mi.set_surface_override_material(i, mine)
	_paint_and_blood.call_deferred()


func _paint_and_blood() -> void:
	if _skeleton == null or not is_inside_tree():
		return
	for m in find_children("*", "GeometryInstance3D", true, false):
		var g := m as GeometryInstance3D
		# (not the pieces worn over its gear: no paint or blood thrown on them)
		if not (g is GPUParticles3D) and not (g is Label3D) and not String(g.name).begins_with("Wear_"):
			g.layers |= Blood.WOUND_LAYER
	var s := visual_scale / 1.6
	var fwd := _forward()
	var paint: StringName = PAINTS[clampi(paint_index, 0, PAINTS.size() - 1)]
	if paint != &"":
		_face_decal("head_joint", _paint_texture(paint), Color.WHITE, Vector3(0.46, 0.7, 0.34) * s,
				fwd * 0.26 * s + Vector3.UP * 0.12 * s, 1.0)
		if paint == &"red_bands":
			# and three red stripes down its chest
			_face_decal("chest_joint", _paint_texture(&"chest_bands"), Color.WHITE, Vector3(0.7, 0.9, 0.8) * s,
					fwd * 0.3 * s, 0.95)
	if bloody:
		_face_decal("chest_joint", Blood.wound_texture(), Color(0.24, 0.0, 0.0), Vector3(0.9, 1.0, 1.1) * s,
				fwd * 0.3 * s + Vector3.DOWN * 0.1 * s, 1.0)
		_face_decal("head_joint", Blood.wound_texture(), Color(0.26, 0.0, 0.0), Vector3(0.45, 0.8, 0.7) * s,
				fwd * 0.28 * s + Vector3.DOWN * 0.14 * s, 1.0)
		_blade_blood(String(weapon_bone), weapon_tip.x)
		if _second != null:
			_blade_blood(second_bone, second_tip.x)


## A decal laid on its front at `bone`, from in front, its runs downward.
func _face_decal(bone_name: String, tex: Texture2D, tint: Color, size: Vector3, off: Vector3, mix: float) -> void:
	var bone := _skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var hold := BoneAttachment3D.new()
	hold.bone_name = bone_name
	_skeleton.add_child(hold)
	var fwd := _forward()
	var y := fwd
	var z := Vector3.DOWN
	var x := y.cross(z).normalized()
	var decal := Decal.new()
	decal.texture_albedo = tex
	decal.modulate = tint
	decal.albedo_mix = mix
	decal.normal_fade = 0.3
	decal.cull_mask = Blood.WOUND_LAYER
	decal.size = size
	hold.add_child(decal)
	var at := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	decal.transform = at.affine_inverse() * Transform3D(Basis(x, y, z), at.origin + off)


## Blood along a blade, both faces.
func _blade_blood(bone_name: String, reach: float) -> void:
	var hold := BoneAttachment3D.new()
	hold.bone_name = bone_name
	_skeleton.add_child(hold)
	for k in 2:
		var decal := Decal.new()
		decal.texture_albedo = Blood.wound_texture()
		decal.modulate = Color(0.24, 0.0, 0.0)
		decal.albedo_mix = 1.0
		decal.normal_fade = 0.0
		decal.cull_mask = Blood.WOUND_LAYER
		decal.upper_fade = 0.1
		decal.lower_fade = 0.1
		decal.size = Vector3(0.45, 0.5, absf(reach) * 0.85)
		hold.add_child(decal)
		var y := Vector3(0, 0, 1) * (1.0 if k == 0 else -1.0)
		var z := Vector3(-1, 0, 0) * signf(reach)
		decal.transform = Transform3D(Basis(y.cross(z), y, z), Vector3(reach * 0.7, 0.0, 0.0))


static var _paints: Dictionary = {}


## Its paint drawn once (64 x 64, the decal's +Z down the image).
static func _paint_texture(which: StringName) -> ImageTexture:
	if _paints.has(which):
		return _paints[which]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for py in n:
		for px in n:
			var u := float(px) / float(n - 1)
			var v := float(py) / float(n - 1)
			var c := Color(0, 0, 0, 0)
			match which:
				&"red_bands":
					# two bands across the eyes and one lower over the mouth
					if (v > 0.30 and v < 0.40) or (v > 0.44 and v < 0.52) or (v > 0.70 and v < 0.75 and absf(u - 0.5) < 0.3):
						c = Color(0.62, 0.05, 0.03, 0.95)
				&"black_mask":
					# a black band over the eyes, ragged at its ends
					var edge := 0.52 + 0.06 * sin(u * 31.0)
					if v > 0.22 and v < edge and absf(u - 0.5) < 0.49:
						c = Color(0.04, 0.04, 0.05, 0.95)
				&"white_skull":
					# white over the brow and down the cheeks, dark round the eyes
					var eye := minf(Vector2(u - 0.33, v - 0.40).length(), Vector2(u - 0.67, v - 0.40).length())
					if eye < 0.09:
						c = Color(0.05, 0.04, 0.04, 0.95)
					elif v > 0.2 and v < 0.62 and absf(u - 0.5) < 0.42:
						c = Color(0.86, 0.83, 0.76, 0.9)
					elif v >= 0.62 and v < 0.8 and absf(u - 0.5) < 0.42 and fmod(u * 10.0, 1.0) < 0.5:
						c = Color(0.86, 0.83, 0.76, 0.9)
				&"chest_bands":
					# three red stripes, slanting
					var w := fmod(u * 3.0 + v * 0.6, 1.0)
					if w < 0.28 and v > 0.1 and v < 0.9:
						c = Color(0.6, 0.05, 0.03, 0.9)
			img.set_pixel(px, py, c)
	var tex := ImageTexture.create_from_image(img)
	_paints[which] = tex
	return tex
#endregion


#region Arms (2026-10-14)
const ARMS_FIGURE := "res://assets/polysplit/mannequin_m.glb"
## What it may hold, by hand (PolysplitLook.AW names).
const RIGHT_ARMS := ["", "shortsword", "longsword", "curvedsword", "greatsword", "curvedgreatsword", "axe",
		"greataxe", "hammer", "greathammer", "mace", "morningstar", "flail", "spear", "poleaxe", "dagger"]
## (the left hand may hold any one-handed weapon the right may: the same
## in both, the user's word, 2026-10-14; one the pack made only for the right
## hand is turned over into the left as its own falchion is)
const LEFT_ARMS := ["", "none", "shortsword", "longsword", "curvedsword", "axe", "hammer", "mace", "morningstar",
		"flail", "dagger"]
const ARM_STYLES := ["normal", "ornate", "obsidian", "black", "bone"]
## The figure's weapons are a man's; in an orc's fist they are this much bigger.
const ARM_SIZE := 1.45
## ...save the great swords, long already (the user's word, 2026-10-14: too
## long; it should reach him from off with it, not walk in).
const ARM_SIZES := {"greatsword": 1.15, "curvedgreatsword": 1.15}
## A great weapon: its blows from this far out along the reach that lands
## (0.5 the middle, 1 its very tip).
const FAR_SHARE := 0.78
static var _figure: Node3D
## How it holds what it holds: blades (one in a hand), heavy (a great weapon
## in both), pole (a spear or a poleaxe).
var grip: StringName = &"blades"


## Before its parts are read: a great weapon carried on its shoulder at rest,
## held in both hands roused, its guard and its plain blows that weapon's.
func _grip_stance() -> void:
	var heavy := grip == &"heavy"
	idle_clip = &"CR_Shoulder" if heavy else &"CR_HoldPole"
	fidget_clip = idle_clip
	# (roused, Mixamo's great sword stance, walk and run: the sword held
	# before it, facing where it goes)
	guard_idle_clip = &"CR_GS_Idle" if heavy else &"CR_PoleIdle"
	block_clip = &"CR_GS_Block" if heavy else &"CR_ParryPole"
	# its feet the same, its arms holding the weapon as they go
	walk_clip = &"CR_ShoulderWalk" if heavy else &"CR_PoleWalk"
	roused_walk_clip = &"CR_GS_Walk" if heavy else &"CR_PoleGuardWalk"
	run_clip = &"CR_GS_Run" if heavy else &"CR_PoleRun"
	back_clip = &"CR_GS_WalkBack" if heavy else &"CR_PoleBack"
	strafe_l_clip = &"CR_GS_StrafeL" if heavy else &"CR_PoleL"
	strafe_r_clip = &"CR_GS_StrafeR" if heavy else &"CR_PoleR"
	if heavy:
		back_run_clip = &"CR_GS_RunBack"
		hit_clip = &"CR_GS_HeadImpact"
	var loops := Array(loop_clips)
	for c: StringName in [idle_clip, guard_idle_clip, block_clip, walk_clip, roused_walk_clip, run_clip, back_clip,
			strafe_l_clip, strafe_r_clip, back_run_clip]:
		if c == &"":
			continue
		if not loops.has(String(c)):
			loops.append(String(c))
	loop_clips = PackedStringArray(loops)
	var plain: Array[StringName] = [&"CR_Polearm1", &"CR_Polearm2", &"CR_Polearm3"]
	if heavy:
		plain = [&"CR_Heavy1", &"CR_Heavy2", &"CR_Heavy3"]
	attacks = plain
	var parts: Array[Vector3] = []
	var limbs := PackedStringArray()
	var blows := PackedInt32Array()
	for c in plain:
		parts.append(Vector3(1.0, 0.0, 0.85))
		limbs.append("")
		blows.append(1)
	attack_parts = parts
	attack_limbs = limbs
	attack_blows = blows
	attack_clip = plain[0]


## After its own moves: a great weapon's or a polearm's in their place —
## their own strings, counter and trap, drawn from its back.
func _grip_moves() -> void:
	var r := ""
	var heavy := grip == &"heavy"
	var moves: Array[int] = []
	if heavy:
		_hand_move(O_H1, &"CR_Heavy1", Vector3(1.0, 0.0, 0.85), 1.0, r)
		_hand_move(O_H2, &"CR_Heavy2", Vector3(1.0, 0.0, 0.85), 1.0, r)
		_hand_move(O_H3, &"CR_Heavy3", Vector3(1.0, 0.0, 0.85), 1.0, r)
		_hand_move(O_H4, &"CR_Heavy4", Vector3(1.0, 0.0, 0.85), 1.1, r)
		_hand_move(O_HA, &"CR_HeavyA", Vector3(1.0, 0.0, 1.0), 0.9, r)
		_hand_move(O_HB, &"CR_HeavyB", Vector3(1.0, 0.0, 1.0), 0.9, r)
		_hand_move(O_HC, &"CR_HeavyC", Vector3(1.0, 0.0, 1.0), 1.0, r)
		_hand_move(O_GP, &"CR_GroundPound", Vector3(1.0, 0.0, 0.9), 1.2, r)
		# the great sword's own, a man's sword-work at an orc's weight
		_peaks_move(O_GSC, &"CR_OG_Combo_Slash", Vector3(0.95, 0.05, 0.88), 0.55, r, 3)
		_hand_move(O_GSP, &"CR_OG_Power_Slash", Vector3(0.95, 0.05, 0.85), 1.2, r)
		_hand_move(O_GSL, &"CR_OG_Low_Slash", Vector3(1.0, 0.05, 0.8), 0.8, r)
		_hand_move(O_GSD, &"CR_OG_Downward_Slash", Vector3(0.95, 0.05, 0.85), 1.1, r)
		_hand_move(O_GSS, &"CR_GS_HighSpin", Vector3(1.05, 0.05, 0.85), 1.1, r)
		_hand_move(O_GSSL, &"CR_GS_Slide", Vector3(1.0, 0.0, 0.85), 0.9, r)
		_hand_move(O_GSCR, &"CR_GS_CrouchSlash", Vector3(1.0, 0.05, 0.85), 0.8, r)
		# the pommel in his face (its own, the sword's)
		_hand_move(O_HILT, &"CR_GS_Hilt", Vector3(1.0, 0.05, 0.8), 0.35, "R_wrist_joint>R_wrist_joint:0.45")
		_kinds[O_HILT] = &"guard"
		moves = [O_H1, O_H2, O_H3, O_H4, O_HA, O_HB, O_HC, O_GP, O_GSC, O_GSP, O_GSL, O_GSD, O_GSS, O_GSSL, O_GSCR, O_HILT]
		_special(O_DRAW, &"CR_Enter2H", Vector3(1.0, 0.0, 1.0))
		_special(O_TAUNT, &"CR_GS_Pose", Vector3(1.0, 0.0, 1.0))
		_hand_combos = [
			# a wide cut, back the other way, and down through him
			{"name": &"cleave", "moves": [O_GSL, O_H2, O_GSD], "fells": [2], "weight": 1.3},
			# a slow wind-up, the whole weight in one cut
			{"name": &"power", "moves": [O_H1, O_GSP], "fells": [1], "weight": 1.0},
			{"name": &"heavy_string", "moves": [O_HA, O_HB, O_HC], "fells": [2], "weight": 0.9},
			{"name": &"sweep_slam", "moves": [O_H3, O_GP], "fells": [1], "weight": 0.9},
			{"name": &"turn_cleave", "moves": [O_H2, O_KICKL, O_H4], "fells": [2], "weight": 0.7},
			{"name": &"hilt", "moves": [O_H1, O_HILT, O_GSD], "fells": [2], "weight": 0.8},
			# low across his legs, up again, and the whole weight down
			{"name": &"low_rise", "moves": [O_GSCR, O_GSP], "fells": [1], "weight": 0.9},
			# from off: the slide in under him, then the cut down
			{"name": LUNGE_COMBO, "moves": [O_GSSL, O_GSD], "fells": [1], "weight": 1.0, "far": true},
			# the spinning cut that carries it through him, and the slam
			{"name": &"whirl", "moves": [O_GSS, O_GP], "fells": [1], "weight": 0.9},
			{"name": &"frenzy", "moves": [O_GSL, O_H2, O_GSS, O_GP], "fells": [3], "weight": 1.5,
					"rage_only": true},
			{"name": COUNTER_COMBO, "moves": [O_H1], "fells": [0], "weight": 0.0, "far": true},
			{"name": TRAP_COMBO, "moves": [O_GSP], "fells": [0], "weight": 0.0, "far": true},
		]
	else:
		_hand_move(O_P1, &"CR_Polearm1", Vector3(1.0, 0.0, 0.85), 0.9, r)
		_hand_move(O_P2, &"CR_Polearm2", Vector3(1.0, 0.0, 0.85), 0.9, r)
		_hand_move(O_P3, &"CR_Polearm3", Vector3(1.0, 0.0, 0.85), 1.0, r)
		_hand_move(O_P4, &"CR_Polearm4", Vector3(1.0, 0.0, 0.85), 1.1, r)
		moves = [O_P1, O_P2, O_P3, O_P4]
		_special(O_DRAW, &"CR_EnterPole", Vector3(1.0, 0.0, 1.0))
		_hand_combos = [
			{"name": &"thrusts", "moves": [O_P1, O_P2], "fells": [1], "weight": 1.3},
			{"name": &"sweeps", "moves": [O_P3, O_P4], "fells": [1], "weight": 1.1},
			{"name": &"long", "moves": [O_P1, O_P3, O_P2, O_P4], "fells": [3], "weight": 0.8},
			{"name": &"kick_thrust", "moves": [O_P2, O_KICKL, O_P4], "fells": [2], "weight": 0.8},
			{"name": LUNGE_COMBO, "moves": [O_P2], "fells": [0], "weight": 1.0, "far": true},
			{"name": &"frenzy", "moves": [O_P1, O_P2, O_P3, O_P4, O_P1], "fells": [4], "weight": 1.5,
					"rage_only": true},
			{"name": COUNTER_COMBO, "moves": [O_P1], "fells": [0], "weight": 0.0, "far": true},
			{"name": TRAP_COMBO, "moves": [O_P4], "fells": [0], "weight": 0.0, "far": true},
		]
	for what: int in moves:
		_slow_to[what] = windup_least
		_snap[what] = swing_snap
	_holds[moves[0]] = [feint_chance, 0.3, 0.65, 0.22]
	# down into him where he lies: the great weapon's overhead
	_hand_move(O_STAB, &"CR_Heavy4" if heavy else &"CR_Polearm1", Vector3(1.0, 0.0, 0.85), stab_share, r)
	_kinds[O_STAB] = &"stomp"
	_slow_to[O_STAB] = windup_least
	_snap[O_STAB] = swing_snap


## Before its blows are measured: the weapons it holds put in its hands, the
## reach of each taken from the weapon (its farthest point from the hand).
func _equip_arms() -> void:
	if arm_right == "" and arm_left == "":
		return
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D if body != null else null
	if skel == null:
		return
	var own := body.find_child("Orc_Sword", true, false) as MeshInstance3D
	var two_hands := false
	if arm_right != "":
		var kind: StringName = PolysplitLook.AW.get(arm_right, {}).get("kind", &"sword")
		two_hands = kind == &"two_hands" or kind == &"spear"
		var tip := _put_in_hand(skel, own, "ps_w_aw_%s_%s" % [arm_right, PolysplitLook.STYLE_MODELS.get(arm_style, arm_style)],
				String(weapon_bone), float(ARM_SIZES.get(arm_right, ARM_SIZE)))
		if tip != Vector3.ZERO:
			weapon_tip = tip
			if own != null:
				own.visible = false
			if arm_right in ["hammer", "greathammer", "mace", "morningstar", "flail"]:
				weapon_radius = 0.2
	if two_hands:
		grip = &"pole" if PolysplitLook.AW.get(arm_right, {}).get("kind", &"") == &"spear" else &"heavy"
		_grip_stance()
		# its reach the weapon's: it strikes from where the blade's far part
		# meets him, and stops short there
		var long := weapon_tip.length() * visual_scale
		strike_off = maxf(strike_off, long * 0.95)
		reach = maxf(reach, strike_off + 0.9)
		strike_far = FAR_SHARE
	if two_hands and arm_left == "":
		arm_left = "none"
	if arm_left == "none":
		# an empty left hand: its fist
		second_tip = Vector3(0.25, 0.0, 0.0)
	elif arm_left != "":
		var style: String = PolysplitLook.STYLE_MODELS.get(arm_style, arm_style)
		var tip := _put_in_hand(skel, own, "ps_o_aw_%s_%s" % [arm_left, style], second_bone)
		if tip == Vector3.ZERO:
			tip = _turn_into_left(skel, "ps_w_aw_%s_%s" % [arm_left, style])
		if tip != Vector3.ZERO:
			second_tip = tip
	# the scene's own blows name the falchions' reach: theirs now
	var r_at := "@%s,%s,%s:" % [weapon_tip.x, weapon_tip.y, weapon_tip.z]
	var l_at := "@%s,%s,%s:" % [second_tip.x, second_tip.y, second_tip.z]
	var limbs := PackedStringArray()
	for spec in attack_limbs:
		limbs.append(spec.replace("@1.1,0,0:", r_at).replace("@-1.1,0,0:", l_at))
	attack_limbs = limbs
	leap_limbs = leap_limbs.replace("@1.1,0,0:", r_at)


## The right hand's weapon `mesh_name` in the left: unskinned, held on the
## left hand where it rests on the right, turned over (`second_turn`); its
## farthest point from the hand in the left hand's frame.
func _turn_into_left(skel: Skeleton3D, mesh_name: String) -> Vector3:
	if _figure == null:
		var scene := load(ARMS_FIGURE) as PackedScene
		if scene == null:
			return Vector3.ZERO
		_figure = scene.instantiate() as Node3D
	var src := _figure.find_child(mesh_name, true, false) as MeshInstance3D
	var fig := src.get_node_or_null(src.skeleton) as Skeleton3D if src != null and src.skin != null else null
	if fig == null or skel.find_bone(second_bone) < 0:
		return Vector3.ZERO
	# the bone it is weighted to (the figure's weapon_r) and where that rests
	# on the right hand
	var held := -1
	var bind := Transform3D.IDENTITY
	for i in src.skin.get_bind_count():
		if String(src.skin.get_bind_name(i)).begins_with("weapon"):
			held = fig.find_bone(String(src.skin.get_bind_name(i)))
			bind = src.skin.get_bind_pose(i)
	var hand := fig.find_bone(String(weapon_bone))
	if held < 0 or hand < 0:
		return Vector3.ZERO
	var on_hand := fig.get_bone_global_rest(hand).affine_inverse() * fig.get_bone_global_rest(held) * bind
	var bigger := Transform3D(Basis.from_scale(Vector3.ONE * ARM_SIZE), Vector3.ZERO)
	var place := second_turn * bigger * on_hand
	var hold := BoneAttachment3D.new()
	hold.name = "LeftArm"
	hold.bone_name = second_bone
	skel.add_child(hold)
	var mi := MeshInstance3D.new()
	mi.name = "Arm_" + mesh_name + "_left"
	mi.mesh = src.mesh
	mi.transform = place
	var mat := src.get_active_material(0)
	var albedo: Texture2D = (mat as StandardMaterial3D).albedo_texture if mat is StandardMaterial3D else null
	if albedo != null:
		mi.material_override = PolysplitLook.aw_material(arm_style, albedo)
	hold.add_child(mi)
	var box := src.mesh.get_aabb()
	var far := Vector3.ZERO
	for k in 8:
		var p := place * box.get_endpoint(k)
		if p.length() > far.length():
			far = p
	return far * 0.92


## `src`'s skin made for `skel`: a bone it lacks (the figure's weapon_r and
## weapon_l, its coat tails) bound to the nearest of its forebears it has,
## where it rests on that one; all of it `size` bigger about each bone.
func _rebound(src: MeshInstance3D, skel: Skeleton3D, size: float) -> Skin:
	var skin := src.skin.duplicate() as Skin
	var fig := src.get_node_or_null(src.skeleton) as Skeleton3D
	var bigger := Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3.ZERO)
	for i in skin.get_bind_count():
		var name := String(skin.get_bind_name(i))
		var bind := skin.get_bind_pose(i)
		if skel.find_bone(name) < 0:
			var b := fig.find_bone(name) if fig != null else -1
			var rel := Transform3D.IDENTITY
			while b >= 0 and skel.find_bone(fig.get_bone_name(b)) < 0:
				rel = fig.get_bone_rest(b) * rel
				b = fig.get_bone_parent(b)
			name = fig.get_bone_name(b) if b >= 0 else "pelvis_joint"
			bind = rel * bind
			skin.set_bind_name(i, StringName(name))
		skin.set_bind_pose(i, bigger * bind)
	return skin


## The figure's weapon mesh `mesh_name` skinned to this skeleton (bound by
## bone name; a bind with no bone here goes to the pelvis — no weapon is
## weighted to one), next to its own meshes; the weapon's farthest point
## from `bone` in that bone's frame (ZERO if there is no such mesh).
func _put_in_hand(skel: Skeleton3D, beside: MeshInstance3D, mesh_name: String, bone: String,
		size: float = ARM_SIZE) -> Vector3:
	if _figure == null:
		var scene := load(ARMS_FIGURE) as PackedScene
		if scene == null:
			return Vector3.ZERO
		_figure = scene.instantiate() as Node3D
	var src := _figure.find_child(mesh_name, true, false) as MeshInstance3D
	if src == null or src.skin == null:
		return Vector3.ZERO
	var skin := _rebound(src, skel, size)
	var hand_bind := Transform3D.IDENTITY
	for i in skin.get_bind_count():
		if String(skin.get_bind_name(i)) == bone:
			hand_bind = skin.get_bind_pose(i)
	var mi := MeshInstance3D.new()
	mi.name = "Arm_" + mesh_name
	mi.mesh = src.mesh
	mi.skin = skin
	var parent := beside.get_parent() if beside != null else skel.get_parent()
	parent.add_child(mi)
	mi.transform = beside.transform if beside != null else Transform3D.IDENTITY
	mi.skeleton = mi.get_path_to(skel)
	var mat := src.get_active_material(0)
	var albedo: Texture2D = (mat as StandardMaterial3D).albedo_texture if mat is StandardMaterial3D else null
	if albedo != null:
		mi.material_override = PolysplitLook.aw_material(arm_style, albedo)
	# its reach: the farthest corner of it from the hand, in the hand's frame
	var box := src.mesh.get_aabb()
	var far := Vector3.ZERO
	for k in 8:
		var p := hand_bind * box.get_endpoint(k)
		if p.length() > far.length():
			far = p
	return far * 0.92
#endregion



#region Outfits (2026-10-14)
## Darker gear for it, the user's word: brutal, fine and fearsome, Elden
## Ring's colours — blackened and rusted iron, black leather, old crimson —
## and the mannequin's pieces worn over its own (a piece: mesh, how much
## bigger than a man's, its tint).
const OUTFITS := {
	"": {"objects": "", "pieces": []},
	"Ashen": {"objects": "Objects_OrcAshen", "pieces": []},
	"Rust": {"objects": "Objects_OrcRust", "pieces": [["ps_x_knight_pauldrons", 1.3, Color(0.5, 0.27, 0.16)]]},
	"Iron hood": {"objects": "Objects_OrcAshen", "pieces": [["ps_x_knight_pauldrons", 1.3, Color(0.3, 0.3, 0.32)],
			["ps_hat_hood", 1.35, Color(0.32, 0.08, 0.08)]]},
	"Warlord": {"objects": "Objects_OrcAshen", "pieces": [["ps_x_knight_pauldrons", 1.3, Color(0.42, 0.36, 0.26)],
			["ps_hat_greathelm", 1.4, Color(0.34, 0.33, 0.34)]]},
}
## Its cape, worn with any gear or none (the user's word, 2026-10-14: the
## cape on its own): [the mannequin's piece, how much bigger, its tint].
const CAPES := {
	"": [],
	"Black cape": ["ps_x_warlock_cape", 1.3, Color(0.05, 0.045, 0.05)],
	"Crimson cape": ["ps_x_warlock_cape", 1.3, Color(0.34, 0.025, 0.035)],
	"Hide cape": ["ps_x_archer_cape", 1.3, Color(0.24, 0.14, 0.07)],
	"Grey mantle": ["ps_x_sorcerer_cloak", 1.3, Color(0.17, 0.17, 0.16)],
}


func _wear_outfit() -> void:
	if body == null or _skeleton == null:
		return
	var c: Array = CAPES.get(cape, [])
	if not c.is_empty():
		_wear_piece(String(c[0]), float(c[1]), c[2], body.find_child("Orc_Head", true, false) as MeshInstance3D, true)
	var o: Dictionary = OUTFITS.get(outfit, {})
	if o.is_empty():
		return
	var dress := body.get_node_or_null(^"Dress")
	if String(o["objects"]) != "" and dress != null:
		var old: Material = PackCreature.material(String(dress.get(&"objects")))
		var new: Material = PackCreature.material(String(o["objects"]))
		for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			for i in mi.get_surface_override_material_count():
				if mi.get_surface_override_material(i) == old:
					mi.set_surface_override_material(i, new)
	var beside := body.find_child("Orc_Head", true, false) as MeshInstance3D
	for piece: Array in o["pieces"]:
		_wear_piece(String(piece[0]), float(piece[1]), piece[2], beside)


## One of the mannequin's pieces on it, made `size` bigger about each bone it
## hangs on and tinted.
func _wear_piece(mesh_name: String, size: float, tint: Color, beside: MeshInstance3D, flat: bool = false) -> void:
	if _figure == null:
		var scene := load(ARMS_FIGURE) as PackedScene
		if scene == null:
			return
		_figure = scene.instantiate() as Node3D
	var src := _figure.find_child(mesh_name, true, false) as MeshInstance3D
	if src == null or src.skin == null:
		return
	var skin := _rebound(src, _skeleton, size)
	var mi := MeshInstance3D.new()
	mi.name = "Wear_" + mesh_name
	mi.mesh = src.mesh
	mi.skin = skin
	var parent := beside.get_parent() if beside != null else _skeleton
	parent.add_child(mi)
	mi.transform = beside.transform if beside != null else Transform3D.IDENTITY
	mi.skeleton = mi.get_path_to(_skeleton)
	for i in src.mesh.get_surface_count():
		var m := src.get_active_material(i)
		if flat:
			# cloth of one colour (its texture would tint it all one blue)
			var cloth := StandardMaterial3D.new()
			cloth.albedo_color = tint
			cloth.roughness = 0.95
			cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.set_surface_override_material(i, cloth)
		elif m is StandardMaterial3D:
			var mine := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			mine.albedo_color = mine.albedo_color * tint
			mi.set_surface_override_material(i, mine)
		elif m is ShaderMaterial:
			mi.set_surface_override_material(i, m)
#endregion
