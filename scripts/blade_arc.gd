class_name BladeArc
extends MeshInstance3D

## The crescent a blade cuts through the air.
##
## Every rendered frame the blade is emitting, the world positions of its base
## and tip are recorded with the time they were taken. The ribbon is not drawn
## through those samples directly — at a hard swing the blade turns a long way
## between two frames, and straight segments between them read as corners.
## Instead a Catmull-Rom curve is run through the base samples and another
## through the tip samples, and the ribbon is laid along both at even steps of
## *time*, so it bends round the swing as a smooth arc at any frame rate.
##
## Its look is in `blade_arc.gdshader`: a bright hairline along the edge the
## tip swept, a paler body that thins toward the hilt, wind streaks running
## back along it, the air behind it faintly warped, and a tail that frays away
## as it ages. The ribbon also narrows along its length — the inner edge is
## drawn in toward the outer one as it ages — so the cut reads as a crescent
## that sharpens to a point behind the blade.
##
## The mesh is allocated once and only its buffers are rewritten after that
## (see [SwordTrail] for why rebuilding a surface each frame is not an option).

## How long, in seconds, a point of the arc lasts behind the blade.
@export var life: float = 0.24
## Rows the ribbon is drawn with. More is smoother; 48 is plenty for a swing.
@export var rows: int = 48
## How far in toward the tip the inner edge is drawn by the time a point dies:
## 0 keeps the full width of the blade, 1 closes the tail to a point.
@export_range(0.0, 1.0) var taper: float = 0.8
## Stretches the arc a little past the tip, so the edge line is not clipped at
## the blade's point.
@export var tip_overshoot: float = 0.06
@export var core_color: Color = Color(1.0, 1.0, 1.0)
@export var glow_color: Color = Color(0.78, 0.87, 1.0)
## Overall strength; 0 hides it.
@export var intensity: float = 1.15
## How much the air behind the blade is bent.
@export var distortion: float = 0.012
## Lines drawn along the edge the tip swept: 1 for a blade, 3 for a claw (the
## marks of its claws, side by side), and how far apart, as a share of the
## arc's width.
@export var strands: int = 1
@export var strand_gap: float = 0.11
## How much of the pale sheet behind the edge shows (0: only the lines).
@export var sheet: float = 0.45
## 0 the glowing hairline; 1 the broad brushed smear that goes to smoke as it
## ages (see the shader).
@export_range(0.0, 1.0) var smear: float = 0.0
@export var smoke_color: Color = Color(0.52, 0.55, 0.62)

var emitting: bool = false

const SHADER := preload("res://assets/fx/blade_arc.gdshader")

## The heroes' cut is bent air ([code]assets/fx/cut_air.gdshader[/code]): the
## strong one, the user's pick (2026-10-05), by default. To try, F1 (F2 too, as
## F1 is the test arena's board there) steps it through the smear it always was
## (0), the air bent soft (1), strong (2) and stronger still (3).
## Only arcs under a [SkinnedRig] follow it; the orc's and the wolf's keep theirs.
static var air_look: int = 2
const AIR_NAMES := ["ხმლის კვალი: როგორც იყო", "ხმლის კვალი: ჰაერი, ნაზი", "ხმლის კვალი: ჰაერი, ძლიერი",
		"ხმლის კვალი: ჰაერი, უძლიერესი"]
## [strength, split, rim, haze, seam, wave] for 1, 2 and 3.
const AIR_LOOKS := [[], [0.022, 0.1, 0.22, 0.6, 0.0, 0.0], [0.04, 0.16, 0.3, 0.6, 0.8, 0.0],
		[0.065, 0.15, 0.4, 0.75, 1.4, 1.0]]
static var _air_shader: Shader = null
static var _switched_on: int = -1
static var _note: Label = null
var _air_material: ShaderMaterial = null
## What this arc has on; -1 till the first frame puts on `air_look`.
var _look_shown: int = -1

