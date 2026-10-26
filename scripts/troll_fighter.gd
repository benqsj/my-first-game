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
## Its foot stamped down before it uproots: the trunk bursts up out of the
## ground before it (2026-10-26, the user).
const W_UPSTOMP := 289
const W_GREAT := 251
const W_TWO := 252
const W_STRING := 253
const W_SCOOP := 254
const W_CHOP := 255
## The tree swept along the ground and up (earth flying), its root end rammed.
const W_GOLF := 256
const W_BUTT := 257
## DoubleL's heavy one-handed blows (2026-10-25, the user's word: a lean
## after each and a slow way back, as Elden Ring's): two strings of three,
## the first two cut short of their way back so the next follows, the last
## kept whole; one of them whole alone; a lunge in from off.
const W_HA1 := 270
const W_HA2 := 271
const W_HA3 := 272
const W_HB1 := 273
const W_HB2 := 274
const W_HB3 := 275
const W_LUNGE := 276
## The same first blows opening another string, or alone (each string's
## first its own: it is opened from its own gap).
const W_HA1F := 277
const W_HA1X := 278
const W_HB1F := 279
## The rest of a blow cut short for the next, when the next is not to come:
## its lean and slow way back after all (no string just stopped dead).
const W_RA1 := 284
const W_RA2 := 285
const W_RB1 := 286
const W_RB2 := 287
const W_RA1X := 288
const DL_REST := {W_HA1: W_RA1, W_HA2: W_RA2, W_HB1: W_RB1, W_HB2: W_RB2, W_HA1X: W_RA1X}
const GRAB_ON := false
const OLD_TREE := [W_GREAT, W_TWO, W_STRING, W_SCOOP, W_CHOP, W_GOLF, W_BUTT]
const DL_MOVES := [W_HA1, W_HA2, W_HA3, W_HB1, W_HB2, W_HB3, W_LUNGE, W_HA1F, W_HA1X, W_HB1F]
## Its body and his kept this far apart (at its size 1.6) at the nearest a
## DoubleL clip carries it: those clips stride on past the blow.
const DL_ROOM := 1.5
## A DoubleL blow opened only within this of the gap its own stride lands
## from (never stretched: its feet keep to the ground); a string runs on only
## while the next one's does.
const DL_TOL := 0.35
## (no longer used to stretch a stride)
const DL_FIT := Vector2(0.88, 1.12)
## An old string opened only within this of the gap its first blow lands from.
const OLD_FIT := 0.5
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
var _tree_mesh: MeshInstance3D
## Every peer: the tree's size in the world as last held (the thrown one
## made the same).
var _tree_size: float = 0.0
## The tree held as a spear: up from the level, and the hand this far
## (model metres) from its grip toward its middle.
const SPEAR_PITCH := 0.14
const SPEAR_GRIP := 0.35
## Every peer: the pitch it will be cast at (the host's, `net_spear`).
var _spear_pitch: float = SPEAR_PITCH
var _spear_sent: int = -1
var _spear_arm: SpearArm
## Host: whether it means to open one of DoubleL's strings as it comes on
## (rolled every `_dl_roll_in`).
var _dl_will: bool = true
var _dl_roll_in: float = 0.0
## Every peer: the gap each DoubleL blow's tree lands on him from (`_dl_rest`).
## Each old tree move's blows: the gap each lands at (2026-10-26: its
## strings' later blows fell past him, it having walked on into him).
var _old_lands: Dictionary = {}
var _dl_lands: Dictionary = {}
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
const SUN_ON := false
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
	# (no gliding in under a blow: the user, 2026-10-26, it slid at him held
	# in its wind-up; it opens its blows from where they land instead)
	glide_most = 0.0
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
	_dl_rest()
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
	var way: Dictionary = UPROOTS[uproot_way]
	_special(W_UPROOT, way["clip"] as StringName, way["play"] as Vector3)
	_special(W_UPSTOMP, &"CR_TR_Stomp", Vector3(0.95, 0.0, 0.9))
	_hand_move(W_GREAT, &"CR_OG_Heavy_Swing", Vector3(1.15, 0.28, 0.82), 1.4, TREE)
	# (its third swing put aside, 2026-10-26: measured, it passes within
	# 0.75 m of its own body, over him at any gap he can stand at; the user
	# saw the string's last blow miss every time. Never a string's last move:
	# cut after its second blow for the next)
	_hand_move(W_TWO, &"CR_OG_TwoHand_Combo", Vector3(1.0, 0.05, 0.94), 0.85, TREE, [0.18, 0.39])
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
	# DoubleL's (the hand's speed through each measured, _shots_tmp/cmp/
	# dl_speed.gd: where the blow falls, in the whole clip)
	# (each whole: in a string all but its last are cut after their last
	# blow by `hand_tail`; `_dl_rest` keeps the rest for when the string ends;
	# the blow found where the tree swings fastest, as for the old ones; by
	# hand where its wind-up is the faster: the hand's speed, dl_speed.gd)
	_hand_move(W_HA1, &"CR_DL_HeavyA1", Vector3(1.0, 0.0, 1.0), 1.0, TREE)
	_hand_move(W_HA1X, &"CR_DL_HeavyA1", Vector3(1.0, 0.0, 1.0), 1.0, TREE)
	_hand_move(W_HA1F, &"CR_DL_HeavyA1", Vector3(1.0, 0.0, 1.0), 1.2, TREE)
	_hand_move(W_HA2, &"CR_DL_HeavyA2", Vector3(1.0, 0.08, 1.0), 1.0, TREE)
	_hand_move(W_HA3, &"CR_DL_HeavyA3", Vector3(1.0, 0.08, 1.0), 1.3, TREE)
	_hand_move(W_HB1, &"CR_DL_HeavyB1", Vector3(1.0, 0.05, 1.0), 1.1, TREE, [0.4])
	_hand_move(W_HB1F, &"CR_DL_HeavyB1", Vector3(1.0, 0.05, 1.0), 1.2, TREE, [0.4])
	_hand_move(W_HB2, &"CR_DL_HeavyB2", Vector3(1.0, 0.08, 1.0), 1.0, TREE)
	_hand_move(W_HB3, &"CR_DL_HeavyB3", Vector3(1.0, 0.08, 1.0), 1.35, TREE)
	_hand_move(W_LUNGE, &"CR_DL_Lunge", Vector3(1.0, 0.0, 1.0), 1.2, TREE, [0.25])
	for what in [W_HA3, W_HB3, W_HA1F, W_HB1F, W_LUNGE]:
		_kinds[what] = &"crush"
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
## A DoubleL blow: its stride fitted (a little at most) so the tree, as the
## blow falls, is just where it reaches him (the user: from the gap it
## reaches him from).
func _begin(what: int) -> void:
	super(what)
	if not (what in DL_MOVES) or _quarry == null or _anim == null:
		return
	# (its own stride, never stretched: any stretch slid its planted feet;
	# it is opened only from where its own stride lands, `_dl_fits`)
	_stretch = 1.0


