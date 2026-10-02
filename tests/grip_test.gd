extends SceneTree
## The arms in the picked clips (ANIMATION_MIGRATION.md, part 3): Polysplit's
## figure on the UE mannequin, the arms of each lab set in its hands, every
## clip the user picked for that set played through frame by frame.
##
## Checked, as the game shows it (the figure, posed off the mannequin by
## [FigureFollower]; every bone keyed, [method Moveset.complete]):
## * each weapon's grip goes through its fist (the handle's line within
##   GRIP_TOLERANCE of the middle of the curled fingers): a failure;
## * a two-handed weapon (the great sword, the staff) has the other fist on
##   its handle, once the game has put it back there
##   ([method SkinnedRig.hilt_hand]): the frames it is off it are counted
##   (apart from those where the clip itself lets go of the hilt);
## * the blade stays out of the body (the torso, the head, the thighs, as
##   capsules round the figure's bones): the frames it is in deeper than
##   BODY_TOLERANCE are counted, and how deep it goes;
## * the shield on the forearm, turned as the game turns it for the clip
##   (the moves' "shield_turn"), faces ahead in the guard, the block and the
##   bash.
## A clip that keeps a hand off the hilt or the blade in the body more than a
## fifth of the time is named in the report (a WARN, not a failure: the clips
## are the user's picks). The report is also written to
## user://grip_report.json.
##   Godot --headless --path . --script res://tests/grip_test.gd

const MANNEQUIN := "res://assets/anim/lab/ual2_mannequin.glb"
const KEVIN := "res://assets/anim/lab/kevin_lib.res"
const FIGURE := "res://assets/polysplit/mannequin_m.glb"
const RATE := 30.0
## The middle of the curled fingers, in each hand's weapon bone's frame.
const FIST_R := Vector3(-0.003, 0.084, -0.021)
const FIST_L := Vector3(0.003, 0.084, -0.021)
const GRIP_TOLERANCE := 0.045
const OFF_HAND_TOLERANCE := 0.07
const BODY_TOLERANCE := 0.03
## set -> the arms held: "w" in the right hand, "o" in the left, "two" the
## left fist on the right one's handle.
const ARMS := {
	"SWORD AND SHIELD": {"w": "ps_w_sword_a", "shield": "ps_o_shield"},
	"TWO HANDS": {"w": "ps_w_greatsword", "two": true},
	"TWO KNIVES": {"w": "ps_w_dagger", "o": "ps_o_dagger"},
	"BOW": {"o": "ps_w_bow"},
	"SPEAR (A STAFF FOR NOW)": {"w": "ps_w_staff_a", "two": true},
}
## The body as capsules: [bone a, bone b (or "" for a sphere), radius].
const BODY := [["pelvis_joint", "neck_joint", 0.15], ["head_joint", "", 0.13],
		["L_thigh_joint", "L_knee_joint", 0.085], ["R_thigh_joint", "R_knee_joint", 0.085]]

var M: Skeleton3D
var F: Skeleton3D
var P: AnimationPlayer
var fig: Node3D
var follow: FigureFollower
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	failures.append(msg)
	print("FAIL ", msg)


