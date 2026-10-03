class_name SkinnedRig
extends CharacterRig

## Tariel as a real skinned character: one Skeleton3D, and the Mixamo sword and
## shield library played on it through an AnimationPlayer.
##
## It stands in for [CharacterRig] everywhere the controller talks to a rig —
## same calls, same answers — so `player.gd` does not know which of the two it
## was handed. The procedural rig is untouched and still drives Avtandil;
## putting Tariel back on it is one line in `tariel.tres`.
##
## The model and every clip come from `assets/tariel_rigged/tariel_rigged.glb`,
## exported from `~/Desktop/vepxis-art/tariel/tariel.blend` (see NOTES.md
## there): the old joint hierarchy turned into a 36-bone skeleton with UE
## mannequin names, every armour plate bound rigidly to one bone so nothing
## stretches, and the Mixamo clips retargeted onto it in Blender.
##
## What the library does not cover — climbing, the slide, sheathing — falls back
## to the nearest pose it does have. Those are marked below.

## Which clip plays for what. Everything the rig decides is looked up here, so a
## second character is a second table (see `SkinnedArcherRig`), not a second rig.
## Set by `_configure()`; these are Tariel's.
var clips := {
	&"idle": &"SS_Idle", &"walk": &"SS_Walk", &"run": &"SS_Run",
	&"walk_back": &"SS_Backward_Walk", &"run_back": &"SS_Backward_Run",
	&"walk_left": &"SS_Left_Strafe_Walk", &"walk_right": &"SS_Right_Strafe_Walk",
	&"run_left": &"SS_Left_Run_Strafe", &"run_right": &"SS_Right_Run_Strafe",
	&"block_idle": &"SS_Block_Idle", &"block_walk": &"SS_Block_Walk",
	&"block_walk_back": &"SS_Block_Walk_Back", &"block_walk_left": &"SS_Block_Walk_Left",
	&"block_walk_right": &"SS_Block_Walk_Right",
	&"crouch": &"SS_Crouch_Block_Idle", &"air": &"SS_Running_Jump",
	&"crouch_walk": &"SS_Crouch_Walk", &"crouch_walk_back": &"SS_Crouch_Walk_Back",
	&"crouch_walk_left": &"SS_Crouch_Walk_Left", &"crouch_walk_right": &"SS_Crouch_Walk_Right",
	&"roll": &"Roll_Quick_To_Run", &"down": &"SS_Falling_Back_Death",
	&"hit": &"SS_Head_Impact", &"hit_blocked": &"SS_Blocked_Impact",
	&"mantle": &"SS_Mantle", &"plunge": &"SS_Jump_Attack",
	&"overhead": &"SS_Downward_Slash",
	# Keyed in Blender off the guard: the shield swept out across the blow and
	# the body opened behind it, the sword drawn back for the answer.
	&"parry": &"SS_Parry",
	# The same guard behind the tower shield: lower, knees bent, leaning in.
	&"tower_block": &"SS_Tower_Block",
}
## Ground speed each in-place cycle was authored at, measured in Blender off the
## planted foot (m/s). The play rate is the body's speed over this, so the feet
## keep up with the ground instead of skating.
var ground_speed := {
	&"SS_Walk": 1.42, &"SS_Run": 3.2,
	&"SS_Backward_Walk": 1.12, &"SS_Backward_Run": 3.22,
	&"SS_Left_Strafe_Walk": 1.08, &"SS_Right_Strafe_Walk": 1.21,
	&"SS_Left_Run_Strafe": 2.56, &"SS_Right_Run_Strafe": 2.45,
	&"SS_Block_Walk": 1.42, &"SS_Block_Walk_Back": 1.12,
	&"SS_Block_Walk_Left": 1.08, &"SS_Block_Walk_Right": 1.21,
	&"SS_Crouch_Walk": 1.5, &"SS_Crouch_Walk_Back": 1.14,
	&"SS_Crouch_Walk_Left": 1.3, &"SS_Crouch_Walk_Right": 1.32,
}
var looping: Array[StringName] = [
	&"SS_Idle", &"SS_Walk", &"SS_Run", &"SS_Backward_Walk", &"SS_Backward_Run",
	&"SS_Left_Strafe_Walk", &"SS_Right_Strafe_Walk", &"SS_Left_Run_Strafe",
	&"SS_Right_Run_Strafe", &"SS_Block_Idle", &"SS_Crouch_Block_Idle",
	&"SS_Left_Crouch_Idle_Loop", &"SS_Sword_Play_Idle", &"SS_Look_Around_Idle",
	&"SS_Block_Walk", &"SS_Block_Walk_Back", &"SS_Block_Walk_Left", &"SS_Block_Walk_Right",
	&"SS_Crouch_Walk", &"SS_Crouch_Walk_Back", &"SS_Crouch_Walk_Left", &"SS_Crouch_Walk_Right",
	&"SS_Tower_Block",
]
## The cuts a flurry cycles through, in order.
var flurry: Array[StringName] = [&"SS_High_Attack", &"SS_Cross_Slash", &"SS_Downward_Slash"]
## Cuts of the flurry played from a part of their clip only, as shares of its
## length (from, until): a thrust out of a longer knife-fighting clip.
var flurry_part: Dictionary = {}
## The flurry speeds up as it goes: each cut this share quicker than the last.
var flurry_quicken: float = 0.0
## No cut of the flurry is played faster than this (seconds for its part),
## the last no faster than `finisher_min_time`. Zero: `swing_rate` for all.
var flurry_min_time: float = 0.0
var finisher_min_time: float = 0.0
## How much the last cut of the flurry is worth against the others.
var finisher_weight: float = 1.0
## Heavy blows, thrown with `attack(HEAVY + i)`: each {clip, part (from, until
## as shares), rate, weight (what it is worth against a light cut), aim (bent
## down to what it is thrown at), step (how far it may carry him in to it)}.
## Which one is the controller's to choose.
var heavy: Array = []
const HEAVY := 100
## The attack style of the running cut (the moves' `run_attack`).
const RUN_CUT := 90
## The attack style of Tariel's skill, the rising cut (the moves' `rising_cut`).
const RISING_CUT := 91
## The attack style of Tariel's second skill, the shadow slide (the moves'
## `shadow_slide`).
const SHADOW_SLIDE := 92
## And his third, the shadow lance (the moves' `shadow_lance`).
const SHADOW_LANCE := 93
## The moves' spec each of those styles plays.
const CUT_SPECS := {RUN_CUT: "run_attack", RISING_CUT: "rising_cut", SHADOW_SLIDE: "shadow_slide",
	SHADOW_LANCE: "shadow_lance"}
## Clips that cut more than once: every window its own blow (a new attack
## serial, a new whoosh), as shares of the clip.
var cut_windows: Dictionary = {}
## Clips whose own travel carries the body (a flip, a lunge): the controller
## moves him by `carry_velocity` while one plays.
var carried: Dictionary = {}
## Where the arc behind the blade is drawn, as shares of a clip: the whole sweep
## of the swing (the tip past a third of its top speed), which is wider than the
## window that cuts. A clip not in it draws its arc over its cut window only.
var trail_window: Dictionary = {}
## How this hero's arc looks ([BladeArc] properties by name: life, intensity,
## sheet, taper), and how much brighter, wider and longer it is on a blow worth
## more than 1.2 of a cut (a heavy blow, the end of the string).
var arc_style: Dictionary = {}
var arc_heavy_boost: float = 1.0
## The off hand's arc only while a whole figure is worn (see `whole_faces`):
## the assassin made real has a knife in that hand, the old one has none.
var off_hand_whole_only: bool = false
var _arc_base: Dictionary = {}
## A heavy blow's clip reached its `slam` share: the blade in the ground at
## `at`, where the shockwave goes out from. Once a blow, on every peer.
signal slammed(at: Vector3, heft: float)
var _slam_done: bool = false
var carry_velocity := Vector3.ZERO
## How much of its clip's travel a carried blow covers: set by the controller
## so a flip lands where what it is thrown at stands (1 on every other peer).
var carry_scale: float = 1.0
## What the blow in hand is worth against a light cut.
var cut_weight: float = 1.0
var _heavy_now: bool = false
var _heavy_aim: bool = true
var _window_at: int = -1
var _carrying: bool = false
## Where each swing's blade is actually travelling, as a fraction of the clip —
## measured in Blender as the span the tip moves faster than 55% of its peak.
var cut_window := {
	&"SS_High_Attack": Vector2(0.41, 0.487), &"SS_Cross_Slash": Vector2(0.44, 0.52),
	&"SS_Downward_Slash": Vector2(0.378, 0.467), &"SS_Low_Attack": Vector2(0.404, 0.462),
	&"SS_Power_Slash": Vector2(0.548, 0.575), &"SS_Jump_Attack": Vector2(0.471, 0.543),
	&"SS_Crouch_Slash": Vector2(0.366, 0.488),
}
## How far into the roll clip the body is back on its feet (pelvis lowest at 0.64).
var roll_share := 0.8
## The jump attack, re-baked in Blender with the clip's own jump taken out (the
## controller does the jumping): the sword goes up from 0.40, the chop reaches
## the ground at 0.56, the blade stays in it to 0.77 and he stands after that.
## Thrown in the air it plays `air_cut_from`..`plunge_from` and holds the chop
## until the feet land; the landing (`plunge()`) carries on from there, so the
## two are one movement rather than a cut into another clip.
var air_cut_from := 0.40
var plunge_from := 0.56

## Blade, measured from the fist along the blade (m).
const BLADE_BASE := 0.18
const BLADE_TIP := 1.03
## The same, per character (a dagger is a third of a sword), and which way the
## blade points in the socket at rest, in the skeleton's frame: the knight's
## sword lies forward in the T, the rogue's daggers stand up.
var blade_base := BLADE_BASE
var blade_tip := BLADE_TIP
var blade_rest_dir := Vector3(0, 0, 1)
## A blade in the other hand too, which cuts the air as the right one does.
var off_hand_blade := false
## What a swing sounds like: one of these, at random, at `swing_pitch`. The
## knight's sword; the rogue sets his own knife's (`SkinnedRogueRig`).
var swing_sounds: Array[String] = [
	"res://unverified/sounds/tariel/slash_1.wav", "res://unverified/sounds/tariel/slash_2.wav",
	"res://unverified/sounds/tariel/slash_3.wav", "res://unverified/sounds/tariel/slash_4.wav",
]
## The older, lighter whooshes: the staff and the hunter's knife keep these.
const LIGHT_SWINGS: Array[String] = [
	"res://unverified/sounds/tariel/swing_1.wav", "res://unverified/sounds/tariel/swing_2.wav",
	"res://unverified/sounds/tariel/swing_3.wav", "res://unverified/sounds/tariel/swing_4.wav",
	"res://unverified/sounds/tariel/swing_5.wav", "res://unverified/sounds/tariel/swing_6.wav",
	"res://unverified/sounds/tariel/swing_7.wav",
]
## How loud the swing plays, dB. (The user's slashes are ~8 dB hotter than
## the old air cuts; the rigs that keep those set their own.)
var swing_volume := -18.0
## The weight of a cut heard in its swing (see [method _whoosh_now]): a string's
## first cut higher and quicker, its second plainer, its last (and a cut of
## about its weight) deeper with a rush of air under it, a heavy blow deeper
## still with a deep rush. Off for the rigs with sounds of their own.
var heft_swings := true
const AIR_RUSH: Array[String] = ["res://unverified/sounds/tariel/air_2.wav", "res://unverified/sounds/tariel/air_3.wav"]
const AIR_DEEP: Array[String] = ["res://unverified/sounds/tariel/air_5.wav"]
## The cut weights from which a swing is heard as a string's last, and as a
## heavy blow.
const HEFT_FINISHER := 1.15
const HEFT_HEAVY := 1.75
## The blade going into a creature: one of these at random.
var hit_sounds: Array[String] = ["res://unverified/sounds/tariel/hit_1.wav"]
var hit_volume := -19.0
## Being hurt.
var hurt_sounds: Array[String] = ["res://unverified/sounds/all/hurt_1.wav"]
var hurt_volume := -19.0
var swing_pitch := 1.0

@export_group("Skinned")
## Under this speed the body stands; over `run_threshold` it runs.
@export var idle_threshold: float = 0.25
@export var run_threshold: float = 3.2
## Clamp on how far a cycle is sped up or slowed down to match the ground. Past
## the top of it the feet slide a little rather than blur.
@export var min_play_rate: float = 0.6
@export var max_play_rate: float = 2.1
## Seconds without a click after which the flurry starts again from its first
## swing; 0 keeps it going round wherever it was.
@export var flurry_reset_after: float = 0.0
var _last_attack_at: float = -100.0
@export var loco_blend: float = 0.2
@export var action_blend: float = 0.1
## Widens the measured cutting window a little each side, as a fraction of the clip.
@export var cut_margin: float = 0.03
## Swings play at this rate. Mixamo's are unhurried; the game is not.
@export var swing_rate: float = 1.6
## A swing thrown on the move keeps running legs under it (see
## [StrideModifier]) instead of skating on the clip's planted feet.
@export var swing_strides: bool = true
## How fast he must be going under a swing for the run to be laid under it.
@export var swing_stride_from: float = 1.6
## How quickly the legs go over to the stride and back, in seconds.
@export var stride_blend: float = 0.12

@export_group("Cloth")
## The cape and the ponytail hang off spring bones: they lag behind the body and
## swing back, and the cape is kept off the legs by capsules on them.
@export var cloth_enabled: bool = true
## Pull back towards the way the cloth hangs at rest. Lower is floppier.
@export var cape_stiffness: float = 1.3
@export var cape_drag: float = 0.55
@export var cape_gravity: float = 2.2
## How thick the cape is treated as being when it meets the legs.
@export var cape_radius: float = 0.04
@export var hair_stiffness: float = 0.8
@export var hair_drag: float = 0.4
@export var hair_gravity: float = 0.4
## Capes of cloth ([ClothCape]), one spec each, set by `_configure()`. When
## there are any the cape's spring bones are left alone: the cloth is the cape.
var capes: Array[Dictionary] = []
## The capes hung, for the tests.
var cloth_capes: Array[ClothCape] = []

enum Role { NONE, SWING, ROLL, HIT, DOWN, GET_UP, PLUNGE, CLIMB, FREE }

var _anim: AnimationPlayer
var _skel: Skeleton3D
var _body: Node3D
var _sword_mesh: MeshInstance3D
## The mesh of the blade in the hand, looked up by name (blood goes on it).
var sword_mesh_name: String = "tariel_sword"
var _role: Role = Role.NONE
## Whether the legs walk under the free action now playing (the body moving on
## while the arms do something else — the assassin coating his blade).
var walk_under: bool = false
## Cuts bent down to what they are thrown at ([StrikeAim]); set in `_configure`.
var strike_aim: bool = false
## The height over his feet his swings cut at on their own (metres).
var strike_natural: float = 1.2
## A cut whose clip strikes lower (or higher) than that, by name.
var strike_heights: Dictionary = {}
## How much longer the blade reaches for what it cuts, along its own line
## (metres), and how far a cut aimed at something is let down to it past what
## the bend makes up. A short knife moving fast is past a body between two
## physics ticks as often as it is in it; this is the give that makes the cuts
## that looked like they landed, land.
var strike_reach: float = 0.0
var strike_pull: float = 0.0
var _strike: StrikeAim
var _strike_on: bool = false
var _strike_at: Vector3 = Vector3.ZERO
var _act_clip: StringName = &""
var _action_left: float = 0.0
var _action_len: float = 0.0
var _action_rate: float = 1.0
## Where in its clip the action in hand started, as a share of its length.
var _action_from: float = 0.0
var _base_clip: StringName = &""
var _flurry_slot: int = -1
var _airborne_now: bool = false
var _blocking_now: bool = false
var _plunge_left: float = 0.0
var _swing_commit: float = 0.0
var _air_cut: bool = false
## The evade playing is one that cuts on the way ([Swordsman] `EVADE`).
var _evade_cut: bool = false
var _sliding: bool = false
var _stride: StrideModifier
var _stride_clip: StringName = &""
var _stride_time: float = 0.0
## The cut the blade leaves in the air ([BladeArc]); it stands in for the
## ribbon [CharacterRig] hangs off the procedural rig.
var _arc: BladeArc
var _arc_l: BladeArc
var _blade_base_l: Marker3D
var _blade_tip_l: Marker3D
## Which shield is on the arm (see [enum Shields] in `inventory.gd`): 0 the
## round one, 1 the tower shield. The model carries both; one is shown.
var shield_kind: int = 0
var _shield_meshes: Array[MeshInstance3D] = []
## Outfits the model carries, each its own mesh on the one skeleton (their
## names in the model); one is shown. Empty for a hero with only the one
## (set by `_configure()`).
var garbs: Array[StringName] = []
## Which of `garbs` is on.
var garb: int = 0
## How each outfit hangs the capes: per outfit, one look per spec in `capes`
## (its keys laid over the spec — colours, `length`… — or `{"off": true}`
## to leave that cape off). Empty: every outfit wears the capes as they are.
var garb_capes: Array = []
## The hair styles the model carries, worn over whichever outfit is on. Hair
## is fitted to the skull it grows on, so each style is a mesh per kind of
## skull: "<mesh_prefix>_hair_<skull>_<style>" (see `hair_mesh()`). Empty for
## a hero with only the one.
var hairs: Array[StringName] = []
## What each of `hairs` is called on the hero select.
var hair_names: Array[String] = []
## Which of `hairs` is on.
var hair: int = 0
## The faces the model carries — the head itself, each its own mesh
## "<mesh_prefix>_face_<key>" — with what each is called and which kind of
## skull it is (the hair shown is the set fitted to it). Empty: no choice.
var faces: Array[StringName] = []
var face_names: Array[String] = []
var face_skulls: Array[StringName] = []
## Which of `faces` is on.
var face: int = 0
## Faces that are the whole figure — body and dress with the head — so the
## outfit and the hair are hidden while one is on.
var whole_faces: Array[StringName] = []
## How the capes hang while a whole figure is on (as `garb_capes`, by face).
var whole_capes: Dictionary = {}
## What the model's own meshes are named from.
var mesh_prefix: String = "tariel"
## Faces that carry no shield: while one is on, neither shield is shown.
var shieldless_faces: Array[StringName] = []
## Faces with a sword of their own in the figure: the model's sword is hidden.
var own_sword_faces: Array[StringName] = []
## Figures on skeletons of their own (see [FigureFollower]): other models,
## loaded beside this one and moved by this rig's skeleton. By id:
## {"scene": the model, "prefix": what its meshes' names start with, "map":
## figure bone -> this rig's bone it is turned by, "hips": the figure's bone
## whose partner's travel is carried}. Each carries the arms itself
## ("<prefix>_sword", "_shield", "_tower_shield").
var figures: Dictionary = {}
## Per face worn on one: {"figure": its id, "show": [...], "hide": [...]}:
## the figure's meshes shown are those named "<prefix>_" + one of "show" and
## none of "hide".
var figure_faces: Dictionary = {}
## How a face fights, where it is not as the rig does (set by `_configure()`):
## face -> {"flurry", "flurry_part", "heavy"} laid over the rig's own, and
## "off_hand": false to draw no ring off the off hand, "hide_arms": the
## figure's "arm_*" meshes it does not carry. For a figure that holds one blade
## where the rig holds two.
var face_moves: Dictionary = {}
## The rig's own moves, kept as `_configure()` left them (see `face_moves`).
var _own_moves: Dictionary = {}
## Whether the off hand's ring is drawn for the face that is on.
var _off_hand_on: bool = true
## The figures loaded, by id: {"node", "skel", "follow", "mount"}.
var _figs: Dictionary = {}
## The hero the hero select's maker dresses (see [PolysplitLook]): set in
## `_configure()`, it adds the face CUSTOM, worn on a figure with every part of
## Polysplit's heroes (assets/polysplit/<hero>_<m|f>.glb), each loaded the
## first time it is worn. Empty: no maker.
var polysplit_hero: StringName = &""
## The look made on the hero select, worn while CUSTOM is (see
## [PolysplitLook]); set before the rig is in the tree, or by `set_look()`.
var ps_look: Dictionary = {}
const CUSTOM := &"custom"
## The bones a hero's arms hang from, carried onto the maker's figure by the
## same names where the rig has them (vepxis-art tools/fig_hero.py).
const ARM_BONES: Array[StringName] = [&"weapon_r", &"weapon_l", &"shield_l", &"bow_l", &"bow_limb_l", &"bow_tip_l",
		&"bow_limb_u", &"bow_tip_u", &"draw_r"]
