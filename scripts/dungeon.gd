class_name Dungeon
extends Node3D

## A dungeon behind one of the open world's gates ([Portals],
## portal_dungeons_plan.md): a run of places, one after another (the user's
## word: Archero's rooms and Hades' doors together, 2026-10-20). The hero stands
## in the first, a hall of the palace; its creatures come, and when the last of
## them is down two portals open at its far end, each with the place it leads
## to and the reward that waits there written over it — a cave, a forest, an
## island in the sky, a court or a broken hall of the palace. He walks into the
## one he wants: the screen goes dark a moment and he is there. The reward is
## his when that place is cleared. The last place is the lord's court on the
## palace's roof, at night; the lord down, the dungeon is closed: the hero is
## brought up to its top level and a way out stands where the lord was.
##
## Places are built when they are chosen (behind the dark), each far from the
## others; the one left behind is taken down. Its creatures are made with it,
## asleep where they stand, and wake a moment after he comes.
##
## Levels: the hero comes in at the dungeon's first level ([Leveling] is new in
## every level loaded) and the creatures carry him up as they fall; each place
## cleared tops him up to its `reach`, so he meets the lord at 7. Dying alone in
## here puts him back by the gate he came in by; in a band, the fallen get up
## when the place is cleared.

const WALL_T := 1.6
const DOOR_W := 6.0
const DOOR_H := 7.5
## Invisible height added to every wall, so nobody climbs out over it.
const BLOCK_H := 60.0
## How long after dying alone he is taken back out.
const BACK_OUT_AFTER := 3.0
## How often one of the two portals is a cursed one, and what the curse
## makes of its creatures.
const CURSE_CHANCE := 0.35
const CURSE_HEALTH := 1.5
const CURSE_HARDER := 1.3

## How far apart the places of one run are built (m, along −Z).
const STEP_GAP := 420.0
## Seconds the screen takes to go dark, and to come back.
const FADE := 0.45
## A frame quicker than this (ms) counts as settled ([method _settle]), and
## the most frames the dark is held for that.
const SETTLED_MS := 26.0
const SETTLE_MAX := 50
## Where [method _warm_up] puts the places up, out of the way of the run's.
const WARM_AT := Vector3(0.0, 0.0, 4000.0)
## Seconds after he arrives that a place's creatures wake.
const WAKE_AFTER := 1.2
## At most this many of a place's creatures are up at once (the user's word,
## 2026-10-20: so many together was too much); the rest come in waves through
## a rift that opens in the place once those are down.
const AT_ONCE := 6
## Seconds the rift stands open before the next wave comes out of it: a
## breath after the last of the first is down, it opens slowly (the user's
## word: not at once, and fine to see), then they come out one by one. Never
## more than two waves in a place.
const RIFT_DUE := 1.6
const RIFT_GROW := 2.2
const RIFT_TIME := RIFT_GROW + 0.5

const IMP := "res://scenes/enemies/imp.tscn"
const PUGLIN := "res://scenes/enemies/puglin.tscn"
const GOBLIN := "res://scenes/enemies/pack/goblin.tscn"
const ORC := "res://scenes/enemies/pack/orc.tscn"
const ORC_SKIRM := "res://scenes/enemies/pack/orc_skirmisher.tscn"
const OGRE := "res://scenes/enemies/pack/ogre.tscn"
const ORC_CHIEF := "res://scenes/enemies/pack/orc_chief.tscn"
const TROLL := "res://scenes/enemies/pack/troll.tscn"
## The boss halfway through ([constant RUN], the fifth step): Synty's pig
## butcher (the user's pick, 2026-10-22), fighting as an orc with a great axe
## ([PigButcher]).
const BUTCHER := "res://scenes/enemies/pack/pig_butcher.tscn"
## The flyers of the second half (the user's word, 2026-10-22: Quaternius'
## Ghost_Skull throwing souls, Dragon_Evolved throwing fire, a torch's size,
## several at once, no higher than a sword reaches) ([Flyer]).
const SKULL := "res://scenes/enemies/pack/ghost_skull.tscn"
const DRAGONET := "res://scenes/enemies/pack/dragonet.tscn"
## The minotaur, an elite of the second half (the user's word, 2026-10-22,
## monster_polish_plan.md: the new ones as elites at steps 6-9): its charge,
## its axe into the ground ([MinotaurFighter]).
const MINOTAUR := "res://scenes/enemies/minotaur.tscn"

## The orcs of the first dungeon (the user's word, 2026-10-20): before the last
## place two of different kinds, one with two swords, one with a long sword,
## neither with its whole run of combos; in the last, the lord of the orcs with
## his great sword.
## Here they are harder than out in the land (the user's word, 2026-10-20: a
## hero come up through the dungeon killed them far too easily): about twice
## the health, harder blows; the lord most of all.
const ORC_TWO_SWORDS := {"hand_combo_chance": Vector2(0.3, 0.55), "max_health": 720.0, "hit_damage": 72.0}
const SHAMAN := {"role": "shaman"}
const ELITE := {"role": "elite"}
const ORC_LONG_SWORD := {"arm_right": "longsword", "arm_left": "none", "hand_combo_chance": Vector2(0.15, 0.4),
		"max_health": 720.0, "hit_damage": 76.0}
const ORC_LORD := {"arm_right": "greatsword", "arm_style": "black", "outfit": "Lord", "cape": "Black cape",
		"intro_title": "ორკების მბრძანებელი", "phase_two_at": 0.4, "rage_redden": false,
		"combo_rest": Vector2(2.0, 3.0), "max_health": 1650.0, "hit_damage": 92.0}
## What the lord leaves him (the user's word, 2026-10-21: his sword, for good):
## his black blade, in the kind the hero's class holds — the great sword for
## a knight, a long sword for a swordsman, a curved one for a rogue, a staff, a
## bow ([method Inventory.special_arm]).
const LORD_GIFT := "aw_greatsword_obsidian,aw_longsword_obsidian,aw_curvedsword_obsidian,aw_staff_obsidian,aw_longbow_obsidian"
const LORD_GIFT_NAME := "The Orc Lord's"

## Where a portal can lead: what it is called, how it is built ("hall" under a
## roof, "court" open with windows, "terrace" open on one side over the drop,
## "throne" the lord's court on the roof, "cave", "forest", "sky" an island
## over the clouds), how big, how high its walls, how far up it stands.
const PLACES := {
	"hall": {"name": "სასახლის დარბაზი", "kind": "gold_hall", "w": 44.0, "l": 56.0, "h": 18.0},
	"court": {"name": "სასახლის ეზო", "kind": "court", "w": 52.0, "l": 64.0, "h": 11.0},
	"great_hall": {"name": "ჩანგრეული დარბაზი", "kind": "hall", "w": 50.0, "l": 70.0, "h": 24.0, "hole": true},
	# (the four terraces, low poly, [TerracePlaces]: the user's word,
	# 2026-10-24 — all four concepts, each its own place, in the stead of the
	# old terrace, rampart, storm path and lord's court)
	"terrace": {"name": "ტბის ტერასა", "kind": "lake", "w": 56.0, "l": 66.0, "h": 0.0},
	# two halls one after the other, a wave in each (the user's pick D + A,
	# 2026-10-25) [TwinCave]; the old "cave" kind's code kept
	"cave": {"name": "გამოქვაბული", "kind": "twin_cave", "w": 56.0, "l": 110.0, "h": 17.0},
	# (56 by 56: inside the shrine's ring of arches, [ForestGlade].RING_R)
	"forest": {"name": "ტყე", "kind": "forest", "w": 56.0, "l": 56.0, "h": 0.0},
	"sky": {"name": "ცის კუნძული", "kind": "sky", "w": 56.0, "l": 56.0, "h": 0.0, "lift": 160.0},
	# (the lord's court remade: a round arena on a cliff top in the mist, the
	# user's pick C of the concepts, 2026-10-25 [ThroneCourt]; 64 by 64 so
	# its round floor fits)
	"throne": {"name": "ტახტის ეზო", "kind": "lord_court", "w": 64.0, "l": 64.0, "h": 0.0, "lift": 160.0},
	# the orcs' war camp on a mountain fortress (the user's word, 2026-10-25:
	# look A of the lord's court, liked, a place of its own [ThroneCourt])
	"camp": {"name": "ორკების ბანაკი", "kind": "war_camp", "w": 64.0, "l": 64.0, "h": 0.0, "lift": 160.0},
	# (the flooded crypt and the stone king's tomb behind it, low poly
	# [CryptTomb]: the user's pick, 2026-10-24)
	"crypt": {"name": "აკლდამა", "kind": "flood_crypt", "w": 44.0, "l": 100.0, "h": 15.0},
	"swamp": {"name": "ჭაობი", "kind": "swamp", "w": 58.0, "l": 62.0, "h": 0.0},
	"mountain": {"name": "ჩანჩქერის ნანგრევები", "kind": "falls", "w": 46.0, "l": 64.0, "h": 0.0, "lift": 60.0},
	"rampart": {"name": "ციხის ტერასა", "kind": "fort", "w": 50.0, "l": 60.0, "h": 0.0},
	# the places to get one's breath back ([RestSpot]): no creatures, "rest" on the portal
	# (the spring in a glade of an autumn maple wood, low poly: the user's
	# concept "tye3", 2026-10-26 [HolySpring]; the old cloister's builder,
	# kind "spring", kept)
	"spring": {"name": "წმინდა წყარო", "kind": "holy_spring", "w": 52.0, "l": 52.0, "h": 0.0, "rest": "სიცოცხლე ბოლომდე"},
	"prison": {"name": "ტყვეების ოთახი", "kind": "cell_cave", "w": 34.0, "l": 50.0, "h": 11.0, "rest": "მცველები · გაათავისუფლე ტყვე",
			"guards": true},
	# and the quiet place of the portal's own (the user's word, 2026-10-22;
	# the merchant taken out, 2026-10-26) ([PortalEvent])
	# (the ring of standing stones in a pine wood at dusk, low poly: the
	# user's pick "B" of the concepts, 2026-10-26 [AltarCircle])
	"altar": {"name": "სამსხვერპლო", "kind": "altar", "w": 52.0, "l": 60.0, "h": 0.0, "rest": "შესწირე და მიიღე"},
}

## The creatures that live in the places (the user's word, 2026-10-27: each
## place its own folk): the dead in the crypt, the risen dead in the swamp,
## the ghouls in the cave, wolves with the goblins in the wood, a golem in the
## waterfall's ruins, orcs and an ogre on the fortress, flyers in the sky,
## orcs and a troll in their camp.
const SKEL_WARRIOR := "res://scenes/enemies/pack/skeleton_warrior.tscn"
const SKEL_ARCHER := "res://scenes/enemies/pack/skeleton_archer.tscn"
const SKEL_MAGE := "res://scenes/enemies/pack/skeleton_mage.tscn"
const ZOMBIE_M := "res://scenes/enemies/pack/zombie_m.tscn"
const ZOMBIE_F := "res://scenes/enemies/pack/zombie_f.tscn"
const GHOUL := "res://scenes/enemies/pack/ghoul.tscn"
const GOLEM := "res://scenes/enemies/pack/golem.tscn"
const WOLF := "res://scenes/enemies/wolf.tscn"
## A great one that comes with the second wave, last, at its own strength
## (not an elite's three times) ([method mixed]).
const LATE := {"late": true}

## Per dungeon, its run: each step the places its portals may lead to, the
## creatures in each ("*" any of them) as [scene, count, props], the level
## they show ("lv"), what clearing it gives on top of them ("xp", wolves'
## worth) and the level it tops him up to ("reach").
## The first dungeon (the user's word, 2026-10-25, claude/portal_sequence_plan.md):
## up from under the earth to over the clouds; the lake terrace to begin, the
## dark places (crypt, swamp, cave), the sunny middle (wood, waterfall ruins,
## fortress), over the clouds (sky island, orcs' camp); the butcher at the
## fifth, the lord at the tenth. No place twice in a run ([method _choice_specs]).
const RUN := {
	0: [
		# (2026-10-27, the user's word: more of them, a bigger second wave, the
		# kinds mixed in little by little; slower levels; the ogre a boss
		# near the end)
		# 1 — the lake terrace, quiet and bright: imps and puglins, a few goblins
		{"places": ["terrace"], "lv": 1, "xp": 0.8, "reach": 1, "foes": {"*": [[IMP, 5], [PUGLIN, 4], [GOBLIN, 2]]}},
		# 2 — the crypt's skeletons with the imps, or the swamp's dead with the puglins
		# (the crypt's fewer that shoot, 2026-10-28, the user's word: nearly all
		# of them shooting at once was too much)
		{"places": ["crypt", "swamp"], "lv": 2, "xp": 1.0, "reach": 2,
				"foes": {"crypt": [[SKEL_WARRIOR, 5], [IMP, 3], [SKEL_ARCHER, 2], [SKULL, 1]],
						"swamp": [[ZOMBIE_M, 2], [ZOMBIE_F, 2], [PUGLIN, 4], [IMP, 3]]}},
		# 3 — the ghouls' cave, or the two again, each with something of the other
		{"places": ["cave", "swamp", "crypt"], "lv": 3, "xp": 1.2, "reach": 2,
				"foes": {"cave": [[GHOUL, 9], [ZOMBIE_M, 2], [GHOUL, 1, ELITE]],
						"swamp": [[ZOMBIE_M, 2], [ZOMBIE_F, 2], [PUGLIN, 4], [SKEL_WARRIOR, 2], [IMP, 2], [PUGLIN, 1, ELITE]],
						"crypt": [[SKEL_WARRIOR, 5], [SKEL_ARCHER, 2], [SKEL_MAGE, 1], [SKULL, 2], [ZOMBIE_F, 2], [SKEL_WARRIOR, 1, ELITE]]}},
		# 4 — the wood's goblins and wolves, or the ruins' golem
		{"places": ["forest", "mountain"], "lv": 4, "xp": 1.5, "reach": 3,
				"foes": {"forest": [[GOBLIN, 4], [GOBLIN, 1, SHAMAN], [WOLF, 4], [IMP, 3]],
						"mountain": [[IMP, 4], [GOBLIN, 3], [SKEL_ARCHER, 2], [SKULL, 2], [GOLEM, 1, LATE]]}},
		# 5 — the first boss, alone in the palace's hall
		{"places": ["hall"], "lv": 5, "xp": 2.0, "reach": 4, "boss": true, "boss_name": "ყასაბი",
				"foes": {"*": [[BUTCHER, 1]]}},
		# 6 — the second half
		{"places": ["forest", "rampart", "cave"], "lv": 6, "xp": 1.5, "reach": 5,
				"foes": {"forest": [[WOLF, 5], [GOBLIN, 3], [GOBLIN, 1, SHAMAN], [PUGLIN, 3], [GOBLIN, 1, ELITE]],
						"rampart": [[ORC_SKIRM, 1], [GOBLIN, 3], [SKEL_ARCHER, 3], [SKEL_WARRIOR, 3], [IMP, 2], [GOBLIN, 1, ELITE]],
						"cave": [[GHOUL, 9], [ZOMBIE_M, 2], [ZOMBIE_F, 2], [GHOUL, 1, ELITE]]}},
		# 7 — the ruins' golem and the minotaur, or the fortress
		{"places": ["mountain", "rampart"], "lv": 7, "xp": 1.8, "reach": 5,
				"foes": {"mountain": [[GOLEM, 1], [IMP, 4], [DRAGONET, 2], [SKEL_WARRIOR, 3], [MINOTAUR, 1, LATE]],
						"rampart": [[ORC, 1, ORC_LONG_SWORD], [SKEL_ARCHER, 3], [GOBLIN, 3], [SKULL, 2], [WOLF, 2]]}},
		# 8 — the sky's flyers, or the fortress with the troll last
		{"places": ["sky", "rampart"], "lv": 7, "xp": 1.8, "reach": 6,
				"foes": {"sky": [[DRAGONET, 3], [SKULL, 3], [IMP, 4], [GOBLIN, 2]],
						"rampart": [[ORC, 1, ORC_TWO_SWORDS], [ORC_SKIRM, 1], [SKEL_ARCHER, 3], [GOBLIN, 3], [TROLL, 1, LATE]]}},
		# 9 — the lord of the orcs on his court
		{"places": ["throne"], "lv": 8, "xp": 2.0, "reach": 7, "boss": true, "boss_name": "ორკების მბრძანებელი",
				"foes": {"*": [[ORC_CHIEF, 1, ORC_LORD]]}},
		# 10 — the ogre, the last of all, alone on the camp's ground (the
		# user's word, 2026-10-27: the last boss is the ogre)
		{"places": ["camp"], "lv": 9, "boss": true, "boss_name": "ოგრე",
				"foes": {"*": [[OGRE, 1]]}},
	],
}
## Places a step may borrow when all of its own were already seen in this
## run: the fighting places by their height (the dark, the middle, high).
const ZONES := [["crypt", "swamp", "cave"], ["forest", "mountain", "rampart", "terrace"], ["sky"]]
## The prisoners' jailers (the user's word, 2026-10-25: kill them, and the key
## they leave opens the cell): goblins and puglins with an elite among them
## early on, an orc and the skulls with them later.
const JAILERS_EARLY := [[GOBLIN, 3], [PUGLIN, 2], [GOBLIN, 1, ELITE]]
const JAILERS_LATE := [[GOBLIN, 2], [SKULL, 2], [ORC_SKIRM, 1], [PUGLIN, 1, ELITE]]
## The steps a place to rest (the spring, the prisoners) may be offered
## before, beside the step's own place (1-based, the rests not counted); and
## before every boss, the spring always.
const REST_BEFORE := [3, 6, 8]
## Spike traps in the floor ([SpikeTrap]): from this step on, in this share of
## the places.
const TRAPS_FROM := 3
const TRAP_CHANCE := 0.6
## Places where "survive" is never the goal.
const NO_SURVIVE := ["crypt", "cave"]
## Places where the totems never stand (in the cave they stood in its walls).
const NO_TOTEMS := ["cave"]
## The room's gift of gold (gold is dear: a creature leaves one coin).
const GOLD_GIFT := 4
## Each place, to look round it from F1 ([method view_place]): the step whose
## light (day into night) it is seen in, and what it is called on the board.
const VIEW := {
	"hall": [0, "Hall"], "forest": [2, "Forest"],
	"crypt": [2, "Crypt"], "swamp": [2, "Swamp"], "sky": [5, "Sky island"],
	"mountain": [5, "Waterfall ruins"], "spring": [5, "Holy spring"], "prison": [5, "Prisoners' room"],
	"altar": [5, "Altar"],
	"terrace": [7, "Lake terrace"], "rampart": [7, "Fortress terrace"], "throne": [9, "Lord's court"],
	"camp": [7, "Orc camp"], "cave": [3, "Cave (two halls)"],
}

## The boss of each dungeon: the scene in its last place that has to fall.
const BOSS := {0: ORC_CHIEF}
## What waits behind a portal (the user's word): its name and the portal's colour.
const REWARDS := {
	"boon": {"name": "კურთხევა", "tint": Color(1.0, 0.86, 0.45)},
	"life": {"name": "სიცოცხლე", "tint": Color(0.95, 0.22, 0.28)},
	"gold": {"name": "ოქრო", "tint": Color(1.0, 0.76, 0.2)},
	"blade": {"name": "ხმლის ძალა", "tint": Color(0.45, 0.75, 1.0)},
	"skill": {"name": "სკილების სისწრაფე", "tint": Color(0.72, 0.38, 1.0)},
}
## How many may set on each hero at once, an orc near him counting as one
## (the user's word: at most two; the rest throw from off).
const CROWD := 2
## With this many shooting from off (flyers, skeleton archers and mages),
## only `CROWD_UNDER_FIRE` at each hero up close.
const SHOOTERS_MANY := 2
const CROWD_UNDER_FIRE := 1
const SHOOTERS := ["res://scenes/enemies/pack/skeleton_archer.tscn", "res://scenes/enemies/pack/skeleton_mage.tscn"]
## Seconds between any two things thrown at one hero (the user's word: so
## many waiting made a hail of it; then, 2 s still too few to get out of the
## way of all of them: a rest from all throwing after each; 2026-10-27, more
## of them throwing, the archers in the turn too: 3.2).
const THROW_GAP := 3.2
## Held back, they wait round him on these rings, spread out evenly.
const HOLD_RINGS := [8.5, 11.5]
## The ones shooting from off stand round him on these, each its own bearing.
const SHOOT_RINGS := [13.0, 16.0]
## (who has a turn at him, the one he walks up to, now and then one more:
## [CombatDirector])