## Host: the clip's own travel never bringing it nearer him than a body's
## room (on past a blow, those clips stride on into where he would have
## been thrown).
func _carry(delta: float) -> Vector3:
	var v := super(delta)
	# (only with him down: standing, a blow throws him back out of its way)
	if _quarry == null or not _quarry_down() or not (act in DL_MOVES or act in DL_REST.values()):
		return v
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length() < _dl_room() and to.length_squared() > 0.0001:
		var n := to.normalized()
		var toward := v.dot(n)
		if toward > 0.0:
			v -= n * toward
	return v


func _dl_room() -> float:
	return DL_ROOM * visual_scale / 1.6


## A DoubleL move's whole length, cut by nothing.
func _dl_whole(what: int) -> float:
	var m: Array = _moves_table[what]
	return _anim.clip_length(m[0]) * (float(m[3]) - float(m[2])) / float(m[1])


## Where a DoubleL move is cut when the next follows: after its last blow.
func _dl_cut(what: int) -> float:
	var ms := _blow_moments(what)
	return (ms[ms.size() - 1] + hand_tail) if not ms.is_empty() else _dl_whole(what)


## How far forward the move's clip carries it by `until` (the furthest, if
## `furthest`), metres on this body.
func _dl_ahead(what: int, until: float, furthest: bool) -> float:
	var clip := _clip_of(what)
	var from := _hips(clip, _clip_time(what, 0.0)).x
	if not furthest:
		return _hips(clip, _clip_time(what, until)).x - from
	var most := 0.0
	for i in range(1, 17):
		most = maxf(most, _hips(clip, _clip_time(what, until * float(i) / 16.0)).x - from)
	return most


## How far forward the move's clip carries it to its blow, metres.
func _dl_stride(what: int) -> float:
	var ms := _blow_moments(what)
	return _dl_ahead(what, ms[0], false) if not ms.is_empty() else 0.0


## How much its stride to the blow must be fitted for the tree to land on
## him from `gap` (1: its own; below 0: nowhere near).
func _dl_k(what: int, gap: float) -> float:
	var land := float(_dl_lands.get(what, 2.4 * visual_scale / 1.6))
	var stride := _dl_stride(what)
	if stride < 0.3:
		return 1.0 if absf(gap - land) <= 0.35 else -1.0
	return (gap - land) / stride


func _dl_fits(what: int, gap: float) -> bool:
	var want := float(_dl_lands.get(what, 2.4 * visual_scale / 1.6)) + _dl_stride(what)
	return absf(gap - want) <= DL_TOL


## Every peer, once: the rest of each blow cut short for the next, from just
## where it is cut.
func _dl_rest() -> void:
	if _anim == null:
		return
	# where each blow lands: the gap its tree reaches him at, as it falls
	for what: int in DL_MOVES:
		var m: Array = _moves_table[what]
		var ms := _blow_moments(what)
		var share := _clip_time(what, ms[0]) / maxf(_anim.clip_length(m[0]), 0.01) if not ms.is_empty() else 0.4
		var land := _gap_that_lands(what, m, share)
		_dl_lands[what] = land if land > 0.0 else 2.4 * visual_scale / 1.6
	# the old ones too (no gliding in now: they open from where they land)
	for what: int in OLD_TREE:
		var m: Array = _moves_table[what]
		var ms := _blow_moments(what)
		if ms.is_empty():
			continue
		var share := _clip_time(what, ms[0]) / maxf(_anim.clip_length(m[0]), 0.01)
		var land := _gap_that_lands(what, m, share)
		if land > 0.0:
			_dl_lands[what] = land
			_strike_from[what] = land + maxf(_dl_ahead(what, ms[0], false), 0.0)
		var lands := PackedFloat32Array()
		for t in ms:
			var l := _gap_that_lands(what, m, _clip_time(what, t) / maxf(_anim.clip_length(m[0]), 0.01))
			lands.append(l if l > 0.0 else -1.0)
		_old_lands[what] = lands
	for what: int in DL_REST:
		var m: Array = _moves_table[what]
		var share := _clip_time(what, _dl_cut(what)) / maxf(_anim.clip_length(m[0]), 0.01)
		_special(int(DL_REST[what]), m[0], Vector3(float(m[1]), minf(share, 0.98), 1.0))


## Each DoubleL string opened from the gap its first stride carries the
## tree onto him from.
func _dl_gaps() -> void:
	if _anim == null:
		return
	for c: Dictionary in _hand_combos:
		if bool(c.get("dl", false)):
			var first := int((c["moves"] as Array)[0])
			_strike_from[first] = float(_dl_lands.get(first, 2.4)) + _dl_stride(first)


## How far a blow of its, landing now, throws him back on his feet: a
## DoubleL blow's stride carries on after it, so he is thrown out of its way
## (into the next one's reach, in a string), not walked into nor slid short.
func blow_shove_m() -> float:
	if _anim != null and _old_lands.has(act):
		return _old_shove()
	if not (act in DL_MOVES) or _anim == null:
		return 0.0
	var ms := _blow_moments(act)
	if ms.is_empty():
		return 0.0
	var at_blow := _dl_ahead(act, ms[0], false) * _stretch
	var land := float(_dl_lands.get(act, 2.0))
	if _hand_combo >= 0 and _hand_step < _hand_moves.size() - 1:
		var nxt := int(_hand_moves[_hand_step + 1])
		if nxt in DL_MOVES:
			var cut := _dl_ahead(act, _dl_cut(act), false) * _stretch
			var want := float(_dl_lands.get(nxt, 2.0)) + _dl_stride(nxt)
			return maxf(want - (land - (cut - at_blow)), 0.0)
	var rest := _dl_ahead(act, _dl_whole(act), true) * _stretch - at_blow
	return maxf(rest - (land - _dl_room()), 0.0) + 0.3


