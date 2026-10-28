class_name DungeonWarmUp
extends RefCounted

## Everything a run shows, drawn once behind the dark so it is not made in
## front of him: the first place, the creatures, the skills (warm-up), each
## next place as he comes to it ([method _look_round]), and the materials kept
## while the dungeon stands. Taken out of dungeon.gd (2026-10-28); every
## function takes the dungeon as `dun`.

## Everything the run will show, shown to the renderer once behind the
## loading screen ([SceneLoader] waits while a node called PipelineWarmup is
## there, as for the open world's [PipelineWarmup]): the first place looked
## round (the others are, behind the dark, as he comes to them), one of each creature, the
## lord and his orcs, the portals, the shards of the dead, the sparks, the
## heroes' own skills. Godot makes what it draws the first time it draws it,
## and made in front of him each of those was a stall (the user's word,
## 2026-10-20: it sticks going through a portal).
static func _warm_up(dun: Dungeon) -> void:
	if DisplayServer.get_name() == "headless" or not dun.is_inside_tree():
		return
	var started := Time.get_ticks_msec()
	var level_root: Node = dun.owner if dun.owner != null else dun.get_parent()
	var mark := Node.new()
	mark.name = "PipelineWarmup"
	level_root.add_child(mark)
	var was_going := dun._going
	dun._going = true
	if dun._bus >= 0 and dun._bus < AudioServer.bus_count:
		AudioServer.set_bus_mute(dun._bus, true)
	var dark := dun._fade.color.a if dun._fade != null else 0.0
	if dun._fade != null:
		dun._fade.color.a = 1.0
	var eye := Camera3D.new()
	eye.fov = 95.0
	eye.far = 520.0
	dun.add_child(eye)
	# Only the place he stands in, from its door and from over it. The
	# others are no longer put up here (they cost ~3.5 s of the loading
	# screen at High on the M1): each is looked round behind the dark as he
	# goes through its portal ([method _look_round], the user's idea,
	# 2026-10-28: made at the right time, not all beforehand).
	await DungeonWarmUp._look_round(dun, dun.current, eye)

	# The creatures, the portals, the fights' own: in a row before the eye.
	var stage := Node3D.new()
	stage.name = "WarmStage"
	dun.add_child(stage)
	stage.global_position = Dungeon.WARM_AT + Vector3(0.0, 0.0, -400.0)
	eye.make_current()
	eye.global_position = stage.global_position + Vector3(0.0, 3.0, 9.0)
	eye.look_at(stage.global_position + Vector3(0.0, 1.5, 0.0))
	var shown: Array[Node3D] = []
	var x := -6.0
	var made_paths := {}
	for list: Array in dun._premade.values():
		for body: Variant in list:
			if is_instance_valid(body):
				made_paths[String((body as Node).get_meta(&"scene", ""))] = true
	for path: String in dun._scenes:
		var scene: PackedScene = dun._scenes[path]
		if scene == null or made_paths.has(path):
			continue
		var body := scene.instantiate() as Node3D
		if "leash_radius" in body:
			body.set("leash_radius", 0.01)
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.position = Vector3(x, 0.0, 0.0)
		stage.add_child(body)
		shown.append(body)
		x += 3.0
	var lent: Array[Node3D] = []
	for list: Array in dun._premade.values():
		for body: Variant in list:
			if is_instance_valid(body):
				var b := body as Node3D
				b.global_position = stage.global_position + Vector3(x, 0.0, -2.0)
				b.visible = true
				lent.append(b)
				x += 3.5
	for k in 2:
		var gate := PortalLook.new()
		gate.tint = Dungeon.REWARDS["blade"]["tint"] if k == 0 else Color(0.85, 0.12, 0.2)
		var view := Dungeon.PREVIEWS % "cave"
		if k == 0 and ResourceLoader.exists(view):
			gate.view = load(view) as Texture2D
		gate.position = Vector3(-4.0 + float(k) * 8.0, 0.0, -6.0)
		stage.add_child(gate)
	# a blessing's light and its lightning (their materials made now)
	dun.boons._light(&"chain", stage.global_position + Vector3(6.0, 0.0, -3.0), stage)
	dun.boons._bolt(stage.global_position + Vector3(-3.0, 1.5, 0.0), stage.global_position + Vector3(3.0, 1.5, 0.0))
	# the letters the portals and the banner write with, at their sizes: each
	# new letter was drawn into the font's cache as the portals opened
	var letters := "0123456789/:. "
	for code in range(0x10D0, 0x10F1):
		letters += String.chr(code)
	for sizes: Vector2i in [Vector2i(72, 14), Vector2i(56, 12)]:
		var words := Label3D.new()
		words.text = letters
		words.font_size = sizes.x
		words.outline_size = sizes.y
		words.pixel_size = 0.004
		words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		words.no_depth_test = true
		words.position = Vector3(0.0, 4.0 + float(sizes.x) * 0.01, 2.0)
		stage.add_child(words)
	if dun._banner != null:
		dun._banner.text = letters
		dun._banner.show()
		dun._banner_until = 0.0
	var props := MudBall.warm_props()
	stage.add_child(props)
	props.position = Vector3(0.0, 1.5, 5.0)
	var ember := MeshInstance3D.new()
	ember.mesh = MudBall.lump_mesh()
	ember.material_override = MudBall.coal()
	ember.position = Vector3(0.6, 0.0, 0.0)
	props.add_child(ember)
	RogueSkills.warm(props)
	MageSkills.warm(props)
	DarkSkills.warm(props)
	DungeonWarmUp._warm_first_uses(props)
	ScreenMud.prepare(dun.get_tree())
	ScreenMud.splat(dun.get_tree(), 1.0)
	var world := Blood.world_of(dun)
	if world != null:
		SkillFx.burst(world, stage.global_position + Vector3(0.0, 2.0, 3.0), Color(1.0, 0.8, 0.4), 14,
				Vector2(2.0, 5.0), Vector3.UP, 180.0, Vector2(0.03, 0.07), Vector3(0, -6.0, 0), 0.35)
	# the light he goes up in at a new level (its sound kept quiet)
	var lifted := Node3D.new()
	stage.add_child(lifted)
	lifted.position = Vector3(3.0, 0.0, 2.0)
	var beam := LevelBeam.on(lifted)
	if beam != null:
		for node in beam.find_children("*", "AudioStreamPlayer3D", true, false):
			(node as AudioStreamPlayer3D).stop()
	# the cave's bats, gone round as a flock
	dun._bat_flock(stage.global_position + Vector3(0.0, 3.0, 0.0))
	# one of them broken as the dead are: lit, then in shards
	var breaking: DeathShatter = null
	if not shown.is_empty():
		breaking = DeathShatter.start(dun, shown[0])
	# the flash of a blow and the ice shell, on the skinned bodies themselves
	# (the skinned versions of those materials are made apart)
	for b: Node3D in shown.slice(1) + lent:
		if is_instance_valid(b):
			HitFeel.flash(b, 0.3)
	if shown.size() > 1 and is_instance_valid(shown[1]):
		FrostShell.encase(shown[1], 0.3)
	for f in 40:
		eye.make_current()
		await dun.get_tree().process_frame
		if f % 3 == 1:
			DungeonWarmUp._keep_materials(dun, level_root)
		if f >= 6 and (breaking == null or not is_instance_valid(breaking)):
			break
	# What each of those was drawn with, held for as long as the dungeon is
	# up. Godot makes a material's shader for each kind of material and lets
	# it go when the last one of that kind is gone: the shards of the dead, the
	# bats, the sparks were each made afresh every time they came round again
	# (a death cost 40–100 ms; the bats near a second).
	DungeonWarmUp._keep_materials(dun, level_root)
	ScreenMud.clear(dun.get_tree())
	for b in lent:
		if is_instance_valid(b):
			b.visible = false
			b.global_position = Vector3(b.global_position.x, -300.0, 0.0)
	# out of sight, and gone once what the skills and the sparks left timed
	# on it has run out
	# (the one in shards goes with the stage: its shards still hold it)
	for body in shown.slice(1):
		if is_instance_valid(body):
			body.queue_free()
	stage.visible = false
	dun.get_tree().create_timer(6.0).timeout.connect(stage.queue_free)

	# the view back to the hero's own eye
	var hers := dun._hero_eye()
	eye.queue_free()
	if hers != null:
		hers.make_current()
	if dun._fade != null:
		dun._fade.color.a = dark
	if dun._bus >= 0 and dun._bus < AudioServer.bus_count:
		AudioServer.set_bus_mute(dun._bus, false)
	dun._going = was_going
	mark.queue_free()
	# the dungeon's name, now that it can be seen
	dun._say("%s" % String(Portals.DEFS[dun.id]["name"]), 3.5)
	print("Dungeon: warm-up %d ms" % (Time.get_ticks_msec() - started))


