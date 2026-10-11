class_name OgreFighter
extends PackBrute

## The ogre (Polysplit's Biped Creatures, CREATURES_PACK.md): a great club,
## slow and heavy (the user's picks, 2026-10-07; its fight made over in
## Elden Ring's way, 2026-10-08: "it does the same combo again and again").
##
## * **Strings, light and heavy.** Its swings are of two kinds: quick light
##   ones (a sweep, a chop, a backhand, a low sweep, a wide one round to the
##   side), that only stagger him, and heavy ones (an overhead smash, a
##   cleave, a leaping slam, a whirl brought down) that throw him down by
##   themselves (Elden Ring's rule, the user's word 2026-10-09: "not every
##   second blow should knock you down"). Each swing may run on into another
##   (`FOLLOW`, weighed; never the same twice running), up to `string_most`
##   of them, each turned a little after him; the close of a long one
##   (`finisher_from`) fells him too, light or not, if all of it found him.
##   Then it stands to get its breath (`recover`) — the opening.
## * **Where he stands chooses.** Off to its side it sweeps round at him; at
##   its back, the backhand; hugging it, a kick that beats a raised shield
##   aside; 4.5-8 m off, a lunge; the opener it began with last time is
##   seldom the next.
## * **Delayed swings** ([PackBrute] `_holds`): a heavy one, now and then,
##   held at the top of its wind-up before it comes down; him backed out of
##   its reach meanwhile, it slides at him fast as it lets go and follows him
##   round to the blow (`slide_*`): running does not beat it, a roll does.
##   And the roll-catch
##   (`CATCH`): him rolled out from under a blow, the next comes held a
##   beat, timed for the end of a roll made too early.
## * **Tracking, then committed** (Elden Ring's): each swing and leap turns
##   after him up to a late point before its blow (`commit_lead`), and is
##   locked from there — it is the timing of a roll that beats it, not
##   running from it.
## * **Its gait** (the user's word, 2026-10-09): a heavy walk of long strides
##   about its ground, a lumbering trot (`trot_clip`) coming at him, and a
##   real run (`run_speed`) when he plainly runs from it; each clip played at
##   the pace its feet keep to the ground.
## * **From afar** (the distance ladder): 4.5-8 m the sword dash (`LUNGE`);
##   8-14 m a great leap with the club overhead, brought down on him
##   (`LEAP_SLAM`); 12-22 m it runs at him, springs high and comes down club
##   first (`RUN_SLAM`). Both fell him; they follow him till they leave the
##   ground and are locked a little after.
## * **Aftershock**: a single heavy blow or a slam that strikes the ground is
##   followed a beat later by a second burst of earth ahead of it — the one
##   who comes back in too soon is caught (a jump or a roll clears it).
## * **The ground struck** (`CR_GroundPound`): the club brought down on the
##   ground sends a shock out round it ([PackBrute._quake], `pound_radius`):
##   whoever is on the ground as it passes is thrown down. Jump it, or roll.
## * **The great blow** (`CR_Heavy2`): the club raised slowly overhead, glowing
##   hotter as it goes (`heavy_slow`), and brought down: no shield holds it
##   (a "crush": the guard is beaten down and most of it lands), and it
##   throws him down. Get out from under it.
## * **The fallen trodden.** Him down within `stomp_reach`: the club brought
##   down on him where he lies ("stomp"). Roll out, or get up quick.
## * **Its stance** ([PackBrute]): no blow stops it or pushes it about, but
##   enough of them, heavy ones above all, put it down on a knee, open.
## * **Rage** ([PackBrute]): at half its health — and its strings run longer,
##   with the pound and the great blow in them.
## * **Combos** (`COMBOS`, the user's word 2026-10-10: a new combo, Elden
##   Ring's way): besides the strings weighed swing by swing, a few combos
##   made by hand, always the same moves in the same order, so they can be
##   learnt — Mixamo's great axe and great sword swings on its club. Their
##   last blow (`fells` in each) throws him down by itself; the ones before
##   only stagger. Some hold the closing blow at the top a beat (the delayed
##   finisher). Opened now and then instead of a string (`combo_chance`).
##   Some read him before their close (`branch`: he rolled, he is far off),
##   enraged most run longer (`rage`) and two come only then (`rage_only`);
##   hugging it, it headbutts, stamps or swipes him off (`close`), and at a
##   raised shield it swings its free hand at it first (`guard`).
## * **A held blow shows** (the user's word, 2026-10-10): the moment a swing
##   stops at the top of its wind-up, a glint off the club and a growl
##   ([method _glint]) — the delay can be learnt, not only guessed.

@export_group("Pound")
@export var pound_clip: StringName = &"CR_GroundPound"
@export var pound_part: Vector3 = Vector3(1.0, 0.0, 0.92)
@export var pound_radius: float = 5.5
@export var pound_share: float = 0.85
## The pound three times (the user's word, 2026-10-11): a slam, a second one
## quick on it, and a third held overhead a beat and brought down hardest —
## each sends rock out further (m, at its size: 5, 10, 20 — 40 was too far,
## the user's word), no ring.
@export var pound_reaches: Vector3 = Vector3(5.0, 10.0, 20.0)

@export var pound_from: float = 1.5
@export var pound_to: float = 5.0
@export var pound_cooldown: Vector2 = Vector2(9.0, 14.0)

@export_group("Great blow")
@export var heavy_clip: StringName = &"CR_Heavy2"
@export var heavy_part: Vector3 = Vector3(0.95, 0.0, 0.9)
## How many times slower its wind-up is played, and how long before the blow
## it comes back to its own pace.
@export var heavy_slow: float = 2.4
@export var heavy_lead: float = 0.18
@export var heavy_share: float = 1.5
@export var heavy_cooldown: Vector2 = Vector2(8.0, 13.0)
## The great blow does not miss him by his walking off (the user's word,
## 2026-10-11): it turns after where he will be through its glowing wind-up
## till `heavy_commit` s before the blow, and him out of its reach it closes on
## him over its last `heavy_close` s (`heavy_close_most` m at most; a roll
## still beats it).
@export var heavy_commit: float = 0.12
@export var heavy_close: float = 0.5
@export var heavy_close_most: float = 8.0
## ...and the ground it strikes bursts up in rock all round (rows of stone
## out from the club to `heavy_rock_length` m, [RockWave]), and the
## blow goes through the ground to everyone on it within `heavy_quake_radius`
## m (at its size): they are thrown down (jump it, or roll).
@export var heavy_rock_length: float = 20.0
@export var heavy_quake_radius: float = 20.0
## How fast its rock runs out over the ground (m/s): the blow through the
## ground goes out with it.
@export var rock_pace: float = 22.0
@export var heavy_quake_share: float = 0.8

@export_group("Stomp")
@export var stomp_clip: StringName = &"CR_Heavy2"
@export var stomp_part: Vector3 = Vector3(1.3, 0.0, 0.85)
@export var stomp_reach: float = 3.4
@export var stomp_share: float = 0.6
@export var stomp_cooldown: float = 5.0
## The share of the times it treads on him down rather than wait for him.
@export var stomp_chance: float = 0.6

@export_group("Strings")
## The most swings in one string, calm and enraged.
@export var string_most: int = 3
## How soon after a swing's last blow the next of its string begins (s).
@export var string_follow_after: float = 0.32
@export var string_most_raging: int = 5
## Its breath got back after a string ends (s), calm and enraged.
@export var recover: Vector2 = Vector2(0.5, 1.1)
@export var recover_raging: Vector2 = Vector2(0.25, 0.6)
## Between its strings (and over him while he is down) it does not stand dead
## still (the user's word, 2026-10-10: it stood about a third of a fight): it
## prowls round him at this pace (m/s at its size), keeping to its reach,
## facing him, and now and then turns the other way.
@export var prowl_speed: float = 0.8
@export var prowl_turn_every: Vector2 = Vector2(1.0, 2.2)
## ...never further round him than this (deg) from where it last came at him:
## it does not end up behind him (the camera's side).
@export var prowl_arc: float = 30.0
## How far it turns after him between two swings of a string (degrees).
@export var string_turn: float = 55.0
@export var lunge_from: float = 4.5
@export var lunge_to: float = 8.0
@export var lunge_cooldown: Vector2 = Vector2(6.0, 10.0)
@export var kick_cooldown: float = 4.0
@export_group("Gait")
## Its trot coming at him (the walk is `walk_clip`, the run `run_clip`); the
## paces it changes from walk to trot and from trot to run (m/s).
@export var trot_clip: StringName = &"CR_OgreTrot"
@export var trot_above: float = 2.9
@export var run_gait_above: float = 4.9
## No trot (the user's word, 2026-10-11: the jog out, its quick run in its
## place): coming at him it runs, at `run_speed`, as it did only when he ran.
@export var runs_after: bool = true
## Its run, when he runs from it: the gap opening this fast (m/s) for this
## long (s) with him this far off.
@export var run_speed: float = 6.0
@export var flee_rate: float = 1.2
@export var flee_time: float = 0.6
@export var flee_from: float = 5.0

@export_group("From afar")
@export var leap_slam_clip: StringName = &"CR_Heavy4"
@export var leap_slam_part: Vector3 = Vector3(1.0, 0.0, 0.92)
@export var leap_slam_from: float = 8.0
@export var leap_slam_to: float = 14.0
@export var leap_slam_cooldown: Vector2 = Vector2(8.0, 12.0)
@export var leap_slam_share: float = 1.3
@export var run_slam_clip: StringName = &"CR_RunJumpSlam"
@export var run_slam_part: Vector3 = Vector3(1.0, 0.218, 1.0)
@export var run_slam_from: float = 12.0
@export var run_slam_to: float = 22.0
## It springs off its run this far from him.
@export var run_slam_takeoff: float = 9.5
@export var run_slam_cooldown: Vector2 = Vector2(10.0, 16.0)
@export var run_slam_share: float = 1.5

@export_group("Elden Ring")
## How long before a blow it stops turning after him (s): light, heavy.
@export var commit_lead: Vector2 = Vector2(0.28, 0.36)
## The roll-catch's hold, and how often it answers a roll with it.
@export var catch_hold: Vector2 = Vector2(0.42, 0.55)
@export var catch_chance: float = 0.65
## The aftershock: how long after the blow, how far ahead of the club, how
## wide, and its worth (a share of `hit_damage`; it staggers, never fells).
@export var aftershock_after: float = 0.4
@export var aftershock_ahead: float = 1.1
@export var aftershock_radius: float = 2.6
@export var aftershock_share: float = 0.45
## Whether its blows into the ground answer a beat later with that second,
## unseen burst ahead of the club. Off (the user's word, 2026-10-11): it read
## as a hit out of nowhere, small stones and a stagger with nothing to warn
## of it; the rock of the great blow and the pound stays. Its stamping foot
## still uses the burst (seen coming).
@export var aftershocks_follow: bool = false
## A held swing (the user's word, 2026-10-09): planted through its wind-up
## and its hold — no stepping in or backing off, so no glide and no rocking
## to and fro as he moves round it; let go with him out of its reach (by
## more than `slide_slack` m), it slides at him at once from the end of the
## hold to its blow, turning after him all the way — only a roll beats it.
## It slides no further than `slide_most` (m at its size).
@export var slide_most: float = 11.0
@export var slide_slack: float = 0.15
## Running does not beat a held swing, a jump slam or a leap (the user's
## word, 2026-10-10: running fast he kept out of its reach — only a roll
## must): they go for where he will be when the blow lands, his run carried
## on (`chase_lead_most` s of it at most), and turn after him until
## `chase_commit` s before the blow (a leap: `chase_flight_commit` of its
## flight). The jump slam closes on him over its last `jump_slam_close` s,
## `jump_slam_most` m at most.
@export var chase_lead_most: float = 1.2
@export var chase_commit: float = 0.12
@export var chase_flight_commit: float = 0.85
@export var jump_slam_close: float = 0.55
@export var jump_slam_most: float = 7.0
## The whirl that slides ([constant OG_SPIN_SLIDE], the user's word 2026-10-11:
## fast, as Tariel's and the assassin's glide at a foe, and from 15-20 m too):
## him off out of its reach, it shoots at him at `spin_dash_speed` (m/s at its
## size), timed to get there as the club comes round — far off, the slide
## starts in its wind-up and the turn comes on the way; near, it turns and
## shoots in at the end. No further than `spin_slide_most` m.
@export var spin_dash_speed: float = 20.0
@export var spin_slide_most: float = 24.0
## Its combos' moves played this much quicker than the clips (the user's word,
## 2026-10-11: they were too slow): light, heavy.
@export var combo_pace: Vector2 = Vector2(1.5, 1.32)

