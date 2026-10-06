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
## And Mixamo's two-handed sword combo, his second string, the same way.
const COMBO2 := &"WR_Combo2"
const COMBO2_PARTS := [&"WR_Combo2_A", &"WR_Combo2_B", &"WR_Combo2_C"]
## Out of a fight he carries the sword on his right shoulder, one hand on it
## (the Mixamo idle and swagger walk under it, the arm laid there in Blender);
## a blow, a hit or a target puts both hands back on the hilt, and so many
## seconds of quiet lay it back on the shoulder.
const REST := &"WR_Rest"
const REST_WALK := &"WR_RestWalk"
const RELAX_AFTER := 4.0

## His two strings: the great sword combo standing (or set out from), the
## two-handed combo thrown on the move.
var string_still: Array[StringName] = []
var string_moving: Array[StringName] = []
var _fight_until: float = -100.0
var cloak: ClothBones


func _ready() -> void:
	var player := find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if player != null:
		var lib := player.get_animation_library(&"")
		for pair: Array in [[COMBO, COMBO_PARTS], [COMBO2, COMBO2_PARTS]]:
			if not player.has_animation(pair[0]):
				continue
			for n: StringName in pair[1]:
				if not lib.has_animation(n):
					lib.add_animation(n, player.get_animation(pair[0]))
	super()
	# The cloak: his own, hung as cloth (ClothBones), last of all, over the
	# body as it stands.
	if _skel != null:
		cloak = ClothBones.new()
		cloak.name = "Cloak"
		_skel.add_child(cloak)
		if not cloak.setup(_skel):
			cloak.queue_free()
			cloak = null


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
		&"WR_RestWalk": 1.66,
	}
	looping = [
		&"WR_Idle", &"WR_Walk", &"WR_Run", &"WR_WalkBack", &"WR_RunBack", &"WR_StrafeL",
		&"WR_StrafeR", &"WR_RunL", &"WR_RunR", &"WR_Block", &"WR_Crouch", &"WR_Rest", &"WR_RestWalk",
	]
	# His string: the great sword combo's three blows — across from his right,
	# back across low, and the big one from over the shoulder — and the high
	# spin to end it, the blade coming round twice. Slow, each one a weight
	# thrown; left for a beat it starts over.
	# On the move he throws the other one: Mixamo's two-handed sword combo,
	# cut from his right, back from his left, and over the head down, and the
	# heavy swing into the ground to end it.
	string_still = [&"WR_Combo_A", &"WR_Combo_B", &"WR_Combo_C", &"WR_HighSpin"]
	string_moving = [&"WR_Combo2_A", &"WR_Combo2_B", &"WR_Combo2_C", &"WR_HighSpin"]
	flurry = string_still.duplicate()
	flurry_part = {
		&"WR_Combo_A": Vector2(0.06, 0.36), &"WR_Combo_B": Vector2(0.38, 0.62),
		&"WR_Combo_C": Vector2(0.64, 0.9), &"WR_HighSpin": Vector2(0.1, 0.74),
		&"WR_Combo2_A": Vector2(0.05, 0.31), &"WR_Combo2_B": Vector2(0.31, 0.58),
		&"WR_Combo2_C": Vector2(0.58, 0.88),
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
		&"WR_Slide": Vector2(0.56, 0.72), &"WR_Combo2_A": Vector2(0.19, 0.245),
		&"WR_Combo2_B": Vector2(0.39, 0.5), &"WR_Combo2_C": Vector2(0.66, 0.79),
		&"WR_HeavySwing": Vector2(0.45, 0.56),
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
		&"WR_Slide": Vector2(0.56, 0.78), &"WR_Combo2_A": Vector2(0.15, 0.25),
		&"WR_Combo2_B": Vector2(0.38, 0.51), &"WR_Combo2_C": Vector2(0.66, 0.79),
		&"WR_HeavySwing": Vector2(0.44, 0.56),
	}
	# The heavy blows, on the other button (no shield to raise), which one by
	# what the string has come to (Player._heavy_blow):
	#  0 out of nothing: the power slash, two great cuts stepping in;
	#  1 early in the string: the leap, and the blade brought down two-handed
	#    into the ground where the thing stands (the ground shakes);
	#  2 later: the cut down, and down again into the ground;
	#  3 at the end of the string: the great swing round and into the ground;
	#  4 at a run: sliding in low under it and the blade coming up.
	heavy = [
		{"clip": &"WR_Power", "part": Vector2(0.1, 0.9), "rate": 1.2, "weight": 1.8, "step": 2.2, "rise": 0.86},
		{"clip": &"WR_JumpAttack", "part": Vector2(0.12, 0.86), "rate": 1.25, "weight": 2.2, "aim": false,
			"travel": 2.68, "slam": 0.6, "rise": 0.72},
		{"clip": &"WR_Downward", "part": Vector2(0.04, 0.8), "rate": 1.2, "weight": 2.0, "slam": 0.58,
			"rise": 0.7},
		{"clip": &"WR_HeavySwing", "part": Vector2(0.24, 0.72), "rate": 1.35, "weight": 2.1, "slam": 0.55,
			"rise": 0.66},
		{"clip": &"WR_Slide", "part": Vector2(0.05, 0.9), "rate": 1.2, "weight": 2.0, "aim": false,
			"travel": 2.94, "rise": 0.8},
	]
	# Every blow carries him as far as the man in the clip went (its travel is
	# on the root bone): the weight goes into the step, the step into the cut.
	carried = {&"WR_JumpAttack": true, &"WR_Slide": true, &"WR_Combo_A": true, &"WR_Combo_B": true,
			&"WR_Combo_C": true, &"WR_HighSpin": true, &"WR_Power": true, &"WR_Combo2_A": true,
			&"WR_Combo2_B": true, &"WR_Combo2_C": true}
	# Off a jump: the jump attack from the top of its leap to the blade going in.
	air_cut_from = 0.42
	plunge_from = 0.6
	roll_share = 0.62
	# A great sword's pace: slower out of the guard, a longer ease from one
	# blow into the next.
	swing_rate = 1.3
	# On the mannequin too: a great sword swung by a big man, slower than
	# the others' blows (MQ_SWING_RATE x0.82).
	mq_swing_scale = 0.82
	swing_recovery = 0.18
	# A great sword is slow to bring back (the user's word, 2026-10-06): once
	# a blow has cut, the blade comes back to guard slower than it went, the
	# end of a string slower still, and the stance eased back in over it.
	recover_pace = 0.78
	last_recover_pace = 0.55
	recover_blend = 0.35
	last_recover_blend = 0.55
	action_blend = 0.12
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
	# and YOUR OWN, made on the hero select out of Polysplit's heroes
	# ([PolysplitLook], `SkinnedRig._add_maker()`)
	polysplit_hero = &"warrior"
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


