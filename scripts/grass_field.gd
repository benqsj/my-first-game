class_name GrassField
extends Node3D

## Bends grass out of the way as something walks or rolls through it, and keeps
## the whole field swaying in the wind.
##
## The field is **one mesh drawn many times**, not many meshes. The clump model
## is 8 256 triangles and there are the better part of two thousand of them; as
## instanced scenes that was seventeen hundred draw calls and most of the frame,
## and it is what `Graphics._apply_grass()` means when it calls the grass "most
## of the cost of the world". So the placement arrives as a flat array of
## numbers — written by `tools/build_scatter.py`, five floats to a clump — and is
## turned at load into [MultiMeshInstance3D]s, a couple of dozen of them, split
## on a grid:
##
## * a chunk is one draw call however many clumps stand in it;
## * a chunk is culled, faded and dropped to a coarser level of detail on its
##   own, which is why the grid is tight — the renderer picks one detail level
##   per multimesh, so a big chunk would hold the near clumps back;
## * only a chunk that something has actually walked through is re-uploaded, so
##   the field costs a buffer write where the player is and nothing anywhere
##   else.
##
## Everything above that is unchanged. Each clump keeps the orientation it was
## placed with; the lean is a rotation layered on top of that, about a horizontal
## axis through the clump's base, so the blades tip away from whatever is pushing
## them and spring back once it has passed. Clumps are bucketed into a uniform
## grid at startup, so a field of several thousand only ever costs a handful of
## cell lookups per pusher per frame:
##
## * clumps near a pusher are integrated every frame — that is the part the
##   player feels;
## * clumps that are still leaning stay awake until they have stood back up;
## * everything else within `wind_radius` only gets the wind, spread over
##   `wind_slices` frames because a slow sway does not need 60 Hz;
## * anything further out is left alone entirely.
##
## The player is not the only thing that flattens grass: every body in the
## "enemy" group pushes too, with a wider radius since the creatures are bigger.
##
## Children that are not clumps — the stone clusters that share this node — are
## left exactly as they are. They are solid, there are thirty of them, and they
## are not what was costing anything.

## Floats per clump in `clumps`: x, z, yaw, width, height.
const STRIDE := 5

@export_group("Field")
## The clump model. Its first mesh is what gets drawn, once per clump.
@export var clump_scene: String = "res://assets/grass/grass2.glb"
## Placement, five floats to a clump: x and z in the field's own frame, the yaw
## it stands at, and the width and height it is scaled to. Written by
## `tools/build_scatter.py`; not meant to be edited by hand.
@export var clumps: PackedFloat32Array = PackedFloat32Array()
## A second, cheaper model, laid out the same way. `grass.glb` is a tenth of the
## triangles of the clump but ships untextured and reads as flat green leaf cards
## rather than blades, so it is only worth mixing in where the grass is small and
## sparse. Left empty by the scatter as it stands.
@export var tuft_scene: String = "res://assets/grass/grass.glb"
@export var tufts: PackedFloat32Array = PackedFloat32Array()
## Each clump's own colour, multiplied over its texture, in the order of
## `clumps` then `tufts`. Empty leaves them all as the model was coloured. This
## is what the meadows use to tone the kit's lime down and to vary one drift
## from the next; blood is laid on top of it and washes back to it.
@export var tints: PackedColorArray = PackedColorArray()
## Side of a drawing chunk, in metres. Small on purpose: one level of detail is
## picked per chunk, so a large chunk keeps the clumps at the player's feet at
## the same detail as the ones at its far corner.
@export var draw_chunk: float = 16.0

@export_group("Bending")
## Kept for the scenes that still set it. Children are no longer searched for
## clumps — the placement comes from `clumps` — but a name prefix is still what
## tells a stone cluster from a tuft in the scatter that produces both.
@export var grass_prefix: String = "Grass"
## How far from a pusher a clump starts to feel it, in metres.
@export var reach: float = 1.5
## How far the blades lean at the centre of the push, in radians.
@export var max_bend: float = 1.15
## How fast the blades give way. Higher snaps out of the way sooner.
@export var bend_speed: float = 14.0
## How fast they stand back up once nothing is on them.
@export var recover_speed: float = 4.5
## Creatures are wider than the knight, so they trample a wider band.
@export var enemy_reach_scale: float = 1.7

@export_group("Wind")
@export var wind_enabled: bool = true
## Lean the wind alone puts into the blades, in radians.
@export var wind_strength: float = 0.1
## Gusts per second.
@export var wind_speed: float = 0.9
## Which way the wind blows, on the ground plane.
@export var wind_direction: Vector2 = Vector2(1.0, 0.35)
## Distance between gust crests, in metres. Long waves read as rolling gusts,
## short ones as choppy ripples.
@export var wind_wavelength: float = 9.0

