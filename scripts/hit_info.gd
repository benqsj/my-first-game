class_name HitInfo
extends RefCounted

## One blow, as it reaches whatever it struck: what [HurtboxComponent] hands
## its owner's `receive_hit(hit)`. Every weapon builds one of these — a blade
## through [method HurtboxComponent.scan], an arrow or a spell through
## [method HurtboxComponent.take_hit] — so a hit means the same thing whatever
## landed it.

## What it is worth before the struck one's p.def / m.def (a critical already in it).
var damage: float = 0.0
## Where on the body it landed.
var at: Vector3 = Vector3.ZERO
## The way it was going (a shove and the blood go along it).
var blow: Vector3 = Vector3.ZERO
var critical: bool = false
## Whether to spill blood for it here (false when a severed limb already bled).
var spill: bool = true
## Who dealt it; may be null (the archer gone while his arrow flew).
var from: Node = null
## A spell's (m.def) rather than a blade's or an arrow's (p.def).
var magic: bool = false
## A blade's cut through [method HurtboxComponent.scan] (not a shot or a spell).
var by_blade: bool = false
## The attacker's swing serial for a cut (-1 otherwise): one swing, one hit.
var serial: int = -1


static func make(worth: float, where: Vector3, along: Vector3, crit: bool = false,
		bleed: bool = true, source: Node = null, spell: bool = false) -> HitInfo:
	var hit := HitInfo.new()
	hit.damage = worth
	hit.at = where
	hit.blow = along
	hit.critical = crit
	hit.spill = bleed
	hit.from = source if is_instance_valid(source) else null
	hit.magic = spell
	return hit


## The one who dealt it as a body in the world, or null.
func attacker() -> Node3D:
	return from as Node3D if is_instance_valid(from) else null
