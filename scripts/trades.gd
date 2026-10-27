class_name Trades
extends RefCounted

## The village grows with his runs (the user's word, 2026-10-21: what makes a
## player come back — every run leaves something): the orcs he kills in the
## portal leave him their tusks ("ორკის ეშვი", kept for good, even when he
## falls), and the prisoners he frees there take up a trade in the village:
## the first a smith, the second a healer, the third a priest. Each, for
## tusks, makes him stronger for good:
##
## * **smith** ("მჭედელი") — his blade sharpened: each level +8% to his blows.
## * **healer** ("მკურნალი") — one more flask each level.
## * **priest** ("მღვდელი") — a blessing at the portal's start; then four
##   lights to choose from instead of three.
##
## [Game] keeps the tusks and the levels; [VillageTrade] is the man at his
## stall; [World] puts what is bought on the heroes ([method apply]); the
## [Dungeon] counts the tusks ([method tusks_for]) and the priest's gifts.

const ORDER := ["smith", "healer", "priest"]
const ALL := {
	"smith": {"name": "მჭედელი", "costs": [150, 300, 550, 900, 1400], "tint": Color(1.0, 0.55, 0.2),
			"what": "მახვილი ლესავს: +8% დარტყმა", "per": 0.08},
	"healer": {"name": "მკურნალი", "costs": [250, 600, 1100], "tint": Color(0.45, 1.0, 0.55),
			"what": "კიდევ ერთი ფლაკონი"},
	# (no blessing at the portal's start any more, the user's word 2026-10-27)
	"priest": {"name": "მღვდელი", "costs": [600], "tint": Color(0.75, 0.8, 1.0),
			"what": ["ოთხი კურთხევა სამის ნაცვლად"]},
}
## What a creature of the portal leaves: the lord a heap, the named ones more.
const LORD_TUSKS := 20
const ROLE_TUSKS := 3


## Which trade the `k`th man freed takes up ("" the fourth on: he only lives there).
static func trade_of(k: int) -> String:
	return ORDER[k] if k >= 0 and k < ORDER.size() else ""


static func level(game: Node, trade: String) -> int:
	if game == null:
		return 0
	var levels: Variant = game.get(&"trade_levels")
	return int((levels as Dictionary).get(trade, 0)) if levels is Dictionary else 0


static func max_level(trade: String) -> int:
	return (ALL[trade]["costs"] as Array).size()


## What the next level costs (-1: none left).
static func cost(game: Node, trade: String) -> int:
	var lv := level(game, trade)
	var costs: Array = ALL[trade]["costs"]
	return int(costs[lv]) if lv < costs.size() else -1


## What the next level does, in words.
static func next_words(game: Node, trade: String) -> String:
	var what: Variant = ALL[trade]["what"]
	if what is Array:
		var lv := mini(level(game, trade), (what as Array).size() - 1)
		return String((what as Array)[lv])
	return String(what)


## Whether the trade is in the village yet (its man freed).
static func open(game: Node, trade: String) -> bool:
	if game == null:
		return false
	var freed: Variant = game.get(&"freed")
	return freed is Array and (freed as Array).size() > ORDER.find(trade)


## The tusks a creature of the portal leaves.
static func tusks_for(body: Node) -> int:
	if body.has_meta(&"gift"):
		return LORD_TUSKS
	if body.has_meta(&"treasure"):
		return TreasureGoblin.TUSKS
	if String(body.get_meta(&"role", "")) != "":
		return ROLE_TUSKS
	return 1


## What is bought put on `hero` (once, as he is made: [World]).
static func apply(hero: Player, game: Node) -> void:
	if hero == null or game == null or hero.has_meta(&"trades_on") or not hero.is_multiplayer_authority():
		return
	hero.set_meta(&"trades_on", true)
	var sharp := level(game, "smith")
	if sharp > 0:
		hero.dealt_scale *= 1.0 + float(ALL["smith"]["per"]) * float(sharp)
	var flasks := level(game, "healer")
	if flasks > 0:
		hero.flask_count += flasks
		hero.flasks_left = hero.flask_count