## The rig's own meshes (not named for it, as the warrior's are) put away
## while the maker's figure is worn, to show again after.
var _own_hidden: Array[MeshInstance3D] = []
## Where the cut's markers sit on the rig's own blade, kept to go back to
## from the maker's (whose blades are their own length).
var _blade_at: Array[Vector3] = []
## The figure worn now (null while the rig's own look is on).
var _figure: Node3D
var _figure_skel: Skeleton3D
var _figure_mount: BoneAttachment3D
var _rig_mount: BoneAttachment3D
var _rig_mount_l: Node3D

## YOUR OWN is worn on Quaternius' UAL 2 mannequin, the UE skeleton (three
## spine bones, every finger), and fights with the clips the user picked in
## the animation lab ([Moveset], ANIMATION_MIGRATION.md): the mannequin is
## loaded beside the model the first time YOUR OWN is worn, its own mesh
## hidden, and while it is worn it is this rig's skeleton and player — the
## model's is still and hidden. The hero's own clips come with it, carried
## onto the mannequin (`HERO_LIB`), for whatever the picks leave out; the
## figure is the maker's built on the mannequin's limbs (`MANNEQUIN_FIGURE`).
## The looks AS HE WAS and the rest stay on the hero's own rig and clips.
## False: YOUR OWN on the hero's own rig, as before the migration.
var maker_on_mannequin: bool = true
const MANNEQUIN_SCENE := "res://assets/anim/lab/ual2_mannequin.glb"
const KEVIN_LIB := "res://assets/anim/lab/kevin_lib.res"
const HERO_LIB := "res://assets/anim/heroes/%s_mannequin.res"
const MANNEQUIN_FIGURE := "res://assets/polysplit/mannequin_%s.glb"
## Clips another hero's library lends this one on the mannequin (clip ->
## hero): the mage's spell is Tariel's.
var mq_borrow: Dictionary = {}
## The shield's face about the left forearm (degrees from up towards ahead,
## in the T-pose) as the maker's figure is built (vepxis-art ps_creator.py
## THETA0), and where it is turned to for a clip the moves do not name.
const SHIELD_BUILT_TURN := 18.6
var shield_turn_default: float = 0.0
## The picked blows' pace (see `swing_rate`).
const MQ_SWING_RATE := 1.1
## This hero's share of that pace: under 1 for a heavy one (the warrior).
var mq_swing_scale: float = 1.0
## How fast the shield goes round onto a clip's way (degrees a second).
const SHIELD_TURN_RATE := 540.0
## Seconds without a blow, a hit or a guard after which he stands easy (the
## lab's STANDING) rather than on guard.
const EASE_AFTER := 4.0
## The moves worn on the mannequin ([method Moveset.build]); empty off it.
var moves: Dictionary = {}
var _on_mq: bool = false
## {"node", "skel", "anim", "stride", "strike"} once built.
var _mq: Dictionary = {}
## The model's own skeleton, player and modifiers while the mannequin is worn.
var _own: Dictionary = {}
## The rig's own tables as `_configure()` left them (see `_tables()`).
var _own_tables: Dictionary = {}
var _strings: Array = []
var _fight_till: float = -100.0
var _guard_clip: StringName = &""
var _air_was: bool = false
var _air_t: float = 0.0
var _air_clip: StringName = &""
var _air_rising: bool = false
## A clip that only brings him back (a blow's recovery, the landing): moving
## off lets go of it.
var _recovering: bool = false
var _shield_turn_now: float = NAN
## The two-handed weapon's ends in the figure's hand (see `_hilt()`).
var _hilt_ends: Array[Vector3] = []


func _ready() -> void:
	_attack_rng.randomize()
	_anim = find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	_skel = find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	if _anim == null or _skel == null:
		push_error("SkinnedRig: the model has no AnimationPlayer or Skeleton3D.")
		return
	_body = get_parent() as Node3D
	_configure()
	if polysplit_hero != &"":
		_add_maker()
	_own_moves = {"flurry": flurry.duplicate(), "flurry_part": flurry_part.duplicate(),
			"heavy": heavy.duplicate(true)}
	_own_tables = _tables()
	for n in looping:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	# The clips carry their travel on the `root` bone. The controller moves the
	# body itself, so that travel is taken out of the pose rather than played.
	var holder := _anim.get_node(_anim.root_node)
	_anim.root_motion_track = NodePath(String(holder.get_path_to(_skel)) + ":root")
	_setup_blade()
	# Before the cloth, so the cape's spring bones hang over the legs as they
	# end up, stride and all.
	_stride = StrideModifier.new()
	_stride.name = "Stride"
	_skel.add_child(_stride)
	if strike_aim:
		_strike = StrikeAim.new()
		_strike.name = "StrikeAim"
		_strike.natural = strike_natural
		_skel.add_child(_strike)
	if cloth_enabled:
		_setup_cloth()
	# The capes are the rig's own cloth, not spring bones: hung on every rig.
	_setup_capes()
	_put_on_dress()
	_sword_mesh = find_child(sword_mesh_name, true, false) as MeshInstance3D
	for mesh_name in ["tariel_shield", "tariel_tower_shield"]:
		_shield_meshes.append(find_child(mesh_name, true, false) as MeshInstance3D)
	_setup_figure()
	set_shield(shield_kind)
	set_garb(garb)
	set_face(face)
	_set_base(clips[&"idle"], 0.0, 1.0)
	# Read off the disk now, not on the first swing.
	Sfx.warm(swing_sounds + hit_sounds + hurt_sounds + AIR_RUSH + AIR_DEEP)
	ImpactFx.warm()


## Override to swap in another character's clip table (see `clips`). The
## knight's own: his tiger's skin, hung from the fur across his shoulders.
func _configure() -> void:
	wardrobe = TARIEL_WARDROBE
	# His sword is swung at a man's chest; a puglin (1.1 m) is under it. Bent
	# down to what it is thrown at ([StrikeAim]), as the assassin's knife is.
	strike_aim = true
	strike_natural = 1.3
	strike_pull = 0.25
	# His string, after the one the user filmed in Dragonwilds: a hard cut from
	# his right to his left with a step into it, a backhand low and in, a sweep
	# up out of a crouch, and to end it a whole turn on his feet, low, the blade
	# coming round and up with him. Each about 0.5 s; left for a beat, it
	# starts over. (The great sword's running spin was the first finisher: two
	# hands on the hilt through his shield, a run under it and a lean back —
	# it read as a man falling round, not turning.)
	flurry = [&"TR_Axe_R2L", &"TR_Inward", &"TR_Axe_Spin_A", &"TR_Axe_Rising"]
	flurry_part = {
		&"TR_Axe_R2L": Vector2(0.25, 0.62), &"TR_Inward": Vector2(0.36, 0.78),
		&"TR_Axe_Spin_A": Vector2(0.2, 0.62), &"TR_Axe_Rising": Vector2(0.1, 0.62),
	}
	finisher_weight = 1.6
	flurry_reset_after = 1.1
	# Measured in Blender: the tip past 55% of its top speed (cuts) and past
	# 30% (the arc behind it).
	cut_window.merge({
		&"TR_Axe_R2L": Vector2(0.389, 0.431), &"TR_Inward": Vector2(0.485, 0.591),
		&"TR_Axe_Spin_A": Vector2(0.36, 0.413), &"TR_Axe_Rising": Vector2(0.253, 0.411),
		&"TR_GS_JumpSlam": Vector2(0.446, 0.6),
	}, true)
	trail_window = {
		&"TR_Axe_R2L": Vector2(0.319, 0.458), &"TR_Inward": Vector2(0.47, 0.606),
		&"TR_Axe_Spin_A": Vector2(0.333, 0.467), &"TR_Axe_Rising": Vector2(0.23, 0.44),
		&"TR_GS_JumpSlam": Vector2(0.385, 0.631),
	}
	carried = {&"TR_GS_JumpSlam": true}
	# His heavy blow, thrown out of his guard (the attack button with the
	# shield up): a leap and the sword brought down two-handed into the ground,
	# carried to where the thing stands; the ground shakes where it goes in
	# (`slam`). Once the blade is in, an evade takes him out of getting up.
	heavy = [
		{"clip": &"TR_GS_JumpSlam", "part": Vector2(0.12, 0.86), "rate": 1.45, "weight": 1.9, "aim": false,
			"travel": 3.09, "slam": 0.47, "rise": 0.66},
	]
	# A broad, bright cut in the air, as in the videos, and brighter and longer
	# on the finisher and the slam.
	arc_style = {"life": 0.26, "intensity": 1.0, "sheet": 0.5, "taper": 0.35, "smear": 1.0,
			"tip_overshoot": 0.12}
	arc_heavy_boost = 1.25
	# His outfits (see [Inventory]), the first worn: the berserker's; none
	# with a cape.
	# His outfit (see [Inventory]): the berserker's, no cape.
	garbs = [&"tariel_vk_berserker"]
	garb_capes = [[{"off": true}]]
	# Who he is, picked on the hero select: the square-headed Tariel he always
	# was (the berserker's harness, the long mohawk), or the wanderer after
	# Ashen — a whole figure of his own (body, masked head, hair and dress one
	# mesh), so no outfit or hair is worn with him.
	hairs = [&"mohawk_long"]
	hair_names = ["LONG MOHAWK"]
	# Or the warrior in the iron helm: leather and a scaled coat, his face in
	# the helm's shadow, his own copper-red sword and no shield (".Fuse
	# Warrior" by Leonardo Carvalho, Sketchfab, CC-BY-4.0: a rigged Mixamo
	# character, posed onto this rig and his weights renamed onto it by
	# vepxis-art/tools/fw_fit.py).
	# Or a figure on its OWN skeleton, which follows this one ([FigureFollower];
	# each one's rest turned onto this rig's limbs in Blender):
	# - Blink's low poly man (FREE Low Poly Human – RPG Character, Unity Asset
	#   Store; assets/tariel_blink/SOURCES.txt, tools/bl_blink.py): THE SQUIRE
	#   in the starter's leathers, THE KNIGHT in the plate and helm.
	# - Synty's Sidekick (FREE Starter Pack; assets/tariel_sidekick/SOURCES.txt,
	#   tools/sk_build.py): THE PALADIN and THE HOODED as Synty made them, THE
	#   SWORN bareheaded and bearded in the knight's plate, THE IRON KNIGHT in
	#   the plate in steel and blue.
	# - Polysplit's Low-Poly Medieval Fantasy Heroes (Basic Pack;
	#   assets/polysplit/SOURCES.txt, tools/ps_creator.py): YOUR OWN, made
	#   on the hero select out of every part of the pack ([PolysplitLook];
	#   `_add_maker()` puts it last). It took THE SWORDSMAN's place, the one
	#   look of the pack he wore before.
	faces = [&"box", &"ashen", &"fuse", &"squire", &"knight", &"paladin", &"hooded", &"sworn", &"iron"]
	face_skulls = faces.duplicate()
	face_names = ["AS HE WAS", "THE WANDERER", "THE IRON HELM", "THE SQUIRE", "THE KNIGHT",
			"THE PALADIN", "THE HOODED", "THE SWORN", "THE IRON KNIGHT"]
	polysplit_hero = &"tariel"
	# (THE DARK KNIGHT left him: the knight is THE WARRIOR now, a hero of his
	# own on his own skeleton, SkinnedWarriorRig.)
	var on_figures: Array[StringName] = [&"squire", &"knight", &"paladin", &"hooded", &"sworn", &"iron"]
	whole_faces = [&"ashen", &"fuse"]
	whole_faces.append_array(on_figures)
	shieldless_faces = [&"fuse"]
	shieldless_faces.append_array(on_figures)
	own_sword_faces = shieldless_faces.duplicate()
	figures = {
		&"blink": {"scene": "res://assets/tariel_blink/tariel_blink.glb", "prefix": "blink", "hips": &"Root_M",
			"map": {
				&"Root_M": &"pelvis", &"Spine1_M": &"spine_01", &"Chest_M": &"spine_02",
				&"Neck_M": &"neck_01", &"Head_M": &"head",
				&"Scapula_R": &"clavicle_r", &"Shoulder_R": &"upperarm_r", &"Elbow_R": &"lowerarm_r",
				&"Wrist_R": &"hand_r", &"weapon_r": &"weapon_r",
				&"Scapula_L": &"clavicle_l", &"Shoulder_L": &"upperarm_l", &"Elbow_L": &"lowerarm_l",
				&"Wrist_L": &"hand_l", &"shield_l": &"shield_l",
				&"Hip_R": &"thigh_r", &"Knee_R": &"calf_r", &"Ankle_R": &"foot_r", &"Toes_R": &"ball_r",
				&"Hip_L": &"thigh_l", &"Knee_L": &"calf_l", &"Ankle_L": &"foot_l", &"Toes_L": &"ball_l",
			}},
		# Sidekick's bones are the mannequin's, as this rig's are; its third
		# spine bone is this rig's second, the second rides the first.
		&"sidekick": {"scene": "res://assets/tariel_sidekick/tariel_sidekick.glb", "prefix": "sk", "hips": &"pelvis",
			"map": {
				&"pelvis": &"pelvis", &"spine_01": &"spine_01", &"spine_03": &"spine_02",
				&"neck_01": &"neck_01", &"head": &"head",
				&"clavicle_r": &"clavicle_r", &"upperarm_r": &"upperarm_r", &"lowerarm_r": &"lowerarm_r",
				&"hand_r": &"hand_r", &"weapon_r": &"weapon_r",
				&"clavicle_l": &"clavicle_l", &"upperarm_l": &"upperarm_l", &"lowerarm_l": &"lowerarm_l",
				&"hand_l": &"hand_l", &"shield_l": &"shield_l",
				&"thigh_r": &"thigh_r", &"calf_r": &"calf_r", &"foot_r": &"foot_r", &"ball_r": &"ball_r",
				&"thigh_l": &"thigh_l", &"calf_l": &"calf_l", &"foot_l": &"foot_l", &"ball_l": &"ball_l",
			}},
	}
	figure_faces = {
		&"squire": {"figure": &"blink", "show": ["body_", "starter_"], "hide": ["body_underwear"]},
		&"knight": {"figure": &"blink", "show": ["body_", "plate_"], "hide": ["body_underwear", "body_hair"]},
		&"paladin": {"figure": &"sidekick", "show": ["paladin"]},
		&"hooded": {"figure": &"sidekick", "show": ["hooded"]},
		&"sworn": {"figure": &"sidekick", "show": ["sworn"]},
		&"iron": {"figure": &"sidekick", "show": ["iron"]},
	}
	# The wanderer wears a cloak of plain brown wool under his capelet, hung
	# from the back of the shoulders to the calf: real cloth, in the wind.
	whole_capes = {&"ashen": [{"base": Color("6b4a33"), "hem": Color("7d5b3f"), "trim": Color("3a2a1c"),
			"pattern": "plain", "left": [0.23, 0.13, 1.56], "right": [-0.23, 0.13, 1.56], "length": 1.0,
			"spread": 1.3, "cols": 9, "rows": 13,
			# kept off his broader build: the back and the capelet over it, the
			# breeches, the boots, the arms swinging back
			"colliders": [["pelvis", "neck_01", 0.21], ["spine_01", "spine_02", 0.235], ["spine_02", "neck_01", 0.2],
					["thigh_l", "calf_l", 0.15], ["thigh_r", "calf_r", 0.15], ["calf_l", "foot_l", 0.12],
					["calf_r", "foot_r", 0.12], ["upperarm_l", "lowerarm_l", 0.1], ["upperarm_r", "lowerarm_r", 0.1],
					["lowerarm_l", "hand_l", 0.08], ["lowerarm_r", "hand_r", 0.08]]}]}
	capes = [{
		"bone": "spine_02", "left": [0.21, 0.15, 1.6], "right": [-0.21, 0.15, 1.6],
		"length": 1.15, "spread": 1.35, "flare": 0.12, "wrap": 0.13, "cols": 7, "rows": 11,
		"base": Color.html("d98a2b"), "hem": Color.html("f2c27a"), "trim": Color.html("1b1310"),
		"pattern": "tiger", "hold": 0.5, "wind": 1.0, "drag": 0.6,
		"colliders": [["pelvis", "neck_01", 0.17], ["thigh_l", "calf_l", 0.11], ["thigh_r", "calf_r", 0.11],
				["calf_l", "foot_l", 0.09], ["calf_r", "foot_r", 0.09]],
	}]


