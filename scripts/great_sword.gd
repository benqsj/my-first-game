class_name GreatSword
extends RefCounted
## The knight's great sword on the UE mannequin (YOUR OWN holding a great
## sword, a great axe or a pole: [Moveset] kind `two_hands`), laid over what
## [Moveset] builds out of the lab's picks (the user's word, 2026-10-06):
## - he fights on both buttons (the user's word, 2026-10-06, 16:05): the
##   block button (no shield to raise) always throws the two-handed string
##   (Kevin's 2H, the lab's CUT 1-4), the attack button the one F6 picks of
##   the others: one hand (Kevin's 1H, the blade swung from the right fist,
##   the other hand let go of the grip by `SkinnedRig.hilt_hand` wherever a
##   clip takes it off), or Tariel's two strings as he throws them with no
##   shield in hand (UAL 2's Regular and Heavy A-B-C, their own ways back to
##   guard, `Swordsman.STRINGS`). The heavy blow is off the block button;
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
## The string the block button throws (an index into the sets), and the ones
## F6 goes through for the attack button, the first worn until F6 is pressed.
const BLOCK_STRING := 0
const MAIN_STRINGS: Array[int] = [1, 2, 3]


## Seconds of the clip before its cut each blow is played from (the other
## strings' Moveset.LEAD 0.28): the blade gathered from further back.
const GATHER := 0.38


## Lays the design over `t`, a [method Moveset.build] table for two hands.
static func apply(t: Dictionary) -> void:
	# his own two, then Tariel's two (as Tariel throws them with no shield)
	var sets: Array = STRINGS.duplicate(true)
	for ts: Dictionary in Swordsman.STRINGS:
		var mine := ts.duplicate(true)
		mine["name"] = "TARIEL  " + String(ts["name"])
		sets.append(mine)
	t["strings"] = [(sets[MAIN_STRINGS[0]]["clips"] as Array).duplicate()]
	t["recover"] = {}
	t["string_sets"] = sets
	t["block_string"] = BLOCK_STRING
	t["main_strings"] = MAIN_STRINGS
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
