class_name GreatSword
extends RefCounted
## The knight's great sword on the UE mannequin (YOUR OWN holding a great
## sword, a great axe or a pole: [Moveset] kind `two_hands`), laid over what
## [Moveset] builds out of the lab's picks (the user's word, 2026-10-06):
## - he fights on both buttons, in one of two ways F6 goes between (the
##   user's word, 2026-10-06, 16:21): one hand on the attack button (Kevin's
##   1H, the blade swung from the right fist, the other hand let go of the
##   grip by `SkinnedRig.hilt_hand` wherever a clip takes it off) and both
##   hands on the block button (no shield to raise; Kevin's 2H, the lab's
##   CUT 1-4); or both hands on the attack button and, on the block button,
##   what Tariel's block button throws with no shield in hand (UAL 2's Heavy
##   A-B-C with its own ways back to guard, `Swordsman.STRINGS[1]`). The
##   heavy blow is off the block button;
## - every blow is played on to its clip's end, its own way back to guard, and
##   that way back slower than the cut ([member SkinnedRig.recover_pace]):
##   left alone a blow comes back slowly, the end of a string slower still. A
##   blow thrown into it cuts it short as before.

const STRINGS: Array = [
	{"name": "TWO HANDS  1-2-3-4", "clips": [&"KV_Attack2H01", &"KV_Attack2H02", &"KV_Attack2H03", &"KV_Attack2H04"],
		"recover": {}},
	{"name": "ONE HAND  1-2-3-4", "clips": [&"KV_Attack1H01_R", &"KV_Attack1H03_R", &"KV_Attack1H04_R",
			&"KV_Attack1H02_R"], "recover": {}},
]
## The ways he fights, F6 going from one to the next: [the attack button's
## string, the block button's] (indices into the sets: 0 two hands, 1 one
## hand, 2 Tariel's Heavy A-B-C), each with its name.
const MODES: Array = [
	{"name": "ONE HAND  /  TWO HANDS", "strings": [1, 0]},
	{"name": "TWO HANDS  /  TARIEL'S HEAVY A-B-C", "strings": [0, 2]},
]


## Seconds of the clip before its cut each blow is played from (the other
## strings' Moveset.LEAD 0.28): the blade gathered from further back.
const GATHER := 0.38


## Lays the design over `t`, a [method Moveset.build] table for two hands.
static func apply(t: Dictionary) -> void:
	# his own two, then Tariel's block-button string (as Tariel throws it
	# with no shield)
	var sets: Array = STRINGS.duplicate(true)
	var heavy: Dictionary = (Swordsman.STRINGS[1] as Dictionary).duplicate(true)
	heavy["name"] = "TARIEL  " + String(heavy["name"])
	sets.append(heavy)
	t["strings"] = [(sets[MODES[0]["strings"][0]]["clips"] as Array).duplicate()]
	t["recover"] = {}
	t["string_sets"] = sets
	t["modes"] = MODES
	# Tariel's blows flow one into the next: played as made, each to its end
	# ([member SkinnedRig.played_out])
	t["played_out"] = {}
	for c: StringName in heavy["clips"]:
		t["played_out"][c] = true
	t["swing_from"] = {}
	# the block button throws a string ([method SkinnedRig.block_throws_string])
	t["block_strings"] = true
	for i in sets.size():
		for c: StringName in sets[i]["clips"]:
			Swordsman._measure(t, c)
			var cuts: Array = Moveset.clip_meta(c).get("cuts", [])
			# Kevin's: gathered from further back than the other strings'
			# blows, played on to the clip's end, back to guard; Tariel's
			# whole, each ending where the next begins
			var from := 0.0
			if i < STRINGS.size() and not cuts.is_empty():
				var clip_len := float(Moveset.clip_meta(c).get("length", 1.0))
				from = maxf(float(cuts[0][0]) - GATHER / clip_len, 0.0)
			t["flurry_part"][c] = Vector2(from, 1.0)
			# where the swing sets off: the start of the measured arc that
			# runs into the cut ([member SkinnedRig.swing_from])
			if not cuts.is_empty():
				for tr: Array in Moveset.clip_meta(c).get("trails", []):
					if float(tr[0]) <= float(cuts[0][0]) and float(tr[1]) >= float(cuts[0][0]):
						t["swing_from"][c] = float(tr[0])
