class_name GreatSword
extends RefCounted
## The knight's great sword on the UE mannequin (YOUR OWN holding a great
## sword, a great axe or a pole: [Moveset] kind `two_hands`), laid over what
## [Moveset] builds out of the lab's picks (the user's word, 2026-10-06):
## - he fights on both buttons: the attack button throws the string F6 picked,
##   the other button (no shield to raise) the other string, as Tariel does
##   without a shield. The heavy blow is off that button for him;
## - the strings are Kevin's: both hands on the hilt (the lab's CUT 1-4) and
##   one hand, the blade swung from the right fist (the other hand let go of
##   the grip by `SkinnedRig.hilt_hand`, which leaves it where the clip
##   lets go);
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

## Seconds of the clip before its cut each blow is played from (the other
## strings' Moveset.LEAD 0.28): the blade gathered from further back.
const GATHER := 0.38


## Lays the design over `t`, a [method Moveset.build] table for two hands.
static func apply(t: Dictionary) -> void:
	t["strings"] = [(STRINGS[0]["clips"] as Array).duplicate()]
	t["recover"] = {}
	t["string_sets"] = STRINGS
	t["swing_from"] = {}
	# the block button throws the other string ([method SkinnedRig.block_throws_string])
	t["block_strings"] = true
	for s: Dictionary in STRINGS:
		for c: StringName in s["clips"]:
			Swordsman._measure(t, c)
			var cuts: Array = Moveset.clip_meta(c).get("cuts", [])
			var from := 0.0
			if not cuts.is_empty():
				# gathered from further back than the other strings' blows
				var clip_len := float(Moveset.clip_meta(c).get("length", 1.0))
				from = maxf(float(cuts[0][0]) - GATHER / clip_len, 0.0)
			# from a little before its cut to the clip's end: back to guard
			t["flurry_part"][c] = Vector2(from, 1.0)
			# where the swing sets off: the start of the measured arc that
			# runs into the cut ([member SkinnedRig.swing_from])
			if not cuts.is_empty():
				for tr: Array in Moveset.clip_meta(c).get("trails", []):
					if float(tr[0]) <= float(cuts[0][0]) and float(tr[1]) >= float(cuts[0][0]):
						t["swing_from"][c] = float(tr[0])
