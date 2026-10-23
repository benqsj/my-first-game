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
const AT_ONCE := 5
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
	"hall": {"name": "სასახლის დარბაზი", "kind": "hall", "w": 44.0, "l": 56.0, "h": 18.0},
	"court": {"name": "სასახლის ეზო", "kind": "court", "w": 52.0, "l": 64.0, "h": 11.0},
	"great_hall": {"name": "ჩანგრეული დარბაზი", "kind": "hall", "w": 50.0, "l": 70.0, "h": 24.0, "hole": true},
	"terrace": {"name": "ტერასა", "kind": "terrace", "w": 56.0, "l": 66.0, "h": 14.0},
	"cave": {"name": "გამოქვაბული", "kind": "cave", "w": 54.0, "l": 62.0, "h": 15.0},
	"forest": {"name": "ტყე", "kind": "forest", "w": 70.0, "l": 78.0, "h": 0.0},
	"sky": {"name": "ცის კუნძული", "kind": "sky", "w": 56.0, "l": 56.0, "h": 0.0, "lift": 160.0},
	"throne": {"name": "ტახტის ეზო", "kind": "throne", "w": 66.0, "l": 78.0, "h": 6.0},
	"crypt": {"name": "აკლდამა", "kind": "crypt", "w": 36.0, "l": 60.0, "h": 9.0},
	"swamp": {"name": "ჭაობი", "kind": "swamp", "w": 58.0, "l": 62.0, "h": 0.0},
	"mountain": {"name": "ქარიშხლის ბილიკი", "kind": "mountain", "w": 46.0, "l": 64.0, "h": 0.0, "lift": 60.0},
	"rampart": {"name": "ციხის გალავანი", "kind": "rampart", "w": 26.0, "l": 80.0, "h": 0.0},
	# the places to get one's breath back ([RestSpot]): no creatures, "rest" on the portal
	"spring": {"name": "წმინდა წყარო", "kind": "spring", "w": 36.0, "l": 44.0, "h": 12.0, "rest": "სიცოცხლე ბოლომდე"},
	"prison": {"name": "ტყვეების ოთახი", "kind": "prison", "w": 34.0, "l": 50.0, "h": 11.0, "rest": "გაათავისუფლე ტყვე"},
	# and the two quiet places of the portal's own (the user's word,
	# 2026-10-22: a merchant, an altar) ([PortalEvent])
	"merchant": {"name": "ვაჭარი", "kind": "merchant", "w": 32.0, "l": 42.0, "h": 11.0, "rest": "იყიდე ოქროთი"},
	"altar": {"name": "სამსხვერპლო", "kind": "altar", "w": 32.0, "l": 42.0, "h": 13.0, "rest": "შესწირე და მიიღე"},
}

## Per dungeon, its run: each step the places its portals may lead to, the
## creatures in each ("*" any of them) as [scene, count, props], the level
## they show ("lv"), what clearing it gives on top of them ("xp", wolves'
## worth) and the level it tops him up to ("reach"). The first dungeon: imps in
## the hall; imps and puglins, puglins and goblins, or goblins and imps; more
## of them; the two orcs, taking turns; the lord of the orcs alone.
const RUN := {
	0: [
		# 1
		{"places": ["hall"], "lv": 1, "xp": 1.5, "reach": 2, "foes": {"*": [[IMP, 5], [GOBLIN, 3]]}},
		# 2 — a goblin shaman with most of them, kept back, from here on (the
		# user's word, 2026-10-21: roles in the fight)
		# (the court, the cave and the broken hall gone from the run: the user's
		# word, 2026-10-23, not liked)
		{"places": ["forest", "crypt", "swamp"], "lv": 2, "xp": 2.0, "reach": 3,
				"foes": {"forest": [[GOBLIN, 4], [GOBLIN, 1, SHAMAN], [IMP, 4]], "crypt": [[IMP, 5], [GOBLIN, 4]],
						"swamp": [[PUGLIN, 6], [GOBLIN, 4]]}},
		# 3 — and an elite in the second wave
		{"places": ["sky", "forest", "crypt", "swamp", "mountain"], "lv": 3, "xp": 2.5, "reach": 3,
				"foes": {"sky": [[IMP, 5], [GOBLIN, 4], [GOBLIN, 1, ELITE]],
						"forest": [[GOBLIN, 4], [GOBLIN, 1, SHAMAN], [PUGLIN, 4], [GOBLIN, 1, ELITE]],
						"crypt": [[IMP, 5], [GOBLIN, 4], [IMP, 1, ELITE]],
						"swamp": [[PUGLIN, 4], [GOBLIN, 1, SHAMAN], [GOBLIN, 4], [PUGLIN, 1, ELITE]],
						"mountain": [[GOBLIN, 5], [IMP, 4], [GOBLIN, 1, ELITE]]}},
		# 4 — one orc, with two swords (the user's word, 2026-10-21: the
		# shield orc not liked; one, the two-sword one)
		{"places": ["terrace", "forest", "sky", "rampart", "mountain"], "lv": 4, "xp": 3.0, "reach": 4,
				"foes": {"*": [[ORC, 1, ORC_TWO_SWORDS]]}},
		# 5 — the first boss, alone in the palace's hall (the user's word,
		# 2026-10-22: ten steps, every fifth a boss; the court gone 2026-10-23)
		{"places": ["hall"], "lv": 5, "xp": 4.0, "reach": 5, "boss": true, "boss_name": "ყასაბი",
				"foes": {"*": [[BUTCHER, 1]]}},
		# 6 — the second half: an orc among them, the elite still last; the
		# skulls come in (the user's word, 2026-10-22: flyers, several at once)
		{"places": ["hall", "forest", "crypt", "swamp"], "lv": 6, "xp": 3.0, "reach": 5,
				"foes": {"*": [[ORC_SKIRM, 1], [GOBLIN, 2], [SKULL, 3], [GOBLIN, 1, SHAMAN], [PUGLIN, 1, ELITE]]}},
		# 7 — the dragonets' fire; the minotaur last, in the elite's place
		{"places": ["sky", "mountain", "swamp", "crypt"], "lv": 7, "xp": 3.5, "reach": 6,
				"foes": {"*": [[ORC, 1, ORC_LONG_SWORD], [IMP, 3], [DRAGONET, 2], [MINOTAUR, 1]]}},
		# 8 — a troll, and what follows it about, the two kinds of flyer over it
		{"places": ["terrace", "rampart", "forest", "swamp"], "lv": 7, "xp": 3.5, "reach": 7,
				"foes": {"*": [[TROLL, 1], [GOBLIN, 1, SHAMAN], [PUGLIN, 2], [SKULL, 2], [DRAGONET, 1]]}},
		# 9 — the two orcs, taking turns, and dragonets throwing
		{"places": ["terrace", "sky", "mountain", "rampart"], "lv": 8, "xp": 4.0, "reach": 7,
				"foes": {"*": [[ORC, 1, ORC_TWO_SWORDS], [ORC, 1, ORC_LONG_SWORD], [DRAGONET, 2]]}},
		# 10 — the lord of the orcs
		{"places": ["throne"], "lv": 8, "boss": true, "boss_name": "ორკების მბრძანებელი",
				"foes": {"*": [[ORC_CHIEF, 1, ORC_LORD]]}},
	],
}
## The steps a place to rest (the spring, the prisoners) may be offered
## before, beside the step's own place (1-based, the rests not counted); and
## before every boss, the spring always.
const REST_BEFORE := [3, 6, 8]
## Spike traps in the floor ([SpikeTrap]): from this step on, in this share of
## the places.
const TRAPS_FROM := 3
const TRAP_CHANCE := 0.6
## Each place, to look round it from F1 ([method view_place]): the step whose
## light (day into night) it is seen in, and what it is called on the board.
const VIEW := {
	"hall": [0, "Hall"], "forest": [2, "Forest"],
	"crypt": [2, "Crypt"], "swamp": [2, "Swamp"], "sky": [5, "Sky island"],
	"mountain": [5, "Storm path"], "spring": [5, "Holy spring"], "prison": [5, "Prisoners' room"],
	"merchant": [5, "Merchant"], "altar": [5, "Altar"],
	"terrace": [7, "Terrace"], "rampart": [7, "Rampart"], "throne": [9, "Lord's court"],
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
## Seconds between any two things thrown at one hero (the user's word: so
## many waiting made a hail of it; then, 2 s still too few to get out of the
## way of all of them: a rest from all throwing after each).
const THROW_GAP := 5.0
## Held back, they wait round him on these rings, spread out evenly.
const HOLD_RINGS := [8.5, 11.5]

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
## What was bought at the merchant's or given at the altar this run, by any
## hero ([PortalEvent]).
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
var _tusk_label: Label
## This run: when its first place woke, what fell, the tusks won, whether it
## is over ([RunSummary]).
var _run_start: float = -1.0
var run_kills: int = 0
var run_tusks: int = 0
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
	c = mix(c, vec3(0.16, 0.19, 0.09), moss * mix(0.6, 0.15, photo));
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
	vec3 c = stone.rgb * (0.7 + 0.45 * n);
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
	c = mix(c, vec3(0.13, 0.17, 0.10), 0.25 * (1.0 - photo * 0.7) * smoothstep(1.2, 0.0, wpos.y) * step(0.6, n));
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
	c = mix(c, vec3(0.09, 0.13, 0.06) * (0.8 + 0.4 * mn), moss * mix(0.75, 0.22, photo));
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
	_tusk_counter()
	if game != null and Trades.level(game, "priest") >= 2:
		boons.lights = 4
	# The first place: the first step's own.
	_arrive_at(0, String(steps[0]["places"][0]), "", true)
	_apply_phase(_phase)
	_place_marks()
	# Where the orcs' heavy blows crack the floor ([OrcFighter]).
	add_to_group(&"ground_scars")
	_say("%s" % String(Portals.DEFS[id]["name"]), 3.5)
	Fighter.throw_gap = THROW_GAP
	# The run's orcs and its lord made now, behind the loading screen, and
	# everything the run will show drawn once there ([method _warm_up]).
	_premake.call_deferred()
	_warm_up.call_deferred()
	# brought in late, at the party's door ([method Net.bring_waiting])
	var join: Dictionary = game.get(&"join_at") if game != null else {}
	if not join.is_empty():
		game.set(&"join_at", {})
		_join_party.call_deferred(join)
	elif game != null and Trades.level(game, "priest") >= 1 and String(game.get(&"view_place")) == "":
		_priest_gift.call_deferred()
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


#region The orcs' tusks
## A creature of the portal watched: the blessings' doings on it, and the
## tusks it leaves when it dies ([Trades]).
func _watch_foe(body: Node3D) -> void:
	boons.watch(body)
	if body.has_signal(&"died") and not body.has_meta(&"tusks_watched"):
		body.set_meta(&"tusks_watched", true)
		body.connect(&"died", _on_tusks.bind(body))


func _on_tusks(body: Node3D) -> void:
	if not is_instance_valid(body):
		return
	var n := Trades.tusks_for(body) * (2 if bool(_room(current).get("cursed", false)) else 1)
	run_kills += 1
	run_tusks += n
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method(&"add_tusks"):
		game.call(&"add_tusks", n)
	_show_tusks(n)


## The count at the screen's right, under the map.
func _tusk_counter() -> void:
	_tusk_label = Label.new()
	_tusk_label.anchor_left = 1.0
	_tusk_label.anchor_right = 1.0
	_tusk_label.offset_left = -260
	_tusk_label.offset_right = -24
	_tusk_label.offset_top = 228
	_tusk_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tusk_label.add_theme_font_size_override("font_size", 21)
	_tusk_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	_tusk_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_tusk_label.add_theme_constant_override("outline_size", 6)
	_tusk_label.pivot_offset = Vector2(236, 14)
	_tusk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tusk_label)
	_show_tusks(0)


func _show_tusks(gained: int) -> void:
	if _tusk_label == null:
		return
	var game := get_node_or_null("/root/Game")
	var have := int(game.get(&"tusks")) if game != null and game.get(&"tusks") != null else 0
	_tusk_label.text = "ორკის ეშვი: %d" % have
	if gained > 0:
		_tusk_label.text += "   +%d" % gained
		var tw := _tusk_label.create_tween()
		tw.tween_property(_tusk_label, "scale", Vector2(1.25, 1.25), 0.08)
		tw.tween_property(_tusk_label, "scale", Vector2.ONE, 0.25)
		tw.tween_interval(1.8)
		tw.tween_callback(_show_tusks.bind(0))
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
	steps.insert(at, {"places": [place], "lv": before.get("lv", 1), "foes": {}, "rest": true})
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
		foes = foes + foes
	if p.has("rest"):
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
	var lists: Array = []
	var last: Array = []
	for entry: Array in foes:
		var one := entry.duplicate()
		one[1] = 1
		var role := String((entry[2] as Dictionary).get("role", "")) if entry.size() > 2 else ""
		var many: Array = []
		for n in int(entry[1]):
			many.append(one)
		if role == "elite":
			last.append_array(many)
		else:
			lists.append(many)
	var out: Array = []
	var left := true
	while left:
		left = false
		for many: Array in lists:
			if not many.is_empty():
				out.append(many.pop_front())
				left = true
	out.append_array(last)
	return out


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
	if i == steps.size() - 1:
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
	for file in ResourceLoader.list_directory(SND):
		if file.get_extension() == "wav":
			var stream := load(SND + file)
			if stream != null:
				_sounds.append(stream)
	# and the dungeon's music, the lord's too: read in as his court came up,
	# it was a stall just as the dark lifted there
	var music := get_node_or_null("/root/Music")
	if music != null and music.get_script() != null:
		var tracks: Dictionary = (music.get_script() as Script).get_script_constant_map().get("TRACKS", {})
		for key: StringName in [&"dungeon", &"dungeon_boss"]:
			for path: String in tracks.get(key, []):
				if ResourceLoader.exists(path):
					_sounds.append(load(path))


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
	rift.position = c + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, -l * 0.22)
	rift.scale = Vector3(0.02, 0.02, 0.02)
	add_child(rift)
	return rift


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
	var last := i == steps.size() - 1
	if last and is_instance_valid(_lord_fight):
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
					purse.give(60)
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
		# with others, no totems: who broke one is not told to the rest yet
		if goal == "totems" and online():
			goal = ""
		out.append({"place": place, "reward": reward, "goal": goal, "cursed": k == cursed_one and reward != ""})
	return out


