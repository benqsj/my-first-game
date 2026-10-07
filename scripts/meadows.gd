class_name Meadows
extends Node

## Where the grass grows, and the flowers and the reeds, worked out at load for
## the whole map.
##
## The grass used to be a patch written into the scene around the spawn by a
## scatter script: bright lime tufts on the open ground, grass in the middle of
## the wood where the wood had since grown, none at all anywhere else on a map
## that has since tripled in size. Grass grows where grass grows, so this asks
## the level the same questions a walker would:
##
## * **Drifts on open ground.** A slow noise field decides where the meadow is
##   thick and where it thins to bare ground, so it lies in sweeps rather than
##   in rectangles or in an even sprinkle. Clumps come in knots of a few, the
##   way grass seeds, taller in the middle of a drift than at its edge.
## * **The edges of things.** Grass is thickest where nothing is mown and
##   nothing is trodden: along the shoulders of the tracks and at the treeline.
##   The tracks themselves are bare.
## * **Reeds at the water.** A band of tall, darker clumps and bulrushes round
##   the mere and along the bay's shore, just above the waterline.
## * **Thin under the trees.** Deep in the wood it is too dark for more than
##   the odd tuft.
## * **Flowers** in patches of one kind at a time — daisies here, violets
##   there — inside the drifts, not dotted evenly across the map.
## * **Not through things.** Anything solid standing on the spot — a house, a
##   wall, a boulder — and nothing is planted there.
##
## Colour is part of it. The kit's clump is a flat lime; every clump is toned
## (`GrassField.tints`) to a duller, deeper green with a little variation,
## drier and more golden in the open, darker by the water.
##
## Seeded, like the wood, so every peer grows the same field.

const FLOWERS: PackedStringArray = [
	"res://assets/forest/Flower_Daisy_1.obj",
	"res://assets/forest/Flower_Daisy_2.obj",
	"res://assets/forest/Flower_Violet_1.obj",
	"res://assets/forest/Flower_Violet_2.obj",
	"res://assets/forest/Flower_Bellflower_1.obj",
	"res://assets/forest/Flower_Balloon_1.obj",
]
const REEDS: PackedStringArray = [
	"res://assets/forest/Cattail_1.obj",
	"res://assets/forest/Cattail_2.obj",
	"res://assets/forest/Cattail_3.obj",
]

@export var grass: NodePath
@export var forest: NodePath
@export var paths: NodePath
## [Marsh] nodes: the water to keep out of and to line with reeds.
@export var water: Array[NodePath] = []
## The ground to grow on, (min x, min z, size x, size z).
@export var bounds: Rect2 = Rect2(-116.0, -452.0, 232.0, 628.0)
## Metres between the points the field is sampled on. Each point that takes
## grows a knot of clumps, not one.
@export var spacing: float = 3.4
## Most clumps it will plant, however lush the numbers come out.
@export var budget: int = 9000
@export var random_seed: int = 40711
## Whether the meadows flower. Off: the daisies and the rest were clutter.
@export var flowers: bool = false
## The low sward under the meadows (the new look, [Looks]): how many short
## clumps round each meadow or edge clump, and the most there will be.
@export var sward_per_clump: int = 6
@export var sward_budget: int = 72000
## The sward over the open ground too, not only round the meadows: laid in
## broad patches (most of the open ground, gaps where the earth shows) on a
## grid this fine; thinned evenly to [member open_sward_budget] clumps if it
## comes to more. 0 turns it off.
@export var open_sward_spacing: float = 2.1
@export var open_sward_budget: int = 42000
## Past this the flowers and bulrushes are not drawn.
@export var decor_draw_distance: float = 80.0

@export_group("Colour")
## Multiplied over the clump's own lime, in linear colour (the multimesh's
## instance colour is not sRGB). The lime has next to no blue in it, so blue is
## left alone and red and green are taken well down: that is what turns it into
## a grass green, or towards straw where the meadow dries.
@export var meadow_tone: Color = Color(0.34, 0.37, 1.0)
@export var dry_tone: Color = Color(0.52, 0.42, 1.0)
@export var reed_tone: Color = Color(0.27, 0.31, 1.0)
@export var wood_tone: Color = Color(0.24, 0.28, 1.0)

