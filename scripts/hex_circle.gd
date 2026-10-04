class_name HexCircle
extends Node3D

## A burst under a hero's feet, cast by a creature ([MageFighter]): a ring
## of violet light opens on the ground where he stood and tightens for
## `delay` seconds — time to get out of it — then the ground erupts there
## ([GroundFx], [DustRing]) and whoever is still inside takes the blow
## (`receive_blow`, a spell: through m.def; host only).

var radius: float = 1.8
var delay: float = 1.1
var damage: float = 30.0
var shooter: Node3D
var colour: Color = Color(0.62, 0.35, 1.0)

var _age: float = 0.0
var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _fill_mat: StandardMaterial3D
var _done: bool = false


static func cast(into: Node, at: Vector3, from: Node3D, hurt: float, size: float = 1.8,
		wait: float = 1.1) -> HexCircle:
	if into == null:
		return null
	var hex := HexCircle.new()
	hex.radius = size
	hex.delay = wait
	hex.damage = hurt
	hex.shooter = from
	into.add_child(hex)
	hex.global_position = at + Vector3.UP * 0.03
	return hex


func _ready() -> void:
	_ring_mat = _material(0.9)
	_fill_mat = _material(0.18)
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.07
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3(1.0, 0.15, 1.0)
	add_child(_ring)
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 48
	_fill = MeshInstance3D.new()
	_fill.mesh = disc
	_fill.material_override = _fill_mat
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.scale = Vector3.ONE * 0.05
	add_child(_fill)


func _material(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 1.5
	return m


func _process(delta: float) -> void:
	_age += delta
	if not _done:
		# The fill grows out to the ring as the moment comes; the ring pulses.
		var t := clampf(_age / delay, 0.0, 1.0)
		_fill.scale = Vector3(t, 1.0, t)
		_ring_mat.albedo_color.a = 0.55 + 0.4 * absf(sin(_age * 9.0))
		if _age >= delay:
			_erupt()
		return
	var fade := clampf((_age - delay) / 0.4, 0.0, 1.0)
	_ring_mat.albedo_color.a = 0.9 * (1.0 - fade)
	_fill_mat.albedo_color.a = 0.3 * (1.0 - fade)
	if fade >= 1.0:
		queue_free()


func _erupt() -> void:
	_done = true
	_fill_mat.albedo_color = Color(colour.r, colour.g, colour.b, 0.35)
	var into := get_parent()
	GroundFx.eruption(into, global_position, radius / 1.8)
	if not multiplayer.is_server():
		return
	for node in get_tree().get_nodes_in_group("player"):
		var who := node as Node3D
		if who == null or not who.has_method(&"receive_blow") or who.get("net_dead") == true:
			continue
		var off := who.global_position - global_position
		off.y = 0.0
		if off.length() <= radius + 0.25:
			who.call(&"receive_blow", damage, shooter if is_instance_valid(shooter) else self,
					0, 2, get_instance_id() % 100000, true)
