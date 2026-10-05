class_name SkinnedRogueRig
extends SkinnedRig

## The assassin: one long knife, quick and light. Everything is the knight's
## rig; this is his clip table — a five-blow combo cut out of Mixamo's
## one-handed sword combo, a fighter's idle, a man's walk and run, a forward
## flip and a twisting flip to get out of trouble — and the knife in his right
## hand, built in Blender (`tools/hero_round3.py`).
##
## Source: `~/Desktop/vepxis-art/heroes/heroes.blend` (`dagger_rig`), built by
## `tools/hero_rig.py` and dressed by `tools/hero_dress.py`; the cut windows and
## the ground speeds below were measured there.


func _configure() -> void:
	# A short dark cape with a crimson hem, and the scarf's two tails over it.
	var body := [["pelvis", "neck_01", 0.16], ["thigh_l", "calf_l", 0.1], ["thigh_r", "calf_r", 0.1],
			["calf_l", "foot_l", 0.085], ["calf_r", "foot_r", 0.085]]
	capes = [{
		"bone": "spine_02", "left": [0.22, 0.15, 1.52], "right": [-0.22, 0.15, 1.52],
		"length": 0.72, "spread": 1.25, "flare": 0.08, "wrap": 0.1, "cols": 6, "rows": 8,
		"base": Color.html("30333f"), "hem": Color.html("8e1222"), "trim": Color.html("5c0b16"),
		"hold": 0.5, "wind": 1.0, "drag": 0.6, "colliders": body,
	}, {
		"bone": "spine_02", "left": [0.13, 0.17, 1.5], "right": [0.03, 0.17, 1.5],
		"length": 0.32, "spread": 0.9, "flare": 0.03, "wrap": 0.0, "cols": 2, "rows": 5,
		"base": Color.html("8e1222"), "hem": Color.html("5c0b16"), "trim": Color.html("8e1222"),
		"hold": 0.35, "wind": 1.4, "drag": 0.7, "colliders": [["pelvis", "neck_01", 0.17]],
	}]
	# His outfits (see [Inventory]), the first worn; each hangs the cape and the
	# scarf's tail its own way.
	garbs = [&"rogue_sand_shorts", &"rogue_wraith_red", &"rogue_nightblade", &"rogue_crimson",
			&"rogue_wraith_white", &"rogue_sandstrider", &"rogue_shade_shorts", &"rogue_ash_shorts"]
	garb_capes = [
		# the loose sand top and short breeches: no cape, no scarf tail
		[{"off": true}, {"off": true}],
		# a short cape cut to a point at the back, narrower at the shoulders
		[{"left": [0.17, 0.16, 1.5], "right": [-0.17, 0.16, 1.5], "length": 0.46, "point": 0.55,
			"spread": 1.1, "flare": 0.06, "wrap": 0.08, "cols": 7, "rows": 8, "base": Color.html("111114"),
			"hem": Color.html("8e1222"), "trim": Color.html("5c0b16"), "pattern": "plain"}, {"off": true}],
		[{"base": Color.html("1c202c"), "hem": Color.html("8e1222"), "trim": Color.html("5c0b16")}, {}],
		[{"length": 0.55, "spread": 1.15, "base": Color.html("701823"), "hem": Color.html("4a0f18"),
			"trim": Color.html("4a0f18")}, {"off": true}],
		[{"length": 1.2, "spread": 1.3, "base": Color.html("111114"), "hem": Color.html("e3ded2"),
			"trim": Color.html("bfb8aa"), "pattern": "plain"}, {"off": true}],
		[{"off": true}, {"off": true}],
		[{"off": true}, {"base": Color.html("8e1222"), "hem": Color.html("5c0b16"), "trim": Color.html("8e1222")}],
		[{"off": true}, {"off": true}],
	]
	clips = {
		# Standing square, both feet under him and the knife low in his hand
		# (Mixamo's standing idle, the legs and hips set straight in Blender,
		# tools/dg9_build.py) — not the fighter's side-on guard he had.
		&"idle": &"DG_Stand", &"walk": &"DG_Walk", &"run": &"DG_Run",
		&"walk_back": &"DG_Walk_Back", &"run_back": &"DG_Run_Back",
		&"walk_left": &"DG_Walk_Left", &"walk_right": &"DG_Walk_Right",
		&"run_left": &"DG_Run_Left", &"run_right": &"DG_Run_Right",
		# No shield, so no guard; the table still has to name something.
		&"block_idle": &"DG_Idle_Knife", &"block_walk": &"DG_Walk",
		&"block_walk_back": &"DG_Walk_Back", &"block_walk_left": &"DG_Walk_Left",
		&"block_walk_right": &"DG_Walk_Right",
		&"crouch": &"DG_Crouch", &"air": &"DG_Fall",
		&"crouch_walk": &"DG_Sneak", &"crouch_walk_back": &"DG_Crouch_Walk_Back",
		&"crouch_walk_left": &"DG_Crouch_Walk_Left", &"crouch_walk_right": &"DG_Crouch_Walk_Right",
		# One tap is a forward flip out of trouble, two a twisting one: both
		# carry him the way he is going, as the body does.
		&"roll": &"DG_Flip", &"dodge": &"DG_Twist", &"down": &"DG_Death",
		&"hit": &"DG_Hit", &"hit_blocked": &"DG_Hit",
		&"mantle": &"DG_Hang_To_Crouch", &"plunge": &"DG_Double_Stab",
		&"climb_up": &"DG_Climb_Up", &"climb_down": &"DG_Climb_Down",
		&"shimmy_left": &"DG_Shimmy_Left", &"shimmy_right": &"DG_Shimmy_Right",
		&"hang": &"DG_Hang",
		&"step_fwd": &"DG_Dodge_Fwd", &"step_back": &"DG_Dodge_Back",
		&"step_left": &"DG_Dodge_Left", &"step_right": &"DG_Dodge_Right",
		&"backflip": &"DG_Backflip",
		&"overhead": &"DG_Dual_Combo",
	}
	ground_speed = {
		# Mixamo's walks and runs (tools/retarget_mixamo.py), measured off the
		# root bone: a man's walk and run, upright, rather than a ninja's.
		&"DG_Walk": 0.92, &"DG_Run": 3.72, &"DG_Walk_Back": 0.47, &"DG_Run_Back": 2.67,
		&"DG_Walk_Left": 1.46, &"DG_Walk_Right": 1.46, &"DG_Run_Left": 3.81, &"DG_Run_Right": 3.05,
		&"DG_Sneak": 1.98, &"DG_Crouch_Walk_Back": 0.89, &"DG_Crouch_Walk_Left": 1.14,
		&"DG_Crouch_Walk_Right": 1.17,
	}
	looping = [
		&"DG_Idle", &"DG_Stand", &"DG_Idle_Knife", &"DG_Walk", &"DG_Run", &"DG_Walk_Back", &"DG_Run_Back",
		&"DG_Walk_Left", &"DG_Walk_Right", &"DG_Run_Left", &"DG_Run_Right", &"DG_Crouch",
		&"DG_Sneak", &"DG_Crouch_Walk_Back", &"DG_Crouch_Walk_Left", &"DG_Crouch_Walk_Right",
		&"DG_Fall", &"DG_Climb_Up", &"DG_Climb_Down", &"DG_Shimmy_Left", &"DG_Shimmy_Right",
		&"DG_Hang",
	]
	# Eight blows that run into each other, all cut tight to the blow itself
	# in Blender so the knife is moving from the first frame: the five of
	# Mixamo's one-handed sword combo, a spinning cut and a backhand from its
	# axe set, and a last big blow off its three-hit combo. Each starts about
	# where the last left the blade, so a string of clicks is one long, quick,
	# turning combo. Left alone for a second it starts again from the first.
	# A knife's string, each cut starting where the last one left the knife
	# (the ends and starts matched by the knife's tip, measured in Blender): the
	# slash down and back up, the spin, the backhand, the long sweep from high
	# right to low left, and the blow down to the ground to end it. No cut
	# faster than `flurry_min_time`, the last no faster than
	# `finisher_min_time`: the tightest of them were a blur at his pace.
	# The string ends in a whirl now, as the dual blades do in the user's
	# Dragonwilds video: a whole turn low on his feet, both knives drawing a
	# ring round him and the right one coming up out of it (the axe's turn and
	# rising cut, the same clip as Tariel's last). The blow down to the ground
	# it replaced is still his, among the heavy ones (DG_Axe_Three).
	# And now a string for two knives, not for a sword and a shield: the first
	# cuts were the one-handed sword's, the left hand tucked to the chest as if
	# it held a shield, only the right knife moving — a man flailing one knife.
	# Now both work, as a knife-fighter's do: both knives thrown out wide, both
	# brought back in across him, then Mixamo's dual-blade combo cut into its
	# three blows (left then right; both at once; both again, the other way —
	# DG_Dual_A/B/C, copies of DG_Dual_Combo, measured off the hands' speed in
	# Blender), and the whirl to end it.
	flurry = [&"DG_Slash_Out", &"DG_Slash_In", &"DG_Dual_A", &"DG_Dual_B", &"DG_Dual_C", &"DG_Whirl"]
	flurry_part = {
		&"DG_Slash_Out": Vector2(0.22, 0.6), &"DG_Slash_In": Vector2(0.36, 0.7),
		&"DG_Dual_A": Vector2(0.1, 0.36), &"DG_Dual_B": Vector2(0.36, 0.57),
		&"DG_Dual_C": Vector2(0.57, 0.82), &"DG_Whirl": Vector2(0.1, 0.62),
	}
	flurry_quicken = 0.0
	flurry_min_time = 0.36
	finisher_min_time = 0.46
	finisher_weight = 1.35
	# The heavy blows, on the other button (he has no shield to raise): which
	# one is what the string has come to (see Player._heavy_blow).
	#  0 out of nothing: a lunge in with the point and a slash back out;
	#  1 early in the string: a spinning leap, a kick and the knife coming down,
	#    down onto the ground and rolling up onto his feet again, whole (the
	#    getting up is part of it: cut short, he sprang up out of the ground);
	#    once the cuts are done an evade takes him out of the getting up;
	#  2 later: three great cuts, the last from over his head to the ground;
	#  3 at the end of the string: the whirling combo, round and through;
	#  4 at a run: a flying front flip, the knife coming down as he lands.
	heavy = WIND_HEAVY.duplicate(true)
	cut_windows = {
		&"DG_Thrust_Slash": [Vector2(0.211, 0.267), Vector2(0.456, 0.522)],
		&"DG_Spin_Flip_Kick": [Vector2(0.369, 0.441), Vector2(0.45, 0.559)],
		&"DG_Axe_Three": [Vector2(0.175, 0.27), Vector2(0.373, 0.46), Vector2(0.571, 0.651)],
		&"DG_Dual_Combo": [Vector2(0.248, 0.321), Vector2(0.468, 0.514), Vector2(0.67, 0.761)],
		&"DG_Big_Flip": [Vector2(0.8, 0.96)],
	}
	carried = {&"DG_Spin_Flip_Kick": true, &"DG_Big_Flip": true, &"DG_Dual_Combo": true}
	# Both knives cut the air bright and broad, as the dual blades do in the
	# user's Dragonwilds videos; the heavy blows and the last cut of the string
	# brighter and longer still.
	# The rings drawn wider than the short knife itself, as in the video.
	arc_style = {"life": 0.26, "intensity": 1.0, "sheet": 0.6, "taper": 0.3, "smear": 1.0,
			"tip_overshoot": 0.6}
	arc_heavy_boost = 1.25
	flurry_reset_after = 1.0
	cut_window = {
		&"DG_Combo_1": Vector2(0.3, 0.8), &"DG_Combo_2": Vector2(0.15, 1.0),
		&"DG_Spin_Cut": Vector2(0.37, 0.84), &"DG_Combo_3": Vector2(0.25, 0.88),
		&"DG_Backhand_Cut": Vector2(0.2, 0.8), &"DG_Combo_4": Vector2(0.31, 0.88),
		&"DG_Combo_5": Vector2(0.0, 0.89), &"DG_Finisher": Vector2(0.35, 0.8),
		&"DG_Double_Stab": Vector2(0.326, 0.37), &"DG_Dual_Combo": Vector2(0.257, 0.743),
		&"DG_Slash_Out": Vector2(0.38, 0.49), &"DG_Axe_R2L": Vector2(0.319, 0.486),
		&"DG_Thrust_Slash": Vector2(0.211, 0.267), &"DG_Spin_Flip_Kick": Vector2(0.369, 0.441),
		&"DG_Axe_Three": Vector2(0.175, 0.27), &"DG_Big_Flip": Vector2(0.8, 0.96),
		&"DG_Whirl": Vector2(0.253, 0.411),
		&"DG_Slash_In": Vector2(0.47, 0.6), &"DG_Dual_A": Vector2(0.15, 0.33),
		&"DG_Dual_B": Vector2(0.43, 0.52), &"DG_Dual_C": Vector2(0.66, 0.75),
	}
	trail_window = {
		&"DG_Whirl": Vector2(0.23, 0.44), &"DG_Slash_Out": Vector2(0.34, 0.52),
		&"DG_Slash_In": Vector2(0.44, 0.63), &"DG_Dual_A": Vector2(0.13, 0.35),
		&"DG_Dual_B": Vector2(0.41, 0.55), &"DG_Dual_C": Vector2(0.63, 0.78),
	}
	# Thrown off a jump: the double stab from its raise to the stab going in.
	air_cut_from = 0.2
	plunge_from = 0.35
	roll_share = 0.8
	# One blow eased into the next over a little longer than a man's: at his
	# pace the knight's 0.1 s is a snap from pose to pose.
	action_blend = 0.14
	# Quick hands.
	swing_rate = OWN_SWING_RATE
	# his blows are made for knives: a short sword in either hand is slower
	arms_ref = PolysplitLook.arm_speed("dagger")
	swing_recovery = 0.12
	run_threshold = 3.0
	max_play_rate = 2.4
	# The knife: lying forward out of the thumb's side of the right fist at
	# rest, as Tariel's sword does. It stood up out of the back of the fist
	# before, and every Mixamo blow — made for a blade held the other way —
	# turned it over into a reverse grip as the wrist turned to cut, and the
	# cut in the air with it.
	blade_base = 0.075
	blade_tip = 0.42
	blade_rest_dir = Vector3(0, 0, 1)
	# The one made real carries a second knife in his left hand; it draws its
	# ring too (it does not cut: the right one does).
	off_hand_blade = true
	off_hand_whole_only = true
	# Who he is, picked on the hero select (tools/dg13_ranger.py): Quaternius'
	# Ranger (CC0) fitted onto his rig, in its brown leather and sand linen —
	# THE BLADE with the hood up and his face under it, THE SHADE with the
	# hood off, long hair, and a dark cloth over all his face but the eyes —
	# each with a cloak; or the one of boxes he was, who wears the outfits in
	# the bag.
	mesh_prefix = "rogue"
	# and YOUR OWN, made on the hero select out of Polysplit's heroes
	# ([PolysplitLook], `SkinnedRig._add_maker()`)
	polysplit_hero = &"rogue"
	# Or Synty's Sidekick on its own skeleton, which follows his
	# ([FigureFollower]), with his own knives cut out of his model
	# (vepxis-art/tools/fig_hero.py, tools/sk_build.py): THE FOX MASK in the
	# mask and its hood, the wanderer's coat in reds; THE HOOD in the deep
	# hood with a cloth over his mouth, in dark steel and blue.
	# Only THE FOX MASK is worn (2026-10-02, the user's pick): THE BLADE, THE
	# SHADE, AS HE WAS, THE HOOD and THE NINJA were taken off the hero select.
	faces = [&"foxmask"]
	face_skulls = faces.duplicate()
	face_names = ["THE FOX MASK"]
	whole_faces = [&"foxmask"]
	figures = {
		&"sidekick": {"scene": "res://assets/rogue_sidekick/rogue_sidekick.glb", "prefix": "sk",
			"hips": &"pelvis", "map": SkinnedRig.sidekick_map({&"weapon_r": &"weapon_r", &"weapon_l": &"weapon_l"})},
	}
	figure_faces = {
		&"foxmask": {"figure": &"sidekick", "show": ["foxmask"]},
	}
	# Sidekick's men are made for one blade (the fox mask carries one sword,
	# at his hip): so one knife, in the right fist, no ring off the empty left
	# hand, and the one-handed string he had before the two-knife one —
	# Mixamo's one-handed sword combo (the left hand tucked to the chest), the
	# spinning cut, the backhand, the axe's cut from right to left and the
	# whirl to end it. The two-knife heavy blow gives way to the one-handed
	# combo's last big blow.
	var one_heavy: Array = WIND_HEAVY_ONE.duplicate(true)
	var one_knife := {
		"flurry": [&"DG_Combo_1", &"DG_Combo_2", &"DG_Spin_Cut", &"DG_Backhand_Cut", &"DG_Axe_R2L", &"DG_Whirl"],
		"flurry_part": {&"DG_Axe_R2L": Vector2(0.236, 0.597), &"DG_Whirl": Vector2(0.1, 0.62)},
		"heavy": one_heavy, "off_hand": false, "hide_arms": ["arm_knife_l"],
	}
	face_moves = {&"foxmask": one_knife}
	# His own knife: its whooshes, its bite, his grunt.
	heft_swings = false
	swing_sounds = [
		"res://unverified/sounds/assassin/swing_1.wav", "res://unverified/sounds/assassin/swing_2.wav",
		"res://unverified/sounds/assassin/swing_3.wav", "res://unverified/sounds/assassin/swing_4.wav",
	]
	swing_pitch = 1.0
	swing_volume = -17.0
	hit_sounds = [
		"res://unverified/sounds/assassin/hit_1.wav", "res://unverified/sounds/assassin/hit_2.wav",
		"res://unverified/sounds/assassin/hit_3.wav",
	]
	hit_volume = -13.0
	hurt_sounds = ["res://unverified/sounds/assassin/hurt_1.wav"]
	hurt_volume = -15.0
	cloth_enabled = false
	# A short knife cuts what is in front of him wherever it is: bent down to a
	# puglin or a wolf on the ground, a hand longer for the hit than it looks.
	strike_aim = true
	strike_natural = 1.25
	strike_heights = {&"DG_Finisher": 0.7, &"DG_Slash_Out": 0.8, &"DG_Axe_R2L": 1.0, &"DG_Thrust_Slash": 0.85}
	strike_reach = 0.2
	strike_pull = 0.3


