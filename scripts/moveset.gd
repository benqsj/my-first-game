class_name Moveset
extends RefCounted
## The heroes' moves on the UE mannequin (ANIMATION_MIGRATION.md): what the
## user picked in the animation lab (assets/anim/lab/picks.json), by what is
## held, made into the tables [SkinnedRig] plays from while YOUR OWN is worn.
##
## A set ("MOVING", "SWORD AND SHIELD"...) is picked by the arms of the look
## ([method kind_of]); MOVING is laid under every one. Each move's pick is
## its column's clips (the main) and, under "also", more to play at random.
## "NOW (MIXAMO)" in a pick ("c:roll") is the hero's own clip from his clip
## table, retargeted onto the mannequin with the rest of his clips
## (assets/anim/heroes/<hero>_mannequin.res, vepxis-art tools/h2m.gd): what
## the picks leave out (crouching, climbing, the bow's draws, the skills)
## plays from those too.
##
## Where each blow cuts, where its arc is drawn, how fast each cycle walks
## and which way the shield faces are measured off the clips themselves
## (assets/anim/lab/clip_meta.json, vepxis-art tools/clip_meta.gd).

const PICKS := "res://assets/anim/lab/picks.json"
const META := "res://assets/anim/lab/clip_meta.json"
## The lab's sets, by the kind of arms (see `kind_of`).
const SETS := {
	&"moving": "MOVING", &"sword": "SWORD AND SHIELD", &"two_hands": "TWO HANDS",
	&"knives": "TWO KNIVES", &"bow": "BOW", &"spear": "SPEAR (A STAFF FOR NOW)",
	&"dual": "TWO BLADES",
}
## Moves of MOVING -> the rig's clip table key.
const MOVING_SLOTS := {
	"STANDING": &"idle", "WALK": &"walk", "RUN": &"run", "SPRINT": &"sprint", "RUN LEFT": &"run_left",
	"RUN BACK": &"run_back", "DODGE": &"roll", "CLIMB UP": &"mantle", "HIT": &"hit", "DEATH": &"down",
}
## Clips the lab did not show, of the same family as a pick (Kevin's walk
## and run the other ways, a guard taking a blow for each kind of arms).
const COMPANIONS := {
	&"walk_back": &"KV_Walk01_Backward", &"walk_left": &"KV_StrafeWalk01_Left",
	&"walk_right": &"KV_StrafeWalk01_Right", &"run_right": &"KV_StrafeRun01_Right",
	# the four ways between (TARIEL_POLISH.md: eight ways round what he is
	# locked on, 2026-10-04)
	&"walk_fl": &"KV_Walk01_ForwardLeft", &"walk_fr": &"KV_Walk01_ForwardRight",
	&"walk_bl": &"KV_Walk01_BackwardLeft", &"walk_br": &"KV_Walk01_BackwardRight",
	# a jog behind the raised shield: Kevin's run, slow, under the guard
	&"guard_jog": &"KV_Run01_Forward",
	# the jog, with nothing held (Shift is the sprint, the user's word,
	# 2026-10-04)
	&"jog": &"KV_Run01_Forward",
}
const BLOCK_HIT := {
	&"two_hands": &"KV_Parry2H01_Hit", &"knives": &"KV_ParryDW01_Hit", &"spear": &"KV_ParryPolearm01_Hit",
	&"dual": &"KV_ParryDW01_Hit",
}
## Each class's death (the look's "cls"), Kevin's, the user's picks
## (2026-10-03): the swordsman, the knight, the rogue and the hunter theirs,
## the rest shared out among the six.
const DEATHS := {
	"swordsman": &"KV_Death01", "knight": &"KV_CombatDeath04", "rogue": &"KV_CombatDeath03",
	"hunter": &"KV_CombatDeath02", "archer": &"KV_CombatDeath01", "fighter": &"KV_Death02",
	"mage": &"KV_Death02", "sorcerer": &"KV_CombatDeath01", "warlock": &"KV_CombatDeath04",
	"witch": &"KV_CombatDeath03",
}
## A hero's own death, whatever class he wears (Tariel's, the user's word).
const HERO_DEATHS := {&"tariel": &"KV_Death01"}
## Deaths played slower than made: KV_Death01 is 0.7 s, too quick a fall (the
## user's word, 2026-10-03); at x0.6 it takes 1.2 s.
const DEATH_RATE := {&"KV_Death01": 0.6}
## A string's blow is played from a little before its cut to a little after
## (seconds), so one runs into the next.
const LEAD := 0.28
const FOLLOW := 0.32
## The measured paces against what stands the feet in the game: played at
## its measured pace a cycle's feet slid forward (0.9-1.1 m/s at a run); at
## this share of it they stand (0.15-0.36 m/s), the same for Tariel (x1.2),
## the warrior and the assassin (tests/stride_test.gd, 2026-10-02).
const PACE_FIX := 0.833
## A clip with more than one cut in it, as more than one blow of a string:
## each part is the clip under "<clip>#<n>" (the same Animation).
const PART_MARK := "#"

