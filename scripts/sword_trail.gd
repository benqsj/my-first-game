class_name SwordTrail
extends MeshInstance3D

## The pale streak a blade leaves behind as it cuts the air.
##
## Every frame the blade is emitting, the world positions of its base and tip
## are pushed onto a short ring of samples. Those pairs are stitched into a
## triangle strip, so the ribbon is the surface the edge actually swept — it
## follows any swing without being authored per attack. The streak fades out
## behind the blade instead of snapping away when the swing ends.
##
## The mesh is allocated **once** and only its vertex positions are rewritten
## after that. Building a fresh surface every frame — with `ImmediateMesh` or by
## re-adding one to an `ArrayMesh` — costs tens of milliseconds a frame on this
## renderer no matter how few vertices are in it, which is enough to hitch the
## whole game every time anything swings. Writing into the buffer that is
## already there costs nothing measurable.
##
## Two things follow from allocating up front:
##
## * The ribbon always has `sample_count` slots. When fewer samples than that
##   have been taken, they are spread across all the slots, which leaves
##   zero-area triangles where slots repeat — invisible, and it keeps the fade
##   gradient lined up with the visible part of the streak.
## * The fade is baked into the vertex colours once (it only ever depends on how
##   far along the ribbon a vertex is) and the overall fade-out after a swing
##   rides on the material's alpha, so no attribute buffer has to be touched.

## How many blade positions the ribbon remembers. More gives a longer streak.
@export var sample_count: int = 16
## Seconds the streak takes to fade out once the blade stops.
@export var fade_time: float = 0.22
## Colour at the leading edge. Alpha scales the whole ribbon.
@export var tint: Color = Color(1.0, 1.0, 1.0, 0.5)
## How dim the ribbon's inner edge is next to its outer one.
@export var inner_edge_alpha: float = 0.35

var emitting: bool = false

var _base: Node3D
var _tip: Node3D
var _base_points: Array[Vector3] = []
var _tip_points: Array[Vector3] = []
var _ages: Array[float] = []

var _mesh: ArrayMesh
var _material: StandardMaterial3D
var _slots: int = 0
## Reused every frame so the per-frame write allocates nothing.
var _scratch: PackedVector3Array = PackedVector3Array()
## Mirrors `visible`, so the flag is only written when it actually changes.
## Starts true because that is what a fresh node's `visible` is.
var _drawn: bool = true


func _ready() -> void:
	# World-space vertices, so the ribbon stays put while the character moves on.
	top_level = true
	transform = Transform3D.IDENTITY
	cast_shadow = SHADOW_CASTING_SETTING_OFF

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.disable_receive_shadows = true
	material_override = _material

	_allocate()
	_show(false)


## Builds the one surface this trail will ever have: a strip of `sample_count`
## vertex pairs, parked at the origin, with the length-wise fade baked into the
## vertex colours.
func _allocate() -> void:
	_slots = maxi(sample_count, 2)
	var count := _slots * 2
	var verts := PackedVector3Array()
	var colours := PackedColorArray()
	verts.resize(count)
	colours.resize(count)
	_scratch.resize(count)

	var last := float(_slots - 1)
	for slot in _slots:
		# The tail of the ribbon is dimmer than its leading edge, and the inner
		# edge is dimmer than the outer one.
		var along := float(slot) / last
		colours[slot * 2] = Color(tint.r, tint.g, tint.b, along * inner_edge_alpha)
		colours[slot * 2 + 1] = Color(tint.r, tint.g, tint.b, along)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colours

	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays, [], {},
			Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	mesh = _mesh

	# The vertices are world-space and the buffer is written to directly, so the
	# surface's own bounds never describe where the ribbon actually is. A custom
	# box large enough to cover the level stops it being culled — and, unlike
	# rebuilding the surface, means nothing has to be re-inserted into the
	# renderer's spatial index as the streak moves.
	custom_aabb = AABB(Vector3(-500.0, -500.0, -500.0), Vector3(1000.0, 1000.0, 1000.0))


## Points the trail at the two ends of the blade it should follow.
func setup(blade_base: Node3D, blade_tip: Node3D) -> void:
	_base = blade_base
	_tip = blade_tip


func _process(delta: float) -> void:
	if _base == null or _tip == null:
		return

	if emitting:
		_base_points.push_back(_base.global_position)
		_tip_points.push_back(_tip.global_position)
		_ages.push_back(0.0)
		while _base_points.size() > _slots:
			_drop_oldest()

	if _ages.is_empty():
		_show(false)
		return

	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] >= fade_time:
		_drop_oldest()

	if _base_points.size() < 2:
		_show(false)
		return

	# The whole streak dims once the blade stops feeding it: while a swing is
	# running the newest sample is always fresh, so this stays at full strength.
	var freshest: float = _ages[_ages.size() - 1]
	var strength := 1.0 - clampf(freshest / maxf(fade_time, 0.001), 0.0, 1.0)
	_material.albedo_color = Color(1.0, 1.0, 1.0, tint.a * strength)

	_write_positions()
	_show(true)


func _drop_oldest() -> void:
	_base_points.remove_at(0)
	_tip_points.remove_at(0)
	_ages.remove_at(0)


## Spreads however many samples exist across all the slots and pushes them into
## the vertex buffer in place.
func _write_positions() -> void:
	var taken := _base_points.size()
	var last := float(_slots - 1)
	for slot in _slots:
		var i := mini(int(round(float(slot) / last * float(taken - 1))), taken - 1)
		_scratch[slot * 2] = _base_points[i]
		_scratch[slot * 2 + 1] = _tip_points[i]
	_mesh.surface_update_vertex_region(0, 0, _scratch.to_byte_array())


func _show(on: bool) -> void:
	if _drawn == on:
		return
	_drawn = on
	visible = on
