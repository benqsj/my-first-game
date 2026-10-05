class_name BossPhase
extends Resource

## One stage of a boss's fight ([Brute]: the orc warriors, Arkdeva, and every
## raid or instance boss after them). A boss holds its stages in
## [member Brute.phases]; when its health falls to a stage's `hp_threshold` it
## steps into it: it plays the stage's move, gets quicker and harder to hurt
## by the stage's multipliers, and starts throwing the stage's new attacks in
## among its own. A boss let go of (back home, whole again) starts over.
##
## Made as a `.tres` per stage, so five bosses are five sets of numbers rather
## than five copies of code:
##
##     [sub_resource type="Resource" script=ExtResource("boss_phase")]
##     hp_threshold = 0.5
##     phase_animation = &"STAMP"
##     speed_multiplier = 1.3
##     armour_multiplier = 1.25
##     new_attacks_array = [&"COMBO", &"SPIT_TWO"]

## The share of its max health (0..1) at or below which this stage begins.
@export_range(0.0, 1.0, 0.01) var hp_threshold: float = 0.5
## The move it opens the stage with: the name of one of the boss's own attacks
## (its `Act` enum: "ROAR" for an orc, "STAMP" for Arkdeva). Empty: none.
@export var phase_animation: StringName = &""
## Its walk, run and approach, times this.
@export_range(0.1, 4.0, 0.05) var speed_multiplier: float = 1.0
## Its p.def and m.def, times this ([Defence]).
@export_range(0.1, 4.0, 0.05) var armour_multiplier: float = 1.0
## Attacks (names from its `Act` enum) it now throws as well as its own: about
## half of its choices once it is in this stage come from these.
@export var new_attacks_array: Array[StringName] = []
