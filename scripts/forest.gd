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
	# The lane down from the settlement to the greybox core.
	[Vector2(30, 6), Vector2(58, -2), Vector2(92, -8)],
	# And the rest of the farmed ground, north and south of the settlement.
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
	Vector3(82.0, -14.0, 9.0),
	# The lane out to the east, and Arkdeva's glade in the wood, which is wide:
	# its thorns run eleven metres.
	Vector3(60.0, -12.0, 13.0),
	Vector3(5.0, -50.0, 22.0),
	# The settlement. It sits on the open side and the treeline would not reach
	# it anyway, but the hedgerows are planted by hand and would run straight
	# through the street without this.
	Vector3(64.0, 43.0, 26.0),
	# The mere in the marsh and the village on its island (Marsh.mere_centre),
	# wider than the water so the wood stands back from the shore.
	Vector3(10.0, -188.0, 52.0),
	# And a gap in the trees on its north side, where the ride down from the
	# open ground east of the core comes out. Only south of the old boundary:
	# a clearing inside the square would re-roll the whole square's wood.
	Vector3(28.0, -130.0, 9.0),
	Vector3(24.0, -142.0, 10.0),
	# The bay: where the harbour's pier comes ashore, and the way to it from
	# the mere, down the east side of the marsh.
	Vector3(0.0, -282.0, 22.0),
	Vector3(0.0, -302.0, 34.0),
	Vector3(14.0, -255.0, 12.0),
	Vector3(36.0, -232.0, 10.0),
]

## The wolves' wood: north of the village, on the land past the old square's
## north edge (`north_extent`), from well clear of the village's fence up to
## the north wall, and on to the west into the great wood (x, z, width, depth,
## each). It does not start at the fence: a stretch of open ground first, then
## a young fir or two, then more, and then the giants (`GROVE_RAMP`). Planted
## after everything else, so the rest of the map's wood comes out of the seed
## as it did before.
const GROVE := Rect2(8.0, 98.0, 110.0, 80.0)
const GROVE_WEST := Rect2(-26.0, 94.0, 34.0, 84.0)
## Over how many metres from its foot the wood thickens from nothing to full.
const GROVE_RAMP := 26.0
## Room kept round each of the wolves in it (x, z, radius), so none is born in a
## trunk; and a few open places for the light to come down into.
const GROVE_GLADES: Array[Vector3] = [
	Vector3(-14.0, 112.0, 4.0),
	Vector3(4.0, 124.0, 4.0),
	Vector3(-6.0, 146.0, 4.0),
	Vector3(12.0, 166.0, 4.0),
	Vector3(26.0, 132.0, 4.0),
	Vector3(34.0, 112.0, 4.0),
	Vector3(42.0, 152.0, 4.0),
	Vector3(52.0, 170.0, 4.0),
	Vector3(58.0, 126.0, 4.0),
	Vector3(66.0, 146.0, 4.0),
	Vector3(78.0, 114.0, 4.0),
	Vector3(84.0, 166.0, 4.0),
	Vector3(92.0, 136.0, 4.0),
	Vector3(104.0, 118.0, 4.0),
	Vector3(108.0, 150.0, 4.0),
	Vector3(100.0, 170.0, 4.0),
	Vector3(46.0, 128.0, 7.0),
	Vector3(86.0, 150.0, 7.5),
	Vector3(10.0, 142.0, 7.0),
	Vector3(70.0, 168.0, 6.0),
]

## The giants: firs of the wood's own making (vepxis-art `tools/giant_fir.py`,
## `forest/giant_fir.blend`) — a trunk a metre and more across, flaring into
## roots at the foot and bare for twelve to sixteen metres before the first
## boughs, the crown in drooping tiers thirty metres up. A few hundred
## triangles each, far apart, so walking in under them is walking into a hall
## of stems.
const HILL_GIANTS := {
	"spacing": 9.5,
	"chance": 0.9,
	"models": [
		{"path": "res://assets/forest/GiantFir_A.obj", "scale": Vector2(0.9, 1.15), "biome": 1},
		{"path": "res://assets/forest/GiantFir_B.obj", "scale": Vector2(0.9, 1.2), "biome": 1},
		{"path": "res://assets/forest/GiantFir_C.obj", "scale": Vector2(0.9, 1.1), "biome": 1},
	],
}
## And young firs among them, thinner, and the first of the wood at its foot.
const HILL_YOUNG := {
	"spacing": 9.0,
	"chance": 0.5,
	"models": [
		{"path": "res://assets/forest/Tree_Pine_1.obj", "scale": Vector2(1.1, 2.0), "biome": 1},
		{"path": "res://assets/forest/Tree_Pine_2.obj", "scale": Vector2(1.1, 2.1), "biome": 1},
		{"path": "res://assets/forest/Tree_Pine_3.obj", "scale": Vector2(1.0, 1.8), "biome": 1},
		{"path": "res://assets/forest/Tree_Pine_4.obj", "scale": Vector2(0.9, 1.5), "biome": 1},
	],
}

