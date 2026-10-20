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
## How far apart the places of one run are built (m, along −Z).
const STEP_GAP := 420.0
## Seconds the screen takes to go dark, and to come back.
const FADE := 0.45
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

## The orcs of the first dungeon (the user's word, 2026-10-20): before the last
## place two of different kinds, one with two swords, one with a long sword,
## neither with its whole run of combos; in the last, the lord of the orcs with
## his great sword.
## Here they are harder than out in the land (the user's word, 2026-10-20: a
## hero come up through the dungeon killed them far too easily): about twice
## the health, harder blows; the lord most of all.
const ORC_TWO_SWORDS := {"hand_combo_chance": Vector2(0.3, 0.55), "max_health": 720.0, "hit_damage": 72.0}
const ORC_LONG_SWORD := {"arm_right": "longsword", "arm_left": "none", "hand_combo_chance": Vector2(0.15, 0.4),
		"max_health": 720.0, "hit_damage": 76.0}
const ORC_LORD := {"arm_right": "greatsword", "arm_style": "black", "outfit": "Lord", "cape": "Black cape",
		"combo_rest": Vector2(2.0, 3.0), "max_health": 1650.0, "hit_damage": 92.0}

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
	"forest": {"name": "ტყე", "kind": "forest", "w": 58.0, "l": 64.0, "h": 0.0},
	"sky": {"name": "ცის კუნძული", "kind": "sky", "w": 52.0, "l": 58.0, "h": 0.0, "lift": 160.0},
	"throne": {"name": "ტახტის ეზო", "kind": "throne", "w": 66.0, "l": 78.0, "h": 6.0},
	"crypt": {"name": "აკლდამა", "kind": "crypt", "w": 36.0, "l": 60.0, "h": 9.0},
	"swamp": {"name": "ჭაობი", "kind": "swamp", "w": 58.0, "l": 62.0, "h": 0.0},
	"mountain": {"name": "ქარიშხლის ბილიკი", "kind": "mountain", "w": 46.0, "l": 64.0, "h": 0.0, "lift": 60.0},
	"rampart": {"name": "ციხის გალავანი", "kind": "rampart", "w": 26.0, "l": 80.0, "h": 0.0},
}

## Per dungeon, its run: each step the places its portals may lead to, the
## creatures in each ("*" any of them) as [scene, count, props], the level
## they show ("lv"), what clearing it gives on top of them ("xp", wolves'
## worth) and the level it tops him up to ("reach"). The first dungeon: imps in
## the hall; imps and puglins, puglins and goblins, or goblins and imps; more
## of them; the two orcs, taking turns; the lord of the orcs alone.
const RUN := {
	0: [
		{"places": ["hall"], "lv": 1, "xp": 1.5, "reach": 2, "foes": {"*": [[IMP, 8]]}},
		{"places": ["court", "cave", "forest", "crypt", "swamp"], "lv": 3, "xp": 2.5, "reach": 4,
				"foes": {"court": [[IMP, 5], [PUGLIN, 5]], "cave": [[PUGLIN, 6], [GOBLIN, 4]],
						"forest": [[GOBLIN, 5], [IMP, 4]], "crypt": [[IMP, 5], [GOBLIN, 4]],
						"swamp": [[PUGLIN, 6], [GOBLIN, 4]]}},
		{"places": ["great_hall", "cave", "sky", "forest", "crypt", "swamp", "mountain"], "lv": 5, "xp": 3.0, "reach": 6,
				"foes": {"great_hall": [[PUGLIN, 5], [IMP, 5]], "cave": [[PUGLIN, 5], [GOBLIN, 5]],
						"sky": [[IMP, 5], [GOBLIN, 5]], "forest": [[GOBLIN, 5], [PUGLIN, 5]],
						"crypt": [[IMP, 5], [GOBLIN, 5]], "swamp": [[PUGLIN, 5], [GOBLIN, 5]],
						"mountain": [[GOBLIN, 5], [IMP, 5]]}},
		{"places": ["terrace", "forest", "sky", "cave", "rampart", "mountain"], "lv": 7, "xp": 3.5, "reach": 7,
				"foes": {"*": [[ORC, 1, ORC_TWO_SWORDS], [ORC, 1, ORC_LONG_SWORD]]}},
		{"places": ["throne"], "lv": 8, "foes": {"*": [[ORC_CHIEF, 1, ORC_LORD]]}},
	],
}
## The boss of each dungeon: the scene in its last place that has to fall.
const BOSS := {0: ORC_CHIEF}
## What waits behind a portal (the user's word): its name and the portal's colour.
const REWARDS := {
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
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
	float gone = step(hash(vec2(s.y, 9.7)), 0.05 + 0.08 * wear);
	bool cob = rocky > 0.5 || to_wall < border || abs(lp.x) < aisle || gone > 0.5;
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
	vec3 nw = normalize(vec3(-hx * k, 1.0, -hz * k));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 c;
	float rough;
	float mottle = noise(p * 0.6 + g.z * 13.0) * 0.6 + noise(p * 5.0) * 0.25 + noise(p * 19.0) * 0.15;
	if (g.y < 0.5) {
		c = mix(slab_a.rgb, slab_b.rgb, g.z) * (0.72 + 0.45 * mottle);
		// Worn: the high middle of a slab paler, its edge darker.
		c *= 0.6 + 0.45 * h;
		rough = 0.88 - 0.25 * h * (1.0 - wet);
		// Cracks running across in patches.
		float patch = smoothstep(1.0 - wear, 1.0 - wear + 0.2, noise(p * 0.05 + 3.0));
		vec3 v = voronoi(p * 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.04, v.y - v.x)) * patch;
		c = mix(c, grit.rgb, crack * 0.85);
	} else if (g.y < 1.5) {
		c = mix(cobble_a.rgb, cobble_b.rgb, g.z) * (0.8 + 0.35 * mottle);
		c *= 0.28 + 0.8 * clamp(h, 0.0, 1.0);
		c = mix(c, grit.rgb, g.w * 0.35);
		rough = 0.8 - 0.3 * h;
	} else {
		c = grit.rgb * (0.8 + 2.5 * h) + vec3(0.02, 0.03, 0.0) * noise(p * 4.0);
		rough = 1.0;
	}
	// Moss and dirt in the low places near the walls.
	float low = 1.0 - smoothstep(0.1, 0.5, h);
	float moss = low * smoothstep(5.0, 0.5, to_wall) * smoothstep(0.45, 0.7, noise(p * 0.8 + 5.0));
	c = mix(c, vec3(0.16, 0.19, 0.09), moss * 0.6);
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
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float big = fbm(p * 0.05);
	float mid = fbm(p * 0.3 + 4.0);
	float fine = noise(p * 6.0) * 0.5 + noise(p * 17.0) * 0.5;
	vec3 c = mix(grass_a.rgb, grass_b.rgb, mid) * (0.8 + 0.35 * fine);
	float bare = smoothstep(bare_from, bare_from + 0.15, big + (mid - 0.5) * 0.4);
	c = mix(c, earth.rgb * (0.8 + 0.4 * fine), bare);
	c = mix(c, moss.rgb, smoothstep(0.62, 0.8, fbm(p * 0.12 + 9.0)) * 0.6);
	c = mix(c, leaves.rgb * (0.7 + 0.5 * fine), smoothstep(0.7, 0.85, fbm(p * 0.4 + 2.0)) * 0.7);
	// the path the creatures have trodden, down the middle
	float path = smoothstep(2.6, 1.2, abs(p.x - sin(p.y * 0.05) * 3.0) + (mid - 0.5) * 2.0);
	c = mix(c, earth.rgb * 0.9, path * path_amount);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	// blades of grass: the normal ruffled where it grows
	vec3 nw = normalize(vec3((noise(p * 9.0) - 0.5) * 0.5 * (1.0 - bare), 1.0, (noise(p * 9.0 + 3.1) - 0.5) * 0.5 * (1.0 - bare)));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
}
"""

const WALL_SHADER := """
shader_type spatial;
uniform vec4 stone : source_color = vec4(0.55, 0.49, 0.40, 1.0);
uniform vec4 grout : source_color = vec4(0.08, 0.07, 0.09, 1.0);
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
	float joint = step(f.x, 0.02) + step(0.98, f.x) + step(f.y, 0.04) + step(0.96, f.y);
	c = mix(c, grout.rgb, clamp(joint, 0.0, 1.0));
	// Darker towards the floor, as old stone is, and a little moss low down.
	c *= 0.72 + 0.28 * smoothstep(0.0, 4.0, wpos.y);
	c = mix(c, vec3(0.13, 0.17, 0.10), 0.25 * smoothstep(1.2, 0.0, wpos.y) * step(0.6, n));
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
	c = mix(c, vec3(0.09, 0.13, 0.06) * (0.8 + 0.4 * mn), moss * 0.75);
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
	var game := get_node_or_null("/root/Game")
	if game != null and int(game.get(&"dungeon_id")) >= 0:
		id = int(game.get(&"dungeon_id"))
	if not RUN.has(id):
		id = 0
	steps = RUN[id]
	cleared.resize(steps.size())
	cleared.fill(false)
	_rng.randomize()
	_materials()
	_sky()
	_sound_bus()
	_vista()
	_build_hud()
	# The first place: the first step's own.
	_arrive_at(0, String(steps[0]["places"][0]), "", true)
	_apply_phase(_phase)
	_place_marks()
	# Where the orcs' heavy blows crack the floor ([OrcFighter]).
	add_to_group(&"ground_scars")
	_say("%s" % String(Portals.DEFS[id]["name"]), 3.5)
	Fighter.throw_gap = THROW_GAP


