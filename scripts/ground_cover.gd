class_name GroundCover
extends RefCounted

## What lies on the ground of the core, laid once the wood has grown: ferns in
## knots on the floor of the wolves' firs and the great wood, broad-leaved
## plants, mushrooms in rings, the odd mossy stone and stump, and fallen logs in
## the great wood; in the open, stones lying in the fields, pebbles at the edges
## of the tracks, and at the woods' edges a few small patches of bellflowers
## and violets (no daisies: scattered over the meadows they were clutter).
## (Roots at the trunks' feet, twigs and the kit's grass tufts were tried: in
## the dark grade they read as black spikes and bright green sprouts.)
##
## The ferns and plants are Quaternius' Stylized Nature kit (CC0, saved out of
## `assets/village/village_props.glb` as meshes in `assets/village/cover/`),
## the rest the wood's own kit (`assets/forest`). All planted through
## [method Forest.plant], so drawn as the wood is — a multimesh per model per
## chunk, graded by [Looks] with the rest of the wood, no shadows, cut off by
## distance. Only the logs are solid, and there are none on the wolves' hill:
## it is still open ground to fight on.
##
## The same on every peer: a fixed seed and a walk over a fixed grid.

## Off for a measure of what it costs (perf probes).
static var enabled := true

const SEED := 90721
## The core's ground (x, z, width, depth), as [Meadows] has it.
const BOUNDS := Rect2(-116.0, -452.0, 232.0, 628.0)
## Metres between the points the ground is looked at.
const STEP := 3.0

const K := "res://assets/forest/%s.obj"
const COVER := "res://assets/village/cover/%s.res"
const MOSS := Color(0.72, 0.9, 0.62)
## The nature kit's leaves are a spring lime; under the firs, in the dark grade,
## they want to be the wood's own deep green.
const SHADE := Color(0.55, 0.66, 0.46)
## [path, tint or none] — one flat table, the index is what is planted.
const MODELS := [
	[COVER % "fern_1", SHADE], [COVER % "plant_1", SHADE], [COVER % "plant_7", null],  # 0 1 2
	[K % "Mushroom_Brown", null], [K % "Mushroom_Grey", null],                        # 3 4
	[K % "Mushroom_Red_Spotted", null], [K % "Mushroom_Dark_Red", null],              # 5 6
	[K % "Rock_2", MOSS], [K % "Rock_4", MOSS], [K % "Stump_1", null],                # 7 8 9
	[K % "Log_1", null], [K % "Log_3", null],                                         # 10 11
	[K % "Stepping_Stone_1", null], [K % "Stepping_Stone_3", null],                   # 12 13
	[K % "Rock_1", null], [K % "Rock_3", null],                                       # 14 15
	[K % "Flower_Bellflower_1", null], [K % "Flower_Bellflower_3", null],             # 16 17
	[K % "Flower_Violet_1", null], [K % "Flower_Violet_2", null],                     # 18 19
]
const FERN := 0
const PLANT := 1
const LOW_LEAVES := 2
const MUSHROOMS := [3, 4, 5, 6]
const MOSSY := [7, 8]
const STUMP := 9
const LOGS := [10, 11]
const STONES := [12, 13]
const FIELD_ROCKS := [14, 15]
const BLOOMS := [16, 17, 18, 19]

## How far each kind of thing is drawn, metres.
const NEAR := 46.0
const MID := 70.0


static func lay(forest: Forest, village: Rect2) -> Dictionary:
	if not enabled or forest == null:
		return {}
	var started := Time.get_ticks_usec()
	var planned := plan(forest, village)
	forest.plant("Ground Litter", planned["models"], planned["litter"], NEAR, false)
	forest.plant("Ground Open", planned["models"], planned["open"], MID, false)
	forest.plant("Ground Logs", planned["models"], planned["logs"], MID, false)
	var out := {"litter": planned["litter"].size(), "open": planned["open"].size(), "logs": planned["logs"].size()}
	print("GroundCover: %s, in %.0f ms" % [out, (Time.get_ticks_usec() - started) / 1000.0])
	return out


