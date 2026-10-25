class_name TrollFighter
extends PackBrute

## The troll (Polysplit's Biped Creatures, CREATURES_PACK.md): a giant that
## fights with its own body and the ground it stands on (the user's pick,
## 2026-10-25: the other bosses all carry weapons — the ogre a club, the golem
## a maul, the orc an axe, the butcher a cleaver — so the troll none, until it
## tears a tree out of the ground at half its health, and the tree breaks
## under his blows).
##
## **Its first look, bare-handed** (fists closed, [HandFist]):
## * a left jab, a great hook, knees and an uppercut (four blows), a headbutt
##   with a hand on him, a stomp that splits the ground in three lines out in
##   front (no rings), an uppercut chased in from a few steps off;
## * **the grab** (`P_GRAB`): it reaches for him; caught, he is lifted, held up,
##   and slammed into the ground. A roll slips the reach; in co-op the other
##   hero's blows make it let go ([method _receive]);
## * **the tackle** (its leap, [PackBrute]): from off, head down at him;
##   missed, it stumbles;
## * **rocks** ([TrollRock]): a boulder torn out of the ground and thrown over
##   its head; one bowled along the ground at him; three stones one after
##   another. Each is seen in its hands before it goes;
## * at him lying, now and then, it flexes over him.
##
## **Its second look** (at `uproot_at` of its health, once more at
## `uproot_again_at` if the first broke): it tears a tree out of the ground,
## roots and earth and all, and fights with it in both hands: Mixamo's great
## swing and two-handed string, the club string (the one string kept from
## before), the scoop up and the chop down. **The tree breaks**: every blow of
## his on the troll splits it further (two crack stages, splinters flying);
## broken, it bursts in its hands and the troll goes down on its knee, open.
##
## What it keeps from before (2026-10-25, the first passes): slow up and fast
## down (`_slow_to`, `_snap`), delayed swings (`_holds`), a reel after a great
## miss, its balance rocking, staggering and breaking (Elden Ring's stance),
## its body wounded where struck and slower for it, its wounds closing while
## nothing burns or freezes it.

@export_group("Rocks")
@export var rock_from: float = 6.0
@export var rock_to: float = 22.0
@export var rock_cooldown: Vector2 = Vector2(7.0, 11.0)
## Of `hit_damage`: the boulder thrown, the one bowled, each stone.
@export var rock_share: Vector3 = Vector3(1.4, 1.1, 0.45)

@export_group("Grab")
@export var grab_reach: float = 3.0
@export var grab_cooldown: Vector2 = Vector2(10.0, 15.0)
## Of `hit_damage`: the slam.
@export var slam_share: float = 1.9
## Of its health: what the other hero must deal it to make it let go.
@export var grab_free: float = 0.035

@export_group("Tree")
const ROCKS_FILE := "res://assets/creatures/troll_rocks.glb"
@export_range(0.0, 1.0) var uproot_at: float = 0.55
@export_range(0.0, 1.0) var uproot_again_at: float = 0.22
## The tree's size in its hand's frame (a man's; the troll drawn 1.6 times).
@export var tree_scale: float = 0.85
## How far out along its grip the root end reaches, and how thick it strikes.
@export var tree_reach: float = 1.25
@export var tree_radius: float = 0.42
## What one of his blows takes off the tree (of 1), a heavy one more.
@export var tree_wear: Vector2 = Vector2(0.07, 0.12)

@export_group("Regeneration")
@export var regen: float = 0.004
@export var regen_stopped: float = 6.0
@export var regen_tint: Color = Color(0.45, 1.0, 0.35)

@export_group("Crack")
@export var crack_reach: float = 7.5
@export var crack_speed: float = 11.0
@export var crack_width: float = 0.85
@export var crack_share: float = 0.8

@export_group("Body")
const WOUND_AT := [0.8, 0.6, 0.4, 0.2]
@export var wound_slow: float = 0.06
@export var wound_stance: float = 0.1
const TOTTER_AT := 0.4
const STAGGER_AT := 0.72

## Bare-handed.
const P_JAB := 230
const P_HOOK := 231
const P_KNEES := 232
const P_CHASE := 233
const P_HEADBUTT := 234
const P_STOMP := 235
const P_GRAB := 236
const P_FLEX := 237
## Rocks: torn out of the ground; thrown over its head, bowled, a stone.
const R_PICK := 240
const R_THROW := 241
const R_BOWL := 242
const R_STONE := 243
## The great stone ball (the user's word, 2026-10-25: not a swing along the
## ground, it went the wrong way): both fists brought down into the ground,
## the ground shattering; as it heaves them back up, the ball rolls up out of
## it at him. Three times.
const R_GOLF := 244
## Its fists in the ground, and up again with the ball (clip shares).
const BALL_SLAM := 0.433
const BALL_UP := 0.6
## Bare, its other way: both fists clasped and swung (a hammer, a great one
## round), a two-handed ram.
const P_HAMMER := 226
const P_HOME := 227
const P_RAM := 228
## With the tree.
const W_UPROOT := 250
const W_GREAT := 251
const W_TWO := 252
const W_STRING := 253
const W_SCOOP := 254
const W_CHOP := 255
## The tree swept along the ground and up (earth flying), its root end rammed.
const W_GOLF := 256
const W_BUTT := 257
const T_REEL := 210
const T_TOTTER := 211
const T_STAGGER := 212
## Out of breath after a string or a great blow: stood, heaving, open.
const T_WINDED := 213
## Kept for the tests of before: its great swing is the tree's now.
const T_SWING := W_GREAT
## Round 7 (the user's picks, 2026-10-25):
## its skin turned to stone, healing behind it till it is broken open;
const S_SKIN := 260
## both palms thrust out, the air before them knocking down whoever is on it;
const P_CLAP := 261
## up and down on him body and all, then lying a breath, then up;
const S_SPLASH := 262
const S_DOWN := 263
## its tree, near broken, thrown like a spear;
const W_THROW := 258
## a roar, and stones falling out of the sky round them (enraged).
const R_RAIN := 245
const SKIN_TIME := 4.5
const SPLASH_LIFT := 0.35
const SPLASH_FLY := 1.0
const SPLASH_HIGH := 5.5
const DOWN_HOLD := 1.3
## Moves held at the top of their wind-up (the user's word: lean back, hold
## the arm there, then throw): [clip share of the top, seconds held there,
## clip share of the release].
const HOLD_AT := {W_THROW: [0.38, 0.6, 0.56], P_CLAP: [0.44, 0.5, 0.6]}

## Its swings that carry it off its balance when they find nothing.
const MISS_REELS := [W_GREAT, LEAP, P_HOME]
## Its moves after which it is out of breath whatever else.
const HEAVY_ENDS := [W_GREAT, W_CHOP, R_THROW, R_BOWL, P_GRAB, P_STOMP, LEAP, P_HOME, W_GOLF, R_GOLF]
## How far each move's weight carries its body on after the blow: [pitch
## forward deg, roll deg (+: over to its left), m/s carried on].
const LEANS := {
	P_JAB: [3.0, 0.0, 0.6], P_HOOK: [5.0, 7.0, 1.2], P_KNEES: [6.0, 0.0, 0.8],
	P_CHASE: [7.0, 0.0, 1.8], P_HEADBUTT: [8.0, 0.0, 0.9], P_STOMP: [6.0, 0.0, 0.5],
	W_GREAT: [6.0, 10.0, 2.0], W_TWO: [5.0, 5.0, 1.2], W_STRING: [5.0, 6.0, 1.2],
	W_SCOOP: [-4.0, 0.0, 0.6], W_CHOP: [11.0, 0.0, 1.6], LEAP: [9.0, 0.0, 0.0],
	P_HAMMER: [5.0, 8.0, 1.0], P_HOME: [7.0, 12.0, 1.6], P_RAM: [8.0, 0.0, 1.5],
	W_GOLF: [-3.0, 10.0, 1.0], W_BUTT: [8.0, 0.0, 1.5],
}
## The tail of a blow, after `hand_tail`, played this much slower: the weight
## coming back up (the user's word, 2026-10-25).
const DRAG := 1.7

## Its blows that split the ground where they come down.
const CRACKS := [W_CHOP]
const FIST_RR := "R_elbow_joint>R_midFinger_joint3:0.3"
const FIST_LL := "L_elbow_joint>L_midFinger_joint3:0.3"
const KNEES := "L_thigh_joint>L_knee_joint:0.26|R_thigh_joint>R_knee_joint:0.26"
const HEAD := "head_joint>head_joint@0.11,0.13,0:0.34"
const FOOT := "R_knee_joint>R_ankle_joint:0.25|L_knee_joint>L_ankle_joint:0.25"
const BODY := "pelvis_joint>head_joint:0.5|L_shoulder_joint>R_shoulder_joint:0.4"
const TREE := "R_equip_joint>R_equip_joint@1.25,0,0:0.42"
const SOUNDS := "res://sounds/ogre/"

## Host: its waits.
var _rock_wait: float = 3.0
var _grab_wait: float = 4.0
var _flex_wait: float = 4.0
var _chase_wait: float = 3.0
## Host: the rock being thrown: its kind, how many stones are left, whether
## it has gone.
var _rock_kind: int = TrollRock.Kind.BIG
## For the tests: the kind of rock it must throw next (-1: its choice).
var rock_pick: int = -1
var _stones_left: int = 0
var _balls_left: int = 0
var _ball_wait: float = 8.0
var _sprayed_serial: int = -1
var balls_rolled: int = 0
## Every peer: when its fists went into the ground (s into the move).
var _slam_at: float = -1.0
## Every peer, in the slam: how high its fists have been, and were last.
var _hands_top: float = 0.0
var _hands_last: float = 99.0
var _rock_gone: bool = false
## Every peer: the rock seen in its hands.
var _held: MeshInstance3D
var _held_kind: int = -1
## Host: him in its grip, what the others have dealt it since, done.
var _grabbed: Node3D
var _grab_tried: bool = false
var _slammed: bool = false
var _freed_by: float = 0.0
## Every peer: whether it holds the tree; the tree, its hold, its state.
var armed: bool = false
var uproots: int = 0
var tree_life: float = 1.0
var _tree_stage: int = 0
var _tree_hold: BoneAttachment3D
var _tree: Node3D
var _tree_mat: ShaderMaterial
var _rising: Node3D
var _hand_fists: Array[HandFist] = []
var _left_grip: TwoHandGrip
## Every peer: the move shown and its clock.
var _seen_serial: int = -1
var _seen_clock: float = 0.0
var _whooshed: int = -1
## Host.
var _landed_serial: int = -1
var _cracked_serial: int = -1
var _stomped_serial: int = -1
var _cracks: Array[GroundCrack] = []
var _rocked: int = 0
var wounds: int = 0
var _rage_eased: bool = false
var _stance0: float = 0.0
var _stopped_for: float = 0.0
var healing: bool = false
var _mote_clock: float = 0.0
var _heal_glow: StandardMaterial3D
var _heal_shown: bool = false
var _wound_marks: Array[Marker3D] = []
var _drip_in: float = 0.5
var _tree_dropped: bool = false
var _drop_in: float = -1.0
## For the tests and probes.
var reels: int = 0
var totters: int = 0
var staggers: int = 0
var cracks_made: int = 0
var rocks_thrown: int = 0
var grabs_made: int = 0
var grabs_caught: int = 0
var trees_broken: int = 0
var bites_healed: int = 0
## Round 7, host.
var _skin_wait: float = 20.0
var _skin_dmg: float = 0.0
var _clap_wait: float = 6.0
var _hug_for: float = 0.0
var _splash_wait: float = 9.0
var _sp_from: Vector3
var _sp_to: Vector3
var _sp_landed: int = -1
var _clapped: int = -1
var _thrown_tree: bool = false
var _javelin_serial: int = -1
var _rain_wait: float = 5.0
var _rained: int = -1
var _drops: Array = []
var _throw_at: Node3D
var _suns_made: bool = false
var _sun_t: float = 0.0
var _sun_level: int = 0
var _sun_spent: int = -1
## Every peer.
var stoned: int = 0
var _suns: Array = []
var _stone_mat: StandardMaterial3D
var _stone_shader: ShaderMaterial
var _smoke_in: float = 0.0
## For the probes.
var skins_made: int = 0
var skins_broken: int = 0
var claps_made: int = 0
var splashes_made: int = 0
var trees_thrown: int = 0
var rains_made: int = 0
var heroes_thrown: int = 0
var sun_falls: int = 0
var winded_made: int = 0
## Host: the swing's weight carrying it on after the blow (m/s, along).
var _carry_on: Vector3 = Vector3.ZERO
var _carried_serial: int = -1
## Every peer: its body leaned by the swing's weight (deg: pitch, roll), and
## the body's own basis it is leaned from.
var _lean: Vector2 = Vector2.ZERO
var _body_basis: Basis
var _body_basis_got: bool = false