## Place `i` shown to the renderer once from its door and from high over
## it (two frames each), through `eye` or a camera of its own, the view then
## given back to his own eye. Done behind the dark (the loading screen, a
## portal's black): Godot makes what it draws the first time it draws it,
## and this way that is not in front of him. ~60–400 ms a place at High on
## the M1 (2026-10-27 probe), where it used to be all at the start.
static func _look_round(dun: Dungeon, i: int, eye: Camera3D = null) -> void:
	if DisplayServer.get_name() == "headless" or i < 0 or i >= dun.rooms.size():
		return
	var own := eye == null
	if own:
		eye = Camera3D.new()
		eye.fov = 95.0
		eye.far = 520.0
		dun.add_child(eye)
	var r: Dictionary = dun.rooms[i]
	var c := dun.centre(i)
	var l := float(r.get("l", 40.0))
	var h := maxf(float(r.get("h", 0.0)), 8.0)
	for pose: Array in [[Vector3(0.0, 2.5, l * 0.5 - 3.0), Vector3(0.0, 2.0, 0.0)],
			[Vector3(0.0, h + 14.0, -l * 0.35), Vector3(0.0, 0.0, l * 0.1)]]:
		if not is_instance_valid(eye):
			return
		eye.make_current()
		eye.global_position = c + (pose[0] as Vector3)
		eye.look_at(c + (pose[1] as Vector3))
		await dun.get_tree().process_frame
		await dun.get_tree().process_frame
	if own:
		eye.queue_free()
		var hers := dun._hero_eye()
		if hers != null:
			hers.make_current()