@export_group("Combos")
## How often it opens a combo of its own (`COMBOS`) rather than a string, he
## in front and in reach of its first move: calm, enraged.
@export var combo_chance: Vector2 = Vector2(0.4, 0.55)
## Hugging it (him closer than its kick's reach), how often it answers with one
## of its close combos (a headbutt, a stamp, a swipe of its free hand) rather
## than the kick.
@export var close_combo_chance: float = 0.6
## A combo reads him before a `branch`: he is "far" past its next move's reach
## by this much (m at its size).
@export var branch_far: float = 1.5

@export_group("Strings")
## The closing swing of a string this long or longer (calm, enraged) throws
## him down even if it is a light one — if every blow of the string before
## it found him ([Player.receive_blow]). Shorter strings end on a stagger.
@export var finisher_from: Vector2i = Vector2i(3, 4)

const SOUNDS := "res://sounds/ogre/"
const WHOOSH_HEAVY := SOUNDS + "whoosh_heavy.wav"
const WHOOSH_LIGHT := SOUNDS + "whoosh_light.wav"
const ROAR_SOUND := SOUNDS + "roar.wav"
const ROAR_SHORT_SOUND := SOUNDS + "roar_short.wav"
const GRUNTS := [SOUNDS + "grunt_1.wav", SOUNDS + "grunt_2.wav", SOUNDS + "grunt_3.wav"]
const CLUB_GROUND := [SOUNDS + "club_ground_1.wav", SOUNDS + "club_ground_2.wav", SOUNDS + "club_ground_3.wav",
		SOUNDS + "club_ground_4.wav"]
const STEPS := [SOUNDS + "step_1.wav", SOUNDS + "step_2.wav", SOUNDS + "step_3.wav"]

const POUND := 113
const HEAVY := 114
const STOMP := 115
## Its light swings.
const SWEEP := 130
const CHOP := 131
const BACKHAND := 132
const WIDE := 133
const LOW := 134
## Its heavy ones.
const SMASH := 135
const CLEAVE := 136
const JUMP_SLAM := 137
const WHIRL := 138
## A kick at him hugging it, and a lunge from further off.
const KICK := 139
const LUNGE := 140
## Its leaps from afar, and the roll-catch.
const LEAP_SLAM := 141
const RUN_SLAM := 143
const CATCH := 144
## The combos' own moves (Mixamo's great axe and great sword, 2026-10-10).
const OG_HORIZ := 150
const OG_BACK := 151
const OG_DOWN := 152
const OG_SPIN := 153
const OG_TWIN := 154
const OG_DOUBLE := 155
const OG_TRIPLE := 156
const OG_JUMP := 157
const OG_DOWN_HELD := 158
const OG_JUMP_HELD := 159
## ...and fresh from Mixamo (vepxis-art/mixamo_ogre): its two-handed club
## combo, the one-handed one, the club down into the ground two-handed, and
## a great leap down on him.
const OG_CLUB2H := 160
const OG_CLUB1H := 161
const OG_GROUND := 162
const OG_MJUMP := 163
## The whirl closing the run of three, drawn out (the user's word, 10-10
## 19:29): slower, and him off out of its reach it slides at him through the
## turn, so it comes round on him as it gets to him, not slid up and then
## turned ([constant FLIGHTS], no lift).
const OG_SPIN_SLIDE := 164
## Hugging it: a headbutt, a stamp of its foot (the ground bursting up round
## it, [method _aftershock]) and its free hand swung at him (beats a raised
## shield aside, "guard").
const OG_HEADBUTT := 165
const OG_STOMP_FOOT := 166
const OG_SWIPE := 167
## The pound's second (quick) and third (held overhead, then brought down).
const POUND_2 := 168
const POUND_3 := 169
## what -> [clip, [rate, from, to], heavy, share of `hit_damage`, its blows'
## moments (shares of the clip; empty: where the club reaches furthest),
## name ([member BLOW_NAMES]), held at the top [shortest, longest, s before
## the blow] or [] (always held, when given)].
const COMBO_MOVES := {
	OG_HORIZ: [&"CR_OG_Attack_Horizontal", Vector3(0.95, 0.1, 0.8), false, 0.6, [], &"og_horiz", []],
	OG_BACK: [&"CR_OG_Attack_Backhand", Vector3(0.95, 0.08, 0.62), false, 0.6, [], &"og_back", []],
	OG_DOWN: [&"CR_OG_Attack_Downward", Vector3(0.9, 0.05, 0.75), true, 1.1, [], &"og_down", []],
	OG_SPIN: [&"CR_OG_Attack_360", Vector3(0.9, 0.0, 0.7), true, 1.2, [], &"og_spin", []],
	OG_TWIN: [&"CR_OG_Combo_3", Vector3(0.95, 0.12, 0.9), false, 0.5, [0.372, 0.617], &"og_twin", []],
	OG_DOUBLE: [&"CR_OG_Combo_1", Vector3(0.95, 0.1, 0.85), false, 0.5, [0.372, 0.639], &"og_double", []],
	OG_TRIPLE: [&"CR_OG_Combo_2", Vector3(0.95, 0.08, 0.85), false, 0.45, [0.217, 0.406, 0.617], &"og_triple", []],
	OG_JUMP: [&"CR_OG_Jump_Attack", Vector3(0.9, 0.05, 0.85), true, 1.25, [], &"og_jump", []],
	OG_DOWN_HELD: [&"CR_OG_Attack_Downward", Vector3(0.9, 0.05, 0.75), true, 1.15, [], &"og_down", [0.7, 1.0, 0.22]],
	OG_JUMP_HELD: [&"CR_OG_Jump_Attack", Vector3(0.9, 0.05, 0.85), true, 1.3, [], &"og_jump", [0.5, 0.75, 0.3]],
	OG_CLUB2H: [&"CR_OG_Club_Combo2H", Vector3(1.0, 0.36, 0.85), false, 0.5, [0.517, 0.728], &"og_club", []],
	OG_CLUB1H: [&"CR_OG_Club_Combo1H", Vector3(1.0, 0.22, 0.85), false, 0.45, [0.35, 0.594, 0.739], &"og_club", []],
	OG_GROUND: [&"CR_OG_Zombie_Overhead", Vector3(0.95, 0.05, 0.6), true, 1.2, [], &"og_ground", []],
	OG_MJUMP: [&"CR_OG_Mutant_Jump", Vector3(0.95, 0.02, 0.8), true, 1.35, [], &"og_mjump", []],
	OG_SPIN_SLIDE: [&"CR_OG_Attack_360", Vector3(1.0, 0.0, 0.7), true, 1.25, [], &"og_spin", []],
	# [.., limbs that strike (as `attack_limbs`), the kind of blow]
	OG_HEADBUTT: [&"CR_OG_Headbutt", Vector3(1.0, 0.1, 0.7), false, 0.4, [], &"og_headbutt", [],
			"head_joint>head_joint@0.11,0.13,0:0.24", &"guard"],
	OG_STOMP_FOOT: [&"CR_OG_Stomp", Vector3(1.0, 0.05, 0.75), false, 0.3, [], &"og_stomp", [],
			"R_knee_joint>R_toe_joint:0.16", &""],
	OG_SWIPE: [&"CR_OG_Mutant_Swipe", Vector3(1.0, 0.2, 0.8), false, 0.45, [], &"og_swipe", [],
			"L_elbow_joint>L_midFinger_joint3:0.18", &"guard"],
}
## Its combos made by hand: name, its moves in order, which of them throw
## him down by themselves (by their place; the others only stagger), and how
## often it picks it.
const COMBOS := [
	{"name": &"three", "moves": [OG_HORIZ, OG_BACK, OG_DOWN], "fells": [2], "weight": 1.0,
			"rage": [OG_SPIN_SLIDE]},
	{"name": &"delayed_leap", "moves": [OG_TWIN, OG_JUMP_HELD], "fells": [1], "weight": 0.8,
			"rage": [OG_GROUND]},
	{"name": &"five_spin", "moves": [OG_TRIPLE, OG_SPIN], "fells": [1], "weight": 0.7},
	{"name": &"feint", "moves": [OG_BACK, OG_HORIZ, OG_DOWN_HELD], "fells": [2], "weight": 0.8,
			"rage": [OG_JUMP_HELD]},
	{"name": &"club_ground", "moves": [OG_CLUB2H, OG_GROUND], "fells": [1], "weight": 0.8},
	{"name": &"club_leap", "moves": [OG_CLUB1H, OG_MJUMP], "fells": [1], "weight": 0.6},
	{"name": &"five_spin_slide", "moves": [OG_TRIPLE, OG_SPIN_SLIDE], "fells": [1], "weight": 0.7,
			"rage": [OG_MJUMP]},
	# Reading him (the user's pick, 10-10): the same opening, its close by what
	# he did — rolled out under it: the overhead held for the end of his roll;
	# backed off: the whirl sliding at him, or a leap; stood: as it was.
	{"name": &"three_read", "moves": [OG_HORIZ, OG_BACK, OG_DOWN], "fells": [2], "weight": 0.9,
			"branch": {2: [[&"rolled", OG_DOWN_HELD], [&"far", OG_JUMP_HELD]]}},
	{"name": &"five_read", "moves": [OG_TRIPLE, OG_SPIN], "fells": [1], "weight": 0.9,
			"branch": {1: [[&"far", OG_SPIN_SLIDE], [&"rolled", OG_DOWN_HELD]]}},
	# Hugging it.
	{"name": &"headbutt", "moves": [OG_HEADBUTT, OG_DOWN], "fells": [1], "weight": 1.0, "close": true},
	{"name": &"stamp", "moves": [OG_STOMP_FOOT, OG_SPIN], "fells": [1], "weight": 0.8, "close": true},
	{"name": &"shove", "moves": [OG_SWIPE, OG_CLUB2H], "fells": [1], "weight": 0.8, "close": true,
			"guard": true},
	# At a raised shield, from its reach: the free hand beats it aside first.
	{"name": &"shield_break", "moves": [OG_SWIPE, OG_HORIZ, OG_DOWN], "fells": [2], "weight": 0.4,
			"guard": true},
	# Enraged only.
	{"name": &"fury", "moves": [OG_CLUB2H, OG_SPIN_SLIDE, OG_GROUND], "fells": [2], "weight": 1.0,
			"rage_only": true},
	{"name": &"storm", "moves": [OG_HORIZ, OG_BACK, OG_HORIZ, OG_BACK, OG_DOWN_HELD], "fells": [4],
			"weight": 0.8, "rage_only": true},
	# The pound three times, its rock further each time (opened when its pound
	# is due, never weighed among the others).
	{"name": &"triple_pound", "moves": [POUND, POUND_2, POUND_3], "fells": [], "weight": 0.0,
			"relentless": true},
]
## A leap's flight drawn out: act -> [clip s it leaves the ground, clip s it
## lands, how many times slower the flight is played], and how high the
## body is lifted on top of the clip's own jump (m at its size).
const FLIGHTS := {
	# (2026-10-11, the user's word: quicker through the air at him — the
	# flights played quicker than the clips, not drawn out)
	LEAP_SLAM: [0.05, 0.45, 0.8, 1.0],
	RUN_SLAM: [0.87, 1.62, 0.75, 0.55],
}

