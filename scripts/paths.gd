class_name Paths
extends Node3D

## The tracks people have worn between the places on the map: from the spawn to
## the settlement's gate and down its street, into the wood to the first glade,
## and south past Arkdeva's glade to the mere and on to the bay's pier.
##
## The map was a set of places dropped onto one green plain — every one of them
## the same distance from nowhere. A worn track says somebody walks from here
## to there, and it is most of what makes a clearing read as a village green and
## a gap in the trees read as a way through. They also tell a player where to go.
##
## Each track is a polyline in `tracks`, (x, z) in metres. It is drawn as one
## ribbon laid on the ground, fading out at its edges and wandering a little in
## width so it does not look ruled, and the wood keeps off it ([Forest] asks
## [method near]). Where a track crosses ground that dips (the marsh, the bay's
## shore) it follows that ground's height, read off the [Marsh] nodes in
## `ground`.

@export var tracks: Array[PackedVector2Array] = []
## Across a track, in metres.
@export var width: float = 2.6
@export var material: Material
## [Marsh] nodes whose ground the tracks follow where it is not flat.
@export var ground: Array[NodePath] = []
## Metres between the ribbon's cross-sections.
@export var step: float = 1.5

## Across a road in the lands round the core ([Lands]), in metres.
@export var road_width: float = 3.4

## The roads of the lands (each land's way from its gate to its boss, and the
## spurs to its village), read from the map at load. Drawn and kept clear of
## trees like [member tracks], but not flattened into the core's ground: the
## map already cut them into the lands.
var roads: Array[PackedVector2Array] = []

var _noise := FastNoiseLite.new()
var _width: float = 0.0


func _ready() -> void:
	_noise.seed = 70111
	_noise.frequency = 0.08
	_width = width
	for i in tracks.size():
		_draw("Track_%d" % i, tracks[i])
	roads = lands_roads()
	_index_roads()
	_width = road_width
	for i in roads.size():
		_draw("Road_%d" % i, roads[i])
	_width = width


func _draw(node_name: String, line: PackedVector2Array) -> void:
	var mesh := _ribbon(line)
	if mesh == null:
		return
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## The lands' roads as the map has them ([x, z, y] every few metres), or none
## when there are no lands.
static func lands_roads() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var lands := Lands.current
	if lands == null or not is_instance_valid(lands) or lands.info.is_empty():
		return out
	var lines: Array = []
	var regions: Dictionary = lands.info.get("regions", {})
	for key: String in regions:
		lines.append(regions[key].get("route", []))
	var spurs: Dictionary = lands.info.get("spurs", {})
	for key: String in spurs:
		lines.append(spurs[key])
	# and the streets of the city (Gulansharo), [x, z] a point
	var city: Dictionary = lands.info.get("city", {})
	for street: Array in city.get("streets", []):
		lines.append(street)
	for pts: Array in lines:
		var line := PackedVector2Array()
		for p: Array in pts:
			line.append(Vector2(float(p[0]), float(p[1])))
		if line.size() >= 2:
			out.append(line)
	return out


## Whether a point is within `margin` metres of the edge of any track.
func near(at: Vector2, margin: float = 0.0) -> bool:
	if _near_any(tracks, at, width * 0.5 + margin):
		return true
	if _road_segments.is_empty():
		return false
	# The roads are long: only the segments filed under this point's cell.
	var reach := road_width * 0.5 + margin
	var reach2 := reach * reach
	var lo := Vector2i(floori((at.x - reach) / ROAD_CELL), floori((at.y - reach) / ROAD_CELL))
	var hi := Vector2i(floori((at.x + reach) / ROAD_CELL), floori((at.y + reach) / ROAD_CELL))
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var list: PackedInt32Array = _road_cells.get(Vector2i(cx, cz), PackedInt32Array())
			for k in list:
				var a := _road_segments[k * 2]
				var b := _road_segments[k * 2 + 1]
				var ab := b - a
				var t := clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				if at.distance_squared_to(a + ab * t) < reach2:
					return true
	return false


