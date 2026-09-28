class_name LandsPlaces
extends Node3D

## What stands in the lands round the core ([Lands]), put up at load from the
## map's own lists: the ways over the water, the villages, the camps and the
## boss arenas, the waymarks at the gates, and the landmarks each land is
## remembered by.
##
## Built out of the kit and out of boxes, as the greybox core was: the ruins,
## the idols, the giant trees and the rest are stand-ins that sit where the map
## put them and are the size it asked for, until each has its own model (the
## list is in vepxis-art/NOTES.md). What has to *work* works now: the bridges
## carry a body over (the deep water under them is let through, see
## [member Lands.crossings]), the stepping stones are stood on, the villages'
## houses and the palisades are solid.
##
## The city of Gulansharo on the bay's north shore is put up here as well (it
## stands in the core, but it is the map's): its wall and towers, its gates —
## the land gate shut until the orcs in the mist village are dead — its streets
## and market, twelve named houses each with its sign, the moles and the
## lighthouse, the ships.
##
## The fires a hero travels between are [Waystones]; the lands' look per land
## is [LandsMood].

const KIT := "res://unverified/assets/area/HighLandsFantasyBuildings/"
const HUT := KIT + "Hut/SM_Hut.fbx"
const BARRACKS := KIT + "Barracks/SM_Barracks.fbx"
const TOWN_CENTRE := KIT + "TownCenter/SM_TownCenter.fbx"
const WATCHTOWER := KIT + "WatchTower/SM_WatchTower.fbx"
const WINDMILL := KIT + "Windmill/SM_Windmill.fbx"
const WALL_TOWER := KIT + "Walls/Tower/SM_Tower.fbx"
const WALL := KIT + "Walls/WallMid/SM_WallMid.fbx"
const FENCE := KIT + "MiscProps/SM_WoodFence.fbx"
const BARREL := KIT + "MiscProps/SM_Barrel.fbx"
const CRATE := KIT + "MiscProps/SM_WoodCrate.fbx"
const RUIN_TOWER := "res://unverified/assets/tower/tower1.glb"
const F := "res://assets/forest/"
const FIRE := F + "Campfire_Star.obj"
const FIRE_TEEPEE := F + "Campfire_Teepee.obj"
const TENTS: PackedStringArray = [F + "Tent_Leanto_1.obj", F + "Tent_Leanto_2.obj"]
const ROCKS: PackedStringArray = [F + "Rock_1.obj", F + "Rock_3.obj", F + "Rock_5.obj", F + "Rock_7.obj", F + "Rock_9.obj"]
const STEPS: PackedStringArray = [F + "Stepping_Stone_1.obj", F + "Stepping_Stone_2.obj", F + "Stepping_Stone_3.obj", F + "Stepping_Stone_4.obj"]
const LOGS: PackedStringArray = [F + "Log_1.obj", F + "Log_3.obj", F + "Log_5.obj"]
const TIMBER: PackedStringArray = [F + "Timber_Stack_1.obj", F + "Timber_Stack_2.obj"]
const MUSHROOMS: PackedStringArray = [F + "Mushroom_Red_Spotted.obj", F + "Mushroom_Brown.obj", F + "Mushroom_Dark_Red.obj"]
const BUSHES: PackedStringArray = [F + "Bush_2.obj", F + "Bush_4.obj", F + "Grass_Clump_3.obj"]

## Kit buildings are drawn at this scale in the core village.
const KIT_SCALE := 1.6

var _lands: Lands
var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()
## The colliders, on one body per [constant SOLID_CELL] square (a single body
## over the whole map is looked at in full by every query that touches it; see
## Forest._add_trunk).
var _bodies: Node3D
var _cells: Dictionary = {}
const SOLID_CELL := 32.0
var counts: Dictionary = {}


func _ready() -> void:
	_lands = Lands.current
	if _lands == null or not is_instance_valid(_lands) or _lands.info.is_empty():
		return
	var started := Time.get_ticks_usec()
	_rng.seed = 90411
	_bodies = Node3D.new()
	_bodies.name = "Solid"
	add_child(_bodies)
	_build_crossings()
	_build_settlements()
	_build_camps()
	_build_gates()
	_build_landmarks()
	_build_city()
	print("LandsPlaces: %s, in %.1f ms" % [counts, (Time.get_ticks_usec() - started) / 1000.0])


#region Helpers
## Adds a collider at `at` (the level's frame) to the body of its square.
func _add_shape(shape: Shape3D, at: Transform3D) -> void:
	var cell := Vector2i(floori(at.origin.x / SOLID_CELL), floori(at.origin.z / SOLID_CELL))
	var body: StaticBody3D = _cells.get(cell)
	if body == null:
		body = StaticBody3D.new()
		body.name = "Solid_%d_%d" % [cell.x, cell.y]
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3((cell.x + 0.5) * SOLID_CELL, 0.0, (cell.y + 0.5) * SOLID_CELL)
		_bodies.add_child(body)
		_cells[cell] = body
	var owner_id := body.create_shape_owner(self)
	body.shape_owner_add_shape(owner_id, shape)
	at.origin -= body.position
	body.shape_owner_set_transform(owner_id, at)

func _ground(x: float, z: float) -> float:
	return Terrain.height(x, z)


func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var c := Color(0.5, 0.5, 0.5)
	var rough := 0.9
	match key:
		"wood":
			c = Color(0.42, 0.3, 0.19)
		"wood_dark":
			c = Color(0.26, 0.18, 0.12)
		"plank":
			c = Color(0.52, 0.39, 0.25)
		"rope":
			c = Color(0.62, 0.52, 0.34)
		"stone":
			c = Color(0.52, 0.5, 0.46)
		"stone_dark":
			c = Color(0.34, 0.33, 0.31)
		"moss_stone":
			c = Color(0.36, 0.42, 0.3)
		"earth":
			c = Color(0.36, 0.4, 0.22)
		"burnt":
			c = Color(0.12, 0.1, 0.09)
		"bone":
			c = Color(0.86, 0.82, 0.72)
		"ice":
			c = Color(0.82, 0.92, 0.98)
			rough = 0.25
		"cave":
			c = Color(0.02, 0.02, 0.02)
		"hay":
			c = Color(0.78, 0.64, 0.3)
		"cloth":
			c = Color(0.6, 0.18, 0.12)
		"glow":
			c = Color(0.55, 0.95, 0.75)
			m.emission_enabled = true
			m.emission = Color(0.4, 1.0, 0.7)
			m.emission_energy_multiplier = 2.5
		"light":
			c = Color(1.0, 0.92, 0.7, 0.12)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	m.roughness = rough
	if key in ["stone", "stone_dark", "moss_stone"]:
		var tex := load("res://assets/terrain_real/aerial_rocks_02_diff.jpg") as Texture2D
		if tex != null:
			m.albedo_texture = tex
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * 0.35
	_mats[key] = m
	return m