@export_group("Layout")
## Change this and the whole wood is re-rolled. Fixed rather than randomised: the
## same seed has to grow the same wood on every peer, or players would be walking
## into trees nobody else can see.
@export var random_seed: int = 90238411
## Half the side of the ground plane. Nothing is planted beyond this.
@export var half_extent: float = 116.0
## How much further the ground runs to the south (towards -z) than
## `half_extent`, in metres: the marsh strip. The wood grows into it too.
@export var south_extent: float = 0.0
## And past that, the bay strip, planted last of all.
@export var bay_extent: float = 0.0
## How much further the ground runs to the north than `half_extent`: the
## wolves' wood behind the village ([member Terrain.north_extra]).
@export var north_extent: float = 60.0
## Ground that dips under water ([Marsh] nodes): nothing is planted where any of
## them is below its dry level. A tree standing in a lake is a tree nobody
## planted.
@export var wet_ground: Array[NodePath] = []
## The worn tracks ([Paths]): nothing grows on them or within a metre and a half
## of their edges, so a track through the wood is a way through it.
@export var paths: NodePath
## How the kit's leaves are toned, as a multiplier on their colour. The kit's
## broadleaf greens are a flat lime that reads as plastic next to anything
## textured; this takes them down to something a leaf could be.
@export var leaf_tone: Color = Color(0.62, 0.74, 0.5)
## The same for the textured broadleaf leaves (oak, bush), whose lime is in the
## texture: a stronger pull, down and towards olive, so the wood reads as a
## summer wood rather than as a toy one.
@export var broadleaf_tone: Color = Color(0.86, 0.7, 0.56)
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
@export var min_collider_radius: float = 0.15
## How much of the measured trunk a collider covers. Under 1 on purpose — a
## cylinder cut to the widest point of a flared base catches the player a foot
## away from the bark.
@export var collider_shrink: float = 0.9

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
## Planting the wolves' hill ([constant GROVE]) rather than the wood at large.
var _on_hill: bool = false


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
	# The strip the map grew by, planted after everything else so the square's
	# wood comes out of the same seed exactly as it did before the strip existed.
	if south_extent > 0.0:
		var from := -(half_extent + south_extent) + edge_margin
		var to := -half_extent - edge_margin * 0.5
		_grow("Canopy South", CANOPY, tree_draw_distance, trees_cast_shadows, true, from, to)
		_grow("Undergrowth South", UNDERGROWTH, undergrowth_draw_distance, false, false, from, to)
		_grow("Litter South", LITTER, litter_draw_distance, false, false, from, to)
	if bay_extent > 0.0:
		var from := -(half_extent + south_extent + bay_extent) + edge_margin
		var to := -(half_extent + south_extent) - edge_margin * 0.5
		_grow("Canopy Bay", CANOPY, tree_draw_distance, trees_cast_shadows, true, from, to)
		_grow("Undergrowth Bay", UNDERGROWTH, undergrowth_draw_distance, false, false, from, to)
		_grow("Litter Bay", LITTER, litter_draw_distance, false, false, from, to)
	# The land north of the old square: the great wood runs on up its west side
	# (the wolves' wood, after, takes the rest).
	if north_extent > 0.0:
		var from := half_extent + edge_margin * 0.5
		var to := half_extent + north_extent - edge_margin
		_grow("Canopy North", CANOPY, tree_draw_distance, trees_cast_shadows, true, from, to)
		_grow("Undergrowth North", UNDERGROWTH, undergrowth_draw_distance, false, false, from, to)
		_grow("Litter North", LITTER, litter_draw_distance, false, false, from, to)
	# The wolves' hill, last of all.
	_on_hill = true
	var north_to := half_extent + north_extent - edge_margin
	_grow("Giants Hill", HILL_GIANTS, tree_draw_distance, trees_cast_shadows, true, GROVE_WEST.position.y - 4.0, north_to)
	_grow("Young Firs Hill", HILL_YOUNG, tree_draw_distance, trees_cast_shadows, true, GROVE_WEST.position.y - 4.0, north_to)
	_on_hill = false

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