const SND := "res://assets/sounds/dungeon/"
## The land's own photographed ground and rock, brought in through the portal
## (the user's word, 2026-10-23: inside, the colours and textures of the world
## he left): the village square's cobbles and the land's rock, grass, earth and
## leaves.
const PHOTO := {
	"cob": "res://assets/village/ground/cobble_diff.jpg",
	"cob_nor": "res://assets/village/ground/cobble_nor.jpg",
	"rock": "res://assets/terrain_real/aerial_rocks_02_diff.jpg",
	"rock_nor": "res://assets/terrain_real/aerial_rocks_02_nor_gl.jpg",
	"grass": "res://assets/terrain_real/grass004/Grass004_1K-JPG_Color.jpg",
	"grass_nor": "res://assets/terrain_real/grass004/Grass004_1K-JPG_NormalGL.jpg",
	"earth": "res://assets/terrain_real/forest_ground_04_diff.jpg",
	"earth_nor": "res://assets/terrain_real/forest_ground_04_nor_gl.jpg",
	"leaves": "res://assets/terrain_real/forest_leaves_02_diff.jpg",
	"mud": "res://assets/terrain_real/brown_mud_02_diff.jpg",
	"mud_nor": "res://assets/terrain_real/brown_mud_02_nor_gl.jpg",
}
## A picture of each place, seen inside the portal that leads to it.
const PREVIEWS := "res://assets/dungeon/previews/%s.png"

## Which dungeon this is (from [member Game.dungeon_id]; 0 when there is none).
@export var id: int = 0

signal room_cleared(index: int)
signal closed

## The run's steps (from `RUN`).
var steps: Array = []
## The places he has been to, one per step so far: {place, kind, w, l, h,
## foes, lv, xp, reach, reward}.
var rooms: Array = []
## Each place's middle, on its floor.
var centres: Array[Vector3] = []
## The place the heroes are in.
var current: int = -1
var cleared: Array[bool] = []
var is_closed: bool = false
## The portals open now, each with its meta "place" and "reward".
var choices: Array[PortalLook] = []
## Rewards given so far, by name.
var rewards_given: Array[String] = []
## What was given at the altar this run, by any hero ([PortalEvent]).
var deals_made: Array[String] = []
## The run's blessings ([Boons]).
var boons: Boons
## What the place he is in asks of him besides killing them all ([RoomGoal]),
## or null.
var _goal: RoomGoal
## The next place's first creature is its captain ([RoomGoal] "captain").
var _captain_next: bool = false
var _goal_nag: float = 0.0
var _woken: bool = false
## The creatures still to come (each place's, made with it, hidden till their
## wave), which wave this is of how many, and the rift they come out of.
var _reserve: Array[Node3D] = []
var wave: int = 0
var waves: int = 1
var _rift: PortalLook = null
var _rift_out: bool = false
var _rift_at: float = -1.0
var _rift_due: float = -1.0
var _wake_at: float = -1.0
var _going: bool = false
var _room_nodes: Array[Node3D] = []
var _alive: Array[Node3D] = []
var _spawned: int = 0
## The flooded crypt's stone king ([CryptTomb]): made with its creatures,
## hidden under the floor, risen from his throne when they are all down; and
## whether he has risen.
var _king: Node3D = null
var _king_up: bool = false
## The run's creatures, read in once ([method _load_foes]).
var _scenes: Dictionary = {}
## Per step, the creatures made for it at the start ([method _premake]), in the
## order its list has them.
var _premade: Dictionary = {}
## The portals out of the place he is in, made as he came, hidden till it is
## cleared ([method _prepare_offer]); and the rift its next wave will come by.
var _ready_choices: Array[PortalLook] = []
var _rift_ready: PortalLook = null
var _exit_ready: PortalLook = null
var _sounds: Array[Resource] = []
## Materials held so their shaders stay made ([method _keep_materials]).
var _kept: Dictionary = {}
## A usual frame here lately (ms), for [method _settle] to measure by.
var _usual_ms: float = 16.0
var _floor_shader: Shader
var _ground_shader: Shader
var _rock_mat: ShaderMaterial
var _cave_mat: ShaderMaterial
var _glass_shader: Shader
var _beam_shader: Shader
## Every column standing: {room, at, h, thick, parts (meshes), blocker, broken}.
var _columns: Array[Dictionary] = []
var _crowd_clock: float = 0.0
## The small ones let at the heroes just now ([method _hold_back_crowd]).
var _holders: Array[Node3D] = []
## How hard the fight presses him, who has a turn at him ([CombatDirector]).
var director: CombatDirector
## Each place's creatures, made with it: asleep where they stand till it wakes.
var _room_foes: Array = []
## The pair of orcs taking turns at a lone hero: whose turn, since when, and
## each one's health at the last look (a blow on the other one hands it over).
var _orc_on: Node3D = null
var _orc_since: float = 0.0
var _orc_hand_over: float = 16.0
var _orc_health: Dictionary = {}
## The light of the day, place by place (0 afternoon .. 4 night), and its tween.
var _phase: float = 0.0
var _phase_tween: Tween
var _sky_mat: ShaderMaterial
var _lord_fight: LordFight
## This run: when its first place woke, what fell, the tusks won, whether it
## is over ([RunSummary]).
var _run_start: float = -1.0
var run_kills: int = 0
## His gold as the run began ([Game]), for what the run brought.
var run_gold_start: int = 0
var _run_over: bool = false
## A room looked round from F1, not a run.
var _viewing: bool = false
## The portal he went through was a cursed one ([method _curse]).
var _curse_next: bool = false
var _curse_mat: ShaderMaterial
var _treasure: TreasureGoblin
var _lore_put: bool = false
## The host's throws for the place being gone into ([method take]).
var _arrival_plan: Dictionary = {}
## What the portals being made ready lead to ([method _prepare_offer]).
var _ready_specs: Array = []
var _asked_at: float = -10.0
var _sun: DirectionalLight3D
var _sun_yaw: float = 0.0
var _env: Environment
var _scars: int = 0
var _wall_mat: ShaderMaterial
var _trim_mat: StandardMaterial3D
var _iron_mat: StandardMaterial3D
var _cloth_mat: StandardMaterial3D
var _gold_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D
## The fires' look, shared by all of them ([method _flame]).
var _fire_mat: ShaderMaterial
var _coals_mat: ShaderMaterial
var _fire_quads: Dictionary = {}
var _ember_draw: QuadMesh
var _ember_pms: Dictionary = {}
## The fires' lights, flickering: {light, base, at}.
var _fire_lights: Array[Dictionary] = []
## The kit's trees with their leaves taken off, by the mesh they came from.
var _bare_meshes: Dictionary = {}
var _back_out_at: float = -1.0
var _watched: Dictionary = {}
var _layer: CanvasLayer
var _banner: Label
var _banner_until: float = 0.0
var _fade: ColorRect
var _exit: PortalLook = null
var _rng := RandomNumberGenerator.new()
## The sounds: the bus with the place's echo, the place's own (looped), and
## the clocks of the ones that come now and then.
var _bus: int = -1
var _amb: Array[AudioStreamPlayer] = []
var _drip_in: float = 4.0
var _thunder_in: float = 20.0
var _owl_in: float = 12.0
var _models: Dictionary = {}
## The graveyard kit's meshes and materials ([method _necro]), bone.
var _necro_meshes: Dictionary = {}
var _necro_mat: ShaderMaterial
var _necro_glow: StandardMaterial3D
var _bone_mat: StandardMaterial3D
var _banner_mat: ShaderMaterial
## The clocks of the stones from a hall's roof and the lightning.
var _stones_in: float = 10.0
var _storm_in: float = 6.0
## Where the place's hanging braziers creak from, and the clocks of the other
## sounds that come now and then (bats, the eagle, a banner in the wind).
var _creaks: Array[Vector3] = []
var _creak_in: float = 8.0
var _bats_in: float = 9.0
var _eagle_in: float = 10.0
var _flap_in: float = 7.0
## Birds circling the island in the sky: {node, centre, radius, height, speed, at}.
var _birds: Array[Dictionary] = []
## The sea of cloud under the island in the sky, lit with the day.
var _cloud_sea: ShaderMaterial
var _cloud_layer_mats: Array[ShaderMaterial] = []

const FLOOR_SHADER := """
shader_type spatial;
// Brute stone, built (the user's word, 2026-10-20: not a chessboard; round
// stones to make it): big rough-cut slabs in courses, chipped at the edges,
// dark joints full of grit; along the walls, down an aisle and where a slab
// is gone, cobbles - small round stones, each its own dome and shade. The
// relief is a height field; its slope bends the normal.
uniform vec4 slab_a : source_color = vec4(0.46, 0.42, 0.38, 1.0);
uniform vec4 slab_b : source_color = vec4(0.30, 0.28, 0.27, 1.0);
uniform vec4 cobble_a : source_color = vec4(0.50, 0.46, 0.40, 1.0);
uniform vec4 cobble_b : source_color = vec4(0.28, 0.26, 0.25, 1.0);
uniform vec4 grit : source_color = vec4(0.07, 0.06, 0.055, 1.0);
uniform float slab = 2.2;
uniform float course = 1.5;
uniform float pebble = 0.26;
uniform vec2 centre = vec2(0.0);
uniform vec2 half_size = vec2(20.0);
uniform float border = 2.4;
uniform float aisle = 0.0;
uniform float wear = 0.5;
uniform float wet = 0.0;
uniform float relief = 0.05;
// A cave's floor: round stones all over, no slabs.
uniform float rocky = 0.0;
// Snow lying in the hollows (the mountain).
uniform float snow = 0.0;
// The outside world's own stone (the user's word, 2026-10-23: inside the
// portal the colours and textures of the land he left): the village square's
// photographed cobbles where cobbles lie, and the land's photographed rock
// worked into each slab's face. 0 leaves the drawn stone alone.
uniform float photo = 0.0;
// Cobbles all over, as the village's streets (the user's word, 2026-10-23):
// no slabs at all.
uniform float all_cob = 0.0;
// How much moss and dirt lies in the low places (the prisoners' room: none).
uniform float moss_amt = 1.0;
uniform sampler2D cob_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cob_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cob_tile = 4.0;
uniform float stone_tile = 3.6;
// The square's cobbles are laid with this tint over them in the village.
uniform vec4 cob_tint : source_color = vec4(0.74, 0.70, 0.64, 1.0);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
// Nearest and second-nearest feature distance, and the nearest one's id.
vec3 voronoi(vec2 x) {
	vec2 n = floor(x); vec2 f = fract(x);
	float m1 = 8.0; float m2 = 8.0; float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.15 + 0.7 * vec2(hash(n + g), hash(n + g + 17.3));
			float d = length(g + o - f);
			if (d < m1) { m2 = m1; m1 = d; id = hash(n + g + 5.1); } else if (d < m2) { m2 = d; }
		}
	}
	return vec3(m1, m2, id);
}
float jit(float k, float row) { return (hash(vec2(k, row)) - 0.5) * 0.7; }
// Slabs in courses, each course its own run of lengths: distance to the slab's
// edge (m) and its id.
vec2 slabs(vec2 p) {
	float row = floor(p.y / course);
	float y0 = row * course;
	float xs = p.x / slab + hash(vec2(row, 3.1)) * 7.0;
	float k = floor(xs);
	float b0 = k + jit(k, row);
	float b1 = k + 1.0 + jit(k + 1.0, row);
	if (xs < b0) { b1 = b0; k -= 1.0; b0 = k + jit(k, row); }
	else if (xs > b1) { k += 1.0; b0 = b1; b1 = k + 1.0 + jit(k + 1.0, row); }
	float ex = min(xs - b0, b1 - xs) * slab;
	float ey = min(p.y - y0, y0 + course - p.y);
	return vec2(min(ex, ey), hash(vec2(k, row) + 0.37));
}
// x: height 0..1, y: kind (0 slab, 1 cobble, 2 joint), z: id, w: slab gone.
vec4 ground(vec2 p) {
	vec2 lp = p - centre;
	vec2 dw = half_size - abs(lp);
	float to_wall = min(dw.x, dw.y);
	vec2 s = slabs(p);
	float gone = step(hash(vec2(s.y, 9.7)), (0.05 + 0.08 * wear) * (1.0 - photo * 0.6));
	bool cob = rocky > 0.5 || all_cob > 0.5 || to_wall < border || abs(lp.x) < aisle || gone > 0.5;
	if (cob) {
		vec3 v = voronoi(p / pebble);
		float r = (v.y - v.x) / (v.x + v.y + 0.0001);
		float h = sin(clamp(r * 2.4, 0.0, 1.0) * 1.5708) * (0.75 + 0.25 * v.z);
		return vec4(h * 0.8 - gone * 0.2, 1.0, v.z, gone);
	}
	float e = s.x + (noise(p * 2.3) - 0.5) * 0.16 * (0.5 + wear) + (noise(p * 7.0) - 0.5) * 0.05;
	if (e < 0.03) {
		vec3 g = voronoi(p / 0.07);
		return vec4(0.12 * smoothstep(0.0, 0.5, (g.y - g.x) / (g.x + g.y + 0.0001)), 2.0, g.z, 0.0);
	}
	float top = smoothstep(0.03, 0.16, e);
	float pits = noise(p * 3.1 + s.y * 9.0) * 0.6 + noise(p * 11.0) * 0.4;
	float tilt = (hash(vec2(s.y, 1.3)) - 0.5) * 0.25;
	return vec4(top * (0.82 + 0.12 * pits + tilt * 0.4), 0.0, s.y, 0.0);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec2 lp = p - centre;
	vec2 dw = half_size - abs(lp);
	float to_wall = min(dw.x, dw.y);
	vec4 g = ground(p);
	float h = g.x;
	float far = smoothstep(18.0, 55.0, length(VERTEX));
	float e = 0.025;
	float hx = ground(p + vec2(e, 0.0)).x - h;
	float hz = ground(p + vec2(0.0, e)).x - h;
	float k = relief * (1.0 - far * 0.8) / e;
	// the square's cobbles bring their own relief
	bool photo_cob = photo > 0.5 && g.y > 0.5 && g.y < 1.5 && rocky < 0.5;
	if (photo_cob) { k = 0.0; }
	vec3 nw = normalize(vec3(-hx * k, 1.0, -hz * k));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 c;
	float rough;
	vec2 suv = p / stone_tile + vec2(g.z * 7.3, g.z * 3.1);
	vec3 st = texture(stone_tex, suv).rgb;
	// the rock's grain, not its colour: its light and dark over the slab's own
	float grain = mix(1.0, clamp(lum(st) / 0.11, 0.65, 1.35), photo * 0.7);
	vec3 nmap = vec3(0.5, 0.5, 1.0);
	float mottle = noise(p * 0.6 + g.z * 13.0) * 0.6 + noise(p * 5.0) * 0.25 + noise(p * 19.0) * 0.15;
	if (g.y < 0.5) {
		c = mix(slab_a.rgb, slab_b.rgb, g.z) * mix(0.72 + 0.45 * mottle, 0.85 + 0.2 * mottle, photo) * grain;
		nmap = mix(nmap, texture(stone_nor, suv).rgb, photo * 0.7);
		// Worn: the high middle of a slab paler, its edge darker.
		c *= 0.6 + 0.45 * h;
		rough = 0.88 - 0.25 * h * (1.0 - wet);
		// Cracks running across in patches.
		float patch = smoothstep(1.0 - wear, 1.0 - wear + 0.2, noise(p * 0.05 + 3.0));
		vec3 v = voronoi(p * 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.04, v.y - v.x)) * patch;
		c = mix(c, grit.rgb, crack * mix(0.85, 0.25, photo));
	} else if (g.y < 1.5) {
		if (photo_cob) {
			// the village square's cobbles, the room's own cast over them
			vec2 cuv = p / cob_tile;
			vec3 ct = texture(cob_tex, cuv).rgb;
			// broad light and dark over it, so its tiles do not show
			ct *= 0.86 + 0.28 * (noise(p * 0.07 + 3.3) * 0.7 + noise(p * 0.21) * 0.3);
			vec3 tone = mix(cobble_a.rgb, cobble_b.rgb, 0.45) / vec3(0.134, 0.113, 0.089);
			c = ct * cob_tint.rgb * clamp(tone, vec3(0.5), vec3(1.6));
			nmap = texture(cob_nor, cuv).rgb;
			h = clamp(lum(ct) * 2.2, 0.0, 1.0);
			rough = 0.85 - 0.2 * h;
		} else {
			c = mix(cobble_a.rgb, cobble_b.rgb, g.z) * (0.8 + 0.35 * mottle) * grain;
			c *= 0.28 + 0.8 * clamp(h, 0.0, 1.0);
			c = mix(c, grit.rgb, g.w * 0.35);
			rough = 0.8 - 0.3 * h;
			nmap = mix(nmap, texture(stone_nor, suv).rgb, photo * 0.6);
		}
	} else {
		c = grit.rgb * (0.8 + 2.5 * h) + vec3(0.02, 0.03, 0.0) * noise(p * 4.0);
		rough = 1.0;
	}
	// Moss and dirt in the low places near the walls.
	float low = 1.0 - smoothstep(0.1, 0.5, h);
	float moss = low * smoothstep(5.0, 0.5, to_wall) * smoothstep(0.45, 0.7, noise(p * 0.8 + 5.0));
	c = mix(c, vec3(0.16, 0.19, 0.09), moss * mix(0.6, 0.15, photo) * moss_amt);
	float drift = smoothstep(0.62, 0.8, noise(p * 0.12 + 21.0) + noise(p * 0.9) * 0.2) * snow;
	c = mix(c, vec3(0.86, 0.88, 0.93), drift * (1.0 - h * 0.6) * 0.8);
	c *= mix(0.62, 1.0, smoothstep(0.0, 3.0, to_wall));
	// Rain standing in the hollows of the open rooms.
	float pool = smoothstep(0.6, 0.68, noise(p * 0.07 + 11.0)) * wet * (0.5 + 0.5 * low);
	c *= 1.0 - pool * 0.4;
	rough = mix(rough, 0.18, pool);
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.35 + pool * 0.1;
	NORMAL_MAP = nmap;
}
"""

const GROUND_SHADER := """
shader_type spatial;
// The forest's floor: grass in clumps and swathes, bare earth between, moss
// and fallen leaves, a trodden path down the middle (the swamp's: darker).
uniform vec4 grass_a : source_color = vec4(0.20, 0.32, 0.10, 1.0);
uniform vec4 grass_b : source_color = vec4(0.32, 0.42, 0.14, 1.0);
uniform vec4 earth : source_color = vec4(0.26, 0.19, 0.12, 1.0);
uniform vec4 moss : source_color = vec4(0.13, 0.22, 0.08, 1.0);
uniform vec4 leaves : source_color = vec4(0.42, 0.24, 0.10, 1.0);
uniform float path_amount = 0.8;
uniform float bare_from = 0.55;
// The land's own photographed ground (the user's word, 2026-10-23): its
// grass, earth and fallen leaves, each as light or dark as the place's colour
// asks. 0 leaves the drawn ground alone.
uniform float photo = 0.0;
uniform sampler2D t_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_grass : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_earth : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_earth : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D t_leaves : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Wet mud in patches here and there (the user's word, 2026-10-23).
uniform sampler2D t_mud : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D n_mud : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float mud = 0.0;
varying vec3 wpos;
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float tone(vec3 want, float ref) { return clamp(lum(want) / ref, 0.5, 1.3); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float big = fbm(p * 0.05);
	float mid = fbm(p * 0.3 + 4.0);
	float fine = noise(p * 6.0) * 0.5 + noise(p * 17.0) * 0.5;
	vec3 g_col = mix(grass_a.rgb, grass_b.rgb, mid) * (0.8 + 0.35 * fine);
	vec3 e_col = earth.rgb * (0.8 + 0.4 * fine);
	vec3 l_col = leaves.rgb * (0.7 + 0.5 * fine);
	vec2 guv = p / 2.5;
	vec2 euv = p / 3.0;
	if (photo > 0.5) {
		g_col = texture(t_grass, guv).rgb * tone(mix(grass_a.rgb, grass_b.rgb, mid), 0.09);
		e_col = texture(t_earth, euv).rgb * tone(earth.rgb, 0.035);
		l_col = texture(t_leaves, euv * 1.2).rgb * tone(leaves.rgb, 0.06);
	}
	vec3 c = g_col;
	float bare = smoothstep(bare_from, bare_from + 0.15, big + (mid - 0.5) * 0.4);
	c = mix(c, e_col, bare);
	c = mix(c, moss.rgb * mix(1.0, lum(g_col) / 0.14, photo), smoothstep(0.62, 0.8, fbm(p * 0.12 + 9.0)) * 0.6);
	c = mix(c, l_col, smoothstep(0.7, 0.85, fbm(p * 0.4 + 2.0)) * 0.7);
	// the path the creatures have trodden, down the middle
	float path = smoothstep(2.6, 1.2, abs(p.x - sin(p.y * 0.05) * 3.0) + (mid - 0.5) * 2.0);
	c = mix(c, e_col * 0.9, path * path_amount);
	// the mud: its own soft-edged patches, darker, wet, shining a little
	float mp = smoothstep(0.58, 0.68, fbm(p * 0.06 + 17.0) + (fine - 0.5) * 0.08) * mud * photo;
	vec2 muv = p / 3.2;
	c = mix(c, texture(t_mud, muv).rgb * 0.5, mp);
	float wet_edge = smoothstep(0.5, 0.58, fbm(p * 0.06 + 17.0)) * mud * photo * (1.0 - mp);
	c *= 1.0 - wet_edge * 0.25;
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.7, mp);
	if (photo > 0.5) {
		NORMAL_MAP = mix(mix(texture(n_grass, guv).rgb, texture(n_earth, euv).rgb, max(bare, path * path_amount)),
				texture(n_mud, muv).rgb, mp);
	} else {
		// blades of grass: the normal ruffled where it grows
		vec3 nw = normalize(vec3((noise(p * 9.0) - 0.5) * 0.5 * (1.0 - bare), 1.0, (noise(p * 9.0 + 3.1) - 0.5) * 0.5 * (1.0 - bare)));
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
}
"""