## A weapon mesh's two ends and its bone, in the bone's frame.
func _ends(mesh_name: String) -> Dictionary:
	if mesh_name == "":
		return {}
	var m := fig.find_child(mesh_name, true, false) as MeshInstance3D
	if m == null:
		return {}
	# the bone it is bound to: the one its first vertex leans on most
	var arrays := m.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := int(float(bones.size()) / maxi((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 1))
	var at := 0
	for k in per:
		if weights[k] > weights[at]:
			at = k
	var bi := bones[at]
	var bone := String(m.skin.get_bind_name(bi))
	if bone == "":
		bone = F.get_bone_name(m.skin.get_bind_bone(bi))
	var bind := m.skin.get_bind_pose(bi)
	var pts: Array[Vector3] = []
	for s in m.mesh.get_surface_count():
		for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			pts.append(bind * v)
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var a := pts[0]
	for p in pts:
		if p.distance_squared_to(c) > a.distance_squared_to(c):
			a = p
	var b := a
	for p in pts:
		if p.distance_squared_to(a) > b.distance_squared_to(a):
			b = p
	return {"bone": bone, "a": a, "b": b, "c": c, "pts": pts}


func _bone_g(n: String) -> Transform3D:
	return F.global_transform * F.get_bone_global_pose(F.find_bone(n))


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	return p.distance_to(Geometry3D.get_closest_point_to_segment(p, a, b))


func _line_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	return p.distance_to(Geometry3D.get_closest_point_to_segment_uncapped(p, a, b))


## How far the deepest of `pts` is inside the body (0: none), and where.
func _in_body(pts: Array[Vector3]) -> Array:
	var deepest := 0.0
	var part := ""
	for cap: Array in BODY:
		var a := _bone_g(cap[0]).origin
		var b := a
		if cap[1] != "":
			b = _bone_g(cap[1]).origin
		else:
			a += Vector3.UP * 0.1
			b = a
		for p in pts:
			var depth := float(cap[2]) - _seg_dist(p, a, b)
			if depth > deepest:
				deepest = depth
				part = cap[0]
	return [deepest, part]


func _pose(t: float) -> void:
	P.seek(t, true)
	M.force_update_all_bone_transforms()
	follow.follow()


func _run() -> void:
	var man := (load(MANNEQUIN) as PackedScene).instantiate() as Node3D
	root.add_child(man)
	M = man.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	P = man.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	P.add_animation_library(&"kv", load(KEVIN))
	for lib_name: StringName in P.get_animation_library_list():
		var lib := P.get_animation_library(lib_name)
		for n: StringName in lib.get_animation_list():
			Moveset.complete(lib.get_animation(n), M)
	fig = (load(FIGURE) as PackedScene).instantiate() as Node3D
	man.add_child(fig)
	F = fig.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	var map := SkinnedRig.polysplit_map({})
	map[&"chest_joint"] = &"spine_03"
	map[&"head_joint"] = &"Head"
	follow = FigureFollower.new()
	fig.add_child(follow)
	if not follow.setup(M, F, map, &"pelvis_joint"):
		_fail("the figure does not follow the mannequin")
	var report := {}
	var warned: Array[String] = []
	for set_name: String in ARMS:
		var arms: Dictionary = ARMS[set_name]
		var w := _ends(arms.get("w", ""))
		var o := _ends(arms.get("o", ""))
		# the grips, at rest
		for pair: Array in [[w, FIST_R, "w"], [o, FIST_L, "o"]]:
			var e: Dictionary = pair[0]
			if e.is_empty():
				continue
			var d := _line_dist(pair[1], e["a"], e["b"])
			if String(arms[pair[2]]).ends_with("bow"):
				# a bow is bent: its grip is on the bow itself, not on the line
				# between its tips (the string's)
				d = INF
				for p: Vector3 in e["pts"]:
					d = minf(d, p.distance_to(pair[1]))
			print("GRIP %s %s %s: the handle's line %.3f m from the fist" % [set_name, pair[2], arms[pair[2]], d])
			if d > GRIP_TOLERANCE:
				_fail("%s: %s is not in the fist (%.3f m off)" % [set_name, arms[pair[2]], d])
		var shield := _ends(arms.get("shield", ""))
		var clips: Array[StringName] = []
		var picks: Dictionary = Moveset.picks().get(set_name, {})
		for move: String in picks:
			var entry: Dictionary = picks[move]
			var lists: Array = [entry.get("clips", [])]
			for also: Dictionary in entry.get("also", []):
				lists.append(also.get("clips", []))
			for l: Array in lists:
				for c: String in l:
					var n := Moveset.clip_name(c, {})
					if n != &"" and not clips.has(n):
						clips.append(n)
		for clip: StringName in clips:
			var played := String(clip) if P.has_animation(clip) else "kv/" + String(clip)
			if not P.has_animation(played):
				_fail("%s: no clip %s" % [set_name, clip])
				continue
			P.play(played)
			var length := P.get_animation(played).length
			var n := maxi(int(ceil(length * RATE)), 1)
			var off := 0
			var let_go := 0
			var off_max := 0.0
			var body := 0
			var body_max := 0.0
			var body_part := ""
			var facing := -2.0
			var turn := float(Moveset.clip_meta(clip).get("shield_turn", NAN))
			for i in n + 1:
				_pose(minf(i / RATE, length))
				if not w.is_empty():
					if arms.get("two", false):
						# the left fist put back on the grip, as the game does
						var far := w["a"] as Vector3 if (w["a"] as Vector3).length() > (w["b"] as Vector3).length() else w["b"] as Vector3
						var near := w["b"] as Vector3 if far == (w["a"] as Vector3) else w["a"] as Vector3
						var own_off := SkinnedRig.hilt_hand(M, F, far, near)
						if own_off > 0.2:
							let_go += 1
					var wg := _bone_g(w["bone"])
					if arms.get("two", false):
						var lf := _bone_g("weapon_l") * FIST_L
						# the handle: from the pommel end to a hand's breadth past the
						# right fist (the staff: all of it)
						var a: Vector3 = wg * (w["a"] as Vector3)
						var b: Vector3 = wg * (w["b"] as Vector3)
						var d := _seg_dist(lf, a, b)
						if d > OFF_HAND_TOLERANCE:
							off += 1
						off_max = maxf(off_max, d)
					var blade: Array[Vector3] = []
					var tip := w["a"] as Vector3 if (w["a"] as Vector3).length() > (w["b"] as Vector3).length() else w["b"] as Vector3
					for k in range(2, 13):
						blade.append(wg * (tip * (k / 12.0)))
					var ib := _in_body(blade)
					if float(ib[0]) > BODY_TOLERANCE:
						body += 1
						if float(ib[0]) > body_max:
							body_max = ib[0]
							body_part = ib[1]
				if not o.is_empty() and set_name == "TWO KNIVES":
					var og := _bone_g(o["bone"])
					var otip := o["a"] as Vector3 if (o["a"] as Vector3).length() > (o["b"] as Vector3).length() else o["b"] as Vector3
					var oblade: Array[Vector3] = []
					for k in range(3, 13):
						oblade.append(og * (otip * (k / 12.0)))
					var ob := _in_body(oblade)
					if float(ob[0]) > BODY_TOLERANCE:
						body += 1
						if float(ob[0]) > body_max:
							body_max = ob[0]
							body_part = String(ob[1]) + " (left knife)"
				if not shield.is_empty() and not is_nan(turn):
					# the shield turned as the game turns it ([method
					# SkinnedRig._turn_shield]), and where its middle then stands
					# off the forearm: the way its face looks
					var b := F.find_bone("shield_l")
					var el := F.find_bone("L_elbow_joint")
					var wr := F.find_bone("L_wrist_joint")
					var er := F.get_bone_global_rest(el)
					var along := (F.get_bone_global_rest(wr).origin - er.origin).normalized()
					var turned := F.get_bone_global_pose(el).basis.orthonormalized() * er.basis.orthonormalized().inverse() \
							* Basis(along, deg_to_rad(turn - SkinnedRig.SHIELD_BUILT_TURN)) \
							* F.get_bone_global_rest(b).basis.orthonormalized()
					var parent := F.get_bone_global_pose(F.get_bone_parent(b)).basis.orthonormalized()
					F.set_bone_pose_rotation(b, (parent.inverse() * turned).get_rotation_quaternion())
					var mid: Vector3 = _bone_g("shield_l") * (shield["c"] as Vector3)
					var axis_a := _bone_g("L_elbow_joint").origin
					var axis_b := _bone_g("L_wrist_joint").origin
					var face := mid - Geometry3D.get_closest_point_to_segment_uncapped(mid, axis_a, axis_b)
					facing = maxf(facing, face.normalized().dot(Vector3(0, 0, 1)))
			var frames := n + 1
			var line := {"frames": frames}
			var verdict := "OK"
			if arms.get("two", false):
				line["off_hand"] = snappedf(float(off) / frames, 0.01)
				# the frames the clip itself takes the hand off (a one-handed blow)
				line["let_go"] = snappedf(float(let_go) / frames, 0.01)
				line["off_hand_max"] = snappedf(off_max, 0.01)
				if float(off - let_go) / frames > 0.2:
					verdict = "WARN"
			line["in_body"] = snappedf(float(body) / frames, 0.01)
			if body > 0:
				line["in_body_max"] = snappedf(body_max, 0.01)
				line["in_body_part"] = body_part
			if float(body) / frames > 0.2:
				verdict = "WARN"
			if facing > -2.0:
				line["shield_ahead"] = snappedf(facing, 0.01)
			line["verdict"] = verdict
			report["%s/%s" % [set_name, clip]] = line
			print("CLIP %-26s %-28s %s %s" % [set_name, clip, verdict, line])
			if verdict != "OK":
				warned.append("%s/%s" % [set_name, clip])
	print("WARNED ", warned.size(), ": ", warned)
	var f := FileAccess.open("user://grip_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"clips": report, "warned": warned}, "\t", true))
	if failures.is_empty():
		print("All checks passed.")
		quit(0)
	else:
		print("FAILED: ", failures)
		quit(1)
