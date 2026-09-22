class_name Forest
extends Node3D

## Grows the woodland the level sits in, out of one seed and a handful of shapes.
##
## Three thousand trees cannot be three thousand nodes. The scatter already in
## this level puts every grass clump down as its own instanced scene, and at
## seventeen hundred of them that is the ceiling — another few thousand trunks
## placed the same way would be several thousand draw calls and a scene file
## nobody can read. So the wood is built the other way round:
##
## * **Drawn** by [MultiMeshInstance3D]. One per species per chunk, which is one
##   draw call for every oak in a sixty-metre square rather than one per oak.
## * **Chunked** on a grid, so the renderer throws away everything behind the
##   camera in whole squares, and so a species that does not grow in a given
##   square costs nothing there at all.
## * **Collided** through shape owners on a single [StaticBody3D] — a trunk needs
##   a cylinder, not a node, and a thousand nodes that never process are still a
##   thousand nodes to build, transform and tear down.
## * **Placed** from a seeded [RandomNumberGenerator] and two noise fields, so
##   every peer in a multiplayer game grows the identical wood without a byte of
##   it crossing the network.
##
## **The wood is one wood, on one side of the map.** It used to be a ring around
## the play area, thinning outwards, and a ring reads as trees having been
## sprinkled over the ground rather than as a forest — you are never in it and
## never out of it. So the map is divided instead: a solid mass of trees to the
## west, the settlement and its fields to the east, and open ground between them
## where the greybox core is. The boundary is a straight line with a noise
## wobble on it, which gives a treeline you can stand at the edge of.
##
## Species are regional within that: a low-frequency noise field picks which
## conifer or which broadleaf grows where, so the wood has a pine end and an oak
## end and stands of dead timber between them, rather than every species in the
## kit shuffled together. That is a look, and it is also what keeps the per-chunk
## draw call count down — a chunk holds two or three species, not ten.
##
## Nothing here is written into the scene file. The wood is a function of
## `random_seed` and the tables below, which means it is re-rolled by changing a
## number rather than by regenerating ten thousand lines of `.tscn`.

## How each group of plants is laid out.
##
## `spacing` is the lattice it is sampled on, in metres — the single biggest dial
## on what the group costs, since the count goes as 1/spacing². `chance` is how
## much of the coverage at a sample survives into a plant, so a group can be
## thick in the deep wood and absent at its rim. `biome` tags a species to one of
## the two halves of the map, or to 2 for the odd-one-out that is wanted thinly
## everywhere rather than in a region of its own.
const CANOPY := {
	"spacing": 5.0,
	"chance": 0.95,
	"models": [
		# The oak end of the wood.
		{"path": "res://assets/forest/Tree_Oak_1.obj", "scale": Vector2(1.9, 2.7), "biome": 0},
		{"path": "res://assets/forest/Tree_Oak_4.obj", "scale": Vector2(1.9, 2.8), "biome": 0},
		{"path": "res://assets/forest/Tree_Oak_7.obj", "scale": Vector2(1.8, 2.6), "biome": 0},
		# The conifer end.
		{"path": "res://assets/forest/Tree_Pine_2.obj", "scale": Vector2(1.8, 3.0), "biome": 1},
		{"path": "res://assets/forest/Tree_Pine_5.obj", "scale": Vector2(1.9, 3.1), "biome": 1},
		{"path": "res://assets/forest/Tree_Cedar_2.obj", "scale": Vector2(2.1, 3.2), "biome": 1},
		# Dead timber, in its own stands rather than dotted through the rest.
		{"path": "res://assets/forest/Tree_Bare_2.obj", "scale": Vector2(1.3, 2.1), "biome": 2},
		{"path": "res://assets/forest/Tree_Bare_5.obj", "scale": Vector2(1.3, 2.0), "biome": 2},
		{"path": "res://assets/forest/Tree_Oak_6.obj", "scale": Vector2(1.8, 2.6), "biome": 2},
	],
}

