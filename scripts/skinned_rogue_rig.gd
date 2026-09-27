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
	# Now a knife's string, not a sword's: the slash down and back up, a low
	# thrust in (the reverse-grip stab of his knife-fighting set, only its
	# thrust), the spin, the backhand, a quick jab, and the big blow down to the
	# ground to end it. The one-handed sword combo's overhead cuts (3 to 5) are
	# gone: they went over anything shorter than a man.
	flurry = [&"DG_Combo_1", &"DG_Combo_2", &"DG_Stab_Reverse", &"DG_Spin_Cut", &"DG_Backhand_Cut",
			&"DG_Stab_Lead", &"DG_Finisher"]
	flurry_part = {
		&"DG_Stab_Reverse": Vector2(0.243, 0.487),
		&"DG_Stab_Lead": Vector2(0.06, 0.27),
	}
	flurry_reset_after = 1.0
	cut_window = {
		&"DG_Combo_1": Vector2(0.3, 0.8), &"DG_Combo_2": Vector2(0.15, 1.0),
		&"DG_Spin_Cut": Vector2(0.37, 0.84), &"DG_Combo_3": Vector2(0.25, 0.88),
		&"DG_Backhand_Cut": Vector2(0.2, 0.8), &"DG_Combo_4": Vector2(0.31, 0.88),
		&"DG_Combo_5": Vector2(0.0, 0.89), &"DG_Finisher": Vector2(0.35, 0.8),
		&"DG_Double_Stab": Vector2(0.326, 0.37), &"DG_Dual_Combo": Vector2(0.257, 0.743),
		&"DG_Stab_Reverse": Vector2(0.28, 0.41), &"DG_Stab_Lead": Vector2(0.083, 0.2),
	}
	# Thrown off a jump: the double stab from its raise to the stab going in.
	air_cut_from = 0.2
	plunge_from = 0.35
	roll_share = 0.8
	# Quick hands.
	swing_rate = 2.1
	swing_recovery = 0.12
	run_threshold = 3.0
	max_play_rate = 2.4
	# The knife: standing up out of the right fist at rest.
	blade_base = 0.075
	blade_tip = 0.42
	blade_rest_dir = Vector3.UP
	off_hand_blade = false
	# His own knife: its whooshes, its bite, his grunt.
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
	strike_heights = {&"DG_Stab_Reverse": 0.8, &"DG_Finisher": 0.7}
	strike_reach = 0.2
	strike_pull = 0.3


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
	var clip: StringName = clips[&"dodge"]
	if not _anim.has_animation(clip):
		return false
	return _play_action(clip, Role.ROLL, _anim.get_animation(clip).length / maxf(duration, 0.05), 0.06)


## A tap of the dash: the archer's quick step, whichever way it goes as the
## body sees it (+x its right, -y ahead).
func step_dodge(local: Vector2, duration: float) -> void:
	var key := &"step_fwd"
	if absf(local.x) > absf(local.y):
		key = &"step_right" if local.x > 0.0 else &"step_left"
	elif local.y > 0.0:
		key = &"step_back"
	var clip: StringName = clips[key]
	if not _anim.has_animation(clip):
		dodge(duration)
		return
	_play_action(clip, Role.ROLL, _anim.get_animation(clip).length / maxf(duration, 0.05), 0.05)


## Away from what he is facing: a backflip, still facing it.
func backflip(duration: float) -> void:
	var clip: StringName = clips[&"backflip"]
	if _anim.has_animation(clip):
		_play_action(clip, Role.ROLL, _anim.get_animation(clip).length / maxf(duration, 0.05), 0.05)


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