#region Tariel's colours
## What Tariel can wear: each a set of colours for the model's materials (by
## their names in the model, in Blender's linear values) and for his cape (as
## seen). Kept here rather than baked into the model so they can be tried in
## the game — F9 steps through them — and cost nothing: the same meshes, the
## same number of materials. The first is the model as it was made.
const TARIEL_WARDROBE := {
	&"crimson": {"name": "crimson and gold (as made)", "mats": {},
		"cape": {"base": Color("d98a2b"), "hem": Color("f2c27a"), "trim": Color("1b1310"), "pattern": "tiger"}},
	&"panther": {"name": "panther: oxblood, tawny skin, old bronze",
		"mats": {"t6_crimson": Color(0.2, 0.035, 0.03), "t6_tiger": Color(0.30, 0.18, 0.07),
			"t6_tiger2": Color(0.38, 0.26, 0.12), "t6_stripe": Color(0.05, 0.035, 0.025),
			"t6_gold": Color(0.34, 0.22, 0.09), "brass_gold": Color(0.34, 0.22, 0.09),
			"t6_steel": Color(0.36, 0.37, 0.38), "t6_steel2": Color(0.18, 0.19, 0.2),
			"steel": Color(0.33, 0.34, 0.35), "t6_ruby": Color(0.25, 0.03, 0.03),
			"t6_tigereye": Color(0.45, 0.32, 0.05), "tower_crimson": Color(0.2, 0.035, 0.03)},
		"cape": {"base": Color("a8793f"), "hem": Color("d2b37c"), "trim": Color("2a1d14"), "pattern": "tiger"}},
	&"black": {"name": "black and steel, dark amber skin",
		"mats": {"t6_crimson": Color(0.045, 0.045, 0.05), "t6_tiger": Color(0.24, 0.14, 0.05),
			"t6_tiger2": Color(0.3, 0.21, 0.1), "t6_stripe": Color(0.02, 0.015, 0.01),
			"t6_gold": Color(0.3, 0.25, 0.15), "brass_gold": Color(0.3, 0.25, 0.15),
			"t6_steel": Color(0.5, 0.52, 0.55), "t6_steel2": Color(0.22, 0.23, 0.25),
			"t6_ruby": Color(0.3, 0.02, 0.02), "t6_leather": Color(0.07, 0.035, 0.02),
			"tower_crimson": Color(0.05, 0.05, 0.055)},
		"cape": {"base": Color("7d5a2e"), "hem": Color("a88c5c"), "trim": Color("141110"), "pattern": "tiger"}},
	&"indigo": {"name": "indigo, tawny skin, muted gold",
		"mats": {"t6_crimson": Color(0.04, 0.06, 0.14), "t6_tiger": Color(0.30, 0.18, 0.07),
			"t6_tiger2": Color(0.38, 0.26, 0.12), "t6_stripe": Color(0.05, 0.035, 0.025),
			"t6_gold": Color(0.4, 0.3, 0.12), "brass_gold": Color(0.4, 0.3, 0.12),
			"t6_steel": Color(0.42, 0.44, 0.47), "t6_steel2": Color(0.2, 0.21, 0.24),
			"t6_ruby": Color(0.1, 0.15, 0.35), "tower_crimson": Color(0.05, 0.07, 0.15)},
		"cape": {"base": Color("ad8246"), "hem": Color("d8bd86"), "trim": Color("22170f"), "pattern": "tiger"}},
	&"hunter": {"name": "hunter: olive and leather, like Avtandil",
		"mats": {"t6_crimson": Color(0.09, 0.12, 0.05), "t6_tiger": Color(0.30, 0.18, 0.07),
			"t6_tiger2": Color(0.38, 0.26, 0.12), "t6_stripe": Color(0.05, 0.035, 0.025),
			"t6_gold": Color(0.33, 0.22, 0.1), "brass_gold": Color(0.33, 0.22, 0.1),
			"t6_steel": Color(0.34, 0.35, 0.35), "t6_steel2": Color(0.16, 0.17, 0.17),
			"steel": Color(0.33, 0.34, 0.35), "t6_ruby": Color(0.2, 0.3, 0.1),
			"t6_leather": Color(0.12, 0.055, 0.022), "tower_crimson": Color(0.12, 0.08, 0.04)},
		"cape": {"base": Color("a67a44"), "hem": Color("cfb07a"), "trim": Color("241a12"), "pattern": "tiger"}},
## Tariel v8's cloth in colours dark but not black (the t8 materials), each
## with a plain cape to match; and the cape short, and none.
	&"oxblood": {"name": "oxblood: dark wine-red cloth, a plain cape to match",
		"mats": {"t8_cloth": Color(0.107, 0.016, 0.0176), "t8_cloth2": Color(0.0437, 0.0075, 0.0086), "t8_coat2": Color(0.0437, 0.0075, 0.0086)},
		"cape": {"base": Color("4f1c1e"), "hem": Color("a07f47"), "trim": Color("241012"), "pattern": "plain"}},
	&"navy": {"name": "navy: deep blue cloth, a plain cape to match",
		"mats": {"t8_cloth": Color(0.0185, 0.0319, 0.0782), "t8_cloth2": Color(0.0086, 0.0144, 0.0423), "t8_coat2": Color(0.0086, 0.0144, 0.0423)},
		"cape": {"base": Color("202b45"), "hem": Color("a07f47"), "trim": Color("10141f"), "pattern": "plain"}},
	&"umber": {"name": "umber: dark brown wool, a plain cape to match",
		"mats": {"t8_cloth": Color(0.1046, 0.0545, 0.0296), "t8_cloth2": Color(0.0452, 0.0242, 0.0137), "t8_coat2": Color(0.0452, 0.0242, 0.0137)},
		"cape": {"base": Color("4e3828"), "hem": Color("a07f47"), "trim": Color("1c140e"), "pattern": "plain"}},
	&"slate": {"name": "slate: blue-grey cloth, a plain cape to match",
		"mats": {"t8_cloth": Color(0.0497, 0.0612, 0.0908), "t8_cloth2": Color(0.0222, 0.0284, 0.0423), "t8_coat2": Color(0.0222, 0.0284, 0.0423)},
		"cape": {"base": Color("363c49"), "hem": Color("a07f47"), "trim": Color("15181e"), "pattern": "plain"}},
	&"plum": {"name": "plum: dark violet cloth, a plain cape to match",
		"mats": {"t8_cloth": Color(0.0685, 0.0232, 0.0595), "t8_cloth2": Color(0.0284, 0.0103, 0.0252), "t8_coat2": Color(0.0284, 0.0103, 0.0252)},
		"cape": {"base": Color("3f243b"), "hem": Color("a07f47"), "trim": Color("1a0f18"), "pattern": "plain"}},
	&"oxblood_short": {"name": "oxblood, the cape short: to the waist",
		"mats": {"t8_cloth": Color(0.107, 0.016, 0.0176), "t8_cloth2": Color(0.0437, 0.0075, 0.0086), "t8_coat2": Color(0.0437, 0.0075, 0.0086)},
		"cape": {"base": Color("4f1c1e"), "hem": Color("a07f47"), "trim": Color("241012"), "pattern": "plain", "length": 0.62, "spread": 1.2}},
	&"oxblood_bare": {"name": "oxblood, no cape",
		"mats": {"t8_cloth": Color(0.107, 0.016, 0.0176), "t8_cloth2": Color(0.0437, 0.0075, 0.0086), "t8_coat2": Color(0.0437, 0.0075, 0.0086)},
		"cape": {"base": Color("4f1c1e"), "hem": Color("a07f47"), "trim": Color("241012"), "pattern": "plain", "off": true}},
}
## Which of the wardrobe Tariel wears, for every Tariel in this game.
static var dress: StringName = &"black"
## This rig's wardrobe; empty for a hero that has none (set by `_configure()`).
var wardrobe: Dictionary = {}
var _dress_on: StringName = &""
## Whether the capes hang as a dress reshaped them (longer, shorter, off).
var _capes_reshaped: bool = false
var _dress_label: Label


## Puts on `dress` (if this rig has a wardrobe and it is not already on): each
## surface whose material is named in it gets a copy in the new colour; the
## rest, and anything the last dress changed that this one does not, go back
## to the model's own.
func _put_on_dress() -> void:
	if wardrobe.is_empty() or not wardrobe.has(dress) or _dress_on == dress:
		return
	_dress_on = dress
	var outfit: Dictionary = wardrobe[dress]
	var mats: Dictionary = outfit.get("mats", {})
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for i in mesh_node.mesh.get_surface_count():
			var own := mesh_node.mesh.surface_get_material(i)
			if own == null:
				continue
			if not mats.has(own.resource_name):
				mesh_node.set_surface_override_material(i, null)
				continue
			var copy := own.duplicate() as BaseMaterial3D
			if copy == null:
				continue
			# The model's colours are Blender's, linear; the material's are as seen.
			copy.albedo_color = (mats[own.resource_name] as Color).linear_to_srgb()
			mesh_node.set_surface_override_material(i, copy)
	var cape_look: Dictionary = outfit.get("cape", {})
	if cape_look.has("off") or cape_look.has("length") or _capes_reshaped:
		_rehang_capes(cape_look)
	else:
		for cape in cloth_capes:
			cape.recolour(cape_look)


## Takes the capes down and hangs them again with `look` laid over each one's
## spec — for a dress that makes the cape longer or shorter, or leaves it off.
func _rehang_capes(look: Dictionary) -> void:
	for cape in cloth_capes:
		cape.queue_free()
	cloth_capes.clear()
	_capes_reshaped = look.has("off") or look.has("length")
	if look.get("off", false):
		return
	for base in capes:
		var spec := (base as Dictionary).duplicate()
		for key in look:
			spec[key] = look[key]
		var cape := ClothCape.new()
		add_child(cape)
		if cape.setup(_skel, spec):
			cloth_capes.append(cape)
		else:
			cape.queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F9 or wardrobe.is_empty():
		return
	if _body != null and not _body.is_multiplayer_authority():
		return
	var names := wardrobe.keys()
	dress = names[(names.find(dress) + 1) % names.size()]
	_put_on_dress()
	_say_dress()


## Says which dress is on, for a moment, at the top of the screen.
func _say_dress() -> void:
	if _dress_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_dress_label = Label.new()
		_dress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_dress_label.position.y = 92.0
		_dress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dress_label.add_theme_font_size_override("font_size", 22)
		_dress_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_dress_label.add_theme_constant_override("outline_size", 6)
		layer.add_child(_dress_label)
	var names := wardrobe.keys()
	_dress_label.text = "Tariel %d/%d: %s" % [names.find(dress) + 1, names.size(), wardrobe[dress]["name"]]
	_dress_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dress_label.visible = true
	var shown := _dress_label.text
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(_dress_label) and _dress_label.text == shown:
			_dress_label.visible = false)
#endregion


## The cloth capes, each on its own node that draws itself in world space.
func _setup_capes() -> void:
	for spec in capes:
		var cape := ClothCape.new()
		cape.name = "Cape%d" % cloth_capes.size()
		add_child(cape)
		if cape.setup(_skel, spec):
			cloth_capes.append(cape)
		else:
			cape.queue_free()


## Markers for the blade's base and tip on the weapon socket, so the swing trail
## and `get_cutting_edge()` have a segment to read. The blade's direction in the
## socket is read off the rest pose (it points forward, +Z, in the T-pose) rather
## than assumed, so it does not matter which axis the exporter left the bone on.
func _setup_blade() -> void:
	var bone := _skel.find_bone("weapon_r")
	if bone < 0:
		return
	var mount := BoneAttachment3D.new()
	mount.name = "WeaponMount"
	_skel.add_child(mount)
	mount.bone_name = "weapon_r"
	var along := (_skel.get_bone_global_rest(bone).basis.inverse() * blade_rest_dir).normalized()
	_blade_base = Marker3D.new()
	_blade_base.name = "blade_base"
	_blade_base.position = along * blade_base
	mount.add_child(_blade_base)
	_blade_tip = Marker3D.new()
	_blade_tip.name = "blade_tip"
	_blade_tip.position = along * blade_tip
	mount.add_child(_blade_tip)
	_sword_mount = mount
	_arc = BladeArc.new()
	_arc.name = "BladeArc"
	add_child(_arc)
	_arc.setup(_blade_base, _blade_tip)
	for key: String in arc_style:
		_arc.set(key, arc_style[key])
	_arc.restyle()
	_arc_base = {"life": _arc.life, "intensity": _arc.intensity, "sheet": _arc.sheet}
	var left := _skel.find_bone("weapon_l")
	if off_hand_blade and left >= 0:
		var mount_l := BoneAttachment3D.new()
		mount_l.name = "WeaponMountL"
		_skel.add_child(mount_l)
		mount_l.bone_name = "weapon_l"
		var along_l := (_skel.get_bone_global_rest(left).basis.inverse() * blade_rest_dir).normalized()
		var base_l := Marker3D.new()
		base_l.position = along_l * blade_base
		mount_l.add_child(base_l)
		var tip_l := Marker3D.new()
		tip_l.position = along_l * blade_tip
		mount_l.add_child(tip_l)
		_blade_base_l = base_l
		_blade_tip_l = tip_l
		_arc_l = BladeArc.new()
		_arc_l.name = "BladeArcL"
		add_child(_arc_l)
		_arc_l.setup(base_l, tip_l)
		for key: String in arc_style:
			_arc_l.set(key, arc_style[key])
		_arc_l.restyle()


## Spring bones for the cape (`cape_00`..`cape_06`) and the ponytail
## (`hair_00`..`hair_04`), and the capsules that keep the cape out of the legs
## and the body. The clips leave both chains at rest; this runs after them.
func _setup_cloth() -> void:
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Cloth"
	var chains := [
		[&"cape_00", &"cape_06", cape_stiffness, cape_drag, cape_gravity, cape_radius],
		[&"hair_00", &"hair_04", hair_stiffness, hair_drag, hair_gravity, 0.03],
	]
	var usable: Array = []
	for c in chains:
		if c[0] == &"cape_00" and not capes.is_empty():
			continue
		if _skel.find_bone(c[0]) >= 0 and _skel.find_bone(c[1]) >= 0:
			usable.append(c)
	if usable.is_empty():
		return
	_skel.add_child(sim)
	sim.set_setting_count(usable.size())
	for i in usable.size():
		var c: Array = usable[i]
		sim.set_root_bone_name(i, c[0])
		sim.set_end_bone_name(i, c[1])
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_length(i, 0.12)
		sim.set_stiffness(i, c[2])
		sim.set_drag(i, c[3])
		sim.set_gravity(i, c[4])
		sim.set_radius(i, c[5])
	# Capsules along the legs, the hips and the back: bone, radius, length.
	for spec in [[&"thigh_l", 0.1, 0.44], [&"thigh_r", 0.1, 0.44], [&"calf_l", 0.08, 0.42],
			[&"calf_r", 0.08, 0.42], [&"pelvis", 0.17, 0.3], [&"spine_01", 0.17, 0.25],
			[&"spine_02", 0.17, 0.28], [&"head", 0.13, 0.22]]:
		if _skel.find_bone(spec[0]) < 0:
			continue
		var cap := SpringBoneCollisionCapsule3D.new()
		cap.name = "Col_%s" % spec[0]
		sim.add_child(cap)
		cap.set_bone_name(spec[0])
		cap.set_radius(spec[1])
		cap.set_height(spec[2] + spec[1] * 2.0)
		# Capsules run along their own Y, as bones do; centred halfway down it.
		cap.set_position_offset(Vector3(0.0, spec[2] * 0.5, 0.0))
	sim.set_enable_all_child_collisions(0, true)
	if usable.size() > 1:
		sim.set_enable_all_child_collisions(1, true)


