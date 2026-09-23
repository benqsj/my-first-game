class_name RigRetarget
extends Node3D

## Plays the animation library's clips on a skeleton that was built another
## way — other bone names, other bone axes, another rest pose.
##
## [SkeletonAnim] copies a delta from rest bone by bone, which only works when
## both rigs share the mannequin's names and axes. The orc does not: his bones
## are named the Mixamo way, each one's axes were left however his author left
## them, and he stands in an A where the mannequin stands in a T. A delta taken
## in a bone's own frame would twist every limb.
##
## So the turn is carried across in *skeleton* space instead:
##
## * Once, at setup, each of the target's bones is swung until it points where
##   its mannequin bone points at rest (`swing`). That is what takes the A-pose
##   out.
## * Every frame, however far the mannequin's bone has turned from its rest in
##   skeleton space, the target's bone turns as far from that swung rest:
##
##       dst_world = align · (src_world · src_rest⁻¹) · align⁻¹ · swing · dst_rest
##
##   where `align` turns the mannequin's facing onto the target's. The local
##   pose is then that, relative to the parent's world.
##
## The target's own twist on each bone survives, which is what keeps wrists and
## ankles from corkscrewing. Bones missing from the map (the orc's hands, whose
## rest is his fist) keep whatever pose they had.
##
## Blended by weight over whatever already posed the skeleton — for the orc,
## his own walk and run, played by his own [AnimationPlayer] before this runs.

## Emitted when a one-shot clip reaches its end.
signal clip_finished(clip: StringName)

const SOURCE_SCENE := "res://assets/anim/ual2.glb"

## Moments in a clip, measured once per clip for every creature.
static var _peak_cache: Dictionary = {}
static var _low_cache: Dictionary = {}

var _src: Skeleton3D
var _player: AnimationPlayer
var _dst: Skeleton3D

## Target bones, parents before children.
var _order := PackedInt32Array()
## Per target bone: the mannequin bone feeding it, or -1.
var _feed := PackedInt32Array()
var _src_rest_inv: Array[Quaternion] = []
var _dst_swung: Array[Quaternion] = []
var _world: Array[Quaternion] = []
var _align := Quaternion.IDENTITY
var _align_inv := Quaternion.IDENTITY

var _hips: int = -1
var _src_pelvis: int = -1
var _hips_rest := Vector3.ZERO
var _pelvis_rest := Vector3.ZERO
var _hip_scale: float = 1.0
var _hips_parent_inv := Basis.IDENTITY

## Per target bone: 1 when this drives it. All of them, unless masked.
var _driven := PackedByteArray()

var _weight: float = 0.0
var _target_weight: float = 0.0
var _fade_speed: float = 10.0
var _clip: StringName = &""
var _ready_to_play: bool = false


## `map` is target bone -> mannequin bone; `child` is target bone -> the target
## bone it points at, for the rest swing. False if the library is missing.
func setup(target: Skeleton3D, map: Dictionary, child: Dictionary) -> bool:
	if target == null or not ResourceLoader.exists(SOURCE_SCENE):
		push_warning("RigRetarget: nothing to drive, or no library.")
		return false
	_dst = target
	var scene: Node3D = (load(SOURCE_SCENE) as PackedScene).instantiate()
	scene.name = "AnimSource"
	add_child(scene)
	_src = scene.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _src == null or _player == null:
		scene.queue_free()
		return false
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.queue_free()
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.animation_finished.connect(func(clip: StringName) -> void: clip_finished.emit(clip))

	var count := _dst.get_bone_count()
	_order = _hierarchy_order(_dst)
	_feed.resize(count)
	_src_rest_inv.resize(count)
	_dst_swung.resize(count)
	_world.resize(count)
	_driven.resize(count)
	_driven.fill(1)
	for i in count:
		_feed[i] = -1
		_src_rest_inv[i] = Quaternion.IDENTITY
		_dst_swung[i] = Quaternion.IDENTITY
		_world[i] = Quaternion.IDENTITY

	var s_thigh_l := _src.find_bone(String(map.get("LeftUpLeg", "thigh_l")))
	var s_thigh_r := _src.find_bone(String(map.get("RightUpLeg", "thigh_r")))
	var d_thigh_l := _dst.find_bone("LeftUpLeg")
	var d_thigh_r := _dst.find_bone("RightUpLeg")
	if s_thigh_l >= 0 and s_thigh_r >= 0 and d_thigh_l >= 0 and d_thigh_r >= 0:
		var s_left := _flat(_src_rest(s_thigh_l).origin - _src_rest(s_thigh_r).origin)
		var d_left := _flat(_dst_rest(d_thigh_l).origin - _dst_rest(d_thigh_r).origin)
		_align = _arc(s_left, d_left)
		_align_inv = _align.inverse()

	var swings := {}
	for i in _order:
		var bone_name := _dst.get_bone_name(i)
		if not map.has(bone_name):
			continue
		var src := _src.find_bone(String(map[bone_name]))
		if src < 0:
			continue
		var swing := Quaternion.IDENTITY
		var kid_name: String = child.get(bone_name, "")
		var kid := _dst.find_bone(kid_name) if not kid_name.is_empty() else -1
		var src_kid := _src.find_bone(String(map.get(kid_name, ""))) if kid >= 0 else -1
		if kid >= 0 and src_kid >= 0:
			var d_dir := (_dst_rest(kid).origin - _dst_rest(i).origin).normalized()
			var s_dir := _align * (_src_rest(src_kid).origin - _src_rest(src).origin).normalized()
			swing = _arc(d_dir, s_dir)
		else:
			# Head, feet: square with the limb they end.
			var up := _dst.get_bone_parent(i)
			while up >= 0 and not swings.has(up):
				up = _dst.get_bone_parent(up)
			if up >= 0:
				swing = swings[up]
		swings[i] = swing
		_feed[i] = src
		_src_rest_inv[i] = _src_rest(src).basis.get_rotation_quaternion().inverse()
		_dst_swung[i] = swing * _dst_rest(i).basis.get_rotation_quaternion()

	_hips = _dst.find_bone("Hips")
	_src_pelvis = _src.find_bone("pelvis")
	if _hips >= 0 and _src_pelvis >= 0:
		_hips_rest = _dst.get_bone_rest(_hips).origin
		_pelvis_rest = _src_rest(_src_pelvis).origin
		_hip_scale = _dst_rest(_hips).origin.y / maxf(_pelvis_rest.y, 0.001)
		var parent := _dst.get_bone_parent(_hips)
		if parent >= 0:
			_hips_parent_inv = _dst_rest(parent).basis.inverse()

	_ready_to_play = true
	return true


