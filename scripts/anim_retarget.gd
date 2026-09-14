class_name AnimRetarget
extends Node3D

## Plays clips authored for the Quaternius "Universal Animation Library 2"
## mannequin on a model that carries no skeleton of its own.
##
## Tariel is a hierarchy of rigid parts hung off named joint nodes, so nothing
## can be skinned to the mannequin's bones — and copying the mannequin's joint
## *positions* across would pull the parts apart, because the two bodies are not
## built to the same proportions. Only rotation is transferred: every joint is
## given the orientation its mannequin counterpart holds, expressed in the
## model's own frame, which leaves each limb exactly as long as it was authored.
##
## The two rest poses disagree — the mannequin ships in a T-pose, Tariel in a
## sword-and-shield stance — so a fixed per-joint correction is solved once at
## load. `_shortest_arc()` swings each of Tariel's limbs onto the direction its
## counterpart points in the mannequin's rest, which *is* Tariel's T-pose, and
## the correction is the gap between that and the mannequin's own rest. Only the
## swing is solved, never the twist, so the authored grip on the sword and the
## roll of the shoulders survive the transfer.
##
## Sides are crossed on purpose. Tariel's `*_l` nodes sit on the model's -X
## side, and with the model facing +Z that is the mannequin's *right*: matching
## the names up instead of the anatomy would put the sword in the wrong hand.

## Emitted when a one-shot clip reaches its end, before the fade-out finishes.
signal clip_finished(clip: StringName)

const SOURCE_SCENE := "res://assets/anim/ual2.glb"

## Which part of the body a clip is allowed to drive.
##
## UPPER leaves the legs alone, so a swing can be thrown at a dead run. LOWER is
## its opposite and is what carries the walk cycle: the library's only forward
## cycle is a *carrying* walk, with the arms held out in front, so its legs are
## worth having and its arms are not.
enum Mask { FULL, UPPER, LOWER }

## Tariel joint -> mannequin bone. The mannequin's spine_02 and both clavicles
## have no counterpart; because each joint is resolved against the *model*-space
## orientation of its bone rather than against its parent, the missing links are
## absorbed automatically instead of dropping their rotation.
const BONE_MAP := {
	"hips": "pelvis",
	"spine": "spine_01",
	"chest": "spine_03",
	"neck": "neck_01",
	"head": "Head",
	# Sword arm: Tariel's -X side, the mannequin's right.
	"shoulder_l": "upperarm_r",
	"upperarm_l_end": "lowerarm_r",
	"forearm_l_end": "hand_r",
	"hand_l": "hand_r",
	# Shield arm.
	"shoulder_r": "upperarm_l",
	"upperarm_r_end": "lowerarm_l",
	"forearm_r_end": "hand_l",
	"hand_r": "hand_l",
	"hip_l": "thigh_r",
	"thigh_l_end": "calf_r",
	"shin_l_end": "foot_r",
	"foot_l": "foot_r",
	"hip_r": "thigh_l",
	"thigh_r_end": "calf_l",
	"shin_r_end": "foot_l",
	"foot_r": "foot_l",
}

## Parents first: every joint is resolved against the pose its parent was
## actually given this frame, so a partial blend never breaks the chain.
const JOINT_ORDER: Array[String] = [
	"hips", "spine", "chest", "neck", "head",
	"shoulder_l", "upperarm_l_end", "forearm_l_end", "hand_l",
	"shoulder_r", "upperarm_r_end", "forearm_r_end", "hand_r",
	"hip_l", "thigh_l_end", "shin_l_end", "foot_l",
	"hip_r", "thigh_r_end", "shin_r_end", "foot_r",
]