## The heavy blows, on the other button (the user's word, 2026-10-05: not the
## flips and falls he had). Each is wound up first, slowly, and then let go
## all at once (`wind`, the share of the clip the gathering ends at;
## `wind_rate`, its pace; `rate`, the pace of what follows). Which one is
## what the string has come to ([method Player._heavy_blow]):
##  - on its own (out of nothing, or at a run): a long gathering edging in
##    (`creep`, metres), then he throws himself in (`lunge`) and three blows
##    come quick as one;
##  - after cuts of the string: the gathering on the spot and the three quick
##    blows (the user liked it as it was).
## Both are the two-knife combo (DG_Dual_Combo), played on his own rig and on
## the mannequin alike (the DG clips are carried onto it).
const RUSH_IN := {"clip": &"DG_Dual_Combo", "part": Vector2(0.1, 0.86), "wind": 0.23, "wind_rate": 0.95,
		"rate": 3.0, "weight": 1.5, "step": 0.0, "creep": 0.7, "lunge": 6.5, "rise": 0.8,
		"stamina_share": 0.33}
const THREE_QUICK := {"clip": &"DG_Dual_Combo", "part": Vector2(0.1, 0.86), "wind": 0.23, "wind_rate": 1.15,
		"rate": 2.7, "weight": 1.35, "step": 0.8, "rise": 0.8}
