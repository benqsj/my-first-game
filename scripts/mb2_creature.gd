class_name Mb2Creature
extends Node3D

## One of Magic Pig's Low Poly Monster Bundle 2 (claude/monster_bundle2_plan.md,
## 2026-10-31): its own figure (`assets/monsters_mb2/<kind>/<kind>.glb`, made
## by `vepxis-art/tools/mb2_convert.py`) in any of the looks the pack has:
## each part shown or hidden, each shape (ears, horns, wings, belly...), each
## colour set of each group (body, armour, sword), in the pack's own paint
## ("default") or ours ("my-color", [member mine]). It stands and plays one of
## its clips; it does not fight yet. F1's "Monster Bundle 2" corner picks all
## of it ([ArenaPanel]).
##
## The figures face +Z; the game's creatures face -Z, so the figure is turned
## round under the node. Set down on whatever is under it.

const DIR := "res://assets/monsters_mb2/"
const SHADER := preload("res://shaders/mb2_creature.gdshader")

@export var kind: StringName = &"imp"
## group ("body", "armor", "sword") -> index into its colour sets
@export var colors: Dictionary = {}
## our paint, not the pack's
@export var mine: bool = false
## parts (the pack's mesh names) not shown
@export var hidden_parts: PackedStringArray = PackedStringArray()
## a shape's name ([method sliders]) -> -1..1 for a +/- pair, 0..1 for one alone
@export var shapes: Dictionary = {}
@export var clip: StringName = &"Idle"

var figure: Node3D
var player: AnimationPlayer

static var _looks := {}
static var _made := {}


## Every kind converted so far (a folder with its looks.json).
static func kinds() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for n in dir.get_directories():
		if FileAccess.file_exists(DIR + n + "/looks.json"):
			out.append(n)
	out.sort()
	return out


## The kind's looks.json: height, groups (colour sets), parts (name, group,
## shapes), clips.
static func looks(of: StringName) -> Dictionary:
	if not _looks.has(of):
		var text := FileAccess.get_file_as_string(DIR + String(of) + "/looks.json")
		var parsed: Variant = JSON.parse_string(text)
		_looks[of] = parsed if parsed is Dictionary else {}
	return _looks[of]


static func label(of: StringName) -> String:
	return String(of).replace("_", " ").capitalize()


## "SFB_BS_EarSizePlus" and "SFB_BSM_c1_EarSizePlus" are one shape to the pack
## (the armour's follows the body's): "earsizeplus".
static func _short(shape: String) -> String:
	var bits := shape.split("_")
	return bits[bits.size() - 1].to_lower()


## The kind's shapes as F1 shows them: [name, plus, minus] with plus and minus
## short names; a lone shape has minus "".
static func sliders(of: StringName) -> Array:
	var seen := {}
	for part: Dictionary in looks(of).get("parts", []):
		for s: String in part.get("shapes", []):
			if s.begins_with("SFB_BS_"):
				seen[_short(s)] = s.trim_prefix("SFB_BS_")
	var out := []
	var done := {}
	for k: String in seen:
		if done.has(k):
			continue
		var stem := k
		var plus := k
		var minus := ""
		if k.ends_with("plus") and seen.has(k.trim_suffix("plus") + "minus"):
			stem = k.trim_suffix("plus")
			minus = stem + "minus"
		elif k.ends_with("minus") and seen.has(k.trim_suffix("minus") + "plus"):
			stem = k.trim_suffix("minus")
			plus = stem + "plus"
			minus = k
		done[plus] = true
		if minus != "":
			done[minus] = true
		var shown := String(seen[plus])
		if minus != "":
			shown = shown.substr(0, shown.length() - 4)
		out.append([shown, plus, minus])
	out.sort_custom(func(a: Array, b: Array) -> bool: return String(a[0]) < String(b[0]))
	return out


