class_name BowKinds
extends RefCounted

## Avtandil's bows, each its own worth (the user's word, 2026-10-05: all four
## in the bag, the bigger the bow the harder it hits and the slower it draws).
## A bow is the sword hand of his look ([PolysplitLook], "w"): his own, the
## hunter's, and the Advanced Weapons' short and long bows in the look's style.
## What one is worth is a share of his profile's: `atk` of P.ATK (every arrow
## of his, the skills' too), `draw` of the time to full draw. Read off the
## look on every peer, so a remote body draws as long as his own does; only
## the shooter's numbers count for damage, as ever.

const KINDS := {
	"own_bow": {"name": "Avtandil's Bow", "kind": "Recurve bow", "atk": 1.0, "draw": 1.0,
			"text": "His own, the one that bends with him. Drawn quick enough, and it hits as hard as any he has."},
	"bow": {"name": "Hunter's Bow", "kind": "Hunting bow", "atk": 0.93, "draw": 0.92,
			"text": "A plain hunter's bow, a little lighter in the hand and quicker to the ear."},
	"aw_bow": {"name": "Short Bow", "kind": "Short bow", "atk": 0.83, "draw": 0.8,
			"text": "Short and light. The string comes back fast and the shots go one after another, each worth less."},
	"aw_longbow": {"name": "Long Bow", "kind": "Longbow", "atk": 1.17, "draw": 1.15,
			"text": "As tall as he is. Slow to draw all the way, and the arrow lands for more than any other."},
}


## Which of [constant KINDS] an arm id is ("aw_longbow_ornate" -> "aw_longbow"),
## "" for anything that is not one of his bows.
static func key_of(id: String) -> String:
	var aw := PolysplitLook.aw_name(id)
	var key := ("aw_" + aw) if aw != "" else id
	return key if KINDS.has(key) else ""


## The bow `body` holds (its rig's look), "" when it holds none of these.
static func held(body: Node) -> String:
	if body == null:
		return ""
	var rig: Variant = body.get(&"rig")
	if not rig is Object or not is_instance_valid(rig):
		return ""
	var look: Variant = (rig as Object).get(&"ps_look")
	if not look is Dictionary:
		return ""
	return key_of(String((look as Dictionary).get("w", "")))


## The share of P.ATK the bow in `body`'s hands is worth (1 for anything else).
static func atk(body: Node) -> float:
	return float(KINDS.get(held(body), {}).get("atk", 1.0))


## The share of the draw time it takes (1 for anything else).
static func draw(body: Node) -> float:
	return float(KINDS.get(held(body), {}).get("draw", 1.0))
