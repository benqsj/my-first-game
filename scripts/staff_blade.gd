class_name StaffBlade
extends Node3D

## The skeleton mage's blade of light grown out of its staff ([MageFighter],
## the user's word 2026-10-26, shown in films first): it gathers along the
## staff as the staff goes up, the swing (CR_SK_GreatSwordSpell) carries it
## over and down onto the hero, an arc of light behind it, a burst where it
## strikes; then it goes out. The blow itself is the mage's (host); this is
## what every peer sees. It goes out if the swing is cut short.

const GROW := 0.37
const HIT := 2.53
const LENGTH := 1.9

var caster: Node3D
var clip: StringName = &"CR_SK_GreatSwordSpell"
var skeleton: Skeleton3D
var staff_mesh: MeshInstance3D

var _holder: Node3D
var _blade: MeshInstance3D
var _inner: MeshInstance3D
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _im: ImmediateMesh
var _hist: Array = []
var _flash: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _burst: OmniLight3D
var _age: float = 0.0
var _last_t: float = 0.0
var _hit_at: float = -1.0
var _gone_at: float = -1.0


static func grow(into: Node, by: Node3D, sk: Skeleton3D, staff: MeshInstance3D, clip_name: StringName) -> StaffBlade:
	if into == null or by == null or sk == null:
		return null
	var b := StaffBlade.new()
	b.caster = by
	b.skeleton = sk
	b.staff_mesh = staff
	b.clip = clip_name
	into.add_child(b)
	return b


func _ready() -> void:
	top_level = true
	var bone := skeleton.find_bone("R_equip_joint")
	var far := Vector3(0, 1.4, 0)
	if staff_mesh != null and staff_mesh.mesh != null:
		var bind := Transform3D()
		if staff_mesh.skin != null:
			for i in staff_mesh.skin.get_bind_count():
				if staff_mesh.skin.get_bind_name(i) == &"R_equip_joint" or staff_mesh.skin.get_bind_bone(i) == bone:
					bind = staff_mesh.skin.get_bind_pose(i)
		far = Vector3.ZERO
		for v: Vector3 in staff_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := bind * v
			if p.length() > far.length():
				far = p
	var att := BoneAttachment3D.new()
	skeleton.add_child(att)
	att.bone_idx = bone
	_holder = Node3D.new()
	att.add_child(_holder)
	_holder.position = far
	_holder.basis = Basis(Quaternion(Vector3.UP, far.normalized() if far.length() > 0.01 else Vector3.UP))
	tree_exiting.connect(func() -> void:
		if is_instance_valid(att):
			att.queue_free())
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_color = Color(0.7, 0.5, 1.0, 0.9)
	var core := _mat.duplicate() as StandardMaterial3D
	core.albedo_color = Color(1.0, 0.95, 1.0, 0.9)
	_blade = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.42, 1.0, 0.1)
	_blade.mesh = pm
	_blade.material_override = _mat
	_holder.add_child(_blade)
	_inner = MeshInstance3D.new()
	var pm2 := PrismMesh.new()
	pm2.size = Vector3(0.14, 1.0, 0.12)
	_inner.mesh = pm2
	_inner.material_override = core
	_holder.add_child(_inner)
	var guard := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.7, 0.08, 0.12)
	guard.mesh = gb
	guard.material_override = _mat
	_holder.add_child(guard)
	for mi: MeshInstance3D in [_blade, _inner, guard]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.light_color = Color(0.7, 0.5, 1.0)
	_light.omni_range = 6.0
	_holder.add_child(_light)
	var trail := MeshInstance3D.new()
	_im = ImmediateMesh.new()
	trail.mesh = _im
	var tm := _mat.duplicate() as StandardMaterial3D
	tm.albedo_color = Color(1, 1, 1, 1)
	tm.vertex_color_use_as_albedo = true
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail.material_override = tm
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	_flash = MeshInstance3D.new()
	var fs := SphereMesh.new()
	_flash.mesh = fs
	_flash_mat = _mat.duplicate() as StandardMaterial3D
	_flash.material_override = _flash_mat
	_flash.visible = false
	add_child(_flash)
	_burst = OmniLight3D.new()
	_burst.light_color = Color(0.75, 0.55, 1.0)
	_burst.omni_range = 8.0
	_burst.light_energy = 0.0
	add_child(_burst)
	_holder.visible = false


func _process(delta: float) -> void:
	_age += delta
	var alive := is_instance_valid(caster) and not bool(caster.get("is_dead"))
	var t := _last_t
	if alive and _gone_at < 0.0:
		var anim: Variant = caster.get("_anim")
		if anim != null and StringName(anim.call(&"current_clip")) == clip:
			t = float(anim.call(&"clip_position"))
		elif _hit_at < 0.0:
			_gone_at = _age
	elif _gone_at < 0.0:
		_gone_at = _age
	_last_t = maxf(t, _last_t)
	t = _last_t
	if _hit_at >= 0.0 and _gone_at < 0.0 and _age - _hit_at > 0.35:
		_gone_at = _age
	if not is_instance_valid(_holder):
		queue_free()
		return
	var g := clampf((t - GROW) / 0.45, 0.0, 1.0)
	var gone := clampf((_age - _gone_at) / 0.4, 0.0, 1.0) if _gone_at >= 0.0 else 0.0
	var l := LENGTH * (1.0 - pow(1.0 - g, 3.0)) * (1.0 - gone)
	_holder.visible = g > 0.0 and gone < 1.0
	_blade.scale = Vector3(1, maxf(l, 0.01), 1)
	_blade.position = Vector3(0, l * 0.5, 0)
	_inner.scale = Vector3(1, maxf(l * 0.92, 0.01), 1)
	_inner.position = Vector3(0, l * 0.46, 0)
	_light.position = Vector3(0, l * 0.6, 0)
	_light.light_energy = 2.5 * g * (1.0 - gone)
	_mat.albedo_color = Color(0.7, 0.5, 1.0, 0.9 * (0.85 + 0.15 * sin(_age * 30.0)))
	var hb := _holder.global_transform
	if _holder.visible:
		_hist.push_front([hb * Vector3(0, l * 0.55, 0), hb * Vector3(0, l, 0)])
	if _hist.size() > 5:
		_hist.pop_back()
	_im.clear_surfaces()
	if _hist.size() >= 2 and _holder.visible:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for k in _hist.size():
			var fa := 0.55 * (1.0 - float(k) / (_hist.size() - 1))
			_im.surface_set_color(Color(0.75, 0.55, 1.0, fa))
			_im.surface_add_vertex(_hist[k][0])
			_im.surface_set_color(Color(0.75, 0.55, 1.0, fa))
			_im.surface_add_vertex(_hist[k][1])
		_im.surface_end()
	if t >= HIT and _hit_at < 0.0 and _gone_at < 0.0:
		_hit_at = _age
		var tip := hb * Vector3(0, l, 0)
		_flash.global_position = Vector3(tip.x, caster.global_position.y + 0.15, tip.z)
		_burst.global_position = _flash.global_position + Vector3.UP * 0.7
	if _hit_at >= 0.0:
		var u := clampf((_age - _hit_at) / 0.5, 0.0, 1.0)
		_flash.visible = u < 1.0
		_flash.scale = Vector3(1.0, 0.6, 1.0) * (0.15 + u * 0.9)
		_flash_mat.albedo_color = Color(0.85, 0.7, 1.0, 0.7 * (1.0 - u) * (1.0 - u))
		_burst.light_energy = 7.0 * (1.0 - u)
	if _gone_at >= 0.0 and _age - _gone_at > 0.6:
		queue_free()