static var _picks: Dictionary = {}
static var _meta: Dictionary = {}


## The kind of arms `look` ([PolysplitLook]) holds: which set it fights with.
##
## The assassin with a blade in each hand (a knife, or a short sword, in the
## other hand too) fights with both: TWO BLADES, `&"dual"` (the user's word,
## 2026-10-05). One blade, and he fights as he did, one-handed.
static func kind_of(look: Dictionary) -> StringName:
	var w := String(look.get("w", ""))
	# empty-handed: the knife's moves, fists for knives
	if w == "none":
		return &"knives"
	var k := PolysplitLook.kind(w)
	if two_blades(look):
		return &"dual"
	return &"sword" if k == &"shield" else k


## Whether `look` is the assassin's with a blade in each hand.
static func two_blades(look: Dictionary) -> bool:
	var cls := String(look.get("cls", ""))
	if String(PolysplitLook.PROFESSION_OF.get(cls, cls)) != "rogue":
		return false
	var o := String(look.get("o", ""))
	if o == "" or o == "none" or String(look.get("w", "none")) in ["", "none"]:
		return false
	var blade := [&"knives", &"sword"]
	return PolysplitLook.kind(o) in blade and PolysplitLook.kind(String(look.get("w", ""))) in blade


static func picks() -> Dictionary:
	if _picks.is_empty() and FileAccess.file_exists(PICKS):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PICKS))
		if parsed is Dictionary:
			_picks = parsed
	return _picks


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(META):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
		if parsed is Dictionary:
			_meta = parsed
	return _meta


## The measurements of `clip` (see clip_meta.gd), or {}.
static func clip_meta(clip: StringName) -> Dictionary:
	return (meta().get("clips", {}) as Dictionary).get(String(clip), {})


## A pick's clip as the player knows it: "_Loop" off UAL 2's names (Godot's
## glb import takes it off; Kevin's keep theirs), "c:<key>" from the hero's
## own clip table.
static func clip_name(spec: String, own: Dictionary) -> StringName:
	if spec.begins_with("c:"):
		return own.get(StringName(spec.substr(2)), &"")
	if spec.begins_with("KV_"):
		return StringName(spec)
	return StringName(spec.trim_suffix("_Loop"))


## Keys every bone of `skel` that `anim` leaves out at its rest, so a clip
## leaves nothing of the one before it in the pose: UAL 2's clips leave out
## the bones they do not move, Kevin's the mannequin's middle spine bone and
## the fingers' tips, and a bone no clip keys stays wherever the last one
## that did left it. Once per clip.
static func complete(anim: Animation, skel: Skeleton3D) -> void:
	if anim.has_meta(&"complete"):
		return
	var base := "Armature/Skeleton3D"
	var have := {}
	for i in anim.get_track_count():
		var path := String(anim.track_get_path(i))
		if path.contains(":"):
			base = path.get_slice(":", 0)
		have["%d|%s" % [anim.track_get_type(i), path.get_slice(":", 1)]] = true
	for b in skel.get_bone_count():
		var bone := skel.get_bone_name(b)
		var rest := skel.get_bone_rest(b)
		if not have.has("%d|%s" % [Animation.TYPE_ROTATION_3D, bone]):
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [base, bone]))
			anim.rotation_track_insert_key(t, 0.0, rest.basis.get_rotation_quaternion())
		if not have.has("%d|%s" % [Animation.TYPE_POSITION_3D, bone]):
			var t := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [base, bone]))
			anim.position_track_insert_key(t, 0.0, rest.origin)
	anim.set_meta(&"complete", true)


## {"main": [clips], "alts": [[clips], ...]} for the move `move` of set
## `set_key`; empty lists if it was not picked.
static func pick(set_key: StringName, move: String, own: Dictionary = {}) -> Dictionary:
	var out := {"main": [], "alts": []}
	var entry: Dictionary = (picks().get(SETS.get(set_key, ""), {}) as Dictionary).get(move, {})
	for c: String in entry.get("clips", []):
		var n := clip_name(c, own)
		if n != &"":
			out["main"].append(n)
	for also: Dictionary in entry.get("also", []):
		var alt: Array = []
		for c: String in also.get("clips", []):
			var n := clip_name(c, own)
			if n != &"":
				alt.append(n)
		if not alt.is_empty():
			out["alts"].append(alt)
	return out