## An empty parent means the joint hangs directly off the model root.
const JOINT_PARENT := {
	"hips": "",
	"spine": "hips",
	"chest": "spine",
	"neck": "chest",
	"head": "neck",
	"shoulder_l": "chest",
	"upperarm_l_end": "shoulder_l",
	"forearm_l_end": "upperarm_l_end",
	"hand_l": "forearm_l_end",
	"shoulder_r": "chest",
	"upperarm_r_end": "shoulder_r",
	"forearm_r_end": "upperarm_r_end",
	"hand_r": "forearm_r_end",
	"hip_l": "hips",
	"thigh_l_end": "hip_l",
	"shin_l_end": "thigh_l_end",
	"foot_l": "shin_l_end",
	"hip_r": "hips",
	"thigh_r_end": "hip_r",
	"shin_r_end": "thigh_r_end",
	"foot_r": "shin_r_end",
}

## [mannequin bone, Tariel node] whose position marks the far end of each joint.
## The pair of directions is what the rest correction is solved from. Joints
## left out here — wrists, hands, ankles, the head — have nothing meaningful
## pointing out of them, so they inherit their parent's correction, which keeps
## them square with the limb they sit on.
const AIM := {
	"hips": ["spine_01", "spine"],
	"spine": ["spine_03", "chest"],
	"chest": ["neck_01", "neck"],
	"neck": ["Head", "head"],
	"shoulder_l": ["lowerarm_r", "upperarm_l_end"],
	"upperarm_l_end": ["hand_r", "forearm_l_end"],
	"shoulder_r": ["lowerarm_l", "upperarm_r_end"],
	"upperarm_r_end": ["hand_l", "forearm_r_end"],
	"hip_l": ["calf_r", "thigh_l_end"],
	"thigh_l_end": ["foot_r", "shin_l_end"],
	"shin_l_end": ["ball_r", "boot_l_toe"],
	"hip_r": ["calf_l", "thigh_r_end"],
	"thigh_r_end": ["foot_l", "shin_r_end"],
	"shin_r_end": ["ball_l", "boot_r_toe"],
}

## How much of the clip each joint takes under Mask.UPPER. The waist is only
## carried part of the way so the split does not read as a hinge.
const UPPER_MASK := {
	"spine": 0.65, "chest": 1.0, "neck": 1.0, "head": 1.0,
	"shoulder_l": 1.0, "upperarm_l_end": 1.0, "forearm_l_end": 1.0, "hand_l": 1.0,
	"shoulder_r": 1.0, "upperarm_r_end": 1.0, "forearm_r_end": 1.0, "hand_r": 1.0,
}

## The same for Mask.LOWER. The pelvis comes along because the weight shift over
## each foot lives there; the spine takes a little of the counter-rotation and
## the arms take none, so the lean, the breathing and the arm swing stay with
## whatever is driving the upper body.
const LOWER_MASK := {
	"hips": 1.0, "spine": 0.25,
	"hip_l": 1.0, "thigh_l_end": 1.0, "shin_l_end": 1.0, "foot_l": 1.0,
	"hip_r": 1.0, "thigh_r_end": 1.0, "shin_r_end": 1.0, "foot_r": 1.0,
}

var _skeleton: Skeleton3D
var _player: AnimationPlayer
## Joint -> bone index in `_skeleton`.
var _bone: Dictionary = {}
## Joint -> the constant basis that carries a mannequin orientation onto Tariel.
var _correction: Dictionary = {}
## Joint -> the mannequin orientation for this frame, already corrected.
var _sampled: Dictionary = {}
## Mannequin bone -> its rest transform in the model's frame.
var _source_rest: Dictionary = {}
## Skeleton space to model space. Identity unless the imported scene nests the
## armature under a transform.
var _source_basis: Basis = Basis.IDENTITY
var _source_origin: Vector3 = Vector3.ZERO
var _pelvis_rest: Vector3 = Vector3.ZERO
## Tariel is a little shorter than the mannequin, so the pelvis travel written
## into a crouch or a jump has to be brought down to his scale.
var _pelvis_scale: float = 1.0
## Ratio of this body's leg length to the mannequin's, which is what decides how
## far one of its strides actually carries it.
var _limb_scale: float = 1.0
var _pelvis_shift: Vector3 = Vector3.ZERO

