extends SceneTree

## tools/bake_own_garb_icons.gd — the bag's pictures of each hero's own
## clothes, piece by piece (the user's word, 2026-10-06): for every hero of
## PolysplitLook.HERO_CLASSES, each gender, each of his outfits' coat
## (`top_<cls>`), breeches (`bottom_<cls>`) and hat (`hat_<hat>`), the
## figure's mesh alone, dyed as his default look dyes it, three-quarters on.
##
##   godot --path . --script res://tools/bake_own_garb_icons.gd
##
## Out: assets/ui/icons/garb/own_<hero>_<g>_<mesh key>.png. Windowed.

const OUT := "res://assets/ui/icons/garb/"
const PX := 192
## Rendered this much larger, cut to what is drawn, and brought down.
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
	var done := 0
	for hero: StringName in PolysplitLook.HERO_CLASSES:
		var path := "res://scenes/player/%s.tres" % hero
		if not ResourceLoader.exists(path):
			continue
		var prof := load(path) as CharacterProfile
		if prof == null or prof.visuals == null:
			continue
		for g: String in ["m", "f"]:
			var v: Node3D = prof.visuals.instantiate()
			view.add_child(v)
			# three-quarters on: the model faces +Z, the camera looks down -Z
			v.rotation.y = deg_to_rad(-28.0)
			await process_frame
			var custom: int = (v.get(&"faces") as Array).find(SkinnedRig.CUSTOM)
			if custom < 0:
				v.queue_free()
				continue
			v.call(&"set_look", PolysplitLook.default_look(hero, g))
			v.call(&"set_face", custom)
			for i in 6:
				await process_frame
			var fig: Node3D = v.get(&"_figure")
			if fig == null:
				v.queue_free()
				continue
			var keys: Array[String] = []
			for cls: String in PolysplitLook.classes(hero, g):
				keys.append("top_" + cls)
				keys.append("bottom_" + cls)
				var hat := String((PolysplitLook.CLASSES[g] as Dictionary).get(cls, {}).get("hat", ""))
				if hat != "" and not keys.has("hat_" + hat):
					keys.append("hat_" + hat)
			# everything he is drawn with, not only the figure's (the bow's string is the rig's)
			var meshes := v.find_children("*", "MeshInstance3D", true, false)
			for k: String in keys:
				var shown: MeshInstance3D = null
				for m: MeshInstance3D in meshes:
					m.visible = String(m.name) == "ps_" + k
					if m.visible:
						shown = m
				if shown == null:
					continue
				await process_frame
				var box := shown.mesh.get_aabb()
				var lo := Vector3(INF, INF, INF)
				var hi := -lo
				for c in 8:
					var q := shown.global_transform * box.get_endpoint(c)
					lo = lo.min(q)
					hi = hi.max(q)
				var mid := (lo + hi) * 0.5
				cam.position = Vector3(mid.x, mid.y, mid.z + 10.0)
				cam.size = maxf(hi.x - lo.x, hi.y - lo.y) * 1.2
				for f in 3:
					await RenderingServer.frame_post_draw
				_fit(view.get_texture().get_image()).save_png(ProjectSettings.globalize_path(
						OUT + "own_%s_%s_%s.png" % [hero, g, k]))
				done += 1
			v.queue_free()
			await process_frame
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