## A box from `from` to `to` (its top face on the line), `width` across and
## `thick` deep; solid unless told otherwise.
func _beam(from: Vector3, to: Vector3, width: float, thick: float, mat: String, solid: bool = true) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.01:
		return
	var basis := Basis.looking_at(d / length, Vector3.UP)
	var centre := (from + to) * 0.5 - basis.y * thick * 0.5
	_box(Vector3(width, thick, length), Transform3D(basis, centre), mat, solid)


func _box(size: Vector3, at: Transform3D, mat: String, solid: bool = true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = at
	mi.material_override = _mat(mat)
	add_child(mi)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_shape(shape, at)


func _cylinder(radius: float, height: float, at: Vector3, mat: String, solid: bool = true, top: float = -1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at + Vector3(0.0, height * 0.5, 0.0)
	mi.material_override = _mat(mat)
	add_child(mi)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_add_shape(shape, Transform3D(Basis.IDENTITY, mi.position))


## A collider with nothing drawn: a cylinder `radius` round, `height` tall.
func _solid(at: Transform3D, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_add_shape(shape, at)


## A model from the kit's .obj set, where it stands, turned and sized; a
## cylinder round its foot if it is `solid`.
func _prop(path: String, at: Vector3, turn: float, size: float, solid: bool = false, radius: float = 0.0, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := load(path) as Mesh if ResourceLoader.exists(path) else null
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, turn).scaled(stretch * size), at)
	add_child(mi)
	if solid:
		var r := radius if radius > 0.0 else maxf(mesh.get_aabb().size.x, mesh.get_aabb().size.z) * 0.4 * size * stretch.x
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = maxf(mesh.get_aabb().size.y * size * stretch.y, 1.0)
		_add_shape(shape, Transform3D(Basis.IDENTITY, at + Vector3(0.0, shape.height * 0.5, 0.0)))
	return mi


## A kit building (an .fbx under a [Building], so it wears its textures and
## collides by its own hull).
func _building(path: String, at: Vector3, turn: float, size: float = KIT_SCALE, tint: Color = Color.WHITE) -> Node3D:
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene == null:
		return null
	# the kit's .fbx wants its textures found and its hull made a collider; a
	# .glb brings its own textures, and gets a collider from whoever puts it up
	var holder: Node3D = Building.new() if path.ends_with(".fbx") else Node3D.new()
	holder.transform = Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), at)
	var model := scene.instantiate()
	holder.add_child(model)
	add_child(holder)
	if tint != Color.WHITE:
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.roughness = 1.0
		for mi in holder.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = m
	return holder


## A ring of standing stones.
func _ring_of_stones(centre: Vector3, radius: float, count: int, tall: Vector2, mat: String = "stone", solid: bool = true) -> void:
	for i in count:
		var a := TAU * float(i) / count + _rng.randf_range(-0.08, 0.08)
		var p := Vector2(centre.x + cos(a) * radius, centre.z + sin(a) * radius)
		var h := _rng.randf_range(tall.x, tall.y)
		var w := _rng.randf_range(0.8, 1.3)
		var y := _ground(p.x, p.y) - 0.4
		var basis := Basis(Vector3.UP, a + _rng.randf_range(-0.3, 0.3)) * Basis(Vector3.FORWARD, _rng.randf_range(-0.08, 0.08))
		_box(Vector3(w, h, w * 0.6), Transform3D(basis, Vector3(p.x, y + h * 0.5, p.y)), mat, solid)


func _campfire(at: Vector3, lit: bool = true) -> void:
	_prop(FIRE, at, _rng.randf() * TAU, 1.4)
	for i in 8:
		var a := TAU * i / 8.0
		_prop(ROCKS[i % ROCKS.size()], at + Vector3(cos(a) * 1.3, -0.1, sin(a) * 1.3), _rng.randf() * TAU, 0.35)
	if lit:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.3)
		light.light_energy = 2.2
		light.omni_range = 9.0
		light.position = at + Vector3(0.0, 1.0, 0.0)
		light.shadow_enabled = false
		add_child(light)
		var flames := CPUParticles3D.new()
		flames.amount = 18
		flames.lifetime = 0.8
		flames.position = at + Vector3(0.0, 0.3, 0.0)
		flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		flames.emission_sphere_radius = 0.35
		flames.direction = Vector3.UP
		flames.spread = 12.0
		flames.initial_velocity_min = 0.8
		flames.initial_velocity_max = 1.6
		flames.gravity = Vector3(0.0, 0.6, 0.0)
		flames.scale_amount_min = 0.25
		flames.scale_amount_max = 0.5
		var quad := QuadMesh.new()
		quad.size = Vector2(0.5, 0.7)
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		fm.billboard_keep_scale = true
		fm.albedo_color = Color(1.0, 0.55, 0.2)
		fm.vertex_color_use_as_albedo = true
		quad.material = fm
		flames.mesh = quad
		var fade := Gradient.new()
		fade.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
		fade.set_color(1, Color(0.8, 0.2, 0.05, 0.0))
		flames.color_ramp = fade
		add_child(flames)
#endregion


#region Crossings
func _build_crossings() -> void:
	var n := 0
	for c: Dictionary in _lands.crossings:
		var a: Vector3 = c["a"]
		var b: Vector3 = c["b"]
		var mid: Vector3 = c["mid"]
		match String(c["kind"]):
			"plank_bridge", "jetty":
				_wooden_bridge(a, mid, b, 2.8, "plank", true)
			"log_bridge":
				_log_bridge(a, mid, b)
			"arched_stone_bridge":
				_stone_bridge(a, mid, b)
			"rope_bridge":
				_rope_bridge(a, mid, b)
			"stepping_stones", "ford":
				_stepping(a, b, float(c["water"]), String(c["kind"]) == "ford")
		n += 1
	counts["crossings"] = n