const WALL_SHADER := """
shader_type spatial;
uniform vec4 stone : source_color = vec4(0.52, 0.47, 0.40, 1.0);
uniform vec4 grout : source_color = vec4(0.08, 0.07, 0.09, 1.0);
// The land's photographed rock in each block's face (the user's word,
// 2026-10-23), its grain over the block's own colour. 0: the drawn stone.
uniform float photo = 0.0;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// moss low down (0: none) and how much each block differs from the next
// (the prisoners' room, Ashen's look: smooth, even stone)
uniform float moss_amt = 1.0;
uniform float mottle = 1.0;
varying vec3 wpos;
varying vec3 wnorm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	// Ashlar courses: 0.7 m tall, 1.4 m long, every other course half a block over.
	float u = abs(wnorm.x) > abs(wnorm.z) ? wpos.z : wpos.x;
	if (abs(wnorm.y) > 0.5) { u = wpos.x + wpos.z * 0.37; }
	vec2 p = vec2(u / 1.4, wpos.y / 0.7);
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float n = hash(cell);
	vec3 c = stone.rgb * mix(1.0, 0.7 + 0.45 * n, mottle);
	vec2 tuv = vec2(u, wpos.y) / 2.4 + vec2(n * 5.3, n * 2.9);
	vec3 st = texture(stone_tex, tuv).rgb;
	c *= mix(1.0, clamp(dot(st, vec3(0.2126, 0.7152, 0.0722)) / 0.11, 0.6, 1.45), photo * 0.75);
	// a block's edges chipped back, a little darker
	float edge = min(min(f.x, 1.0 - f.x) * 1.4, min(f.y, 1.0 - f.y) * 0.7);
	c *= mix(1.0, 0.8 + 0.2 * smoothstep(0.0, 0.08, edge), photo);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(stone_nor, tuv).rgb, photo * 0.8);
	float joint = step(f.x, 0.02) + step(0.98, f.x) + step(f.y, 0.04) + step(0.96, f.y);
	c = mix(c, grout.rgb, clamp(joint, 0.0, 1.0));
	// Darker towards the floor, as old stone is, and a little moss low down.
	c *= 0.72 + 0.28 * smoothstep(0.0, 4.0, wpos.y);
	c = mix(c, vec3(0.13, 0.17, 0.10), 0.25 * (1.0 - photo * 0.7) * smoothstep(1.2, 0.0, wpos.y) * step(0.6, n) * moss_amt);
	// Water stains running down from the joints, here and there.
	float col = floor(u / 0.9);
	float stain = step(0.82, hash(vec2(col, 3.0))) * smoothstep(0.0, 0.5, fract(u / 0.9))
			* smoothstep(1.0, 0.5, fract(u / 0.9));
	c *= 1.0 - 0.35 * stain * smoothstep(0.0, 6.0, wpos.y);
	// Moss low on the walls, in soft patches, dark.
	vec2 mq = vec2(u, wpos.y) * 0.9;
	float mn = fract(sin(dot(floor(mq), vec2(12.9, 78.2))) * 43758.5);
	vec2 mf = fract(mq);
	vec2 mu = mf * mf * (3.0 - 2.0 * mf);
	float m00 = hash(floor(mq)); float m10 = hash(floor(mq) + vec2(1.0, 0.0));
	float m01 = hash(floor(mq) + vec2(0.0, 1.0)); float m11 = hash(floor(mq) + vec2(1.0, 1.0));
	float mv = mix(mix(m00, m10, mu.x), mix(m01, m11, mu.x), mu.y);
	float moss = smoothstep(0.58, 0.8, mv) * smoothstep(3.2, 0.2, wpos.y) * step(0.0, wpos.y) * step(abs(wnorm.y), 0.5);
	c = mix(c, vec3(0.09, 0.13, 0.06) * (0.8 + 0.4 * mn), moss * mix(0.75, 0.22, photo) * moss_amt);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

## Stained glass high in a hall's walls: lead lines, panes of violet, crimson,
## gold and blue, lit from outside.
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	// A pointed head.
	vec2 q = vec2((uv.x - 0.5) * 2.0, (0.32 - uv.y) / 0.32);
	if (uv.y < 0.32) {
		float a = length(q - vec2(-1.0, 0.0));
		float b = length(q - vec2(1.0, 0.0));
		if (a > 2.0 || b > 2.0) { discard; }
	}
	vec2 g = uv * vec2(4.0, 9.0);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float n = hash(cell);
	vec3 pane = n < 0.3 ? vec3(0.45, 0.12, 0.7) : (n < 0.55 ? vec3(0.7, 0.08, 0.12) : (n < 0.8 ? vec3(0.85, 0.6, 0.15) : vec3(0.15, 0.25, 0.75)));
	float lead = step(f.x, 0.06) + step(0.94, f.x) + step(f.y, 0.08) + step(0.92, f.y);
	vec3 c = mix(pane * (0.8 + 0.5 * hash(cell + 3.0)), vec3(0.02), clamp(lead, 0.0, 1.0));
	ALBEDO = c * 1.6;
}
"""

## A shaft of light: soft at its sides, fading towards its foot.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.75, 0.6, 1.0, 1.0);
uniform float strength = 0.18;
void fragment() {
	float side = pow(abs(dot(NORMAL, VIEW)), 2.0);
	float along = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float flicker = 0.85 + 0.15 * sin(TIME * 0.7 + UV.y * 6.0);
	ALBEDO = tint.rgb * strength * side * along * flicker;
}
"""

## The sea of cloud far below the terrace and the boss's court.
const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 top : source_color = vec4(0.42, 0.33, 0.52, 1.0);
uniform vec4 low : source_color = vec4(0.10, 0.07, 0.16, 1.0);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.012 + vec2(TIME * 0.006, TIME * 0.003);
	float c = fbm(p) * 0.7 + fbm(p * 3.1 - vec2(TIME * 0.01, 0.0)) * 0.3;
	ALBEDO = mix(low.rgb, top.rgb, smoothstep(0.3, 0.8, c));
}
"""


func _ready() -> void:
	# Every lamp put up in here keeps the shadow it was made with when the
	# graphics setting is put on ([Graphics]).
	get_tree().node_added.connect(_on_node_added)
	add_to_group(&"dungeon")
	var game := get_node_or_null("/root/Game")
	if game != null and int(game.get(&"dungeon_id")) >= 0:
		id = int(game.get(&"dungeon_id"))
	if not RUN.has(id):
		id = 0
	# its own copy: a place to rest put in between is a step of this run only
	steps = (RUN[id] as Array).duplicate(true)
	cleared.resize(steps.size())
	cleared.fill(false)
	_rng.randomize()
	if game != null and game.has_signal(&"graphics_changed"):
		game.connect(&"graphics_changed", func(_level: Graphics.Level) -> void: _apply_phase(_phase))
	# Every creature of the run read in now, behind the loading screen: the
	# first puglin used to be read in as he stepped through (0.3 s).
	_load_foes()
	_load_sounds()
	_materials()
	_sky()
	_sound_bus()
	_vista()
	_build_hud()
	boons = Boons.new(self)
	add_child(boons)
	boons.show_list(_layer)
	# (no tusks any more, the user's word, 2026-10-27: all with gold)
	if game != null and "gold" in game:
		run_gold_start = int(game.get(&"gold"))
	if game != null and Trades.level(game, "priest") >= 1:
		boons.lights = 4
	# The first place: the first step's own.
	_arrive_at(0, String(steps[0]["places"][0]), "", true)
	_apply_phase(_phase)
	_place_marks()
	# Where the orcs' heavy blows crack the floor ([OrcFighter]).
	add_to_group(&"ground_scars")
	_say("%s" % String(Portals.DEFS[id]["name"]), 3.5)
	Fighter.throw_gap = THROW_GAP
	director = CombatDirector.new()
	director.name = "CombatDirector"
	add_child(director)
	director.setup(self)
	# The run's orcs and its lord made now, behind the loading screen, and
	# everything the run will show drawn once there ([method _warm_up]).
	_premake.call_deferred()
	_warm_up.call_deferred()
	# brought in late, at the party's door ([method Net.bring_waiting])
	var join: Dictionary = game.get(&"join_at") if game != null else {}
	if not join.is_empty():
		game.set(&"join_at", {})
		_join_party.call_deferred(join)
	# (the priest's blessing before the first place no more: the user's word,
	# 2026-10-27, not wanted at the start)
	if game != null and String(game.get(&"view_place")) != "":
		var asked := String(game.get(&"view_place"))
		game.set(&"view_place", "")
		_view_after_warm_up.call_deferred(asked)


## A creature of a cursed place: hardier, harder, a dark red light in it.
func _curse(body: Node3D) -> void:
	FoeRoles._scale_stat(body, &"max_health", CURSE_HEALTH)
	FoeRoles._scale_stat(body, &"hit_damage", CURSE_HARDER)
	if "health" in body and "max_health" in body:
		body.set(&"health", body.get(&"max_health"))
	body.set_meta(&"cursed", true)
	if body.has_meta(&"rim"):
		return
	if _curse_mat == null:
		var sh := Shader.new()
		sh.code = FoeRoles.RIM_SHADER
		_curse_mat = ShaderMaterial.new()
		_curse_mat.shader = sh
		_curse_mat.set_shader_parameter(&"tint", Color(0.75, 0.02, 0.06))
		_curse_mat.set_shader_parameter(&"amount", 0.7)
	FoeRoles._overlay(body, _curse_mat)


#region Together (the user's word, 2026-10-21: the portals in co-op)
## The host runs the place — wakes it, clears it, opens its rift, picks what
## its portals lead to and its blessings — and tells the others, whose games
## do the same on their side ([method net_wake], [method net_clear],
## [method net_take], [method net_rift], [method net_wave], [method net_lay],
## [method net_boon]). The creatures are the host's, made with the same names
## everywhere so their bodies are sent across. Each game puts rewards and
## blessings on its own hero only ([method mine]).
func _net() -> Node:
	return get_node_or_null("/root/Net")


func online() -> bool:
	var n := _net()
	return n != null and bool(n.call("is_online"))


## Whether this game runs the place (the host, or alone).
func decides() -> bool:
	var n := _net()
	return n == null or bool(n.call("is_host"))


## Whether `hero` is this game's own.
func mine(hero: Node) -> bool:
	return not online() or hero.is_multiplayer_authority()


func _slot_of(hero: Node, fallback: int) -> int:
	var n := _net()
	if n == null or not online():
		return fallback
	return int(n.call("slot_of", hero.get_multiplayer_authority()))


## A client's part: its own hero walking into a portal or the way out asks
## the host.
func _as_client(heroes: Array[Player]) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _asked_at < 0.6:
		return
	for hero in heroes:
		if not mine(hero) or hero.is_dead:
			continue
		for k in choices.size():
			var gap := hero.global_position - choices[k].global_position
			if Vector2(gap.x, gap.z).length() < 1.8 and absf(gap.y) < 3.0:
				_asked_at = now
				ask_take.rpc_id(1, k)
				return
		if _exit != null:
			var out := hero.global_position - _exit.global_position
			out.y = 0.0
			if out.length() < 2.2:
				_asked_at = now
				leave()
				return


@rpc("authority", "call_remote", "reliable")
func net_wake(i: int) -> void:
	if i == current and not _woken:
		_wake(i)


@rpc("authority", "call_remote", "reliable")
func net_rift() -> void:
	if _rift_at < 0.0:
		_open_rift()


@rpc("authority", "call_remote", "reliable")
func net_wave() -> void:
	if not _rift_out:
		_next_wave()


## Host: blessings' lights laid at `at` — the same ones in every game.
func lay_lights(at: Vector3) -> void:
	var ids := boons.offer(boons.lights)
	boons.lay(at, self, ids)
	if online():
		net_lay.rpc(at, ids)


@rpc("authority", "call_remote", "reliable")
func net_lay(at: Vector3, ids: Array) -> void:
	var list: Array[StringName] = []
	for one: Variant in ids:
		list.append(StringName(one))
	boons.lay(at, self, list)


@rpc("authority", "call_remote", "reliable")
func net_boon(id: StringName, where: Vector3) -> void:
	boons.take(id, where)
#endregion


## Seconds since the run's first place woke.
func run_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0 - _run_start if _run_start >= 0.0 else 0.0


## The run over, won or lost: its summary up, once ([RunSummary]). Null if it
## was over already, or this was no run (a room looked round from F1).
func end_run(won: bool) -> RunSummary:
	if _run_over or _run_start < 0.0 or _viewing:
		return null
	_run_over = true
	return RunSummary.make(self, won)


## The village priest's gift ([Trades]): a blessing to choose before the
## first place's creatures, once the loading is done.
func _priest_gift() -> void:
	while get_tree().root.find_child("PipelineWarmup", true, false) != null:
		await get_tree().process_frame
	for k in 20:
		await get_tree().process_frame
	if current != 0 or boons == null or not decides():
		return
	lay_lights(centre(0) + Vector3(0.0, 0.0, float(_room(0)["l"]) * 0.5 - 14.0))
	_say("მღვდლის კურთხევა — აირჩიე", 3.5)


#region The fallen
## A creature of the portal watched: the blessings' doings on it, and its
## death counted.
func _watch_foe(body: Node3D) -> void:
	boons.watch(body)
	if body.has_signal(&"died") and not body.has_meta(&"tusks_watched"):
		body.set_meta(&"tusks_watched", true)
		body.connect(&"died", _on_tusks.bind(body))


func _on_tusks(body: Node3D) -> void:
	if not is_instance_valid(body):
		return
	run_kills += 1

#endregion


## The place asked for from the open world's F1, once the loading is done.
## Come in late, behind the others: the place they are going into built in
## the first one's stead, its creatures the same ones (named for the place).
func _join_party(join: Dictionary) -> void:
	_take_down(current)
	_lore_put = bool(join.get("lore_put", _lore_put))
	_curse_next = bool(join.get("cursed", false))
	_arrival_plan = join.get("plan", {}) as Dictionary
	_arrive_at(int(join["step"]), String(join["place"]), String(join["reward"]), false, String(join.get("goal", "")))
	_arrival_plan = {}
	_to_phase(light_of(current), 0.05)
	for hero in _heroes():
		if mine(hero):
			hero.global_position = entry_point(_slot_of(hero, 0), current)
			hero.velocity = Vector3.ZERO


func _view_after_warm_up(place: String) -> void:
	while get_tree().root.find_child("PipelineWarmup", true, false) != null:
		await get_tree().process_frame
	for k in 5:
		await get_tree().process_frame
	view_place(place)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	Fighter.throw_gap = 0.0
	Sfx.bus = &"Master"
	if _bus >= 0 and _bus < AudioServer.bus_count and AudioServer.get_bus_name(_bus) == &"Dungeon":
		AudioServer.remove_bus(_bus)


func _room(i: int) -> Dictionary:
	return rooms[clampi(i, 0, rooms.size() - 1)]


## Whether step `i` is a place to rest put in between ([method _rest_between]):
## not one of the run's steps as the heroes count them.
func is_rest(i: int) -> bool:
	return bool((steps[clampi(i, 0, steps.size() - 1)] as Dictionary).get("rest", false))


## Which of the run's steps `i` is, counted from 1, the rests left out (a rest
## is the step it comes before).
func stage_of(i: int) -> int:
	var n := 0
	for k in mini(i + 1, steps.size()):
		if not is_rest(k):
			n += 1
	return maxi(n + (1 if is_rest(i) else 0), 1)


## How many steps the run has, the rests left out (10).
func stage_count() -> int:
	var n := 0
	for k in steps.size():
		if not is_rest(k):
			n += 1
	return n


## Whether step `i` is a boss's.
func is_boss(i: int) -> bool:
	return bool((steps[clampi(i, 0, steps.size() - 1)] as Dictionary).get("boss", false))


## The light of step `i` (day into night, [constant PHASES]): its share of
## the whole run, whatever its length.
func light_of(i: int) -> float:
	var of := maxi(stage_count() - 1, 1)
	return float(stage_of(i) - 1) * float(PHASES.size() - 1) / float(of)


## A place to rest put in at step `at`, the step that was there next after it
## (the user's word, 2026-10-22: the spring and the prisoners are not steps).
## Every peer does it as it goes through ([method _go_through]).
func _rest_between(at: int, place: String) -> void:
	var before: Dictionary = steps[at]
	var foes := {}
	if (PLACES[place] as Dictionary).has("guards"):
		foes = {"*": JAILERS_EARLY if int(before.get("lv", 1)) < 5 else JAILERS_LATE}
	steps.insert(at, {"places": [place], "lv": before.get("lv", 1), "foes": foes, "rest": true})
	cleared.insert(at, false)
	# what was made ahead for the steps after it moves on with them
	var moved := {}
	for k: int in _premade:
		moved[k + 1 if k >= at else k] = _premade[k]
	_premade = moved


## Where step `i`'s place is built: one after another along −Z, far apart,
## the island in the sky high up.
func origin(i: int, place: String) -> Vector3:
	return Vector3(0.0, float(PLACES[place].get("lift", 0.0)), -STEP_GAP * float(i))


## The middle of place `i`, on its floor.
func centre(i: int) -> Vector3:
	return centres[clampi(i, 0, centres.size() - 1)]


## Where the heroes stand as they come into place `i`: its near end.
func entry_point(slot: int, i: int = 0) -> Vector3:
	var l: float = _room(i)["l"]
	return centre(i) + Vector3(-1.5 + float(slot % 4) * 1.0, 0.3, l * 0.5 - 6.0 + floorf(float(slot) / 4.0))


## The place a point stands in (-1 outside them all).
func room_at(p: Vector3) -> int:
	for i in rooms.size():
		var c := centre(i)
		var r := _room(i)
		if r.is_empty():
			continue
		if absf(p.z - c.z) <= float(r["l"]) * 0.5 + 0.5 and absf(p.x - c.x) <= float(r["w"]) * 0.5 + 0.5 \
				and absf(p.y - c.y) < 40.0:
			return i
	return -1


func _place_marks() -> void:
	var root: Node = owner if owner != null else get_parent()
	var marks := root.get_node_or_null("SpawnPoints")
	if marks == null:
		return
	for i in marks.get_child_count():
		(marks.get_child(i) as Node3D).position = entry_point(i, maxi(current, 0))


## Step `i`, at `place`: built, its creatures made (asleep), the light of the
## day moved on, and `reward` waiting for it to be cleared.
func _arrive_at(i: int, place: String, reward: String, later: bool = false, goal: String = "") -> void:
	var p: Dictionary = PLACES[place]
	var step: Dictionary = steps[i]
	var foes_by: Dictionary = step["foes"]
	var foes: Array = foes_by.get(place, foes_by.get("*", []))
	# holding out, they keep coming: twice as many wait
	if goal == "survive":
		# (three times: more made at once would stall his coming in)
		foes = foes + foes + foes
	# (the prisoners' place keeps its jailers)
	if p.has("rest") and not p.has("guards"):
		foes = []
	var r := {"place": place, "kind": p["kind"], "w": p["w"], "l": p["l"], "h": p["h"],
			"name": p["name"], "foes": foes, "lv": step.get("lv", 1), "xp": step.get("xp", 0.0),
			"reach": step.get("reach", 0), "reward": reward, "goal": goal, "cursed": _curse_next}
	_curse_next = false
	if p.has("hole"):
		r["hole"] = true
	if p.has("rest"):
		r["xp"] = 0.0
	while rooms.size() <= i:
		rooms.append({})
		centres.append(Vector3.ZERO)
	rooms[i] = r
	centres[i] = origin(i, place)
	current = i
	_woken = false
	_creaks.clear()
	_birds.clear()
	_alive.clear()
	_holders.clear()
	_orc_on = null
	_build_room(i)
	if is_instance_valid(_goal):
		_goal.queue_free()
	_goal = null
	_captain_next = goal == "captain"
	if later:
		_spawn_room.call_deferred(i)
	else:
		_spawn_room(i)
		if goal != "":
			_goal = RoomGoal.make(self, i, goal)
	_ambience(i)
	# the marks a body is spawned on, at this place's door (somebody brought
	# in late, [method Net.bring_waiting])
	if not later:
		_place_marks()
	_drip_in = _rng.randf_range(2.0, 5.0)
	if _map != null:
		_map.queue_redraw()
	# wet through in the storm, dry elsewhere
	for hero in _heroes():
		PlaceBuild.wet(hero, String(p["kind"]) == "mountain")
	_prepare_offer(i + 1)