func _ready() -> void:
	_bare_clips()
	var loops := Array(loop_clips)
	for c in ["CR_HeavyIdle", "CR_HeavyWalk", "CR_HeavyBack", "CR_HeavyL", "CR_HeavyR", "CR_HeavyRun",
			"CR_TR_MutantIdle", "CR_TR_MutantWalk", "CR_TR_MutantRun", "CR_WalkBack", "CR_StrafeL", "CR_StrafeR"]:
		if not loops.has(c):
			loops.append(c)
	loop_clips = PackedStringArray(loops)
	hit_clip = &"CR_GS_Impact"
	block_clip = &"CR_GS_Impact"
	break_clip = &"CR_GS_Impact"
	death_clip = &"CR_MG_Death"
	speed = minf(speed, 1.6)
	chase_speed = 3.4
	close_speed = 1.8
	run_above = 2.5
	dash_chance = 0.0
	stand_turn_max = 1.6
	turn_speed = minf(turn_speed, 3.2)
	act_turn_most = 85.0
	glide_most = 0.9
	glide_gap = 0.8
	chain_snap = 0.0
	max_health = maxf(max_health, 760.0)
	hit_damage = maxf(hit_damage, 52.0)
	reach = 3.0
	strike_off = 2.2
	# (the user's word, 2026-10-25: time for the hero to strike back, it must
	# not be striking all the time)
	attack_cooldown = Vector2(2.0, 3.0)
	attack_cost = 22.0
	stamina_regen = minf(stamina_regen, 14.0)
	# its plain blows, bare: the jab and the hook
	attacks = [&"CR_TR_Jab", &"CR_TR_Hook"] as Array[StringName]
	attack_parts = [Vector3(1.0, 0.0, 0.85), Vector3(1.0, 0.05, 0.8)] as Array[Vector3]
	attack_limbs = PackedStringArray([FIST_LL, FIST_RR])
	attack_blows = PackedInt32Array([1, 1])
	attack_clip = &"CR_TR_Jab"
	# the tackle: head down at him from off
	leap_clip = &"CR_TR_Tackle"
	leap_part = Vector3(1.0, 0.05, 0.62)
	leap_land = 0.39
	leap_from = 5.5
	leap_to = 12.0
	leap_cooldown = 12.0
	leap_quake = 0.0
	leap_limbs = BODY
	leap_share = 1.3
	# its balance (Elden Ring's)
	stance = 540.0
	stance_light_share = 0.4
	stance_rest = 9.0
	stance_down = 3.0
	stance_crit_share = 0.12
	bite_hold = 0.0
	shove_share = 0.15
	flinch_share = 0.55
	rage_at = 0.3
	rage_clip = &"CR_TR_Roar"
	rage_part = Vector3(1.15, 0.1, 0.62)
	rage_pace = 1.12
	rage_harder = 1.3
	hand_pace = 1.0
	hand_tail = 0.5
	hand_combo_chance = Vector2(0.5, 0.65)
	combo_slack = 0.7
	repeat_damp = 0.3
	_stance0 = stance
	super()
	_set_moves()
	_near_floor()
	_set_combos()
	_make_hands()
	_rock_wait = _rng.randf_range(2.5, rock_cooldown.x)
	_grab_wait = _rng.randf_range(4.0, grab_cooldown.x)


func _bare_clips() -> void:
	idle_clip = &"CR_TR_MutantIdle"
	guard_idle_clip = &"CR_TR_MutantIdle"
	fidget_clip = &"CR_TR_MutantIdle"
	walk_clip = &"CR_TR_MutantWalk"
	run_clip = &"CR_TR_MutantRun"
	back_clip = &"CR_WalkBack"
	strafe_l_clip = &"CR_StrafeL"
	strafe_r_clip = &"CR_StrafeR"


func _tree_clips() -> void:
	idle_clip = &"CR_HeavyIdle"
	guard_idle_clip = &"CR_HeavyIdle"
	fidget_clip = &"CR_HeavyIdle"
	walk_clip = &"CR_HeavyWalk"
	run_clip = &"CR_HeavyRun"
	back_clip = &"CR_HeavyBack"
	strafe_l_clip = &"CR_HeavyL"
	strafe_r_clip = &"CR_HeavyR"


## Every move, both looks (every peer has them; the host picks by `armed`).
## Parts and blow moments measured (`_shots_tmp/troll_clips3.gd`, stills).
func _set_moves() -> void:
	_hand_move(P_JAB, &"CR_TR_Jab", Vector3(1.0, 0.0, 0.85), 0.55, FIST_LL)
	_hand_move(P_HOOK, &"CR_TR_Hook", Vector3(1.0, 0.05, 0.8), 1.0, FIST_RR)
	_hand_move(P_KNEES, &"CR_TR_KneesUppercut", Vector3(1.05, 0.1, 0.8), 0.6,
			KNEES + "|" + FIST_RR + "|" + FIST_LL, [0.26, 0.36, 0.46, 0.58])
	_hand_move(P_CHASE, &"CR_TR_ChaseUppercut", Vector3(1.0, 0.0, 0.62), 1.2, FIST_RR + "|" + FIST_LL)
	_hand_move(P_HEADBUTT, &"CR_TR_Headbutt", Vector3(1.0, 0.0, 0.72), 0.8, HEAD)
	_hand_move(P_STOMP, &"CR_TR_Stomp", Vector3(0.95, 0.0, 0.9), 0.7, FOOT)
	_special(P_GRAB, &"CR_TR_Slammer", Vector3(1.25, 0.05, 0.85))
	_special(P_FLEX, &"CR_TR_Flex", Vector3(1.1, 0.05, 0.62))
	_special(R_PICK, &"CR_Harvest", Vector3(1.4, 0.12, 0.5))
	_special(R_THROW, &"CR_TR_ThrowIn", Vector3(1.0, 0.25, 0.85))
	_special(R_BOWL, &"CR_TR_KettleSwing", Vector3(0.9, 0.0, 0.5))
	_special(R_STONE, &"CR_TR_ThrowObject", Vector3(1.6, 0.12, 0.62))
	_special(W_UPROOT, &"CR_TR_Lift", Vector3(2.4, 0.3, 0.92))
	_hand_move(W_GREAT, &"CR_OG_Heavy_Swing", Vector3(1.15, 0.28, 0.82), 1.4, TREE)
	_hand_move(W_TWO, &"CR_OG_TwoHand_Combo", Vector3(1.0, 0.05, 0.94), 0.85, TREE, [0.18, 0.39, 0.68])
	_hand_move(W_STRING, &"CR_OG_Club_Combo2H", Vector3(1.1, 0.14, 0.86), 0.8, TREE, [0.25, 0.517, 0.728])
	_hand_move(W_SCOOP, &"CR_TR_KettleSwing", Vector3(0.9, 0.0, 0.45), 1.1, TREE)
	_hand_move(W_CHOP, &"CR_Heavy1", Vector3(0.9, 0.0, 0.97), 1.35, TREE)
	# (Mixamo's batter's swings, bare-handed: both fists clasped; its golf
	# drive, the long set-up cut away, the swing low along the ground)
	var fists := FIST_RR + "|" + FIST_LL
	_hand_move(P_HAMMER, &"CR_TR_BatSingle", Vector3(1.0, 0.15, 0.68), 0.9, fists)
	_hand_move(P_HOME, &"CR_TR_Homerun", Vector3(1.0, 0.12, 0.5), 1.35, fists)
	_hand_move(P_RAM, &"CR_TR_ButtSmash", Vector3(1.0, 0.2, 0.62), 0.7, fists)
	_hand_move(W_GOLF, &"CR_TR_GolfDrive", Vector3(1.1, 0.47, 0.62), 1.2, TREE, [0.535])
	_hand_move(W_BUTT, &"CR_TR_ButtSmash", Vector3(1.0, 0.2, 0.62), 0.8, TREE)
	# Mixamo's ground spell: both arms up, down into the ground on a knee, up
	_special(R_GOLF, &"CR_MG_Ground", Vector3(0.9, 0.15, 0.85))
	_slow_to[P_HAMMER] = 0.7
	_slow_to[P_HOME] = 1.15
	_snap[P_HOME] = 1.4
	_holds[P_HOME] = [0.4, 0.35, 0.8, 0.25]
	_slow_to[P_RAM] = 0.55
	_slow_to[W_BUTT] = 0.55
	_kinds[P_RAM] = &"guard"
	_kinds[W_BUTT] = &"guard"
	_kinds[P_HOME] = &"crush"
	_special(T_REEL, &"CR_Stun", Vector3(1.25, 0.02, 0.48))
	# round 7: its own flex held, slow (the stone skin); the ground spell's
	# blast, both palms thrust out; the leap; up off its back; the overhead
	# throw (its tree); the roar (the rain)
	_special(S_SKIN, &"CR_TR_Flex", Vector3(0.75, 0.05, 0.7))
	_special(P_CLAP, &"CR_MG_Blast", Vector3(1.0, 0.3, 0.85))
	_special(S_SPLASH, &"CR_Leap", Vector3(0.8, 0.0, 0.5))
	_special(S_DOWN, &"CR_KipUp", Vector3(0.75, 0.0, 1.0))
	# (one-handed, the pick off the ground cut away: up and back over its
	# shoulder, held there, then over: the user's word, 2026-10-25)
	# (since: Mixamo's goalkeeper's far overhand throw, the user's word
	# 2026-10-25: a step in, the tree drawn right back, the other arm out
	# before it, then over: a spear's throw)
	_special(W_THROW, &"CR_TR_GKFarThrow", Vector3(0.95, 0.08, 0.8))
	_special(R_RAIN, &"CR_TR_Roar", Vector3(1.15, 0.1, 0.62))
	_special(T_TOTTER, &"CR_Parry2HHit", Vector3(0.85, 0.0, 0.95))
	_special(T_STAGGER, &"CR_GS_Impact", Vector3(0.8, 0.0, 0.96))
	_special(T_WINDED, &"CR_IdleWounded", Vector3(0.8, 0.0, 1.0))
	# heavy up, fast down (no glow)
	_slow_to[P_HOOK] = 0.8
	_snap[P_HOOK] = 1.3
	_slow_to[P_JAB] = 0.45
	_slow_to[P_HEADBUTT] = 0.75
	_slow_to[P_STOMP] = 0.7
	_slow_to[P_KNEES] = 0.6
	_slow_to[W_CHOP] = 1.05
	_snap[W_CHOP] = 1.6
	_slow_to[W_TWO] = 0.7
	_slow_to[W_SCOOP] = 0.8
	_slow_to[LEAP] = 0.7
	_holds[P_HOOK] = [0.35, 0.3, 0.7, 0.2]
	_holds[W_CHOP] = [0.45, 0.4, 0.95, 0.25]
	_holds[W_GREAT] = [0.3, 0.3, 0.6, 0.25]
	_kinds[P_HEADBUTT] = &"guard"
	_kinds[W_CHOP] = &"crush"
	_kinds[W_GREAT] = &"crush"
	_kinds[LEAP] = &"crush"


## Its bare blows measured landing nearer than its body lets him stand (the
## clips' fists were made for a man's short reach): it opens them from where
## the two bodies meet and steps the rest in under the blow.
func _near_floor() -> void:
	var meet := 1.5
	for what in [ATTACK_BASE, ATTACK_BASE + 1, P_JAB, P_HOOK, P_KNEES, P_HEADBUTT, P_STOMP, P_HAMMER, P_HOME, P_RAM]:
		if _strike_from.has(what):
			_strike_from[what] = maxf(float(_strike_from[what]), meet)
	# the chased uppercut is opened from a few steps off, run in
	_strike_from[P_CHASE] = 3.1
	# the tree's strings all opened from about one gap (else the approach
	# crosses the furthest first and opens that one every time)
	for what in [W_GREAT, W_TWO, W_STRING, W_SCOOP, W_CHOP, W_GOLF, W_BUTT]:
		_strike_from[what] = 1.9


## Its strings, by the look it has: two, three and four blows, each move's
## end into the next's start.
func _set_combos() -> void:
	if armed:
		_hand_combos = [
			# the two-handed string, three blows
			{"name": &"tree_three", "moves": [W_TWO], "fells": [0], "weight": 1.0},
			# the club string (the one kept from before)
			{"name": &"tree_string", "moves": [W_STRING], "fells": [0], "weight": 0.9},
			# up from between its legs, then down into the ground
			{"name": &"tree_scoop_chop", "moves": [W_SCOOP, W_CHOP], "fells": [1], "weight": 1.0},
			# the great swing round (missed, it reels)
			{"name": &"tree_great", "moves": [W_GREAT], "fells": [0], "weight": 0.7},
			# four: the string of three, the chop after it
			{"name": &"tree_four", "moves": [W_TWO, W_CHOP], "fells": [1], "weight": 0.8},
			# along the ground and up, earth flying, then down into it
			{"name": &"tree_golf_chop", "moves": [W_GOLF, W_CHOP], "fells": [1], "weight": 0.9},
			# its root end rammed into him, then round
			{"name": &"tree_butt_great", "moves": [W_BUTT, W_GREAT], "fells": [1], "weight": 0.8},
			{"name": &"tree_butt_string", "moves": [W_BUTT, W_STRING], "fells": [1], "weight": 0.8},
			{"name": &"tree_storm", "moves": [W_SCOOP, W_CHOP, W_GREAT], "fells": [2], "weight": 1.1,
					"rage_only": true},
		]
	else:
		_hand_combos = [
			# two: the jab and the great hook
			{"name": &"jab_hook", "moves": [P_JAB, P_HOOK], "fells": [1], "weight": 1.0},
			# two: its head into him, the stomp
			{"name": &"head_stomp", "moves": [P_HEADBUTT, P_STOMP], "fells": [1], "weight": 0.9},
			# three: jab, hook, stomp
			{"name": &"brawl", "moves": [P_JAB, P_HOOK, P_STOMP], "fells": [2], "weight": 1.0},
			# four: three knees and the uppercut
			{"name": &"knees", "moves": [P_KNEES], "fells": [0], "weight": 0.9},
			# from a few steps off: chased down, the uppercut
			{"name": &"chase", "moves": [P_CHASE], "fells": [0], "weight": 0.6, "far": true},
			# its other way, both fists clasped: a hammer, then the great one round
			{"name": &"hammers", "moves": [P_HAMMER, P_HOME], "fells": [1], "weight": 0.9},
			# three: the ram, the hook, the stomp
			{"name": &"ram_brawl", "moves": [P_RAM, P_HOOK, P_STOMP], "fells": [2], "weight": 0.9},
			# five: a hammer, three knees and the uppercut
			{"name": &"hammer_knees", "moves": [P_HAMMER, P_KNEES], "fells": [1], "weight": 0.7},
			# three: jab, hammer, the great one round
			{"name": &"home_run", "moves": [P_JAB, P_HAMMER, P_HOME], "fells": [2], "weight": 0.8},
			{"name": &"fury", "moves": [P_HOOK, P_HEADBUTT, P_KNEES], "fells": [2], "weight": 1.2, "rage_only": true},
		]
	_hand_last = -1