## Which place to rest behind the second portal: the spring when he is hurt;
## else the prisoners (oftener while the village wants its tradesmen), the
## merchant (only with gold to spend), the altar, now and then the spring.
func _rest_pick(low: bool, wanted: bool) -> String:
	if low:
		return "spring"
	var gold := 0
	for hero in _heroes():
		var purse := Purse.of(hero)
		if purse != null:
			gold = maxi(gold, purse.gold)
	var weights := {"prison": 2.0 if wanted else 0.8, "altar": 1.0, "spring": 0.5,
			"merchant": 1.5 if gold >= 35 else 0.0}
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
##   given that makes blows heavier — each "blade" reward, the merchant's
##   blade and the altar of gold (shared out over the heroes), each blessing,
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
		if d == "blade":
			p *= pow(1.1, 1.0 / float(n))
		elif d == "gold":
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
func _lay_traps(i: int) -> void:
	if _viewing or is_rest(i) or is_boss(i) or stage_of(i) < TRAPS_FROM:
		return
	if i < _room_nodes.size() and is_instance_valid(_room_nodes[i]) and _room_nodes[i].has_node(^"Spikes0"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 104729 * (i + 1) + 7 * id + 3
	if rng.randf() > TRAP_CHANCE:
		return
	SpikeTrap.lay(self, i, rng)


## The merchant's or the altar's keeper in the place he is in ([PortalEvent]).
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
			gate.tint = {"merchant": Color(1.0, 0.72, 0.3), "altar": Color(0.75, 0.12, 0.16)}.get(place, Color(0.45, 0.8, 1.0))
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
	# behind the dark till the new place draws smoothly: whatever it shows
	# for the first time made now, not in front of him
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
## there, as for the open world's [PipelineWarmup]): every other place put up
## out of the way and looked at from three sides, one of each creature, the
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
	var keep := {"current": current, "creaks": _creaks.duplicate(), "birds": _birds.duplicate(),
			"sea": _cloud_sea, "layers": _cloud_layer_mats.duplicate()}
	var here := String(_room(current).get("place", ""))
	var n := 0
	for place: String in PLACES:
		if place == here:
			continue
		var p: Dictionary = PLACES[place]
		var i := rooms.size()
		var r := {"place": place, "kind": p["kind"], "w": p["w"], "l": p["l"], "h": p["h"], "name": p["name"],
				"foes": [], "lv": 1, "xp": 0.0, "reach": 0, "reward": ""}
		if p.has("hole"):
			r["hole"] = true
		rooms.append(r)
		centres.append(WARM_AT + Vector3(0.0, float(p.get("lift", 0.0)), float(n) * 300.0))
		_build_room(i)
		current = i
		_place_look(0.0)
		var c := centre(i)
		var l: float = r["l"]
		var h := maxf(float(r["h"]), 8.0)
		for pose: Array in [[Vector3(0.0, 2.5, l * 0.5 - 3.0), Vector3(0.0, 2.0, 0.0)],
				[Vector3(0.0, h + 14.0, -l * 0.35), Vector3(0.0, 0.0, l * 0.1)]]:
			eye.make_current()
			eye.global_position = c + (pose[0] as Vector3)
			eye.look_at(c + (pose[1] as Vector3))
			await get_tree().process_frame
			await get_tree().process_frame
		if i < _room_nodes.size() and is_instance_valid(_room_nodes[i]):
			_room_nodes[i].free()
		_room_nodes.resize(i)
		var cols: Array[Dictionary] = []
		for col in _columns:
			if int(col["room"]) != i:
				cols.append(col)
		_columns = cols
		rooms.resize(i)
		centres.resize(i)
		n += 1
	current = int(keep["current"])
	_creaks.assign(keep["creaks"])
	_birds.assign(keep["birds"])
	_cloud_sea = keep["sea"]
	_cloud_layer_mats.assign(keep["layers"])
	_apply_phase(_phase)

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
	if is_instance_valid(_lord_fight) and _woken and current == steps.size() - 1 and not _lord_fight.won:
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
			if coming == 0:
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


func _photo_tex(key: String) -> Texture2D:
	if not _photo.has(key):
		var path: String = PHOTO[key]
		_photo[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _photo[key]


## The forest's and the swamp's ground, the land's photographed one in it.
func _ground_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _ground_shader
	m.set_shader_parameter("photo", 1.0)
	m.set_shader_parameter("t_grass", _photo_tex("grass"))
	m.set_shader_parameter("n_grass", _photo_tex("grass_nor"))
	m.set_shader_parameter("t_earth", _photo_tex("earth"))
	m.set_shader_parameter("n_earth", _photo_tex("earth_nor"))
	m.set_shader_parameter("t_leaves", _photo_tex("leaves"))
	m.set_shader_parameter("t_mud", _photo_tex("mud"))
	m.set_shader_parameter("n_mud", _photo_tex("mud_nor"))
	return m


func _materials() -> void:
	_floor_shader = Shader.new()
	_floor_shader.code = FLOOR_SHADER
	_glass_shader = Shader.new()
	_glass_shader.code = GLASS_SHADER
	_beam_shader = Shader.new()
	_beam_shader.code = BEAM_SHADER
	var rock := Shader.new()
	rock.code = ROCK_SHADER
	_rock_mat = ShaderMaterial.new()
	_rock_mat.shader = rock
	_rock_mat.set_shader_parameter("scale", 0.08)
	_rock_mat.set_shader_parameter("rock_a", Color(0.48, 0.44, 0.40))
	_rock_mat.set_shader_parameter("rock_b", Color(0.30, 0.28, 0.27))
	_rock_mat.set_shader_parameter("band", Color(0.58, 0.48, 0.38))
	_rock_mat.set_shader_parameter("wet", 0.0)
	_rock_mat.set_shader_parameter("moss_amount", 0.6)
	_rock_mat.set_shader_parameter("photo", 1.0)
	_rock_mat.set_shader_parameter("photo_tex", _photo_tex("rock"))
	_cave_mat = ShaderMaterial.new()
	_cave_mat.shader = rock
	_cave_mat.set_shader_parameter("scale", 0.3)
	# under the earth as the Eternal Cities lie (the user's word, 2026-10-20:
	# Elden Ring's colours): blue-grey rock, flecked with points of starlight
	# (2026-10-23: the land's grey rock now, only a cold cast left)
	_cave_mat.set_shader_parameter("rock_a", Color(0.40, 0.40, 0.42))
	_cave_mat.set_shader_parameter("rock_b", Color(0.17, 0.17, 0.19))
	_cave_mat.set_shader_parameter("band", Color(0.46, 0.45, 0.47))
	_cave_mat.set_shader_parameter("moss", Color(0.08, 0.22, 0.26))
	_cave_mat.set_shader_parameter("fleck", Color(0.75, 0.88, 1.0))
	_cave_mat.set_shader_parameter("fleck_glow", 3.0)
	_cave_mat.set_shader_parameter("wet", 0.6)
	_cave_mat.set_shader_parameter("moss_amount", 0.35)
	_cave_mat.set_shader_parameter("photo", 0.8)
	_cave_mat.set_shader_parameter("photo_tex", _photo_tex("rock"))
	_ground_shader = Shader.new()
	_ground_shader.code = GROUND_SHADER
	_wall_mat = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = WALL_SHADER
	_wall_mat.shader = ws
	_wall_mat.set_shader_parameter("photo", 1.0)
	_wall_mat.set_shader_parameter("stone_tex", _photo_tex("rock"))
	_wall_mat.set_shader_parameter("stone_nor", _photo_tex("rock_nor"))
	# the dressed stone's colour the village's grey-brown, not the old beige;
	# the land's rock in its face
	_trim_mat = StandardMaterial3D.new()
	_trim_mat.albedo_color = Color(0.56, 0.53, 0.48)
	_trim_mat.roughness = 0.8
	_trim_mat.normal_enabled = true
	_trim_mat.normal_texture = _photo_tex("rock_nor")
	_trim_mat.normal_scale = 0.7
	_trim_mat.uv1_triplanar = true
	_trim_mat.uv1_world_triplanar = true
	_trim_mat.uv1_scale = Vector3(0.4, 0.4, 0.4)
	_iron_mat = StandardMaterial3D.new()
	_iron_mat.albedo_color = Color(0.09, 0.085, 0.08)
	_iron_mat.metallic = 0.85
	_iron_mat.roughness = 0.45
	_cloth_mat = StandardMaterial3D.new()
	_cloth_mat.albedo_color = Color(0.26, 0.07, 0.34)
	_cloth_mat.roughness = 0.95
	_gold_mat = StandardMaterial3D.new()
	_gold_mat.albedo_color = Color(0.78, 0.58, 0.22)
	_gold_mat.metallic = 0.9
	_gold_mat.roughness = 0.35
	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_color = Color(0.17, 0.11, 0.07)
	_wood_mat.roughness = 0.9


## Room `i`'s floor: big slabs in the halls, smaller flags under the sky,
## cobbles along the walls (and up the throne room's aisle), its wear.
func _floor_mat(i: int) -> ShaderMaterial:
	var r := _room(i)
	var kind: String = r["kind"]
	var m := ShaderMaterial.new()
	m.shader = _floor_shader
	m.set_shader_parameter("photo", 1.0)
	m.set_shader_parameter("cob_tex", _photo_tex("cob"))
	m.set_shader_parameter("cob_nor", _photo_tex("cob_nor"))
	m.set_shader_parameter("stone_tex", _photo_tex("rock"))
	m.set_shader_parameter("stone_nor", _photo_tex("rock_nor"))
	var c := centre(i)
	m.set_shader_parameter("centre", Vector2(c.x, c.z))
	m.set_shader_parameter("half_size", Vector2(float(r["w"]) * 0.5, float(r["l"]) * 0.5))
	if kind == "cave":
		m.set_shader_parameter("rocky", 1.0)
		m.set_shader_parameter("pebble", 0.9)
		m.set_shader_parameter("relief", 0.09)
		m.set_shader_parameter("cobble_a", Color(0.38, 0.38, 0.40))
		m.set_shader_parameter("cobble_b", Color(0.17, 0.17, 0.19))
		m.set_shader_parameter("wet", 0.8)
		m.set_shader_parameter("border", 0.0)
		return m
	if kind == "crypt":
		m.set_shader_parameter("slab", 2.0)
		m.set_shader_parameter("course", 1.4)
		m.set_shader_parameter("slab_a", Color(0.40, 0.39, 0.36))
		m.set_shader_parameter("slab_b", Color(0.26, 0.26, 0.25))
		m.set_shader_parameter("cobble_a", Color(0.34, 0.33, 0.31))
		m.set_shader_parameter("cobble_b", Color(0.16, 0.16, 0.16))
		m.set_shader_parameter("wear", 0.75)
		m.set_shader_parameter("border", 2.0)
		m.set_shader_parameter("aisle", 2.2)
		m.set_shader_parameter("wet", 0.4)
		return m
	if kind == "mountain":
		m.set_shader_parameter("rocky", 1.0)
		m.set_shader_parameter("pebble", 1.3)
		m.set_shader_parameter("relief", 0.1)
		m.set_shader_parameter("cobble_a", Color(0.44, 0.44, 0.46))
		m.set_shader_parameter("cobble_b", Color(0.24, 0.24, 0.27))
		m.set_shader_parameter("wet", 1.0)
		m.set_shader_parameter("snow", 1.0)
		m.set_shader_parameter("border", 0.0)
		return m
	if kind in ["court", "terrace", "sky", "rampart", "spring", "merchant", "altar"]:
		m.set_shader_parameter("all_cob", 1.0)
	if kind == "prison":
		# big dark flags, cold, worn (the user's word, 2026-10-23: another floor)
		m.set_shader_parameter("slab", 1.9)
		m.set_shader_parameter("course", 1.3)
		m.set_shader_parameter("slab_a", Color(0.36, 0.36, 0.37))
		m.set_shader_parameter("slab_b", Color(0.25, 0.25, 0.27))
		m.set_shader_parameter("cobble_a", Color(0.34, 0.33, 0.33))
		m.set_shader_parameter("cobble_b", Color(0.18, 0.18, 0.19))
		m.set_shader_parameter("border", 1.2)
		m.set_shader_parameter("wear", 0.5)
		return m
	if kind == "rampart":
		m.set_shader_parameter("slab", 1.6)
		m.set_shader_parameter("course", 1.1)
		m.set_shader_parameter("slab_a", Color(0.50, 0.49, 0.47))
		m.set_shader_parameter("slab_b", Color(0.34, 0.34, 0.34))
		m.set_shader_parameter("wear", 0.7)
		m.set_shader_parameter("border", 1.0)
		m.set_shader_parameter("wet", 0.5)
		return m
	if kind == "sky":
		m.set_shader_parameter("slab", 2.0)
		m.set_shader_parameter("course", 1.4)
		m.set_shader_parameter("slab_a", Color(0.56, 0.52, 0.48))
		m.set_shader_parameter("slab_b", Color(0.40, 0.38, 0.36))
		m.set_shader_parameter("wear", 0.4)
		m.set_shader_parameter("border", 2.0)
		return m
	if kind == "hall":
		m.set_shader_parameter("slab", 2.6)
		m.set_shader_parameter("course", 1.7)
		m.set_shader_parameter("slab_a", Color(0.50, 0.45, 0.38))
		m.set_shader_parameter("slab_b", Color(0.36, 0.32, 0.27))
		m.set_shader_parameter("wear", 0.45 if not r.has("hole") else 0.75)
		m.set_shader_parameter("border", 2.2)
		m.set_shader_parameter("aisle", 2.6)
	else:
		m.set_shader_parameter("slab", 1.8)
		m.set_shader_parameter("course", 1.25)
		m.set_shader_parameter("slab_a", Color(0.49, 0.44, 0.38))
		m.set_shader_parameter("slab_b", Color(0.35, 0.31, 0.27))
		m.set_shader_parameter("border", 3.2)
		m.set_shader_parameter("wear", 0.65)
		m.set_shader_parameter("wet", 1.0 if kind != "throne" else 0.6)
		if kind == "throne":
			m.set_shader_parameter("aisle", 3.0)
	return m


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
	var root: Node = owner if owner != null else get_parent()
	var env_node := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return
	_env = env_node.environment
	var shader := Shader.new()
	shader.code = SKY_SHADER
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = shader
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.fog_density = 0.0007
	_env.fog_sky_affect = 0.2
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.06
	_env.adjustment_contrast = 1.03
	_env.ssao_enabled = true
	_env.ssao_intensity = 1.1
	_sun = root.get_node_or_null("Sun") as DirectionalLight3D
	if _sun != null:
		_sun_yaw = _sun.rotation.y
		# the land's sun: its shadows as soft, as far
		_sun.shadow_opacity = 0.72
		_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_sun.directional_shadow_split_1 = 0.26
		_sun.directional_shadow_blend_splits = true
		_sun.directional_shadow_max_distance = 95.0
	_apply_phase(0.0)


## Over `seconds`, to the light of room `to`.
func _to_phase(to: float, seconds: float) -> void:
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_method(_apply_phase, _phase, to, seconds)


func _apply_phase(t: float) -> void:
	_phase = t
	var i := clampi(int(floorf(t)), 0, PHASES.size() - 1)
	var j := mini(i + 1, PHASES.size() - 1)
	var u := clampf(t - float(i), 0.0, 1.0)
	var a: Dictionary = PHASES[i]
	var b: Dictionary = PHASES[j]
	var top: Color = (a["top"] as Color).lerp(b["top"], u)
	var hor: Color = (a["hor"] as Color).lerp(b["hor"], u)
	var sun_c: Color = (a["sun"] as Color).lerp(b["sun"], u)
	var night := lerpf(float(a["night"]), float(b["night"]), u)
	var elev := lerpf(float(a["elev"]), float(b["elev"]), u)
	var sun_e := lerpf(float(a["sun_e"]), float(b["sun_e"]), u)
	var yaw := _sun_yaw
	# Into the night: the sun goes down, then the moon comes up, elsewhere.
	if float(b["night"]) > 0.9 and float(a["night"]) < 0.9:
		if u < 0.5:
			elev = lerpf(float(a["elev"]), -6.0, u * 2.0)
			sun_e = lerpf(float(a["sun_e"]), 0.0, u * 2.0)
			sun_c = a["sun"]
		else:
			elev = float(b["elev"])
			yaw = _sun_yaw + PI * 0.7
			sun_e = lerpf(0.0, float(b["sun_e"]), (u - 0.5) * 2.0)
			sun_c = b["sun"]
	elif float(a["night"]) > 0.9:
		yaw = _sun_yaw + PI * 0.7
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("top_col", top)
		_sky_mat.set_shader_parameter("hor_col", hor)
		_sky_mat.set_shader_parameter("gnd_col", (a["gnd"] as Color).lerp(b["gnd"], u))
		_sky_mat.set_shader_parameter("sun_col", sun_c)
		_sky_mat.set_shader_parameter("night", night)
		_sky_mat.set_shader_parameter("cloud", lerpf(float(a["cloud"]), float(b["cloud"]), u))
	if _env != null:
		_env.ambient_light_color = (a["amb"] as Color).lerp(b["amb"], u)
		_env.ambient_light_energy = lerpf(float(a["amb_e"]), float(b["amb_e"]), u)
		_env.fog_light_color = (a["fog"] as Color).lerp(b["fog"], u)
	var lit := hor.lerp(Color(1, 1, 1), 0.5) * lerpf(1.0, 0.3, night)
	for m in _cloud_layer_mats:
		m.set_shader_parameter("top", lit.lerp(sun_c, 0.15))
		m.set_shader_parameter("low", lit.darkened(0.35).lerp(top, 0.25))
	if _sun != null:
		_sun.rotation = Vector3(-deg_to_rad(maxf(elev, -6.0)), yaw, 0.0)
		_sun.light_color = sun_c
		_sun.light_energy = maxf(sun_e, 0.0)
		_sun.visible = sun_e > 0.01
	_place_look(night)


## Each place's own air over the day's (the user's word, 2026-10-20: the
## palace's and the cave's colours as Elden Ring's): the palace's halls in a
## golden haze, the light through them thick enough to see, Leyndell's warm
## pale stone; the cave a deep blue under the earth, its own mist, its
## crystals and flecks bright in it like the underground cities' starlight.
func _place_look(night: float = 0.0) -> void:
	if _env == null or rooms.is_empty() or current < 0 or current >= rooms.size():
		return
	var kind := String(_room(current).get("kind", ""))
	_env.glow_enabled = true
	_env.glow_intensity = 0.9
	_env.glow_bloom = 0.08
	_env.glow_hdr_threshold = 1.0
	_env.volumetric_fog_enabled = false
	_env.fog_density = 0.0021
	_env.fog_height_density = 0.0
	_env.adjustment_contrast = 1.03
	_env.adjustment_saturation = 1.06
	_env.fog_sky_affect = 0.2
	match kind:
		"hall", "court", "terrace", "throne":
			# the gold is the day's: by night only the torches' warmth is left
			var day := 1.0 - clampf(night, 0.0, 1.0)
			var gold := Color(0.92, 0.72, 0.42)
			# the land's own air (the user's word, 2026-10-23: inside the
			# portal, the colours of the world he left), no gold haze
			_env.fog_light_color = _env.fog_light_color.lerp(gold, 0.05 * day)
		"crypt":
			# the catacombs: cold grey stone, the candles' warmth in it, but
			# a man still seen as he is (2026-10-23)
			_env.ambient_light_color = Color(0.52, 0.56, 0.58)
			_env.ambient_light_energy = 1.45
			_env.fog_light_color = Color(0.30, 0.32, 0.33)
			_env.fog_density = 0.004
			_env.glow_intensity = 1.2
			_env.glow_bloom = 0.16
			_env.glow_hdr_threshold = 0.85
			_env.volumetric_fog_enabled = true
			_env.volumetric_fog_density = 0.0025
			_env.volumetric_fog_albedo = Color(0.75, 0.78, 0.75)
			_env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			_env.volumetric_fog_length = 50.0
			_env.volumetric_fog_ambient_inject = 0.1
		"swamp":
			# sickly, green: the poison swamps'
			_env.fog_light_color = _env.fog_light_color.lerp(Color(0.45, 0.55, 0.35), 0.6)
			_env.ambient_light_color = _env.ambient_light_color.lerp(Color(0.55, 0.62, 0.45), 0.45)
			_env.fog_density = 0.004
		"mountain":
			# the storm: dark, cold, the clouds down on the peaks
			_env.ambient_light_color = _env.ambient_light_color.lerp(Color(0.48, 0.52, 0.58), 0.4)
			_env.ambient_light_energy *= 0.9
			_env.fog_light_color = Color(0.32, 0.35, 0.42).lerp(_env.fog_light_color, 0.3)
			_env.fog_density = 0.006
			if _sky_mat != null:
				_sky_mat.set_shader_parameter("cloud", 0.92)
				_sky_mat.set_shader_parameter("top_col", Color(0.16, 0.18, 0.24))
				_sky_mat.set_shader_parameter("hor_col", Color(0.36, 0.38, 0.44))
			if _sun != null:
				_sun.light_energy *= 0.7
		"rampart":
			# Stormveil's grey over the gold
			_env.fog_light_color = _env.fog_light_color.lerp(Color(0.6, 0.62, 0.66), 0.4)
			_env.adjustment_contrast = 1.1
		"forest":
			# the dead wood (the user's word, 2026-10-20: dark, a wood one is
			# afraid of): little light gets through, cold and grey-green, a
			# mist one cannot see far into, the sky shut out
			# (2026-10-23: still the dead wood, but the land's colours in it)
			_env.ambient_light_color = Color(0.50, 0.56, 0.52)
			_env.ambient_light_energy *= 0.9
			_env.fog_light_color = Color(0.36, 0.40, 0.40)
			_env.fog_density = 0.009
			_env.fog_sky_affect = 0.6
			_env.adjustment_contrast = 1.06
			_env.adjustment_saturation = 0.95
			_env.glow_hdr_threshold = 0.9
			# low mist over the ground, thinning upward: the height fog (cheap,
			# no volumetric, the user's word, 2026-10-23: light to draw)
			_env.fog_light_color = Color(0.62, 0.66, 0.66)
			_env.fog_density = 0.005
			_env.fog_height = centre(current).y + 1.5
			_env.fog_height_density = 0.03
			if _sky_mat != null:
				var dim := 1.0 - 0.6 * clampf(night, 0.0, 1.0)
				_sky_mat.set_shader_parameter("cloud", 0.95)
				_sky_mat.set_shader_parameter("top_col", Color(0.1 * dim, 0.11 * dim, 0.13 * dim))
				_sky_mat.set_shader_parameter("hor_col", Color(0.3 * dim, 0.34 * dim, 0.35 * dim))
			if _sun != null:
				_sun.light_energy *= 0.75
				_sun.light_color = _sun.light_color.lerp(Color(0.85, 0.9, 0.92), 0.4)
		"cave":
			# (2026-10-23: the land's grey under the earth, a cold cast only)
			_env.ambient_light_color = Color(0.54, 0.56, 0.59)
			_env.ambient_light_energy = 1.5
			_env.fog_light_color = Color(0.26, 0.30, 0.36)
			_env.fog_density = 0.005
			_env.glow_intensity = 1.25
			_env.glow_bloom = 0.18
			_env.glow_hdr_threshold = 0.8
			_env.volumetric_fog_enabled = true
			_env.volumetric_fog_density = 0.004
			_env.volumetric_fog_albedo = Color(0.7, 0.76, 0.85)
			_env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
			_env.volumetric_fog_length = 60.0
			_env.volumetric_fog_ambient_inject = 0.2
	# a cursed place: blood in its air ([method _curse])
	if bool(_room(current).get("cursed", false)):
		_env.fog_light_color = _env.fog_light_color.lerp(Color(0.45, 0.03, 0.04), 0.75)
		_env.fog_density = maxf(_env.fog_density, 0.004)
		_env.ambient_light_color = _env.ambient_light_color.lerp(Color(0.95, 0.3, 0.28), 0.45)
		_env.volumetric_fog_albedo = _env.volumetric_fog_albedo.lerp(Color(0.9, 0.15, 0.12), 0.7)
		_env.adjustment_saturation *= 0.9
	# Low has neither (the graphics setting's word, [Graphics]): the plain fog
	# a little thicker in the volumetric's place.
	if Graphics.current == Graphics.Level.LOW:
		_env.glow_enabled = false
		if _env.volumetric_fog_enabled:
			_env.volumetric_fog_enabled = false
			_env.fog_density *= 1.6


## A fire low enough to walk into (the user's word, 2026-10-23: in places he
## went through the fire) gets a post round it no one goes through.
func _block_fires(room: Node3D) -> void:
	if room == null:
		return
	for n in room.find_children("*", "Node3D", true, false):
		if not n.is_in_group(&"dungeon_flame"):
			continue
		var f := n as Node3D
		var low := f.global_position.y - room.global_position.y
		if low > 2.2 or low < -0.5:
			continue
		var r := clampf(float(f.get_meta(&"size", 1.0)) * 0.3, 0.3, 0.9)
		var post := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = 2.4
		shape.shape = cyl
		post.add_child(shape)
		room.add_child(post)
		post.global_position = Vector3(f.global_position.x, room.global_position.y + 1.2, f.global_position.z)


func _build_room(i: int) -> void:
	_build_room_body(i)
	if i < _room_nodes.size():
		_block_fires(_room_nodes[i])


func _build_room_body(i: int) -> void:
	var r := _room(i)
	var kind: String = r["kind"]
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	var c := centre(i)
	var room := Node3D.new()
	room.name = "Room%d" % (i + 1)
	room.position = c
	add_child(room)
	while _room_nodes.size() <= i:
		_room_nodes.append(null)
	_room_nodes[i] = room
	match kind:
		"cave":
			PlaceBuild.cave(self, room, i)
			return
		"forest":
			_build_forest(room, i)
			return
		"sky":
			_build_sky(room, i)
			return
		"crypt":
			PlaceBuild.crypt(self, room, i)
			return
		"swamp":
			_build_swamp(room, i)
			return
		"mountain":
			_build_mountain(room, i)
			return
		"rampart":
			_build_rampart(room, i)
			return
		"spring", "prison":
			RestSpot.build(self, room, i, kind)
			return
		"merchant", "altar":
			PortalEvent.build(self, room, i, kind)
			return
	var last := kind == "throne"
	var far := -l * 0.5 - WALL_T * 0.5
	var near := l * 0.5 + WALL_T * 0.5
	# The crag under it, down into the lands.
	_crag_under(room, w + WALL_T * 2.0, l + WALL_T * 2.0, PalaceVista.DROP + 40.0, -24.0)

	# The floor (with the strip under the next doorway), and the rock under it.
	_solid(room, _floor_mat(i), Vector3(w + WALL_T * 2.0, 1.0, l + WALL_T), Vector3(0.0, -0.5, -WALL_T * 0.5))
	# The palace's own footings, going down into the crag.
	_solid(room, _wall_mat, Vector3(w + WALL_T * 2.0, 24.0, l + WALL_T), Vector3(0.0, -13.0, -WALL_T * 0.5), false)

	# The long walls; the terrace has one side open over the drop.
	for side: float in [-1.0, 1.0]:
		var x := side * (w + WALL_T) * 0.5
		if kind == "terrace" and side > 0.0:
			_balustrade(room, Vector3(w * 0.5 - 0.3, 0.0, 0.0), l + WALL_T)
			continue
		if kind == "throne":
			_parapet(room, Vector3(x, 0.0, -WALL_T * 0.5), Vector3(WALL_T, h, l + WALL_T * 2.0))
			continue
		if kind == "court":
			_window_wall(room, x, l, h)
		else:
			_solid(room, _wall_mat, Vector3(WALL_T, h, l + WALL_T * 2.0), Vector3(x, h * 0.5, -WALL_T * 0.5))
	# The near wall, where he came in by.
	_solid(room, _wall_mat, Vector3(w + WALL_T * 2.0, h, WALL_T), Vector3(0.0, h * 0.5, near))
	# The far wall with its gate (shut: the way on is by the portals), or the
	# lord's court's open end over the drop.
	if not last:
		var wall_h := h
		var wall_w := w + WALL_T * 2.0
		var piece := (wall_w - DOOR_W) * 0.5
		for side: float in [-1.0, 1.0]:
			_solid(room, _wall_mat, Vector3(piece, wall_h, WALL_T),
					Vector3(side * (DOOR_W + piece) * 0.5, wall_h * 0.5, far))
		_solid(room, _wall_mat, Vector3(DOOR_W, wall_h - DOOR_H, WALL_T),
				Vector3(0.0, DOOR_H + (wall_h - DOOR_H) * 0.5, far))
		_door_frame(room, Vector3(0.0, 0.0, far))
		_build_gate(room, Vector3(0.0, 0.0, far))
	else:
		_balustrade_across(room, Vector3(0.0, 0.0, -l * 0.5 + 0.3), w)

	# A cornice along the tops of the walls.
	if kind == "hall" or kind == "court":
		for side: float in [-1.0, 1.0]:
			var x := side * (w * 0.5 + 0.2)
			_trim(room, Vector3(0.6, 0.45, l), Vector3(x, h - 0.6, 0.0))
	if kind == "court":
		_merlons(room, w, l, h)

	# Columns: two rows in a hall (and a tall vault on beams), along the walls elsewhere.
	if kind == "hall":
		_battle_remains(room, w, l)
		_hall_columns(room, i, w, l, h)
		_ceiling(room, w, l, h, r.has("hole"))
		_high_windows(room, w, l, h)
	elif kind == "court":
		_wall_columns(room, i, w, l, h)
		_basin(room)
		_fallen_column(room, Vector3(-w * 0.25, 0.0, l * 0.22), 0.6)
	elif kind == "terrace":
		_blades_in_floor(room, w, l, 8)
		_wall_columns(room, i, w, l, h, true)
		_fallen_column(room, Vector3(w * 0.18, 0.0, -l * 0.28), -0.4)
	else:
		_ruins(room, i, w, l)
		_blades_in_floor(room, w, l, 14)
		_dais(room, l)
		_throne(room, l)

	# the orcs' own over it all (the user's word, 2026-10-21: one should see
	# the orcs have taken it)
	OrcSpoils.dress(self, room, kind, w, l, h, kind == "hall" and not r.has("hole"))
	_wainscot(room, kind, w, l)
	_rubble_round(room, i, w, l)
	_motes(room, w, l, h)
	# (the standing braziers down the hall's aisle gone: the user's word,
	# 2026-10-23)


## An iron bowl of fire on three legs, waist high.
func _standing_brazier(room: Node3D, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = at
	room.add_child(holder)
	for k in 3:
		var a := TAU * float(k) / 3.0
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.07, 1.15, 0.07)
		leg.mesh = lm
		leg.material_override = _iron_mat
		leg.position = Vector3(sin(a) * 0.28, 0.55, cos(a) * 0.28)
		leg.rotation = Vector3(cos(a) * 0.22, 0.0, -sin(a) * 0.22)
		holder.add_child(leg)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.55
	bm.bottom_radius = 0.22
	bm.height = 0.38
	bm.radial_segments = 12
	bowl.mesh = bm
	bowl.material_override = _iron_mat
	bowl.position = Vector3(0.0, 1.22, 0.0)
	holder.add_child(bowl)
	var coals := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.48
	cm.bottom_radius = 0.48
	cm.height = 0.04
	coals.mesh = cm
	if _coals_mat == null:
		var sh := Shader.new()
		sh.code = COALS_SHADER
		_coals_mat = ShaderMaterial.new()
		_coals_mat.shader = sh
	coals.material_override = _coals_mat
	coals.position = Vector3(0.0, 1.39, 0.0)
	holder.add_child(coals)
	holder.add_child(_flame(Vector3(0.0, 1.42, 0.0), 1.7, 22))
	_crackle(holder, Vector3(0.0, 1.4, 0.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.6
	light.omni_range = 10.0
	light.position = Vector3(0.0, 2.0, 0.0)
	holder.add_child(_fire_light(light))


func _solid(parent: Node3D, mat: Material, size: Vector3, at: Vector3, block: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# Walls go on up, unseen, so nobody climbs out over them.
	var tall := block and size.y > 2.5 and at.y > 0.0
	bs.size = Vector3(size.x, size.y + (BLOCK_H if tall else 0.0), size.z)
	shape.shape = bs
	shape.position.y = (BLOCK_H * 0.5) if tall else 0.0
	body.add_child(shape)
	parent.add_child(body)
	return body


func _deco(parent: Node3D, mat: Material, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


func _trim(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	_deco(parent, _trim_mat, box, at)


## An invisible wall: only something to stop the heroes.
func _blocker(parent: Node3D, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body


## A courtyard's long wall: piers and high arched windows onto the mountains.
func _window_wall(room: Node3D, x: float, l: float, h: float) -> void:
	var n := 4
	var bay := (l + WALL_T * 2.0) / float(n)
	var sill := 2.4
	var head := h - 2.2
	var win := bay * 0.48
	for k in n:
		var z0 := l * 0.5 + WALL_T - bay * float(k)
		var mid := z0 - bay * 0.5
		var pier := (bay - win) * 0.5
		for s: float in [-1.0, 1.0]:
			_solid(room, _wall_mat, Vector3(WALL_T, h, pier), Vector3(x, h * 0.5, mid - WALL_T * 0.5 + s * (win + pier) * 0.5))
		_solid(room, _wall_mat, Vector3(WALL_T, sill, win), Vector3(x, sill * 0.5, mid - WALL_T * 0.5))
		_solid(room, _wall_mat, Vector3(WALL_T, h - head, win), Vector3(x, head + (h - head) * 0.5, mid - WALL_T * 0.5))
		# A carved lintel and sill.
		var lintel := BoxMesh.new()
		lintel.size = Vector3(WALL_T + 0.3, 0.5, win + 0.8)
		_deco(room, _trim_mat, lintel, Vector3(x, head + 0.25, mid - WALL_T * 0.5))
		var sill_box := BoxMesh.new()
		sill_box.size = Vector3(WALL_T + 0.4, 0.3, win + 0.6)
		_deco(room, _trim_mat, sill_box, Vector3(x, sill + 0.15, mid - WALL_T * 0.5))
		_blocker(room, Vector3(WALL_T, head - sill, win), Vector3(x, sill + (head - sill) * 0.5, mid - WALL_T * 0.5))


## Battlements along the courtyard's tops.
func _merlons(room: Node3D, w: float, l: float, h: float) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * (w + WALL_T) * 0.5
		var k := 0.0
		while k < l:
			var box := BoxMesh.new()
			box.size = Vector3(WALL_T, 1.1, 1.3)
			_deco(room, _wall_mat, box, Vector3(x, h + 0.55, l * 0.5 - 1.0 - k))
			k += 2.6


## A balustrade along `length` at `at` (running along z), the drop beyond it.
func _balustrade(room: Node3D, at: Vector3, length: float) -> void:
	_trim(room, Vector3(0.5, 0.18, length), at + Vector3(0.0, 1.1, -WALL_T * 0.5))
	_trim(room, Vector3(0.6, 0.2, length), at + Vector3(0.0, 0.1, -WALL_T * 0.5))
	var k := 0.0
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.14
	post.height = 0.85
	post.radial_segments = 8
	while k < length:
		_deco(room, _trim_mat, post, at + Vector3(0.0, 0.62, length * 0.5 - WALL_T * 0.5 - 0.3 - k))
		k += 0.45
	_blocker(room, Vector3(0.6, 12.0, length), at + Vector3(0.0, 6.0, -WALL_T * 0.5))
	# The palace's own wall going down into the cloud.
	var cliff := BoxMesh.new()
	cliff.size = Vector3(2.0, 90.0, length + 2.0)
	_deco(room, _wall_mat, cliff, at + Vector3(0.7, -45.2, -WALL_T * 0.5))


## The same across the far end of the boss's court.
func _balustrade_across(room: Node3D, at: Vector3, w: float) -> void:
	_trim(room, Vector3(w, 0.18, 0.5), at + Vector3(0.0, 1.1, 0.0))
	_trim(room, Vector3(w, 0.2, 0.6), at + Vector3(0.0, 0.1, 0.0))
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.14
	post.height = 0.85
	post.radial_segments = 8
	var k := 0.0
	while k < w:
		_deco(room, _trim_mat, post, at + Vector3(-w * 0.5 + 0.3 + k, 0.62, 0.0))
		k += 0.45
	_blocker(room, Vector3(w, 12.0, 0.6), at + Vector3(0.0, 6.0, 0.0))
	var cliff := BoxMesh.new()
	cliff.size = Vector3(w + 6.0, 90.0, 2.0)
	_deco(room, _wall_mat, cliff, at + Vector3(0.0, -45.2, -0.7))


## The boss's court: a low parapet with crenels, the drop below it.
func _parapet(room: Node3D, at: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 1.3, size.z)
	_deco(room, _wall_mat, box, at + Vector3(0.0, 0.65, 0.0))
	var k := 0.0
	while k < size.z:
		var m := BoxMesh.new()
		m.size = Vector3(size.x, 0.9, 1.2)
		_deco(room, _wall_mat, m, at + Vector3(0.0, 1.75, size.z * 0.5 - 1.0 - k))
		k += 2.4
	_blocker(room, Vector3(size.x, 14.0, size.z), at + Vector3(0.0, 7.0, 0.0))
	var cliff := BoxMesh.new()
	cliff.size = Vector3(size.x + 1.0, 90.0, size.z)
	_deco(room, _wall_mat, cliff, at + Vector3(signf(at.x) * 0.5, -45.2, 0.0))


## A carved frame round a doorway, both faces.
func _door_frame(room: Node3D, at: Vector3) -> void:
	for face: float in [-1.0, 1.0]:
		var z := at.z + face * (WALL_T * 0.5 + 0.15)
		for side: float in [-1.0, 1.0]:
			_trim(room, Vector3(0.7, DOOR_H + 0.4, 0.3), Vector3(side * (DOOR_W * 0.5 + 0.35), DOOR_H * 0.5, z))
		_trim(room, Vector3(DOOR_W + 1.4, 0.8, 0.35), Vector3(0.0, DOOR_H + 0.4, z))
		# A shield-shaped boss of gold over the door.
		var boss := BoxMesh.new()
		boss.size = Vector3(1.0, 1.2, 0.2)
		var b := _deco(room, _gold_mat, boss, Vector3(0.0, DOOR_H + 1.4, z + face * 0.1))
		b.rotation.z = PI * 0.25


## Two rows of tall columns down a hall, banners between, torches on them.
func _hall_columns(room: Node3D, i: int, w: float, l: float, h: float) -> void:
	var n := maxi(3, int(l / 9.0))
	for k in n:
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			var x := side * (w * 0.5 - 4.5)
			_column(room, i, Vector3(x, 0.0, z), h, 1.15)
			if k % 2 == 0:
				_torch(room, Vector3(x - side * 0.85, 3.6, z))
			# Banners on the walls between the columns.
			if k < n - 1:
				_hang_banner(room, Vector3(side * (w * 0.5 - 0.1), h - 2.2, z - l / float(n) * 0.5), side, minf(7.0, h * 0.45))


func _wall_columns(room: Node3D, i: int, w: float, l: float, h: float, one_side: bool = false) -> void:
	var n := maxi(3, int(l / 10.0))
	for k in n:
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			if one_side and side > 0.0:
				continue
			var x := side * (w * 0.5 - 0.9)
			_column(room, i, Vector3(x, 0.0, z), h * 0.9, 0.9)
			if k % 2 == 1:
				_torch(room, Vector3(x - side * 0.7, 3.4, z))


func _column(room: Node3D, i: int, at: Vector3, h: float, thick: float) -> void:
	var base := BoxMesh.new()
	base.size = Vector3(thick * 2.0, 0.6, thick * 2.0)
	_solid(room, _trim_mat, base.size, at + Vector3(0.0, 0.3, 0.0))
	var shaft := CylinderMesh.new()
	shaft.top_radius = thick * 0.62
	shaft.bottom_radius = thick * 0.7
	shaft.height = h - 1.4
	shaft.radial_segments = 14
	var parts: Array[MeshInstance3D] = []
	parts.append(_deco(room, _wall_mat, shaft, at + Vector3(0.0, 0.6 + (h - 1.4) * 0.5, 0.0)))
	var blocker := _blocker(room, Vector3(thick * 1.3, h, thick * 1.3), at + Vector3(0.0, h * 0.5, 0.0))
	var cap := BoxMesh.new()
	cap.size = Vector3(thick * 1.9, 0.8, thick * 1.9)
	parts.append(_deco(room, _trim_mat, cap, at + Vector3(0.0, h - 0.4, 0.0)))
	# Gilded rings at the shaft's foot and neck.
	for y: float in [1.0, h - 1.0]:
		var band := CylinderMesh.new()
		band.top_radius = thick * 0.74
		band.bottom_radius = thick * 0.74
		band.height = 0.18
		band.radial_segments = 14
		parts.append(_deco(room, _gold_mat, band, at + Vector3(0.0, y, 0.0)))
	_columns.append({"room": i, "at": room.position + at, "local": at, "h": h, "thick": thick,
			"parts": parts, "blocker": blocker, "node": room, "broken": false})

func _hang_banner(room: Node3D, at: Vector3, side: float, long: float) -> void:
	var cloth := QuadMesh.new()
	cloth.size = Vector2(2.0, long)
	var cl := _deco(room, _torn_cloth(), cloth, at + Vector3(-side * 0.1, -long * 0.5, 0.0))
	cl.rotation.y = PI * 0.5
	for z: float in [-0.75, 0.75]:
		var stripe := BoxMesh.new()
		stripe.size = Vector3(0.09, long, 0.14)
		_deco(room, _gold_mat, stripe, at + Vector3(-side * 0.11, -long * 0.5, z))
	var rod := CylinderMesh.new()
	rod.top_radius = 0.06
	rod.bottom_radius = 0.06
	rod.height = 2.4
	var r := _deco(room, _gold_mat, rod, at + Vector3(-side * 0.15, 0.05, 0.0))
	r.rotation.x = PI * 0.5
	# A golden lozenge on it.
	var mark := BoxMesh.new()
	mark.size = Vector3(0.1, 0.7, 0.7)
	var m := _deco(room, _gold_mat, mark, at + Vector3(-side * 0.13, -long * 0.35, 0.0))
	m.rotation.x = PI * 0.25


## A hall's roof: a flat ceiling on deep beams, iron braziers hanging from it.
## Where `hole` is set, the roof has fallen in over the middle: the sky
## through it, sunlight down it, its beams broken and the rubble under it.
func _ceiling(room: Node3D, w: float, l: float, h: float, hole: bool = false) -> void:
	var hz := 0.0
	var hl := 0.0
	var hw := 0.0
	if hole:
		hz = -l * 0.08
		hl = 16.0
		hw = 14.0
	var full_l := l + WALL_T * 2.0
	if not hole:
		var slab := BoxMesh.new()
		slab.size = Vector3(w + WALL_T * 2.0, 1.0, full_l)
		_deco(room, _wood_mat, slab, Vector3(0.0, h + 0.5, -WALL_T * 0.5))
	else:
		# Four slabs round the hole.
		var near_l := (l * 0.5 + WALL_T) - (hz + hl * 0.5)
		var far_l := (hz - hl * 0.5) - (-l * 0.5 - WALL_T * 2.0)
		var a := BoxMesh.new()
		a.size = Vector3(w + WALL_T * 2.0, 1.0, near_l)
		_deco(room, _wood_mat, a, Vector3(0.0, h + 0.5, hz + hl * 0.5 + near_l * 0.5))
		var b := BoxMesh.new()
		b.size = Vector3(w + WALL_T * 2.0, 1.0, far_l)
		_deco(room, _wood_mat, b, Vector3(0.0, h + 0.5, hz - hl * 0.5 - far_l * 0.5))
		for side: float in [-1.0, 1.0]:
			var sw := (w + WALL_T * 2.0 - hw) * 0.5
			var c := BoxMesh.new()
			c.size = Vector3(sw, 1.0, hl)
			_deco(room, _wood_mat, c, Vector3(side * (hw * 0.5 + sw * 0.5), h + 0.5, hz))
		# Moonlight down through it, and what fell.
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = hw * 0.45
		cyl.bottom_radius = hw * 0.6
		cyl.height = h + 2.0
		cyl.radial_segments = 16
		cyl.cap_top = false
		cyl.cap_bottom = false
		beam.mesh = cyl
		var bm := ShaderMaterial.new()
		bm.shader = _beam_shader
		bm.set_shader_parameter("tint", Color(1.0, 0.88, 0.66))
		bm.set_shader_parameter("strength", 0.03)
		beam.material_override = bm
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position = Vector3(0.0, h * 0.5, hz)
		room.add_child(beam)
		var shaft := SpotLight3D.new()
		shaft.light_color = Color(1.0, 0.88, 0.7)
		shaft.light_energy = 4.0
		shaft.spot_range = h + 8.0
		shaft.spot_angle = 28.0
		shaft.shadow_enabled = true
		shaft.position = Vector3(0.0, h + 4.0, hz)
		shaft.rotation.x = -PI * 0.5
		room.add_child(shaft)
		_rubble(room, Vector3(2.0, 0.0, hz + 1.5), 3.2, 24, 99)
		_rubble(room, Vector3(-5.0, 0.0, hz - 3.0), 2.0, 12, 7)
		# A beam come down, lying on the rubble (the user's word, 2026-10-21:
		# it stood on its end in the air).
		var fallen := BoxMesh.new()
		fallen.size = Vector3(0.9, 0.8, 13.0)
		var fb := _deco(room, _wood_mat, fallen, Vector3(-2.5, 0.75, hz + 1.0))
		fb.rotation = Vector3(0.09, 0.55, 0.04)
		var lie := _blocker(room, Vector3(0.9, 1.2, 13.0), Vector3(-2.5, 0.6, hz + 1.0))
		lie.rotation.y = 0.55
		# ivy hanging down over the broken edge (no grass on the floor: the
		# user's word, 2026-10-23, too much of it)
		for k in 8:
			var side := -1.0 if k % 2 == 0 else 1.0
			var at := Vector3(side * hw * 0.5, h - 0.3, hz + _rng.randf_range(-hl * 0.4, hl * 0.4))
			_necro_put(room, "EA_Nature_Ivy_01a" if k % 3 != 0 else "EA_Nature_Ivy_01c", at, PI * 0.5 * side, 2.4, false)
	var n := int(l / 5.0)
	for k in n + 1:
		var z := l * 0.5 - float(k) * l / float(n)
		if hole and absf(z - hz) < hl * 0.5:
			# Its broken ends sticking out over the hole.
			for side: float in [-1.0, 1.0]:
				var stub := BoxMesh.new()
				stub.size = Vector3((w - hw) * 0.5 + 1.5, 0.9, 0.7)
				var st := _deco(room, _wood_mat, stub, Vector3(side * (hw * 0.5 + (w - hw) * 0.25 - 0.75), h - 0.45, z))
				st.rotation.z = side * 0.06
			continue
		var beam_box := BoxMesh.new()
		beam_box.size = Vector3(w, 0.9, 0.7)
		_deco(room, _wood_mat, beam_box, Vector3(0.0, h - 0.45, z))
	for side: float in [-1.0, 1.0]:
		var long := BoxMesh.new()
		long.size = Vector3(0.8, 1.1, l)
		_deco(room, _wood_mat, long, Vector3(side * (w * 0.5 - 4.5), h - 1.0, 0.0))
	for k in 3:
		var z := l * 0.5 - (float(k) + 0.5) * l / 3.0
		if hole and absf(z - hz) < hl * 0.5 + 2.0:
			continue
		_hanging_brazier(room, Vector3(0.0, h, z), h)


func _hanging_brazier(room: Node3D, top: Vector3, h: float) -> void:
	var drop := minf(h - 6.0, 9.0)
	_creaks.append(room.position + top + Vector3(0.0, -drop * 0.5, 0.0))
	var chain := CylinderMesh.new()
	chain.top_radius = 0.04
	chain.bottom_radius = 0.04
	chain.height = drop
	_deco(room, _iron_mat, chain, top + Vector3(0.0, -drop * 0.5, 0.0))
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.9
	bowl.bottom_radius = 0.35
	bowl.height = 0.5
	bowl.radial_segments = 10
	var at := top + Vector3(0.0, -drop - 0.25, 0.0)
	_deco(room, _iron_mat, bowl, at)
	room.add_child(_flame(at + Vector3(0.0, 0.2, 0.0), 2.2, 40))
	_crackle(room, at)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.66, 0.36)
	light.light_energy = 3.4
	light.omni_range = 22.0
	light.position = at + Vector3(0.0, 0.6, 0.0)
	room.add_child(_fire_light(light))


## The courtyard's dry basin in the middle.
func _basin(room: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		_solid(room, _trim_mat, Vector3(7.0, 0.8, 0.5), Vector3(0.0, 0.4, side * 3.25))
		_solid(room, _trim_mat, Vector3(0.5, 0.8, 7.0), Vector3(side * 3.25, 0.4, 0.0))
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.0, 6.0)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.08, 0.06, 0.14)
	wm.metallic = 0.3
	wm.roughness = 0.05
	water.material_override = wm
	water.position = Vector3(0.0, 0.55, 0.0)
	room.add_child(water)
	var plinth := BoxMesh.new()
	plinth.size = Vector3(1.2, 2.2, 1.2)
	_solid(room, _trim_mat, plinth.size, Vector3(0.0, 1.1, 0.0))
	var urn := CylinderMesh.new()
	urn.top_radius = 0.7
	urn.bottom_radius = 0.3
	urn.height = 0.8
	_deco(room, _gold_mat, urn, Vector3(0.0, 2.6, 0.0))


## Broken columns round the boss's court.
func _ruins(room: Node3D, i: int, w: float, l: float) -> void:
	var heights: Array[float] = [7.0, 3.2, 9.0, 1.8, 5.5, 8.0, 2.4, 6.5]
	for k in 8:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := l * 0.5 - 8.0 - floorf(float(k) / 2.0) * (l - 24.0) / 3.0
		_column(room, i, Vector3(side * (w * 0.5 - 3.0), 0.0, z), heights[k], 1.2)
		if k % 3 == 0:
			_torch(room, Vector3(side * (w * 0.5 - 4.2), 1.2, z))


## A raised dais at the far end, where the way out will stand.
func _dais(room: Node3D, l: float) -> void:
	for k in 3:
		_solid(room, _trim_mat, Vector3(20.0 - float(k) * 3.5, 0.3, 11.0 - float(k) * 2.5),
				Vector3(0.0, 0.15 + float(k) * 0.3, -l * 0.5 + 6.0 - float(k) * 0.6))


## What is seen from the open rooms: the v5 lands far below and round the
## palace, their mountains on the horizon ([PalaceVista]), and the crag the
## palace stands on going down to them.
func _vista() -> void:
	var lands := PalaceVista.new()
	lands.name = "Vista"
	# The palace over the middle of the lands' basin.
	var mid := -STEP_GAP * float(steps.size() - 1) * 0.5
	lands.position = Vector3(-560.0, 0.0, mid + 120.0)
	add_child(lands)


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
	var brutes := 0
	for body in _alive:
		if not is_instance_valid(body) or bool(body.get("is_dead")):
			continue
		var gap := INF
		for hero in standing:
			gap = minf(gap, body.global_position.distance_to(hero.global_position))
		if body is PackBrute:
			if gap < 9.0 and not (body as PackBrute).held_back:
				brutes += 1
			continue
		# the shaman keeps back by itself ([FoeRoles]), and the flyers do
		if FoeRoles.role_of(body) == &"shaman" or body is Flyer:
			continue
		if "held_back" in body:
			small.append([gap, body])
	var allowed := maxi(CROWD * standing.size() - brutes, 0)
	# Those that have their turn keep it while near; the nearest fill the rest.
	var keep: Array[Node3D] = []
	for h in _holders:
		for pair: Array in small:
			if pair[1] == h and float(pair[0]) < 11.0:
				keep.append(h)
	small.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for pair: Array in small:
		if keep.size() >= allowed:
			break
		if not keep.has(pair[1]):
			keep.append(pair[1])
	while keep.size() > allowed:
		keep.pop_back()
	_holders = keep
	var waiting: Array[Fighter] = []
	for pair: Array in small:
		var held: bool = not keep.has(pair[1])
		(pair[1] as Node).set("held_back", held)
		if held:
			waiting.append(pair[1])
	_spread(waiting, standing)


## The ones held back, round each hero on `HOLD_RINGS` at even bearings (the
## user's word: no more than three in a place), each kept to the side of him
## it is on so none crosses another.
func _spread(waiting: Array[Fighter], standing: Array[Player]) -> void:
	if standing.is_empty():
		return
	var by_hero := {}
	for body in waiting:
		var best: Player = standing[0]
		for hero in standing:
			if hero.global_position.distance_squared_to(body.global_position) \
					< best.global_position.distance_squared_to(body.global_position):
				best = hero
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
			body.held_radius = float(HOLD_RINGS[k % HOLD_RINGS.size()])


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
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	for k in count:
		var piece := MeshInstance3D.new()
		if k % 3 == 0:
			var block := BoxMesh.new()
			block.size = Vector3(rng.randf_range(0.5, 1.3), rng.randf_range(0.35, 0.7), rng.randf_range(0.5, 1.0)) * clampf(size / 2.0, 0.4, 1.4)
			piece.mesh = block
			piece.material_override = _wall_mat
		else:
			piece.mesh = RockWave._crag_mesh(k % RockWave.SHAPES)
			piece.material_override = _rock_mat
			var s := rng.randf_range(0.25, 0.75) * size * 0.6
			piece.scale = Vector3(s, s * rng.randf_range(0.5, 0.9), s)
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * size
		piece.position = at + Vector3(cos(a) * r, rng.randf_range(0.0, 0.25) * (1.0 - r / maxf(size, 0.01)) * size, sin(a) * r)
		piece.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		parent.add_child(piece)


## Heaps along the walls and in the corners, where the palace has begun to come down.
func _rubble_round(room: Node3D, i: int, w: float, l: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + i * 17 + id
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := rng.randf_range(-l * 0.4, l * 0.4)
		_rubble(room, Vector3(side * (w * 0.5 - 2.0), 0.0, z), rng.randf_range(1.2, 2.6), rng.randi_range(8, 16), rng.randi())


## A column lying where it fell long ago, in drums.
func _fallen_column(room: Node3D, at: Vector3, yaw: float) -> void:
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	for k in 4:
		var drum := CylinderMesh.new()
		drum.top_radius = 0.6
		drum.bottom_radius = 0.6
		drum.height = 2.2
		drum.radial_segments = 14
		var d := _deco(room, _wall_mat, drum, at + dir * (float(k) * 2.5 + randf_range(-0.2, 0.2)) + Vector3(0.0, 0.6, 0.0))
		d.rotation = Vector3(PI * 0.5, yaw, float(k) * 0.3)
	_solid(room, _trim_mat, Vector3(2.0, 0.6, 2.0), at - dir * 2.0 + Vector3(0.0, 0.3, 0.0))
	var lying := _blocker(room, Vector3(1.2, 1.2, 10.0), at + dir * 3.75 + Vector3(0.0, 0.6, 0.0))
	lying.rotation.y = yaw
	_rubble(room, at + dir * 5.0, 1.4, 8, int(at.x * 13.0 + at.z))


## A dark panelled band along the foot of the walls.
func _wainscot(room: Node3D, kind: String, w: float, l: float) -> void:
	if kind == "throne":
		return
	for side: float in [-1.0, 1.0]:
		if kind == "terrace" and side > 0.0:
			continue
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 1.5, l)
		_deco(room, _wood_mat if kind == "hall" else _trim_mat, box, Vector3(side * (w * 0.5 - 0.12), 0.75, 0.0))
		var rail := BoxMesh.new()
		rail.size = Vector3(0.32, 0.12, l)
		_deco(room, _gold_mat if kind == "hall" else _trim_mat, rail, Vector3(side * (w * 0.5 - 0.14), 1.52, 0.0))


## Tall stained-glass windows high in a hall's long walls, light slanting in.
func _high_windows(room: Node3D, w: float, l: float, h: float) -> void:
	var n := maxi(3, int(l / 14.0))
	var tall := minf(h * 0.38, 9.0)
	var wide := 2.6
	for k in n:
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			var x := side * (w * 0.5 - 0.02)
			var glass := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(wide, tall)
			glass.mesh = q
			var gm := ShaderMaterial.new()
			gm.shader = _glass_shader
			glass.material_override = gm
			glass.position = Vector3(x, h - 2.5 - tall * 0.5, z)
			glass.rotation.y = -side * PI * 0.5
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			room.add_child(glass)
			# A carved frame.
			for e: float in [-1.0, 1.0]:
				var jamb := BoxMesh.new()
				jamb.size = Vector3(0.35, tall + 0.4, 0.3)
				_deco(room, _trim_mat, jamb, Vector3(x - side * 0.15, glass.position.y, z + e * (wide * 0.5 + 0.15)))
			var sill := BoxMesh.new()
			sill.size = Vector3(0.5, 0.3, wide + 0.9)
			_deco(room, _trim_mat, sill, Vector3(x - side * 0.2, glass.position.y - tall * 0.5 - 0.15, z))
			# Light slanting down from it across the hall, on one side only.
			if side < 0.0 and k % 2 == 0:
				var beam := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = wide * 0.35
				cyl.bottom_radius = wide * 0.6
				var length := (h - 2.5) * 1.6
				cyl.height = length
				cyl.radial_segments = 12
				cyl.cap_top = false
				cyl.cap_bottom = false
				beam.mesh = cyl
				var bm := ShaderMaterial.new()
				bm.shader = _beam_shader
				bm.set_shader_parameter("tint", Color(1.0, 0.8, 0.6))
				bm.set_shader_parameter("strength", 0.045)
				beam.material_override = bm
				beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var top := Vector3(x, h - 2.5 - tall * 0.5, z)
				var foot := Vector3(x * 0.15, 0.0, z - 3.0)
				beam.position = (top + foot) * 0.5
				var dir := (top - foot).normalized()
				beam.basis = Basis(Quaternion(Vector3.UP, dir))
				room.add_child(beam)


## Dust hanging in the air of a room, lit where the light is.
func _motes(room: Node3D, w: float, l: float, h: float) -> void:
	var dust := GPUParticles3D.new()
	dust.amount = 160
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.position = Vector3(0.0, minf(h, 12.0) * 0.5, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.45, minf(h, 12.0) * 0.45, l * 0.45)
	pm.gravity = Vector3(0.0, -0.02, 0.0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.9, 0.8, 0.0))
	fade.add_point(0.5, Color(1.0, 0.9, 0.8, 0.35))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.9, 0.8, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	dust.draw_pass_1 = q
	dust.visibility_aabb = AABB(Vector3(-w, -h, -l) * 0.6, Vector3(w, h, l) * 1.2)
	room.add_child(dust)


## The orc lord's seat on the dais, braziers either side of it.
func _throne(room: Node3D, l: float) -> void:
	var z := -l * 0.5 + 3.4
	var y := 0.9
	_solid(room, _wall_mat, Vector3(3.2, 1.0, 2.6), Vector3(0.0, y + 0.5, z))
	_solid(room, _wall_mat, Vector3(3.2, 5.5, 0.7), Vector3(0.0, y + 2.75, z - 1.0))
	for side: float in [-1.0, 1.0]:
		_solid(room, _wall_mat, Vector3(0.5, 1.6, 2.6), Vector3(side * 1.6, y + 1.3, z))
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.25
		horn.height = 1.8
		horn.radial_segments = 6
		var hn := _deco(room, _iron_mat, horn, Vector3(side * 1.4, y + 6.1, z - 1.0))
		hn.rotation.z = -side * 0.35
	var seat := BoxMesh.new()
	seat.size = Vector3(2.4, 0.15, 2.0)
	_deco(room, _cloth_mat, seat, Vector3(0.0, y + 1.08, z + 0.1))
	var skull := SphereMesh.new()
	skull.radius = 0.45
	skull.height = 0.8
	_deco(room, _trim_mat, skull, Vector3(0.0, y + 5.0, z - 0.6))
	for side: float in [-1.0, 1.0]:
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.9
		bowl.bottom_radius = 0.4
		bowl.height = 0.6
		var at := Vector3(side * 6.0, y + 1.6, z + 1.0)
		_solid(room, _iron_mat, Vector3(0.4, 1.6, 0.4), at + Vector3(0.0, -0.9, 0.0))
		_deco(room, _iron_mat, bowl, at)
		room.add_child(_flame(at + Vector3(0.0, 0.25, 0.0), 3.0, 50))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.3)
		light.light_energy = 3.6
		light.omni_range = 20.0
		light.position = at + Vector3(0.0, 1.0, 0.0)
		room.add_child(_fire_light(light))


## An iron portcullis filling the doorway at `at`, down.
func _build_gate(room: Node3D, at: Vector3) -> Node3D:
	var gate := StaticBody3D.new()
	gate.name = "Gate"
	gate.position = at
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(DOOR_W, DOOR_H, 0.4)
	shape.shape = bs
	shape.position.y = DOOR_H * 0.5
	gate.add_child(shape)
	var bars := 13
	for b in bars:
		var bar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = DOOR_H
		cyl.radial_segments = 6
		bar.mesh = cyl
		bar.material_override = _iron_mat
		bar.position = Vector3(-DOOR_W * 0.5 + (float(b) + 0.5) * DOOR_W / float(bars), DOOR_H * 0.5, 0.0)
		gate.add_child(bar)
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 0.3
		tip.mesh = cone
		tip.material_override = _iron_mat
		tip.rotation.x = PI
		tip.position = Vector3(bar.position.x, -0.1, 0.0)
		gate.add_child(tip)
	for hh: float in [1.2, 3.0, 4.8, 6.6]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(DOOR_W, 0.12, 0.16)
		rail.mesh = rb
		rail.material_override = _iron_mat
		rail.position = Vector3(0.0, hh, 0.0)
		gate.add_child(rail)
	room.add_child(gate)
	return gate


## A fire (the user's word, 2026-10-20: the palace's fires prettier): a flame
## drawn whole by a shader, its tongues licking up and tearing off, white-gold
## at its root and dark red at its tips, sparks going up from it. Its light
## flickers ([method _fire_light]).
func _flame(at: Vector3, size: float, amount: int) -> Node3D:
	var fire := Node3D.new()
	fire.position = at
	fire.add_to_group(&"dungeon_flame")
	fire.set_meta(&"size", size)
	if _fire_mat == null:
		var sh := Shader.new()
		sh.code = FLAME_SHADER
		_fire_mat = ShaderMaterial.new()
		_fire_mat.shader = sh
	var small := size < 1.0
	var dims := Vector2(0.55, 0.85) * size if not small else Vector2(0.3, 0.5) * size
	var key := snappedf(size, 0.05)
	var quad: QuadMesh = _fire_quads.get(key) as QuadMesh
	if quad == null:
		quad = QuadMesh.new()
		quad.size = dims
		quad.center_offset = Vector3(0.0, dims.y * 0.42, 0.0)
		quad.material = _fire_mat
		_fire_quads[key] = quad
	var body := MeshInstance3D.new()
	body.mesh = quad
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.custom_aabb = AABB(Vector3(-dims.x * 0.5, -0.1, -dims.x * 0.5), Vector3(dims.x, dims.y + 0.2, dims.x))
	fire.add_child(body)
	if small:
		return fire
	fire.add_child(_embers(size, maxi(4, amount / 4)))
	return fire


## Sparks going up from a fire, swirling, dying out.
func _embers(size: float, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.8
	p.local_coords = true
	p.randomness = 0.6
	if _ember_draw == null:
		_ember_draw = QuadMesh.new()
		_ember_draw.size = Vector2(0.035, 0.035)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.vertex_color_use_as_albedo = true
		qm.albedo_color = Color(4.0, 2.6, 1.4)
		_ember_draw.material = qm
	var key := snappedf(size, 0.05)
	var pm: ParticleProcessMaterial = _ember_pms.get(key) as ParticleProcessMaterial
	if pm == null:
		pm = ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.1 * size
		pm.direction = Vector3.UP
		pm.spread = 22.0
		pm.initial_velocity_min = 0.6 * size
		pm.initial_velocity_max = 1.3 * size
		pm.gravity = Vector3(0.0, 0.25, 0.0)
		pm.damping_min = 0.2
		pm.damping_max = 0.6
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.4
		pm.turbulence_noise_scale = 1.6
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.15
		pm.scale_min = 0.5
		pm.scale_max = 1.4
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		fade.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.9), Color(0.6, 0.1, 0.0, 0.0)])
		var ramp := GradientTexture1D.new()
		ramp.gradient = fade
		pm.color_ramp = ramp
		_ember_pms[key] = pm
	p.process_material = pm
	p.draw_pass_1 = _ember_draw
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2) * size, Vector3(4, 5, 4) * size)
	return p


