class_name SwordTrail
extends MeshInstance3D

## The pale streak a blade leaves behind as it cuts the air.
##
## Every frame the blade is emitting, the world positions of its base and tip
## are pushed onto a short ring of samples. Those pairs are stitched into a
## triangle strip, so the ribbon is the surface the edge actually swept — it
## follows any swing without being authored per attack. Samples fade out by age,
## which is what makes the streak trail off behind the blade instead of
## snapping away when the swing ends.

## How many blade positions the ribbon remembers. More gives a longer streak.
@export var sample_count: int = 16
## Seconds a sample takes to fade out completely.
@export var fade_time: float = 0.22
## Colour at the leading edge. Alpha scales the whole ribbon.
@export var tint: Color = Color(1.0, 1.0, 1.0, 0.5)

var emitting: bool = false

var _base: Node3D
var _tip: Node3D
var _base_points: Array[Vector3] = []
var _tip_points: Array[Vector3] = []
var _ages: Array[float] = []
var _immediate: ImmediateMesh


func _ready() -> void:
	# World-space vertices, so the ribbon stays put while the character moves on.
	top_level = true
	transform = Transform3D.IDENTITY
	# The mesh is rebuilt from world coordinates, so its bounds do not describe
	# where it actually is; a wide margin keeps it from being culled.
	extra_cull_margin = 16.0
	cast_shadow = SHADOW_CASTING_SETTING_OFF

	_immediate = ImmediateMesh.new()
	mesh = _immediate

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.disable_receive_shadows = true
	material_override = mat


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
		while _base_points.size() > sample_count:
			_drop_oldest()

	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] >= fade_time:
		_drop_oldest()

	_rebuild()


func _drop_oldest() -> void:
	_base_points.remove_at(0)
	_tip_points.remove_at(0)
	_ages.remove_at(0)


func _rebuild() -> void:
	_immediate.clear_surfaces()
	if _base_points.size() < 2:
		return

	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var last := maxf(_base_points.size() - 1.0, 1.0)
	for i in _base_points.size():
		# Two fades multiply: older samples are dimmer, and the tail of the
		# ribbon is dimmer than its leading edge.
		var by_age := 1.0 - clampf(_ages[i] / maxf(fade_time, 0.001), 0.0, 1.0)
		var along := float(i) / last
		var alpha := tint.a * by_age * along
		var colour := Color(tint.r, tint.g, tint.b, alpha)

		_immediate.surface_set_color(Color(colour.r, colour.g, colour.b, alpha * 0.35))
		_immediate.surface_add_vertex(_base_points[i])
		_immediate.surface_set_color(colour)
		_immediate.surface_add_vertex(_tip_points[i])
	_immediate.surface_end()