func _wooden_bridge(a: Vector3, mid: Vector3, b: Vector3, width: float, mat: String, rails: bool) -> void:
	_beam(a, mid, width, 0.25, mat)
	_beam(mid, b, width, 0.25, mat)
	var along := (b - a)
	along.y = 0.0
	var side := Vector3(-along.z, 0.0, along.x).normalized() * (width * 0.5 - 0.1)
	# stringers under the planks, and posts down to the bed
	for s: float in [-1.0, 1.0]:
		_beam(a + side * s - Vector3(0, 0.25, 0), mid + side * s - Vector3(0, 0.25, 0), 0.22, 0.3, "wood_dark", false)
		_beam(mid + side * s - Vector3(0, 0.25, 0), b + side * s - Vector3(0, 0.25, 0), 0.22, 0.3, "wood_dark", false)
	var length := a.distance_to(b)
	var posts := maxi(2, int(length / 2.5))
	for i in posts + 1:
		var t := float(i) / posts
		var p := a.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(b, (t - 0.5) * 2.0)
		for s: float in [-1.0, 1.0]:
			var q := p + side * s
			if rails:
				_box(Vector3(0.14, 1.1, 0.14), Transform3D(Basis.IDENTITY, q + Vector3(0, 0.55, 0)), "wood_dark", true)
			if i > 0 and i < posts:
				var bed := minf(_ground(q.x, q.z), q.y - 0.3)
				_box(Vector3(0.2, q.y - bed + 0.3, 0.2), Transform3D(Basis.IDENTITY, Vector3(q.x, (q.y + bed) * 0.5 - 0.2, q.z)), "wood_dark", false)
	if rails:
		for s: float in [-1.0, 1.0]:
			_beam(a + side * s + Vector3(0, 1.1, 0), mid + side * s + Vector3(0, 1.1, 0), 0.1, 0.1, "wood", false)
			_beam(mid + side * s + Vector3(0, 1.1, 0), b + side * s + Vector3(0, 1.1, 0), 0.1, 0.1, "wood", false)


func _log_bridge(a: Vector3, mid: Vector3, b: Vector3) -> void:
	# two great trunks side by side, a flattened walk on them
	var along := b - a
	along.y = 0.0
	var side := Vector3(-along.z, 0.0, along.x).normalized()
	for s: float in [-0.45, 0.45]:
		for pair: Array in [[a, mid], [mid, b]]:
			var p0: Vector3 = pair[0]
			var p1: Vector3 = pair[1]
			var d := p1 - p0
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.45
			mesh.bottom_radius = 0.5
			mesh.height = d.length() + 0.6
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var basis := Basis.looking_at(d.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			mi.transform = Transform3D(basis, (p0 + p1) * 0.5 + side * s - Vector3(0, 0.4, 0))
			mi.material_override = _mat("wood")
			add_child(mi)
	_beam(a, mid, 1.9, 0.1, "wood", true)
	_beam(mid, b, 1.9, 0.1, "wood", true)


func _stone_bridge(a: Vector3, mid: Vector3, b: Vector3) -> void:
	var top := maxf(mid.y, maxf(a.y, b.y) + 0.3)
	var m := Vector3(mid.x, top, mid.z)
	_beam(a, m, 3.6, 0.6, "stone")
	_beam(m, b, 3.6, 0.6, "stone")
	var along := b - a
	along.y = 0.0
	var side := Vector3(-along.z, 0.0, along.x).normalized() * 1.65
	for s: float in [-1.0, 1.0]:
		_beam(a + side * s + Vector3(0, 0.6, 0), m + side * s + Vector3(0, 0.6, 0), 0.35, 0.65, "stone")
		_beam(m + side * s + Vector3(0, 0.6, 0), b + side * s + Vector3(0, 0.6, 0), 0.35, 0.65, "stone")
	# the arch's spandrels: a thick body under the middle, the water under it
	var under := Vector3(mid.x, top - 0.6, mid.z)
	var bed := _ground(mid.x, mid.z)
	var span := a.distance_to(b)
	_beam(a.lerp(under, 0.35) - Vector3(0, 0.6, 0), b.lerp(under, 0.35) - Vector3(0, 0.6, 0), 3.4, 0.9, "stone_dark", false)
	for t: float in [0.18, 0.82]:
		var p := a.lerp(b, t)
		_box(Vector3(3.2, maxf(top - bed, 1.0), minf(2.2, span * 0.12)),
				Transform3D(Basis.looking_at(along.normalized(), Vector3.UP), Vector3(p.x, (top + bed) * 0.5 - 0.6, p.z)), "stone_dark", false)


func _rope_bridge(a: Vector3, mid: Vector3, b: Vector3) -> void:
	# planks on ropes, bank to the middle over the water and on to the far bank,
	# sagging a little on each run; posts at both ends
	var along := b - a
	along.y = 0.0
	var side := Vector3(-along.z, 0.0, along.x).normalized()
	for run: Array in [[a, mid], [mid, b]]:
		var p0: Vector3 = run[0]
		var p1: Vector3 = run[1]
		var length := p0.distance_to(p1)
		var steps := maxi(3, int(length / 1.2))
		var sag := minf(length * 0.03, 0.4)
		var prev := p0
		for i in range(1, steps + 1):
			var t := float(i) / steps
			var p := p0.lerp(p1, t) - Vector3(0, sin(t * PI) * sag, 0)
			_beam(prev, p, 1.7, 0.12, "plank", true)
			for s: float in [-1.0, 1.0]:
				_beam(prev + side * s * 0.95 + Vector3(0, 1.0, 0), p + side * s * 0.95 + Vector3(0, 1.0, 0), 0.05, 0.05, "rope", false)
			prev = p
	for end: Vector3 in [a, b]:
		for s: float in [-1.0, 1.0]:
			_cylinder(0.14, 1.9, end + side * s * 1.0 - Vector3(0, 0.3, 0), "wood_dark", true)


func _stepping(a: Vector3, b: Vector3, water: float, ford: bool) -> void:
	var length := a.distance_to(b)
	var gap := 1.35 if not ford else 1.9
	var n := maxi(2, int(length / gap))
	for i in range(0, n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t)
		var bed := _ground(p.x, p.z)
		if water > -INF and bed > water + 0.25:
			continue
		var top := water + 0.18 if water > -INF else bed + 0.2
		var jitter := Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.25, 0.25))
		var path := STEPS[i % STEPS.size()]
		_prop(path, Vector3(p.x, top - 0.35, p.z) + jitter, _rng.randf() * TAU, 1.3)
		if ford:
			continue  # a ford is waded: its stones are there to be seen
		var shape := CylinderShape3D.new()
		shape.radius = 0.55
		shape.height = maxf(top - bed + 0.5, 0.6)
		_add_shape(shape, Transform3D(Basis.IDENTITY, Vector3(p.x, top - shape.height * 0.5, p.z) + jitter))
#endregion