## Whether he holds the fighting stance: a blow in the last few seconds, a
## blow taken, or something locked on to.
func in_fight() -> bool:
	if Time.get_ticks_msec() / 1000.0 < _fight_until:
		return true
	return _body != null and _body.get(&"target") != null


func _wake() -> void:
	_fight_until = Time.get_ticks_msec() / 1000.0 + RELAX_AFTER


## A new string is picked by how he stands when it starts: standing, the
## great sword combo; on the move, the two-handed one.
func attack(style: int = -1) -> void:
	_wake()
	var now := Time.get_ticks_msec() / 1000.0
	var fresh := _flurry_slot < 0 or _flurry_slot >= flurry.size() - 1 \
			or (flurry_reset_after > 0.0 and now - _last_attack_at > flurry_reset_after)
	# (on the mannequin the strings are the picked ones, see SkinnedRig)
	if fresh and style < HEAVY and not _on_mq:
		var body := _body as CharacterBody3D
		var moving := body != null and Vector2(body.velocity.x, body.velocity.z).length() > 1.2
		flurry.assign(string_moving if moving else string_still)
		_flurry_slot = -1
	super(style)


func flinch() -> void:
	_wake()
	super()


func _pick_base(planar: float, airborne: bool, dashing: bool, vy: float, blocking: bool) -> void:
	# (on the mannequin the sword is not laid on his shoulder: his REST clips
	# hold his own great sword, not the figure's; the picked stance is used)
	if not _on_mq and not airborne and not blocking and not _crouching and not _wall_climbing and not in_fight():
		if planar < idle_threshold:
			_set_base(REST, 0.3, 1.0)
			return
		if planar <= run_threshold and _direction_clip(planar) == clips[&"walk"]:
			_set_base(REST_WALK, loco_blend, _rate(REST_WALK, planar))
			return
	super(planar, airborne, dashing, vy, blocking)
