class_name FrostShell
extends Node3D

## Frozen (the elf's Frost Nova, the user's word 2026-10-07): a body locked in
## a shell of ice for its time. Every peer: the ice round it (a clear blue
## sheath the size of what it wears, crystals standing out of it from the
## ground up) and its figure stopped in whatever pose it was in (its rig's
## processing held); on its own peer it cannot go anywhere ([ShadowHold]).
## The host also reels it ([method Brute.react] "stun"), so it does not strike.
##
## A blow from the elf's own spells (a bolt, a spear, the moon) breaks it
## early, and is worth `SHATTER` times as much ([method shatter]); otherwise it
## cracks and falls away when its time is up.

const SHATTER := 1.5
const ICE := Color(0.62, 0.9, 1.0)
const ICE_HOT := Color(0.9, 0.98, 1.0)

var _body: Node3D
var _left: float = 0.0
var _rig: Node
var _rig_mode: int = PROCESS_MODE_INHERIT
var _sheath: MeshInstance3D
var _mat: StandardMaterial3D
var _age: float = 0.0
var _crystals: Array[Node3D] = []
var _size := Vector3(0.8, 1.8, 0.8)


## Every peer: `body` frozen for `seconds` (a fresh freeze only lengthens it).
static func encase(body: Node3D, seconds: float) -> void:
	if body == null or not body.is_inside_tree() or seconds <= 0.0 or body.get(&"is_dead") == true:
		return
	var old := body.get_node_or_null(^"FrostShell") as FrostShell
	if old != null:
		old._left = maxf(old._left, seconds)
		ShadowHold.hold(body, seconds)
		return
	var shell := FrostShell.new()
	shell.name = "FrostShell"
	shell._body = body
	shell._left = seconds
	body.add_child(shell)
	ShadowHold.hold(body, seconds)


## Whether `body` is frozen now.
static func is_frozen(body: Node) -> bool:
	return body != null and is_instance_valid(body) and body.get_node_or_null(^"FrostShell") != null


## A blow at `body`: if it is frozen the ice breaks, and the blow is worth
## `SHATTER` as much; else 1. (Every peer, where the blow lands.)
static func shatter(body: Node) -> float:
	if not is_frozen(body):
		return 1.0
	var shell := body.get_node(^"FrostShell") as FrostShell
	shell._break(true)
	return SHATTER


func _ready() -> void:
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY, _body.global_position)
	_measure()
	# the figure stopped where it is
	var rig: Variant = _body.get(&"rig")
	_rig = rig as Node if rig is Node else _body.get_node_or_null(^"Visuals")
	if _rig != null:
		_rig_mode = _rig.process_mode
		_rig.process_mode = Node.PROCESS_MODE_DISABLED
	_build()
	var into := get_parent().get_parent()
	if into != null:
		var at := global_position + Vector3.UP * _size.y * 0.4
		SkillFx.burst(into, at, ICE_HOT, 26, Vector2(1.0, 3.5), Vector3.UP, 180.0, Vector2(0.02, 0.05),
				Vector3(0, -5, 0), 0.6)
		SkillFx.flash(into, at, ICE_HOT, 0.6 + _size.x * 0.4, 0.2, 2.0)


## How big it is: what it wears, measured once.
func _measure() -> void:
	var box := AABB()
	var first := true
	# what it wears only: its meshes, not a name or a bar over its head
	for node in _body.find_children("*", "MeshInstance3D", true, false):
		var vi := node as MeshInstance3D
		if vi == null or not vi.is_visible_in_tree() or vi.mesh == null:
			continue
		var b := vi.global_transform * vi.get_aabb()
		if b.size.length() > 12.0:
			continue
		box = b if first else box.merge(b)
		first = false
	if first:
		var br: Variant = _body.get(&"body_radius")
		var r := float(br) if br != null else 0.4
		_size = Vector3(r * 2.0, maxf(r * 4.0, 1.4), r * 2.0)
		return
	var feet := _body.global_position.y
	var br: Variant = _body.get(&"body_radius")
	var wide := (float(br) if br != null else 0.5) * 2.0
	# a weapon held out or up does not make it broader or taller than it is
	_size = Vector3(clampf(minf(maxf(box.size.x, box.size.z) * 0.7, wide * 1.6), 0.7, 4.0),
			clampf(box.end.y - feet, 0.8, 5.0), 0.0)
	_size.z = _size.x


