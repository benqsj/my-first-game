class_name DungeonFx
extends RefCounted

## The places' happenings while a fight goes on: the floor cracked by an
## orc's blow and a column brought down, fires flickering, birds and bats,
## lightning, stones from the roof, the flash of a blow. Taken out of
## dungeon.gd (2026-10-28); every function takes the dungeon as `dun`.

## Every peer: an orc's heavy blow has cracked the floor at `at` (called by
## [OrcFighter] through the "ground_scars" group). The crack stays, stone is
## thrown up round it, and a column near enough comes down.
static func scar(dun: Dungeon, at: Vector3, weight: float) -> void:
	if dun.room_at(at) < 0:
		return
	dun._scars += 1
	Sfx.play(dun, Dungeon.SND + "crumble.wav", null, at, randf_range(0.9, 1.1), -3.0 + 4.0 * weight)
	var crack := DarkFx.decal(dun, at, DarkFx.CRACK, 2.2 + 1.8 * weight, Color(0.07, 0.06, 0.05, 1.0), 0.0, 0.95)
	crack.rotation.y = randf() * TAU
	dun._rubble(dun, at - dun.global_position, 0.6 + 0.8 * weight, int(3 + 5 * weight), dun._scars * 31)
	if weight < 0.6:
		return
	for col in dun._columns:
		if bool(col["broken"]):
			continue
		var c: Vector3 = col["at"]
		if Vector2(c.x - at.x, c.z - at.z).length() < float(col["thick"]) + 2.2 * weight:
			DungeonFx._topple(dun, col, at)
			break


## A column brought down: a stump stands, its drums lie where it fell.
static func _topple(dun: Dungeon, col: Dictionary, from: Vector3) -> void:
	col["broken"] = true
	Sfx.play(dun, Dungeon.SND + "thud.wav", null, col["at"], randf_range(0.9, 1.05), 4.0)
	for part: MeshInstance3D in col["parts"]:
		part.visible = false
	var blocker: StaticBody3D = col["blocker"]
	if is_instance_valid(blocker):
		blocker.queue_free()
	var room: Node3D = col["node"]
	var at: Vector3 = col["local"]
	var thick: float = col["thick"]
	var stump := CylinderMesh.new()
	stump.top_radius = thick * 0.66
	stump.bottom_radius = thick * 0.7
	stump.height = 2.2
	stump.radial_segments = 14
	dun._deco(room, dun._wall_mat, stump, at + Vector3(0.0, 1.1, 0.0))
	dun._blocker(room, Vector3(thick * 1.3, 2.2, thick * 1.3), at + Vector3(0.0, 1.1, 0.0))
	var away := (col["at"] as Vector3) - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var h: float = col["h"]
	var drums := 3
	for k in drums:
		var drum := CylinderMesh.new()
		drum.top_radius = thick * 0.64
		drum.bottom_radius = thick * 0.64
		drum.height = (h - 3.0) / float(drums)
		drum.radial_segments = 14
		var where := at + away * (2.4 + float(k) * (drum.height + 0.3)) + Vector3(0.0, thick * 0.64, 0.0)
		var d := dun._deco(room, dun._wall_mat, drum, where)
		d.rotation = Vector3(PI * 0.5, atan2(away.x, away.z), randf_range(-0.2, 0.2))
	var world := Blood.world_of(dun)
	if world != null:
		SkillFx.burst(world, (col["at"] as Vector3) + Vector3.UP * 2.0, Color(0.5, 0.45, 0.4, 0.6), 40,
				Vector2(1.5, 5.0), Vector3.UP, 80.0, Vector2(0.12, 0.3), Vector3(0, -2.0, 0), 1.6)


static func _flicker_fires(dun: Dungeon, now: float) -> void:
	var k := 0
	while k < dun._fire_lights.size():
		var f: Dictionary = dun._fire_lights[k]
		var obj: Variant = f["light"]
		if not is_instance_valid(obj):
			dun._fire_lights.remove_at(k)
			continue
		var light := obj as OmniLight3D
		if light.is_visible_in_tree():
			var t := now + float(f["at"])
			light.light_energy = float(f["base"]) * (0.86 + 0.07 * sin(t * 7.3) + 0.05 * sin(t * 13.7 + 1.3)
					+ 0.03 * sin(t * 23.1 + 2.1))
		k += 1


static func _fly_birds(dun: Dungeon, delta: float) -> void:
	for b in dun._birds:
		# checked before the cast: a cast of a freed bird is an error each
		# frame (a place's birds outlive it till the next arrival clears them)
		if not is_instance_valid(b["node"]):
			continue
		var node := b["node"] as Node3D
		b["at"] = float(b["at"]) + float(b["speed"]) * delta
		var a: float = b["at"]
		var r: float = b["radius"]
		node.position = Vector3(sin(a) * r, float(b["height"]) + sin(a * 3.0) * 2.0, cos(a) * r)
		node.rotation.y = a + (PI * 0.5 if float(b["speed"]) > 0.0 else -PI * 0.5)
		var flap := sin(Time.get_ticks_msec() / 1000.0 * 7.0 + r) * 0.5
		(node.get_node("L") as Node3D).rotation.z = flap
		(node.get_node("R") as Node3D).rotation.z = -flap


