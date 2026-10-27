class_name AltarCircle
extends Object

## The altar ("სამსხვერპლო"), low poly as the forest (the user's pick of the
## Higgsfield concepts, "B", 2026-10-26): a ring of tall carved standing
## stones with faintly glowing runes in a dark pine wood at dusk, round a
## raised round dais of stone flags; on the dais the two altars of
## [PortalEvent], the great crimson crystal (blood) on the left and the bowl
## of molten gold on the right; the arched great stone behind them, iron
## lanterns hung from the stones, mossy boulders, candles, two ravens, a
## low mist.
##
## The shapes are `altar_lowpoly.glb` (Blender, `vepxis-art/world/altar_lowpoly.py`),
## lit with the forest's shaders ([ForestGlade]). The deals are [PortalEvent]'s.

const KIT := "res://assets/dungeon/altar/altar_lowpoly.glb"
const PINES := ["Pine0", "Pine1", "Pine2", "Pine3"]
## The dais: round, its top this high, this wide.
const DAIS_R := 8.5
const DAIS_TOP := 0.44
## The ring of standing stones; their bearings from the back (-z), in degrees,
## clear of the way in (+z) and of the two portals behind (±9, −l/2+10).
const RING_R := 12.0
const STONE_BEARINGS := [50.0, 78.0, 106.0, 134.0]
## The great stone at the back.
const GREAT_Z := -12.0
## Where the two altars stand on the dais (the event's own frame).
const BLOOD_AT := Vector3(-3.6, DAIS_TOP, -1.2)
const GOLD_AT := Vector3(3.6, DAIS_TOP, -1.2)
## The lantern on a lantern stone (Mono1, 3, 5, 7), in its own frame.
const LAMP_AT := Vector3(1.6, 2.93, 0.0)

static var _kit: Node3D