## Every clip of the picks and companions (the hero's own left out): what
## clip_meta.gd measures.
static func all_clips() -> Array[StringName]:
	var out: Array[StringName] = []
	for set_name: String in picks():
		for move: String in picks()[set_name]:
			var entry: Dictionary = picks()[set_name][move]
			var lists: Array = [entry.get("clips", [])]
			for also: Dictionary in entry.get("also", []):
				lists.append(also.get("clips", []))
			for l: Array in lists:
				for c: String in l:
					if not c.begins_with("c:") and not out.has(clip_name(c, {})):
						out.append(clip_name(c, {}))
	for c: StringName in COMPANIONS.values() + BLOCK_HIT.values() + Swordsman.CLIPS:
		if not out.has(c):
			out.append(c)
	return out


## The tables for fighting with arms of `kind`, MOVING under them, for a hero
## whose own clip table is `own`. Keys: "clips" (laid over his own), "alts"
## (clip -> other clips to play in its place at random), "strings" (the
## blows a string of light attacks goes through; one is picked at random as
## a string starts), "flurry_part", "heavy", "cut_window", "cut_windows",
## "trail_window", "recover" (a blow -> the clip that brings him back out of
## it, played if no blow follows), "ground_speed", "looping", "roll_share",
## "shield_turn" (clip -> the shield's face, degrees from up towards ahead
## about the forearm), "aliases" (a part's name -> its clip), "bow" (the bow's
## clips by use), "guard" (the stance while fighting).
static func build(kind: StringName, own: Dictionary) -> Dictionary:
	var t := {"clips": {}, "alts": {}, "strings": [], "flurry_part": {}, "heavy": [], "cut_window": {},
			"cut_windows": {}, "trail_window": {}, "recover": {}, "ground_speed": {}, "looping": [],
			"roll_share": {}, "shield_turn": {}, "aliases": {}, "bow": {}, "guard": &"", "kind": kind}
	var clips: Dictionary = t["clips"]
	# MOVING
	for move: String in MOVING_SLOTS:
		var p := pick(&"moving", move, own)
		if p["main"].is_empty():
			continue
		var slot: StringName = MOVING_SLOTS[move]
		clips[slot] = p["main"][0]
		var alts: Array = []
		for alt: Array in p["alts"]:
			alts.append(alt[0])
		if not alts.is_empty():
			t["alts"][p["main"][0]] = alts
	for slot: StringName in COMPANIONS:
		clips[slot] = COMPANIONS[slot]
	var jump := pick(&"moving", "JUMP", own)
	if jump["main"].size() >= 3:
		clips[&"air_start"] = jump["main"][0]
		clips[&"air"] = jump["main"][1]
		clips[&"land"] = jump["main"][2]
	elif not jump["main"].is_empty():
		clips[&"air"] = jump["main"][0]
	for alt: Array in jump["alts"]:
		t["alts"][clips.get(&"air", &"")] = [alt[0]]
	# a dodge that hops out and back is played to where it is farthest out
	var roll_clip: StringName = clips.get(&"roll", &"")
	t["roll_share"][roll_clip] = float(clip_meta(roll_clip).get("hop_peak", 0.86)) \
			if clip_meta(roll_clip).has("hop_peak") else 0.86
	# the arms
	var set_key := kind
	if set_key in [&"sword", &"two_hands", &"knives", &"spear", &"dual"]:
		var guard := pick(set_key, "ON GUARD", own)
		if not guard["main"].is_empty():
			t["guard"] = guard["main"][0]
			if not guard["alts"].is_empty():
				t["alts"][guard["main"][0]] = [guard["alts"][0][0]]
	match kind:
		&"sword":
			_string_of(t, ["CUT 1", "CUT 2", "CUT 3"], &"sword", own)
			_combo(t, "COMBO", &"sword", own)
			_heavy(t, "HEAVY BLOW", &"sword", own, 1.8)
			_slot(t, &"block_idle", "BLOCK", &"sword", own)
			_slot(t, &"hit_blocked", "BLOCK, HIT", &"sword", own)
			_slot(t, &"parry", "SHIELD BASH", &"sword", own)
			_slot(t, &"draw", "SWORD DRAWN", &"sword", own)
		&"two_hands":
			_string_of(t, ["CUT 1", "CUT 2", "CUT 3", "CUT 4"], &"two_hands", own)
			_slot(t, &"block_idle", "PARRY", &"two_hands", own)
			_slot(t, &"parry", "PARRY", &"two_hands", own)
			_heavy(t, "SLAM", &"two_hands", own, 2.1)
		&"knives":
			_string_of(t, ["STAB 1", "STAB 2"], &"knives", own)
			_combo(t, "COMBO", &"knives", own)
			_slot(t, &"block_idle", "PARRY", &"knives", own)
			_slot(t, &"parry", "PARRY", &"knives", own)
			_heavy(t, "ONE KNIFE", &"knives", own, 1.6)
		&"dual":
			# a blow for each hand in turn, and both at once (the lab's TWO
			# BLADES, picked by the user); the heavy blows are the rig's own
			_string_of(t, ["CUT 1", "CUT 2", "CUT 3", "CUT 4", "CUT 5", "CUT 6"], &"dual", own)
			_combo(t, "COMBO", &"dual", own)
			_slot(t, &"block_idle", "PARRY", &"dual", own)
			_slot(t, &"parry", "PARRY", &"dual", own)
		&"spear":
			_string_of(t, ["THRUST 1", "THRUST 2", "SWEEP"], &"spear", own)
			_slot(t, &"block_idle", "PARRY", &"spear", own)
			_heavy(t, "SPIN", &"spear", own, 1.9)
		&"bow":
			for pair: Array in [["NOCK", &"draw"], ["AIM", &"aim"], ["AIM HIGH", &"aim_high"], ["SHOOT", &"loose"],
					["RAPID", &"rapid"]]:
				var p := pick(&"bow", pair[0], own)
				if not p["main"].is_empty():
					t["bow"][pair[1]] = p["main"][0]
	if BLOCK_HIT.has(kind) and not clips.has(&"hit_blocked"):
		clips[&"hit_blocked"] = BLOCK_HIT[kind]
	if t["guard"] != &"" and not clips.has(&"block_idle"):
		clips[&"block_idle"] = t["guard"]
	# what the measurements say of every clip in the tables
	var used: Array[StringName] = []
	for c: StringName in clips.values():
		used.append(c)
	for s: Array in t["strings"]:
		for c: StringName in s:
			used.append(c)
	for h: Dictionary in t["heavy"]:
		used.append(h["clip"])
	for c: StringName in t["alts"]:
		if String(c).begins_with("heavy:"):
			for h: Dictionary in t["alts"][c]:
				used.append(h["clip"])
			continue
		for a: StringName in t["alts"][c]:
			used.append(a)
	if t["guard"] != &"":
		used.append(t["guard"])
	for c: StringName in used:
		var m := clip_meta(_base_of(t, c))
		if m.is_empty():
			continue
		if m.has("ground_speed"):
			t["ground_speed"][c] = float(m["ground_speed"]) * PACE_FIX
		if bool(m.get("loop", false)) and not t["looping"].has(c):
			t["looping"].append(c)
		if m.has("shield_turn"):
			t["shield_turn"][c] = float(m["shield_turn"])
		if not t["aliases"].has(c) and not t["cut_window"].has(c):
			var cuts: Array = m.get("cuts", [])
			var trails: Array = m.get("trails", [])
			if cuts.size() == 1:
				t["cut_window"][c] = _v2(cuts[0])
				if not trails.is_empty():
					t["trail_window"][c] = _v2(trails[0])
			elif cuts.size() > 1:
				var many: Array = []
				for w: Array in cuts:
					many.append(_v2(w))
				t["cut_windows"][c] = many
				t["cut_window"][c] = Vector2(_v2(cuts[0]).x, _v2(cuts[cuts.size() - 1]).y)
				if not trails.is_empty():
					t["trail_window"][c] = Vector2(_v2(trails[0]).x, _v2(trails[trails.size() - 1]).y)
	if t["guard"] != &"" and not t["looping"].has(t["guard"]):
		t["looping"].append(t["guard"])
	if kind == &"sword":
		# one author and one design for the sword (Tariel): see Swordsman
		Swordsman.apply(t)
	elif kind == &"two_hands":
		# the knight's great sword, on both buttons: see GreatSword
		GreatSword.apply(t)
	return t


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## The clip a part's name stands for ("Sword_Regular_Combo#2" ->
## "Sword_Regular_Combo"), or the name itself.
static func _base_of(t: Dictionary, c: StringName) -> StringName:
	return t["aliases"].get(c, c)