## A fire's light, flickering with it ([method _flicker_fires]).
func _fire_light(light: OmniLight3D) -> OmniLight3D:
	_fire_lights.append({"light": light, "base": light.light_energy, "at": _rng.randf_range(0.0, 100.0)})
	return light


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
	var holder := Node3D.new()
	holder.position = at
	room.add_child(holder)
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.07
	cm.height = 0.36
	cup.mesh = cm
	cup.material_override = _iron_mat
	holder.add_child(cup)
	holder.add_child(_flame(Vector3(0.0, 0.22, 0.0), 1.2, 18))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.64, 0.32)
	light.light_energy = 2.6
	light.omni_range = 14.0
	light.position = Vector3(0.0, 0.4, 0.0)
	holder.add_child(_fire_light(light))


func _build_hud() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	# The dark the heroes go through from one place to the next.
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_banner = Label.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_left = -400
	_banner.offset_right = 400
	_banner.offset_top = 90
	_banner.offset_bottom = 140
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_color", Color(0.9, 0.82, 1.0))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.hide()
	_layer.add_child(_banner)
	# the run's map along the top: its ten steps, the bosses marked, where he is
	_map = Control.new()
	_map.name = "RunMap"
	_map.anchor_left = 0.5
	_map.anchor_right = 0.5
	_map.offset_left = -230.0
	_map.offset_right = 230.0
	_map.offset_top = 18.0
	_map.offset_bottom = 56.0
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	_layer.add_child(_map)


