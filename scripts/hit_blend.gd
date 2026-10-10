class_name HitBlend
extends SkeletonModifier3D
## A second hit clip laid over the one playing, by how far the blow came from
## between their two sides (the user's word, 2026-10-10: the reactions went
## by four sides only). [SkinnedRig] plays the clip of the nearer side; this
## takes `weight` of the other's pose at the same share of its length, so a
## blow from in front and to the left is part of each. Every bone the clip
## turns; the hips' place too. First on the skeleton, right after the clips,
## so all the rest (the stride, the lean, the feet) lies over the mix.

## The other side's clip, and how far through the main one is (0..1).
var clip: Animation
var share: float = 0.0
## 0 = only the clip playing, up to 0.5 = half each (a blow from between).
var weight: float = 0.0

var _tracks: Array[Vector2i] = []
var _hips := Vector2i(-1, -1)
var _for: Animation


func _ready() -> void:
	active = true


func _find(skel: Skeleton3D) -> void:
	_for = clip
	_tracks.clear()
	_hips = Vector2i(-1, -1)
	if clip == null:
		return
	for i in clip.get_track_count():
		var bone := skel.find_bone(String(clip.track_get_path(i)).get_slice(":", 1))
		if bone < 0:
			continue
		match clip.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				_tracks.append(Vector2i(i, bone))
			Animation.TYPE_POSITION_3D:
				if bone == skel.find_bone("pelvis"):
					_hips = Vector2i(i, bone)


func _process_modification() -> void:
	if weight <= 0.001 or clip == null:
		return
	var skel := get_skeleton()
	if skel == null:
		return
	if _for != clip:
		_find(skel)
	var at := clampf(share, 0.0, 1.0) * clip.length
	for tb in _tracks:
		var own := skel.get_bone_pose_rotation(tb.y)
		skel.set_bone_pose_rotation(tb.y, own.slerp(clip.rotation_track_interpolate(tb.x, at), weight))
	if _hips.x >= 0:
		var own_at := skel.get_bone_pose_position(_hips.y)
		skel.set_bone_pose_position(_hips.y, own_at.lerp(clip.position_track_interpolate(_hips.x, at), weight))