func _src_rest(bone: int) -> Transform3D:
	return _src.get_bone_global_rest(bone)


func _dst_rest(bone: int) -> Transform3D:
	return _dst.get_bone_global_rest(bone)


static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length_squared() > 1e-10 else Vector3.RIGHT


## The shortest turn from one direction onto another, safe for opposites.
static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	if from.length_squared() < 1e-10 or to.length_squared() < 1e-10:
		return Quaternion.IDENTITY
	from = from.normalized()
	to = to.normalized()
	if from.dot(to) < -0.9999:
		var axis := from.cross(Vector3.UP)
		if axis.length_squared() < 1e-6:
			axis = from.cross(Vector3.RIGHT)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(from, to)


static func _hierarchy_order(skeleton: Skeleton3D) -> PackedInt32Array:
	var order := PackedInt32Array()
	var todo: Array[int] = []
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_parent(i) < 0:
			todo.append(i)
	while not todo.is_empty():
		var bone: int = todo.pop_front()
		order.append(bone)
		for kid in skeleton.get_bone_children(bone):
			todo.append(kid)
	return order


#region Playback
## Limits the clips to the named target bones — the orc's guard is his arms
## and head, over his own walking legs. Empty drives every bone again.
func set_mask(bones: PackedStringArray) -> void:
	if _dst == null:
		return
	_driven.fill(1 if bones.is_empty() else 0)
	for b in bones:
		var idx := _dst.find_bone(b)
		if idx >= 0:
			_driven[idx] = 1


func play(clip: StringName, fade: float = 0.2, speed: float = 1.0, restart: bool = false) -> bool:
	if not _ready_to_play or not _player.has_animation(clip):
		return false
	_target_weight = 1.0
	_fade_speed = 1.0 / maxf(fade, 0.01)
	if _clip == clip and _player.is_playing() and not restart:
		_player.speed_scale = maxf(speed, 0.0)
		return true
	_clip = clip
	if restart and _player.current_animation == String(clip):
		_player.stop()
	_player.play(clip, fade if _weight > 0.001 else 0.0)
	_player.speed_scale = maxf(speed, 0.0)
	return true


## Hands the skeleton back to whatever posed it before this.
func release(fade: float = 0.3) -> void:
	_target_weight = 0.0
	_fade_speed = 1.0 / maxf(fade, 0.01)


func weight() -> float:
	return _weight


func current_clip() -> StringName:
	return _clip if _target_weight > 0.0 else &""


func has_clip(clip: StringName) -> bool:
	return _ready_to_play and _player.has_animation(clip)


func clip_length(clip: StringName) -> float:
	if not has_clip(clip):
		return 0.0
	return _player.get_animation(clip).length