## Deliberately thin. Bushes were the second most numerous thing on the map and
## almost none of them were ever looked at: they sit under a canopy, they are a
## metre across, and there were twelve hundred of them. A few hundred, gathered
## where the wood is thickest, read as undergrowth; twelve hundred read as moss.
const UNDERGROWTH := {
	"spacing": 5.6,
	"chance": 0.3,
	"models": [
		{"path": "res://assets/forest/Bush_1.obj", "scale": Vector2(1.1, 2.0), "biome": 0},
		{"path": "res://assets/forest/Bush_3.obj", "scale": Vector2(1.2, 2.1), "biome": 1},
		{"path": "res://assets/forest/Bush_5.obj", "scale": Vector2(1.1, 1.9), "biome": 2},
	],
}

## Stones, fallen trunks and mushrooms: what makes a floor read as a forest floor
## rather than as a field with trees standing in it. Only ever seen close up, so
## it is drawn close up and is thin on the ground.
const LITTER := {
	"spacing": 6.4,
	"chance": 0.42,
	"models": [
		{"path": "res://assets/forest/Rock_2.obj", "scale": Vector2(0.8, 2.2), "biome": 0},
		{"path": "res://assets/forest/Log_2.obj", "scale": Vector2(1.2, 2.2), "biome": 0},
		{"path": "res://assets/forest/Stump_2.obj", "scale": Vector2(1.3, 2.4), "biome": 1},
		{"path": "res://assets/forest/Grass_Clump_3.obj", "scale": Vector2(1.8, 3.4), "biome": 1},
		{"path": "res://assets/forest/Mushroom_Red_Spotted.obj", "scale": Vector2(1.1, 2.0), "biome": 2},
		{"path": "res://assets/forest/Flower_Bellflower_2.obj", "scale": Vector2(1.2, 2.2), "biome": 2},
	],
}

## Trees that were *planted*, not grown: lines of them along the boundaries of
## the settlement's fields and its lanes.
##
## The open half of the map would otherwise be bare, and filling it by loosening
## the treeline would put the wood back where it was taken from. A hedgerow says
## something different from a wood — somebody marked this field out — and it is
## what makes the east read as farmed rather than as empty.
const HEDGEROW := {
	"spacing": 7.5,
	"wander": 1.6,
	"models": [
		{"path": "res://assets/forest/Tree_Oak_4.obj", "scale": Vector2(1.6, 2.2)},
		{"path": "res://assets/forest/Tree_Oak_6.obj", "scale": Vector2(1.5, 2.1)},
		{"path": "res://assets/forest/Tree_Oak_1.obj", "scale": Vector2(1.5, 2.0)},
	],
}

## The lines themselves, as polylines in metres. Plain arrays of [Vector2] rather
## than [PackedVector2Array]s: the packed one has to be *constructed*, and a
## constructor call cannot sit in a `const`.
const HEDGEROWS: Array[Array] = [
	# The two long field boundaries the settlement sits between.
	[Vector2(26, 18), Vector2(62, 15), Vector2(102, 19)],
	[Vector2(28, 70), Vector2(66, 73), Vector2(104, 69)],
	# A windbreak along the far side of the fields.
	[Vector2(106, 22), Vector2(109, 46), Vector2(106, 66)],
	# The lane down from the settlement to the greybox core.
	[Vector2(30, 6), Vector2(58, -2), Vector2(92, -8)],
	# And the rest of the farmed ground, north and south of the settlement.
	[Vector2(6, 84), Vector2(44, 94), Vector2(84, 92)],
	[Vector2(16, 96), Vector2(20, 72), Vector2(14, 48)],
	[Vector2(72, -30), Vector2(98, -46), Vector2(108, -74)],
	[Vector2(24, -46), Vector2(58, -56), Vector2(86, -52)],
	[Vector2(30, -22), Vector2(52, -26), Vector2(70, -22)],
	[Vector2(96, -6), Vector2(104, -24), Vector2(100, -44)],
	[Vector2(40, -84), Vector2(76, -90), Vector2(104, -96)],
]