#region Settlements
func _build_settlements() -> void:
	var n := 0
	for st: Dictionary in _lands.info.get("settlements", []):
		if String(st.get("region", "core")) == "core":
			continue  # the spawn's village, the mist village and the city are the core's own
		var c := Vector2(float(st["x"]), float(st["z"]))
		var r := float(st["radius"])
		var houses := int(st.get("houses", 5))
		var style := String(st.get("style", "farm"))
		var y := _ground(c.x, c.y)
		# a well-trodden square: a fire, barrels and crates by it
		_campfire(Vector3(c.x, y, c.y))
		_building(BARREL, Vector3(c.x + 2.8, y, c.y + 1.2), 0.3)
		_building(CRATE, Vector3(c.x - 2.6, y, c.y + 2.0), 1.1)
		# the houses round it, facing in
		for i in houses:
			var a := TAU * (float(i) + 0.5) / houses + _rng.randf_range(-0.12, 0.12)
			var d := r * _rng.randf_range(0.45, 0.62)
			var p := c + Vector2(cos(a), sin(a)) * d
			var face := atan2(c.x - p.x, c.y - p.y)
			var path := HUT
			match style:
				"stone":
					path = HUT if i % 3 else WATCHTOWER
				"towers":
					path = WALL_TOWER if i % 2 == 0 else HUT
				"wood":
					path = HUT
				"farm":
					path = HUT if i % 4 else BARRACKS
			_building(path, Vector3(p.x, _ground(p.x, p.y) - 0.05, p.y), face)
		if style == "farm":
			var p := c + Vector2(r * 0.8, 0.0).rotated(0.7)
			_building(WINDMILL, Vector3(p.x, _ground(p.x, p.y), p.y), 0.4)
		# fence round it, gapped where the road comes in
		_fence_ring(c, r * 0.92, style)
		n += 1
	counts["settlements"] = n


func _fence_ring(c: Vector2, r: float, style: String) -> void:
	var step := 5.2
	var count := int(TAU * r / step)
	for i in count:
		# a few gaps for the ways in
		if i % 11 == 0 or i % 11 == 1:
			continue
		var a := TAU * i / count
		var p := c + Vector2(cos(a), sin(a)) * r
		var y := _ground(p.x, p.y)
		if Lands.water(p.x, p.y) > -INF:
			continue
		if style == "towers" or style == "stone":
			_box(Vector3(step, 1.3, 0.6), Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(p.x, y + 0.5, p.y)), "stone", true)
		else:
			_building(FENCE, Vector3(p.x, y, p.y), -a, 1.9)
#endregion


#region Camps, rests, arenas
func _build_camps() -> void:
	var regions: Dictionary = _lands.info.get("regions", {})
	var camps := 0
	for key: String in regions:
		var region: Dictionary = regions[key]
		for camp: Dictionary in region.get("camps", []):
			var c := Vector2(float(camp["x"]), float(camp["z"]))
			var y := _ground(c.x, c.y)
			var who := String(camp.get("who", ""))
			if who.contains("ორკ"):
				_palisade(c, 13.0)
			_campfire(Vector3(c.x, y, c.y))
			var tents := clampi(int(float(camp.get("count", 3)) / 2.0), 1, 3)
			for i in tents:
				var a := TAU * i / tents + 0.6
				var p := c + Vector2(cos(a), sin(a)) * 5.0
				_prop(TENTS[i % TENTS.size()], Vector3(p.x, _ground(p.x, p.y), p.y), -a + PI * 0.5, 1.6, true, 1.3)
			for i in 3:
				var a := TAU * i / 3.0 + 1.9
				var p := c + Vector2(cos(a), sin(a)) * 2.6
				_prop(LOGS[i % LOGS.size()], Vector3(p.x, _ground(p.x, p.y), p.y), a, 1.1)
			camps += 1
		# the rest before the boss: a fire and a cairn with the land's banner
		var rest: Dictionary = region.get("rest", {})
		if rest.has("at"):
			var at: Array = rest["at"]
			var p := Vector2(float(at[0]), float(at[1]))
			var y := _ground(p.x, p.y)
			_campfire(Vector3(p.x, y, p.y))
			_cairn(Vector3(p.x + 3.5, y, p.y + 1.5), 1.4)
			_banner(Vector3(p.x + 3.5, y + 2.2, p.y + 1.5))
		# the boss's ground: standing stones round it
		var arena: Dictionary = region.get("arena", {})
		if arena.has("x"):
			var ac := Vector3(float(arena["x"]), float(arena.get("floor_y", 0.0)), float(arena["z"]))
			_ring_of_stones(ac, float(arena["r"]) * 0.97, 22, Vector2(2.2, 4.2), "stone_dark", true)
	counts["camps"] = camps


func _palisade(c: Vector2, r: float) -> void:
	var count := int(TAU * r / 0.7)
	for i in count:
		var a := TAU * i / count
		# the gate
		if a > 4.4 and a < 5.0:
			continue
		var p := c + Vector2(cos(a), sin(a)) * r
		var h := _rng.randf_range(2.6, 3.4)
		_cylinder(0.22, h, Vector3(p.x, _ground(p.x, p.y) - 0.3, p.y), "wood_dark", i % 2 == 0, 0.08)


func _cairn(at: Vector3, size: float) -> void:
	for i in 5:
		var s := size * (1.0 - i * 0.16)
		_prop(ROCKS[i % ROCKS.size()], at + Vector3(0, i * 0.45 * size, 0), _rng.randf() * TAU, s * 0.6, i == 0, 0.8 * size)


func _banner(at: Vector3) -> void:
	_cylinder(0.06, 3.2, at - Vector3(0, 1.4, 0), "wood_dark", false)
	_box(Vector3(0.9, 1.4, 0.04), Transform3D(Basis.IDENTITY, at + Vector3(0.45, 0.9, 0)), "cloth", false)
#endregion


#region Gates
## Where a land begins, on the ring: two tall stones either side of the way.
func _build_gates() -> void:
	var regions: Dictionary = _lands.info.get("regions", {})
	for key: String in regions:
		var gate: Array = regions[key].get("gate", [])
		if gate.size() < 2:
			continue
		var g := Vector2(float(gate[0]), float(gate[1]))
		var route: Array = regions[key].get("route", [])
		var dir := Vector2.RIGHT
		if route.size() > 2:
			var p1: Array = route[0]
			var p2: Array = route[2]
			dir = (Vector2(float(p2[0]), float(p2[1])) - Vector2(float(p1[0]), float(p1[1]))).normalized()
		var side := Vector2(-dir.y, dir.x)
		for s: float in [-3.4, 3.4]:
			var p := g + side * s
			var y := _ground(p.x, p.y)
			_box(Vector3(1.1, 4.2, 0.9), Transform3D(Basis(Vector3.UP, atan2(side.x, side.y)), Vector3(p.x, y + 1.7, p.y)), "moss_stone", true)
