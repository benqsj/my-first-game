class_name BoneShatter
extends RefCounted

## A skinned figure broken into its bones where it stands: a skeleton cut down
## comes apart and its pieces fall and roll about the ground (the skeleton
## warrior's death).
##
## Each triangle of its meshes goes with the bone that holds most of its
## first corner, carried up to the nearest of `PIECES` (a finger with its
## hand, the helm with the skull, the ribs with the chest), and is laid down
## as it is posed this frame. Each piece is a [RigidBody3D] of its own with a
## box round it, on the world's layer only (nothing walks into it, it lies on
## the ground), thrown along `push` and out from the middle, spinning. They
## lie `linger` seconds, sink into the ground and are gone. Cosmetic: every
## peer breaks its own.

## The bones a figure breaks into; any other bone goes with the first of
## these above it.
const PIECES := [
	"head_joint", "chest_joint", "waist_joint", "pelvis_joint",
	"L_shoulder_joint", "L_elbow_joint", "L_wrist_joint",
	"R_shoulder_joint", "R_elbow_joint", "R_wrist_joint",
	"L_thigh_joint", "L_knee_joint", "L_ankle_joint",
	"R_thigh_joint", "R_knee_joint", "R_ankle_joint",
	"L_equip_joint", "R_equip_joint",
]
## What a piece weighs against its size, and how hard it is thrown.
const DENSITY := 60.0
const MAX_SOUNDS := 7