## An old tree move's blow landing now: he is thrown back just so far that
## its next blow (this move's, or the next move's in its string), with the
## clip's own stride between, falls where it reaches him; not into its body,
## the swing passing over him (2026-10-26, the user: the last blow of its
## string always missed).
func _old_shove() -> float:
	if _quarry == null:
		return 0.0
	var ms := _blow_moments(act)
	var lands: PackedFloat32Array = _old_lands[act]
	if ms.is_empty():
		return 0.0
	var k := 0
	for i in ms.size():
		if _act_time >= ms[i] - _blow_window_for(act).x:
			k = i
	var now := _dl_ahead(act, ms[k], false)
	var land := -1.0
	var travel := 0.0
	if k + 1 < ms.size():
		land = lands[k + 1]
		travel = _dl_ahead(act, ms[k + 1], false) - now
	elif _hand_combo >= 0 and _hand_step < _hand_moves.size() - 1:
		var nxt := int(_hand_moves[_hand_step + 1])
		var nms := _blow_moments(nxt)
		if not _old_lands.has(nxt) or nms.is_empty():
			return 0.0
		land = (_old_lands[nxt] as PackedFloat32Array)[0]
		travel = _dl_ahead(act, _act_length, false) - now + _dl_ahead(nxt, nms[0], false)
	if land <= 0.0:
		return 0.0
	return maxf(land + maxf(travel, 0.0) * _stretch - _distance_to(_quarry), 0.0)


## Host: now and then, as it comes on with its tree and he stands just where
## one of DoubleL's strings would carry it, that string begun.
func _dl_open(gap: float, delta: float) -> bool:
	_dl_roll_in -= delta
	if _dl_roll_in <= 0.0:
		_dl_roll_in = 2.0
		_dl_will = _rng.randf() < 0.65
	# (its breath after the last nearly back: it comes on into this one)
	if not _dl_will or _hand_combo >= 0 or _cooldown > 0.7 or stamina < attack_cost or _quarry == null \
			or not _in_front(_quarry, 50.0):
		return false
	var picks: Array[int] = []
	for i in _hand_combos.size():
		var c: Dictionary = _hand_combos[i]
		if not bool(c.get("dl", false)) or (bool(c.get("rage_only", false)) and not raging):
			continue
		if _dl_fits(int((c["moves"] as Array)[0]), gap):
			picks.append(i)
	if picks.is_empty():
		return false
	_dl_will = false
	mode = Mode.FIGHT
	start_hand_combo(picks[_rng.randi() % picks.size()])
	return true


## Host: a DoubleL string only from the gap its strides cover (near him,
## the old ones; further, these).
func _try_hand_combo(gap: float) -> bool:
	var saved := {}
	for c: Dictionary in _hand_combos:
		if not bool(c.get("dl", false)):
			continue
		var first := int((c["moves"] as Array)[0])
		if saved.has(first):
			continue
		var want := float(_strike_from.get(first, 0.0))
		if not _dl_fits(first, gap):
			saved[first] = want
			_strike_from[first] = 99.0
	var made := super(gap)
	for first: int in saved:
		_strike_from[first] = saved[first]
	return made


## Host: a DoubleL string runs on only while its next stride lands on him;
## else the blow cut short is played out (its lean, its slow way back).
func _hand_next(what: int) -> int:
	var cut := DL_REST.has(what) and _hand_combo >= 0 and _hand_step < _hand_moves.size() - 1 \
			and _act_length < _dl_whole(what) - 0.05
	var next := super(what)
	if not cut:
		return next
	if next >= 0 and _quarry != null and _dl_fits(next, _distance_to(_quarry)):
		return next
	_hand_step = _hand_moves.size()
	return int(DL_REST[what])


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
			# the two-handed pair, then the great swing round
			{"name": &"tree_three", "moves": [W_TWO, W_GREAT], "fells": [1], "weight": 1.0},
			# the club string (the one kept from before)
			{"name": &"tree_string", "moves": [W_STRING], "fells": [0], "weight": 0.9},
			# up from between its legs, then down into the ground
			{"name": &"tree_scoop_chop", "moves": [W_SCOOP, W_CHOP], "fells": [1], "weight": 1.0},
			# the great swing round (missed, it reels)
			{"name": &"tree_great", "moves": [W_GREAT], "fells": [0], "weight": 0.7},
			# four: the two-handed pair, up from between its legs, the chop
			{"name": &"tree_four", "moves": [W_TWO, W_SCOOP, W_CHOP], "fells": [2], "weight": 0.8},
			# along the ground and up, earth flying, then down into it
			{"name": &"tree_golf_chop", "moves": [W_GOLF, W_CHOP], "fells": [1], "weight": 0.9},
			# its root end rammed into him, then round
			{"name": &"tree_butt_great", "moves": [W_BUTT, W_GREAT], "fells": [1], "weight": 0.8},
			{"name": &"tree_butt_string", "moves": [W_BUTT, W_STRING], "fells": [1], "weight": 0.8},
			{"name": &"tree_storm", "moves": [W_SCOOP, W_CHOP, W_GREAT], "fells": [2], "weight": 1.1,
					"rage_only": true},
			# DoubleL's heavy strings: three each, the last with its whole
			# lean and slow way back (his chance)
			{"name": &"heavy_a", "moves": [W_HA1, W_HA2, W_HA3], "fells": [2], "weight": 1.2, "dl": true},
			# (B1's and B3's blows put aside: measured, their tree came down
			# short of him whatever the gap; B2 and A3 in their places)
			{"name": &"heavy_b", "moves": [W_HB2, W_HA3], "fells": [1], "weight": 1.2, "dl": true},
			{"name": &"heavy_cross", "moves": [W_HA1X, W_HB2], "fells": [1], "weight": 1.0, "dl": true},
			# each blow alone, whole: its lean and slow way back his chance
			{"name": &"heavy_one", "moves": [W_HA1F], "fells": [0], "weight": 0.7, "dl": true},
			{"name": &"heavy_a2", "moves": [W_HA2], "fells": [0], "weight": 0.6, "dl": true},
			{"name": &"heavy_a3", "moves": [W_HA3], "fells": [0], "weight": 0.6, "dl": true},
			{"name": &"heavy_b2", "moves": [W_HB2], "fells": [0], "weight": 0.6, "dl": true},
			{"name": &"heavy_lunge", "moves": [W_LUNGE], "fells": [0], "weight": 0.8, "dl": true},
		]
		_dl_gaps()
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
	_spear_arm = SpearArm.new()
	_spear_arm.name = "SpearArm"
	_skeleton.add_child(_spear_arm)
	_skeleton.add_child(_left_grip)
	# its hands put on the trunk it tears up
	for side in ["R", "L"]:
		var arm := SpearArm.new()
		arm.name = "PullArm" + side
		arm.upper_bone = side + "_shoulder_joint"
		arm.fore_bone = side + "_elbow_joint"
		arm.wrist_bone = side + "_wrist_joint"
		arm.grip_bone = side + "_equip_joint"
		arm.aim = true
		_skeleton.add_child(arm)
		_pull_arms.append(arm)


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
		_begin(W_UPSTOMP)
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
	# with its tree, coming in: from the gap one of DoubleL's strings covers
	# with its own strides, that string (nearer, the old ones)
	if armed and _dl_open(gap, delta):
		return true
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
	# (the grab put away a while, the user, 2026-10-26: it wants much more
	# work before it is shown again)
	if GRAB_ON and not armed and _grab_wait <= 0.0 and gap <= grab_reach and _in_front(_quarry, 50.0):
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
		var gap := _distance_to(_quarry) if _quarry != null else 0.0
		for i in _hand_combos.size():
			var c: Dictionary = _hand_combos[i]
			if bool(c.get("rage_only", false)) and not raging:
				continue
			# DoubleL's only from the gap their strides cover (else they slid);
			# the old ones from about where their first blow lands
			var first := int((c["moves"] as Array)[0])
			if bool(c.get("dl", false)):
				if not _dl_fits(first, gap):
					continue
			elif absf(gap - float(_strike_from.get(first, gap))) > OLD_FIT:
				continue
			picks.append(i)
		if picks.is_empty():
			# none lands from here: the old one landing nearest
			var best := -1
			var off := 99.0
			for i in _hand_combos.size():
				var c: Dictionary = _hand_combos[i]
				if bool(c.get("dl", false)) or (bool(c.get("rage_only", false)) and not raging):
					continue
				var d := absf(gap - float(_strike_from.get(int((c["moves"] as Array)[0]), gap)))
				if d < off:
					off = d
					best = i
			if best >= 0:
				picks.append(best)
		if not picks.is_empty():
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
	if what == W_UPSTOMP and not is_dead and not armed:
		_begin(W_UPROOT)
		return
	if what == W_UPROOT:
		if stoned == 1:
			_send(&"net_skin", [0])
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
	# (the carry on after the blow taken out, 2026-10-26: its body slid on
	# with its feet still; the lean alone shows the weight)
	return v


