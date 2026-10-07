class_name DarkRift
extends Node3D

## The tear in the sky the dark elf's comets come out of ([DarkSkills]): a
## whirl of black cloud lit from inside in violet, a ring of runes turning
## under it, opening fast, flickering as each comet leaves it, and closing
## again when the last is gone.

const RADIUS := 4.2
const OPEN_TIME := 0.35
const CLOSE_TIME := 0.5

var lasts: float = 2.0

var _age: float = 0.0
var _runes: MeshInstance3D
var _runes_mat: StandardMaterial3D
var _inner: MeshInstance3D
var _inner_mat: StandardMaterial3D
var _cloud: GPUParticles3D
var _light: OmniLight3D
var _closing := false


## Torn at `at`, facing `toward` (the way the comets will go out of it).
static func tear(into: Node, at: Vector3, seconds: float, toward: Vector3 = Vector3.DOWN) -> DarkRift:
	if into == null:
		return null
	var r := DarkRift.new()
	r.lasts = seconds
	into.add_child(r)
	r.global_position = at
	var y := toward.normalized() if toward.length_squared() > 0.0001 else Vector3.DOWN
	var x := y.cross(Vector3.UP)
	x = x.normalized() if x.length_squared() > 0.0001 else Vector3.RIGHT
	r.global_basis = Basis(x, y, x.cross(y)).orthonormalized()
	return r


func _ready() -> void:
	_runes_mat = _flat(DarkFx.RUNES, DarkFx.VOID)
	_runes = _disc(_runes_mat, RADIUS * 2.0)
	_inner_mat = _flat(DarkFx.SPIKES, DarkFx.HOT)
	_inner = _disc(_inner_mat, RADIUS * 1.2)
	_inner.position = Vector3.UP * 0.05
	# the black cloud, whirling in on itself
	_cloud = SkillFx.particles(self, global_position + Vector3.UP * 0.3, {"amount": 36, "life": 1.4,
			"ring": Vector2(RADIUS * 0.3, RADIUS * 1.1), "speed": Vector2(0.0, 0.3), "orbit": -1.5,
			"tangent": 5.0, "size": Vector2(1.6, 2.6), "grow": 0.5, "add": false, "tex": DarkFx.PUFF,
			"spin": true, "local": true,
			"colors": [Color(DarkFx.INK, 0.0), Color(DarkFx.INK, 0.9), Color(0.07, 0.03, 0.1, 0.0)]})
	SkillFx.particles(self, global_position, {"amount": 30, "life": 0.9, "local": true,
			"ring": Vector2(RADIUS * 0.2, RADIUS), "speed": Vector2(0.0, 0.4), "orbit": -3.0, "tangent": 6.0,
			"size": Vector2(0.4, 0.8), "grow": 0.4, "tex": DarkFx.FLAME, "spin": true,
			"colors": [Color(DarkFx.HOT, 0.0), Color(DarkFx.VOID, 0.8), Color(DarkFx.VOID, 0.0)]})
	_light = OmniLight3D.new()
	_light.light_color = DarkFx.VOID
	_light.light_energy = 0.0
	_light.omni_range = 18.0
	add_child(_light)
	_light.position = Vector3.DOWN * 1.0
	var b := global_basis.orthonormalized()
	global_basis = b.scaled(Vector3.ONE * 0.05)


## A flat, glowing, added picture, both faces.
static func _flat(tex: Texture2D, color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.albedo_color = Color(color, 0.0)
	return m


func _disc(mat: Material, across: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(across, across)
	q.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## A comet goes out of it: it flares.
func pulse() -> void:
	_light.light_energy = 6.0
	_inner_mat.albedo_color.a = 1.0


func _process(delta: float) -> void:
	_age += delta
	var open := clampf(_age / OPEN_TIME, 0.0, 1.0)
	var shut := clampf((_age - lasts) / CLOSE_TIME, 0.0, 1.0)
	var k := (1.0 - pow(1.0 - open, 3.0)) * (1.0 - shut * shut)
	var b := global_basis.orthonormalized()
	global_basis = b.scaled(Vector3.ONE * maxf(k, 0.05))
	_runes.rotation.y += delta * 0.9
	_inner.rotation.y -= delta * 2.2
	_runes_mat.albedo_color.a = 0.9 * k
	_inner_mat.albedo_color.a = lerpf(_inner_mat.albedo_color.a, 0.55 * k, 1.0 - exp(-6.0 * delta))
	_light.light_energy = lerpf(_light.light_energy, 2.0 * k, 1.0 - exp(-5.0 * delta))
	if shut > 0.0 and not _closing:
		_closing = true
		_cloud.emitting = false
	if shut >= 1.0:
		queue_free()