func _exit_tree() -> void:
	Fighter.throw_gap = 0.0
	Sfx.bus = &"Master"
	if _bus >= 0 and _bus < AudioServer.bus_count and AudioServer.get_bus_name(_bus) == &"Dungeon":
		AudioServer.remove_bus(_bus)


func _room(i: int) -> Dictionary:
	return rooms[clampi(i, 0, rooms.size() - 1)]


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
		(marks.get_child(i) as Node3D).position = entry_point(i, 0)


## Step `i`, at `place`: built, its creatures made (asleep), the light of the
## day moved on, and `reward` waiting for it to be cleared.
func _arrive_at(i: int, place: String, reward: String, later: bool = false) -> void:
	var p: Dictionary = PLACES[place]
	var step: Dictionary = steps[i]
	var foes_by: Dictionary = step["foes"]
	var foes: Array = foes_by.get(place, foes_by.get("*", []))
	var r := {"place": place, "kind": p["kind"], "w": p["w"], "l": p["l"], "h": p["h"],
			"name": p["name"], "foes": foes, "lv": step.get("lv", 1), "xp": step.get("xp", 0.0),
			"reach": step.get("reach", 0), "reward": reward}
	if p.has("hole"):
		r["hole"] = true
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
	if later:
		_spawn_room.call_deferred(i)
	else:
		_spawn_room(i)
	_ambience(i)
	_drip_in = _rng.randf_range(2.0, 5.0)


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
	for entry: Array in r["foes"]:
		var scene := load(String(entry[0])) as PackedScene
		if scene == null:
			continue
		for n in int(entry[1]):
			var body := scene.instantiate() as Node3D
			body.name = "D%d_R%d_%d" % [id, i, k]
			var across := (float(k % 4) - 1.5) * (w - 14.0) / 3.0
			var row := floorf(float(k) / 4.0)
			var at := c + Vector3(across + sin(float(k) * 2.3) * 1.2, 0.3, -l * 0.08 - row * 3.0)
			if String(entry[0]) == BOSS.get(id, ""):
				at = c + Vector3(0.0, 0.3, -l * 0.2)
			body.position = at
			body.rotation.y = 0.0
			if entry.size() > 2:
				var props: Dictionary = entry[2]
				for key: String in props:
					body.set(StringName(key), props[key])
			body.set("band", StringName("dungeon_%d_room_%d" % [id, i]))
			body.set("camp_centre", Vector3(c.x, c.y, c.z))
			if "leash_radius" in body:
				body.set("leash_radius", 0.01)
			body.set_meta(&"level", int(r["lv"]))
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
			k += 1
	waves = 2 if not _reserve.is_empty() else 1


## The rift the next wave comes out of: in the far half of the place, a
## moment before they come.
func _open_rift() -> void:
	var c := centre(current)
	var l: float = _room(current)["l"]
	_rift = PortalLook.new()
	_rift.name = "Rift"
	_rift.tint = Color(0.85, 0.12, 0.2)
	_rift.position = c + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, -l * 0.22)
	_rift.scale = Vector3(0.02, 0.02, 0.02)
	add_child(_rift)
	_rift_out = false
	# it opens slowly: out of a point of light, growing, the air drawn into it
	var grow := create_tween()
	grow.tween_property(_rift, "scale", Vector3.ONE, RIFT_GROW).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var world := Blood.world_of(self)
	if world != null:
		for k in 3:
			get_tree().create_timer(RIFT_GROW * float(k) / 3.0).timeout.connect(func() -> void:
				if is_instance_valid(_rift):
					SkillFx.burst(world, _rift.global_position + Vector3.UP * 2.6, Color(0.95, 0.25, 0.3), 40,
							Vector2(0.5, 2.0), Vector3.UP, 180.0, Vector2(0.05, 0.14), Vector3(0, 0.6, 0), 1.0))
	_rift_at = Time.get_ticks_msec() / 1000.0 + RIFT_TIME
	Sfx.play(self, SND + "portal_open.wav", null, _rift.position + Vector3.UP * 2.0, 0.8, 4.0)
	_say("ტალღა %d / %d" % [wave + 1, waves], 2.5)


## The rest of them out of the rift, one after another, at him; the rift
## closing after them.
func _next_wave() -> void:
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
		_alive.append(body)
		if hero != null and body.has_method("_rouse"):
			body.call_deferred("_rouse", hero)
	_spawned = _alive.size()
	var last := i == steps.size() - 1
	if last:
		Sfx.play_flat(self, SND + "horn.wav", 1.0, -3.0)
	_say("ბოსი: ორკების მბრძანებელი" if last else String(_room(i)["name"]), 3.0)
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


func _clear(i: int) -> void:
	if cleared[i]:
		return
	cleared[i] = true
	room_cleared.emit(i)
	var r := _room(i)
	# What clearing it is worth on top of its creatures, and the level it
	# brings him to at least.
	for hero in _heroes():
		var book := hero.get_node_or_null("Leveling") as Leveling
		if book == null or hero.is_dead:
			continue
		var bonus := float(r.get("xp", 0.0))
		if bonus > 0.0:
			book.gain(bonus)
		if int(r.get("reach", 0)) > 0:
			book.raise_to(int(r["reach"]))
	# The fallen get up when the place is clear (the user's word: in a band,
	# the dead wait for the others to clear the room).
	for hero in _heroes():
		if hero.is_dead and hero.has_method("_respawn"):
			var at := hero.global_position
			hero.call("_respawn")
			hero.global_position = at
	if String(r.get("reward", "")) != "":
		_give(String(r["reward"]))
	if i < steps.size() - 1:
		_offer(i + 1)
	else:
		_close()


## What waits behind the portal he chose, his now.
func _give(what: String) -> void:
	rewards_given.append(what)
	for hero in _heroes():
		if hero.is_dead:
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
func _offer(next: int) -> void:
	var pool: Array = (steps[next]["places"] as Array).duplicate()
	var here := String(_room(current)["place"])
	if pool.size() > 2:
		pool.erase(here)
	pool.shuffle()
	var take := mini(2, pool.size())
	var gifts: Array = REWARDS.keys()
	gifts.shuffle()
	var last := next == steps.size() - 1
	var l: float = _room(current)["l"]
	for k in take:
		var place := String(pool[k])
		var reward := "" if last else String(gifts[k])
		var gate := PortalLook.new()
		gate.name = "Choice%d" % k
		if reward != "":
			gate.tint = REWARDS[reward]["tint"]
		# what is behind it, seen in it
		var view := PREVIEWS % place
		if ResourceLoader.exists(view):
			gate.view = load(view) as Texture2D
		var side := 0.0 if take == 1 else (-1.0 if k == 0 else 1.0)
		gate.position = centre(current) + Vector3(side * 9.0, 0.0, -l * 0.5 + 10.0)
		gate.set_meta(&"place", place)
		gate.set_meta(&"reward", reward)
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
		what.text = ("ჯილდო: " + String(REWARDS[reward]["name"])) if reward != "" else "ბოსი"
		what.font_size = 56
		what.pixel_size = 0.012
		what.outline_size = 12
		what.modulate = REWARDS[reward]["tint"] if reward != "" else Color(1.0, 0.4, 0.35)
		what.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		what.no_depth_test = true
		what.position = Vector3(0.0, 8.5, 0.0)
		gate.add_child(what)
		choices.append(gate)
		Sfx.play(self, SND + "portal_open.wav", null, gate.position + Vector3.UP * 2.0, 1.0, 2.0)
	_say("აირჩიე გზა" if take > 1 else "გზა ბოსისკენ", 3.0)