func animate(delta: float, planar_speed: float, _speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	if _anim == null:
		return
	_airborne_now = airborne
	_blocking_now = blocking
	_hold_stop(delta)
	_tick_drag(delta)
	_sheath_tick(delta)
	_plunge_left = maxf(_plunge_left - delta, 0.0)
	_swing_commit = maxf(_swing_commit - delta, 0.0)

	if _role != Role.NONE:
		_action_left -= delta
		var through := _progress()
		if _hold_at > 0.0 and _role == Role.SWING:
			# The running cut wound up: held at its `hold` till it is let go.
			if not _holding and through >= _hold_at:
				_holding = true
				# frozen there, or (a spec's `creep`) coming on slowly, as a
				# spell is cast, no further than its `creep_until`
				_anim.speed_scale = _action_rate * _hold_creep
			if _holding and _hold_creep > 0.0 and through >= _hold_until:
				_anim.speed_scale = 0.0
			_action_left = maxf(_action_left, 0.2)
		_attack_cutting = (_role == Role.SWING or _role == Role.PLUNGE or (_role == Role.ROLL and _evade_cut)) \
				and _in_window(through)
		if _attack_cutting:
			_strike_world()
		if _role == Role.SWING and _heavy_now and not _slam_done:
			var slam := _slam_share()
			if slam > 0.0 and through >= slam:
				_slam_done = true
				var at := global_position
				if _blade_tip != null:
					at = _blade_tip.global_position
					at.y = global_position.y
				slammed.emit(at, cut_weight)
		# A swing that has done its work gives the body back as soon as the
		# player moves off; standing still, it plays out its follow-through.
		# (and a clip that only brings him back, as soon as he moves off)
		var released := ((_role == Role.SWING and not _air_cut and _swing_commit <= 0.0)
				or (_role == Role.FREE and _recovering)
				or (_role == Role.ROLL and _evade_cut and not dashing)) and planar_speed > idle_threshold
		if _role == Role.DOWN:
			pass  # held until get_up() or leave_ground()
		elif _air_cut and _action_left <= 0.0 and airborne:
			_anim.speed_scale = 0.0  # the chop, held until the ground arrives
		elif _action_left <= 0.0 or released:
			# A blow of the picked moves with a recovery of its own (UAL 2's
			# "_Rec"): played after it, if nothing follows and he stands.
			var after: StringName = &""
			if _on_mq and _role == Role.SWING and not released and not _heavy_now:
				after = (moves.get("recover", {}) as Dictionary).get(_act_clip, &"")
			_end_action()
			if after != &"" and planar_speed <= idle_threshold and not airborne and _anim.has_animation(after):
				_play_action(after, Role.FREE, 1.15, 0.08)
				_recovering = true
	else:
		_attack_cutting = false
	# A clip whose own travel carries him: what its root moved by last frame,
	# as a pace over the ground.
	_carrying = _role == Role.SWING and carried.has(_act_clip)
	if _carrying:
		var moved := _skel.global_basis * _anim.get_root_motion_position()
		moved.y = 0.0
		carry_velocity = moved / maxf(delta, 0.001) * carry_scale
	else:
		carry_velocity = Vector3.ZERO
	var trailing := _attack_cutting or _in_trail()
	for arc: BladeArc in [_arc, _arc_l]:
		if arc == null:
			continue
		arc.emitting = trailing and (arc == _arc or ((not off_hand_whole_only or wearing_whole()) and _off_hand_on))
		if trailing and arc_heavy_boost != 1.0 and not _arc_base.is_empty():
			var boost := arc_heavy_boost if cut_weight > 1.2 else 1.0
			arc.intensity = float(_arc_base["intensity"]) * boost
			arc.life = float(_arc_base["life"]) * (1.0 + (boost - 1.0) * 0.8)
			arc.sheet = minf(float(_arc_base["sheet"]) * boost, 1.0)
			arc.restyle()

	if _on_mq:
		_mq_tick(delta, planar_speed, airborne, vertical_speed, blocking)
	if _role == Role.NONE:
		_pick_base(planar_speed, airborne, dashing, vertical_speed, blocking)
	_update_stride(delta, planar_speed, airborne)
	_update_strike(delta)


## Where the cut in hand is aimed (set by the controller every frame of a swing
## at something; `on` false when there is nothing to aim it at).
func aim_strike(at: Vector3, on: bool) -> void:
	_strike_on = on
	if on:
		_strike_at = at


func _update_strike(delta: float) -> void:
	if _strike == null:
		return
	# Not bent to the target through a cut of the string that turns him right
	# round (the spin): the waist pulled back towards the target all through
	# the turn is a man wringing himself.
	var spinning := not _heavy_now and carried.has(_act_clip)
	var want := _strike_on and _role == Role.SWING and not _air_cut and (not _heavy_now or _heavy_aim) and not spinning
	# In fast, as the swing starts; out more slowly as it gives the body back.
	_strike.weight = move_toward(_strike.weight, 1.0 if want else 0.0, delta / (0.07 if want else 0.2))
	_strike.natural = float(strike_heights.get(_act_clip, strike_natural))
	if want:
		_strike.target = _strike_at if _strike.weight < 0.02 else _strike.target.lerp(_strike_at, 1.0 - exp(-18.0 * delta))


func get_cutting_edge() -> PackedVector3Array:
	var edge := super()
	if edge.is_empty() or (strike_reach <= 0.0 and strike_pull <= 0.0):
		return edge
	var along := edge[1] - edge[0]
	if along.length_squared() > 0.0001:
		edge[1] += along.normalized() * strike_reach
	if _strike_on and strike_pull > 0.0:
		var near := Geometry3D.get_closest_point_to_segment(_strike_at, edge[0], edge[1])
		var dy := clampf(_strike_at.y - near.y, -strike_pull, 0.0)
		edge[0].y += dy
		edge[1].y += dy
	return edge

## Running legs under a swing thrown on the move: the cycle that fits the way
## the body is going, carried on from the phase the run was at, faded in over
## `stride_blend` and back out when the swing ends or the body stops.
func _update_stride(delta: float, planar: float, airborne: bool) -> void:
	if _stride == null:
		return
	# A blow whose own clip carries him (a spin, a leap) has its own feet: a run
	# laid under a body turning round on them is a man running on the spot.
	# (and on the mannequin, under the guard held up: the picked block is a
	# standing one, the legs walk under it)
	var under := (swing_strides and _role == Role.SWING and not _air_cut and not carried.has(_act_clip)) \
			or (_role == Role.FREE and walk_under) or (_on_mq and _role == Role.NONE and _blocking_now)
	# Only under a swing that is really going somewhere: at a swing's own pace
	# (a man stepping into his cut) the clip's feet are his, and a walk laid
	# under them is legs shuffling on the spot under a body that is cutting.
	var least := idle_threshold if _role != Role.SWING else maxf(idle_threshold, swing_stride_from)
	var want := under and not airborne and planar > least
	if want:
		var clip := _direction_clip(planar)
		if _anim.has_animation(clip):
			if clip != _stride_clip:
				# Same foot forward in the new cycle: keep the phase as a share.
				var from_len := _stride.cycle.length if _stride.cycle != null else 1.0
				var share := fposmod(_stride_time, maxf(from_len, 0.01)) / maxf(from_len, 0.01)
				_stride_clip = clip
				_stride.cycle = _anim.get_animation(clip)
				_stride_time = share * _stride.cycle.length
			_stride_time += delta * _rate(clip, planar)
			_stride.time = _stride_time
		else:
			want = false
	_stride.weight = move_toward(_stride.weight, 1.0 if want else 0.0,
			delta / maxf(stride_blend, 0.01))
	# the sword put away or drawn on the run: only the sword arm is the clip's
	_stride.upper = _sheath_play != &"" and _role == Role.FREE and _act_clip == _sheath_play


func _pick_base(planar: float, airborne: bool, _dashing: bool, _vy: float, blocking: bool) -> void:
	if _on_mq and _mq_base(planar, airborne, blocking):
		return
	if airborne:
		_set_base(clips[&"air"], loco_blend, 0.8)
		return
	if blocking:
		if planar < idle_threshold:
			var guard: StringName = clips[&"block_idle"]
			if shield_kind == 1 and clips.has(&"tower_block") and _anim.has_animation(clips[&"tower_block"]):
				guard = clips[&"tower_block"]
			_set_base(guard, 0.12, 1.0)
		else:
			# Legs from the walk, the guard held up over them (baked in Blender).
			var bclip := _block_walk_clip()
			var brate := clampf(planar / float(ground_speed.get(bclip, 1.4)), min_play_rate, max_play_rate)
			_set_base(bclip, 0.15, brate)
		return
	if _crouching or _wall_climbing:
		if _sliding or _wall_climbing or planar < idle_threshold or not clips.has(&"crouch_walk"):
			# A slide is carried, not walked: the crouched pose held while the
			# body goes along the ground.
			_set_base(clips[&"crouch"], loco_blend, 1.0)
		else:
			var cclip := _dir4(&"crouch_walk", &"crouch_walk_back", &"crouch_walk_left", &"crouch_walk_right")
			_set_base(cclip, loco_blend, _rate(cclip, planar))
		return
	if planar < idle_threshold:
		_set_base(clips[&"idle"], loco_blend, 1.0)
		return
	var clip := _direction_clip(planar)
	var rate := clampf(planar / float(ground_speed.get(clip, 1.4)), min_play_rate, max_play_rate)
	_set_base(clip, loco_blend, rate)


## Which cycle fits the way the body is actually travelling relative to where it
## faces — forwards, backwards, or sideways while locked on to something.
func _direction_clip(planar: float) -> StringName:
	var run := planar > run_threshold
	var body := _body as CharacterBody3D
	if body == null:
		return clips[&"run"] if run else clips[&"walk"]
	var local := body.global_transform.basis.inverse() * body.velocity
	var fwd := -local.z
	var side := local.x
	if absf(side) > absf(fwd) * 1.2:
		if side > 0.0:
			return clips[&"run_right"] if run else clips[&"walk_right"]
		return clips[&"run_left"] if run else clips[&"walk_left"]
	if fwd < 0.0:
		return clips[&"run_back"] if run else clips[&"walk_back"]
	# the picked sprint only past his own run (the controller has no sprint of
	# its own: at his run's pace Kevin's sprint was his run, legs flung wide)
	if _on_mq and run and clips.has(&"sprint") and _body != null and _body.get(&"run_speed") != null \
			and planar > float(_body.get(&"run_speed")) * 1.1:
		return clips[&"sprint"]
	return clips[&"run"] if run else clips[&"walk"]


func _block_walk_clip() -> StringName:
	var body := _body as CharacterBody3D
	if body == null:
		return clips[&"block_walk"]
	var local := body.global_transform.basis.inverse() * body.velocity
	if absf(local.x) > absf(local.z) * 1.2:
		return clips[&"block_walk_right"] if local.x > 0.0 else clips[&"block_walk_left"]
	return clips[&"block_walk_back"] if local.z > 0.0 else clips[&"block_walk"]


func _dir4(fwd: StringName, back: StringName, left: StringName, right: StringName) -> StringName:
	var body := _body as CharacterBody3D
	if body == null:
		return clips[fwd]
	var local := body.global_transform.basis.inverse() * body.velocity
	if absf(local.x) > absf(local.z) * 1.2:
		return clips[right] if local.x > 0.0 else clips[left]
	return clips[back] if local.z > 0.0 else clips[fwd]


func _rate(clip: StringName, planar: float) -> float:
	return clampf(planar / float(ground_speed.get(clip, 1.4)), min_play_rate, max_play_rate)


func _set_base(clip: StringName, blend: float, rate: float) -> void:
	if not _anim.has_animation(clip):
		return
	if clip != _base_clip or _anim.current_animation != clip:
		_base_clip = clip
		_anim.play(clip, blend)
	_anim.speed_scale = rate


func _play_action(clip: StringName, role: Role, rate: float = 1.0, blend: float = -1.0,
		from: float = 0.0, until: float = 1.0) -> bool:
	if not _anim.has_animation(clip):
		return false
	var length := _anim.get_animation(clip).length
	# A drag left over from a missed cut is not this clip's, nor a held cut.
	_drag_left = 0.0
	_hold_at = -1.0
	_holding = false
	_role = role
	_recovering = false
	_evade_cut = false
	_act_clip = clip
	_action_len = length
	_action_rate = maxf(rate, 0.01)
	_action_from = from
	_window_at = -1
	_action_left = length * (until - from) / _action_rate
	_base_clip = &""
	# Where the legs were in their cycle, for a stride carried on under the swing.
	var was := StringName(_anim.current_animation)
	if ground_speed.has(was) and _anim.has_animation(was):
		_stride_clip = was
		_stride_time = _anim.current_animation_position
		if _stride != null:
			_stride.cycle = _anim.get_animation(was)
	_anim.play(clip, action_blend if blend < 0.0 else blend)
	_anim.speed_scale = _action_rate
	if from > 0.0:
		_anim.seek(length * from, true)
	elif was == clip:
		# The same clip again — a roll straight after a roll: play() would carry
		# on from where it is, so start it over.
		_anim.seek(0.0, true)
	return true


func _end_action() -> void:
	_air_cut = false
	_evade_cut = false
	walk_under = false
	_recovering = false
	_role = Role.NONE
	_act_clip = &""
	_attack_cutting = false
	_base_clip = &""  # forces the next base pick to crossfade in


func _progress() -> float:
	if _action_len <= 0.0:
		return 1.0
	return clampf(_anim.current_animation_position / _action_len, 0.0, 1.0)


func _in_window(through: float) -> bool:
	var many: Array = cut_windows.get(_act_clip, [])
	if not many.is_empty():
		for i in many.size():
			var span: Vector2 = many[i]
			if through >= span.x - cut_margin and through <= span.y + cut_margin:
				if i != _window_at:
					if _window_at >= 0:
						# The next blow of the same clip: a new cut, which
						# whatever it lands on takes afresh.
						attack_serial += 1
						_whoosh_now()
					_window_at = i
				return true
		return false
	var w: Vector2 = cut_window.get(_act_clip, Vector2.ZERO)
	return w != Vector2.ZERO and through >= w.x - cut_margin and through <= w.y + cut_margin


## Inside the clip's `trail_window`: the arc is drawn though the blade may not
## be cutting yet (or any more).
func _in_trail() -> bool:
	if _holding:
		return false  # wound up and held: no blade moving yet
	if _role != Role.SWING and _role != Role.PLUNGE and not (_role == Role.ROLL and _evade_cut):
		return false
	var w: Vector2 = trail_window.get(_act_clip, Vector2.ZERO)
	if w == Vector2.ZERO:
		return false
	var p := _progress()
	return p >= w.x and p <= w.y


## The share of the heavy blow in hand at which its blade meets the ground
## (its spec's `slam`), or 0 if it has none.
func _slam_share() -> float:
	for h: Dictionary in heavy:
		if h["clip"] == _act_clip:
			return float(h.get("slam", 0.0))
	return 0.0


## Where in the flurry the last cut was, or -1 if the string has been left
## long enough to start again.
func flurry_position() -> int:
	if flurry_reset_after > 0.0 and Time.get_ticks_msec() / 1000.0 - _last_attack_at > flurry_reset_after:
		return -1
	return _flurry_slot


## A heavy blow is playing (not a cut of the flurry).
func is_heavy() -> bool:
	return _role == Role.SWING and _heavy_now


## The cut has done its work and only the follow-through is left: a light cut
## may be broken off here (by an evade), a heavy blow may not.
func in_recovery() -> bool:
	if _role != Role.SWING or _air_cut:
		return false
	if _heavy_now:
		# A heavy blow plays out — unless what is left of it is only getting
		# back up (its `rise`), which an evade may take him out of.
		for h: Dictionary in heavy:
			if h["clip"] == _act_clip and h.has("rise"):
				return _progress() > float(h["rise"])
		return false
	var w: Vector2 = cut_window.get(_act_clip, Vector2.ZERO)
	return w != Vector2.ZERO and _progress() > w.y + cut_margin


## Its travel is carrying him (see `carried`).
func carrying() -> bool:
	return _carrying


#region The rig's interface, as the controller calls it
func attack(style: int = -1) -> void:
	attack_serial += 1
	var clip: StringName
	if _airborne_now and _anim.has_animation(clips[&"plunge"]):
		# Off a jump: the jump attack's own raise and chop, held at the bottom
		# until the landing takes it on (see `plunge()`).
		_attack_style = AttackStyle.OVERHEAD
		if _play_action(clips[&"plunge"], Role.SWING, swing_rate, 0.08, air_cut_from, plunge_from):
			_air_cut = true
			_swing_commit = swing_time()
			_whoosh()
		return
	if _on_mq:
		_rouse()
	if CUT_SPECS.has(style) and has_cut(CUT_SPECS[style]):
		# The running cut: a sweep thrown out of the run, lunging; the string
		# goes on from its second blow after it (its spec's `string_at`). The
		# rising cut, the skill, is played the same way.
		var rc: Dictionary = moves[CUT_SPECS[style]]
		_attack_style = AttackStyle.SIDE
		_heavy_now = false
		cut_weight = float(rc.get("weight", 1.0))
		_last_attack_at = Time.get_ticks_msec() / 1000.0
		_flurry_slot = int(rc.get("string_at", 0))
		if _play_action(rc["clip"], Role.SWING, float(rc.get("rate", 1.0)) * mq_swing_scale, 0.06,
				0.0, float(rc.get("until", 1.0))):
			_hold_at = float(rc.get("hold", -1.0))
			_hold_creep = float(rc.get("creep", 0.0))
			_hold_until = float(rc.get("creep_until", _hold_at))
			if _hold_at > 0.0:
				# Wound up and held there while he runs in; the controller
				# lets it go ([method release_cut]).
				_swing_commit = 999.0
			else:
				_swing_commit = swing_time()
				_whoosh()
		return
	if style >= HEAVY and style - HEAVY < heavy.size():
		var h: Dictionary = heavy[style - HEAVY]
		if _on_mq:
			# the pick's "also" played at random in its place
			var others: Array = (moves.get("alts", {}) as Dictionary).get(StringName("heavy:%d" % (style - HEAVY)), [])
			var i := randi() % (others.size() + 1)
			if i > 0 and _anim.has_animation((others[i - 1] as Dictionary)["clip"]):
				h = others[i - 1]
		_attack_style = AttackStyle.THRUST
		# A heavy blow ends the string: the next click starts it again.
		_flurry_slot = -1
		_heavy_now = true
		_slam_done = false
		cut_weight = float(h.get("weight", 1.5))
		_heavy_aim = bool(h.get("aim", true))
		var hp: Vector2 = h.get("part", Vector2(0.0, 1.0))
		var h_rate := float(h.get("rate", swing_rate)) * (mq_swing_scale if _on_mq and h.has("rate") else 1.0)
		if _play_action(h["clip"], Role.SWING, h_rate, 0.08, hp.x, hp.y):
			_swing_commit = swing_time()
			_whoosh()
		return
	_heavy_now = false
	cut_weight = 1.0
	if style == AttackStyle.OVERHEAD:
		clip = clips[&"overhead"]
		_attack_style = AttackStyle.OVERHEAD
	else:
		_attack_style = AttackStyle.SIDE
		# A combo left alone for a while starts again from its first cut.
		var now := Time.get_ticks_msec() / 1000.0
		if flurry_reset_after > 0.0 and now - _last_attack_at > flurry_reset_after:
			_flurry_slot = -1
		if _on_mq and _strings.size() > 1 and (_flurry_slot < 0 or _flurry_slot >= flurry.size() - 1):
			# a new string: one of the picked ones, at random
			flurry.assign(_strings[randi() % _strings.size()])
			_flurry_slot = -1
		_last_attack_at = now
		_flurry_slot = (_flurry_slot + 1) % flurry.size()
		clip = flurry[_flurry_slot]
	var part: Vector2 = flurry_part.get(clip, Vector2(0.0, 1.0))
	var rate := swing_rate
	if _attack_style == AttackStyle.SIDE:
		rate *= 1.0 + flurry_quicken * maxi(_flurry_slot, 0)
		var last := _flurry_slot == flurry.size() - 1
		if last:
			cut_weight = finisher_weight
		var least := finisher_min_time if last else flurry_min_time
		if least > 0.0 and _anim.has_animation(clip):
			var span := _anim.get_animation(clip).length * (part.y - part.x)
			rate = minf(rate, span / least)
	if _play_action(clip, Role.SWING, rate, -1.0, part.x, part.y):
		_swing_commit = swing_time()
		_whoosh()


## The sword going through the air — every peer plays the swing, so every peer
## hears it.
##
## The sounds are short slashes now, so they are timed to the cut itself —
## where the clip's cut window opens — not to the start of the wind-up, where
## a short one was over before the blade moved and seemed not to play.
func _whoosh() -> void:
	var serial := attack_serial
	var clip := _act_clip
	var w: Vector2 = cut_window.get(_act_clip, Vector2.ZERO)
	var many: Array = cut_windows.get(_act_clip, [])
	if not many.is_empty():
		w = many[0]
	var lead := 0.0
	if w != Vector2.ZERO and _action_len > 0.0 and _action_rate > 0.0:
		# A touch before the window opens: a slash is heard as the blade comes.
		lead = maxf(_action_len * (w.x - _action_from) / _action_rate - 0.06, 0.0)
	if lead <= 0.01:
		_whoosh_now()
		return
	get_tree().create_timer(lead, false).timeout.connect(func() -> void:
		# Only if it is still that swing (not cut short by a hit or a roll).
		if is_inside_tree() and attack_serial == serial and _act_clip == clip:
			_whoosh_now())


func _whoosh_now() -> void:
	var at: Node3D = self
	if _sword_mount != null:
		at = _sword_mount
	if not heft_swings:
		Sfx.play_any(self, swing_sounds, at, swing_pitch, swing_volume)
		return
	var heft := swing_heft()
	match heft:
		&"heavy":
			Sfx.play_any(self, swing_sounds, at, swing_pitch * 0.84, swing_volume + 2.0)
			Sfx.play_any(self, AIR_DEEP, at, 0.95, swing_volume + 1.0)
		&"finisher":
			Sfx.play_any(self, swing_sounds, at, swing_pitch * 0.92, swing_volume + 1.0)
			Sfx.play_any(self, AIR_RUSH, at, 1.0, swing_volume - 4.0)
		&"second":
			Sfx.play_any(self, swing_sounds, at, swing_pitch * 0.98, swing_volume)
		_:
			Sfx.play_any(self, swing_sounds, at, swing_pitch * 1.07, swing_volume - 1.0)


## What the cut in hand is heard as: &"first" or &"second" of a string (and
## the light cuts, an evade's), &"finisher" (a string's last, the running
## cut, a thrust) or &"heavy" (a heavy blow, the skills' big cuts).
func swing_heft() -> StringName:
	if cut_weight >= HEFT_HEAVY or _heavy_now:
		return &"heavy"
	if cut_weight >= HEFT_FINISHER:
		return &"finisher"
	if _attack_style == AttackStyle.SIDE and _flurry_slot > 0 and _role == Role.SWING:
		return &"second"
	return &"first"


## The swing whose blade has already met the world (see [method _strike_world]).
var _world_struck := -1
var _tip_was := Vector3.ZERO
var _tip_was_serial := -1
## Set when a cut has run into the world: what it met and where, for a test.
var last_world_strike: Dictionary = {}


## A cut that runs into the world — a trunk, a wall, a rock, a fence — is heard
## where it does, once a swing, with a puff of grit: steel on stone, a knock in
## wood ([method ImpactFx.strike]). The ground under a low cut is not (a face
## that looks up), nor a body (those take the cut themselves).
func _strike_world() -> void:
	if _world_struck == attack_serial or _blade_base == null or _blade_tip == null or not is_inside_tree():
		return
	var from := _blade_base.global_position
	var to := _blade_tip.global_position
	var tip_was: Vector3 = _tip_was if _tip_was_serial == attack_serial else to
	_tip_was = to
	_tip_was_serial = attack_serial
	if from.distance_squared_to(to) < 0.01:
		return
	# along the blade, and along the way its tip went since the last tick (a
	# backhand starts with the blade already through the wall)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if hit.is_empty() and tip_was.distance_squared_to(to) > 0.0001:
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(tip_was, to, 1))
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var what := hit["collider"] as Node
	if normal.y > 0.6 or what == null or what is CharacterBody3D:
		return
	_world_struck = attack_serial
	var matter := ImpactFx.matter_of(what)
	if matter == &"flesh":
		matter = &"stone"
	var at: Vector3 = hit["position"]
	ImpactFx.strike(self, at, matter, cut_weight)
	DustRing.burst(Blood.world_of(self), at, 0.25)
	last_world_strike = {"matter": matter, "at": at, "serial": attack_serial, "what": String(what.name)}


