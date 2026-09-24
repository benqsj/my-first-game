class_name GlowTail
extends MeshInstance3D

## A tail of light behind something flying: the mage's bolt.
##
## Where [SwordTrail] is a flat band swept by two points — right for a blade,
## which *is* a flat thing cutting through the air — this is a line through
## the points the head has passed, turned every frame to face the camera, so
## it has the same body from any side. Seen end-on or edge-on, it is still a
## streak.
##
## * **It tapers.** Full width at the head, nothing at the tail, so it reads
##   as one thing leaving a wake rather than a tube.
## * **It carries its colour along its length**: hot and pale where the head
##   is, cooling to a deep gold and to nothing further back.
## * **It is as long as the flight is fast.** Points live `life` seconds, so a
##   bolt that is only gathering pace has a short tail and one at full speed a
##   long one — the build-up is seen in the tail as well as the head.
## * **Its edges are soft**, across its width, from a small texture drawn once.
##
## As [SwordTrail] does, it allocates its mesh once and only rewrites vertex
## positions after that: rebuilding a surface a frame is what hitches.
## It frees itself once it has been let go of and has faded.

@export var sample_count: int = 30
## Width at the head, in metres.
@export var width: float = 0.12
## Seconds a point stays on the tail.
@export var life: float = 0.3
## Above 1 the tail stays thick further back before it narrows.
@export var taper: float = 1.0
@export var head_colour: Color = Color(1.0, 0.97, 0.85, 1.0)
@export var tail_colour: Color = Color(1.0, 0.5, 0.12, 0.0)

## Set false when whatever it trails is gone; the tail then fades out behind
## it and the node goes.
var emitting: bool = true
## What it trails, if anything: its position *now* is drawn as the tail's head
## every frame, so the tail stays joined to it between the physics ticks that
## feed the samples — at forty metres a second a tick is most of a metre.
var head: Node3D
## Where on the head, in the head's own frame, the tail joins it.
var head_offset: Vector3 = Vector3.ZERO

var _points: Array[Vector3] = []
var _ages: Array[float] = []
var _mesh: ArrayMesh
var _material: StandardMaterial3D
var _scratch := PackedVector3Array()
var _slots: int = 0

static var _edge_tex: ImageTexture = null


func _ready() -> void:
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
	_material.albedo_texture = _edge_texture()
	material_override = _material
	_allocate()
	visible = false


func _allocate() -> void:
	_slots = maxi(sample_count, 2)
	var count := _slots * 2
	var verts := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(count)
	colours.resize(count)
	uvs.resize(count)
	_scratch.resize(count)
	var last := float(_slots - 1)
	for slot in _slots:
		# Slot 0 is the tail, the last slot the head.
		var along := float(slot) / last
		var c := tail_colour.lerp(head_colour, pow(along, 1.4))
		colours[slot * 2] = c
		colours[slot * 2 + 1] = c
		uvs[slot * 2] = Vector2(0.0, along)
		uvs[slot * 2 + 1] = Vector2(1.0, along)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays, [], {},
			Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	mesh = _mesh
	custom_aabb = AABB(Vector3(-500.0, -500.0, -500.0), Vector3(1000.0, 1000.0, 1000.0))


## Where the head is now. Called once a frame by whatever is flying.
func push(point: Vector3) -> void:
	if not emitting:
		return
	if not _points.is_empty() and _points[_points.size() - 1].distance_squared_to(point) < 0.0004:
		# Not moved enough to be worth a sample: the head just follows.
		_points[_points.size() - 1] = point
		_ages[_ages.size() - 1] = 0.0
		return
	_points.push_back(point)
	_ages.push_back(0.0)
	while _points.size() > _slots:
		_points.remove_at(0)
		_ages.remove_at(0)


func _process(delta: float) -> void:
	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] >= life:
		_points.remove_at(0)
		_ages.remove_at(0)
	var points := _points.duplicate()
	var ages := _ages.duplicate()
	if emitting and head != null and is_instance_valid(head) and head.is_inside_tree():
		points.append(head.global_transform * head_offset)
		ages.append(0.0)
	if points.size() < 2:
		visible = false
		if not emitting:
			queue_free()
		return
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else Vector3(0, 100, 0)
	var taken := points.size()
	var last := float(_slots - 1)
	for slot in _slots:
		var f := float(slot) / last
		# The samples there are, spread over every slot, tail to head.
		var x := f * float(taken - 1)
		var i := mini(int(x), taken - 2)
		var p: Vector3 = (points[i] as Vector3).lerp(points[i + 1], x - float(i))
		var ahead: Vector3 = (points[i + 1] as Vector3) - (points[i] as Vector3)
		if ahead.length_squared() < 1e-8:
			ahead = Vector3.FORWARD
		var side := ahead.cross(eye - p)
		side = side.normalized() if side.length_squared() > 1e-8 else Vector3.UP
		# Thin at the tail and thinned by age, so a tail left behind shrinks
		# away rather than just going see-through.
		var age := lerpf(ages[i], ages[i + 1], x - float(i))
		var w := width * pow(f, taper) * sqrt(clampf(1.0 - age / life, 0.0, 1.0))
		_scratch[slot * 2] = p - side * w * 0.5
		_scratch[slot * 2 + 1] = p + side * w * 0.5
	_mesh.surface_update_vertex_region(0, 0, _scratch.to_byte_array())
	visible = true


## Soft across the width, solid down the length.
static func _edge_texture() -> ImageTexture:
	if _edge_tex != null:
		return _edge_tex
	var w := 32
	var img := Image.create(w, 2, false, Image.FORMAT_RGBA8)
	for x in w:
		var u := absf(float(x) / float(w - 1) * 2.0 - 1.0)
		var a := clampf(1.0 - u * u, 0.0, 1.0)
		for y in 2:
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_edge_tex = ImageTexture.create_from_image(img)
	return _edge_tex
