class_name NecroPlaces
extends Node3D

## The old graveyard west of the mist village, and the dead wood round each of
## Arkdeva's two lairs, out of EmaceArt's NecroPOLY kit (`assets/necropoly/`,
## converted from the Unity package by `vepxis-art/necropoly/convert.py`).
##
## * **The graveyard** (`GRAVEYARD`): three of the kit's chunks at 0.4 of their
##   size (the kit is built about two and a half times a man): the walled yard
##   with its gate to the east (`02c`), the broken ground south of it (`02a`)
##   and a row of mausoleums along the north (`01c`); dead trees, lamp posts,
##   dead grass and mud round it, ground mist and the graveyard's own sound. A
##   spur of track runs to its gate from the way south to the mist village. The
##   skeletons that keep it are a camp in [constant World.CAMPS].
## * **The dead wood** (`LAIRS`): round each lair the living trees of the wood
##   give way to the kit's bare dead ones — every tree within `DEAD_CORE` of the
##   lair, fewer and fewer out to `DEAD_REACH` — with roots, dead grass and mist
##   on the ground. The trees are swapped where they stand: the wood's own trunk
##   keeps colliding, its drawn copy is put out (scaled to nothing in its
##   MultiMesh) and a dead tree is drawn in its place.
## * **F9** flips the kit's colours between ours (drained a little, darker,
##   warmer, moss on what faces the sky: `shaders/necro.gdshader`) and the
##   kit's own palette, and says which at the top of the screen. The level
##   starts in the kit's own (`ours_at_start`).
## * **Sound** (`sounds/ambience/`, from the Sonniss GDC bundle): a low evil
##   hum over the graveyard and each lair, and birds in the living wood.
##
## Nothing here is networked: every peer builds the same from these tables.

## The kit is modelled about 2.5 times a man (a lamp post ten metres high).
const KIT_SCALE := 0.4
## Pieces of the graveyard: chunk, (x, z), yaw in degrees, and how far it is
## sunk. A chunk's gate end is its +Z; yaw -90 turns that to the east (-X),
## towards the track. The kit raises its yards on a plinth (02c's paving is
## 2.5 m up, at our scale); each is sunk until its floor is the ground's, a
## couple of centimetres over it.
const GRAVEYARD: Array[Array] = [
	["02c", Vector2(88.0, -158.0), -90.0, 2.47],
	["02a", Vector2(90.0, -180.0), -90.0, 0.27],
	["01c", Vector2(87.0, -139.0), 180.0, 1.42],
]
## The ground each piece covers, for the grass to keep off (x, z, w, d).
const GRAVE_GROUND: Array[Rect2] = [
	Rect2(68.5, -171.0, 39.0, 26.0),
	Rect2(71.0, -189.0, 38.0, 18.5),
	Rect2(74.5, -143.5, 26.0, 9.0),
]
## Loose pieces of the kit round the graveyard: model, (x, z), yaw, size
## (times `KIT_SCALE`).
const GRAVE_PROPS: Array[Array] = [
	["EA03_Environment_Nature_Tree_1b", Vector2(66.0, -146.0), 20.0, 1.0],
	["EA03_Environment_Nature_Tree_1b", Vector2(111.0, -150.0), 140.0, 0.8],
	["EA03_Environment_Nature_Tree_1b", Vector2(64.0, -186.0), 250.0, 0.9],
	["EA03_Environment_Nature_Tree_1b", Vector2(113.0, -178.0), 310.0, 1.1],
	["EA_Nature_Tree_12d", Vector2(70.0, -132.0), 60.0, 1.0],
	["EA_Nature_Tree_12d", Vector2(104.0, -133.0), 200.0, 1.2],
	["EA_Nature_Tree_12d", Vector2(60.0, -170.0), 300.0, 1.0],
	["EA_Exterior_Lantern_Solid_01a", Vector2(66.5, -154.0), 90.0, 0.9],
	["EA_Exterior_Lantern_Solid_01a", Vector2(66.5, -162.0), 90.0, 0.9],
	["EA_Exterior_Lantern_Solid_01c", Vector2(58.0, -166.0), 0.0, 0.85],
	["EA_Environment_Nature_Root_2c", Vector2(62.0, -150.0), 30.0, 1.0],
	["EA_Environment_Nature_Root_2c", Vector2(109.0, -186.0), 200.0, 1.1],
	["EA_Nature_Tree_Root_1b", Vector2(68.0, -178.0), 80.0, 1.0],
	["EA_Swamp_Grass_Hill_Dead_01a", Vector2(63.0, -158.0), 0.0, 1.4],
	["EA_Swamp_Grass_Hill_Dead_01c", Vector2(61.0, -141.0), 70.0, 1.4],
	["EA_Swamp_Grass_Hill_Dead_01d", Vector2(110.0, -163.0), 10.0, 1.4],
	["EA_Swamp_Grass_Hill_Dead_01b", Vector2(98.0, -131.0), 120.0, 1.4],
	["EA_Swamp_Grass_Hill_Dead_01a", Vector2(66.0, -192.0), 200.0, 1.4],
	["EA03_Environment_Mud_02", Vector2(60.0, -160.0), 90.0, 1.0],
	["EA03_Environment_Mud_04", Vector2(84.0, -194.0), 0.0, 1.0],
	["EA_Swamp_Stones_02a", Vector2(72.0, -140.0), 40.0, 1.3],
	["EA_Swamp_Stones_04c", Vector2(112.0, -142.0), 0.0, 1.2],
	["EA_Arch_Wall04_Ruin_01b", Vector2(62.0, -176.0), 75.0, 1.6],
	["EA_Arch_Wall04_Ruin_01b", Vector2(115.0, -168.0), 100.0, 1.6],
]
## The walled yard's wall (02c): its stone is low and the iron above it too
## thin to collide as it is drawn, so the wall is a run of boxes round the
## yard (x0, z0, x1, z1), broken at the gate. Across the gate nothing of the
## kit collides (`GATE_CLEAR`, x0, z0, x1, z1): the gravestone it has just
## inside would leave a man a gap of one metre.
const YARD_WALL: Array[Vector4] = [
	Vector4(69.3, -170.1, 106.7, -170.1),
	Vector4(69.3, -145.9, 106.7, -145.9),
	Vector4(106.7, -170.1, 106.7, -145.9),
	Vector4(69.3, -170.1, 69.3, -159.6),
	Vector4(69.3, -154.4, 69.3, -145.9),
]
const GATE_CLEAR := Vector4(67.0, -159.6, 77.5, -154.4)
const WALL_HEIGHT := 1.5
## Lamp posts get a light; these are the ones near the gate.
const LIT := [7, 8, 9]
## The gate, where the sound of the place is loudest, and the middle of it.
const GRAVE_MIDDLE := Vector3(88.0, 0.0, -160.0)