var _weight: float = 0.0
var _target_weight: float = 0.0
var _fade_speed: float = 10.0
var _mask: Mask = Mask.FULL
var _clip: StringName = &""
var _ready_to_play: bool = false


## Loads the animation library and solves the rest correction for every mapped
## joint. `joints` maps joint name to node; `neutral` gives the orientation each
## joint is measured from, which for the legs and the shield arm is not the
## stance baked into the file. Returns false if the library is unusable, in
## which case the caller should carry on with its own procedural animation.
func setup(rig: Node3D, joints: Dictionary, neutral: Dictionary) -> bool:
	if not ResourceLoader.exists(SOURCE_SCENE):
		push_warning("AnimRetarget: %s is missing, clips disabled." % SOURCE_SCENE)
		return false

	var scene: Node3D = (load(SOURCE_SCENE) as PackedScene).instantiate()
	scene.name = "AnimSource"
	add_child(scene)

	_skeleton = scene.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _skeleton == null or _player == null:
		push_warning("AnimRetarget: no skeleton or animation player in the library.")
		scene.queue_free()
		return false

	# The mannequin itself is never drawn; only its joint angles are wanted.
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).visible = false

	# Stepped by hand from animate(), so the pose is always the one belonging to
	# the frame being drawn rather than whatever the mixer last left behind.
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.animation_finished.connect(_on_clip_finished)

	var source_to_model := rig.global_transform.affine_inverse() * _skeleton.global_transform
	_source_basis = source_to_model.basis.orthonormalized()
	_source_origin = source_to_model.origin

	for joint_name: String in BONE_MAP:
		var bone_name: String = BONE_MAP[joint_name]
		var idx := _skeleton.find_bone(bone_name)
		if idx < 0:
			push_warning("AnimRetarget: bone '%s' is missing from the library." % bone_name)
			return false
		_bone[joint_name] = idx

	# Rest transforms of every bone the solve touches, brought into model space.
	var wanted: Array = BONE_MAP.values().duplicate()
	for pair: Array in AIM.values():
		wanted.append(pair[0])
	for bone_name: String in wanted:
		var idx := _skeleton.find_bone(bone_name)
		if idx < 0 or _source_rest.has(bone_name):
			continue
		var rest := _skeleton.get_bone_global_rest(idx)
		_source_rest[bone_name] = Transform3D(
				_source_basis * rest.basis, _source_origin + _source_basis * rest.origin)

	var dest_rest := _solve_dest_rest(rig, joints, neutral)
	if dest_rest.is_empty():
		return false
	_solve_corrections(joints, dest_rest)

	_pelvis_rest = (_source_rest["pelvis"] as Transform3D).origin
	var hips_rest: Transform3D = dest_rest["hips"]
	_pelvis_scale = hips_rest.origin.y / maxf(_pelvis_rest.y, 0.01)

	# How far a stride carries this body compared with the mannequin's is set by
	# the legs, not by how tall either of them is.
	var source_leg := ((_source_rest["thigh_r"] as Transform3D).origin
			- (_source_rest["foot_r"] as Transform3D).origin).length()
	var dest_leg := ((dest_rest["hip_l"] as Transform3D).origin
			- (dest_rest["shin_l_end"] as Transform3D).origin).length()
	_limb_scale = dest_leg / maxf(source_leg, 0.01)

	_ready_to_play = true
	return true


## Where every joint sits, in model space, when the model stands in `neutral`.
##
## Composed from the joints' own local transforms rather than read back off the
## scene tree: the reference stance is not the one currently posed, and walking
## the chain by hand avoids having to push a throwaway pose through the engine
## and undo it afterwards.
func _solve_dest_rest(rig: Node3D, joints: Dictionary, neutral: Dictionary) -> Dictionary:
	var hips := joints.get("hips") as Node3D
	if hips == null or hips.get_parent() == null:
		push_warning("AnimRetarget: the model has no hips to hang the rest pose off.")
		return {}

	var rest := {"": rig.global_transform.affine_inverse() * (hips.get_parent() as Node3D).global_transform}
	for joint_name in JOINT_ORDER:
		var node := joints.get(joint_name) as Node3D
		if node == null:
			push_warning("AnimRetarget: joint '%s' is missing from the model." % joint_name)
			return {}
		var euler: Vector3 = neutral.get(joint_name, node.rotation)
		var local := Transform3D(Basis.from_euler(euler, node.rotation_order), node.position)
		rest[joint_name] = (rest[JOINT_PARENT[joint_name]] as Transform3D) * local
	return rest