static func _keep_materials(dun: Dungeon, under: Node) -> void:
	for node in under.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		DungeonWarmUp._keep(dun, g.material_override)
		DungeonWarmUp._keep(dun, g.material_overlay)
		var meshes: Array[Mesh] = []
		if g is MeshInstance3D:
			var mi := g as MeshInstance3D
			meshes.append(mi.mesh)
			for k in mi.get_surface_override_material_count():
				DungeonWarmUp._keep(dun, mi.get_surface_override_material(k))
		elif g is GPUParticles3D:
			var gp := g as GPUParticles3D
			DungeonWarmUp._keep(dun, gp.process_material)
			for k in gp.draw_passes:
				meshes.append(gp.get_draw_pass_mesh(k))
		for mesh in meshes:
			if mesh == null:
				continue
			for k in mesh.get_surface_count():
				DungeonWarmUp._keep(dun, mesh.surface_get_material(k))
			if mesh is PrimitiveMesh:
				DungeonWarmUp._keep(dun, (mesh as PrimitiveMesh).material)


static func _keep(dun: Dungeon, m: Material) -> void:
	if m == null or not (m is BaseMaterial3D or m is ParticleProcessMaterial):
		return
	dun._kept[m.get_instance_id()] = m


## Those loaded, held so the cache keeps them while the game is up.
static var _held: Array = []


## What stalled the game the first time it came, seen on the TestFlight build
## (the user's word, 2026-10-28: a stop on some skills — another hero's too —
## and some creatures' moves): shown here once, behind the loading.
static func _warm_first_uses(props: Node3D) -> void:
	_held.clear()
	ImpactFx.warm()
	var here := props.global_position
	# the elf mage's: the frost nova, the moon's runes, their lights
	FrostNova.burst(props, here, 0.6, 0.1)
	for e: float in [1.4, 2.2]:
		var rd := Decal.new()
		rd.size = Vector3.ONE
		rd.texture_albedo = MoonWell.runes()
		rd.texture_emission = MoonWell.runes()
		rd.emission_energy = e
		props.add_child(rd)
	SkillFx.light(props, here, Color(0.8, 0.85, 1.0), 1.0, 2.0, 0.3)
	# shaders made on first use: the heroes' cut air, the poison's veins, the
	# zombie's scream, the troll's stone
	for path: String in ["res://assets/fx/cut_air.gdshader", HeroPoison.VEINS,
			ZombieFighter.SCREAM_AIR, "res://scripts/troll_stone.gdshader"]:
		if not ResourceLoader.exists(path):
			continue
		var q := MeshInstance3D.new()
		q.mesh = QuadMesh.new()
		var sm := ShaderMaterial.new()
		sm.shader = load(path) as Shader
		_held.append(sm.shader)
		q.material_override = sm
		props.add_child(q)
	# the butcher's hook, loaded mid-fight before
	if ResourceLoader.exists(PigButcher.HOOK_MESH):
		var hook := load(PigButcher.HOOK_MESH) as PackedScene
		if hook != null:
			_held.append(hook)
			props.add_child(hook.instantiate())