## The field has been grown (or grown again) and handed to the grass.
signal grown

## Where the low sward grows, laid out as [member GrassField.clumps] is, and its
## colours: planned with the meadows, drawn only by a look that wants it.
var sward := PackedFloat32Array()
var sward_tints := PackedColorArray()
## Its own dice, so planning it leaves the meadows exactly as they were.
var _sward_rng := RandomNumberGenerator.new()

## How many were planted, and of what, for anything that wants to check.
var counts: Dictionary = {}

var _drift := FastNoiseLite.new()
var _dry := FastNoiseLite.new()
var _bloom := FastNoiseLite.new()
var _patches := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
## Model path -> transforms, for the flowers and reeds.
var _decor: Dictionary = {}


func _ready() -> void:
	_drift.seed = random_seed
	_drift.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_drift.frequency = 0.026
	_drift.fractal_octaves = 3
	_dry.seed = random_seed + 3
	_dry.frequency = 0.012
	_bloom.seed = random_seed + 9
	_bloom.frequency = 0.05
	_patches.seed = random_seed + 23
	_patches.frequency = 0.035
	_patches.fractal_octaves = 2
	_rng.seed = random_seed
	_sward_rng.seed = random_seed + 17
	# Everything it asks has to have been built first — the wood, the tracks,
	# the water, and the colliders it looks for things standing in the way with.
	_grow.call_deferred()


func _grow() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var field := get_node_or_null(grass) as GrassField
	if field == null:
		return
	var started := Time.get_ticks_usec()
	var wood := get_node_or_null(forest) as Forest
	var tracks := get_node_or_null(paths) as Paths
	var ponds: Array[Marsh] = []
	for path in water:
		var pond := get_node_or_null(path) as Marsh
		if pond != null:
			ponds.append(pond)
	var space := field.get_world_3d().direct_space_state
	var to_field := field.global_transform.affine_inverse()

	var placed := PackedFloat32Array()
	var tints := PackedColorArray()
	var low := PackedFloat32Array()
	var low_tints := PackedColorArray()
	counts = {"meadow": 0, "edge": 0, "reed": 0, "wood": 0, "flowers": 0, "bulrushes": 0}
	var z := bounds.position.y
	var row := 0
	while z <= bounds.end.y:
		var x := bounds.position.x + (spacing * 0.5 if row % 2 else 0.0)
		while x <= bounds.end.x:
			var at := Vector2(x + _rng.randf_range(-0.45, 0.45) * spacing,
					z + _rng.randf_range(-0.45, 0.45) * spacing)
			x += spacing
			var site := _site(at, ponds, tracks, wood)
			if site.is_empty() or _rng.randf() > float(site["chance"]):
				continue
			# A knot of clumps round the point.
			var knot := _rng.randi_range(int(site["knot"].x), int(site["knot"].y))
			for k in knot:
				var spot := at + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 1.1)
				if not _dry_and_open(spot, ponds, tracks, space):
					continue
				var shade := _rng.randf_range(0.9, 1.07)
				var tone: Color = site["tone"]
				var local := to_field * Vector3(spot.x, 0.0, spot.y)
				placed.append(local.x)
				placed.append(local.z)
				placed.append(_rng.randf() * TAU)
				placed.append(_rng.randf_range(0.9, 1.4))
				placed.append(float(site["tall"]) * _rng.randf_range(0.85, 1.15))
				tints.append(Color(tone.r * shade, tone.g * shade, tone.b * shade))
				counts[site["kind"]] = int(counts[site["kind"]]) + 1
				if site.has("dry"):
					_plan_sward(spot, float(site["dry"]), to_field, low, low_tints, tracks)
			_decorate(at, site, ponds, tracks, space)
		z += spacing * sqrt(3.0) * 0.5
		row += 1

	# Over budget, the whole field is thinned evenly — not cut off at whatever
	# row the count ran out on, which would leave one end of the map bare.
	var total := tints.size()
	if total > budget:
		var keep_p := PackedFloat32Array()
		var keep_t := PackedColorArray()
		var keep := float(budget) / float(total)
		for i in total:
			if _rng.randf() < keep:
				keep_t.append(tints[i])
				for k in GrassField.STRIDE:
					keep_p.append(placed[i * GrassField.STRIDE + k])
		placed = keep_p
		tints = keep_t
	field.replace(placed, tints)
	_build_decor()
	_open_sward(ponds, tracks, wood, space, to_field, low, low_tints)
	_thin_sward(low, low_tints)
	grown.emit()
	print("Meadows: %s, %d clumps, in %.0f ms" % [counts, placed.size() / GrassField.STRIDE,
			(Time.get_ticks_usec() - started) / 1000.0])


