class_name Dungeon
extends Node3D

## A dungeon behind one of the open world's gates ([Portals],
## portal_dungeons_plan.md): a palace of rooms one after another (the user's
## word: Archero's way). The hero stands in the first; its creatures come, and
## when the last of them is down the iron gate at its far end goes up. The
## gate behind comes down as he goes through. The last room is the boss's;
## the boss down, the dungeon is closed: what it gives is on the floor, the
## hero is brought up to the dungeon's top level, and a gate out stands at the
## far end.
##
## The rooms are big and high (the user's word, 2026-10-20) and not all of them
## under a roof: some are halls (a ceiling on beams, braziers hanging from it),
## some open to the sky — a courtyard with windows onto the mountains, a
## terrace with one side open over a sea of cloud far below, and the boss's
## court on the cliff's edge. Built in code from `ROOMS`: floors, walls,
## columns, banners, torches, iron gates, and round it all the sky, the sun,
## the mountains and the cloud below.
##
## Levels: the hero comes in at the dungeon's first level ([Leveling] is new
## in every level loaded) and the creatures carry him up as they fall; a
## dungeon closed tops him up to its last. Dying alone in here puts him back
## by the gate he came in by; in a band, the fallen get up when the room is
## cleared.

const WALL_T := 1.6
const DOOR_W := 6.0
const DOOR_H := 7.5
## Invisible height added to every wall, so nobody climbs out over it.
const BLOCK_H := 60.0
## How long after dying alone he is taken back out.
const BACK_OUT_AFTER := 3.0

const IMP := "res://scenes/enemies/imp.tscn"
const PUGLIN := "res://scenes/enemies/puglin.tscn"
const ORC := "res://scenes/enemies/pack/orc.tscn"
const ORC_SKIRM := "res://scenes/enemies/pack/orc_skirmisher.tscn"
const OGRE := "res://scenes/enemies/pack/ogre.tscn"
const ORC_CHIEF := "res://scenes/enemies/pack/orc_chief.tscn"

## The orcs of the first dungeon (the user's word, 2026-10-20): before the last
## room two of different kinds, one with two swords, one with a long sword,
## neither with its whole run of combos; in the last, the lord of the orcs with
## his great sword.
const ORC_TWO_SWORDS := {"hand_combo_chance": Vector2(0.3, 0.55)}
const ORC_LONG_SWORD := {"arm_right": "longsword", "arm_left": "none", "hand_combo_chance": Vector2(0.15, 0.4)}
const ORC_LORD := {"arm_right": "greatsword", "arm_style": "black", "outfit": "Lord", "cape": "Black cape",
		"combo_rest": Vector2(2.4, 3.4)}

## Per dungeon: its rooms. Each: kind ("hall" under a roof, "court" open with
## windows, "terrace" open with one side over the drop, "throne" the boss's
## court on the cliff), width, length, wall height, and its creatures as
## [scene, count, props], "lv" the level they show and "xp" what clearing
## it gives on top of them (wolves' worth: the hero comes to the lord at level
## 7, the user's word, 2026-10-20). Twice the floor of the first round (the user's
## word, 2026-10-20). The first dungeon: imps; imps and puglins; puglins and
## imps; the two orcs, taking turns; the lord of the orcs alone. Closing it brings
## the hero to its top level whatever he has gained on the way.
const ROOMS := {
	0: [
		{"kind": "hall", "w": 44.0, "l": 56.0, "h": 18.0, "lv": 1, "xp": 1.5, "foes": [[IMP, 6]]},
		{"kind": "court", "w": 52.0, "l": 64.0, "h": 11.0, "lv": 3, "xp": 2.5, "foes": [[IMP, 5], [PUGLIN, 5]]},
		{"kind": "hall", "w": 50.0, "l": 70.0, "h": 24.0, "hole": true, "lv": 5, "xp": 3.0,
				"foes": [[PUGLIN, 7], [IMP, 5]]},
		{"kind": "terrace", "w": 56.0, "l": 66.0, "h": 14.0, "lv": 7, "xp": 3.5,
				"foes": [[ORC, 1, ORC_TWO_SWORDS], [ORC, 1, ORC_LONG_SWORD]]},
		{"kind": "throne", "w": 66.0, "l": 78.0, "h": 6.0, "lv": 8, "foes": [[ORC_CHIEF, 1, ORC_LORD]]},
	],
}
## The boss of each dungeon: the scene in its last room that has to fall.
const BOSS := {0: ORC_CHIEF}
## How many may set on each hero at once, an orc near him counting as one
## (the user's word: at most two; the rest throw from off).
const CROWD := 2
## Seconds between any two things thrown at one hero (the user's word: so
## many waiting made a hail of it).
const THROW_GAP := 2.0
## Held back, they wait round him on these rings, spread out evenly.
const HOLD_RINGS := [8.5, 11.5]

