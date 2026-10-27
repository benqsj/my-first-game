class_name MudBall
extends Node3D

## A lump of mud a puglin throws. Every peer flies its own on the same arc; the
## host's is the one that hits. What it hits is told back to the thrower
## (`mud_landed`).
##
## Made to be seen coming: a fist-sized lump, lumpy and wet-shining with a pale
## rim round it so it stands off the ground behind it, spinning, shedding drops
## as it goes, with a dark spot on the ground under it that says where the arc
## is; a slap and a spray of drops where it lands, and a patch that dries.

const GRAVITY := 12.0
const RADIUS := 0.2
## How much bigger the lump is drawn than it hits (it must read in the air).
const SEEN := 1.45
## What a hero keeps of his grip on the ground standing in a patch.
const SLIP := 0.12
const LIFE := 4.0
const SPLAT_SOUND := "res://unverified/sounds/all/land.wav"
const THROW_SOUND := "res://unverified/sounds/all/jump.wav"

var _vel: Vector3 = Vector3.ZERO
var _thrower: Node3D
var _host: bool = false
var _age: float = 0.0
var _done: bool = false
var _lump: MeshInstance3D
var _shadow: MeshInstance3D
var _drip_in: float = 0.0
## A burning coal (an imp's) rather than mud: glows, sheds sparks, leaves no patch.
var ember: bool = false
## The fireball's pieces (an imp's): a white-hot core, a halo round it, the
## tail of fire and smoke it streams, its light.
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _glow: OmniLight3D
var _trail: Array[GPUParticles3D] = []
var _streaks: Array[MeshInstance3D] = []
static var _streak_tex: Texture2D

static var _material: StandardMaterial3D
static var _lump_mesh: ArrayMesh
static var _drop_mesh: SphereMesh
static var _shadow_mat: StandardMaterial3D
static var _ember_mat: StandardMaterial3D


static func fling(world: Node, from: Vector3, vel: Vector3, thrower: Node3D, host: bool,
		coal: bool = false) -> MudBall:
	var ball := MudBall.new()
	ball.ember = coal
	ball._vel = vel
	ball._thrower = thrower
	ball._host = host
	world.add_child(ball)
	ball.global_position = from
	Sfx.play(world, THROW_SOUND, null, from, 0.62, -8.0)
	return ball


## Wet mud: dark brown, glossy, a pale rim so a lump reads against earth.
static func mud() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.3, 0.19, 0.09)
		_material.roughness = 0.35
		_material.clearcoat_enabled = true
		_material.clearcoat = 0.8
		_material.clearcoat_roughness = 0.15
		_material.rim_enabled = true
		_material.rim = 0.7
		_material.rim_tint = 0.35
	return _material


## A coal: glowing orange-red, bright enough to read in any light.
static func coal() -> StandardMaterial3D:
	if _ember_mat == null:
		_ember_mat = StandardMaterial3D.new()
		_ember_mat.albedo_color = Color(0.25, 0.06, 0.02)
		_ember_mat.emission_enabled = true
		_ember_mat.emission = Color(1.0, 0.42, 0.1)
		_ember_mat.emission_energy_multiplier = 3.0
	return _ember_mat


## A lump rather than a ball: a sphere pushed in and out by a few lobes.
static func lump_mesh() -> ArrayMesh:
	if _lump_mesh == null:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 14
		s.rings = 8
		var arrays := s.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var lobes := [Vector3(1, 0.3, 0.2), Vector3(-0.4, 1, 0.3), Vector3(0.2, -0.5, 1), Vector3(-0.7, -0.6, -0.5)]
		for i in verts.size():
			var v := verts[i]
			var n := v.normalized()
			var k := 1.0
			for l: Vector3 in lobes:
				k += 0.16 * maxf(n.dot(l.normalized()), 0.0) ** 3
			k -= 0.08 * absf(sin(n.x * 7.0) * sin(n.y * 5.0 + 1.0))
			verts[i] = n * k * RADIUS
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		var st := SurfaceTool.new()
		var raw := ArrayMesh.new()
		raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		st.create_from(raw, 0)
		st.generate_normals()
		_lump_mesh = st.commit()
	return _lump_mesh


