class_name Defence
extends RefCounted

## Defence, for heroes and creatures alike, in two kinds:
##
## * **p.def** — physical: what armour, hide and toughness take off a blade,
##   claws, a fist, an arrow.
## * **m.def** — magical: what they take off the mage's bolts, fire, poison, the
##   wolf's claw wave (torn air) and Arkdeva's venom.
##
##     taken = damage × 100 / (100 + def)
##
## So a def of 0 takes a blow whole, 25 takes 80 % of it, 50 two thirds, 100
## half. Each point is worth less than the one before, and no amount of it makes
## anything untouchable.
##
## | who | HP | p.def | m.def |
## |---|---|---|---|
## | Tariel (the slowest to kill and to die) | 180 | 40 | 20 |
## | Avtandil | 120 | 15 | 15 |
## | the Assassin | 110 | 20 | 15 |
## | the Mage | 105 | 12 | 40 |
## | imp | 90 | 20 | 10 |
## | puglin | 150 | 25 | 10 |
## | wolf | 160 | 40 | 10 |
## | orc | 320 | 120 | 40 |
## | Arkdeva | 420 | 150 | 60 |
##
## What a hero hits with is p.atk (the profile's `damage`) or, for the mage,
## m.atk (`m_atk`); see [CharacterProfile] and README "Balance".

const SCALE := 100.0


static func taken(damage: float, p_def: float) -> float:
	return damage * SCALE / (SCALE + maxf(p_def, 0.0))


## The same, choosing the defence by the kind of blow.
static func against(damage: float, p_def: float, m_def: float, magic: bool) -> float:
	return taken(damage, m_def if magic else p_def)