func _run_act(delta: float) -> void:
	super(delta)
	if is_dead or not _decides():
		_run_cracks(delta)
		return
	_round7_act(delta)
	if act == T_REEL or act == T_TOTTER or act == T_STAGGER or act == W_UPROOT or act == W_UPSTOMP or act == P_FLEX:
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
	_tree_mesh = mi
	_tree_dropped = false
	if not _skeleton.skeleton_updated.is_connected(_pose_tree):
		_skeleton.skeleton_updated.connect(_pose_tree)


## Every peer, each time its pose is made: while it throws, the tree is
## held as a spear is (the user, 2026-10-25: held one way and then flown
## another it looked broken): turned from the way the hand holds it to lying
## along the throw, snapped end ahead and a little up, gripped near its
## middle, held so through the drawing back, the hold and the cast, and let
## go lying just as it then flies ([TrollRock] takes it on from there).
func _pose_tree() -> void:
	if _tree == null or not is_instance_valid(_tree) or _tree_dropped or _tree_mesh == null:
		return
	var throwing := act == W_THROW and not is_dead
	if _left_grip != null:
		_left_grip.active = armed and not throwing
	if not throwing:
		if _tree.top_level:
			_tree.top_level = false
			_tree.transform = Transform3D.IDENTITY
		return
	var b := _skeleton.find_bone("R_equip_joint")
	if b < 0:
		return
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(b)
	var natural := hand * _tree_mesh.transform
	var size := natural.basis.get_scale().x
	var top := _held_time(W_THROW, 0)
	var w := smoothstep(0.05, maxf(top * 0.55, 0.2), _seen_clock)
	var lead := spear_way()
	var spear := TrollRock.spear_basis(lead)
	var q := natural.basis.get_rotation_quaternion().slerp(spear.get_rotation_quaternion(), w)
	# the hand from the grip (model 0) to its middle, toward the root end
	var at := hand.origin + lead * SPEAR_GRIP * size * w
	_tree.top_level = true
	_tree.global_transform = Transform3D(Basis(q).scaled(Vector3.ONE * size), at) * _tree_mesh.transform.affine_inverse()
	_tree_size = size


## The way the tree lies as it is thrown: along its facing, a little up.
func spear_way() -> Vector3:
	var f := _forward()
	f.y = 0.0
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD
	return (f * cos(_spear_pitch) + Vector3.UP * sin(_spear_pitch)).normalized()


## Every peer, each frame: its throwing arm put as a spear-thrower's is (no
## clip has it): raised and drawn back beside its head, the elbow out and
## down, drawn further back through the hold, then driven out ahead along
## the throw as it lets go, and back to the clip after.
func _drive_spear_arm() -> void:
	if _spear_arm == null:
		return
	if act != W_THROW or is_dead:
		_spear_arm.weight = 0.0
		return
	var c := _seen_clock
	var top := _held_time(W_THROW, 0)
	var held := _held_time(W_THROW, 1)
	var rel := _held_time(W_THROW, 2)
	var w := smoothstep(0.05, maxf(top * 0.7, 0.2), c) * (1.0 - smoothstep(rel + 0.08, rel + 0.5, c))
	_spear_arm.weight = w
	if w <= 0.001:
		return
	var f := _forward()
	f.y = 0.0
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD
	var out := _bone_at("R_shoulder_joint") - global_position
	out.y = 0.0
	out -= f * out.dot(f)
	out = out.normalized() if out.length_squared() > 0.0001 else f.cross(Vector3.UP)
	var pull := smoothstep(top, held, c)
	var carry := (-f * (0.42 + 0.18 * pull) + Vector3.UP * 0.55 + out * 0.5).normalized() * 0.86
	var cast := (spear_way() + Vector3.UP * 0.12 + out * 0.18).normalized() * 0.97
	var push := smoothstep(rel - 0.22, rel, c)
	push *= push
	_spear_arm.reach = carry.normalized().slerp(cast.normalized(), push) * lerpf(0.86, 0.97, push)
	_spear_arm.pole_hint = (Vector3.DOWN + out * 0.7 - f * 0.3).lerp(Vector3.DOWN + out * 0.3, push)


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