static func drop_mesh() -> SphereMesh:
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 1.0
		_drop_mesh.height = 2.0
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
	return _drop_mesh


## A lump, a drop and a patch to hang in front of the warm-up's camera, so the
## renderer builds their pipelines behind the black and not on the first throw
## ([PipelineWarmup]).
static func warm_props() -> Node3D:
	var holder := Node3D.new()
	var lump := MeshInstance3D.new()
	lump.mesh = lump_mesh()
	lump.material_override = mud()
	holder.add_child(lump)
	var drop := MeshInstance3D.new()
	drop.mesh = drop_mesh()
	drop.material_override = mud()
	drop.scale = Vector3.ONE * 0.05
	drop.position = Vector3(0.3, 0.0, 0.0)
	holder.add_child(drop)
	var patch := MudPatch.new()
	patch.position = Vector3(-0.3, -0.2, 0.0)
	holder.add_child(patch)
	return holder


func _ready() -> void:
	top_level = true
	_lump = MeshInstance3D.new()
	_lump.mesh = lump_mesh()
	_lump.material_override = mud()
	_lump.visible = not ember
	add_child(_lump)
	if ember:
		_make_fireball()
	else:
		# bigger than it hits, so it reads against the sky and the ground, and
		# a trail of wet clods behind it (the user's word, 2026-10-27)
		_lump.scale = Vector3.ONE * SEEN
		SkillFx.particles(self, global_position, {
			"amount": 26, "life": 0.45, "speed": Vector2(0.1, 0.4), "spread": 60.0,
			"gravity": Vector3(0, -4.0, 0), "size": Vector2(0.06, 0.12), "sphere": 0.08, "add": false,
			"colors": [Color(0.32, 0.2, 0.09, 0.95), Color(0.24, 0.15, 0.07, 0.0)],
		})
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.albedo_color = Color(0.05, 0.03, 0.02, 0.55)
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS * 1.3
	disc.bottom_radius = RADIUS * 1.3
	disc.height = 0.005
	disc.radial_segments = 14
	_shadow.mesh = disc
	_shadow.material_override = _shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var from := global_position
	_vel.y -= GRAVITY * delta
	var to := from + _vel * delta
	_lump.rotate_object_local(Vector3(1, 0.3, 0).normalized(), 9.0 * delta)
	# Squashed along the way it flies, a little.
	_lump.scale = Vector3(0.9, 0.9, 1.15) * SEEN
	if ember:
		_burn(delta)
	if _host and _thrower != null and is_instance_valid(_thrower):
		for node in get_tree().get_nodes_in_group("player"):
			var who := node as Node3D
			if who == null:
				continue
			var low := who.global_position + Vector3.UP * 0.3
			var high := who.global_position + Vector3.UP * 1.7
			if WeaponSweep.touches(from, to, RADIUS + 0.35, low, high):
				_thrower.call(&"mud_landed", who)
				_splash(to, false)
				return
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if not hit.is_empty():
		_splash(hit["position"], true, hit["normal"])
		return
	global_position = to
	# The spot under it.
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(to, to + Vector3.DOWN * 30.0, 1))
	if down.is_empty():
		_shadow.visible = false
	else:
		var ground: Vector3 = down["position"]
		var high := to.y - ground.y
		_shadow.visible = true
		_shadow.global_position = ground + Vector3.UP * 0.03
		var grow := 1.0 + high * 0.15
		_shadow.scale = Vector3(grow, 1.0, grow)
		_shadow.transparency = clampf(high / 8.0, 0.0, 0.85)
	# Drops flung off it.
	_drip_in -= delta
	if _drip_in <= 0.0 and not ember:
		_drip_in = 0.035
		MudDrop.spawn(get_parent(), to, _vel * 0.2 + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)),
				randf_range(0.03, 0.06), ember)
	if _age > LIFE:
		queue_free()