@export_group("Performance")
## Grass beyond this many metres from the camera stops being drawn, fading out
## over the last few metres so nothing pops. Zero draws all of it, always.
@export var draw_distance: float = 130.0
## Whether the blades cast shadows into the sun's shadow map.
##
## Off by default, and still the single biggest switch on this node: the field
## has to be re-drawn once per shadow cascade on top of the visible pass, for
## shadows that at this size of blade are almost impossible to see. Grass still
## *receives* the shadows of everything around it.
@export var casts_shadows: bool = false
## How eagerly a chunk drops to a coarser level of detail, as a multiplier on the
## viewport's threshold — *below* 1 means sooner. Leaning on the LODs the
## importer generated is what keeps the triangle count sane; a blade twenty
## metres off does not need its full silhouette. Applied per chunk rather than
## through the viewport so the buildings and creatures keep their detail.
@export var lod_bias: float = 0.06
## Clumps further than this from the player are not swayed at all. Kept short on
## purpose: writing a transform per clump per frame is the expensive part of this
## script, and a blade of grass 25 m out is not visibly moving anyway.
@export var wind_radius: float = 22.0
## The wind pass is split across this many frames. A gust cycle lasts about a
## second, so a clump updated every fifth frame still reads as smooth.
@export var wind_slices: int = 5
## Side of a bending bucket, in metres. Wants to be a little over `reach`.
@export var cell_size: float = 2.5

## The orientation each clump was placed with. The lean is layered on top.
var _rest: Array[Basis] = []
## Where each clump stands, in the field's own frame.
var _home: PackedVector3Array = PackedVector3Array()
## Random per-clump offset so neighbours do not sway in lockstep.
var _phase: PackedFloat32Array = PackedFloat32Array()
## Current lean per clump: direction is which way it leans, length is how far.
var _bend: Array[Vector3] = []

## Which multimesh each clump is drawn by, and its slot inside it.
var _multi: Array[MultiMesh] = []
var _slot: PackedInt32Array = PackedInt32Array()
## What each clump is currently drawn with, kept on this side of the rendering
## server. A multimesh is write-only in a headless run — `get_instance_transform`
## comes back as the identity when there is no renderer behind it — so anything
## that needs to *read* the pose, which is every test and the blood, has to read
## it from here rather than from the buffer it was written into.
var _pose: Array[Basis] = []
## Each clump's position inside its own chunk. Constant: a clump tips, it does
## not move.
var _local: PackedVector3Array = PackedVector3Array()
## How bloodied each clump is. White is clean.
var _tint: PackedColorArray = PackedColorArray()
## What each clump is when clean.
var _base: PackedColorArray = PackedColorArray()
## The nodes that do the drawing, one per occupied chunk.
var _chunks: Array[MultiMeshInstance3D] = []
## Model index -> the mesh that draws it. Held only while the field is built.
var _built_meshes: Dictionary = {}

## Grid cell -> indices of the clumps standing in it.
var _grid: Dictionary = {}
## Indices that are mid-bend or mid-recovery, and so need every frame.
var _awake: Dictionary = {}
## Scratch, reused every frame to avoid churning arrays.
var _pushed: Dictionary = {}

var _player: Node3D
## Counts up to `WATCH_EVERY`, at which point the nearest player is asked for
## again.
var _watch_tick: int = 0
var _time: float = 0.0
var _slice: int = 0
var _wind_dir: Vector3 = Vector3.FORWARD
## Frames of sway pass still owed after the wind is switched off, so the field
## settles back upright instead of freezing mid-gust.
var _settling: int = 0
var _was_windy: bool = false


func _ready() -> void:
	_build()

	var flat := Vector3(wind_direction.x, 0.0, wind_direction.y)
	_wind_dir = flat.normalized() if not flat.is_zero_approx() else Vector3.FORWARD

	# Not looked up here any more: players are spawned into the level rather than
	# baked into it, so at this moment there may be none — and with more than one
	# there is no single right answer anyway. `_find_watcher()` asks again, every
	# so often, for whichever is nearest.
	_find_watcher()


## Throws the field away and plants this one instead: the placement and the
## colours, laid out as `clumps` and `tints` are. For a field grown at load
## ([Meadows]) rather than written into the scene.
func replace(new_clumps: PackedFloat32Array, new_tints: PackedColorArray) -> void:
	for node in _chunks:
		node.queue_free()
	_chunks.clear()
	_built_meshes.clear()
	_awake.clear()
	_pushed.clear()
	for list in [_rest, _bend, _multi, _pose]:
		(list as Array).clear()
	_home = PackedVector3Array()
	_phase = PackedFloat32Array()
	_slot = PackedInt32Array()
	_local = PackedVector3Array()
	_tint = PackedColorArray()
	_base = PackedColorArray()
	clumps = new_clumps
	tufts = PackedFloat32Array()
	tints = new_tints
	_build()