static func _slot(t: Dictionary, slot: StringName, move: String, set_key: StringName, own: Dictionary) -> void:
	var p := pick(set_key, move, own)
	if not p["main"].is_empty():
		t["clips"][slot] = p["main"][0]


## The part of `clip` around its cut (LEAD before, FOLLOW after), as shares.
static func _part(clip: StringName, window: Vector2) -> Vector2:
	var m := clip_meta(clip)
	var length := float(m.get("length", 1.0))
	return Vector2(maxf(window.x - LEAD / length, 0.0), minf(window.y + FOLLOW / length, 1.0))


## A string out of one blow per move (each pick's first clip; its second, if
## it has one, the recovery after it), and another out of each move's first
## "also", where every move has one.
static func _string_of(t: Dictionary, moves: Array, set_key: StringName, own: Dictionary) -> void:
	var main: Array[StringName] = []
	var alt: Array[StringName] = []
	for move: String in moves:
		var p := pick(set_key, move, own)
		if p["main"].is_empty():
			continue
		var blow: StringName = p["main"][0]
		main.append(blow)
		if p["main"].size() > 1:
			t["recover"][blow] = p["main"][1]
		var cuts: Array = clip_meta(blow).get("cuts", [])
		if not cuts.is_empty():
			t["flurry_part"][blow] = _part(blow, _v2(cuts[0]))
		if not p["alts"].is_empty() and alt.size() == main.size() - 1:
			var a: StringName = p["alts"][0][0]
			alt.append(a)
			var acuts: Array = clip_meta(a).get("cuts", [])
			if not acuts.is_empty():
				t["flurry_part"][a] = _part(a, _v2(acuts[0]))
	if not main.is_empty():
		t["strings"].append(main)
	if alt.size() == main.size() and not alt.is_empty():
		t["strings"].append(alt)


