class_name OrcWarrior
extends Brute

## The orc warrior: twice Tariel's height, an axe in his right fist, and his
## own clips for every move he makes.
##
## His clips are Mixamo's axe set, retargeted onto his rig in Blender
## (`tools/retarget_orc.py` in the art folder) and baked into
## `assets/orc/orc_axe.glb`: an axe idle, a walk and a run, a guard, six blows,
## three combos, a kick, a running leap, a battle cry and a death. He used to
## borrow the mannequin library's sword swings through [RigRetarget]; an axe
## swung like a sword never looked like an axe.
##
## * **Attacks.** Close in: a single blow (horizontal, backhand or overhead), a
##   combo of two or three blows, the kick, or the spin — the one that catches
##   anyone standing beside or behind him. The overhead blow is also his heavy:
##   it goes into the ground, and the earth splits ahead of it in a run of
##   stone spikes. Further off he runs and leaps, and lands with the same slam.
##   The blows land where his right hand moves fastest in each clip, measured
##   off it once. Only a combo that lands every blow knocks a player down.
## * **The battle cry.** The first time he sees someone he stops and roars.
## * **The guard.** Only an archer makes him cover his face: while a player
##   with a bow is drawing on him he raises his axe across himself (the guard
##   clip, laid over his upper body while his legs keep walking) and an arrow
##   does `guard_factor` of its damage.
## * **The axe** is the village's, set in his fist by a grip read off his own
##   mesh: where the fist's vertices gather, and the line their knuckles make.
## * **The chains.** Besides the combos Mixamo ships, three long ones of his
##   own: clips run together in Blender (`tools/orc_chains.py`), each cut short
##   of its settle and cross-faded into the next — a combo into the spin, three
##   blows ending in the overhead, a kick into a combo. He steps in behind them
##   while they last, and a chain that ends overhead ends in the slam.
## * **The cut in the air.** A [BladeArc] follows the axe's head whenever it
##   moves fast in an attack.
##
## **The great-axe orc** (`great_axe`, scenes/enemies/orc_greataxe.tscn) is the
## same warrior with a topknot and a braid, and a double-bitted axe held in both
## fists: Mixamo's great-sword set (`tools/great_axe.py`), with the left arm
## solved onto the haft every frame and the axe skinned to a `weapon_axe` bone,
## so it comes with the rig rather than being placed here. His braid swings on
## spring bones. Everything else — the acts, the slam, the guard — is shared,
## played from his own clips (see `GREAT_ACTS`).

enum Act {
	NONE = 0, SWING = 1, COMBO = 2, HEAVY = 3, KICK = 4, SPIN = 5, LEAP = 6, ROAR = 7,
	BACKHAND = 8, COMBO_THREE = 9, COMBO_SHORT = 10,
	CHAIN_A = 11, CHAIN_B = 12, CHAIN_C = 13,
	REACT_MARK = 40, REACT_KNOCK = 41, REACT_BURN = 42, REACT_POISON = 43, DEAD = 99,
}

## How he takes the heroes' skills: act -> clips played one after another,
## each [clip, rate, share of it played]. From Mixamo (vepxis-art/mixamo_skills,
## RX_*), in both his glbs.
const REACTS := {
	Act.REACT_MARK: [[&"RX_Flinch", 1.3, 0.7], [&"OR_Mutant_Roar", 1.15, 1.0]],
	Act.REACT_KNOCK: [[&"RX_Falling_Down", 1.15, 1.0], [&"RX_Getting_Up", 1.25, 1.0]],
	Act.REACT_BURN: [[&"RX_Swat_Bugs", 1.2, 0.55], [&"RX_Agony_Head", 1.1, 0.5]],
	Act.REACT_POISON: [[&"RX_Injured_Stumble", 1.0, 0.45]],
}
const REACT_OF := {
	# The hunter's mark is only laid on: no reaction to it (the user's call).
	&"knock": Act.REACT_KNOCK, &"burn": Act.REACT_BURN,
	&"poison": Act.REACT_POISON,
}

## The clips, by what they are for.
const IDLE := &"OR_Axe_Idle"
const CALM_IDLE := &"OR_Orc_Idle"
const CALM_WALK := &"OR_Orc_Walk"
const WALK := &"OR_Axe_Walk"
const RUN := &"OR_Mutant_Run"
const GUARD := &"OR_Block_Idle"
const SWING_CLIP := &"OR_Attack_Horizontal"
const HEAVY_CLIP := &"OR_Attack_Downward"
const DEATH_CLIP := &"OR_Death"
## act -> [clip, how many blows it lands, rate, whether its last blow is the
## overhead that slams into the ground]
const ACTS := {
	Act.SWING: [&"OR_Attack_Horizontal", 1, 1.15],
	Act.BACKHAND: [&"OR_Attack_Backhand", 1, 1.15],
	Act.HEAVY: [&"OR_Attack_Downward", 1, 1.05],
	Act.COMBO: [&"OR_Combo_1", 2, 1.1],
	Act.COMBO_THREE: [&"OR_Combo_2", 3, 1.1],
	Act.COMBO_SHORT: [&"OR_Combo_3", 2, 1.1],
	Act.KICK: [&"OR_Kick", 1, 1.2],
	Act.SPIN: [&"OR_Attack_360", 1, 1.15],
	Act.LEAP: [&"OR_Run_Jump_Attack", 1, 1.15],
	Act.ROAR: [&"OR_Battlecry", 0, 1.1],
	Act.CHAIN_A: [&"OR_Chain_Berserk", 3, 1.15],
	Act.CHAIN_B: [&"OR_Chain_Breaker", 3, 1.1, true],
	Act.CHAIN_C: [&"OR_Chain_Brawler", 3, 1.15],
	Act.DEAD: [&"OR_Death", 0, 1.0],
}
const LOOPS: Array[StringName] = [
	&"OR_Axe_Idle", &"OR_Orc_Idle", &"OR_Orc_Walk", &"OR_Axe_Walk", &"OR_Axe_Run", &"OR_Mutant_Run",
	&"OR_Block_Idle",
]