## Where the wood does not grow, whatever the treeline says: (x, z, radius).
##
## Short, now that the wood is one mass on one side. The settlement and its
## fields are on the other side of the treeline and need no zone of their own;
## what is left is the greybox core, the props standing in it, and the glades the
## creatures are met in — which have to be *inside* the wood to be glades.
const CLEARINGS: Array[Vector3] = [
	Vector3(0.0, 0.0, 30.0),      # the greybox core: stairs, ramp, pillars, spawn
	Vector3(-18.5, -16.0, 11.0),  # the house
	Vector3(-13.0, -11.0, 6.0),   # the cart
	Vector3(-20.0, 16.0, 6.0),    # the big rocks, which are cover worth keeping
	Vector3(-22.0, 2.0, 6.0),
	Vector3(-38.0, -22.0, 6.0),
	Vector3(-46.0, 30.0, 6.0),
	# Glades the creatures are met in. Only a handful are placed by hand — the
	# density field already opens the wood up here and there, and every zone cut
	# out of it is a hole in the thing being built.
	Vector3(-58.0, -14.0, 14.0),
	Vector3(-46.0, 54.0, 13.0),
	Vector3(-84.0, 26.0, 13.0),
	Vector3(-72.0, -58.0, 13.0),
	Vector3(-26.0, -74.0, 13.0),
	Vector3(-100.0, 76.0, 12.0),
	# Camps the imps hold (World.CAMPS). The two above at (-72, -58) and
	# (-100, 76) are theirs too.
	Vector3(-96.0, -8.0, 10.0),
	Vector3(-72.0, 96.0, 10.0),
	Vector3(-104.0, -50.0, 9.0),
	Vector3(-50.0, -100.0, 9.0),
	Vector3(-92.0, 50.0, 10.0),
	Vector3(-58.0, -36.0, 10.0),
	# And the puglins', out on the open side, clear of the hedgerows.
	Vector3(40.0, -70.0, 9.0),
	Vector3(88.0, -68.0, 9.0),
	Vector3(40.0, 108.0, 9.0),
	# The settlement. It sits on the open side and the treeline would not reach
	# it anyway, but the hedgerows are planted by hand and would run straight
	# through the street without this.
	Vector3(64.0, 43.0, 26.0),
]

@export_group("Layout")
## Change this and the whole wood is re-rolled. Fixed rather than randomised: the
## same seed has to grow the same wood on every peer, or players would be walking
## into trees nobody else can see.
@export var random_seed: int = 90238411
## Half the side of the ground plane. Nothing is planted beyond this.
@export var half_extent: float = 116.0
## How far in from the boundary the wood stops, so no trunk grows through a wall.
@export var edge_margin: float = 3.0

## Which way the wood lies, as a direction pointing *into* it. West and a little
## south, so the settlement gets the east and the morning sun comes over the
## trees rather than out of them.
@export var forest_heading: Vector2 = Vector2(-0.94, -0.34)
## How far along that heading the treeline stands, in metres from the middle of
## the map. Larger pushes the wood further west and leaves more open ground;
## negative brings its edge back across the middle.
@export var treeline: float = -10.0
## How far the edge of the wood wanders either side of that line, in metres. A
## straight treeline reads as a hedge somebody planted.
@export var treeline_wander: float = 18.0
## Over how many metres the wood thickens from nothing to full at its edge.
@export var treeline_fade: float = 18.0
## Below this the density field is a glade rather than wood. The field runs -1 to
## 1 and is bell-shaped about zero, so this is well below the middle: a little
## under a fifth of the wood comes out as openings.
@export var glade_cut: float = -0.7
## Side of a chunk, in metres.
##
## This is a trade, and which way it goes was measured rather than guessed. A
## smaller chunk culls more finely; a larger one is fewer draw calls, and with
## four shadow cascades every visible chunk costs up to five of them. Standing at
## the spawn the level draws 2 100 times for 630 000 triangles — which is to say
## it is bound by the number of things drawn and not by how much is in them — so
## the chunks are wide. Narrowing them from 64 m to 44 m cost 300 draw calls
## there and saved nothing measurable anywhere.
@export var chunk_size: float = 64.0