#endregion


#region Landmarks
func _build_landmarks() -> void:
	var n := 0
	var forest := get_parent().get_node_or_null("Forest") as Forest
	for lm: Dictionary in _lands.info.get("landmarks", []):
		var kind := String(lm["kind"])
		var x := float(lm["x"])
		var z := float(lm["z"])
		if not _lands.covers(x, z):
			continue
		var at := Vector3(x, _ground(x, z), z)
		var turn := deg_to_rad(float(lm.get("rot_deg", 0.0)))
		var size := float(lm.get("scale", 1.0))
		match kind:
			"kurgan":
				_mound(at, 9.0 * size, 3.2 * size)
			"stone_idol":
				_box(Vector3(1.3, 3.6, 0.9), Transform3D(Basis(Vector3.UP, turn), at + Vector3(0, 1.6, 0)), "stone_dark")
				_box(Vector3(1.0, 0.9, 1.0), Transform3D(Basis(Vector3.UP, turn), at + Vector3(0, 3.8, 0)), "stone_dark")
			"wayside_cross":
				_box(Vector3(0.3, 3.0, 0.3), Transform3D(Basis(Vector3.UP, turn), at + Vector3(0, 1.3, 0)), "stone")
				_box(Vector3(1.4, 0.28, 0.28), Transform3D(Basis(Vector3.UP, turn), at + Vector3(0, 2.2, 0)), "stone", false)
			"hillfort_ring":
				for i in 28:
					var a := TAU * i / 28.0
					_mound(at + Vector3(cos(a) * 36.0, 0, sin(a) * 36.0), 5.0, 1.8)
			"stone_circle":
				_ring_of_stones(at, 7.5 * size, 11, Vector2(2.0, 3.4))
			"stone_pillars":
				_ring_of_stones(at, 30.0, 9, Vector2(8.0, 14.0), "stone_dark")
			"cairn":
				_cairn(at, 1.0)
			"skull_cairn":
				_cairn(at, 1.3)
				for i in 6:
					var a := TAU * i / 6.0
					var bone := _prop(ROCKS[i % ROCKS.size()], at + Vector3(cos(a) * 1.8, 0.1, sin(a) * 1.8), a, 0.22)
					if bone != null:
						bone.material_override = _mat("bone")
			"ruined_tower", "ruined_watchtower":
				if _building(RUIN_TOWER, at - Vector3(0, 0.3, 0), turn, 1.0) == null:
					_building(WALL_TOWER, at, turn)
				else:
					_solid(Transform3D(Basis.IDENTITY, at + Vector3(0, 5.0, 0)), 3.0, 10.0)
				_rubble(at, 7.0)
			"ruined_fortress":
				_fortress(at)
			"orc_lookout":
				_building(WATCHTOWER, at, turn)
			"orc_palisade":
				pass  # the camp there puts it up
			"quarry":
				_rubble(at, 12.0)
				for i in 4:
					_prop(TIMBER[i % TIMBER.size()], at + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)), _rng.randf() * TAU, 1.2)
			"cave_mouth":
				_cave(at, turn)
			"glacier":
				_mound(at, 26.0, 9.0, "ice")
			"viewpoint_rock", "rock_gate":
				for s: float in ([-1.0, 1.0] if kind == "rock_gate" else [0.0]):
					var side := Vector3(cos(turn), 0, -sin(turn)) * 5.5 * s
					_prop(ROCKS[2], at + side - Vector3(0, 0.5, 0), turn, 3.8, true, 2.5, Vector3(1.0, 1.8, 1.0))
			"waterfall", "waterfall_small":
				_spray(at, size * (1.0 if kind == "waterfall" else 0.6))
			"fallen_giant":
				var trunk := CylinderMesh.new()
				trunk.top_radius = 0.9
				trunk.bottom_radius = 1.2
				trunk.height = 16.0
				var mi := MeshInstance3D.new()
				mi.mesh = trunk
				mi.material_override = _mat("wood")
				mi.transform = Transform3D(Basis(Vector3.UP, turn) * Basis(Vector3.FORWARD, PI * 0.5), at + Vector3(0, 0.7, 0))
				add_child(mi)
				_beam(at - Vector3(cos(turn), 0, -sin(turn)) * 8.0 + Vector3(0, 1.6, 0),
						at + Vector3(cos(turn), 0, -sin(turn)) * 8.0 + Vector3(0, 1.6, 0), 1.8, 1.6, "wood", true)
			"hollow_giant_oak", "sacred_beech", "ancient_beech", "ancient_maple", "lone_giant_tree":
				_giant_tree(forest, kind, at, size)
			"light_glade":
				_light_shafts(at)
			"mushroom_ring":
				for i in 16:
					var a := TAU * i / 16.0
					var p := at + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0)
					var m := _prop(MUSHROOMS[i % MUSHROOMS.size()], Vector3(p.x, _ground(p.x, p.z), p.z), a, 0.9)
					if m != null and i % 2 == 0:
						m.material_override = _mat("glow")
				var glow := OmniLight3D.new()
				glow.light_color = Color(0.45, 1.0, 0.75)
				glow.light_energy = 0.9
				glow.omni_range = 7.0
				glow.position = at + Vector3(0, 0.6, 0)
				add_child(glow)
			"fern_ravine":
				for i in 26:
					var p := at + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-6, 6)).rotated(Vector3.UP, turn)
					_prop(BUSHES[i % BUSHES.size()], Vector3(p.x, _ground(p.x, p.z), p.z), _rng.randf() * TAU, _rng.randf_range(1.2, 2.0))
			"antler_altar", "hunters_shrine":
				_box(Vector3(2.4, 1.0, 1.4), Transform3D(Basis(Vector3.UP, turn), at + Vector3(0, 0.4, 0)), "stone")
				for s: float in [-0.6, 0.6]:
					_box(Vector3(0.08, 1.2, 0.08), Transform3D(Basis(Vector3.FORWARD, s * 0.6), at + Vector3(s, 1.5, 0)), "bone", false)
			"hut", "watermill":
				_building(HUT, at, turn)
				if kind == "watermill":
					var wheel := CylinderMesh.new()
					wheel.top_radius = 2.2
					wheel.bottom_radius = 2.2
					wheel.height = 0.5
					var mi := MeshInstance3D.new()
					mi.mesh = wheel
					mi.material_override = _mat("wood_dark")
					mi.transform = Transform3D(Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(cos(turn), 0, -sin(turn)) * 4.5 + Vector3(0, 1.4, 0))
					add_child(mi)
			"ruined_hamlet", "burnt_farm":
				for i in (4 if kind == "ruined_hamlet" else 2):
					var p := at + Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12))
					_building(HUT, Vector3(p.x, _ground(p.x, p.z) - 0.4, p.z), _rng.randf() * TAU, KIT_SCALE,
							Color(0.14, 0.12, 0.1) if kind == "burnt_farm" else Color(0.45, 0.42, 0.38))
				_rubble(at, 10.0)
			"treehouses":
				for i in 3:
					var a := TAU * i / 3.0
					var p := at + Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
					var g := _ground(p.x, p.z)
					_cylinder(1.3, 7.0, Vector3(p.x, g - 0.2, p.z), "wood", true, 1.0)
					_box(Vector3(5.0, 0.3, 5.0), Transform3D(Basis(Vector3.UP, a), Vector3(p.x, g + 6.2, p.z)), "plank", true)
					_box(Vector3(3.2, 2.2, 3.2), Transform3D(Basis(Vector3.UP, a), Vector3(p.x, g + 7.5, p.z)), "wood", true)
			"haystacks":
				for i in 5:
					var p := at + Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-9, 9))
					_mound(Vector3(p.x, _ground(p.x, p.z), p.z), 1.6, 2.4, "hay")
			"vineyard", "switchback", "sheep_flock", "deer_herd", "white_stag", "stone_stair", \
					"plank_bridge", "log_bridge", "arched_stone_bridge", "rope_bridge", "stepping_stones", "ford", "jetty":
				continue  # rows are in the cover, the ways are crossings, the beasts are the game's
			_:
				continue
		n += 1
	counts["landmarks"] = n