## Through portal `k`: the screen goes dark, the next place is built behind
## the dark and the heroes are put in it, the dark lifts.
func take(k: int) -> void:
	if _going or k < 0 or k >= choices.size():
		return
	_going = true
	var gate := choices[k]
	var place := String(gate.get_meta(&"place"))
	var reward := String(gate.get_meta(&"reward"))
	var next := current + 1
	Sfx.play_flat(self, SND + "portal_whoosh.wav", 1.0, -2.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	await tw.finished
	for c in choices:
		c.queue_free()
	choices.clear()
	_take_down(current)
	_arrive_at(next, place, reward)
	var slot := 0
	for hero in _heroes():
		hero.global_position = entry_point(slot, next)
		hero.velocity = Vector3.ZERO
		slot += 1
	_to_phase(float(next), 0.05)
	# a few frames behind the dark: the new place drawn once, its shaders made
	for f in 6:
		await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE)
	_wake_at = Time.get_ticks_msec() / 1000.0 + WAKE_AFTER
	_going = false


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
	# The way out, on the dais at the far end.
	var last := current
	_exit = PortalLook.new()
	_exit.name = "WayOut"
	_exit.tint = Portals.DEFS[id]["tint"]
	_exit.position = centre(last) + Vector3(0.0, 0.0, -float(_room(last)["l"]) * 0.5 + 15.0)
	add_child(_exit)
	closed.emit()


func _watch_deaths(heroes: Array[Player]) -> void:
	for hero in heroes:
		if _watched.has(hero.get_instance_id()):
			continue
		_watched[hero.get_instance_id()] = true
		hero.died.connect(_on_hero_died.bind(hero))
		# Here a hero gets up only when his place is cleared, or by the gate outside.
		hero.set(&"respawn_time", 9999.0)


func _on_hero_died(_hero: Player) -> void:
	# Alone (or all of them down): back out by the gate.
	for hero in _heroes():
		if not hero.is_dead:
			return
	_say("დამარცხდი", BACK_OUT_AFTER)
	_back_out_at = Time.get_ticks_msec() / 1000.0 + BACK_OUT_AFTER


## Back to the open world, by the gate this dungeon is behind.
func leave() -> void:
	set_process(false)
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.set(&"portal_return", id)
		game.set(&"dungeon_id", -1)
	SceneLoader.go(get_tree(), Portals.WORLD)