@export_group("Performance")
## How far the canopy is still drawn. Generous: being able to see the far side of
## a wood is the point of it, and a chunk of trunks is one draw call.
@export var tree_draw_distance: float = 260.0
@export var undergrowth_draw_distance: float = 95.0
## Ground litter is small, and past fifty metres it is a smear. Cut early.
@export var litter_draw_distance: float = 52.0
## Whether the canopy goes into the sun's shadow map. Worth it — the dapple is
## most of what sells a wood — but it is the most expensive switch on this node.
@export var trees_cast_shadows: bool = true
## Level-of-detail eagerness for the multimeshes, as a multiplier on the
## viewport's threshold. Below 1 drops to a coarser mesh sooner.
@export var lod_bias: float = 0.6
## Closest two trunks may stand, in metres. The lattice already keeps them
## roughly apart, but the jitter that stops the wood looking planted can put two
## on top of one another — and two trunks a foot apart is a wall with a tree
## drawn on it. Anything that lands closer than this to a trunk already standing
## is dropped.
@export var min_trunk_gap: float = 3.2
## Side of a collision cell, in metres. Each gets its own body, which is what
## keeps a query from having to look at every trunk on the map — see `_add_trunk`
## for what that cost before it was split.
@export var collider_chunk: float = 22.0
## Trunks thinner than this are not given a collider: a sapling the player can
## brush past reads better than a bollard.
@export var min_collider_radius: float = 0.22
## How much of the measured trunk a collider covers. Under 1 on purpose — a
## cylinder cut to the widest point of a flared base catches the player a foot
## away from the bark.
@export var collider_shrink: float = 0.78

## How many of each group were planted, for anything that wants to check.
var counts: Dictionary = {}

var _rng := RandomNumberGenerator.new()
## Picks which species of a group grows where. Low frequency on purpose: the
## point is a pine side of the map and an oak side, not per-tree confetti.
var _biome := FastNoiseLite.new()
## Breaks the treeline up, so the wood has glades and thickets in it.
var _density := FastNoiseLite.new()
## Wanders the edge of the wood, so the treeline is ragged rather than ruled.
var _edge := FastNoiseLite.new()

var _trunks: Node3D
## Collision cell -> the body holding the trunks that grow in it.
var _bodies: Dictionary = {}
## Path -> the loaded mesh, with whatever material the importer worked out from
## the `.mtl`. Shared by every chunk, so an oak is one mesh and one material for
## the whole map however many chunks it grows in.
var _meshes: Dictionary = {}
## Radius, snapped -> the one cylinder every trunk that thick collides with.
var _shape_pool: Dictionary = {}
## Mesh path -> how thick that model is at the base, in the model's own units.
var _radius_cache: Dictionary = {}
## Gap-grid cell -> where the trunks already planted in it stand.
var _standing: Dictionary = {}


func _ready() -> void:
	var started := Time.get_ticks_usec()
	_rng.seed = random_seed
	_biome.seed = random_seed
	_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_biome.frequency = 0.008
	_density.seed = random_seed + 7717
	_density.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_density.frequency = 0.021
	_density.fractal_octaves = 2
	_edge.seed = random_seed + 4133
	_edge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	# Long wavelength: the treeline should bulge and bay over tens of metres, not
	# fray from one tree to the next.
	_edge.frequency = 0.007
	_edge.fractal_octaves = 2

	_trunks = Node3D.new()
	_trunks.name = "Trunks"
	add_child(_trunks)

	_grow("Canopy", CANOPY, tree_draw_distance, trees_cast_shadows, true)
	_grow("Undergrowth", UNDERGROWTH, undergrowth_draw_distance, false, false)
	_grow("Litter", LITTER, litter_draw_distance, false, false)
	_grow_lines("Hedgerows", HEDGEROW, HEDGEROWS)

	print("Forest: %s, %d trunks over %d bodies (%d distinct shapes), in %.1f ms" % [
			counts, trunk_count(), _bodies.size(), _shape_pool.size(),
			(Time.get_ticks_usec() - started) / 1000.0])