## Solves the constant per-joint correction, parents first so that a joint with
## nothing to aim at can fall back on the limb it belongs to.
func _solve_corrections(joints: Dictionary, dest_rest: Dictionary) -> void:
	var swing := {"": Basis.IDENTITY}
	for joint_name in JOINT_ORDER:
		var turn: Basis = swing[JOINT_PARENT[joint_name]]
		if AIM.has(joint_name):
			var pair: Array = AIM[joint_name]
			var here: Transform3D = dest_rest[joint_name]
			var source_dir: Vector3 = ((_source_rest[pair[0]] as Transform3D).origin
					- (_source_rest[BONE_MAP[joint_name]] as Transform3D).origin)
			var dest_dir: Vector3 = _dest_origin(joints, dest_rest, pair[1]) - here.origin
			if source_dir.length_squared() > 1e-8 and dest_dir.length_squared() > 1e-8:
				turn = _shortest_arc(dest_dir.normalized(), source_dir.normalized())
		swing[joint_name] = turn

		# Where the joint would sit if the model held the mannequin's rest pose,
		# against where the mannequin actually holds it.
		var t_pose := turn * (dest_rest[joint_name] as Transform3D).basis.orthonormalized()
		var source_basis: Basis = (_source_rest[BONE_MAP[joint_name]] as Transform3D).basis.orthonormalized()
		_correction[joint_name] = t_pose * source_basis.inverse()


## Model-space origin of a node used as an aim target. Joints are already
## solved; anything else — a boot's toe cap, say — is walked back up to the
## nearest joint and composed from there.
func _dest_origin(joints: Dictionary, dest_rest: Dictionary, node_name: String) -> Vector3:
	if dest_rest.has(node_name):
		return (dest_rest[node_name] as Transform3D).origin

	var node := joints.get(node_name) as Node3D
	if node == null:
		var hips := joints.get("hips") as Node3D
		node = hips.get_parent().find_child(node_name, true, false) as Node3D
	if node == null:
		push_warning("AnimRetarget: aim target '%s' is missing from the model." % node_name)
		return Vector3.ZERO

	var local := Transform3D.IDENTITY
	var walk := node
	while walk != null and not dest_rest.has(String(walk.name)):
		local = walk.transform * local
		walk = walk.get_parent() as Node3D
	if walk == null:
		push_warning("AnimRetarget: aim target '%s' hangs off no known joint." % node_name)
		return Vector3.ZERO
	return ((dest_rest[String(walk.name)] as Transform3D) * local).origin


## The least rotation that carries `from` onto `to`.
static func _shortest_arc(from: Vector3, to: Vector3) -> Basis:
	var axis := from.cross(to)
	if axis.length_squared() < 1e-12:
		if from.dot(to) > 0.0:
			return Basis.IDENTITY
		return Basis(from.cross(Vector3.UP).normalized() if absf(from.y) < 0.9
				else from.cross(Vector3.RIGHT).normalized(), PI)
	return Basis(axis.normalized(), from.angle_to(to))


#region Playback
## Starts a clip. `fade` is the cross-fade in seconds, `mask` decides whether
## the legs come along, and `weight` caps how far the clip overrides the
## procedural pose.
func play(clip: StringName, fade: float = 0.12, speed: float = 1.0,
		mask: Mask = Mask.FULL, weight: float = 1.0) -> bool:
	if not _ready_to_play or not _player.has_animation(clip):
		return false
	_clip = clip
	_mask = mask
	_target_weight = clampf(weight, 0.0, 1.0)
	_fade_speed = 1.0 / maxf(fade, 0.01)
	_player.play(clip, -1.0, speed)
	return true


