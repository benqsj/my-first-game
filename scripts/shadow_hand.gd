class_name ShadowHand
extends Node3D

## One of the dark elf's Dark Hands ([ShadowGrasp]): a long black arm thrust
## up out of the ground, its hand open, the long-clawed fingers closing on what
## it reached for, held shut while it holds, then opening and sinking back in a
## flare of black fire, burning away as it goes. Made of [method DarkFx.flesh].
##
## Its palm faces +Z: [method reach] turns it on what it grabs. Drawn the same on
## every peer; it does nothing to anyone (the grasp does: [ShadowGrasp]).

## Its parts' lengths at a scale of 1: the arm up out of the ground to the
## elbow (`ELBOW` of it above the ground), the forearm bent from there over
## what it holds, the hand on that.
const ARM := 1.4
const ELBOW := 0.6
const FORE := 0.55
## How deep it starts, under the ground.
const DEEP := 2.3
## The fingers' joints, from the knuckle out, and how far each one bends shut.
const JOINTS: Array[float] = [0.2, 0.15, 0.22]
const BEND: Array[float] = [0.75, 1.0, 0.85]
const RISE := 0.22
const OPEN := 0.18
const SINK := 0.45

var hold_time: float = 1.2
## How far it leans in over what it holds (radians).
var lean: float = 0.35

var _age: float = 0.0
var _mat: ShaderMaterial
var _root: Node3D
var _fore: Node3D
var _joints: Array[Node3D] = []
var _thumb: Array[Node3D] = []
var _fire: Array[GPUParticles3D] = []
var _size: float = 1.0
var _shake := Vector3.ZERO
var _sunk := false

static var _seg_mesh: Mesh
static var _claw_mesh: Mesh
static var _arm_mesh: Mesh
static var _fore_mesh: Mesh
static var _palm_mesh: Mesh


## A hand out of the ground at `at`, its palm toward `toward`, `size` times a
## man's and a half, holding for `hold` seconds.
static func rise(into: Node, at: Vector3, toward: Vector3, size: float, hold: float,
		lean_in: float = 0.35) -> ShadowHand:
	if into == null:
		return null
	var h := ShadowHand.new()
	h._size = size
	h.hold_time = hold
	h.lean = lean_in
	into.add_child(h)
	h.global_position = at
	var to := toward - at
	to.y = 0.0
	if to.length_squared() < 0.0001:
		to = Vector3.FORWARD
	h.global_basis = Basis.looking_at(-to.normalized(), Vector3.UP)
	return h


func _ready() -> void:
	_mat = DarkFx.flesh()
	_root = Node3D.new()
	add_child(_root)
	_root.scale = Vector3.ONE * _size
	_root.position = Vector3.DOWN * DEEP * _size
	_piece(_root, _arms(), Vector3(0.0, ELBOW - ARM * 0.5, 0.0))
	_fore = Node3D.new()
	_fore.position = Vector3(0.0, ELBOW, 0.0)
	_root.add_child(_fore)
	_piece(_fore, _fores(), Vector3(0.0, FORE * 0.5, 0.0))
	var palm := Node3D.new()
	palm.position = Vector3(0.0, FORE, 0.0)
	_fore.add_child(palm)
	_piece(palm, _palms(), Vector3(0.0, 0.13, 0.0))
	# four fingers fanned a little, and the thumb off the side
	for f in 4:
		var x := lerpf(-0.11, 0.11, f / 3.0)
		var knuckle := Node3D.new()
		knuckle.position = Vector3(x, 0.26, 0.0)
		knuckle.rotation.z = -x * 2.2
		palm.add_child(knuckle)
		_finger(knuckle, 1.0 - 0.12 * absf(f - 1.5), _joints)
	var base := Node3D.new()
	base.position = Vector3(0.15, 0.08, 0.03)
	base.rotation = Vector3(0.4, 0.0, -0.9)
	palm.add_child(base)
	_finger(base, 0.8, _thumb)
	_curl(-0.25)
	var into := get_parent()
	# where it breaks out: black fire and a spray of grit
	_fire = DarkFx.black_fire(into, global_position + Vector3.UP * 0.05, hold_time + RISE + 0.2, 0.8 * _size,
			{"box": Vector3(0.22, 0.05, 0.22) * _size, "rate": 0.7})
	DarkFx.embers(into, global_position + Vector3.UP * 0.1, 12, Vector2(1.5, 3.5), 0.7, 50.0)
	DarkFx.smoke(into, global_position + Vector3.UP * 0.3, 4, 1.0 * _size, 1.2, 0.8, 0.2)