## Where every tree stands, (x, z): what [Looks] lays the forest floor under.
func trunk_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for here: PackedVector2Array in _standing.values():
		out.append_array(here)
	return out


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
		shadows: bool, solid: bool, z_from: float = NAN, z_to: float = NAN) -> void:
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
	# The rows to sample: the square by default, or a strip of the ground beyond
	# it (see `south_extent`).
	var z_low := -limit if is_nan(z_from) else z_from
	var z_high := limit if is_nan(z_to) else z_to
	# Hexagonal rows pack more evenly than a square lattice at the same spacing.
	var row_step := spacing * sqrt(3.0) / 2.0
	var row := 0
	var z := z_low
	while z <= z_high:
		var x := -limit + (spacing * 0.5 if row % 2 else 0.0)
		while x <= limit:
			var at := Vector2(x + _rng.randf_range(-0.42, 0.42) * spacing,
					z + _rng.randf_range(-0.42, 0.42) * spacing)
			x += spacing
			if absf(at.x) > limit or at.y < z_low or at.y > z_high:
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
			if group.has("stretch"):
				var stretch: Vector2 = group["stretch"]
				basis = basis.scaled(Vector3(1.0, _rng.randf_range(stretch.x, stretch.y), 1.0))

			var key := _chunk_of(at)
			var bucket: Dictionary = chunks.get(key, {})
			var list: Array = bucket.get(pick, [])
			list.append(Transform3D(basis, Vector3(at.x, Terrain.height_under(at.x, at.y, 0.35), at.y)))
			bucket[pick] = list
			chunks[key] = bucket
			planted += 1

			if solid:
				_add_trunk(models[pick]["path"], at, size, basis)
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
				if _wood(at) > 0.0 or is_clear(at) or _too_close(at) or _on_path(at):
					continue

				var pick := _rng.randi_range(0, models.size() - 1)
				var span: Vector2 = models[pick]["scale"]
				var size := _rng.randf_range(span.x, span.y)
				var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
						Vector3(size, size * _rng.randf_range(0.9, 1.15), size))

				var key := _chunk_of(at)
				var bucket: Dictionary = chunks.get(key, {})
				var list: Array = bucket.get(pick, [])
				list.append(Transform3D(basis, Vector3(at.x, Terrain.height_under(at.x, at.y, 0.35), at.y)))
				bucket[pick] = list
				chunks[key] = bucket
				planted += 1

				_add_trunk(models[pick]["path"], at, size, basis)
				_remember_trunk(at)

	counts[group_name] = planted
	_build_chunks(holder, models, chunks, tree_draw_distance, trees_cast_shadows)


## 0 where nothing grows, 1 in the deepest part of the wood.
func _coverage(at: Vector2) -> float:
	if _is_wet(at) or _on_path(at):
		return 0.0
	if _on_hill:
		return _hill_wood(at)
	# North of the old square, only the great wood's own side: the rest is the
	# wolves' wood's, planted after.
	if at.y > half_extent and (GROVE.grow(4.0).has_point(at) or GROVE_WEST.grow(4.0).has_point(at)):
		return 0.0
	for zone in CLEARINGS:
		var gap := at.distance_to(Vector2(zone.x, zone.y))
		if gap < zone.z:
			return 0.0
		# A soft rim, so a glade has a ragged edge rather than a shaved circle.
		if gap < zone.z + 7.0:
			return _wood(at) * (gap - zone.z) / 7.0
	return _wood(at)


## The wood on the wolves' hill ([constant GROVE]): thick from the ragged foot
## of it up, with the density field's glades and the wolves' own.
func _hill_wood(at: Vector2) -> float:
	var k := 0.0
	var ragged := _edge.get_noise_2d(at.x * 4.0, 17.0) * 6.0
	if GROVE.grow(2.0).has_point(at):
		# North of the village: open ground first, then the wood thickening
		# slowly up from a ragged foot.
		k = clampf((at.y - GROVE.position.y - ragged) / GROVE_RAMP, 0.0, 1.0)
	if GROVE_WEST.grow(2.0).has_point(at):
		# West of it, running into the great wood.
		var foot := clampf((at.y - GROVE_WEST.position.y - ragged) / GROVE_RAMP, 0.0, 1.0)
		var west := clampf((at.x - GROVE_WEST.position.x - ragged) / 10.0, 0.0, 1.0)
		k = maxf(k, foot * west)
	# Nowhere near the village's lot.
	if World.VILLAGE.grow(12.0).has_point(at):
		k = 0.0
	if k <= 0.0:
		return 0.0
	for g: Vector3 in GROVE_GLADES:
		var gap := at.distance_to(Vector2(g.x, g.y))
		if gap < g.z:
			return 0.0
		if gap < g.z + 5.0:
			k *= (gap - g.z) / 5.0
	# No glades cut by the density field here: the firs stand far enough apart
	# that the whole hill is open between them.
	return k


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
	else:
		mesh = _toned(mesh)
	_meshes[path] = mesh
	return mesh