## what -> [clip, [rate, from, to], heavy, share of `hit_damage`, how often
## it opens with it, how it does from his side (`_side_weight`), whether it
## fells him (1: it does, by itself; 99: not — but the closing blow of a long
## string does, [member finisher_from])].
const SWINGS := {
	SWEEP: [&"CR_Slash1", Vector3(0.85, 0.0, 0.9), false, 0.55, 1.0, &"front", 99],
	CHOP: [&"CR_Slash4", Vector3(0.85, 0.0, 0.9), false, 0.6, 1.0, &"front", 99],
	BACKHAND: [&"CR_RegB", Vector3(0.8, 0.0, 0.92), false, 0.6, 0.35, &"behind", 99],
	WIDE: [&"CR_Slash3", Vector3(0.82, 0.0, 0.92), false, 0.65, 0.6, &"side", 99],
	LOW: [&"CR_LightD", Vector3(0.85, 0.0, 0.9), false, 0.55, 0.7, &"side", 99],
	SMASH: [&"CR_Heavy1", Vector3(1.0, 0.0, 0.92), true, 1.05, 0.9, &"front", 1],
	CLEAVE: [&"CR_Heavy3", Vector3(1.0, 0.0, 0.92), true, 1.0, 0.8, &"front", 1],
	JUMP_SLAM: [&"CR_Heavy4", Vector3(1.0, 0.0, 0.92), true, 1.2, 0.5, &"front", 1],
	WHIRL: [&"CR_HeavyD", Vector3(0.9, 0.0, 0.95), true, 1.35, 0.3, &"front", 1],
	KICK: [&"CR_Kick", Vector3(0.95, 0.0, 0.85), false, 0.35, 0.0, &"front", 99],
	LUNGE: [&"CR_SwordDash", Vector3(0.9, 0.0, 0.9), false, 0.7, 0.0, &"front", 99],
	# The smash, held a beat for the end of his roll: never an opener.
	CATCH: [&"CR_Heavy1", Vector3(1.0, 0.0, 0.92), true, 1.05, 0.0, &"front", 1],
}

## What a swing may run on into: [what, weight]; -1 is the string's end.
const FOLLOW := {
	SWEEP: [[BACKHAND, 0.45], [CHOP, 0.25], [SMASH, 0.2], [CATCH, 0.12], [-1, 0.2]],
	BACKHAND: [[SMASH, 0.35], [LOW, 0.2], [WHIRL, 0.15], [-1, 0.25]],
	CHOP: [[SWEEP, 0.3], [CLEAVE, 0.3], [CATCH, 0.12], [-1, 0.25]],
	LOW: [[CLEAVE, 0.35], [BACKHAND, 0.2], [-1, 0.25]],
	WIDE: [[SMASH, 0.3], [BACKHAND, 0.25], [CATCH, 0.1], [-1, 0.3]],
	CATCH: [[WIDE, 0.25], [SWEEP, 0.15], [-1, 0.6]],
	LEAP_SLAM: [[WIDE, 0.25], [BACKHAND, 0.15], [-1, 0.6]],
	RUN_SLAM: [[-1, 1.0]],
	SMASH: [[CLEAVE, 0.3], [WIDE, 0.2], [-1, 0.4]],
	CLEAVE: [[WHIRL, 0.2], [SWEEP, 0.2], [-1, 0.5]],
	JUMP_SLAM: [[WIDE, 0.35], [SMASH, 0.2], [-1, 0.35]],
	WHIRL: [[-1, 1.0]],
	KICK: [[SMASH, 0.45], [SWEEP, 0.35], [-1, 0.2]],
	LUNGE: [[BACKHAND, 0.35], [SMASH, 0.3], [CHOP, 0.2], [-1, 0.15]],
	POUND: [[SWEEP, 0.25], [-1, 0.75]],
	HEAVY: [[-1, 1.0]],
}
## Enraged, on top: the pound and the great blow come into its strings.
const FOLLOW_RAGING := {
	SMASH: [[JUMP_SLAM, 0.25]],
	CLEAVE: [[POUND, 0.3]],
	WHIRL: [[POUND, 0.5], [-1, -0.5]],
	POUND: [[HEAVY, 0.4], [JUMP_SLAM, 0.3]],
	HEAVY: [[POUND, 0.4], [-1, -0.4]],
	JUMP_SLAM: [[WHIRL, 0.25]],
}

var _pound_wait: float = 3.0
var _heavy_wait: float = 2.0
var _stomp_wait: float = 0.0
var _lunge_wait: float = 3.0
var _kick_wait: float = 0.0
## Which way round him it prowls (1 to its right), and when it turns.
var _prowl_side: float = 1.0
var _prowl_turn: float = 0.0
## Where round him it was when it last came at him (flat, from him), and
## how far round from there it has prowled (deg).
var _prowl_home := Vector3.ZERO
var _prowl_was: float = 0.0
## Act seconds the club meets the ground in the pound and the stomp.
var _pound_at: float = 0.5
var _stomp_at: float = 0.5
var _pounded: bool = false
## Host: how many swings into this string, the swing it opened with last, and
## the moves it has made (for a test).
var _string_count: int = 0
var _last_opener: int = -1
var _lunge_speed: float = 0.0
## The held swing sliding at him: the act serial it is on, and its speed.
var _slide_serial: int = -1
var _slide_speed: float = 0.0
## The jump slam's speed closing on him.
var _jump_speed: float = 0.0
## How many held swings slid at him (for the tests).
var slides_made: int = 0
var moves_made: Array[int] = []
## Host: this swing closes its string (and fells him), and the blows of the
## string so far by their kind (each kind is a combo of its own to him).
var _closing: bool = false
var _kind_blows: Dictionary = {}
var finishers_made: int = 0
## Host: the combo it is on (`COMBOS`, -1 none), the place in it, the one to
## open with next ([method start_combo]), the last it made; counts.
var _combo: int = -1
var _combo_step: int = 0
var _combo_pending: int = -1
var _last_combo: int = -1
var combos_made: Array[int] = []
## Host: the combo's moves as they run this time (its rage tail on, its
## branches taken) and which of them fell him; the last one's, for a test.
var _combo_moves: Array = []
var _combo_fells_at: Array = []
var last_combo_moves: Array = []
## How many branches it took, by the reading (for a test).
var branches_taken: Dictionary = {}
## Every peer: the held swing it last showed the glint of.
var _glint_serial: int = -1
## Host: the leaps' waits and speed, the run-up at him, whether he is running
## from it (and how long the gap has been opening), the gap a tick ago.
var _leap_slam_wait: float = 4.0
var _run_slam_wait: float = 5.0
var _flight_speed: float = 0.0
var _charging: bool = false
var _charge_time: float = 0.0
var running_after: bool = false
var _opening: float = 0.0
var _last_gap: float = -1.0
var _trot_speed: float = 3.8
## Host: he rolled under this swing's blow; the aftershocks to come
## ([at, seconds left, id]); counts for a test.
var _saw_roll: bool = false
var _shocks: Array = []
var _shock_look: Vector2 = Vector2(-1, 0)
var aftershocks_made: int = 0
var catches_made: int = 0
## Every peer: the body lifted through a leap.
var _lifted: bool = false
## Every peer: the move shown and its clock, which of its blows have been
## heard, and the feet (down or not) for the footfalls.
var _heard_serial: int = -1
var _heard_clock: float = 0.0
var _heard: int = 0
var _ankles: PackedInt32Array = PackedInt32Array()
var _foot_down: Array[bool] = [true, true]


func _ready() -> void:
	super()
	_special(POUND, pound_clip, pound_part)
	_special(POUND_2, pound_clip, Vector3(pound_part.x * 1.6, 0.25, pound_part.z))
	_special(POUND_3, pound_clip, pound_part)
	# the club itself on him in each (it only staggers: the rock throws him)
	for p: int in [POUND_2, POUND_3]:
		_special_strike(p, "", pound_share * 0.6, 99)
	# the third held overhead a beat, glinting ([method _watch_hold])
	_holds[POUND_3] = [1.0, 0.55, 0.75, 0.25]
	_special(HEAVY, heavy_clip, heavy_part)
	_special_strike(HEAVY, "", heavy_share, 1)
	_kinds[HEAVY] = &"crush"
	_windups[HEAVY] = [heavy_slow, heavy_lead]
	_special(STOMP, stomp_clip, stomp_part)
	for what: int in SWINGS:
		var sw: Array = SWINGS[what]
		_special(what, sw[0], sw[1])
		# A heavy one fells him by itself, a light one never (but as the close
		# of a long string, [method _begin_move]).
		_special_strike(what, "", float(sw[3]), int(sw[6]))
		if bool(sw[2]):
			_holds[what] = [0.3, 0.3, 0.75, 0.22]
	for what: int in COMBO_MOVES:
		_combo_move(what)
	_holds.erase(CATCH)
	_holds[HEAVY] = [0.35, 0.25, 0.6, 0.2]
	# The roll-catch is always held, a roll's length.
	_holds[CATCH] = [1.0, catch_hold.x, catch_hold.y, 0.3]
	_special(LEAP_SLAM, leap_slam_clip, leap_slam_part)
	_special_strike(LEAP_SLAM, "", leap_slam_share, 1)
	_special(RUN_SLAM, run_slam_clip, run_slam_part)
	_special_strike(RUN_SLAM, "", run_slam_share, 1)
	# Down on him club first out of the run: no shield holds it.
	_kinds[RUN_SLAM] = &"crush"
	_trot_speed = chase_speed
	_leap_slam_wait = _rng.randf_range(3.0, leap_slam_cooldown.x)
	_run_slam_wait = _rng.randf_range(3.0, run_slam_cooldown.x)
	# The kick beats a raised shield aside, as the orc's does.
	_kinds[KICK] = &"guard"
	_pound_at = _club_down(POUND)
	_stomp_at = _club_down(STOMP)
	_pound_wait = _rng.randf_range(2.0, pound_cooldown.x)
	_heavy_wait = _rng.randf_range(1.0, heavy_cooldown.x)
	# Fresh to the fight it walks in first; the lunge comes later.
	_lunge_wait = _rng.randf_range(3.5, lunge_cooldown.x)
	if _skeleton != null:
		for bone in foot_bones:
			_ankles.append(_skeleton.find_bone(bone))
	Sfx.warm([WHOOSH_HEAVY, WHOOSH_LIGHT, ROAR_SOUND, ROAR_SHORT_SOUND] + GRUNTS + CLUB_GROUND + STEPS)