const WIND_HEAVY := [RUSH_IN, THREE_QUICK, THREE_QUICK, THREE_QUICK, RUSH_IN]
## With one blade (the other hand empty, the user's word 2026-10-05): the same
## gathering and rush, but the blows one-handed — the axe's three great cuts
## (DG_Axe_Three: right, back, and over the head down), the left hand out of it.
const RUSH_IN_ONE := {"clip": &"DG_Axe_Three", "part": Vector2(0.02, 0.72), "wind": 0.16, "wind_rate": 1.05,
		"rate": 2.7, "weight": 1.6, "step": 0.0, "creep": 0.7, "lunge": 6.5, "rise": 0.7,
		"stamina_share": 0.33}
const THREE_ONE := {"clip": &"DG_Axe_Three", "part": Vector2(0.06, 0.72), "wind": 0.16, "wind_rate": 1.25,
		"rate": 2.5, "weight": 1.45, "step": 0.8, "rise": 0.7}
const WIND_HEAVY_ONE := [RUSH_IN_ONE, THREE_ONE, THREE_ONE, THREE_ONE, RUSH_IN_ONE]


## Whether he holds a blade in each hand now: on the mannequin by his look's
## arms ([method Moveset.two_blades]); on his own rig every look but the one
## that holds one knife.
func two_blades() -> bool:
	if _on_mq:
		return moves.get("kind", &"") == &"dual"
	return face_moves.get(faces[face] if face < faces.size() else &"", {}).is_empty()


