class_name Swordsman
extends RefCounted
## Tariel's sword and shield on the UE mannequin: one author (Quaternius'
## UAL 2), one design, every clip played whole and near its own pace
## (ANIMATION_MIGRATION.md, "6. ტარიელი: მოხდენილი მეომარი").
##
## Laid over what [Moveset] builds out of the lab's picks for the sword:
## - the string is UAL 2's own chain, A -> B -> C, the same each time (no
##   other string picked at random, nothing of another pack's in it). Each
##   blow ends in the pose the next begins in; left alone, A and B are brought
##   back to guard by their own "_Rec"; C (a leap round the blade) ends
##   standing;
## - no move has another played in its place at random ("alts" emptied);
## - the evade is Sword_Dash: low and forward, the blade drawn across on the
##   way (a light cut, `EVADE.weight`), played whole: the dash is its lunge
##   and its cut, the rest (the low hold and the rising) is its recovery,
##   which moving off releases;
## - the jump attack is Sword_GroundPound, which starts in UAL 2's aerial pose:
##   in the air it plays up to the blade raised over the head (`hold`) and
##   holds it there; landing, it plays on, the blade into the ground, at its
##   own pace.
##
## What is measured of these clips (cuts, the shield's face) is in
## clip_meta.json with the rest (vepxis-art tools/clip_meta.gd measures
## `CLIPS` with the sword).

const STRING: Array[StringName] = [&"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C"]
const RECOVER := {&"Sword_Regular_A": &"Sword_Regular_A_Rec", &"Sword_Regular_B": &"Sword_Regular_B_Rec"}
## rate: Sword_Dash is 1.57 s; at 1.3 its lunge and cut (to 0.585 s of the
## clip) fill a 0.45 s dash, the cut at ~0.2-0.3 s of it.
const EVADE := {"clip": &"Sword_Dash", "rate": 1.3, "weight": 0.6, "cut": Vector2(0.16, 0.25)}
## hold: the blade at its highest (0.167 s of 1.167); cut: the chop, from the
## top to the blade in the ground (0.23-0.35 s), as shares.
const JUMP_ATTACK := {"clip": &"Sword_GroundPound", "hold": 0.143, "cut": Vector2(0.19, 0.3)}
## The runs to try in the game, F6 going from one to the next (the user is
## choosing, 2026-10-02): Kevin's (the pick), Tariel's own Mixamo one carried
## onto the mannequin, UAL 2's with the shield up.
const RUNS: Array[StringName] = [&"KV_Run01_Forward", &"KV_Sprint01_Forward", &"SS_Run", &"Sprint_Shield",
		&"Sprint_Swing"]
## Runs made here out of two: the legs and trunk of the first, the arms of the
## second (in step: the second's left foot ahead where the first's is), baked
## once into the mannequin's library ([method bake]). Sprint_Swing: UAL 2's
## shield sprint with Kevin's run's arms swinging, not the shield held up.
const ARMS_FROM := {&"Sprint_Swing": [&"Sprint_Shield", &"KV_Run01_Forward"]}
## Their paces as Tariel plays them (m/s, his size), where the measure off the
## clip does not hold: a run with both feet off the ground between steps has
## no foot standing to measure (clip_meta read Sprint_Shield as 0.48 m/s).
## Found in the game by trying paces for the least slide (2026-10-02); the
## sprint's is its own rate at his run.
const RUN_PACE := {&"SS_Run": 4.3, &"Sprint_Shield": 5.6, &"Sprint_Swing": 5.6}
## Clips to measure with the sword besides the picks.
const CLIPS: Array[StringName] = [&"Sword_Dash", &"Sword_GroundPound", &"Sword_Aerial_Idle", &"Sprint_Shield"]