func _splash(at: Vector3, ground: bool, normal: Vector3 = Vector3.UP) -> void:
	_done = true
	var world := get_parent()
	if ember:
		_fire_burst(world, at, normal)
		queue_free()
		return
	for i in 14:
		var out := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * randf_range(1.5, 4.0)
		MudDrop.spawn(world, at + Vector3.UP * 0.1, out + normal * randf_range(1.5, 4.0), randf_range(0.03, 0.08), ember)
	Sfx.play(world, SPLAT_SOUND, null, at, randf_range(0.5, 0.6), -4.0)
	if ground and normal.y > 0.6 and not ember:
		var patch := MudPatch.new()
		world.add_child(patch)
		patch.global_position = at + normal * 0.02
	elif not ember and is_inside_tree():
		# it found him: the mud falls off him at his feet
		var down := get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0, 1))
		if not down.is_empty() and (down["normal"] as Vector3).y > 0.6:
			var patch := MudPatch.new()
			world.add_child(patch)
			patch.global_position = (down["position"] as Vector3) + Vector3.UP * 0.02
	queue_free()


## The imp's fireball (the user, 2026-10-27: the old one was an egg-shaped
## coal that broke into glowing crumbs): a small white-hot core in an orange
## halo, a comet's tail of fire that curls up into smoke behind it, sparks
## off it, a flickering light.
func _make_fireball() -> void:
	_core = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	s.radial_segments = 16
	s.rings = 8
	_core.mesh = s
	_core.material_override = SkillFx.glow(Color(1.0, 0.78, 0.4), 2.5, false)
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	_halo = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	_halo.mesh = q
	var hm := SkillFx.sprite_material(SkillFx.dot(), true)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.vertex_color_use_as_albedo = false
	hm.albedo_color = Color(1.0, 0.38, 0.05, 0.55)
	_halo.material_override = hm
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	# the tail: hot tongues left behind in the world as it flies on
	_trail.append(SkillFx.particles(self, global_position, {
		"amount": 45, "life": 0.25, "speed": Vector2(0.2, 0.6), "spread": 180.0,
		"gravity": Vector3(0, 1.5, 0), "size": Vector2(0.08, 0.16), "sphere": 0.09, "grow": 0.05,
		"tex": SkillFx.dot(), "add": true, "spin": true,
		"colors": [Color(1.0, 0.7, 0.3, 0.7), Color(1.0, 0.42, 0.08, 0.6), Color(0.8, 0.15, 0.02, 0.35),
				Color(0.3, 0.04, 0.0, 0.0)],
	}))
	_trail.append(SkillFx.particles(self, global_position, {
		"amount": 36, "life": 0.4, "speed": Vector2(0.2, 0.6), "spread": 180.0,
		"gravity": Vector3(0, 2.5, 0), "size": Vector2(0.18, 0.3), "sphere": 0.08, "grow": 0.2,
		"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false,
		"colors": [Color(1.0, 0.75, 0.3, 0.0), Color(1.0, 0.5, 0.1, 0.9), Color(0.8, 0.16, 0.02, 0.7),
				Color(0.2, 0.03, 0.0, 0.0)],
	}))
	# smoke curling off the end of the tail
	_trail.append(SkillFx.particles(self, global_position, {
		"amount": 18, "life": 0.9, "speed": Vector2(0.1, 0.3), "spread": 180.0,
		"gravity": Vector3(0, 0.8, 0), "size": Vector2(0.2, 0.35), "sphere": 0.1, "grow": 0.5,
		"add": false,
		"colors": [Color(0.2, 0.17, 0.15, 0.0), Color(0.22, 0.19, 0.17, 0.35), Color(0.3, 0.28, 0.27, 0.0)],
	}))
	# sparks flung off
	_trail.append(SkillFx.particles(self, global_position, {
		"amount": 16, "life": 0.5, "speed": Vector2(0.6, 1.6), "spread": 180.0,
		"gravity": Vector3(0, -3.0, 0), "size": Vector2(0.025, 0.045), "sphere": 0.08, "add": true,
		"colors": [Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.5, 0.1, 0.9), Color(1.0, 0.3, 0.05, 0.0)],
	}))
	for p in _trail:
		p.fixed_fps = 0
		p.interpolate = false
	# the tail itself: two streaks stretched back along its flight, turned to
	# the camera, white-gold inside an orange sheath
	for spec: Array in [[Color(1.0, 0.36, 0.05, 0.75), 0.42], [Color(1.0, 0.75, 0.35, 0.8), 0.15]]:
		var st := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2.ONE
		st.mesh = sq
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.albedo_texture = streak_tex()
		sm.albedo_color = spec[0]
		st.material_override = sm
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		st.top_level = true
		st.set_meta(&"width", spec[1])
		add_child(st)
		_streaks.append(st)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.5, 0.15)
	_glow.light_energy = 2.0
	_glow.omni_range = 3.5
	_glow.shadow_enabled = false
	add_child(_glow)


