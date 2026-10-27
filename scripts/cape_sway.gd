class_name CapeSway
extends SkeletonModifier3D
## A cape that hangs (the user's word, 2026-10-27: the orc lord's cape stood
## off his back like a board when he leant into a cut). The mannequin's cape
## bones (`cape_joint1..6`, given to a skeleton that had none: [method
## OrcFighter._add_cape_bones]) from where they turn down his back: each laid
## a share of the way from where its body carries it toward hanging straight
## down, lagging behind as he moves and swinging after, never in at his body.

## The chain, top to bottom (bone indices).
var chain: PackedInt32Array = PackedInt32Array()
## Whose front the cape keeps behind (its `_forward()`): its owner.
var owner_body: Node3D
## How far toward hanging straight down (0 as carried, 1 plumb).
var hang: float = 0.7
## How quickly it follows where it would hang (per second), and how far a
## run throws it back (seconds of his speed).
var follow: float = 7.0
var trail: float = 0.07
## The body it hangs over, kept out of (the user's word, 2026-10-27: the cape
## went in through him): a capsule from `body_low` to `body_high` (bones),
## `body_radius` round (skeleton units; 0 from his shoulders' width).
var body_low: int = -1
var body_high: int = -1
var body_radius: float = 0.0
var shoulders: PackedInt32Array = PackedInt32Array()

var _from: int = -1
var _dirs: Array[Vector3] = []
var _last: Vector3 = Vector3.INF


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or chain.size() < 2:
		return
	var dt := get_process_delta_time()
	if dt <= 0.0:
		dt = 1.0 / 60.0
	if _from < 0:
		_find_hang(sk)
	if _from < 0:
		return
	var at := sk.global_position
	var vel := Vector3.ZERO
	if _last != Vector3.INF:
		vel = (at - _last) / dt
		vel.y = 0.0
		if vel.length() > 30.0:
			vel = Vector3.ZERO
	_last = at
	var fwd := Vector3.FORWARD
	if owner_body != null and owner_body.has_method(&"_forward"):
		fwd = owner_body.call(&"_forward")
	var world := sk.global_basis.orthonormalized()
	var to_skel := world.inverse()
	var k := 0.0
	for i in range(_from, chain.size()):
		var b := chain[i]
		var parent := sk.get_bone_parent(b)
		var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		var g := pg * sk.get_bone_pose(b)
		var off := _child_off(sk, i)
		var d := (g.basis * off)
		if d.length_squared() < 0.000001:
			continue
		d = d.normalized()
		# where it would hang, in the world: down, thrown back by his run,
		# and never in at his front
		var want := Vector3.DOWN - vel * trail - fwd * 0.35
		var flat_fwd := Vector3(fwd.x, 0.0, fwd.z).normalized()
		if want.dot(flat_fwd) > -0.05:
			want -= flat_fwd * (want.dot(flat_fwd) + 0.05)
		want = want.normalized()
		var j := i - _from
		if j >= _dirs.size():
			_dirs.append(want)
		_dirs[j] = _dirs[j].slerp(want, 1.0 - exp(-dt * follow)).normalized()
		var t := (to_skel * _dirs[j]).normalized()
		var aim := d.slerp(t, clampf(hang + k * 0.1, 0.0, 1.0)).normalized()
		k += 1.0
		aim = _out_of_body(sk, g.origin, aim, off.length())
		if d.dot(aim) > 0.99999:
			continue
		var q := Quaternion(d, aim)
		var nb := Basis(q) * g.basis
		var local := pg.basis.orthonormalized().inverse() * nb.orthonormalized()
		sk.set_bone_pose_rotation(b, local.get_rotation_quaternion())


## Bone `i` of the chain to its child, in its own frame (the last one: as its
## parent's was).
func _child_off(sk: Skeleton3D, i: int) -> Vector3:
	if i + 1 < chain.size():
		return sk.get_bone_rest(chain[i + 1]).origin
	return sk.get_bone_rest(chain[i]).origin


## Where down his back it turns to hang: the first bone whose child lies
## below it at rest.
func _find_hang(sk: Skeleton3D) -> void:
	for i in chain.size():
		var g := sk.get_bone_global_rest(chain[i])
		var d := g.basis * _child_off(sk, i)
		if d.normalized().y < -0.5:
			_from = i
			return
	_from = maxi(chain.size() - 3, 0)


## `aim` from `at` (skeleton space) turned so its end `long` along it stays
## outside his body (behind him, if it would go in).
func _out_of_body(sk: Skeleton3D, at: Vector3, aim: Vector3, long: float) -> Vector3:
	if body_low < 0 or body_high < 0:
		return aim
	var a := sk.get_bone_global_pose(body_low).origin
	var b := sk.get_bone_global_pose(body_high).origin
	var r := body_radius
	if r <= 0.0 and shoulders.size() == 2:
		r = sk.get_bone_global_pose(shoulders[0]).origin.distance_to(sk.get_bone_global_pose(shoulders[1]).origin) * 0.42
	if r <= 0.0:
		return aim
	var tip := at + aim * long
	var ab := b - a
	var u := clampf((tip - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var c := a + ab * u
	var out := tip - c
	if out.length() >= r:
		return aim
	if out.length_squared() < 0.000001:
		out = at - c
	tip = c + out.normalized() * r
	var d := tip - at
	return d.normalized() if d.length_squared() > 0.000001 else aim