func _mound(at: Vector3, radius: float, height: float, mat: String = "earth") -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height * 2.0
	mesh.is_hemisphere = true
	mesh.radial_segments = 24
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at - Vector3(0, 0.3, 0)
	mi.material_override = _mat(mat)
	add_child(mi)
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.7
	shape.height = height * 0.7
	_add_shape(shape, Transform3D(Basis.IDENTITY, at + Vector3(0, shape.height * 0.5 - 0.3, 0)))


func _rubble(at: Vector3, spread: float) -> void:
	for i in 10:
		var p := at + Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread, spread))
		var s := _rng.randf_range(0.5, 1.1)
		_box(Vector3(s * 1.4, s * 0.7, s), Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, _ground(p.x, p.z) + s * 0.25, p.z)), "stone", s > 0.8)


func _fortress(at: Vector3) -> void:
	# a broken curtain wall round the court, towers at the corners, a gate south
	var half := 26.0
	var corners: Array[Vector2] = [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for i in 4:
		var c0: Vector2 = corners[i]
		var c1: Vector2 = corners[(i + 1) % 4]
		var pieces := 8
		for k in pieces:
			# gaps: the gate (south side middle) and a breach or two
			if (i == 0 and (k == 3 or k == 4)) or (k == 6 and i == 2):
				continue
			var p := c0.lerp(c1, (k + 0.5) / pieces)
			var w := Vector3(at.x + p.x, 0, at.z + p.y)
			var h := _rng.randf_range(2.8, 5.5)
			var dir := (c1 - c0).normalized()
			_box(Vector3(half * 2.0 / pieces + 0.1, h, 1.4), Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x)),
					Vector3(w.x, _ground(w.x, w.z) + h * 0.5 - 0.4, w.z)), "stone", true)
	for c: Vector2 in corners:
		var w := Vector3(at.x + c.x, 0, at.z + c.y)
		_cylinder(3.2, _rng.randf_range(7.0, 10.0), Vector3(w.x, _ground(w.x, w.z) - 0.5, w.z), "stone", true, 2.9)


func _cave(at: Vector3, turn: float) -> void:
	# a dark mouth in a wall of rock
	var basis := Basis(Vector3.UP, turn)
	_box(Vector3(9.0, 6.5, 0.4), Transform3D(basis, at + Vector3(0, 3.0, 0) + basis.z * 1.5), "cave", true)
	for s: float in [-1.0, 1.0]:
		_prop(ROCKS[1], at + basis.x * 6.0 * s + basis.z * 1.0, turn, 3.2, true, 2.2, Vector3(1.0, 1.6, 1.0))
	_prop(ROCKS[3], at + Vector3(0, 6.0, 0) + basis.z * 1.0, turn, 4.0, false, 0.0, Vector3(1.6, 0.8, 1.0))


func _spray(at: Vector3, size: float) -> void:
	var mist := CPUParticles3D.new()
	mist.amount = int(28 * size) + 6
	mist.lifetime = 3.0
	mist.position = at + Vector3(0, 0.5, 0)
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(4.0, 0.5, 4.0) * size
	mist.direction = Vector3.UP
	mist.spread = 35.0
	mist.initial_velocity_min = 0.6
	mist.initial_velocity_max = 1.6
	mist.gravity = Vector3(0, 0.15, 0)
	mist.scale_amount_min = 2.0 * size
	mist.scale_amount_max = 4.0 * size
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 0.22)
	m.albedo_texture = LandsMood.soft_dot()
	quad.material = m
	mist.mesh = quad
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.5))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	mist.color_ramp = fade
	add_child(mist)


func _giant_tree(forest: Forest, kind: String, at: Vector3, size: float) -> void:
	var path := "res://assets/forest/Tree_Oak_1.obj"
	var tint := Color.WHITE
	match kind:
		"sacred_beech", "ancient_beech":
			path = "res://assets/forest/Tree_Oak_5.obj"
			tint = Color(1.55, 0.78, 0.28)
		"ancient_maple":
			path = "res://assets/forest/Tree_Oak_3.obj"
			tint = Color(1.85, 0.38, 0.2)
		"hollow_giant_oak":
			path = "res://assets/forest/Tree_Oak_7.obj"
		"lone_giant_tree":
			path = "res://assets/forest/Tree_Oak_7.obj"
			tint = Color(0.9, 1.05, 0.8)
	var mesh: Mesh = null
	if forest != null:
		var model := {"path": path}
		if tint != Color.WHITE:
			model["tint"] = tint
		mesh = forest._model_mesh(model)
	elif ResourceLoader.exists(path):
		mesh = load(path) as Mesh
	if mesh == null:
		return
	var big := 2.4 * size * 2.2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * big), at - Vector3(0, 0.4, 0))
	add_child(mi)
	_cylinder(minf(0.35 * big, 2.2), 12.0, at - Vector3(0, 1.0, 0), "wood", true)
	if kind == "hollow_giant_oak":
		_box(Vector3(1.8, 2.6, 0.3), Transform3D(Basis.IDENTITY, at + Vector3(0, 1.3, minf(0.35 * big, 2.2) + 0.05)), "cave", false)


