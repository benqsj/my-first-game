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
## columns, banners, torches, iron gates, and round it all the sky, the moon,
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

## Per dungeon: its rooms. Each: kind ("hall" under a roof, "court" open with
## windows, "terrace" open with one side over the drop, "throne" the boss's
## court on the cliff), width, length, wall height, and its creatures as
## [scene, count]. The first dungeon (the user's word: 5 in the first room, 8
## in the second, the first room's kinds coming back with the new ones). Worth
## (in wolves, [Leveling]): 3, 5.6, 15.2, 20.4, 14 — about 58 of the 63 that
## take him from 1 to 10; closing it gives the rest.
const ROOMS := {
	0: [
		{"kind": "hall", "w": 30.0, "l": 38.0, "h": 13.0, "foes": [[IMP, 5]]},
		{"kind": "court", "w": 36.0, "l": 44.0, "h": 9.0, "foes": [[IMP, 4], [PUGLIN, 4]]},
		{"kind": "hall", "w": 34.0, "l": 48.0, "h": 18.0, "foes": [[PUGLIN, 4], [IMP, 3], [ORC, 4]]},
		{"kind": "terrace", "w": 38.0, "l": 46.0, "h": 11.0, "foes": [[ORC, 3], [ORC_SKIRM, 3], [PUGLIN, 3], [IMP, 3]]},
		{"kind": "throne", "w": 46.0, "l": 54.0, "h": 5.0, "foes": [[OGRE, 1], [ORC, 2]]},
	],
}
## The boss of each dungeon: the scene in its last room that has to fall.
const BOSS := {0: OGRE}

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
var _floor_hall: ShaderMaterial
var _floor_open: ShaderMaterial
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
uniform vec4 stone_a : source_color = vec4(0.30, 0.28, 0.30, 1.0);
uniform vec4 stone_b : source_color = vec4(0.22, 0.20, 0.24, 1.0);
uniform vec4 grout : source_color = vec4(0.07, 0.06, 0.08, 1.0);
uniform float tile = 2.0;
uniform float shine = 0.4;
uniform float rows = 0.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz / tile;
	// Flagstones in running rows when `rows` is set, a chequer otherwise.
	p.x += rows * mod(floor(p.y), 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float n = hash(cell);
	float check = (1.0 - rows) * mod(cell.x + cell.y, 2.0) + rows * step(0.5, n);
	vec3 c = mix(stone_a.rgb, stone_b.rgb, check) * (0.8 + 0.32 * n);
	float joint = step(f.x, 0.025) + step(0.975, f.x) + step(f.y, 0.025) + step(0.975, f.y);
	c = mix(c, grout.rgb, clamp(joint, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = mix(0.85, 0.25, shine) + 0.15 * n;
	SPECULAR = 0.3 + 0.3 * shine;
}
"""

const WALL_SHADER := """
shader_type spatial;
uniform vec4 stone : source_color = vec4(0.27, 0.25, 0.28, 1.0);
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
	ALBEDO = c;
	ROUGHNESS = 0.9;
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
	_build_hud()
	_say("%s" % String(Portals.DEFS[id]["name"]), 3.5)


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
	var fs := Shader.new()
	fs.code = FLOOR_SHADER
	_floor_hall = ShaderMaterial.new()
	_floor_hall.shader = fs
	_floor_hall.set_shader_parameter("tile", 2.4)
	_floor_hall.set_shader_parameter("shine", 0.75)
	_floor_hall.set_shader_parameter("stone_a", Color(0.36, 0.33, 0.37))
	_floor_hall.set_shader_parameter("stone_b", Color(0.16, 0.14, 0.18))
	_floor_open = ShaderMaterial.new()
	_floor_open.shader = fs
	_floor_open.set_shader_parameter("tile", 1.6)
	_floor_open.set_shader_parameter("shine", 0.15)
	_floor_open.set_shader_parameter("rows", 1.0)
	_floor_open.set_shader_parameter("stone_a", Color(0.40, 0.37, 0.34))
	_floor_open.set_shader_parameter("stone_b", Color(0.31, 0.29, 0.28))
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


## Dusk over the palace: a violet sky, a low moon.
func _sky() -> void:
	var root: Node = owner if owner != null else get_parent()
	var env_node := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return
	var env := env_node.environment
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.05, 0.04, 0.14)
	mat.sky_horizon_color = Color(0.52, 0.30, 0.46)
	mat.sky_curve = 0.12
	mat.ground_horizon_color = Color(0.30, 0.20, 0.32)
	mat.ground_bottom_color = Color(0.05, 0.03, 0.08)
	mat.sun_angle_max = 8.0
	mat.sun_curve = 0.05
	var sky := Sky.new()
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.25
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(0.7, 0.66, 0.92)
		sun.light_energy = 0.6


func _build_room(i: int) -> void:
	var r := _room(i)
	var kind: String = r["kind"]
	var w: float = r["w"]
	var l: float = r["l"]
	var h: float = r["h"]
	var open := kind != "hall"
	var c := centre(i)
	var room := Node3D.new()
	room.name = "Room%d" % (i + 1)
	room.position = c
	add_child(room)
	var last := i == rooms.size() - 1
	var far := -l * 0.5 - WALL_T * 0.5
	var near := l * 0.5 + WALL_T * 0.5

	# The floor (with the strip under the next doorway), and the rock under it.
	_solid(room, _floor_hall if not open else _floor_open, Vector3(w + WALL_T * 2.0, 1.0, l + WALL_T),
			Vector3(0.0, -0.5, -WALL_T * 0.5))
	_solid(room, _wall_mat, Vector3(w + WALL_T * 2.0, 60.0, l + WALL_T), Vector3(0.0, -31.0, -WALL_T * 0.5), false)

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
		_hall_columns(room, w, l, h)
		_ceiling(room, w, l, h)
	elif kind == "court":
		_wall_columns(room, w, l, h)
		_basin(room)
	elif kind == "terrace":
		_wall_columns(room, w, l, h, true)
	else:
		_ruins(room, w, l)
		_dais(room, l)

	# A runner down the middle.
	var rug := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(4.0, 0.03, l - 6.0)
	rug.mesh = rm
	var rug_mat := StandardMaterial3D.new()
	rug_mat.albedo_color = Color(0.30, 0.04, 0.07)
	rug_mat.roughness = 1.0
	rug.material_override = rug_mat
	rug.position = Vector3(0.0, 0.015, 0.0)
	room.add_child(rug)
	for side: float in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.22, 0.035, l - 6.0)
		edge.mesh = em
		edge.material_override = _gold_mat
		edge.position = Vector3(side * 1.9, 0.018, 0.0)
		room.add_child(edge)


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
func _blocker(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)


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
		# The window's pointed head, in carved stone.
		for s: float in [-1.0, 1.0]:
			var box := BoxMesh.new()
			box.size = Vector3(WALL_T + 0.1, win * 0.62, 0.35)
			var piece := _deco(room, _trim_mat, box, Vector3(x, head - win * 0.2, mid - WALL_T * 0.5 + s * win * 0.25))
			piece.rotation.x = s * 0.9
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
func _hall_columns(room: Node3D, w: float, l: float, h: float) -> void:
	var n := maxi(3, int(l / 9.0))
	for k in n:
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			var x := side * (w * 0.5 - 4.5)
			_column(room, Vector3(x, 0.0, z), h, 1.0)
			if k % 2 == 0:
				_torch(room, Vector3(x - side * 0.85, 3.6, z))
			# Banners on the walls between the columns.
			if k < n - 1:
				_hang_banner(room, Vector3(side * (w * 0.5 - 0.1), h - 2.2, z - l / float(n) * 0.5), side, minf(7.0, h * 0.45))


