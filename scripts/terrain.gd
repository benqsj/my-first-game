class_name Terrain
extends StaticBody3D

## The ground of the old 240-metre square, no longer flat: rolling everywhere,
## a few real hills and hollows out in the wild, and dead level wherever
## something stands on it.
##
## One function, [method height_at], answers for the whole of it, on every
## peer alike (a seed and a handful of numbers, as the wood and the marsh are
## grown). The drawn ground is a grid of it, a metre a cell, cut into chunks so
## what is behind the camera is not drawn; the floor the bodies stand on is a
## [HeightMapShape3D] sampled on the same grid, so what is drawn is what is
## walked on.
##
## **Where it stays flat.** Everything that was put down on the old flat box
## is still at y = 0, so the ground comes back down to 0 under it and around
## it: every mesh standing in `Level` (the settlement, the tower, the greybox
## core), the spawn marks, the creatures already placed, the camps
## ([constant World.CAMPS]) and the wood's clearings ([constant Forest.CLEARINGS]).
## The worn tracks ([Paths]) keep a little of the roll, a fifth, so a path runs
## over the land instead of cutting through it. The flatness is worked out once,
## at load, into a coarse grid ([member mask_cell]) and read bilinearly.
##
## **Where it meets the marsh.** The strip south of the old boundary is built
## by [Marsh] at y = 0 along the seam; the relief fades to nothing over the last
## [member seam_fade] metres before it, so there is no step.
##
## Anything that plants things on the ground asks [method height] — a static
## call that answers 0 where there is no terrain (the test course).

## Half the side of the square, metres. The old box was 240 across.
@export var half_size: float = 120.0
## A cell of the drawn and the collided grid.
@export var cell: float = 1.0
## Chunks per side, for culling.
@export var chunks: int = 8
## The roll: amplitude (m) and how wide a swell is (1 / frequency).
@export var roll_height: float = 2.6
@export var roll_scale: float = 70.0
@export var terrain_seed: int = 20260925
## Hills and hollows put where they are wanted: (x, z, radius, height).
## Negative height is a hollow.
@export var features: Array[Vector4] = [
	Vector4(-92.0, -92.0, 30.0, 11.0),   # the south-west height over the wood
	Vector4(-108.0, 14.0, 22.0, 8.0),    # a shoulder by the west wall
	Vector4(-30.0, 104.0, 20.0, 6.0),    # north of the core, over the wood's edge
	Vector4(104.0, -34.0, 20.0, 8.0),    # the east down, past the puglins' lane
	Vector4(84.0, 100.0, 22.0, 7.5),     # the north-east knoll
	Vector4(102.0, -96.0, 24.0, 8.5),    # the south-east rise
	Vector4(76.0, -40.0, 12.0, -2.4),    # a hollow in the east fields
	Vector4(-66.0, 76.0, 13.0, -2.2),    # a dip in the wood
	Vector4(20.0, -96.0, 16.0, 4.0),     # a low swell on the way south
]
## The land climbs this much towards the north, east and west walls, to meet
## the mountains ([Horizon]) rather than stop at a line.
@export var edge_rise: float = 4.5
@export var edge_band: float = 26.0
## Over how far the relief fades out before the marsh strip's seam (z = -half).
@export var seam_fade: float = 26.0
## Flat ground: how far round what stands on it is kept dead level, and over
## how far it then rises back into the land.
@export var keep_margin: float = 2.0
@export var keep_fade: float = 10.0
## Tracks keep this much of the roll.
@export var track_keep: float = 0.2
## Resolution of the flatness grid.
@export var mask_cell: float = 2.0
## The materials the ground can wear: [0] the house style, [1] realistic. The
## marsh strips wear the same one.
@export var styles: Array[Material] = []
@export var style: int = 0

## The terrain in the level, for [method height].
static var current: Terrain = null

var _noise := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _mask := PackedFloat32Array()
var _mask_n: int = 0
var _track := PackedFloat32Array()
var _meshes: Array[MeshInstance3D] = []


## The height of the ground at (x, z), or 0 where there is none.
static func height(x: float, z: float) -> float:
	if current == null or not is_instance_valid(current):
		return 0.0
	return current.height_at(x, z)