## What would grow at a point, and how likely: {kind, chance, tall, tone, knot},
## or empty where nothing does.
func _site(at: Vector2, ponds: Array[Marsh], tracks: Paths, wood: Forest) -> Dictionary:
	var shore := 99.0
	for pond in ponds:
		if pond.height_at(at.x, at.y) < pond.water_level + 0.06:
			return {}
		shore = minf(shore, _to_water(pond, at))
	if tracks != null and tracks.near(at, 0.35):
		return {}
	if VillageProps.in_plaza(at, 0.5):
		return {}
	if NecroPlaces.blocks(at):
		return {}
	if shore < 5.0:
		return {"kind": &"reed", "chance": 0.85 - shore * 0.12,
				"tall": _rng.randf_range(1.4, 1.9), "tone": reed_tone, "knot": Vector2i(3, 5)}
	var cover := 0.0
	if wood != null and not wood.is_clear(at):
		cover = wood._wood(at)
	if cover > 0.65:
		return {"kind": &"wood", "chance": 0.05, "tall": 0.8, "tone": wood_tone,
				"knot": Vector2i(1, 2)}
	var drift := _drift.get_noise_2d(at.x, at.y)
	# The meadow proper: nothing below the drift's floor, then it thickens fast,
	# so a drift has an edge you can see rather than fading into a sprinkle.
	var meadow := smoothstep(0.02, 0.3, drift) * 0.9
	var edge := 0.0
	if cover > 0.02:
		edge = 0.8 * clampf(1.0 - absf(cover - 0.3) / 0.35, 0.0, 1.0)
	if tracks != null and tracks.near(at, 3.2):
		edge = maxf(edge, 0.55)
	var chance := maxf(meadow, edge)
	if chance < 0.12:
		return {}
	var dryness := clampf(_dry.get_noise_2d(at.x, at.y) * 0.9 + 0.3, 0.0, 1.0) * (1.0 - cover)
	return {
		"kind": &"edge" if edge > meadow else &"meadow",
		"chance": chance,
		"tall": lerpf(0.75, 1.5, smoothstep(0.0, 0.6, maxf(drift, edge - 0.3))),
		"tone": meadow_tone.lerp(dry_tone, dryness),
		"knot": Vector2i(2, 4),
		"drift": drift,
		"dry": dryness,
	}


## A few short clumps round a meadow clump: the low, mixed sward the new look
## fills a meadow with. Their colour is in the model (a blade at a time); the
## tint only pulls a patch towards hay where the meadow is dry.
func _plan_sward(spot: Vector2, dryness: float, to_field: Transform3D,
		low: PackedFloat32Array, low_tints: PackedColorArray, tracks: Paths = null) -> void:
	for k in sward_per_clump:
		var at := spot + Vector2.from_angle(_sward_rng.randf() * TAU) * _sward_rng.randf_range(0.2, 1.8)
		# Not on the square's cobbles, nor out in the worn middle of a track.
		if VillageProps.in_plaza(at) or (tracks != null and tracks.near(at, -0.6)):
			continue
		var local := to_field * Vector3(at.x, 0.0, at.y)
		low.append(local.x)
		low.append(local.z)
		low.append(_sward_rng.randf() * TAU)
		low.append(_sward_rng.randf_range(0.9, 1.45))
		low.append(_sward_rng.randf_range(0.75, 1.25))
		var shade := _sward_rng.randf_range(0.86, 1.06)
		var tint := Color(1.0, 1.0, 1.0).lerp(Color(1.14, 1.0, 0.7), dryness * 0.8)
		low_tints.append(Color(tint.r * shade, tint.g * shade, tint.b * shade))