func _ready() -> void:
	var look := looks(kind)
	# (Blender's glb, or Godot's own scn for those Blender cannot read:
	# tools/mb2_from_fbx.gd)
	var base := DIR + String(kind) + "/" + String(kind)
	var scene := load(base + ".glb" if ResourceLoader.exists(base + ".glb") else base + ".scn") as PackedScene
	if scene == null:
		push_warning("Mb2Creature: no figure for %s" % kind)
		return
	figure = scene.instantiate() as Node3D
	figure.name = "Figure"
	figure.rotation.y = PI
	add_child(figure)
	var found := figure.find_children("*", "AnimationPlayer", true, false)
	player = found[0] as AnimationPlayer if not found.is_empty() else null
	if player != null:
		player.animation_finished.connect(_again)
	apply()
	_add_body(float(look.get("height", 2.0)))
	_set_down.call_deferred()


## Puts on what is set: paint, parts, shapes, clip.
func apply() -> void:
	if figure == null:
		return
	var look := looks(kind)
	var group_of := {}
	for part: Dictionary in look.get("parts", []):
		group_of[String(part["name"])] = String(part["group"])
	var weights := {}
	for s: Array in sliders(kind):
		var v := float(shapes.get(String(s[0]), 0.0))
		if String(s[2]) == "":
			weights[String(s[1])] = clampf(v, 0.0, 1.0)
		else:
			weights[String(s[1])] = maxf(v, 0.0)
			weights[String(s[2])] = maxf(-v, 0.0)
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var part := String(mesh.name)
		mesh.visible = not hidden_parts.has(part)
		mesh.material_override = _material(String(group_of.get(part, "body")))
		for i in mesh.get_blend_shape_count():
			var short := _short(_blend_name(mesh, i))
			mesh.set_blend_shape_value(i, float(weights.get(short, 0.0)))
	if player != null:
		var want := String(clip)
		if not player.has_animation(want):
			want = stand_clip(player)
		player.play(want, 0.15)


## The clip it stands in: Idle, else the first idle that is not a break or
## a turn into something, else the first.
static func stand_clip(of: AnimationPlayer) -> String:
	var names := of.get_animation_list()
	if of.has_animation("Idle"):
		return "Idle"
	for n in names:
		var low := String(n).to_lower()
		if low.contains("idle") and not low.contains("break") and not low.contains("to"):
			return String(n)
	return String(names[0]) if not names.is_empty() else ""


static func _blend_name(mesh: MeshInstance3D, i: int) -> String:
	var array_mesh := mesh.mesh as ArrayMesh
	return String(array_mesh.get_blend_shape_name(i)) if array_mesh != null else ""


func _again(_name: StringName) -> void:
	if player != null and is_inside_tree():
		player.play(_name)


## The material of a group in the colour set picked for it (shared between
## creatures wearing the same).
func _material(group: String) -> ShaderMaterial:
	var sets: Array = looks(kind).get("groups", {}).get(group, [])
	var at := int(colors.get(group, 0))
	var name := String(sets[wrapi(at, 0, sets.size())]) if not sets.is_empty() else ""
	var key := "%s/%s/%s/%s" % [kind, group, name, mine]
	if _made.has(key):
		return _made[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if name != "":
		m.set_shader_parameter("palette", load(DIR + String(kind) + "/tex/" + name + ".png"))
	m.set_shader_parameter("mine", mine)
	_made[key] = m
	return m


## Its size for a camera framing it (its skinned meshes' own boxes are in
## the pack's units).
func view_box() -> AABB:
	var tall := float(looks(kind).get("height", 2.0))
	var wide := tall * 0.9
	return AABB(global_position + Vector3(-wide * 0.5, 0.0, -wide * 0.5), Vector3(wide, tall, wide))


## Which way it faces (the preview turns its face to the camera).
func _forward() -> Vector3:
	return -global_transform.basis.z


## Stands on the ground under it.
func _set_down() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var from := global_position + Vector3.UP * 1.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0)
	var others: Array[RID] = []
	for body in get_tree().get_nodes_in_group(&"pack_creature_body"):
		others.append((body as CollisionObject3D).get_rid())
	query.exclude = others
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y


## Something to bump into: a capsule its height.
func _add_body(tall: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.add_to_group(&"pack_creature_body")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = clampf(tall * 0.18, 0.25, 1.5)
	capsule.height = maxf(tall, capsule.radius * 2.0)
	shape.shape = capsule
	shape.position = Vector3(0.0, tall * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)
