extends SceneTree
## tools/hero_mixamo_clips.gd — Mixamo clips baked onto the heroes'
## mannequin (UAL 2's, the skeleton every hero on it plays: SkinnedRig
## MANNEQUIN_SCENE), the same transfer as tools/creature_clips.gd: each bone
## turned in the world as its Mixamo partner has turned from rest, after its
## rest is turned to point the way the partner's does.
##
##   godot --headless --path . --script res://tools/hero_mixamo_clips.gd
##
## In: CLIPS ([name here, fbx, from s, to s]). Out: ESCAPE_LIB, an
## AnimationLibrary with its tracks keyed as the mannequin's own clips are,
## loaded into every hero's library ([method SkinnedRig._build_mannequin]).
const HERO := "res://assets/anim/lab/ual2_mannequin.glb"
const OUT := "res://assets/anim/heroes/escape_clips.res"
## The ghoul's pin broken (2026-10-27, the user's word): from his back both
## feet kick it off and he springs up (Mixamo "Inverted Double Kick To Kip
## Up", from the moment he lies on his back).
const CLIPS := [
	["HX_KickUp", "res://assets/anim/heroes/mixamo/HX_Kick_To_Kip_Up.fbx", 1.3, 2.55],
]
const FPS := 30.0
const MIXAMO_NAMES := {
	"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "neck_01": "Neck", "Head": "Head",
	"clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm", "lowerarm_l": "LeftForeArm", "hand_l": "LeftHand",
	"thigh_l": "LeftUpLeg", "calf_l": "LeftLeg", "foot_l": "LeftFoot", "ball_l": "LeftToeBase",
	"clavicle_r": "RightShoulder", "upperarm_r": "RightArm", "lowerarm_r": "RightForeArm", "hand_r": "RightHand",
	"thigh_r": "RightUpLeg", "calf_r": "RightLeg", "foot_r": "RightFoot", "ball_r": "RightToeBase",
}
var _map := {}
var _aim := {}


func _initialize() -> void:
	_run.call_deferred()


func _pairs(fig: Skeleton3D) -> void:
	var chains := [["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"]]
	for s: String in ["l", "r"]:
		chains.append(["clavicle_" + s, "upperarm_" + s, "lowerarm_" + s, "hand_" + s, "middle_01_" + s])
		chains.append(["thigh_" + s, "calf_" + s, "foot_" + s, "ball_" + s])
		for fg: String in ["index", "middle", "ring", "pinky", "thumb"]:
			chains.append(["%s_01_%s" % [fg, s], "%s_02_%s" % [fg, s], "%s_03_%s" % [fg, s]])
	for ch: Array in chains:
		for i in ch.size():
			var b := StringName(ch[i])
			if fig.find_bone(b) < 0:
				continue
			_map[b] = b
			if i + 1 < ch.size() and fig.find_bone(StringName(ch[i + 1])) >= 0:
				_aim[b] = [StringName(ch[i + 1]), StringName(ch[i + 1])]


func _mixamo_name(m: String) -> String:
	if MIXAMO_NAMES.has(m):
		return String(MIXAMO_NAMES[m])
	var parts := m.split("_")
	if parts.size() == 3 and parts[1].is_valid_int():
		var side := "Left" if parts[2] == "l" else "Right"
		return "%sHand%s%d" % [side, parts[0].capitalize(), int(parts[1])]
	return "?" + m


func _run() -> void:
	var hero := (load(HERO) as PackedScene).instantiate() as Node3D
	root.add_child(hero)
	var fig := hero.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player0 := hero.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var some: Animation = player0.get_animation(player0.get_animation_list()[0])
	var prefix_path := String(some.track_get_path(0)).get_slice(":", 0)
	print("MANNEQUIN ", hero.get_path_to(fig), " bones ", fig.get_bone_count(), " tracks as ", prefix_path)
	_pairs(fig)
	var n := fig.get_bone_count()
	var order := PackedInt32Array()
	var done := {}
	while order.size() < n:
		for i in n:
			if not done.has(i) and (fig.get_bone_parent(i) < 0 or done.has(fig.get_bone_parent(i))):
				order.append(i)
				done[i] = true
	var out_lib := AnimationLibrary.new()
	for c: Array in CLIPS:
		var doc := FBXDocument.new()
		var st := FBXState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(String(c[1])), st) != OK:
			print("FAIL ", c[1])
			continue
		var mx := doc.generate_scene(st) as Node3D
		root.add_child(mx)
		var src := mx.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := mx.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var take := StringName("")
		for t: StringName in player.get_animation_list():
			if String(t) != "RESET":
				take = t
				break
		var prefix := ""
		for i in src.get_bone_count():
			var bn := src.get_bone_name(i)
			if bn.ends_with("Hips"):
				prefix = bn.substr(0, bn.length() - 4)
				break
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var anim := _bake(src, player, take, func(m: String) -> String: return prefix + _mixamo_name(m), fig, order,
				float(c[2]), float(c[3]))
		for t in anim.get_track_count():
			anim.track_set_path(t, NodePath(prefix_path + ":" + String(anim.track_get_path(t)).get_slice(":", 1)))
		out_lib.add_animation(StringName(c[0]), anim)
		print("CLIP ", c[0], " ", anim.length)
		mx.queue_free()
	print("HXB_OK ", ResourceSaver.save(out_lib, OUT))
	quit()