## The run's map (the user's word, 2026-10-22): a mark a step, joined, gold
## for those cleared, the one he is in ringed bright; a boss's mark larger, a
## red diamond; in a place to rest, a small blue drop between the steps it
## sits between, not one of them.
func _draw_map() -> void:
	var n := stage_count()
	if n <= 1:
		return
	var w := _map.size.x
	var y := _map.size.y * 0.5
	var gap := w / float(n - 1)
	var here := stage_of(current)
	var resting := is_rest(current)
	var gold := Color(1.0, 0.84, 0.45)
	var dim := Color(0.75, 0.7, 0.85, 0.55)
	var font := ThemeDB.fallback_font
	_map.draw_line(Vector2(0.0, y), Vector2(w, y), Color(0.0, 0.0, 0.0, 0.55), 5.0)
	_map.draw_line(Vector2(0.0, y), Vector2(gap * float(here - 1), y), Color(gold, 0.85), 2.0)
	if here < n:
		_map.draw_line(Vector2(gap * float(here - 1), y), Vector2(w, y), dim, 2.0)
	var stage := 0
	for k in steps.size():
		if is_rest(k):
			continue
		var x := gap * float(stage)
		var boss := is_boss(k)
		var done := k < cleared.size() and cleared[k]
		var size := 9.0 if boss else 6.0
		var fill := gold if done else (Color(0.95, 0.3, 0.25) if boss else Color(0.2, 0.18, 0.26))
		var edge := Color(0.95, 0.35, 0.3) if boss else (gold if done else dim)
		if boss:
			var pts := PackedVector2Array([Vector2(x, y - size), Vector2(x + size, y), Vector2(x, y + size), Vector2(x - size, y)])
			_map.draw_colored_polygon(pts, fill)
			pts.append(pts[0])
			_map.draw_polyline(pts, edge, 2.0)
		else:
			_map.draw_circle(Vector2(x, y), size, fill)
			_map.draw_arc(Vector2(x, y), size, 0.0, TAU, 20, edge, 1.5)
		if stage + 1 == here and not resting:
			_map.draw_arc(Vector2(x, y), size + 5.0, 0.0, TAU, 28, Color(1.0, 0.95, 0.8), 2.5)
		if font != null:
			_map.draw_string(font, Vector2(x - 8.0, y + size + 14.0), str(stage + 1), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 11,
					Color(1.0, 0.95, 0.85, 0.85 if stage + 1 == here else 0.5))
		stage += 1
	if resting:
		var x := gap * (float(here - 1) - 0.5)
		_map.draw_circle(Vector2(x, y), 5.0, Color(0.45, 0.8, 1.0))
		_map.draw_arc(Vector2(x, y), 10.0, 0.0, TAU, 24, Color(0.75, 0.92, 1.0), 2.0)