## The music for now ([World] asks): the boss's while its place is fought,
## otherwise the dungeon's.
func music_wanted() -> StringName:
	if current == steps.size() - 1 and not is_closed:
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
	if _banner != null and _banner.visible and now > _banner_until:
		_banner.hide()
	var heroes := _heroes()
	_watch_deaths(heroes)
	if _back_out_at > 0.0 and now >= _back_out_at:
		_back_out_at = -1.0
		leave()
		return
	if _going:
		return
	# The place wakes a moment after he comes (the first, when he is in it).
	if not _woken and current >= 0:
		if _wake_at < 0.0:
			for hero in heroes:
				if not hero.is_dead and room_at(hero.global_position) == current:
					_wake_at = now + WAKE_AFTER
		elif now >= _wake_at:
			_wake_at = -1.0
			_wake(current)
	if _woken and not cleared[current]:
		var left := 0
		for body in _alive:
			if is_instance_valid(body) and not bool(body.get("is_dead")):
				left += 1
		if left == 0 and _spawned > 0:
			var coming := 0
			for body in _reserve:
				if is_instance_valid(body) and not bool(body.get("is_dead")):
					coming += 1
			if coming == 0:
				_clear(current)
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
	_cave_mat = ShaderMaterial.new()
	_cave_mat.shader = rock
	_cave_mat.set_shader_parameter("scale", 0.3)
	# under the earth as the Eternal Cities lie (the user's word, 2026-10-20:
	# Elden Ring's colours): blue-grey rock, flecked with points of starlight
	_cave_mat.set_shader_parameter("rock_a", Color(0.30, 0.33, 0.42))
	_cave_mat.set_shader_parameter("rock_b", Color(0.10, 0.11, 0.17))
	_cave_mat.set_shader_parameter("band", Color(0.36, 0.40, 0.55))
	_cave_mat.set_shader_parameter("moss", Color(0.08, 0.22, 0.26))
	_cave_mat.set_shader_parameter("fleck", Color(0.75, 0.88, 1.0))
	_cave_mat.set_shader_parameter("fleck_glow", 3.0)
	_cave_mat.set_shader_parameter("wet", 0.6)
	_cave_mat.set_shader_parameter("moss_amount", 0.35)
	_ground_shader = Shader.new()
	_ground_shader.code = GROUND_SHADER
	_wall_mat = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = WALL_SHADER
	_wall_mat.shader = ws
	_trim_mat = StandardMaterial3D.new()
	_trim_mat.albedo_color = Color(0.70, 0.63, 0.50)
	_trim_mat.roughness = 0.75
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
	var c := centre(i)
	m.set_shader_parameter("centre", Vector2(c.x, c.z))
	m.set_shader_parameter("half_size", Vector2(float(r["w"]) * 0.5, float(r["l"]) * 0.5))
	if kind == "cave":
		m.set_shader_parameter("rocky", 1.0)
		m.set_shader_parameter("pebble", 0.9)
		m.set_shader_parameter("relief", 0.09)
		m.set_shader_parameter("cobble_a", Color(0.30, 0.32, 0.40))
		m.set_shader_parameter("cobble_b", Color(0.12, 0.13, 0.18))
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
		m.set_shader_parameter("slab_a", Color(0.62, 0.56, 0.45))
		m.set_shader_parameter("slab_b", Color(0.45, 0.40, 0.33))
		m.set_shader_parameter("cobble_a", Color(0.55, 0.49, 0.40))
		m.set_shader_parameter("cobble_b", Color(0.33, 0.29, 0.25))
		m.set_shader_parameter("wear", 0.45 if not r.has("hole") else 0.75)
		m.set_shader_parameter("border", 2.2)
		m.set_shader_parameter("aisle", 2.6)
	else:
		m.set_shader_parameter("slab", 1.8)
		m.set_shader_parameter("course", 1.25)
		m.set_shader_parameter("slab_a", Color(0.50, 0.46, 0.41))
		m.set_shader_parameter("slab_b", Color(0.34, 0.32, 0.30))
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
const PHASES := [
	{"elev": 52.0, "sun": Color(1.0, 0.92, 0.8), "sun_e": 1.3, "top": Color(0.20, 0.40, 0.70),
			"hor": Color(0.82, 0.80, 0.74), "gnd": Color(0.30, 0.28, 0.26), "amb": Color(0.62, 0.61, 0.60),
			"amb_e": 1.45, "fog": Color(0.66, 0.70, 0.78), "night": 0.0, "cloud": 0.45},
	{"elev": 34.0, "sun": Color(1.0, 0.86, 0.66), "sun_e": 1.25, "top": Color(0.20, 0.37, 0.66),
			"hor": Color(0.92, 0.76, 0.58), "gnd": Color(0.30, 0.27, 0.24), "amb": Color(0.64, 0.60, 0.56),
			"amb_e": 1.4, "fog": Color(0.72, 0.68, 0.66), "night": 0.0, "cloud": 0.5},
	{"elev": 15.0, "sun": Color(1.0, 0.70, 0.44), "sun_e": 1.1, "top": Color(0.22, 0.30, 0.56),
			"hor": Color(1.0, 0.60, 0.36), "gnd": Color(0.28, 0.22, 0.20), "amb": Color(0.66, 0.55, 0.50),
			"amb_e": 1.3, "fog": Color(0.80, 0.58, 0.46), "night": 0.0, "cloud": 0.55},
	{"elev": 3.0, "sun": Color(1.0, 0.46, 0.26), "sun_e": 0.8, "top": Color(0.10, 0.12, 0.32),
			"hor": Color(0.86, 0.36, 0.28), "gnd": Color(0.16, 0.12, 0.14), "amb": Color(0.55, 0.46, 0.52),
			"amb_e": 1.15, "fog": Color(0.52, 0.32, 0.36), "night": 0.3, "cloud": 0.55},
	{"elev": 38.0, "sun": Color(0.62, 0.70, 1.0), "sun_e": 0.55, "top": Color(0.012, 0.018, 0.06),
			"hor": Color(0.07, 0.09, 0.18), "gnd": Color(0.03, 0.03, 0.05), "amb": Color(0.42, 0.48, 0.66),
			"amb_e": 0.95, "fog": Color(0.10, 0.12, 0.20), "night": 1.0, "cloud": 0.4},
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
	_env.adjustment_saturation = 1.12
	_env.adjustment_contrast = 1.05
	_sun = root.get_node_or_null("Sun") as DirectionalLight3D
	if _sun != null:
		_sun_yaw = _sun.rotation.y
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
	_env.fog_density = 0.0007
	_env.adjustment_contrast = 1.05
	match kind:
		"hall", "court", "terrace", "throne":
			# the gold is the day's: by night only the torches' warmth is left
			var day := 1.0 - clampf(night, 0.0, 1.0)
			var gold := Color(0.92, 0.72, 0.42)
			_env.fog_light_color = _env.fog_light_color.lerp(gold, 0.5 * day)
			_env.ambient_light_color = _env.ambient_light_color.lerp(Color(0.78, 0.66, 0.50), 0.35 * day)
			_env.adjustment_contrast = 1.12
			_env.glow_intensity = 1.1
			_env.glow_bloom = 0.14
			_env.glow_hdr_threshold = 0.85
			if kind == "hall":
				_env.fog_density = 0.0035
				_env.volumetric_fog_enabled = true
				_env.volumetric_fog_density = 0.0035
				_env.volumetric_fog_albedo = Color(0.95, 0.82, 0.6)
				_env.volumetric_fog_emission = Color(0.06, 0.045, 0.02)
				_env.volumetric_fog_length = 70.0
				_env.volumetric_fog_ambient_inject = 0.15
		"crypt":
			# the catacombs: cold grey stone, the candles' warmth in it
			_env.ambient_light_color = Color(0.40, 0.44, 0.48)
			_env.ambient_light_energy = 1.1
			_env.fog_light_color = Color(0.16, 0.18, 0.18)
			_env.fog_density = 0.009
			_env.glow_intensity = 1.2
			_env.glow_bloom = 0.16
			_env.glow_hdr_threshold = 0.85
			_env.volumetric_fog_enabled = true
			_env.volumetric_fog_density = 0.012
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
			_env.ambient_light_color = _env.ambient_light_color.lerp(Color(0.42, 0.46, 0.55), 0.6)
			_env.ambient_light_energy *= 0.8
			_env.fog_light_color = Color(0.32, 0.35, 0.42).lerp(_env.fog_light_color, 0.3)
			_env.fog_density = 0.006
			if _sky_mat != null:
				_sky_mat.set_shader_parameter("cloud", 0.92)
				_sky_mat.set_shader_parameter("top_col", Color(0.16, 0.18, 0.24))
				_sky_mat.set_shader_parameter("hor_col", Color(0.36, 0.38, 0.44))
			if _sun != null:
				_sun.light_energy *= 0.45
		"rampart":
			# Stormveil's grey over the gold
			_env.fog_light_color = _env.fog_light_color.lerp(Color(0.6, 0.62, 0.66), 0.4)
			_env.adjustment_contrast = 1.1
		"cave":
			_env.ambient_light_color = Color(0.30, 0.38, 0.62)
			_env.ambient_light_energy = 1.05
			_env.fog_light_color = Color(0.14, 0.2, 0.38)
			_env.fog_density = 0.006
			_env.glow_intensity = 1.25
			_env.glow_bloom = 0.18
			_env.glow_hdr_threshold = 0.8
			_env.volumetric_fog_enabled = true
			_env.volumetric_fog_density = 0.008
			_env.volumetric_fog_albedo = Color(0.6, 0.72, 1.0)
			_env.volumetric_fog_emission = Color(0.01, 0.015, 0.04)
			_env.volumetric_fog_length = 60.0
			_env.volumetric_fog_ambient_inject = 0.2


func _build_room(i: int) -> void:
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
			_build_cave(room, i)
			return
		"forest":
			_build_forest(room, i)
			return
		"sky":
			_build_sky(room, i)
			return
		"crypt":
			_build_crypt(room, i)
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

	_wainscot(room, kind, w, l)
	_rubble_round(room, i, w, l)
	_motes(room, w, l, h)
	if kind != "hall":
		return
	# Down a hall's middle, a cobbled aisle between standing braziers (the red
	# runner went, the user's word, 2026-10-20).
	var step := 12.0
	var count := int((l - 10.0) / step)
	for k in count:
		var z := -l * 0.5 + 8.0 + float(k) * step
		for side: float in [-1.0, 1.0]:
			_standing_brazier(room, Vector3(side * 4.2, 0.0, z))


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
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.2, 0.05, 0.02)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.35, 0.08)
	hot.emission_energy_multiplier = 2.5
	coals.material_override = hot
	coals.position = Vector3(0.0, 1.39, 0.0)
	holder.add_child(coals)
	holder.add_child(_flame(Vector3(0.0, 1.42, 0.0), 1.7, 22))
	_crackle(holder, Vector3(0.0, 1.4, 0.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.6
	light.omni_range = 10.0
	light.position = Vector3(0.0, 2.0, 0.0)
	holder.add_child(light)


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
		# A beam come down, one end on the floor.
		var fallen := BoxMesh.new()
		fallen.size = Vector3(0.9, 0.8, 15.0)
		var fb := _deco(room, _wood_mat, fallen, Vector3(-3.0, 3.6, hz + 2.0))
		fb.rotation = Vector3(0.5, 0.35, 0.0)
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
	room.add_child(light)


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
		room.add_child(light)


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


func _flame(at: Vector3, size: float, amount: int) -> GPUParticles3D:
	var flame := GPUParticles3D.new()
	flame.amount = amount
	flame.lifetime = 0.6
	flame.position = at
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08 * size
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5 * size
	pm.initial_velocity_max = 0.9 * size
	pm.gravity = Vector3(0.0, 0.6, 0.0)
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.75, 0.3, 0.95))
	fade.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	flame.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.24) * size
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	flame.draw_pass_1 = q
	flame.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	return flame


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
	holder.add_child(light)


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
			parts = [["wind_loop.wav", -22.0]]
			if not night:
				parts.append(["birds_loop.wav", -12.0])
			else:
				parts.append(["crickets_loop.wav", -12.0])
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
		if (kind == "forest" or kind == "swamp") and _phase >= 2.8:
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
func _boulder(room: Node3D, at: Vector3, size: Vector3, yaw: float, mat: Material, shadow: bool = true) -> MeshInstance3D:
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
	return crag


## A rock turned upside down under something, its top at `top` (its own
## frame's height), hanging down from there.
func _hang(rock: MeshInstance3D, top: float) -> void:
	rock.rotation.x = PI
	var box := rock.mesh.get_aabb()
	rock.position.y = top + box.position.y * rock.scale.y


