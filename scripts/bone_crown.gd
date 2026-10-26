class_name BoneCrown
extends Node3D

## The skeleton mage's bones hung in the air before it throws them
## ([MageFighter], the user's word 2026-10-26: as the elf's Frost Spears, but
## its own real bones): ten pieces of its skeleton ([method BoneShard.cut]),
## one after another, five over each shoulder, high round its head, each
## turned point first on the one it will throw them at. They go where it
## goes. Thrown one by one ([method take]); what is left breaks if it falls.

const COUNT := 10
const FORM_EVERY := 0.09
const FORM_GROW := 0.3

var caster: Node3D
var quarry: Node3D
## [[mesh, material], ...]: the pieces, used in turn.
var pieces: Array = []

var _nodes: Array[Node3D] = []
var _offs: Array[Vector3] = []
var _born: Array[float] = []
var _taken: Array[bool] = []
var _age: float = 0.0
var _breaking: float = -1.0


static func form(into: Node, by: Node3D, at: Node3D, parts: Array) -> BoneCrown:
	if into == null or by == null or parts.is_empty():
		return null
	var c := BoneCrown.new()
	c.caster = by
	c.quarry = at
	c.pieces = parts
	into.add_child(c)
	return c


func _ready() -> void:
	top_level = true
	for i in COUNT:
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := floorf(i / 2.0) / 4.0
		_offs.append(Vector3(side * lerpf(0.75, 2.1, fmod(k * 1.7 + 0.13 * i, 1.0)),
				lerpf(2.3, 3.4, fmod(k * 2.3 + 0.37, 1.0)),
				-lerpf(-0.2, 0.9, fmod(k * 1.3 + 0.21 * i, 1.0))))
		var p: Array = pieces[i % pieces.size()]
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.material_override = p[1]
		mi.visible = false
		add_child(mi)
		_nodes.append(mi)
		_born.append(FORM_EVERY * i)
		_taken.append(false)


## Where piece `i` is now, and the way it points (+Y).
func place_of(i: int) -> Transform3D:
	return _nodes[i].global_transform if i < _nodes.size() else global_transform


## Piece `i` thrown: gone from the crown.
func take(i: int) -> void:
	if i < _taken.size():
		_taken[i] = true
		_nodes[i].visible = false


func all_formed() -> bool:
	return _age >= FORM_EVERY * (COUNT - 1) + FORM_GROW


func break_all() -> void:
	if _breaking < 0.0:
		_breaking = _age


func _process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(caster) or bool(caster.get("is_dead")):
		break_all()
	if _breaking >= 0.0:
		var u := clampf((_age - _breaking) / 0.3, 0.0, 1.0)
		for i in _nodes.size():
			_nodes[i].scale = Vector3.ONE * maxf(1.0 - u, 0.01)
		if u >= 1.0:
			queue_free()
		return
	var fwd := Vector3.FORWARD
	if caster.has_method(&"_forward"):
		fwd = caster.call(&"_forward") as Vector3
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP).normalized()
	var mark := caster.global_position + fwd * 6.0 + Vector3.UP
	if is_instance_valid(quarry):
		mark = quarry.global_position + Vector3.UP
	var done := true
	for i in _nodes.size():
		if _taken[i]:
			continue
		done = false
		var g := clampf((_age - _born[i]) / FORM_GROW, 0.0, 1.0)
		var o := _offs[i]
		var p := caster.global_position + right * o.x + Vector3.UP * (o.y + 0.05 * sin(_age * 3.0 + i)) + fwd * o.z
		var dir := (mark - p).normalized()
		_nodes[i].visible = g > 0.0
		_nodes[i].global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)).scaled(Vector3.ONE * maxf(1.0 - pow(1.0 - g, 3.0), 0.01)), p)
	if done:
		queue_free()
