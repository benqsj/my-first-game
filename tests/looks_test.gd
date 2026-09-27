extends SceneTree

## The world's looks ([Looks]), stepped through with F8.
##
##     godot --headless --script res://tests/looks_test.gd
##
## Checks that the level starts in the new look (the forest floor, the light
## clump and the low sward), that F8 puts the old one back (the house ground and
## the full clump on every clump, without growing the field again), that the
## ground mask has trees and grass in it where they are, and that F8's round
## comes back to the new look.

const WORLD := "res://scenes/world/greybox_world.tscn"

var _failures := 0


func _initialize() -> void:
	var world: World = load(WORLD).instantiate()
	root.add_child(world)
	await _wait(1)
	var player: Player = world.player()
	for creature in world.find_children("*", "CharacterBody3D", true, false):
		if creature != player:
			creature.queue_free()
	await _wait(10)

	var land := Terrain.current
	var looks := land.get_node_or_null("Looks") as Looks if land != null else null
	var field := world.get_node_or_null("Level/Scatter") as GrassField
	_check("there are looks to step through", looks != null and looks.LOOKS.size() >= 2)
	_check("and grass to dress", field != null and field.clump_count() > 1000,
			"%d clumps" % (field.clump_count() if field != null else 0))
	if looks == null or field == null:
		_finish()
		return
	var chunk := land.get_node_or_null("Chunk_0_0") as MeshInstance3D
	var light := _clump_mesh(field)
	var clumps := field.clump_count()

	# --- the new look is the default -----------------------------------------
	_check("it starts in the new look", looks.look == 0)
	_check("on the forest floor", chunk != null and chunk.material_override == land.styles[2])
	_check("with the light clump", light != null and field.clump_scene == Looks.LIGHT_GRASS)
	_check("which is light", light != null and _tris(light) < 600,
			"%d triangles" % (_tris(light) if light else 0))
	var sward := looks.sward()
	_check("a low sward fills the meadows", sward != null and sward.visible
			and sward.clump_count() > clumps, "%d short clumps" % (sward.clump_count() if sward != null else 0))
	var short := _clump_mesh(sward) if sward != null else null
	_check("of short clumps, lighter still", short != null and _tris(short) < 260
			and short.get_aabb().size.y < 0.5,
			"%d triangles, %.2f m" % [_tris(short) if short else 0, short.get_aabb().size.y if short else 0.0])
	_check("drawn nearer than the grass", sward != null and sward.draw_distance_scale < 0.6)

	# --- F8: the old one ------------------------------------------------------
	looks.apply(1)
	var old_mesh := _clump_mesh(field)
	_check("F8 puts on the old look", chunk.material_override == land.styles[0])
	_check("with the full clump", field.clump_scene == Looks.OLD_GRASS and old_mesh != null
			and old_mesh != light and _tris(old_mesh) > 5000, "%d triangles" % (_tris(old_mesh) if old_mesh else 0))
	_check("on the same clumps, not a new field", field.clump_count() == clumps)
	var every := true
	for node in field.find_children("*", "MultiMeshInstance3D", false, false):
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh == light:
			every = false
	_check("every chunk of it", every)
	_check("and no sward", sward != null and not sward.visible)
	looks.apply(0)

	var mat := land.styles[2] as ShaderMaterial
	var mask := looks.ground_mask()
	_check("the forest floor has its mask", mask != null and mat.get_shader_parameter("ground_mask") == mask)
	var image := mask.get_image() if mask != null else null
	var rect := looks.mask_rect()
	var forest := world.get_node("Forest") as Forest
	var trunks := forest.trunk_positions()
	var under := 0
	for i in mini(trunks.size(), 200):
		if _at(image, rect, trunks[i]).r > 0.3:
			under += 1
	_check("red under the trees", trunks.size() > 100 and under > mini(trunks.size(), 200) * 0.9,
			"%d of %d" % [under, mini(trunks.size(), 200)])
	var green := 0
	for i in range(0, clumps, maxi(clumps / 200, 1)):
		var at := field.to_global(field.clump_home(i))
		if _at(image, rect, Vector2(at.x, at.z)).g > 0.2:
			green += 1
	_check("green under the grass", green > 150, "%d of 200" % green)
	var spawn := (world.get_node("SpawnPoints").get_child(0) as Node3D).global_position
	_check("and no wood at the spawn", _at(image, rect, Vector2(spawn.x, spawn.z)).r < 0.2)
	var marsh := world.get_node_or_null("Marsh/Ground") as MeshInstance3D
	_check("the marsh's ground goes with it", marsh == null or marsh.material_override == land.styles[2])

	# --- round again --------------------------------------------------------
	for i in Looks.LOOKS.size():
		looks.apply(looks.look + 1)
	_check("F8's round comes back to the new look", looks.look == 0
			and chunk.material_override == land.styles[2] and _clump_mesh(field) == light
			and sward.visible)
	_finish()


func _clump_mesh(field: GrassField) -> Mesh:
	for node in field.find_children("*", "MultiMeshInstance3D", false, false):
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh != null:
			return multi.mesh
	return null


func _tris(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		else:
			total += index.size() / 3
	return total


func _at(image: Image, rect: Rect2, at: Vector2) -> Color:
	if image == null:
		return Color.BLACK
	var x := clampi(int((at.x - rect.position.x) / Looks.MASK_CELL), 0, image.get_width() - 1)
	var y := clampi(int((at.y - rect.position.y) / Looks.MASK_CELL), 0, image.get_height() - 1)
	return image.get_pixel(x, y)


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _finish() -> void:
	print("")
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) FAILED." % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok   - %s" % label)
	else:
		_failures += 1
		print("  FAIL - %s %s" % [label, ("(%s)" % detail) if detail else ""])
