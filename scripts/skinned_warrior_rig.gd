class_name SkinnedWarriorRig
extends SkinnedRig

## THE WARRIOR: two hands on one great sword, no shield, on a skeleton of his
## own. Anton Puzanov's Knight of darkness 2 (Unity Asset Store) keeps the
## bones it came with (the mannequin's names), and Mixamo's Great Sword pack is
## carried onto them (vepxis-art/tools/wr_build.py, out:
## assets/warrior/warrior.glb). Both fists are closed round the hilt at rest;
## in every clip the blade runs the way the Mixamo man's two palms run on his
## grip, the right hand turned to it and the left brought onto the hilt under
## it. Nothing follows Tariel: his cuts, walk and run are his own, and so is
## his weight (warrior.tres: slower to get going, to stop and to turn).
##
## Cut windows, trails and ground speeds measured in Blender
## (tools/wr_measure.py): the blade's tip past 55 % of its top speed cuts,
## past 30 % draws the arc; the planted foot's speed is the cycle's pace.

## The three blows of Mixamo's great sword combo, each a part of the one clip
## under a name of its own (so each has its own part, window and trail).
const COMBO := &"WR_Combo"
const COMBO_PARTS := [&"WR_Combo_A", &"WR_Combo_B", &"WR_Combo_C"]


func _ready() -> void:
	var player := find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if player != null and player.has_animation(COMBO):
		var lib := player.get_animation_library(&"")
		for n: StringName in COMBO_PARTS:
			if not lib.has_animation(n):
				lib.add_animation(n, player.get_animation(COMBO))
	super()