var _base: Node3D
var _tip: Node3D
var _t_base: Array[Vector3] = []
var _t_tip: Array[Vector3] = []
var _t_at: PackedFloat64Array = PackedFloat64Array()
var _clock: float = 0.0

var _mesh: ArrayMesh
var _material: ShaderMaterial
var _positions := PackedVector3Array()
var _uvs := PackedVector2Array()
var _drawn: bool = true


func _ready() -> void:
	top_level = true
	transform = Transform3D.IDENTITY
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	_apply_look()
	_allocate()
	_show(false)


func _apply_look() -> void:
	_material.set_shader_parameter("core_color", core_color)
	_material.set_shader_parameter("glow_color", glow_color)
	_material.set_shader_parameter("intensity", intensity)
	_material.set_shader_parameter("distortion", distortion)
	_material.set_shader_parameter("strands", strands)
	_material.set_shader_parameter("strand_gap", strand_gap)
	_material.set_shader_parameter("sheet", sheet)
	_material.set_shader_parameter("smear", smear)
	_material.set_shader_parameter("smoke_color", smoke_color)


## Pushes the look to the shader again after its properties have been changed
## (they are only read into it when the arc is made).
func restyle() -> void:
	if _material != null:
		_apply_look()


func _allocate() -> void:
	rows = maxi(rows, 4)
	_positions.resize(rows * 2)
	_uvs.resize(rows * 2)
	for r in rows:
		_uvs[r * 2] = Vector2(1.0, 0.0)
		_uvs[r * 2 + 1] = Vector2(1.0, 1.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays, [], {},
			Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	mesh = _mesh
	custom_aabb = AABB(Vector3(-500.0, -500.0, -500.0), Vector3(1000.0, 1000.0, 1000.0))


## Points the arc at the two ends of the blade it should follow.
func setup(blade_base: Node3D, blade_tip: Node3D) -> void:
	_base = blade_base
	_tip = blade_tip


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or (key.keycode != KEY_F1 and key.keycode != KEY_F2):
		return
	if not get_parent() is SkinnedRig:
		return
	# every hero's arc hears the key: only the first steps the look
	if _switched_on == Engine.get_process_frames():
		return
	_switched_on = Engine.get_process_frames()
	air_look = (air_look + 1) % AIR_NAMES.size()
	_tell(AIR_NAMES[air_look])


## The look's name a moment on the screen.
func _tell(text: String) -> void:
	if _note == null or not is_instance_valid(_note):
		var layer := CanvasLayer.new()
		layer.layer = 90
		get_tree().root.add_child(layer)
		_note = Label.new()
		_note.position = Vector2(40.0, 140.0)
		_note.add_theme_font_size_override("font_size", 30)
		_note.add_theme_color_override("font_outline_color", Color.BLACK)
		_note.add_theme_constant_override("outline_size", 8)
		layer.add_child(_note)
	_note.text = text
	_note.modulate.a = 1.0
	var fade := _note.create_tween()
	fade.tween_interval(1.4)
	fade.tween_property(_note, "modulate:a", 0.0, 0.6)


## Puts on the look `air_look` asks for, if it is not on already.
func _wear_look() -> void:
	_look_shown = air_look
	if air_look == 0:
		material_override = _material
		return
	if _air_shader == null:
		_air_shader = load("res://assets/fx/cut_air.gdshader") as Shader
	if _air_material == null:
		_air_material = ShaderMaterial.new()
		_air_material.shader = _air_shader
		_air_material.set_shader_parameter("streak_tex", load("res://assets/fx/tex/cut_air_streak.png"))
		_air_material.set_shader_parameter("break_tex", load("res://assets/fx/tex/cut_air_break.png"))
	var look: Array = AIR_LOOKS[air_look]
	_air_material.set_shader_parameter("strength", look[0])
	_air_material.set_shader_parameter("split", look[1])
	_air_material.set_shader_parameter("rim", look[2])
	_air_material.set_shader_parameter("haze", look[3])
	_air_material.set_shader_parameter("seam", look[4])
	_air_material.set_shader_parameter("wave", look[5])
	material_override = _air_material


func _process(delta: float) -> void:
	if _base == null or _tip == null:
		return
	if _look_shown != air_look and get_parent() is SkinnedRig:
		_wear_look()
	_clock += delta
	if emitting:
		var b := _base.global_position
		var t := _tip.global_position
		t += (t - b) * tip_overshoot
		# The pose only changes on a physics tick, and frames can come faster
		# than ticks (a fast display, or slowed time). A frame that finds the
		# blade where it was adds nothing: kept, it would put two samples at one
		# place and different times, and the curve would kink there.
		var last := _t_tip.size() - 1
		var moved := last < 0 or _t_tip[last].distance_squared_to(t) > 0.000001 \
				or _t_base[last].distance_squared_to(b) > 0.000001
		if moved and (last < 0 or _clock - _t_at[last] > 0.0005):
			_t_base.push_back(b)
			_t_tip.push_back(t)
			_t_at.push_back(_clock)
	# Forget what is older than the arc lasts — but keep one sample past that
	# so the spline has a point to lean on at the tail.
	while _t_at.size() > 2 and _clock - _t_at[1] >= life:
		_t_base.remove_at(0)
		_t_tip.remove_at(0)
		_t_at.remove_at(0)
	if _t_at.size() < 2 or _clock - _t_at[_t_at.size() - 1] >= life:
		if not emitting:
			_t_base.clear()
			_t_tip.clear()
			_t_at.clear()
		_show(false)
		return
	_write()
	_show(true)


## Lays the rows along the two curves at even steps of age, newest first.
func _write() -> void:
	var newest: float = _t_at[_t_at.size() - 1]
	var oldest: float = maxf(_t_at[0], _clock - life)
	var step := life / float(rows - 1)
	var seg := _t_at.size() - 2
	# The clips are keyed at 30 a second and the blade changes direction at
	# every key, which even a spline shows as a faint corner. A light blur
	# along the samples rounds those off; the newest stays where the blade is.
	var base := _smoothed(_t_base)
	var tip := _smoothed(_t_tip)
	for r in rows:
		var when := clampf(_clock - step * float(r), oldest, newest)
		# The segment `when` lies in; rows are in decreasing time, so it only
		# ever walks back.
		while seg > 0 and _t_at[seg] > when:
			seg -= 1
		var span: float = _t_at[seg + 1] - _t_at[seg]
		var u := clampf((when - _t_at[seg]) / maxf(span, 0.0001), 0.0, 1.0)
		var b := _curve(base, seg, u)
		var t := _curve(tip, seg, u)
		var age := clampf((_clock - when) / life, 0.0, 1.0)
		b = b.lerp(t, taper * pow(age, 1.3))
		_positions[r * 2] = b
		_positions[r * 2 + 1] = t
		_uvs[r * 2] = Vector2(age, 0.0)
		_uvs[r * 2 + 1] = Vector2(age, 1.0)
	_mesh.surface_update_vertex_region(0, 0, _positions.to_byte_array())
	_mesh.surface_update_attribute_region(0, 0, _uvs.to_byte_array())


## Two passes of a [1 2 1] blur over the samples, ends held.
func _smoothed(p: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = p.duplicate()
	var n := out.size()
	if n < 3:
		return out
	for _pass in 2:
		var prev := out[0]
		for i in range(1, n - 1):
			var here := out[i]
			out[i] = (prev + here * 2.0 + out[i + 1]) * 0.25
			prev = here
	return out


## Catmull-Rom through the samples, between `i` and `i + 1`.
func _curve(p: Array[Vector3], i: int, u: float) -> Vector3:
	var last := p.size() - 1
	var p1 := p[i]
	var p2 := p[mini(i + 1, last)]
	var p0 := p[i - 1] if i > 0 else p1 * 2.0 - p2
	var p3 := p[i + 2] if i + 2 <= last else p2 * 2.0 - p1
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * ((2.0 * p1) + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 \
			+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u3)


func _show(on: bool) -> void:
	if _drawn == on:
		return
	_drawn = on
	visible = on
