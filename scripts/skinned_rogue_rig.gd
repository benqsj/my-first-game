class_name SkinnedRogueRig
extends SkinnedRig

## The assassin: one long knife, quick and light. Everything is the knight's
## rig; this is his clip table — Mixamo's knife stabs, the double stab and the
## dual combo, a ninja's idle and run, flips to get out of trouble — and the
## knife in his right hand, built in Blender (`tools/hero_round3.py`).
##
## Source: `~/Desktop/vepxis-art/heroes/heroes.blend` (`dagger_rig`), built by
## `tools/hero_rig.py` and dressed by `tools/hero_dress.py`; the cut windows and
## the ground speeds below were measured there.


func _configure() -> void:
	clips = {
		&"idle": &"DG_Idle", &"walk": &"DG_Walk", &"run": &"DG_Run",
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
		&"roll": &"DG_Roll", &"dodge": &"DG_Backflip", &"down": &"DG_Death",
		&"hit": &"DG_Hit", &"hit_blocked": &"DG_Hit",
		&"mantle": &"DG_Mantle", &"plunge": &"DG_Double_Stab",
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
		&"DG_Idle", &"DG_Idle_Knife", &"DG_Walk", &"DG_Run", &"DG_Walk_Back", &"DG_Run_Back",
		&"DG_Walk_Left", &"DG_Walk_Right", &"DG_Run_Left", &"DG_Run_Right", &"DG_Crouch",
		&"DG_Sneak", &"DG_Crouch_Walk_Back", &"DG_Crouch_Walk_Left", &"DG_Crouch_Walk_Right",
		&"DG_Fall",
	]
	# Three stabs, round and round, all with the knife hand: the rear-hand
	# thrust, the lead stab mirrored onto the right (DG_Stab_Lead_R, flipped
	# in Blender), and the reverse-grip cut.
	flurry = [&"DG_Stab_Rear", &"DG_Stab_Lead_R", &"DG_Stab_Reverse"]
	cut_window = {
		&"DG_Stab_Lead": Vector2(0.211, 0.324), &"DG_Stab_Lead_R": Vector2(0.211, 0.324),
		&"DG_Stab_Rear": Vector2(0.469, 0.531),
		&"DG_Stab_Reverse": Vector2(0.241, 0.354), &"DG_Double_Stab": Vector2(0.326, 0.37),
		&"DG_Dual_Combo": Vector2(0.257, 0.743),
	}
	# Thrown off a jump: the double stab from its raise to the stab going in.
	air_cut_from = 0.2
	plunge_from = 0.35
	roll_share = 0.8
	# Quick hands.
	swing_rate = 2.5
	swing_recovery = 0.12
	run_threshold = 3.0
	max_play_rate = 2.4
	# The knife: standing up out of the right fist at rest.
	blade_base = 0.075
	blade_tip = 0.42
	blade_rest_dir = Vector3.UP
	off_hand_blade = false
	# The sword's whoosh, a dagger's worth higher.
	swing_pitch = 1.45
	cloth_enabled = false


func dodge_clip(duration: float) -> bool:
	var clip: StringName = clips[&"dodge"]
	if not _anim.has_animation(clip):
		return false
	return _play_action(clip, Role.ROLL, _anim.get_animation(clip).length / maxf(duration, 0.05), 0.06)