## Whether a point is somewhere the wood was told to keep out of. For anything
## placing creatures or props that wants to land in the open.
func is_clear(at: Vector2) -> bool:
	for zone in CLEARINGS:
		if at.distance_to(Vector2(zone.x, zone.y)) < zone.z:
			return true
	return false


## How many trunks are solid. Zero means the wood is scenery the player walks
## straight through, which is a thing worth being able to check for.
func trunk_count() -> int:
	var total := 0
	for body: StaticBody3D in _bodies.values():
		total += body.get_shape_owners().size()
	return total


## Where the trunk nearest a point stands, in the level's own frame, or the point
## itself if there are none. For putting a test next to a tree without it having
## to know where any of them grew.
func trunk_near(point: Vector3) -> Vector3:
	var best := point
	var closest := INF
	for body: StaticBody3D in _bodies.values():
		for owner_id in body.get_shape_owners():
			var at: Vector3 = body.global_transform \
					* body.shape_owner_get_transform(owner_id).origin
			at.y = 0.0
			var gap := at.distance_squared_to(Vector3(point.x, 0.0, point.z))
			if gap < closest:
				closest = gap
				best = at
	return best


#region Planting
## Scatters one group over the map and builds the nodes that draw and collide it.
func _grow(group_name: String, group: Dictionary, draw_distance: float,
		shadows: bool, solid: bool) -> void:
	var models: Array = group["models"]
	var spacing: float = group["spacing"]
	var chance: float = group["chance"]

	var holder := Node3D.new()
	holder.name = group_name
	add_child(holder)

	# chunk -> species index -> the transforms of everything of that species in it
	var chunks: Dictionary = {}
	var planted := 0

	var limit := half_extent - edge_margin
	# Hexagonal rows pack more evenly than a square lattice at the same spacing.
	var row_step := spacing * sqrt(3.0) / 2.0
	var row := 0
	var z := -limit
	while z <= limit:
		var x := -limit + (spacing * 0.5 if row % 2 else 0.0)
		while x <= limit:
			var at := Vector2(x + _rng.randf_range(-0.42, 0.42) * spacing,
					z + _rng.randf_range(-0.42, 0.42) * spacing)
			x += spacing
			if absf(at.x) > limit or absf(at.y) > limit:
				continue
			var cover := _coverage(at)
			if cover <= 0.0 or _rng.randf() > cover * chance:
				continue
			if solid and _too_close(at):
				continue
			var pick := _species(models, at)
			if pick < 0:
				continue
			var span: Vector2 = models[pick]["scale"]
			# Bigger where the wood is thickest, so a thicket reads as older.
			var size := _rng.randf_range(span.x, span.y) * (0.82 + 0.28 * cover)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
					Vector3(size, size * _rng.randf_range(0.92, 1.12), size))

			var key := _chunk_of(at)
			var bucket: Dictionary = chunks.get(key, {})
			var list: Array = bucket.get(pick, [])
			list.append(Transform3D(basis, Vector3(at.x, 0.0, at.y)))
			bucket[pick] = list
			chunks[key] = bucket
			planted += 1

			if solid:
				_add_trunk(models[pick]["path"], at, size)
				_remember_trunk(at)
		z += row_step
		row += 1

	counts[group_name] = planted
	_build_chunks(holder, models, chunks, draw_distance, shadows)