## One of the combos' moves: its clip, its blows (where the club reaches
## furthest, or at the moments given), held at the top if it is so made.
func _combo_move(what: int) -> void:
	var c: Array = COMBO_MOVES[what]
	var part: Vector3 = c[1]
	part.x *= combo_pace.y if bool(c[2]) else combo_pace.x
	_special(what, c[0], part)
	var at: Array = c[4]
	if c.size() > 7 and not String(c[7]).is_empty():
		_special_strike(what, String(c[7]), float(c[3]), 99)
		if c.size() > 8 and not StringName(c[8]).is_empty():
			_kinds[what] = c[8]
	elif at.is_empty():
		_special_strike(what, "", float(c[3]), 99)
	else:
		var bones := strike_bones if not strike_bones.is_empty() else PackedStringArray([String(weapon_bone)])
		var limbs: Array = []
		for i in at.size():
			limbs.append("weapon")
		_strikes_table[what] = [bones, limbs, float(c[3]), 99, 0.5, PackedFloat32Array(at)]
		if _anim != null:
			var from := _gap_that_lands(what, _moves_table[what], float(at[0]))
			if from > 0.0:
				_strike_from[what] = from
	var held: Array = c[6]
	if not held.is_empty():
		_holds[what] = [1.0, float(held[0]), float(held[1]), float(held[2])]


## Act seconds of the pound's slam (`what` one of the three), its hold put in.
func _pound_time(what: int) -> float:
	var t := _club_down(what)
	var sh := _shape(what)
	if sh.is_empty():
		return t
	var k := float(sh[0])
	var slow := float(sh[1])
	return t * slow if t <= k else t + k * (slow - 1.0) + float(sh[2])


## Act seconds of a move when its club is lowest, in front.
func _club_down(what: int) -> float:
	var m: Array = _moves_table[what]
	if _anim == null or _weapon < 0:
		return _move_length(what) * 0.5
	var at := _anim.measure_reach(m[0], String(weapon_bone), weapon_tip, reach_forward, float(m[2]), float(m[3]))
	if at < 0.0:
		return _move_length(what) * 0.5
	return (at - float(m[2])) * _anim.clip_length(m[0]) / maxf(float(m[1]), 0.01)


func _leaps() -> Array:
	return [LEAP, LUNGE, LEAP_SLAM, RUN_SLAM]


#region Choosing
func _own_move(delta: float) -> bool:
	_pound_wait = maxf(_pound_wait - delta, 0.0)
	_heavy_wait = maxf(_heavy_wait - delta, 0.0)
	_stomp_wait = maxf(_stomp_wait - delta, 0.0)
	_lunge_wait = maxf(_lunge_wait - delta, 0.0)
	_kick_wait = maxf(_kick_wait - delta, 0.0)
	_leap_slam_wait = maxf(_leap_slam_wait - delta, 0.0)
	_run_slam_wait = maxf(_run_slam_wait - delta, 0.0)
	var gap := _distance_to(_quarry)
	_watch_flight(gap, delta)
	if drill_combo >= 0:
		return _ogre_drill(gap, delta)
	# Running at him to spring off the run.
	if _charging:
		_charge_time += delta
		if _quarry_down() or _charge_time > 4.5 or gap > run_slam_to + 8.0:
			_charging = false
		elif gap <= run_slam_takeoff:
			_charging = false
			if gap >= run_slam_takeoff * 0.55 and stamina >= attack_cost:
				mode = Mode.FIGHT
				_face(_quarry.global_position - global_position, 1.0, 50.0)
				_open(RUN_SLAM)
				return true
		else:
			mode = Mode.CHASE
			_move_towards(_quarry.global_position, _pace(run_speed), delta)
			return true
	# Him down in reach: the club on him where he lies.
	if _quarry_down():
		if gap <= stomp_reach and _stomp_wait <= 0.0:
			if _rng.randf() > stomp_chance:
				_stomp_wait = stomp_cooldown * 0.5
				return false
			_face(_quarry.global_position - global_position, 1.0, 50.0)
			_open(STOMP)
			return true
		if gap > stomp_reach * 0.8:
			_move_towards(_quarry.global_position, chase_speed, delta)
			return true
		return _prowl(gap, delta, stomp_reach * 0.7)
	if _from_afar(gap, delta):
		return true
	if _pound_wait <= 0.0 and gap >= pound_from and gap <= pound_to and stamina >= attack_cost:
		mode = Mode.FIGHT
		start_combo(_combo_named(&"triple_pound"))
		return true
	var want := float(_strike_from.get(HEAVY, strike_off))
	if _heavy_wait <= 0.0 and _cooldown <= 0.0 and gap <= want + 0.6 and gap >= want - 1.2 \
			and stamina >= attack_cost:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(HEAVY)
		return true
	if (_cooldown > 0.0 or stamina < attack_cost) and _prowl(gap, delta, strike_off):
		return true
	if attacks.is_empty() or _cooldown > 0.0 or stamina < attack_cost:
		return super(delta)
	if _lunge_wait <= 0.0 and gap >= lunge_from and gap <= lunge_to:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(LUNGE)
		return true
	if _try_combo(gap):
		return true
	var pick := _pick_opener(gap)
	if pick >= 0:
		mode = Mode.FIGHT
		if SWINGS[pick][5] == &"front":
			_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(pick)
		return true
	return super(delta)


## Host, between its strings: round him at `prowl_speed`, facing him, kept
## at `keep` m; off to the side it was going, now and then the other way.
## False when he is not near enough to prowl round (it closes in as ever).
func _prowl(gap: float, delta: float, keep: float) -> bool:
	if _quarry == null or prowl_speed <= 0.0 or gap > keep + 3.0:
		return false
	mode = Mode.FIGHT
	_prowl_turn -= delta
	if _prowl_turn <= 0.0:
		_prowl_turn = _rng.randf_range(prowl_turn_every.x, prowl_turn_every.y)
		if _rng.randf() < 0.5:
			_prowl_side = -_prowl_side
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	var ahead := to.normalized()
	if _prowl_home == Vector3.ZERO:
		_prowl_home = -ahead
	# kept within `prowl_arc` of where it came at him: going further out, back
	var around := rad_to_deg(_prowl_home.signed_angle_to(-ahead, Vector3.UP))
	if absf(around) > prowl_arc and absf(around) > absf(_prowl_was):
		_prowl_side = -_prowl_side
		_prowl_turn = _rng.randf_range(prowl_turn_every.x, prowl_turn_every.y)
	_prowl_was = around
	_face(ahead, delta, turn_speed)
	var side := ahead.cross(Vector3.UP) * _prowl_side
	# round him, and in or out to its reach
	var radial := clampf((gap - keep) * 1.5, -1.0, 1.0)
	var want := (side + ahead * radial).normalized() * prowl_speed * clampf(visual_scale / 1.6, 0.6, 1.6)
	velocity.x = move_toward(velocity.x, want.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, want.z, acceleration * delta)
	return true


## Host: the leaps from afar, if he is at their gap and they are due.
func _from_afar(gap: float, delta: float) -> bool:
	if stamina < attack_cost or _quarry_down():
		return false
	var run_ok := _run_slam_wait <= 0.0 and gap >= run_slam_from and gap <= run_slam_to
	var leap_ok := _leap_slam_wait <= 0.0 and gap >= leap_slam_from and gap <= leap_slam_to
	if run_ok and (not leap_ok or _rng.randf() < 0.5):
		# Off at a run at him first; it springs at `run_slam_takeoff`.
		_charging = true
		_charge_time = 0.0
		_run_slam_wait = _rng.randf_range(run_slam_cooldown.x, run_slam_cooldown.y)
		mode = Mode.CHASE
		_move_towards(_quarry.global_position, _pace(run_speed), delta)
		return true
	if leap_ok:
		mode = Mode.FIGHT
		_face(_quarry.global_position - global_position, 1.0, 50.0)
		_open(LEAP_SLAM)
		return true
	return false


## A pace, quicker enraged.
func _pace(base: float) -> float:
	return base * (rage_pace if raging else 1.0)


## Host: whether he is running from it — the gap opening fast for a while
## with him well off — and its pace after him by that: a trot, or a run.
func _watch_flight(gap: float, delta: float) -> void:
	if _last_gap >= 0.0 and delta > 0.0:
		var opening := (gap - _last_gap) / delta
		if opening > flee_rate and gap > flee_from:
			_opening += delta
		else:
			_opening = maxf(_opening - delta * 0.5, 0.0)
	_last_gap = gap
	if _opening >= flee_time and gap > flee_from:
		running_after = true
	elif running_after and (gap < flee_from - 1.0 or _opening <= 0.0):
		running_after = false
	chase_speed = _pace(run_speed if running_after or runs_after else _trot_speed)


## The Brawler's own choosing goes through the strings too.
func _begin_attack() -> void:
	if _quarry_down() or _quarry == null:
		return
	if attacks.is_empty():
		super()
		return
	if _try_combo(_distance_to(_quarry)):
		return
	var pick := _pick_opener(_distance_to(_quarry))
	if pick >= 0:
		_open(pick)
	else:
		super()


## Host, practising one combo ([member PackBrute.drill_combo], here of
## `COMBOS`; no strings, no leaps, no pound): its breath got back prowling
## (him down too), then in to it and at him.
func _ogre_drill(gap: float, delta: float) -> bool:
	mode = Mode.FIGHT
	_charging = false
	if _quarry_down() or _cooldown > 0.0 or stamina < attack_cost:
		if _prowl(gap, delta, strike_off):
			return true
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		return true
	var first := int((COMBOS[drill_combo]["moves"] as Array)[0])
	var want := float(_strike_from.get(first, strike_off))
	if gap <= want + 0.6:
		start_combo(drill_combo)
		return true
	_move_towards(_quarry.global_position, chase_speed, delta)
	return true


## Host: now and then one of its combos instead of a string, if he is in
## front and its first move lands from here.
func _try_combo(gap: float) -> bool:
	var where := _where_he_is()
	var nearest := 0.4 * maxf(visual_scale, 0.01) + 0.55
	var hugging := gap < nearest + 0.35 and where != &"behind"
	var chance := close_combo_chance if hugging else (combo_chance.y if raging else combo_chance.x)
	if _rng.randf() >= chance:
		return false
	if not hugging and where != &"front":
		return false
	var guarded := _quarry is Player and bool((_quarry as Player).is_blocking)
	var options: Array = []
	for i in COMBOS.size():
		var c: Dictionary = COMBOS[i]
		# never weighed (the triple pound: opened when its pound is due)
		if float(c["weight"]) <= 0.0:
			continue
		if bool(c.get("close", false)) != hugging:
			continue
		if bool(c.get("rage_only", false)) and not raging:
			continue
		if not hugging and not _fits(int((c["moves"] as Array)[0]), gap):
			continue
		var w := float(c["weight"]) * (0.2 if i == _last_combo else 1.0)
		if bool(c.get("guard", false)):
			# a shield up in front of it: beaten aside first, far more often
			w *= 4.0 if guarded else 0.5
		options.append([i, w])
	var pick := _weighed(options)
	if pick < 0:
		return false
	mode = Mode.FIGHT
	start_combo(pick)
	return true