## Every peer: as it uproots (2026-10-26, the user: it must take hold of the
## tree and pull it out itself, not have it in its hand all at once): a
## broken trunk pushes up out of the ground just where its hand will reach
## down, its roots still deep; it takes hold, tugs, and as it heaves the tree
## comes up out of the earth in its grip, turned as it goes into just the way
## it is then held (`net_arm` makes that tree where this one is).
##
## The ways it may tear it up (two tried side by side): its clip and the part
## played [rate, from, to]; the shares of the move its hand closes on the
## trunk at (burst up already, at its stamp), the heave tears it out at, and
## it is turned into its right hand's grip over; the hand that takes it; and
## where that hand reaches down to [forward, right, up] in metres.
const UPROOTS := {
	&"lift": {"clip": &"CR_TR_Lift", "play": Vector3(2.4, 0.3, 0.92), "grip": 0.17,
			"heave": 0.6, "turn": Vector2(0.6, 0.93), "hand": "R_equip_joint", "spot": Vector3(0.62, 0.3, 0.7)},
	# (Mixamo's "Pull Plant", standing: both hands down to it, a few tugs,
	# torn up and swung aside)
	&"pull": {"clip": &"CR_TR_PullPlant", "play": Vector3(1.0, 0.0, 1.0), "grip": 0.27,
			"heave": 0.57, "turn": Vector2(0.6, 0.95), "hand": "R_equip_joint", "spot": Vector3(0.67, 0.1, 0.08)},
	# (Mixamo's "Pick Up Torch From The Ground": the left hand down for it and
	# up high with it, then into the right)
	&"pick": {"clip": &"CR_TR_PickFloor", "play": Vector3(1.0, 0.0, 1.0), "grip": 0.36,
			"heave": 0.47, "turn": Vector2(0.8, 1.0), "hand": "L_equip_joint", "spot": Vector3(0.78, -0.5, 0.02)},
}
## Which (the films set it before it is made).
static var uproot_way: StringName = &"pull"
var _up_off: Transform3D               # the tree in its hand's frame, gripped
var _up_spot: Transform3D              # the tree standing in the ground
var _up_torn := false
var _up_lost := -1                     # when its uprooting was cut short (ms)
var _pull_arms: Array[SpearArm] = []   # its hands onto the trunk [right, left]
var _up_held := false                  # torn out, in its hand
var _up_age := 0.0                     # how long since the trunk burst up (s, game time)
const UP_BURST := 0.4                  # how long it takes to come up (s)


## Its stamp before it uproots (2026-10-26, the user: something must guard it
## as it tears its tree up): a shock along the ground throws anyone near off
## his feet and away (a jump clears it, no shield holds it), and its skin
## goes to stone till the tree is up, a blow taking only this share.
const UPROOT_WAVE := 5.5
const UPROOT_TAKEN := 0.25


## Every peer: its tree's roots out of the ground round it (each its node,
## when it breaks out (s after the stamp), where it lies, its way out).
var _up_roots: Array[Dictionary] = []
const ROOT_SPEED := 12.0               # how fast the heave runs out (m/s)
const ROOT_WAYS := 8                   # the ways its roots run out
const ROOT_FAR := 8.0                  # how far (m on a body of 1.6)
const ROOT_DEEP := 1.4                 # how deep they lie before (m)


## Every peer: at its stamp, the roots laid out along five ways from its
## body, under the ground, each to break out as the heave reaches it.
func _roots_up(into: Node3D, fw: Vector3) -> void:
	_roots_sink()
	var s := visual_scale / 1.6
	# (2026-10-26, the user: grander, bigger, further and more of them):
	# eight ways out, each forking once on its way
	for k in ROOT_WAYS:
		var dir := fw.rotated(Vector3.UP, TAU * float(k) / float(ROOT_WAYS) + randf_range(-0.15, 0.15))
		_root_line(into, global_position, dir, 0.6 * s, ROOT_FAR * s * randf_range(0.8, 1.0), 1.0)
		var fork := dir.rotated(Vector3.UP, randf_range(0.45, 0.7) * (1.0 if randf() < 0.5 else -1.0))
		var from := global_position + dir * ROOT_FAR * s * randf_range(0.3, 0.45)
		_root_line(into, from, fork, 0.0, ROOT_FAR * s * 0.45, 0.7)


## Every peer: one line of roots out from `from` along `dir`, `start` to
## `far` metres, `big` their size (its own share).
func _root_line(into: Node3D, from: Vector3, dir: Vector3, start: float, far: float, big: float) -> void:
	var s := visual_scale / 1.6
	var at := start
	var head := Vector2(from.x - global_position.x, from.z - global_position.z).length()
	while at < far:
		# thickest near its body, thinner out to the end
		var grow := big * lerpf(1.25, 0.75, at / maxf(far, 0.1))
		var length := randf_range(1.5, 2.2) * s * grow
		var way := dir.rotated(Vector3.UP, randf_range(-0.3, 0.3))
		var side := way.cross(Vector3.UP).normalized()
		var lay := Basis(way * length, Vector3.UP * randf_range(1.5, 2.1) * s * grow, side * 1.7 * s * grow)
		var origin := from + dir * at
		origin.y = global_position.y
		var mi := MeshInstance3D.new()
		mi.mesh = TrollRock.mesh("GroundRoot_%d" % randi_range(0, 2))
		mi.material_override = TrollRock.material()
		into.add_child(mi)
		var base := Transform3D(lay, origin)
		mi.global_transform = base.translated(Vector3.DOWN * ROOT_DEEP * s)
		_up_roots.append({"n": mi, "d": (head + at) / ROOT_SPEED, "b": base, "out": false, "way": way})
		at += length * randf_range(0.7, 0.9)