## A combo clip as a string of its own: each of its cuts a blow, under
## "<clip>#<n>"; its "also" (a list of clips) as another string.
static func _combo(t: Dictionary, move: String, set_key: StringName, own: Dictionary) -> void:
	var p := pick(set_key, move, own)
	if p["main"].is_empty():
		return
	var clip: StringName = p["main"][0]
	var cuts: Array = clip_meta(clip).get("cuts", [])
	var trails: Array = clip_meta(clip).get("trails", [])
	var length := float(clip_meta(clip).get("length", 1.0))
	var s: Array[StringName] = []
	var from := 0.0
	for i in cuts.size():
		var w := _v2(cuts[i])
		var part_name := StringName("%s%s%d" % [clip, PART_MARK, i + 1])
		t["aliases"][part_name] = clip
		var until := minf(w.y + FOLLOW / length, 1.0)
		if i + 1 < cuts.size():
			# up to just before the next blow's lead-in
			until = minf(until, maxf(_v2(cuts[i + 1]).x - LEAD / length, w.y))
		t["flurry_part"][part_name] = Vector2(maxf(from, w.x - LEAD / length), until)
		t["cut_window"][part_name] = w
		if i < trails.size():
			t["trail_window"][part_name] = _v2(trails[i])
		from = until
		s.append(part_name)
	if not s.is_empty():
		t["strings"].append(s)
	for alt: Array in p["alts"]:
		var a: Array[StringName] = []
		for c: StringName in alt:
			a.append(c)
			var acuts: Array = clip_meta(c).get("cuts", [])
			if not acuts.is_empty():
				t["flurry_part"][c] = _part(c, _v2(acuts[0]))
		if a.size() > 1:
			t["strings"].append(a)


## The heavy blow: the pick's first clip, its "also" played at random in its
## place; worth `weight` light cuts. A blade into the ground (its lowest
## point, measured) shakes it there.
static func _heavy(t: Dictionary, move: String, set_key: StringName, own: Dictionary, weight: float) -> void:
	var p := pick(set_key, move, own)
	if p["main"].is_empty():
		return
	var specs: Array = []
	for c: StringName in [p["main"][0]] + p["alts"].map(func(a: Array) -> StringName: return a[0]):
		var m := clip_meta(c)
		var spec := {"clip": c, "part": Vector2(0.0, 1.0), "rate": 1.2, "weight": weight}
		if m.has("slam"):
			spec["slam"] = float(m["slam"])
			spec["aim"] = false
		var cuts: Array = m.get("cuts", [])
		if not cuts.is_empty():
			spec["rise"] = minf(_v2(cuts[cuts.size() - 1]).y + 0.1, 0.95)
		specs.append(spec)
	t["heavy"].append(specs[0])
	if specs.size() > 1:
		t["alts"][StringName("heavy:%d" % (t["heavy"].size() - 1))] = specs.slice(1)