func _combo_named(name: StringName) -> int:
	for i in COMBOS.size():
		if COMBOS[i]["name"] == name:
			return i
	return 0


## Host: combo `which` of `COMBOS` begun now, turned to him.
func start_combo(which: int) -> void:
	if _quarry != null:
		_face(_quarry.global_position - global_position, 1.0, 50.0)
	_combo_pending = which
	_open(int((COMBOS[which]["moves"] as Array)[0]))


## A string begun with `what`.
func _open(what: int) -> void:
	_string_count = 0
	if _quarry != null:
		_prowl_home = Vector3(global_position.x - _quarry.global_position.x, 0.0,
				global_position.z - _quarry.global_position.z).normalized()
	_prowl_was = 0.0
	_pounded = false
	# One combo on him for the whole string: its blows count together, so a
	# heavy one after a light one fells him ([Player.receive_blow]).
	_chain_serial = 1000000 + act_serial + 1
	_chain_blow = 0
	_kind_blows.clear()
	_closing = false
	_combo = _combo_pending
	_combo_pending = -1
	_combo_step = 0
	_combo_moves = []
	_combo_fells_at = []
	if _combo >= 0:
		_last_combo = _combo
		combos_made.append(_combo)
		var c: Dictionary = COMBOS[_combo]
		_combo_moves = (c["moves"] as Array).duplicate()
		_combo_fells_at = (c["fells"] as Array).duplicate()
		if raging and c.has("rage"):
			# enraged it runs on: its old close only staggers now, the new one fells
			_combo_moves.append_array(c["rage"])
			_combo_fells_at = [_combo_moves.size() - 1]
		last_combo_moves = _combo_moves
	if SWINGS.has(what) and what != KICK and what != LUNGE:
		_last_opener = what
	if what == KICK:
		_kick_wait = kick_cooldown
	_begin_move(what)


## The next move of a string (after `prev`, -1 for its first).
func _begin_move(what: int, prev: int = -1) -> void:
	if prev >= 0 and _strikes_table.has(prev):
		var n := _blow_moments(prev).size()
		_chain_blow += n
		var kind := _combo_kind(prev)
		_kind_blows[kind] = int(_kind_blows.get(kind, 0)) + n
	_string_count += 1
	_pounded = false
	_jump_speed = 0.0
	moves_made.append(what)
	if moves_made.size() > 200:
		moves_made = moves_made.slice(-100)
	_saw_roll = false
	_closing = _closes(what)
	if what == CATCH:
		catches_made += 1
	if _combo >= 0 and _combo_fells():
		# A combo's felling blow: a fresh combo to him, its blows his last,
		# so it throws him down by itself (Elden Ring's finisher).
		finishers_made += 1
		_chain_serial = 2000000 + act_serial + 1
		_chain_blow = 0
		var keep: Array = _strikes_table[what]
		var close := keep.duplicate()
		close[3] = _blow_moments(what).size()
		_strikes_table[what] = close
		_begin(what)
		_strikes_table[what] = keep
	elif _combo < 0 and _closing and _finishes() and _strikes_table.has(what) and int((_strikes_table[what] as Array)[3]) > 1:
		# The close of a long string: its last blow fells him, if every blow
		# of its kind in the string found him (they count as one combo).
		finishers_made += 1
		var keep: Array = _strikes_table[what]
		var close := keep.duplicate()
		close[3] = int(_kind_blows.get(_combo_kind(what), 0)) + _blow_moments(what).size()
		_strikes_table[what] = close
		_begin(what)
		_strikes_table[what] = keep
	else:
		_begin(what)
	if FLIGHTS.has(what) and _quarry != null:
		var span := _flight_span(what)
		_flight_speed = _close_speed_for(what, span.y, span.x)
	_spin_on = false
	_spin_from = -1.0
	if what == OG_SPIN_SLIDE and _quarry != null:
		_spin_dash(false)
	if what == LUNGE and _quarry != null:
		var until := _blow_moments(LUNGE)[0]
		var m: Array = _moves_table[LUNGE]
		var own := _hips(m[0], _clip_time(LUNGE, until)).x - _hips(m[0], _clip_time(LUNGE, 0.0)).x
		var short := float(_strike_from.get(LUNGE, strike_off))
		_lunge_speed = maxf(_distance_to(_quarry) - short - own, 0.0) / maxf(until, 0.2)


## Its blows brought down on him from above: felled by one, he is crushed
## down where he stands ([method Player.receive_blow] asks).
const OVERHEAD := [SMASH, JUMP_SLAM, LEAP_SLAM, CATCH, OG_DOWN, OG_DOWN_HELD, OG_JUMP, OG_JUMP_HELD, OG_GROUND, OG_MJUMP]


func blow_from_above() -> bool:
	return OVERHEAD.has(act) and _blow_kind(act).is_empty()


## Its blows by name, for the hero's falls: he falls the way the user picked
## for each ([member Player.BLOW_FALLS], 2026-10-09).
const BLOW_NAMES := {
	SWEEP: &"sweep", CHOP: &"chop", BACKHAND: &"backhand", WIDE: &"wide", LOW: &"low",
	SMASH: &"smash", CLEAVE: &"cleave", JUMP_SLAM: &"jump_slam", WHIRL: &"whirl",
	KICK: &"kick", LUNGE: &"lunge", LEAP_SLAM: &"leap_slam", RUN_SLAM: &"run_slam",
	CATCH: &"catch", POUND: &"pound", POUND_2: &"pound", POUND_3: &"pound", HEAVY: &"heavy", STOMP: &"stomp",
}


## Whether the blow it is dealing now was held at the top of its wind-up
## (the "it stops, then strikes" swing): a heavy one, it fells (the user's
## word, 2026-10-10; [member Player.STAGGERS_ONLY]).
func blow_held() -> bool:
	return _hold_of(act) > 0.0


## The blow it is dealing now, by name (&"" none): [member BLOW_NAMES].
func blow_name() -> StringName:
	if COMBO_MOVES.has(act):
		return COMBO_MOVES[act][5]
	return BLOW_NAMES.get(act, &"")


## The kind a move's blows reach him as — his combo key goes by it, so the
## blows of a string count together only within one kind.
func _combo_kind(what: int) -> StringName:
	var kind := _blow_kind(what)
	if kind.is_empty() and OVERHEAD.has(what):
		return &"above"
	return kind


## Where he stands against the way it faces: "front", "side" or "behind".
func _where_he_is() -> StringName:
	var to := _quarry.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return &"front"
	var angle := rad_to_deg(_forward().angle_to(to.normalized()))
	if angle > 120.0:
		return &"behind"
	if angle > 55.0:
		return &"side"
	return &"front"


## How far off a swing can be begun: from a little inside where it lands to
## as far as it can step in before its blow.
func _fits(what: int, gap: float, slack: float = 0.0) -> bool:
	var want := float(_strike_from.get(what, strike_off))
	var ms := _blow_moments(what)
	var step := clampf(close_speed * ((ms[0] if not ms.is_empty() else 0.5) - 0.15), 0.3, 2.2)
	return gap >= want - 0.8 - slack and gap <= want + step + slack


func _side_weight(where: StringName, suits: StringName) -> float:
	if where == suits:
		return 3.0 if where != &"front" else 1.0
	if where == &"behind":
		return 0.08
	if where == &"side":
		return 0.35 if suits == &"front" else 0.8
	return 0.5 if suits == &"side" else 0.25


## Its first swing, by how far off he is and where: none if none will do.
func _pick_opener(gap: float) -> int:
	var where := _where_he_is()
	var nearest := 0.4 * maxf(visual_scale, 0.01) + 0.55
	if gap < nearest + 0.35 and _kick_wait <= 0.0 and where != &"behind":
		return KICK
	var options: Array = []
	for what: int in SWINGS:
		var sw: Array = SWINGS[what]
		var base := float(sw[4])
		if base <= 0.0 or not _fits(what, gap):
			continue
		var w := base * _side_weight(where, sw[5])
		if what == _last_opener:
			w *= 0.25
		options.append([what, w])
	return _weighed(options)


func _weighed(options: Array) -> int:
	var total := 0.0
	for o: Array in options:
		total += maxf(float(o[1]), 0.0)
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	for o: Array in options:
		roll -= maxf(float(o[1]), 0.0)
		if roll <= 0.0:
			return int(o[0])
	return int((options[-1] as Array)[0])


## Whether `what`, begun now as the `_string_count`th of its string, is its
## last: at the most a string runs, or by the same odds the string would end
## after it ([method _follow]) — weighed now, as it begins, so its blow knows
## it closes (a long string's close fells him; a lone heavy blow's is
## followed by its aftershock).
func _weighed_ahead(what: int) -> bool:
	return SWINGS.has(what) and what != KICK and what != LUNGE


## A combo's close picked by what he did: the first reading that holds of
## `options` ([reading, move]) — "rolled": he rolled under the move before;
## "far": he is past the reach of `plain` (its close as made) by
## `branch_far` — or `plain`.
func _read_him(options: Array, plain: int) -> int:
	var gap := _distance_to(_quarry)
	var reach := float(_strike_from.get(plain, strike_off))
	for o: Array in options:
		var holds := false
		match StringName(o[0]):
			&"rolled":
				holds = _saw_roll
			&"far":
				holds = gap > reach + branch_far * visual_scale / 1.6
		if holds:
			branches_taken[o[0]] = int(branches_taken.get(o[0], 0)) + 1
			return int(o[1])
	branches_taken[&"plain"] = int(branches_taken.get(&"plain", 0)) + 1
	return plain


## Whether the combo's move now is one of its felling blows.
func _combo_fells() -> bool:
	return _combo >= 0 and _combo_fells_at.has(_combo_step)


## Whether the string closing on `what` now is long enough to fell him.
func _finishes() -> bool:
	return _string_count >= (finisher_from.y if raging else finisher_from.x)



func _closes(what: int) -> bool:
	if _combo >= 0:
		return _combo_step >= _combo_moves.size() - 1
	if not _weighed_ahead(what):
		return false
	var most := string_most_raging if raging else string_most
	if _string_count >= most:
		return true
	var weights := _follow(what)
	var total := 0.0
	for k: int in weights:
		total += maxf(float(weights[k]), 0.0)
	return total > 0.0 and _rng.randf() < maxf(float(weights.get(-1, 0.0)), 0.0) / total


## What may come after `what` in a string, weighed: next -> weight (-1 the end).
func _follow(what: int) -> Dictionary:
	var weights := {}
	for f: Array in FOLLOW.get(what, []):
		weights[int(f[0])] = float(weights.get(int(f[0]), 0.0)) + float(f[1])
	if raging:
		for f: Array in FOLLOW_RAGING.get(what, []):
			weights[int(f[0])] = float(weights.get(int(f[0]), 0.0)) + float(f[1])
		# Enraged, it seldom stops.
		weights[-1] = float(weights.get(-1, 0.0)) * 0.35
	return weights