func _wall_columns(room: Node3D, w: float, l: float, h: float, one_side: bool = false) -> void:
	var n := maxi(3, int(l / 10.0))
	for k in n:
		var z := l * 0.5 - (float(k) + 0.5) * l / float(n)
		for side: float in [-1.0, 1.0]:
			if one_side and side > 0.0:
				continue
			var x := side * (w * 0.5 - 0.9)
			_column(room, Vector3(x, 0.0, z), h * 0.9, 0.8)
			if k % 2 == 1:
				_torch(room, Vector3(x - side * 0.7, 3.4, z))


func _column(room: Node3D, at: Vector3, h: float, thick: float) -> void:
	var base := BoxMesh.new()
	base.size = Vector3(thick * 2.0, 0.6, thick * 2.0)
	_solid(room, _trim_mat, base.size, at + Vector3(0.0, 0.3, 0.0))
	var shaft := CylinderMesh.new()
	shaft.top_radius = thick * 0.62
	shaft.bottom_radius = thick * 0.7
	shaft.height = h - 1.4
	shaft.radial_segments = 12
	_deco(room, _wall_mat, shaft, at + Vector3(0.0, 0.6 + (h - 1.4) * 0.5, 0.0))
	_blocker(room, Vector3(thick * 1.3, h, thick * 1.3), at + Vector3(0.0, h * 0.5, 0.0))
	var cap := BoxMesh.new()
	cap.size = Vector3(thick * 1.9, 0.8, thick * 1.9)
	_deco(room, _trim_mat, cap, at + Vector3(0.0, h - 0.4, 0.0))


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
func _ceiling(room: Node3D, w: float, l: float, h: float) -> void:
	var slab := BoxMesh.new()
	slab.size = Vector3(w + WALL_T * 2.0, 1.0, l + WALL_T * 2.0)
	_deco(room, _wood_mat, slab, Vector3(0.0, h + 0.5, -WALL_T * 0.5))
	var n := int(l / 5.0)
	for k in n + 1:
		var beam := BoxMesh.new()
		beam.size = Vector3(w, 0.9, 0.7)
		_deco(room, _wood_mat, beam, Vector3(0.0, h - 0.45, l * 0.5 - float(k) * l / float(n)))
	for side: float in [-1.0, 1.0]:
		var long := BoxMesh.new()
		long.size = Vector3(0.8, 1.1, l)
		_deco(room, _wood_mat, long, Vector3(side * (w * 0.5 - 4.5), h - 1.0, 0.0))
	for k in 3:
		_hanging_brazier(room, Vector3(0.0, h, l * 0.5 - (float(k) + 0.5) * l / 3.0), h)


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
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 2.6
	light.omni_range = 18.0
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
func _ruins(room: Node3D, w: float, l: float) -> void:
	var heights: Array[float] = [7.0, 3.2, 9.0, 1.8, 5.5, 8.0, 2.4, 6.5]
	for k in 8:
		var side := -1.0 if k % 2 == 0 else 1.0
		var z := l * 0.5 - 6.0 - floorf(float(k) / 2.0) * (l - 16.0) / 3.0
		_column(room, Vector3(side * (w * 0.5 - 3.0), 0.0, z), heights[k], 1.1)
		if k % 3 == 0:
			_torch(room, Vector3(side * (w * 0.5 - 4.2), 1.2, z))


