class_name Lands
extends StaticBody3D

## The world round the core: the five lands of the v4 map (west, north,
## Mamberi's wood, Ochopintre's beeches, the devs' mountains), 600 × 890 m with
## the old level in its middle.
##
## Nothing here is worked out in the game. The map was drawn and baked in
## `vepxis-art/map/v4/` (design.py → raster.py → export_game.py) and what it
## wrote is read from `assets/world/lands/`: the height of every metre, the
## water's level, which way it runs, the cover. The core is not in it: inside
## [member core] the ground is [Terrain]'s and the marshes', exactly as it was
## (the map took its heights from them, so the two meet without a step).
##
## * **Ground.** Chunks of a flat grid lifted in the shader
##   (`shaders/lands_ground.gdshader`) from a float texture of the heights, so
##   building it is cheap and every chunk of one size shares one mesh. Near
##   chunks a metre a cell, far ones five; each has a skirt so the two never
##   show a crack between them.
## * **Floor.** Four [HeightMapShape3D]s round the core. Where the water is
##   too deep to wade (`block`) the floor rises out of it, so a body is held on
##   the bank: there is no swimming, the rivers are crossed at the fords and
##   over the bridges.
## * **Water.** One surface over every wet metre at the water's level, falling
##   down the rivers and down the falls (`shaders/lands_water.gdshader`).
## * **Edge.** The world ends at its rim: walls round it, a skirt of land
##   running away under the [Horizon]'s mountains.
##
## [method height] answers for all of it ([method Terrain.height_at] asks here
## for anything outside its square).

const DIR := "res://assets/world/lands/"
const GROUND_SHADER := "res://shaders/lands_ground.gdshader"
const WATER_SHADER := "res://shaders/lands_water.gdshader"

## Cells a chunk is on a side.
@export var chunk_cells: int = 50
## A far chunk's cell, in metres (divides the chunk and the core's edges).
@export var far_step: int = 5
## Beyond this a chunk is drawn coarse.
@export var near_range: float = 170.0
## How far the floor rises above deep water.
@export var barrier_rise: float = 2.5
## The water's material. Left empty, a [ShaderMaterial] on the lands' water shader
## with the mere's ripples.
@export var water_material: Material
## How far the land runs out beyond the rim, falling away under the mountains.
@export var beyond: float = 1400.0

## The lands in the level, for [method height].
static var current: Lands = null

var nx: int = 0
var nz: int = 0
var x0: float = 0.0
var z0: float = 0.0
## The core, (x0, z0, x1, z1): drawn and walked on by [Terrain] and [Marsh].
var core := Vector4(-120.0, -455.0, 120.0, 180.0)
var info: Dictionary = {}

var _h := PackedFloat32Array()
var _w := PackedFloat32Array()
var _block := PackedByteArray()
var _loaded := false
var _ground: ShaderMaterial
var _grids: Dictionary = {}


## The height of the ground at (x, z) in the lands, or 0 where there is none
## (the core, or past the rim, or no lands in the level).
static func height(x: float, z: float) -> float:
	if current == null or not is_instance_valid(current) or not current.covers(x, z):
		return 0.0
	return current.height_at(x, z)


## The water's surface at (x, z), or -INF where it is dry.
static func water(x: float, z: float) -> float:
	if current == null or not is_instance_valid(current) or not current.covers(x, z):
		return -INF
	return current.water_at(x, z)


func _enter_tree() -> void:
	current = self
	_load()


func _exit_tree() -> void:
	if current == self:
		current = null