## What the string runs on into after `what`, or -1: weighed, never the same
## swing twice running, only one that lands from where he is now.
func _next_in_string(what: int) -> int:
	if _combo >= 0:
		# a combo: its next move, whatever (only him down, or out of breath,
		# break it off)
		# (a relentless one, the pound's three, goes on with him down)
		var on_him := bool(COMBOS[_combo].get("relentless", false)) or not _quarry_down()
		if _quarry == null or not on_him or _combo_step + 1 >= _combo_moves.size() \
				or stamina < attack_cost * 0.25:
			return -1
		_combo_step += 1
		var branch: Dictionary = COMBOS[_combo].get("branch", {})
		if branch.has(_combo_step):
			_combo_moves[_combo_step] = _read_him(branch[_combo_step], int(_combo_moves[_combo_step]))
		return int(_combo_moves[_combo_step])
	if _quarry == null or _quarry_down() or not FOLLOW.has(what):
		return -1
	if _string_count >= (string_most_raging if raging else string_most):
		return -1
	if stamina < attack_cost * 0.5:
		return -1
	var gap := _distance_to(_quarry)
	# He rolled out from under it: the roll-catch, held for the end of the
	# next roll he makes too early.
	if _saw_roll and what != CATCH and _fits(CATCH, gap, 1.5) and _rng.randf() < catch_chance:
		return CATCH
	if _closing:
		return -1
	var weights := _follow(what)
	# A swing's end was weighed as it began ([method _closes]).
	var past := _weighed_ahead(what)
	var options: Array = []
	for next: int in weights:
		var w := float(weights[next])
		if next == -1:
			if not past:
				options.append([-1, w])
			continue
		if next == what:
			continue
		match next:
			POUND:
				if gap > pound_to:
					continue
			HEAVY:
				var want := float(_strike_from.get(HEAVY, strike_off))
				if gap > want + 1.0 or gap < want - 1.6:
					continue
			_:
				if not _fits(next, gap, 1.0):
					continue
		options.append([next, w])
	return _weighed(options)
#endregion


#region Acting
func _extra_velocity(delta: float) -> Vector3:
	var held := _slide_span(act)
	if held.x >= 0.0:
		# Planted through the wind-up and the hold; then the slide, if he
		# backed off, or the plain step in under the blow.
		if _act_time < held.x:
			return Vector3.ZERO
		if _slide_serial == act_serial:
			return _forward() * _slide_speed if _act_time <= held.y else Vector3.ZERO
	if act == LUNGE:
		if _act_time <= _blow_moments(LUNGE)[0]:
			return _forward() * _lunge_speed
		return Vector3.ZERO
	if act == OG_SPIN_SLIDE:
		var ms := _blow_moments(act)
		if _spin_from >= 0.0 and not ms.is_empty() and _act_time >= _spin_from and _act_time <= ms[0]:
			if not _spin_on:
				_spin_on = true
				spin_dashes += 1
				if is_inside_tree() and multiplayer.has_multiplayer_peer():
					net_slide.rpc()
				else:
					net_slide()
			return _forward() * _spin_speed
		return Vector3.ZERO
	if act == JUMP_SLAM and _jump_speed > 0.0:
		var span := _jump_span()
		if _act_time >= span.x and _act_time <= span.y:
			return _forward() * _jump_speed
	if act == HEAVY and _heavy_speed > 0.0:
		var hs := _heavy_span()
		if _act_time >= hs.x and _act_time <= hs.y:
			return _forward() * _heavy_speed
		if _act_time < hs.x:
			return Vector3.ZERO
	if FLIGHTS.has(act):
		var span := _flight_span(act)
		if _act_time >= span.x and _act_time <= span.y:
			return _forward() * _flight_speed
		return Vector3.ZERO
	return super(delta)


## Act seconds of the move's last moment of turning after him: a little
## before its first blow (`commit_lead`), a leap a third into its flight.
func _commit_at(what: int) -> float:
	if FLIGHTS.has(what):
		var span := _flight_span(what)
		return lerpf(span.x, span.y, chase_flight_commit)
	var ms := _blow_moments(what)
	if ms.is_empty():
		return 0.0
	if what == JUMP_SLAM:
		return ms[0] - chase_commit
	if what == HEAVY:
		return ms[0] - heavy_commit
	if what == OG_SPIN_SLIDE and _spin_from >= 0.0:
		# after him till the last 15 % of its dash
		return ms[0] - maxf(0.15 * (ms[0] - _spin_from), 0.06)
	var heavy := _is_heavy(what)
	return ms[0] - (commit_lead.y if heavy else commit_lead.x)


func _track_rate(what: int) -> float:
	if FLIGHTS.has(what) or what == LUNGE:
		return turn_speed * 1.3
	if what == CATCH:
		return turn_speed * 1.2
	return turn_speed * (0.85 if _is_heavy(what) else 0.7)


## Turning after him till the move commits ([method _commit_at]), and then
## locked: the dash and the leaps sized to where he is now, as they turn.
func _track_before_blow(delta: float) -> void:
	if _quarry == null:
		return
	if _slide_after_him(delta):
		return
	if _act_time >= _commit_at(act):
		return
	var chases := _chases(act)
	var at := _quarry_ahead(act) if chases else _quarry.global_position
	# a leap in the air, a jump slam closing: turned after him hard
	var rate := _track_rate(act) * (3.0 if chases and _act_time >= _chase_from(act) else 1.0)
	_face(at - global_position, delta, rate)
	_reframe()
	if act == LUNGE:
		_lunge_speed = _close_speed_for(LUNGE, _blow_moments(LUNGE)[0], 0.0)
	elif FLIGHTS.has(act):
		var span := _flight_span(act)
		_flight_speed = _close_speed_for(act, span.y, span.x, true)
	elif act == JUMP_SLAM:
		_jump_closing()
	elif act == OG_SPIN_SLIDE:
		_spin_dash(true)
	elif act == HEAVY:
		_heavy_closing()


## Host: the sliding whirl's dash at him ([member spin_dash_speed]): from when
## (act s, -1 none: he is in its reach) and how fast, to be on him as the club
## comes round; once on its way, only its speed, to where he will be.
var _spin_from: float = -1.0
var _spin_speed: float = 0.0
var _spin_on: bool = false
var spin_dashes: int = 0


func _spin_dash(ahead: bool) -> void:
	var ms := _blow_moments(OG_SPIN_SLIDE)
	if ms.is_empty() or _quarry == null:
		return
	var blow := ms[0]
	var m: Array = _moves_table[OG_SPIN_SLIDE]
	var own := _hips(m[0], _clip_time(OG_SPIN_SLIDE, blow)).x - _hips(m[0], _clip_time(OG_SPIN_SLIDE, _act_time)).x
	var reach := float(_strike_from.get(OG_SPIN_SLIDE, strike_off))
	var gap := _gap_to(_quarry_ahead(OG_SPIN_SLIDE)) if ahead else _distance_to(_quarry)
	var d := clampf(gap - reach - own, 0.0, spin_slide_most * visual_scale / 1.6)
	var left := maxf(blow - _act_time, 0.05)
	if _spin_on:
		_spin_speed = d / left
		return
	if d < 0.3:
		_spin_from = -1.0
		_spin_speed = 0.0
		return
	var window := minf(d / (spin_dash_speed * visual_scale / 1.6), left)
	_spin_from = blow - window
	_spin_speed = d / maxf(window, 0.05)


## The moves running does not beat ([member chase_lead_most]): the leaps, the
## jump slam, a held swing.
func _chases(what: int) -> bool:
	return FLIGHTS.has(what) or what == JUMP_SLAM or what == OG_SPIN_SLIDE or what == HEAVY \
			or _slide_span(what).x >= 0.0


## Act seconds from which a chasing move is on its way at him (the leap off
## the ground, the jump slam closing, the held swing let go).
func _chase_from(what: int) -> float:
	if what == HEAVY:
		return 0.0
	if what == OG_SPIN_SLIDE:
		return _spin_from if _spin_from >= 0.0 else INF
	if FLIGHTS.has(what):
		return _flight_span(what).x
	if what == JUMP_SLAM:
		return _jump_span().x
	return _slide_span(what).x


## Where he will be when this move's first blow lands, if he runs on as he
## runs now (flat, on the ground he stands on).
func _quarry_ahead(what: int) -> Vector3:
	var at := _quarry.global_position
	var ms := _blow_moments(what)
	if ms.is_empty():
		return at
	return at + _his_run * clampf(ms[0] - _act_time, 0.0, chase_lead_most)


## Host: how he is running over the ground, as it sees him move (smoothed;
## a peer's body far off has no velocity of its own to read).
var _his_run: Vector3 = Vector3.ZERO
var _his_last: Vector3 = Vector3.INF
var _his_who: Node3D = null


func _watch_his_run(delta: float) -> void:
	if _quarry == null or not is_instance_valid(_quarry) or delta <= 0.0:
		_his_run = Vector3.ZERO
		_his_last = Vector3.INF
		return
	var at := _quarry.global_position
	if _his_who != _quarry or _his_last == Vector3.INF:
		_his_who = _quarry
		_his_last = at
		_his_run = Vector3.ZERO
		return
	var moved := (at - _his_last) / delta
	moved.y = 0.0
	_his_last = at
	# a jump of the body (set over, respawned): not a run
	if moved.length() > 14.0:
		return
	_his_run = _his_run.lerp(moved, 1.0 - exp(-12.0 * delta))


## The jump slam's closing on him: act seconds [from, its blow].
func _jump_span() -> Vector2:
	var ms := _blow_moments(JUMP_SLAM)
	if ms.is_empty():
		return Vector2(-1.0, -1.0)
	return Vector2(maxf(ms[0] - jump_slam_close, 0.0), ms[0])


## Host: the jump slam's speed onto where he will be, if he is out of its
## reach; none if he is in it (it lands where it stands, as it always did).
## The great blow's closing on him: act seconds [from, its blow].
func _heavy_span() -> Vector2:
	var ms := _blow_moments(HEAVY)
	if ms.is_empty():
		return Vector2(-1.0, -1.0)
	return Vector2(maxf(ms[0] - heavy_close, 0.0), ms[0])


var _heavy_speed: float = 0.0


## Host: the great blow's speed onto where he will be, him out of its reach
## (none in it: it comes down where it stands).
func _heavy_closing() -> void:
	var span := _heavy_span()
	if span.x < 0.0:
		return
	var reach := float(_strike_from.get(HEAVY, strike_off))
	var gap := _gap_to(_quarry_ahead(HEAVY))
	if gap <= reach + slide_slack * visual_scale / 1.6:
		_heavy_speed = 0.0
		return
	_heavy_speed = clampf(_close_speed_for(HEAVY, span.y, span.x, true), 0.0,
			heavy_close_most * visual_scale / 1.6 / maxf(span.y - span.x, 0.15))


func _jump_closing() -> void:
	var span := _jump_span()
	if span.x < 0.0:
		return
	var reach := float(_strike_from.get(JUMP_SLAM, strike_off))
	var gap := _gap_to(_quarry_ahead(JUMP_SLAM))
	if gap <= reach + slide_slack * visual_scale / 1.6:
		_jump_speed = 0.0
		return
	_jump_speed = clampf(_close_speed_for(JUMP_SLAM, span.y, span.x, true), 0.0,
			jump_slam_most * visual_scale / 1.6 / maxf(span.y - span.x, 0.15))


func _gap_to(at: Vector3) -> float:
	var gap := at - global_position
	gap.y = 0.0
	return gap.length()


