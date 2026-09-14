class_name GrassField
extends Node3D

## Bends grass out of the way as something walks or rolls through it, and keeps
## the whole field swaying in the wind.
##
## Every child whose name starts with `grass_prefix` is treated as a clump. Each
## clump keeps the orientation it was placed with; the lean is a rotation
## layered on top of that, about a horizontal axis through the clump's base, so
## the blades tip away from whatever is pushing them and spring back once it has
## passed.
##
## Clumps are bucketed into a uniform grid at startup, so a field of several
## thousand only ever costs a handful of cell lookups per pusher per frame:
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

@export_group("Bending")
## Only children whose name starts with this are bent. Rocks and other props
## sitting in the same scatter node are left alone.
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
## Off by default, and it is the single biggest thing on this node: a field of a
## few thousand clumps has to be re-drawn once per shadow cascade on top of the
## visible pass, which measured as roughly half the frame on an M1 — for shadows
## that, at this size of blade, are almost impossible to see. Grass still
## *receives* the shadows of everything around it.
@export var casts_shadows: bool = false
## How eagerly a clump drops to a coarser level of detail, as a multiplier on
## the viewport's threshold — *below* 1 means sooner. The clump mesh is 8 256
## triangles and there are well over a thousand of them, so leaning on the LODs
## the importer generated is what keeps the triangle count sane; a blade twenty
## metres off does not need its full silhouette. Applied per clump rather than
## through the viewport so the buildings and creatures keep their detail.
@export var lod_bias: float = 0.06
## Clumps further than this from the player are not swayed at all. Kept short
## on purpose: writing a transform per clump per frame is the expensive part of
## this script, and a blade of grass 25 m out is not visibly moving anyway.
@export var wind_radius: float = 22.0
## The wind pass is split across this many frames. A gust cycle lasts about a
## second, so a clump updated every fifth frame still reads as smooth.
@export var wind_slices: int = 5
## Side of a grid bucket, in metres. Wants to be a little over `reach`.
@export var cell_size: float = 2.5

var _clumps: Array[Node3D] = []
var _rest: Array[Basis] = []
var _home: PackedVector3Array = PackedVector3Array()
## Random per-clump offset so neighbours do not sway in lockstep.
var _phase: PackedFloat32Array = PackedFloat32Array()
## Current lean per clump: direction is which way it leans, length is how far.
var _bend: Array[Vector3] = []

## Grid cell -> indices of the clumps standing in it.
var _grid: Dictionary = {}
## Indices that are mid-bend or mid-recovery, and so need every frame.
var _awake: Dictionary = {}
## Scratch, reused every frame to avoid churning arrays.
var _pushed: Dictionary = {}

var _player: Node3D
var _time: float = 0.0
var _slice: int = 0
var _wind_dir: Vector3 = Vector3.FORWARD
## Frames of sway pass still owed after the wind is switched off, so the field
## settles back upright instead of freezing mid-gust.
var _settling: int = 0
var _was_windy: bool = false


func _ready() -> void:
	for child in get_children():
		var node := child as Node3D
		if node == null or not node.name.begins_with(grass_prefix):
			continue
		_clumps.append(node)
		_rest.append(node.transform.basis)
		_bend.append(Vector3.ZERO)
		_home.append(node.global_position)
		_phase.append(randf() * TAU)
		_prepare_meshes(node)

	_build_grid()

	var flat := Vector3(wind_direction.x, 0.0, wind_direction.y)
	_wind_dir = flat.normalized() if not flat.is_zero_approx() else Vector3.FORWARD

	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		push_warning("GrassField: no node in the \"player\" group, grass will not react.")


## Pushes the three performance settings back down onto every clump. They are
## normally applied once, as the field is built; this is for when they change
## afterwards, which is what a graphics setting does.
func refresh_meshes() -> void:
	for clump in _clumps:
		_prepare_meshes(clump)


## Settings that have to be reached through to the meshes inside an instanced
## clump: how far away it is still worth drawing, and whether it goes into the
## shadow map at all.
func _prepare_meshes(clump: Node3D) -> void:
	var stack: Array[Node] = [clump]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var mesh := node as GeometryInstance3D
		if mesh == null:
			continue
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if lod_bias > 0.0:
			mesh.lod_bias = lod_bias
		if draw_distance <= 0.0:
			continue
		mesh.visibility_range_end = draw_distance
		mesh.visibility_range_end_margin = maxf(draw_distance * 0.12, 2.0)
		mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _build_grid() -> void:
	_grid.clear()
	for i in _clumps.size():
		var key := _cell(_home[i])
		var bucket: PackedInt32Array = _grid.get(key, PackedInt32Array())
		bucket.append(i)
		_grid[key] = bucket


func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.z / cell_size))


func _process(delta: float) -> void:
	_time += delta

	var origin := _player.global_position if _player != null else Vector3.ZERO
	_collect_pushes()

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


## Works out how hard every pusher leans on the clumps around it, and wakes the
## ones it touches.
func _collect_pushes() -> void:
	_pushed.clear()
	if _player != null:
		_push_from(_player.global_position, reach)

	var cull := wind_radius * wind_radius
	var origin := _player.global_position if _player != null else Vector3.ZERO
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		var at := enemy.global_position
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
		_clumps[index].transform.basis = _rest[index]
		return
	# Rotating about the horizontal axis square to the lean tips the clump over
	# in that direction.
	var axis := Vector3.UP.cross(lean)
	if axis.length_squared() < 0.000001:
		return
	_clumps[index].transform.basis = Basis(axis.normalized(), amount) * _rest[index]