## Every peer: its fists closed, its left hand drawn onto the tree's haft.
func _make_hands() -> void:
	if _skeleton == null:
		return
	for s in ["R", "L"]:
		var f := HandFist.new()
		f.name = "Fist" + s
		f.side = s
		f.close = 0.8
		_skeleton.add_child(f)
		_hand_fists.append(f)
	_left_grip = TwoHandGrip.new()
	_left_grip.name = "TreeGrip"
	_left_grip.hand_bone = "R_equip_joint"
	_left_grip.axis = Vector3.RIGHT
	_left_grip.along = Vector2(-0.55, -0.18)
	_left_grip.active = false
	_skeleton.add_child(_left_grip)


#region Host: what it chooses
func _own_move(delta: float) -> bool:
	_rock_wait = maxf(_rock_wait - delta, 0.0)
	_ball_wait = maxf(_ball_wait - delta, 0.0)
	_grab_wait = maxf(_grab_wait - delta, 0.0)
	_flex_wait = maxf(_flex_wait - delta, 0.0)
	_chase_wait = maxf(_chase_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	# half its health gone: the tree (once more if the first broke)
	if not armed and (uproots == 0 and health <= max_health * uproot_at
			or uproots == 1 and health <= max_health * uproot_again_at):
		mode = Mode.FIGHT
		velocity = Vector3.ZERO
		_begin(W_UPROOT)
		return true
	if _round7_move(delta, gap):
		return true
	if _quarry_down():
		if _flex_wait <= 0.0 and gap < 9.0:
			_flex_wait = _rng.randf_range(9.0, 14.0)
			mode = Mode.FIGHT
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_begin(P_FLEX)
			return true
		return false
	# the great stone balls, three, either look
	if _ball_wait <= 0.0 and gap >= 5.0 and gap <= 22.0 and stamina >= attack_cost:
		_ball_wait = _rng.randf_range(16.0, 22.0)
		_rock_wait = maxf(_rock_wait, 4.0)
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		# one slam: three balls up out of the ground at once
		_balls_left = 1
		_rock_gone = false
		_begin(R_GOLF)
		return true
	if not armed and _rock_wait <= 0.0 and gap >= rock_from and gap <= rock_to and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		var r := _rng.randf()
		_rock_kind = TrollRock.Kind.BIG if r < 0.45 else (TrollRock.Kind.ROLL if r < 0.75 else TrollRock.Kind.SMALL)
		if rock_pick >= 0:
			_rock_kind = rock_pick
		_rock_gone = false
		if _rock_kind == TrollRock.Kind.SMALL:
			_stones_left = 3
			_begin(R_STONE)
		else:
			_begin(R_PICK)
		return true
	if not armed and _grab_wait <= 0.0 and gap <= grab_reach and _in_front(_quarry, 50.0):
		_grab_wait = _rng.randf_range(grab_cooldown.x, grab_cooldown.y)
		grabs_made += 1
		_grab_tried = false
		_slammed = false
		_grabbed = null
		_freed_by = 0.0
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(P_GRAB)
		return true
	# now and then, from a few steps off, it runs in under an uppercut
	if not armed and _chase_wait <= 0.0 and _cooldown <= 0.0 and gap >= 2.4 and gap <= 4.2 \
			and stamina >= attack_cost and _in_front(_quarry, 40.0):
		_chase_wait = _rng.randf_range(6.0, 10.0)
		if _rng.randf() < 0.5:
			for i in _hand_combos.size():
				if (_hand_combos[i] as Dictionary)["name"] == &"chase":
					start_hand_combo(i)
					return true
	return super(delta)


func _in_front(who: Node3D, degrees: float) -> bool:
	var to := who.global_position - global_position
	to.y = 0.0
	return to.length_squared() < 0.0001 or rad_to_deg(_forward().angle_to(to.normalized())) <= degrees


## Its plain blows only bare-handed; with the tree, one of the tree's strings.
func _begin_attack() -> void:
	if armed and not _hand_combos.is_empty():
		var picks: Array[int] = []
		for i in _hand_combos.size():
			if not bool((_hand_combos[i] as Dictionary).get("rage_only", false)) or raging:
				picks.append(i)
		start_hand_combo(picks[_rng.randi() % picks.size()])
		return
	super()


func _leaps() -> Array:
	return [LEAP, P_CHASE]


func _try_leap() -> bool:
	if armed:
		return false
	return super()


func _blow_reached(who: Node3D, what: int) -> void:
	super(who, what)
	_landed_serial = act_serial


func _after(what: int) -> void:
	if _round7_after(what):
		return
	if what == R_PICK:
		if _quarry != null:
			_face(_quarry.global_position - global_position, 1.0, 50.0)
		_rock_gone = false
		_begin(R_THROW if _rock_kind == TrollRock.Kind.BIG else R_BOWL)
		return
	if what == R_THROW or what == R_BOWL:
		_rock_wait = _rng.randf_range(rock_cooldown.x, rock_cooldown.y)
	if what == R_GOLF:
		_balls_left -= 1
		# (all three, him down or not: he must get up and out of their way)
		if _balls_left > 0 and _quarry != null and not is_dead:
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_rock_gone = false
			_begin(R_GOLF)
			return
	if what == R_STONE:
		_stones_left -= 1
		if _stones_left > 0 and _quarry != null and not is_dead and not _quarry_down():
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_rock_gone = false
			_begin(R_STONE)
			return
		_rock_wait = _rng.randf_range(rock_cooldown.x, rock_cooldown.y)
	if what == P_GRAB:
		_let_go()
		if not _slammed and not is_dead:
			# it reached and caught nothing: it stumbles after its own reach
			reels += 1
			_begin(T_REEL)
			return
	if what == W_UPROOT:
		uproots += 1
		if not armed:
			_send_arm(true)
	var missed := MISS_REELS.has(what) and _landed_serial != act_serial and not is_dead and _decides()
	if missed:
		_hand_combo = -1
	# what this run of blows came to (a combo's every move, or this one)
	var blows := _blow_moments(what).size() if _strikes().has(what) else 0
	if _hand_combo >= 0 and _hand_step >= _hand_moves.size() - 1:
		blows = 0
		for m in _hand_moves:
			blows += _blow_moments(int(m)).size()
	super(what)
	if missed and act == Act.NONE and not is_dead:
		reels += 1
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(T_REEL)
		return
	if what == T_REEL or what == T_STAGGER:
		_cooldown = maxf(_cooldown, 0.6)
	if what == T_WINDED:
		_cooldown = maxf(_cooldown, 0.7)
		return
	# a run of blows over (nothing after it): it stands heaving, open to him
	if act == Act.NONE and not is_dead and _decides() and (blows > 0 or HEAVY_ENDS.has(what)):
		var chance := 1.0 if blows >= 3 or HEAVY_ENDS.has(what) else (0.55 if blows == 2 else 0.25)
		if _rng.randf() < chance:
			_wind(what, blows)


## Host: stood heaving for a while (shorter enraged), open: his blows rock
## its balance the more.
func _wind(what: int, blows: int) -> void:
	winded_made += 1
	velocity.x = 0.0
	velocity.z = 0.0
	_begin(T_WINDED)
	var long := clampf(0.9 + 0.3 * float(blows), 1.3, 2.4)
	if HEAVY_ENDS.has(what):
		long = maxf(long, 1.8)
	if raging:
		long *= 0.65
	_act_length = minf(_act_length, long) if _act_length > 0.0 else long


## The weight after a blow: the clip after its last blow (and `hand_tail`)
## played slower, so it comes back up heavily; on every peer alike.
func _drag_from(what: int) -> float:
	if not LEANS.has(what) or not _strikes().has(what):
		return -1.0
	var ms := _blow_moments(what)
	return ms[ms.size() - 1] + hand_tail if not ms.is_empty() else -1.0


func _clip_time(what: int, t: float) -> float:
	if what == S_DOWN:
		t = maxf(t - DOWN_HOLD, 0.0)
	if HOLD_AT.has(what):
		var top := _held_time(what, 0)
		if t > top:
			t = maxf(top, t - float((HOLD_AT[what] as Array)[1]))
	var from := _drag_from(what)
	if from > 0.0 and t > from:
		t = from + (t - from) / DRAG
	return super(what, t)


func _move_length(what: int) -> float:
	var length := super(what)
	if what == S_DOWN:
		length += DOWN_HOLD
	if HOLD_AT.has(what):
		length += float((HOLD_AT[what] as Array)[1])
	var from := _drag_from(what)
	if from > 0.0 and length > from:
		length = from + (length - from) * DRAG
	return length


## Host: the swing carrying it on along where it faced.
func _extra_velocity(delta: float) -> Vector3:
	var v := super(delta)
	if not LEANS.has(act):
		_carry_on = Vector3.ZERO
		return v
	var ms := _blow_moments(act)
	if not ms.is_empty() and _carried_serial != act_serial and _act_time >= ms[ms.size() - 1]:
		_carried_serial = act_serial
		_carry_on = _forward() * float((LEANS[act] as Array)[2])
	_carry_on = _carry_on.move_toward(Vector3.ZERO, 3.0 * delta)
	return v + _carry_on


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		_run_cracks(delta)
		return
	_round7_act(delta)
	if act == T_REEL or act == T_TOTTER or act == T_STAGGER or act == W_UPROOT or act == P_FLEX:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	# the rock goes
	if (act == R_THROW or act == R_BOWL or act == R_STONE or act == R_GOLF) and not _rock_gone:
		if _quarry != null and _act_time < _release_time(act):
			_face(_quarry.global_position - global_position, delta, turn_speed * 1.5)
		var due := _act_time >= _release_time(act)
		if act == R_GOLF:
			# the ball comes as it heaves its fists back up out of the ground
			due = _sprayed_serial == act_serial and _seen_clock >= _slam_at + 0.45
		if due:
			_rock_gone = true
			if act == R_GOLF:
				_release_ball()
			else:
				_release_rock()
	if act == P_GRAB:
		_run_grab()
	# the stomp: the ground split in three lines out in front
	if act == P_STOMP and _stomped_serial != act_serial:
		var ms := _blow_moments(act)
		if not ms.is_empty() and _act_time >= ms[0]:
			_stomped_serial = act_serial
			for deg in [-32.0, 0.0, 32.0]:
				_crack(_foot_at(), _forward().rotated(Vector3.UP, deg_to_rad(deg)), 5.0, 0.6)
	# the tree down into the ground: a crack along a line
	if CRACKS.has(act) and _cracked_serial != act_serial:
		var ms := _blow_moments(act)
		if not ms.is_empty() and _act_time >= ms[ms.size() - 1]:
			_cracked_serial = act_serial
			var head := _tree_head()
			_crack(Vector3(head.x, global_position.y, head.z), _aim_way(head), crack_reach, crack_share)
			_wear_tree(0.03)
	_run_cracks(delta)


## When in a throw its rock leaves its hands (s into the act).
func _release_time(what: int) -> float:
	var m: Array = _moves_table[what]
	var at := 0.57 if what == R_THROW else (0.28 if what == R_BOWL else (BALL_UP if what == R_GOLF else 0.49))
	return (at - float(m[2])) * _anim.clip_length(m[0]) / maxf(float(m[1]), 0.01) if _anim != null else 0.8


func _foot_at() -> Vector3:
	if _skeleton == null:
		return global_position
	var b := _skeleton.find_bone("R_ankle_joint")
	var p := _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin if b >= 0 else global_position
	return Vector3(p.x, global_position.y, p.z) + _forward() * 0.4


func _aim_way(from: Vector3) -> Vector3:
	var way := _forward()
	if _quarry != null:
		var to := _quarry.global_position - from
		to.y = 0.0
		if to.length_squared() > 0.25 and to.normalized().dot(_forward()) > 0.5:
			way = to.normalized()
	return way
#endregion


#region Host: the rocks
func _release_rock() -> void:
	if _quarry == null:
		return
	rocks_thrown += 1
	var kind := _rock_kind
	var from := _held_at(kind)
	var target := _quarry.global_position + Vector3.UP * 0.9
	var v := Vector3.ZERO
	var worth := hit_damage * _blow_worth(R_THROW)
	if kind == TrollRock.Kind.ROLL:
		# bowled low at his feet: it comes down a few metres off and rolls on
		var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
		v = flat.normalized() * 7.0 + Vector3.UP * 3.0
		worth *= rock_share.y
	else:
		var gap := Vector3(target.x - from.x, 0.0, target.z - from.z).length()
		var flight := clampf(gap / (13.0 if kind == TrollRock.Kind.BIG else 20.0), 0.45, 1.3)
		if _quarry is CharacterBody3D:
			var qv := (_quarry as CharacterBody3D).velocity
			target += Vector3(qv.x, 0.0, qv.z) * flight * (0.5 if kind == TrollRock.Kind.BIG else 0.8)
		v = (target - from) / flight + Vector3.UP * 0.5 * TrollRock.GRAVITY * flight
		worth *= rock_share.x if kind == TrollRock.Kind.BIG else rock_share.z
	var id := act_serial * 10 + rocks_thrown % 10
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_rock.rpc(kind, from, v, worth, id)
	else:
		net_rock(kind, from, v, worth, id)


@rpc("authority", "call_local", "reliable")
func net_rock(kind: int, from: Vector3, v: Vector3, worth: float, id: int) -> void:
	_show_held(-1)
	TrollRock.throw(Blood.world_of(self), from, v, kind, worth, self, _decides(), id)


## Host: the swing along the ground tears a great ball of stone out of it in
## front of it and sends it rolling after him.
func _release_ball() -> void:
	if _quarry == null:
		return
	balls_rolled += 1
	# where its fists went in, a little on (the middle one of the three)
	var from := global_position + _forward() * 2.8 * visual_scale / 1.6
	var way := _quarry.global_position - from
	way.y = 0.0
	if way.length_squared() < 0.01:
		way = _forward()
	var worth := hit_damage * 1.5 * _blow_worth(R_GOLF)
	var id := act_serial * 10 + 5
	var path := _quarry.get_path() if _quarry.is_inside_tree() else NodePath()
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_ball.rpc(from, way.normalized(), worth, id, path)
	else:
		net_ball(from, way.normalized(), worth, id, path)
	balls_rolled += 2


@rpc("authority", "call_local", "reliable")
func net_ball(from: Vector3, way: Vector3, worth: float, id: int, after: NodePath) -> void:
	var into := Blood.world_of(self)
	if into == null:
		return
	var hero := get_node_or_null(after) as Node3D if not after.is_empty() else null
	GroundFx.eruption(into, from, 1.2, false)
	GroundFx.weapon_dust(into, from, 1.8)
	SkillFx.particles(into, from + Vector3.UP * 0.3, {
		"amount": 22, "life": 1.2, "one_shot": true, "explosiveness": 1.0, "add": false,
		"speed": Vector2(3.0, 7.0), "dir": (way + Vector3.UP * 1.4).normalized(), "spread": 35.0,
		"gravity": Vector3(0, -14, 0), "damping": 0.3, "size": Vector2(0.06, 0.14), "sphere": 0.6,
		"colors": [Color(0.38, 0.29, 0.19, 1.0), Color(0.33, 0.25, 0.17, 1.0), Color(0.3, 0.23, 0.16, 0.0)],
	})
	WindBlast.shake(self, 0.12, 0.45, 20.0)
	Sfx.play_any(self, [SOUNDS + "club_ground_2.wav", SOUNDS + "club_ground_4.wav"], self, 0.6, 3.0)
	Sfx.play_any(self, [SOUNDS + "roar_short.wav", SOUNDS + "grunt_2.wav"], self, 0.8, -2.0)
	# three, the middle one a little on, the others either side of it: they
	# grind round where they rose, then go one after another, each after the
	# one before (the user's word: as the elf's ice chain goes)
	var side := way.cross(Vector3.UP).normalized() * 2.3 * visual_scale / 1.6
	var back := -way * 0.6 * visual_scale / 1.6
	var spots := [from, from + side + back, from - side + back]
	var lead: TrollRock = null
	for i in 3:
		var at: Vector3 = spots[i]
		if i > 0:
			GroundFx.eruption(into, at, 0.9, false)
			GroundFx.weapon_dust(into, at, 1.4)
		var aim := (from + way * 4.0 - at)
		aim.y = 0.0
		lead = TrollRock.roll_ball(into, at, aim.normalized(), worth, self, _decides(), id + i * 100, hero,
				0.75 + 0.5 * float(i), lead)


## Any peer, for the hero: its blows cut his swing short with the tree in its
## hands, and its heaviest bare blows (the user's word, 2026-10-25).
func blow_breaks_swing() -> bool:
	return armed or act == P_HOOK or act == P_CHASE or act == P_HOME or act == P_HEADBUTT


## Where the rock is held: between its hands (or in its right, a stone).
func _held_at(kind: int) -> Vector3:
	if _skeleton == null:
		return global_position + Vector3.UP * 2.5
	var r := _bone_at("R_equip_joint")
	if kind == TrollRock.Kind.SMALL:
		return r
	var l := _bone_at("L_equip_joint")
	return r.lerp(l, 0.5)


func _bone_at(name: String) -> Vector3:
	var b := _skeleton.find_bone(name) if _skeleton != null else -1
	if b < 0:
		return global_position + Vector3.UP * 2.0 * visual_scale
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
#endregion


#region Host: the grab and the slam
func _run_grab() -> void:
	var m: Array = _moves_table[P_GRAB]
	var length := _anim.clip_length(m[0]) if _anim != null else 7.5
	var reach_t := (0.18 - float(m[2])) * length / float(m[1])
	var slam_t := (0.73 - float(m[2])) * length / float(m[1])
	if not _grab_tried and _act_time >= reach_t:
		_grab_tried = true
		var who := _quarry as Player
		if who != null and not who.is_dead and _distance_to(who) <= grab_reach + 0.6 and _in_front(who, 70.0) \
				and not who.is_evading():
			_grabbed = who
			grabs_caught += 1
			who.grab_by(self, 6.0)
			# (the hero thrown at the other taken out: the user's word, 2026-10-25)
			_throw_at = null
			Sfx.play_any(self, [SOUNDS + "grunt_2.wav"], self, 0.8, 0.0)
		else:
			# nothing in its hand: the rest of the move is a stumble
			_act_length = _act_time + 0.05
	# another hero near: it turns him to that one, to throw him at him
	if _grabbed != null and not _slammed and _throw_at != null and is_instance_valid(_throw_at):
		_face(_throw_at.global_position - global_position, get_physics_process_delta_time(), turn_speed * 2.0)
	if _grabbed != null and not _slammed and _act_time >= slam_t:
		_slammed = true
		var who := _grabbed
		_let_go()
		if _throw_at != null and is_instance_valid(_throw_at) and not bool(_throw_at.get("is_dead")) \
				and is_instance_valid(who):
			_hurl_hero(who, _throw_at)
			_throw_at = null
			return
		if is_instance_valid(who) and who.has_method(&"receive_blow"):
			who.call(&"receive_blow", hit_damage * slam_share * _blow_worth(P_GRAB), self, 0, 1, act_serial * 10 + 3)
		var at := who.global_position if is_instance_valid(who) else global_position + _forward() * 2.0
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_slam.rpc(at)
		else:
			net_slam(at)


func _let_go() -> void:
	if _grabbed != null and is_instance_valid(_grabbed) and _grabbed.has_method(&"release_grab"):
		_grabbed.call(&"release_grab")
	_grabbed = null


## [Player] `grab_by`: he is held in its right hand, up off the ground.
func grab_point() -> Vector3:
	var at := _bone_at("R_equip_joint")
	at.y = maxf(at.y - 0.6, global_position.y + 1.2)
	return at


@rpc("authority", "call_local", "reliable")
func net_slam(at: Vector3) -> void:
	var into := Blood.world_of(self)
	GroundFx.weapon_dust(into, at, 1.6)
	GroundFx.eruption(into, at, 0.7, false)
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.18, 0.45, 18.0)
	Sfx.play_any(self, [SOUNDS + "club_ground_2.wav", SOUNDS + "club_ground_4.wav"], self, 0.7, 3.0)