## The speed on top of the clip's own travel that brings the move's blow on
## him from where he is now, laid over the act seconds from `from` (or now,
## if later) to `until`.
func _close_speed_for(what: int, until: float, from: float, ahead: bool = false) -> float:
	var ms := _blow_moments(what)
	var blow := ms[0] if not ms.is_empty() else until
	var m: Array = _moves_table[what]
	var own := _hips(m[0], _clip_time(what, blow)).x - _hips(m[0], _clip_time(what, _act_time)).x
	var short := float(_strike_from.get(what, strike_off))
	if FLIGHTS.has(what):
		# a leap comes down a little inside its reach: quicker through the air,
		# it overshot less and landed short of him from far (2026-10-11)
		short -= 0.5 * visual_scale / 1.6
	var left := maxf(until - maxf(from, _act_time), 0.15)
	var gap := _gap_to(_quarry_ahead(what)) if ahead else _distance_to(_quarry)
	return maxf(gap - short - own, 0.0) / left


## Act seconds a held swing slides over: [the end of its hold, its blow], or
## (-1, -1) if it is not held this time.
func _slide_span(what: int) -> Vector2:
	var sh := _shape(what)
	if sh.is_empty() or float(sh[2]) <= 0.0:
		return Vector2(-1.0, -1.0)
	var ms := _blow_moments(what)
	if ms.is_empty():
		return Vector2(-1.0, -1.0)
	var release := float(sh[0]) * float(sh[1]) + float(sh[2])
	return Vector2(release, ms[0])


## Host: a held swing let go with him out of its reach slides at him and
## follows him round to its blow. True while it is sliding.
func _slide_after_him(delta: float) -> bool:
	var sp := _slide_span(act)
	if sp.x < 0.0 or _act_time > sp.y:
		return false
	if _slide_serial != act_serial:
		if not _decides() or _act_time < sp.x or _quarry_down():
			return false
		var reach := float(_strike_from.get(act, strike_off))
		if _gap_to(_quarry_ahead(act)) <= reach + slide_slack * visual_scale / 1.6:
			return false
		_slide_serial = act_serial
		slides_made += 1
		_face(_quarry_ahead(act) - global_position, 1.0, 50.0)
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_slide.rpc()
		else:
			net_slide()
	# turned after where he will be till just before the blow, then locked
	if _act_time < sp.y - chase_commit:
		_face(_quarry_ahead(act) - global_position, delta, turn_speed * 4.0)
		_reframe()
	var window := maxf(sp.y - sp.x, 0.15)
	_slide_speed = clampf(_close_speed_for(act, sp.y, sp.x, true), 0.0,
			slide_most * visual_scale / 1.6 / window)
	return true


## Every peer: the held swing let go at him — a grunt, grit kicked up off
## its feet as it slides.
@rpc("authority", "call_local", "reliable")
func net_slide() -> void:
	_sound_at(GRUNTS, global_position + Vector3.UP * 1.6 * visual_scale, 0.8, 0.0)
	var into := Blood.world_of(self)
	var back := -_forward()
	for side: float in [-0.35, 0.35]:
		var at := global_position + back * 0.3 + _forward().cross(Vector3.UP) * side * visual_scale
		SkillFx.particles(into, at + Vector3.UP * 0.08, {
			"amount": 9, "life": 0.7, "one_shot": true, "explosiveness": 0.85, "add": false,
			"speed": Vector2(0.8, 2.0), "dir": back + Vector3.UP * 0.6, "spread": 35.0, "gravity": Vector3(0, -3.0, 0),
			"damping": 1.5, "size": Vector2(0.15, 0.32), "grow": 0.4, "sphere": 0.2,
			"colors": [Color(0.6, 0.55, 0.47, 0.0), Color(0.58, 0.53, 0.46, 0.4), Color(0.55, 0.5, 0.45, 0.0)],
		})
	WindBlast.shake(self, 0.05, 0.2, 9.0)


## A leap's flight in act seconds: [leaves the ground, lands], drawn out.
func _flight_span(what: int) -> Vector2:
	var f: Array = FLIGHTS[what]
	var m: Array = _moves_table[what]
	var c0 := _anim.clip_length(m[0]) * float(m[2]) if _anim != null else 0.0
	var a0 := (float(f[0]) - c0) / float(m[1])
	var a1 := (float(f[1]) - c0) / float(m[1])
	return Vector2(a0, a0 + (a1 - a0) * float(f[2]))


## [act s the flight begins, its length at the clip's pace, how much slower].
func _flight_warp(what: int) -> Vector3:
	var f: Array = FLIGHTS[what]
	var m: Array = _moves_table[what]
	var c0 := _anim.clip_length(m[0]) * float(m[2]) if _anim != null else 0.0
	var a0 := (float(f[0]) - c0) / float(m[1])
	return Vector3(a0, (float(f[1]) - float(f[0])) / float(m[1]), float(f[2]))


func _clip_time(what: int, t: float) -> float:
	if FLIGHTS.has(what) and _anim != null:
		var w := _flight_warp(what)
		if t > w.x:
			if t < w.x + w.y * w.z:
				t = w.x + (t - w.x) / w.z
			else:
				t -= w.y * (w.z - 1.0)
	return super(what, t)


func _move_length(what: int) -> float:
	var length := super(what)
	if FLIGHTS.has(what) and _anim != null:
		var w := _flight_warp(what)
		length += w.y * (w.z - 1.0)
	# a swing the string goes on from: on into the next soon after its last
	# blow, its own recovery cut (the user's word, 2026-10-10: the pauses
	# in its strings were so long he could not tell it was a string)
	if what == act and (SWINGS.has(what) or COMBO_MOVES.has(what)) and not _closing and _string_count > 0:
		var ms := _blow_moments(what)
		if not ms.is_empty():
			length = minf(length, ms[ms.size() - 1] + string_follow_after)
	return length


func _blow_moments(what: int) -> PackedFloat32Array:
	var ms := super(what)
	if not FLIGHTS.has(what) or _anim == null:
		return ms
	var w := _flight_warp(what)
	var out := PackedFloat32Array()
	for m in ms:
		if m <= w.x:
			out.append(m)
		elif m <= w.x + w.y:
			out.append(w.x + (m - w.x) * w.z)
		else:
			out.append(m + w.y * (w.z - 1.0))
	return out


func _run_act(delta: float) -> void:
	var was := act
	var serial := act_serial
	var t0 := _act_time - delta
	super(delta)
	if is_dead or not _decides():
		return
	if was == act and serial == act_serial and _strikes_table.has(act):
		_watch_blows(t0)
	if (act == POUND or act == POUND_2 or act == POUND_3) and not _pounded and _act_time >= _pound_time(act):
		_pounded = true
		var k := 0 if act == POUND else (1 if act == POUND_2 else 2)
		var tip := _weapon_tip_at()
		var at := Vector3(tip.x, global_position.y, tip.z)
		var reach := pound_reaches[k] * visual_scale / 1.6
		_quake(at, reach, hit_damage * pound_share * (1.0 + 0.25 * k), false, rock_pace)
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_rocks.rpc(at, act_serial, reach, 1.0 + 0.35 * k)
		else:
			net_rocks(at, act_serial, reach, 1.0 + 0.35 * k)
	elif act == STOMP and not _pounded and _act_time >= _stomp_at:
		_pounded = true
		_stomp_down()
	elif act == HEAVY and not _pounded and _act_time >= _blow_moments(HEAVY)[0]:
		# the great blow into the ground: rock bursting up all round, and
		# everyone on the ground near it thrown down
		_pounded = true
		var tip := _weapon_tip_at()
		var at := Vector3(tip.x, global_position.y, tip.z)
		_quake(at, heavy_quake_radius * visual_scale / 1.6, hit_damage * heavy_quake_share, false, rock_pace)
		var length := heavy_rock_length * visual_scale / 1.6
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			net_rocks.rpc(at, act_serial, length, 1.4)
		else:
			net_rocks(at, act_serial, length, 1.4)
	elif act == OG_STOMP_FOOT and not _pounded and _act_time >= _blow_moments(OG_STOMP_FOOT)[0]:
		# its foot down: the ground bursts up round it (it staggers him)
		_pounded = true
		var foot := global_position
		if _skeleton != null:
			var b := _skeleton.find_bone("R_toe_joint")
			if b >= 0:
				foot = _skeleton.global_transform * _skeleton.get_bone_global_pose(b).origin
		_aftershock(Vector3(foot.x, global_position.y, foot.z) + _forward() * 0.6 * visual_scale / 1.6,
				act_serial * 1000 + 55)


## Host, through a swing: did he roll from under its blow (for the
## roll-catch), and did a lone heavy blow or a slam meet the ground (an
## aftershock to follow).
func _watch_blows(t0: float) -> void:
	var ms := _blow_moments(act)
	if ms.is_empty():
		return
	if _quarry is Player:
		var st := (_quarry as Player).state
		if st == Player.State.DODGING or st == Player.State.DASHING:
			for m in ms:
				if absf(_act_time - m) < 0.3:
					_saw_roll = true
	var last := ms[ms.size() - 1]
	if aftershocks_follow and t0 < last and _act_time >= last and _shakes_after(act):
		_shock_look = Vector2(act_serial, _act_time + 0.35)
	# From its blow on, the first moment the club is down by the ground.
	if int(_shock_look.x) == act_serial and _act_time <= _shock_look.y:
		var tip := _weapon_tip_at()
		if tip.y - global_position.y < 0.9 * visual_scale:
			_shock_look = Vector2(-1, 0)
			var ahead := _forward() * aftershock_ahead * visual_scale / 1.6
			_shocks.append([Vector3(tip.x, global_position.y, tip.z) + ahead, aftershock_after, act_serial * 1000 + 77])


## Whether the ground answers this move's blow a beat later: the slams and
## the great blow always, a heavy swing when it closes its string alone or
## last (combos stay as they were).
func _shakes_after(what: int) -> bool:
	if (FLIGHTS.has(what) and float((FLIGHTS[what] as Array)[3]) > 0.0) or what == HEAVY or what == JUMP_SLAM:
		return true
	if COMBO_MOVES.has(what):
		return bool(COMBO_MOVES[what][2]) and _closing
	return SWINGS.has(what) and bool(SWINGS[what][2]) and _closing


func _physics_process(delta: float) -> void:
	_watch_his_run(delta)
	super(delta)
	if _shocks.is_empty() or is_dead or not _decides():
		return
	for i in range(_shocks.size() - 1, -1, -1):
		var sh: Array = _shocks[i]
		sh[1] = float(sh[1]) - delta
		if float(sh[1]) > 0.0:
			continue
		_shocks.remove_at(i)
		_aftershock(sh[0], int(sh[2]))


