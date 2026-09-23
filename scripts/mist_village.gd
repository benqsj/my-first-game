class_name MistVillage
extends Node3D

## The misty village on its island in the mere, as it comes out of
## `assets/world/mist_village.glb`, with the few things the importer cannot be
## told fixed up here.
##
## The model arrived as `assets/world/mist2.glb`: a diorama of eight thousand
## separate pieces, several of whose houses had been exported from Blender with
## a lossy transform (see `tools/mist_village.py` in the art folder — a child of
## a squashed parent loses its shear, and the shingles fly off the roof in long
## shards). The village this instances is that model rebuilt: the transforms
## solved back, the pieces merged by material into twenty meshes, scaled to the
## characters (2.2×, which makes a barrel the height of a hip), and given
## collision by name — `-colonly` for the island's ground as a trimesh,
## `-convcolonly` for a handful of hulls per house, the trees, rocks and
## barrels. A house is some sixty thousand triangles of shingle; colliding with
## it by the triangle is what cost the old house in this level seven
## milliseconds a physics tick, and a player cannot tell a hull from a wall.
##
## What is left for this script is the materials:
##
## * the grass cards come in as alpha *blended*, which sorts badly against
##   itself and casts no shadow — they are cut out instead;
## * the island's green is painted into its vertex colours, which the material
##   is not told to read;
## * the grass is not drawn into the sun's shadow map. Two thousand cards
##   flickering in a shadow nobody can see is the whole cost of the grass.

## Below this alpha a grass card's texel is thrown away.
@export var grass_cutoff: float = 0.45

var fixed: int = 0


func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var has_colours := false
		var arrays := mesh.mesh as ArrayMesh
		if arrays != null:
			for s in arrays.get_surface_count():
				if arrays.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR:
					has_colours = true
		for s in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(s) as BaseMaterial3D
			if source == null:
				continue
			var material := source
			if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				material = source.duplicate() as BaseMaterial3D
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = grass_cutoff
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if has_colours and not material.vertex_color_use_as_albedo:
				if material == source:
					material = source.duplicate() as BaseMaterial3D
				material.vertex_color_use_as_albedo = true
			if material != source:
				mesh.set_surface_override_material(s, material)
				fixed += 1
