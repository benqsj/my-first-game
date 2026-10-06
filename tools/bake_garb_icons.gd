extends SceneTree

## tools/bake_garb_icons.gd — the bag's pictures of the skeletons' clothes
## ([SkeletonGarb]): each piece of the all-in-one kit alone (its cloth, not the
## bones modelled into it), in its colours,
## on the kit's skeleton at rest, three-quarters on, lit, on a clear ground.
##
##   godot --path . --script res://tools/bake_garb_icons.gd
##
## Out: assets/ui/icons/garb/<id>.png (192 px). Windowed (it renders).

const OUT := "res://assets/ui/icons/garb/"
const PX := 192
const OVER := 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var view := SubViewport.new()
	view.size = Vector2i(PX * OVER, PX * OVER)
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cam.environment = env
	view.add_child(cam)
	cam.current = true
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(30), 0)
	key.light_energy = 1.4
	view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-150), 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.75, 0.82, 1.0)
	view.add_child(rim)
	var kit := (load(SkeletonGarb.KIT) as PackedScene).instantiate() as Node3D
	view.add_child(kit)
	# three-quarters on (the kit faces +Z, the camera looks down -Z)
	kit.rotation.y = deg_to_rad(-28.0)
	var done := 0
	for id: String in SkeletonGarb.PIECES:
		var piece: Array = SkeletonGarb.PIECES[id]
		var shown: MeshInstance3D = null
		for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
			mi.visible = String(mi.name) == String(piece[1])
			if mi.visible:
				shown = mi
				# the cloth only, as it is worn (SkeletonGarb.cloth_of)
				mi.mesh = SkeletonGarb.cloth_of(id)
				var mat := PackCreature.material(String(piece[4]))
				for s in mi.mesh.get_surface_count():
					mi.set_surface_override_material(s, mat)
		if shown == null:
			continue
		await process_frame
		var box := shown.mesh.get_aabb()
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for k in 8:
			var q := shown.global_transform * box.get_endpoint(k)
			lo = lo.min(q)
			hi = hi.max(q)
		var mid := (lo + hi) * 0.5
		cam.position = Vector3(mid.x, mid.y, mid.z + 10.0)
		cam.size = maxf(hi.x - lo.x, hi.y - lo.y) * 1.1
		for f in 3:
			await RenderingServer.frame_post_draw
		_fit(view.get_texture().get_image()).save_png(ProjectSettings.globalize_path(OUT + id + ".png"))
		done += 1
	print("BAKED ", done)
	quit()


## The drawn part of `img`, centred on a square of PX with a margin.
func _fit(img: Image) -> Image:
	var used := img.get_used_rect()
	var out := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	if used.size.x < 2 or used.size.y < 2:
		return out
	var part := img.get_region(used)
	var k := float(PX) * 0.88 / float(maxi(used.size.x, used.size.y))
	part.resize(maxi(int(used.size.x * k), 1), maxi(int(used.size.y * k), 1), Image.INTERPOLATE_LANCZOS)
	out.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()),
			Vector2i(floori((PX - part.get_width()) * 0.5), floori((PX - part.get_height()) * 0.5)))
	return out