## Host: the second burst of earth: whoever is on the ground near it is
## caught (a stagger; off the ground, or rolling, it misses him).
func _aftershock(at: Vector3, id: int) -> void:
	aftershocks_made += 1
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_aftershock.rpc(at)
	else:
		net_aftershock(at)
	for node in get_tree().get_nodes_in_group(&"player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or bool(who.get("is_dead")):
			continue
		var rel := who.global_position - at
		if absf(rel.y) > 2.0 or Vector2(rel.x, rel.z).length() > aftershock_radius * visual_scale / 1.6:
			continue
		who.call(&"receive_blow", hit_damage * aftershock_share * _blow_worth(0), self, 0, 2, id, false, &"ground")


## Every peer: the great blow's rock — rows of stone bursting up out from where
## the club went in, all the way round, grit thrown up, the view shaken hard.
@rpc("authority", "call_local", "reliable")
func net_rocks(at: Vector3, seed_of: int, length: float, size: float) -> void:
	var into := Blood.world_of(self)
	var s := visual_scale / 1.6
	RockWave.spawn(into, at, length, size * s, rock_pace, seed_of)
	GroundFx.eruption(into, at, (0.9 + 0.3 * size) * s, false)
	ImpactFx.thud(self, at, true)
	_sound_at(CLUB_GROUND, at, 0.75 - 0.05 * size, 2.0 + size)
	WindBlast.shake(self, 0.12 + 0.08 * size, 0.5 + 0.15 * size, 16.0)


## Every peer: the ground bursting up again ahead of where the club fell —
## earth and stones thrown up unevenly, a deep crack of it, the view shaken
## (no ring).
@rpc("authority", "call_local", "reliable")
func net_aftershock(at: Vector3) -> void:
	var into := Blood.world_of(self)
	var fwd := _forward()
	GroundFx.eruption(into, at + Vector3.UP * 0.05, 0.9, false)
	GroundFx.eruption(into, at + fwd * 0.9 + fwd.cross(Vector3.UP) * 0.4 + Vector3.UP * 0.05, 0.55, false)
	ImpactFx.thud(self, at + Vector3.UP * 0.2, true)
	_sound_at(CLUB_GROUND, at, 0.72, 1.0)
	WindBlast.shake(self, 0.1, 0.35, 14.0)


## Host: the club down where he lies: a blow at him if it comes down by him.
func _stomp_down() -> void:
	var at := _weapon_tip_at()
	var world := Blood.world_of(self)
	DustRing.burst(world, Vector3(at.x, global_position.y + 0.05, at.z), 0.6 * visual_scale)
	ImpactFx.thud(self, at, true)
	if _quarry == null or not _quarry.has_method(&"receive_blow"):
		return
	var flat := Vector2(at.x - _quarry.global_position.x, at.z - _quarry.global_position.z).length()
	if flat <= 1.5:
		_quarry.call(&"receive_blow", hit_damage * stomp_share * _blow_worth(STOMP), self, 0, 1,
				act_serial, false, &"stomp")


func _after(what: int) -> void:
	match what:
		POUND:
			_pound_wait = _rng.randf_range(pound_cooldown.x, pound_cooldown.y) * (0.6 if raging else 1.0)
		HEAVY:
			_heavy_wait = _rng.randf_range(heavy_cooldown.x, heavy_cooldown.y) * (0.6 if raging else 1.0)
		STOMP:
			_stomp_wait = stomp_cooldown
		LUNGE:
			_lunge_wait = _rng.randf_range(lunge_cooldown.x, lunge_cooldown.y)
		LEAP_SLAM:
			_leap_slam_wait = _rng.randf_range(leap_slam_cooldown.x, leap_slam_cooldown.y) * (0.7 if raging else 1.0)
	var stringed := SWINGS.has(what) or COMBO_MOVES.has(what) or what == POUND or what == POUND_2 \
			or what == POUND_3 or what == HEAVY or FLIGHTS.has(what)
	var next := -1
	if stringed and not is_dead and _decides():
		next = _next_in_string(what)
	super(what)
	if next >= 0:
		# On into the next, turned a little after him.
		if _quarry != null:
			var to := _quarry.global_position - global_position
			rotation.y = rotate_toward(rotation.y, atan2(-to.x, -to.z), deg_to_rad(string_turn))
		_begin_move(next, what)
		return
	if stringed:
		var r := recover_raging if raging else recover
		_cooldown = _rng.randf_range(r.x, r.y)
	_string_count = 0
	_chain_serial = -1
	_chain_blow = 0
	_closing = false
	_combo = -1
#endregion


#region Looks and sounds
## Every peer: the swing heard coming, the club meeting the ground, its roar,
## and the weight of its feet.
func _process(delta: float) -> void:
	super(delta)
	if is_dead:
		return
	if act_serial != _heard_serial:
		_heard_serial = act_serial
		_heard_clock = 0.0
		_heard = 0
		_on_new_act()
	else:
		_heard_clock += delta
	_watch_hold()
	_lift_in_flight()
	if _strikes_table.has(act):
		var ms := _blow_moments(act)
		while _heard < ms.size() * 2:
			var i := _heard / 2
			var whoosh := _heard % 2 == 0
			var when := ms[i] - (0.16 if whoosh else 0.0)
			if _heard_clock < when:
				break
			_heard += 1
			if whoosh:
				Sfx.play(self, WHOOSH_HEAVY if _is_heavy(act) else WHOOSH_LIGHT, null, _weapon_tip_at(),
						0.95 if _is_heavy(act) else 1.05, -4.0 if _is_heavy(act) else -9.0)
			elif _is_heavy(act):
				_club_lands()
	elif act == Act.NONE:
		_footfalls()


## Every peer: a swing held at the top of its wind-up shows it the moment it
## stops there (the user's word, 2026-10-10: the delay should be learnt).
func _watch_hold() -> void:
	if is_dead or act_serial == _glint_serial or not _holds.has(act):
		return
	var sh := _shape(act)
	if sh.is_empty() or float(sh[2]) <= 0.0:
		return
	if _heard_clock < float(sh[0]) * float(sh[1]):
		return
	_glint_serial = act_serial
	_glint()


## A glint off the club's end — a hard white-gold flash and sparks — and a
## low growl.
func _glint() -> void:
	var tip := _weapon_tip_at()
	var into := Blood.world_of(self)
	SkillFx.particles(into, tip, {
		"amount": 26, "life": 0.45, "one_shot": true, "explosiveness": 1.0, "add": true,
		"speed": Vector2(1.5, 4.0), "dir": Vector3.UP, "spread": 180.0, "gravity": Vector3.ZERO,
		"damping": 5.0, "size": Vector2(0.12, 0.26), "grow": -0.6, "sphere": 0.08,
		"colors": [Color(1.0, 0.95, 0.75, 0.0), Color(1.0, 0.9, 0.6, 1.0), Color(1.0, 0.55, 0.2, 0.0)],
	})
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.85, 0.55)
	flash.omni_range = 3.0 * visual_scale
	flash.light_energy = 11.0
	flash.shadow_enabled = false
	into.add_child(flash)
	flash.global_position = tip
	var t := flash.create_tween()
	t.tween_property(flash, "light_energy", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	t.tween_callback(flash.queue_free)
	Sfx.play_any(self, GRUNTS, self, 0.72, -2.0)


## Every peer: through a leap's flight the body is carried higher than the
## clip's own jump, an arc over the act clock; back on the ground after.
func _lift_in_flight() -> void:
	if body == null:
		return
	if FLIGHTS.has(act) and not is_dead and _anim != null:
		var span := _flight_span(act)
		var u := clampf((_heard_clock - span.x) / maxf(span.y - span.x, 0.05), 0.0, 1.0)
		# Up over the first 60 %, then brought down hard.
		var arc := sin(PI * 0.5 * u / 0.6) if u < 0.6 else cos(PI * 0.5 * (u - 0.6) / 0.4)
		body.position.y = _body_rest_y + float((FLIGHTS[act] as Array)[3]) * visual_scale / 1.6 * arc
		_lifted = true
	elif _lifted:
		_lifted = false
		if not is_dead:
			body.position.y = _body_rest_y


## Its walk, its trot, its run, by its pace (every peer sees the pace), each
## played at the rate its feet keep to the ground; anything else (sideways,
## back, standing) as any of the pack.
func _play_locomotion(delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var pace := planar.length()
	if pace < 0.15 or trot_clip.is_empty() or planar.dot(_forward()) < pace * 0.6:
		super(delta)
		return
	var now := _anim.current_clip()
	var clip := walk_clip
	var to_trot := trot_above - (0.25 if now == trot_clip or now == run_clip else 0.0)
	var to_run := run_gait_above - (0.3 if now == run_clip else 0.0)
	if pace > to_run and not run_clip.is_empty():
		clip = run_clip
	elif pace > to_trot:
		clip = run_clip if runs_after and not run_clip.is_empty() else trot_clip
	_anim.play(clip, 0.25, gait_rate(clip, pace))


func _is_heavy(what: int) -> bool:
	if COMBO_MOVES.has(what):
		return bool(COMBO_MOVES[what][2])
	return what == HEAVY or what == STOMP or (SWINGS.has(what) and bool(SWINGS[what][2]))


func _on_new_act() -> void:
	if act == RAGE:
		Sfx.play(self, ROAR_SOUND, self, Vector3.ZERO, 0.95, 2.0)
	elif act == STANCE:
		Sfx.play_any(self, GRUNTS, self, 0.8, -2.0)
	elif act == POUND or act == POUND_3 or act == HEAVY:
		Sfx.play(self, ROAR_SHORT_SOUND, self, Vector3.ZERO, 1.1, -6.0)
	elif _is_heavy(act) and randf() < 0.45:
		Sfx.play_any(self, GRUNTS, self, 1.0, -7.0)


## A heavy blow come down: if the club is down by the ground, the ground
## takes it — the crack of it, earth and grit thrown up, the view shaken.
func _club_lands() -> void:
	var tip := _weapon_tip_at()
	if tip.y - global_position.y > 0.9 * visual_scale:
		return
	var at := Vector3(tip.x, global_position.y + 0.05, tip.z)
	_sound_at(CLUB_GROUND, at, 1.0, -2.0)
	var into := Blood.world_of(self)
	GroundFx.eruption(into, at, 0.55, false)
	WindBlast.shake(self, 0.07, 0.28, 12.0)


## Walking or running, each foot as it comes down: a deep step and a little
## dust off it, the view nudged when he is near.
func _footfalls() -> void:
	if _skeleton == null or _ankles.size() < 2:
		return
	var pace := Vector2(velocity.x, velocity.z).length()
	for k in 2:
		if _ankles[k] < 0:
			continue
		var foot := _skeleton.global_transform * _skeleton.get_bone_global_pose(_ankles[k]).origin
		var low := foot.y - global_position.y < 0.16 * visual_scale
		if low and not _foot_down[k] and pace > 0.6:
			var into := Blood.world_of(self)
			_sound_at(STEPS, foot, 0.92 if pace > run_gait_above else 1.0,
					-9.0 if pace < 3.0 else (-5.0 if pace < run_gait_above else -2.0))
			SkillFx.particles(into, Vector3(foot.x, global_position.y + 0.08, foot.z), {
				"amount": 5, "life": 0.8, "one_shot": true, "explosiveness": 0.9, "add": false,
				"speed": Vector2(0.3, 0.9), "dir": Vector3.UP, "spread": 80.0, "gravity": Vector3(0, -0.4, 0),
				"damping": 2.0, "size": Vector2(0.18, 0.35), "grow": 0.3, "sphere": 0.15,
				"colors": [Color(0.6, 0.55, 0.47, 0.0), Color(0.58, 0.53, 0.46, 0.3), Color(0.55, 0.5, 0.45, 0.0)],
			})
			if pace > 2.5:
				WindBlast.shake(self, 0.035 if pace > run_gait_above else 0.02, 0.15, 7.0)
		_foot_down[k] = low


func _sound_at(paths: Array, at: Vector3, pitch: float, volume_db: float) -> void:
	Sfx.play(self, String(paths[randi() % paths.size()]), null, at, pitch, volume_db)
#endregion