## The ice: a sheath from the ground to over its head, and crystals out of it.
func _build() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.72, 0.9, 1.0, 0.0)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.05
	_mat.metallic = 0.3
	_mat.rim_enabled = true
	_mat.rim = 1.0
	_mat.rim_tint = 0.2
	_mat.emission_enabled = true
	_mat.emission = ICE
	_mat.emission_energy_multiplier = 0.35
	_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_sheath = MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = _size.x * 0.55
	shape.height = maxf(_size.y * 1.08, shape.radius * 2.0 + 0.1)
	shape.radial_segments = 10
	shape.rings = 4
	_sheath.mesh = shape
	_sheath.material_override = _mat
	_sheath.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheath.position = Vector3.UP * shape.height * 0.47
	_sheath.scale = Vector3(1.0, 0.05, 1.0)
	add_child(_sheath)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := int(clampf(_size.x * 7.0, 6.0, 16.0))
	for i in count:
		var a := TAU * float(i) / float(count) + rng.randf_range(-0.2, 0.2)
		var r := _size.x * rng.randf_range(0.42, 0.62)
		var tall := _size.y * rng.randf_range(0.14, 0.32)
		var c := IceShard.spike(tall, tall * 0.2, 1.0)
		add_child(c)
		c.position = Vector3(cos(a) * r, rng.randf_range(-0.05, _size.y * 0.15), sin(a) * r)
		var out := Vector3(cos(a), 0.0, sin(a))
		# leaning out from it, each its own way round its own length
		c.basis = Basis(out.cross(Vector3.UP).normalized(), -rng.randf_range(0.2, 0.6)) \
				* Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		c.scale = Vector3.ONE * 0.01
		c.set_meta(&"full", 1.0)
		_crystals.append(c)


func _process(delta: float) -> void:
	_age += delta
	_left -= delta
	if _body == null or not is_instance_valid(_body) or _body.get(&"is_dead") == true:
		_break(false)
		return
	global_position = _body.global_position
	# the ice comes up over it fast, from the ground
	var k := clampf(_age / 0.18, 0.0, 1.0)
	_sheath.scale = Vector3(1.0, lerpf(0.05, 1.0, k), 1.0)
	_mat.albedo_color.a = 0.42 * k
	for c in _crystals:
		c.scale = Vector3.ONE * maxf(k * (1.0 + 0.2 * sin(clampf(_age / 0.3, 0.0, 1.0) * PI)), 0.01)
	if _left <= 0.0:
		_break(false)


## It ends: cracked and falling away, or (`shattered`, struck) burst apart.
func _break(shattered: bool) -> void:
	if is_queued_for_deletion():
		return
	if _rig != null and is_instance_valid(_rig):
		_rig.process_mode = _rig_mode as Node.ProcessMode
	var into := get_parent().get_parent() if get_parent() != null else null
	if into != null:
		var at := global_position + Vector3.UP * _size.y * 0.45
		var n := 40 if shattered else 22
		SkillFx.burst(into, at, ICE_HOT, n, Vector2(2.0, 6.0) if shattered else Vector2(0.6, 2.2),
				Vector3.UP, 180.0, Vector2(0.03, 0.08) if shattered else Vector2(0.02, 0.05),
				Vector3(0, -9, 0), 0.8)
		if shattered:
			SkillFx.flash(into, at, ICE_HOT, 0.8 + _size.x * 0.5, 0.22, 3.0)
			SkillFx.ring(into, at, Vector3.UP, ICE, 0.3, 2.0 + _size.x, 0.35, 0.05, 2.5)
		SkillFx.particles(into, global_position + Vector3.UP * 0.3, {"amount": 10, "life": 1.0, "one_shot": true,
				"explosiveness": 0.9, "speed": Vector2(0.2, 0.6), "spread": 180.0, "size": Vector2(0.4, 0.8),
				"add": false, "grow": 0.6, "box": Vector3(_size.x * 0.4, 0.3, _size.x * 0.4),
				"colors": [Color(0.92, 0.97, 1.0, 0.0), Color(0.9, 0.96, 1.0, 0.3), Color(0.9, 0.95, 1.0, 0.0)]})
	var held := _body.get_node_or_null(^"ShadowHold") if _body != null and is_instance_valid(_body) else null
	if held != null:
		held.queue_free()
	queue_free()