## Arkdeva's lairs (as in [constant World.CAMPS]).
const LAIRS: Array[Vector2] = [Vector2(-104.0, -118.0), Vector2(-80.0, -216.0)]
## Every tree this near a lair is dead; out to `DEAD_REACH` fewer and fewer.
const DEAD_CORE := 28.0
const DEAD_REACH := 46.0
## Of the wood's groups, which hold trees (swapped) and bushes (some put out).
const TREE_GROUPS: PackedStringArray = ["Canopy"]
const BUSH_GROUPS: PackedStringArray = ["Undergrowth"]
## The dead trees, and how big (times `KIT_SCALE`).
const DEAD_TREES: Array[Array] = [
	["EA03_Environment_Nature_Tree_1b", 0.55, 0.95],
	["EA03_Environment_Nature_Tree_1b", 0.55, 0.95],
	["EA_Nature_Tree_12d", 0.9, 1.4],
]
## Strewn on the dead wood's floor round each lair: model, how many.
const DEAD_FLOOR: Array[Array] = [
	["EA_Swamp_Grass_Hill_Dead_01a", 7], ["EA_Swamp_Grass_Hill_Dead_01c", 6],
	["EA_Swamp_Grass_Hill_Dead_01d", 5], ["EA_Environment_Nature_Root_2c", 4],
	["EA_Nature_Tree_Root_1b", 4], ["EA_Swamp_Root_03c", 4], ["EA_Swamp_Stones_02a", 4],
]

const PROPS_PATH := "res://assets/necropoly/necro_props.glb"
const CHUNK_PATH := "res://assets/necropoly/necropoly_chunk_%s.glb"
const PALETTE := "res://assets/necropoly/necro_palette.png"
const SOUND := "res://sounds/ambience/graveyard_loop.ogg"
## And the living wood's birds, so the dead wood is heard going quiet.
const BIRDS := "res://sounds/ambience/forest_birds_loop.ogg"
const BIRDS_AT: Array[Vector3] = [Vector3(-72.0, 3.0, 40.0), Vector3(-66.0, 3.0, -50.0)]

