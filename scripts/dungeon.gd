class_name Dungeon
extends Node3D

## A dungeon behind one of the open world's gates ([Portals],
## portal_dungeons_plan.md): a palace of rooms one after another (the user's
## word: Archero's way). The hero stands in the first; its creatures come, and
## when the last of them is down the iron gate at its far end goes up. The
## gate behind comes down as he goes through. The last room is the boss's;
## the boss down, the dungeon is closed: what it gives is on the floor, the
## hero is brought up to the dungeon's top level, and a gate out stands where
## the boss stood.
##
## Built in code from `ROOMS` below: floors, walls, pillars, torches and the
## iron gates. Its creatures are the open world's ([World] `CAMP_SCENES`);
## each room keeps the last room's kinds and adds its own.
##
## Levels: the hero comes in at the dungeon's first level ([Leveling] is new
## in every level loaded) and the creatures carry him up as they fall; a
## dungeon closed tops him up to its last. Dying alone in here puts him back
## by the gate he came in by.

## Room size (x across, z along) and walls.
const ROOM_W := 24.0
const ROOM_L := 28.0
const WALL_H := 6.5
const WALL_T := 1.2
const DOOR_W := 4.2
const DOOR_H := 4.4
## How long after dying alone he is taken back out.
const BACK_OUT_AFTER := 3.0

const IMP := "res://scenes/enemies/imp.tscn"
const PUGLIN := "res://scenes/enemies/puglin.tscn"
const ORC := "res://scenes/enemies/pack/orc.tscn"
const ORC_SKIRM := "res://scenes/enemies/pack/orc_skirmisher.tscn"
const OGRE := "res://scenes/enemies/pack/ogre.tscn"

## Per dungeon: its rooms, each a list of [scene, count]. The first dungeon
## (the user's word: 5 in the first room, 8 in the second, the first room's
## kinds coming back with the new ones). Worth (in wolves, [Leveling]):
## 3, 5.6, 14.6, 20.4, 14 — about 58 of the 63 that take him from 1 to 10;
## closing it gives the rest.
const ROOMS := {
	0: [
		[[IMP, 5]],
		[[IMP, 4], [PUGLIN, 4]],
		[[PUGLIN, 4], [IMP, 3], [ORC, 4]],
		[[ORC, 3], [ORC_SKIRM, 3], [PUGLIN, 3], [IMP, 3]],
		[[OGRE, 1], [ORC, 2]],
	],
}
## The boss of each dungeon: the scene in its last room that has to fall.
const BOSS := {0: OGRE}

## Which dungeon this is (from [member Game.dungeon_id]; 0 when there is none).
@export var id: int = 0

signal room_cleared(index: int)
signal closed