func _load() -> void:
	if _loaded:
		return
	var text := FileAccess.get_file_as_string(DIR + "lands.json")
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Lands: %slands.json is missing or broken." % DIR)
		return
	info = parsed
	nx = int(info["nx"])
	nz = int(info["nz"])
	x0 = float(info["x0"])
	z0 = float(info["z0"])
	var c: Dictionary = info["core"]
	# The core's own grids end on whole metres: Terrain at z = 180, the bay at -455.
	core = Vector4(float(c["x0"]), ceilf(float(c["z0"])), float(c["x1"]), ceilf(float(c["z1"])))
	_h = _read("height.f32.gz", nx * nz * 4).to_float32_array()
	_w = _read("water.f32.gz", nx * nz * 4).to_float32_array()
	_block = _read("block.u8.gz", nx * nz)
	_loaded = _h.size() == nx * nz and _w.size() == nx * nz and _block.size() == nx * nz
	if not _loaded:
		push_error("Lands: the grids in %s are not %d × %d." % [DIR, nx, nz])
		return
	# Worked out as soon as the grids are in, so the wood (grown before the
	# lands are built) can keep off them.
	_find_crossings()


## One of the map's lists (`trees`, `rocks`): its rows after the header, each
## [kind, x, z, y, scale, turn in degrees].
func table(list: String) -> Array:
	var out: Array = []
	var text := FileAccess.get_file_as_string(DIR + list + ".txt")
	var lines := text.split("\n", false)
	for i in range(1, lines.size()):
		var f := lines[i].split(",")
		if f.size() < 6:
			continue
		out.append([f[0], f[1].to_float(), f[2].to_float(), f[3].to_float(), f[4].to_float(), f[5].to_float()])
	return out


static func _read(file: String, size: int) -> PackedByteArray:
	var raw := FileAccess.get_file_as_bytes(DIR + file)
	if raw.is_empty():
		return PackedByteArray()
	return raw.decompress(size, FileAccess.COMPRESSION_GZIP)


## Whether (x, z) is in the lands: inside the rim and not in the core.
func covers(x: float, z: float) -> bool:
	if not _loaded:
		return false
	if x < x0 or z < z0 or x > x0 + nx - 1 or z > z0 + nz - 1:
		return false
	return not in_core(x, z)


## Whether (x, z) is strictly inside the core.
func in_core(x: float, z: float) -> bool:
	return x > core.x and x < core.z and z > core.y and z < core.w


## Whether (x, z) is inside the world's rim at all.
func inside(x: float, z: float) -> bool:
	return x >= x0 and z >= z0 and x <= x0 + nx - 1 and z <= z0 + nz - 1


## The rim, (x0, z0, x1, z1).
func rim() -> Vector4:
	return Vector4(x0, z0, x0 + nx - 1, z0 + nz - 1)


func _at(ix: int, iz: int) -> float:
	return _h[clampi(iz, 0, nz - 1) * nx + clampi(ix, 0, nx - 1)]


## The ground's height, read bilinearly off the grid.
func height_at(x: float, z: float) -> float:
	if not _loaded:
		return 0.0
	var fx := clampf(x - x0, 0.0, nx - 1.0)
	var fz := clampf(z - z0, 0.0, nz - 1.0)
	var ix := mini(int(fx), nx - 2)
	var iz := mini(int(fz), nz - 2)
	var tx := fx - ix
	var tz := fz - iz
	var a := lerpf(_at(ix, iz), _at(ix + 1, iz), tx)
	var b := lerpf(_at(ix, iz + 1), _at(ix + 1, iz + 1), tx)
	return lerpf(a, b, tz)


## The water's level over the metre (x, z) is in, or -INF.
func water_at(x: float, z: float) -> float:
	if not _loaded:
		return -INF
	var ix := clampi(int(round(x - x0)), 0, nx - 1)
	var iz := clampi(int(round(z - z0)), 0, nz - 1)
	var v := _w[iz * nx + ix]
	return v if v > -90.0 else -INF


func _ready() -> void:
	if not _loaded:
		return
	var started := Time.get_ticks_usec()
	collision_layer = 1
	collision_mask = 0
	_meet_the_core()
	_build_ground()
	_build_floor()
	_build_water()
	_build_edge()
	_build_grass()
	print("Lands: %d × %d m round the core, in %.1f ms" % [nx - 1, nz - 1, (Time.get_ticks_usec() - started) / 1000.0])