#endregion


#region Host: cracks in the ground
func _crack(from: Vector3, way: Vector3, far: float, share: float) -> void:
	cracks_made += 1
	var c := GroundCrack.new(from, way, far, crack_speed, crack_width, 7000000 + act_serial * 4 + cracks_made % 4)
	c.set_meta(&"share", share)
	_cracks.append(c)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_crack.rpc(from, way, far)
	else:
		net_crack(from, way, far)


func _run_cracks(delta: float) -> void:
	if not _decides():
		return
	for i in range(_cracks.size() - 1, -1, -1):
		var c: GroundCrack = _cracks[i]
		for who: Node3D in c.reached(delta, get_tree()):
			who.call(&"receive_blow", hit_damage * float(c.get_meta(&"share", crack_share)) * _blow_worth(0), self, 0, 1,
					c.id, false, &"ground")
		if c.done():
			_cracks.remove_at(i)


@rpc("authority", "call_local", "reliable")
func net_crack(from: Vector3, way: Vector3, far: float) -> void:
	GroundCrack.show(self, from, way, far, crack_speed)
#endregion


#region The tree
## Host: armed (or not), told to every peer.
func _send_arm(on: bool) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_arm.rpc(on)
	else:
		net_arm(on)


@rpc("authority", "call_local", "reliable")
func net_arm(on: bool) -> void:
	armed = on
	if on:
		_thrown_tree = false
	if on:
		tree_life = 1.0
		_tree_stage = 0
		_tree_clips()
		_make_tree()
	else:
		_bare_clips()
	if _left_grip != null:
		_left_grip.active = on
	if _decides():
		_set_combos()
		reach = 3.6 if on else 3.0
		strike_off = 2.8 if on else 2.2


func _make_tree() -> void:
	if _skeleton == null:
		return
	if _rising != null and is_instance_valid(_rising):
		_rising.queue_free()
		_rising = null
	if _tree_hold == null:
		_tree_hold = BoneAttachment3D.new()
		_tree_hold.name = "TrollTreeHold"
		add_child(_tree_hold)
		_tree_hold.use_external_skeleton = true
		_tree_hold.external_skeleton = _tree_hold.get_path_to(_skeleton)
		_tree_hold.bone_name = "R_equip_joint"
	if _tree != null and is_instance_valid(_tree):
		_tree.queue_free()
	_tree = Node3D.new()
	_tree.name = "TrollTree"
	_tree_hold.add_child(_tree)
	var mi := MeshInstance3D.new()
	mi.mesh = TrollRock.mesh("Tree")
	_tree_mat = TrollRock.material().duplicate() as ShaderMaterial
	_tree_mat.set_shader_parameter("bright", 1.15)
	mi.material_override = _tree_mat
	# its length (the model's +Y) along the hand's grip (the equip joint's +X)
	mi.transform = Transform3D(Basis(Vector3.BACK, -PI * 0.5).scaled(Vector3.ONE * tree_scale), Vector3.ZERO)
	_tree.add_child(mi)
	_tree_dropped = false


## Where the tree's root end is.
func _tree_head() -> Vector3:
	if _tree_hold != null and is_instance_valid(_tree_hold):
		return _tree_hold.global_transform * (Vector3.RIGHT * tree_reach)
	return global_position + _forward() * 2.5


## Host: the tree worn by a blow; cracking at two thirds and one, burst at none.
func _wear_tree(amount: float) -> void:
	if not armed or is_dead:
		return
	tree_life = maxf(tree_life - amount, 0.0)
	var stage := 3 if tree_life <= 0.0 else (2 if tree_life < 0.34 else (1 if tree_life < 0.67 else 0))
	if stage == _tree_stage:
		return
	_tree_stage = stage
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_tree.rpc(stage)
	else:
		net_tree(stage)
	if stage == 3:
		trees_broken += 1
		_hand_combo = -1
		_send_arm(false)
		# it is left on its knee, open
		if stance > 0.0 and act != STANCE:
			_break_stance()


## Every peer: the tree splitting (1, 2) or bursting in its hands (3).
@rpc("authority", "call_local", "reliable")
func net_tree(stage: int) -> void:
	_tree_stage = stage
	var into := Blood.world_of(self)
	var mid := _tree_head().lerp(_bone_at("R_equip_joint"), 0.5)
	Sfx.play_any(self, [SOUNDS + "club_ground_3.wav", SOUNDS + "club_ground_1.wav"], self, 1.35 - 0.15 * stage, -2.0)
	if into != null:
		SkillFx.particles(into, mid, {
			"amount": 10 + 10 * stage, "life": 0.9, "one_shot": true, "explosiveness": 1.0, "add": false,
			"speed": Vector2(2.0, 5.0), "dir": Vector3.UP, "spread": 85.0, "gravity": Vector3(0, -10, 0),
			"damping": 0.4, "size": Vector2(0.04, 0.09),
			"colors": [Color(0.62, 0.48, 0.32, 1.0), Color(0.55, 0.42, 0.28, 1.0), Color(0.5, 0.38, 0.25, 0.0)],
		})
	if _tree_mat != null:
		_tree_mat.set_shader_parameter("bright", 1.15 - 0.2 * float(mini(stage, 2)))
	if stage < 3:
		return
	# burst: its bits fly, the root end falls
	if into != null:
		for i in 5:
			var bit := MeshInstance3D.new()
			bit.mesh = TrollRock.mesh("TreeBit_%d" % i)
			bit.material_override = TrollRock.material()
			bit.scale = Vector3.ONE * randf_range(1.6, 2.4)
			into.add_child(bit)
			bit.global_position = mid + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.4), randf_range(-0.3, 0.3))
			var to := bit.global_position + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
			to.y = global_position.y + 0.05
			var tw := bit.create_tween().set_parallel(true)
			tw.tween_property(bit, "global_position", to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(bit, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.7)
			tw.chain().tween_interval(3.0)
			tw.chain().tween_callback(bit.queue_free)
		GroundFx.weapon_dust(into, Vector3(mid.x, global_position.y, mid.z), 1.2)
	Sfx.play_any(self, [SOUNDS + "grunt_1.wav", SOUNDS + "roar_short.wav"], self, 0.8, 0.0)
	if _tree != null and is_instance_valid(_tree):
		_tree.queue_free()
		_tree = null


## Every peer: as it uproots, the tree seen coming up out of the ground
## beside it, earth flying, then into its hands (`net_arm`).
func _show_uproot() -> void:
	if act != W_UPROOT or _skeleton == null:
		return
	var m: Array = _moves_table[W_UPROOT]
	var length := _anim.clip_length(m[0]) / float(m[1]) * (float(m[3]) - float(m[2])) if _anim != null else 3.0
	var share := _seen_clock / maxf(length, 0.1)
	if share >= 0.35 and _rising == null and not armed:
		var into := Blood.world_of(self)
		if into == null:
			return
		_rising = Node3D.new()
		into.add_child(_rising)
		var spot := global_position + _forward() * 1.6 * visual_scale / 1.6
		_rising.global_position = spot + Vector3.DOWN * 2.6
		var mi := MeshInstance3D.new()
		mi.mesh = TrollRock.mesh("Tree")
		mi.material_override = TrollRock.material()
		# upright, roots down, growing up out of the ground
		mi.transform = Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * tree_scale * visual_scale), Vector3.ZERO)
		_rising.add_child(mi)
		var tw := _rising.create_tween()
		tw.tween_property(_rising, "global_position", spot + Vector3.UP * 0.6, length * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		GroundFx.eruption(into, spot, 1.1, false)
		GroundFx.weapon_dust(into, spot, 1.8)
		WindBlast.shake(self, 0.14, 0.8, 20.0)
		Sfx.play_any(self, [SOUNDS + "strain_rise.wav", SOUNDS + "roar.wav"], self, 0.8, 0.0)
		for k in 6:
			var piece := TrollRock.model(TrollRock.Kind.SMALL, k)
			into.add_child(piece)
			piece.global_position = spot + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))
			var up := piece.create_tween()
			up.tween_property(piece, "global_position", piece.global_position + Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 3.0), randf_range(-1.5, 1.5)), 0.4).set_ease(Tween.EASE_OUT)
			up.tween_property(piece, "global_position:y", spot.y + 0.05, 0.45).set_ease(Tween.EASE_IN)
			up.tween_interval(2.5)
			up.tween_callback(piece.queue_free)