## A flash of lightning over a stormy place, its thunder after it.
static func _lightning(dun: Dungeon) -> void:
	if dun._sky_mat == null:
		return
	var tw := dun.create_tween()
	tw.tween_method(func(v: float) -> void: dun._sky_mat.set_shader_parameter("flash", v), 0.0, 1.0, 0.05)
	tw.tween_method(func(v: float) -> void: dun._sky_mat.set_shader_parameter("flash", v), 1.0, 0.2, 0.12)
	tw.tween_method(func(v: float) -> void: dun._sky_mat.set_shader_parameter("flash", v), 0.2, 0.9, 0.06)
	tw.tween_method(func(v: float) -> void: dun._sky_mat.set_shader_parameter("flash", v), 0.9, 0.0, 0.4)
	var bolt := OmniLight3D.new()
	bolt.light_color = Color(0.8, 0.85, 1.0)
	bolt.light_energy = 0.0
	bolt.omni_range = 220.0
	bolt.shadow_enabled = false
	dun.add_child(bolt)
	bolt.global_position = dun.centre(dun.current) + Vector3(dun._rng.randf_range(-40.0, 40.0), 70.0, dun._rng.randf_range(-40.0, 40.0))
	var lt := dun.create_tween()
	lt.tween_property(bolt, "light_energy", 6.0, 0.05)
	lt.tween_property(bolt, "light_energy", 1.0, 0.12)
	lt.tween_property(bolt, "light_energy", 5.0, 0.06)
	lt.tween_property(bolt, "light_energy", 0.0, 0.4)
	lt.tween_callback(bolt.queue_free)
	dun.get_tree().create_timer(dun._rng.randf_range(0.4, 1.4)).timeout.connect(func() -> void:
		Sfx.play_flat(dun, Dungeon.SND + "thunder.wav", dun._rng.randf_range(0.9, 1.15), -2.0))
#endregion


## Now and then a few stones and dust come down from a hall's roof near him.
static func _falling_stones(dun: Dungeon, near: Vector3, h: float) -> void:
	var world := Blood.world_of(dun)
	if world == null:
		return
	var at := near + Vector3(dun._rng.randf_range(-9.0, 9.0), 0.0, dun._rng.randf_range(-9.0, 9.0))
	at.y = dun.centre(dun.current).y
	for k in dun._rng.randi_range(2, 5):
		var stone := MeshInstance3D.new()
		stone.mesh = RockWave._crag_mesh(dun._rng.randi_range(0, RockWave.SHAPES - 1))
		var box := stone.mesh.get_aabb()
		var size := dun._rng.randf_range(0.12, 0.3)
		stone.scale = Vector3.ONE * size / maxf(box.size.x, 0.01)
		stone.material_override = dun._rock_mat
		world.add_child(stone)
		var from := at + Vector3(dun._rng.randf_range(-0.8, 0.8), h - 0.5, dun._rng.randf_range(-0.8, 0.8))
		stone.global_position = from
		var fall := sqrt(2.0 * (h - 0.5) / 9.8) * dun._rng.randf_range(0.95, 1.1)
		var tw := dun.create_tween()
		tw.tween_property(stone, "global_position:y", at.y + 0.1, fall).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(stone, "rotation", Vector3(dun._rng.randf_range(-6.0, 6.0), 0.0, dun._rng.randf_range(-6.0, 6.0)), fall)
		tw.tween_interval(6.0)
		tw.tween_callback(stone.queue_free)
	SkillFx.burst(world, at + Vector3.UP * (h - 0.5), Color(0.7, 0.62, 0.5, 0.6), 30, Vector2(0.2, 1.0), Vector3.DOWN,
			40.0, Vector2(0.08, 0.2), Vector3(0, -3.0, 0), 2.5)
	var land := sqrt(2.0 * (h - 0.5) / 9.8)
	dun.get_tree().create_timer(land).timeout.connect(func() -> void:
		DustRing.burst(world, at + Vector3.UP * 0.05, 0.5)
		Sfx.play(dun, Dungeon.SND + "crumble.wav", null, at, dun._rng.randf_range(1.2, 1.5), -12.0))


## A flock of bats out of the dark of the roof, gone again.
static func _bat_flock(dun: Dungeon, at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 2.6
	p.one_shot = true
	p.explosiveness = 0.85
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.5
	pm.direction = Vector3(dun._rng.randf_range(-1.0, 1.0), -0.2, dun._rng.randf_range(-1.0, 1.0)).normalized()
	pm.spread = 50.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.5
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.2)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.03, 0.025, 0.03)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	dun.add_child(p)
	p.global_position = at
	p.emitting = true
	dun.get_tree().create_timer(3.5).timeout.connect(p.queue_free)


## A blow on one of them seen: a warm flash where it struck and a few sparks.
static func _on_foe_hurt(dun: Dungeon, _remaining: float, body: Node3D) -> void:
	if not is_instance_valid(body):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(body.get_meta(&"flashed", -1.0)) < 0.1:
		return
	body.set_meta(&"flashed", now)
	var world := Blood.world_of(dun)
	if world == null:
		return
	var at := body.global_position + Vector3.UP * 1.1 * maxf(float(body.get("visual_scale")) if "visual_scale" in body else 1.0, 0.5)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.78, 0.45)
	flash.light_energy = 3.5
	flash.omni_range = 4.5
	world.add_child(flash)
	flash.global_position = at
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.16)
	tw.tween_callback(flash.queue_free)
	SkillFx.burst(world, at, Color(1.0, 0.8, 0.4), 14, Vector2(2.0, 5.0), Vector3.UP, 180.0, Vector2(0.03, 0.07),
			Vector3(0, -6.0, 0), 0.35)
#endregion