## A running cut to throw ([Swordsman] `RUN_ATTACK`).
func has_run_cut() -> bool:
	return has_cut("run_attack")


## A cut of the moves' `key` spec ("run_attack", "rising_cut") to throw.
func has_cut(key: String) -> bool:
	return _on_mq and moves.has(key) and _anim != null \
			and _anim.has_animation((moves[key] as Dictionary)["clip"])


## The moves' `key` spec, or {}.
func cut_spec(key: String) -> Dictionary:
	return moves.get(key, {}) if _on_mq else {}


## The running cut's spec ([Swordsman] `RUN_ATTACK`), or {}.
func run_cut_spec() -> Dictionary:
	return moves.get("run_attack", {}) if _on_mq else {}


## Share of the clip the running cut is held wound up at (-1: none), and
## whether it has got there.
var _hold_at: float = -1.0
var _holding: bool = false
## Held coming on slowly (a share of its rate) up to a share of the clip.
var _hold_creep: float = 0.0
var _hold_until: float = -1.0


## A running cut wound up and held, not yet let go.
func holding_cut() -> bool:
	return _hold_at > 0.0 and _role == Role.SWING


## Lets the held cut go: on from where it is held at the clip's rate. Returns
## the seconds he is held for it (to its cut's end and `swing_recovery`).
func release_cut() -> float:
	if not holding_cut():
		return 0.0
	var at := maxf(_progress(), _hold_at)
	_hold_at = -1.0
	_holding = false
	if _stop_left <= 0.0:
		_anim.speed_scale = _action_rate
	_action_from = at
	_action_left = _action_len * (1.0 - at) / _action_rate
	var w: Vector2 = cut_window.get(_act_clip, Vector2(at, at))
	_swing_commit = _action_len * maxf(w.y - at, 0.0) / _action_rate + swing_recovery
	_whoosh()
	return _swing_commit


## Plays the blow in hand at whatever pace brings it to `share` of its clip
## in `seconds` (between half and two and a half times its own rate): a swing
## timed to land on something, as the end of a slide. Not while a bite holds it.
func pace_to(share: float, seconds: float) -> void:
	if _role != Role.SWING or _action_len <= 0.0 or _stop_left > 0.0 or holding_cut():
		return
	var left := maxf(share - _progress(), 0.0) * _action_len
	var speed := _action_rate
	if left > 0.0 and seconds > 0.0:
		speed = clampf(left / seconds, _action_rate * 0.5, _action_rate * 2.5)
	_anim.speed_scale = speed
	_action_left = _action_len * (1.0 - _progress()) / maxf(speed, 0.01)


## Back to the blow's own pace (after `pace_to`).
func pace_own() -> void:
	if _role != Role.SWING or _action_len <= 0.0 or _stop_left > 0.0 or holding_cut():
		return
	_anim.speed_scale = _action_rate
	_action_left = _action_len * (1.0 - _progress()) / maxf(_action_rate, 0.01)


## Seconds from now until the blow in hand starts cutting (0 if it is).
func time_to_cut() -> float:
	if _role != Role.SWING or _action_len <= 0.0:
		return 0.0
	var w: Vector2 = cut_window.get(_act_clip, Vector2.ZERO)
	return maxf(_action_len * (w.x - _progress()) / maxf(_action_rate, 0.01), 0.0)


## A charge to make behind the shield (the moves' "shield_bash" clip).
func can_shield_bash() -> bool:
	return _on_mq and _anim != null and clips.has(&"shield_bash") and _anim.has_animation(clips[&"shield_bash"])


## The charge behind the shield, played whole over `seconds`: the drive in,
## the shield thrown into what is there, and the standing back up.
func shield_bash(seconds: float) -> void:
	if not can_shield_bash():
		return
	_rouse()
	var clip: StringName = clips[&"shield_bash"]
	var length := _anim.get_animation(clip).length
	_heavy_now = false
	cut_weight = 1.0
	_play_action(clip, Role.FREE, clampf(length / maxf(seconds, 0.1), 0.6, 2.0), 0.05)


## Seconds left of a missed cut's dragged follow-through, and the share of
## its pace it drags at.
var _drag_left: float = 0.0
var _drag_rate: float = 1.0


## The cut went through nothing: what is left of it drags (played at `slow`
## until `seconds` have been lost), and it gives the body back that much
## later.
func overreach(seconds: float, slow: float) -> void:
	if _role != Role.SWING or _anim == null or seconds <= 0.0 or _drag_left > 0.0:
		return
	slow = clampf(slow, 0.1, 0.95)
	_drag_rate = slow
	_drag_left = seconds / (1.0 - slow)
	_swing_commit += seconds
	_action_left += seconds
	_action_rate *= slow
	_anim.speed_scale *= slow


func _tick_drag(delta: float) -> void:
	if _drag_left <= 0.0:
		return
	_drag_left -= delta
	if _drag_left <= 0.0 or _role != Role.SWING:
		_drag_left = 0.0
		if _role == Role.SWING and _stop_left <= 0.0:
			_action_rate /= _drag_rate
			_anim.speed_scale /= _drag_rate


## Being missed: dragging (see `overreach`).
func dragging() -> bool:
	return _drag_left > 0.0


func swing_time() -> float:
	if _role != Role.SWING or _action_len <= 0.0:
		return attack_duration
	var w: Vector2 = cut_window.get(_act_clip, Vector2(0.5, 0.5))
	var many: Array = cut_windows.get(_act_clip, [])
	if not many.is_empty():
		w = Vector2((many[0] as Vector2).x, (many[many.size() - 1] as Vector2).y)
	var part: Vector2 = flurry_part.get(_act_clip, Vector2(0.0, 1.0))
	for h: Dictionary in heavy:
		if h["clip"] == _act_clip:
			part = h.get("part", part)
			# Held to the end of its getting back up (`hold`): let go earlier,
			# the first step off would snap him from the ground to his feet.
			if h.has("hold") and _heavy_now:
				return _action_len * (float(h["hold"]) - _action_from) / _action_rate
	return minf(_action_len * (w.y - _action_from) / _action_rate + swing_recovery,
			_action_len * (part.y - _action_from) / _action_rate)


func current_swing() -> StringName:
	return _act_clip if _role == Role.SWING else &""


func plunge(seconds: float) -> void:
	_plunge_left = maxf(seconds, 0.1)
	var length := _anim.get_animation(clips[&"plunge"]).length if _anim.has_animation(clips[&"plunge"]) else 1.0
	if _anim.current_animation == clips[&"plunge"]:
		# Already the jump attack, from the air: carry on from wherever the chop
		# has got to — no new clip, no blend, no jump in the pose.
		var at := clampf(_anim.current_animation_position / length, 0.0, 1.0)
		_air_cut = false
		_role = Role.PLUNGE
		_act_clip = clips[&"plunge"]
		_action_len = length
		_action_rate = maxf(length * (1.0 - at) / _plunge_left, 0.05)
		_action_left = _plunge_left
		_anim.speed_scale = _action_rate
		return
	# The landing of the jump attack — the blade going in and the body coming
	# back up over it — stretched over however long the recovery is.
	_play_action(clips[&"plunge"], Role.PLUNGE, length * (1.0 - plunge_from) / _plunge_left, 0.06, plunge_from, 1.0)


func is_planted() -> bool:
	return _plunge_left > 0.0


## The blade has gone into something: its sound, at the point it went in, the
## wet thump of it under the steel, and the swing caught a moment in the body.
##
## `matter` is what it went into ([method ImpactFx.matter_of]): flesh thumps
## wet, bone cracks, stone rings; the heavier the cut, the deeper and louder.
func blade_landed(matter: StringName = &"flesh") -> void:
	var at: Node3D = self
	if _sword_mount != null:
		at = _sword_mount
	var k := clampf(cut_weight - 1.0, -0.4, 1.0)
	var steel := hit_volume + 2.5 * k
	if matter == &"stone":
		steel -= 4.0  # the ring is the stone's own
	Sfx.play_any(self, hit_sounds, at, randf_range(0.94, 1.06) * (1.0 - 0.1 * maxf(k, 0.0)) * (1.12 if matter == &"bone" else 1.0), steel)
	ImpactFx.strike(self, at.global_position, matter, cut_weight)
	# Held as long as the body it bit is ([HitFeel]): the two stand still
	# together, longer for the end of a string or a heavy blow.
	hitstop(HitFeel.stop_for(cut_weight) * bite_stop / 0.075)


## How long the swing is held as it bites (seconds): the blade felt going in.
var bite_stop: float = 0.075
var _stop_left: float = 0.0
var _stop_rate: float = 1.0
## The rate the clip is held at while stopped: all but still.
const STOP_RATE := 0.04


## Whether the swing is held in a bite now.
func in_hitstop() -> bool:
	return _stop_left > 0.0


func hitstop(seconds: float) -> void:
	if _anim == null or seconds <= 0.0:
		return
	if _stop_left <= 0.0:
		_stop_rate = _anim.speed_scale
		_anim.speed_scale = _stop_rate * STOP_RATE
	_stop_left = maxf(_stop_left, seconds)
	# The swing's clock is held too, or it would end short of its clip.
	if _role != Role.NONE:
		_action_left += seconds


## The hold over: the clip goes on at the rate it had — unless something else
## has set a rate of its own in the meantime, which is left alone.
func _hold_stop(delta: float) -> void:
	if _stop_left <= 0.0:
		return
	_stop_left -= delta
	if _stop_left <= 0.0 and absf(_anim.speed_scale - _stop_rate * STOP_RATE) < 0.0001:
		_anim.speed_scale = _stop_rate


## Hurt: a grunt.
func hurt() -> void:
	Sfx.play_any(self, hurt_sounds, self, randf_range(0.95, 1.05), hurt_volume)


func bloody() -> void:
	blade_blood = minf(blade_blood + 0.34, 1.0)
	if _sword_mesh == null:
		return
	var overlay := StandardMaterial3D.new()
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color(0.35, 0.02, 0.02, blade_blood * 0.7)
	overlay.roughness = 0.35
	_sword_mesh.material_overlay = overlay


func dodge(duration: float) -> void:
	if _on_mq and moves.has("evade"):
		# An evade that cuts on the way, played whole at its own rate: the
		# dash is its lunge and cut, the rest its recovery ([Swordsman]).
		var evade: Dictionary = moves["evade"]
		if _play_action(evade["clip"], Role.ROLL, float(evade["rate"]), 0.06):
			_evade_cut = true
			_heavy_now = false
			cut_weight = float(evade["weight"])
			attack_serial += 1
			_whoosh()
		return
	# The roll part of the clip, fitted to the dash so the tumble and the
	# movement finish together; what is left of the clip is the run-out, which
	# the locomotion picks up instead.
	var roll: StringName = _mq_roll() if _on_mq else clips[&"roll"]
	var share := roll_share
	if _on_mq:
		share = float((moves.get("roll_share", {}) as Dictionary).get(roll, roll_share))
	var length := _anim.get_animation(roll).length if _anim.has_animation(roll) else 1.0
	_play_action(roll, Role.ROLL, length * share / maxf(duration, 0.05), 0.05, 0.0, share)


func dodge_clip(duration: float) -> bool:
	if _on_mq and moves.has("evade"):
		return false  # the evade is the one move; no longer one to turn it into
	var roll: StringName = _mq_roll() if _on_mq else clips[&"roll"]
	var length := _anim.get_animation(roll).length if _anim.has_animation(roll) else 0.0
	if length <= 0.0:
		return false
	return _play_action(roll, Role.ROLL, length / maxf(duration, 0.05), 0.06)


func hit() -> void:
	flinch()


func flinch() -> void:
	if _on_mq:
		_rouse()
	if _role == Role.SWING or _role == Role.DOWN:
		return
	_play_action(clips[&"hit_blocked"] if _blocking_now else clips[&"hit"], Role.HIT, 1.3, 0.05)


## A blow thrown back off the shield: the guard's own jolt, played fast — the
## shield punched out into the blow and brought back.
func parry() -> void:
	if _role == Role.DOWN or _role == Role.GET_UP:
		return
	if _on_mq:
		_rouse()
	if clips.has(&"parry") and _anim.has_animation(clips[&"parry"]):
		_play_action(clips[&"parry"], Role.HIT, 1.5, 0.03)
	else:
		_play_action(clips[&"hit_blocked"], Role.HIT, 2.0, 0.04)


## Shows the shield that is carried and hides the other.
func set_shield(kind: int) -> void:
	shield_kind = kind
	var bare := face < faces.size() and shieldless_faces.has(faces[face])
	if _sword_mesh != null:
		_sword_mesh.visible = not (face < faces.size() and own_sword_faces.has(faces[face]))
	for i in _shield_meshes.size():
		if _shield_meshes[i] != null:
			_shield_meshes[i].visible = i == kind and not bare
	_show_figure_arms()
	_base_clip = &""


## Shows the outfit `index` of `garbs` and hides the others.
func set_garb(index: int) -> void:
	garb = clampi(index, 0, maxi(garbs.size() - 1, 0))
	for i in garbs.size():
		var mesh := find_child(String(garbs[i]), true, false) as MeshInstance3D
		if mesh != null:
			mesh.visible = i == garb and not wearing_whole()
	if _skel == null:
		return
	if wearing_whole() and whole_capes.has(faces[face]):
		_hang_capes(whole_capes[faces[face]])
	elif garb < garb_capes.size():
		_hang_capes(garb_capes[garb])


## The mesh of hair style `style` (an index into `hairs`) for the skull
## `skull` — the one the face that is on has, if none is named.
func hair_mesh(style: int, skull: StringName = &"") -> StringName:
	if skull == &"":
		skull = face_skulls[face] if face < face_skulls.size() else &"box"
	return StringName("%s_hair_%s_%s" % [mesh_prefix, skull, hairs[style]])


## Shows the hair `index` of `hairs`, the one fitted to the face that is on,
## and hides every other.
func set_hair(index: int) -> void:
	hair = clampi(index, 0, maxi(hairs.size() - 1, 0))
	if hairs.is_empty():
		return
	var on := hair_mesh(hair)
	var skulls: Array[StringName] = [&"box"]
	for skull in face_skulls:
		if not skulls.has(skull):
			skulls.append(skull)
	for skull in skulls:
		for i in hairs.size():
			var mesh := find_child(String(hair_mesh(i, skull)), true, false) as MeshInstance3D
			if mesh != null:
				mesh.visible = hair_mesh(i, skull) == on and not wearing_whole()


## Shows the face `index` of `faces` and hides the others; the hair follows
## it onto its skull.
func set_face(index: int) -> void:
	# A look no longer offered (an index saved when there were more) is the
	# hero's first, not his last: the last is YOUR OWN, the maker's.
	face = index if index >= 0 and index < faces.size() else 0
	for i in faces.size():
		var mesh := find_child("%s_face_%s" % [mesh_prefix, faces[i]], true, false) as MeshInstance3D
		if mesh != null:
			mesh.visible = i == face
	# A face the model still carries but the rig no longer offers (looks taken
	# off the hero select) stays hidden.
	for node in find_children("%s_face_*" % mesh_prefix, "MeshInstance3D", true, false):
		var key := StringName(String(node.name).trim_prefix("%s_face_" % mesh_prefix))
		if not faces.has(key):
			(node as MeshInstance3D).visible = false
	set_hair(hair)
	set_garb(garb)
	_show_figure()
	_apply_moves()
	if not _shield_meshes.is_empty():
		set_shield(shield_kind)