const OWN_SWING_RATE := 2.1
## On the mannequin, with knives (`arms_ref`, a knife's pace): his own cuts a
## touch slower than on his own rig (the user's word, 2026-10-05: too quick);
## a short sword in either hand plays them slower still (x1/1.2).
const MQ_KNIFE_RATE := 2.22
## Two blades or one (the user's word, 2026-10-05, after measuring with
## `_shots_tmp/as/dps.gd`): two cut more often, a little lighter each, and
## dearer — his stamina gone in about four seconds of cutting; one cuts less
## often, harder, cheaper — about six. About the same harm a second either way.
## The crit is the same for both.
const TWO_BLADES := {"damage": 0.95, "stamina": 10.0}
## (One blade's string is three cuts, its last the heavier one every third
## blow instead of every sixth: at x1.0 it already lands as hard a second as
## two blades at x0.95 — measured 2.56 against 2.49.)
const ONE_BLADE := {"damage": 1.0, "stamina": 7.0, "pace": 0.9}


## On the mannequin the picks give him a heavy blow of their own; his own,
## wound up, are kept.
func _wear_moves() -> void:
	super()
	# One knife: always the whole three-cut string, its last blow the turning
	# one (the user's word, 2026-10-05: he liked it, and it came only now and
	# then, a new string picked at random between it and the two-cut one).
	if _on_mq and not two_blades() and _strings.size() > 1:
		var whole: Array = _strings[0]
		for st: Array in _strings:
			if st.size() > whole.size():
				whole = st
		_strings = [whole]
		flurry.assign(whole)
	# (no cut quicker than this: his own 0.36 held the two-blade string back)
	if _on_mq:
		flurry_min_time = 0.3
	# one blade: a tenth slower than the picks' pace
	if _on_mq and not two_blades():
		for c: StringName in flurry:
			clip_rate[c] = MQ_SWING_RATE * mq_swing_scale * float(ONE_BLADE["pace"])
	# his own knife cuts at his own rig's pace, whatever the picks' is (they
	# were made slow: at the mannequin's 1.1 they were half his speed)
	for c: StringName in flurry:
		if String(c).begins_with("DG_"):
			clip_rate[c] = MQ_KNIFE_RATE * mq_swing_scale
	heavy = (WIND_HEAVY if two_blades() else WIND_HEAVY_ONE).duplicate(true)