var _map: Control


func _say(text: String, seconds: float) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.show()
	_banner_until = Time.get_ticks_msec() / 1000.0 + seconds


#region Sounds
## The dungeon's own bus, its echo after the place (a hall rings, a cave
## more, the open air hardly), the world's sounds sent through it ([Sfx]).
func _sound_bus() -> void:
	_bus = AudioServer.get_bus_index(&"Dungeon")
	if _bus < 0:
		_bus = AudioServer.bus_count
		AudioServer.add_bus(_bus)
		AudioServer.set_bus_name(_bus, &"Dungeon")
		AudioServer.set_bus_send(_bus, &"Master")
		var echo := AudioEffectReverb.new()
		AudioServer.add_bus_effect(_bus, echo)
	Sfx.bus = &"Dungeon"


func _echo(kind: String) -> void:
	if _bus < 0 or AudioServer.get_bus_effect_count(_bus) == 0:
		return
	var echo := AudioServer.get_bus_effect(_bus, 0) as AudioEffectReverb
	if echo == null:
		return
	match kind:
		"hall":
			echo.room_size = 0.85
			echo.damping = 0.35
			echo.wet = 0.26
		"cave", "crypt":
			echo.room_size = 0.95
			echo.damping = 0.25
			echo.wet = 0.38
		"court", "throne":
			echo.room_size = 0.5
			echo.damping = 0.6
			echo.wet = 0.1
		_:
			echo.room_size = 0.3
			echo.damping = 0.8
			echo.wet = 0.04
	echo.dry = 1.0