## Every peer, each frame: each root breaking out as the heave reaches it (a
## touch past, then settling), and straining as it is tugged at.
func _show_roots(share: float, way: Dictionary) -> void:
	var s := visual_scale / 1.6
	var strain := smoothstep(float(way["grip"]), float(way["heave"]), share) if act == W_UPROOT else 0.0
	var into := Blood.world_of(self)
	for r: Dictionary in _up_roots:
		var mi := r["n"] as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var k := clampf((_up_age - float(r["d"])) / 0.3, 0.0, 1.0)
		if k > 0.0 and not bool(r["out"]):
			r["out"] = true
			if into != null:
				GroundFx.weapon_dust(into, (r["b"] as Transform3D).origin, 1.1)
		var rise := 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)
		var base: Transform3D = r["b"]
		var shake := Basis((r["way"] as Vector3), 0.05 * strain * sin(_up_age * 40.0 + float(r["d"]) * 13.0))
		mi.global_transform = Transform3D(shake * base.basis, base.origin + Vector3.DOWN * ROOT_DEEP * s * (1.0 - rise)
				+ Vector3.UP * 0.05 * s * strain * absf(sin(_up_age * 23.0 + float(r["d"]) * 7.0)))


## Every peer: as the tree is torn out, its roots torn up out of the ground
## after it, earth flying, and gone.
func _roots_torn() -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	var to := _rising.global_position if _rising != null and is_instance_valid(_rising) else global_position
	for r: Dictionary in _up_roots:
		var mi := r["n"] as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var at := mi.global_position
		var pull := to - at
		pull.y = 0.0
		var tw := mi.create_tween().set_parallel(true)
		var wait := 0.035 * at.distance_to(to)
		tw.tween_property(mi, "global_position", at + pull * 0.3 + Vector3.UP * 1.2 * s, 0.4).set_delay(wait).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", mi.scale * 0.05, 0.4).set_delay(wait + 0.05).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
		if into != null and randf() < 0.5:
			GroundFx.weapon_dust(into, Vector3(at.x, global_position.y, at.z), 0.8)
	_up_roots.clear()


## Every peer: its roots let sink back into the ground (cut short).
func _roots_sink() -> void:
	for r: Dictionary in _up_roots:
		var mi := r["n"] as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var tw := mi.create_tween()
		tw.tween_property(mi, "global_position", mi.global_position + Vector3.DOWN * 0.8, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)
	_up_roots.clear()


## Host: the shock of its stamp (out from its body, all round).
func _uproot_wave() -> void:
	var reach_m := UPROOT_WAVE * visual_scale / 1.6
	for who: Node3D in WeaponSweep.targets(get_tree()):
		var d := Vector2(who.global_position.x - global_position.x, who.global_position.z - global_position.z).length()
		if d <= reach_m:
			# (thrown the harder the nearer: its force rides on the "sweep"
			# a blow leaves on him, [method WeaponSweep.motion_on])
			var away := who.global_position - global_position
			away.y = 0.0
			away = away.normalized() if away.length_squared() > 0.0001 else -_forward()
			var push := lerpf(42.0, 28.0, d / reach_m)
			who.set_meta(&"blow_sweep", [away * push + Vector3.UP * 2.5, Engine.get_physics_frames()])
			who.call(&"receive_blow", hit_damage * 0.35, self, 0, 1, 7100000 + act_serial, false, &"ground")


## Its stamping foot (the right ankle) raised above, and down again below,
## so high (m on a body of 1).
const UPSTOMP_RAISED := 0.45
const UPSTOMP_DOWN := 0.18
var _up_raised := false
var _up_down := false


func _show_uproot() -> void:
	_put_pull_arms()
	var uprooting := act == W_UPROOT or act == W_UPSTOMP
	if not uprooting or _skeleton == null:
		# (cut short, it lets go and the trunk sinks back; a moment given
		# first, for its arming to reach this peer)
		if _rising != null and is_instance_valid(_rising) and not armed:
			if _up_lost < 0:
				_up_lost = Time.get_ticks_msec()
			elif Time.get_ticks_msec() - _up_lost > 600:
				_roots_sink()
				var gone := _rising
				_rising = null
				var tw := gone.create_tween()
				tw.tween_property(gone, "global_position", gone.global_position + Vector3.DOWN * 2.5, 0.8).set_ease(Tween.EASE_IN)
				tw.tween_callback(gone.queue_free)
		return
	_up_lost = -1
	var way: Dictionary = UPROOTS[uproot_way]
	# (born as its stamping foot comes down: watched, raised and down again)
	if act == W_UPSTOMP and _rising == null:
		var ab := _skeleton.find_bone("R_ankle_joint")
		if ab >= 0:
			var h := (_skeleton.global_transform * _skeleton.get_bone_global_pose(ab).origin).y - global_position.y
			if h > UPSTOMP_RAISED * visual_scale:
				_up_raised = true
			_up_down = _up_raised and h < UPSTOMP_DOWN * visual_scale
		else:
			_up_down = _seen_clock >= 1.4
	if _rising == null and not armed and (act == W_UPROOT or _up_down):
		var into := Blood.world_of(self)
		if into == null:
			return
		_rising = Node3D.new()
		_rising.name = "TrollTreeRising"
		into.add_child(_rising)
		var mi := MeshInstance3D.new()
		mi.mesh = TrollRock.mesh("Tree")
		var mat := TrollRock.material().duplicate() as ShaderMaterial
		mat.set_shader_parameter("bright", 1.15)
		mi.material_override = mat
		_rising.add_child(mi)
		# upright, roots down, its grip just where its hand will close,
		# leaning a little toward it
		var fw := _forward()
		fw.y = 0.0
		fw = fw.normalized()
		var right := fw.cross(Vector3.UP).normalized()
		var at: Vector3 = way["spot"]
		var grip := global_position + fw * at.x + right * at.y + Vector3.UP * at.z
		var size := tree_scale * visual_scale
		_up_spot = Transform3D(Basis(right, -0.12) * Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * size), grip)
		_rising.global_transform = _up_spot.translated(Vector3.DOWN * 2.4)
		_up_torn = false
		_up_age = 0.0
		_up_held = false
		_up_raised = false
		_up_down = false
		# the ground split from its foot to where the trunk bursts up
		var foot := _foot_at()
		foot.y = global_position.y
		var ground := Vector3(grip.x, global_position.y, grip.z)
		var way_to := ground - foot
		way_to.y = 0.0
		if way_to.length() > 0.2:
			GroundCrack.show(self, foot, way_to.normalized(), way_to.length() + 0.4, crack_speed)
		GroundFx.weapon_dust(into, foot, 1.4)
		GroundFx.eruption(into, ground, 0.8, false)
		GroundFx.weapon_dust(into, ground, 1.6)
		WindBlast.shake(self, 0.16, 0.6, 20.0)
		Sfx.play_any(self, [SOUNDS + "club_ground_1.wav", SOUNDS + "club_ground_3.wav"], self, 0.9, 0.0)
		Sfx.play_any(self, [SOUNDS + "strain_rise.wav"], self, 0.6, 0.0)
		# its stamp's shock: its tree's roots heave up out of the earth
		# all round, out along five ways (2026-10-26, the user)
		_roots_up(into, fw)
		if _decides() and act == W_UPSTOMP:
			_uproot_wave()
			_send(&"net_skin", [1])
		if not _skeleton.skeleton_updated.is_connected(_hold_rising):
			_skeleton.skeleton_updated.connect(_hold_rising)
	if _rising == null or not is_instance_valid(_rising):
		return
	_up_age += get_process_delta_time()
	var share := _uproot_share() if act == W_UPROOT else 0.0
	_show_roots(share, way)
	if act == W_UPROOT and share >= float(way["heave"]) and not _up_torn:
		_up_torn = true
		_roots_torn()
		var into := Blood.world_of(self)
		if into != null:
			var at := _rising.global_position
			var spot := Vector3(at.x, global_position.y, at.z)
			GroundFx.eruption(into, spot, 1.1, false)
			GroundFx.weapon_dust(into, spot, 1.8)
			WindBlast.shake(self, 0.14, 0.8, 20.0)
			Sfx.play_any(self, [SOUNDS + "roar.wav", SOUNDS + "grunt_1.wav"], self, 0.8, 0.0)
			for k in 6:
				var piece := TrollRock.model(TrollRock.Kind.SMALL, k)
				into.add_child(piece)
				piece.global_position = spot + Vector3(randf_range(-0.6, 0.6), 0.2, randf_range(-0.6, 0.6))
				var up := piece.create_tween()
				up.tween_property(piece, "global_position", piece.global_position + Vector3(randf_range(-1.5, 1.5), randf_range(1.5, 3.0), randf_range(-1.5, 1.5)), 0.4).set_ease(Tween.EASE_OUT)
				up.tween_property(piece, "global_position:y", spot.y + 0.05, 0.45).set_ease(Tween.EASE_IN)
				up.tween_interval(2.5)
				up.tween_callback(piece.queue_free)


