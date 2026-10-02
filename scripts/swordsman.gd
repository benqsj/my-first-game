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
## The run: Kevin's sprint, played at its own pace (Tariel's `run_speed` is
## its pace over the ground, 7.4 m/s; the user's pick, 2026-10-02, after trying
## five in the game: his run is a jog, the sprint the run a fighter makes).
const RUN := &"KV_Sprint01_Forward"
## Strings and heavy blows to try in the game (F6 the string, F7 the heavy
## blow; the user is choosing, 2026-10-03). The first of each is the one worn
## until another is picked. "recover": a blow's own way back to guard.
const STRINGS: Array = [
	{"name": "UAL2 REGULAR  A-B-C", "clips": [&"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C"],
		"recover": {&"Sword_Regular_A": &"Sword_Regular_A_Rec", &"Sword_Regular_B": &"Sword_Regular_B_Rec"}},
	{"name": "UAL2 LIGHT  A-B-C-D", "clips": [&"Sword_Light_A", &"Sword_Light_B", &"Sword_Light_C", &"Sword_Light_D"],
		"recover": {&"Sword_Light_A": &"Sword_Light_A_Rec", &"Sword_Light_B": &"Sword_Light_B_Rec",
			&"Sword_Light_C": &"Sword_Light_C_Rec"}},
	{"name": "UAL2 HEAVY  A-B-C", "clips": [&"Sword_Heavy_A", &"Sword_Heavy_B", &"Sword_Heavy_C"],
		"recover": {&"Sword_Heavy_A": &"Sword_Heavy_A_Rec", &"Sword_Heavy_B": &"Sword_Heavy_B_Rec",
			&"Sword_Heavy_C": &"Sword_Heavy_C_Rec"}},
	{"name": "KEVIN  1H 01-02-03-04", "clips": [&"KV_Attack1H01_R", &"KV_Attack1H02_R", &"KV_Attack1H03_R",
			&"KV_Attack1H04_R"], "recover": {}},
]
const HEAVIES: Array = [
	{"name": "UAL2 HEAVY COMBO", "clip": &"Sword_Heavy_Combo"},
	{"name": "UAL2 HEAVY D", "clip": &"Sword_Heavy_D"},
	{"name": "UAL2 UPPERCUT", "clip": &"Sword_UpperCut"},
	{"name": "KEVIN 1H 05", "clip": &"KV_Attack1H05_R"},
]
## Clips to measure with the sword besides the picks.
const CLIPS: Array[StringName] = [&"Sword_Dash", &"Sword_GroundPound", &"Sword_Aerial_Idle",
	&"Sword_Light_A", &"Sword_Light_B", &"Sword_Light_C", &"Sword_Light_D", &"Sword_Light_A_Rec",
	&"Sword_Light_B_Rec", &"Sword_Light_C_Rec", &"Sword_Heavy_A", &"Sword_Heavy_B", &"Sword_Heavy_C",
	&"Sword_Heavy_A_Rec", &"Sword_Heavy_B_Rec", &"Sword_Heavy_C_Rec", &"Sword_Heavy_D", &"Sword_Heavy_Combo",
	&"Sword_UpperCut", &"KV_Attack1H01_R", &"KV_Attack1H02_R", &"KV_Attack1H03_R", &"KV_Attack1H04_R",
	&"KV_Attack1H05_R"]


## Lays the design over `t`, a [method Moveset.build] table for the sword.
static func apply(t: Dictionary) -> void:
	t["alts"] = {}
	t["strings"] = [STRING.duplicate()]
	t["recover"] = RECOVER.duplicate()
	# every string and heavy blow to try, each clip measured and played whole
	t["string_sets"] = STRINGS
	var heavies: Array = []
	for s: Dictionary in STRINGS:
		for c: StringName in s["clips"]:
			t["flurry_part"][c] = Vector2(0.0, 1.0)
			_measure(t, c)
	for h: Dictionary in HEAVIES:
		_measure(t, h["clip"])
		heavies.append(heavy_spec(h["clip"]))
	t["heavy_sets"] = heavies
	if not heavies.is_empty():
		t["heavy"] = [heavies[0]]
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
	t["clips"][&"run"] = RUN
	for c: StringName in [evade["clip"], jump["clip"]]:
		var m := Moveset.clip_meta(c)
		if m.has("shield_turn"):
			t["shield_turn"][c] = float(m["shield_turn"])



## The heavy blow `clip` as [SkinnedRig] `heavy` holds one (as Moveset makes
## the pick's): whole, a little quicker than made, worth 1.8 light cuts, a
## blade that reaches the ground shaking it there.
static func heavy_spec(clip: StringName) -> Dictionary:
	var m := Moveset.clip_meta(clip)
	var spec := {"clip": clip, "part": Vector2(0.0, 1.0), "rate": 1.15, "weight": 1.8}
	if m.has("slam"):
		spec["slam"] = float(m["slam"])
		spec["aim"] = false
	var cuts: Array = m.get("cuts", [])
	if not cuts.is_empty():
		spec["rise"] = minf(float(cuts[cuts.size() - 1][1]) + 0.1, 0.95)
	return spec


## Where `clip` cuts and draws its arc, from what is measured of it, into `t`
## (as Moveset.build does for the picks).
static func _measure(t: Dictionary, clip: StringName) -> void:
	var m := Moveset.clip_meta(clip)
	var cuts: Array = m.get("cuts", [])
	var trails: Array = m.get("trails", [])
	if cuts.size() == 1:
		t["cut_window"][clip] = Vector2(float(cuts[0][0]), float(cuts[0][1]))
		if not trails.is_empty():
			t["trail_window"][clip] = Vector2(float(trails[0][0]), float(trails[trails.size() - 1][1]))
	elif cuts.size() > 1:
		var many: Array = []
		for w: Array in cuts:
			many.append(Vector2(float(w[0]), float(w[1])))
		t["cut_windows"][clip] = many
		t["cut_window"][clip] = Vector2(many[0].x, many[many.size() - 1].y)
		if not trails.is_empty():
			t["trail_window"][clip] = Vector2(float(trails[0][0]), float(trails[trails.size() - 1][1]))
	if m.has("shield_turn"):
		t["shield_turn"][clip] = float(m["shield_turn"])