## Every peer: the tree let go as it falls.
func _drop_tree() -> void:
	if _tree == null or not is_instance_valid(_tree) or _tree_dropped:
		return
	_tree_dropped = true
	var t := _tree.global_transform
	_tree.top_level = true
	_tree.global_transform = t
	var size := t.basis.get_scale().x
	var side := _forward().cross(Vector3.UP).normalized()
	var land := Transform3D(Basis(side, -PI * 0.5).scaled(Vector3.ONE * size),
			Vector3(t.origin.x, global_position.y + 0.15 * size, t.origin.z) + _forward() * 0.3 * size)
	var tw := _tree.create_tween()
	tw.tween_property(_tree, "global_transform", land, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		GroundFx.weapon_dust(Blood.world_of(self), land.origin, 1.0)
		Sfx.play_any(self, [SOUNDS + "club_ground_1.wav"], self, 0.7, -2.0))
#endregion


#region Every peer: what is seen and heard
func _process(delta: float) -> void:
	super(delta)
	if act_serial != _seen_serial:
		_seen_serial = act_serial
		_seen_clock = 0.0
		_hands_top = 0.0
		_hands_last = 99.0
		_on_move_shown()
	else:
		_seen_clock += delta
	_show_lean(delta)
	_spray_earth()
	_show_sun(delta)
	_show_held_move(delta)
	_show_stone(delta)
	_whoosh()
	_show_rock()
	_show_uproot()
	for f in _hand_fists:
		# fists for blows; round the haft with the tree; slack at rest, bare
		var want := 1.0 if armed else (0.95 if act != Act.NONE else 0.55)
		f.close = move_toward(f.close, want, delta * 4.0)
	if is_dead:
		_show_held(-1)
		if armed and not _tree_dropped:
			if _drop_in < 0.0:
				_drop_in = 0.55
			_drop_in -= delta
			if _drop_in <= 0.0:
				_drop_tree()
	_show_healing(delta)
	_bleed(delta)


func _on_move_shown() -> void:
	if is_dead:
		return
	if act == R_RAIN:
		# its roar shakes the ground: stones hop about its feet, dust off it
		var world := Blood.world_of(self)
		if world != null:
			var s := visual_scale / 1.6
			TrollRock.scatter(world, global_position, 8, Vector2(0.5, 1.0), Vector2(0.5, 2.0), Vector2(2.0, 4.5),
					Vector3.ZERO, act_serial, 3.0 * s, 1.0)
			for k in 4:
				var a := TAU * float(k) / 4.0 + randf()
				GroundFx.weapon_dust(world, global_position + Vector3(cos(a), 0.0, sin(a)) * 2.5 * s, 1.0)
		WindBlast.shake(self, 0.16, 1.4, 30.0)
	if act == W_CHOP or act == W_GREAT or act == R_THROW or act == P_HOOK or act == LEAP:
		Sfx.play_any(self, [SOUNDS + "strain_rise.wav", SOUNDS + "grunt_2.wav"], self, randf_range(0.85, 0.95), -6.0)
	elif act == T_REEL or act == T_STAGGER:
		Sfx.play_any(self, [SOUNDS + "grunt_1.wav", SOUNDS + "grunt_3.wav"], self, randf_range(0.8, 0.9), -4.0)
	elif act == P_FLEX:
		Sfx.play_any(self, [SOUNDS + "roar_short.wav"], self, 0.85, 0.0)
	elif act == R_PICK or act == R_STONE:
		var at := global_position + _forward() * 0.9 * visual_scale / 1.6
		GroundFx.eruption(Blood.world_of(self), at, 0.45 if act == R_STONE else 0.7, false)
		GroundFx.weapon_dust(Blood.world_of(self), at, 1.0 if act == R_PICK else 0.6)


## Every peer: the air before each blow.
func _whoosh() -> void:
	if is_dead or not _strikes().has(act):
		return
	var ms := _blow_moments(act)
	for i in ms.size():
		var key := act_serial * 16 + i
		if key <= _whooshed:
			continue
		if _seen_clock >= ms[i] - 0.14:
			_whooshed = key
			var heavy := armed or act == P_HOOK or act == LEAP or act == P_CHASE
			Sfx.play(self, SOUNDS + ("whoosh_heavy.wav" if heavy else "whoosh_light.wav"), self,
					Vector3.UP * 1.6 * visual_scale, randf_range(0.82, 0.92) if heavy else randf_range(0.9, 1.0), -3.0)
		break


## Every peer: the rock in its hands from the pick to the throw.
func _show_rock() -> void:
	var kind := -1
	if not is_dead:
		if act == R_PICK and _seen_clock > 0.35:
			kind = _rock_shown_kind()
		elif (act == R_THROW or act == R_BOWL) and _seen_clock < _release_time(act):
			kind = _rock_shown_kind()
		elif act == R_STONE and _seen_clock > 0.35 and _seen_clock < _release_time(act):
			kind = TrollRock.Kind.SMALL
	_show_held(kind)
	if _held != null and _held.visible:
		_held.global_position = _held_at(kind) + (Vector3.UP * 0.1 if kind != TrollRock.Kind.SMALL else Vector3.ZERO)


## The kind of rock it is shown holding (the host's choice is not sent: a
## boulder for the overhead throw, the same for the bowl, a stone for a stone).
func _rock_shown_kind() -> int:
	return TrollRock.Kind.ROLL if act == R_BOWL else TrollRock.Kind.BIG


func _show_held(kind: int) -> void:
	if kind == _held_kind:
		return
	_held_kind = kind
	if _held != null and is_instance_valid(_held):
		_held.queue_free()
		_held = null
	if kind < 0:
		return
	_held = TrollRock.model(kind, act_serial)
	_held.top_level = true
	add_child(_held)


func _bleed(delta: float) -> void:
	if _wound_marks.is_empty() or is_dead:
		return
	_drip_in -= delta
	if _drip_in > 0.0:
		return
	_drip_in = randf_range(0.25, 0.7) / float(_wound_marks.size())
	var mark := _wound_marks[randi() % _wound_marks.size()]
	if not is_instance_valid(mark) or not mark.is_inside_tree():
		return
	SkillFx.burst(Blood.world_of(self), mark.global_position, Color(0.45, 0.02, 0.015), 3, Vector2(0.2, 0.6),
			Vector3.DOWN, 30.0, Vector2(0.03, 0.05), Vector3(0, -9.0, 0), 0.6)
#endregion


## Every peer: the body leaned on by its blow's weight from the blow until
## its tail is done, then up again; over to the side with a swing across.
func _show_lean(delta: float) -> void:
	if body == null:
		return
	if not _body_basis_got:
		_body_basis_got = true
		_body_basis = body.transform.basis
	if is_dead:
		if _lean != Vector2.ZERO:
			_lean = Vector2.ZERO
			body.transform.basis = _body_basis
		return
	var want := Vector2.ZERO
	if LEANS.has(act):
		var ms := _blow_moments(act)
		if not ms.is_empty() and _seen_clock >= ms[0] - 0.05:
			var l: Array = LEANS[act]
			var after := _seen_clock - ms[ms.size() - 1]
			var k := 1.0
			if after > hand_tail:
				var tail := maxf(_act_length_seen() - ms[ms.size() - 1] - hand_tail, 0.2)
				k = clampf(1.0 - (after - hand_tail) / tail, 0.0, 1.0)
			want = Vector2(float(l[0]), float(l[1])) * k
	elif act == T_WINDED:
		want = Vector2(5.0, 0.0)
	elif HOLD_AT.has(act):
		want = _held_lean()
	# down onto it quick, up off it slow
	var rate := 40.0 if want.length() > _lean.length() else 9.0
	_lean = _lean.move_toward(want, rate * delta)
	body.transform.basis = Basis(Vector3.RIGHT, deg_to_rad(_lean.x)) * Basis(Vector3.FORWARD, deg_to_rad(_lean.y)) * _body_basis


## Every peer: a swing along the ground throws the earth up before it.
func _spray_earth() -> void:
	if act == R_GOLF:
		_shatter_ground()
		return
	if act != W_GOLF or _sprayed_serial == act_serial or is_dead:
		return
	var at_t := -1.0
	var ms := _blow_moments(act)
	at_t = ms[0] if not ms.is_empty() else 1.0
	if _seen_clock < at_t - 0.05:
		return
	_sprayed_serial = act_serial
	var into := Blood.world_of(self)
	if into == null:
		return
	var at := global_position + _forward() * 1.4 * visual_scale / 1.6
	if armed:
		var head := _tree_head()
		at = Vector3(head.x, global_position.y, head.z)
	GroundFx.weapon_dust(into, at, 1.2)
	SkillFx.particles(into, at + Vector3.UP * 0.2, {
		"amount": 16, "life": 1.0, "one_shot": true, "explosiveness": 1.0, "add": false,
		"speed": Vector2(2.5, 6.0), "dir": (_forward() + Vector3.UP).normalized(), "spread": 40.0,
		"gravity": Vector3(0, -14, 0), "damping": 0.3, "size": Vector2(0.05, 0.12), "sphere": 0.4,
		"colors": [Color(0.38, 0.29, 0.19, 1.0), Color(0.33, 0.25, 0.17, 1.0), Color(0.3, 0.23, 0.16, 0.0)],
	})


## Every peer: both its fists into the ground, the ground shattered round
## them: earth and stones thrown up, short cracks out from them (lines, no
## ring), the view shaken.
func _shatter_ground() -> void:
	if _sprayed_serial == act_serial or is_dead:
		return
	# (by its fists themselves: raised high, then brought down till they go
	# no lower, so the ground breaks as they meet it, on every peer alike)
	var low := _held_at(TrollRock.Kind.BIG).y - global_position.y
	var m: Array = _moves_table[R_GOLF]
	var by_clip := (BALL_SLAM - float(m[2])) * _anim.clip_length(m[0]) / maxf(float(m[1]), 0.01) if _anim != null else 0.9
	var last := _hands_last
	_hands_last = low
	_hands_top = maxf(_hands_top, low)
	var met := _hands_top > low + 1.0 * visual_scale / 1.6 and low >= last - 0.002
	if not met and _seen_clock < by_clip + 2.0:
		return
	_sprayed_serial = act_serial
	_slam_at = _seen_clock
	var into := Blood.world_of(self)
	if into == null:
		return
	var hands := _held_at(TrollRock.Kind.BIG)
	var at := Vector3(hands.x, global_position.y, hands.z)
	GroundFx.eruption(into, at, 1.1, false)
	GroundFx.weapon_dust(into, at, 2.0)
	HitFx.spawn(into, &"stone", at + Vector3.UP * 0.2, Vector3.UP, 1.6)
	SkillFx.particles(into, at + Vector3.UP * 0.2, {
		"amount": 26, "life": 1.1, "one_shot": true, "explosiveness": 1.0, "add": false,
		"speed": Vector2(3.0, 7.5), "dir": Vector3.UP, "spread": 55.0, "gravity": Vector3(0, -16, 0),
		"damping": 0.3, "size": Vector2(0.07, 0.18), "sphere": 0.5,
		"colors": [Color(0.45, 0.42, 0.38, 1.0), Color(0.36, 0.28, 0.19, 1.0), Color(0.33, 0.26, 0.18, 0.0)],
	})
	var fwd := _forward()
	for deg in [-70.0, -30.0, 0.0, 30.0, 70.0, 180.0]:
		GroundCrack.show(self, at, fwd.rotated(Vector3.UP, deg_to_rad(deg)), 2.4 if absf(deg) < 100.0 else 1.4, 14.0)
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.2, 0.5, 22.0)
	Sfx.play_any(self, [SOUNDS + "club_ground_2.wav", SOUNDS + "club_ground_4.wav"], self, 0.55, 4.0)


