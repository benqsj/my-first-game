class_name Defence
extends RefCounted

## Physical defence — **p.def** — for heroes and creatures alike: what armour,
## hide and toughness take off a physical blow (a blade, claws, an arrow).
##
##     taken = damage × 100 / (100 + p.def)
##
## So p.def 0 takes a blow whole, 25 takes 80 % of it, 50 two thirds, 100 half.
## Each point is worth less than the one before, and no amount of it makes
## anything untouchable.
##
## | who | p.def | takes |
## |---|---|---|
## | Tariel (the most, and the most health: 160) | 35 | 74 % |
## | the Assassin | 20 | 83 % |
## | Avtandil | 15 | 87 % |
## | the Mage | 12 | 89 % |
## | imp, puglin | 20 | 83 % |
## | wolf (twice the imp's) | 40 | 71 % |
##
## Fire and poison (afflictions) are not physical and go through it.

const SCALE := 100.0


static func taken(damage: float, p_def: float) -> float:
	return damage * SCALE / (SCALE + maxf(p_def, 0.0))
