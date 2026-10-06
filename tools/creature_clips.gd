extends SceneTree

## tools/creature_clips.gd — the mannequin's clips (UAL 2's and Kevin's) baked
## onto Polysplit's 99-bone skeleton, the one all thirteen Biped Creatures
## share (CREATURES_PACK.md §5), so any of them plays them as its own.
##
##   godot --headless --path . --script res://tools/creature_clips.gd
##
## Out: assets/creatures/anim/biped_clips.scn (the bare skeleton and an
## AnimationPlayer holding every clip, for [SkeletonAnim] as `clip_source`)
## and biped_clip_meta.json (how far the hips travel in each, for
## [ClipFighter]).
##
## Each figure bone is turned in the world as its partner on the mannequin
## has turned from rest, after its rest has been turned to point the way the
## partner's does (both rests are T-poses facing +Z, a few degrees apart):
##   global = pose · rest_src⁻¹ · align · rest_fig
## Bones with no partner (hair, cape, coat tails, the equip and bow bones)
## ride their parents at rest. The hips are carried as well, by the
## mannequin's hip travel scaled to the figure's height; what the root carries
## across the ground is taken out (the clips are in place) and goes to the
## meta instead, [forward, left] in metres at the figure's size.

const MQ := "res://assets/anim/lab/ual2_mannequin.glb"
const KV := "res://assets/anim/lab/kevin_lib.res"
## The mage hero's own clips on the mannequin (casts, the staff held).
const MAGE := "res://assets/anim/heroes/mage_mannequin.res"
const FIG := "res://assets/creatures/Skeleton_Base.fbx"
const OUT := "res://assets/creatures/anim/biped_clips.scn"
const META := "res://assets/creatures/anim/biped_clip_meta.json"
const FPS := 30.0

## [name here, clip on the mannequin, a cycle]
const CLIPS := [
	["CR_Idle", "KV_Idle01", true],
	["CR_CombatIdle", "KV_CombatIdle1H01", true],
	["CR_ShieldIdle", "Idle_Shield", true],
	["CR_Walk", "KV_Walk01_Forward", true],
	["CR_WalkBack", "KV_Walk01_Backward", true],
	["CR_StrafeL", "KV_StrafeWalk01_Left", true],
	["CR_StrafeR", "KV_StrafeWalk01_Right", true],
	["CR_Run", "KV_Run01_Forward", true],
	["CR_Slash1", "KV_Attack1H01_R", false],
	["CR_Slash2", "KV_Attack1H02_R", false],
	["CR_Slash3", "KV_Attack1H03_R", false],
	["CR_Slash4", "KV_Attack1H04_R", false],
	["CR_Slash5", "KV_Attack1H05_R", false],
	["CR_ShieldBash", "KV_AttackShield01", false],
	["CR_ShieldBash2", "KV_AttackShield02", false],
	["CR_ShieldDash", "Shield_Dash", false],
	["CR_Block", "KV_BlockShield01_Loop", true],
	["CR_BlockHit", "KV_BlockShield01_Hit", false],
	["CR_Hit", "KV_CombatDamage01", false],
	["CR_Hit2", "KV_CombatDamage02", false],
	["CR_Stun", "KV_Stun01", false],
	["CR_Death", "KV_CombatDeath01", false],
	["CR_Death2", "KV_CombatDeath02", false],
	["CR_Dodge", "KV_Dodge01", false],
	["CR_Punch1", "KV_AttackPunch01_R", false],
	["CR_Punch2", "KV_AttackPunch03_R", false],
	["CR_Kick", "KV_AttackKick01_R", false],
	["CR_PunchL", "KV_AttackPunch01_L", false],
	["CR_Heavy1", "KV_Attack2H01", false],
	["CR_Heavy2", "KV_Attack2H02", false],
	["CR_Heavy3", "KV_Attack2H03", false],
	["CR_Heavy4", "KV_Attack2H04", false],
	["CR_HeavyIdle", "KV_CombatIdle2H01", true],
	["CR_GroundPound", "Sword_GroundPound", false],
	["CR_SwordCombo", "Sword_Regular_Combo", false],
	["CR_HeavyCombo", "Sword_Heavy_Combo", false],
	["CR_Knee", "Melee_Knee", false],
	["CR_IdleWounded", "KV_IdleWounded01", true],
	["CR_Sprint", "KV_Sprint01_Forward", true],
	["CR_Death3", "KV_CombatDeath03", false],
	["CR_Death4", "KV_CombatDeath04", false],
	["CR_BowNotch", "Bow_Notch", false],
	["CR_BowAim", "Bow_Aim_Neutral", true],
	["CR_BowShoot", "Bow_Shoot", false],
	["CR_BowRapid", "Bow_RapidShoot", false],
	["CR_MG_Idle", "MG_Idle", true],
	["CR_MG_Walk", "MG_Walk", true],
	["CR_MG_WalkBack", "MG_Walk_Back", true],
	["CR_MG_WalkL", "MG_Walk_Left", true],
	["CR_MG_WalkR", "MG_Walk_Right", true],
	["CR_MG_Run", "MG_Run", true],
	["CR_MG_Throw", "MG_Cast_Throw", false],
	["CR_MG_Ground", "MG_Cast_Ground", false],
	["CR_MG_Blast", "MG_Cast_Blast", false],
	["CR_MG_Raise", "MG_Cast_2H", false],
	["CR_MG_Hit", "MG_Hit", false],
	["CR_MG_Death", "MG_Death", false],
	["CR_Staff1", "KV_AttackPolearm01", false],
	["CR_Staff2", "KV_AttackPolearm03", false],
	# Nock and draw (the hand on the string at 0.63 s, full at 1.05), held on
	# the aim a breath, and loosed at 1.45 s (BowFighter.LOOSE_AT).
	["CR_BowShot", [["Bow_Notch", 0.0, 1.25], ["Bow_Aim_Neutral", 0.0, 0.2], ["Bow_Shoot", 0.0, -1.0]], false],
	["CR_PunchCombo", "Melee_Combo", false],
	["CR_Hook", "Melee_Hook", false],
	["CR_Uppercut", "Melee_Uppercut", false],
	["CR_ZombieIdle", "Zombie_Idle", true],
	["CR_ZombieWalk", "Zombie_Walk_Fwd", true],
	["CR_ZombieRun", "Zombie_Run_Fwd", true],
	["CR_ZombieScratch", "Zombie_Scratch", false],
	["CR_ZombieBite", "Zombie_Bite", false],
	["CR_Rise", "Zombie_Spawn", false],
]