func _act_length_seen() -> float:
	return _move_length(act) if act != Act.NONE else 0.0


#region Host: its balance and its body
func _add_stance(amount: float) -> void:
	# stood heaving, or come back up off a blow: open, his blows rock it more
	if act == T_WINDED:
		amount *= 1.5
	elif LEANS.has(act):
		var ms := _blow_moments(act)
		if not ms.is_empty() and _act_time > ms[ms.size() - 1]:
			amount *= 1.25
	super(amount)
	if is_dead or stance <= 0.0 or act == STANCE or act == PIECES or act == RAGE or act == LEAP \
			or act == W_UPROOT or act == P_GRAB or act == S_SPLASH or act == S_DOWN or act == S_SKIN \
			or act == R_RAIN or act == W_THROW:
		return
	var share := stance_taken / stance
	if _rocked < 2 and share >= STAGGER_AT:
		_rocked = 2
		staggers += 1
		_hand_combo = -1
		_sweeps.clear()
		velocity.x = 0.0
		velocity.z = 0.0
		_begin(T_STAGGER)
	elif _rocked < 1 and share >= TOTTER_AT and (act == Act.NONE or act == T_REEL):
		_rocked = 1
		totters += 1
		_begin(T_TOTTER)


func _receive(damage: float, at: Vector3, blow: Vector3, from: Node3D, magic: bool = false) -> bool:
	# its stone skin: most of it turned, but every blow cracks it, a heavy one
	# the more
	if act == S_SKIN and _decides() and stoned == 1:
		_skin_dmg += damage * (1.7 if damage >= 35.0 else 1.0)
		damage *= 0.3
		if _skin_dmg >= max_health * 0.06:
			_skin_break()
	var bled := super(damage, at, blow, from, magic)
	if stance_taken <= 0.0 and act != STANCE:
		_rocked = 0
	if bled and armed:
		_wear_tree(tree_wear.y if damage >= 40.0 else tree_wear.x)
	# him held: the other hero's blows make it let go
	if bled and _grabbed != null and from != _grabbed and from != null and from.is_in_group(&"player"):
		_freed_by += damage
		if _freed_by >= max_health * grab_free:
			_let_go()
			_begin(T_STAGGER)
	if bled and not is_dead and wounds < WOUND_AT.size() and health <= max_health * float(WOUND_AT[wounds]):
		_wound(at, blow)
	return bled


func _wound(at: Vector3, blow: Vector3) -> void:
	wounds += 1
	var keep := (1.0 - wound_slow * float(wounds)) / (1.0 - wound_slow * float(wounds - 1))
	speed *= keep
	chase_speed *= keep
	close_speed *= keep
	stance = _stance0 * (1.0 - wound_stance * float(wounds))
	if stance_taken >= stance and act != STANCE:
		_break_stance()
	var bone := _nearest_bone(at)
	if bone < 0:
		return
	var b := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	var local := b.affine_inverse() * at
	var way := b.basis.inverse() * (-blow if blow.length_squared() > 0.0001 else -_forward())
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_wound.rpc(String(_skeleton.get_bone_name(bone)), local, way, wounds)
	else:
		net_wound(String(_skeleton.get_bone_name(bone)), local, way, wounds)


func _nearest_bone(at: Vector3) -> int:
	if _skeleton == null:
		return -1
	var best := -1
	var near := INF
	for name_of: String in ["chest_joint", "waist_joint", "pelvis_joint", "L_shoulder_joint", "R_shoulder_joint",
			"L_elbow_joint", "R_elbow_joint", "L_thigh_joint", "R_thigh_joint", "L_knee_joint", "R_knee_joint",
			"neck_joint"]:
		var i := _skeleton.find_bone(name_of)
		if i < 0:
			continue
		var p := (_skeleton.global_transform * _skeleton.get_bone_global_pose(i)).origin
		var d := p.distance_squared_to(at)
		if d < near:
			near = d
			best = i
	return best


@rpc("authority", "call_local", "reliable")
func net_wound(bone_name: String, local: Vector3, way: Vector3, count: int) -> void:
	if _skeleton == null or _skeleton.find_bone(bone_name) < 0:
		return
	if not has_meta(&"wound_layer"):
		set_meta(&"wound_layer", true)
		for m in body.find_children("*", "GeometryInstance3D", true, false) if body != null else []:
			var g := m as GeometryInstance3D
			if g != null and not (g is GPUParticles3D) and not (g is Label3D):
				g.layers |= Blood.WOUND_LAYER
	var hold := BoneAttachment3D.new()
	hold.bone_name = bone_name
	_skeleton.add_child(hold)
	var y := way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD
	var z := Vector3.DOWN - y * y.dot(Vector3.DOWN)
	z = z.normalized() if z.length_squared() > 0.0001 else y.cross(Vector3.RIGHT).normalized()
	var x := y.cross(z).normalized()
	var s := 1.0 / maxf(visual_scale, 0.01)
	var deep := 1.0 + 0.25 * float(count - 1)
	var decal := Decal.new()
	decal.name = "Wound%d" % count
	decal.texture_albedo = Blood.wound_texture()
	decal.modulate = Color(0.5, 0.03, 0.02)
	decal.albedo_mix = 1.0
	decal.cull_mask = Blood.WOUND_LAYER
	# (deep through it: a blow's point is on its body's axis; the far side's
	# skin faces away and is faded out)
	decal.size = Vector3(0.6 * deep, 1.5, 0.9 * deep) * s * visual_scale / 1.6
	decal.normal_fade = 0.4
	hold.add_child(decal)
	decal.transform = Transform3D(Basis(x, y, z), local + y * 0.25)
	var mark := Marker3D.new()
	mark.name = "WoundAt%d" % count
	hold.add_child(mark)
	mark.position = local
	_wound_marks.append(mark)
	var world := Blood.world_of(self)
	var at := _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(bone_name)) * local
	if world != null:
		SkillFx.burst(world, at, Color(0.5, 0.03, 0.02), 18, Vector2(1.0, 3.2), _skeleton.global_basis * y, 50.0,
				Vector2(0.03, 0.07), Vector3(0, -9.0, 0), 0.7)
	Sfx.play_any(self, [SOUNDS + "grunt_1.wav", SOUNDS + "grunt_3.wav"], self, randf_range(0.78, 0.86), -3.0)
#endregion


#region Its wounds closing
func _show_healing(delta: float) -> void:
	var on := healing and not is_dead and body != null and act != PIECES and stoned == 0 and _stone_a <= 0.0
	if on != _heal_shown:
		_heal_shown = on
		if body != null:
			if _heal_glow == null:
				_heal_glow = StandardMaterial3D.new()
				_heal_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_heal_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_heal_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_heal_glow.albedo_color = Color(regen_tint, 0.0)
			for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
				mi.material_overlay = _heal_glow if on else null
	if not on:
		return
	_heal_glow.albedo_color.a = 0.05 + 0.05 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0))
	_mote_clock += delta
	if _mote_clock < 0.2:
		return
	_mote_clock = 0.0
	var at := global_position + Vector3.UP * randf_range(0.5, 1.7) * visual_scale \
			+ Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35)) * visual_scale
	SkillFx.burst(Blood.world_of(self), at, regen_tint, 6, Vector2(0.3, 0.9), Vector3.UP, 35.0,
			Vector2(0.045, 0.09), Vector3(0, 1.6, 0), 1.0)


func _physics_process(delta: float) -> void:
	super(delta)
	if is_dead:
		if _decides():
			_let_go()
		return
	if not _decides():
		return
	if raging and not _rage_eased:
		_rage_eased = true
		attack_cooldown = Vector2(1.0, 1.7)
		_rain_wait = 2.0
	_round7_tick(delta)
	var aff := Afflictions.of(self, false)
	if aff != null and (aff.is_burning() or aff.is_chilled()):
		_stopped_for = regen_stopped
	_stopped_for = maxf(_stopped_for - delta, 0.0)
	var heal := _stopped_for <= 0.0 and health < max_health and act != PIECES
	if heal:
		health = minf(health + max_health * regen * delta, max_health)
	if heal != healing:
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_regen.rpc(heal)
		else:
			net_regen(heal)


@rpc("authority", "call_local", "reliable")
func net_regen(on: bool) -> void:
	healing = on


func react(kind: StringName, from: Node3D = null, push: Vector3 = Vector3.ZERO) -> void:
	if kind == &"burn" or kind == &"chill" or kind == &"freeze":
		_stopped_for = regen_stopped
	# fire cracks the stone skin open at once
	if kind == &"burn" and act == S_SKIN and _decides() and stoned == 1:
		_skin_break()
	super(kind, from, push)
#endregion


#region Round 7: stone skin, the clap, the body splash, the tree thrown, the hero thrown, the rain, the sun
## Host: one of the round's moves, if one is due (true if it took one).
func _round7_move(delta: float, gap: float) -> bool:
	_skin_wait = maxf(_skin_wait - delta, 0.0)
	_clap_wait = maxf(_clap_wait - delta, 0.0)
	_splash_wait = maxf(_splash_wait - delta, 0.0)
	if not _suns_made:
		_make_suns()
	# them close about its legs (two, or one a while): both palms out
	var near := 0
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Node3D
		if hero != null and not bool(hero.get("is_dead")) and _distance_to(hero) <= 2.8:
			near += 1
	_hug_for = _hug_for + delta if near > 0 else maxf(_hug_for - delta * 0.5, 0.0)
	if _clap_wait <= 0.0 and (near >= 2 or _hug_for >= 2.5) and not _quarry_down():
		_clap_wait = _rng.randf_range(11.0, 15.0)
		_hug_for = 0.0
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(P_CLAP)
		return true
	# enraged: the sky falls on them (taken out: the user did not like it)
	if false and raging and _rain_wait <= 0.0:
		_rain_wait = _rng.randf_range(24.0, 30.0)
		mode = Mode.FIGHT
		velocity = Vector3.ZERO
		_begin(R_RAIN)
		return true
	# the tree near broken: thrown at him
	if armed and not _thrown_tree and tree_life < 0.4 and gap >= 5.0 and gap <= 18.0 and not _quarry_down():
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_begin(W_THROW)
		return true
	# hurt, him a little off: its skin to stone, healing behind it
	if _skin_wait <= 0.0 and health < max_health * 0.75 and gap > 3.5:
		_skin_wait = _rng.randf_range(30.0, 38.0)
		_skin_dmg = 0.0
		skins_made += 1
		mode = Mode.FIGHT
		velocity = Vector3.ZERO
		_begin(S_SKIN)
		_act_length = SKIN_TIME
		_send(&"net_skin", [1])
		return true
	# (the body splash taken out: the user did not like the leap at all)
	return false


## Host: what follows one of the round's moves (true if it took it).
func _round7_after(what: int) -> bool:
	if what == S_SPLASH:
		_begin(S_DOWN)
		return true
	if what == S_SKIN and stoned == 1 and _decides():
		# held out: whole again, and healed
		health = minf(health + max_health * 0.12, max_health)
		bites_healed += 1
		_send(&"net_skin", [0])
		_send(&"net_skin_healed", [])
	if what == STANCE and stoned != 0 and _decides():
		_send(&"net_skin", [0])
	if what == S_DOWN:
		_cooldown = maxf(_cooldown, 0.6)
	return false


## Host, every frame of a move of the round's.
func _round7_act(delta: float) -> void:
	if act == S_SPLASH:
		_run_splash(delta)
	elif act == P_CLAP:
		var at_t := _held_time(P_CLAP, 2)
		if _act_time < at_t and _quarry != null:
			_face(_quarry.global_position - global_position, delta, turn_speed)
		elif _clapped != act_serial:
			_clapped = act_serial
			_clap()
	elif act == W_THROW:
		var at_t := _held_time(W_THROW, 2)
		if _act_time < at_t and _quarry != null:
			_face(_quarry.global_position - global_position, delta, turn_speed * 1.5)
		elif _javelin_serial != act_serial and armed:
			_javelin_serial = act_serial
			_throw_tree()
	elif act == R_RAIN and _rained != act_serial and _act_time >= 0.8:
		_rained = act_serial
		_call_rain()
	elif act == S_SKIN or act == S_DOWN or act == R_RAIN:
		velocity.x = 0.0
		velocity.z = 0.0


## Host, every frame: the falling stones due, the sun on it.
func _round7_tick(delta: float) -> void:
	for i in range(_drops.size() - 1, -1, -1):
		var d: Array = _drops[i]
		d[0] = float(d[0]) - delta
		if float(d[0]) <= 0.0:
			_send(&"net_drop", [d[1], int(d[2])])
			_drops.remove_at(i)
	if _rain_wait > 0.0 and raging and act == Act.NONE:
		_rain_wait = maxf(_rain_wait - delta, 0.0)
	# the sun: stood in it, it stiffens; long enough, it goes down in stone
	var lit := -1
	for i in _suns.size():
		var s := _suns[i] as TrollSun
		if s != null and s.covers(global_position):
			lit = i
	if lit >= 0 and act != STANCE and stoned == 0:
		_sun_t += delta
	else:
		_sun_t = maxf(_sun_t - delta * 0.7, 0.0)
	var level := mini(int(_sun_t / 0.55), 2)
	if level != _sun_level:
		_sun_level = level
		_send(&"net_sun_level", [level])
	if lit >= 0 and _sun_t >= 1.6:
		_sun_t = 0.0
		_sun_level = 0
		sun_falls += 1
		_hand_combo = -1
		_send(&"net_sun_state", [lit, false])
		_send(&"net_skin", [3])
		_break_stance()
		var idx := lit
		get_tree().create_timer(20.0).timeout.connect(func() -> void:
			if is_instance_valid(self) and not is_dead:
				_send(&"net_sun_state", [idx, true]))