## The tail's streak: bright at its head (u 0), thinning and fading back.
static func streak_tex() -> Texture2D:
	if _streak_tex == null:
		var w := 128
		var h := 32
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for x in w:
			var u := float(x) / float(w - 1)
			var half := 0.5 * (1.0 - u * 0.75) * minf(1.0, (u + 0.04) * 9.0)
			for y in h:
				var v := absf(float(y) / float(h - 1) - 0.5)
				var edge := clampf(1.0 - v / maxf(half, 0.001), 0.0, 1.0)
				var a := edge * edge * pow(1.0 - u, 1.6)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_streak_tex = ImageTexture.create_from_image(img)
	return _streak_tex


## The fireball in flight: its core throbbing, its light flickering, its tail
## laid back along the way it came.
func _burn(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and _vel.length_squared() > 0.01:
		var dir := _vel.normalized()
		var length := clampf(_vel.length() * 0.08, 0.4, 1.3)
		var head := global_position + dir * 0.08
		var mid := head - dir * length * 0.5
		var side := dir.cross(cam.global_position - mid)
		if side.length_squared() > 0.0001:
			side = side.normalized()
			for st in _streaks:
				var wd := float(st.get_meta(&"width"))
				var x := -dir * length
				var y := side * wd
				st.global_transform = Transform3D(Basis(x, y, x.cross(y).normalized()), mid)
	var t := _age * 31.0
	var throb := 1.0 + 0.12 * sin(t) * sin(t * 0.37 + 1.0)
	_core.scale = Vector3.ONE * throb
	_halo.scale = Vector3.ONE * (0.92 + 0.16 * absf(sin(_age * 17.0)))
	_glow.light_energy = 1.8 + 0.5 * sin(t * 0.7) * sin(t * 0.23)


## Where the fireball breaks: a burst of flame that billows and rolls up into
## smoke, sparks, a flash of light. Its tail is left to burn out where it was.
func _fire_burst(world: Node, at: Vector3, normal: Vector3) -> void:
	for p in _trail:
		if is_instance_valid(p):
			var xf := p.global_transform
			remove_child(p)
			world.add_child(p)
			p.global_transform = xf
			p.emitting = false
			p.get_tree().create_timer(p.lifetime + 0.2, false).timeout.connect(p.queue_free)
	_trail.clear()
	var up := (normal + Vector3.UP).normalized()
	SkillFx.particles(world, at, {
		"amount": 30, "life": 0.5, "one_shot": true, "explosiveness": 0.9,
		"speed": Vector2(1.2, 3.0), "dir": up, "spread": 75.0, "damping": 5.0,
		"gravity": Vector3(0, 2.5, 0), "size": Vector2(0.18, 0.36), "sphere": 0.1, "grow": 0.1,
		"tex": SkillFx.dot(), "add": true, "spin": true,
		"colors": [Color(1.0, 0.72, 0.35, 0.8), Color(1.0, 0.42, 0.08, 0.7), Color(0.75, 0.15, 0.02, 0.3),
				Color(0.2, 0.03, 0.0, 0.0)],
	})
	SkillFx.particles(world, at, {
		"amount": 16, "life": 0.55, "one_shot": true, "explosiveness": 0.85,
		"speed": Vector2(0.6, 1.6), "dir": up, "spread": 60.0, "damping": 3.0,
		"gravity": Vector3(0, 3.5, 0), "size": Vector2(0.3, 0.5), "sphere": 0.1, "grow": 0.2,
		"tex": SkillFx.flame(), "quad": Vector2(0.5, 1.0), "add": false,
		"colors": [Color(1.0, 0.75, 0.3, 0.0), Color(1.0, 0.5, 0.1, 0.95), Color(0.8, 0.16, 0.02, 0.7),
				Color(0.2, 0.03, 0.0, 0.0)],
	})
	SkillFx.particles(world, at + Vector3.UP * 0.2, {
		"amount": 12, "life": 1.2, "one_shot": true, "explosiveness": 0.7,
		"speed": Vector2(0.3, 0.8), "dir": Vector3.UP, "spread": 50.0, "damping": 1.0,
		"gravity": Vector3(0, 0.9, 0), "size": Vector2(0.4, 0.7), "sphere": 0.15, "grow": 0.5,
		"add": false,
		"colors": [Color(0.2, 0.17, 0.15, 0.0), Color(0.22, 0.19, 0.17, 0.4), Color(0.32, 0.3, 0.29, 0.0)],
	})
	SkillFx.burst(world, at, Color(1.0, 0.5, 0.1), 22, Vector2(2.0, 5.0), up, 80.0,
			Vector2(0.025, 0.05), Vector3(0, -7, 0), 0.6)
	SkillFx.light(world, at, Color(1.0, 0.5, 0.15), 4.0, 5.0, 0.4)
	Sfx.play(world, SPLAT_SOUND, null, at, randf_range(0.75, 0.85), -8.0)


## A drop of mud off a lump or out of its splash, falling, gone when it lands.
class MudDrop extends MeshInstance3D:
	var _v := Vector3.ZERO
	var _t := 0.0

	static func spawn(world: Node, at: Vector3, vel: Vector3, size: float, spark: bool = false) -> void:
		var d := MudDrop.new()
		d._v = vel
		d.mesh = MudBall.drop_mesh()
		d.material_override = MudBall.coal() if spark else MudBall.mud()
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.scale = Vector3.ONE * size
		world.add_child(d)
		d.global_position = at

	func _process(delta: float) -> void:
		_t += delta
		_v.y -= MudBall.GRAVITY * delta
		global_position += _v * delta
		if _t > 0.9 or global_position.y < -50.0:
			queue_free()


## What a hero standing at `at` keeps of his grip on the ground: `SLIP` in a
## patch of mud (he slides on it), else 1.
static func grip_at(tree: SceneTree, at: Vector3) -> float:
	if tree == null:
		return 1.0
	for node in tree.get_nodes_in_group(&"mud_patch"):
		var p := node as MudPatch
		if p == null or not p.slippery():
			continue
		var d := p.global_position - at
		if absf(d.y) > 0.5:
			continue
		d.y = 0.0
		if d.length() < MudPatch.RADIUS * maxf(p.scale.x, p.scale.z):
			return SLIP
	return 1.0


## The brown patch a lump leaves on the ground, drying away; while it is wet
## a hero on it slides ([method MudBall.grip_at]).
class MudPatch extends MeshInstance3D:
	const RADIUS := 0.85
	const WET := 9.0
	var _age := 0.0
	var _mat: StandardMaterial3D

	func slippery() -> bool:
		return _age < WET

	func _ready() -> void:
		add_to_group(&"mud_patch")
		var disc := CylinderMesh.new()
		disc.top_radius = RADIUS
		disc.bottom_radius = RADIUS
		disc.height = 0.01
		disc.radial_segments = 14
		mesh = disc
		_mat = MudBall.mud().duplicate() as StandardMaterial3D
		_mat.rim_enabled = false
		# wet but dark: the sky's sheen on it read as a pale disc
		_mat.albedo_color = Color(0.2, 0.13, 0.06)
		_mat.clearcoat = 0.3
		_mat.metallic_specular = 0.25
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material_override = _mat
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rotate_y(randf() * TAU)
		scale = Vector3(randf_range(0.7, 1.3), 1.0, randf_range(0.7, 1.3))

	func _process(delta: float) -> void:
		_age += delta
		if _age > WET:
			_mat.albedo_color.a = clampf(1.0 - (_age - WET) / 3.0, 0.0, 1.0)
			if _age > WET + 3.0:
				queue_free()