## Which dungeon this is (from [member Game.dungeon_id]; 0 when there is none).
@export var id: int = 0

signal room_cleared(index: int)
signal closed

var rooms: Array = []
## Each room's middle (on the floor) and its near and far ends (z).
var centres: Array[Vector3] = []
## Room index the heroes are in, -1 before the first wakes.
var current: int = -1
var cleared: Array[bool] = []
var is_closed: bool = false
## The iron gate at the far end of each room (none after the last).
var gates: Array[Node3D] = []
var _alive: Array[Node3D] = []
var _spawned: int = 0
var _floor_shader: Shader
var _rock_mat: StandardMaterial3D
var _glass_shader: Shader
var _beam_shader: Shader
## Every column standing: {room, at, h, thick, parts (meshes), blocker, broken}.
var _columns: Array[Dictionary] = []
var _crowd_clock: float = 0.0
## The small ones let at the heroes just now ([method _hold_back_crowd]).
var _holders: Array[Node3D] = []
## Every room's creatures, made when the dungeon loads (no stall when a room
## wakes, the user's word): asleep where they stand till theirs does.
var _room_foes: Array = []
## The pair of orcs taking turns at a lone hero: whose turn, since when, and
## each one's health at the last look (a blow on the other one hands it over).
var _orc_on: Node3D = null
var _orc_since: float = 0.0
var _orc_hand_over: float = 16.0
var _orc_health: Dictionary = {}
## The light of the day, room by room (0 afternoon .. 4 night), and its tween.
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
var _exit: PortalLook = null
## Gate index -> the height it is going to.
var _gate_goal: Dictionary = {}

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
	bool cob = to_wall < border || abs(lp.x) < aisle || gone > 0.5;
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