## Whether the level starts in our colours (true) or the kit's own.
@export var ours_at_start: bool = false
@export var build_graveyard: bool = true
@export var build_dead_wood: bool = true

var ours: bool = false
var material: ShaderMaterial
var glow: StandardMaterial3D
## Model name -> mesh, out of the props glb.
var _meshes: Dictionary = {}
## How many of the wood's trees were swapped for dead ones.
var swapped: int = 0
var _label: Label
var _label_left: float = 0.0


## Whether the grass ([Meadows]) should keep off this point: the graveyard's
## own ground is the kit's.
static func blocks(at: Vector2) -> bool:
	for r in GRAVE_GROUND:
		if r.has_point(at):
			return true
	return false


func _ready() -> void:
	name = "NecroPlaces"
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/necro.gdshader")
	material.set_shader_parameter(&"palette", load(PALETTE))
	glow = StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.62, 0.25)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.55, 0.2)
	glow.emission_energy_multiplier = 3.0
	_load_props()
	if build_graveyard:
		_build_graveyard()
	if build_dead_wood:
		_build_dead_wood()
	for at in BIRDS_AT:
		add_child(_sound(at, -12.0, 16.0, 80.0, BIRDS))
	set_ours(ours_at_start)
	set_process(false)


func set_ours(on: bool) -> void:
	ours = on
	material.set_shader_parameter(&"ours", 1.0 if on else 0.0)


#region Meshes
func _load_props() -> void:
	var scene := load(PROPS_PATH) as PackedScene
	if scene == null:
		push_warning("NecroPlaces: %s is missing" % PROPS_PATH)
		return
	var root := scene.instantiate()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		_meshes[String(mi.name)] = _dressed(mi.mesh)
	root.free()


## The mesh with our two materials on it: the glow for what the kit made
## emissive (lamps, candles), the palette for the rest.
func _dressed(mesh: Mesh) -> Mesh:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		return mesh
	var copy := array_mesh.duplicate() as ArrayMesh
	for s in copy.get_surface_count():
		var m := copy.surface_get_material(s)
		var lit := m != null and m.resource_name.contains("glow")
		copy.surface_set_material(s, glow if lit else material)
	return copy


func _place(mesh: Mesh, at: Vector3, yaw: float, size: float, shadows: bool = true,
		parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * size * KIT_SCALE), at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(mi)
	return mi


func _ground(x: float, z: float, r: float = 0.5) -> float:
	return Terrain.height_under(x, z, r)
#endregion


#region The graveyard
func _build_graveyard() -> void:
	var yard := Node3D.new()
	yard.name = "Graveyard"
	add_child(yard)
	var body := StaticBody3D.new()
	body.name = "GraveyardBody"
	yard.add_child(body)
	for piece: Array in GRAVEYARD:
		var scene := load(CHUNK_PATH % piece[0]) as PackedScene
		if scene == null:
			continue
		var at: Vector2 = piece[1]
		var chunk := scene.instantiate() as Node3D
		chunk.name = "Chunk_%s" % piece[0]
		chunk.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(piece[2]))).scaled(Vector3.ONE * KIT_SCALE),
				Vector3(at.x, _ground(at.x, at.y, 6.0) - float(piece[3]), at.y))
		yard.add_child(chunk)
		for node in chunk.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			mi.mesh = _dressed(mi.mesh)
			mi.lod_bias = 0.6
			mi.visibility_range_end = 220.0
			_collide(body, mi)
	for w in YARD_WALL:
		var a := Vector2(w.x, w.y)
		var b := Vector2(w.z, w.w)
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, WALL_HEIGHT, a.distance_to(b) + 0.4)
		var wall := CollisionShape3D.new()
		wall.shape = box
		var mid := (a + b) * 0.5
		wall.position = Vector3(mid.x, _ground(mid.x, mid.y) + WALL_HEIGHT * 0.5, mid.y)
		wall.rotation.y = atan2(b.x - a.x, b.y - a.y)
		body.add_child(wall)
	for i in GRAVE_PROPS.size():
		var p: Array = GRAVE_PROPS[i]
		var mesh: Mesh = _meshes.get(p[0])
		if mesh == null:
			continue
		var at: Vector2 = p[1]
		var mi := _place(mesh, Vector3(at.x, _ground(at.x, at.y), at.y), p[2], p[3],
				not String(p[0]).contains("Grass"), yard)
		mi.visibility_range_end = 200.0
		if String(p[0]).contains("Tree") and not String(p[0]).contains("Root"):
			_trunk(body, mi.position, 0.45 * float(p[3]))
		if String(p[0]).contains("Lantern"):
			_trunk(body, mi.position, 0.25)
		if i in LIT:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.66, 0.35)
			lamp.light_energy = 1.6
			lamp.omni_range = 9.0
			lamp.distance_fade_enabled = true
			lamp.distance_fade_begin = 60.0
			lamp.position = mi.position + Vector3(0.0, 3.6 * float(p[3]), 0.0)
			yard.add_child(lamp)
	add_child(_mist(GRAVE_MIDDLE + Vector3(0, _ground(GRAVE_MIDDLE.x, GRAVE_MIDDLE.z), 0), Vector3(30, 1, 34),
			Color(0.62, 0.66, 0.64, 0.10), 26))
	add_child(_sound(GRAVE_MIDDLE + Vector3(0, 1.5, 0), -6.0, 14.0, 75.0))