#region The seam
## How far into the lands their ground is eased to meet the core's, metres.
@export var seam_blend: float = 8.0


## Brings the lands' edge onto the core's ground where they meet ([Terrain]'s
## square: its east and west sides and its north end), easing the difference
## out over [member seam_blend]. The map took the core's heights from the game,
## but the core's ground is worked out at load from what stands on it, so it
## can have moved a little since; this keeps the seam without a step.
func _meet_the_core() -> void:
	var terrain := Terrain.current
	if terrain == null or not is_instance_valid(terrain):
		return
	var reach := int(seam_blend)
	var north := terrain.north_edge()
	var half := terrain.half_size
	# the two long sides
	for side: int in [-1, 1]:
		var edge := int(round(side * half - x0))
		for iz in range(int(round(-half - z0)), int(round(north - z0)) + 1):
			var z := z0 + iz
			var diff := terrain.height_at(side * half, z) - _h[iz * nx + edge]
			for k in range(0, reach + 1):
				var ix := edge + side * k
				var t := float(k) / reach
				_h[iz * nx + ix] += diff * (1.0 - t * t * (3.0 - 2.0 * t))
	# the north end
	var top := int(round(north - z0))
	for ix in range(int(round(-half - x0)) + 1, int(round(half - x0))):
		var x := x0 + ix
		var diff := terrain.height_at(x, north) - _h[top * nx + ix]
		for k in range(0, reach + 1):
			var iz := top + k
			var t := float(k) / reach
			_h[iz * nx + ix] += diff * (1.0 - t * t * (3.0 - 2.0 * t))
#endregion


#region Ground
func _texture(data: PackedByteArray, fmt: Image.Format) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(nx, nz, false, fmt, data))


func _ground_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(GROUND_SHADER) as Shader
	mat.set_shader_parameter("height_tex", _texture(_h.to_byte_array(), Image.FORMAT_RF))
	for key: String in ["splat_a", "splat_b", "splat_c"]:
		mat.set_shader_parameter(key, _texture(_read(key + ".rgba8.gz", nx * nz * 4), Image.FORMAT_RGBA8))
	var tint := _texture(_read("tint.rgba8.gz", nx * nz * 4), Image.FORMAT_RGBA8)
	mat.set_shader_parameter("tint_tex", tint)
	mat.set_shader_parameter("crop_tex", tint)
	mat.set_shader_parameter("origin", Vector2(x0, z0))
	mat.set_shader_parameter("grid_size", Vector2(nx, nz))
	mat.set_shader_parameter("core", core)
	# The core's house-style ground lends its noise, so the grass is one grass.
	var terrain := Terrain.current
	if terrain != null and is_instance_valid(terrain) and not terrain.styles.is_empty():
		var house := terrain.styles[0] as ShaderMaterial
		if house != null:
			for key: String in ["mottle", "bump", "grass_a", "grass_b", "grass_dry"]:
				var v: Variant = house.get_shader_parameter(key)
				if v != null:
					mat.set_shader_parameter(key, v)
	return mat


