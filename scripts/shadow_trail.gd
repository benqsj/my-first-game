class_name ShadowTrail
extends Node3D

## The shadow a perfectly timed dodge leaves: for a second the body sheds
## copies of itself — dark, rimmed with violet, each frozen where it was — that
## fade behind it.
##
## A copy is the character's own skeleton and meshes, duplicated with the pose
## they hold at that moment and cut loose from everything that animates them,
## so it is the exact shape of the body a moment ago rather than a stand-in.
## Every copy wears the same shadow material, and fades and sinks a little as
## it goes.
##
## It frees itself when the last copy has gone.

## How long it keeps shedding, how often, and how long each copy lasts.
@export var shedding: float = 1.0
## How long after a perfect dodge nothing lands on the body that sheds it
## (read by [Player]): the shedding and the last copies fading.
const GUARD := 1.2
const EVERY := 0.07
@export var every: float = EVERY
@export var copy_life: float = 0.5

var _skeleton: Skeleton3D
var _left: float = 0.0
var _next: float = 0.0
var _copies: Array[Dictionary] = []

static var _shader: Shader = null


## Starts one on `body`, shedding copies of the skeleton under its visuals —
## for `seconds` (its `shedding` if not given), one each `each` (its `every`).
static func start(body: Node3D, seconds: float = -1.0, each: float = -1.0) -> ShadowTrail:
	if body == null:
		return null
	var skeleton := shown_skeleton(body)
	if skeleton == null:
		return null
	var old := body.get_node_or_null("ShadowTrail") as ShadowTrail
	if old != null:
		old._skeleton = skeleton
		old._go_on(seconds, each)
		return old
	var trail := ShadowTrail.new()
	trail.name = "ShadowTrail"
	trail._skeleton = skeleton
	trail._go_on(seconds, each)
	body.add_child(trail)
	return trail


func _go_on(seconds: float, each: float) -> void:
	_left = shedding if seconds < 0.0 else seconds
	every = each if each > 0.0 else EVERY
	_next = 0.0


## The skeleton the body is seen in: of those under it, the one shown with the
## most meshes shown on it. (A hero on the mannequin keeps his own model
## hidden and the mannequin's skeleton bare; what is seen is the figure, a
## skeleton of its own — the first Skeleton3D found is the hidden one, and a
## shadow copied off it has nothing in it to see.)
static func shown_skeleton(body: Node3D) -> Skeleton3D:
	var best: Skeleton3D = null
	var most := 0
	for node in body.find_children("*", "Skeleton3D", true, false):
		var skel := node as Skeleton3D
		if not skel.is_visible_in_tree():
			continue
		var shown := 0
		for child in skel.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).visible:
				shown += 1
		if shown > most:
			most = shown
			best = skel
	return best


func _process(delta: float) -> void:
	_left -= delta
	_next -= delta
	if _left > 0.0 and _next <= 0.0 and is_instance_valid(_skeleton):
		_next = every
		_shed()
	for i in range(_copies.size() - 1, -1, -1):
		var copy: Dictionary = _copies[i]
		copy.age = float(copy.age) + delta
		var t := clampf(float(copy.age) / copy_life, 0.0, 1.0)
		var node: Node3D = copy.node
		if t >= 1.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_copies.remove_at(i)
			continue
		(copy.mat as ShaderMaterial).set_shader_parameter("fade", 1.0 - t)
		node.global_position = (copy.at as Vector3) + Vector3.DOWN * 0.08 * t
	if _left <= 0.0 and _copies.is_empty():
		queue_free()


func _shed() -> void:
	var copy := _skeleton.duplicate(0) as Skeleton3D
	# Only the meshes: nothing that would go on moving it (spring bones, the
	# stride, attachments with lights on them).
	for child in copy.get_children():
		if not child is MeshInstance3D or not (child as MeshInstance3D).visible:
			copy.remove_child(child)
			child.free()
	copy.top_level = true
	var mat := ShaderMaterial.new()
	mat.shader = _material()
	mat.set_shader_parameter("fade", 1.0)
	for child in copy.get_children():
		var mesh := child as MeshInstance3D
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var into := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	into.add_child(copy)
	copy.global_transform = _skeleton.global_transform
	for b in _skeleton.get_bone_count():
		copy.set_bone_pose(b, _skeleton.get_bone_pose(b))
	_copies.append({"node": copy, "mat": mat, "age": 0.0, "at": copy.global_position})


static func _material() -> Shader:
	if _shader != null:
		return _shader
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
uniform float fade = 1.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 body = vec3(0.04, 0.02, 0.07);
	vec3 edge = vec3(0.55, 0.25, 1.0);
	ALBEDO = mix(body, edge, rim);
	ALPHA = (0.42 + 0.5 * rim) * fade;
}
"""
	return _shader