## The great-axe orc's clips.
const GREAT_CLIPS := {
	&"idle": &"GA_Idle", &"calm_idle": &"OR_Mutant_Breathing_Idle", &"calm_walk": &"GA_Walk",
	&"walk": &"GA_Walk", &"run": &"GA_Run", &"guard": &"GA_Block_Idle", &"death": &"OR_Death",
}
const GREAT_ACTS := {
	Act.SWING: [&"GA_Power_Slash", 1, 1.1],
	Act.BACKHAND: [&"GA_Low_Slash", 1, 1.1],
	Act.HEAVY: [&"GA_Downward_Slash", 1, 1.0],
	Act.COMBO: [&"GA_Combo_Slash", 3, 1.1],
	Act.COMBO_THREE: [&"GA_Combo_Slash", 3, 1.2],
	Act.COMBO_SHORT: [&"GA_Chain_Crush", 2, 1.1, true],
	Act.KICK: [&"GA_Spin_Kick", 1, 1.15],
	Act.SPIN: [&"GA_High_Spin_Attack", 1, 1.1],
	Act.LEAP: [&"GA_Jump_Attack", 1, 1.1],
	Act.ROAR: [&"OR_Mutant_Roar", 0, 1.15],
	Act.CHAIN_A: [&"GA_Chain_Fury", 4, 1.1],
	Act.CHAIN_B: [&"GA_Chain_Crush", 2, 1.05, true],
	Act.CHAIN_C: [&"GA_Chain_Reaper", 3, 1.1, true],
	Act.DEAD: [&"OR_Death", 0, 1.0],
}
const GREAT_LOOPS: Array[StringName] = [
	&"GA_Idle", &"OR_Mutant_Breathing_Idle", &"GA_Walk", &"GA_Run", &"GA_Block_Idle",
]
const CHAINS: Array[int] = [Act.CHAIN_A, Act.CHAIN_B, Act.CHAIN_C]

## What the guard moves while his legs walk.
const GUARD_BONES: PackedStringArray = [
	"Spine01", "Spine", "neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand", "weapon_axe",
]
## The grip in his right hand's own frame: the middle of the fist, and the turn
## that runs the haft along the knuckles with the blade out. Read off the mesh
## once, in the bestiary.
const FIST_LOCAL := Vector3(-0.65376, 13.47461, 0.47799)
const GRIP := Quaternion(-0.48301, -0.78505, 0.31603, 0.22476)
## Held a little way up the haft, so the fist closes round wood.
const AXE_DROP := 0.18
## The head of the axe, in the axe's own frame: where the slam lands.
const AXE_HEAD := Vector3(0.12, 0.62, 0.0)
const AXE_SCENE := "res://unverified/assets/area/HighLandsFantasyBuildings/MiscProps/SM_Axe.fbx"
const AXE_TEXTURES := "res://unverified/assets/area/HighLandsFantasyBuildings/MiscProps/TextureMaps"
## The stretch of the village axe the cut in the air is drawn along, in the
## axe's own frame: up the haft to the far corner of the bit.
const ARC_BASE := Vector3(0.0, 0.3, 0.0)
const ARC_TIP := Vector3(0.16, 0.68, 0.0)
## The same on the great axe, in its bone's frame (centimetres, Y up the haft):
## from below the bits to the top spike.
const GREAT_ARC_BASE := Vector3(0.0, 38.0, 0.0)
const GREAT_ARC_TIP := Vector3(0.0, 84.0, 0.0)
const GREAT_AXE_HEAD := Vector3(0.0, 62.0, 0.0)
## The axe as its blows see it ([WeaponSweep]): the haft from the fist up to the
## head, and the head out to the far corner of the bit, each a capsule this
## thick — in the axe's own units (the village axe's, and the great axe's
## centimetres).
const HAFT_RADIUS := 0.035
const BIT_RADIUS := 0.08
const GREAT_HAFT_RADIUS := 3.0
const GREAT_BIT_RADIUS := 20.0
## A foot in the kick, in metres.
const FOOT_RADIUS := 0.2
## How long either side of the moment his hand moves fastest a blow is live,
## in seconds: the swing coming through, and a little of its follow-through.
const BLOW_BEFORE := 0.16
const BLOW_AFTER := 0.12
## The spin carries the axe right round him, the kick is a leg's whole swing,
## and the overhead is the axe coming all the way down.
const SPIN_BEFORE := 0.35
const SPIN_AFTER := 0.3
const KICK_BEFORE := 0.22
const KICK_AFTER := 0.15
const OVERHEAD_BEFORE := 0.28
const OVERHEAD_AFTER := 0.06
## Slower than this at the bit, metres a second, the axe is only being carried.
const CUTTING_SPEED := 4.0
## Around where the overhead hits the ground, the stones that burst up.
const SLAM_BURST := 0.9