## A cave (the user's word: under the ground, in a cave): a floor of rough
## round stones, walls and a roof of rock with a crack of daylight in it,
## stone teeth up from the floor and down from the roof, crystals that glow
## violet and blue and light the rock round them, a still pool, mushrooms.
func _build_cave(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	_solid(room, _floor_mat(i), Vector3(w + 30.0, 1.0, l + 30.0), Vector3(0.0, -0.5, 0.0))
	_bounds(room, w, l)
	# The walls: great rocks all round, leaning in.
	var per := 10.0
	for side in 4:
		var long := l if side < 2 else w
		var n := int(long / per) + 2
		for k in n:
			var along := -long * 0.5 - 4.0 + float(k) * per + _rng.randf_range(-2.0, 2.0)
			var out := _rng.randf_range(2.0, 5.0)
			var at := Vector3.ZERO
			match side:
				0: at = Vector3(-w * 0.5 - out, -1.0, along)
				1: at = Vector3(w * 0.5 + out, -1.0, along)
				2: at = Vector3(along, -1.0, -l * 0.5 - out)
				_: at = Vector3(along, -1.0, l * 0.5 + out)
			var rock := _boulder(room, at, Vector3(_rng.randf_range(12.0, 18.0), h + _rng.randf_range(2.0, 8.0),
					_rng.randf_range(10.0, 15.0)), _rng.randf_range(0.0, TAU), _cave_mat)
			rock.rotation.z = _rng.randf_range(-0.15, 0.15)
	# The roof: slabs of rock, one crack of daylight left between them.
	var gap_x := _rng.randf_range(-w * 0.15, w * 0.15)
	var gap_z := -l * 0.12
	for gx in 3:
		for gz in 3:
			var at := Vector3((float(gx) - 1.0) * w * 0.36, h + 1.0, (float(gz) - 1.0) * l * 0.36)
			if absf(at.x - gap_x) < w * 0.2 and absf(at.z - gap_z) < l * 0.2:
				continue
			var slab := _boulder(room, at, Vector3(w * 0.45, 9.0, l * 0.45), _rng.randf_range(0.0, TAU), _cave_mat)
			_hang(slab, h + 9.0)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 5.0
	cyl.height = h + 6.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	var bm := ShaderMaterial.new()
	bm.shader = _beam_shader
	bm.set_shader_parameter("tint", Color(1.0, 0.9, 0.7))
	bm.set_shader_parameter("strength", 0.05)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3(gap_x, (h + 6.0) * 0.5, gap_z)
	room.add_child(beam)
	var shaft := SpotLight3D.new()
	shaft.light_color = Color(1.0, 0.9, 0.72)
	shaft.light_energy = 5.0
	shaft.spot_range = h + 14.0
	shaft.spot_angle = 22.0
	shaft.position = Vector3(gap_x, h + 10.0, gap_z)
	shaft.rotation.x = -PI * 0.5
	room.add_child(shaft)
	# Stone teeth.
	for k in 26:
		var up := k % 2 == 0
		var tooth := CylinderMesh.new()
		var tall := _rng.randf_range(2.0, 6.5)
		tooth.top_radius = 0.05
		tooth.bottom_radius = _rng.randf_range(0.5, 1.3)
		tooth.height = tall
		tooth.radial_segments = 7
		tooth.rings = 1
		var edge := _rng.randf()
		var x := (_rng.randf_range(0.32, 0.48) * (1.0 if _rng.randf() < 0.5 else -1.0)) * w if edge < 0.7 \
				else _rng.randf_range(-w * 0.4, w * 0.4)
		var z := _rng.randf_range(-l * 0.45, l * 0.45)
		var t := MeshInstance3D.new()
		t.mesh = tooth
		t.material_override = _cave_mat
		if up:
			t.position = Vector3(x, tall * 0.5, z)
			if absf(x) < w * 0.3:
				continue
			_post(room, Vector3(x, 0.0, z), tooth.bottom_radius * 0.7, tall)
		else:
			t.rotation.x = PI
			t.position = Vector3(x, h - tall * 0.5 + 1.5, z)
		room.add_child(t)
	# Boulders fallen from the roof, here and there.
	for k in 12:
		var x := signf(_rng.randf() - 0.5) * _rng.randf_range(w * 0.2, w * 0.46)
		var rock := _nature(room, "Rock_Medium_%d" % _rng.randi_range(1, 3), Vector3(x, 0.0, _rng.randf_range(-l * 0.45, l * 0.45)),
				_rng.randf_range(1.8, 3.6), _rng.randf_range(0.0, TAU))
		if rock != null:
			for m in rock.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = _cave_mat
	for k in 30:
		_nature(room, "Pebble_Round_%d" % _rng.randi_range(1, 5), Vector3(_rng.randf_range(-w * 0.45, w * 0.45), 0.0,
				_rng.randf_range(-l * 0.45, l * 0.45)), _rng.randf_range(1.0, 2.2), _rng.randf_range(0.0, TAU), false)
	# Crystals in clusters, glowing.
	var tints := [Color(0.3, 0.6, 1.0), Color(0.25, 0.85, 1.0), Color(1.0, 0.75, 0.35)]
	for k in 9:
		var tint: Color = tints[k % tints.size()]
		var a := float(k) / 9.0 * TAU + _rng.randf_range(-0.2, 0.2)
		var at := Vector3(sin(a) * w * 0.42, 0.0, cos(a) * l * 0.42)
		_crystals(room, at, tint)
	# A still pool, faintly lit from under.
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 5.5
	disc.bottom_radius = 5.5
	disc.height = 0.05
	disc.radial_segments = 28
	pool.mesh = disc
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.02, 0.05, 0.07)
	pm.metallic = 0.0
	pm.roughness = 0.12
	pm.metallic_specular = 0.2
	pm.emission_enabled = true
	pm.emission = Color(0.1, 0.4, 0.5)
	pm.emission_energy_multiplier = 0.4
	pool.material_override = pm
	pool.position = Vector3(w * 0.22, 0.03, l * 0.18)
	room.add_child(pool)
	for k in 10:
		var name: String = ["Mushroom_Brown", "Mushroom_Dark_Red", "Mushroom_Grey", "Mushroom_Red_Spotted"][k % 4]
		var x := (w * 0.44) * (1.0 if k % 2 == 0 else -1.0) + _rng.randf_range(-2.0, 2.0)
		var shroom := _prop(room, name, Vector3(x, 0.0, _rng.randf_range(-l * 0.4, l * 0.4)), _rng.randf_range(0.6, 1.4),
				_rng.randf_range(0.0, TAU), false)
		if k % 3 == 0:
			_glow(shroom, [Color(0.2, 0.9, 0.8), Color(0.5, 0.9, 0.3), Color(0.3, 0.6, 1.0)][k % 3])
	_mist(room, w, l, 0.4, Color(0.45, 0.58, 0.85), 0.32)
	_torch(room, Vector3(-w * 0.3, 2.8, l * 0.5 - 2.0))
	_torch(room, Vector3(w * 0.3, 2.8, l * 0.5 - 2.0))
	_motes(room, w, l, h)


## A cluster of crystals at `at`, glowing `tint`, with the light they give.
func _crystals(room: Node3D, at: Vector3, tint: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint.darkened(0.5)
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 2.6
	mat.roughness = 0.15
	mat.metallic = 0.3
	for k in _rng.randi_range(4, 7):
		var c := CylinderMesh.new()
		var tall := _rng.randf_range(0.8, 2.6)
		c.top_radius = 0.02
		c.bottom_radius = _rng.randf_range(0.14, 0.32)
		c.height = tall
		c.radial_segments = 6
		c.rings = 1
		var m := MeshInstance3D.new()
		m.mesh = c
		m.material_override = mat
		m.position = at + Vector3(_rng.randf_range(-0.8, 0.8), tall * 0.4, _rng.randf_range(-0.8, 0.8))
		m.rotation = Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.5, 0.5))
		room.add_child(m)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 2.2
	light.omni_range = 11.0
	light.position = at + Vector3(0.0, 1.4, 0.0)
	room.add_child(light)