## Lays the design over `t`, a [method Moveset.build] table for the sword.
static func apply(t: Dictionary) -> void:
	t["alts"] = {}
	t["strings"] = [STRING.duplicate()]
	for c: StringName in STRING:
		t["flurry_part"][c] = Vector2(0.0, 1.0)
	t["recover"] = RECOVER.duplicate()
	var evade := EVADE.duplicate()
	var cuts: Array = Moveset.clip_meta(evade["clip"]).get("cuts", [])
	if not cuts.is_empty():
		evade["cut"] = Vector2(float(cuts[0][0]), float(cuts[0][1]))
	t["evade"] = evade
	t["cut_window"][evade["clip"]] = evade["cut"]
	# the arc drawn behind the cut: the measured trail it falls in
	for w: Array in Moveset.clip_meta(evade["clip"]).get("trails", []):
		if float(w[0]) <= evade["cut"].x and float(w[1]) >= evade["cut"].y:
			t["trail_window"][evade["clip"]] = Vector2(float(w[0]), float(w[1]))
	var jump: Dictionary = JUMP_ATTACK.duplicate()
	t["jump_attack"] = jump
	t["clips"][&"plunge"] = jump["clip"]
	# the chop only, not the raise before it
	t["cut_window"][jump["clip"]] = jump["cut"]
	(t["cut_windows"] as Dictionary).erase(jump["clip"])
	t["trail_window"][jump["clip"]] = Vector2(float(jump["hold"]), float(jump["cut"].y) + 0.03)
	t["runs"] = RUNS.duplicate()
	t["run_pace"] = RUN_PACE.duplicate()
	for c: StringName in RUNS:
		var m := Moveset.clip_meta(c)
		if m.has("ground_speed"):
			t["ground_speed"][c] = float(m["ground_speed"]) * Moveset.PACE_FIX
		if bool(m.get("loop", false)) and not t["looping"].has(c):
			t["looping"].append(c)
	for c: StringName in [evade["clip"], jump["clip"]]:
		var m := Moveset.clip_meta(c)
		if m.has("shield_turn"):
			t["shield_turn"][c] = float(m["shield_turn"])


## Makes the `ARMS_FROM` runs in `lib` (the mannequin's, `skel` its skeleton),
## each once.
static func bake(lib: AnimationLibrary, skel: Skeleton3D) -> void:
	for made: StringName in ARMS_FROM:
		var from: Array = ARMS_FROM[made]
		if lib.has_animation(made) or not lib.has_animation(from[0]) or not lib.has_animation(from[1]):
			continue
		var legs := lib.get_animation(from[0])
		var arms := lib.get_animation(from[1])
		var out := legs.duplicate(true) as Animation
		out.loop_mode = Animation.LOOP_LINEAR
		var at_legs := _left_ahead(legs, skel)
		var at_arms := _left_ahead(arms, skel)
		var arm_tracks := _tracks(arms)
		for i in out.get_track_count():
			if out.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(out.track_get_path(i)).get_slice(":", 1)
			if not _is_arm(bone):
				continue
			var src: int = arm_tracks.get("r|" + bone, -1)
			if src < 0:
				continue
			while out.track_get_key_count(i) > 0:
				out.track_remove_key(i, 0)
			var n := int(ceil(out.length * 30.0))
			for k in n + 1:
				var t := minf(k / 30.0, out.length)
				var ta := fposmod((t - at_legs) / out.length * arms.length + at_arms, arms.length)
				out.rotation_track_insert_key(i, t, arms.rotation_track_interpolate(src, ta))
		lib.add_animation(made, out)


static func _is_arm(bone: String) -> bool:
	if bone == "hand_l" or bone == "hand_r":
		return true
	for part: String in ["clavicle_", "upperarm_", "lowerarm_"]:
		if bone.begins_with(part):
			return true
	return false


## "r|bone" / "p|bone" -> the clip's rotation / position track of that bone.
static func _tracks(anim: Animation) -> Dictionary:
	var out := {}
	for i in anim.get_track_count():
		var bone := String(anim.track_get_path(i)).get_slice(":", 1)
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				out["r|" + bone] = i
			Animation.TYPE_POSITION_3D:
				out["p|" + bone] = i
	return out


## Where in a cycle the left foot is farthest ahead of the right (+z ahead).
static func _left_ahead(anim: Animation, skel: Skeleton3D) -> float:
	var tracks := _tracks(anim)
	var l := skel.find_bone("foot_l")
	var r := skel.find_bone("foot_r")
	var best := 0.0
	var best_d := -INF
	for k in 60:
		var t := anim.length * k / 60.0
		var d := _pose(anim, tracks, skel, l, t).origin.z - _pose(anim, tracks, skel, r, t).origin.z
		if d > best_d:
			best_d = d
			best = t
	return best


## A bone's place in the skeleton at `t` of `anim`, worked out up its chain.
static func _pose(anim: Animation, tracks: Dictionary, skel: Skeleton3D, bone: int, t: float) -> Transform3D:
	var out := Transform3D.IDENTITY
	var b := bone
	while b >= 0:
		var name := skel.get_bone_name(b)
		var rest := skel.get_bone_rest(b)
		var rot := rest.basis.get_rotation_quaternion()
		var pos := rest.origin
		if tracks.has("r|" + name):
			rot = anim.rotation_track_interpolate(tracks["r|" + name], t)
		if tracks.has("p|" + name):
			pos = anim.position_track_interpolate(tracks["p|" + name], t)
		out = Transform3D(Basis(rot), pos) * out
		b = skel.get_bone_parent(b)
	return out