## Side of the grid the roads' segments are filed on, for [method near].
const ROAD_CELL := 24.0
## Each road segment's two ends, one after the other.
var _road_segments := PackedVector2Array()
## Grid cell -> the segments that pass through it.
var _road_cells: Dictionary = {}


func _index_roads() -> void:
	_road_segments.clear()
	_road_cells.clear()
	for line in roads:
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var k := int(_road_segments.size() / 2.0)
			_road_segments.append(a)
			_road_segments.append(b)
			var lo := Vector2i(floori(minf(a.x, b.x) / ROAD_CELL), floori(minf(a.y, b.y) / ROAD_CELL))
			var hi := Vector2i(floori(maxf(a.x, b.x) / ROAD_CELL), floori(maxf(a.y, b.y) / ROAD_CELL))
			for cz in range(lo.y, hi.y + 1):
				for cx in range(lo.x, hi.x + 1):
					var cell := Vector2i(cx, cz)
					var list: PackedInt32Array = _road_cells.get(cell, PackedInt32Array())
					list.append(k)
					_road_cells[cell] = list


static func _near_any(lines: Array[PackedVector2Array], at: Vector2, reach: float) -> bool:
	var reach2 := reach * reach
	for line in lines:
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			# a cheap box test first: the roads are long and mostly far away
			if at.x < minf(a.x, b.x) - reach or at.x > maxf(a.x, b.x) + reach \
					or at.y < minf(a.y, b.y) - reach or at.y > maxf(a.y, b.y) + reach:
				continue
			var ab := b - a
			var t := clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if at.distance_squared_to(a + ab * t) < reach2:
				return true
	return false


func _height(x: float, z: float) -> float:
	# On the old square the land's own relief ([Terrain]); south of it, the
	# marsh strips' dished ground.
	if Terrain.current != null and Terrain.current.contains(x, z):
		return Terrain.height(x, z)
	# Out in the lands, their ground (a touch higher: the drawn grid is coarser
	# than a ribbon's sections, and a slope would swallow it).
	if Lands.current != null and Lands.current.covers(x, z):
		return Lands.height(x, z) + 0.06
	var lowest := 0.0
	for path in ground:
		var marsh := get_node_or_null(path) as Marsh
		if marsh != null:
			lowest = minf(lowest, marsh.height_at(x, z))
	return lowest


## A strip along the line, a cross-section every `step` metres, with vertex
## alpha running to nothing at both edges.
func _ribbon(line: PackedVector2Array) -> ArrayMesh:
	if line.size() < 2:
		return null
	# Resample evenly, so the bends are as smooth as the straights.
	var points := PackedVector2Array()
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n:
			points.append(a.lerp(b, float(k) / n))
	points.append(line[line.size() - 1])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run := 0.0
	var total := _length(points)
	# Five across: edge, shoulder, middle, shoulder, edge.
	var across: Array[float] = [-1.0, -0.55, 0.0, 0.55, 1.0]
	var alpha: Array[float] = [0.0, 0.85, 1.0, 0.85, 0.0]
	for i in points.size():
		var p := points[i]
		var dir := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x)
		if i > 0:
			run += p.distance_to(points[i - 1])
		var half := _width * 0.5 * (0.85 + 0.3 * (_noise.get_noise_1d(run) * 0.5 + 0.5))
		# Tracks thin out where they begin and end rather than stopping square.
		var ends := clampf(minf(run, total - run) / 4.0, 0.25, 1.0)
		for k in across.size():
			var q := p + side * across[k] * half * ends
			var y := _height(q.x, q.y) + 0.035
			st.set_color(Color(1.0, 1.0, 1.0, alpha[k] * (0.55 + 0.45 * ends)))
			st.set_uv(Vector2(across[k] * 0.5 + 0.5, run / (_width * 1.5)))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, y, q.y))
	var cols := across.size()
	for i in points.size() - 1:
		for k in cols - 1:
			var a := i * cols + k
			var b := a + 1
			var c := a + cols
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_tangents()
	return st.commit()


static func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total