## Plants a tree every few metres along each of a set of lines.
##
## Shares everything below it with [method _grow] — the same multimeshes, the
## same pooled trunk cylinders, the same chunk grid — and differs only in where
## the points come from: walked along a polyline rather than sampled off a
## lattice. A hedgerow is a line of trees, so it is written as one.
func _grow_lines(group_name: String, group: Dictionary, lines: Array[Array]) -> void:
	var models: Array = group["models"]
	var spacing: float = group["spacing"]
	var wander: float = group["wander"]

	var holder := Node3D.new()
	holder.name = group_name
	add_child(holder)

	var chunks: Dictionary = {}
	var planted := 0
	var limit := half_extent - edge_margin

	for line: Array in lines:
		for leg in line.size() - 1:
			var from: Vector2 = line[leg]
			var to: Vector2 = line[leg + 1]
			var run := from.distance_to(to)
			var steps := maxi(1, roundi(run / spacing))
			var across := (to - from).orthogonal().normalized()
			for step in steps:
				# Off the line by a little, and never twice in the same place,
				# so a hedgerow reads as grown rather than as printed.
				var at := from.lerp(to, float(step) / steps) \
						+ across * _rng.randf_range(-wander, wander)
				if absf(at.x) > limit or absf(at.y) > limit:
					continue
				# A hedgerow that runs into the wood or through a building is a
				# hedgerow nobody planted.
				if _wood(at) > 0.0 or is_clear(at) or _too_close(at):
					continue

				var pick := _rng.randi_range(0, models.size() - 1)
				var span: Vector2 = models[pick]["scale"]
				var size := _rng.randf_range(span.x, span.y)
				var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
						Vector3(size, size * _rng.randf_range(0.9, 1.15), size))

				var key := _chunk_of(at)
				var bucket: Dictionary = chunks.get(key, {})
				var list: Array = bucket.get(pick, [])
				list.append(Transform3D(basis, Vector3(at.x, 0.0, at.y)))
				bucket[pick] = list
				chunks[key] = bucket
				planted += 1

				_add_trunk(models[pick]["path"], at, size)
				_remember_trunk(at)

	counts[group_name] = planted
	_build_chunks(holder, models, chunks, tree_draw_distance, trees_cast_shadows)


## 0 where nothing grows, 1 in the deepest part of the wood.
func _coverage(at: Vector2) -> float:
	for zone in CLEARINGS:
		var gap := at.distance_to(Vector2(zone.x, zone.y))
		if gap < zone.z:
			return 0.0
		# A soft rim, so a glade has a ragged edge rather than a shaved circle.
		if gap < zone.z + 7.0:
			return _wood(at) * (gap - zone.z) / 7.0
	return _wood(at)


## The treeline: everything past a wandering line is wood, everything before it
## is not, and inside the wood the density field opens the odd glade.
##
## A line rather than a ring. The difference is the whole look of the map — a
## ring puts trees on every horizon and none of them mean anything, a line gives
## one wood with an edge you can walk out of and an open side to build on.
func _wood(at: Vector2) -> float:
	# Distance past the treeline, measured along the heading and pushed about by
	# noise so the edge is ragged instead of ruled.
	var heading := forest_heading.normalized() if not forest_heading.is_zero_approx() \
			else Vector2.LEFT
	# Sampled along the treeline rather than across it, so the wobble runs with
	# the edge instead of making the whole wood breathe in and out.
	var along := at.dot(Vector2(-heading.y, heading.x))
	var wander := _edge.get_noise_2d(along, 0.0) * treeline_wander
	var depth := at.dot(heading) - treeline - wander
	if depth <= 0.0:
		return 0.0

	var thickness := clampf(depth / maxf(treeline_fade, 0.01), 0.0, 1.0)

	# Glades are *holes*, not a general thinning. Multiplying the whole wood by a
	# noise field is what the first version did and it made every tree a coin
	# toss: nowhere was properly dense and nowhere was properly open. A threshold
	# leaves the wood at full density and takes distinct bites out of it.
	var field := _density.get_noise_2d(at.x, at.y)
	if field < glade_cut:
		return 0.0
	return thickness * clampf((field - glade_cut) / 0.12, 0.0, 1.0)