## A sound that goes round and round.
func _loop(file: String) -> AudioStream:
	var path := SND + file
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	return stream


## The place's own sound (wind through the windows, the cave's breath, birds
## or by night nothing but the wind), and its echo.
func _ambience(i: int) -> void:
	for player in _amb:
		if is_instance_valid(player):
			player.queue_free()
	_amb.clear()
	var r := _room(i)
	var kind: String = r["kind"]
	_echo(kind)
	var night := i >= 3
	var parts: Array = []
	match kind:
		"hall":
			# the orcs' drums somewhere deep in their palace
			parts = [["wind_loop.wav", -24.0], ["drums_far_loop.wav", -25.0]]
		"court", "terrace":
			parts = [["wind_loop.wav", -15.0], ["drums_far_loop.wav", -30.0]]
		"throne":
			parts = [["wind_loop.wav", -15.0]]
		"cave":
			parts = [["cave_loop.wav", -9.0], ["crystal_hum_loop.wav", -17.0]]
		"forest":
			# the dead wood: the wind in bare boughs, no bird sings in it
			parts = [["wind_loop.wav", -14.0]]
			if night:
				parts.append(["crickets_loop.wav", -18.0])
		"sky":
			parts = [["wind_strong_loop.wav", -10.0]]
		"crypt":
			parts = [["cave_loop.wav", -14.0]]
		"swamp":
			parts = [["frogs_loop.wav", -11.0], ["wind_loop.wav", -26.0]]
			if night:
				parts.append(["crickets_loop.wav", -15.0])
		"mountain":
			parts = [["wind_strong_loop.wav", -8.0], ["rain_loop.wav", -9.0]]
		"rampart":
			parts = [["wind_loop.wav", -14.0], ["drums_far_loop.wav", -27.0]]
	for part: Array in parts:
		var stream := _loop(String(part[0]))
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = -60.0
		player.bus = &"Master"
		add_child(player)
		player.play(_rng.randf_range(0.0, 8.0))
		create_tween().tween_property(player, "volume_db", float(part[1]), 2.5)
		_amb.append(player)


## The sounds that come now and then: drips in the cave and the broken hall,
## thunder far off once the day goes, an owl in the forest at night.
func _now_and_then(delta: float, heroes: Array[Player]) -> void:
	if heroes.is_empty() or current < 0 or rooms.is_empty():
		return
	var r := _room(current)
	var kind: String = r["kind"]
	var near := heroes[0].global_position
	_drip_in -= delta
	if _drip_in <= 0.0:
		_drip_in = _rng.randf_range(1.5, 5.0)
		if kind == "cave" or kind == "crypt" or r.has("hole"):
			var at := near + Vector3(_rng.randf_range(-12.0, 12.0), 3.0, _rng.randf_range(-12.0, 12.0))
			Sfx.play(self, SND + "drip_%d.wav" % _rng.randi_range(1, 3), null, at, 1.0, -4.0, 0.15)
	_thunder_in -= delta
	if _thunder_in <= 0.0:
		_thunder_in = _rng.randf_range(25.0, 50.0)
		if _phase >= 2.5 and kind != "cave":
			Sfx.play_flat(self, SND + "thunder.wav", _rng.randf_range(0.85, 1.1), -11.0)
	_creak_in -= delta
	if _creak_in <= 0.0:
		_creak_in = _rng.randf_range(7.0, 15.0)
		if not _creaks.is_empty():
			var at: Vector3 = _creaks[_rng.randi() % _creaks.size()]
			Sfx.play(self, SND + "creak.wav", null, at, 1.0, 2.0, 0.12)
	_bats_in -= delta
	if _bats_in <= 0.0:
		_bats_in = _rng.randf_range(9.0, 20.0)
		if kind == "cave":
			var at := centre(current) + Vector3(_rng.randf_range(-15.0, 15.0), float(r["h"]) - 3.0,
					_rng.randf_range(-15.0, 15.0))
			Sfx.play(self, SND + "bats.wav", null, at, 1.0, 2.0, 0.1)
			_bat_flock(at)
	_eagle_in -= delta
	if _eagle_in <= 0.0:
		_eagle_in = _rng.randf_range(12.0, 26.0)
		if kind == "sky" or (kind == "terrace" and _phase < 2.5):
			Sfx.play_flat(self, SND + "eagle.wav", _rng.randf_range(0.92, 1.08), -9.0)
	_flap_in -= delta
	if _flap_in <= 0.0:
		_flap_in = _rng.randf_range(6.0, 13.0)
		if kind in ["court", "terrace", "throne", "sky", "rampart", "mountain"]:
			var at := near + Vector3(_rng.randf_range(-14.0, 14.0), 4.0, _rng.randf_range(-14.0, 14.0))
			Sfx.play(self, SND + "flap.wav", null, at, 1.0, -2.0, 0.15)
	_stones_in -= delta
	if _stones_in <= 0.0:
		_stones_in = _rng.randf_range(8.0, 16.0)
		if kind == "hall" or kind == "crypt":
			_falling_stones(near, float(r["h"]))
	_storm_in -= delta
	if _storm_in <= 0.0:
		_storm_in = _rng.randf_range(7.0, 15.0)
		if kind == "mountain":
			_lightning()
	_owl_in -= delta
	if _owl_in <= 0.0:
		_owl_in = _rng.randf_range(14.0, 28.0)
		if kind == "forest" or (kind == "swamp" and _phase >= 2.8):
			var at := near + Vector3(_rng.randf_range(-25.0, 25.0), 8.0, _rng.randf_range(-25.0, 25.0))
			Sfx.play(self, SND + "owl.wav", null, at, 1.0, 0.0, 0.08)


## A fire's crackle where it burns, heard close by.
func _crackle(holder: Node3D, at: Vector3) -> void:
	var stream := _loop("fire_loop.wav")
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -4.0
	player.unit_size = 2.2
	player.max_distance = 14.0
	player.bus = &"Dungeon"
	player.position = at
	holder.add_child(player)
	player.play(_rng.randf_range(0.0, 7.0))
#endregion


#region Places beyond the palace
## A model of the forest kit (assets/forest), loaded once.
func _kit(name: String) -> Mesh:
	if _models.has(name):
		return _models[name]
	var path := "res://assets/forest/%s.obj" % name
	var mesh: Mesh = load(path) as Mesh if ResourceLoader.exists(path) else null
	_models[name] = mesh
	return mesh


## A kit model in `room` at `at`, `tall` metres high, turned `yaw`.
func _prop(room: Node3D, name: String, at: Vector3, tall: float, yaw: float, shadow: bool = true) -> MeshInstance3D:
	var mesh := _kit(name)
	if mesh == null:
		return null
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var box := mesh.get_aabb()
	var s := tall / maxf(box.size.y, 0.01)
	m.scale = Vector3.ONE * s
	m.position = at - Vector3(0.0, box.position.y * s, 0.0)
	m.rotation.y = yaw
	if not shadow:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(m)
	return m


## A trunk nobody walks through.
func _post(room: Node3D, at: Vector3, radius: float, tall: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = tall
	shape.shape = cyl
	body.add_child(shape)
	body.position = at + Vector3(0.0, tall * 0.5, 0.0)
	room.add_child(body)


## Unseen walls round a place without walls of its own.
func _bounds(room: Node3D, w: float, l: float) -> void:
	_blocker(room, Vector3(1.0, BLOCK_H, l + 2.0), Vector3(-w * 0.5 - 0.5, BLOCK_H * 0.5, 0.0))
	_blocker(room, Vector3(1.0, BLOCK_H, l + 2.0), Vector3(w * 0.5 + 0.5, BLOCK_H * 0.5, 0.0))
	_blocker(room, Vector3(w + 2.0, BLOCK_H, 1.0), Vector3(0.0, BLOCK_H * 0.5, -l * 0.5 - 0.5))
	_blocker(room, Vector3(w + 2.0, BLOCK_H, 1.0), Vector3(0.0, BLOCK_H * 0.5, l * 0.5 + 0.5))


## Great rocks under a place's footprint, down into the lands far below.
func _crag_under(room: Node3D, w: float, l: float, depth: float, top: float = -1.0) -> void:
	var z := l * 0.5
	var k := 0
	while z > -l * 0.5 - 10.0:
		var crag := MeshInstance3D.new()
		crag.mesh = RockWave._crag_mesh(k % RockWave.SHAPES)
		var box := crag.mesh.get_aabb()
		var want := Vector3(w * _rng.randf_range(1.0, 1.4), depth, _rng.randf_range(40.0, 70.0))
		crag.scale = Vector3(want.x / maxf(box.size.x, 0.01), want.y / maxf(box.size.y, 0.01), want.z / maxf(box.size.z, 0.01))
		crag.position = Vector3(_rng.randf_range(-5.0, 5.0), 0.0, z - 15.0)
		crag.position.y = top - (box.position.y + box.size.y) * crag.scale.y
		crag.rotation.y = _rng.randf_range(-0.3, 0.3)
		crag.material_override = _rock_mat
		crag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(crag)
		z -= 40.0
		k += 1


## A rock of `size` (x, y, z metres) at `at`, turned `yaw`, in `mat`.
func _boulder(room: Node3D, at: Vector3, size: Vector3, yaw: float, mat: Material, shadow: bool = true,
		solid: bool = true) -> MeshInstance3D:
	var crag := MeshInstance3D.new()
	crag.mesh = RockWave._crag_mesh(_rng.randi_range(0, RockWave.SHAPES - 1))
	var box := crag.mesh.get_aabb()
	crag.scale = Vector3(size.x / maxf(box.size.x, 0.01), size.y / maxf(box.size.y, 0.01), size.z / maxf(box.size.z, 0.01))
	crag.position = at - Vector3(0.0, box.position.y * crag.scale.y, 0.0)
	crag.rotation.y = yaw
	crag.material_override = mat
	if not shadow:
		crag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(crag)
	if solid:
		_rock_body(crag)
	return crag


## A rock one cannot walk into (the user's word, 2026-10-22: the heroes went
## through the rocks): its hull, made at its own size — the body under the
## stretched rock undoes the stretch, and the hull's points take it instead,
## so it is never scaled unevenly. It goes on turning with the rock (a rock
## hung upside down, tipped).
func _rock_body(crag: MeshInstance3D) -> void:
	var hull: ConvexPolygonShape3D = _hulls.get(crag.mesh) as ConvexPolygonShape3D
	if hull == null:
		hull = crag.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		_hulls[crag.mesh] = hull
	if hull == null:
		return
	var pts := PackedVector3Array()
	for p in hull.points:
		pts.append(p * crag.scale)
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.scale = Vector3(1.0 / crag.scale.x, 1.0 / crag.scale.y, 1.0 / crag.scale.z)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	crag.add_child(body)


## Each rock shape's hull, made once.
var _hulls: Dictionary = {}


## A rock turned upside down under something, its top at `top` (its own
## frame's height), hanging down from there.
func _hang(rock: MeshInstance3D, top: float) -> void:
	rock.rotation.x = PI
	var box := rock.mesh.get_aabb()
	rock.position.y = top + box.position.y * rock.scale.y


## A forest on the mountain, dead and dark (the user's word, 2026-10-20: more
## brutal, trees without leaves, darker, a thick wood one is afraid of; no
## flowers): a clearing of bare earth, dead leaves and roots, walled round by a
## wood of bare black trees four deep, tall and close; standing stones in a
## ring, sharpened stakes with skulls on them, bones, logs; mist on the ground,
## crows over it, the light cold and little of it ([method _place_look]).
func _build_forest(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var ground := _ground_mat()
	ground.set_shader_parameter("grass_a", Color(0.09, 0.10, 0.06))
	ground.set_shader_parameter("grass_b", Color(0.15, 0.14, 0.08))
	ground.set_shader_parameter("earth", Color(0.13, 0.095, 0.065))
	ground.set_shader_parameter("moss", Color(0.07, 0.10, 0.05))
	ground.set_shader_parameter("leaves", Color(0.24, 0.14, 0.07))
	ground.set_shader_parameter("bare_from", 0.32)
	ground.set_shader_parameter("mud", 1.0)
	_solid(room, ground, Vector3(w + 90.0, 1.0, l + 90.0), Vector3(0.0, -0.5, 0.0))
	_crag_under(room, w + 90.0, l + 90.0, PalaceVista.DROP + 60.0, -1.0)
	_bounds(room, w, l)
	# The wood round the clearing, four deep and close, taller further in.
	for ring in 4:
		var out := 2.5 + float(ring) * 5.0
		var step := 3.8 + float(ring) * 1.0
		for side in 4:
			var long := (l if side < 2 else w) + out * 2.0
			var n := int(long / step)
			for k in n:
				var along := -long * 0.5 + (float(k) + _rng.randf_range(0.1, 0.9)) * step
				var at := Vector3.ZERO
				match side:
					0: at = Vector3(-w * 0.5 - out, 0.0, along)
					1: at = Vector3(w * 0.5 + out, 0.0, along)
					2: at = Vector3(along, 0.0, -l * 0.5 - out)
					_: at = Vector3(along, 0.0, l * 0.5 + out)
				at += Vector3(_rng.randf_range(-1.6, 1.6), 0.0, _rng.randf_range(-1.6, 1.6))
				var tall := _rng.randf_range(1.6, 2.5) + float(ring) * 0.25
				_nature(room, _a_dead_tree(), at, tall, _rng.randf_range(0.0, TAU), ring == 0, true)
	# (no trees inside any more, nor anything lying about the floor: the
	# user's word, 2026-10-23 — nothing for them to go behind, the clearing
	# open from end to end; the boughs still creak at the wood's edge)
	for k in 5:
		_creaks.append(room.position + Vector3((w * 0.5 + 3.0) * (1.0 if k % 2 == 0 else -1.0), 6.0,
				_rng.randf_range(-l * 0.4, l * 0.4)))
	# Sharpened stakes, a skull on some: the wood's warning.
	# (the user's word, 2026-10-21: the middle cleared — the standing stones,
	# the stream and its stones, what lay about it gone; all of it now at the
	# edge of the wood)
	for k in 14:
		var a := _rng.randf_range(0.0, TAU)
		var at := _forest_edge(w, l, a)
		_stake(room, at, k % 3 == 0)
	# mist lying on the clearing in two soft layers, drifting (the user's word,
	# 2026-10-23: pretty, and light to draw: sheets, no volumetric fog)
	_mist(room, w, l, 0.35, Color(0.74, 0.78, 0.78), 0.3, 14)
	_mist(room, w, l, 1.6, Color(0.70, 0.74, 0.75), 0.16, 8)
	_falling_leaves(room, w, l)
	_circling_birds(room)


## A spot at the edge of the forest's clearing, along bearing `a`: in the
## outer band, next to the trees, the middle left clear.
func _forest_edge(w: float, l: float, a: float) -> Vector3:
	var reach := _rng.randf_range(0.78, 0.96)
	var dir := Vector2(sin(a), cos(a))
	var to_side := minf(w * 0.5 / maxf(absf(dir.x), 0.001), l * 0.5 / maxf(absf(dir.y), 0.001))
	return Vector3(dir.x * to_side * reach, 0.0, dir.y * to_side * reach)


## The dead wood's trees: bare ones, and the twisted ones with their leaves
## stripped.
func _a_dead_tree() -> String:
	if _rng.randf() < 0.7:
		return "DeadTree_%d" % _rng.randi_range(1, 5)
	return "TwistedTree_%d" % _rng.randi_range(1, 5)


## A sharpened stake driven into the earth, leaning, a skull on it if `skull`.
func _stake(room: Node3D, at: Vector3, skull: bool) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.25, 0.25))
	room.add_child(holder)
	var tall := _rng.randf_range(1.8, 2.6)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.09
	pole.bottom_radius = 0.12
	pole.height = tall
	pole.radial_segments = 6
	var pm := MeshInstance3D.new()
	pm.mesh = pole
	pm.material_override = _wood_mat
	pm.position = Vector3(0.0, tall * 0.5, 0.0)
	holder.add_child(pm)
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.09
	tip.height = 0.35
	tip.radial_segments = 6
	var tm := MeshInstance3D.new()
	tm.mesh = tip
	tm.material_override = _wood_mat
	tm.position = Vector3(0.0, tall + 0.17, 0.0)
	holder.add_child(tm)
	if skull:
		OrcSpoils._skull(self, holder, Vector3(0.0, tall - 0.02, 0.0), 1.15)
	_blocker(room, Vector3(0.3, tall, 0.3), at + Vector3(0.0, tall * 0.5, 0.0))