## Clips made of two baked here: the legs (and hips) of the first, the body
## from the waist up of the second, the second looped under the first's
## length. The skeleton warrior walking in behind its raised shield.
## [name here, legs from, waist up from]
const LAYERED := [
	["CR_ShieldWalk", "CR_Walk", "CR_Block"],
	["CR_ShieldBack", "CR_WalkBack", "CR_Block"],
	["CR_ShieldL", "CR_StrafeL", "CR_Block"],
	["CR_ShieldR", "CR_StrafeR", "CR_Block"],
]

var _map := {}  # figure bone -> mannequin bone
var _aim := {}  # figure bone -> [figure child, mannequin child] its direction is taken toward


func _initialize() -> void:
	_run.call_deferred()


func _pairs() -> void:
	_map = {&"pelvis_joint": &"pelvis", &"waist_joint": &"spine_01", &"chest_joint": &"spine_03",
			&"neck_joint": &"neck_01", &"head_joint": &"Head"}
	_aim = {&"pelvis_joint": [&"waist_joint", &"spine_01"], &"waist_joint": [&"chest_joint", &"spine_03"],
			&"chest_joint": [&"neck_joint", &"neck_01"], &"neck_joint": [&"head_joint", &"Head"]}
	for s: String in ["l", "r"]:
		var S := s.to_upper()
		var chain := [["clavicle", "clavicle"], ["shoulder", "upperarm"], ["elbow", "lowerarm"], ["wrist", "hand"],
				["thigh", "thigh"], ["knee", "calf"], ["ankle", "foot"], ["ball", "ball"]]
		for i in chain.size():
			var f := StringName("%s_%s_joint" % [S, chain[i][0]])
			_map[f] = StringName("%s_%s" % [chain[i][1], s])
			if i != 3 and i != 7:
				_aim[f] = [StringName("%s_%s_joint" % [S, chain[i + 1][0]]), StringName("%s_%s" % [chain[i + 1][1], s])]
		_aim[StringName("%s_wrist_joint" % S)] = [StringName("%s_midFinger_joint1" % S), StringName("middle_01_%s" % s)]
		_aim[StringName("%s_ball_joint" % S)] = [StringName("%s_toe_joint" % S), StringName("ball_leaf_%s" % s)]
		for fg: Array in [["index", "index"], ["mid", "middle"], ["ring", "ring"], ["pinky", "pinky"], ["thumb", "thumb"]]:
			for k in 3:
				var f := StringName("%s_%sFinger_joint%d" % [S, fg[0], k + 1])
				_map[f] = StringName("%s_%02d_%s" % [fg[1], k + 1, s])
				if k < 2:
					_aim[f] = [StringName("%s_%sFinger_joint%d" % [S, fg[0], k + 2]), StringName("%s_%02d_%s" % [fg[1], k + 2, s])]