## The lowest of the ground under a footprint of radius `r` round (x, z): what
## a trunk or a post is set down to, so no side of it floats on a slope.
static func height_under(x: float, z: float, r: float) -> float:
	if current == null or not is_instance_valid(current):
		return 0.0
	var h := current.height_at(x, z)
	for d: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		h = minf(h, current.height_at(x + d.x, z + d.y))
	return h


func _enter_tree() -> void:
	current = self
	_noise.seed = terrain_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0 / roll_scale
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.45
	_warp.seed = terrain_seed + 7
	_warp.frequency = 0.02


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	position = Vector3.ZERO
	if styles.is_empty():
		styles = _default_styles()
	# The old flat box goes: its mesh and its shape, out of the tree at once,
	# so nothing that looks for the ground in the first physics frame finds it.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build_mask()
	_build_mesh()
	_build_collision()
	_dress_marsh()
	var args := OS.get_cmdline_user_args()
	if "ground_b" in args:
		set_style(1)
	elif "ground_a" in args:
		set_style(0)
	else:
		set_style(style)


## The ground's height, worked out from scratch (see the class notes).
func height_at(x: float, z: float) -> float:
	if absf(x) > half_size + 0.01 or absf(z) > half_size + 0.01:
		return 0.0
	var h := raw_at(x, z)
	return h * _flat_at(x, z) * _seam(z)