## Builds the place into `room`, `w` by `l` metres, the altars under `ev`;
## gives back {"blood": node, "gold": node} (the altars' glowing parts).
static func build(d: Dungeon, room: Node3D, w: float, l: float, rng: RandomNumberGenerator,
		ev: Node3D) -> Dictionary:
	if _kit == null or not is_instance_valid(_kit):
		_kit = (load(KIT) as PackedScene).instantiate() as Node3D
		_dress(_kit)
	var grow := 1.0
	match Graphics.current:
		Graphics.Level.LOW:
			grow = 0.45
		Graphics.Level.MEDIUM:
			grow = 0.7
		Graphics.Level.ULTRA:
			grow = 1.3
	var slab := d._solid(room, ForestGlade._solid(0.0), Vector3(w + 110.0, 1.0, l + 110.0), Vector3(0.0, -0.5, 0.0))
	for mi in slab.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
	var ground := _piece(room, "Ground", Vector3.ZERO, 0.0, 1.0)
	if ground is GeometryInstance3D:
		(ground as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d._bounds(room, w, l)
	d._crag_under(room, w + 110.0, l + 110.0, PalaceVista.DROP + 60.0, -1.0)
	_dais(room)
	_piece(room, "Path", Vector3(0.0, 0.0, DAIS_R + 0.6), 0.0, 1.0)
	_stones(room, rng)
	var blood := _piece(ev, "AltarBlood", BLOOD_AT, rng.randf_range(0.0, TAU), 1.0)
	var gold := _piece(ev, "AltarGold", GOLD_AT, rng.randf_range(0.0, TAU), 1.0)
	for at: Vector3 in [BLOOD_AT, GOLD_AT]:
		d._blocker(ev, Vector3(1.6, 1.4, 1.6), at + Vector3(0.0, 0.7, 0.0))
	# candles round the altars and at the great stone's foot
	for at: Vector3 in [BLOOD_AT + Vector3(-1.2, 0.0, 0.9), BLOOD_AT + Vector3(1.0, 0.0, -1.0),
			GOLD_AT + Vector3(1.2, 0.0, 0.9), GOLD_AT + Vector3(-1.0, 0.0, -1.0),
			Vector3(-2.6, 0.9, GREAT_Z + 1.6), Vector3(2.4, 0.9, GREAT_Z + 1.7), Vector3(0.0, DAIS_TOP, -5.6)]:
		_piece(ev, "Candles%d" % rng.randi_range(0, 2), at, rng.randf_range(0.0, TAU), rng.randf_range(1.0, 1.5))
	for at: Vector3 in [Vector3(0.0, 1.0, -4.6), Vector3(-2.5, 1.4, GREAT_Z + 1.8)]:
		_candle_light(room, at)
	# two ravens watching, at the dais's front edge
	for at: Vector3 in [Vector3(-5.6, 0.22, 6.0), Vector3(6.9, 0.0, 3.4)]:
		var raven := _piece(room, "Raven", at, rng.randf_range(0.0, TAU), 1.6)
		if raven is GeometryInstance3D:
			(raven as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wood(room, rng, grow, l)
	_mist(room)
	_motes(room)
	return {"blood": blood, "gold": gold}


## The shaders onto the Blender shapes, by their materials' names.
static func _dress(kit: Node3D) -> void:
	for mi: MeshInstance3D in kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			match String(mat.resource_name) if mat != null else "":
				"Needles":
					var nm := ForestGlade._foliage(0.02).duplicate() as ShaderMaterial
					nm.set_shader_parameter("backlight", Vector3(0.06, 0.12, 0.12))
					nm.set_shader_parameter("bright", 1.1)
					mi.set_surface_override_material(s, nm)
				"Ground":
					var gm := ForestGlade._solid(0.0).duplicate() as ShaderMaterial
					gm.set_shader_parameter("bright", 1.3)
					gm.set_shader_parameter("roughness", 1.0)
					mi.set_surface_override_material(s, gm)
				"Rune":
					mi.set_surface_override_material(s, _glowing(Color(1.0, 0.8, 0.5), 0.55))
				"Crystal":
					var cm := _glowing(Color(1.0, 0.18, 0.22), 1.6)
					cm.set_shader_parameter("roughness", 0.25)
					mi.set_surface_override_material(s, cm)
				"Molten":
					mi.set_surface_override_material(s, _glowing(Color(1.0, 0.72, 0.3), 1.5))
				"Glass":
					mi.set_surface_override_material(s, _glowing(Color(1.0, 0.7, 0.38), 2.2))
				"Flame":
					mi.set_surface_override_material(s, _glowing(Color(1.0, 0.66, 0.3), 3.0))
				"Gold":
					var gd := ForestGlade._solid(0.0).duplicate() as ShaderMaterial
					gd.set_shader_parameter("roughness", 0.35)
					gd.set_shader_parameter("glow", 0.25)
					gd.set_shader_parameter("glow_col", Color(1.0, 0.7, 0.3))
					mi.set_surface_override_material(s, gd)
				"Bark":
					mi.set_surface_override_material(s, ForestGlade._solid(0.3))
				"Flags":
					mi.set_surface_override_material(s, ForestGlade._solid(0.0))
				_:
					mi.set_surface_override_material(s, ForestGlade._solid(0.3))
		if mi.name.begins_with("Candles") or mi.name == "Path":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _glowing(tint: Color, glow: float) -> ShaderMaterial:
	var m := ForestGlade._solid(0.0).duplicate() as ShaderMaterial
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("glow_col", tint)
	return m


static func _piece(parent: Node3D, piece: String, at: Vector3, yaw: float, s: float) -> Node3D:
	var src := _kit.get_node_or_null(piece) as Node3D
	if src == null:
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), at)
	parent.add_child(n)
	return n


## The dais to look at and its stop: a low round step he walks up (a cone's
## gentle slope, not a wall).
static func _dais(room: Node3D) -> void:
	_piece(room, "Dais", Vector3.ZERO, 0.0, 1.0)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for k in 24:
		var a := TAU * float(k) / 24.0
		pts.append(Vector3(cos(a) * (DAIS_R + 1.2), -0.05, sin(a) * (DAIS_R + 1.2)))
		pts.append(Vector3(cos(a) * (DAIS_R - 1.6), DAIS_TOP, sin(a) * (DAIS_R - 1.6)))
	hull.points = pts
	shape.shape = hull
	body.add_child(shape)
	room.add_child(body)


## The ring of standing stones round the dais, each with its face to the
## middle; lanterns on two of them; the great stone at the back.
static func _stones(room: Node3D, rng: RandomNumberGenerator) -> void:
	var great := _piece(room, "GreatStone", Vector3(0.0, 0.0, GREAT_Z), 0.0, 1.0)
	if great != null:
		_stop(great, Vector3(5.6, 8.0, 2.4), Vector3(0.0, 4.0, 0.0))
	var k := 0
	for side: float in [-1.0, 1.0]:
		for b: float in STONE_BEARINGS:
			var a := deg_to_rad(b) * side
			# (bearing from the back: -z at 0)
			var at := Vector3(sin(a) * RING_R, 0.0, -cos(a) * RING_R)
			var to_mid := -at.normalized()
			var yaw := atan2(to_mid.x, to_mid.z)
			var lamp := b == 78.0 or b == 134.0
			# each stone its own: the alphabet runs round the ring in order
			# (asomtavruli, the user's word, 2026-10-27); lanterns on 1, 3, 5, 7
			var piece := "Mono%d" % k
			var s := rng.randf_range(1.0, 1.15)
			var stone := _piece(room, piece, at, yaw + rng.randf_range(-0.08, 0.08), s)
			k += 1
			if stone == null:
				continue
			_stop(stone, Vector3(1.9, 6.0, 1.4), Vector3(0.0, 3.0, 0.0))
			if lamp:
				var light := OmniLight3D.new()
				light.light_color = Color(1.0, 0.68, 0.36)
				light.light_energy = 1.4
				light.omni_range = 7.5
				light.shadow_enabled = false
				light.position = LAMP_AT
				stone.add_child(light)


