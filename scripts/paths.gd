class_name Paths
extends Node3D

## The tracks people have worn between the places on the map: from the spawn to
## the settlement's gate and down its street, into the wood to the first glade,
## and south past Arkdeva's glade to the mere and on to the harbour.
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

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 70111
	_noise.frequency = 0.08
	for i in tracks.size():
		var mesh := _ribbon(tracks[i])
		if mesh == null:
			continue
		var node := MeshInstance3D.new()
		node.name = "Track_%d" % i
		node.mesh = mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


## Whether a point is within `margin` metres of the edge of any track.
func near(at: Vector2, margin: float = 0.0) -> bool:
	var reach := width * 0.5 + margin
	var reach2 := reach * reach
	for line in tracks:
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var ab := b - a
			var t := clampf((at - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if at.distance_squared_to(a + ab * t) < reach2:
				return true
	return false


func _height(x: float, z: float) -> float:
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
		var half := width * 0.5 * (0.85 + 0.3 * (_noise.get_noise_1d(run) * 0.5 + 0.5))
		# Tracks thin out where they begin and end rather than stopping square.
		var ends := clampf(minf(run, total - run) / 4.0, 0.25, 1.0)
		for k in across.size():
			var q := p + side * across[k] * half * ends
			var y := _height(q.x, q.y) + 0.035
			st.set_color(Color(1.0, 1.0, 1.0, alpha[k] * (0.55 + 0.45 * ends)))
			st.set_uv(Vector2(across[k] * 0.5 + 0.5, run / (width * 1.5)))
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