## A place's creatures one by one, their kinds taken in turn (the user's
## word, 2026-10-21: never a wave of goblins only, then of imps only — mixed,
## an imp, a goblin…); the elite, which comes with the second wave, last.
static func mixed(foes: Array) -> Array:
	# Each kind's lot, sorted into its part in the fight (the user's word,
	# 2026-10-27, [CombatDirector]'s plan: a wave as a band, not a heap):
	# those that close in, those that come round the side, those that shoot,
	# those that help the rest.
	var parts := {"front": [], "flank": [], "ranged": [], "support": []}
	var last: Array = []
	for entry: Array in foes:
		var one := entry.duplicate()
		one[1] = 1
		var role := String((entry[2] as Dictionary).get("role", "")) if entry.size() > 2 else ""
		var many: Array = []
		for n in int(entry[1]):
			many.append(one)
		var late := entry.size() > 2 and bool((entry[2] as Dictionary).get("late", false))
		if role == "elite" or late:
			last.append_array(many)
		else:
			(parts[_part_of(String(entry[0]), role)] as Array).append(many)
	# within a part the kinds taken in turn
	var queues := {}
	for part: String in parts:
		var q: Array = []
		var left := true
		while left:
			left = false
			for many: Array in parts[part]:
				if not many.is_empty():
					q.append(many.pop_front())
					left = true
		queues[part] = q
	# a band in every few: two that close in, one round the side, one that
	# shoots, and so on; a part run out, the next there is
	var out: Array = []
	var k := 0
	while true:
		var want: String = BAND[k % BAND.size()]
		k += 1
		var q: Array = queues[want]
		if q.is_empty():
			for other: String in ["front", "flank", "ranged", "support"]:
				if not (queues[other] as Array).is_empty():
					q = queues[other]
					break
		if q.is_empty():
			break
		out.append(q.pop_front())
	out.append_array(last)
	return out


## The order a wave is laid in, by part ([method mixed]).
const BAND := ["front", "front", "flank", "ranged", "front", "flank", "ranged", "support"]
const RANGED_KINDS := ["skeleton_archer", "skeleton_mage", "ghost_skull", "dragonet"]
const FLANK_KINDS := ["wolf", "puglin", "imp"]


static func _part_of(scene: String, role: String) -> String:
	if role == "shaman":
		return "support"
	var file := scene.get_file().get_basename()
	if RANGED_KINDS.has(file):
		return "ranged"
	if FLANK_KINDS.has(file):
		return "flank"
	return "front"


## Place `i`'s creatures, standing in its far half, asleep (they see no one:
## their leash is nothing).
func _spawn_room(i: int) -> void:
	var level_root: Node = owner if owner != null else get_parent()
	var creatures := level_root.get_node_or_null("Enemies")
	while _room_foes.size() <= i:
		_room_foes.append([])
	var mine: Array[Node3D] = []
	_room_foes[i] = mine
	_reserve.clear()
	wave = 1
	waves = 1
	if creatures == null:
		return
	var c := centre(i)
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var k := 0
	# the ones made at the start for this step, if any ([method _premake])
	var made: Array = _premade.get(i, [])
	_premade.erase(i)
	for entry: Array in mixed(r["foes"]):
		var scene := _foe_scene(String(entry[0]))
		if scene == null:
			continue
		for n in int(entry[1]):
			var across := (float(k % 4) - 1.5) * (w - 14.0) / 3.0
			var row := floorf(float(k) / 4.0)
			var at := c + Vector3(across + sin(float(k) * 2.3) * 1.2, 0.3, -l * 0.08 - row * 3.0)
			if String(entry[0]) == BOSS.get(id, "") or is_boss(i):
				at = c + Vector3(0.0, 0.3, -l * 0.2)
			elif String(r["kind"]) == "twin_cave":
				# the first wave in the den, the gate on still shut
				at = c + Vector3(across * 0.6 + sin(float(k) * 2.3) * 1.0, 0.3, TwinCave.WAVE_ONE_Z - row * 3.0)
			if not made.is_empty() and is_instance_valid(made[0]) \
					and String((made[0] as Node).get_meta(&"scene", "")) == String(entry[0]):
				var ready_made := made.pop_front() as Node3D
				_take_up(ready_made, at, c, int(r["lv"]))
				if k >= AT_ONCE:
					# a later wave's, as below
					ready_made.position = c + Vector3(float(k) * 1.5, -40.0, 0.0)
					ready_made.visible = false
					ready_made.process_mode = Node.PROCESS_MODE_DISABLED
					_reserve.append(ready_made)
				mine.append(ready_made)
				_watch_foe(ready_made)
				k += 1
				continue
			var body := scene.instantiate() as Node3D
			body.name = "D%d_R%d_%d" % [id, i, k]
			body.position = at
			body.rotation.y = 0.0
			var role := ""
			if entry.size() > 2:
				var props: Dictionary = entry[2]
				for key: String in props:
					body.set(StringName(key), props[key])
				role = String(props.get("role", ""))
			if role == "" and _captain_next:
				_captain_next = false
				role = "captain"
			if role != "":
				FoeRoles.before(body, role)
			body.set("band", StringName("dungeon_%d_room_%d" % [id, i]))
			body.set("camp_centre", Vector3(c.x, c.y, c.z))
			if "leash_radius" in body:
				body.set("leash_radius", 0.01)
			body.set_meta(&"level", int(r["lv"]))
			if String(entry[0]) == BOSS.get(id, ""):
				body.set_meta(&"gift", LORD_GIFT)
				body.set_meta(&"gift_name", LORD_GIFT_NAME)
			if is_boss(i):
				# its anger kept: it turns on whoever hurts it most ([Threat])
				body.set_meta(&"boss", true)
			if body.has_signal(&"hurt"):
				body.connect(&"hurt", _on_foe_hurt.bind(body))
			if k >= AT_ONCE:
				# a later wave's: out of sight under the floor, not thinking
				body.position = c + Vector3(float(k) * 1.5, -40.0, 0.0)
				body.visible = false
				body.process_mode = Node.PROCESS_MODE_DISABLED
				_reserve.append(body)
			creatures.add_child(body)
			mine.append(body)
			_watch_foe(body)
			if role != "":
				FoeRoles.after(body, role, self)
			k += 1
	# any made at the start and not wanted after all
	for spare: Variant in made:
		if is_instance_valid(spare):
			(spare as Node).queue_free()
	waves = 2 if not _reserve.is_empty() else 1
	_king = null
	_king_up = false
	if String(r["kind"]) == "flood_crypt":
		_make_king(i, creatures, c)
	if bool(r.get("cursed", false)):
		for body in mine:
			_curse(body)
	# a piece of the palace's story, once a run, in the second or third place
	if not _lore_put and not _viewing and (i == 2 or (i == 1 and bool(_arrival_plan.get("lore", _rng.randf() < 0.5)))) \
			and i < _room_nodes.size() and is_instance_valid(_room_nodes[i]):
		_lore_put = true
		LoreStone.put(_room_nodes[i], c + Vector3(w * 0.5 - 3.0, 0.0, l * 0.32), -PI * 0.5)
	# now and then a goblin with a sack of gold ([TreasureGoblin])
	if is_instance_valid(_treasure) and is_instance_valid(_treasure.body):
		_treasure.body.queue_free()
	_treasure = null
	if i < steps.size() - 1 and not mine.is_empty() and not _viewing \
			and bool(_arrival_plan.get("treasure", _rng.randf() < TreasureGoblin.CHANCE)):
		_treasure = TreasureGoblin.make(self, i)
	# the lord's court: his fight's own doings, his guard made now
	if is_instance_valid(_lord_fight):
		_lord_fight.queue_free()
	_lord_fight = null
	# (on his court, wherever in the run it stands: the ogre is the last
	# since 2026-10-27)
	if _place_of(i) == "throne":
		_lord_fight = LordFight.new()
		_lord_fight.name = "LordFight"
		add_child(_lord_fight)
		_lord_fight.setup(self, i)
	# its rift made now too, out of sight and out of the way, if it has one
	if is_instance_valid(_rift_ready):
		_rift_ready.queue_free()
	_rift_ready = null
	if waves > 1:
		_rift_ready = _make_rift(c, l)
		_rift_ready.visible = false
		_rift_ready.process_mode = Node.PROCESS_MODE_DISABLED


## Each of the run's creatures read in, so none is read in as he steps
## through a portal.
func _load_foes() -> void:
	_foe_scene(TreasureGoblin.SCENE)
	for step: Dictionary in steps:
		var by: Dictionary = step["foes"]
		for list: Array in by.values():
			for entry: Array in list:
				_foe_scene(String(entry[0]))


## The dungeon's sounds read in now too, and held: the first thunder over the
## rampart was read off the disk as it rolled (a 70 ms stall).
func _load_sounds() -> void:
	DungeonSound._load_sounds(self)


func _foe_scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _scenes[path]


func _creatures_node() -> Node:
	var level_root: Node = owner if owner != null else get_parent()
	return level_root.get_node_or_null("Enemies") if level_root != null else null


## The creatures of every step past the first that has the same ones wherever
## its portal leads — the two orcs, the lord — made now, behind the loading
## screen. Each takes 0.15–0.4 s to set itself up (its blows measured off its
## clips), and made as he came through the portal that was the freeze the
## user saw (2026-10-20). Out of sight under everything and not thinking till
## their place comes ([method _take_up]).
func _premake() -> void:
	var holder := _creatures_node()
	if holder == null:
		return
	for i in range(1, steps.size()):
		var by: Dictionary = steps[i]["foes"]
		if by.size() != 1 or not by.has("*"):
			continue
		var list: Array[Node3D] = []
		var k := 0
		# in the order the place will want them ([method mixed]), or one of a
		# kind is asked for where another was made, and made twice over
		for entry: Array in mixed(by["*"]):
			var scene := _foe_scene(String(entry[0]))
			if scene == null:
				continue
			for n in int(entry[1]):
				var body := scene.instantiate() as Node3D
				body.name = "D%d_R%d_%d" % [id, i, k]
				var away := Vector3(float(i * 10 + k) * 4.0, -300.0, 0.0)
				body.position = away
				var role := ""
				if entry.size() > 2:
					var props: Dictionary = entry[2]
					for key: String in props:
						body.set(StringName(key), props[key])
					role = String(props.get("role", ""))
				if role != "":
					FoeRoles.before(body, role)
				body.set("band", StringName("dungeon_%d_room_%d" % [id, i]))
				body.set("camp_centre", away)
				if "leash_radius" in body:
					body.set("leash_radius", 0.01)
				body.set_meta(&"level", int(steps[i].get("lv", 1)))
				body.set_meta(&"scene", String(entry[0]))
				if String(entry[0]) == BOSS.get(id, ""):
					body.set_meta(&"gift", LORD_GIFT)
					body.set_meta(&"gift_name", LORD_GIFT_NAME)
				if is_boss(i):
					body.set_meta(&"boss", true)
				body.visible = false
				body.process_mode = Node.PROCESS_MODE_DISABLED
				holder.add_child(body)
				if role != "":
					FoeRoles.after(body, role, self)
				list.append(body)
				k += 1
		_premade[i] = list


## One made at the start, put where its place wants it (asleep, like the rest).
func _take_up(body: Node3D, at: Vector3, c: Vector3, lv: int) -> void:
	body.global_position = at
	body.rotation.y = 0.0
	if "velocity" in body:
		body.set("velocity", Vector3.ZERO)
	if "_home" in body:
		body.set("_home", at)
	body.set("camp_centre", Vector3(c.x, c.y, c.z))
	body.set_meta(&"level", lv)
	if body.has_method(&"_pick_target"):
		body.call(&"_pick_target")
	if body.has_signal(&"hurt"):
		body.connect(&"hurt", _on_foe_hurt.bind(body))
	body.visible = true
	body.process_mode = Node.PROCESS_MODE_INHERIT


## A lamp put up in here remembers whether it was made with a shadow, so the
## graphics setting does not give every candle one ([Graphics]).
func _on_node_added(node: Node) -> void:
	if node is Light3D and not node.has_meta(&"designed_shadow"):
		node.set_meta(&"designed_shadow", (node as Light3D).shadow_enabled)


## The rift the next wave comes out of: in the far half of the place, a
## moment before they come.
func _open_rift() -> void:
	var c := centre(current)
	var l: float = _room(current)["l"]
	if is_instance_valid(_rift_ready):
		_rift = _rift_ready
		_rift_ready = null
		_rift.visible = true
		_rift.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		_rift = _make_rift(c, l)
	_rift_out = false
	# it opens slowly: out of a point of light, growing, the air drawn into it
	var grow := create_tween()
	grow.tween_property(_rift, "scale", Vector3.ONE, RIFT_GROW).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var world := Blood.world_of(self)
	if world != null:
		for k in 3:
			get_tree().create_timer(RIFT_GROW * float(k) / 3.0).timeout.connect(_rift_burst)
	_rift_at = Time.get_ticks_msec() / 1000.0 + RIFT_TIME
	if decides() and online():
		net_rift.rpc()
	Sfx.play(self, SND + "portal_open.wav", null, _rift.position + Vector3.UP * 2.0, 0.8, 4.0)
	_say("ტალღა %d / %d" % [wave + 1, waves], 2.5)
	_open_twin_cave()


## The air drawn into the opening rift (on a timer: the place may be gone).
func _rift_burst() -> void:
	var world := Blood.world_of(self)
	if world != null and is_instance_valid(_rift):
		SkillFx.burst(world, _rift.global_position + Vector3.UP * 2.6, Color(0.95, 0.25, 0.3), 40,
				Vector2(0.5, 2.0), Vector3.UP, 180.0, Vector2(0.05, 0.14), Vector3(0, 0.6, 0), 1.0)


func _make_rift(c: Vector3, l: float) -> PortalLook:
	var rift := PortalLook.new()
	rift.name = "Rift"
	rift.tint = Color(0.85, 0.12, 0.2)
	# only the whirl, no stones round it (the user's word, 2026-10-27)
	rift.bare = true
	rift.position = c + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, -l * 0.22)
	rift.scale = Vector3(0.02, 0.02, 0.02)
	add_child(rift)
	return rift


## The stone king of the crypt (the user's word, 2026-10-24: the statue on
## the throne gets up and fights): the golem's body in his crown and with his
## sword, under the floor till he rises; every peer makes him the same.
func _make_king(i: int, creatures: Node, c: Vector3) -> void:
	var scene := load(CryptTomb.KING_SCENE) as PackedScene
	if scene == null or creatures == null:
		return
	var body := scene.instantiate() as Node3D
	body.name = "D%d_R%d_king" % [id, i]
	body.position = c + Vector3(0.0, -40.0, -20.0)
	body.visible = false
	body.process_mode = Node.PROCESS_MODE_DISABLED
	body.set("max_health", CryptTomb.KING_HEALTH)
	body.set("band", StringName("dungeon_%d_room_%d" % [id, i]))
	body.set("camp_centre", c + CryptTomb.KING_STAND)
	if "leash_radius" in body:
		body.set("leash_radius", 0.01)
	body.set_meta(&"level", int(_room(i)["lv"]) + 1)
	body.set_meta(&"boss_name", CryptTomb.KING_NAME)
	if body.has_signal(&"hurt"):
		body.connect(&"hurt", _on_foe_hurt.bind(body))
	creatures.add_child(body)
	if "health" in body:
		body.set("health", CryptTomb.KING_HEALTH)
	CryptTomb.dress_king(body)
	_watch_foe(body)
	_king = body


@rpc("authority", "call_remote", "reliable")
func net_king_rise() -> void:
	_king_rise()


## The statue crumbles, and the king stands before his throne; a moment
## later he comes at the nearest of them.
func _king_rise() -> void:
	if _king_up or not is_instance_valid(_king):
		return
	_king_up = true
	var c := centre(current)
	var room: Node3D = _room_nodes[current] if current < _room_nodes.size() else null
	CryptTomb.wake_statue(self, room)
	Sfx.play_flat(self, SND + "horn.wav", 0.7, -2.0)
	_say("%s გაიღვიძა!" % CryptTomb.KING_NAME, 3.0)
	var body := _king
	body.global_position = c + CryptTomb.KING_STAND
	body.rotation.y = 0.0
	body.visible = true
	body.process_mode = Node.PROCESS_MODE_INHERIT
	var l: float = _room(current)["l"]
	if "leash_radius" in body:
		body.set("leash_radius", l)
	if "sight_range" in body:
		body.set("sight_range", l * 1.5)
	_alive.append(body)
	_spawned += 1
	if current < _room_foes.size():
		(_room_foes[current] as Array).append(body)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if not is_instance_valid(body):
			return
		var hero := _nearest_hero(body.global_position)
		if hero != null and body.has_method("_rouse"):
			body.call("_rouse", hero))


## The rest of them out of the rift, one after another, at him; the rift
## closing after them.
func _next_wave() -> void:
	if decides() and online():
		net_wave.rpc()
	_rift_out = true
	wave += 1
	var l: float = _room(current)["l"]
	var at: Vector3 = _rift.global_position if is_instance_valid(_rift) else centre(current)
	var out := 0
	var list: Array[Node3D] = _reserve.duplicate()
	_reserve.clear()
	for body in list:
		if not is_instance_valid(body) or bool(body.get("is_dead")):
			continue
		var a := TAU * float(out) / float(maxi(list.size(), 1))
		var spot := at + Vector3(sin(a) * 2.4, 0.3, 2.2 + cos(a) * 1.4)
		_alive.append(body)
		_spawned += 1
		get_tree().create_timer(0.45 * float(out)).timeout.connect(_step_out.bind(body, spot, l))
		out += 1
	if is_instance_valid(_rift):
		var gone := _rift
		_rift = null
		var tw := create_tween()
		tw.tween_interval(0.45 * float(out) + 1.8)
		tw.tween_property(gone, "scale", Vector3(0.02, 0.02, 0.02), 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(gone.queue_free)


## One of the next wave out of the rift at `spot`.
func _step_out(body: Node3D, spot: Vector3, l: float) -> void:
	if not is_instance_valid(body) or bool(body.get("is_dead")):
		return
	body.global_position = spot
	body.visible = true
	body.process_mode = Node.PROCESS_MODE_INHERIT
	if "leash_radius" in body:
		body.set("leash_radius", l)
	var hero := _nearest_hero(spot)
	if hero != null and body.has_method("_rouse"):
		body.call_deferred("_rouse", hero)
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, spot + Vector3.UP * 1.2, Color(0.9, 0.2, 0.3), 30, Vector2(1.0, 3.5), Vector3.UP,
				180.0, Vector2(0.06, 0.16), Vector3(0, -1.0, 0), 0.9)
	Sfx.play(self, SND + "portal_whoosh.wav", null, spot + Vector3.UP, randf_range(1.0, 1.25), -2.0)


## The place's creatures wake and come at him.
func _wake(i: int) -> void:
	_woken = true
	_lay_traps(i)
	if decides() and not _viewing:
		_hold_hard(i)
	if _run_start < 0.0:
		_run_start = Time.get_ticks_msec() / 1000.0
	_alive.clear()
	_holders.clear()
	_orc_on = null
	var l: float = _room(i)["l"]
	var hero := _nearest_hero(centre(i))
	for item: Variant in _room_foes[i]:
		if not is_instance_valid(item) or _reserve.has(item):
			continue
		var body := item as Node3D
		if "leash_radius" in body:
			body.set("leash_radius", l)
		# from anywhere in the place they see him (the user's word,
		# 2026-10-23: as he comes in, every one of them)
		if "sight_range" in body:
			body.set("sight_range", maxf(float(body.get("sight_range")), l * 1.5))
		_alive.append(body)
		if hero != null and body.has_method("_rouse"):
			body.call_deferred("_rouse", hero)
	_spawned = _alive.size()
	if is_instance_valid(_lord_fight):
		_lord_fight.wake()
	elif is_boss(i):
		Sfx.play_flat(self, SND + "horn.wav", 1.0, -3.0)
		_say("ბოსი: %s" % String(steps[i].get("boss_name", "")), 3.0)
	else:
		_say("%d/%d  ·  %s" % [stage_of(i), stage_count(), String(_room(i)["name"])], 3.0)
	if is_instance_valid(_goal):
		_goal.start()
	if is_instance_valid(_treasure):
		get_tree().create_timer(2.5).timeout.connect(_treasure.release)
	if decides() and online():
		net_wake.rpc(i)
	if _spawned == 0:
		_clear(i)


func _nearest_hero(to: Vector3) -> Player:
	var best: Player = null
	var gap := INF
	for hero in _heroes():
		if hero.is_dead:
			continue
		var d := hero.global_position.distance_to(to)
		if d < gap:
			gap = d
			best = hero
	return best


## The place cleared — decided by the host, which tells the others what comes
## of it ([method net_clear]): the next portals, the cursed place's extra gift.
func _clear(i: int) -> void:
	if cleared[i] or not decides():
		return
	var plan := {}
	var r := _room(i)
	if bool(r.get("cursed", false)) and String(r.get("reward", "")) == "boon":
		var others: Array = REWARDS.keys()
		others.erase("boon")
		plan["extra"] = String(others[_rng.randi() % others.size()])
	if i < steps.size() - 1:
		plan["specs"] = _ready_specs if not _ready_specs.is_empty() else _choice_specs(i + 1)
	_ready_specs = []
	_apply_clear(i, plan)
	if online():
		net_clear.rpc(i, plan)