## The evades played no faster than a man can be seen to move (the user's
## word, 2026-10-05: they were a blur at two to four times their pace): of
## each clip only the stretch where he goes (measured off its root in
## `_shots_tmp/as/curves.py`), not the gathering before it or the standing
## up after, which the next move blends over.
const EVADE_PART := {
	&"DG_Dodge_Fwd": Vector2(0.12, 0.9), &"DG_Dodge_Back": Vector2(0.08, 0.66),
	&"DG_Dodge_Left": Vector2(0.06, 0.88), &"DG_Dodge_Right": Vector2(0.06, 0.85),
	&"DG_Twist": Vector2(0.0, 0.75), &"DG_Backflip": Vector2(0.12, 0.58),
}


func _evade(clip: StringName, duration: float, blend: float) -> bool:
	if not _anim.has_animation(clip):
		return false
	var part: Vector2 = EVADE_PART.get(clip, Vector2(0.0, 1.0))
	var length := _anim.get_animation(clip).length
	return _play_action(clip, Role.ROLL, length * (part.y - part.x) / maxf(duration, 0.05), blend, part.x, part.y)


## The run leaned into, on whichever skeleton he wears ([RunLean]).
const LEAN_RUN := 0.16
const LEAN_SPRINT := 0.2
var _leans: Dictionary = {}
var _lean_now: float = 0.0