## Every peer, each frame: its hands brought onto the trunk as they reach
## down for it, held there through the tugs, let go back to the clip as it
## comes up (in the hand then).
func _put_pull_arms() -> void:
	if _pull_arms.size() < 2:
		return
	var w := 0.0
	var way: Dictionary = UPROOTS[uproot_way]
	if act == W_UPROOT and _rising != null and is_instance_valid(_rising) and not armed:
		var share := _uproot_share()
		var grip := float(way["grip"])
		var heave := float(way["heave"])
		w = smoothstep(grip - 0.12, grip, share) * (1.0 - smoothstep(heave, heave + 0.12, share))
	var left_only := String(way["hand"]).begins_with("L")
	(_pull_arms[0] as SpearArm).weight = 0.0 if left_only else w
	(_pull_arms[1] as SpearArm).weight = w
	if w <= 0.0:
		return
	# the right on its haft just above the ground, the left a little higher
	var at := _rising.global_position
	var up := -_rising.global_basis.y.normalized()
	var s := visual_scale / 1.6
	(_pull_arms[0] as SpearArm).aim_at = at
	(_pull_arms[1] as SpearArm).aim_at = at + up * (0.0 if left_only else 0.24 * s)
	for arm: SpearArm in _pull_arms:
		arm.pole_hint = Vector3.DOWN + _forward() * -0.3


func _uproot_share() -> float:
	var m: Array = _moves_table[W_UPROOT]
	var length := _anim.clip_length(m[0]) / float(m[1]) * (float(m[3]) - float(m[2])) if _anim != null else 3.0
	return _seen_clock / maxf(length, 0.1)