func _configure() -> void:
	clips = {
		&"idle": &"WR_Idle", &"walk": &"WR_Walk", &"run": &"WR_Run",
		&"walk_back": &"WR_WalkBack", &"run_back": &"WR_RunBack",
		&"walk_left": &"WR_StrafeL", &"walk_right": &"WR_StrafeR",
		&"run_left": &"WR_RunL", &"run_right": &"WR_RunR",
		# No shield: the blade held across him is his guard, if a table asks.
		&"block_idle": &"WR_Block", &"block_walk": &"WR_Walk",
		&"block_walk_back": &"WR_WalkBack", &"block_walk_left": &"WR_StrafeL",
		&"block_walk_right": &"WR_StrafeR",
		&"crouch": &"WR_Crouch", &"air": &"WR_Jump",
		&"roll": &"WR_Roll", &"down": &"WR_Death",
		&"hit": &"WR_HeadHit", &"hit_blocked": &"WR_Impact",
		&"mantle": &"WR_Jump", &"plunge": &"WR_JumpAttack",
		&"overhead": &"WR_Downward",
	}
	ground_speed = {
		&"WR_Walk": 1.1, &"WR_Run": 3.9, &"WR_WalkBack": 0.82, &"WR_RunBack": 1.9,
		&"WR_StrafeL": 0.94, &"WR_StrafeR": 1.0, &"WR_RunL": 2.3, &"WR_RunR": 2.7,
	}
	looping = [
		&"WR_Idle", &"WR_Walk", &"WR_Run", &"WR_WalkBack", &"WR_RunBack", &"WR_StrafeL",
		&"WR_StrafeR", &"WR_RunL", &"WR_RunR", &"WR_Block", &"WR_Crouch",
	]
	# His string: the great sword combo's three blows — across from his right,
	# back across low, and the big one from over the shoulder — and the high
	# spin to end it, the blade coming round twice. Slow, each one a weight
	# thrown; left for a beat it starts over.
	flurry = [&"WR_Combo_A", &"WR_Combo_B", &"WR_Combo_C", &"WR_HighSpin"]
	flurry_part = {
		&"WR_Combo_A": Vector2(0.06, 0.36), &"WR_Combo_B": Vector2(0.38, 0.62),
		&"WR_Combo_C": Vector2(0.64, 0.9), &"WR_HighSpin": Vector2(0.1, 0.74),
	}
	flurry_min_time = 0.5
	finisher_min_time = 0.75
	finisher_weight = 1.7
	flurry_reset_after = 1.3
	cut_window.merge({
		&"WR_Combo_A": Vector2(0.2, 0.27), &"WR_Combo_B": Vector2(0.465, 0.545),
		&"WR_Combo_C": Vector2(0.72, 0.79), &"WR_HighSpin": Vector2(0.18, 0.66),
		&"WR_Power": Vector2(0.35, 0.83), &"WR_JumpAttack": Vector2(0.47, 0.62),
		&"WR_Downward": Vector2(0.13, 0.56), &"WR_Low": Vector2(0.44, 0.57),
		&"WR_Slide": Vector2(0.56, 0.72),
	}, true)
	# The blows that cut twice cut in two windows, not through the swing
	# between them.
	cut_windows = {
		&"WR_HighSpin": [Vector2(0.18, 0.3), Vector2(0.55, 0.66)],
		&"WR_Power": [Vector2(0.35, 0.58), Vector2(0.7, 0.83)],
		&"WR_Downward": [Vector2(0.13, 0.19), Vector2(0.44, 0.56)],
	}
	trail_window = {
		&"WR_Combo_A": Vector2(0.19, 0.29), &"WR_Combo_B": Vector2(0.46, 0.55),
		&"WR_Combo_C": Vector2(0.71, 0.79), &"WR_HighSpin": Vector2(0.14, 0.68),
		&"WR_Power": Vector2(0.33, 0.83), &"WR_JumpAttack": Vector2(0.46, 0.65),
		&"WR_Downward": Vector2(0.1, 0.6), &"WR_Low": Vector2(0.42, 0.58),
		&"WR_Slide": Vector2(0.56, 0.78),
	}
	# The heavy blows, on the other button (no shield to raise), which one by
	# what the string has come to (Player._heavy_blow):
	#  0 out of nothing: the power slash, two great cuts stepping in;
	#  1 early in the string: the leap, and the blade brought down two-handed
	#    into the ground where the thing stands (the ground shakes);
	#  2 later: the cut down, and down again into the ground;
	#  3 at the end of the string: the low sweep;
	#  4 at a run: sliding in low under it and the blade coming up.
	heavy = [
		{"clip": &"WR_Power", "part": Vector2(0.1, 0.9), "rate": 1.2, "weight": 1.8, "step": 2.2, "rise": 0.86},
		{"clip": &"WR_JumpAttack", "part": Vector2(0.12, 0.86), "rate": 1.25, "weight": 2.2, "aim": false,
			"travel": 2.68, "slam": 0.6, "rise": 0.72},
		{"clip": &"WR_Downward", "part": Vector2(0.04, 0.8), "rate": 1.2, "weight": 2.0, "slam": 0.58,
			"rise": 0.7},
		{"clip": &"WR_Low", "part": Vector2(0.28, 0.82), "rate": 1.25, "weight": 1.9, "rise": 0.7},
		{"clip": &"WR_Slide", "part": Vector2(0.05, 0.9), "rate": 1.2, "weight": 2.0, "aim": false,
			"travel": 2.94, "rise": 0.8},
	]
	carried = {&"WR_JumpAttack": true, &"WR_Slide": true}
	# Off a jump: the jump attack from the top of its leap to the blade going in.
	air_cut_from = 0.42
	plunge_from = 0.6
	roll_share = 0.62
	# A great sword's pace: slower out of the guard, a longer ease from one
	# blow into the next.
	swing_rate = 1.25
	swing_recovery = 0.2
	action_blend = 0.15
	run_threshold = 3.0
	max_play_rate = 2.0
	# The blade from just over his right fist (the guard) to its point.
	blade_base = 0.12
	blade_tip = 1.35
	sword_mesh_name = "warrior_sword"
	# A broad, heavy arc, longer on the finisher and the heavy blows.
	arc_style = {"life": 0.3, "intensity": 1.0, "sheet": 0.6, "taper": 0.35, "smear": 1.0,
			"tip_overshoot": 0.1}
	arc_heavy_boost = 1.3
	# His cloak and coat are part of the model, skinned to his legs.
	cloth_enabled = false
	capes = []
	garbs = []
	garb_capes = []
	hairs = []
	hair_names = []
	mesh_prefix = "warrior"
	faces = [&"warrior"]
	face_skulls = faces.duplicate()
	face_names = ["THE WARRIOR"]
	whole_faces = [&"warrior"]
	# Swung at a man's chest; bent down to a puglin or a wolf.
	strike_aim = true
	strike_natural = 1.3
	strike_pull = 0.25
	# A heavier whoosh.
	swing_pitch = 0.82
	swing_volume = -16.0


## The blade lies along weapon_r's own length (its Y), whichever way the hand
## held it at rest: the socket's direction is read off the bone, not assumed.
func _setup_blade() -> void:
	var bone := _skel.find_bone("weapon_r")
	if bone >= 0:
		blade_rest_dir = (_skel.get_bone_global_rest(bone).basis * Vector3.UP).normalized()
	super()
