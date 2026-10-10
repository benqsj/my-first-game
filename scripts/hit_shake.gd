class_name HitShake
extends SkeletonModifier3D
## A body shaken where a blow holds it (the hit stop, [HitFeel]): its hips
## jolted to and fro along the blow, quickly, dying away — so a body held
## still by a blow reads as struck, not as the game catching (the user's
## word, 2026-10-10: the hold felt like a hitch). Laid last on the skeleton,
## over whatever clips and other modifiers made of it.

## How fast it shakes (to and fro a second).
const RATE := 26.0
## The hips' names looked for; else the skeleton's first root bone.
const HIPS := ["pelvis", "Pelvis", "Hips", "hips", "mixamorig:Hips", "root"]

var _bone: int = -1
var _along := Vector3.ZERO
var _amount: float = 0.0
var _from_ms: int = 0
var _for_ms: int = 0


## `who` shaken `amount` metres along `along` (world; flat), dying away over
## `seconds`. A new shake takes the place of one still going.
static func shake(who: Node, along: Vector3, amount: float, seconds: float) -> void:
	if who == null or amount <= 0.0 or seconds <= 0.0:
		return
	var skel := _skeleton_of(who)
	if skel == null:
		return
	var it := skel.get_node_or_null(^"HitShake") as HitShake
	if it == null:
		it = HitShake.new()
		it.name = &"HitShake"
		skel.add_child(it)
	it.start(along, amount, seconds)


static func _skeleton_of(who: Node) -> Skeleton3D:
	if who is Skeleton3D:
		return who as Skeleton3D
	var best: Skeleton3D = null
	for node in who.find_children("*", "Skeleton3D", true, false):
		var s := node as Skeleton3D
		if best == null or s.get_bone_count() > best.get_bone_count():
			best = s
	return best


func start(along: Vector3, amount: float, seconds: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _bone < 0:
		for n: String in HIPS:
			_bone = skel.find_bone(n)
			if _bone >= 0:
				break
		if _bone < 0 and skel.get_bone_count() > 0:
			_bone = 0
	var flat := Vector3(along.x, 0.0, along.z)
	if flat.length_squared() < 0.0001:
		flat = skel.global_basis.x
		flat.y = 0.0
	_along = flat.normalized()
	_amount = amount
	_from_ms = HitFeel.now_ms()
	_for_ms = maxi(int(seconds * 1000.0), 1)


## How far it is shaken now (world, metres), for a test.
func offset() -> Vector3:
	var t := float(HitFeel.now_ms() - _from_ms) / 1000.0
	var u := t * 1000.0 / float(_for_ms)
	if _amount <= 0.0 or u >= 1.0 or u < 0.0:
		return Vector3.ZERO
	var fade := (1.0 - u) * (1.0 - u)
	# a square-ish to and fro: first along the blow, then back past still
	var wave := sin(TAU * RATE * t)
	wave = signf(wave) * sqrt(absf(wave))
	return _along * _amount * fade * wave


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or _bone < 0 or _bone >= skel.get_bone_count():
		return
	var off := offset()
	if off == Vector3.ZERO:
		return
	# world -> the bone's parent's space (the skeleton's, for a root bone)
	var parent := skel.get_bone_parent(_bone)
	var frame := skel.global_transform
	if parent >= 0:
		frame = frame * skel.get_bone_global_pose(parent)
	var local := frame.basis.inverse() * off
	skel.set_bone_pose_position(_bone, skel.get_bone_pose_position(_bone) + local)