func _run() -> void:
	_pairs()
	var mq := (load(MQ) as PackedScene).instantiate() as Node3D
	root.add_child(mq)
	var src := mq.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := mq.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	for src_lib: AnimationLibrary in [player.get_animation_library(&""), load(KV) as AnimationLibrary,
			load(MAGE) as AnimationLibrary]:
		for clip: StringName in src_lib.get_animation_list():
			lib.add_animation(clip, src_lib.get_animation(clip))
	for clip: StringName in lib.get_animation_list():
		Moveset.complete(lib.get_animation(clip), src)
	for lib_name: StringName in player.get_animation_library_list():
		player.remove_animation_library(lib_name)
	player.add_animation_library(&"", lib)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

	var fig_root := (load(FIG) as PackedScene).instantiate() as Node3D
	root.add_child(fig_root)
	var fig := fig_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var n := fig.get_bone_count()

	# Rests, parents first.
	var order := PackedInt32Array()
	var done := {}
	while order.size() < n:
		for i in n:
			if not done.has(i) and (fig.get_bone_parent(i) < 0 or done.has(fig.get_bone_parent(i))):
				order.append(i)
				done[i] = true
	var d_rest: Array[Transform3D] = []
	for i in n:
		d_rest.append(fig.get_bone_global_rest(i).orthonormalized())
	var s_rest: Array[Transform3D] = []
	for i in src.get_bone_count():
		s_rest.append(src.get_bone_global_rest(i).orthonormalized())
	var from := PackedInt32Array()
	from.resize(n)
	from.fill(-1)
	var offset: Array[Basis] = []  # rest_src⁻¹ · align · rest_fig, per figure bone
	offset.resize(n)
	for key: StringName in _map:
		var t := fig.find_bone(String(key))
		var s := src.find_bone(String(_map[key]))
		if t < 0 or s < 0:
			push_error("no bone %s / %s" % [key, _map[key]])
			continue
		from[t] = s
		var align := Basis.IDENTITY
		if _aim.has(key):
			var tc := fig.find_bone(String(_aim[key][0]))
			var sc := src.find_bone(String(_aim[key][1]))
			if tc >= 0 and sc >= 0:
				var a := (d_rest[tc].origin - d_rest[t].origin).normalized()
				var b := (s_rest[sc].origin - s_rest[s].origin).normalized()
				if a.length() > 0.5 and b.length() > 0.5 and a.dot(b) < 0.99999:
					var axis := a.cross(b)
					if axis.length() > 1e-6:
						align = Basis(axis.normalized(), a.angle_to(b))
		offset[t] = s_rest[s].basis.inverse() * align * d_rest[t].basis
	var hips := fig.find_bone("pelvis_joint")
	var s_hips := src.find_bone("pelvis")
	var s_root := src.find_bone("root")
	var k := d_rest[hips].origin.y / s_rest[s_hips].origin.y
	print("height ratio ", k)

	var out_lib := AnimationLibrary.new()
	var meta := {}
	var g: Array[Transform3D] = []
	g.resize(n)
	for c: Array in CLIPS:
		# A clip of several: [[mannequin clip, from s, to s], ...] played one
		# after the other (the archer's draw, aim and loose as one move).
		var segments: Array = (c[1] as Array).duplicate(true) if c[1] is Array else [[c[1], 0.0, -1.0]]
		var total := 0.0
		var missing := false
		for seg: Array in segments:
			if not lib.has_animation(StringName(seg[0])):
				push_error("no clip " + String(seg[0]))
				missing = true
				break
			var seg_len := lib.get_animation(StringName(seg[0])).length
			if float(seg[2]) < 0.0 or float(seg[2]) > seg_len:
				seg[2] = seg_len
			total += float(seg[2]) - float(seg[1])
		if missing:
			continue
		var loop: bool = c[2]
		var frames := maxi(int(round(total * FPS)), 1)
		var count := frames if loop else frames + 1
		var anim := Animation.new()
		anim.length = float(frames) / FPS
		anim.step = 1.0 / FPS
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		var rot_track := {}
		for t in n:
			if from[t] >= 0 or t == hips:
				var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(tr, NodePath("Skeleton3D:" + fig.get_bone_name(t)))
				rot_track[t] = tr
		var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, NodePath("Skeleton3D:pelvis_joint"))
		player.play(StringName(segments[0][0]))
		player.seek(float(segments[0][1]), true)
		var root0 := src.get_bone_global_pose(s_root).origin if s_root >= 0 else Vector3.ZERO
		var path := []
		var playing := String(segments[0][0])
		for f in count:
			var time := minf(float(f) / FPS, total)
			var seg_i := 0
			while seg_i < segments.size() - 1 and time > float(segments[seg_i][2]) - float(segments[seg_i][1]):
				time -= float(segments[seg_i][2]) - float(segments[seg_i][1])
				seg_i += 1
			var seg: Array = segments[seg_i]
			if String(seg[0]) != playing:
				playing = String(seg[0])
				player.play(StringName(playing))
			player.seek(minf(float(seg[1]) + time, float(seg[2])), true)
			var travel := (src.get_bone_global_pose(s_root).origin - root0) if s_root >= 0 else Vector3.ZERO
			travel.y = 0.0
			path.append([snappedf(travel.z * k, 0.0001), snappedf(travel.x * k, 0.0001), 0.0])
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
		out_lib.add_animation(StringName(c[0]), anim)
		meta[String(c[0])] = {"frames": count, "fps": int(FPS), "loop": loop, "hips": path, "from": str(c[1])}
		print("CLIP ", c[0], " <- ", c[1], " frames ", count, " travel %.2f" % float(path[-1][0]))

	_layer(out_lib, meta, fig)

	# The bare skeleton and the player, as a scene SkeletonAnim can load.
	var holder := Node3D.new()
	holder.name = "BipedClips"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	holder.add_child(skel)
	skel.owner = holder
	for i in n:
		skel.add_bone(fig.get_bone_name(i))
	for i in n:
		skel.set_bone_parent(i, fig.get_bone_parent(i))
		skel.set_bone_rest(i, fig.get_bone_rest(i))
	skel.reset_bone_poses()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	holder.add_child(ap)
	ap.owner = holder
	ap.add_animation_library(&"", out_lib)
	var packed := PackedScene.new()
	packed.pack(holder)
	var err := ResourceSaver.save(packed, OUT)
	var file := FileAccess.open(META, FileAccess.WRITE)
	file.store_string(JSON.stringify(meta))
	file.close()

	# Where the pack's weapons reach, in their bones' own frames (for the
	# Brawler's weapon_tip).
	for pair: Array in [["Skeleton_Warrior", "Skeleton_Warrior_Sword", "R_equip_joint"],
			["Orc", "Orc_Sword", "R_equip_joint"], ["Goblin", "Goblin_Club", "R_equip_joint"],
			["Ogre", "Ogre_Club", "R_equip_joint"], ["Skeleton_Mage", "Skeleton_Mage_Staff", "R_equip_joint"]]:
		var sc := (load("res://assets/creatures/%s.fbx" % pair[0]) as PackedScene).instantiate()
		var mi := sc.find_child(pair[1], true, false) as MeshInstance3D
		var sk := sc.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var bone := sk.find_bone(pair[2])
		var bt := sk.get_bone_global_rest(bone)
		var far := Vector3.ZERO
		var far_d := 0.0
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var d := v.distance_to(bt.origin)
			if d > far_d:
				far_d = d
				far = v
		print("TIP ", pair[1], " on ", pair[2], " local ", bt.affine_inverse() * far, " length %.2f" % far_d)
		sc.free()
	print("SAVED ", OUT, " err ", err, " clips ", out_lib.get_animation_list().size())
	quit()