## Two-handed, the great-sword clips and the double-bitted axe (see above).
@export var great_axe: bool = false

@export_group("Attack")
@export var reach: float = 2.7
## A raid boss: every blow of his is enough to kill a player outright.
@export var swing_damage: float = 115.0
@export var combo_damage: float = 115.0
@export var heavy_damage: float = 170.0
@export var slam_damage: float = 170.0
@export var kick_damage: float = 115.0
@export var spin_damage: float = 170.0
@export var leap_damage: float = 190.0
## How fast he covers the ground in the leap, metres a second.
@export var leap_speed: float = 7.0
## The run of spikes out of the ground after the slam: its length, how much
## wider and taller than the bestiary's it is drawn, and what it does.
@export var wave_length: float = 9.0
@export var wave_size: float = 1.25
@export var wave_damage: float = 190.0
## How far off he may open with the leap, for it to land on somebody.
@export var slam_range: float = 9.0
## How fast he walks in behind a chain, to stay on whoever backs off from it.
@export var chain_advance: float = 2.2
## How far from him his axe really lands (measured: 3.1 to 4 m round him), and
## his foot in the kick. He opens from further off than that (`reach`), so up
## to each blow he steps in — no faster than `close_speed` — until whoever he
## is after is this far off: a blow thrown from too far away is a miss.
@export var strike_reach: float = 2.9
@export var kick_reach: float = 1.6
@export var close_speed: float = 3.6
## His clips were made for a man's height. Twice that, his flat swings would
## sail over a man's head — and now that a blow has to touch, they would miss —
## so around each blow he stoops into it: this far forward at the waist, in
## degrees, bringing the axe down to a man's chest.
@export var stoop: float = 17.0
## How long either side of a blow the stoop takes to come and go, seconds.
@export var stoop_ease: float = 0.35
## His ground is the water his camp stands in — all of it, shore to shore —
## rather than a ring round the camp: he follows anyone in it, and lets go of
## whoever climbs out.
@export var holds_the_water: bool = true

@export_group("Looks")
## How fast the axe head must be going, metres a second, to cut the air.
@export var arc_speed: float = 10.0

@export_group("Guard")
@export_range(0.0, 1.0) var guard_factor: float = 0.35
@export var threat_range: float = 45.0
@export var threat_cone: float = 20.0
## How long the axe stays up after the draw ends — the arrow is in the air.
@export var guard_linger: float = 0.6
## Share of his chase pace while he comes on behind his guard.
@export var guard_pace: float = 0.6

## Replicated.
var guarding: bool = false

var _skeleton: Skeleton3D
var _own: AnimationPlayer
var _hand: int = -1
var _hips: int = -1
var _hips_rest := Vector3.ZERO
var _axe: Node3D
## Own clip -> ground covered a second at rate 1.
var _natural: Dictionary = {}
## act -> when its blows land, as shares of the clip.
var _blows: Dictionary = {}
var _slam_at: float = -1.0
var _blows_done: int = 0
var _slammed: bool = false
## Where the last slam came down, for anything checking it.
var _slam_point := Vector3.ZERO
var _threat: float = 0.0
var _ranged_try: float = 0.0
var _roared: bool = false
## The guard clip's rotation tracks for the upper body: [track, bone].
var _guard_tracks: Array[Vector2i] = []
var _guard_time: float = 0.0
## This warrior's acts and clips: [ACTS] and the axe-and-fist set, or the
## great axe's.
var _acts: Dictionary = ACTS
var _idle: StringName = IDLE
var _calm_idle: StringName = CALM_IDLE
var _calm_walk: StringName = CALM_WALK
var _walk: StringName = WALK
var _run: StringName = RUN
var _guard: StringName = GUARD
var _death: StringName = DEATH_CLIP
## Where the slam lands from.
var _head_mark: Node3D
var _arc: BladeArc
var _arc_tip: Node3D
var _arc_last := Vector3.ZERO
## The water that is his ground (a node with `in_mere()`), found once.
var _water: Node
var _water_found: bool = false
## The bones the reel from a parry bends, and how far into it he is.
var _reel_bones: Dictionary = {}
var _reel_clock: float = 0.0