## Which species grows at a point.
func _species(models: Array, at: Vector2) -> int:
	if models.is_empty():
		return -1
	var wanted := 2 if _rng.randf() < 0.12 else \
			(0 if _biome.get_noise_2d(at.x, at.y) < 0.0 else 1)
	var matches := PackedInt32Array()
	for i in models.size():
		if int(models[i]["biome"]) == wanted:
			matches.append(i)
	if matches.is_empty():
		return _rng.randi_range(0, models.size() - 1)
	return matches[_rng.randi_range(0, matches.size() - 1)]


func _chunk_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / chunk_size), floori(at.y / chunk_size))


## Whether a trunk already stands within `min_trunk_gap` of a point. Bucketed on
## a grid a gap wide, so only nine cells are ever looked at however many trees
## have been planted.
func _too_close(at: Vector2) -> bool:
	if min_trunk_gap <= 0.0:
		return false
	var squared := min_trunk_gap * min_trunk_gap
	var centre := _gap_cell(at)
	for cx in range(centre.x - 1, centre.x + 2):
		for cz in range(centre.y - 1, centre.y + 2):
			for other in _standing.get(Vector2i(cx, cz), PackedVector2Array()) as PackedVector2Array:
				if at.distance_squared_to(other) < squared:
					return true
	return false


## Notes that a tree now stands here, so the next one gives it room. Recorded
## even for a trunk too thin to be worth a collider — a sapling is still
## something the next tree should not grow inside.
func _remember_trunk(at: Vector2) -> void:
	var cell := _gap_cell(at)
	var here: PackedVector2Array = _standing.get(cell, PackedVector2Array())
	here.append(at)
	_standing[cell] = here


func _gap_cell(at: Vector2) -> Vector2i:
	var side := maxf(min_trunk_gap, 0.5)
	return Vector2i(floori(at.x / side), floori(at.y / side))
#endregion


#region Drawing
## Turns the placement lists into one [MultiMeshInstance3D] per species per
## chunk, sitting at the chunk's own centre so the renderer has a tight box to
## cull against rather than one the size of the map.
func _build_chunks(holder: Node3D, models: Array, chunks: Dictionary,
		draw_distance: float, shadows: bool) -> void:
	for key: Vector2i in chunks:
		var centre := Vector3((key.x + 0.5) * chunk_size, 0.0, (key.y + 0.5) * chunk_size)
		var chunk := Node3D.new()
		chunk.name = "Chunk_%d_%d" % [key.x, key.y]
		chunk.position = centre
		holder.add_child(chunk)

		var bucket: Dictionary = chunks[key]
		for index: int in bucket:
			var path: String = models[index]["path"]
			var mesh := _mesh(path)
			if mesh == null:
				continue
			var list: Array = bucket[index]

			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = mesh
			multi.instance_count = list.size()
			for i in list.size():
				var local: Transform3D = list[i]
				local.origin -= centre
				multi.set_instance_transform(i, local)

			var node := MultiMeshInstance3D.new()
			node.name = path.get_file().get_basename()
			node.multimesh = multi
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.lod_bias = lod_bias
			if draw_distance > 0.0:
				node.visibility_range_end = draw_distance
				node.visibility_range_end_margin = maxf(draw_distance * 0.15, 4.0)
				node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			chunk.add_child(node)


## Loads a model once and remembers it. Missing files are warned about rather
## than fatal: a kit that has been trimmed should cost the level a species, not
## the whole wood.
func _mesh(path: String) -> Mesh:
	if _meshes.has(path):
		return _meshes[path]
	var mesh: Mesh = null
	if ResourceLoader.exists(path):
		mesh = load(path) as Mesh
	if mesh == null:
		push_warning("Forest: '%s' is missing; that species will not grow." % path)
	_meshes[path] = mesh
	return mesh