@rpc("authority", "call_remote", "reliable")
func net_clear(i: int, plan: Dictionary) -> void:
	if i == current and not cleared[i]:
		_apply_clear(i, plan)


func _apply_clear(i: int, plan: Dictionary) -> void:
	if cleared[i]:
		return
	cleared[i] = true
	room_cleared.emit(i)
	_open_twin_cave()
	if _map != null:
		_map.queue_redraw()
	var r := _room(i)
	# What clearing it is worth on top of its creatures, and the level it
	# brings him to at least (the host's to give: [Leveling]).
	for hero in _heroes():
		var book := hero.get_node_or_null("Leveling") as Leveling
		if book == null or hero.is_dead or not decides():
			continue
		var bonus := float(r.get("xp", 0.0))
		if bonus > 0.0:
			book.gain(bonus)
		if int(r.get("reach", 0)) > 0:
			book.raise_to(int(r["reach"]))
	# The fallen get up when the place is clear (the user's word: in a band,
	# the dead wait for the others to clear the room).
	for hero in _heroes():
		if hero.is_dead and hero.has_method("_respawn") and mine(hero):
			var at := hero.global_position
			hero.call("_respawn")
			hero.global_position = at
	if String(r.get("reward", "")) != "":
		var what := String(r["reward"])
		if bool(r.get("cursed", false)):
			# its reward twice over: a blessing with one light more and a
			# gift besides, or the gift twice
			if what == "boon":
				_give(String(plan.get("extra", "gold")))
				boons.lights += 1
				_give(what)
				boons.lights -= 1
			else:
				_give(what)
				_give(what)
		else:
			_give(what)
	if i < steps.size() - 1:
		_offer(i + 1, plan.get("specs", []))
	else:
		_close()


## What waits behind the portal he chose, his now.
func _give(what: String) -> void:
	rewards_given.append(what)
	if what == "boon":
		# three lights in the middle of the place: he walks into the one he
		# wants (laid by the host, the same for everyone: [method net_lay])
		if decides():
			lay_lights(centre(current) + Vector3(0.0, 0.0, float(_room(current)["l"]) * 0.2))
		_say("აირჩიე კურთხევა", 3.0)
		return
	for hero in _heroes():
		# each his own: a reward is put on him by his own game
		if hero.is_dead or not mine(hero):
			continue
		match what:
			"life":
				hero.max_health *= 1.2
				if hero.profile != null:
					hero.profile.max_health = hero.max_health
				hero.health = hero.max_health
			"gold":
				var purse := Purse.of(hero)
				if purse != null:
					purse.give(GOLD_GIFT)
			"blade":
				var book := hero.get_node_or_null("Leveling") as Leveling
				if book != null:
					book.boost_blows(1.15)
			"skill":
				hero.skill_haste *= 0.8
		var world := Blood.world_of(self)
		if world != null:
			SkillFx.burst(world, hero.global_position + Vector3.UP * 1.2, REWARDS[what]["tint"], 50,
					Vector2(1.0, 3.5), Vector3.UP, 180.0, Vector2(0.06, 0.16), Vector3(0, 1.0, 0), 1.4)
	_say("ჯილდო: %s" % String(REWARDS[what]["name"]), 3.0)


## The portals out of the place just cleared, to step `next`: two, each to a
## place of its own with a reward of its own (one, to the lord).
func _offer(next: int, specs: Array = []) -> void:
	var made := _ready_choices
	_ready_choices = []
	var gates: Array[PortalLook] = []
	for gate in made:
		if is_instance_valid(gate):
			gates.append(gate)
	if gates.is_empty():
		gates = _gates_from(specs, next) if not specs.is_empty() else _make_choices(next)
	for gate in gates:
		gate.visible = true
		gate.process_mode = Node.PROCESS_MODE_INHERIT
		choices.append(gate)
		Sfx.play(self, SND + "portal_open.wav", null, gate.position + Vector3.UP * 2.0, 1.0, 2.0)
	_say("აირჩიე გზა" if gates.size() > 1 else "გზა ბოსისკენ", 3.0)


## The portals out of the place just come to, made as he comes (behind the
## dark) and kept out of sight and out of the way till it is cleared: made as
## the last creature fell, two portals were a stall at that moment.
func _prepare_offer(next: int) -> void:
	for gate in _ready_choices:
		if is_instance_valid(gate):
			gate.queue_free()
	_ready_choices = []
	if next >= steps.size():
		# the last place: its way out instead
		if not is_instance_valid(_exit_ready):
			_exit_ready = _make_exit()
			_exit_ready.visible = false
			_exit_ready.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if not decides():
		return
	_ready_specs = _choice_specs(next)
	_ready_choices = _gates_from(_ready_specs, next)
	for gate in _ready_choices:
		gate.visible = false
		# out of the physics as well: its stones do not stand in his way
		gate.process_mode = Node.PROCESS_MODE_DISABLED


## Two portals to step `next` (one, to the lord), each to a place of its own
## with a reward of its own, at the far end of the place he is in.
func _make_choices(next: int) -> Array[PortalLook]:
	return _gates_from(_choice_specs(next), next)


## What the two portals to step `next` lead to — decided by the host alone and
## sent to the others ([method net_clear]): place, reward, goal, cursed.
func _choice_specs(next: int) -> Array:
	var out: Array = []
	var pool: Array = (steps[next]["places"] as Array).duplicate()
	var here := String(_room(current)["place"])
	if pool.size() > 2:
		pool.erase(here)
	# no place twice in a run (the user's word, 2026-10-25): those already
	# seen left out; short of two, a place of the same height not yet seen
	if pool.size() > 1:
		pool = _unseen(pool)
	_shuffle(pool)
	# before the orcs, now and then, a place to get one's breath back behind
	# one of the two (the user's word, 2026-10-21): the spring when he is hurt
	# — oftener, and oftener the prisoners, while the village wants its three
	# tradesmen ([Trades])
	var game := get_node_or_null("/root/Game")
	var wanted := game != null and game.get(&"freed") != null and (game.get(&"freed") as Array).size() < Trades.ORDER.size()
	# (never two rests one after the other)
	var resting := (PLACES.get(here, {}) as Dictionary).has("rest")
	if not resting and is_boss(next):
		# before a boss, the spring always, beside the way to him (the user's
		# word, 2026-10-22: it is not a step)
		pool = [pool[0], "spring"]
	elif not resting and REST_BEFORE.has(stage_of(next)) and pool.size() >= 2 \
			and _rng.randf() < (0.75 if wanted else 0.5):
		var low := false
		for hero in _heroes():
			if hero.health < hero.max_health * 0.6:
				low = true
		pool[1] = _rest_pick(low, wanted)
	var take := mini(2, pool.size())
	# a blessing behind one of the two, most times (the user's word,
	# 2026-10-21: the reward should change how he fights); never two
	var gifts: Array = REWARDS.keys()
	gifts.erase("boon")
	_shuffle(gifts)
	if _rng.randf() < 0.75 and not boons.offer(1).is_empty():
		gifts.insert(_rng.randi_range(0, 1), "boon")
	var last := next == steps.size() - 1
	var cursed_one := -1
	if not last and next >= 1 and not is_boss(next) and _rng.randf() < CURSE_CHANCE:
		cursed_one = _rng.randi_range(0, take - 1)
	for k in take:
		var place := String(pool[k])
		var rest: bool = (PLACES[place] as Dictionary).has("rest")
		var reward := "" if last or rest else String(gifts[k])
		var goal := "" if rest or is_boss(next) else RoomGoal.pick(_rng, next, steps.size() - 1)
		goal = _fit_goal(goal, place)
		out.append({"place": place, "reward": reward, "goal": goal, "cursed": k == cursed_one and reward != ""})
	return out


## A goal as it may be at `place` in this run:
## * holding out not where a place has its own lord or ways (the crypt's
##   king came as a bar with no one under it, 2026-10-27), and once a run at
##   most (2026-10-28: the forest and the swamp were always "survive");
## * no totems with others (who broke one is not told to the rest yet), nor
##   in the cave (they stood in its walls, out of reach, and its door would
##   not open, 2026-10-28);
## * never the same goal two places running.
func _fit_goal(goal: String, place: String) -> String:
	var held_out := false
	for r: Variant in rooms:
		if r is Dictionary and String((r as Dictionary).get("goal", "")) == "survive":
			held_out = true
	var last := ""
	if current >= 0 and current < rooms.size() and rooms[current] is Dictionary:
		last = String((rooms[current] as Dictionary).get("goal", ""))
	if goal == "survive" and (held_out or NO_SURVIVE.has(place)):
		goal = "totems"
	if goal == "totems" and (online() or NO_TOTEMS.has(place)):
		goal = ""
	if goal != "" and goal == last:
		goal = ""
	return goal


## Of `pool`, the places not yet seen in this run; when that leaves fewer
## than two, places of the same height ([constant ZONES]) not yet seen; when
## even that is short, the pool as it was.
func _unseen(pool: Array) -> Array:
	var seen := {}
	for r in rooms:
		if r is Dictionary and (r as Dictionary).has("place"):
			seen[String(r["place"])] = true
	var out: Array = []
	for p in pool:
		if not seen.has(String(p)):
			out.append(p)
	if out.size() < 2:
		for zone: Array in ZONES:
			if not zone.has(pool[0]):
				continue
			for p in zone:
				if out.size() < 2 and not seen.has(String(p)) and not out.has(p):
					out.append(p)
	return out if out.size() >= 2 else pool


## Which place to rest behind the second portal: the spring when he is hurt;
## else the prisoners (oftener while the village wants its tradesmen), the
## altar, now and then the spring.
func _rest_pick(low: bool, wanted: bool) -> String:
	if low:
		return "spring"
	var weights := {"prison": 2.0 if wanted else 0.8, "altar": 1.0, "spring": 0.5}
	var total := 0.0
	for k: String in weights:
		total += float(weights[k])
	var roll := _rng.randf() * total
	for k: String in weights:
		roll -= float(weights[k])
		if roll <= 0.0 and float(weights[k]) > 0.0:
			return k
	return "spring"


#region Kept hard however strong they grow, however many they are
## (the user's word, 2026-10-22: some runs he came to the last boss so strong
## he killed him easily; and two together killed him very quickly)
##
## * **How strong the run has made them** ([method run_power]): what it has
##   given that makes blows heavier — each "blade" reward, the altar of
##   gold (shared out over the heroes), each blessing,
##   half the village smith's edge. Against what a run is expected to have
##   given by then (`EXPECT_POWER` by the last step, from nothing at the
##   first), only part of the excess is made up for (the user's word,
##   2026-10-22: "the boss should grow with how strong we got, but not all
##   the way — or growing stronger would mean nothing"): `BOSS_SHARE` of it
##   on a boss's health (to `POWER_MOST`), `HIT_SHARE` on its blows (to
##   `POWER_HIT_MOST`), from the sixth step on `FOE_SHARE` on the other
##   creatures' health. A strong run still kills them sooner than a weak one.
## * **How many they are**: each hero past the first, a boss (and the lord's
##   guard) `COOP_BOSS` more health, the others `COOP_FOE` more; the big
##   ones' stance `COOP_STANCE` more (two blades break it twice as fast).
## The host reckons it as a place wakes and tells everyone ([method net_harden]).
const EXPECT_POWER := 1.3
const BOSS_SHARE := 0.5
const HIT_SHARE := 0.25
const FOE_SHARE := 0.25
const POWER_MOST := 1.6
const POWER_HIT_MOST := 1.2
const FOE_MOST := 1.4
const COOP_BOSS := 0.85
const COOP_FOE := 0.5
const COOP_STANCE := 0.5


## How much heavier the run has made their blows (1: nothing yet).
func run_power() -> float:
	var p := 1.0
	for r in rewards_given:
		if r == "blade":
			p *= 1.15
	var n := maxi(_heroes().size(), 1)
	for d in deals_made:
		if d == "gold":
			p *= pow(PortalEvent.GOLD_BLADE, 1.0 / float(n))
	p *= 1.0 + 0.06 * float(boons.taken.size()) if boons != null else 1.0
	var game := get_node_or_null("/root/Game")
	if game != null:
		p *= 1.0 + 0.5 * float(Trades.ALL["smith"]["per"]) * float(Trades.level(game, "smith"))
	return p


## What place `i` asks of its creatures, for `heroes` heroes whose blows the
## run has made `power` times heavier: {boss, foe, hit, stance} multipliers.
func hard_factors(i: int, heroes: int, power: float) -> Dictionary:
	var along := float(stage_of(i) - 1) / float(maxi(stage_count() - 1, 1))
	var excess := maxf(power / lerpf(1.0, EXPECT_POWER, along), 1.0) - 1.0
	var more := float(maxi(heroes, 1) - 1)
	return {
		"boss": minf(1.0 + BOSS_SHARE * excess, POWER_MOST) * (1.0 + COOP_BOSS * more),
		"guard": 1.0 + COOP_BOSS * more,
		"foe": (minf(1.0 + FOE_SHARE * excess, FOE_MOST) if stage_of(i) >= 6 else 1.0) * (1.0 + COOP_FOE * more),
		"hit": minf(1.0 + HIT_SHARE * excess, POWER_HIT_MOST),
		"stance": 1.0 + COOP_STANCE * more,
	}


## Host: place `i` as it wakes, made as hard as the heroes now are.
func _hold_hard(i: int) -> void:
	var standing := 0
	for hero in _heroes():
		if not hero.is_dead:
			standing += 1
	var f := hard_factors(i, standing, run_power())
	if online():
		net_harden.rpc(i, f)
	else:
		net_harden(i, f)


## On every peer: the creatures of place `i` (and the lord's guard) made
## harder by `f` ([method hard_factors]), once.
@rpc("authority", "call_local", "reliable")
func net_harden(i: int, f: Dictionary) -> void:
	last_hardness = f.duplicate()
	var bodies: Array = []
	if i < _room_foes.size():
		bodies.append_array(_room_foes[i])
	var guards: Array = []
	if is_boss(i) and is_instance_valid(_lord_fight):
		guards.append_array(_lord_fight.guards)
	for item: Variant in bodies + guards:
		if not is_instance_valid(item) or (item as Node).has_meta(&"hardened"):
			continue
		var body := item as Node3D
		body.set_meta(&"hardened", true)
		var guard := guards.has(body)
		var big := is_boss(i) and not guard
		var hp := float(f["guard"]) if guard else (float(f["boss"]) if big else float(f["foe"]))
		FoeRoles._scale_stat(body, &"max_health", hp)
		if big:
			FoeRoles._scale_stat(body, &"hit_damage", float(f["hit"]))
		if "stance" in body:
			FoeRoles._scale_stat(body, &"stance", float(f["stance"]))
		if "health" in body and "max_health" in body:
			body.set(&"health", body.get(&"max_health"))


## The last place's hardness, as it woke (tests).
var last_hardness: Dictionary = {}
#endregion


## Spike traps in the floor of place `i` as it wakes ([SpikeTrap]; the user's
## word, 2026-10-22): from the third step on, not in a boss's place nor a
## quiet one; the same on every peer (its own dice, from the dungeon and the
## step). Laid as it wakes, when its floor has long been there to find.
## The place step `i` was made at ("" before it is).
func _place_of(i: int) -> String:
	if i < 0 or i >= rooms.size() or not (rooms[i] is Dictionary):
		return ""
	return String((rooms[i] as Dictionary).get("place", ""))