func _ready() -> void:
	super()
	roar_sound = "res://unverified/sounds/orc/roar_1.wav"
	_skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	_own = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null or _own == null:
		push_warning("Orc '%s': no skeleton or no clips." % name)
		return
	_hand = _skeleton.find_bone("RightHand")
	_hips = _skeleton.find_bone("Hips")
	if _hips >= 0:
		_hips_rest = _skeleton.get_bone_rest(_hips).origin
	_own.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if great_axe:
		_acts = GREAT_ACTS
		_idle = GREAT_CLIPS[&"idle"]
		_calm_idle = GREAT_CLIPS[&"calm_idle"]
		_calm_walk = GREAT_CLIPS[&"calm_walk"]
		_walk = GREAT_CLIPS[&"walk"]
		_run = GREAT_CLIPS[&"run"]
		_guard = GREAT_CLIPS[&"guard"]
		_death = GREAT_CLIPS[&"death"]
	for clip in (GREAT_LOOPS if great_axe else LOOPS):
		if _own.has_animation(clip):
			_own.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in [_calm_walk, _walk, _run]:
		if _own.has_animation(clip):
			_natural[clip] = _measure_pace(clip)
	for what: int in _acts:
		var spec: Array = _acts[what]
		if int(spec[1]) > 0:
			_blows[what] = _measure_blows(spec[0], int(spec[1]))
	_slam_at = (_blows[Act.HEAVY] as PackedFloat32Array)[0] if _blows.has(Act.HEAVY) else 0.5
	_find_guard_tracks()
	_reel_bones = Recoil.bones_of(_skeleton)
	_own.play(_calm_idle if _own.has_animation(_calm_idle) else _idle)
	_own.advance(0.0)
	if great_axe:
		_mount_great_axe()
		_make_braid()
	else:
		_make_axe()
	_make_arc()


## Metres a second one of his own cycles would carry him at rate 1: two
## steps, a step being as far apart as his feet get.
func _measure_pace(clip: StringName) -> float:
	var anim := _own.get_animation(clip)
	var left := _skeleton.find_bone("LeftFoot")
	var right := _skeleton.find_bone("RightFoot")
	if anim == null or anim.length <= 0.0 or left < 0 or right < 0:
		return 1.5
	var widest := 0.0
	_own.play(clip)
	for i in 24:
		_own.seek(anim.length * float(i) / 24.0, true)
		var gap := _skeleton.get_bone_global_pose(left).origin - _skeleton.get_bone_global_pose(right).origin
		gap.y = 0.0
		widest = maxf(widest, gap.length())
	_own.stop()
	# The skeleton is in centimetres under the armature's 0.01.
	var metres := widest * 2.0 * 0.01 * visual_scale
	return maxf(metres / anim.length, 0.3)


