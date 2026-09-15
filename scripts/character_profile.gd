class_name CharacterProfile
extends Resource

## One playable character: what they look like, what they carry, and how they
## differ from the others.
##
## The controller is shared — every character walks, jumps, dodges and climbs
## with the same code — so a character *is* this resource plus a model. Adding
## the fourth is writing a fourth `.tres`, not a fourth controller.
##
## Everything here that names a controller field overrides it on spawn. Leave a
## value at the scene's own default and the character simply keeps it.

enum Weapon {
	MELEE, ## Sword in hand, swung at whatever is in front of it.
	BOW, ## Drawn and loosed, and worth more the longer it is held.
}

@export var display_name: String = ""
## One line for the character-select screen.
@export_multiline var blurb: String = ""
## The model and its rig, hung under the player as `Visuals`. Its root carries
## the rig script, so a character with a bow brings `ArcherRig` with it.
@export var visuals: PackedScene
@export var weapon: Weapon = Weapon.MELEE
## Whether there is a shield to put up. Without one the block button does
## nothing, which the character-select screen says out loud.
@export var can_block: bool = true

@export_group("Movement")
## Overrides the controller's own. The knight is the yardstick at 9 m/s.
@export var run_speed: float = 7.2
@export var walk_speed: float = 3.6
## How far the tumbling roll carries. The archer trades armour for ground.
@export var dash_speed: float = 11.0
@export var dash_duration: float = 0.45
## And the longer, animated evade.
@export var dodge_speed: float = 8.5
@export var dodge_duration: float = 0.7

@export_group("Combat")
## How often a hit lands for `crit_damage` times its worth, 0 to 1.
@export_range(0.0, 1.0) var crit_chance: float = 0.1
@export var crit_damage: float = 2.0
## What a hit is worth before any of that. For the bow this is the *full draw*
## figure; a snap shot is worth a fraction of it.
@export var damage: float = 26.0

@export_group("Bow")
## How long the string takes to come all the way back. Anything loosed before
## that is worth proportionally less.
@export var draw_time: float = 0.85
## What a shot straight off the click is worth, as a share of a full draw. The
## floor under tapping: fast, but never free.
@export_range(0.0, 1.0) var snap_share: float = 0.25
## How fast the arrow leaves the bow at a full draw, in m/s.
@export var arrow_speed: float = 34.0
## And off a snap shot, which drops further and reaches less far.
@export var arrow_speed_snap: float = 21.0
## Shortest gap between loosing one arrow and drawing the next.
@export var shot_cooldown: float = 0.18