## Retimes the running clip without restarting it — what a looping walk cycle
## needs so the feet keep up with the ground under them.
func set_speed(speed: float) -> void:
	if _ready_to_play and _player.is_playing():
		_player.speed_scale = maxf(speed, 0.0)


## Parks the clip at a point in its own length, 0 to 1, and leaves it there.
##
## For a cycle whose timing belongs to something else: a walk driven off the
## controller's stride phase stays in step with the ground at any speed, which
## playing it at a rate of its own cannot do once the stride starts lengthening.
func seek_ratio(where: float) -> void:
	if not _ready_to_play or _clip.is_empty():
		return
	if _player.is_playing():
		_player.pause()
	_player.seek(clip_length(_clip) * clampf(where, 0.0, 1.0), true)


## Slides the layer's strength without disturbing what it is playing — what a
## cycle that is permanently half-in needs, as against a one-shot that fades all
## the way in and back out again.
func blend_to(weight: float, fade: float = 0.15) -> void:
	_target_weight = clampf(weight, 0.0, 1.0)
	_fade_speed = 1.0 / maxf(fade, 0.01)


## Hands the body back to the procedural pose over `fade` seconds.
func stop(fade: float = 0.15) -> void:
	blend_to(0.0, fade)


## Stops the mixer outright. Only worth doing once the layer has faded to
## nothing, and only to spare the cost of stepping a clip nobody can see.
func halt() -> void:
	if _ready_to_play:
		_player.stop()
	_clip = &""


## Drops the layer where it stands: no fade, nothing left running, nothing left
## to chain from. For transitions the body does not ease into — catching hold of
## a wall in mid-jump is one, and a take-off clip fading out over it for even a
## tenth of a second reads as the jump carrying on up the wall.
func cut() -> void:
	_target_weight = 0.0
	_weight = 0.0
	halt()


## Freezes the library on one frame of a clip, at full strength and full body.
## For tooling: the game never wants a pose that does not move, but a screenshot
## has to be taken at a time somebody chose rather than whenever the frame fell.
func hold(clip: StringName, ratio: float) -> bool:
	if not _ready_to_play or not _player.has_animation(clip):
		return false
	_clip = clip
	_mask = Mask.FULL
	_weight = 1.0
	_target_weight = 1.0
	_player.play(clip)
	_player.seek(clip_length(clip) * clampf(ratio, 0.0, 1.0), true)
	_player.pause()
	return true


func is_playing(clip: StringName = &"") -> bool:
	if not _ready_to_play or not _player.is_playing():
		return false
	return clip.is_empty() or _clip == clip


func current_clip() -> StringName:
	return _clip if is_playing() else &""


## The clip the layer is holding, whether or not it is still running. A cycle
## driven by seek() is paused between frames, so is_playing() says nothing about
## whether it needs starting.
func loaded_clip() -> StringName:
	return _clip


## How far through the running clip we are, 0 to 1.
func clip_progress() -> float:
	if not is_playing():
		return 0.0
	var anim := _player.get_animation(_clip)
	if anim == null or anim.length <= 0.0:
		return 0.0
	return clampf(_player.current_animation_position / anim.length, 0.0, 1.0)


func clip_length(clip: StringName) -> float:
	if not _ready_to_play:
		return 0.0
	var anim := _player.get_animation(clip)
	return anim.length if anim != null else 0.0


func has_clip(clip: StringName) -> bool:
	return _ready_to_play and _player.has_animation(clip)


func clip_names() -> PackedStringArray:
	return _player.get_animation_list() if _ready_to_play else PackedStringArray()


## Overall strength of the clip this frame, 0 while the model is entirely under
## procedural control.
func weight() -> float:
	return _weight


## Strength for one joint, after the mask.
func joint_weight(joint_name: String) -> float:
	match _mask:
		Mask.UPPER:
			return _weight * float(UPPER_MASK.get(joint_name, 0.0))
		Mask.LOWER:
			return _weight * float(LOWER_MASK.get(joint_name, 0.0))
	return _weight