func animate(delta: float, planar_speed: float, speed_ratio: float, airborne: bool,
		dashing: bool, vertical_speed: float, blocking: bool = false) -> void:
	super(delta, planar_speed, speed_ratio, airborne, dashing, vertical_speed, blocking)
	var skel: Skeleton3D = _mq.get("skel") if _on_mq else _skel
	if skel == null:
		return
	var lean: RunLean = _leans.get(skel)
	if lean == null or not is_instance_valid(lean):
		lean = RunLean.new()
		lean.name = "RunLean"
		skel.add_child(lean)
		_leans[skel] = lean
	var want := 0.0
	if _role == Role.NONE and not airborne and not dashing:
		if _base_clip == clips.get(&"sprint", &"-"):
			want = LEAN_SPRINT
		elif _base_clip == clips.get(&"run", &"-") or _base_clip == clips.get(&"jog", &"-"):
			want = LEAN_RUN * clampf(planar_speed / 5.0, 0.0, 1.0)
	_lean_now = move_toward(_lean_now, want, delta * 0.9)
	for s: Skeleton3D in _leans:
		var l: RunLean = _leans[s]
		if is_instance_valid(l):
			l.amount = _lean_now if s == skel else 0.0
			# his face (the rig is turned about: its +Z is the way he faces)
			l.forward = global_basis.z