## A forest on the mountain (the user's word: in a forest): a clearing of grass
## and earth ringed by tall trees, stones standing in a ring at its middle,
## logs, stumps, rocks, ferns and flowers, fireflies once the day goes.
func _build_forest(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var ground := ShaderMaterial.new()
	ground.shader = _ground_shader
	_solid(room, ground, Vector3(w + 90.0, 1.0, l + 90.0), Vector3(0.0, -0.5, 0.0))
	_crag_under(room, w + 90.0, l + 90.0, PalaceVista.DROP + 60.0, -1.0)
	_bounds(room, w, l)
	# The wood round the clearing, two and three deep.
	for ring in 3:
		var out := 3.0 + float(ring) * 7.0
		var step := 5.5 + float(ring) * 1.5
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
				at += Vector3(_rng.randf_range(-2.0, 2.0), 0.0, _rng.randf_range(-2.0, 2.0))
				_nature(room, _a_tree(), at, _rng.randf_range(1.5, 2.4), _rng.randf_range(0.0, TAU), ring == 0)
	# A few inside, near the edge, that one can walk round.
	for k in 7:
		var x := (w * _rng.randf_range(0.3, 0.44)) * (1.0 if k % 2 == 0 else -1.0)
		var z := _rng.randf_range(-l * 0.42, l * 0.42)
		_nature(room, _a_tree(), Vector3(x, 0.0, z), _rng.randf_range(1.3, 1.9), _rng.randf_range(0.0, TAU))
		_post(room, Vector3(x, 0.0, z), 0.55, 4.0)
	# Standing stones in a ring at the middle, one fallen.
	for k in 7:
		var a := float(k) / 7.0 * TAU
		var at := Vector3(sin(a) * 8.0, 0.0, cos(a) * 8.0 - 4.0)
		if k == 3:
			var lying := BoxMesh.new()
			lying.size = Vector3(1.2, 1.0, 3.6)
			var d := _deco(room, _wall_mat, lying, at + Vector3(0.0, 0.5, 0.0))
			d.rotation.y = a + 0.6
			continue
		var stone := BoxMesh.new()
		var tall := _rng.randf_range(2.8, 4.2)
		stone.size = Vector3(1.3, tall, 0.8)
		var s := _deco(room, _wall_mat, stone, at + Vector3(0.0, tall * 0.5, 0.0))
		s.rotation = Vector3(_rng.randf_range(-0.06, 0.06), a, _rng.randf_range(-0.06, 0.06))
		_blocker(room, Vector3(1.0, tall, 1.0), at + Vector3(0.0, tall * 0.5, 0.0))
	# What lies about.
	for k in 10:
		var x := _rng.randf_range(-w * 0.46, w * 0.46)
		var z := _rng.randf_range(-l * 0.46, l * 0.46)
		if absf(x) < 6.0 and absf(z) < 14.0:
			continue
		_prop(room, ["Log_1", "Log_3", "Stump_1", "Stump_2"][k % 4], Vector3(x, 0.0, z), _rng.randf_range(0.9, 1.3),
				_rng.randf_range(0.0, TAU), false)
	var bits := [["Rock_Medium_1", 1.2], ["Rock_Medium_2", 1.0], ["Rock_Medium_3", 1.4], ["Bush_Common", 1.3],
			["Bush_Common_Flowers", 1.3], ["Fern_1", 1.4], ["Plant_1_Big", 1.2], ["Plant_7_Big", 1.2],
			["Mushroom_Common", 1.4], ["Mushroom_Laetiporus", 1.2]]
	for k in 46:
		var bit: Array = bits[k % bits.size()]
		var x := _rng.randf_range(-w * 0.47, w * 0.47)
		var z := _rng.randf_range(-l * 0.47, l * 0.47)
		if absf(x) < 6.0 and absf(z) < 14.0:
			continue
		# most of it near the edge of the wood
		if _rng.randf() < 0.6:
			x = signf(x + 0.01) * _rng.randf_range(w * 0.3, w * 0.48)
		_nature(room, String(bit[0]), Vector3(x, 0.0, z), float(bit[1]) * _rng.randf_range(0.8, 1.3),
				_rng.randf_range(0.0, TAU), false)
	var small := ["Grass_Common_Tall", "Grass_Wispy_Tall", "Grass_Common_Short", "Flower_3_Group", "Flower_4_Group",
			"Clover_1", "Clover_2", "Grass_Wispy_Short", "Pebble_Round_2", "Flower_3_Single"]
	for k in 220:
		_nature(room, small[k % small.size()], Vector3(_rng.randf_range(-w * 0.49, w * 0.49), 0.0,
				_rng.randf_range(-l * 0.49, l * 0.49)), _rng.randf_range(0.9, 1.6), _rng.randf_range(0.0, TAU), false)
	_fireflies(room, w, l)
	_stream(room, w, l)
	_mist(room, w, l, 0.3, Color(0.92, 0.94, 0.96), 0.16)
	if i < 3:
		_butterflies(room, w, l)


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
	q.size = Vector2(0.09, 0.09)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(2.0, 2.0, 1.2)
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-w, -2, -l), Vector3(w * 2.0, 6.0, l * 2.0))
	room.add_child(p)


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
func _nature(room: Node3D, name: String, at: Vector3, scale: float, yaw: float, shadow: bool = true) -> Node3D:
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
	if not shadow:
		for m in n.find_children("*", "GeometryInstance3D", true, false):
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


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


## The sea of cloud under the island: soft layers one over another.
func _cloud_layers(room: Node3D) -> void:
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
		m.position = Vector3(0.0, -78.0 + float(k) * 7.0, 0.0)
		room.add_child(m)
		_cloud_layer_mats.append(mat)
	_apply_phase(_phase)