## The LAYERED clips, out of clips already baked: every key of the legs'
## clip kept, the waist and all above it turned as the other clip has them
## at that moment (looped).
func _layer(out_lib: AnimationLibrary, meta: Dictionary, fig: Skeleton3D) -> void:
	var waist := fig.find_bone("waist_joint")
	for c: Array in LAYERED:
		var legs := out_lib.get_animation(StringName(c[1]))
		var upper := out_lib.get_animation(StringName(c[2]))
		if legs == null or upper == null:
			push_error("layered %s: missing %s / %s" % [c[0], c[1], c[2]])
			continue
		var anim := legs.duplicate(true) as Animation
		var swapped := 0
		for tr in anim.get_track_count():
			if anim.track_get_type(tr) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := fig.find_bone(String(anim.track_get_path(tr)).get_slice(":", 1))
			var b := bone
			while b >= 0 and b != waist:
				b = fig.get_bone_parent(b)
			if b != waist:
				continue
			var src := upper.find_track(anim.track_get_path(tr), Animation.TYPE_ROTATION_3D)
			if src < 0:
				continue
			for k in anim.track_get_key_count(tr):
				var t := fmod(anim.track_get_key_time(tr, k), upper.length)
				anim.track_set_key_value(tr, k, upper.rotation_track_interpolate(src, t))
			swapped += 1
		out_lib.add_animation(StringName(c[0]), anim)
		var m: Dictionary = (meta[String(c[1])] as Dictionary).duplicate(true)
		m["from"] = "%s legs, %s waist up" % [c[1], c[2]]
		meta[String(c[0])] = m
		print("LAYERED ", c[0], " bones from ", c[2], ": ", swapped)