func _light_shafts(at: Vector3) -> void:
	for i in 5:
		var mesh := CylinderMesh.new()
		mesh.top_radius = _rng.randf_range(0.8, 1.6)
		mesh.bottom_radius = mesh.top_radius * 1.6
		mesh.height = 22.0
		mesh.cap_top = false
		mesh.cap_bottom = false
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _mat("light")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p := at + Vector3(_rng.randf_range(-7, 7), 0, _rng.randf_range(-7, 7))
		mi.transform = Transform3D(Basis(Vector3.FORWARD, 0.35) * Basis(Vector3.RIGHT, 0.12), p + Vector3(0, 10.0, 0))
		add_child(mi)
#endregion


#region The city
## Where the orcs of the mist village stand (the city's land gate opens when
## they are all dead).
const MIST := Vector2(10.0, -190.0)

var _gate: Node3D
var _gate_body: StaticBody3D
var _mist_left := -1

signal gate_opened


func _build_city() -> void:
	var city: Dictionary = _lands.info.get("city", {})
	if city.is_empty():
		return
	var wall: Array = city.get("wall", [])
	var gates: Array = city.get("gates", [])
	# the wall, gapped at the gates
	for i in wall.size():
		var p0: Array = wall[i]
		var p1: Array = wall[(i + 1) % wall.size()]
		var a := Vector2(float(p0[0]), float(p0[1]))
		var b := Vector2(float(p1[0]), float(p1[1]))
		var cuts: Array[float] = []
		for g: Dictionary in gates:
			var gp := Vector2(float(g["x"]), float(g["z"]))
			var ab := b - a
			var t := clampf((gp - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if gp.distance_to(a + ab * t) < 3.0:
				cuts.append(t)
		_wall_run(a, b, cuts)
	for t: Array in city.get("towers", []):
		var p := Vector2(float(t[0]), float(t[1]))
		_cylinder(3.3, 12.0, Vector3(p.x, _ground(p.x, p.y) - 0.6, p.y), "stone", true, 3.0)
		_cylinder(3.7, 1.0, Vector3(p.x, _ground(p.x, p.y) + 11.2, p.y), "stone_dark", false, 3.7)
	for g: Dictionary in gates:
		_city_gate(g)
	# the market: paving, stalls round it
	var market: Dictionary = city.get("market", {})
	if market.has("x"):
		var m := Vector3(float(market["x"]), 0.0, float(market["z"]))
		m.y = _ground(m.x, m.z)
		var r := float(market.get("r", 12.0))
		_cylinder(r, 0.12, m - Vector3(0, 0.08, 0), "stone", false)
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			var p := m + Vector3(cos(a), 0, sin(a)) * (r - 2.5)
			_stall(Vector3(p.x, _ground(p.x, p.z), p.z), -a + PI * 0.5, i)
	for b: Dictionary in city.get("buildings", []):
		_house(b)
	for mole: Array in city.get("moles", []):
		for i in mole.size() - 1:
			var p0: Array = mole[i]
			var p1: Array = mole[i + 1]
			var a := Vector3(float(p0[0]), 0.7, float(p0[1]))
			var b := Vector3(float(p1[0]), 0.7, float(p1[1]))
			_beam(a, b, 5.0, 3.2, "stone")
	var lh: Array = city.get("lighthouse", [])
	if lh.size() == 2:
		var p := Vector3(float(lh[0]), 0.7, float(lh[1]))
		_cylinder(2.4, 15.0, p, "stone", true, 1.8)
		_cylinder(2.0, 0.4, p + Vector3(0, 15.0, 0), "stone_dark", false)
		var beacon := OmniLight3D.new()
		beacon.light_color = Color(1.0, 0.8, 0.45)
		beacon.light_energy = 3.0
		beacon.omni_range = 26.0
		beacon.position = p + Vector3(0, 16.2, 0)
		add_child(beacon)
	for ship: Array in city.get("ships", []):
		_ship(Vector3(float(ship[0]), -0.6, float(ship[1])), deg_to_rad(float(ship[2])))
	_watch_the_mist.call_deferred()


func _wall_run(a: Vector2, b: Vector2, cuts: Array[float]) -> void:
	var length := a.distance_to(b)
	var gap := 3.2 / maxf(length, 0.01)
	var spans: Array[Vector2] = [Vector2(0.0, 1.0)]
	for t in cuts:
		var next: Array[Vector2] = []
		for sp in spans:
			if t - gap > sp.x and t + gap < sp.y:
				next.append(Vector2(sp.x, t - gap))
				next.append(Vector2(t + gap, sp.y))
			else:
				next.append(sp)
		spans = next
	for sp in spans:
		var p0 := a.lerp(b, sp.x)
		var p1 := a.lerp(b, sp.y)
		var mid := (p0 + p1) * 0.5
		var y := minf(_ground(p0.x, p0.y), minf(_ground(mid.x, mid.y), _ground(p1.x, p1.y))) - 1.0
		var dir := (p1 - p0).normalized()
		_box(Vector3(p0.distance_to(p1), 8.0, 2.4), Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x)),
				Vector3(mid.x, y + 4.0, mid.y)), "stone", true)
		# the walk's parapet, crenels every other step
		var n := int(p0.distance_to(p1) / 2.0)
		for k in n:
			if k % 2 == 0:
				continue
			var q := p0.lerp(p1, (k + 0.5) / n)
			_box(Vector3(1.0, 1.0, 2.5), Transform3D(Basis(Vector3.UP, -atan2(dir.y, dir.x)), Vector3(q.x, y + 8.5, q.y)), "stone", false)