func clip_progress() -> float:
	if not _ready_to_play or _clip.is_empty():
		return 0.0
	var length := clip_length(_clip)
	if length <= 0.0 or not _player.is_playing():
		return 1.0
	return clampf(_player.current_animation_position / length, 0.0, 1.0)


## The moments, 0 to 1, when `bones` of the mannequin move fastest in `clip`:
## where each blow of a combo lands.
func measure_peaks(clip: StringName, bones: PackedStringArray,
		threshold: float = 0.55, spacing: float = 0.08) -> PackedFloat32Array:
	var key := "%s|%s|%s|%s" % [clip, ",".join(bones), threshold, spacing]
	if _peak_cache.has(key):
		return _peak_cache[key]
	var peaks := PackedFloat32Array()
	if not has_clip(clip):
		return peaks
	var ids := PackedInt32Array()
	for b in bones:
		var idx := _src.find_bone(b)
		if idx >= 0:
			ids.append(idx)
	var track := _sample(clip, ids, 90)
	var speed := PackedFloat32Array()
	var top := 0.0
	for i in track.size() - 1:
		var fastest := 0.0
		for b in ids.size():
			fastest = maxf(fastest, track[i + 1][b].distance_to(track[i][b]))
		speed.append(fastest)
		top = maxf(top, fastest)
	for i in range(1, speed.size() - 1):
		if speed[i] < top * threshold or speed[i] < speed[i - 1] or speed[i] < speed[i + 1]:
			continue
		var t := (float(i) + 0.5) / float(speed.size())
		if not peaks.is_empty() and t - peaks[peaks.size() - 1] < spacing:
			continue
		peaks.append(t)
	_peak_cache[key] = peaks
	return peaks


## When, after `after` of the way through, `bone` comes lowest: for the heavy
## combo, the moment the overhead blow meets the ground. 0 to 1.
func lowest_moment(clip: StringName, bone: String, after: float = 0.55) -> float:
	var key := "%s|%s|%s" % [clip, bone, after]
	if _low_cache.has(key):
		return _low_cache[key]
	var idx := _src.find_bone(bone)
	if idx < 0 or not has_clip(clip):
		return -1.0
	var track := _sample(clip, PackedInt32Array([idx]), 80)
	var best := -1.0
	var low := INF
	for i in track.size():
		var t := float(i) / float(track.size() - 1)
		if t > after and track[i][0].y < low:
			low = track[i][0].y
			best = t
	_low_cache[key] = best
	return best


func _sample(clip: StringName, ids: PackedInt32Array, steps: int) -> Array[PackedVector3Array]:
	var track: Array[PackedVector3Array] = []
	var length := clip_length(clip)
	var was := _player.current_animation
	var at := _player.current_animation_position
	_player.play(clip)
	for i in steps + 1:
		_player.seek(length * float(i) / float(steps), true)
		var row := PackedVector3Array()
		for idx in ids:
			row.append(_src.get_bone_global_pose(idx).origin)
		track.append(row)
	_player.stop()
	if not was.is_empty():
		_player.play(was)
		_player.seek(at, true)
	return track


## Steps the library and writes its pose onto the target. Call once a frame,
## after anything else that poses the target.
func advance(delta: float) -> void:
	if not _ready_to_play:
		return
	_weight = move_toward(_weight, _target_weight, _fade_speed * delta)
	if _weight <= 0.001:
		return
	# A cycle starts over by itself; a one-shot holds its last frame.
	if not _player.is_playing() and not _clip.is_empty():
		var anim := _player.get_animation(_clip)
		if anim != null and anim.loop_mode != Animation.LOOP_NONE:
			_player.play(_clip)
	_player.advance(delta)

	for i in _order:
		var parent := _dst.get_bone_parent(i)
		var parent_world := _world[parent] if parent >= 0 else Quaternion.IDENTITY
		var local := _dst.get_bone_pose_rotation(i)
		var src := _feed[i]
		if src >= 0 and _driven[i] == 1:
			var turned := _src.get_bone_global_pose(src).basis.get_rotation_quaternion() * _src_rest_inv[i]
			var wanted := _align * turned * _align_inv * _dst_swung[i]
			var wanted_local := (parent_world.inverse() * wanted).normalized()
			local = wanted_local if _weight >= 0.999 else local.slerp(wanted_local, _weight)
			_dst.set_bone_pose_rotation(i, local)
		_world[i] = parent_world * local

	if _hips >= 0 and _src_pelvis >= 0 and _driven[_hips] == 1:
		var travel := _src.get_bone_global_pose(_src_pelvis).origin - _pelvis_rest
		var moved := _hips_rest + _hips_parent_inv * (_align * travel) * _hip_scale
		_dst.set_bone_pose_position(_hips, _dst.get_bone_pose_position(_hips).lerp(moved, _weight))
#endregion
