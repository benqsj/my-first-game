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
## The strings, F6 going from one to the other in the game (the user's pick,
## 2026-10-03): UAL 2's Regular A-B-C, the one worn until the other is picked,
## and UAL 2's Heavy A-B-C. "recover": a blow's own way back to guard.
const STRINGS: Array = [
	{"name": "UAL2 REGULAR  A-B-C", "clips": [&"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C"],
		"recover": {&"Sword_Regular_A": &"Sword_Regular_A_Rec", &"Sword_Regular_B": &"Sword_Regular_B_Rec"}},
	{"name": "UAL2 HEAVY  A-B-C", "clips": [&"Sword_Heavy_A", &"Sword_Heavy_B", &"Sword_Heavy_C"],
		"recover": {&"Sword_Heavy_A": &"Sword_Heavy_A_Rec", &"Sword_Heavy_B": &"Sword_Heavy_B_Rec",
			&"Sword_Heavy_C": &"Sword_Heavy_C_Rec"}},
]
## The running cut (TARIEL_POLISH.md, 5): the first cut thrown at a run is
## UAL 2's Sword_Light_D, a wide sweep out of a lunge, its cut at 0.09-0.17 of
## 1.67 s (0.14-0.26 s at x1.1); the string goes on from B after it.
const RUN_ATTACK := {"clip": &"Sword_Light_D", "rate": 1.1, "weight": 1.25}
## Tariel's skill, the Rising Cut (the user's pick, 2026-10-03, from the run
## cuts tried): UAL 2's Sword_UpperCut wound up (held at `hold`, the sword
## drawn back low) while he runs at what he picked, let go `strike_gap`
## metres (body to body) off it: the blade comes up through it. `pace`: of
## his run; `hold_max`: let go by then whatever; `blind_hold`: with nothing
## to run at, let go after this; `string_at` -1: the string starts again at A.
const RISING_CUT := {"clip": &"Sword_UpperCut", "rate": 1.0, "weight": 1.7, "hold": 0.06,
	"strike_gap": 1.1, "pace": 1.12, "hold_max": 1.6, "blind_hold": 0.45, "string_at": -1}
## Tariel's second skill, the Shadow Slide (TARIEL_POLISH.md 12, the user's
## word 2026-10-03: the running cut, out of a slide, with the shadows): UAL 2's
## Sword_Light_D, the blade drawn back (`hold` 0.035 of the clip) and coming on
## slowly from there (`creep`, a share of its rate, no further than
## `creep_until`, short of its cut at 0.09) while he slides in at what he
## picked, up to `slide_max` metres; with nothing before him `slide_blind`.
## Let go to cut `strike_gap` metres (body to body) off it.
const SHADOW_SLIDE := {"clip": &"Sword_Light_D", "rate": 1.1, "weight": 1.6, "hold": 0.035, "creep": 0.22,
	"creep_until": 0.07, "slide_max": 7.0, "slide_blind": 8.0, "strike_gap": 1.0, "string_at": -1}
## Tariel's third skill, the Shadow Lance (the user's word, 2026-10-03: the
## thrust's peak, the sword furthest out, falls just as the slide ends at the
## monster): Kevin's lunge and thrust (KV_Attack1H05_R) drawn back to `hold`
## 0.15 (the blade behind him, measured) and drawn on slowly from there
## (`creep`, to `creep_until`) through the slide, as a spell is cast; let go so
## that its `peak` 0.26 (the arm out, the blade level ahead at the chest: tip
## 2.16 m ahead, 1.5 m up, straight on; `_shots_tmp/lance_probe.gd`) comes as
## he arrives. The slide ends `strike_gap` metres (body to body) off it: the
## point goes in at the peak. It cuts when the point reaches it (no reach past
## the blade's own: `sure_margin` 0).
const SHADOW_LANCE := {"clip": &"KV_Attack1H05_R", "rate": 1.0, "weight": 1.8, "hold": 0.15, "creep": 0.12,
	"creep_until": 0.17, "peak": 0.26, "slide_max": 7.0, "slide_blind": 8.0, "strike_gap": 1.7,
	"sure_margin": 0.0, "lance": true, "string_at": -1}
## Kept for the swords to come (the user's word, 2026-10-03: each sword its own
## swings), tried in the game as the running cut (`_shots_tmp/runcut_reel.gd`):
## KV_Attack1H05_R held wound up like the Rising Cut (a lunge and thrust), and
## Sword_Heavy_D unheld, the run carried on through the swing to its cut and a
## step past it (Player `_ease_delay`): a heavy chop out of a run.
const RUN_CUTS_KEPT := {
	&"thrust": {"clip": &"KV_Attack1H05_R", "rate": 1.0, "weight": 1.4, "hold": 0.15, "strike_gap": 1.0},
	&"heavy_chop": {"clip": &"Sword_Heavy_D", "rate": 1.1, "weight": 1.6},
}
## The charge behind the shield (TARIEL_POLISH.md, 4): UAL 2's Shield_Dash.
const SHIELD_BASH := &"Shield_Dash"
## Clips to measure with the sword besides the picks.
const CLIPS: Array[StringName] = [&"Sword_Dash", &"Sword_GroundPound", &"Sword_Aerial_Idle", &"Sword_Light_D",
	&"Shield_Dash", &"Sword_UpperCut", &"KV_Attack1H05_R",
	&"Sword_Heavy_A", &"Sword_Heavy_B", &"Sword_Heavy_C", &"Sword_Heavy_A_Rec", &"Sword_Heavy_B_Rec",
	&"Sword_Heavy_C_Rec"]


## Lays the design over `t`, a [method Moveset.build] table for the sword.
static func apply(t: Dictionary) -> void:
	t["alts"] = {}
	t["strings"] = [STRING.duplicate()]
	t["recover"] = RECOVER.duplicate()
	# both strings, each clip measured and played whole
	t["string_sets"] = STRINGS
	for s: Dictionary in STRINGS:
		for c: StringName in s["clips"]:
			t["flurry_part"][c] = Vector2(0.0, 1.0)
			_measure(t, c)
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
	t["clips"][&"shield_bash"] = SHIELD_BASH
	var run_cut: Dictionary = RUN_ATTACK.duplicate()
	t["run_attack"] = run_cut
	t["flurry_part"][run_cut["clip"]] = Vector2(0.0, 1.0)
	_measure(t, run_cut["clip"])
	var rising: Dictionary = RISING_CUT.duplicate()
	t["rising_cut"] = rising
	t["flurry_part"][rising["clip"]] = Vector2(0.0, 1.0)
	_measure(t, rising["clip"])
	var thrust: Dictionary = SHADOW_SLIDE.duplicate()
	t["shadow_slide"] = thrust
	var lance: Dictionary = SHADOW_LANCE.duplicate()
	t["shadow_lance"] = lance
	t["flurry_part"][lance["clip"]] = Vector2(0.0, 1.0)
	_measure(t, lance["clip"])
	t["flurry_part"][thrust["clip"]] = Vector2(0.0, 1.0)
	_measure(t, thrust["clip"])
	if not t["cut_window"].has(run_cut["clip"]):
		t["cut_window"][run_cut["clip"]] = Vector2(0.09, 0.17)
	for c: StringName in [evade["clip"], jump["clip"]]:
		var m := Moveset.clip_meta(c)
		if m.has("shield_turn"):
			t["shield_turn"][c] = float(m["shield_turn"])



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