func _lay_traps(i: int) -> void:
	if _viewing or is_rest(i) or is_boss(i):
		return
	# holding out is running: spikes there always (the user's word, 2026-10-27)
	var holding := i < rooms.size() and rooms[i] is Dictionary \
			and String((rooms[i] as Dictionary).get("goal", "")) == "survive"
	if stage_of(i) < TRAPS_FROM and not holding:
		return
	if i < _room_nodes.size() and is_instance_valid(_room_nodes[i]) and _room_nodes[i].has_node(^"Spikes0"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 104729 * (i + 1) + 7 * id + 3
	if rng.randf() > TRAP_CHANCE and not holding:
		return
	SpikeTrap.lay(self, i, rng)


## The altar's keeper in the place he is in ([PortalEvent]).
func _event_here() -> PortalEvent:
	if current < 0 or current >= _room_nodes.size() or not is_instance_valid(_room_nodes[current]):
		return null
	return _room_nodes[current].get_node_or_null(^"Event") as PortalEvent


## A deal asked for by a hero on another peer: the host makes it, or not.
@rpc("any_peer", "call_remote", "reliable")
func net_ask_deal(k: int, hero: NodePath) -> void:
	if not decides():
		return
	var ev := _event_here()
	var who := get_node_or_null(hero) as Player
	if ev != null and who != null:
		ev.host_deal(k, who)


## The host's word: the deal made, on every peer.
@rpc("authority", "call_local", "reliable")
func net_deal_done(k: int, hero: NodePath) -> void:
	var ev := _event_here()
	if ev != null:
		ev.deal_done(k, get_node_or_null(hero) as Player)


## Shuffled by the dungeon's own dice (not the engine's, which no one else shares).
func _shuffle(list: Array) -> void:
	for k in range(list.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k)
		var t: Variant = list[k]
		list[k] = list[j]
		list[j] = t


## The portals themselves, from what they lead to ([method _choice_specs]).
func _gates_from(specs: Array, _next: int) -> Array[PortalLook]:
	var out: Array[PortalLook] = []
	var l: float = _room(current)["l"]
	var take := specs.size()
	for k in take:
		var spec: Dictionary = specs[k]
		var place := String(spec["place"])
		var rest: bool = (PLACES[place] as Dictionary).has("rest")
		var reward := String(spec["reward"])
		var goal := String(spec["goal"])
		var gate := PortalLook.new()
		gate.name = "Choice%d" % k
		if reward != "":
			gate.tint = REWARDS[reward]["tint"]
		elif rest:
			gate.tint = {"altar": Color(0.75, 0.12, 0.16)}.get(place, Color(0.45, 0.8, 1.0))
		# what is behind it, seen in it
		var view := PREVIEWS % place
		if ResourceLoader.exists(view):
			gate.view = load(view) as Texture2D
		var side := 0.0 if take == 1 else (-1.0 if k == 0 else 1.0)
		gate.position = centre(current) + Vector3(side * 9.0, 0.0, -l * 0.5 + 10.0)
		gate.set_meta(&"place", place)
		gate.set_meta(&"reward", reward)
		gate.set_meta(&"goal", goal)
		# now and then one is cursed (the user's word, 2026-10-21: a risk worth
		# taking): its creatures stronger, its reward twice
		if bool(spec.get("cursed", false)):
			gate.set_meta(&"cursed", true)
			gate.tint = Color(0.6, 0.04, 0.08)
		add_child(gate)
		var title := Label3D.new()
		title.text = String(PLACES[place]["name"])
		title.font_size = 72
		title.pixel_size = 0.012
		title.outline_size = 14
		title.modulate = Color(1.0, 0.96, 0.9)
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.no_depth_test = true
		title.position = Vector3(0.0, 9.6, 0.0)
		gate.add_child(title)
		var what := Label3D.new()
		what.text = ("ჯილდო: " + String(REWARDS[reward]["name"])) if reward != "" \
				else (String(PLACES[place]["rest"]) if rest else "ბოსი")
		what.font_size = 56
		what.pixel_size = 0.012
		what.outline_size = 12
		what.modulate = REWARDS[reward]["tint"] if reward != "" \
				else (Color(0.6, 0.9, 1.0) if rest else Color(1.0, 0.4, 0.35))

		what.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		what.no_depth_test = true
		what.position = Vector3(0.0, 8.5, 0.0)
		gate.add_child(what)
		if bool(gate.get_meta(&"cursed", false)):
			var curse := Label3D.new()
			curse.text = "☠ წყეული: ძლიერი მტრები — ორმაგი ჯილდო ☠"
			curse.font_size = 46
			curse.pixel_size = 0.012
			curse.outline_size = 12
			curse.modulate = Color(1.0, 0.25, 0.22)
			curse.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			curse.no_depth_test = true
			curse.position = Vector3(0.0, 6.6 if goal != "" else 7.55, 0.0)
			gate.add_child(curse)
		if goal != "":
			var aim := Label3D.new()
			aim.text = "მიზანი: " + String(RoomGoal.KINDS[goal]["name"])
			aim.font_size = 48
			aim.pixel_size = 0.012
			aim.outline_size = 12
			aim.modulate = Color(1.0, 0.7, 0.45)
			aim.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			aim.no_depth_test = true
			aim.position = Vector3(0.0, 7.55, 0.0)
			gate.add_child(aim)
		out.append(gate)
	return out


## Through portal `k`: the screen goes dark, the next place is built behind
## the dark and the heroes are put in it, the dark lifts.
func take(k: int) -> void:
	if _going or k < 0 or k >= choices.size() or not decides():
		return
	# what the place behind it holds that is left to chance, the host's throw
	var plan := {"treasure": _rng.randf() < TreasureGoblin.CHANCE, "lore": _rng.randf() < 0.5}
	if online():
		net_take.rpc(k, plan)
		# whoever waits in the village to follow comes in behind them
		var gate := choices[k]
		_net().call("bring_waiting", {"dungeon_id": id, "portal_return": id, "join_at": {
			"step": current + 1, "place": String(gate.get_meta(&"place")),
			"reward": String(gate.get_meta(&"reward")), "cursed": bool(gate.get_meta(&"cursed", false)),
			"goal": String(gate.get_meta(&"goal", "")), "plan": plan, "lore_put": _lore_put}})
	_go_through(k, plan)


@rpc("authority", "call_remote", "reliable")
func net_take(k: int, plan: Dictionary) -> void:
	_go_through(k, plan)


## A client walked into portal `k`: the host takes everyone through.
@rpc("any_peer", "call_remote", "reliable")
func ask_take(k: int) -> void:
	if decides():
		take(k)


func _go_through(k: int, plan: Dictionary) -> void:
	if _going or k < 0 or k >= choices.size():
		return
	_going = true
	_arrival_plan = plan
	var gate := choices[k]
	var place := String(gate.get_meta(&"place"))
	var reward := String(gate.get_meta(&"reward"))
	_curse_next = bool(gate.get_meta(&"cursed", false))
	var goal := String(gate.get_meta(&"goal", ""))
	var next := current + 1
	if (PLACES[place] as Dictionary).has("rest"):
		_rest_between(next, place)
	Sfx.play_flat(self, SND + "portal_whoosh.wav", 1.0, -2.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	await tw.finished
	for c in choices:
		c.queue_free()
	choices.clear()
	_take_down(current)
	_arrive_at(next, place, reward, false, goal)
	_arrival_plan = {}
	var slot := 0
	for hero in _heroes():
		# each game puts its own hero at the door, at his own place in the line
		if mine(hero):
			hero.global_position = entry_point(_slot_of(hero, slot), next)
			hero.velocity = Vector3.ZERO
		slot += 1
	_to_phase(light_of(next), 0.05)
	# behind the dark: the new place seen once from its door and from over
	# it, so what it shows for the first time is made now and not when he
	# turns round in it; then till it draws smoothly
	await _look_round(next)
	await _settle()
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE)
	_wake_at = Time.get_ticks_msec() / 1000.0 + WAKE_AFTER
	_going = false


## Frames go by till three in a row come quickly ([constant SETTLED_MS]),
## at least four, at most [constant SETTLE_MAX] (a slow machine is not held
## in the dark for ever).
func _settle() -> void:
	var quick := 0
	var limit := maxf(SETTLED_MS, _usual_ms * 1.5)
	var last := Time.get_ticks_usec()
	for f in SETTLE_MAX:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		quick = quick + 1 if float(now - last) / 1000.0 < limit else 0
		last = now
		if f >= 3 and quick >= 3:
			return


## Everything the run will show, shown to the renderer once behind the
## loading screen ([SceneLoader] waits while a node called PipelineWarmup is
## there, as for the open world's [PipelineWarmup]): the first place looked
## round (the others are, behind the dark, as he comes to them), one of each creature, the
## lord and his orcs, the portals, the shards of the dead, the sparks, the
## heroes' own skills. Godot makes what it draws the first time it draws it,
## and made in front of him each of those was a stall (the user's word,
## 2026-10-20: it sticks going through a portal).
func _warm_up() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var started := Time.get_ticks_msec()
	var level_root: Node = owner if owner != null else get_parent()
	var mark := Node.new()
	mark.name = "PipelineWarmup"
	level_root.add_child(mark)
	var was_going := _going
	_going = true
	if _bus >= 0 and _bus < AudioServer.bus_count:
		AudioServer.set_bus_mute(_bus, true)
	var dark := _fade.color.a if _fade != null else 0.0
	if _fade != null:
		_fade.color.a = 1.0
	var eye := Camera3D.new()
	eye.fov = 95.0
	eye.far = 520.0
	add_child(eye)
	# Only the place he stands in, from its door and from over it. The
	# others are no longer put up here (they cost ~3.5 s of the loading
	# screen at High on the M1): each is looked round behind the dark as he
	# goes through its portal ([method _look_round], the user's idea,
	# 2026-10-28: made at the right time, not all beforehand).
	await _look_round(current, eye)

	# The creatures, the portals, the fights' own: in a row before the eye.
	var stage := Node3D.new()
	stage.name = "WarmStage"
	add_child(stage)
	stage.global_position = WARM_AT + Vector3(0.0, 0.0, -400.0)
	eye.make_current()
	eye.global_position = stage.global_position + Vector3(0.0, 3.0, 9.0)
	eye.look_at(stage.global_position + Vector3(0.0, 1.5, 0.0))
	var shown: Array[Node3D] = []
	var x := -6.0
	var made_paths := {}
	for list: Array in _premade.values():
		for body: Variant in list:
			if is_instance_valid(body):
				made_paths[String((body as Node).get_meta(&"scene", ""))] = true
	for path: String in _scenes:
		var scene: PackedScene = _scenes[path]
		if scene == null or made_paths.has(path):
			continue
		var body := scene.instantiate() as Node3D
		if "leash_radius" in body:
			body.set("leash_radius", 0.01)
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.position = Vector3(x, 0.0, 0.0)
		stage.add_child(body)
		shown.append(body)
		x += 3.0
	var lent: Array[Node3D] = []
	for list: Array in _premade.values():
		for body: Variant in list:
			if is_instance_valid(body):
				var b := body as Node3D
				b.global_position = stage.global_position + Vector3(x, 0.0, -2.0)
				b.visible = true
				lent.append(b)
				x += 3.5
	for k in 2:
		var gate := PortalLook.new()
		gate.tint = REWARDS["blade"]["tint"] if k == 0 else Color(0.85, 0.12, 0.2)
		var view := PREVIEWS % "cave"
		if k == 0 and ResourceLoader.exists(view):
			gate.view = load(view) as Texture2D
		gate.position = Vector3(-4.0 + float(k) * 8.0, 0.0, -6.0)
		stage.add_child(gate)
	# a blessing's light and its lightning (their materials made now)
	boons._light(&"chain", stage.global_position + Vector3(6.0, 0.0, -3.0), stage)
	boons._bolt(stage.global_position + Vector3(-3.0, 1.5, 0.0), stage.global_position + Vector3(3.0, 1.5, 0.0))
	# the letters the portals and the banner write with, at their sizes: each
	# new letter was drawn into the font's cache as the portals opened
	var letters := "0123456789/:. "
	for code in range(0x10D0, 0x10F1):
		letters += String.chr(code)
	for sizes: Vector2i in [Vector2i(72, 14), Vector2i(56, 12)]:
		var words := Label3D.new()
		words.text = letters
		words.font_size = sizes.x
		words.outline_size = sizes.y
		words.pixel_size = 0.004
		words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		words.no_depth_test = true
		words.position = Vector3(0.0, 4.0 + float(sizes.x) * 0.01, 2.0)
		stage.add_child(words)
	if _banner != null:
		_banner.text = letters
		_banner.show()
		_banner_until = 0.0
	var props := MudBall.warm_props()
	stage.add_child(props)
	props.position = Vector3(0.0, 1.5, 5.0)
	var ember := MeshInstance3D.new()
	ember.mesh = MudBall.lump_mesh()
	ember.material_override = MudBall.coal()
	ember.position = Vector3(0.6, 0.0, 0.0)
	props.add_child(ember)
	RogueSkills.warm(props)
	MageSkills.warm(props)
	DarkSkills.warm(props)
	ScreenMud.prepare(get_tree())
	ScreenMud.splat(get_tree(), 1.0)
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, stage.global_position + Vector3(0.0, 2.0, 3.0), Color(1.0, 0.8, 0.4), 14,
				Vector2(2.0, 5.0), Vector3.UP, 180.0, Vector2(0.03, 0.07), Vector3(0, -6.0, 0), 0.35)
	# the light he goes up in at a new level (its sound kept quiet)
	var lifted := Node3D.new()
	stage.add_child(lifted)
	lifted.position = Vector3(3.0, 0.0, 2.0)
	var beam := LevelBeam.on(lifted)
	if beam != null:
		for node in beam.find_children("*", "AudioStreamPlayer3D", true, false):
			(node as AudioStreamPlayer3D).stop()
	# the cave's bats, gone round as a flock
	_bat_flock(stage.global_position + Vector3(0.0, 3.0, 0.0))
	# one of them broken as the dead are: lit, then in shards
	var breaking: DeathShatter = null
	if not shown.is_empty():
		breaking = DeathShatter.start(self, shown[0])
	for f in 40:
		eye.make_current()
		await get_tree().process_frame
		if f % 3 == 1:
			_keep_materials(level_root)
		if f >= 6 and (breaking == null or not is_instance_valid(breaking)):
			break
	# What each of those was drawn with, held for as long as the dungeon is
	# up. Godot makes a material's shader for each kind of material and lets
	# it go when the last one of that kind is gone: the shards of the dead, the
	# bats, the sparks were each made afresh every time they came round again
	# (a death cost 40–100 ms; the bats near a second).
	_keep_materials(level_root)
	ScreenMud.clear(get_tree())
	for b in lent:
		if is_instance_valid(b):
			b.visible = false
			b.global_position = Vector3(b.global_position.x, -300.0, 0.0)
	# out of sight, and gone once what the skills and the sparks left timed
	# on it has run out
	# (the one in shards goes with the stage: its shards still hold it)
	for body in shown.slice(1):
		if is_instance_valid(body):
			body.queue_free()
	stage.visible = false
	get_tree().create_timer(6.0).timeout.connect(stage.queue_free)

	# the view back to the hero's own eye
	var hers := _hero_eye()
	eye.queue_free()
	if hers != null:
		hers.make_current()
	if _fade != null:
		_fade.color.a = dark
	if _bus >= 0 and _bus < AudioServer.bus_count:
		AudioServer.set_bus_mute(_bus, false)
	_going = was_going
	mark.queue_free()
	# the dungeon's name, now that it can be seen
	_say("%s" % String(Portals.DEFS[id]["name"]), 3.5)
	print("Dungeon: warm-up %d ms" % (Time.get_ticks_msec() - started))


## Place `i` shown to the renderer once from its door and from high over
## it (two frames each), through `eye` or a camera of its own, the view then
## given back to his own eye. Done behind the dark (the loading screen, a
## portal's black): Godot makes what it draws the first time it draws it,
## and this way that is not in front of him. ~60–400 ms a place at High on
## the M1 (2026-10-27 probe), where it used to be all at the start.
func _look_round(i: int, eye: Camera3D = null) -> void:
	if DisplayServer.get_name() == "headless" or i < 0 or i >= rooms.size():
		return
	var own := eye == null
	if own:
		eye = Camera3D.new()
		eye.fov = 95.0
		eye.far = 520.0
		add_child(eye)
	var r: Dictionary = rooms[i]
	var c := centre(i)
	var l := float(r.get("l", 40.0))
	var h := maxf(float(r.get("h", 0.0)), 8.0)
	for pose: Array in [[Vector3(0.0, 2.5, l * 0.5 - 3.0), Vector3(0.0, 2.0, 0.0)],
			[Vector3(0.0, h + 14.0, -l * 0.35), Vector3(0.0, 0.0, l * 0.1)]]:
		if not is_instance_valid(eye):
			return
		eye.make_current()
		eye.global_position = c + (pose[0] as Vector3)
		eye.look_at(c + (pose[1] as Vector3))
		await get_tree().process_frame
		await get_tree().process_frame
	if own:
		eye.queue_free()
		var hers := _hero_eye()
		if hers != null:
			hers.make_current()


func _keep_materials(under: Node) -> void:
	for node in under.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		_keep(g.material_override)
		_keep(g.material_overlay)
		var meshes: Array[Mesh] = []
		if g is MeshInstance3D:
			var mi := g as MeshInstance3D
			meshes.append(mi.mesh)
			for k in mi.get_surface_override_material_count():
				_keep(mi.get_surface_override_material(k))
		elif g is GPUParticles3D:
			var gp := g as GPUParticles3D
			_keep(gp.process_material)
			for k in gp.draw_passes:
				meshes.append(gp.get_draw_pass_mesh(k))
		for mesh in meshes:
			if mesh == null:
				continue
			for k in mesh.get_surface_count():
				_keep(mesh.surface_get_material(k))
			if mesh is PrimitiveMesh:
				_keep((mesh as PrimitiveMesh).material)


func _keep(m: Material) -> void:
	if m == null or not (m is BaseMaterial3D or m is ParticleProcessMaterial):
		return
	_kept[m.get_instance_id()] = m


## The camera the hero is seen through.
func _hero_eye() -> Camera3D:
	for hero in _heroes():
		if hero.is_multiplayer_authority() and hero.camera != null:
			return hero.camera
	return null


## The place left behind, and what is left of its creatures, taken down.
func _take_down(i: int) -> void:
	if i < _room_nodes.size() and is_instance_valid(_room_nodes[i]):
		_room_nodes[i].queue_free()
	if i < _room_foes.size():
		for body: Variant in _room_foes[i]:
			if is_instance_valid(body):
				(body as Node).queue_free()
		_room_foes[i] = []
	_alive.clear()
	_cloud_sea = null
	_cloud_layer_mats.clear()
	_reserve.clear()
	_rift_at = -1.0
	_rift_due = -1.0
	if is_instance_valid(_rift):
		_rift.queue_free()
	_rift = null
	if is_instance_valid(_goal):
		_goal.queue_free()
	_goal = null
	boons.clear_lights()
	var keep: Array[Dictionary] = []
	for col in _columns:
		if int(col["room"]) != i:
			keep.append(col)
	_columns = keep


func _close() -> void:
	is_closed = true
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method(&"close_portal"):
		game.call(&"close_portal", id)
	# Up to the dungeon's last level.
	var top := int(Portals.DEFS[id]["to"])
	for hero in _heroes():
		var book := hero.get_node_or_null("Leveling") as Leveling
		if book != null:
			book.raise_to(top)
	_say("%s დაიხურა!" % String(Portals.DEFS[id]["name"]), 4.0)
	# The way out, on the dais at the far end (made as he came in, hidden).
	if is_instance_valid(_exit_ready):
		_exit = _exit_ready
		_exit_ready = null
		_exit.visible = true
		_exit.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		_exit = _make_exit()
	closed.emit()


func _make_exit() -> PortalLook:
	var last := current
	var gate := PortalLook.new()
	gate.name = "WayOut"
	gate.tint = Portals.DEFS[id]["tint"]
	gate.position = centre(last) + Vector3(0.0, 0.0, -float(_room(last)["l"]) * 0.5 + 15.0)
	add_child(gate)
	return gate


func _watch_deaths(heroes: Array[Player]) -> void:
	for hero in heroes:
		if _watched.has(hero.get_instance_id()):
			continue
		_watched[hero.get_instance_id()] = true
		hero.died.connect(_on_hero_died.bind(hero))
		# Here a hero gets up only when his place is cleared, or by the gate outside.
		hero.set(&"respawn_time", 9999.0)


func _on_hero_died(fallen: Player) -> void:
	# The second breath, if he has it: up again where he fell, half himself.
	if boons != null and boons.save_from_death(fallen):
		get_tree().create_timer(1.4).timeout.connect(_second_breath.bind(fallen))
		return
	# Alone (or all of them down): back out by the gate.
	for hero in _heroes():
		if not hero.is_dead:
			return
	_say("დამარცხდი", BACK_OUT_AFTER)
	# beaten by the lord: he remembers it ([LordFight])
	if is_instance_valid(_lord_fight) and _woken and not _lord_fight.won:
		var game := get_node_or_null("/root/Game")
		if game != null and game.has_method(&"beaten_by_lord"):
			game.call(&"beaten_by_lord")
		_lord_fight.speak(LordFight.gloat())
	# the run's summary up, and he goes back when he says so (the user's
	# word, 2026-10-21: a button to rise in the village, the numbers to look
	# at till then); no run (a room looked round): out after a moment
	if end_run(false) == null:
		_back_out_at = Time.get_ticks_msec() / 1000.0 + BACK_OUT_AFTER


## Straight into `place` to look round it (the user's word, 2026-10-21: to
## see every room and say what to change; F1's "Rooms", [ArenaPanel]): built
## in its light, him at its door, no portals; its creatures only if `with_foes`
## (then they wake and fight as in the run).
func view_place(place: String, with_foes: bool = false) -> void:
	if not PLACES.has(place) or _going:
		return
	_viewing = true
	var step := int(VIEW.get(place, [1])[0])
	for ch in choices:
		ch.queue_free()
	choices.clear()
	if is_instance_valid(_exit):
		_exit.queue_free()
	_exit = null
	_take_down(current)
	cleared[step] = false
	_arrive_at(step, place, "", false, "")
	for gate in _ready_choices:
		if is_instance_valid(gate):
			gate.queue_free()
	_ready_choices.clear()
	if not with_foes:
		for body: Variant in _room_foes[step]:
			if is_instance_valid(body):
				(body as Node).queue_free()
		_room_foes[step] = []
		# (and no king to rise in an empty crypt)
		if is_instance_valid(_king):
			_king.queue_free()
		_king = null
		_reserve.clear()
		_alive.clear()
		# nothing to wake, nothing to clear: no portals come
		_woken = true
		cleared[step] = true
	_to_phase(light_of(step), 0.05)
	var slot := 0
	for hero in _heroes():
		hero.global_position = entry_point(slot, step)
		hero.velocity = Vector3.ZERO
		slot += 1
	_say(String(PLACES[place]["name"]), 3.0)


## Up again where he fell, with half his health (the blessing "მეორე სუნთქვა").
func _second_breath(hero: Player) -> void:
	if not is_instance_valid(hero) or not hero.is_dead:
		return
	var at := hero.global_position
	hero.call(&"_respawn")
	hero.global_position = at
	hero.health = hero.max_health * 0.5
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, at + Vector3.UP, Boons.ALL[&"second"]["tint"], 80, Vector2(2.0, 6.0), Vector3.UP, 180.0,
				Vector2(0.05, 0.14), Vector3(0, -1.0, 0), 1.2)
	_say("მეორე სუნთქვა!", 2.5)


## Back to the open world, by the gate this dungeon is behind.
func leave() -> void:
	# with others: everyone goes back together, when the host says
	if online():
		_net().call("travel", Portals.WORLD, {"portal_return": id, "dungeon_id": -1})
		return
	set_process(false)
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.set(&"portal_return", id)
		game.set(&"dungeon_id", -1)
	SceneLoader.go(get_tree(), Portals.WORLD)


## The music for now ([World] asks): the boss's while its place is fought,
## otherwise the dungeon's.
func music_wanted() -> StringName:
	if is_boss(current) and not is_closed and not cleared[current]:
		return &"dungeon_boss"
	return &"dungeon"


func _heroes() -> Array[Player]:
	var out: Array[Player] = []
	for node in get_tree().get_nodes_in_group(&"player"):
		var body := node as Player
		if body != null:
			out.append(body)
	return out


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_flicker_fires(now)
	if not _going:
		_usual_ms = lerpf(_usual_ms, minf(delta * 1000.0, 100.0), 0.05)
	if _banner != null and _banner.visible and now > _banner_until:
		_banner.hide()
	var heroes := _heroes()
	_watch_deaths(heroes)
	for hero in heroes:
		boons.watch_hero(hero)
	if _back_out_at > 0.0 and now >= _back_out_at:
		_back_out_at = -1.0
		leave()
		return
	if _going:
		return
	if not decides():
		_as_client(heroes)
		_now_and_then(delta, heroes)
		_fly_birds(delta)
		return
	# The place wakes a moment after he comes (the first, when he is in it) —
	# with others, once all of them have come into the dungeon.
	if not _woken and current >= 0 and bool(_net().call("everyone_in") if _net() != null else true):
		if _wake_at < 0.0:
			for hero in heroes:
				if not hero.is_dead and room_at(hero.global_position) == current:
					_wake_at = now + WAKE_AFTER
		elif now >= _wake_at:
			_wake_at = -1.0
			_wake(current)
	if _woken and not cleared[current]:
		var goal := _goal if is_instance_valid(_goal) else null
		if goal != null:
			goal.tick(delta)
		var left := 0
		for body in _alive:
			if is_instance_valid(body) and not bool(body.get("is_dead")):
				left += 1
		if goal != null and goal.takes_waves():
			if left == 0 and goal.may_clear():
				_clear(current)
		elif left == 0 and _spawned > 0:
			var coming := 0
			for body in _reserve:
				if is_instance_valid(body) and not bool(body.get("is_dead")):
					coming += 1
			if coming == 0 and is_instance_valid(_king) and not _king_up:
				# the crypt's last: the stone king rises from his throne
				if decides():
					_king_rise()
					if online():
						net_king_rise.rpc()
			elif coming == 0:
				if goal == null or goal.may_clear():
					_clear(current)
				elif now >= _goal_nag:
					_goal_nag = now + 8.0
					_say("დაანგრიე ტოტემები!", 2.5)
			elif _rift_at < 0.0:
				if _rift_due < 0.0:
					_rift_due = now + RIFT_DUE
				elif now >= _rift_due:
					_rift_due = -1.0
					_open_rift()
			elif now >= _rift_at and not _rift_out:
				_next_wave()
	_crowd_clock -= delta
	if _crowd_clock <= 0.0:
		_crowd_clock = 0.2
		var standing: Array[Player] = []
		for hero in heroes:
			if not hero.is_dead:
				standing.append(hero)
		_lead_orcs(standing)
		_hold_back_crowd(heroes)
	_now_and_then(delta, heroes)
	_fly_birds(delta)
	for k in choices.size():
		for hero in heroes:
			var gap := hero.global_position - choices[k].global_position
			if not hero.is_dead and Vector2(gap.x, gap.z).length() < 1.8 and absf(gap.y) < 3.0:
				take(k)
				return
	if _exit != null:
		for hero in heroes:
			var gap := hero.global_position - _exit.global_position
			gap.y = 0.0
			if not hero.is_dead and gap.length() < 2.2:
				leave()
				return


