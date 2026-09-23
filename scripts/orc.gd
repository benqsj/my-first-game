class_name OrcWarrior
extends Brute

## The orc warrior: two and a half metres of him, an axe in his right fist.
##
## His own clips are a walk and a run. Everything else — the idle, the swings,
## the guard, the fall — is the animation library's, carried onto his rig by
## [RigRetarget], which is what lets a Mixamo-built body use the mannequin's
## fights.
##
## * **Attacks.** A single swing (`Sword_Regular_A`), a combo
##   (`Sword_Regular_Combo`) and the heavy combo (`Sword_Heavy_Combo`), whose
##   last blow is overhead into the ground: the earth splits ahead of it in a
##   long run of stone spikes, a hit of its own on anyone it runs under. The
##   blows land where his right hand moves fastest in the clip, measured off it.
##   Only a combo that lands every blow knocks a player down.
## * **The guard.** Only an archer makes him cover his face: while a player
##   with a bow is drawing on him (aimed at him, or facing him within
##   `threat_cone` degrees and inside `threat_range`) he raises his off arm
##   (`Idle_Shield`) and an arrow does `guard_factor` of its damage. He keeps
##   coming, arm up, at a walk.
## * **The axe** is the village's, set in his fist by a grip read off his own
##   mesh: where the fist's vertices gather, and the line their knuckles make.

enum Act { NONE = 0, SWING = 1, COMBO = 2, HEAVY = 3, DEAD = 99 }

## His bones -> the mannequin's. The hands are left out: the orc's rest is a
## fist, and turned the mannequin's way they came out claw-shaped.
const MAP := {
	"Hips": "pelvis", "Spine02": "spine_01", "Spine01": "spine_02", "Spine": "spine_03",
	"neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r",
}
## Where each bone points, for the rest swing.
const CHILD := {
	"Hips": "Spine02", "Spine02": "Spine01", "Spine01": "Spine", "Spine": "neck", "neck": "Head",
	"LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand",
	"RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand",
	"LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "LeftFoot": "LeftToeBase",
	"RightUpLeg": "RightLeg", "RightLeg": "RightFoot", "RightFoot": "RightToeBase",
}
## What the guard moves while his legs walk.
const GUARD_BONES: PackedStringArray = [
	"Spine01", "Spine", "neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm",
	"RightShoulder", "RightArm", "RightForeArm",
]
## The grip in his right hand's own frame: the middle of the fist, and the turn
## that runs the haft along the knuckles with the blade out the way the
## mannequin's sword cuts. Read off the mesh once, in the bestiary.
const FIST_LOCAL := Vector3(-0.65376, 13.47461, 0.47799)
const GRIP := Quaternion(-0.48301, -0.78505, 0.31603, 0.22476)
## Held a little way up the haft, so the fist closes round wood.
const AXE_DROP := 0.18
## The head of the axe, in the axe's own frame: where the slam lands.
const AXE_HEAD := Vector3(0.12, 0.62, 0.0)
const AXE_SCENE := "res://assets/area/HighLandsFantasyBuildings/MiscProps/SM_Axe.fbx"
const AXE_TEXTURES := "res://assets/area/HighLandsFantasyBuildings/MiscProps/TextureMaps"

const IDLE := &"Idle_No"
const GUARD := &"Idle_Shield"
const SWING_CLIP := &"Sword_Regular_A"
const COMBO_CLIP := &"Sword_Regular_Combo"
const HEAVY_CLIP := &"Sword_Heavy_Combo"
const DEATH_CLIP := &"Hit_Knockback"

@export_group("Attack")
@export var reach: float = 2.7
@export var swing_speed: float = 1.1
@export var swing_damage: float = 14.0
@export var combo_damage: float = 12.0
@export var heavy_damage: float = 15.0
@export var slam_damage: float = 22.0
## The run of spikes out of the ground after the slam: its length, how much
## wider and taller than the bestiary's it is drawn, and what it does.
@export var wave_length: float = 9.0
@export var wave_size: float = 1.25
@export var wave_damage: float = 20.0
## How far off he may open with the heavy combo, for the spikes to reach.
@export var slam_range: float = 9.0