## How many clumps are standing. For anything checking the field was built.
func clump_count() -> int:
	return _rest.size()


## Where a clump stands, in the field's own frame.
func clump_home(index: int) -> Vector3:
	return _home[index] if index >= 0 and index < _home.size() else Vector3.ZERO


## The orientation a clump is holding this frame, lean and all. What a test that
## wants to know whether the grass gave way should be reading.
func clump_basis(index: int) -> Basis:
	if index < 0 or index >= _pose.size():
		return Basis.IDENTITY
	return _pose[index]


## The clump nearest a point, or -1 if the field is empty. For placing a test
## somewhere there is actually grass to tread on.
func clump_near(point: Vector3) -> int:
	var best := -1
	var closest := INF
	for i in _home.size():
		var gap := _home[i].distance_squared_to(point)
		if gap < closest:
			closest = gap
			best = i
	return best


#region Building
## Turns the placement numbers into the meshes that draw them.
##
## Both models share one index space — a clump is a clump whichever mesh draws
## it, as far as the bending and the wind are concerned — but a chunk only ever
## holds one model, since a multimesh draws one mesh.
func _build() -> void:
	var groups: Array = [[clump_scene, clumps], [tuft_scene, tufts]]
	var total := (clumps.size() + tufts.size()) / STRIDE
	if total == 0:
		return

	_rest.resize(total)
	_bend.resize(total)
	_home.resize(total)
	_phase.resize(total)
	_multi.resize(total)
	_slot.resize(total)
	_pose.resize(total)
	_local.resize(total)
	_tint.resize(total)
	_base.resize(total)
	for i in total:
		_base[i] = tints[i] if i < tints.size() else Color.WHITE

	# (model, chunk) -> the clumps drawn there.
	var buckets: Dictionary = {}
	var next := 0
	for group in groups.size():
		var path: String = groups[group][0]
		var placement: PackedFloat32Array = groups[group][1]
		if placement.size() < STRIDE:
			continue
		var mesh := _model_mesh(path)
		if mesh == null:
			push_warning("GrassField: no mesh in '%s', so it is not drawn." % path)
			next += placement.size() / STRIDE
			continue

		for n in placement.size() / STRIDE:
			var at := n * STRIDE
			var i := next + n
			# Standing on the land where it rolls ([Terrain]), not on a flat floor.
			var world_at := global_transform * Vector3(placement[at], 0.0, placement[at + 1])
			_home[i] = Vector3(placement[at], Terrain.height(world_at.x, world_at.z) - global_position.y,
					placement[at + 1])
			_rest[i] = Basis(Vector3.UP, placement[at + 2]).scaled(
					Vector3(placement[at + 3], placement[at + 4], placement[at + 3]))
			_bend[i] = Vector3.ZERO
			_phase[i] = randf() * TAU

			var key := Vector3i(group, floori(_home[i].x / draw_chunk),
					floori(_home[i].z / draw_chunk))
			var list: PackedInt32Array = buckets.get(key, PackedInt32Array())
			list.append(i)
			buckets[key] = list
		next += placement.size() / STRIDE
		_built_meshes[group] = mesh

	for key: Vector3i in buckets:
		_build_chunk(_built_meshes[key.x], key, buckets[key])

	_build_grid()


func _build_chunk(mesh: Mesh, key: Vector3i, members: PackedInt32Array) -> void:
	var centre := Vector3((key.y + 0.5) * draw_chunk, 0.0, (key.z + 0.5) * draw_chunk)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	# Carries the blood a fight leaves on the ground. White is clean, so an
	# unstained field looks exactly as it did before there was a channel for it.
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = members.size()

	for slot in members.size():
		var i := members[slot]
		_multi[i] = multi
		_slot[i] = slot
		_pose[i] = _rest[i]
		_local[i] = _home[i] - centre
		_tint[i] = _base[i]
		multi.set_instance_color(slot, _base[i])
		multi.set_instance_transform(slot, Transform3D(_rest[i], _local[i]))

	var node := MultiMeshInstance3D.new()
	node.name = "Chunk_%d_%d_%d" % [key.x, key.y, key.z]
	node.multimesh = multi
	node.position = centre
	_prepare(node)
	add_child(node)
	_chunks.append(node)