## A flat grid `w` × `d` metres at `step`, with a skirt round it: UV.x is the
## step, UV.y 1 on the skirt.
func _grid(w: int, d: int, step: int) -> ArrayMesh:
	var key := Vector3i(w, d, step)
	if _grids.has(key):
		return _grids[key]
	var cols := int(float(w) / step) + 1
	var rows := int(float(d) / step) + 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for iz in rows:
		for ix in cols:
			verts.append(Vector3(ix * step, 0.0, iz * step))
			uvs.append(Vector2(step, 0.0))
	for iz in rows - 1:
		for ix in cols - 1:
			var a := iz * cols + ix
			idx.append_array([a, a + 1, a + cols, a + 1, a + cols + 1, a + cols])
	# The skirt: the border walked round once, each vertex doubled below itself.
	var ring := PackedInt32Array()
	for ix in cols:
		ring.append(ix)
	for iz in range(1, rows):
		ring.append(iz * cols + cols - 1)
	for ix in range(cols - 2, -1, -1):
		ring.append((rows - 1) * cols + ix)
	for iz in range(rows - 2, 0, -1):
		ring.append(iz * cols)
	var base := verts.size()
	for i in ring.size():
		verts.append(verts[ring[i]])
		uvs.append(Vector2(step, 1.0))
	for i in ring.size():
		var j := (i + 1) % ring.size()
		var a := ring[i]
		var b := ring[j]
		var a2 := base + i
		var b2 := base + j
		# Both ways round: a skirt is seen from whichever side the crack is on.
		idx.append_array([a, b, a2, b, b2, a2, a, a2, b, b, a2, b2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_grids[key] = mesh
	return mesh


func _build_ground() -> void:
	_ground = _ground_material()
	var holder := Node3D.new()
	holder.name = "Ground"
	add_child(holder)
	for cz in range(0, nz - 1, chunk_cells):
		for cx in range(0, nx - 1, chunk_cells):
			var w := mini(chunk_cells, nx - 1 - cx)
			var d := mini(chunk_cells, nz - 1 - cz)
			var lo := Vector2(x0 + cx, z0 + cz)
			var hi := lo + Vector2(w, d)
			if lo.x >= core.x and hi.x <= core.z and lo.y >= core.y and hi.y <= core.w:
				continue  # all core
			var low := INF
			var high := -INF
			for iz in range(cz, cz + d + 1):
				for ix in range(cx, cx + w + 1):
					var h := _h[iz * nx + ix]
					low = minf(low, h)
					high = maxf(high, h)
			var box := AABB(Vector3(0.0, low - 2.0, 0.0), Vector3(w, high - low + 2.5, d))
			var fine := MeshInstance3D.new()
			fine.name = "Near_%d_%d" % [cx, cz]
			fine.mesh = _grid(w, d, 1)
			fine.position = Vector3(lo.x, 0.0, lo.y)
			fine.custom_aabb = box
			fine.material_override = _ground
			fine.visibility_range_end = near_range
			fine.visibility_range_end_margin = 10.0
			holder.add_child(fine)
			var coarse := MeshInstance3D.new()
			coarse.name = "Far_%d_%d" % [cx, cz]
			coarse.mesh = _grid(w, d, far_step)
			coarse.position = fine.position
			coarse.custom_aabb = box
			coarse.material_override = _ground
			coarse.visibility_range_begin = near_range
			coarse.visibility_range_begin_margin = 10.0
			coarse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(coarse)
#endregion


#region Crossings
## The kinds of landmark that are ways over the water.
const CROSSING_KINDS: PackedStringArray = ["plank_bridge", "log_bridge", "arched_stone_bridge",
		"rope_bridge", "stepping_stones", "ford", "jetty"]

## The ways over the water, worked out from the map's landmarks at load (the
## map says where a bridge is, not how long): each {kind, key, a, b, mid, water}
## — the two banks and the middle of the deck (the deck's height there), and the
## water's level under it (-INF for none). The floor under each is let through
## the deep water's barrier, so a body on the deck is not stopped by it.
## [LandsPlaces] puts the bridges up on these.
var crossings: Array[Dictionary] = []


func _find_crossings() -> void:
	crossings.clear()
	for lm: Dictionary in info.get("landmarks", []):
		var kind := String(lm["kind"])
		if not kind in CROSSING_KINDS:
			continue
		var at := Vector2(float(lm["x"]), float(lm["z"]))
		var c := jetty(at) if kind == "jetty" else span(at, float(lm.get("rot_deg", 0.0)))
		if c.is_empty():
			push_warning("Lands: no way over the water found at %s (%s)." % [at, lm["key"]])
			continue
		c["kind"] = kind
		c["key"] = String(lm["key"])
		crossings.append(c)
		if kind != "ford":
			var a: Vector3 = c["a"]
			var b: Vector3 = c["b"]
			_open(Vector2(a.x, a.z), Vector2(b.x, b.z), 2.0 if kind != "stepping_stones" else 1.2)


## Whether (x, z) is within `margin` of a way over the water.
func near_crossing(at: Vector2, margin: float) -> bool:
	for c: Dictionary in crossings:
		var a3: Vector3 = c["a"]
		var b3: Vector3 = c["b"]
		var a := Vector2(a3.x, a3.z)
		var ab := Vector2(b3.x, b3.z) - a
		var t := clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if at.distance_to(a + ab * t) < margin:
			return true
	return false


## The nearest wet metre to `at` within `reach`, or `at` itself when none is.
func _nearest_water(at: Vector2, reach: int = 16) -> Vector2:
	if water_at(at.x, at.y) > -INF:
		return at
	for r in range(1, reach + 1):
		for k in 24:
			var p := at + Vector2.from_angle(TAU * k / 24.0) * float(r)
			if water_at(p.x, p.y) > -INF:
				return p
	return at


## The shortest way over the water near `at`: tried along the map's turn, across
## it and on the diagonals; each end where the bank stands up to the deck.
func span(at: Vector2, rot_deg: float) -> Dictionary:
	var centre := _nearest_water(at)
	var wl := water_at(centre.x, centre.y)
	if wl == -INF:
		return {}
	var deck := wl + 1.2
	var best := {}
	for turn: float in [0.0, 90.0, 45.0, 135.0]:
		var dir := Vector2.from_angle(deg_to_rad(rot_deg + turn))
		var ends: Array[Vector3] = []
		for side: float in [-1.0, 1.0]:
			# out to where the bank stands up to the deck, or three metres onto
			# dry ground where the far side is low
			var dry := 0
			for t in range(1, 50):
				var p := centre + dir * side * float(t)
				if water_at(p.x, p.y) > -INF:
					dry = 0
					continue
				dry += 1
				if height_at(p.x, p.y) >= deck - 0.6 or dry >= 3:
					var q := centre + dir * side * (float(t) + 1.0)
					ends.append(Vector3(q.x, height_at(q.x, q.y), q.y))
					break
		if ends.size() < 2:
			continue
		var length := ends[0].distance_to(ends[1])
		if best.is_empty() or length < float(best["length"]):
			var mid := (ends[0] + ends[1]) * 0.5
			mid.y = maxf(mid.y, deck)
			best = {"a": ends[0], "b": ends[1], "mid": mid, "water": wl, "length": length}
	return best


## A landing stage: from the water's edge nearest `at` out over the water.
func jetty(at: Vector2) -> Dictionary:
	var edge := _nearest_water(at, 16)
	var wl := water_at(edge.x, edge.y)
	if wl == -INF:
		return {}
	# out towards where the water is widest
	var best_dir := Vector2.ZERO
	var best_run := 0
	for k in 16:
		var dir := Vector2.from_angle(TAU * k / 16.0)
		var run := 0
		for t in range(1, 12):
			var p := edge + dir * float(t)
			if water_at(p.x, p.y) == -INF:
				break
			run = t
		if run > best_run:
			best_run = run
			best_dir = dir
	if best_run < 2:
		return {}
	var deck := wl + 0.9
	var a2 := edge - best_dir * 3.0
	var b2 := edge + best_dir * minf(float(best_run) * 0.7, 7.0)
	var a := Vector3(a2.x, maxf(height_at(a2.x, a2.y), deck), a2.y)
	var b := Vector3(b2.x, deck, b2.y)
	return {"a": a, "b": b, "mid": (a + b) * 0.5, "water": wl, "length": a.distance_to(b)}


## Lets the floor through the deep water's barrier along a way over it.
func _open(a: Vector2, b: Vector2, half_width: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * half_width
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * half_width
	var ab := b - a
	for iz in range(maxi(int(lo.y - z0), 0), mini(int(hi.y - z0) + 2, nz)):
		for ix in range(maxi(int(lo.x - x0), 0), mini(int(hi.x - x0) + 2, nx)):
			var p := Vector2(x0 + ix, z0 + iz)
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if p.distance_to(a + ab * t) <= half_width:
				_block[iz * nx + ix] = 0
#endregion


#region Floor
func _build_floor() -> void:
	# Grid cells (ix, iz) spans, inclusive, round the core.
	var cx0 := int(core.x - x0)
	var cx1 := int(core.z - x0)
	var cz0 := int(core.y - z0)
	var cz1 := int(core.w - z0)
	var spans: Array[Rect2i] = [
		Rect2i(0, 0, cx0, nz - 1),                       # east of the core, all its length
		Rect2i(cx1, 0, nx - 1 - cx1, nz - 1),            # west of it
		Rect2i(cx0, cz1, cx1 - cx0, nz - 1 - cz1),       # north of it
		Rect2i(cx0, 0, cx1 - cx0, cz0),                  # south of it, past the bay
	]
	var n := 0
	for span in spans:
		if span.size.x < 1 or span.size.y < 1:
			continue
		var w := span.size.x + 1
		var d := span.size.y + 1
		var data := PackedFloat32Array()
		data.resize(w * d)
		for iz in d:
			var row := (span.position.y + iz) * nx + span.position.x
			for ix in w:
				var k := row + ix
				var h := _h[k]
				if _block[k] != 0:
					h = maxf(h, _w[k] + barrier_rise)
				data[iz * w + ix] = h
		var shape := HeightMapShape3D.new()
		shape.map_width = w
		shape.map_depth = d
		shape.map_data = data
		var cs := CollisionShape3D.new()
		cs.name = "Floor%d" % n
		cs.shape = shape
		# A height map is centred on its node.
		cs.position = Vector3(x0 + span.position.x + (w - 1) * 0.5, 0.0, z0 + span.position.y + (d - 1) * 0.5)
		add_child(cs)
		n += 1
#endregion


#region Water
func _water_material() -> Material:
	if water_material != null:
		return water_material
	var mat := ShaderMaterial.new()
	mat.shader = load(WATER_SHADER) as Shader
	var mere := load("res://assets/world/water.tres") as ShaderMaterial
	if mere != null:
		mat.set_shader_parameter("ripple_a", mere.get_shader_parameter("ripple_a"))
		mat.set_shader_parameter("ripple_b", mere.get_shader_parameter("ripple_b"))
	mat.set_shader_parameter("flow_tex", _texture(_read("flow.rgba8.gz", nx * nz * 4), Image.FORMAT_RGBA8))
	mat.set_shader_parameter("origin", Vector2(x0, z0))
	mat.set_shader_parameter("grid_size", Vector2(nx, nz))
	return mat


## The level at a cell corner: the highest of the wet cells round it, reaching
## a cell further out when none of the four is wet, so the surface runs a
## little in under the banks and they cut its edge.
func _corner_level(ix: int, iz: int) -> float:
	var best := -INF
	for r: int in [1, 2]:
		for dz in range(-r, r):
			for dx in range(-r, r):
				var jx := ix + dx
				var jz := iz + dz
				if jx < 0 or jz < 0 or jx >= nx or jz >= nz:
					continue
				var v := _w[jz * nx + jx]
				if v > -90.0:
					best = maxf(best, v)
		if best > -INF:
			return best
	return best


func _build_water() -> void:
	var mat := _water_material()
	var holder := Node3D.new()
	holder.name = "Water"
	add_child(holder)
	# Which cells are drawn: the wet ones and one round them.
	var wet := PackedByteArray()
	wet.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			if _w[iz * nx + ix] > -90.0:
				for dz in range(-1, 2):
					for dx in range(-1, 2):
						var jx := ix + dx
						var jz := iz + dz
						if jx >= 0 and jz >= 0 and jx < nx and jz < nz:
							wet[jz * nx + jx] = 1
	for cz in range(0, nz - 1, chunk_cells):
		for cx in range(0, nx - 1, chunk_cells):
			var verts := PackedVector3Array()
			var idx := PackedInt32Array()
			var corner := {}
			for iz in range(cz, mini(cz + chunk_cells, nz - 1)):
				for ix in range(cx, mini(cx + chunk_cells, nx - 1)):
					if wet[iz * nx + ix] == 0:
						continue
					var x := x0 + ix
					var z := z0 + iz
					if in_core(x + 0.5, z + 0.5):
						continue
					var quad := PackedInt32Array()
					for c: Vector2i in [Vector2i(ix, iz), Vector2i(ix + 1, iz), Vector2i(ix, iz + 1), Vector2i(ix + 1, iz + 1)]:
						if not corner.has(c):
							var lv := _corner_level(c.x, c.y)
							corner[c] = verts.size()
							verts.append(Vector3(x0 + c.x, lv, z0 + c.y))
						quad.append(corner[c])
					idx.append_array([quad[0], quad[1], quad[2], quad[1], quad[3], quad[2]])
			if idx.is_empty():
				continue
			# A corner no wet cell touches takes the lowest of its quad's others.
			for i in verts.size():
				if verts[i].y == -INF:
					verts[i].y = _lowest_near(verts, idx, i)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			var normals := PackedVector3Array()
			normals.resize(verts.size())
			normals.fill(Vector3.UP)
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mi := MeshInstance3D.new()
			mi.name = "Water_%d_%d" % [cx, cz]
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)


func _lowest_near(verts: PackedVector3Array, idx: PackedInt32Array, i: int) -> float:
	var low := INF
	for t in range(0, idx.size(), 3):
		if idx[t] == i or idx[t + 1] == i or idx[t + 2] == i:
			for k in 3:
				var y := verts[idx[t + k]].y
				if y > -INF:
					low = minf(low, y)
	return low if low < INF else 0.0
#endregion


#region Grass
## How far the lands' grass is drawn, and the side of its drawing chunks.
@export var grass_draw_distance: float = 95.0
@export var grass_chunk: float = 32.0


## The lands' grass: clumps placed by the map's exporter (where the cover is
## grass and flowers, a little under the trees), drawn, swayed and trodden down
## by a [GrassField] of their own.
func _build_grass() -> void:
	var raw := FileAccess.get_file_as_bytes(DIR + "grass.f32.gz")
	var tints_raw := FileAccess.get_file_as_bytes(DIR + "grass_tint.rgba8.gz")
	if raw.is_empty() or tints_raw.is_empty():
		return
	var clumps := raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).to_float32_array()
	var rgba := tints_raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var tints := PackedColorArray()
	tints.resize(int(rgba.size() / 4.0))
	for i in tints.size():
		tints[i] = Color(rgba[i * 4] / 255.0, rgba[i * 4 + 1] / 255.0, rgba[i * 4 + 2] / 255.0)
	var field := GrassField.new()
	field.name = "Grass"
	field.draw_chunk = grass_chunk
	field.draw_distance = grass_draw_distance
	add_child(field)
	field.replace(clumps, tints)


#region Edge
func _build_edge() -> void:
	var r := rim()
	var mid := Vector2((r.x + r.z) * 0.5, (r.y + r.w) * 0.5)
	var size := Vector2(r.z - r.x, r.w - r.y)
	# Walls round the rim, high enough that nothing is thrown over them.
	var walls := [
		[Vector3(r.x - 0.5, 150.0, mid.y), Vector3(1.0, 400.0, size.y + 2.0)],
		[Vector3(r.z + 0.5, 150.0, mid.y), Vector3(1.0, 400.0, size.y + 2.0)],
		[Vector3(mid.x, 150.0, r.y - 0.5), Vector3(size.x + 2.0, 400.0, 1.0)],
		[Vector3(mid.x, 150.0, r.w + 0.5), Vector3(size.x + 2.0, 400.0, 1.0)],
	]
	var body := StaticBody3D.new()
	body.name = "Rim"
	body.collision_layer = 1
	body.collision_mask = 0
	for i in walls.size():
		var box := BoxShape3D.new()
		box.size = walls[i][1]
		var cs := CollisionShape3D.new()
		cs.name = "Wall%d" % i
		cs.shape = box
		cs.position = walls[i][0]
		body.add_child(cs)
	add_child(body)
	_build_beyond(r)


## Land past the rim: from the rim's own heights out and down, under the
## mountains, so looking out from a peak there is country and not sky.
func _build_beyond(r: Vector4) -> void:
	var ring: Array[Vector3] = []
	var step := 10.0
	var x := r.x
	while x < r.z:
		ring.append(Vector3(x, height_at(x, r.y), r.y))
		x += step
	var z := r.y
	while z < r.w:
		ring.append(Vector3(r.z, height_at(r.z, z), z))
		z += step
	x = r.z
	while x > r.x:
		ring.append(Vector3(x, height_at(x, r.w), r.w))
		x -= step
	z = r.w
	while z > r.y:
		ring.append(Vector3(r.x, height_at(r.x, z), z))
		z -= step
	var centre := Vector3((r.x + r.z) * 0.5, 0.0, (r.y + r.w) * 0.5)
	var noise := FastNoiseLite.new()
	noise.seed = 4411
	noise.frequency = 0.004
	# Out along the line from the middle: 60 m (a shoulder), 300 m, and far off.
	var outs := [0.0, 60.0, 300.0, beyond]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for k in outs.size():
		for p in ring:
			var out := Vector3(p.x - centre.x, 0.0, p.z - centre.z)
			var dir := out.normalized()
			# pushed out square to the rim, not radially, so the rings do not cross
			var push := Vector3(signf(dir.x) if absf(p.x - centre.x) >= (r.z - r.x) * 0.5 - 0.01 else 0.0, 0.0,
					signf(dir.z) if absf(p.z - centre.z) >= (r.w - r.y) * 0.5 - 0.01 else 0.0)
			if push == Vector3.ZERO:
				push = dir
			var at: Vector3 = p + push.normalized() * float(outs[k])
			var n := noise.get_noise_2d(at.x, at.z)
			var y := p.y
			match k:
				1:
					y = p.y * 0.85 + 4.0 + n * 10.0
				2:
					y = p.y * 0.55 + 12.0 + n * 30.0
				3:
					y = -20.0
			at.y = y
			verts.append(at)
			cols.append(Color(0.24, 0.29, 0.19).lerp(Color(0.34, 0.36, 0.38), clampf(float(k) / 3.0, 0.0, 1.0)))
	var m := ring.size()
	var idx := PackedInt32Array()
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.ZERO)
	for k in outs.size() - 1:
		for i in m:
			var a := k * m + i
			var b := k * m + (i + 1) % m
			var c := (k + 1) * m + i
			var d := (k + 1) * m + (i + 1) % m
			idx.append_array([a, b, c, b, d, c])
			# faces lit from above whichever way round they were wound
			for tri: Array in [[a, b, c], [b, d, c]]:
				var f: Vector3 = (verts[tri[1]] - verts[tri[0]]).cross(verts[tri[2]] - verts[tri[0]])
				if f.y < 0.0:
					f = -f
				for v: int in tri:
					normals[v] += f
	for i in normals.size():
		normals[i] = normals[i].normalized() if normals[i].length_squared() > 0.0 else Vector3.UP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "Beyond"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
#endregion