## A finger of three joints on `knuckle`, `long` times the length.
func _finger(knuckle: Node3D, long: float, into: Array[Node3D]) -> void:
	var at := knuckle
	for j in JOINTS.size():
		var joint := Node3D.new()
		if j > 0:
			joint.position = Vector3(0.0, JOINTS[j - 1] * long, 0.0)
		at.add_child(joint)
		var claw := j == JOINTS.size() - 1
		var piece := _piece(joint, _claws() if claw else _segs(), Vector3(0.0, JOINTS[j] * long * 0.5, 0.0))
		piece.scale = Vector3(1.0, JOINTS[j] * long / (0.15 if claw else 0.1), 1.0)
		into.append(joint)
		at = joint


func _piece(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.position = at
	parent.add_child(mi)
	return mi


## How shut the hand is: 0 open, 1 a fist round what it holds, below 0 flung
## open wider.
func _curl(k: float) -> void:
	for i in _joints.size():
		_joints[i].rotation.x = k * BEND[i % BEND.size()]
	for i in _thumb.size():
		_thumb[i].rotation.x = k * 0.7


func _process(delta: float) -> void:
	_age += delta
	var up := DEEP * _size
	var end := RISE + OPEN + hold_time
	if _age < RISE:
		# out of the ground fast, overshooting a little
		var t := _age / RISE
		var e := 1.0 + 2.2 * pow(t - 1.0, 3.0) + 1.2 * pow(t - 1.0, 2.0)
		_root.position.y = -up + up * e
		_lean(0.0)
		_curl(-0.25)
	elif _age < RISE + OPEN:
		var t := (_age - RISE) / OPEN
		_root.position.y = 0.0
		_lean(t * t)
		_curl(lerpf(-0.25, 1.0, t * t))
	elif _age < end:
		# held shut and straining: it shakes
		_shake = _shake.lerp(Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * 0.012 * _size, 0.4)
		_root.position = _shake
		_lean(1.0)
		_curl(1.0 + 0.04 * sin(_age * 40.0))
	else:
		if not _sunk:
			_sunk = true
			var into := get_parent()
			DarkFx.black_fire(into, global_position + Vector3.UP * 0.1, 0.0, 0.9 * _size,
					{"box": Vector3(0.2, 0.3, 0.2) * _size, "rate": 0.8})
			DarkFx.embers(into, global_position + Vector3.UP * (0.6 * _size), 10, Vector2(0.5, 1.5), 0.8)
		var t := clampf((_age - end) / SINK, 0.0, 1.0)
		_curl(lerpf(1.0, 0.1, minf(t * 2.0, 1.0)))
		_lean(1.0 - t)
		_root.position.y = -up * 0.55 * t * t
		_mat.set_shader_parameter(&"dissolve", t * 1.05)
		if t >= 1.0:
			queue_free()


## How far over it is bent, 0..1 of `lean`: a little at the shoulder, more at
## the elbow.
func _lean(k: float) -> void:
	_root.rotation.x = lean * 0.45 * k
	_fore.rotation.x = lean * 1.5 * k


static func _segs() -> Mesh:
	if _seg_mesh == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.03
		c.bottom_radius = 0.037
		c.height = 0.1
		c.radial_segments = 6
		c.rings = 1
		_seg_mesh = c
	return _seg_mesh


static func _claws() -> Mesh:
	if _claw_mesh == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.031
		c.height = 0.15
		c.radial_segments = 5
		c.rings = 1
		_claw_mesh = c
	return _claw_mesh


static func _arms() -> Mesh:
	if _arm_mesh == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.07
		c.bottom_radius = 0.1
		c.height = ARM
		c.radial_segments = 8
		c.rings = 3
		_arm_mesh = c
	return _arm_mesh


static func _fores() -> Mesh:
	if _fore_mesh == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.06
		c.bottom_radius = 0.07
		c.height = FORE
		c.radial_segments = 8
		c.rings = 2
		_fore_mesh = c
	return _fore_mesh


static func _palms() -> Mesh:
	if _palm_mesh == null:
		var s := SphereMesh.new()
		s.radius = 0.15
		s.height = 0.32
		s.radial_segments = 10
		s.rings = 6
		var st := SurfaceTool.new()
		st.create_from(s, 0)
		var raw := st.commit()
		var arrays := raw.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = Vector3(verts[i].x * 1.05, verts[i].y, verts[i].z * 0.42)
		arrays[Mesh.ARRAY_VERTEX] = verts
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_palm_mesh = out
	return _palm_mesh