@export_group("Guard")
@export_range(0.0, 1.0) var guard_factor: float = 0.35
@export var threat_range: float = 45.0
@export var threat_cone: float = 20.0
## How long the arm stays up after the draw ends — the arrow is in the air.
@export var guard_linger: float = 0.6
## Share of his chase pace while he comes on behind his raised arm. One: the
## guard costs him nothing — the arm goes up and he keeps coming at a run.
@export var guard_pace: float = 1.0

## Replicated.
var guarding: bool = false

var _skeleton: Skeleton3D
var _own: AnimationPlayer
var _rt: RigRetarget
var _hand: int = -1
var _hips: int = -1
var _hips_rest := Vector3.ZERO
var _axe: Node3D
## Own clip -> ground covered a second at rate 1.
var _natural: Dictionary = {}
var _blows: Dictionary = {}
var _slam_at: float = -1.0
var _blows_done: int = 0
var _slammed: bool = false
var _threat: float = 0.0
var _ranged_try: float = 0.0
var _masked: bool = false


func _ready() -> void:
	super()
	_skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	_own = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null:
		push_warning("Orc '%s': no skeleton." % name)
		return
	_hand = _skeleton.find_bone("RightHand")
	_hips = _skeleton.find_bone("Hips")
	if _hips >= 0:
		_hips_rest = _skeleton.get_bone_rest(_hips).origin
	if _own != null:
		_own.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip in [&"walk", &"run"]:
			if _own.has_animation(clip):
				_own.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				_natural[clip] = _measure_pace(clip)
		if _own.has_animation(&"walk"):
			_own.play(&"walk")

	_rt = RigRetarget.new()
	_rt.name = "Retarget"
	add_child(_rt)
	if not _rt.setup(_skeleton, MAP, CHILD):
		_rt.queue_free()
		_rt = null
	else:
		_rt.play(IDLE, 0.01)
		_blows[Act.SWING] = _rt.measure_peaks(SWING_CLIP, PackedStringArray(["hand_r"]))
		_blows[Act.COMBO] = _rt.measure_peaks(COMBO_CLIP, PackedStringArray(["hand_r"]))
		_slam_at = _rt.lowest_moment(HEAVY_CLIP, "hand_r", 0.55)
		var heavy := PackedFloat32Array()
		for t in _rt.measure_peaks(HEAVY_CLIP, PackedStringArray(["hand_r"])):
			if t < _slam_at - 0.05:
				heavy.append(t)
		heavy.append(_slam_at if _slam_at > 0.0 else 0.75)
		_blows[Act.HEAVY] = heavy
	for key in [Act.SWING, Act.COMBO]:
		if not _blows.has(key) or (_blows[key] as PackedFloat32Array).is_empty():
			_blows[key] = PackedFloat32Array([0.45])
	if not _blows.has(Act.HEAVY):
		_blows[Act.HEAVY] = PackedFloat32Array([0.3, 0.5, 0.75])
	_make_axe()


## Metres a second one of his own cycles carries him at rate 1: two steps, a
## step being as far apart as his feet get.
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
	add_child(_axe)
	_place_axe()


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
	var head := _axe.get_node_or_null("Head") as Node3D if _axe != null else null
	var at := head.global_position if head != null else global_position + _forward() * reach
	at.y = global_position.y + 0.03
	return at


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