## Host: an rpc to every peer (or straight, alone).
func _send(method: StringName, args: Array) -> void:
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		callv(&"rpc", [method] + args)
	else:
		callv(method, args)


func _other_hero(not_this: Node3D, within: float) -> Node3D:
	var best: Node3D = null
	var near := within
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Node3D
		if hero == null or hero == not_this or bool(hero.get("is_dead")):
			continue
		var d := hero.global_position.distance_to(not_this.global_position)
		if d < near:
			near = d
			best = hero
	return best


#region The body splash
func _run_splash(delta: float) -> void:
	var t := _act_time
	if t < SPLASH_LIFT:
		if _quarry != null:
			_face(_quarry.global_position - global_position, delta, turn_speed)
		_sp_from = global_position
		return
	if _sp_landed == act_serial:
		return
	if _sp_to == Vector3.ZERO or t - delta < SPLASH_LIFT:
		var to := _quarry.global_position if _quarry != null else global_position + _forward() * 8.0
		if _quarry is CharacterBody3D:
			var qv := (_quarry as CharacterBody3D).velocity
			to += Vector3(qv.x, 0.0, qv.z) * 0.45
		var flat := Vector3(to.x - _sp_from.x, 0.0, to.z - _sp_from.z)
		if flat.length() > 14.0:
			flat = flat.normalized() * 14.0
		# short of him by its own body, so it comes down on him, not past
		if flat.length() > 1.2:
			flat -= flat.normalized() * 0.6
		_sp_to = Vector3(_sp_from.x + flat.x, _sp_from.y, _sp_from.z + flat.z)
	var k := clampf((t - SPLASH_LIFT) / SPLASH_FLY, 0.0, 1.0)
	var pos := _sp_from.lerp(_sp_to, k) + Vector3.UP * SPLASH_HIGH * 4.0 * k * (1.0 - k)
	global_position = pos
	velocity = Vector3.ZERO
	if k >= 1.0:
		_sp_landed = act_serial
		_splash_land(_sp_to)
		_sp_to = Vector3.ZERO


func _splash_land(at: Vector3) -> void:
	splashes_made += 1
	_send(&"net_splash", [at])
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Node3D
		if hero == null or bool(hero.get("is_dead")) or not hero.has_method(&"receive_blow"):
			continue
		if hero.global_position.distance_to(at) > 3.4 * visual_scale / 1.6:
			continue
		if hero.has_method(&"is_evading") and bool(hero.call(&"is_evading")):
			continue
		hero.call(&"receive_blow", hit_damage * 1.5, self, 0, 1, act_serial * 10 + 7, false, &"above")
	for deg in [0.0, 72.0, 144.0, 216.0, 288.0]:
		_crack(at, _forward().rotated(Vector3.UP, deg_to_rad(deg)), 4.5, 0.5)