#endregion


#region Collision
## Gives one trunk a cylinder, on the body that covers the patch of ground it
## grows in.
##
## **Not one body for the whole wood.** That was the first version and it cost
## two milliseconds of physics a tick *anywhere on the map* — standing out on the
## open plain with no tree within eighty metres. The broadphase culls by body:
## once a query touches a body at all, every shape that body owns is looked at,
## so seven hundred trunks on one body means seven hundred cylinders considered
## whenever anything comes near any of them. Split onto a grid, a query looks at
## the twenty or so in one cell and the rest may as well not exist. The same
## trap, and the same measurement, as the trimesh colliders on the house.
##
## Shapes themselves are still pooled by radius to the nearest five centimetres,
## which is a different saving: a thousand trees want a dozen *shapes* between
## them, however many bodies those are spread over.
func _add_trunk(path: String, at: Vector2, size: float) -> void:
	var mesh := _mesh(path)
	if mesh == null:
		return
	var radius := _trunk_radius(mesh) * size * collider_shrink
	if radius < min_collider_radius:
		return

	var key := maxf(snappedf(radius, 0.05), 0.05)
	var shape: CylinderShape3D = _shape_pool.get(key)
	if shape == null:
		shape = CylinderShape3D.new()
		shape.radius = key
		# One height for every trunk of a given thickness: the cylinder only has
		# to stop a character walking through, and cutting one per tree would
		# undo the point of pooling them.
		shape.height = TRUNK_HEIGHT
		_shape_pool[key] = shape

	var body := _body_for(at)
	var owner_id := body.create_shape_owner(self)
	body.shape_owner_add_shape(owner_id, shape)
	# Sunk so the bottom cap is well under the ground: a lip at the foot of a
	# tree is something the player trips over on the way past. The offset is
	# relative to the body, which sits at the middle of its own cell.
	body.shape_owner_set_transform(owner_id, Transform3D(Basis.IDENTITY,
			Vector3(at.x, TRUNK_HEIGHT * 0.5 - TRUNK_SINK, at.y) - body.position))


## The body covering the ground a point stands on, made the first time something
## grows there.
func _body_for(at: Vector2) -> StaticBody3D:
	var cell := Vector2i(floori(at.x / collider_chunk), floori(at.y / collider_chunk))
	var body: StaticBody3D = _bodies.get(cell)
	if body != null:
		return body

	body = StaticBody3D.new()
	body.name = "Trunks_%d_%d" % [cell.x, cell.y]
	# Layer 1 is the world everything else collides against — the ground and the
	# boundary walls are on it, and a tree is the same kind of thing.
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3((cell.x + 0.5) * collider_chunk, 0.0,
			(cell.y + 0.5) * collider_chunk)
	_trunks.add_child(body)
	_bodies[cell] = body
	return body

## How tall a trunk collider is and how far of it is buried, in metres. Tall
## enough that nothing gets on top of one, deep enough that nothing catches on
## the bottom edge.
const TRUNK_HEIGHT := 9.0
const TRUNK_SINK := 1.5


## How thick a model is at its base, in the model's own units.
##
## Measured off the mesh rather than typed in per species: the widest point of
## the bottom eighth of the vertices is the trunk, and everything above it is
## canopy the player walks under. Swap a species for another and its collider is
## right without a number being changed anywhere.
func _trunk_radius(mesh: Mesh) -> float:
	var cached: Variant = _radius_cache.get(mesh.resource_path)
	if cached != null:
		return cached

	var bounds := mesh.get_aabb()
	var ceiling := bounds.position.y + maxf(bounds.size.y * 0.12, 0.05)
	var middle := Vector2(bounds.get_center().x, bounds.get_center().z)
	var widest := 0.0
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y <= ceiling:
				widest = maxf(widest, Vector2(v.x, v.z).distance_to(middle))
	_radius_cache[mesh.resource_path] = widest
	return widest
#endregion