## Breaks every visible skinned mesh under `body`, posed on `skeleton`, into
## `world`; hides `body`. `push` is the way and the strength (m/s) of the
## blow that broke it.
static func burst(world: Node, body: Node3D, skeleton: Skeleton3D, push: Vector3,
		linger: float = 4.0, sink_time: float = 1.2) -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = []
	if world == null or body == null or skeleton == null or not skeleton.is_inside_tree():
		return out
	var n := skeleton.get_bone_count()
	# Where each bone is now, composed from the local poses (the global pose
	# can lag the clip by a frame), and which piece it goes with.
	var posed: Array[Transform3D] = []
	posed.resize(n)
	var piece_of := PackedInt32Array()
	piece_of.resize(n)
	var piece_set := {}
	for name: String in PIECES:
		var b := skeleton.find_bone(name)
		if b >= 0:
			piece_set[b] = true
	for i in n:
		var p := skeleton.get_bone_parent(i)
		var local := skeleton.get_bone_pose(i)
		posed[i] = local if p < 0 else posed[p] * local
	for i in n:
		var b := i
		while b >= 0 and not piece_set.has(b):
			b = skeleton.get_bone_parent(b)
		piece_of[i] = b if b >= 0 else 0
	var skel_xf := skeleton.global_transform
	# piece bone -> material -> SurfaceTool (world-space corners), and its box
	var parts := {}
	var boxes := {}
	var middle_sum := Vector3.ZERO
	var middle_count := 0
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.skin == null:
			continue
		var skin := mi.skin
		var bind_bone := PackedInt32Array()
		var bind_xf: Array[Transform3D] = []
		for k in skin.get_bind_count():
			var bone := skin.get_bind_bone(k)
			if bone < 0:
				bone = skeleton.find_bone(String(skin.get_bind_name(k)))
			bind_bone.append(maxi(bone, 0))
			bind_xf.append(skel_xf * posed[maxi(bone, 0)] * skin.get_bind_pose(k))
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if verts.is_empty() or bones.is_empty():
				continue
			var per := floori(float(bones.size()) / float(verts.size()))
			var material := mi.get_active_material(s)
			# Each corner skinned into the world, and the bone holding most of it.
			var wv := PackedVector3Array()
			wv.resize(verts.size())
			var wn := PackedVector3Array()
			wn.resize(verts.size())
			var owner := PackedInt32Array()
			owner.resize(verts.size())
			for v in verts.size():
				var acc := Vector3.ZERO
				var nacc := Vector3.ZERO
				var best := -1.0
				var best_bone := 0
				var total := 0.0
				for j in per:
					var w := weights[v * per + j]
					if w <= 0.0:
						continue
					var k := bones[v * per + j]
					if k >= bind_xf.size():
						continue
					var xf: Transform3D = bind_xf[k]
					acc += (xf * verts[v]) * w
					if not norms.is_empty():
						nacc += (xf.basis * norms[v]) * w
					total += w
					if w > best:
						best = w
						best_bone = bind_bone[k]
				wv[v] = acc / total if total > 0.0 else skel_xf * verts[v]
				wn[v] = nacc.normalized() if nacc.length_squared() > 0.0 else Vector3.UP
				owner[v] = piece_of[best_bone]
			var tri_count := floori((index.size() if not index.is_empty() else verts.size()) / 3.0)
			for t in tri_count:
				var a := index[t * 3] if not index.is_empty() else t * 3
				var b := index[t * 3 + 1] if not index.is_empty() else t * 3 + 1
				var c := index[t * 3 + 2] if not index.is_empty() else t * 3 + 2
				var piece := owner[a]
				if not parts.has(piece):
					parts[piece] = {}
				var by_mat: Dictionary = parts[piece]
				if not by_mat.has(material):
					var tool := SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					by_mat[material] = tool
				var st: SurfaceTool = by_mat[material]
				for i: int in [a, b, c]:
					st.set_normal(wn[i])
					st.set_uv(uvs[i] if i < uvs.size() else Vector2.ZERO)
					st.add_vertex(wv[i])
					boxes[piece] = (boxes[piece] as AABB).expand(wv[i]) if boxes.has(piece) else AABB(wv[i], Vector3.ZERO)
					middle_sum += wv[i]
					middle_count += 1
	if parts.is_empty():
		return out
	# The middle of the whole, to throw the pieces out from.
	var middle := middle_sum / maxf(float(middle_count), 1.0)
	var sounds := [0]
	for piece: int in parts:
		var by_mat: Dictionary = parts[piece]
		var box: AABB = boxes[piece]
		var centre := box.get_center()
		var mesh := ArrayMesh.new()
		for m: Variant in by_mat:
			var st: SurfaceTool = by_mat[m]
			st.set_material(m as Material)
			st.commit(mesh)
		var rb := RigidBody3D.new()
		rb.name = "Bone_%s" % skeleton.get_bone_name(piece)
		rb.collision_layer = 0
		rb.collision_mask = 1
		var size := box.size.max(Vector3.ONE * 0.06)
		rb.mass = clampf(size.x * size.y * size.z * DENSITY, 0.2, 8.0)
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size * 0.85
		shape.shape = bs
		rb.add_child(shape)
		var draw := MeshInstance3D.new()
		draw.mesh = mesh
		# The corners are where they stood in the world: drawn back from the
		# piece's middle.
		draw.position = -centre
		rb.add_child(draw)
		var phys := PhysicsMaterial.new()
		phys.bounce = 0.25
		phys.friction = 0.8
		rb.physics_material_override = phys
		world.add_child(rb)
		rb.global_position = centre
		var out_dir := centre - middle
		out_dir.y = 0.0
		var spread := out_dir.normalized() * randf_range(0.6, 1.8) if out_dir.length() > 0.01 else Vector3.ZERO
		var high := clampf(centre.y - body.global_position.y, 0.0, 2.0)
		rb.linear_velocity = push * randf_range(0.5, 1.1) * (0.5 + 0.5 * high / 2.0) + spread \
				+ Vector3.UP * randf_range(0.3, 1.6)
		rb.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 7.0
		# The bigger ones are heard landing (a few).
		if size.length() > 0.25:
			rb.contact_monitor = true
			rb.max_contacts_reported = 1
			rb.body_entered.connect(func(_other: Node) -> void:
				if sounds[0] < MAX_SOUNDS and rb.linear_velocity.length() > 1.6:
					sounds[0] += 1
					ImpactFx.strike(rb, rb.global_position, &"bone", 0.55)
				rb.set_deferred(&"contact_monitor", false), CONNECT_ONE_SHOT)
		var tw := rb.create_tween()
		tw.tween_interval(linger + randf_range(0.0, 0.6))
		tw.tween_callback(func() -> void: rb.freeze = true)
		tw.tween_property(rb, "position:y", -0.7, sink_time).as_relative()
		tw.tween_callback(rb.queue_free)
		out.append(rb)
	body.visible = false
	return out