## The relief before anything is flattened.
func raw_at(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * roll_height
	for f in features:
		var d := Vector2(x - f.x, z - f.y).length()
		# A little ragged at the rim, so no hill is a perfect dome.
		var r := f.z * (1.0 + 0.18 * _warp.get_noise_2d(x, z))
		if d < r:
			var t := 0.5 + 0.5 * cos(PI * d / r)
			h += f.w * t * t * (3.0 - 2.0 * t)
	# The rise to the walls, north, east and west (the south is the marsh).
	var edge := maxf(maxf(x - (half_size - edge_band), -half_size + edge_band - x), z - (half_size - edge_band))
	if edge > 0.0:
		var t := clampf(edge / edge_band, 0.0, 1.0)
		h += edge_rise * t * t * (1.0 + 0.4 * _warp.get_noise_2d(x * 2.0, z * 2.0))
	return h


func _seam(z: float) -> float:
	var t := clampf((z + half_size) / seam_fade, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


#region Flatness
func _build_mask() -> void:
	_mask_n = int(round(half_size * 2.0 / mask_cell)) + 1
	_mask.resize(_mask_n * _mask_n)
	_mask.fill(1.0)
	_track.resize(_mask_n * _mask_n)
	_track.fill(0.0)
	var world := _world()
	var level := get_parent()
	# Everything standing in the level.
	for node in level.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		if vi == null or is_ancestor_of(vi):
			continue
		var box := vi.global_transform * vi.get_aabb()
		if box.size.x > 100.0 or box.size.z > 100.0:
			continue  # a wall or a sky, not something standing on the ground
		_keep_rect(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
	for node in level.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		if cs == null or is_ancestor_of(cs) or cs.shape == null:
			continue
		var box := cs.global_transform * cs.shape.get_debug_mesh().get_aabb()
		if box.size.x > 100.0 or box.size.z > 100.0:
			continue
		_keep_rect(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
	# Spawn marks and whoever is already standing somewhere.
	for group_name: String in ["SpawnPoints", "Enemies", "People", "Villagers", "Npcs"]:
		var holder := world.get_node_or_null(group_name) as Node
		if holder == null:
			continue
		for node in holder.find_children("*", "Node3D", false, false):
			var at := (node as Node3D).global_position
			_keep_circle(Vector2(at.x, at.z), 3.0)
	for camp: Array in World.CAMPS:
		var c: Vector2 = camp[1]
		_keep_circle(c, 8.0)
	for c: Vector3 in Forest.CLEARINGS:
		_keep_circle(Vector2(c.x, c.y), c.z * 0.6)
	# The tracks: a third of the roll left.
	var paths := world.get_node_or_null("Paths")
	if paths != null:
		var tracks: Array = paths.get("tracks")
		var width: float = paths.get("width")
		for line: PackedVector2Array in tracks:
			for i in line.size() - 1:
				_keep_segment(line[i], line[i + 1], width * 0.5)


## The level this ground is in: the first [World] up the tree (or the scene).
func _world() -> Node:
	var node := get_parent()
	while node != null and not (node is World):
		node = node.get_parent()
	if node != null:
		return node
	return get_tree().current_scene if get_tree().current_scene != null else get_parent()


func _index(ix: int, iz: int) -> int:
	return iz * _mask_n + ix


func _cells(lo: Vector2, hi: Vector2) -> Rect2i:
	var a := Vector2i(floori((lo.x + half_size) / mask_cell), floori((lo.y + half_size) / mask_cell))
	var b := Vector2i(ceili((hi.x + half_size) / mask_cell), ceili((hi.y + half_size) / mask_cell))
	a = a.clamp(Vector2i.ZERO, Vector2i(_mask_n - 1, _mask_n - 1))
	b = b.clamp(Vector2i.ZERO, Vector2i(_mask_n - 1, _mask_n - 1))
	return Rect2i(a, b - a)


func _cell_at(ix: int, iz: int) -> Vector2:
	return Vector2(ix * mask_cell - half_size, iz * mask_cell - half_size)


func _ease(d: float) -> float:
	var t := clampf((d - keep_margin) / keep_fade, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _keep_rect(r: Rect2) -> void:
	var reach := keep_margin + keep_fade
	var span := _cells(r.position - Vector2(reach, reach), r.end + Vector2(reach, reach))
	for iz in range(span.position.y, span.end.y + 1):
		for ix in range(span.position.x, span.end.x + 1):
			var p := _cell_at(ix, iz)
			var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
			var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
			var k := _index(ix, iz)
			_mask[k] = minf(_mask[k], _ease(sqrt(dx * dx + dz * dz)))


func _keep_circle(c: Vector2, radius: float) -> void:
	var reach := radius + keep_margin + keep_fade
	var span := _cells(c - Vector2(reach, reach), c + Vector2(reach, reach))
	for iz in range(span.position.y, span.end.y + 1):
		for ix in range(span.position.x, span.end.x + 1):
			var k := _index(ix, iz)
			_mask[k] = minf(_mask[k], _ease(maxf(_cell_at(ix, iz).distance_to(c) - radius, 0.0)))


func _keep_segment(a: Vector2, b: Vector2, half_width: float) -> void:
	var reach := half_width + keep_fade
	var span := _cells(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach),
			Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach))
	var ab := b - a
	for iz in range(span.position.y, span.end.y + 1):
		for ix in range(span.position.x, span.end.x + 1):
			var p := _cell_at(ix, iz)
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			var near := 1.0 - clampf((d - half_width) / keep_fade, 0.0, 1.0)
			var k := _index(ix, iz)
			_mask[k] = minf(_mask[k], lerpf(1.0, track_keep, near))
			_track[k] = maxf(_track[k], clampf(1.0 - (d - half_width * 0.6) / 2.5, 0.0, 1.0))


func _grid_at(data: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + half_size) / mask_cell, 0.0, _mask_n - 1.001)
	var fz := clampf((z + half_size) / mask_cell, 0.0, _mask_n - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(data[_index(ix, iz)], data[_index(ix + 1, iz)], tx)
	var b := lerpf(data[_index(ix, iz + 1)], data[_index(ix + 1, iz + 1)], tx)
	return lerpf(a, b, tz)


func _flat_at(x: float, z: float) -> float:
	return _grid_at(_mask, x, z)


## How much of a worn track is at (x, z), 0..1: for the ground's material.
func track_at(x: float, z: float) -> float:
	return _grid_at(_track, x, z)
#endregion


#region Mesh and collision
func _build_mesh() -> void:
	var n := int(round(half_size * 2.0 / cell))  # cells per side
	var per := n / chunks
	# Heights once, on the full grid (one more than cells per side).
	var heights := PackedFloat32Array()
	heights.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			heights[iz * (n + 1) + ix] = height_at(ix * cell - half_size, iz * cell - half_size)
	_heights = heights
	_n = n
	for cz in chunks:
		for cx in chunks:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for iz in range(cz * per, (cz + 1) * per + 1):
				for ix in range(cx * per, (cx + 1) * per + 1):
					var x := ix * cell - half_size
					var z := iz * cell - half_size
					var h := heights[iz * (n + 1) + ix]
					var hl := heights[iz * (n + 1) + maxi(ix - 1, 0)]
					var hr := heights[iz * (n + 1) + mini(ix + 1, n)]
					var hd := heights[maxi(iz - 1, 0) * (n + 1) + ix]
					var hu := heights[mini(iz + 1, n) * (n + 1) + ix]
					st.set_normal(Vector3(hl - hr, 2.0 * cell, hd - hu).normalized())
					# The material reads a worn track in the vertex alpha (1 = none).
					st.set_color(Color(1.0, 1.0, 1.0, 1.0 - track_at(x, z)))
					st.set_uv(Vector2(x, z))
					st.add_vertex(Vector3(x, h, z))
			var row := per + 1
			for iz in per:
				for ix in per:
					var a := iz * row + ix
					st.add_index(a)
					st.add_index(a + 1)
					st.add_index(a + row)
					st.add_index(a + 1)
					st.add_index(a + row + 1)
					st.add_index(a + row)
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cz]
			mi.mesh = st.commit()
			add_child(mi)
			_meshes.append(mi)


var _heights := PackedFloat32Array()
var _n: int = 0


func _build_collision() -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = _n + 1
	shape.map_depth = _n + 1
	shape.map_data = _heights
	var cs := CollisionShape3D.new()
	cs.name = "Floor"
	cs.shape = shape
	cs.scale = Vector3(cell, 1.0, cell)
	add_child(cs)


## The marsh strips draw their ground with the same material, so the seam does
## not show whichever is worn.
func _dress_marsh() -> void:
	var world := _world()
	for m in world.find_children("*", "Marsh", true, false):
		if styles.size() > style:
			m.set("ground_material", styles[style])


const SHADER := "res://shaders/terrain_ground.gdshader"
const REAL := "res://assets/terrain_real/"
## The realistic set: uniform -> (colour, normal) under [constant REAL].
const REAL_MAPS := {
	"grass": ["grass004/Grass004_1K-JPG_Color.jpg", "grass004/Grass004_1K-JPG_NormalGL.jpg"],
	"meadow": ["aerial_grass_rock_diff.jpg", "aerial_grass_rock_nor_gl.jpg"],
	"dry": ["grass004/Grass004_1K-JPG_Color.jpg", "grass004/Grass004_1K-JPG_NormalGL.jpg"],
	"earth": ["forest_ground_04_diff.jpg", "forest_ground_04_nor_gl.jpg"],
	"rock": ["aerial_rocks_02_diff.jpg", "aerial_rocks_02_nor_gl.jpg"],
	"mud": ["brown_mud_02_diff.jpg", "brown_mud_02_nor_gl.jpg"],
}


## The two materials, when none are given: the house style, carrying on the old
## ground's own noise, and the photographed one.
func _default_styles() -> Array[Material]:
	var shader := load(SHADER) as Shader
	var mottle: Texture2D = null
	var bump: Texture2D = null
	for child in get_children():
		var mi := child as MeshInstance3D
		if mi != null and mi.get_surface_override_material(0) is StandardMaterial3D:
			var old := mi.get_surface_override_material(0) as StandardMaterial3D
			mottle = old.albedo_texture
			bump = old.normal_texture
	var a := ShaderMaterial.new()
	a.shader = shader
	a.set_shader_parameter("realistic", false)
	a.set_shader_parameter("mottle", mottle)
	a.set_shader_parameter("bump", bump)
	var b := ShaderMaterial.new()
	b.shader = shader
	b.set_shader_parameter("realistic", true)
	b.set_shader_parameter("mottle", mottle)
	b.set_shader_parameter("bump", bump)
	for key: String in REAL_MAPS:
		var pair: Array = REAL_MAPS[key]
		if ResourceLoader.exists(REAL + pair[0]):
			b.set_shader_parameter("t_" + key, load(REAL + pair[0]))
		if ResourceLoader.exists(REAL + pair[1]):
			b.set_shader_parameter("n_" + key, load(REAL + pair[1]))
	var out: Array[Material] = [a, b]
	return out


## Puts the ground in one of its materials, the marsh strips' too.
func set_style(which: int) -> void:
	if styles.is_empty():
		return
	style = clampi(which, 0, styles.size() - 1)
	var mat := styles[style]
	for mi in _meshes:
		mi.material_override = mat
	var world := _world()
	for m in world.find_children("*", "Marsh", true, false):
		m.set("ground_material", mat)
		var ground := m.get_node_or_null("Ground") as MeshInstance3D
		if ground != null:
			ground.material_override = mat


func _unhandled_key_input(event: InputEvent) -> void:
	# F8 swaps the ground's material, to compare the two.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F8:
		set_style((style + 1) % maxi(styles.size(), 1))
#endregion