## When the `count` blows of a clip land, as shares of its length: the moments
## his right hand moves fastest, the strongest `count` of them, in order.
func _measure_blows(clip: StringName, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var anim := _own.get_animation(clip) if _own.has_animation(clip) else null
	if anim == null or _hand < 0:
		for i in count:
			out.append((i + 1.0) / (count + 1.0))
		return out
	var samples := 90
	var at: Array[Vector3] = []
	_own.play(clip)
	for i in samples + 1:
		_own.seek(anim.length * float(i) / samples, true)
		at.append(_skeleton.get_bone_global_pose(_hand).origin)
	_own.stop()
	var speed := PackedFloat32Array()
	for i in samples:
		speed.append(at[i + 1].distance_to(at[i]))
	# Local maxima, strongest first, at least a sixth of a second apart.
	var peaks: Array[Vector2] = []
	for i in range(1, samples - 1):
		if speed[i] >= speed[i - 1] and speed[i] >= speed[i + 1]:
			peaks.append(Vector2((float(i) + 0.5) / samples, speed[i]))
	peaks.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	var gap := (1.0 / 6.0) / maxf(anim.length, 0.01)
	var chosen: Array[float] = []
	for p in peaks:
		var clear := true
		for c in chosen:
			if absf(c - p.x) < gap:
				clear = false
				break
		if clear:
			chosen.append(p.x)
		if chosen.size() == count:
			break
	chosen.sort()
	for c in chosen:
		out.append(c)
	while out.size() < count:
		out.append((out.size() + 1.0) / (count + 1.0))
	return out


func _find_guard_tracks() -> void:
	if not _own.has_animation(_guard):
		return
	var anim := _own.get_animation(_guard)
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(anim.track_get_path(t).get_concatenated_subnames())
		if bone_name in GUARD_BONES:
			var bone := _skeleton.find_bone(bone_name)
			if bone >= 0:
				_guard_tracks.append(Vector2i(t, bone))


func _make_axe() -> void:
	if not ResourceLoader.exists(AXE_SCENE):
		return
	_axe = Node3D.new()
	_axe.name = "Axe"
	_axe.top_level = true
	var model := (load(AXE_SCENE) as PackedScene).instantiate() as Node3D
	model.position = Vector3.DOWN * AXE_DROP
	_axe.add_child(model)
	var material := Building._material_for(AXE_TEXTURES, "Props")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if material != null and mesh.mesh != null:
			for s in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(s, material)
	var head := Marker3D.new()
	head.name = "Head"
	head.position = AXE_HEAD + Vector3.DOWN * AXE_DROP
	_axe.add_child(head)
	_head_mark = head
	_mark_edge(_axe, Vector3.ZERO, ARC_BASE + Vector3.DOWN * AXE_DROP, ARC_TIP + Vector3.DOWN * AXE_DROP)
	add_child(_axe)
	_place_axe()


## The great axe is in the model already, skinned to `weapon_axe`; this only
## hangs the marks off that bone.
func _mount_great_axe() -> void:
	if _skeleton.find_bone("weapon_axe") < 0:
		return
	var mount := BoneAttachment3D.new()
	mount.name = "GreatAxeMount"
	_skeleton.add_child(mount)
	mount.bone_name = "weapon_axe"
	var head := Marker3D.new()
	head.name = "Head"
	head.position = GREAT_AXE_HEAD
	mount.add_child(head)
	_head_mark = head
	_mark_edge(mount, Vector3.ZERO, GREAT_ARC_BASE, GREAT_ARC_TIP)


## The three marks the axe's blows are measured between: the fist, where the
## head starts, and the far corner of the bit.
var _hit_marks: Array[Node3D] = []


func _mark_edge(holder: Node3D, grip: Vector3, neck: Vector3, tip: Vector3) -> void:
	_hit_marks.clear()
	for at in [grip, neck, tip]:
		var mark := Marker3D.new()
		mark.name = "Hit%d" % _hit_marks.size()
		mark.position = at
		holder.add_child(mark)
		_hit_marks.append(mark)


## The axe as it is this frame, for a [WeaponSweep].
func _axe_parts() -> Array:
	if _hit_marks.size() < 3:
		# No axe: his right forearm and fist.
		return [WeaponSweep.bones(_skeleton, _skeleton.find_bone("RightForeArm"), _hand, 0.3)]
	var haft := GREAT_HAFT_RADIUS if great_axe else HAFT_RADIUS
	var bit := GREAT_BIT_RADIUS if great_axe else BIT_RADIUS
	return [
		WeaponSweep.between(_hit_marks[0], _hit_marks[1], haft),
		WeaponSweep.between(_hit_marks[1], _hit_marks[2], bit),
	]


## Both legs from the knee to the toes, for the kick.
func _feet_parts() -> Array:
	var out := []
	for side in ["Left", "Right"]:
		var knee := _skeleton.find_bone(side + "Leg")
		var ankle := _skeleton.find_bone(side + "Foot")
		var toe := _skeleton.find_bone(side + "ToeBase")
		if knee < 0 or ankle < 0 or toe < 0:
			continue
		out.append(WeaponSweep.bones(_skeleton, knee, ankle, FOOT_RADIUS))
		out.append(WeaponSweep.bones(_skeleton, ankle, toe, FOOT_RADIUS))
	return out


## The cut in the air, laid along the axe's head.
func _make_arc() -> void:
	var holder: Node3D = _axe
	var base_at := ARC_BASE + Vector3.DOWN * AXE_DROP
	var tip_at := ARC_TIP + Vector3.DOWN * AXE_DROP
	if great_axe:
		holder = _head_mark.get_parent() as Node3D if _head_mark != null else null
		base_at = GREAT_ARC_BASE
		tip_at = GREAT_ARC_TIP
	if holder == null:
		return
	var base := Marker3D.new()
	base.name = "ArcBase"
	base.position = base_at
	holder.add_child(base)
	_arc_tip = Marker3D.new()
	_arc_tip.name = "ArcTip"
	_arc_tip.position = tip_at
	holder.add_child(_arc_tip)
	_arc = BladeArc.new()
	_arc.name = "BladeArc"
	_arc.life = 0.22
	_arc.taper = 0.7
	_arc.intensity = 0.9
	_arc.glow_color = Color(0.86, 0.88, 0.92)
	add_child(_arc)
	_arc.setup(base, _arc_tip)


## The braid, on spring bones, so it swings as he runs and swings.
func _make_braid() -> void:
	if _skeleton.find_bone("hair_00") < 0 or _skeleton.find_bone("hair_03") < 0:
		return
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Braid"
	_skeleton.add_child(sim)
	sim.set_setting_count(1)
	sim.set_root_bone_name(0, &"hair_00")
	sim.set_end_bone_name(0, &"hair_03")
	sim.set_extend_end_bone(0, true)
	sim.set_end_bone_length(0, 10.0)
	sim.set_stiffness(0, 0.9)
	sim.set_drag(0, 0.45)
	sim.set_gravity(0, 0.6)


func _place_axe() -> void:
	if _axe == null or _skeleton == null or _hand < 0:
		return
	var hand := _skeleton.get_bone_global_pose(_hand)
	var frame := _skeleton.global_transform
	var fist := frame * (hand * FIST_LOCAL)
	var turn := frame.basis.get_rotation_quaternion() * hand.basis.get_rotation_quaternion() * GRIP
	_axe.global_transform = Transform3D(Basis(turn.normalized()).scaled(Vector3.ONE * visual_scale), fist)


## Where the slam lands, on the ground.
func axe_head() -> Vector3:
	var at := _head_mark.global_position if _head_mark != null else global_position + _forward() * reach
	at.y = global_position.y + 0.03
	return at


func clip_length(clip: StringName) -> float:
	return _own.get_animation(clip).length if _own != null and _own.has_animation(clip) else 1.0


#region Deciding
func _physics_process(delta: float) -> void:
	_watch_archers(delta)
	super(delta)


## Is anybody drawing a bow on him?
func _watch_archers(delta: float) -> void:
	_threat = maxf(_threat - delta, 0.0)
	if is_dead:
		guarding = false
		return
	var cone := cos(deg_to_rad(threat_cone))
	for node in get_tree().get_nodes_in_group("player"):
		var archer := node as Player
		if archer == null or not archer.has_bow():
			continue
		if not (archer.is_drawing() or archer.net_draw > 0.0):
			continue
		var to_me := global_position - archer.global_position
		to_me.y = 0.0
		var gap := to_me.length()
		if gap > threat_range or gap < 0.3:
			continue
		var aimed := archer.target == self
		if not aimed:
			var facing := -archer.global_transform.basis.z
			facing.y = 0.0
			aimed = facing.normalized().dot(to_me / gap) >= cone
		if aimed:
			_threat = guard_linger
	guarding = _threat > 0.0 and act == ACT_NONE


func _arrow_factor(_from: Node3D) -> float:
	return guard_factor if guarding else 1.0


func _move_towards(point: Vector3, pace: float, delta: float) -> void:
	super(point, pace * (guard_pace if guarding else 1.0), delta)


func _stand_off() -> float:
	return reach * 0.8


func _holds(point: Vector3) -> bool:
	var water := _home_water()
	if water != null:
		return bool(water.call("in_mere", Vector2(point.x, point.z)))
	return super(point)


## The first mere up the tree whose water his camp stands in.
func _home_water() -> Node:
	if _water_found or not holds_the_water:
		return _water
	_water_found = true
	var at := get_parent()
	while at != null:
		for child in at.get_children():
			if child.has_method("in_mere") and bool(child.call("in_mere", Vector2(camp_centre.x, camp_centre.z))):
				_water = child
				return _water
		at = at.get_parent()
	return null


## The first sight of somebody: a roar before the chase.
func _rouse(who: Node3D) -> void:
	var was_idle := mode == Mode.GUARD
	super(who)
	var cry: StringName = _acts[Act.ROAR][0]
	if was_idle and not _roared and not is_dead and act == ACT_NONE and _decides() \
			and _own != null and _own.has_animation(cry):
		_roared = true
		_begin(Act.ROAR, cry, float(_acts[Act.ROAR][2]))


func _choose_attack(gap: float) -> void:
	if _own == null:
		return
	if gap <= reach:
		var roll := _rng.randf()
		var behind := _someone_behind()
		if behind and roll < 0.6:
			_open(Act.SPIN)
		elif gap < reach * 0.45 and roll < 0.2:
			_open(Act.KICK)
		elif roll < 0.3:
			_open([Act.SWING, Act.BACKHAND][_rng.randi() % 2])
		elif roll < 0.55:
			_open([Act.COMBO, Act.COMBO_THREE, Act.COMBO_SHORT][_rng.randi() % 3])
		elif roll < 0.85:
			_open(CHAINS[_rng.randi() % CHAINS.size()])
		else:
			_open(Act.HEAVY)
		return
	# Further off, now and then, the running leap.
	_ranged_try -= get_physics_process_delta_time()
	if gap < slam_range and gap > reach + 1.5 and _ranged_try <= 0.0:
		_ranged_try = 2.5
		if _rng.randf() < 0.4:
			_open(Act.LEAP)


## Anyone near enough to hit but not in front of him.
func _someone_behind() -> bool:
	var ahead := _players_ahead(reach + 0.6, 0.3)
	for who in _players_near(global_position, reach + 0.6):
		if not ahead.has(who):
			return true
	return false


func _open(what: int) -> void:
	var spec: Array = _acts[what]
	_begin(what, spec[0], float(spec[2]))


func _begin(what: int, clip: StringName, rate: float) -> void:
	_blows_done = 0
	_slammed = false
	_start(what, clip_length(clip) / maxf(rate, 0.05))
	_arm_blows(what)


## Every blow of the act just begun, as the axe (or the foot) it is: each one
## lands only on whoever it actually passes through, around the moment his hand
## moves fastest.
func _arm_blows(what: int) -> void:
	if not _blows.has(what) or _skeleton == null:
		return
	var at: PackedFloat32Array = _blows[what]
	var spec: Array = _acts[what]
	var count := at.size()
	var combo := what == Act.COMBO or what == Act.COMBO_THREE or what == Act.COMBO_SHORT \
			or what in CHAINS
	_slam_sweep = null
	for i in count:
		var moment := at[i] * _act_length
		var overhead := what == Act.HEAVY or what == Act.LEAP \
				or (spec.size() > 3 and bool(spec[3]) and i == count - 1)
		var sweep: WeaponSweep
		if what == Act.KICK:
			sweep = _sweep(_feet_parts, CUTTING_SPEED * 0.75, moment - KICK_BEFORE, moment + KICK_AFTER,
					func(who: Node3D) -> void: _floor(who, kick_damage))
		elif what == Act.SPIN:
			sweep = _sweep(_axe_parts, CUTTING_SPEED, moment - SPIN_BEFORE, moment + SPIN_AFTER,
					func(who: Node3D) -> void: _floor(who, spin_damage))
		elif overhead:
			var damage := leap_damage if what == Act.LEAP else slam_damage
			sweep = _sweep(_axe_parts, CUTTING_SPEED, moment - OVERHEAD_BEFORE, moment + OVERHEAD_AFTER,
					func(who: Node3D) -> void: _floor(who, damage))
			_slam_sweep = sweep
		else:
			var damage := combo_damage if combo else swing_damage
			# A single blow is sent as the first of two: it never floors.
			var blows := count if combo else 2
			var index := i
			sweep = _sweep(_axe_parts, CUTTING_SPEED, moment - BLOW_BEFORE, moment + BLOW_AFTER,
					func(who: Node3D) -> void: _hit(who, damage, index, blows))


## A skill landing: the orc's own reactions. Only a knock stops what he is
## doing; the rest wait for him to be free.
func _react(kind: StringName) -> void:
	if kind == &"stun":
		# Stunned: he reels where he stands, as from a parry.
		if act != Act.REACT_KNOCK:
			_reel()
		return
	if not REACT_OF.has(kind):
		return
	var what: int = REACT_OF[kind]
	if kind != &"knock" and act != ACT_NONE:
		return
	var total := 0.0
	for seg: Array in REACTS[what]:
		if _own == null or not _own.has_animation(seg[0]):
			return
		total += clip_length(seg[0]) * float(seg[2]) / float(seg[1])
	_start(what, total)


## Knocked down he is open, as when reeling from a parry.
func _reel_act() -> bool:
	return act == Act.REACT_KNOCK


func _turn_while_acting() -> float:
	if REACTS.has(act):
		return 0.0
	if act == Act.LEAP:
		return 0.9
	return 0.5 if act in CHAINS else 0.3


func _run_act(delta: float) -> bool:
	if act == Act.LEAP:
		# Runs and leaps until the blow comes down, then plants.
		var blows: PackedFloat32Array = _blows.get(Act.LEAP, PackedFloat32Array([0.6]))
		var through := _act_time / maxf(_act_length, 0.001)
		if through < blows[0] and _quarry != null and _distance_to(_quarry) > reach * 0.6:
			var ahead := _forward() * leap_speed
			velocity.x = ahead.x
			velocity.z = ahead.z
		else:
			_slow(delta, 4.0)
	elif not _close_in(delta):
		_slow(delta, 2.0)
	if _blows.has(act):
		var blows: PackedFloat32Array = _blows[act]
		var through := _act_time / maxf(_act_length, 0.001)
		while _blows_done < blows.size() and through >= blows[_blows_done]:
			_blows_done += 1
			_land(_blows_done - 1, blows.size())
	return _act_time < _act_length


## Steps in towards the next blow of the act, so it lands where it is aimed
## rather than short of it: true while he is stepping.
func _close_in(_delta: float) -> bool:
	if _quarry == null or not _blows.has(act) or act == Act.SPIN or act == Act.ROAR:
		return false
	var blows: PackedFloat32Array = _blows[act]
	if _blows_done >= blows.size():
		return false
	var gap := _distance_to(_quarry)
	var want := kick_reach if act == Act.KICK else strike_reach
	if gap <= want:
		return false
	var left := blows[_blows_done] * _act_length - _act_time
	var pace := minf((gap - want) / maxf(left, 0.15), close_speed)
	if act in CHAINS:
		pace = maxf(pace, chain_advance)
	var ahead := _forward() * pace
	velocity.x = ahead.x
	velocity.z = ahead.z
	return true


## One blow of the act under way at its moment. The blows themselves are the
## axe's sweeps (`_arm_blows`); what is left here is the overhead meeting the
## ground.
func _land(index: int, count: int) -> void:
	match act:
		Act.HEAVY, Act.LEAP:
			_slam(leap_damage if act == Act.LEAP else slam_damage)
		Act.SPIN, Act.KICK:
			pass
		_:
			var spec: Array = _acts[act]
			if spec.size() > 3 and bool(spec[3]) and index == count - 1:
				# A chain or combo that ends overhead ends in the slam.
				_slam(slam_damage)


## The overhead's own sweep, so the ground bursting under it does not strike
## twice whoever the axe already went through.
var _slam_sweep: WeaponSweep


## The overhead blow into the ground: the stones bursting up right where it
## hit, and the spikes running on from there.
func _slam(damage: float) -> void:
	_slammed = true
	var at := axe_head()
	_slam_point = at
	for who in _players_near(at, SLAM_BURST * visual_scale / 2.24):
		if _slam_sweep == null or not _slam_sweep.caught.has(who):
			_floor(who, damage)
	_launch_wave(at, _forward(), wave_length, wave_size, wave_damage)
	net_slam.rpc(at, _forward())
#endregion


#region Looks
@rpc("authority", "call_local", "reliable")
func net_slam(at: Vector3, direction: Vector3) -> void:
	var world := Blood.world_of(self)
	GroundFx.eruption(world, at, 1.2)
	GroundFx.wave(world, at, direction, wave_length, false, wave_size)


func _show_act() -> void:
	if act == ACT_REEL:
		# The clip that threw the blow is left where it is, and run back.
		_reel_clock = 0.0
		return
	if REACTS.has(act):
		_react_seg = -1
		return
	if _own == null or not _acts.has(act):
		return
	var spec: Array = _acts[act]
	var clip: StringName = spec[0]
	if not _own.has_animation(clip):
		return
	# Every peer starts the clip from the top, at the rate the host's act length
	# was worked out for, so the blow is seen when it lands.
	var again := _own.current_animation == String(clip)
	_own.play(clip, 0.12, float(spec[2]))
	if again:
		_own.seek(0.0, true)


func _animate(delta: float) -> void:
	if _skeleton == null or _own == null:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var moving := planar > 0.2
	if is_dead:
		if _own.current_animation != String(_death) and _own.has_animation(_death):
			_own.play(_death, 0.1)
	elif act == ACT_REEL:
		# The axe goes back the way it came, then he stands reeling over the
		# idle while the fold (below) doubles him up.
		_reel_clock += delta
		if _reel_clock < Recoil.REBOUND:
			_own.speed_scale = -2.4
		else:
			if _own.current_animation != String(_idle):
				_own.play(_idle, 0.35)
			_own.speed_scale = 1.0
	elif REACTS.has(act):
		_play_react()
	elif act == ACT_NONE:
		var roused := mode != Mode.GUARD
		var clip: StringName
		if moving:
			if planar > 2.6:
				clip = _run
			elif roused or guarding:
				clip = _walk
			else:
				clip = _calm_walk
		elif guarding:
			clip = _guard
		else:
			clip = _idle if roused else _calm_idle
		if not _own.has_animation(clip):
			clip = _idle
		if _own.current_animation != String(clip):
			_own.play(clip, 0.25)
		_own.speed_scale = clampf(planar / float(_natural.get(clip, 1.5)), 0.6, 1.8) if moving else 1.0
	elif not REACTS.has(act):
		_own.speed_scale = 1.0
	_own.advance(delta * HitFeel.pace(self))
	# His clips are kept on the spot; the body is what moves him.
	if _hips >= 0:
		var at := _skeleton.get_bone_pose_position(_hips)
		_skeleton.set_bone_pose_position(_hips, Vector3(_hips_rest.x, at.y, _hips_rest.z))
	if act == ACT_REEL and not is_dead:
		Recoil.pose(_skeleton, self, _reel_bones, _reel_clock, great_axe)
	# The guard over a walking lower body.
	if guarding and moving and act == ACT_NONE and not _guard_tracks.is_empty():
		var anim := _own.get_animation(_guard)
		_guard_time = fmod(_guard_time + delta, maxf(anim.length, 0.01))
		for tb in _guard_tracks:
			_skeleton.set_bone_pose_rotation(tb.y, anim.rotation_track_interpolate(tb.x, _guard_time))
	_stoop_into_blows()
	_place_axe()
	_feed_arc(delta)


## Acts whose blows come round flat, at his own chest: the ones he stoops into.
func _flat_blows() -> bool:
	return act in [Act.SWING, Act.BACKHAND, Act.COMBO, Act.COMBO_THREE, Act.COMBO_SHORT, Act.SPIN] \
			or act in CHAINS


## Bends him forward at the waist around each flat blow, so the axe comes
## through at a man's height (see `stoop`). On every peer, off the act's own
## clock; the last blow of a chain that ends overhead is left as it is.
func _stoop_into_blows() -> void:
	if stoop <= 0.0 or is_dead or not _flat_blows() or not _blows.has(act):
		return
	var waist := _skeleton.find_bone("Spine02")
	if waist < 0:
		return
	var spec: Array = _acts[act]
	var length := clip_length(spec[0]) / maxf(float(spec[2]), 0.05)
	var blows: PackedFloat32Array = _blows[act]
	var bend := 0.0
	for i in blows.size():
		if spec.size() > 3 and bool(spec[3]) and i == blows.size() - 1:
			continue
		var off := absf(_shown_time - blows[i] * length)
		bend = maxf(bend, 1.0 - smoothstep(0.0, stoop_ease, off - 0.08))
	if bend <= 0.0:
		return
	# Forward about his own right, in the skeleton's space.
	var right := (_skeleton.global_transform.basis.inverse() * global_transform.basis.x).normalized()
	var pose := _skeleton.get_bone_global_pose(waist)
	var lean := Basis(right, -deg_to_rad(stoop) * bend)
	_skeleton.set_bone_global_pose(waist, Transform3D(lean * pose.basis, pose.origin))


## The reaction's clips, one after another, by the time since it started.
var _react_seg: int = -1


func _play_react() -> void:
	var segs: Array = REACTS[act]
	var t := _shown_time
	var i := 0
	while i < segs.size() - 1:
		var seg: Array = segs[i]
		var span := clip_length(seg[0]) * float(seg[2]) / float(seg[1])
		if t < span:
			break
		t -= span
		i += 1
	if i != _react_seg:
		_react_seg = i
		var seg: Array = segs[i]
		if _own.has_animation(seg[0]):
			var again := _own.current_animation == String(seg[0])
			_own.play(seg[0], 0.12 if i == 0 else 0.25, float(seg[1]))
			if again:
				_own.seek(0.0, true)
	_own.speed_scale = float((segs[_react_seg] as Array)[1])


## The axe cuts the air while it moves fast in an attack.
func _feed_arc(delta: float) -> void:
	if _arc == null or _arc_tip == null:
		return
	var at := _arc_tip.global_position
	var speed := at.distance_to(_arc_last) / maxf(delta, 0.001)
	_arc_last = at
	var striking := act != ACT_NONE and act != Act.ROAR and act != Act.DEAD and not is_dead
	_arc.emitting = striking and speed > arc_speed
#endregion