## [constant PHOTO]'s textures, loaded once.
var _photo: Dictionary = {}


## The forest's and the swamp's ground, the land's photographed one in it.
func _ground_mat() -> ShaderMaterial:
	return DungeonLook._ground_mat(self)


func _materials() -> void:
	DungeonLook._materials(self)


## Room `i`'s floor: big slabs in the halls, smaller flags under the sky,
## cobbles along the walls (and up the throne room's aisle), its wear.
func _floor_mat(i: int) -> ShaderMaterial:
	return DungeonLook._floor_mat(self, i)


## The light, room by room (the user's word, 2026-10-20: clouds, the day
## going down as he goes on, night at the boss with the moon and stars): sun
## height (degrees; below 0 it has set), its colour and strength, the sky's top,
## horizon and ground, the fill light's colour and strength, the haze, how much
## night (stars, the moon), how cloudy.
## (2026-10-23, the user's word: inside the portal the light and colours as
## out in the land, where everything is pleasant to look at, near and far:
## the land's own sun, sky, fill light and haze through the whole run; only
## the last steps go into a golden late afternoon, and the lord's court into
## a bright moonlit night that still shows a man as he is.)
const LAND_SUN := Color(1.0, 0.98, 0.95)
const PHASES := [
	{"elev": 45.0, "sun": LAND_SUN, "sun_e": 1.1, "top": Color(0.36, 0.50, 0.72),
			"hor": Color(0.70, 0.74, 0.76), "gnd": Color(0.21, 0.23, 0.19), "amb": Color(0.58, 0.64, 0.60),
			"amb_e": 1.9, "fog": Color(0.67, 0.71, 0.73), "night": 0.0, "cloud": 0.4},
	{"elev": 42.0, "sun": LAND_SUN, "sun_e": 1.1, "top": Color(0.36, 0.50, 0.72),
			"hor": Color(0.70, 0.74, 0.76), "gnd": Color(0.21, 0.23, 0.19), "amb": Color(0.58, 0.64, 0.60),
			"amb_e": 1.9, "fog": Color(0.67, 0.71, 0.73), "night": 0.0, "cloud": 0.45},
	{"elev": 36.0, "sun": Color(1.0, 0.95, 0.88), "sun_e": 1.1, "top": Color(0.35, 0.49, 0.71),
			"hor": Color(0.74, 0.75, 0.74), "gnd": Color(0.21, 0.22, 0.19), "amb": Color(0.60, 0.64, 0.60),
			"amb_e": 1.85, "fog": Color(0.69, 0.71, 0.72), "night": 0.0, "cloud": 0.45},
	{"elev": 22.0, "sun": Color(1.0, 0.88, 0.72), "sun_e": 1.1, "top": Color(0.33, 0.45, 0.68),
			"hor": Color(0.84, 0.76, 0.66), "gnd": Color(0.22, 0.21, 0.18), "amb": Color(0.62, 0.62, 0.58),
			"amb_e": 1.75, "fog": Color(0.74, 0.71, 0.68), "night": 0.0, "cloud": 0.5},
	{"elev": 40.0, "sun": Color(0.72, 0.80, 1.0), "sun_e": 0.75, "top": Color(0.05, 0.08, 0.18),
			"hor": Color(0.20, 0.25, 0.36), "gnd": Color(0.06, 0.07, 0.09), "amb": Color(0.52, 0.58, 0.70),
			"amb_e": 1.55, "fog": Color(0.24, 0.28, 0.36), "night": 1.0, "cloud": 0.35},
]

const SKY_SHADER := """
shader_type sky;
uniform vec4 top_col : source_color = vec4(0.2, 0.4, 0.7, 1.0);
uniform vec4 hor_col : source_color = vec4(0.8, 0.8, 0.74, 1.0);
uniform vec4 gnd_col : source_color = vec4(0.3, 0.28, 0.26, 1.0);
uniform vec4 sun_col : source_color = vec4(1.0, 0.9, 0.8, 1.0);
uniform float night = 0.0;
uniform float cloud = 0.5;
uniform float flash = 0.0;
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + 11.7; a *= 0.5; }
	return v;
}
void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 c = mix(hor_col.rgb, top_col.rgb, pow(clamp(y, 0.0, 1.0), 0.5));
	if (y < 0.0) { c = mix(hor_col.rgb, gnd_col.rgb, clamp(-y * 4.0, 0.0, 1.0)); }
	// Stars, at night, twinkling.
	if (night > 0.01 && y > 0.0) {
		vec3 q = d * 260.0;
		vec3 cell = floor(q);
		float h = hash3(cell);
		float star = step(0.986, h) * smoothstep(0.32, 0.0, length(fract(q) - 0.5));
		float tw = 0.65 + 0.35 * sin(TIME * (2.0 + h * 3.0) + h * 60.0);
		c += vec3(1.0, 0.95, 0.88) * star * tw * night * smoothstep(0.0, 0.25, y) * 2.2;
		// the Milky Way, faint
		float band = exp(-pow(dot(d, normalize(vec3(0.5, 0.2, -0.8))) * 3.2, 2.0));
		c += vec3(0.10, 0.10, 0.16) * band * fbm(d.xz * 9.0 + d.y * 4.0) * night;
	}
	// The sun, or at night the moon, and the glow round it.
	float sd = dot(d, LIGHT0_DIRECTION);
	if (LIGHT0_ENABLED) {
		float glow = pow(max(sd, 0.0), 48.0) * 0.6 + pow(max(sd, 0.0), 6.0) * 0.18;
		c += sun_col.rgb * glow * mix(1.0, 0.35, night);
		float size = mix(0.99965, 0.9993, night);
		float disc = smoothstep(size, size + 0.00012, sd);
		vec3 moon = vec3(0.92, 0.93, 1.0) * (0.8 + 0.25 * fbm(d.xy * 400.0)) * 1.6;
		c = mix(c, mix(sun_col.rgb * 8.0, moon, night), disc);
	}
	// Clouds on a high plane, drifting, lit on the side the light is.
	if (y > 0.0) {
		vec2 uv = d.xz / (y + 0.15) * 0.9 + vec2(TIME * 0.004, TIME * 0.0016);
		float n = fbm(uv * 1.4);
		float cov = smoothstep(1.0 - cloud, 1.0 - cloud + 0.28, n) * smoothstep(0.0, 0.18, y);
		vec3 l2 = normalize(vec3(LIGHT0_DIRECTION.x, 0.0001, LIGHT0_DIRECTION.z));
		float toward = clamp(0.5 + 0.5 * dot(normalize(vec3(d.x, 0.0001, d.z)), l2), 0.0, 1.0);
		vec3 lit = mix(hor_col.rgb * 1.15 + sun_col.rgb * 0.25, vec3(0.30, 0.33, 0.42), night);
		vec3 dark = mix(mix(top_col.rgb, hor_col.rgb, 0.5) * 0.7, vec3(0.04, 0.045, 0.07), night);
		vec3 cc = mix(dark, lit, clamp(n * 0.7 + toward * 0.5, 0.0, 1.0));
		cc += sun_col.rgb * pow(max(sd, 0.0), 12.0) * 0.6 * (1.0 - night);
		c = mix(c, cc, cov * 0.92);
	}
	COLOR = c + vec3(0.75, 0.8, 1.0) * flash * (0.4 + 0.6 * clamp(y + 0.3, 0.0, 1.0));
}
"""


## The sky (a shader of its own: clouds, stars, the moon), the light and the
## haze, set to the first room's afternoon.
func _sky() -> void:
	DungeonLook._sky(self)


## Over `seconds`, to the light of room `to`.
func _to_phase(to: float, seconds: float) -> void:
	DungeonLook._to_phase(self, to, seconds)


func _apply_phase(t: float) -> void:
	DungeonLook._apply_phase(self, t)


## Each place's own air over the day's (the user's word, 2026-10-20: the
## palace's and the cave's colours as Elden Ring's): the palace's halls in a
## golden haze, the light through them thick enough to see, Leyndell's warm
## pale stone; the cave a deep blue under the earth, its own mist, its
## crystals and flecks bright in it like the underground cities' starlight.
func _place_look(night: float = 0.0) -> void:
	DungeonLook._place_look(self, night)


## The rock in the two-hall cave's tunnel rolled away ([TwinCave]): as the
## second wave comes, or as the place is cleared (one wave only); every peer
## comes here by its own rift or clear.
func _open_twin_cave() -> void:
	if current < 0 or current >= rooms.size() or String(_room(current).get("kind", "")) != "twin_cave":
		return
	var room: Node3D = _room_nodes[current] if current < _room_nodes.size() else null
	TwinCave.open_way(self, room)


func _ashen_look(cave: bool = false) -> void:
	DungeonLook._ashen_look(self, cave)


## The lord's court on its cliff in the mist ([ThroneCourt]), over Ashen's
## light ([method _ashen_look]): open, the air pale and white far off so the
## far pillars of rock fade into it, the cliff's foot lost in the cloud, the
## sun low and soft from the side behind the cloud.
## `which`: "c" that; "a" the warlord's camp at a grey dusk, the sun low and
## orange under the cloud; "b" the royal court's golden afternoon, clear.
func _court_look(which: String = "c") -> void:
	DungeonLook._court_look(self, which)


func _build_room(i: int) -> void:
	DungeonBuild._build_room(self, i)


func _solid(parent: Node3D, mat: Material, size: Vector3, at: Vector3, block: bool = true) -> StaticBody3D:
	return DungeonBuild._solid(self, parent, mat, size, at, block)