## With a blade in each hand both cut: the edge given to whatever asks is the
## one going faster this tick (a blow of the left hand is the left knife's).
var _edges_tick: int = -1
var _edge_r_was := Vector3.ZERO
var _edge_l_was := Vector3.ZERO
var _left_edge: bool = false


func get_cutting_edge() -> PackedVector3Array:
	var edge := super()
	if edge.is_empty() or _blade_tip_l == null or _blade_base_l == null or not two_blades() \
			or not _off_hand_on:
		return edge
	var tick := Engine.get_physics_frames()
	if tick != _edges_tick:
		var r := _blade_tip.global_position
		var l := _blade_tip_l.global_position
		if _edges_tick == tick - 1:
			_left_edge = l.distance_to(_edge_l_was) > r.distance_to(_edge_r_was) * 1.15
		else:
			_left_edge = false
		_edge_r_was = r
		_edge_l_was = l
		_edges_tick = tick
	if not _left_edge:
		return edge
	var base := _blade_base_l.global_position
	var tip := _blade_tip_l.global_position
	var along := tip - base
	if along.length_squared() > 0.0001:
		tip += along.normalized() * strike_reach
	return PackedVector3Array([base, tip])


## A blow's worth by what he holds (see `TWO_BLADES`, `ONE_BLADE`).
func attack(style: int = -1) -> void:
	super(style)
	cut_weight *= float((TWO_BLADES if two_blades() else ONE_BLADE)["damage"])