## The sward over the open ground, in patches: everywhere that is not wood
## (a clearing cut in one counts as open), water, track, the square's cobbles or under something standing (looked for
## only in the village, where the houses are — out in the fields there is
## nothing to find and a ray a clump would cost the load a second).
func _open_sward(ponds: Array[Marsh], tracks: Paths, wood: Forest,
		space: PhysicsDirectSpaceState3D, to_field: Transform3D,
		low: PackedFloat32Array, low_tints: PackedColorArray) -> void:
	if open_sward_spacing <= 0.0 or open_sward_budget <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + 29
	var built := World.VILLAGE.grow(10.0)
	var laid := 0
	var z := bounds.position.y
	while z <= bounds.end.y:
		var x := bounds.position.x
		while x <= bounds.end.x:
			var at := Vector2(x, z) + Vector2(rng.randf(), rng.randf()) * open_sward_spacing
			x += open_sward_spacing
			var patch := _patches.get_noise_2d(at.x, at.y)
			if patch < -0.18 or rng.randf() > 0.55 + patch:
				continue
			# (the margins take in the 0.8 m the two clumps spread from the point)
			if VillageProps.in_plaza(at, 1.3) or (tracks != null and tracks.near(at, 1.1)):
				continue
			var cover := 0.0
			if wood != null and not wood.is_clear(at):
				cover = maxf(wood._wood(at), wood._hill_wood(at))
			if cover > 0.3:
				continue
			var wet := false
			for pond in ponds:
				if pond.height_at(at.x, at.y) < pond.water_level + 0.3:
					wet = true
					break
			if wet:
				continue
			if built.has_point(at) and not _dry_and_open(at, ponds, tracks, space):
				continue
			# Two clumps a point: half the points looked at for the same sward.
			var dryness := clampf(_dry.get_noise_2d(at.x, at.y) * 0.9 + 0.3, 0.0, 1.0)
			var tint := Color(1.0, 1.0, 1.0).lerp(Color(1.14, 1.0, 0.7), dryness * 0.8)
			for k in 2:
				var spot := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.8)
				var local := to_field * Vector3(spot.x, 0.0, spot.y)
				low.append(local.x)
				low.append(local.z)
				low.append(rng.randf() * TAU)
				low.append(rng.randf_range(0.9, 1.45))
				low.append(rng.randf_range(0.7, 1.15))
				var shade := rng.randf_range(0.84, 1.04)
				low_tints.append(Color(tint.r * shade, tint.g * shade, tint.b * shade))
				laid += 1
		z += open_sward_spacing
	# Over its budget, thinned evenly (not cut off at a row).
	if laid > open_sward_budget:
		var keep := float(open_sward_budget) / float(laid)
		var first := low_tints.size() - laid
		var kept_p := low.slice(0, first * GrassField.STRIDE)
		var kept_t := low_tints.slice(0, first)
		for i in range(first, low_tints.size()):
			if rng.randf() < keep:
				kept_t.append(low_tints[i])
				for k in GrassField.STRIDE:
					kept_p.append(low[i * GrassField.STRIDE + k])
		low.clear()
		low.append_array(kept_p)
		low_tints.clear()
		low_tints.append_array(kept_t)
		laid = kept_t.size() - first
	counts["open sward"] = laid


func _thin_sward(low: PackedFloat32Array, low_tints: PackedColorArray) -> void:
	var total := low_tints.size()
	if total <= sward_budget:
		sward = low
		sward_tints = low_tints
		return
	var keep := float(sward_budget) / float(total)
	sward = PackedFloat32Array()
	sward_tints = PackedColorArray()
	for i in total:
		if _sward_rng.randf() < keep:
			sward_tints.append(low_tints[i])
			for k in GrassField.STRIDE:
				sward.append(low[i * GrassField.STRIDE + k])