const WALL_SHADER := """
shader_type spatial;
uniform vec4 stone : source_color = vec4(0.42, 0.38, 0.34, 1.0);
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
	if not ROOMS.has(id):
		id = 0
	rooms = ROOMS[id]
	cleared.resize(rooms.size())
	cleared.fill(false)
	_lay_out()
	_materials()
	_sky()
	for i in rooms.size():
		_build_room(i)
	_vista()
	_place_marks()
	# Where the orcs' heavy blows crack the floor ([OrcFighter]).
	add_to_group(&"ground_scars")
	_build_hud()
	_say("%s" % String(Portals.DEFS[id]["name"]), 3.5)
	Fighter.throw_gap = THROW_GAP
	_spawn_all.call_deferred()


func _exit_tree() -> void:
	Fighter.throw_gap = 0.0


func _room(i: int) -> Dictionary:
	return rooms[i]


## Each room's middle: the first at the origin, the rest one after another
## along −Z with a wall between.
func _lay_out() -> void:
	centres.clear()
	var z := 0.0
	for i in rooms.size():
		var l: float = _room(i)["l"]
		if i > 0:
			z -= l * 0.5
		centres.append(Vector3(0.0, 0.0, z))
		z -= l * 0.5 + WALL_T
	return


## The middle of room `i`, on the floor.
func centre(i: int) -> Vector3:
	return centres[clampi(i, 0, centres.size() - 1)]


## Where the heroes stand when the dungeon is loaded: the near end of room 0.
func entry_point(slot: int) -> Vector3:
	var l: float = _room(0)["l"]
	return centre(0) + Vector3(-1.5 + float(slot % 4) * 1.0, 0.1, l * 0.5 - 4.0 + floorf(float(slot) / 4.0))


## The room a point stands in (-1 outside them all).
func room_at(p: Vector3) -> int:
	for i in rooms.size():
		var c := centre(i)
		var r := _room(i)
		if absf(p.z - c.z) <= float(r["l"]) * 0.5 and absf(p.x) <= float(r["w"]) * 0.5 + 0.5:
			return i
	return -1


func _place_marks() -> void:
	var root: Node = owner if owner != null else get_parent()
	var marks := root.get_node_or_null("SpawnPoints")
	if marks == null:
		return
	for i in marks.get_child_count():
		(marks.get_child(i) as Node3D).position = entry_point(i)


func _materials() -> void:
	_floor_shader = Shader.new()
	_floor_shader.code = FLOOR_SHADER
	_glass_shader = Shader.new()
	_glass_shader.code = GLASS_SHADER
	_beam_shader = Shader.new()
	_beam_shader.code = BEAM_SHADER
	_rock_mat = StandardMaterial3D.new()
	_rock_mat.albedo_color = Color(0.40, 0.37, 0.33)
	_rock_mat.roughness = 0.95
	_wall_mat = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = WALL_SHADER
	_wall_mat.shader = ws
	_trim_mat = StandardMaterial3D.new()
	_trim_mat.albedo_color = Color(0.42, 0.39, 0.40)
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
	if kind == "hall":
		m.set_shader_parameter("slab", 2.6)
		m.set_shader_parameter("course", 1.7)
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
	COLOR = c;
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
	if _sun != null:
		_sun.rotation = Vector3(-deg_to_rad(maxf(elev, -6.0)), yaw, 0.0)
		_sun.light_color = sun_c
		_sun.light_energy = maxf(sun_e, 0.0)
		_sun.visible = sun_e > 0.01


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
	var last := i == rooms.size() - 1
	var far := -l * 0.5 - WALL_T * 0.5
	var near := l * 0.5 + WALL_T * 0.5

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
	# The near wall, in the first room only (the rest share the last room's far one).
	if i == 0:
		_solid(room, _wall_mat, Vector3(w + WALL_T * 2.0, h, WALL_T), Vector3(0.0, h * 0.5, near))
	# The far wall: as high as the higher of the two rooms, with a gate, or the
	# boss's court's open end over the drop.
	if not last:
		var nxt := _room(i + 1)
		var wall_h := maxf(h, float(nxt["h"]))
		var wall_w := maxf(w, float(nxt["w"])) + WALL_T * 2.0
		var piece := (wall_w - DOOR_W) * 0.5
		for side: float in [-1.0, 1.0]:
			_solid(room, _wall_mat, Vector3(piece, wall_h, WALL_T),
					Vector3(side * (DOOR_W + piece) * 0.5, wall_h * 0.5, far))
		_solid(room, _wall_mat, Vector3(DOOR_W, wall_h - DOOR_H, WALL_T),
				Vector3(0.0, DOOR_H + (wall_h - DOOR_H) * 0.5, far))
		_door_frame(room, Vector3(0.0, 0.0, far))
		gates.append(_build_gate(room, Vector3(0.0, 0.0, far)))
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
		_hall_columns(room, i, w, l, h)
		_ceiling(room, w, l, h, r.has("hole"))
		_high_windows(room, w, l, h)
	elif kind == "court":
		_wall_columns(room, i, w, l, h)
		_basin(room)
		_fallen_column(room, Vector3(-w * 0.25, 0.0, l * 0.22), 0.6)
	elif kind == "terrace":
		_wall_columns(room, i, w, l, h, true)
		_fallen_column(room, Vector3(w * 0.18, 0.0, -l * 0.28), -0.4)
	else:
		_ruins(room, i, w, l)
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
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.08, long, 2.0)
	_deco(room, _cloth_mat, cloth, at + Vector3(-side * 0.1, -long * 0.5, 0.0))
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
	var mid := (centre(0) + centre(rooms.size() - 1)) * 0.5
	var lands := PalaceVista.new()
	lands.name = "Vista"
	# The palace over the middle of the lands' basin.
	lands.position = Vector3(mid.x - 560.0, 0.0, mid.z + 120.0)
	add_child(lands)
	# The crag: great rocks under the palace's footprint, down into the lands.
	var last := rooms.size() - 1
	var far_z := centre(last).z - float(_room(last)["l"]) * 0.5
	var near_z := centre(0).z + float(_room(0)["l"]) * 0.5
	var widest := 0.0
	for r: Dictionary in rooms:
		widest = maxf(widest, float(r["w"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + id
	var k := 0
	var z := near_z
	while z > far_z - 10.0:
		var crag := MeshInstance3D.new()
		crag.mesh = RockWave._crag_mesh(k % RockWave.SHAPES)
		var box := crag.mesh.get_aabb()
		var want := Vector3(widest * rng.randf_range(1.0, 1.5), PalaceVista.DROP + 40.0, rng.randf_range(50.0, 80.0))
		crag.scale = Vector3(want.x / maxf(box.size.x, 0.01), want.y / maxf(box.size.y, 0.01), want.z / maxf(box.size.z, 0.01))
		crag.position = Vector3(rng.randf_range(-6.0, 6.0), 0.0, z - 20.0)
		crag.position.y = -24.0 - (box.position.y + box.size.y) * crag.scale.y
		crag.rotation.y = rng.randf_range(-0.3, 0.3)
		crag.material_override = _rock_mat
		crag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(crag)
		z -= 45.0
		k += 1


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
		var o := body as PackBrute
		if o != null and is_instance_valid(o) and not o.is_dead:
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


## An iron portcullis filling the doorway at `at`; raised by `_set_gate`.
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


## The music for now ([World] asks): the boss's while its room is fought,
## otherwise the dungeon's.
func music_wanted() -> StringName:
	if current == rooms.size() - 1 and not is_closed:
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
	# A room wakes when a living hero is well inside it.
	for hero in heroes:
		if hero.is_dead:
			continue
		var r := room_at(hero.global_position)
		if r > current and r >= 0 and (r == 0 or cleared[r - 1]):
			var c := centre(r)
			if hero.global_position.z < c.z + float(_room(r)["l"]) * 0.5 - 3.0:
				_wake(r)
	if current >= 0 and not cleared[current]:
		var left := 0
		for body in _alive:
			if is_instance_valid(body) and not bool(body.get("is_dead")):
				left += 1
		if left == 0 and _spawned > 0:
			_clear(current)
	_tick_gates(delta)
	_crowd_clock -= delta
	if _crowd_clock <= 0.0:
		_crowd_clock = 0.2
		var standing: Array[Player] = []
		for hero in heroes:
			if not hero.is_dead:
				standing.append(hero)
		_lead_orcs(standing)
		_hold_back_crowd(heroes)
	if _exit != null:
		for hero in heroes:
			var gap := hero.global_position - _exit.global_position
			gap.y = 0.0
			if not hero.is_dead and gap.length() < 2.2:
				leave()
				return


## Every room's creatures, made at once as the dungeon loads, standing in the
## far half of their rooms, asleep (they see no one: their leash is nothing),
## and all but the first two rooms not even thinking yet.
func _spawn_all() -> void:
	var level_root: Node = owner if owner != null else get_parent()
	var creatures := level_root.get_node_or_null("Enemies")
	_room_foes.clear()
	for i in rooms.size():
		var mine: Array[Node3D] = []
		_room_foes.append(mine)
		if creatures == null:
			continue
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
				var across := (float(k % 4) - 1.5) * (w - 12.0) / 3.0
				var row := floorf(float(k) / 4.0)
				var at := c + Vector3(across + sin(float(k) * 2.3) * 1.2, 0.2, -l * 0.08 - row * 3.0)
				if String(entry[0]) == BOSS.get(id, ""):
					at = c + Vector3(0.0, 0.2, -l * 0.2)
				body.position = at
				body.rotation.y = 0.0
				if entry.size() > 2:
					var props: Dictionary = entry[2]
					for key: String in props:
						body.set(StringName(key), props[key])
				body.set("band", StringName("dungeon_%d_room_%d" % [id, i]))
				body.set("camp_centre", Vector3(c.x, 0.0, c.z))
				if "leash_radius" in body:
					body.set("leash_radius", 0.01)
				if r.has("lv"):
					body.set_meta(&"level", int(r["lv"]))
				if i >= 2:
					body.process_mode = Node.PROCESS_MODE_DISABLED
				# out of sight till the gate before its room opens (its bars and
				# name would show through the walls)
				body.visible = i == 0
				creatures.add_child(body)
				mine.append(body)
				k += 1


## Room `i`'s creatures, already standing in it, wake and come at him; the
## room after it starts to stir (thinking, still asleep).
func _wake(i: int) -> void:
	current = i
	_alive.clear()
	_holders.clear()
	_orc_on = null
	# The gate behind him comes down again.
	if i > 0:
		_set_gate(i - 1, false)
	if _room_foes.size() != rooms.size():
		_spawn_all()
	var l: float = _room(i)["l"]
	var hero := _nearest_hero(centre(i))
	for body: Node3D in _room_foes[i]:
		if not is_instance_valid(body):
			continue
		body.process_mode = Node.PROCESS_MODE_INHERIT
		if "leash_radius" in body:
			body.set("leash_radius", l)
		_alive.append(body)
		if hero != null and body.has_method("_rouse"):
			body.call_deferred("_rouse", hero)
	_spawned = _alive.size()
	if i + 1 < _room_foes.size():
		for body: Node3D in _room_foes[i + 1]:
			if is_instance_valid(body):
				body.process_mode = Node.PROCESS_MODE_INHERIT
	_to_phase(float(i), 7.0)
	var last := i == rooms.size() - 1
	_say("ბოსი: ორკების მბრძანებელი" if last else "ოთახი %d / %d" % [i + 1, rooms.size()], 3.0)
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
	# What clearing the room is worth on top of its creatures.
	var bonus := float(_room(i).get("xp", 0.0))
	if bonus > 0.0:
		for hero in _heroes():
			var book := hero.get_node_or_null("Leveling") as Leveling
			if book != null and not hero.is_dead:
				book.gain(bonus)
	# The fallen get up when the room is clear (the user's word: in a band,
	# the dead wait for the others to clear the room).
	for hero in _heroes():
		if hero.is_dead and hero.has_method("_respawn"):
			var at := hero.global_position
			hero.call("_respawn")
			hero.global_position = at
	if i + 1 < _room_foes.size():
		for body: Node3D in _room_foes[i + 1]:
			if is_instance_valid(body):
				body.visible = true
	if i < rooms.size() - 1:
		_set_gate(i, true)
		_say("კარი გაიღო", 2.0)
	else:
		_close()


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
	var last := rooms.size() - 1
	_exit = PortalLook.new()
	_exit.name = "WayOut"
	_exit.tint = Portals.DEFS[id]["tint"]
	_exit.position = centre(last) + Vector3(0.0, 0.0, -float(_room(last)["l"]) * 0.5 + 15.0)
	add_child(_exit)
	closed.emit()


## Gate `i` (at the far end of room `i`) up or down.
func _set_gate(i: int, open: bool) -> void:
	if i < 0 or i >= gates.size():
		return
	_gate_goal[i] = (DOOR_H - 0.2) if open else 0.0
	var shape := gates[i].get_child(0) as CollisionShape3D
	if shape != null:
		shape.set_deferred(&"disabled", open)


func _tick_gates(delta: float) -> void:
	for i: int in _gate_goal:
		var g := gates[i]
		var goal: float = _gate_goal[i]
		g.position.y = move_toward(g.position.y, goal, delta * 3.0)


func _watch_deaths(heroes: Array[Player]) -> void:
	for hero in heroes:
		if _watched.has(hero.get_instance_id()):
			continue
		_watched[hero.get_instance_id()] = true
		hero.died.connect(_on_hero_died.bind(hero))
		# Here a hero gets up only when his room is cleared, or by the gate outside.
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