func _city_gate(g: Dictionary) -> void:
	var p := Vector2(float(g["x"]), float(g["z"]))
	var y := _ground(p.x, p.y)
	# the arch over the way
	var faces := String(g.get("faces", "north"))
	var across := Vector3.RIGHT if faces in ["north", "south"] else Vector3.BACK
	var basis := Basis(Vector3.UP, 0.0 if faces in ["north", "south"] else PI * 0.5)
	for s: float in [-1.0, 1.0]:
		_box(Vector3(1.8, 9.0, 3.2), Transform3D(basis, Vector3(p.x, y + 4.0, p.y) + across * 4.1 * s), "stone_dark", true)
	_box(Vector3(10.0, 2.0, 3.2), Transform3D(basis, Vector3(p.x, y + 8.8, p.y)), "stone_dark", false)
	if g.has("locked_until"):
		# the doors: shut until the mist village's orcs are dead
		_gate = Node3D.new()
		_gate.name = "LandGate"
		add_child(_gate)
		var door := BoxMesh.new()
		door.size = Vector3(6.4, 7.0, 0.5)
		var mi := MeshInstance3D.new()
		mi.mesh = door
		mi.material_override = _mat("wood_dark")
		mi.transform = Transform3D(basis, Vector3(p.x, y + 3.4, p.y))
		_gate.add_child(mi)
		_gate_body = StaticBody3D.new()
		_gate_body.collision_layer = 1
		var shape := BoxShape3D.new()
		shape.size = door.size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = mi.transform
		_gate_body.add_child(cs)
		_gate.add_child(_gate_body)


## Waits for the orcs of the mist village to be dead, then opens the land gate.
func _watch_the_mist() -> void:
	if _gate == null:
		return
	var creatures := get_parent().get_node_or_null("Enemies")
	if creatures == null:
		return
	_mist_left = 0
	for body in creatures.get_children():
		var home: Variant = body.get("camp_centre")
		if not home is Vector3:
			continue
		var h: Vector3 = home
		if Vector2(h.x, h.z).distance_to(MIST) > 20.0 or not body.has_signal(&"died"):
			continue
		_mist_left += 1
		body.connect(&"died", _on_mist_orc_died, CONNECT_ONE_SHOT)


func _on_mist_orc_died() -> void:
	_mist_left -= 1
	if _mist_left <= 0:
		open_land_gate()


## The land gate swings open (and stays open).
func open_land_gate() -> void:
	if _gate == null:
		return
	_gate_body.queue_free()
	var tween := create_tween()
	tween.tween_property(_gate, "position:y", -7.5, 2.5).set_trans(Tween.TRANS_SINE)
	gate_opened.emit()


## Whether the land gate is still shut.
func land_gate_shut() -> bool:
	return _gate != null and is_instance_valid(_gate_body) and not _gate_body.is_queued_for_deletion()


func _house(b: Dictionary) -> void:
	var x := float(b["x"])
	var z := float(b["z"])
	var w := float(b["w"])
	var d := float(b["d"])
	var turn := deg_to_rad(float(b.get("rot_deg", 0.0)))
	var y := minf(_ground(x, z), float(b.get("y", 0.0)))
	var basis := Basis(Vector3.UP, turn)
	var tall := 5.5 if w * d < 140.0 else 7.0
	_box(Vector3(w, tall + 1.0, d), Transform3D(basis, Vector3(x, y + tall * 0.5 - 0.5, z)), "stone", true)
	var roof := PrismMesh.new()
	roof.size = Vector3(d + 1.0, 3.2, w + 1.0) if w >= d else Vector3(w + 1.0, 3.2, d + 1.0)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = _hex(String(b.get("roof", "#8a3e2c")))
	rm.roughness = 0.85
	var mi := MeshInstance3D.new()
	mi.mesh = roof
	mi.material_override = rm
	var ridge := basis * (Basis(Vector3.UP, PI * 0.5) if w >= d else Basis.IDENTITY)
	mi.transform = Transform3D(ridge, Vector3(x, y + tall + 1.6, z))
	add_child(mi)
	# the door and the sign, on the side that looks at the market
	var front := basis * Vector3(0, 0, 1.0)
	var to_market := Vector3(-x, 0, -268.0 - z).normalized()
	if front.dot(to_market) < 0.0:
		front = -front
	var half := d * 0.5 if absf((basis * Vector3(0, 0, 1)).dot(front)) > 0.5 else w * 0.5
	var door := Vector3(x, y, z) + front * (half + 0.05)
	_box(Vector3(1.8, 2.6, 0.1), Transform3D(Basis.looking_at(front, Vector3.UP), door + Vector3(0, 1.3, 0)), "wood_dark", false)
	var board := Label3D.new()
	board.text = String(b.get("name", ""))
	board.font_size = 42
	board.pixel_size = 0.012
	board.outline_size = 10
	board.modulate = Color(1.0, 0.93, 0.75)
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.visibility_range_end = 32.0
	board.position = door + Vector3(0, 3.4, 0) + front * 0.3
	add_child(board)


func _hex(text: String) -> Color:
	return Color.html(text) if Color.html_is_valid(text) else Color(0.55, 0.3, 0.2)


func _stall(at: Vector3, turn: float, i: int) -> void:
	var basis := Basis(Vector3.UP, turn)
	_box(Vector3(2.6, 1.0, 1.2), Transform3D(basis, at + Vector3(0, 0.5, 0)), "wood", true)
	for s: float in [-1.2, 1.2]:
		_box(Vector3(0.1, 2.4, 0.1), Transform3D(basis, at + basis * Vector3(s, 1.2, -0.5)), "wood_dark", false)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = [Color(0.7, 0.2, 0.15), Color(0.85, 0.7, 0.3), Color(0.2, 0.4, 0.6), Color(0.35, 0.55, 0.3)][i % 4]
	var roof := BoxMesh.new()
	roof.size = Vector3(3.0, 0.06, 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = roof
	mi.material_override = cloth
	mi.transform = Transform3D(basis * Basis(Vector3.RIGHT, 0.25), at + Vector3(0, 2.4, 0))
	add_child(mi)


func _ship(at: Vector3, turn: float) -> void:
	var basis := Basis(Vector3.UP, turn)
	var hull := PrismMesh.new()
	hull.size = Vector3(3.6, 2.2, 13.0)
	var mi := MeshInstance3D.new()
	mi.mesh = hull
	mi.material_override = _mat("wood")
	mi.transform = Transform3D(basis * Basis(Vector3.FORWARD, PI), at + Vector3(0, 0.6, 0))
	add_child(mi)
	_box(Vector3(3.4, 0.2, 12.0), Transform3D(basis, at + Vector3(0, 1.7, 0)), "plank", true)
	var mast := at + basis * Vector3(0, 1.7, 0.5)
	_cylinder(0.18, 11.0, mast, "wood_dark", false)
	var sail := BoxMesh.new()
	sail.size = Vector3(6.0, 5.0, 0.05)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.9, 0.86, 0.76)
	var s := MeshInstance3D.new()
	s.mesh = sail
	s.material_override = sm
	s.transform = Transform3D(basis, mast + Vector3(0, 7.0, 0))
	add_child(s)
#endregion