## What a light blow costs him, by what he holds (the profile's 9 as asked of
## him by [Player]).
func blow_stamina(cost: float) -> float:
	var arms: Dictionary = TWO_BLADES if two_blades() else ONE_BLADE
	return cost * float(arms["stamina"]) / 9.0


## The Poisoned Blade's coat (`DG_Poison_Coat`, built in Blender by
## `tools/dg9_build.py`): the knife brought up before his chest, two fingers of
## the other hand run along it from the guard to the point, the excess flicked
## off. Returns how long it takes at `rate`.
const COAT_CLIP := &"DG_Poison_Coat"


func coat_length(rate: float) -> float:
	if _anim == null or not _anim.has_animation(COAT_CLIP):
		return 1.2
	return _anim.get_animation(COAT_CLIP).length / maxf(rate, 0.01)


func coat_blade(rate: float) -> float:
	var t := play_part(COAT_CLIP, rate, 0.0, 1.0, 0.12)
	# he walks on while he does it: the legs take the walk under the arms
	walk_under = t > 0.0
	return t if t > 0.0 else 1.2


func dodge_clip(duration: float) -> bool:
	return _evade(clips[&"dodge"], duration, 0.06)


## A tap of the dash: the archer's quick step, whichever way it goes as the
## body sees it (+x its right, -y ahead).
func step_dodge(local: Vector2, duration: float) -> void:
	var key := &"step_fwd"
	if absf(local.x) > absf(local.y):
		key = &"step_right" if local.x > 0.0 else &"step_left"
	elif local.y > 0.0:
		key = &"step_back"
	if not _evade(clips[key], duration, 0.05):
		dodge(duration)


## Away from what he is facing: a backflip, still facing it.
func backflip(duration: float) -> void:
	_evade(clips[&"backflip"], duration, 0.05)


## On a wall: hanging, climbing up or down, or shimmying along — the archer's
## way, off Mixamo's climbs retargeted onto his rig.
const CLIMB_UP_SPEED := 0.53
const SHIMMY_SPEED := 0.25


func _pick_base(planar: float, airborne: bool, dashing: bool, vy: float, blocking: bool) -> void:
	if _wall_climbing:
		var drive := _climb_drive
		if drive.length() < 0.15 or _climb_speed < 0.05:
			_set_base(clips[&"hang"], 0.2, 1.0)
		elif absf(drive.y) >= absf(drive.x):
			_set_base(clips[&"climb_up"] if drive.y > 0.0 else clips[&"climb_down"], 0.2,
					clampf(_climb_speed / CLIMB_UP_SPEED, 0.4, 3.0))
		else:
			_set_base(clips[&"shimmy_right"] if drive.x > 0.0 else clips[&"shimmy_left"], 0.2,
					clampf(_climb_speed / SHIMMY_SPEED, 0.4, 3.0))
		return
	super(planar, airborne, dashing, vy, blocking)