## An island in the sky (the user's word: up in the sky; then, prettier,
## without the clouds in front): an old paved floor on a great rock, grass and
## flowers grown over its edges, trees on it, broken columns, a low wall round
## it with gaps (unseen walls in them), little islands floating round with
## trees of their own, birds, and a soft sea of cloud far under.
func _build_sky(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	_solid(room, _floor_mat(i), Vector3(w + 6.0, 1.0, l + 6.0), Vector3(0.0, -0.5, 0.0))
	# The rock it stands on, narrowing down to a point.
	for k in 5:
		var rock := _boulder(room, Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-8.0, 8.0)),
				Vector3(w * (1.15 - float(k) * 0.18), 30.0 + float(k) * 12.0, l * (1.15 - float(k) * 0.18)),
				_rng.randf_range(0.0, TAU), _rock_mat, false)
		_hang(rock, -1.0 - float(k) * 6.0)
	# grass over the rock's rim, round the floor
	var lawn := ShaderMaterial.new()
	lawn.shader = _ground_shader
	for side in 4:
		var along := w + 12.0 if side < 2 else l + 12.0
		var strip := Vector3(along, 0.6, 5.0) if side < 2 else Vector3(5.0, 0.6, along)
		var at := Vector3(0.0, -0.25, (l * 0.5 + 4.0) * (1.0 if side == 0 else -1.0)) if side < 2 \
				else Vector3((w * 0.5 + 4.0) * (1.0 if side == 2 else -1.0), -0.25, 0.0)
		_solid(room, lawn, strip, at, false)
	_bounds(room, w, l)
	for side: float in [-1.0, 1.0]:
		_balustrade(room, Vector3(side * (w * 0.5 + 0.5), 0.0, 0.0), l + 2.0)
		_balustrade_across(room, Vector3(0.0, 0.0, side * (l * 0.5 + 0.5)), w + 2.0)
	for k in 6:
		var x := (w * 0.5 - 4.0) * (1.0 if k % 2 == 0 else -1.0)
		var z := -l * 0.35 + floorf(float(k) / 2.0) * l * 0.35
		if k == 3:
			_fallen_column(room, Vector3(x * 0.6, 0.0, z), 0.9)
			continue
		_column(room, i, Vector3(x, 0.0, z), _rng.randf_range(6.0, 10.0), 1.1)
	_rubble_round(room, i, w, l)
	# trees on the grass outside the wall, and bushes and flowers against it
	for k in 10:
		var side := k % 4
		var at := Vector3(_rng.randf_range(-w * 0.5, w * 0.5), 0.0, (l * 0.5 + 4.0) * (1.0 if side == 0 else -1.0)) \
				if side < 2 else Vector3((w * 0.5 + 4.0) * (1.0 if side == 2 else -1.0), 0.0, _rng.randf_range(-l * 0.5, l * 0.5))
		_nature(room, "CommonTree_%d" % _rng.randi_range(1, 5) if k % 3 != 2 else "TwistedTree_%d" % _rng.randi_range(1, 5),
				at, _rng.randf_range(1.0, 1.5), _rng.randf_range(0.0, TAU))
	for k in 60:
		var on_floor := k % 3 == 0
		var x := _rng.randf_range(-w * 0.5 - 4.0, w * 0.5 + 4.0)
		var z := _rng.randf_range(-l * 0.5 - 4.0, l * 0.5 + 4.0)
		if on_floor:
			x = (w * 0.5 - 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		elif absf(x) < w * 0.5 and absf(z) < l * 0.5:
			continue
		var bit: String = ["Grass_Wispy_Tall", "Grass_Common_Tall", "Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers",
				"Fern_1", "Clover_1"][k % 7]
		_nature(room, bit, Vector3(x, 0.0, z), _rng.randf_range(0.9, 1.5), _rng.randf_range(0.0, TAU), false)
	# Little islands round about, each with its tree and its grass.
	for k in 9:
		var a := float(k) / 9.0 * TAU + _rng.randf_range(-0.2, 0.2)
		var far := _rng.randf_range(70.0, 150.0)
		var at := Vector3(sin(a) * far, _rng.randf_range(-30.0, 25.0), cos(a) * far)
		var size := _rng.randf_range(8.0, 20.0)
		var top := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = size * 0.5
		disc.bottom_radius = size * 0.42
		disc.height = 1.2
		disc.radial_segments = 10
		top.mesh = disc
		top.material_override = lawn
		top.position = at
		top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(top)
		var under := _boulder(room, at, Vector3(size * 0.95, size * 1.3, size * 0.95), _rng.randf_range(0.0, TAU), _rock_mat, false)
		_hang(under, at.y - 0.4)
		_nature(room, _a_tree(), at + Vector3(0.0, 0.6, 0.0), size * 0.12, _rng.randf_range(0.0, TAU), false)
		for g in 4:
			_nature(room, "Grass_Wispy_Tall", at + Vector3(_rng.randf_range(-size, size) * 0.3, 0.6,
					_rng.randf_range(-size, size) * 0.3), 1.2, _rng.randf_range(0.0, TAU), false)
	_cloud_layers(room)
	_circling_birds(room)
	_motes(room, w, l, 10.0)

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
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.06 + vec2(TIME * 0.01, TIME * 0.004);
	float n = noise(p) * 0.6 + noise(p * 2.7) * 0.4;
	float d = clamp(1.0 - length(UV - 0.5) * 2.0, 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = smoothstep(0.35, 0.8, n) * d * thick;
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
func _mist(room: Node3D, w: float, l: float, y: float, tint: Color, thick: float) -> void:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MIST_SHADER
	mat.shader = sh
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("thick", thick)
	for k in 10:
		var m := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(_rng.randf_range(16.0, 30.0), _rng.randf_range(16.0, 30.0))
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
		room.add_child(l)


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


## A crypt under the palace (the user's word: under the ground; Elden Ring's
## catacombs): a long low vault on ribs, the dead in niches in its walls and
## in stone coffins down its sides, candles burning on them, chains hanging,
## bones on the floor, a cold grey air with the candles' warmth in it.
func _build_crypt(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	var stone := _wall_mat.duplicate() as ShaderMaterial
	stone.set_shader_parameter("stone", Color(0.36, 0.35, 0.33))
	_solid(room, _floor_mat(i), Vector3(w + WALL_T * 2.0, 1.0, l + WALL_T * 2.0), Vector3(0.0, -0.5, 0.0))
	for side: float in [-1.0, 1.0]:
		_solid(room, stone, Vector3(WALL_T, h, l + WALL_T * 2.0), Vector3(side * (w + WALL_T) * 0.5, h * 0.5, 0.0))
		_solid(room, stone, Vector3(w + WALL_T * 2.0, h, WALL_T), Vector3(0.0, h * 0.5, side * (l + WALL_T) * 0.5))
	# the vault: a flat roof on ribs, an arch of stone every six metres
	_solid(room, stone, Vector3(w + WALL_T * 2.0, 1.0, l + WALL_T * 2.0), Vector3(0.0, h + 0.5, 0.0), false)
	var step := 6.0
	var n := int(l / step)
	for k in n + 1:
		var z := -l * 0.5 + float(k) * step
		var rib := BoxMesh.new()
		rib.size = Vector3(w, 0.8, 0.9)
		_deco(room, _trim_mat, rib, Vector3(0.0, h - 0.4, z))
		for side: float in [-1.0, 1.0]:
			var pier := BoxMesh.new()
			pier.size = Vector3(1.2, h, 1.2)
			_deco(room, stone, pier, Vector3(side * (w * 0.5 - 0.6), h * 0.5, z))
			_blocker(room, Vector3(1.2, h, 1.2), Vector3(side * (w * 0.5 - 0.6), h * 0.5, z))
			# the dead in their niche between the piers
			if k < n:
				var nz := z + step * 0.5
				var niche := _necro_put(room, "EA_Bld_Tomb_Niche_Clean_Class_A_01c",
						Vector3(side * (w * 0.5 - 0.2), 0.0, nz), PI * 0.5 * -side, 2.2)
				if niche == null:
					var box := BoxMesh.new()
					box.size = Vector3(0.8, 2.2, 3.2)
					_deco(room, _trim_mat, box, Vector3(side * (w * 0.5 - 0.4), 1.1, nz))
				_candles(room, Vector3(side * (w * 0.5 - 1.6), 0.0, nz + _rng.randf_range(-1.0, 1.0)), k % 2 == 0)
				if _rng.randf() < 0.5:
					_bones(room, Vector3(side * (w * 0.5 - 2.4), 0.0, nz + _rng.randf_range(-1.5, 1.5)))
	# stone coffins down the middle in two rows, candles on some
	for k in 6:
		var z := -l * 0.32 + float(k) * l * 0.13
		for side: float in [-1.0, 1.0]:
			if _rng.randf() < 0.25:
				continue
			var x := side * w * 0.22
			var coffin := BoxMesh.new()
			coffin.size = Vector3(1.4, 0.9, 2.6)
			_deco(room, stone, coffin, Vector3(x, 0.45, z))
			var lid := BoxMesh.new()
			lid.size = Vector3(1.6, 0.25, 2.8)
			var ld := _deco(room, _trim_mat, lid, Vector3(x, 1.02, z))
			if _rng.randf() < 0.3:
				# pushed aside
				ld.position += Vector3(side * 0.5, -0.1, 0.3)
				ld.rotation = Vector3(0.0, 0.3, side * 0.25)
			_blocker(room, Vector3(1.4, 1.2, 2.6), Vector3(x, 0.6, z))
			if _rng.randf() < 0.6:
				_candles(room, Vector3(x + _rng.randf_range(-0.4, 0.4), 1.15, z + _rng.randf_range(-0.8, 0.8)), _rng.randf() < 0.5)
	# chains hanging from the ribs, creaking
	for k in 8:
		var at := Vector3(_rng.randf_range(-w * 0.35, w * 0.35), h - 0.8, -l * 0.5 + _rng.randf_range(3.0, l - 3.0))
		var chain := _necro_put(room, "EA_Decor_Chain_01a" if k % 2 == 0 else "EA_Decor_Chain_01b", at, _rng.randf_range(0.0, TAU), 3.0)
		if chain == null:
			var c := CylinderMesh.new()
			c.top_radius = 0.04
			c.bottom_radius = 0.04
			c.height = 2.5
			_deco(room, _iron_mat, c, at - Vector3(0.0, 1.25, 0.0))
		_creaks.append(room.position + at)
	for k in 10:
		_bones(room, Vector3(_rng.randf_range(-w * 0.4, w * 0.4), 0.0, _rng.randf_range(-l * 0.45, l * 0.45)))
	_rubble_round(room, i, w, l)
	_mist(room, w, l, 0.3, Color(0.55, 0.6, 0.58), 0.3)
	_motes(room, w, l, h)
	for side: float in [-1.0, 1.0]:
		_torch(room, Vector3(side * 3.5, 3.0, l * 0.5 - 0.6))


## A swamp (the user's word: somewhere else again): dark mud and moss, pools of
## still green water, dead trees and twisted roots, reeds and swamp grass, a
## low sickly mist, frogs and the night's crickets.
func _build_swamp(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var ground := ShaderMaterial.new()
	ground.shader = _ground_shader
	ground.set_shader_parameter("grass_a", Color(0.16, 0.20, 0.09))
	ground.set_shader_parameter("grass_b", Color(0.24, 0.27, 0.11))
	ground.set_shader_parameter("earth", Color(0.17, 0.13, 0.09))
	ground.set_shader_parameter("moss", Color(0.12, 0.18, 0.08))
	ground.set_shader_parameter("leaves", Color(0.22, 0.17, 0.09))
	ground.set_shader_parameter("path_amount", 0.0)
	ground.set_shader_parameter("bare_from", 0.42)
	_solid(room, ground, Vector3(w + 90.0, 1.0, l + 90.0), Vector3(0.0, -0.5, 0.0))
	_crag_under(room, w + 90.0, l + 90.0, PalaceVista.DROP + 60.0, -1.0)
	_bounds(room, w, l)
	# pools of still water
	var water := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WATER_SHADER
	water.shader = sh
	water.set_shader_parameter("deep", Color(0.04, 0.08, 0.05))
	water.set_shader_parameter("shallow", Color(0.16, 0.22, 0.12))
	water.set_shader_parameter("flow", 0.04)
	for k in 9:
		var pool := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		var rad := _rng.randf_range(3.0, 7.5)
		disc.top_radius = rad
		disc.bottom_radius = rad
		disc.height = 0.02
		disc.radial_segments = 20
		pool.mesh = disc
		pool.material_override = water
		pool.scale = Vector3(1.0, 1.0, _rng.randf_range(0.6, 1.4))
		pool.rotation.y = _rng.randf_range(0.0, TAU)
		pool.position = Vector3(_rng.randf_range(-w * 0.4, w * 0.4), 0.03, _rng.randf_range(-l * 0.4, l * 0.4))
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(pool)
		for m in 4:
			var a := _rng.randf_range(0.0, TAU)
			_prop(room, "Cattail_%d" % _rng.randi_range(1, 5), pool.position + Vector3(sin(a), 0.0, cos(a)) * rad * 0.95,
					_rng.randf_range(1.2, 2.0), _rng.randf_range(0.0, TAU), false)
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
				_nature(room, name, at, _rng.randf_range(1.1, 1.7), _rng.randf_range(0.0, TAU), ring == 0)
	for k in 6:
		var x := (w * _rng.randf_range(0.25, 0.42)) * (1.0 if k % 2 == 0 else -1.0)
		var z := _rng.randf_range(-l * 0.4, l * 0.4)
		_nature(room, "DeadTree_%d" % _rng.randi_range(1, 5), Vector3(x, 0.0, z), _rng.randf_range(1.0, 1.4), _rng.randf_range(0.0, TAU))
		_post(room, Vector3(x, 0.0, z), 0.5, 4.0)
	var swampy := ["EA_Swamp_Grass_01a", "EA_Swamp_Grass_01f", "EA_Swamp_Grass_02a", "EA_Swamp_Grass_02e",
			"EA_Swamp_Grass_04a", "EA_Swamp_Grass_Hill_Dead_01a", "EA_Swamp_Grass_Hill_Dead_01c",
			"EA_Swamp_Root_03c", "EA_Swamp_Root_04d", "EA_Swamp_Stones_02a", "EA_Swamp_Dirt_Root_04a",
			"EA_Environment_Nature_Root_2c", "EA_Swamp_Leaf_01a"]
	for k in 110:
		var at := Vector3(_rng.randf_range(-w * 0.49, w * 0.49), 0.0, _rng.randf_range(-l * 0.49, l * 0.49))
		var bit: String = swampy[k % swampy.size()]
		# the grassy hummocks are big as they are
		var size := _rng.randf_range(0.5, 0.9) if bit.contains("Hill") else _rng.randf_range(0.9, 1.6)
		_necro_put(room, bit, at, _rng.randf_range(0.0, TAU), size, false)
	for k in 12:
		_prop(room, ["Log_1", "Log_3", "Stump_1", "Stump_2"][k % 4], Vector3(_rng.randf_range(-w * 0.45, w * 0.45), 0.0,
				_rng.randf_range(-l * 0.45, l * 0.45)), _rng.randf_range(0.9, 1.3), _rng.randf_range(0.0, TAU), false)
	_mist(room, w, l, 0.25, Color(0.55, 0.62, 0.45), 0.4)
	_fireflies(room, w, l)


## A mountain path in a storm (the user's word: a stormy mountain path):
## a broken shelf of rock high among the peaks, cliffs round it, a few pines
## bent by the wind, snow in the hollows, rain driven across it, the sky dark
## and lit by lightning.
func _build_mountain(room: Node3D, i: int) -> void:
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	_solid(room, _floor_mat(i), Vector3(w + 20.0, 1.0, l + 20.0), Vector3(0.0, -0.5, 0.0))
	_crag_under(room, w + 30.0, l + 30.0, PalaceVista.DROP + 120.0, -1.0)
	_bounds(room, w, l)
	# cliffs: great rocks along both long sides, the near and far ends open to
	# the drop; grey, snow on what faces up
	var cliff := _rock_mat.duplicate() as ShaderMaterial
	cliff.set_shader_parameter("rock_a", Color(0.44, 0.45, 0.48))
	cliff.set_shader_parameter("rock_b", Color(0.20, 0.21, 0.24))
	cliff.set_shader_parameter("band", Color(0.52, 0.52, 0.55))
	cliff.set_shader_parameter("moss", Color(0.86, 0.88, 0.93))
	cliff.set_shader_parameter("moss_amount", 0.9)
	cliff.set_shader_parameter("wet", 0.5)
	for side: float in [-1.0, 1.0]:
		var z := -l * 0.5 - 6.0
		while z < l * 0.5 + 6.0:
			var tall := _rng.randf_range(14.0, 34.0)
			_boulder(room, Vector3(side * (w * 0.5 + _rng.randf_range(3.0, 8.0)), -2.0, z),
					Vector3(_rng.randf_range(12.0, 20.0), tall, _rng.randf_range(10.0, 16.0)), _rng.randf_range(0.0, TAU), cliff)
			z += _rng.randf_range(7.0, 11.0)
	# boulders on the shelf to fight round
	for k in 9:
		var at := Vector3(_rng.randf_range(-w * 0.4, w * 0.4), 0.0, _rng.randf_range(-l * 0.4, l * 0.4))
		if absf(at.x) < 5.0 and at.z > 0.0:
			continue
		var size := _rng.randf_range(2.0, 4.5)
		_boulder(room, at - Vector3(0.0, 0.3, 0.0), Vector3(size * 1.3, size, size * 1.1), _rng.randf_range(0.0, TAU), cliff)
		_blocker(room, Vector3(size, size, size * 0.9), at + Vector3(0.0, size * 0.4, 0.0))
	for k in 10:
		var x := (w * _rng.randf_range(0.36, 0.5)) * (1.0 if k % 2 == 0 else -1.0)
		_nature(room, "Pine_%d" % _rng.randi_range(1, 5), Vector3(x, 0.0, _rng.randf_range(-l * 0.45, l * 0.45)),
				_rng.randf_range(1.2, 2.0), _rng.randf_range(0.0, TAU))
	for k in 40:
		_nature(room, ["Grass_Wispy_Tall", "Grass_Wispy_Short", "Pebble_Round_3", "Rock_Medium_2"][k % 4],
				Vector3(_rng.randf_range(-w * 0.48, w * 0.48), 0.0, _rng.randf_range(-l * 0.48, l * 0.48)),
				_rng.randf_range(0.8, 1.4), _rng.randf_range(0.0, TAU), false)
	# an old shrine of the road: a broken arch and a cairn
	for side: float in [-1.0, 1.0]:
		_column(room, i, Vector3(side * 4.0, 0.0, -l * 0.3), 7.0, 0.9)
	var lintel := BoxMesh.new()
	lintel.size = Vector3(9.5, 0.9, 1.4)
	var lt := _deco(room, _trim_mat, lintel, Vector3(0.6, 7.2, -l * 0.3))
	lt.rotation.z = -0.08
	_rain(room, w, l)


## Rain driven across a place.
func _rain(room: Node3D, w: float, l: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 3500
	p.lifetime = 1.2
	p.position = Vector3(0.0, 22.0, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(w * 0.7, 1.0, l * 0.7)
	pm.direction = Vector3(0.25, -1.0, 0.1)
	pm.spread = 3.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 24.0
	pm.gravity = Vector3(0.0, -10.0, 0.0)
	pm.particle_flag_align_y = true
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.7)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
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
	# what the fighting left: fires, arrows, blades
	for k in 5:
		var at := Vector3(_rng.randf_range(-w * 0.35, w * 0.35), 0.0, -l * 0.4 + float(k) * l * 0.2)
		_rubble(room, at, 1.4, 8, k * 13)
		room.add_child(_flame(at + Vector3(0.0, 0.4, 0.0), 2.4, 30))
		_crackle(room, at + Vector3(0.0, 0.4, 0.0))
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.55, 0.25)
		glow.light_energy = 2.4
		glow.omni_range = 10.0
		glow.position = at + Vector3(0.0, 1.2, 0.0)
		room.add_child(glow)
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
	for k in 9:
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
