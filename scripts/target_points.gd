class_name TargetPoints
extends RefCounted

## Where on a creature a lock can sit.
##
## Something small is one point, about where the old lock sat. Something big —
## taller than `BIG` — is three: its legs, its middle and its head, so a lock on
## a golem or an orc can be put on whichever part of it the fight is about. The
## points come from the creature's own model, measured once: the box its meshes
## make, in its own frame, sliced at the legs, the belly and the head. A head
## bone, where the skeleton has one, stands in for the top slice, so the mark
## follows the head when it moves.

const BIG := 1.9
const LEGS := 0.22
const BELLY := 0.55
const HEAD := 0.88
const NAMES := ["legs", "belly", "head"]


## World-space points on `who`, lowest first. Never empty.
static func of(who: Node3D) -> Array[Vector3]:
	var info := _measure(who)
	var out: Array[Vector3] = []
	var xf := who.global_transform
	for local in info["points"]:
		out.append(xf * (local as Vector3))
	var head: Node3D = info.get("head_follow")
	if head != null and is_instance_valid(head) and out.size() == 3:
		out[2] = head.global_position
	return out


## Which slice is the default when a lock first lands: the middle of a big one.
static func default_index(who: Node3D) -> int:
	return 1 if of(who).size() == 3 else 0


static func _measure(who: Node3D) -> Dictionary:
	if who.has_meta(&"_target_points"):
		return who.get_meta(&"_target_points")
	var box := AABB()
	var first := true
	var inv := who.global_transform.affine_inverse()
	for node in who.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree() or _is_overlay(mi, who):
			continue
		var local := inv * mi.global_transform * mi.get_aabb()
		# A skinned mesh's own box is its bind pose's, which can be anything
		# (the orc's is 4 cm: its model is in other units, put right by its
		# skeleton): the bones it rides are measured in too.
		var bones := _bone_box(mi, inv)
		if bones.size != Vector3.ZERO:
			local = local.merge(bones)
		box = local if first else box.merge(local)
		first = false
	var info := {}
	if first or box.size.y < BIG:
		# Small, or nothing to measure: the single point the lock always used.
		info["points"] = [Vector3(0.0, 0.8, 0.0)]
	else:
		var mid := box.get_center()
		var bottom := box.position.y
		var h := box.size.y
		info["points"] = [
			Vector3(mid.x, bottom + h * LEGS, mid.z),
			Vector3(mid.x, bottom + h * BELLY, mid.z),
			Vector3(mid.x, bottom + h * HEAD, mid.z),
		]
		info["head_follow"] = _head_attachment(who)
	who.set_meta(&"_target_points", info)
	return info


## The box the bones of `mi`'s skeleton make, in `inv`'s frame (none when
## it has no skin), the head's bone given a skull on top of it.
static func _bone_box(mi: MeshInstance3D, inv: Transform3D) -> AABB:
	if mi.skin == null or mi.skeleton.is_empty():
		return AABB()
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skel == null or skel.get_bone_count() == 0:
		return AABB()
	var to := inv * skel.global_transform
	var box := AABB(to * skel.get_bone_global_pose(0).origin, Vector3.ZERO)
	for i in skel.get_bone_count():
		box = box.expand(to * skel.get_bone_global_pose(i).origin)
	# the topmost bone is the head's root, not its crown
	box.size.y *= 1.06
	return box


## Health bars, trails and the like hang off a creature without being part of
## its body; measuring them in would make everything a head taller.
static func _is_overlay(node: Node, who: Node) -> bool:
	var at := node
	while at != null and at != who:
		if at is HealthBar or at is SwordTrail or at is TargetMarker or (at is Node3D and (at as Node3D).top_level):
			return true
		at = at.get_parent()
	return false


## A node riding the head bone, if there is a skeleton with one.
static func _head_attachment(who: Node3D) -> Node3D:
	for node in who.find_children("*", "Skeleton3D", true, false):
		var skel := node as Skeleton3D
		for i in skel.get_bone_count():
			var bone := skel.get_bone_name(i).to_lower()
			if bone == "head" or bone.ends_with(":head") or bone.ends_with("_head") or bone == "head_01":
				var at := BoneAttachment3D.new()
				at.name = "TargetHead"
				skel.add_child(at)
				at.bone_name = skel.get_bone_name(i)
				return at
	for name in ["head", "Head", "skull"]:
		var joint := who.find_child(name, true, false) as Node3D
		if joint != null:
			return joint
	return null