## Fights as the face that is on does (see `face_moves`), or as the rig does.
func _apply_moves() -> void:
	if _own_moves.is_empty():
		return
	if _on_mq:
		_wear_moves()
		_off_hand_on = PolysplitLook.cuts(String(ps_look.get("o", "")))
		return
	var m: Dictionary = face_moves.get(faces[face], {}) if face < faces.size() else {}
	flurry.assign(m.get("flurry", _own_moves["flurry"]))
	flurry_part = m.get("flurry_part", _own_moves["flurry_part"])
	heavy = m.get("heavy", _own_moves["heavy"])
	_off_hand_on = m.get("off_hand", true)
	if face < faces.size() and faces[face] == CUSTOM:
		_off_hand_on = PolysplitLook.cuts(String(ps_look.get("o", "")))


## Whether the face that is on is a whole figure (see `whole_faces`).
func wearing_whole() -> bool:
	return face < faces.size() and whole_faces.has(faces[face])


## The bone map for a figure on Blink's skeleton (see `figures`): its body
## bones by this rig's, and `extra` (the arm bones both carry) as given.
static func blink_map(extra: Dictionary) -> Dictionary:
	var map := {
		&"Root_M": &"pelvis", &"Spine1_M": &"spine_01", &"Chest_M": &"spine_02",
		&"Neck_M": &"neck_01", &"Head_M": &"head",
		&"Scapula_R": &"clavicle_r", &"Shoulder_R": &"upperarm_r", &"Elbow_R": &"lowerarm_r",
		&"Wrist_R": &"hand_r",
		&"Scapula_L": &"clavicle_l", &"Shoulder_L": &"upperarm_l", &"Elbow_L": &"lowerarm_l",
		&"Wrist_L": &"hand_l",
		&"Hip_R": &"thigh_r", &"Knee_R": &"calf_r", &"Ankle_R": &"foot_r", &"Toes_R": &"ball_r",
		&"Hip_L": &"thigh_l", &"Knee_L": &"calf_l", &"Ankle_L": &"foot_l", &"Toes_L": &"ball_l",
	}
	map.merge(extra)
	return map


## The same for Synty's Sidekick: the mannequin's names, as this rig's are;
## its third spine bone is this rig's second, the second rides the first.
static func sidekick_map(extra: Dictionary) -> Dictionary:
	var map := {}
	for b in ["pelvis", "spine_01", "neck_01", "head", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
			"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "thigh_r", "calf_r", "foot_r", "ball_r",
			"thigh_l", "calf_l", "foot_l", "ball_l"]:
		map[StringName(b)] = StringName(b)
	map[&"spine_03"] = &"spine_02"
	map.merge(extra)
	return map


## The same for Polysplit's heroes (vepxis-art tools/ps_build.py): their
## waist is this rig's first spine bone, their chest the second.
static func polysplit_map(extra: Dictionary) -> Dictionary:
	var map := {
		&"pelvis_joint": &"pelvis", &"waist_joint": &"spine_01", &"chest_joint": &"spine_02",
		&"neck_joint": &"neck_01", &"head_joint": &"head",
	}
	for s: String in ["l", "r"]:
		var side := s.to_upper()
		for pair: Array in [["clavicle", "clavicle"], ["shoulder", "upperarm"], ["elbow", "lowerarm"], ["wrist", "hand"],
				["thigh", "thigh"], ["knee", "calf"], ["ankle", "foot"], ["ball", "ball"]]:
			map[StringName("%s_%s_joint" % [side, pair[0]])] = StringName("%s_%s" % [pair[1], s])
	map.merge(extra)
	return map


## The same for a model rigged to Mixamo's skeleton (the "mixamorig:" taken
## off its names, vepxis-art tools/bl_mixfig.py); its middle spine bone rides
## the first.
static func mixamo_map(extra: Dictionary) -> Dictionary:
	var map := {
		&"Hips": &"pelvis", &"Spine": &"spine_01", &"Spine2": &"spine_02", &"Neck": &"neck_01", &"Head": &"head",
		&"RightShoulder": &"clavicle_r", &"RightArm": &"upperarm_r", &"RightForeArm": &"lowerarm_r",
		&"RightHand": &"hand_r",
		&"LeftShoulder": &"clavicle_l", &"LeftArm": &"upperarm_l", &"LeftForeArm": &"lowerarm_l",
		&"LeftHand": &"hand_l",
		&"RightUpLeg": &"thigh_r", &"RightLeg": &"calf_r", &"RightFoot": &"foot_r", &"RightToeBase": &"ball_r",
		&"LeftUpLeg": &"thigh_l", &"LeftLeg": &"calf_l", &"LeftFoot": &"foot_l", &"LeftToeBase": &"ball_l",
	}
	map.merge(extra)
	return map


## The same for a model on Rigify's basic human skeleton (spine to
## spine.006, upper_arm.L, shin.L...): its hips are "spine", its neck
## spine.004, its head spine.006.
static func rigify_map(extra: Dictionary) -> Dictionary:
	var map := {
		&"spine": &"pelvis", &"spine.001": &"spine_01", &"spine.003": &"spine_02", &"spine.004": &"neck_01",
		&"spine.006": &"head",
		&"shoulder.R": &"clavicle_r", &"upper_arm.R": &"upperarm_r", &"forearm.R": &"lowerarm_r", &"hand.R": &"hand_r",
		&"shoulder.L": &"clavicle_l", &"upper_arm.L": &"upperarm_l", &"forearm.L": &"lowerarm_l", &"hand.L": &"hand_l",
		&"thigh.R": &"thigh_r", &"shin.R": &"calf_r", &"foot.R": &"foot_r", &"toe.R": &"ball_r",
		&"thigh.L": &"thigh_l", &"shin.L": &"calf_l", &"foot.L": &"foot_l", &"toe.L": &"ball_l",
	}
	map.merge(extra)
	return map


## Whether the face that is on is worn on the figure's own skeleton.
func wearing_figure() -> bool:
	return face < faces.size() and figure_faces.has(faces[face])


## Loads each figure beside the model, its skeleton following this one, with
## a mount on its sword hand for the blade's cut (see `_show_figure()`).
func _setup_figure() -> void:
	_rig_mount = _sword_mount
	if _blade_base_l != null:
		_rig_mount_l = _blade_base_l.get_parent() as Node3D
	if _blade_base != null:
		_blade_at = [_blade_base.position, _blade_tip.position]
		if _blade_base_l != null:
			_blade_at.append_array([_blade_base_l.position, _blade_tip_l.position])
	for id: StringName in figures:
		if not (figures[id] as Dictionary).get("lazy", false):
			_load_figure(id)


## Loads the figure `id` beside the model, following its skeleton (see
## `_setup_figure()`). False if it cannot be.
func _load_figure(id: StringName) -> bool:
	var model := _skel.owner as Node3D if _skel.owner != null else _skel.get_parent() as Node3D
	var spec: Dictionary = figures[id]
	var path := String(spec["scene"])
	if not ResourceLoader.exists(path):
		return false
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.name = "Figure_" + String(id)
	model.get_parent().add_child(node)
	node.transform = model.transform
	node.visible = false
	var skel := node.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	if skel == null:
		node.queue_free()
		return false
	var follow := FigureFollower.new()
	follow.name = "FigureFollower_" + String(id)
	add_child(follow)
	follow.damp = spec.get("damp", {})
	follow.mids = spec.get("mids", {})
	if not follow.setup(_skel, skel, spec["map"], spec["hips"]):
		push_warning("SkinnedRig: figure %s's skeleton does not match its map." % id)
	var mount: BoneAttachment3D = null
	if skel.find_bone("weapon_r") >= 0:
		mount = BoneAttachment3D.new()
		mount.name = "WeaponMount"
		skel.add_child(mount)
		mount.bone_name = "weapon_r"
	var mount_l: BoneAttachment3D = null
	if skel.find_bone("weapon_l") >= 0:
		mount_l = BoneAttachment3D.new()
		mount_l.name = "WeaponMountL"
		skel.add_child(mount_l)
		mount_l.bone_name = "weapon_l"
	follow.followed.connect(_on_figure_followed.bind(id))
	follow.followed.connect(_turn_shield.bind(id))
	follow.followed.connect(_hilt.bind(id))
	follow.followed.connect(_hold_sheathed.bind(id))
	_figs[id] = {"node": node, "skel": skel, "follow": follow, "mount": mount, "mount_l": mount_l}
	return true


## Shows the figure the face that is on is worn on, with its meshes for that
## face, and hides every other; the blade's cut is drawn off whichever sword
## hand is seen.
func _show_figure() -> void:
	if figures.is_empty():
		return
	var look: Dictionary = figure_faces.get(faces[face], {}) if wearing_figure() else {}
	var custom: bool = look.get("custom", false)
	# YOUR OWN on the mannequin, every other look on the model's own skeleton
	_use_mannequin(custom and maker_on_mannequin)
	if custom:
		look["figure"] = &"psf" if String(ps_look.get("g", "m")) == "f" else &"psm"
	var worn: StringName = look.get("figure", &"")
	if worn != &"" and not _figs.has(worn) and not _load_figure(worn):
		push_warning("SkinnedRig: the figure %s is missing." % worn)
		worn = &""
	# (on the mannequin the model is hidden whole, see `_use_mannequin()`)
	_hide_own(custom and worn != &"" and not _on_mq)
	_figure = null
	_figure_skel = null
	_figure_mount = null
	for id: StringName in _figs:
		var fig: Dictionary = _figs[id]
		var node := fig["node"] as Node3D
		node.visible = id == worn
		if id != worn:
			continue
		_figure = node
		_figure_skel = fig["skel"]
		_figure_mount = fig["mount"]
		var prefix := String(figures[id]["prefix"]) + "_"
		var shows: Array = look.get("show", [])
		var hides: Array = look.get("hide", [])
		if custom:
			PolysplitLook.apply(node, ps_look)
			shows = []
			if _on_mq and String(ps_look.get("w", "")) == "own_bow":
				# the mannequin's figure has the pack's bow only (his own
				# bends on bones of his rig's)
				var bow := node.find_child("ps_w_bow", true, false) as MeshInstance3D
				if bow != null:
					bow.visible = true
		var listed: Array[Node] = []
		if not custom:
			listed = node.find_children("*", "MeshInstance3D", true, false)
		for mesh: MeshInstance3D in listed:
			var key := String(mesh.name).trim_prefix(prefix)
			if key in ["sword", "shield", "tower_shield"] or key.begins_with("arm_"):
				continue
			var shown := false
			for pre: String in shows:
				shown = shown or key.begins_with(pre)
			for pre: String in hides:
				shown = shown and not key.begins_with(pre)
			mesh.visible = shown
		(fig["follow"] as FigureFollower).follow()
	_show_figure_arms()
	var mount := _figure_mount if _figure_mount != null else _rig_mount
	if mount != null and _blade_base != null and _blade_base.get_parent() != mount:
		_blade_base.reparent(mount, false)
		_blade_tip.reparent(mount, false)
		_sword_mount = mount
	var fig_l: Node3D = null
	if _figure != null:
		fig_l = _figs[worn]["mount_l"]
	var mount_l := fig_l if fig_l != null else _rig_mount_l
	if mount_l != null and _blade_base_l != null and _blade_base_l.get_parent() != mount_l:
		_blade_base_l.reparent(mount_l, false)
		_blade_tip_l.reparent(mount_l, false)
	_fit_blades(custom)
	_fit_sheath(custom)
	_scale_ground()


## The cut's markers along the blade in hand: the maker's blades are measured
## off their meshes (a dagger is short, a great sword long); every other look
## has the rig's own.
func _fit_blades(custom: bool) -> void:
	if _blade_at.size() < 2:
		return
	_blade_base.position = _blade_at[0]
	_blade_tip.position = _blade_at[1]
	if _blade_at.size() >= 4:
		_blade_base_l.position = _blade_at[2]
		_blade_tip_l.position = _blade_at[3]
	if not custom or _figure == null:
		return
	var w := String(ps_look.get("w", ""))
	if PolysplitLook.cuts(w):
		var mesh := _figure.find_child("ps_w_" + w, true, false) as MeshInstance3D
		# the blade's way in the hand: the rig's own, or on the mannequin's
		# figure (whose hand bones are the mannequin's) the blade's own
		var along := _blade_at[1].normalized()
		if _on_mq:
			along = _far(mesh, &"weapon_r").normalized()
		var reach := _reach(mesh, &"weapon_r", along)
		if reach > 0.1:
			_blade_tip.position = along * reach * 0.96
			_blade_base.position = along * minf(_blade_at[0].length(), reach * 0.3)
	var o := String(ps_look.get("o", ""))
	if _blade_at.size() >= 4 and PolysplitLook.cuts(o):
		var mesh_l := _figure.find_child("ps_o_" + o, true, false) as MeshInstance3D
		var along_l := _blade_at[3].normalized()
		if _on_mq:
			along_l = _far(mesh_l, &"weapon_l").normalized()
		var reach_l := _reach(mesh_l, &"weapon_l", along_l)
		if reach_l > 0.1:
			_blade_tip_l.position = along_l * reach_l * 0.96
			if _on_mq:
				_blade_base_l.position = along_l * minf(_blade_at[2].length(), reach_l * 0.3)


## How far `mesh` (a weapon rigid on the figure's `bone`) reaches from the
## bone along `along` (in the bone's frame), at rest.
func _reach(mesh: MeshInstance3D, bone: StringName, along: Vector3) -> float:
	if mesh == null or mesh.skin == null or mesh.mesh == null or _figure_skel == null:
		return 0.0
	var at := _figure_skel.find_bone(bone)
	var bind := Transform3D()
	var found := false
	for i in mesh.skin.get_bind_count():
		var named := mesh.skin.get_bind_name(i)
		if named == bone or (named == &"" and mesh.skin.get_bind_bone(i) == at):
			bind = mesh.skin.get_bind_pose(i)
			found = true
	if not found:
		return 0.0
	var best := 0.0
	for s in mesh.mesh.get_surface_count():
		for v: Vector3 in mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			best = maxf(best, (bind * v).dot(along))
	return best


## The point of `mesh` (rigid on the figure's `bone`) farthest from the bone
## (or from `from`), in the bone's frame at rest: a blade's tip (and from the
## tip, its pommel). Zero if it cannot be read.
func _far(mesh: MeshInstance3D, bone: StringName, from: Vector3 = Vector3.ZERO) -> Vector3:
	if mesh == null or mesh.skin == null or mesh.mesh == null or _figure_skel == null:
		return Vector3.ZERO
	var at := _figure_skel.find_bone(bone)
	var bind := Transform3D()
	var found := false
	for i in mesh.skin.get_bind_count():
		var named := mesh.skin.get_bind_name(i)
		if named == bone or (named == &"" and mesh.skin.get_bind_bone(i) == at):
			bind = mesh.skin.get_bind_pose(i)
			found = true
	if not found:
		return Vector3.ZERO
	var best := Vector3.ZERO
	for s in mesh.mesh.get_surface_count():
		for v: Vector3 in mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p := bind * v
			if p.distance_squared_to(from) > best.distance_squared_to(from):
				best = p
	return best


## Puts the rig's own meshes away while the maker's figure is worn (`on`), and
## brings back after those no look of the rig's would show again.
func _hide_own(on: bool) -> void:
	if not on:
		for mesh in _own_hidden:
			if is_instance_valid(mesh):
				mesh.visible = true
		_own_hidden.clear()
		return
	for mesh: MeshInstance3D in _skel.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible:
			continue
		mesh.visible = false
		if not String(mesh.name).begins_with(mesh_prefix + "_") and not _own_hidden.has(mesh):
			_own_hidden.append(mesh)


## Adds the maker's face, CUSTOM, last of the hero's looks: worn on the
## figure of the look's gender, its bones following the rig's by
## [method polysplit_map] (a chest on the rig's third spine bone where it has
## one), its arms on the rig's own arm bones.
func _add_maker() -> void:
	if faces.is_empty():
		faces = [&"own"]
		face_skulls = [&"own"]
		face_names = ["AS HE WAS"]
	faces.append(CUSTOM)
	face_skulls.append(CUSTOM)
	face_names.append("YOUR OWN")
	whole_faces.append(CUSTOM)
	shieldless_faces.append(CUSTOM)
	own_sword_faces.append(CUSTOM)
	var extra := {}
	for b in ARM_BONES:
		if _skel.find_bone(b) >= 0:
			extra[b] = b
	var map := polysplit_map(extra)
	if _skel.find_bone("spine_03") >= 0:
		map[&"chest_joint"] = &"spine_03"
	var scene := "res://assets/polysplit/%s_%s.glb" % [polysplit_hero, "%s"]
	if maker_on_mannequin:
		# on the mannequin: its chest is its third spine bone, its head "Head";
		# the figure's arm bones ride their hands and forearm
		map = polysplit_map({})
		map[&"chest_joint"] = &"spine_03"
		map[&"head_joint"] = &"Head"
		scene = MANNEQUIN_FIGURE
	for g: String in ["m", "f"]:
		figures[StringName("ps" + g)] = {"scene": scene % g,
				"prefix": "ps", "hips": &"pelvis_joint", "map": map, "lazy": true}
	figure_faces[CUSTOM] = {"figure": &"psm", "custom": true}
	ps_look = PolysplitLook.normalized(ps_look, polysplit_hero)


#region YOUR OWN on the mannequin
## The tables a hero fights from (see `clips`, `flurry`...), as they stand.
func _tables() -> Dictionary:
	return {"clips": clips.duplicate(), "ground_speed": ground_speed.duplicate(), "looping": looping.duplicate(),
			"flurry": flurry.duplicate(), "flurry_part": flurry_part.duplicate(), "heavy": heavy.duplicate(true),
			"cut_window": cut_window.duplicate(), "cut_windows": cut_windows.duplicate(true),
			"trail_window": trail_window.duplicate(), "carried": carried.duplicate(),
			"flurry_reset_after": flurry_reset_after, "swing_rate": swing_rate, "run_threshold": run_threshold,
			"air_cut_from": air_cut_from, "plunge_from": plunge_from}


func _set_tables(t: Dictionary) -> void:
	clips = (t["clips"] as Dictionary).duplicate()
	ground_speed = (t["ground_speed"] as Dictionary).duplicate()
	looping.assign(t["looping"])
	flurry.assign(t["flurry"])
	flurry_part = (t["flurry_part"] as Dictionary).duplicate()
	heavy = (t["heavy"] as Array).duplicate(true)
	cut_window = (t["cut_window"] as Dictionary).duplicate()
	cut_windows = (t["cut_windows"] as Dictionary).duplicate(true)
	trail_window = (t["trail_window"] as Dictionary).duplicate()
	carried = (t["carried"] as Dictionary).duplicate()
	flurry_reset_after = float(t["flurry_reset_after"])
	swing_rate = float(t["swing_rate"])
	run_threshold = float(t["run_threshold"])
	air_cut_from = float(t.get("air_cut_from", air_cut_from))
	plunge_from = float(t.get("plunge_from", plunge_from))