static func _stop(n: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	n.add_child(body)


static func _candle_light(room: Node3D, at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 0.8
	light.omni_range = 4.5
	light.shadow_enabled = false
	light.position = at
	room.add_child(light)


## The dark pine wood all round, the near ones stopping him; mossy boulders.
static func _wood(room: Node3D, rng: RandomNumberGenerator, grow: float, l: float) -> void:
	# (clear of the two portals behind, (±9, −l/2+10), and the way to them)
	var gates: Array[Vector3] = [Vector3(-9.0, 0.0, -l * 0.5 + 10.0), Vector3(9.0, 0.0, -l * 0.5 + 10.0)]
	var clear := func(at: Vector3) -> bool:
		for g in gates:
			if at.distance_to(g) < 6.0:
				return false
		return true
	for k in int(16.0):
		var a := (float(k) + 0.5) / 16.0 * TAU + rng.randf_range(-0.1, 0.1)
		var at := Vector3(sin(a), 0.0, cos(a)) * rng.randf_range(18.5, 23.0)
		# (the way in, +z, left open)
		if (absf(at.x) < 10.0 and at.z > 0.0) or not clear.call(at):
			continue
		var s := rng.randf_range(0.9, 1.25)
		var pine := _piece(room, PINES[k % PINES.size()], at, rng.randf_range(0.0, TAU), s)
		if pine != null:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var c := CylinderShape3D.new()
			c.radius = 0.7 * s
			c.height = 6.0
			shape.shape = c
			shape.position.y = 3.0
			body.add_child(shape)
			pine.add_child(body)
	for k in int(80.0 * grow):
		var a := rng.randf_range(0.0, TAU)
		var at := Vector3(sin(a), 0.0, cos(a)) * rng.randf_range(27.0, 66.0)
		if absf(at.x) < 7.0 and at.z > 0.0 and at.z < 36.0:
			continue
		_piece(room, PINES[rng.randi_range(0, PINES.size() - 1)], at, rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.5))
	for k in 16:
		var a := rng.randf_range(0.0, TAU)
		var at := Vector3(sin(a), 0.0, cos(a)) * rng.randf_range(14.5, 24.0)
		if (absf(at.x) < 5.0 and at.z > 0.0) or not clear.call(at):
			continue
		var piece := "Rock%d" % (k % 4)
		var s := rng.randf_range(0.9, 1.5)
		var rock := _piece(room, piece, at, rng.randf_range(0.0, TAU), s)
		if rock != null and k % 4 in [1, 2]:
			_stop(rock, Vector3(1.8, 1.6, 1.8) * s * (1.0 if k % 4 == 1 else 1.3), Vector3(0.0, 0.6, 0.0))


## A low blue mist lying over the ground among the stones and trees.
static func _mist(room: Node3D) -> void:
	if Graphics.current == Graphics.Level.LOW:
		return
	var fog := FogVolume.new()
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fog.size = Vector3(90.0, 5.0, 90.0)
	fog.position = Vector3(0.0, 0.4, 0.0)
	var m := FogMaterial.new()
	m.density = 0.05
	m.albedo = Color(0.62, 0.70, 0.86)
	m.height_falloff = 0.6
	m.edge_fade = 0.6
	fog.material = m
	fog.name = "Mist"
	room.add_child(fog)


## Little warm sparks drifting up over the altars, slow.
static func _motes(room: Node3D) -> void:
	var p := GPUParticles3D.new()
	p.amount = 50
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.position = Vector3(0.0, 1.0, -1.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6.0, 0.5, 4.0)
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.gravity = Vector3(0.0, 0.08, 0.0)
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.75, 0.45, 0.0))
	fade.add_point(0.3, Color(1.0, 0.75, 0.45, 0.8))
	fade.set_color(fade.get_point_count() - 1, Color(1.0, 0.75, 0.45, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = SkillFx.dot()
	q.material = qm
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-8, -1, -6), Vector3(16, 10, 12))
	room.add_child(p)