## The mesh inside one of the models. Taken once and shared by every chunk that
## draws it.
func _model_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		push_warning("GrassField: '%s' is missing." % path)
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var mesh: Mesh = null
	for node in root.find_children("*", "MeshInstance3D", true, false):
		mesh = (node as MeshInstance3D).mesh
		if mesh != null:
			break
	if mesh != null:
		# The stain is a per-instance colour, and a material that ignores vertex
		# colour would throw it away.
		for s in mesh.get_surface_count():
			var material := mesh.surface_get_material(s) as BaseMaterial3D
			if material != null:
				material.vertex_color_use_as_albedo = true
	root.free()
	return mesh


func _build_grid() -> void:
	_grid.clear()
	for i in _home.size():
		var key := _cell(_home[i])
		var bucket: PackedInt32Array = _grid.get(key, PackedInt32Array())
		bucket.append(i)
		_grid[key] = bucket


func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.z / cell_size))


## Pushes the three performance settings back down onto every chunk. They are
## normally applied once, as the field is built; this is for when they change
## afterwards, which is what a graphics setting does.
func refresh_meshes() -> void:
	for node in _chunks:
		_prepare(node)


func _prepare(node: MultiMeshInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadows \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if lod_bias > 0.0:
		node.lod_bias = lod_bias
	if draw_distance <= 0.0:
		node.visibility_range_end = 0.0
		return
	node.visibility_range_end = draw_distance
	node.visibility_range_end_margin = maxf(draw_distance * 0.12, 2.0)
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
#endregion


#region Staining
## Darkens the clumps within `radius` of a point, for the blood a fight leaves
## behind. Cumulative: a patch fought over twice ends up darker than one fought
## over once.
##
## A tint rather than an overlay material. Every clump is drawn out of one
## multimesh, so there is no per-clump material to swap any more — but the
## multimesh already carries a colour per instance, and the clump's own texture
## showing through a darkened tint is what a bloodied patch of grass looks like
## anyway.
func stain(point: Vector3, radius: float, tint: Color, strength: float = 0.5) -> void:
	if _multi.is_empty():
		return
	var at := to_local(point)
	var span := ceili(radius / cell_size)
	var centre := _cell(at)
	var radius_squared := radius * radius
	for cx in range(centre.x - span, centre.x + span + 1):
		for cz in range(centre.y - span, centre.y + span + 1):
			for i in _grid.get(Vector2i(cx, cz), PackedInt32Array()) as PackedInt32Array:
				var offset := _home[i] - at
				offset.y = 0.0
				if offset.length_squared() >= radius_squared:
					continue
				# Closer means bloodier, and a clump already stained only gets
				# darker rather than being re-tinted from clean.
				var falloff := 1.0 - sqrt(offset.length_squared()) / radius
				_tint[i] = _tint[i].lerp(tint, clampf(strength * falloff, 0.0, 1.0))
				if _multi[i] != null:
					_multi[i].set_instance_color(_slot[i], _tint[i])


## Puts every clump back to clean.
func clear_stains() -> void:
	for i in _multi.size():
		_tint[i] = _base[i]
		if _multi[i] != null:
			_multi[i].set_instance_color(_slot[i], _base[i])
#endregion


func _process(delta: float) -> void:
	if _rest.is_empty():
		return
	_time += delta

	var origin := to_local(_player.global_position) if _player != null else Vector3.ZERO
	_collect_pushes(origin)

	# 1. Everything a pusher is standing in, plus everything still standing back
	#    up from the last time one went through.
	var push_weight := 1.0 - exp(-bend_speed * delta)
	var recover_weight := 1.0 - exp(-recover_speed * delta)
	for i: int in _awake.keys():
		var wanted: Vector3 = _pushed.get(i, Vector3.ZERO)
		var weight := push_weight if wanted != Vector3.ZERO else recover_weight
		var bend: Vector3 = _bend[i].lerp(wanted, weight)
		if bend.length_squared() < 0.000025 and wanted == Vector3.ZERO:
			bend = Vector3.ZERO
			_awake.erase(i)
		_bend[i] = bend
		_lean(i, bend + _wind_at(i))

	# 2. Wind for the rest of the field, a slice at a time.
	var windy := wind_enabled and wind_strength > 0.0
	if _was_windy and not windy:
		_settling = maxi(wind_slices, 1)
	_was_windy = windy
	if windy:
		_sway_slice(origin)
	elif _settling > 0:
		_settling -= 1
		_sway_slice(origin)

	_slice = (_slice + 1) % maxi(wind_slices, 1)


## Which player the grass is reacting to: the nearest one to the field's own
## centre. Re-asked every `WATCH_EVERY` frames rather than every frame — grass
## bending does not need sixty-hertz accuracy about whose boots are nearest, and
## the group walk is not free.
const WATCH_EVERY := 20

func _find_watcher() -> void:
	var best: Node3D = null
	var closest := INF
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null:
			continue
		var gap := global_position.distance_squared_to(who.global_position)
		if gap < closest:
			closest = gap
			best = who
	_player = best


## Works out how hard every pusher leans on the clumps around it, and wakes the
## ones it touches.
func _collect_pushes(origin: Vector3) -> void:
	_pushed.clear()
	_watch_tick += 1
	if _watch_tick >= WATCH_EVERY or _player == null or not is_instance_valid(_player):
		_watch_tick = 0
		_find_watcher()
	if _player != null:
		_push_from(origin, reach)

	var cull := wind_radius * wind_radius
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		var at := to_local(enemy.global_position)
		if _player != null and at.distance_squared_to(origin) > cull:
			continue
		_push_from(at, reach * enemy_reach_scale)


func _push_from(origin: Vector3, radius: float) -> void:
	var radius_squared := radius * radius
	var span := ceili(radius / cell_size)
	var centre := _cell(origin)
	for cx in range(centre.x - span, centre.x + span + 1):
		for cz in range(centre.y - span, centre.y + span + 1):
			var bucket: PackedInt32Array = _grid.get(Vector2i(cx, cz), PackedInt32Array())
			for i in bucket:
				var offset := _home[i] - origin
				offset.y = 0.0
				var distance_squared := offset.length_squared()
				if distance_squared >= radius_squared or distance_squared < 0.0001:
					continue
				# Closer means further over, and the lean points away.
				var falloff := 1.0 - sqrt(distance_squared) / radius
				var wanted := offset.normalized() * (max_bend * falloff)
				# Two pushers on one clump: the stronger one wins.
				var current: Vector3 = _pushed.get(i, Vector3.ZERO)
				if wanted.length_squared() > current.length_squared():
					_pushed[i] = wanted
				_awake[i] = true


## Sways one slice of the clumps standing near the player. Wind is a pure
## function of position and time, so a clump that is skipped this frame simply
## picks up the wave where it is when its turn comes round.
func _sway_slice(origin: Vector3) -> void:
	var slices := maxi(wind_slices, 1)
	var radius_squared := wind_radius * wind_radius
	var span := ceili(wind_radius / cell_size)
	var centre := _cell(origin)
	for cx in range(centre.x - span, centre.x + span + 1):
		for cz in range(centre.y - span, centre.y + span + 1):
			var bucket: PackedInt32Array = _grid.get(Vector2i(cx, cz), PackedInt32Array())
			for i in bucket:
				if i % slices != _slice or _awake.has(i):
					continue
				if _home[i].distance_squared_to(origin) > radius_squared:
					continue
				_lean(i, _wind_at(i))


func _wind_at(index: int) -> Vector3:
	if not wind_enabled or wind_strength <= 0.0:
		return Vector3.ZERO
	var at := _home[index]
	# A travelling wave, so gusts sweep across the field instead of every blade
	# breathing together, plus a slow swell that varies the strength.
	var travel := (at.x * _wind_dir.x + at.z * _wind_dir.z) / maxf(wind_wavelength, 0.01)
	# Only a fraction of the per-clump offset goes into the wave: at full
	# strength neighbours end up completely out of step and the gust reads as
	# noise rather than as something sweeping through.
	var wave := sin(_time * wind_speed * TAU - travel * TAU + _phase[index] * 0.3)
	var swell := 0.75 + 0.25 * sin(_time * wind_speed * 0.31 + _phase[index] * 0.5)
	return _wind_dir * (wind_strength * swell * (0.55 + 0.45 * wave))


## Tips a clump over in `lean`'s direction by `lean`'s length, pivoting on its
## base and keeping the scale and yaw it was placed with.
func _lean(index: int, lean: Vector3) -> void:
	var amount := lean.length()
	if amount < 0.0005:
		_write(index, _rest[index])
		return
	# Rotating about the horizontal axis square to the lean tips the clump over
	# in that direction.
	var axis := Vector3.UP.cross(lean)
	if axis.length_squared() < 0.000001:
		return
	_write(index, Basis(axis.normalized(), amount) * _rest[index])


## Puts one clump's orientation into the chunk that draws it, and remembers it.
## The origin does not change: a clump never moves, it only tips.
func _write(index: int, basis: Basis) -> void:
	_pose[index] = basis
	var multi := _multi[index]
	if multi != null:
		multi.set_instance_transform(_slot[index], Transform3D(basis, _local[index]))