## Dead leaves coming down through the bare wood, slowly, turning.
func _falling_leaves(room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(0.0, 9.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.5, 1.0, l * 0.5)
	pm.gravity = Vector3(0.3, -0.9, 0.1)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.3
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	pm.color = Color(0.32, 0.2, 0.1)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.09)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.roughness = 1.0
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -12, -l), Vector3(w * 2.0, 16.0, l * 2.0))
	room.add_child(p)


## Fireflies over the clearing (seen once it grows dark).
func _fireflies(room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 6.0
	p.position = Vector3(0.0, 1.6, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.45, 1.2, l * 0.45)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.9, 0.3, 0.0))
	fade.add_point(0.3, Color(1.0, 0.92, 0.35, 1.0))
	fade.add_point(0.7, Color(0.9, 1.0, 0.4, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.9, 0.3, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(2.0, 2.0, 1.2)
	# a soft round glow (the user's word, 2026-10-23: not squares)
	qm.albedo_texture = PlaceBuild.soft_dot()
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -2, -l), Vector3(w * 2.0, 6.0, l * 2.0))
	room.add_child(p)


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
	var path := "res://glTF/%s.gltf" % name
	var scene: PackedScene = _models.get(path) as PackedScene
	if scene == null:
		if not ResourceLoader.exists(path):
			return null
		scene = load(path) as PackedScene
		_models[path] = scene
	if scene == null:
		return null
	var n := scene.instantiate() as Node3D
	n.position = at
	n.rotation.y = yaw
	# the kit's twisted trees stand twice as tall as the rest, its flowers
	# as tall as a man
	if name.begins_with("TwistedTree"):
		scale *= 0.5
	elif name.begins_with("Flower"):
		scale *= 0.45
	n.scale = Vector3.ONE * scale
	room.add_child(n)
	if bare:
		_strip_leaves(n)
	_solid_nature(n, name)
	if not shadow:
		for m in n.find_children("*", "GeometryInstance3D", true, false):
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Trees and rocks of the kit stand in the way (the user's word, 2026-10-22:
## the heroes walked through them): a trunk for a tree, its hull for a rock,
## in the model's own frame (the node is scaled evenly).
func _solid_nature(n: Node3D, name: String) -> void:
	var holder: Node3D = n
	var shape: Shape3D = null
	var at := Vector3.ZERO
	if name.contains("Tree"):
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.45
		trunk.height = 6.0
		shape = trunk
		at = Vector3(0.0, 3.0, 0.0)
	elif name.begins_with("Rock_"):
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			return
		var mesh := meshes[0] as MeshInstance3D
		var hull: ConvexPolygonShape3D = _hulls.get(mesh.mesh) as ConvexPolygonShape3D
		if hull == null:
			hull = mesh.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
			_hulls[mesh.mesh] = hull
		shape = hull
		# in the mesh's own frame, whatever the model's nodes do to it
		holder = mesh
	if shape == null:
		return
	var body := StaticBody3D.new()
	body.name = "Solid"
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = at
	body.add_child(col)
	holder.add_child(body)


## A tree of the kit with its leaves taken off (the dead wood's).
func _strip_leaves(n: Node3D) -> void:
	for node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var am := mi.mesh as ArrayMesh
		if am == null:
			continue
		var bare: ArrayMesh = _bare_meshes.get(am) as ArrayMesh
		if bare == null:
			bare = am.duplicate() as ArrayMesh
			for k in range(bare.get_surface_count() - 1, -1, -1):
				var m := bare.surface_get_material(k)
				if m != null and m.resource_name.to_lower().contains("lea"):
					bare.surface_remove(k)
			_bare_meshes[am] = bare
		if bare.get_surface_count() == 0:
			mi.visible = false
		else:
			mi.mesh = bare


## The forest's trees, at random, the big leafy ones most of all.
func _a_tree() -> String:
	var roll := _rng.randf()
	if roll < 0.55:
		return "CommonTree_%d" % _rng.randi_range(1, 5)
	if roll < 0.9:
		return "Pine_%d" % _rng.randi_range(1, 5)
	if roll < 0.96:
		return "TwistedTree_%d" % _rng.randi_range(1, 5)
	return "DeadTree_%d" % _rng.randi_range(1, 5)


## A green tree: the broadleaf and the pine, never the red twisted one.
func _a_green_tree() -> String:
	if _rng.randf() < 0.65:
		return "CommonTree_%d" % _rng.randi_range(1, 5)
	return "Pine_%d" % _rng.randi_range(1, 5)


## The sea of cloud under the island: soft layers one over another.
func _cloud_layers(room: Node3D, base: float = -78.0) -> void:
	_cloud_layer_mats.clear()
	var sh := Shader.new()
	sh.code = CLOUD_LAYER_SHADER
	for k in 4:
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2600.0, 2600.0)
		m.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("seed", float(k) * 13.7)
		mat.set_shader_parameter("cover", 0.42 + float(k) * 0.08)
		mat.set_shader_parameter("opacity", 0.55 + float(k) * 0.12)
		mat.set_shader_parameter("middle", Vector2(room.global_position.x, room.global_position.z))
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(0.0, base + float(k) * (7.0 if base < -60.0 else 4.0), 0.0)
		room.add_child(m)
		_cloud_layer_mats.append(mat)
	_apply_phase(_phase)


## An island in the sky: a round temple arena on a floating rock over a sea of
## cloud (the user's pick of the concept pictures, 2026-10-23; [SkyTemple]
## builds it). The place is 56 m square only so that its round floor fits:
## an unseen wall stands round the rim at 28.6 m.
func _build_sky(room: Node3D, i: int) -> void:
	var r := _room(i)
	SkyTemple.build(self, room, _rng)
	# the sea of cloud close under the island, so nothing shows below it
	_cloud_layers(room, -40.0)
	_circling_birds(room)
	_motes(room, float(r["w"]) * 0.7, float(r["l"]) * 0.7, 10.0)

#endregion


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
	var z := l * 0.12
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.2, w + 80.0)
	water.mesh = plane
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WATER_SHADER
	mat.shader = sh
	water.material_override = mat
	water.rotation.y = PI * 0.5 + 0.12
	water.position = Vector3(0.0, 0.04, z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(water)
	# its banks: stones along both sides
	for k in 40:
		var x := -w * 0.55 + float(k) * (w * 1.1 / 40.0)
		for side: float in [-1.0, 1.0]:
			var at := Vector3(x, 0.0, z + side * 1.9 + x * 0.12 + _rng.randf_range(-0.3, 0.3))
			_prop(room, "Rock_%d" % _rng.randi_range(1, 9), at, _rng.randf_range(0.25, 0.6), _rng.randf_range(0.0, TAU), false)
	for k in 3:
		var x := -6.0 + float(k) * 6.0
		_prop(room, "Stepping_Stone_%d" % (k + 1), Vector3(x, 0.02, z + x * 0.12), 0.25, _rng.randf_range(0.0, TAU), false)
	var stream := _loop("stream_loop.wav")
	if stream != null:
		for x: float in [-w * 0.3, w * 0.3]:
			var sound := AudioStreamPlayer3D.new()
			sound.stream = stream
			sound.volume_db = -6.0
			sound.unit_size = 5.0
			sound.max_distance = 30.0
			sound.bus = &"Dungeon"
			sound.position = Vector3(x, 0.3, z + x * 0.12)
			room.add_child(sound)
			sound.play(_rng.randf_range(0.0, 10.0))


## Mist lying low over the ground, drifting.
func _mist(room: Node3D, w: float, l: float, y: float, tint: Color, thick: float, count: int = 10) -> void:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MIST_SHADER
	mat.shader = sh
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("thick", thick)
	for k in count:
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(_rng.randf_range(18.0, 34.0), _rng.randf_range(18.0, 34.0))
		m.mesh = plane
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(_rng.randf_range(-w * 0.45, w * 0.45), y + _rng.randf_range(0.0, 0.8),
				_rng.randf_range(-l * 0.45, l * 0.45))
		room.add_child(m)


## Butterflies over the flowers, by day.
func _butterflies(room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 8.0
	p.position = Vector3(0.0, 1.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.42, 0.6, l * 0.42)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.0
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 2.0
	var cols := Gradient.new()
	cols.set_color(0, Color(1.0, 0.85, 0.2))
	cols.add_point(0.5, Color(0.95, 0.4, 0.75))
	cols.set_color(cols.get_point_count() - 1, Color(0.4, 0.75, 1.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = cols
	pm.color_initial_ramp = ramp
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.12)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.vertex_color_use_as_albedo = true
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -2, -l), Vector3(w * 2.0, 8.0, l * 2.0))
	room.add_child(p)


## Some of a cave's mushrooms give a light of their own.
func _glow(m: MeshInstance3D, tint: Color) -> void:
	if m == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint.darkened(0.4)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 1.8
	m.material_override = mat
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 0.8
	light.omni_range = 4.0
	light.position = Vector3(0.0, 0.6 / maxf(m.scale.y, 0.01), 0.0)
	m.add_child(light)


## Birds circling the island, far off and near.
func _circling_birds(room: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.07)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 7:
		var bird := Node3D.new()
		for side: float in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(1.4, 0.05, 0.45)
			wing.mesh = wm
			wing.material_override = mat
			wing.position = Vector3(side * 0.7, 0.0, 0.0)
			wing.name = "L" if side < 0.0 else "R"
			bird.add_child(wing)
		room.add_child(bird)
		_birds.append({"node": bird, "radius": _rng.randf_range(40.0, 120.0), "height": _rng.randf_range(8.0, 40.0),
				"speed": _rng.randf_range(0.08, 0.2) * (1.0 if k % 2 == 0 else -1.0), "at": _rng.randf_range(0.0, TAU)})


func _fly_birds(delta: float) -> void:
	for b in _birds:
		var node := b["node"] as Node3D
		if not is_instance_valid(node):
			continue
		b["at"] = float(b["at"]) + float(b["speed"]) * delta
		var a: float = b["at"]
		var r: float = b["radius"]
		node.position = Vector3(sin(a) * r, float(b["height"]) + sin(a * 3.0) * 2.0, cos(a) * r)
		node.rotation.y = a + (PI * 0.5 if float(b["speed"]) > 0.0 else -PI * 0.5)
		var flap := sin(Time.get_ticks_msec() / 1000.0 * 7.0 + r) * 0.5
		(node.get_node("L") as Node3D).rotation.z = flap
		(node.get_node("R") as Node3D).rotation.z = -flap


## Blades left standing in the floor where the orcs' fights were.
func _blades_in_floor(room: Node3D, w: float, l: float, count: int) -> void:
	for k in count:
		var sword := Node3D.new()
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var long := _rng.randf_range(0.9, 1.5)
		bm.size = Vector3(0.09, long, 0.025)
		blade.mesh = bm
		blade.material_override = _iron_mat
		blade.position = Vector3(0.0, long * 0.5 - 0.25, 0.0)
		sword.add_child(blade)
		var guard := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.36, 0.05, 0.06)
		guard.mesh = gm
		guard.material_override = _gold_mat if k % 3 == 0 else _iron_mat
		guard.position = Vector3(0.0, long - 0.25, 0.0)
		sword.add_child(guard)
		var grip := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 0.22
		grip.mesh = cm
		grip.material_override = _wood_mat
		grip.position = Vector3(0.0, long - 0.12, 0.0)
		sword.add_child(grip)
		var x := _rng.randf_range(-w * 0.42, w * 0.42)
		var z := _rng.randf_range(-l * 0.4, l * 0.4)
		if absf(x) < 4.0:
			x += 6.0 * signf(x + 0.01)
		sword.position = Vector3(x, 0.0, z)
		sword.rotation = Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.35, 0.35))
		room.add_child(sword)
#endregion


#region Round 10: more places (the crypt, the swamp, the stormy mountain, the rampart)
## The graveyard kit's props (assets/necropoly: candles, chains, lanterns, the
## tomb niche, the swamp's grass, roots and stones), dressed as [NecroPlaces]
## dresses them: its palette, and a glow for what burns.
func _necro(name: String) -> Mesh:
	if _necro_meshes.is_empty():
		_necro_mat = ShaderMaterial.new()
		_necro_mat.shader = load("res://shaders/necro.gdshader")
		_necro_mat.set_shader_parameter(&"palette", load("res://assets/necropoly/necro_palette.png"))
		_necro_mat.set_shader_parameter(&"ours", 1.0)
		_necro_glow = StandardMaterial3D.new()
		_necro_glow.albedo_color = Color(1.0, 0.62, 0.25)
		_necro_glow.emission_enabled = true
		_necro_glow.emission = Color(1.0, 0.55, 0.2)
		_necro_glow.emission_energy_multiplier = 3.0
		var scene := load("res://assets/necropoly/necro_props.glb") as PackedScene
		if scene != null:
			var root := scene.instantiate()
			for node in root.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				var am := mi.mesh as ArrayMesh
				if am == null:
					continue
				var copy := am.duplicate() as ArrayMesh
				for k in copy.get_surface_count():
					var m := copy.surface_get_material(k)
					var lit := m != null and m.resource_name.contains("glow")
					copy.surface_set_material(k, _necro_glow if lit else _necro_mat)
				_necro_meshes[String(mi.name)] = copy
			root.free()
	return _necro_meshes.get(name) as Mesh


func _necro_put(room: Node3D, name: String, at: Vector3, yaw: float, size: float = 1.0, shadow: bool = true) -> MeshInstance3D:
	var mesh := _necro(name)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size * 0.4), at)
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(mi)
	return mi


## A cluster of candles burning, with the little light they give.
func _candles(room: Node3D, at: Vector3, light: bool = true) -> void:
	for k in _rng.randi_range(2, 4):
		_necro_put(room, ["EA_Candle_01a", "EA_Candle_01b", "EA_Candle_01c"][k % 3],
				at + Vector3(_rng.randf_range(-0.35, 0.35), 0.0, _rng.randf_range(-0.35, 0.35)), _rng.randf_range(0.0, TAU),
				_rng.randf_range(0.8, 1.3), false)
	room.add_child(_flame(at + Vector3(0.0, 0.45, 0.0), 0.6, 8))
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 1.4
		l.omni_range = 7.0
		l.position = at + Vector3(0.0, 0.8, 0.0)
		room.add_child(_fire_light(l))


## Old bones lying: a few long ones and a skull.
func _bones(room: Node3D, at: Vector3) -> void:
	if _bone_mat == null:
		_bone_mat = StandardMaterial3D.new()
		_bone_mat.albedo_color = Color(0.78, 0.74, 0.64)
		_bone_mat.roughness = 0.8
	for k in _rng.randi_range(3, 6):
		var b := CylinderMesh.new()
		b.top_radius = 0.04
		b.bottom_radius = 0.05
		b.height = _rng.randf_range(0.35, 0.7)
		b.radial_segments = 6
		var m := _deco(room, _bone_mat, b, at + Vector3(_rng.randf_range(-0.6, 0.6), 0.05, _rng.randf_range(-0.6, 0.6)))
		m.rotation = Vector3(PI * 0.5, _rng.randf_range(0.0, TAU), 0.0)
	var skull := SphereMesh.new()
	skull.radius = 0.13
	skull.height = 0.24
	skull.radial_segments = 10
	skull.rings = 5
	_deco(room, _bone_mat, skull, at + Vector3(0.0, 0.12, 0.0))