func _choose_attack(gap: float) -> void:
	if _rt == null:
		return
	if gap <= reach:
		var roll := _rng.randf()
		if roll < 0.35:
			_begin(Act.SWING, SWING_CLIP, swing_speed)
		elif roll < 0.7:
			_begin(Act.COMBO, COMBO_CLIP, 1.0)
		else:
			_begin(Act.HEAVY, HEAVY_CLIP, 1.0)
		return
	# Further off, now and then, the heavy combo for the spikes to reach.
	_ranged_try -= get_physics_process_delta_time()
	if gap < slam_range and gap > reach + 1.5 and _ranged_try <= 0.0:
		_ranged_try = 2.5
		if _rng.randf() < 0.35:
			_begin(Act.HEAVY, HEAVY_CLIP, 1.0)


func _begin(what: int, clip: StringName, rate: float) -> void:
	_blows_done = 0
	_slammed = false
	_start(what, _rt.clip_length(clip) / maxf(rate, 0.05))


func _run_act(delta: float) -> bool:
	_slow(delta, 2.0)
	if act == Act.SWING or act == Act.COMBO or act == Act.HEAVY:
		var blows: PackedFloat32Array = _blows[act]
		var through := _act_time / maxf(_act_length, 0.001)
		while _blows_done < blows.size() and through >= blows[_blows_done]:
			_blows_done += 1
			var last := _blows_done == blows.size()
			if act == Act.HEAVY and last:
				_slam()
			else:
				var damage := swing_damage if act == Act.SWING else (combo_damage if act == Act.COMBO else heavy_damage)
				# A single swing is sent as the first of two: it never floors.
				var count := maxi(blows.size(), 2) if act == Act.SWING else blows.size()
				for who in _players_ahead(reach + 0.6, 0.3):
					_hit(who, damage, _blows_done - 1, count)
	return _act_time < _act_length


## The overhead blow into the ground: whoever is under it, and the spikes.
func _slam() -> void:
	_slammed = true
	var blows: PackedFloat32Array = _blows[Act.HEAVY]
	var at := axe_head()
	for who in _players_near(at, 1.8):
		_hit(who, slam_damage, blows.size() - 1, blows.size())
	for who in _players_ahead(reach + 0.4, 0.5):
		if who.global_position.distance_to(at) > 1.8:
			_hit(who, slam_damage, blows.size() - 1, blows.size())
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
	if _rt == null:
		return
	_set_mask(false)
	match act:
		Act.SWING:
			_rt.play(SWING_CLIP, 0.15, swing_speed, true)
		Act.COMBO:
			_rt.play(COMBO_CLIP, 0.15, 1.0, true)
		Act.HEAVY:
			_rt.play(HEAVY_CLIP, 0.15, 1.0, true)
		Act.DEAD:
			_rt.play(DEATH_CLIP, 0.1, 1.0, true)


func _set_mask(upper: bool) -> void:
	if upper == _masked or _rt == null:
		return
	_masked = upper
	_rt.set_mask(GUARD_BONES if upper else PackedStringArray())


func _animate(delta: float) -> void:
	if _skeleton == null:
		return
	var planar := Vector3(velocity.x, 0.0, velocity.z).length()
	var moving := planar > 0.2
	if _own != null:
		if moving:
			var clip := &"run" if planar > 2.4 and _own.has_animation(&"run") else &"walk"
			if _own.current_animation != String(clip):
				_own.play(clip, 0.25)
			_own.speed_scale = clampf(planar / float(_natural.get(clip, 1.5)), 0.6, 1.8)
		_own.advance(delta)
		# His clips walk off the spot; the body is what moves him.
		if _hips >= 0:
			var at := _skeleton.get_bone_pose_position(_hips)
			_skeleton.set_bone_pose_position(_hips, Vector3(_hips_rest.x, at.y, _hips_rest.z))
	if _rt != null:
		if act == ACT_NONE and not is_dead:
			if guarding:
				_set_mask(moving)
				_rt.play(GUARD, 0.15)
			elif moving:
				_rt.release(0.3)
			else:
				_set_mask(false)
				_rt.play(IDLE, 0.3)
		_rt.advance(delta)
	_place_axe()
#endregion