## The orientation, in model space, that `joint_name` should hold this frame.
func joint_basis(joint_name: String) -> Basis:
	return _sampled.get(joint_name, Basis.IDENTITY)


## How far the clip lifts or drops the hips, already brought to Tariel's scale.
func hips_offset() -> Vector3:
	return _pelvis_shift * _weight


## Steps the library on and reads the pose back out. Must run before the model
## is posed for the frame.
func advance(delta: float) -> void:
	if not _ready_to_play:
		return

	_weight = move_toward(_weight, _target_weight, _fade_speed * delta)
	if _player.is_playing():
		_player.advance(delta)
	if _weight <= 0.001:
		_pelvis_shift = Vector3.ZERO
		return

	for joint_name in JOINT_ORDER:
		var pose := _skeleton.get_bone_global_pose(_bone[joint_name])
		_sampled[joint_name] = ((_correction[joint_name] as Basis)
				* (_source_basis * pose.basis).orthonormalized())

	var pelvis := _source_origin + _source_basis * _skeleton.get_bone_global_pose(_bone["hips"]).origin
	_pelvis_shift = (pelvis - _pelvis_rest) * _pelvis_scale


func _on_clip_finished(clip: StringName) -> void:
	clip_finished.emit(clip)


## The slice of `clip`, in normalised time, over which `joint_name` is actually
## travelling — for a sword swing, the frames where the blade would be cutting
## rather than winding up or recovering.
##
## Read off the clip instead of hand-tuned, so retiming a swing or dropping in a
## different one needs no numbers changed anywhere.
func measure_travel(clip: StringName, joint_name: String, threshold: float = 0.45) -> Vector2:
	const STEPS := 48
	if not has_clip(clip) or not _bone.has(joint_name):
		return Vector2(0.3, 0.7)
	var anim := _player.get_animation(clip)
	if anim == null or anim.length <= 0.0:
		return Vector2(0.3, 0.7)

	var idx: int = _bone[joint_name]
	var track := PackedVector3Array()
	track.resize(STEPS + 1)
	_player.play(clip)
	for i in STEPS + 1:
		_player.seek(anim.length * float(i) / STEPS, true)
		track[i] = _skeleton.get_bone_global_pose(idx).origin
	_player.stop()

	var speed := PackedFloat32Array()
	speed.resize(STEPS)
	var peak := 0.0
	for i in STEPS:
		speed[i] = track[i + 1].distance_to(track[i])
		peak = maxf(peak, speed[i])
	if peak <= 0.0:
		return Vector2(0.3, 0.7)

	var first := STEPS
	var last := 0
	for i in STEPS:
		if speed[i] >= peak * threshold:
			first = mini(first, i)
			last = maxi(last, i + 1)
	if first > last:
		return Vector2(0.3, 0.7)
	return Vector2(float(first) / STEPS, float(last) / STEPS)


## How much ground one cycle of a walk clip covers on *this* body, in metres.
##
## The feet only stay planted if the playback rate is tied to the real stride,
## and a stride typed in by hand goes stale the moment the clip is swapped — so
## it is read off the clip: the feet are furthest apart at mid-stride, which is
## one step, and a full cycle is two of them.
func measure_stride(clip: StringName) -> float:
	const STEPS := 48
	if not has_clip(clip):
		return 0.0
	var anim := _player.get_animation(clip)
	if anim == null or anim.length <= 0.0:
		return 0.0
	var left := _skeleton.find_bone("foot_l")
	var right := _skeleton.find_bone("foot_r")
	if left < 0 or right < 0:
		return 0.0

	var step := 0.0
	_player.play(clip)
	for i in STEPS:
		_player.seek(anim.length * float(i) / STEPS, true)
		var gap := (_skeleton.get_bone_global_pose(left).origin
				- _skeleton.get_bone_global_pose(right).origin)
		gap.y = 0.0
		step = maxf(step, gap.length())
	_player.stop()
	return step * 2.0 * _limb_scale
#endregion