var rooms: Array = []
## Room index the heroes are in, -1 before the first wakes.
var current: int = -1
var cleared: Array[bool] = []
var is_closed: bool = false
## The iron gate at the far end of each room (none after the last).
var gates: Array[Node3D] = []
var _alive: Array[Node3D] = []
var _spawned: int = 0
var _floor_mat: ShaderMaterial
var _wall_mat: ShaderMaterial
var _iron_mat: StandardMaterial3D
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
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz / tile;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float n = hash(cell);
	// Checked slabs, each a little different, with dark joints.
	float check = mod(cell.x + cell.y, 2.0);
	vec3 c = mix(stone_a.rgb, stone_b.rgb, check) * (0.82 + 0.3 * n);
	float joint = step(f.x, 0.03) + step(0.97, f.x) + step(f.y, 0.03) + step(0.97, f.y);
	c = mix(c, grout.rgb, clamp(joint, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 0.55 + 0.3 * n;
	SPECULAR = 0.35;
}
"""

const WALL_SHADER := """
shader_type spatial;
uniform vec4 stone : source_color = vec4(0.26, 0.24, 0.27, 1.0);
uniform vec4 grout : source_color = vec4(0.08, 0.07, 0.09, 1.0);
varying vec3 wpos;
varying vec3 wnorm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	// Ashlar courses: 0.6 m tall, 1.2 m long, every other course half a block over.
	float u = abs(wnorm.x) > abs(wnorm.z) ? wpos.z : wpos.x;
	vec2 p = vec2(u / 1.2, wpos.y / 0.6);
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float n = hash(cell);
	vec3 c = stone.rgb * (0.7 + 0.45 * n);
	float joint = step(f.x, 0.025) + step(0.975, f.x) + step(f.y, 0.05) + step(0.95, f.y);
	c = mix(c, grout.rgb, clamp(joint, 0.0, 1.0));
	// Darker towards the floor, as old stone is.
	c *= 0.75 + 0.25 * smoothstep(0.0, 3.0, wpos.y);
	ALBEDO = c;
	ROUGHNESS = 0.9;
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
	_materials()
	for i in rooms.size():
		_build_room(i)
	_build_hud()
	_say("%s" % String(Portals.DEFS[id]["name"]), 3.5)


## The middle of room `i`, on the floor.
static func centre(i: int) -> Vector3:
	return Vector3(0.0, 0.0, -float(i) * (ROOM_L + WALL_T))


## Where the heroes stand when the dungeon is loaded: the near end of room 0.
static func entry_point(slot: int) -> Vector3:
	return centre(0) + Vector3(-1.5 + float(slot) * 1.0, 0.1, ROOM_L * 0.5 - 3.0)


func _materials() -> void:
	_floor_mat = ShaderMaterial.new()
	var fs := Shader.new()
	fs.code = FLOOR_SHADER
	_floor_mat.shader = fs
	_wall_mat = ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = WALL_SHADER
	_wall_mat.shader = ws
	_iron_mat = StandardMaterial3D.new()
	_iron_mat.albedo_color = Color(0.09, 0.085, 0.08)
	_iron_mat.metallic = 0.85
	_iron_mat.roughness = 0.45


func _build_room(i: int) -> void:
	var c := centre(i)
	var room := Node3D.new()
	room.name = "Room%d" % (i + 1)
	room.position = c
	add_child(room)
	# The floor, and a strip under the doorway to the next room.
	_solid(room, _floor_mat, Vector3(ROOM_W, 1.0, ROOM_L + WALL_T), Vector3(0.0, -0.5, -WALL_T * 0.5))
	# The long walls.
	for side: float in [-1.0, 1.0]:
		_solid(room, _wall_mat, Vector3(WALL_T, WALL_H, ROOM_L + WALL_T * 2.0),
				Vector3(side * (ROOM_W + WALL_T) * 0.5, WALL_H * 0.5, -WALL_T * 0.5))
	# The near wall: whole in the first room, otherwise it is the last room's far wall.
	if i == 0:
		_solid(room, _wall_mat, Vector3(ROOM_W, WALL_H, WALL_T), Vector3(0.0, WALL_H * 0.5, ROOM_L * 0.5 + WALL_T * 0.5))
	# The far wall: with a doorway and its iron gate, except in the last room.
	var far := -ROOM_L * 0.5 - WALL_T * 0.5
	if i < rooms.size() - 1:
		var piece := (ROOM_W - DOOR_W) * 0.5
		for side: float in [-1.0, 1.0]:
			_solid(room, _wall_mat, Vector3(piece, WALL_H, WALL_T),
					Vector3(side * (DOOR_W + piece) * 0.5, WALL_H * 0.5, far))
		_solid(room, _wall_mat, Vector3(DOOR_W, WALL_H - DOOR_H, WALL_T),
				Vector3(0.0, DOOR_H + (WALL_H - DOOR_H) * 0.5, far))
		gates.append(_build_gate(room, Vector3(0.0, 0.0, far)))
	else:
		_solid(room, _wall_mat, Vector3(ROOM_W, WALL_H, WALL_T), Vector3(0.0, WALL_H * 0.5, far))
	# Pillars along the walls, a torch on every other.
	var n := 4
	for k in n:
		var z := ROOM_L * 0.5 - (float(k) + 0.5) * ROOM_L / float(n)
		for side: float in [-1.0, 1.0]:
			var x := side * (ROOM_W * 0.5 - 0.55)
			_solid(room, _wall_mat, Vector3(1.1, WALL_H, 1.1), Vector3(x, WALL_H * 0.5, z))
			_solid(room, _wall_mat, Vector3(1.5, 0.5, 1.5), Vector3(x, 0.25, z))
			if (k + (1 if side > 0.0 else 0)) % 2 == 0:
				_torch(room, Vector3(x - side * 0.7, 3.2, z))
	# A worn runner of red down the middle.
	var rug := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(3.2, 0.02, ROOM_L - 4.0)
	rug.mesh = rm
	var rug_mat := StandardMaterial3D.new()
	rug_mat.albedo_color = Color(0.32, 0.05, 0.07)
	rug_mat.roughness = 1.0
	rug.material_override = rug_mat
	rug.position = Vector3(0.0, 0.01, 0.0)
	room.add_child(rug)


func _solid(parent: Node3D, mat: Material, size: Vector3, at: Vector3) -> StaticBody3D:
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
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)
	return body