func _deco(parent: Node3D, mat: Material, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	return DungeonBuild._deco(self, parent, mat, mesh, at)


## An invisible wall: only something to stop the heroes.
func _blocker(parent: Node3D, size: Vector3, at: Vector3) -> StaticBody3D:
	return DungeonBuild._blocker(self, parent, size, at)


func _wall_columns(room: Node3D, i: int, w: float, l: float, h: float, one_side: bool = false) -> void:
	DungeonBuild._wall_columns(self, room, i, w, l, h, one_side)


## What is seen from the open rooms: the v5 lands far below and round the
## palace, their mountains on the horizon ([PalaceVista]), and the crag the
## palace stands on going down to them.
func _vista() -> void:
	DungeonBuild._vista(self)


## Not all of them at once (the user's word, 2026-10-20: a band of puglins
## rolling together cannot be beaten; at most two at him, the rest throwing
## from off): `CROWD` a hero may be fought by at a time, an orc near him
## counting as one. The ones let at him keep their turn while they are near;
## the rest are held back ([member Fighter.held_back]): out of reach, throwing.
func _hold_back_crowd(heroes: Array[Player]) -> void:
	var standing: Array[Player] = []
	for hero in heroes:
		if not hero.is_dead:
			standing.append(hero)
	var small: Array = []
	var brutes: Array = []
	var shooters: Array = []
	var gunners: Array[Fighter] = []
	for body in _alive:
		if not is_instance_valid(body) or bool(body.get("is_dead")):
			continue
		if body is Flyer or SHOOTERS.has(String(body.scene_file_path)):
			shooters.append(body)
			# (they keep off by themselves: no place among those at him; but
			# each its own bearing round him, not all in a line)
			if not (body is Flyer):
				if body is Fighter:
					gunners.append(body)
				continue
		var gap := INF
		for hero in standing:
			gap = minf(gap, body.global_position.distance_to(hero.global_position))
		if body is PackBrute:
			if gap < 9.0 and not (body as PackBrute).held_back:
				brutes.append(body)
			continue
		# the shaman keeps back by itself ([FoeRoles]), and the flyers do
		if FoeRoles.role_of(body) == &"shaman" or body is Flyer:
			continue
		if "held_back" in body:
			small.append([gap, body])
	# Who has a turn at him now: by weight and the fight's pressure
	# ([CombatDirector]; the user's word, 2026-10-27: two at once, the one he
	# walks up to at once, now and then a third, one at most under fire).
	small.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var keep: Array[Node3D] = director.choose(small, _holders, standing, shooters, brutes)
	_holders = keep
	var waiting: Array[Fighter] = []
	for pair: Array in small:
		var held: bool = not keep.has(pair[1])
		(pair[1] as Node).set("held_back", held)
		if held:
			waiting.append(pair[1])
	_spread(waiting, standing)
	# the archers and mages: each its own side of him, some behind him
	for g in gunners:
		g.shoot_slot = true
	_spread(gunners, standing, SHOOT_RINGS)


## The ones held back, round each hero on `HOLD_RINGS` at even bearings (the
## user's word: no more than three in a place), each kept to the side of him
## it is on so none crosses another.
func _spread(waiting: Array[Fighter], standing: Array[Player], rings: Array = HOLD_RINGS) -> void:
	if standing.is_empty():
		return
	var by_hero := {}
	for body in waiting:
		# round the hero it is after (with others it may turn to the other);
		# none, the nearest
		var best: Player = director._whose(body, standing) if director != null else standing[0]
		if not by_hero.has(best):
			by_hero[best] = []
		var off := body.global_position - best.global_position
		(by_hero[best] as Array).append([atan2(off.x, off.z), body])
	for hero: Player in by_hero:
		var list: Array = by_hero[hero]
		list.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var n := list.size()
		var start := float(list[0][0])
		for k in n:
			var body: Fighter = list[k][1]
			body.held_angle = start + TAU * float(k) / float(n)
			body.held_radius = float(rings[k % rings.size()])


## Two orcs (or more) at one lone hero take turns (the user's word): one at
## him, the other off, waiting; a blow on the waiting one brings it in and
## sends the other off, and every so often they change over by themselves.
## With more heroes they fight as they would.
func _lead_orcs(standing: Array[Player]) -> void:
	var orcs: Array[PackBrute] = []
	for body in _alive:
		if not is_instance_valid(body):
			continue
		var o := body as PackBrute
		if o != null and not o.is_dead:
			orcs.append(o)
	if orcs.size() < 2 or standing.size() != 1:
		for o in orcs:
			o.turn_led = false
			o.held_back = false
		_orc_on = null
		return
	var now := Time.get_ticks_msec() / 1000.0
	var on := _orc_on as PackBrute
	if on == null or not orcs.has(on):
		on = orcs[0]
		_orc_since = now
		_orc_hand_over = randf_range(14.0, 22.0)
	# A blow on one that waits: its turn now.
	for o in orcs:
		var was := float(_orc_health.get(o, o.health))
		if o != on and o.health < was - 0.01:
			on = o
			_orc_since = now
			_orc_hand_over = randf_range(14.0, 22.0)
		_orc_health[o] = o.health
	if now - _orc_since > _orc_hand_over and on.act == Fighter.Act.NONE:
		on = orcs[(orcs.find(on) + 1) % orcs.size()]
		_orc_since = now
		_orc_hand_over = randf_range(14.0, 22.0)
	_orc_on = on
	for o in orcs:
		o.turn_led = true
		o.held_back = o != on


## Every peer: an orc's heavy blow has cracked the floor at `at` (called by
## [OrcFighter] through the "ground_scars" group). The crack stays, stone is
## thrown up round it, and a column near enough comes down.
func scar(at: Vector3, weight: float) -> void:
	if room_at(at) < 0:
		return
	_scars += 1
	Sfx.play(self, SND + "crumble.wav", null, at, randf_range(0.9, 1.1), -3.0 + 4.0 * weight)
	var crack := DarkFx.decal(self, at, DarkFx.CRACK, 2.2 + 1.8 * weight, Color(0.07, 0.06, 0.05, 1.0), 0.0, 0.95)
	crack.rotation.y = randf() * TAU
	_rubble(self, at - global_position, 0.6 + 0.8 * weight, int(3 + 5 * weight), _scars * 31)
	if weight < 0.6:
		return
	for col in _columns:
		if bool(col["broken"]):
			continue
		var c: Vector3 = col["at"]
		if Vector2(c.x - at.x, c.z - at.z).length() < float(col["thick"]) + 2.2 * weight:
			_topple(col, at)
			break


## A column brought down: a stump stands, its drums lie where it fell.
func _topple(col: Dictionary, from: Vector3) -> void:
	col["broken"] = true
	Sfx.play(self, SND + "thud.wav", null, col["at"], randf_range(0.9, 1.05), 4.0)
	for part: MeshInstance3D in col["parts"]:
		part.visible = false
	var blocker: StaticBody3D = col["blocker"]
	if is_instance_valid(blocker):
		blocker.queue_free()
	var room: Node3D = col["node"]
	var at: Vector3 = col["local"]
	var thick: float = col["thick"]
	var stump := CylinderMesh.new()
	stump.top_radius = thick * 0.66
	stump.bottom_radius = thick * 0.7
	stump.height = 2.2
	stump.radial_segments = 14
	_deco(room, _wall_mat, stump, at + Vector3(0.0, 1.1, 0.0))
	_blocker(room, Vector3(thick * 1.3, 2.2, thick * 1.3), at + Vector3(0.0, 1.1, 0.0))
	var away := (col["at"] as Vector3) - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var h: float = col["h"]
	var drums := 3
	for k in drums:
		var drum := CylinderMesh.new()
		drum.top_radius = thick * 0.64
		drum.bottom_radius = thick * 0.64
		drum.height = (h - 3.0) / float(drums)
		drum.radial_segments = 14
		var where := at + away * (2.4 + float(k) * (drum.height + 0.3)) + Vector3(0.0, thick * 0.64, 0.0)
		var d := _deco(room, _wall_mat, drum, where)
		d.rotation = Vector3(PI * 0.5, atan2(away.x, away.z), randf_range(-0.2, 0.2))
	var world := Blood.world_of(self)
	if world != null:
		SkillFx.burst(world, (col["at"] as Vector3) + Vector3.UP * 2.0, Color(0.5, 0.45, 0.4, 0.6), 40,
				Vector2(1.5, 5.0), Vector3.UP, 80.0, Vector2(0.12, 0.3), Vector3(0, -2.0, 0), 1.6)


## Broken stone in a heap at `at` (in `parent`'s frame): `size` across, `count` pieces.
func _rubble(parent: Node3D, at: Vector3, size: float, count: int, seed_n: int) -> void:
	DungeonBuild._rubble(self, parent, at, size, count, seed_n)


## Heaps along the walls and in the corners, where the palace has begun to come down.
func _rubble_round(room: Node3D, i: int, w: float, l: float) -> void:
	DungeonBuild._rubble_round(self, room, i, w, l)


## Dust hanging in the air of a room, lit where the light is.
func _motes(room: Node3D, w: float, l: float, h: float) -> void:
	DungeonBuild._motes(self, room, w, l, h)


## A fire (the user's word, 2026-10-20: the palace's fires prettier): a flame
## drawn whole by a shader, its tongues licking up and tearing off, white-gold
## at its root and dark red at its tips, sparks going up from it. Its light
## flickers ([method _fire_light]).
func _flame(at: Vector3, size: float, amount: int) -> Node3D:
	return DungeonBuild._flame(self, at, size, amount)


## Sparks going up from a fire, swirling, dying out.
func _embers(size: float, amount: int) -> GPUParticles3D:
	return DungeonBuild._embers(self, size, amount)


## A fire's light, flickering with it ([method _flicker_fires]).
func _fire_light(light: OmniLight3D) -> OmniLight3D:
	return DungeonBuild._fire_light(self, light)


func _flicker_fires(now: float) -> void:
	var k := 0
	while k < _fire_lights.size():
		var f: Dictionary = _fire_lights[k]
		var obj: Variant = f["light"]
		if not is_instance_valid(obj):
			_fire_lights.remove_at(k)
			continue
		var light := obj as OmniLight3D
		if light.is_visible_in_tree():
			var t := now + float(f["at"])
			light.light_energy = float(f["base"]) * (0.86 + 0.07 * sin(t * 7.3) + 0.05 * sin(t * 13.7 + 1.3)
					+ 0.03 * sin(t * 23.1 + 2.1))
		k += 1


func _torch(room: Node3D, at: Vector3) -> void:
	DungeonBuild._torch(self, room, at)


func _build_hud() -> void:
	DungeonHud._build_hud(self)


var _map: Control


func _say(text: String, seconds: float) -> void:
	DungeonHud._say(self, text, seconds)


## The dungeon's own bus, its echo after the place (a hall rings, a cave
## more, the open air hardly), the world's sounds sent through it ([Sfx]).
func _sound_bus() -> void:
	DungeonSound._sound_bus(self)


## A sound that goes round and round.
func _loop(file: String) -> AudioStream:
	return DungeonSound._loop(self, file)


## The place's own sound (wind through the windows, the cave's breath, birds
## or by night nothing but the wind), and its echo.
func _ambience(i: int) -> void:
	DungeonSound._ambience(self, i)


## The sounds that come now and then: drips in the cave and the broken hall,
## thunder far off once the day goes, an owl in the forest at night.
func _now_and_then(delta: float, heroes: Array[Player]) -> void:
	DungeonSound._now_and_then(self, delta, heroes)


## A fire's crackle where it burns, heard close by.
func _crackle(holder: Node3D, at: Vector3) -> void:
	DungeonSound._crackle(self, holder, at)


## A model of the forest kit (assets/forest), loaded once.
func _kit(name: String) -> Mesh:
	return DungeonBuild._kit(self, name)


## A kit model in `room` at `at`, `tall` metres high, turned `yaw`.
func _prop(room: Node3D, name: String, at: Vector3, tall: float, yaw: float, shadow: bool = true) -> MeshInstance3D:
	return DungeonBuild._prop(self, room, name, at, tall, yaw, shadow)


## A trunk nobody walks through.
func _post(room: Node3D, at: Vector3, radius: float, tall: float) -> void:
	DungeonBuild._post(self, room, at, radius, tall)


## Unseen walls round a place without walls of its own.
func _bounds(room: Node3D, w: float, l: float) -> void:
	DungeonBuild._bounds(self, room, w, l)


## Great rocks under a place's footprint, down into the lands far below.
func _crag_under(room: Node3D, w: float, l: float, depth: float, top: float = -1.0) -> void:
	DungeonBuild._crag_under(self, room, w, l, depth, top)


## A rock of `size` (x, y, z metres) at `at`, turned `yaw`, in `mat`.
func _boulder(room: Node3D, at: Vector3, size: Vector3, yaw: float, mat: Material, shadow: bool = true,
		solid: bool = true) -> MeshInstance3D:
	return DungeonBuild._boulder(self, room, at, size, yaw, mat, shadow, solid)


## Each rock shape's hull, made once.
var _hulls: Dictionary = {}


## A rock turned upside down under something, its top at `top` (its own
## frame's height), hanging down from there.
func _hang(rock: MeshInstance3D, top: float) -> void:
	DungeonBuild._hang(self, rock, top)


## A sharpened stake driven into the earth, leaning, a skull on it if `skull`.
func _stake(room: Node3D, at: Vector3, skull: bool) -> void:
	DungeonBuild._stake(self, room, at, skull)


## Fireflies over the clearing (seen once it grows dark).
func _fireflies(room: Node3D, w: float, l: float) -> void:
	DungeonBuild._fireflies(self, room, w, l)


const COALS_SHADER := """
shader_type spatial;
// A brazier's bed of coals: black lumps, the gaps between them glowing and
// breathing, brighter in the middle under the flame.
varying vec3 lpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float cells(vec2 p) {
	vec2 n = floor(p); vec2 f = fract(p);
	float m1 = 8.0; float m2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash(n + g), hash(n + g + 7.3));
			float d = length(g + o - f);
			if (d < m1) { m2 = m1; m1 = d; } else if (d < m2) { m2 = d; }
		}
	}
	return m2 - m1;
}
void vertex() { lpos = VERTEX; }
void fragment() {
	vec2 p = lpos.xz * 9.0;
	float gap = 1.0 - smoothstep(0.0, 0.22, cells(p));
	float breathe = 0.6 + 0.4 * noise(p * 0.5 + vec2(TIME * 0.7, -TIME * 0.4));
	float mid = 1.0 - smoothstep(0.0, 0.5, length(lpos.xz));
	float glow = gap * breathe * (0.5 + 0.8 * mid) + mid * 0.25 * breathe;
	ALBEDO = vec3(0.05, 0.04, 0.035) * (0.6 + 0.8 * hash(floor(p)));
	ROUGHNESS = 0.95;
	EMISSION = mix(vec3(0.8, 0.12, 0.02), vec3(1.0, 0.5, 0.12), glow) * glow * 2.6;
}
"""

const FLAME_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// A flame (the user's word, 2026-10-20: prettier fires): turned always to the
// eye about its own upright, tongues of it licking up through moving noise and
// tearing off at the top, hottest low in its middle. Each fire its own by where
// it stands.
varying float seed;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p = p * 2.1 + 1.3; a *= 0.5; }
	return v;
}
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	seed = fract(sin(dot(o, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 50.0;
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
	vec3 face = normalize(cross(side, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * length(MODEL_MATRIX[0].xyz), 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(face, 0.0), vec4(o, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	float y = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME + seed;
	float n = fbm(vec2(x * 1.7 + seed, y * 2.3 - t * 2.0));
	float m = fbm(vec2(x * 3.6 - seed * 0.5, y * 4.6 - t * 3.3));
	float sway = (noise(vec2(t * 0.8, seed)) - 0.5) * 0.45 * y * y;
	float xx = x + (n - 0.5) * 0.6 * y + sway;
	float width = 0.8 * pow(max(1.0 - y, 0.0), 0.65) * smoothstep(-0.04, 0.2, y) + 0.04;
	float body = 1.0 - smoothstep(width * 0.3, width, abs(xx));
	float tear = smoothstep(0.12, 0.5, m * 1.3 - y * 0.95 + 0.38);
	float heat = body * tear * smoothstep(0.0, 0.07, y);
	float core = body * (1.0 - smoothstep(0.05, 0.5, y + abs(xx) * 1.5));
	float h = clamp(heat * (0.5 + 0.7 * (1.0 - y)) + core * 0.7, 0.0, 1.6);
	vec3 c = mix(vec3(0.5, 0.05, 0.01), vec3(1.0, 0.34, 0.05), smoothstep(0.04, 0.4, h));
	c = mix(c, vec3(1.0, 0.68, 0.22), smoothstep(0.4, 0.8, h));
	c = mix(c, vec3(1.0, 0.86, 0.6), smoothstep(1.0, 1.45, h));
	ALBEDO = c * 1.7;
	ALPHA = clamp(h * 1.15, 0.0, 1.0);
}
"""

const ROCK_SHADER := """
shader_type spatial;
// Rock as it is (the user's word, 2026-10-20: the cave's textures prettier):
// laid down in strata, cracked, flecked with what glitters, moss and damp in
// its hollows and low down, its face broken by its own relief. All in the
// world's frame, so any rock of any size takes it.
uniform vec4 rock_a : source_color = vec4(0.36, 0.32, 0.29, 1.0);
uniform vec4 rock_b : source_color = vec4(0.22, 0.20, 0.20, 1.0);
uniform vec4 band : source_color = vec4(0.46, 0.38, 0.31, 1.0);
uniform vec4 moss : source_color = vec4(0.16, 0.22, 0.10, 1.0);
uniform vec4 fleck : source_color = vec4(0.75, 0.6, 1.0, 1.0);
uniform float scale = 0.35;
uniform float wet = 0.4;
uniform float moss_amount = 0.5;
uniform float fleck_glow = 0.0;
// The land's photographed rock over the drawn one (the user's word,
// 2026-10-23), laid on from the three sides; its grain, the rock's colour.
uniform float photo = 0.0;
uniform sampler2D photo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float photo_tile = 4.0;
varying vec3 wpos;
varying vec3 wnorm;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}
float fbm(vec3 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + 3.1; a *= 0.5; }
	return v;
}
float cells(vec3 p) {
	vec3 n = floor(p); vec3 f = fract(p);
	float m1 = 8.0; float m2 = 8.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				vec3 o = vec3(hash(n + g), hash(n + g + 7.3), hash(n + g + 13.1));
				float d = length(g + o - f);
				if (d < m1) { m2 = m1; m1 = d; } else if (d < m2) { m2 = d; }
			}
		}
	}
	return m2 - m1;
}
float height(vec3 p) {
	vec3 q = p * scale * 2.2;
	return noise(q) * 0.55 + noise(q * 2.3 + 1.7) * 0.3 + noise(q * 5.1 + 4.2) * 0.15;
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 p = wpos;
	float n = fbm(p * scale);
	// strata: bands along the height, wavering
	float s = sin((p.y + fbm(p * scale * 0.5) * 6.0) * 1.3) * 0.5 + 0.5;
	vec3 c = mix(rock_b.rgb, rock_a.rgb, n);
	c = mix(c, band.rgb * (0.8 + 0.4 * n), smoothstep(0.8, 0.97, s) * 0.3);
	// cracks
	float cr = 1.0 - smoothstep(0.0, 0.025, cells(p * scale * 0.7));
	c *= 1.0 - cr * 0.4 * smoothstep(0.35, 0.6, fbm(p * scale * 0.3 + 9.0));
	// moss and damp where it faces up and low down
	float up = clamp(wnorm.y, 0.0, 1.0);
	float m = smoothstep(0.45, 0.75, fbm(p * scale * 1.7 + 5.0)) * (0.4 + 0.6 * up) * moss_amount;
	c = mix(c, moss.rgb * (0.7 + 0.5 * n), m);
	if (photo > 0.0) {
		vec3 bw = pow(abs(wnorm), vec3(4.0));
		bw /= (bw.x + bw.y + bw.z);
		vec3 tq = p / photo_tile;
		vec3 t = texture(photo_tex, tq.zy).rgb * bw.x + texture(photo_tex, tq.xz).rgb * bw.y
				+ texture(photo_tex, tq.xy).rgb * bw.z;
		c *= mix(1.0, clamp(dot(t, vec3(0.2126, 0.7152, 0.0722)) / 0.11, 0.4, 1.9), photo);
	}
	// flecks that catch the light (and in the cave, glow faintly)
	float fl = step(0.985, hash(floor(p * 9.0)));
	ALBEDO = mix(c, fleck.rgb, fl * 0.6);
	EMISSION = fleck.rgb * fl * fleck_glow;
	ROUGHNESS = mix(0.95, 0.35, max(fl, wet * 0.5));
	// its relief, from its own height field
	float e = 0.06;
	float h0 = height(p);
	vec3 g = vec3(height(p + vec3(e, 0, 0)) - h0, height(p + vec3(0, e, 0)) - h0, height(p + vec3(0, 0, e)) - h0) / e;
	vec3 nw = normalize(wnorm - (g - wnorm * dot(g, wnorm)) * 0.35);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
"""

const CLOUD_LAYER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// One layer of the sea of cloud under the island: soft, broken, drifting, lit
// with the day, fading out far off so it has no edge.
uniform vec4 top : source_color = vec4(1.0, 0.96, 0.92, 1.0);
uniform vec4 low : source_color = vec4(0.6, 0.62, 0.72, 1.0);
uniform float cover = 0.5;
uniform float seed = 0.0;
uniform float opacity = 0.85;
uniform vec2 middle = vec2(0.0);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 6; i++) { v += a * noise(p); p = p * 2.02 + 1.7; a *= 0.5; }
	return v;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.008 + vec2(seed, seed * 0.7) + vec2(TIME * 0.003, TIME * 0.0012);
	float n = fbm(p);
	float body = smoothstep(1.0 - cover, 1.0 - cover + 0.22, n);
	float far = length(wpos.xz - middle);
	float fade = 1.0 - smoothstep(500.0, 1200.0, far);
	ALBEDO = mix(low.rgb, top.rgb, smoothstep(0.4, 0.9, n + 0.15));
	ALPHA = body * fade * opacity;
}
"""


## A model of the nature kit in glTF/ (the stylized trees, bushes, ferns,
## flowers, grass, rocks: the user's word, 2026-10-20, our own pretty
## low-poly trees), `scale` times its own size, turned `yaw`.
func _nature(room: Node3D, name: String, at: Vector3, scale: float, yaw: float, shadow: bool = true,
		bare: bool = false) -> Node3D:
	return DungeonBuild._nature(self, room, name, at, scale, yaw, shadow, bare)


## The sea of cloud under the island: soft layers one over another.
func _cloud_layers(room: Node3D, base: float = -78.0) -> void:
	DungeonBuild._cloud_layers(self, room, base)


#region More to see (round 7)
const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 deep : source_color = vec4(0.03, 0.16, 0.26, 1.0);
uniform vec4 shallow : source_color = vec4(0.14, 0.40, 0.50, 1.0);
uniform float flow = 0.8;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.9 + vec2(0.0, TIME * flow);
	float a = noise(p * 1.7);
	float b = noise(p * 4.3 + 7.0 - vec2(TIME * 0.3, 0.0));
	float edge = abs(UV.x - 0.5) * 2.0;
	ALBEDO = mix(deep.rgb, shallow.rgb, edge * 0.7 + a * 0.3);
	float foam = smoothstep(0.78, 0.95, b) * 0.5 + smoothstep(0.8, 1.0, edge) * 0.4;
	ALBEDO = mix(ALBEDO, vec3(0.85, 0.9, 0.9), foam);
	vec3 nw = normalize(vec3((a - 0.5) * 0.6, 1.0, (b - 0.5) * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = 0.16;
	SPECULAR = 0.35;
}
"""

const MIST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.9, 0.92, 0.95, 1.0);
uniform float thick = 0.35;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
// Soft where it meets anything (the user's word, 2026-10-21: a line drawn
// across the hero where the mist's sheet cut him): it fades out over a metre
// and a half before whatever stands in it, and near the eye.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.06 + vec2(TIME * 0.01, TIME * 0.004);
	float n = noise(p) * 0.6 + noise(p * 2.7) * 0.4;
	float d = clamp(1.0 - length(UV - 0.5) * 2.0, 0.0, 1.0);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float soft = clamp((VERTEX.z - behind.z) / 1.6, 0.0, 1.0);
	float near = clamp((-VERTEX.z - 1.0) / 6.0, 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = smoothstep(0.25, 0.85, n) * smoothstep(0.0, 0.7, d) * thick * soft * near;
}
"""


## A flock of bats out of the dark of the roof, gone again.
func _bat_flock(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 2.6
	p.one_shot = true
	p.explosiveness = 0.85
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.5
	pm.direction = Vector3(_rng.randf_range(-1.0, 1.0), -0.2, _rng.randf_range(-1.0, 1.0)).normalized()
	pm.spread = 50.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.5
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.2)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.03, 0.025, 0.03)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(3.5).timeout.connect(p.queue_free)


## A stream across the forest's clearing, stepping stones over it, its sound.
func _stream(room: Node3D, w: float, l: float) -> void:
	DungeonBuild._stream(self, room, w, l)


## Mist lying low over the ground, drifting.
func _mist(room: Node3D, w: float, l: float, y: float, tint: Color, thick: float, count: int = 10) -> void:
	DungeonBuild._mist(self, room, w, l, y, tint, thick, count)


## Some of a cave's mushrooms give a light of their own.
func _glow(m: MeshInstance3D, tint: Color) -> void:
	DungeonBuild._glow(self, m, tint)


## Birds circling the island, far off and near.
func _circling_birds(room: Node3D) -> void:
	DungeonBuild._circling_birds(self, room)


func _fly_birds(delta: float) -> void:
	for b in _birds:
		# checked before the cast: a cast of a freed bird is an error each
		# frame (a place's birds outlive it till the next arrival clears them)
		if not is_instance_valid(b["node"]):
			continue
		var node := b["node"] as Node3D
		b["at"] = float(b["at"]) + float(b["speed"]) * delta
		var a: float = b["at"]
		var r: float = b["radius"]
		node.position = Vector3(sin(a) * r, float(b["height"]) + sin(a * 3.0) * 2.0, cos(a) * r)
		node.rotation.y = a + (PI * 0.5 if float(b["speed"]) > 0.0 else -PI * 0.5)
		var flap := sin(Time.get_ticks_msec() / 1000.0 * 7.0 + r) * 0.5
		(node.get_node("L") as Node3D).rotation.z = flap
		(node.get_node("R") as Node3D).rotation.z = -flap


## The graveyard kit's props (assets/necropoly: candles, chains, lanterns, the
## tomb niche, the swamp's grass, roots and stones), dressed as [NecroPlaces]
## dresses them: its palette, and a glow for what burns.
func _necro(name: String) -> Mesh:
	return DungeonBuild._necro(self, name)


func _necro_put(room: Node3D, name: String, at: Vector3, yaw: float, size: float = 1.0, shadow: bool = true) -> MeshInstance3D:
	return DungeonBuild._necro_put(self, room, name, at, yaw, size, shadow)


## A cluster of candles burning, with the little light they give.
func _candles(room: Node3D, at: Vector3, light: bool = true) -> void:
	DungeonBuild._candles(self, room, at, light)


## Old bones lying: a few long ones and a skull.
func _bones(room: Node3D, at: Vector3) -> void:
	DungeonBuild._bones(self, room, at)


## A flash of lightning over a stormy place, its thunder after it.
func _lightning() -> void:
	if _sky_mat == null:
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _sky_mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.05)
	tw.tween_method(func(v: float) -> void: _sky_mat.set_shader_parameter("flash", v), 1.0, 0.2, 0.12)
	tw.tween_method(func(v: float) -> void: _sky_mat.set_shader_parameter("flash", v), 0.2, 0.9, 0.06)
	tw.tween_method(func(v: float) -> void: _sky_mat.set_shader_parameter("flash", v), 0.9, 0.0, 0.4)
	var bolt := OmniLight3D.new()
	bolt.light_color = Color(0.8, 0.85, 1.0)
	bolt.light_energy = 0.0
	bolt.omni_range = 220.0
	bolt.shadow_enabled = false
	add_child(bolt)
	bolt.global_position = centre(current) + Vector3(_rng.randf_range(-40.0, 40.0), 70.0, _rng.randf_range(-40.0, 40.0))
	var lt := create_tween()
	lt.tween_property(bolt, "light_energy", 6.0, 0.05)
	lt.tween_property(bolt, "light_energy", 1.0, 0.12)
	lt.tween_property(bolt, "light_energy", 5.0, 0.06)
	lt.tween_property(bolt, "light_energy", 0.0, 0.4)
	lt.tween_callback(bolt.queue_free)
	get_tree().create_timer(_rng.randf_range(0.4, 1.4)).timeout.connect(func() -> void:
		Sfx.play_flat(self, SND + "thunder.wav", _rng.randf_range(0.9, 1.15), -2.0))
#endregion


## Now and then a few stones and dust come down from a hall's roof near him.
func _falling_stones(near: Vector3, h: float) -> void:
	var world := Blood.world_of(self)
	if world == null:
		return
	var at := near + Vector3(_rng.randf_range(-9.0, 9.0), 0.0, _rng.randf_range(-9.0, 9.0))
	at.y = centre(current).y
	for k in _rng.randi_range(2, 5):
		var stone := MeshInstance3D.new()
		stone.mesh = RockWave._crag_mesh(_rng.randi_range(0, RockWave.SHAPES - 1))
		var box := stone.mesh.get_aabb()
		var size := _rng.randf_range(0.12, 0.3)
		stone.scale = Vector3.ONE * size / maxf(box.size.x, 0.01)
		stone.material_override = _rock_mat
		world.add_child(stone)
		var from := at + Vector3(_rng.randf_range(-0.8, 0.8), h - 0.5, _rng.randf_range(-0.8, 0.8))
		stone.global_position = from
		var fall := sqrt(2.0 * (h - 0.5) / 9.8) * _rng.randf_range(0.95, 1.1)
		var tw := create_tween()
		tw.tween_property(stone, "global_position:y", at.y + 0.1, fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(stone, "rotation", Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0)), fall)
		tw.tween_interval(6.0)
		tw.tween_callback(stone.queue_free)
	SkillFx.burst(world, at + Vector3.UP * (h - 0.5), Color(0.7, 0.62, 0.5, 0.6), 30, Vector2(0.2, 1.0), Vector3.DOWN,
			40.0, Vector2(0.08, 0.2), Vector3(0, -3.0, 0), 2.5)
	var land := sqrt(2.0 * (h - 0.5) / 9.8)
	get_tree().create_timer(land).timeout.connect(func() -> void:
		DustRing.burst(world, at + Vector3.UP * 0.05, 0.5)
		Sfx.play(self, SND + "crumble.wav", null, at, _rng.randf_range(1.2, 1.5), -12.0))


## A blow on one of them seen: a warm flash where it struck and a few sparks.
func _on_foe_hurt(_remaining: float, body: Node3D) -> void:
	if not is_instance_valid(body):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(body.get_meta(&"flashed", -1.0)) < 0.1:
		return
	body.set_meta(&"flashed", now)
	var world := Blood.world_of(self)
	if world == null:
		return
	var at := body.global_position + Vector3.UP * 1.1 * maxf(float(body.get("visual_scale")) if "visual_scale" in body else 1.0, 0.5)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.78, 0.45)
	flash.light_energy = 3.5
	flash.omni_range = 4.5
	world.add_child(flash)
	flash.global_position = at
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.16)
	tw.tween_callback(flash.queue_free)
	SkillFx.burst(world, at, Color(1.0, 0.8, 0.4), 14, Vector2(2.0, 5.0), Vector3.UP, 180.0, Vector2(0.03, 0.07),
			Vector3(0, -6.0, 0), 0.35)
#endregion

