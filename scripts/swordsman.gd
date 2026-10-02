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
## Clips to measure with the sword besides the picks.
const CLIPS: Array[StringName] = [&"Sword_Dash", &"Sword_GroundPound", &"Sword_Aerial_Idle"]


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
	t["clips"][&"run"] = RUN
	for c: StringName in [evade["clip"], jump["clip"]]:
		var m := Moveset.clip_meta(c)
		if m.has("shield_turn"):
			t["shield_turn"][c] = float(m["shield_turn"])