## Loads the mannequin beside the model, its mesh hidden, its player given
## every clip it may play: UAL 2's (its own), Kevin's, the hero's own carried
## onto it, and any lent by another hero (`mq_borrow`) — each with every bone
## keyed ([method Moveset.complete]). False if it cannot be.
func _build_mannequin() -> bool:
	if not ResourceLoader.exists(MANNEQUIN_SCENE):
		return false
	var node := (load(MANNEQUIN_SCENE) as PackedScene).instantiate() as Node3D
	node.name = "Mannequin"
	var model := _skel.owner as Node3D if _skel.owner != null else _skel.get_parent() as Node3D
	add_child(node)
	node.transform = model.transform if model.get_parent() == self else Transform3D.IDENTITY
	var skel := node.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	var player := node.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if skel == null or player == null:
		node.queue_free()
		return false
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = false
	# One library of its own (the clips are shared, the list is not): a second
	# hero on the mannequin must not find this one's clips in his.
	var lib := AnimationLibrary.new()
	var sources: Array[AnimationLibrary] = [player.get_animation_library(&"")]
	if ResourceLoader.exists(KEVIN_LIB):
		sources.append(load(KEVIN_LIB) as AnimationLibrary)
	if ResourceLoader.exists(HERO_LIB % polysplit_hero):
		sources.append(load(HERO_LIB % polysplit_hero) as AnimationLibrary)
	var own := {}
	for src: AnimationLibrary in sources:
		var mine := src.resource_path == HERO_LIB % polysplit_hero
		for n: StringName in src.get_animation_list():
			lib.add_animation(n, src.get_animation(n))
			if mine:
				own[n] = true
	for clip: StringName in mq_borrow:
		var other := HERO_LIB % mq_borrow[clip]
		if ResourceLoader.exists(other) and (load(other) as AnimationLibrary).has_animation(clip):
			lib.add_animation(clip, (load(other) as AnimationLibrary).get_animation(clip))
	for n: StringName in lib.get_animation_list():
		Moveset.complete(lib.get_animation(n), skel)
	for n: StringName in player.get_animation_library_list():
		player.remove_animation_library(n)
	player.add_animation_library(&"", lib)
	var holder := player.get_node(player.root_node)
	player.root_motion_track = NodePath(String(holder.get_path_to(skel)) + ":root")
	var stride := StrideModifier.new()
	stride.name = "Stride"
	skel.add_child(stride)
	var strike: StrikeAim = null
	if strike_aim:
		strike = StrikeAim.new()
		strike.name = "StrikeAim"
		strike.natural = strike_natural
		skel.add_child(strike)
	# last: the feet laid flat under the hero's own clips carried over
	var feet := FootFlat.new()
	feet.name = "FootFlat"
	feet.active = false
	skel.add_child(feet)
	# and last of all: the feet on the ground where it is (slopes, steps)
	var ground := FootGround.new()
	ground.name = "FootGround"
	skel.add_child(ground)
	_mq = {"node": node, "skel": skel, "anim": player, "stride": stride, "strike": strike, "lib": lib,
			"own": own, "feet": feet}
	_mannequin_built(skel)
	return true


## For a rig to add what it hangs off the mannequin's skeleton (a bow's
## modifier), once it is built.
func _mannequin_built(_skel_mq: Skeleton3D) -> void:
	pass


## For a rig to follow the swap onto the mannequin (`on`) and back.
func _mannequin_worn(_on: bool) -> void:
	pass


## Puts the rig onto the mannequin (`on`) or back onto the model's own
## skeleton: which skeleton, player and modifiers it drives, which tables it
## plays from, and which of the two is shown.
func _use_mannequin(on: bool) -> void:
	if on == _on_mq or _anim == null:
		return
	if on and _mq.is_empty() and not _build_mannequin():
		return
	_end_action()
	_base_clip = &""
	var model := (_own.get("skel", _skel) as Skeleton3D)
	var model_root := model.owner as Node3D if model.owner != null else model.get_parent() as Node3D
	if on:
		_own = {"anim": _anim, "skel": _skel, "stride": _stride, "strike": _strike}
		_anim.active = false
		_anim = _mq["anim"]
		_skel = _mq["skel"]
		_stride = _mq["stride"]
		_strike = _mq["strike"]
		_anim.active = true
		# hidden and still: nothing of it (its modifiers, a bow's string) is
		# worked out off a skeleton no one sees
		model_root.visible = false
		model_root.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		_anim.active = false
		_anim = _own["anim"]
		_skel = _own["skel"]
		_stride = _own["stride"]
		_strike = _own["strike"]
		_anim.active = true
		model_root.visible = true
		model_root.process_mode = Node.PROCESS_MODE_INHERIT
		_set_tables(_own_tables)
		moves = {}
	_on_mq = on
	_shield_turn_now = NAN
	# the capes hang off the skeleton worn
	set_garb(garb)
	_mannequin_worn(on)


## The moves for the arms of the look worn ([Moveset]), laid over the hero's
## own tables (which stay for what the picks leave out).
func _wear_moves() -> void:
	var kind := Moveset.kind_of(ps_look)
	if moves.get("kind", &"") == kind:
		return
	moves = Moveset.build(kind, _own_tables["clips"])
	_set_tables(_own_tables)
	for slot: StringName in moves["clips"]:
		var clip: StringName = moves["clips"][slot]
		if clip != &"" and _anim.has_animation(clip):
			clips[slot] = clip
	_mq_ground = (moves["ground_speed"] as Dictionary).duplicate()
	_scale_ground()
	var lib: AnimationLibrary = _mq["lib"]
	for part: StringName in moves["aliases"]:
		if not lib.has_animation(part) and lib.has_animation(moves["aliases"][part]):
			lib.add_animation(part, lib.get_animation(moves["aliases"][part]))
	for clip: StringName in moves["looping"]:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_strings = []
	for s: Array in moves["strings"]:
		var playable := s.filter(func(c: StringName) -> bool: return _anim.has_animation(c))
		if playable.size() == s.size() and not s.is_empty():
			_strings.append(s)
	if not _strings.is_empty():
		flurry.assign(_strings[0])
	for key: String in ["flurry_part", "cut_window", "cut_windows", "trail_window"]:
		(get(key) as Dictionary).merge(moves[key], true)
	if not (moves["heavy"] as Array).is_empty():
		heavy = (moves["heavy"] as Array).duplicate(true)
	if flurry_reset_after <= 0.0:
		flurry_reset_after = 1.2
	# the picked blows were made at the game's pace (UAL 2's) or near it
	# (Kevin's): not hurried as the Mixamo ones were
	swing_rate = MQ_SWING_RATE * mq_swing_scale
	if moves.has("jump_attack"):
		# from the aerial pose up to the blade over the head, held till the
		# ground; the landing plays on from there ([Swordsman])
		air_cut_from = 0.0
		plunge_from = float(moves["jump_attack"]["hold"])
	# from the walk to the run halfway between their paces, each played as
	# near its own pace as it can be
	var walk_pace := float(ground_speed.get(clips[&"walk"], 0.0))
	var run_pace := float(ground_speed.get(clips[&"run"], 0.0))
	if walk_pace > 0.0 and run_pace > walk_pace:
		run_threshold = 0.5 * (walk_pace + run_pace)
	shield_turn_default = float((moves["shield_turn"] as Dictionary).get(moves["guard"], SHIELD_BUILT_TURN))
	# the string last picked (F6), kept
	var cfg := ConfigFile.new()
	if cfg.load(TRIAL_CFG) == OK:
		_wear_string(int(cfg.get_value(String(polysplit_hero), "string", 0)))
	_hilt_ends.clear()
	_flurry_slot = -1
	_base_clip = &""
	# standing at once, so the skeleton (and the figure on it) is posed before
	# the first frame the controller drives
	_set_base(clips[&"idle"], 0.0, 1.0)


const TRIAL_CFG := "user://trial.cfg"


## The other string ([Swordsman] `STRINGS`, F6), kept for next time.
## Its name, or "" if there are none.
func cycle_string() -> String:
	return _cycle_trial("string", (moves.get("string_sets", []) as Array).size(), _wear_string)


func _cycle_trial(key: String, count: int, wear: Callable) -> String:
	if not _on_mq or count == 0:
		return ""
	var cfg := ConfigFile.new()
	cfg.load(TRIAL_CFG)
	var next := (int(cfg.get_value(String(polysplit_hero), key, 0)) + 1) % count
	cfg.set_value(String(polysplit_hero), key, next)
	cfg.save(TRIAL_CFG)
	return wear.call(next)


func _wear_string(i: int) -> String:
	var sets: Array = moves.get("string_sets", [])
	if sets.is_empty():
		return ""
	var s: Dictionary = sets[clampi(i, 0, sets.size() - 1)]
	var clips_of: Array = (s["clips"] as Array).filter(func(c: StringName) -> bool: return _anim.has_animation(c))
	if clips_of.size() != (s["clips"] as Array).size():
		return ""
	_strings = [clips_of]
	flurry.assign(clips_of)
	moves["recover"] = (s["recover"] as Dictionary).duplicate()
	_flurry_slot = -1
	return String(s["name"])


## `clip` as the run, the walk going over to it halfway between their paces.
func _set_run(clip: StringName) -> void:
	clips[&"run"] = clip
	var walk_pace := float(ground_speed.get(clips[&"walk"], 0.0))
	var run_pace := float(ground_speed.get(clip, 0.0))
	if walk_pace > 0.0 and run_pace > walk_pace:
		run_threshold = 0.5 * (walk_pace + run_pace)
	_base_clip = &""


## `clip`, or at random one of the clips picked to play in its place.
func _alt(clip: StringName) -> StringName:
	if not _on_mq:
		return clip
	var others: Array = (moves.get("alts", {}) as Dictionary).get(clip, [])
	if others.is_empty():
		return clip
	var i := randi() % (others.size() + 1)
	if i == 0:
		return clip
	var other: Variant = others[i - 1]
	return other if other is StringName and _anim.has_animation(other) else clip


## The evade on the mannequin, by the way the dash goes as the body sees it:
## Kevin's dodge is a hop that goes out one way and comes back (its "hop",
## measured), so it is played only when the dash goes that way; any other
## way (ahead, as a dash mostly is: the body turns to it) it is the hero's
## own roll, the pick's "also".
func _mq_roll() -> StringName:
	var main: StringName = clips[&"roll"]
	var others: Array = (moves.get("alts", {}) as Dictionary).get(main, [])
	var hop: Array = Moveset.clip_meta(main).get("hop", [])
	if hop.is_empty() or others.is_empty():
		return _alt(main)
	var way := Vector3(float(hop[0]), 0.0, float(hop[1]))
	var dash: Variant = _body.get(&"_dash_direction") if _body != null else null
	var along := 0.0
	if dash is Vector3 and (dash as Vector3).length() > 0.1 and way.length() > 0.05:
		# the clip's +z is the way he faces; the body's is its -z
		var local := _body.global_basis.inverse() * (dash as Vector3)
		along = Vector3(local.x, 0.0, -local.z).normalized().dot(way.normalized())
	if along > 0.5:
		return main
	var own: Variant = others[0]
	return own if own is StringName and _anim.has_animation(own) else main


## A blow thrown or taken, a guard raised: on guard for `EASE_AFTER`.
func _rouse() -> void:
	_fight_till = Time.get_ticks_msec() / 1000.0 + EASE_AFTER


## On guard: lately in a fight, or locked on to something.
func fighting() -> bool:
	if Time.get_ticks_msec() / 1000.0 < _fight_till:
		return true
	return _body != null and _body.get(&"target") != null


## The mannequin's base pose where the moves have their own (the jump's
## start, the air, the guard held up, standing on guard or easy); false for
## the rig's own choice.
func _mq_base(planar: float, airborne: bool, blocking: bool) -> bool:
	if airborne:
		var start: StringName = clips.get(&"air_start", &"")
		if _air_rising and start != &"" and _anim.has_animation(start) \
				and _air_t < _anim.get_animation(start).length * 0.85:
			_set_base(start, 0.08, 1.0)
			return true
		var air := _air_clip if _air_clip != &"" else clips.get(&"air", &"") as StringName
		if not _anim.has_animation(air):
			return false
		_set_base(air, 0.15, 1.0)
		return true
	if _crouching or _wall_climbing:
		return false
	if blocking:
		var guard: StringName = clips.get(&"block_idle", &"")
		if not _anim.has_animation(guard):
			return false
		_set_base(guard, 0.12, 1.0)
		return true
	if planar < idle_threshold:
		var stand: StringName = clips[&"idle"]
		if fighting() and moves.get("guard", &"") != &"":
			if _guard_clip == &"":
				_guard_clip = _alt(moves["guard"])
			stand = _guard_clip
		_set_base(stand, 0.25, 1.0)
		return true
	return false


## Each frame on the mannequin, before the base is picked: the jump's start
## and landing, and the guard let down when the fight is over.
func _mq_tick(delta: float, planar: float, airborne: bool, vy: float, blocking: bool) -> void:
	if airborne and not _air_was:
		_air_t = 0.0
		_air_rising = vy > 0.5
		_air_clip = _alt(clips.get(&"air", &""))
	if airborne:
		_air_t += delta
	elif _air_was and _air_t > 0.35 and _role == Role.NONE and planar <= idle_threshold:
		var land: StringName = clips.get(&"land", &"")
		if land != &"" and _anim.has_animation(land):
			_play_action(land, Role.FREE, 1.4, 0.06, 0.0, 0.45)
			_recovering = true
	_air_was = airborne
	var feet: FootFlat = _mq.get("feet")
	if feet != null:
		feet.active = (_mq["own"] as Dictionary).has(StringName(_anim.current_animation))
	if blocking:
		_rouse()
	if not fighting():
		_guard_clip = &""


## Turns the shield on the maker's figure about its forearm onto the way the
## clip playing holds it to the front (the moves' "shield_turn", measured off
## each clip), or onto the guard's way for a clip that names none: one shield
## on the forearm cannot face the blow in UAL 2's guard and Kevin's block both.
func _turn_shield(id: StringName) -> void:
	if not _on_mq or _figure_skel == null or not _figs.has(id) or _figs[id]["skel"] != _figure_skel:
		return
	var b := _figure_skel.find_bone("shield_l")
	var elbow := _figure_skel.find_bone("L_elbow_joint")
	var wrist := _figure_skel.find_bone("L_wrist_joint")
	if b < 0 or elbow < 0 or wrist < 0:
		return
	var playing := _act_clip if _role != Role.NONE else StringName(_anim.current_animation)
	var want := float((moves.get("shield_turn", {}) as Dictionary).get(playing, shield_turn_default))
	if is_nan(_shield_turn_now):
		_shield_turn_now = want
	else:
		_shield_turn_now = move_toward(_shield_turn_now, want, SHIELD_TURN_RATE * get_process_delta_time())
	var e_rest := _figure_skel.get_bone_global_rest(elbow)
	var along := (_figure_skel.get_bone_global_rest(wrist).origin - e_rest.origin).normalized()
	var turned := _figure_skel.get_bone_global_pose(elbow).basis.orthonormalized() * e_rest.basis.orthonormalized().inverse() \
			* Basis(along, deg_to_rad(_shield_turn_now - SHIELD_BUILT_TURN)) \
			* _figure_skel.get_bone_global_rest(b).basis.orthonormalized()
	var parent := _figure_skel.get_bone_global_pose(_figure_skel.get_bone_parent(b)).basis.orthonormalized()
	_figure_skel.set_bone_pose_rotation(b, (parent.inverse() * turned).get_rotation_quaternion())


## The middle of the curled fingers: the mannequin's (as its clips close
## them round a grip, in its hand bones' frames) and the maker's figure's (in
## its weapon bones' frames), and the line through the mannequin's fist (its
## little finger to its first, the way a blade held in it points).
const MQ_FIST_R := Vector3(-0.028, 0.105, -0.007)
const MQ_FIST_L := Vector3(0.030, 0.105, -0.010)
const MQ_FIST_AXIS := Vector3(-0.02, 0.12, 0.99)
const FIG_FIST_R := Vector3(-0.003, 0.084, -0.021)
const FIG_FIST_L := Vector3(0.003, 0.084, -0.021)