## Walls, tombs and posts collide; floors, grass and the small things on them
## do not (the ground under them is the terrain's): every triangle big enough
## to matter that stands up out of the floor.
func _collide(body: StaticBody3D, mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var faces := mi.mesh.get_faces()
	var xf := mi.global_transform if mi.is_inside_tree() else mi.transform
	var base := Terrain.height(xf.origin.x, xf.origin.z)
	var keep := PackedVector3Array()
	for t in range(0, faces.size(), 3):
		var a := xf * faces[t]
		var b := xf * faces[t + 1]
		var c := xf * faces[t + 2]
		var top := maxf(a.y, maxf(b.y, c.y))
		if top < base + 0.45:
			continue
		var mid := (a + b + c) / 3.0
		if mid.x > GATE_CLEAR.x and mid.x < GATE_CLEAR.z and mid.z > GATE_CLEAR.y and mid.z < GATE_CLEAR.w \
				and mid.y < base + 3.0:
			continue
		var n := (b - a).cross(c - a)
		if n.length() < 0.06:
			continue
		keep.append(a)
		keep.append(b)
		keep.append(c)
	if keep.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(keep)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)


func _trunk(body: StaticBody3D, at: Vector3, radius: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 4.0
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = at + Vector3(0.0, 2.0, 0.0)
	body.add_child(col)
#endregion


#region The dead wood
func _build_dead_wood() -> void:
	var forest := get_parent().get_node_or_null("Forest") as Forest
	var wood := Node3D.new()
	wood.name = "DeadWood"
	add_child(wood)
	var placed: Dictionary = {}  # model index -> Array[Transform3D]
	if forest != null:
		for group in forest.get_children():
			var trees := _is_group(group.name, TREE_GROUPS)
			var bushes := _is_group(group.name, BUSH_GROUPS)
			if not trees and not bushes:
				continue
			for node in group.find_children("*", "MultiMeshInstance3D", true, false):
				_swap(node as MultiMeshInstance3D, trees, placed)
	for k: int in placed:
		var list: Array = placed[k]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _meshes.get(DEAD_TREES[k][0])
		if multi.mesh == null:
			continue
		multi.instance_count = list.size()
		for i in list.size():
			multi.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Dead_%d" % k
		mmi.multimesh = multi
		mmi.visibility_range_end = 260.0
		wood.add_child(mmi)
	for li in LAIRS.size():
		var lair: Vector2 = LAIRS[li]
		_strew(wood, lair, li)
		var y := _ground(lair.x, lair.y)
		wood.add_child(_mist(Vector3(lair.x, y, lair.y), Vector3(DEAD_REACH * 1.4, 1, DEAD_REACH * 1.4),
				Color(0.5, 0.56, 0.5, 0.12), 30))
		wood.add_child(_sound(Vector3(lair.x, y + 1.5, lair.y), -9.0, 12.0, 60.0))


func _is_group(group_name: String, prefixes: PackedStringArray) -> bool:
	for p in prefixes:
		if group_name.begins_with(p):
			return true
	return false


## How likely a tree at this point is to be dead: 1 in the core, easing to 0
## at the reach, broken up a little so the edge is not a circle.
static func dead_chance(at: Vector2) -> float:
	var best := 0.0
	for lair in LAIRS:
		var d := at.distance_to(lair)
		if d >= DEAD_REACH:
			continue
		best = maxf(best, 1.0 - smoothstep(DEAD_CORE, DEAD_REACH, d))
	return best


static func _hash(at: Vector2) -> float:
	return fposmod(sin(at.x * 12.9898 + at.y * 78.233) * 43758.5453, 1.0)


func _swap(mmi: MultiMeshInstance3D, trees: bool, placed: Dictionary) -> void:
	var multi := mmi.multimesh
	if multi == null:
		return
	var xf := mmi.global_transform if mmi.is_inside_tree() else mmi.transform
	var touched := false
	for i in multi.instance_count:
		var t := multi.get_instance_transform(i)
		var at := xf * t.origin
		var p := Vector2(at.x, at.z)
		var chance := dead_chance(p)
		if chance <= 0.0 or _hash(p) >= chance:
			continue
		if not trees and _hash(p * 1.7) > 0.7:
			continue
		multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), t.origin))
		touched = true
		if not trees:
			continue
		swapped += 1
		var k := int(_hash(p * 3.1) * DEAD_TREES.size()) % DEAD_TREES.size()
		var lo: float = DEAD_TREES[k][1]
		var hi: float = DEAD_TREES[k][2]
		var size := lerpf(lo, hi, _hash(p * 5.3)) * KIT_SCALE
		var basis := Basis(Vector3.UP, TAU * _hash(p * 7.7)).scaled(Vector3.ONE * size)
		var list: Array = placed.get(k, [])
		list.append(Transform3D(basis, Vector3(at.x, _ground(at.x, at.z, 0.4) - 0.1, at.z)))
		placed[k] = list
	if touched:
		# the hidden ones still count in the AABB; the box is unchanged
		mmi.multimesh = multi