## A raised dais at the far end, where the way out will stand.
func _dais(room: Node3D, l: float) -> void:
	for k in 2:
		_solid(room, _trim_mat, Vector3(14.0 - float(k) * 3.0, 0.3, 8.0 - float(k) * 2.0),
				Vector3(0.0, 0.15 + float(k) * 0.3, -l * 0.5 + 5.0))


## The sky's furniture seen from the open rooms: mountains on every side, a
## moon, and the sea of cloud far below.
func _vista() -> void:
	var mid := (centre(0) + centre(rooms.size() - 1)) * 0.5
	var far_mat := StandardMaterial3D.new()
	far_mat.albedo_color = Color(0.13, 0.10, 0.20)
	far_mat.roughness = 1.0
	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.55, 0.50, 0.66)
	snow_mat.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + id
	for k in 26:
		var a := TAU * float(k) / 26.0 + rng.randf_range(-0.08, 0.08)
		var dist := rng.randf_range(380.0, 620.0)
		var tall := rng.randf_range(90.0, 230.0)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tall * rng.randf_range(0.7, 1.1)
		cone.height = tall
		cone.radial_segments = 6
		var at := mid + Vector3(cos(a) * dist, -60.0 + tall * 0.5, sin(a) * dist)
		var m := _deco(self, far_mat, cone, at)
		m.rotation.y = rng.randf() * TAU
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cap := CylinderMesh.new()
		cap.top_radius = 0.0
		cap.bottom_radius = cone.bottom_radius * 0.28
		cap.height = tall * 0.28
		cap.radial_segments = 6
		var s := _deco(self, snow_mat, cap, at + Vector3(0.0, tall * 0.36 + 0.5, 0.0))
		s.rotation.y = m.rotation.y
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cloud := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400.0, 2400.0)
	cloud.mesh = plane
	var cm := ShaderMaterial.new()
	var cs := Shader.new()
	cs.code = CLOUD_SHADER
	cm.shader = cs
	cloud.material_override = cm
	cloud.position = mid + Vector3(0.0, -55.0, 0.0)
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
	var moon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 38.0
	sphere.height = 76.0
	moon.mesh = sphere
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.95, 0.9, 1.0)
	moon.material_override = mm
	moon.position = mid + Vector3(260.0, 230.0, -700.0)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)


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
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.8
	light.omni_range = 11.0
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
	if _exit != null:
		for hero in heroes:
			var gap := hero.global_position - _exit.global_position
			gap.y = 0.0
			if not hero.is_dead and gap.length() < 2.2:
				leave()
				return