## The mesh again, with any bright green surface taken down by `leaf_tone`.
## Trunks, bark and the conifers' own darker greens are left as they are.
##
## Two kinds of bright green: a flat green colour, and the broadleaf kit's
## leaves, which are a white material over a lime texture — those are known by
## the material's name, since their colour says nothing.
func _toned(mesh: Mesh) -> Mesh:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null or leaf_tone == Color.WHITE:
		return mesh
	var copy: ArrayMesh = null
	for s in array_mesh.get_surface_count():
		var material := array_mesh.surface_get_material(s) as BaseMaterial3D
		if material == null:
			continue
		var c := material.albedo_color
		var named := material.resource_name + " " + array_mesh.surface_get_name(s)
		var leaves := named.contains("Leaves") and not named.contains("Pine") \
				and not named.contains("Cedar")
		if leaves or (c.g > 0.45 and c.g > c.r * 1.25 and c.g > c.b * 1.25):
			if copy == null:
				copy = array_mesh.duplicate() as ArrayMesh
			var toned := material.duplicate() as BaseMaterial3D
			var tone := broadleaf_tone if leaves else leaf_tone
			toned.albedo_color = Color(c.r * tone.r, c.g * tone.g, c.b * tone.b, c.a)
			copy.surface_set_material(s, toned)
	return copy if copy != null else mesh
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
func _add_trunk(path: String, at: Vector2, size: float, turn: Basis = Basis.IDENTITY) -> void:
	var mesh := _mesh(path)
	if mesh == null:
		return
	var base := _trunk_base(mesh)
	var radius := float(base[1]) * size * collider_shrink
	# Where the trunk actually stands, which is not always the model's origin:
	# turned and scaled the way the tree was drawn.
	var foot: Vector2 = base[0]
	var offset := turn * Vector3(foot.x, 0.0, foot.y)
	at += Vector2(offset.x, offset.z)
	if radius < min_collider_radius:
		return
	# Never thinner than this, even round a thin trunk: a capsule walked
	# head-on into a pencil-thin cylinder slides round it rather than stopping.
	radius = maxf(radius, TRUNK_FLOOR)

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
			Vector3(at.x, Terrain.height_under(at.x, at.y, 0.35) + TRUNK_HEIGHT * 0.5 - TRUNK_SINK, at.y)
			- body.position))


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
## The thinnest a trunk collider is made.
const TRUNK_FLOOR := 0.3
const TRUNK_SINK := 1.5


## How thick a model is at its base, in the model's own units, and where on
## the ground that base stands.
##
## Measured off the mesh rather than typed in per species: the vertices in the
## lowest few percent of the model are the foot of the trunk, their middle is
## where it stands and the furthest of them from that middle is how thick it
## is. Everything above is canopy the player walks under.
##
## It used to take the bottom *eighth* and measure from the middle of the whole
## model's box. Both were wrong for some species: the big pine's lowest boughs
## sweep down into its bottom eighth, which gave it a collider five metres
## across, and a tree whose crown leans one way has the middle of its box off
## to that side, so a trunk thirty centimetres thick measured eighty. Either
## way the player met a wall under branches he could see daylight through.
func _trunk_radius(mesh: Mesh) -> float:
	return float(_trunk_base(mesh)[1])


## [centre of the trunk's foot as (x, z), its radius], cached per model.
func _trunk_base(mesh: Mesh) -> Array:
	var cached: Variant = _radius_cache.get(mesh.resource_path)
	if cached != null:
		return cached

	var bounds := mesh.get_aabb()
	# The foot: the bottom 4 %, but never more than half a unit — a tall tree
	# has low boughs well inside 4 % of its height.
	var ceiling := bounds.position.y + clampf(bounds.size.y * 0.04, 0.05, 0.5)
	var foot := PackedVector2Array()
	for s in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y <= ceiling:
				foot.append(Vector2(v.x, v.z))
	var middle := Vector2.ZERO
	for v in foot:
		middle += v
	middle = middle / foot.size() if not foot.is_empty() else Vector2.ZERO
	var widest := 0.0
	for v in foot:
		widest = maxf(widest, v.distance_to(middle))
	var result := [middle, widest]
	_radius_cache[mesh.resource_path] = result
	return result
#endregion


## Whether a point is under (or at the edge of) water somebody put there.
func _is_wet(at: Vector2) -> bool:
	for path in wet_ground:
		var ground := get_node_or_null(path) as Marsh
		if ground != null and ground.height_at(at.x, at.y) < -0.05:
			return true
	return false


func _on_path(at: Vector2) -> bool:
	if paths.is_empty():
		return false
	var tracks := get_node_or_null(paths) as Paths
	return tracks != null and tracks.near(at, 1.5)