## A swamp (the user's word: somewhere else again): dark mud and moss, pools of
## still green water, dead trees and twisted roots, reeds and swamp grass, a
## low sickly mist, frogs and the night's crickets.
func _build_swamp(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var ground := _ground_mat()
	# mud more than grass
	ground.set_shader_parameter("grass_a", Color(0.11, 0.12, 0.07))
	ground.set_shader_parameter("grass_b", Color(0.15, 0.15, 0.08))
	ground.set_shader_parameter("earth", Color(0.13, 0.10, 0.07))
	ground.set_shader_parameter("moss", Color(0.10, 0.14, 0.06))
	ground.set_shader_parameter("leaves", Color(0.18, 0.13, 0.07))
	ground.set_shader_parameter("path_amount", 0.0)
	ground.set_shader_parameter("bare_from", 0.3)
	ground.set_shader_parameter("mud", 1.0)
	_solid(room, ground, Vector3(w + 90.0, 1.0, l + 90.0), Vector3(0.0, -0.5, 0.0))
	_crag_under(room, w + 90.0, l + 90.0, PalaceVista.DROP + 60.0, -1.0)
	_bounds(room, w, l)
	# pools of still water (the user's word, 2026-10-21: not that water):
	# a few great ones, ragged at their edges, weed and duckweed on them
	var spots: Array[Vector3] = [Vector3(-w * 0.24, 0.0, -l * 0.2), Vector3(w * 0.26, 0.0, -l * 0.05),
			Vector3(-w * 0.18, 0.0, l * 0.18), Vector3(w * 0.12, 0.0, -l * 0.36), Vector3(w * 0.3, 0.0, l * 0.3)]
	for at in spots:
		PlaceBuild.pool(room, at + Vector3(_rng.randf_range(-2.0, 2.0), 0.03, _rng.randf_range(-2.0, 2.0)),
				Vector2(_rng.randf_range(11.0, 16.0), _rng.randf_range(8.0, 12.0)), _rng.randf_range(0.0, TAU),
				{"weed_amount": 0.18, "shine": 0.22, "deep": Color(0.02, 0.04, 0.035), "shallow": Color(0.09, 0.11, 0.07)})
	# the dead wood round it, and inside
	for ring in 2:
		var out := 3.0 + float(ring) * 8.0
		for side in 4:
			var long := (l if side < 2 else w) + out * 2.0
			var count := int(long / 7.0)
			for k in count:
				var along := -long * 0.5 + (float(k) + _rng.randf_range(0.1, 0.9)) * 7.0
				var at := Vector3.ZERO
				match side:
					0: at = Vector3(-w * 0.5 - out, 0.0, along)
					1: at = Vector3(w * 0.5 + out, 0.0, along)
					2: at = Vector3(along, 0.0, -l * 0.5 - out)
					_: at = Vector3(along, 0.0, l * 0.5 + out)
				var name := "DeadTree_%d" % _rng.randi_range(1, 5) if _rng.randf() < 0.65 else "TwistedTree_%d" % _rng.randi_range(1, 5)
				_nature(room, name, at, _rng.randf_range(1.1, 1.7), _rng.randf_range(0.0, TAU), ring == 0, true)
	# behind the dead ones, green trees among bare: one or two green, then
	# bare again (the user's word, 2026-10-23); nothing lying on the floor,
	# no trees inside
	for ring in 2:
		var out := 19.0 + float(ring) * 8.0
		var nth := 0
		for side in 4:
			var long := (l if side < 2 else w) + out * 2.0
			var count := int(long / 8.0)
			for k in count:
				var along := -long * 0.5 + (float(k) + _rng.randf_range(0.15, 0.85)) * 8.0
				var at := Vector3.ZERO
				match side:
					0: at = Vector3(-w * 0.5 - out, 0.0, along)
					1: at = Vector3(w * 0.5 + out, 0.0, along)
					2: at = Vector3(along, 0.0, -l * 0.5 - out)
					_: at = Vector3(along, 0.0, l * 0.5 + out)
				nth += 1
				if nth % 3 != 0:
					_nature(room, _a_green_tree(), at, _rng.randf_range(1.3, 1.9), _rng.randf_range(0.0, TAU), false)
				else:
					_nature(room, "DeadTree_%d" % _rng.randi_range(1, 5), at, _rng.randf_range(1.2, 1.7),
							_rng.randf_range(0.0, TAU), false, true)
	_mist(room, w, l, 0.25, Color(0.66, 0.72, 0.62), 0.24, 12)
	_fireflies(room, w, l)


## A mountain path in a storm (the user's word: a stormy mountain path):
## a broken shelf of rock high among the peaks, cliffs round it, a few pines
## bent by the wind, snow in the hollows, rain driven across it, the sky dark
## and lit by lightning.
func _build_mountain(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	# the shelf: bare rock, dark with the rain, puddles in its hollows (the
	# user's word, 2026-10-21: not that floor; not the stones in the middle;
	# the rain finer, and the wet felt on him)
	var shelf := _rock_mat.duplicate() as ShaderMaterial
	shelf.set_shader_parameter("scale", 0.3)
	shelf.set_shader_parameter("rock_a", Color(0.26, 0.27, 0.30))
	shelf.set_shader_parameter("rock_b", Color(0.11, 0.12, 0.14))
	shelf.set_shader_parameter("band", Color(0.36, 0.36, 0.38))
	shelf.set_shader_parameter("moss", Color(0.16, 0.2, 0.12))
	shelf.set_shader_parameter("moss_amount", 0.35)
	shelf.set_shader_parameter("wet", 1.0)
	_solid(room, shelf, Vector3(w + 20.0, 1.0, l + 20.0), Vector3(0.0, -0.5, 0.0))
	_crag_under(room, w + 30.0, l + 30.0, PalaceVista.DROP + 120.0, -1.0)
	_bounds(room, w, l)
	# cliffs: great rocks along both long sides, the near and far ends open to
	# the drop; grey, wet, snow only high up
	var cliff := _rock_mat.duplicate() as ShaderMaterial
	cliff.set_shader_parameter("rock_a", Color(0.40, 0.41, 0.44))
	cliff.set_shader_parameter("rock_b", Color(0.18, 0.19, 0.22))
	cliff.set_shader_parameter("band", Color(0.48, 0.48, 0.51))
	cliff.set_shader_parameter("moss", Color(0.86, 0.88, 0.93))
	cliff.set_shader_parameter("moss_amount", 0.55)
	cliff.set_shader_parameter("wet", 0.9)
	for side: float in [-1.0, 1.0]:
		var z := -l * 0.5 - 6.0
		while z < l * 0.5 + 6.0:
			var tall := _rng.randf_range(14.0, 34.0)
			_boulder(room, Vector3(side * (w * 0.5 + _rng.randf_range(3.0, 8.0)), -2.0, z),
					Vector3(_rng.randf_range(12.0, 20.0), tall, _rng.randf_range(10.0, 16.0)), _rng.randf_range(0.0, TAU), cliff)
			z += _rng.randf_range(7.0, 11.0)
	# pines along the cliffs' feet, wind-bent; a few stones and tufts there
	for k in 10:
		var x := (w * _rng.randf_range(0.4, 0.5)) * (1.0 if k % 2 == 0 else -1.0)
		_nature(room, "Pine_%d" % _rng.randi_range(1, 5), Vector3(x, 0.0, _rng.randf_range(-l * 0.45, l * 0.45)),
				_rng.randf_range(1.2, 2.0), _rng.randf_range(0.0, TAU))
	for k in 16:
		var x := (w * _rng.randf_range(0.38, 0.48)) * (1.0 if k % 2 == 0 else -1.0)
		_nature(room, ["Grass_Wispy_Short", "Pebble_Round_3", "Rock_Medium_2", "Fern_1"][k % 4],
				Vector3(x, 0.0, _rng.randf_range(-l * 0.46, l * 0.46)), _rng.randf_range(0.8, 1.3), _rng.randf_range(0.0, TAU), false)
	# an old shrine of the road at the far end: a broken arch
	for side: float in [-1.0, 1.0]:
		_column(room, i, Vector3(side * 4.0, 0.0, -l * 0.3), 7.0, 0.9)
	var lintel := BoxMesh.new()
	lintel.size = Vector3(9.5, 0.9, 1.4)
	var lt := _deco(room, _trim_mat, lintel, Vector3(0.6, 7.2, -l * 0.3))
	lt.rotation.z = -0.08
	PlaceBuild.puddles(self, room, w, l)
	_rain(room, w, l)
	PlaceBuild.splashes(room, w, l)


## Rain driven across a place.
func _rain(room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 5000
	p.lifetime = 1.0
	p.position = Vector3(0.0, 22.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.7, 1.0, l * 0.7)
	pm.direction = Vector3(0.25, -1.0, 0.1)
	pm.spread = 3.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 28.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.gravity = Vector3(0.0, -10.0, 0.0)
	pm.particle_flag_align_y = true
	p.process_material = pm
	# thin streaks soft at their edges and ends (the user's word, 2026-10-23:
	# squares, like hail)
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.9)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.82, 0.86, 0.92, 0.22)
	qm.albedo_texture = PlaceBuild.streak()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.billboard_keep_scale = true
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -30, -l), Vector3(w * 2.0, 40.0, l * 2.0))
	room.add_child(p)


## The castle's rampart (the user's word: a broken castle wall): a long
## walk along the top of the wall, its battlements broken here and there and
## the gaps blocked with rubble, a tower at each end, fires still burning from
## the fighting, arrows stuck in the stones, banners torn by the wind.
func _build_rampart(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	_solid(room, _floor_mat(i), Vector3(w + WALL_T * 2.0, 1.0, l + WALL_T * 2.0), Vector3(0.0, -0.5, 0.0))
	_solid(room, _wall_mat, Vector3(w + WALL_T * 2.0, 40.0, l + WALL_T * 2.0), Vector3(0.0, -20.5, 0.0), false)
	_crag_under(room, w + 20.0, l + 20.0, PalaceVista.DROP + 40.0, -40.0)
	_bounds(room, w, l)
	# over the battlements' whole thickness and beyond, and the ends, so no
	# one climbs onto them and off (the user's word, 2026-10-23: he jumped
	# over and fell)
	for side: float in [-1.0, 1.0]:
		_blocker(room, Vector3(WALL_T + 3.0, BLOCK_H, l + 8.0), Vector3(side * (w * 0.5 + WALL_T * 0.5 + 1.0), BLOCK_H * 0.5, 0.0))
		_blocker(room, Vector3(w + 8.0, BLOCK_H, 3.0), Vector3(0.0, BLOCK_H * 0.5, side * (l * 0.5 + 1.5)))
	# the battlements: a breast-high wall, merlons on it, broken in places
	for side: float in [-1.0, 1.0]:
		var x := side * (w * 0.5 + WALL_T * 0.5)
		var z := -l * 0.5
		while z < l * 0.5:
			var piece := minf(_rng.randf_range(5.0, 9.0), l * 0.5 - z)
			var broken := _rng.randf() < 0.2
			var hh := 1.4 if broken else 2.2
			_solid(room, _wall_mat, Vector3(WALL_T, hh, piece), Vector3(x, hh * 0.5, z + piece * 0.5))
			if broken:
				_rubble(room, Vector3(x - side * 1.2, 0.0, z + piece * 0.5), 2.0, 10, int(z * 7.0))
			else:
				var mz := z + 0.8
				while mz < z + piece - 0.6:
					var merlon := BoxMesh.new()
					merlon.size = Vector3(WALL_T, 1.1, 1.0)
					_deco(room, _wall_mat, merlon, Vector3(x, hh + 0.55, mz))
					mz += 2.0
			z += piece
	# a tower at each end
	for end: float in [-1.0, 1.0]:
		var tower := CylinderMesh.new()
		tower.top_radius = w * 0.42
		tower.bottom_radius = w * 0.45
		tower.height = 26.0
		tower.radial_segments = 16
		_deco(room, _wall_mat, tower, Vector3(0.0, 13.0 - 6.0, end * (l * 0.5 + w * 0.42)))
		var roof := CylinderMesh.new()
		roof.top_radius = 0.0
		roof.bottom_radius = w * 0.5
		roof.height = 10.0
		roof.radial_segments = 16
		var rf := _deco(room, _wood_mat, roof, Vector3(0.0, 25.0, end * (l * 0.5 + w * 0.42)))
		if end > 0.0:
			# its roof half burnt away
			rf.scale = Vector3(1.0, 0.55, 1.0)
			rf.rotation.z = 0.25
	# what the fighting left: arrows, blades (the fires lying in the way gone:
	# the user's word, 2026-10-23, he walked through them)
	_arrows(room, w, l, 40)
	_blades_in_floor(room, w, l, 8)
	for k in 6:
		var side := -1.0 if k % 2 == 0 else 1.0
		_hang_banner(room, Vector3(side * (w * 0.5 + 0.6), 6.0, -l * 0.35 + floorf(float(k) / 2.0) * l * 0.35), side, 4.5)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.07
		pole.bottom_radius = 0.07
		pole.height = 6.4
		_deco(room, _wood_mat, pole, Vector3(side * (w * 0.5 + 0.75), 3.0, -l * 0.35 + floorf(float(k) / 2.0) * l * 0.35))


## Arrows stuck in the floor where a volley came down.
func _arrows(room: Node3D, w: float, l: float, count: int) -> void:
	var fletch := StandardMaterial3D.new()
	fletch.albedo_color = Color(0.7, 0.66, 0.6)
	for k in count:
		var arrow := Node3D.new()
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.015
		shaft.bottom_radius = 0.015
		shaft.height = 0.75
		shaft.radial_segments = 5
		var s := MeshInstance3D.new()
		s.mesh = shaft
		s.material_override = _wood_mat
		s.position = Vector3(0.0, 0.3, 0.0)
		arrow.add_child(s)
		var f := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.12, 0.16, 0.01)
		f.mesh = fm
		f.material_override = fletch
		f.position = Vector3(0.0, 0.62, 0.0)
		arrow.add_child(f)
		arrow.position = Vector3(_rng.randf_range(-w * 0.45, w * 0.45), 0.0, _rng.randf_range(-l * 0.45, l * 0.45))
		arrow.rotation = Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.5, 0.5))
		room.add_child(arrow)


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


#region Round 10: the first hall livelier, blows seen
## What a fight long ago left in a hall: shields broken and spears, bones.
func _battle_remains(room: Node3D, w: float, l: float) -> void:
	# only the arrows now (the user's word, 2026-10-23: nothing else lying
	# about the hall's floor)
	for k in 0:
		var at := Vector3(_rng.randf_range(-w * 0.42, w * 0.42), 0.0, _rng.randf_range(-l * 0.42, l * 0.42))
		if absf(at.x) < 3.5:
			at.x += 6.0 * signf(at.x + 0.01)
		var shield := CylinderMesh.new()
		shield.top_radius = 0.5
		shield.bottom_radius = 0.5
		shield.height = 0.06
		shield.radial_segments = 14
		var sh := _deco(room, _wood_mat, shield, at + Vector3(0.0, 0.05, 0.0))
		sh.rotation = Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))
		var rim := CylinderMesh.new()
		rim.top_radius = 0.53
		rim.bottom_radius = 0.53
		rim.height = 0.04
		rim.radial_segments = 14
		_deco(room, _iron_mat, rim, at + Vector3(0.0, 0.03, 0.0))
		var spear := CylinderMesh.new()
		spear.top_radius = 0.03
		spear.bottom_radius = 0.03
		spear.height = 2.4
		spear.radial_segments = 5
		var sp := _deco(room, _wood_mat, spear, at + Vector3(_rng.randf_range(-1.0, 1.0), 0.05, _rng.randf_range(-1.0, 1.0)))
		sp.rotation = Vector3(PI * 0.5, _rng.randf_range(0.0, TAU), 0.0)
		if k % 2 == 0:
			_bones(room, at + Vector3(1.2, 0.0, 0.6))
	_arrows(room, w, l, 18)


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


## The banners' cloth, torn: ragged at the foot, holed (the user's word: torn banners).
func _torn_cloth() -> ShaderMaterial:
	if _banner_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 cloth : source_color = vec4(0.30, 0.08, 0.38, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(wpos.x + wpos.z, wpos.y);
	float ragged = noise(vec2(p.x * 3.0, 0.0)) * 0.25 + noise(vec2(p.x * 9.0, 1.0)) * 0.1;
	if (UV.y > 0.72 + ragged) { discard; }
	if (noise(p * 2.2) > 0.82) { discard; }
	float burn = smoothstep(0.62, 0.8, UV.y + ragged * 0.5);
	ALBEDO = mix(cloth.rgb * (0.75 + 0.35 * noise(p * 6.0)), vec3(0.05, 0.03, 0.02), burn);
	ROUGHNESS = 0.95;
}
"""
		_banner_mat = ShaderMaterial.new()
		_banner_mat.shader = sh
	return _banner_mat
