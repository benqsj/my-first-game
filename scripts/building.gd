class_name Building
extends Node3D

## Makes one of the HighLands kit's `.fbx` buildings usable: gives it back its
## textures, and turns the hull the artist shipped with it into a collider.
##
## The kit is authored for Unreal, and two of its conventions do not survive the
## import.
##
## **Textures.** The `.fbx` names a material — `M_Hut` — but not the files that
## dress it, so everything arrives a flat off-white. The files are there, in a
## `TextureMaps` folder beside the model and named after the same material, so
## the material name is all that is needed to find them: `M_Hut` wants
## `T_Hut_diffuse.png`, `T_Hut_normal.png` and the rest. That is what this looks
## up, per surface, and it is why nothing has to be wired by hand per building.
##
## **Collision.** Unreal reads a mesh whose name starts with `UCX_` as the convex
## hull to collide against; Godot reads it as a second thing to draw. So the
## `UCX_` meshes are taken out of the drawing and put back as
## [ConvexPolygonShape3D]s on a [StaticBody3D] — which is both correct and the
## cheap way round. The alternative is the trimesh the importer would otherwise
## cut from the building itself, and [SimpleCollision] on the house in this same
## level already measured what that costs: seven point seven milliseconds a tick.
##
## A building with no hull gets no collider and says so, rather than silently
## becoming scenery the player walks through.

## Material name -> texture base name, for the one case in the kit where the two
## do not agree. The wall tower's material is `M_TowerW`; its textures are not.
const TEXTURE_ALIASES := {
	"TowerW": "Tower",
}

const MAP_SUFFIXES := {
	"diffuse": "diffuse",
	"normal": "normal",
	"roughness": "roughness",
	"metalness": "metalness",
}

@export_group("Textures")
## Where the `TextureMaps` folder is. Left empty it is worked out from the model
## itself, which is right for anything still sitting where the kit put it.
@export var textures_dir: String = ""
## Off to see the building as the importer produced it, which is what to do when
## a texture has gone missing and the question is whether it was ever found.
@export var apply_materials: bool = true

@export_group("Collision")
@export var build_collision: bool = true
## Which layers the building sits on. 1 is the world everything else collides
## against, which is where the ground and the boundary walls are.
@export_flags_3d_physics var collision_layer: int = 1

## How many surfaces were dressed and how many hulls were found, for anything
## that wants to check the work.
var dressed: int = 0
var hulls: int = 0

## Texture base name -> the material built for it. Ten crates share one material
## and therefore one draw call's worth of state, rather than ten copies of it.
static var _shared: Dictionary = {}


func _ready() -> void:
	var root := _model()
	if root == null:
		push_warning("Building '%s': nothing instanced under it." % name)
		return

	var base := textures_dir if not textures_dir.is_empty() else _guess_textures_dir(root)
	var body: StaticBody3D = null

	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name.begins_with("UCX_"):
			if build_collision:
				body = _add_hull(body, mesh)
			# Drawn, it is a box floating inside the building. Freed rather than
			# hidden: the points have already been copied into the shape.
			mesh.queue_free()
			continue
		if apply_materials:
			_dress(mesh, base)

	if build_collision and body == null:
		push_warning("Building '%s': no UCX_ hull in the model, so nothing to walk into."
				% name)


## The instanced model under this node — whatever was dropped in, without this
## script having to know its name.
func _model() -> Node3D:
	for child in get_children():
		var node := child as Node3D
		if node != null and not node.scene_file_path.is_empty():
			return node
	return get_child(0) as Node3D if get_child_count() > 0 else null


## `.../Hut/SM_Hut.fbx` -> `.../Hut/TextureMaps`.
static func _guess_textures_dir(model: Node3D) -> String:
	if model.scene_file_path.is_empty():
		return ""
	return model.scene_file_path.get_base_dir().path_join("TextureMaps")


#region Textures
## Gives one mesh its material back, per surface, from the material's own name.
func _dress(mesh: MeshInstance3D, base_dir: String) -> void:
	if mesh.mesh == null or base_dir.is_empty():
		return
	for s in mesh.mesh.get_surface_count():
		var source := mesh.mesh.surface_get_material(s) as BaseMaterial3D
		if source == null:
			continue
		var stem := source.resource_name.trim_prefix("M_")
		stem = TEXTURE_ALIASES.get(stem, stem)
		if stem.is_empty():
			continue
		var material := _material_for(base_dir, stem)
		if material != null:
			mesh.set_surface_override_material(s, material)
			dressed += 1


## The material for one texture set, built once and shared by every building
## that asks for it.
static func _material_for(base_dir: String, stem: String) -> StandardMaterial3D:
	var key := base_dir.path_join(stem)
	if _shared.has(key):
		return _shared[key]

	var albedo := _texture(base_dir, stem, "diffuse")
	if albedo == null:
		push_warning("Building: no diffuse map for '%s' in %s." % [stem, base_dir])
		_shared[key] = null
		return null

	var material := StandardMaterial3D.new()
	material.resource_name = stem
	material.albedo_texture = albedo

	var normal := _texture(base_dir, stem, "normal")
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal

	# The maps are the whole of the answer, so the scalars are left wide open and
	# the texture does all of the modulating.
	var rough := _texture(base_dir, stem, "roughness")
	if rough != null:
		material.roughness = 1.0
		material.roughness_texture = rough
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	else:
		material.roughness = 0.85

	var metal := _texture(base_dir, stem, "metalness")
	if metal != null:
		material.metallic = 1.0
		material.metallic_texture = metal
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	_shared[key] = material
	return material


static func _texture(base_dir: String, stem: String, map: String) -> Texture2D:
	var path := base_dir.path_join("T_%s_%s.png" % [stem, map])
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
#endregion


#region Collision
## Copies one `UCX_` hull onto the building's body, making the body if this is
## the first hull found.
func _add_hull(body: StaticBody3D, hull: MeshInstance3D) -> StaticBody3D:
	if hull.mesh == null:
		return body
	if body == null:
		body = StaticBody3D.new()
		body.name = "Collision"
		body.collision_layer = collision_layer
		body.collision_mask = 0
		add_child(body)

	# Into the building's own frame, so the shape is right whatever the building
	# has been scaled or turned to in the level.
	var to_local := global_transform.affine_inverse() * hull.global_transform
	var points := PackedVector3Array()
	for s in hull.mesh.get_surface_count():
		for v in hull.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			points.append(to_local * v)
	if points.size() < 4:
		return body

	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var node := CollisionShape3D.new()
	node.name = hull.name.trim_prefix("UCX_")
	node.shape = shape
	body.add_child(node)
	hulls += 1
	return body
#endregion