func _strew(wood: Node3D, lair: Vector2, seed_offset: int) -> void:
	var n := 0
	for entry: Array in DEAD_FLOOR:
		var mesh: Mesh = _meshes.get(entry[0])
		if mesh == null:
			continue
		for j in int(entry[1]):
			n += 1
			var key := Vector2(float(n) * 1.37 + float(seed_offset) * 17.0, float(j) * 2.11 + lair.x * 0.01)
			var ang := TAU * _hash(key)
			var r := 6.0 + (DEAD_REACH - 8.0) * sqrt(_hash(key * 1.9))
			var x := lair.x + cos(ang) * r
			var z := lair.y + sin(ang) * r
			var mi := _place(mesh, Vector3(x, _ground(x, z), z), rad_to_deg(TAU * _hash(key * 2.7)),
					1.1 + 0.6 * _hash(key * 3.3), false, wood)
			mi.visibility_range_end = 120.0
#endregion


#region Air and sound
## Low drifting mist: a few big soft sheets turned to the camera.
func _mist(at: Vector3, box: Vector3, colour: Color, count: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Mist"
	p.position = at + Vector3(0.0, 0.9, 0.0)
	p.amount = count
	p.lifetime = 24.0
	p.preprocess = 24.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box * 0.5
	p.direction = Vector3(1, 0, 0.3)
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.add_point(0.75, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(11.0, 3.2)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = colour
	m.albedo_texture = _soft()
	m.disable_receive_shadows = true
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.5
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 2.0
	m.distance_fade_max_distance = 8.0
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 140.0
	return p


static var _soft_tex: Texture2D


static func _soft() -> Texture2D:
	if _soft_tex != null:
		return _soft_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 64
	_soft_tex = t
	return t


func _sound(at: Vector3, volume_db: float, unit: float, reach: float, path: String = SOUND) -> AudioStreamPlayer3D:
	var s := AudioStreamPlayer3D.new()
	s.name = "Air"
	var stream := load(path) as AudioStreamOggVorbis
	if stream != null:
		stream = stream.duplicate() as AudioStreamOggVorbis
		stream.loop = true
	s.stream = stream
	s.position = at
	s.volume_db = volume_db
	s.unit_size = unit
	s.max_distance = reach
	s.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	s.autoplay = stream != null
	return s
#endregion


#region F9
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F9 or key.shift_pressed:
		return
	set_ours(not ours)
	_say()


func _say() -> void:
	if _label == null:
		var layer := CanvasLayer.new()
		layer.layer = 50
		add_child(layer)
		_label = Label.new()
		_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_label.position.y = 60.0
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", 6)
		layer.add_child(_label)
	_label.text = "NecroPOLY: ჩვენი ფერები (F9)" if ours else "NecroPOLY: პაკეტის ფერები (F9)"
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.visible = true
	_label_left = 2.5
	set_process(true)


func _process(delta: float) -> void:
	if _label == null or not _label.visible:
		set_process(false)
		return
	_label_left -= delta
	if _label_left <= 0.0:
		_label.visible = false
		set_process(false)
#endregion
