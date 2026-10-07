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
	STAFF, ## A spell: charged and cast like a draw, flying straight.
}

@export var display_name: String = ""
## The people the hero is of, which the hero select groups the roster by:
## &"human", &"elf" or &"dark" (the dark elves).
@export var people: StringName = &"human"
## One line for the character-select screen.
@export_multiline var blurb: String = ""
## The model and its rig, hung under the player as `Visuals`. Its root carries
## the rig script, so a character with a bow brings `ArcherRig` with it.
@export var visuals: PackedScene
@export var weapon: Weapon = Weapon.MELEE
## Whether there is a shield to put up. Without one the block button does
## nothing, which the character-select screen says out loud.
@export var can_block: bool = true
## Whether he can take hold of a wall and climb it. The hunter can; the knight,
## in plate and carrying a shield, runs into the wall and stays on the ground.
## Hauling himself over a waist-high ledge is not this — everybody can do that.
@export var can_climb: bool = true
## Whether a perfectly timed roll leaves his shadow behind him — the light-
## footed ones, the hunter and the assassin.
@export var shadow_dodge: bool = false
## The assassin's evades in a row: a step, then a twisting flip, then a step
## again (see `Player._press_dash`).
@export var step_then_flip: bool = false

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
## Where in the evade (0..1) the feet come back to the ground in its clip: the
## body brakes to a stop there and carries nothing on, so a flip lands where it
## lands instead of sliding on. 1.0 keeps the old glide to the end.
@export_range(0.0, 1.0) var dash_land_at: float = 1.0
@export_range(0.0, 1.0) var dodge_land_at: float = 1.0

@export_group("Weight")
## How the body carries its weight, over the controller's own (a negative
## value keeps the controller's). A heavy fighter gets going and comes to a
## stop slower, turns slower, is carried less far by his own swing and is
## shoved and held less by a blow.
@export var ground_acceleration: float = -1.0
@export var ground_deceleration: float = -1.0
@export var turn_speed: float = -1.0
@export var turn_speed_still: float = -1.0
@export var commit_speed_scale: float = -1.0
@export var blow_shove: float = -1.0
@export var blow_stagger: float = -1.0

@export_group("Vitals")
## How much punishment the body takes before it falls. The knight in his plate
## is the yardstick; the mage in his robe is the least of them.
@export var max_health: float = 120.0
## Physical defence, p.def: how much of a blow his armour takes ([Defence]).
@export var p_def: float = 0.0
## Magical defence, m.def: what he takes off fire, poison, spells and the wolf's
## claw wave ([Defence]).
@export var m_def: float = 0.0
## A shield-bearer's (Tariel's) shield, in what it is worth on his arm and what
## going without it gives him (the user's word, 2026-10-06): this much of his
## p.def is the shield's, gone with it; his cuts worth `bare_damage` times as
## much with both hands free on the attack button's string, and
## `bare_other_damage` times on the other string (the block button's).
@export var shield_p_def: float = 0.0
@export var bare_damage: float = 1.0
@export var bare_other_damage: float = 1.0
## Every roll, swing, shot and blow caught on the shield draws on this.
@export var max_stamina: float = 100.0
## What one attack costs: a swing, an arrow let go, a spell thrown.
@export var attack_stamina: float = 16.0
## What the tumbling roll costs. The longer dodge a double tap turns it into
## costs `dodge_stamina` on top.
@export var roll_stamina: float = 20.0
@export var dodge_stamina: float = 8.0

@export_group("Combat")
## How often a hit lands for `crit_damage` times its worth, 0 to 1.
@export_range(0.0, 1.0) var crit_chance: float = 0.1
@export var crit_damage: float = 2.0
## A cut from behind is a critical worth this many times its worth (the
## assassin's backstab, [RogueSkills]); 0 for none.
@export var backstab: float = 0.0
## p.atk: what a cut or an arrow is worth before any of that. For the bow this
## is the *full draw* figure; a snap shot is worth a fraction of it.
@export var damage: float = 26.0
## m.atk: what a spell is worth — the mage's bolt, before its charge. A staff
## shoots with this instead of `damage`, and it goes through m.def.
@export var m_atk: float = 0.0
## What a shot held to its full charge is worth on top of the draw's own
## scale. The mage's: a full charge is a bigger, blue bolt that hits harder.
@export var full_charge_bonus: float = 1.0
## The skills on the bar at the bottom of the screen, slot by slot (keys 1 to
## 4): ids from [constant Player.SKILLS]. An empty slot is shown empty.
@export var skills: PackedStringArray = PackedStringArray()
## Stamina a second that holding a draw or a charge costs. Run dry and the
## shot goes as it is.
@export var draw_stamina: float = 0.0

## How high a jump goes, in metres. 0 keeps the controller's own.
@export var jump_height: float = 0.0
## Seconds a held jump can hang in the air on the way down, sinking no faster
## than `levitate_fall`. 0 for anyone who cannot.
@export var levitation: float = 0.0
@export var levitate_fall: float = 1.2

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
## The least a shot is gathered before it can go: a click let go sooner goes
## on gathering to this and then goes (the mage's bolt, the user's word
## 2026-10-07: clicked as fast as a bow, the bolts killed everything). 0, a
## bow: it goes off the click.
@export var min_draw: float = 0.0
## What is loosed, if not the controller's arrow — the mage's bolt.
@export var projectile: PackedScene
## How much of the world's gravity pulls on it; below 0 keeps the arrow's.
@export var projectile_drop: float = -1.0


## What a shot is worth at a full draw: m.atk for a staff, p.atk otherwise.
func shot_power() -> float:
	return m_atk if weapon == Weapon.STAFF else damage


## A cut of the blade as it lands: [worth, critical]. Critical `crit_chance` of
## the time, for `crit_damage` times its worth.
func cut(rng: RandomNumberGenerator) -> Array:
	var critical := rng.randf() < crit_chance
	return [damage * (crit_damage if critical else 1.0), critical]