## An iron portcullis filling the doorway at `at`; raised by `open_gate`.
func _build_gate(room: Node3D, at: Vector3) -> Node3D:
	var gate := StaticBody3D.new()
	gate.name = "Gate"
	gate.position = at
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(DOOR_W, DOOR_H, 0.3)
	shape.shape = bs
	shape.position.y = DOOR_H * 0.5
	gate.add_child(shape)
	var bars := 9
	for b in bars:
		var bar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = DOOR_H
		cyl.radial_segments = 6
		bar.mesh = cyl
		bar.material_override = _iron_mat
		bar.position = Vector3(-DOOR_W * 0.5 + (float(b) + 0.5) * DOOR_W / float(bars), DOOR_H * 0.5, 0.0)
		gate.add_child(bar)
		# A spike at each foot.
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.06
		cone.height = 0.22
		tip.mesh = cone
		tip.material_override = _iron_mat
		tip.rotation.x = PI
		tip.position = Vector3(bar.position.x, -0.05, 0.0)
		gate.add_child(tip)
	for h: float in [0.9, 2.2, 3.5]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(DOOR_W, 0.09, 0.12)
		rail.mesh = rb
		rail.material_override = _iron_mat
		rail.position = Vector3(0.0, h, 0.0)
		gate.add_child(rail)
	room.add_child(gate)
	return gate


func _torch(room: Node3D, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = at
	room.add_child(holder)
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.06
	cm.height = 0.3
	cup.mesh = cm
	cup.material_override = _iron_mat
	holder.add_child(cup)
	var flame := GPUParticles3D.new()
	flame.amount = 16
	flame.lifetime = 0.55
	flame.position = Vector3(0.0, 0.2, 0.0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
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
	q.size = Vector2(0.18, 0.24)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	flame.draw_pass_1 = q
	holder.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = Vector3(0.0, 0.35, 0.0)
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


## The room a point stands in (-1 outside them all).
static func room_at(p: Vector3) -> int:
	var i := int(round(-p.z / (ROOM_L + WALL_T)))
	var c := centre(i)
	if absf(p.z - c.z) <= ROOM_L * 0.5 and absf(p.x) <= ROOM_W * 0.5:
		return i
	return -1


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
			if hero.global_position.z < c.z + ROOM_L * 0.5 - 2.0:
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
			if not hero.is_dead and hero.global_position.distance_to(_exit.global_position) < 1.6:
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
	var list: Array = rooms[i]
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
			var across := (float(k % 4) - 1.5) * (ROOM_W - 6.0) / 3.0
			var row := floorf(float(k) / 4.0)
			var at := c + Vector3(across + sin(float(k) * 2.3) * 0.8, 0.2, -ROOM_L * 0.12 - row * 2.4)
			if String(entry[0]) == BOSS.get(id, ""):
				at = c + Vector3(0.0, 0.2, -ROOM_L * 0.25)
			body.position = at
			body.rotation.y = 0.0
			body.set("band", StringName("dungeon_%d_room_%d" % [id, i]))
			body.set("camp_centre", Vector3(c.x, 0.0, c.z))
			if "leash_radius" in body:
				body.set("leash_radius", ROOM_L)
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
	# The way out, where the boss stood.
	_exit = PortalLook.new()
	_exit.name = "WayOut"
	_exit.tint = Portals.DEFS[id]["tint"]
	_exit.position = centre(rooms.size() - 1) + Vector3(0.0, 0.0, -ROOM_L * 0.5 + 2.5)
	add_child(_exit)
	closed.emit()


## Gate `i` (at the far end of room `i`) up or down.
func _set_gate(i: int, open: bool) -> void:
	if i < 0 or i >= gates.size():
		return
	_gate_goal[i] = (DOOR_H - 0.15) if open else 0.0
	var shape := gates[i].get_child(0) as CollisionShape3D
	if shape != null:
		shape.set_deferred(&"disabled", open)


func _tick_gates(delta: float) -> void:
	for i: int in _gate_goal:
		var g := gates[i]
		var goal: float = _gate_goal[i]
		g.position.y = move_toward(g.position.y, goal, delta * 2.2)


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