## Room `i`'s creatures come: in the far half of it, roused at once.
func _wake(i: int) -> void:
	current = i
	_alive.clear()
	_spawned = 0
	# The gate behind him comes down again.
	if i > 0:
		_set_gate(i - 1, false)
	var level_root: Node = owner if owner != null else get_parent()
	var creatures := level_root.get_node_or_null("Enemies")
	if creatures == null:
		return
	var c := centre(i)
	var r := _room(i)
	var w: float = r["w"]
	var l: float = r["l"]
	var list: Array = r["foes"]
	var total := 0
	for entry: Array in list:
		total += int(entry[1])
	var k := 0
	var hero := _nearest_hero(c)
	for entry: Array in list:
		var scene := load(String(entry[0])) as PackedScene
		if scene == null:
			continue
		for n in int(entry[1]):
			var body := scene.instantiate() as Node3D
			body.name = "D%d_R%d_%d" % [id, i, k]
			# A loose crowd over the far half of the room.
			var across := (float(k % 4) - 1.5) * (w - 12.0) / 3.0
			var row := floorf(float(k) / 4.0)
			var at := c + Vector3(across + sin(float(k) * 2.3) * 1.2, 0.2, -l * 0.08 - row * 3.0)
			if String(entry[0]) == BOSS.get(id, ""):
				at = c + Vector3(0.0, 0.2, -l * 0.2)
			body.position = at
			body.rotation.y = 0.0
			body.set("band", StringName("dungeon_%d_room_%d" % [id, i]))
			body.set("camp_centre", Vector3(c.x, 0.0, c.z))
			if "leash_radius" in body:
				body.set("leash_radius", l)
			creatures.add_child(body)
			_alive.append(body)
			_spawned += 1
			k += 1
			if hero != null and body.has_method("_rouse"):
				body.call_deferred("_rouse", hero)
	var last := i == rooms.size() - 1
	_say("ბოსი!" if last else "ოთახი %d / %d" % [i + 1, rooms.size()], 2.5)
	if total == 0:
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
	# The fallen get up when the room is clear (the user's word: in a band,
	# the dead wait for the others to clear the room).
	for hero in _heroes():
		if hero.is_dead and hero.has_method("_respawn"):
			var at := hero.global_position
			hero.call("_respawn")
			hero.global_position = at
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
	_exit.position = centre(last) + Vector3(0.0, 0.6, -float(_room(last)["l"]) * 0.5 + 5.0)
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
