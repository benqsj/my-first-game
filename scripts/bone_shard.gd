class_name BoneShard
extends SpellBolt

## One of the skeleton mage's thrown bones ([MageFighter], the user's word
## 2026-10-26: as the elf throws her spears of ice, but the monster's own real
## bones, thrown straight, not tumbling): a thigh bone, a shin, an arm bone or
## the skull, cut out of the skeleton's own body ([method cut]). A
## [SpellBolt] in how it flies — after the hero, dodged only in time, flying
## on past when shaken off — at the heroes (`against_heroes`), with a violet
## streak behind it, breaking into chips of bone where it strikes.

const VIOLET := Color(0.62, 0.38, 1.0)
const VIOLET_HOT := Color(0.92, 0.82, 1.0)
const BONE := Color(0.9, 0.86, 0.76)

## The piece it is: set before it enters the tree.
var piece_mesh: Mesh
var piece_material: Material


func _ready() -> void:
	glow_colour = VIOLET
	super()
	# as the elf's spears: off at a steady pace, faster and faster
	start_share = 0.4
	ramp_share = 1.0
	ramp_distance = 12.0
	ramp_min = 3.0
	ramp_max = 24.0
	ramp_curve = 2.0
	steer = 24.0
	if _model != null:
		_model.queue_free()
		_model = null
	if piece_mesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = piece_mesh
		mi.material_override = piece_material
		_model = mi
		add_child(_model)
	if _light != null:
		_light.light_color = VIOLET
		_light.light_energy = 1.2
		_light.omni_range = 2.4


func _process(delta: float) -> void:
	super(delta)
	# its own size from the moment it is thrown (the bolt swells from a spark)
	if _model != null and not _fading and not _spent:
		_model.scale = Vector3.ONE


## A thin violet streak behind it.
func _lay_trail() -> void:
	var into := get_parent()
	if into == null:
		return
	_tails.append(_tail(into, 0.12, 0.16, 1.4, Color(VIOLET_HOT, 0.85), Color(VIOLET, 0.0)))
	_tails[0].head = _model if _model != null else self


## It breaks where it strikes: a violet flash, chips of bone thrown out.
func _burst(where: Vector3) -> void:
	for child in get_children():
		if child is Node3D and child != _light and child != _steady:
			(child as Node3D).visible = false
	var into := get_parent()
	if into == null:
		queue_free()
		return
	SkillFx.flash(into, where, VIOLET_HOT, 0.4, 0.16, 2.5)
	SkillFx.particles(into, where, {"amount": 10, "one_shot": true, "explosiveness": 1.0, "life": 0.8,
			"speed": Vector2(1.5, 4.0), "spread": 180.0, "gravity": Vector3(0, -12, 0),
			"size": Vector2(0.04, 0.09), "spin": true, "add": false,
			"colors": [Color(BONE, 1.0), Color(BONE, 1.0), Color(BONE, 0.0)]})
	if _light != null:
		_light.global_position = where
		_light.light_energy = 3.0
		create_tween().tween_property(_light, "light_energy", 0.0, 0.3)
	get_tree().create_timer(0.4).timeout.connect(queue_free)


## A piece of a skeleton's own body (the Biped Creatures' skeleton meshes):
## the triangles `bone` carries in `body`, centred, its long side turned onto
## +Y and scaled to `size` metres long. The body's own material goes with it
## ([method material_of]).
static func cut(body: MeshInstance3D, bone: String, size: float) -> ArrayMesh:
	if body == null or body.mesh == null or body.skin == null:
		return null
	var arr := body.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if verts.is_empty() or idx.is_empty():
		return null
	var per := floori(bones.size() / float(verts.size()))
	var want := -1
	for b in body.skin.get_bind_count():
		if String(body.skin.get_bind_name(b)) == bone:
			want = b
	if want < 0 or per <= 0:
		return null
	var own := PackedInt32Array()
	own.resize(verts.size())
	for v in verts.size():
		var best := 0
		for k in per:
			if w[v * per + k] > w[v * per + best]:
				best = k
		own[v] = bones[v * per + best]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var tris: Array[int] = []
	for t in range(0, idx.size(), 3):
		if own[idx[t]] == want and own[idx[t + 1]] == want and own[idx[t + 2]] == want:
			for q in 3:
				tris.append(idx[t + q])
				lo = lo.min(verts[idx[t + q]])
				hi = hi.max(verts[idx[t + q]])
	if tris.is_empty():
		return null
	var ext := hi - lo
	var centre := (lo + hi) * 0.5
	var turn := Basis()
	if ext.x >= ext.y and ext.x >= ext.z:
		turn = Basis(Vector3.BACK, PI * 0.5)
	elif ext.z >= ext.y:
		turn = Basis(Vector3.RIGHT, PI * 0.5)
	var k := size / maxf(ext[ext.max_axis_index()], 0.01)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: int in tris:
		st.set_normal(turn * norms[v])
		if uvs.size() > v:
			st.set_uv(uvs[v])
		st.add_vertex(turn * ((verts[v] - centre) * k))
	return st.commit()


static func material_of(body: MeshInstance3D) -> Material:
	if body == null:
		return null
	return body.material_override if body.material_override != null else body.get_active_material(0)