## What would be laid, without planting it: {models, litter, open, logs}, each
## list [model index, x, z, size, turn in degrees, solid] as
## [method Forest.plant] takes it.
static func plan(forest: Forest, village: Rect2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var patches := FastNoiseLite.new()
	patches.seed = SEED
	patches.frequency = 0.045
	var models: Array = []
	for m: Array in MODELS:
		var model := {"path": m[0]}
		if m[1] != null:
			model["tint"] = m[1]
			model["tint_all"] = true
		models.append(model)
	var litter: Array = []   # near: small things on the floor
	var open: Array = []     # mid: stones and flowers in the open
	var logs: Array = []     # fallen timber, solid
	var keep_off := village.grow(4.0)

	var nx := int(BOUNDS.size.x / STEP)
	var nz := int(BOUNDS.size.y / STEP)
	for iz in nz:
		for ix in nx:
			var at := BOUNDS.position + Vector2(ix + rng.randf(), iz + rng.randf()) * STEP
			var roll := rng.randf()
			if keep_off.has_point(at) or forest.is_clear(at) or forest._is_wet(at):
				continue
			var hill := forest._hill_wood(at)
			var wood := maxf(hill, forest._coverage(at))
			var on_path := forest._on_path(at)
			var patch := patches.get_noise_2d(at.x, at.y)
			if on_path:
				# Pebbles at the edges of the tracks, not on the worn middle.
				var tracks := forest.get_node_or_null(forest.paths) as Paths
				if roll < 0.16 and tracks != null and not tracks.near(at, 0.2):
					open.append([STONES[rng.randi() % 2], at.x, at.y, rng.randf_range(0.35, 0.7), rng.randf() * 360.0, false])
				continue
			if wood > 0.3:
				# The floor of a wood.
				if roll < 0.13 and patch > -0.3:
					# a knot of ferns
					for k in rng.randi_range(2, 4):
						var spot := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.6)
						litter.append([FERN, spot.x, spot.y, rng.randf_range(1.3, 2.1), rng.randf() * 360.0, false])
				elif roll < 0.16:
					litter.append([PLANT, at.x, at.y, rng.randf_range(0.8, 1.2), rng.randf() * 360.0, false])
				elif roll < 0.21:
					# a ring or a knot of one kind of mushroom
					var kind: int = MUSHROOMS[rng.randi() % 4]
					for k in rng.randi_range(4, 8):
						var spot := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.1, 0.9)
						litter.append([kind, spot.x, spot.y, rng.randf_range(1.6, 2.8), rng.randf() * 360.0, false])
				elif roll < 0.24:
					litter.append([MOSSY[rng.randi() % 2], at.x, at.y, rng.randf_range(0.4, 0.75), rng.randf() * 360.0, false])
				elif roll < 0.25:
					litter.append([STUMP, at.x, at.y, rng.randf_range(2.0, 3.0), rng.randf() * 360.0, false])
				elif roll < 0.258 and hill <= 0.0:
					# fallen timber in the great wood (none on the wolves' hill)
					logs.append([LOGS[rng.randi() % 2], at.x, at.y, rng.randf_range(1.6, 2.3), rng.randf() * 360.0, true])
				continue
			# The open ground.
			if wood > 0.02 and roll < 0.05 and patch > 0.1:
				# At a wood's edge: a small patch of one flower.
				var bloom: int = BLOOMS[int(absf(at.x * 7.13 + at.y * 3.71)) % 4]
				for k in rng.randi_range(4, 9):
					var spot := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.1, 1.6)
					open.append([bloom, spot.x, spot.y, rng.randf_range(0.9, 1.4), rng.randf() * 360.0, false])
			elif roll < 0.025 and patch > 0.0:
				open.append([LOW_LEAVES, at.x, at.y, rng.randf_range(0.9, 1.4), rng.randf() * 360.0, false])
			elif roll < 0.037:
				# A stone lying in the field, and a smaller one or two by it.
				open.append([FIELD_ROCKS[rng.randi() % 2], at.x, at.y, rng.randf_range(0.35, 0.7), rng.randf() * 360.0, false])
				for k in rng.randi_range(0, 2):
					var spot := at + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.7, 1.4)
					open.append([STONES[rng.randi() % 2], spot.x, spot.y, rng.randf_range(0.4, 0.8), rng.randf() * 360.0, false])

	# A knot spreads a metre or two from its point: nothing of it in the village.
	var outside := func(p: Array) -> bool: return not village.has_point(Vector2(p[1], p[2]))
	litter = litter.filter(outside)
	open = open.filter(outside)
	logs = logs.filter(outside)
	return {"models": models, "litter": litter, "open": open, "logs": logs}