## Every peer: it comes down body and all — the ground broken round it,
## stone thrown up, the view shaken hard near it.
@rpc("authority", "call_local", "reliable")
func net_splash(at: Vector3) -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	var s := visual_scale / 1.6
	RockWave.spawn(world, at, 3.8 * s, 0.85 * s, 16.0, act_serial * 13 + 7)
	var crack := DarkFx.decal(world, at, DarkFx.CRACK, 5.5 * s, Color(0.09, 0.07, 0.05, 1.0), 0.0, 0.92)
	crack.rotation.y = randf() * TAU
	var tw := crack.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(crack, "modulate:a", 0.0, 3.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(crack.queue_free)
	SkillFx.burst(world, at + Vector3.UP * 0.2, Color(0.45, 0.39, 0.31, 0.65), 60, Vector2(2.0, 6.0), Vector3.UP, 80.0,
			Vector2(0.12, 0.3), Vector3(0, -1.5, 0), 1.5)
	SkillFx.burst(world, at + Vector3.UP * 0.2, Color(0.26, 0.23, 0.2, 1.0), 40, Vector2(4.0, 10.0), Vector3.UP, 60.0,
			Vector2(0.05, 0.12), Vector3(0, -16.0, 0), 1.1)
	get_tree().call_group(&"ground_scars", &"scar", at, 1.6)
	ImpactFx.strike(self, at + Vector3.UP * 0.2, &"stone", 2.0)
	ImpactFx.thud(self, at, true)
	WindBlast.shake(self, 0.3, 0.7, 30.0)
	Sfx.play_any(self, [SOUNDS + "club_ground_2.wav", SOUNDS + "club_ground_4.wav"], self, 0.5, 6.0)
	Sfx.play_any(self, [SOUNDS + "grunt_1.wav"], self, 0.75, 0.0)
#endregion


#region The clap
func _clap() -> void:
	claps_made += 1
	var front := global_position + _forward() * 1.4 * visual_scale / 1.6
	_send(&"net_clap", [front, _forward()])
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Node3D
		if hero == null or bool(hero.get("is_dead")) or not hero.has_method(&"receive_blow"):
			continue
		var d := _distance_to(hero)
		if d > 3.4 and not (d <= 6.5 and _in_front(hero, 50.0)):
			continue
		if hero.has_method(&"is_evading") and bool(hero.call(&"is_evading")):
			continue
		hero.call(&"receive_blow", hit_damage * 0.9, self, 0, 1, act_serial * 10 + 8)


## Every peer: both palms thrust out — the air before them torn, a wave of
## dust and stones running out along the ground before it, the view knocked.
@rpc("authority", "call_local", "reliable")
func net_clap(at: Vector3, way: Vector3) -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	var s := visual_scale / 1.6
	var up := at + Vector3.UP * 1.6 * s
	SkillFx.particles(world, up, {
		"amount": 60, "life": 0.8, "one_shot": true, "explosiveness": 1.0, "add": false,
		"speed": Vector2(10.0, 20.0), "dir": way, "spread": 28.0, "gravity": Vector3.ZERO,
		"damping": 10.0, "size": Vector2(0.4, 0.9), "grow": 1.8, "sphere": 0.5,
		"colors": [Color(0.92, 0.9, 0.85, 0.0), Color(0.92, 0.9, 0.85, 0.45), Color(0.92, 0.9, 0.85, 0.0)],
	})
	# the wave out along the ground, a step at a time
	for k in 6:
		var d := (1.4 + 1.2 * float(k)) * s
		var spot := at + way * d
		get_tree().create_timer(0.06 * float(k)).timeout.connect(func() -> void:
			if not is_instance_valid(world):
				return
			GroundFx.weapon_dust(world, spot, 1.5 - 0.15 * float(k))
			SkillFx.burst(world, spot + Vector3.UP * 0.1, Color(0.46, 0.4, 0.32, 0.6), 10, Vector2(1.5, 4.0),
					(way + Vector3.UP).normalized(), 50.0, Vector2(0.1, 0.22), Vector3(0, -2.0, 0), 0.8))
	TrollRock.scatter(world, at + way * 1.6 * s, 7, Vector2(0.8, 1.5), Vector2(4.0, 8.0), Vector2(1.5, 3.5), way * 1.5,
			act_serial)
	WindBlast.shake(self, 0.3, 0.5, 24.0)
	Sfx.play_any(self, [SOUNDS + "club_ground_1.wav", SOUNDS + "club_ground_3.wav"], self, 1.1, 6.0)
	Sfx.play_any(self, [SOUNDS + "roar_short.wav"], self, 0.85, 2.0)
	Sfx.play(self, SOUNDS + "whoosh_heavy.wav", self, Vector3.UP * 1.6 * s, 0.6, 4.0)
#endregion


#region The held moves (the tree thrown, the clap): leant back, held, over
## Act time (s) of a held move's top (0), the end of its hold (1), its
## release (2).
func _held_time(what: int, which: int) -> float:
	var h: Array = HOLD_AT[what]
	var m: Array = _moves_table[what]
	var length := _anim.clip_length(m[0]) if _anim != null else 3.0
	var rate := maxf(float(m[1]), 0.01)
	var top := (float(h[0]) - float(m[2])) * length / rate
	if which == 0:
		return top
	if which == 1:
		return top + float(h[1])
	return (float(h[2]) - float(m[2])) * length / rate + float(h[1])


## Every peer: how a held move leans it — back into the wind-up, trembling
## while it is held, then over hard after the release.
func _held_lean() -> Vector2:
	var top := _held_time(act, 0)
	var held := _held_time(act, 1)
	var rel := _held_time(act, 2)
	var back := -13.0 if act == W_THROW else -7.0
	var t := _seen_clock
	if t < top:
		return Vector2(back * clampf(t / maxf(top, 0.1), 0.0, 1.0), 0.0)
	if t < held:
		var shake := sin(t * 47.0) * 1.2
		return Vector2(back + shake, shake * 0.6)
	if t < rel + 0.5:
		return Vector2(10.0 if act == W_THROW else 9.0, 0.0)
	return Vector2.ZERO


var _held_fx_in: float = 0.0
var _held_serial: int = -1
var _held_flags: int = 0


## Every peer: what is seen of a held move: the wind-up gathering (earth off
## its tree's roots, dust drawn in at its feet, the air drawn to its palms),
## the creak and grunt at the top, the rush of the release.
func _show_held_move(delta: float) -> void:
	if is_dead or not HOLD_AT.has(act):
		return
	if _held_serial != act_serial:
		_held_serial = act_serial
		_held_flags = 0
	var world := Blood.world_of(self)
	if world == null:
		return
	var s := visual_scale / 1.6
	var top := _held_time(act, 0)
	var rel := _held_time(act, 2)
	if _seen_clock >= top - 0.1 and _held_flags & 1 == 0:
		_held_flags |= 1
		Sfx.play_any(self, [SOUNDS + "strain_rise.wav"], self, 0.75, 2.0)
		Sfx.play_any(self, [SOUNDS + "grunt_2.wav", SOUNDS + "grunt_3.wav"], self, 0.7, 0.0)
	if _seen_clock >= rel - 0.05 and _held_flags & 2 == 0:
		_held_flags |= 2
		Sfx.play(self, SOUNDS + "whoosh_heavy.wav", self, Vector3.UP * 2.0 * s, 0.55, 6.0)
		WindBlast.shake(self, 0.12, 0.3, 18.0)
		GroundFx.weapon_dust(world, global_position + _forward() * 1.2 * s, 1.3)
	if _seen_clock > rel:
		return
	_held_fx_in -= delta
	if _held_fx_in > 0.0:
		return
	_held_fx_in = 0.07
	var gather := clampf(_seen_clock / maxf(top, 0.1), 0.2, 1.0)
	# dust drawn in round its feet
	var a := randf() * TAU
	var ring := global_position + Vector3(cos(a), 0.05, sin(a)) * randf_range(1.6, 2.6) * s
	SkillFx.burst(world, ring, Color(0.46, 0.4, 0.32, 0.45), 3, Vector2(1.0, 2.2) * gather,
			(global_position - ring).normalized() + Vector3.UP * 0.2, 20.0, Vector2(0.12, 0.25), Vector3.ZERO, 0.6)
	if act == W_THROW and _tree != null and is_instance_valid(_tree):
		# earth shaken off its roots as it is swung up
		var roots := _tree_head()
		SkillFx.burst(world, roots, Color(0.35, 0.27, 0.18, 1.0), 3, Vector2(0.3, 1.2), Vector3.DOWN, 60.0,
				Vector2(0.05, 0.1), Vector3(0, -10.0, 0), 0.9)
		if randf() < 0.35:
			SkillFx.burst(world, roots, Color(0.42, 0.5, 0.25, 1.0), 2, Vector2(0.3, 1.0), Vector3.DOWN, 80.0,
					Vector2(0.06, 0.1), Vector3(0, -2.0, 0), 1.4)
	elif act == P_CLAP:
		# the air drawn to its palms
		var hands := _held_at(TrollRock.Kind.BIG)
		var b := randf() * TAU
		var from := hands + Vector3(cos(b), randf_range(-0.4, 0.6), sin(b)) * 1.8 * s
		SkillFx.burst(world, from, Color(0.95, 0.93, 0.88, 0.35), 2, Vector2(2.0, 3.5) * gather,
				(hands - from).normalized(), 8.0, Vector2(0.15, 0.3), Vector3.ZERO, 0.45)
#endregion


#region The tree thrown
func _throw_tree() -> void:
	if _quarry == null:
		return
	trees_thrown += 1
	_thrown_tree = true
	var from := _tree_head().lerp(_bone_at("R_equip_joint"), 0.5)
	var target := _quarry.global_position + Vector3.UP * 0.6
	var gap := Vector3(target.x - from.x, 0.0, target.z - from.z).length()
	var flight := clampf(gap / 22.0, 0.35, 0.9)
	var v := (target - from) / flight + Vector3.UP * 0.5 * TrollRock.GRAVITY * flight
	_send(&"net_javelin", [from, v, hit_damage * 1.6, act_serial * 10 + 6, tree_scale * visual_scale])
	_send_arm(false)


@rpc("authority", "call_local", "reliable")
func net_javelin(from: Vector3, v: Vector3, worth: float, id: int, size: float) -> void:
	if _tree != null and is_instance_valid(_tree):
		_tree.queue_free()
		_tree = null
	Sfx.play_any(self, [SOUNDS + "roar_short.wav", SOUNDS + "grunt_2.wav"], self, 0.8, 0.0)
	TrollRock.javelin(Blood.world_of(self), from, v, worth, self, _decides(), id, size)
#endregion


#region The hero thrown at the other
func _hurl_hero(who: Node3D, at: Node3D) -> void:
	heroes_thrown += 1
	var world := Blood.world_of(self)
	if world == null:
		return
	var start := who.global_position
	var way := Vector3(at.global_position.x - start.x, 0.0, at.global_position.z - start.z)
	way = way.normalized() if way.length_squared() > 0.0001 else _forward()
	# (the blow comes from behind him, the way he is to go: [Player] throws
	# him away from where a blow came)
	var mark := Node3D.new()
	mark.name = "TrollThrow"
	world.add_child(mark)
	mark.global_position = start - way * 1.5 + Vector3.UP * 0.5
	who.call(&"receive_blow", hit_damage * slam_share * 0.8 * _blow_worth(P_GRAB), mark, 0, 1, act_serial * 10 + 4)
	_send(&"net_slam", [start])
	var serial := act_serial
	get_tree().create_timer(0.35).timeout.connect(func() -> void:
		if is_instance_valid(at) and not bool(at.get("is_dead")) and not (at.has_method(&"is_evading")
				and bool(at.call(&"is_evading"))):
			var rel := at.global_position - start
			rel.y = 0.0
			var along := rel.dot(way)
			if along > 0.0 and along < 9.0 and (rel - way * along).length() < 1.6:
				mark.global_position = at.global_position - way * 1.5 + Vector3.UP * 0.5
				at.call(&"receive_blow", 40.0 if not is_instance_valid(self) else hit_damage * 0.9, mark, 0, 1,
						serial * 10 + 5)
				if is_instance_valid(self):
					_send(&"net_slam", [at.global_position])
		if is_instance_valid(mark) and mark.is_inside_tree():
			mark.get_tree().create_timer(1.5).timeout.connect(mark.queue_free))
#endregion


#region The rain
func _call_rain() -> void:
	rains_made += 1
	var heroes: Array = []
	for node in get_tree().get_nodes_in_group(&"player"):
		var hero := node as Node3D
		if hero != null and not bool(hero.get("is_dead")):
			heroes.append(hero)
	if heroes.is_empty():
		return
	for i in 9:
		var hero := heroes[i % heroes.size()] as Node3D
		var spot := hero.global_position
		if i >= heroes.size():
			var a := _rng.randf() * TAU
			spot += Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(1.5, 4.0)
		_drops.append([0.3 + 0.3 * float(i), spot, act_serial * 100 + 50 + i])


@rpc("authority", "call_local", "reliable")
func net_drop(at: Vector3, id: int) -> void:
	# its warning: grit and pebbles trickling down out of the sky onto the
	# spot, dust stirring there, as it comes
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.particles(world, at + Vector3.UP * 7.0, {
			"amount": 14, "life": 1.3, "one_shot": true, "explosiveness": 0.3, "add": false,
			"speed": Vector2(0.5, 2.0), "dir": Vector3.DOWN, "spread": 12.0, "gravity": Vector3(0, -9, 0),
			"damping": 0.1, "size": Vector2(0.04, 0.09), "sphere": 0.6,
			"colors": [Color(0.4, 0.37, 0.33, 1.0), Color(0.38, 0.35, 0.31, 1.0), Color(0.36, 0.33, 0.3, 0.0)],
		})
		SkillFx.burst(world, at + Vector3.UP * 0.1, Color(0.46, 0.4, 0.32, 0.45), 8, Vector2(0.3, 1.0), Vector3.UP, 80.0,
				Vector2(0.15, 0.3), Vector3(0, 0.3, 0), 1.2)
	TrollRock.throw(Blood.world_of(self), at + Vector3.UP * 24.0, Vector3(0.0, -4.0, 0.0), TrollRock.Kind.BIG,
			hit_damage * 1.2, self, _decides(), id)
#endregion


#region The stone skin, and the sun
## Host: its stone skin broken open (enough blows, or fire): it goes down on
## its knee, open, and gets none of the healing.
func _skin_break() -> void:
	skins_broken += 1
	_send(&"net_skin", [2])
	_break_stance()


@rpc("authority", "call_local", "reliable")
func net_skin(state: int) -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	var mid := global_position + Vector3.UP * 1.6 * s
	if state == 1:
		# the stone climbs it from its feet, dust off the line it climbs
		stoned = 1
		_stone_to(1.05, 1.3)
		Sfx.play_any(self, [SOUNDS + "strain_rise.wav"], self, 0.65, 2.0)
		Sfx.play_any(self, [SOUNDS + "roar_short.wav"], self, 0.6, -2.0)
		if into != null:
			GroundFx.weapon_dust(into, global_position, 1.4)
			TrollRock.scatter(into, global_position, 5, Vector2(0.6, 1.1), Vector2(1.0, 2.5), Vector2(2.0, 4.0),
					Vector3.ZERO, act_serial, 1.2 * s)
	elif state == 2:
		# broken open: the stone burst off it in pieces
		stoned = 0
		_stone_burst(1.0)
		Sfx.play_any(self, [SOUNDS + "club_ground_2.wav", SOUNDS + "club_ground_4.wav"], self, 1.0, 6.0)
		Sfx.play_any(self, [SOUNDS + "grunt_1.wav"], self, 0.75, 0.0)
		WindBlast.shake(self, 0.18, 0.35, 18.0)
	elif state == 3:
		# the sun: the last of it gone to stone where it stands
		stoned = 3
		_stone_to(1.05, 0.35)
		Sfx.play_any(self, [SOUNDS + "grunt_3.wav", SOUNDS + "roar_short.wav"], self, 0.6, 0.0)
		if into != null:
			SkillFx.burst(into, mid, Color(0.6, 0.58, 0.54, 0.6), 30, Vector2(0.5, 2.0), Vector3.UP, 120.0,
					Vector2(0.12, 0.25), Vector3(0, 0.5, 0), 1.6)
	else:
		if stoned == 3:
			# back to itself out of the sun's stone: cracked off it
			_stone_burst(0.7)
			Sfx.play_any(self, [SOUNDS + "club_ground_3.wav"], self, 1.1, 2.0)
		elif stoned == 1:
			# held out: the shell let fall off it, top down, in pieces
			_stone_to(0.0, 1.0)
			_stone_crumble = 1.0
			Sfx.play_any(self, [SOUNDS + "club_ground_1.wav"], self, 1.2, -2.0)
		else:
			_stone_to(0.0, 0.3)
		stoned = 0


@rpc("authority", "call_local", "reliable")
func net_skin_healed() -> void:
	var into := Blood.world_of(self)
	if into == null:
		return
	SkillFx.burst(into, global_position + Vector3.UP * 1.4 * visual_scale / 1.6, regen_tint, 30, Vector2(0.5, 2.0),
			Vector3.UP, 80.0, Vector2(0.06, 0.12), Vector3(0, 1.5, 0), 1.2)
	Sfx.play_any(self, [SOUNDS + "roar_short.wav"], self, 0.8, 0.0)


## Every peer: the stone over its body: up to this share of its height (0:
## none), climbing to `_stone_want`; [method _show_stone] lays it each frame.
var _stone_a: float = 0.0
var _stone_want: float = 0.0
var _stone_rate: float = 1.0
var _stone_dust_in: float = 0.0
var _stone_crumble: float = 0.0
var _stone_opacity: float = 1.0


func _stone_to(share: float, seconds: float) -> void:
	_stone_want = share
	_stone_rate = absf(share - _stone_a) / maxf(seconds, 0.05)
	_stone_opacity = 1.0


## Every peer: the stone burst off it, pieces flung out from all up its body.
func _stone_burst(power: float) -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	if into != null and into is Node3D:
		for h in [0.6, 1.5, 2.4]:
			var at: Vector3 = global_position + Vector3.UP * float(h) * s
			TrollRock.scatter(into as Node3D, at, int(5 * power) + 1, Vector2(0.8, 1.6), Vector2(3.0, 6.5) * power,
					Vector2(1.5, 4.5), Vector3.ZERO, act_serial + int(h * 10.0), 0.4 * s)
		HitFx.spawn(into, &"stone", global_position + Vector3.UP * 1.6 * s, Vector3.UP, 1.8)
		SkillFx.burst(into, global_position + Vector3.UP * 1.6 * s, Color(0.5, 0.48, 0.45, 1.0), 40,
				Vector2(3.0, 7.0), Vector3.UP, 120.0, Vector2(0.05, 0.14), Vector3(0, -14.0, 0), 1.0)
		SkillFx.burst(into, global_position + Vector3.UP * 1.4 * s, Color(0.6, 0.58, 0.54, 0.6), 20,
				Vector2(1.0, 3.0), Vector3.UP, 120.0, Vector2(0.25, 0.45), Vector3(0, -1.0, 0), 1.2)
	_stone_a = 0.0
	_stone_want = 0.0
	_apply_stone(0.0)


## Every peer: the stone's line up its body eased to where it is going, laid
## on; dust off the line while it climbs, pieces off it while it falls away.
func _show_stone(delta: float) -> void:
	if _stone_a == _stone_want and _stone_a <= 0.0:
		return
	var was := _stone_a
	_stone_a = move_toward(_stone_a, _stone_want, _stone_rate * delta)
	_apply_stone(_stone_a)
	var into := Blood.world_of(self)
	if into == null or _stone_a == was:
		return
	_stone_dust_in -= delta
	if _stone_dust_in > 0.0:
		return
	_stone_dust_in = 0.07
	var s := visual_scale / 1.6
	var a := randf() * TAU
	var at := global_position + Vector3(cos(a) * 0.5 * s, _stone_a * STONE_TALL * s, sin(a) * 0.5 * s)
	if _stone_a > was:
		SkillFx.burst(into, at, Color(0.7, 0.67, 0.6, 0.6), 5, Vector2(0.4, 1.4), Vector3(cos(a), 0.3, sin(a)), 40.0,
				Vector2(0.1, 0.2), Vector3(0, -1.5, 0), 0.8)
	elif _stone_crumble > 0.0 and into is Node3D:
		TrollRock.scatter(into as Node3D, at, 1, Vector2(0.6, 1.1), Vector2(0.5, 1.5), Vector2(0.0, 1.0), Vector3.ZERO,
				int(Time.get_ticks_msec()) % 9973, 0.3 * s, 1.5)
		SkillFx.burst(into, at, Color(0.6, 0.58, 0.54, 0.6), 4, Vector2(0.2, 0.8), Vector3.DOWN, 60.0,
				Vector2(0.1, 0.2), Vector3(0, -4.0, 0), 0.8)
		if _stone_a <= 0.0:
			_stone_crumble = 0.0


const STONE_TALL := 3.6


func _apply_stone(a: float) -> void:
	if body == null:
		return
	if _stone_mat == null:
		_stone_shader = ShaderMaterial.new()
		_stone_shader.shader = load("res://scripts/troll_stone.gdshader")
		_stone_mat = StandardMaterial3D.new()
	var on := a > 0.005
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if not on:
			if mi.material_overlay == _stone_shader:
				mi.material_overlay = _glow if raging and _glow != null else null
		elif mi.material_overlay != _stone_shader:
			mi.material_overlay = _stone_shader
	if on:
		_stone_shader.set_shader_parameter("top", global_position.y + a * STONE_TALL * visual_scale / 1.6)
		_stone_shader.set_shader_parameter("opacity", _stone_opacity)
	else:
		_heal_shown = false


## Host: the sun's shafts, two, either side of the ground between it and
## him, set once it first sees him.
func _make_suns() -> void:
	_suns_made = true
	if _quarry == null:
		return
	var base := global_position
	var way := _quarry.global_position - base
	way.y = 0.0
	way = way.normalized() if way.length_squared() > 0.01 else _forward()
	var side := way.cross(Vector3.UP).normalized()
	var spots: Array = []
	for at: Vector3 in [base + way * 4.0 + side * 7.0, base + way * 4.0 - side * 7.0]:
		var down := get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 10.0, 1))
		spots.append((down["position"] as Vector3) if not down.is_empty() else at)
	_send(&"net_suns", [spots])


@rpc("authority", "call_local", "reliable")
func net_suns(spots: Array) -> void:
	for s in _suns:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_suns.clear()
	var into := Blood.world_of(self)
	for at: Vector3 in spots:
		_suns.append(TrollSun.make(into, at))


@rpc("authority", "call_local", "reliable")
func net_sun_state(i: int, on: bool) -> void:
	if i >= 0 and i < _suns.size() and is_instance_valid(_suns[i]):
		(_suns[i] as TrollSun).set_active(on)


## Every peer: how far the sun has stiffened it (0..2), its skin greying.
@rpc("authority", "call_local", "reliable")
func net_sun_level(level: int) -> void:
	if stoned != 0:
		return
	# the stone up its legs, then its body, as it stands in the light
	_stone_to(0.3 * float(level), 0.4)


## Every peer: stood in the sun its skin smokes.
func _show_sun(delta: float) -> void:
	if is_dead or _suns.is_empty():
		return
	var lit := false
	for s in _suns:
		if is_instance_valid(s) and (s as TrollSun).covers(global_position):
			lit = true
	if not lit:
		return
	_smoke_in -= delta
	if _smoke_in > 0.0:
		return
	_smoke_in = 0.1
	var at := global_position + Vector3.UP * randf_range(0.6, 2.6) * visual_scale / 1.6 \
			+ Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)) * visual_scale / 1.6
	SkillFx.burst(Blood.world_of(self), at, Color(0.75, 0.72, 0.68, 0.5), 4, Vector2(0.4, 1.2), Vector3.UP, 30.0,
			Vector2(0.15, 0.3), Vector3(0, 1.2, 0), 1.3)


func _exit_tree() -> void:
	for s in _suns:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_suns.clear()
#endregion
#endregion