func _dry_and_open(spot: Vector2, ponds: Array[Marsh], tracks: Paths,
		space: PhysicsDirectSpaceState3D) -> bool:
	var ground := 0.0
	for pond in ponds:
		var h := pond.height_at(spot.x, spot.y)
		if h < pond.water_level + 0.06:
			return false
		ground = minf(ground, h)
	if tracks != null and tracks.near(spot, 0.25):
		return false
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(spot.x, 6.0, spot.y), Vector3(spot.x, -3.0, spot.y), 1))
	return hit.is_empty() or (hit["position"] as Vector3).y <= ground + 0.12


## Flowers in the drifts, a patch of one kind at a time, and bulrushes in the
## reeds.
func _decorate(at: Vector2, site: Dictionary, ponds: Array[Marsh], tracks: Paths,
		space: PhysicsDirectSpaceState3D) -> void:
	var kind: StringName = site["kind"]
	if kind == &"reed":
		if _rng.randf() < 0.45:
			for k in _rng.randi_range(2, 5):
				var spot := at + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.2, 1.3)
				if _dry_and_open(spot, ponds, tracks, space):
					_add(REEDS[_rng.randi() % REEDS.size()], spot, _rng.randf_range(2.2, 3.2))
					counts["bulrushes"] = int(counts["bulrushes"]) + 1
		return
	if kind != &"meadow" or not flowers:
		return
	var bloom := _bloom.get_noise_2d(at.x, at.y)
	if bloom < 0.25 or _rng.randf() > 0.7:
		return
	# Which flower grows in this patch: the same noise, read coarsely.
	var pick := clampi(int((_dry.get_noise_2d(at.x * 3.0, at.y * 3.0) * 0.5 + 0.5) * FLOWERS.size()),
			0, FLOWERS.size() - 1)
	for k in _rng.randi_range(2, 6):
		var spot := at + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.1, 1.4)
		if _dry_and_open(spot, ponds, tracks, space):
			_add(FLOWERS[pick], spot, _rng.randf_range(1.3, 2.0))
			counts["flowers"] = int(counts["flowers"]) + 1


func _add(path: String, spot: Vector2, size: float) -> void:
	var list: Array = _decor.get(path, [])
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size)
	list.append(Transform3D(basis, Vector3(spot.x, Terrain.height(spot.x, spot.y), spot.y)))
	_decor[path] = list


## One multimesh per model per 48 m square, so the far ones are culled.
func _build_decor() -> void:
	var holder := Node3D.new()
	holder.name = "Blooms"
	add_child(holder)
	var chunk := 48.0
	for path: String in _decor:
		if not ResourceLoader.exists(path):
			continue
		var mesh := load(path) as Mesh
		if mesh == null:
			continue
		var buckets: Dictionary = {}
		for t: Transform3D in _decor[path]:
			var key := Vector2i(floori(t.origin.x / chunk), floori(t.origin.z / chunk))
			var list: Array = buckets.get(key, [])
			list.append(t)
			buckets[key] = list
		for key: Vector2i in buckets:
			var centre := Vector3((key.x + 0.5) * chunk, 0.0, (key.y + 0.5) * chunk)
			var list: Array = buckets[key]
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = list.size()
			for i in list.size():
				var t: Transform3D = list[i]
				t.origin -= centre
				multi.set_instance_transform(i, t)
			var node := MultiMeshInstance3D.new()
			node.multimesh = multi
			node.position = centre
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visibility_range_end = decor_draw_distance
			node.visibility_range_end_margin = 8.0
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			holder.add_child(node)


## Roughly how far a dry point is from the water's edge, in metres: its height
## above the water turned back into distance up the shore slope, plus however far
## outside the rim it stands.
static func _to_water(pond: Marsh, at: Vector2) -> float:
	var h := pond.height_at(at.x, at.y)
	var d := (h - pond.water_level) / maxf(pond.bed_depth, 0.01) * pond.shore_width
	var reach := pond._mere_reach(at)
	if reach > 1.0:
		d += (reach - 1.0) * minf(pond.mere_radii.x, pond.mere_radii.y)
	return d
