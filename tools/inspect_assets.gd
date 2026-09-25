extends SceneTree

## Reports what an imported model actually contains: meshes, surfaces, triangle
## counts, materials and the bounding box, plus any animations.
##
##     godot --path . --headless --script res://tools/inspect_assets.gd
##     godot --path . --headless --script res://tools/inspect_assets.gd -- res://a.obj
##
## Used when wiring a new art pack in, to find out how big a thing is, where its
## origin sits and whether its textures survived the import. Named on the command
## line, or — with nothing given — the handful below, which is one of everything
## the level is built out of.

const PATHS: PackedStringArray = [
	"res://assets/forest/Tree_Oak_1.obj",
	"res://assets/forest/Tree_Pine_1.obj",
	"res://assets/forest/Mountain_1.obj",
	"res://assets/grass/grass2.glb",
	"res://unverified/assets/rock/rock.glb",
	"res://assets/monsters/Bestiary - Dungeon Monsters Kit[Standard]/Exports/GLB (Godot-Unreal)/Imp.glb",
	"res://unverified/assets/area/HighLandsFantasyBuildings/Hut/SM_Hut.fbx",
]


func _init() -> void:
	var wanted := OS.get_cmdline_user_args()
	for path in (wanted if not wanted.is_empty() else PATHS):
		print("\n=== ", path)
		var res := load(path)
		if res == null:
			print("  !! failed to load")
			continue
		if res is Mesh:
			_report_mesh(res as Mesh, "  ")
		elif res is PackedScene:
			var root := (res as PackedScene).instantiate()
			_walk(root, "  ")
			root.free()
		else:
			print("  loaded as ", res.get_class())
	quit()


func _walk(node: Node, indent: String) -> void:
	var extra := ""
	if node is AnimationPlayer:
		extra = " anims=%s" % [(node as AnimationPlayer).get_animation_list()]
	print(indent, node.name, " <", node.get_class(), ">", extra)
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		print(indent, "  xform=", mesh_node.transform)
		_report_mesh(mesh_node.mesh, indent + "  ")
	for child in node.get_children():
		_walk(child, indent + "  ")


func _report_mesh(mesh: Mesh, indent: String) -> void:
	var aabb := mesh.get_aabb()
	var tris := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		tris += (idx.size() if idx.size() > 0 else verts.size()) / 3
	print(indent, "mesh=", mesh.get_class(), " surfaces=", mesh.get_surface_count(),
			" tris=", tris)
	print(indent, "aabb pos=", aabb.position, " size=", aabb.size)
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		var albedo := "-"
		if mat is BaseMaterial3D:
			var tex := (mat as BaseMaterial3D).albedo_texture
			albedo = tex.resource_path if tex != null else "(none) " + str((mat as BaseMaterial3D).albedo_color)
		print(indent, "  surf", s, " mat=", mat.get_class() if mat != null else "null",
				" name=", mat.resource_name if mat != null else "", " albedo=", albedo)