func _bake(src: Skeleton3D, player: AnimationPlayer, take: StringName, rename: Callable, fig: Skeleton3D,
		order: PackedInt32Array, t_from: float = 0.0, t_to: float = -1.0) -> Animation:
	var n := fig.get_bone_count()
	var d_rest: Array[Transform3D] = []
	for i in n:
		d_rest.append(fig.get_bone_global_rest(i).orthonormalized())
	var s_rest: Array[Transform3D] = []
	for i in src.get_bone_count():
		s_rest.append(src.get_bone_global_rest(i).orthonormalized())
	var from := PackedInt32Array()
	from.resize(n)
	from.fill(-1)
	var offset: Array[Basis] = []
	offset.resize(n)
	for key: StringName in _map:
		var t := fig.find_bone(String(key))
		var s := src.find_bone(rename.call(String(_map[key])))
		if t < 0 or s < 0:
			continue
		from[t] = s
		var align := Basis.IDENTITY
		if _aim.has(key):
			var tc := fig.find_bone(String(_aim[key][0]))
			var sc := src.find_bone(rename.call(String(_aim[key][1])))
			if tc >= 0 and sc >= 0:
				var a := (d_rest[tc].origin - d_rest[t].origin).normalized()
				var b := (s_rest[sc].origin - s_rest[s].origin).normalized()
				if a.length() > 0.5 and b.length() > 0.5 and a.dot(b) < 0.99999:
					var axis := a.cross(b)
					if axis.length() > 1e-6:
						align = Basis(axis.normalized(), a.angle_to(b))
		offset[t] = s_rest[s].basis.inverse() * align * d_rest[t].basis
	var hips := fig.find_bone("pelvis")
	var s_hips := src.find_bone(rename.call("pelvis"))
	var k := d_rest[hips].origin.y / s_rest[s_hips].origin.y
	var whole := player.get_animation(take).length
	var end := whole if t_to < 0.0 else minf(t_to, whole)
	var total := end - t_from
	var frames := maxi(int(round(total * FPS)), 1)
	var anim := Animation.new()
	anim.length = float(frames) / FPS
	anim.step = 1.0 / FPS
	var rot_track := {}
	for t in n:
		if from[t] >= 0:
			var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tr, NodePath("Skeleton3D:" + fig.get_bone_name(t)))
			rot_track[t] = tr
	var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, NodePath("Skeleton3D:pelvis"))
	player.play(take)
	player.seek(t_from, true)
	var hips0 := src.get_bone_global_pose(s_hips).origin
	var g: Array[Transform3D] = []
	g.resize(n)
	for f in frames + 1:
		player.seek(t_from + minf(float(f) / FPS, total), true)
		# in place over the ground (the hips' own drift taken out)
		var travel := src.get_bone_global_pose(s_hips).origin - hips0
		travel.y = 0.0
		for t in order:
			var p := fig.get_bone_parent(t)
			var pg: Transform3D = g[p] if p >= 0 else Transform3D.IDENTITY
			var rest_local := fig.get_bone_rest(t).orthonormalized()
			var s := from[t]
			var gt: Transform3D
			if s >= 0:
				var pose := src.get_bone_global_pose(s).orthonormalized()
				gt.basis = (pose.basis * offset[t]).orthonormalized()
				if t == hips:
					gt.origin = d_rest[t].origin + (pose.origin - s_rest[s].origin - travel) * k
				else:
					gt.origin = pg * rest_local.origin
			else:
				gt = pg * rest_local
			g[t] = gt
			if rot_track.has(t):
				var local := pg.affine_inverse() * gt
				anim.rotation_track_insert_key(rot_track[t], float(f) / FPS, local.basis.get_rotation_quaternion())
				if t == hips:
					anim.position_track_insert_key(pos_track, float(f) / FPS, local.origin)
	player.stop()
	return anim