## Two hands on one grip (the great sword, the staff): the clips close the
## mannequin's left fist round the handle, but the figure's arms are its own
## length, so its left fist lands off it. Puts it back: as far along the
## handle from the right fist as the mannequin's is (scaled to the figure's
## arms), the left arm bent onto it (two bones, the elbow kept in its plane).
## Where the clip lets go of the handle (a one-handed blow), it is left alone.
## `tip`, `butt`: the weapon's two ends in the figure's right weapon bone's
## frame. Returns how far the mannequin's own left fist was off its handle.
static func hilt_hand(mq: Skeleton3D, fig: Skeleton3D, tip: Vector3, butt: Vector3) -> float:
	var hr := mq.find_bone("hand_r")
	var hl := mq.find_bone("hand_l")
	var wr := fig.find_bone("weapon_r")
	var sh := fig.find_bone("L_shoulder_joint")
	var el := fig.find_bone("L_elbow_joint")
	var wl := fig.find_bone("L_wrist_joint")
	var held := fig.find_bone("weapon_l")
	if hr < 0 or hl < 0 or wr < 0 or sh < 0 or el < 0 or wl < 0 or held < 0:
		return INF
	var mr := mq.get_bone_global_pose(hr)
	var rf := mr * MQ_FIST_R
	var along := (mr.basis * MQ_FIST_AXIS).normalized()
	var lf := mq.get_bone_global_pose(hl) * MQ_FIST_L
	var s := (lf - rf).dot(along)
	var off := ((lf - rf) - along * s).length()
	var w := 1.0 - smoothstep(0.08, 0.2, off)
	if w <= 0.001:
		return off
	# the figure's arm against the mannequin's, for how far along the grip
	var k := fig.get_bone_global_rest(sh).origin.distance_to(fig.get_bone_global_rest(wl).origin) \
			/ maxf(mq.get_bone_global_rest(mq.find_bone("upperarm_l")).origin.distance_to(mq.get_bone_global_rest(hl).origin), 0.01)
	var g := fig.get_bone_global_pose(wr)
	# as far along from the right fist, on the handle itself
	# (the handle's way as the fist's: its little finger to its first)
	var way := (tip - butt).normalized()
	if way.z < 0.0:
		way = -way
	var want := g * FIG_FIST_R + (g.basis * way).normalized() * s * k
	want = Geometry3D.get_closest_point_to_segment(want, g * butt, g * tip)
	for _pass in 2:
		var a := fig.get_bone_global_pose(sh)
		var b := fig.get_bone_global_pose(el)
		var c := fig.get_bone_global_pose(wl)
		# where the wrist must be for the fist to be on the grip
		var fist := fig.get_bone_global_pose(held) * FIG_FIST_L
		var target := c.origin.lerp(want - (fist - c.origin), w)
		var la := a.origin.distance_to(b.origin)
		var lb := b.origin.distance_to(c.origin)
		var reach := clampf(a.origin.distance_to(target), absf(la - lb) + 0.001, la + lb - 0.001)
		# the elbow opened or closed to the reach
		var bend_axis := (a.origin - b.origin).cross(c.origin - b.origin)
		if bend_axis.length_squared() < 1e-8:
			bend_axis = (b.basis * Vector3.RIGHT)
		bend_axis = bend_axis.normalized()
		var now := (a.origin - b.origin).angle_to(c.origin - b.origin)
		var need := acos(clampf((la * la + lb * lb - reach * reach) / (2.0 * la * lb), -1.0, 1.0))
		var turn_e := Basis(bend_axis, need - now)
		fig.set_bone_pose_rotation(el, (a.basis.orthonormalized().inverse() * turn_e * b.basis.orthonormalized()).get_rotation_quaternion())
		# the whole arm swung from the shoulder onto the target
		var c2 := fig.get_bone_global_pose(wl).origin
		if (c2 - a.origin).length_squared() > 1e-6 and (target - a.origin).length_squared() > 1e-6:
			var swing := Basis(Quaternion((c2 - a.origin).normalized(), (target - a.origin).normalized()))
			var parent := fig.get_bone_global_pose(fig.get_bone_parent(sh)).basis.orthonormalized()
			fig.set_bone_pose_rotation(sh, (parent.inverse() * swing * a.basis.orthonormalized()).get_rotation_quaternion())
	return off


## The figure posed: the left fist put back on a two-handed grip (see
## `hilt_hand()`).
func _hilt(id: StringName) -> void:
	if not _on_mq or _figure_skel == null or not _figs.has(id) or _figs[id]["skel"] != _figure_skel:
		return
	var kind: StringName = moves.get("kind", &"")
	if kind != &"two_hands" and kind != &"spear":
		return
	# the sword away: nothing for the other hand to take hold of
	if _sheath_k > 0.5:
		return
	if _hilt_ends.is_empty():
		var mesh := _figure.find_child("ps_w_" + String(ps_look.get("w", "")), true, false) as MeshInstance3D
		var tip := _far(mesh, &"weapon_r")
		if tip == Vector3.ZERO:
			return
		_hilt_ends = [tip, _far(mesh, &"weapon_r", tip)]
	hilt_hand(_skel, _figure_skel, _hilt_ends[0], _hilt_ends[1])


## Whether the rig is on the mannequin now.
func on_mannequin() -> bool:
	return _on_mq


## The skeleton that moves now: the model's, or the mannequin's while YOUR
## OWN is worn (for whatever reads the feet or the bones: [Footsteps]).
func skeleton_now() -> Skeleton3D:
	return _skel
#endregion


## Wears `look` (see [PolysplitLook]) — at once, if the maker's face is on.
func set_look(look: Dictionary) -> void:
	if polysplit_hero == &"":
		return
	ps_look = PolysplitLook.normalized(look, polysplit_hero)
	if _skel != null and face < faces.size() and faces[face] == CUSTOM:
		_show_figure()
		_apply_moves()
		set_shield(shield_kind)


## The look worn by the maker's face (empty without one).
func get_look() -> Dictionary:
	return ps_look.duplicate(true)


## The arms the figure worn carries: its sword and whichever shield is held,
## and every "<prefix>_arm_*" (knives, a bow) always.
func _show_figure_arms() -> void:
	if _figure == null:
		return
	var prefix := String(figures[figure_faces[faces[face]]["figure"]]["prefix"]) + "_"
	if faces[face] == CUSTOM:
		# the hero's own shield, the one he carries, if the look holds it; the
		# rest is the look's (`PolysplitLook.apply()`)
		var his := String(ps_look.get("o", "")) == "his_shield"
		for key: String in ["shield", "tower_shield"]:
			var mesh := _figure.find_child(prefix + key, true, false) as MeshInstance3D
			if mesh != null:
				mesh.visible = his and shield_kind == (0 if key == "shield" else 1)
		return
	var arms := {"sword": true, "shield": shield_kind == 0, "tower_shield": shield_kind == 1}
	for mesh: MeshInstance3D in _figure.find_children(prefix + "*", "MeshInstance3D", true, false):
		var key := String(mesh.name).trim_prefix(prefix)
		if arms.has(key):
			mesh.visible = arms[key]
		elif key.begins_with("arm_"):
			mesh.visible = not (face_moves.get(faces[face], {}) as Dictionary).get("hide_arms", []).has(key)


## A figure has just been posed off this rig (see [signal
## FigureFollower.followed]); the one worn is `_figure_skel`. For a rig to put
## what hangs off its figure's bones where they now are.
func _on_figure_followed(_id: StringName) -> void:
	pass


## Takes the capes down and hangs them again, each spec in `capes` with its
## look from `looks` laid over it (see `garb_capes`).
func _hang_capes(looks: Array) -> void:
	for cape in cloth_capes:
		cape.queue_free()
	cloth_capes.clear()
	for i in capes.size():
		var look: Dictionary = looks[i] if i < looks.size() else {}
		if look.get("off", false):
			continue
		var spec := (capes[i] as Dictionary).duplicate()
		for key in look:
			spec[key] = look[key]
		var cape := ClothCape.new()
		add_child(cape)
		if cape.setup(_skel, spec):
			cloth_capes.append(cape)
		else:
			cape.queue_free()


func knock_down() -> void:
	_play_action(clips[&"down"], Role.DOWN, 1.4, 0.06)


## Dead: on the mannequin, the death of his look's class (Moveset.DEATHS, each
## class its own, the user's picks); otherwise falling as when knocked down.
## Held there (no getting up out of it).
func die() -> void:
	var clip: StringName = clips[&"down"]
	if _on_mq:
		var own: StringName = Moveset.HERO_DEATHS.get(polysplit_hero,
				Moveset.DEATHS.get(String(ps_look.get("cls", "")), &""))
		if own != &"" and _anim.has_animation(own):
			clip = own
	_play_action(clip, Role.DOWN, float(Moveset.DEATH_RATE.get(clip, 1.0)), 0.08)


func get_up(duration: float) -> void:
	# No stand-up clip in the pack: the fall, played back to front.
	if not _anim.has_animation(clips[&"down"]):
		_end_action()
		return
	var length := _anim.get_animation(clips[&"down"]).length
	_role = Role.GET_UP
	_act_clip = clips[&"down"]
	_action_len = length
	_action_rate = length / maxf(duration, 0.05)
	_action_left = maxf(duration, 0.05)
	_anim.play_backwards(clips[&"down"], 0.1)
	_anim.speed_scale = _action_rate


func leave_ground() -> void:
	if _role == Role.DOWN or _role == Role.GET_UP:
		_end_action()


func is_down() -> bool:
	return _role == Role.DOWN or _role == Role.GET_UP


func slide(active: bool) -> void:
	# No slide in the library; the crouched guard, held, reads well enough at speed.
	_crouching = active
	_sliding = active


func wall_climb(active: bool) -> void:
	_wall_climbing = active
	if active and _role != Role.NONE:
		_end_action()


func climb(duration: float) -> void:
	var clip := _alt(clips[&"mantle"])
	if not _anim.has_animation(clip):
		return
	_play_action(clip, Role.CLIMB, _anim.get_animation(clip).length / maxf(duration, 0.05), 0.06)


func is_crouched() -> bool:
	return _crouching


func is_wall_climbing() -> bool:
	return _wall_climbing


func weapons_slung() -> float:
	return _sheath_k


#region The scabbard
## The sword put away in the scabbard the figure wears, and drawn from it
## (2026-10-03). The scabbard is one of the figure's extras, rigid on one bone
## (the swordsman's on `cape_joint1`, across the back; the fighter's on
## `L_coatTail_joint1`, at the left hip); where the sword sits in it — its
## socket — is worked out off the two meshes when the look is put on
## (`_fit_sheath`). Kevin's clips put it away and draw it, over the back or
## from the hip, whichever the scabbard is; at the moment the hand takes the
## hilt (`grab`, a share of the clip) the sword goes over from the scabbard to
## the hand, or back, in `SHEATH_HANDOFF`. The sword is moved by its bone,
## `weapon_r`, so its mesh and the cut's markers go with it.

## The clips by where the scabbard is: [draw, grab, the share it is played to,
## its rate], [put away, let go, rate]. The grab and let-go are where the hand
## is at the hilt (vepxis-art NOTES 2026-10-03, the hand's path sampled).
const SHEATH_CLIPS := {
	&"back": {"draw": [&"KV_UnsheatheBack01_R", 0.57, 0.8, 1.5], "away": [&"KV_SheatheBack01_R", 0.45, 1.1]},
	&"hips": {"draw": [&"KV_UnsheatheHips01_R", 0.52, 0.8, 1.5], "away": [&"KV_SheatheHips01_R", 0.59, 1.1]},
}
## Seconds the sword takes to go over from the scabbard to the hand or back.
const SHEATH_HANDOFF := 0.08

## Where the sword sits when it is away: {"bone": the scabbard's bone on the
## figure, "at": weapon_r's transform in that bone's frame, "where": &"back" or
## &"hips", "mesh": the scabbard}. Empty when there is nowhere to put it.
var _sheath: Dictionary = {}
## How far the sword is in the scabbard (0 in the hand, 1 away), and where it
## is going.
var _sheath_k: float = 0.0
var _sheath_goal: float = 0.0
## The clip putting it away or drawing it now, and its hand-off share.
var _sheath_clip: StringName = &""
var _sheath_at: float = -1.0
## The clip putting it away or drawing it, kept till it is over (the hand-off
## is done before it ends).
var _sheath_play: StringName = &""


## The mannequin's clips' paces over the ground (m/s at scale 1), as the
## moveset measured them; `ground_speed` is these at the size worn.
var _mq_ground: Dictionary = {}


## The paces at the size the figure is drawn: the model's scale, and how much
## longer the figure's legs are than the mannequin's. The figure's limbs are
## turned as the mannequin's are, so its stride is longer by its legs (its
## hips' height over the mannequin's, [FigureFollower] `_scale`); left out,
## every walk and run played too fast for the ground covered, and the standing
## foot slid back 17-25 % of the pace (`stride_test`, a frame to a tick).
func _scale_ground() -> void:
	if _mq_ground.is_empty():
		return
	var pace := scale.y * _figure_stride()
	for clip: StringName in _mq_ground:
		ground_speed[clip] = float(_mq_ground[clip]) * pace


func _figure_stride() -> float:
	if _figure == null or _figure_skel == null:
		return 1.0
	for id: StringName in _figs:
		if _figs[id]["skel"] == _figure_skel:
			var follow := _figs[id]["follow"] as FigureFollower
			if follow != null and follow._scale > 0.5:
				return follow._scale
	return 1.0


## Whether there is a scabbard to put the sword in.
func can_sheathe() -> bool:
	return not _sheath.is_empty()


## Puts the sword away (`away`) or draws it. Standing or walking, with nothing
## else playing, it is done with the clip; otherwise (in the air, in a move,
## no clip) it is done at once.
func stow_weapons(away: bool) -> void:
	if not can_sheathe():
		_stowed = false
		_sheath_k = 0.0
		_sheath_goal = 0.0
		return
	if away == _stowed:
		return
	_stowed = away
	var spec: Array = (SHEATH_CLIPS[_sheath["where"]] as Dictionary)["away" if away else "draw"]
	var clip: StringName = spec[0]
	if _role != Role.NONE or _airborne_now or not _anim.has_animation(clip):
		_sheath_now(away)
		return
	var rate := float(spec[3] if not away else spec[2])
	var until := float(spec[2]) if not away else 1.0
	if not _play_action(clip, Role.FREE, rate, 0.1, 0.0, until):
		_sheath_now(away)
		return
	walk_under = true
	_sheath_clip = clip
	_sheath_play = clip
	_sheath_at = float(spec[1])


func weapons_stowed() -> bool:
	return _stowed


## Whether the sword is being drawn now (a cut asked for meanwhile waits).
func is_drawing() -> bool:
	return not _stowed and _sheath_play != &"" and _role == Role.FREE and _act_clip == _sheath_play


## How long a draw takes, seconds (0 if the sword is not away to be drawn).
func draw_time() -> float:
	if not _stowed or not can_sheathe():
		return 0.0
	var spec: Array = (SHEATH_CLIPS[_sheath["where"]] as Dictionary)["draw"]
	if not _anim.has_animation(spec[0]):
		return 0.0
	return _anim.get_animation(spec[0]).length * float(spec[2]) / float(spec[3])


## The sword where it is asked to be, now.
func _sheath_now(away: bool) -> void:
	_stowed = away and can_sheathe()
	_sheath_goal = 1.0 if _stowed else 0.0
	_sheath_k = _sheath_goal
	_sheath_clip = &""


## Each frame: the hand reaching the hilt hands the sword over; a clip broken
## off before that leaves it where it was asked to be.
func _sheath_tick(delta: float) -> void:
	if _sheath_clip != &"":
		if _role != Role.FREE or _act_clip != _sheath_clip:
			_sheath_now(_stowed)
		elif _progress() >= _sheath_at:
			_sheath_goal = 1.0 if _stowed else 0.0
			_sheath_clip = &""
	_sheath_k = move_toward(_sheath_k, _sheath_goal, delta / SHEATH_HANDOFF)


## Once the figure is posed: the sword's bone laid in the scabbard, as far as
## it has gone over.
func _hold_sheathed(id: StringName) -> void:
	if _sheath_k <= 0.0 or _sheath.is_empty() or _figure_skel == null or not _figs.has(id) \
			or _figs[id]["skel"] != _figure_skel:
		return
	var w := _figure_skel.find_bone("weapon_r")
	if w < 0:
		return
	var want: Transform3D = _figure_skel.get_bone_global_pose(int(_sheath["bone"])) * (_sheath["at"] as Transform3D)
	var hand := _figure_skel.get_bone_global_pose(w)
	var g := hand.interpolate_with(want, _sheath_k)
	var p := _figure_skel.get_bone_parent(w)
	var local := (_figure_skel.get_bone_global_pose(p) if p >= 0 else Transform3D()).affine_inverse() * g
	_figure_skel.set_bone_pose_rotation(w, local.basis.get_rotation_quaternion())
	_figure_skel.set_bone_pose_position(w, local.origin)


## The socket for the sword in hand in the scabbard the look wears, or none:
## a blade in the sword hand, nothing that cuts in the other, a scabbard worn.
## Of the scabbards worn, the one whose length is nearest the blade's.
func _fit_sheath(custom: bool) -> void:
	_sheath = {}
	if custom and _figure != null and _figure_skel != null and _on_mq:
		var w := String(ps_look.get("w", ""))
		var o := String(ps_look.get("o", ""))
		var sword := _figure.find_child("ps_w_" + w, true, false) as MeshInstance3D
		if PolysplitLook.sheathes(w) and not PolysplitLook.cuts(o) and sword != null:
			var blade := Sheath.blade(sword, _figure_skel, &"weapon_r")
			var best := INF
			for x: Variant in ps_look.get("extras", []):
				var id := String(x)
				if not id.contains("scabbard"):
					continue
				var mesh := _figure.find_child("ps_" + PolysplitLook.extra_key(ps_look, id), true, false) as MeshInstance3D
				Sheath.put_mouth_over_sword_shoulder(mesh, _figure_skel)
				var socket := Sheath.socket(mesh, _figure_skel, blade)
				if socket.is_empty():
					continue
				var miss := absf(float(socket["length"]) - float(blade["length"]))
				if miss < best:
					best = miss
					_sheath = socket
	if _sheath.is_empty():
		_sheath_now(false)
	else:
		_sheath_k = 1.0 if _stowed else 0.0
		_sheath_goal = _sheath_k
#endregion


## Plays `clip` from `from` to `until` (shares of its length) at `rate`, as a
## free action. Returns how long that takes (0 without the clip).
func play_part(clip: StringName, rate: float, from: float = 0.0, until: float = 1.0,
		blend: float = -1.0) -> float:
	if _anim == null or not _play_action(clip, Role.FREE, rate, blend, from, until):
		return 0.0
	return _anim.get_animation(clip).length * (until - from) / maxf(rate, 0.01)


## Where `bone` is in the world right now.
func bone_position(bone: StringName) -> Vector3:
	# On the mannequin what is seen is the figure on it: its own bone, where
	# there is one of the name (the head is "head_joint" on it), or the
	# mannequin's ("head" is "Head" there). Asked for "head" in the hero
	# select, the mannequin had none and the camera went to the belly.
	if _on_mq and _figure_skel != null:
		for name: StringName in [bone, StringName(String(bone) + "_joint")]:
			var j := _figure_skel.find_bone(name)
			if j >= 0:
				return _figure_skel.global_transform * _figure_skel.get_bone_global_pose(j).origin
	if _skel != null and _skel.find_bone(bone) < 0 and _skel.find_bone(String(bone).capitalize()) >= 0:
		bone = StringName(String(bone).capitalize())
	if _skel != null:
		var i := _skel.find_bone(bone)
		if i >= 0:
			return _skel.global_transform * _skel.get_bone_global_pose(i).origin
	return global_position + Vector3.UP * 1.2


func play_clip(clip: StringName, fade: float = -1.0, speed: float = 1.0) -> bool:
	return _play_action(clip, Role.FREE, speed, fade)


func hold_clip(clip: StringName, through: float) -> bool:
	if not _play_action(clip, Role.FREE, 1.0, 0.0, through):
		return false
	_anim.speed_scale = 0.0
	_action_left = INF
	return true


func current_clip() -> StringName:
	return _act_clip


func clip_weight() -> float:
	return 1.0 if _role != Role.NONE else 0.0


func clip_names() -> PackedStringArray:
	return _anim.get_animation_list() if _anim != null else PackedStringArray()


func has_clips() -> bool:
	return _anim != null
#endregion