## Every peer, each time its pose is made while it uproots: the tree put.
func _hold_rising() -> void:
	if _rising == null or not is_instance_valid(_rising) or armed or not (act == W_UPROOT or act == W_UPSTOMP):
		return
	var way: Dictionary = UPROOTS[uproot_way]
	var gb := _skeleton.find_bone(String(way["hand"]))
	var rb := _skeleton.find_bone("R_equip_joint")
	if gb < 0 or rb < 0:
		return
	var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(gb)
	var share := _uproot_share() if act == W_UPROOT else 0.0
	if not _up_held and (act == W_UPSTOMP or share < float(way["heave"])):
		# still rooted, where it burst up (a touch past, then settling, then
		# rocking), and trembling as its hands (put on it) tug
		var e := _up_age
		var k := clampf(e / UP_BURST, 0.0, 1.0)
		var rise := 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)
		var rock := Basis(Vector3.FORWARD, 0.07 * sin(e * 22.0) * exp(-e * 2.5))
		var strain := smoothstep(float(way["grip"]) + 0.05, float(way["heave"]), share) if act == W_UPROOT else 0.0
		rock = Basis(Vector3.RIGHT, 0.035 * strain * sin(share * 90.0)) * rock
		_rising.global_transform = Transform3D(rock * _up_spot.basis, _up_spot.origin + Vector3.DOWN * 2.4 * (1.0 - rise))
		return
	if not _up_held:
		# torn out: in its hand from here, just where its hand had it
		_up_held = true
		_up_off = hand.affine_inverse() * _rising.global_transform
	# then turned into how it is held
	var off := _up_off
	var held := Transform3D(Basis(Vector3.BACK, -PI * 0.5).scaled(Vector3.ONE * tree_scale), Vector3.ZERO)
	var tv: Vector2 = way["turn"]
	var w := smoothstep(tv.x, tv.y, share)
	if gb == rb:
		_rising.global_transform = hand * off.interpolate_with(held, w)
	else:
		# (taken in the other hand: passed into the right as it is turned)
		var right_hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(rb)
		_rising.global_transform = (hand * off).interpolate_with(right_hand * held, w)

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
	_drive_spear_arm()
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
			or act == W_UPROOT or act == W_UPSTOMP or act == P_GRAB or act == S_SPLASH or act == S_DOWN or act == S_SKIN \
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
	# tearing its tree up (2026-10-26, the user: it must not be killed in
	# it): its skin gone to stone, a blow takes a quarter, and none takes
	# its last
	if (act == W_UPSTOMP or act == W_UPROOT) and _decides():
		if stoned == 1 or act == W_UPROOT:
			damage *= UPROOT_TAKEN
		damage = minf(damage, maxf(health - max_health * 0.02, 0.0))
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
	# (the sun's shafts put away, 2026-10-26, the user: it wants none of
	# them, slowing and stiffening it; none are made with it)
	if SUN_ON and not _suns_made:
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
		# the way it will be cast told to all, so it is held lying that way:
		# at the start and again as the hold ends (he may have moved)
		var aim_step := 0 if _act_time < _held_time(W_THROW, 1) - 0.25 else 1
		if _quarry != null and _spear_sent != act_serial * 2 + aim_step:
			_spear_sent = act_serial * 2 + aim_step
			_send(&"net_spear", [_aim_pitch()])
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
	_motes(world, ring, Color(0.46, 0.4, 0.32, 0.45), 3, Vector2(1.0, 2.2) * gather,
			(global_position - ring).normalized() + Vector3.UP * 0.2, 20.0, Vector2(0.12, 0.25), Vector3.ZERO, 0.6)
	if act == W_THROW and _tree != null and is_instance_valid(_tree):
		# earth shaken off its roots as it is swung up
		var roots := _tree_head()
		_motes(world, roots, Color(0.35, 0.27, 0.18, 1.0), 3, Vector2(0.3, 1.2), Vector3.DOWN, 60.0,
				Vector2(0.05, 0.1), Vector3(0, -10.0, 0), 0.9)
		if randf() < 0.35:
			_motes(world, roots, Color(0.42, 0.5, 0.25, 1.0), 2, Vector2(0.3, 1.0), Vector3.DOWN, 80.0,
					Vector2(0.06, 0.1), Vector3(0, -2.0, 0), 1.4)
	elif act == P_CLAP:
		# the air drawn to its palms
		var hands := _held_at(TrollRock.Kind.BIG)
		var b := randf() * TAU
		var from := hands + Vector3(cos(b), randf_range(-0.4, 0.6), sin(b)) * 1.8 * s
		_motes(world, from, Color(0.85, 0.83, 0.78, 0.3), 2, Vector2(2.0, 3.5) * gather,
				(hands - from).normalized(), 8.0, Vector2(0.15, 0.3), Vector3.ZERO, 0.45)
#endregion


#region The tree thrown
## Every peer: a few motes of earth (not `SkillFx.burst`, whose motes are
## born white: these drew white squares round it as it wound up).
static func _motes(into: Node, at: Vector3, color: Color, count: int, speed: Vector2, dir: Vector3,
		spread: float, size: Vector2, gravity: Vector3, life: float) -> void:
	SkillFx.particles(into, at, {
		"amount": count, "life": life, "one_shot": true, "explosiveness": 0.95, "add": false,
		"speed": speed, "dir": dir, "spread": spread, "gravity": gravity, "damping": 2.0,
		"size": Vector2(size.x * 0.5, size.y * 0.5),
		"colors": [color, color, Color(color.r, color.g, color.b, 0.0)],
	})


func _throw_tree() -> void:
	if _quarry == null:
		return
	trees_thrown += 1
	_thrown_tree = true
	# from just where it is held (its model's grip point), not elsewhere
	var from := _tree.global_position if _tree != null and is_instance_valid(_tree) \
			else _tree_head().lerp(_bone_at("R_equip_joint"), 0.5)
	var target := _quarry.global_position + Vector3.UP * 0.6
	var v := _cast(from, target, _spear_pitch)
	var size := _tree_size if _tree_size > 0.0 else tree_scale * visual_scale
	_send(&"net_javelin", [from, v, hit_damage * 1.6, act_serial * 10 + 6, size])
	_send_arm(false)


## A fast flat cast at `target`; the up of it as it leaves.
func _straight_cast(from: Vector3, target: Vector3) -> Vector3:
	var gap := Vector3(target.x - from.x, 0.0, target.z - from.z).length()
	var flight := clampf(gap / 22.0, 0.35, 0.9)
	return (target - from) / flight + Vector3.UP * 0.5 * TrollRock.GRAVITY * flight


## Host: the pitch it will be cast at, from where it is held now.
func _aim_pitch() -> float:
	var from := _tree.global_position if _tree != null and is_instance_valid(_tree) else _bone_at("R_equip_joint")
	var v := _straight_cast(from, _quarry.global_position + Vector3.UP * 0.6)
	var flat := Vector2(v.x, v.z).length()
	return clampf(atan2(v.y, flat), -0.45, 0.45)


## Host: cast at `target` leaving at `pitch` (just as it was held lying),
## the speed found for it; when no fit speed carries it there at that, the
## fast flat cast (the thrown tree then turns its way at once).
func _cast(from: Vector3, target: Vector3, pitch: float) -> Vector3:
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var gap := flat.length()
	var rise := target.y - from.y
	var c := cos(pitch)
	var room := gap * tan(pitch) - rise
	if gap > 0.5 and room > 0.2:
		var speed := sqrt(0.5 * TrollRock.GRAVITY * gap * gap / (c * c * room))
		if speed >= 14.0 and speed <= 42.0:
			return (flat / gap * c + Vector3.UP * sin(pitch)) * speed
	return _straight_cast(from, target)


## Every peer: the way the tree will go, so it is held lying so.
@rpc("authority", "call_local", "reliable")
func net_spear(pitch: float) -> void:
	_spear_pitch = pitch


@rpc("authority", "call_local", "reliable")
func net_javelin(from: Vector3, v: Vector3, worth: float, id: int, size: float) -> void:
	# taken on from just as it is seen held here, lying as it lies
	var held := Basis()
	var have := false
	if _tree != null and is_instance_valid(_tree):
		if _tree_mesh != null and is_instance_valid(_tree_mesh):
			held = _tree_mesh.global_basis
			have = true
		_tree.queue_free()
		_tree = null
		_tree_mesh = null
	Sfx.play_any(self, [SOUNDS + "roar_short.wav", SOUNDS + "grunt_2.wav"], self, 0.8, 0.0)
	TrollRock.javelin(Blood.world_of(self), from, v, worth, self, _decides(), id, size, held if have else Basis(), have)
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
