class_name RoomHazards
extends Node

## A place's own dangers while its creatures are up (the user's word,
## 2026-10-28: the director's plan, liked):
##
## * **cave** — stalactites break from the roof: a ring on the floor where one
##   will land, a moment to step out, then it falls and shatters.
## * **crypt** — the old vault sheds its stones the same way.
## * **swamp** — pools of venom lie about the floor (as Arkdeva's lies,
##   [Venom]), bubbling, a thin green steam over them; two more hidden in
##   the water, seen only by their bubbles; standing in one fills his venom
##   ([HeroPoison]).
##
## Made by [CombatDirector] for the place he has come to; the host chooses
## when and where a stone falls and every peer sees it ([method net_fall]);
## the pools are laid the same on every peer (from the place's own seed).

## A stone: how often, how long its ring shows before it falls, how far it
## falls, its reach and its blow (a share of his whole life).
const FALL_EVERY := Vector2(4.5, 7.5)
const FALL_TELL := 1.3
const FALL_HEIGHT := 9.0
const FALL_TIME := 0.32
const FALL_R := 1.7
const FALL_HURT := 0.18
## Near him: within this of where he stands (now and then right on him).
const FALL_NEAR := 3.5
## The pools: how many, how wide, the venom a second in one.
const POOLS := 4
const POOL_R := Vector2(1.8, 3.0)
const POOL_VENOM := 0.22
## And this many hidden in the water, seen only by their bubbles.
const HIDDEN := 2

var kind := ""
var _d: Dungeon
var _i := -1
var _next := 0.0
var _pools: Array = []
var _combo := 88000


static func make(d: Dungeon, i: int) -> RoomHazards:
	var place := d._place_of(i)
	var k := ""
	match place:
		"cave":
			k = "stalactites"
		"crypt":
			k = "stones"
		"swamp":
			k = "pools"
	if k == "":
		return null
	var h := RoomHazards.new()
	h.name = "RoomHazards"
	h.kind = k
	h._d = d
	h._i = i
	h._next = _now() + 3.0
	return h


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _ready() -> void:
	if kind == "pools":
		_lay_pools()


func _fighting() -> bool:
	for body in _d._alive:
		if is_instance_valid(body) and not bool(body.get("is_dead")) and body.visible:
			return true
	return false


func _process(delta: float) -> void:
	if _d == null or _d.current != _i:
		return
	if kind == "pools":
		_in_pools(delta)
		return
	if not _d.decides() or _now() < _next or not _fighting():
		return
	_next = _now() + randf_range(FALL_EVERY.x, FALL_EVERY.y)
	var heroes := _d._heroes()
	var standing: Array = []
	for h in heroes:
		if not h.is_dead:
			standing.append(h)
	if standing.is_empty():
		return
	var hero: Node3D = standing[randi() % standing.size()]
	var off := Vector3.ZERO
	if randf() > 0.3:
		var a := randf() * TAU
		off = Vector3(cos(a), 0.0, sin(a)) * randf_range(0.8, FALL_NEAR)
	var at := _floor(hero.global_position + off)
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		net_fall.rpc(at)
	else:
		net_fall(at)


func _floor(at: Vector3) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 10.0, 1))
	return hit["position"] if not hit.is_empty() else at


#region Falling
@rpc("authority", "call_local", "reliable")
func net_fall(at: Vector3) -> void:
	var world := Blood.world_of(_d)
	if world == null:
		return
	var spot := Node3D.new()
	spot.name = "Falling"
	world.add_child(spot)
	spot.global_position = at + Vector3.UP * 0.04
	# the ring where it will land, filling in
	var ring := _disc(FALL_R, Color(1.0, 0.35, 0.15, 0.16))
	spot.add_child(ring)
	var fill := _disc(FALL_R, Color(1.0, 0.45, 0.2, 0.32))
	fill.position.y = 0.01
	fill.scale = Vector3(0.05, 1.0, 0.05)
	spot.add_child(fill)
	# the stone, up out of sight
	var stone := MeshInstance3D.new()
	if kind == "stalactites":
		var cone := CylinderMesh.new()
		cone.top_radius = 0.5
		cone.bottom_radius = 0.02
		cone.height = 2.6
		cone.radial_segments = 6
		cone.rings = 1
		stone.mesh = cone
	else:
		var rock := SphereMesh.new()
		rock.radius = 0.6
		rock.height = 1.0
		rock.radial_segments = 6
		rock.rings = 3
		stone.mesh = rock
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.41, 0.4) if kind == "stalactites" else Color(0.38, 0.36, 0.33)
	mat.roughness = 1.0
	stone.material_override = mat
	stone.position = Vector3.UP * FALL_HEIGHT
	stone.visible = false
	spot.add_child(stone)
	var tw := spot.create_tween()
	tw.tween_property(fill, "scale", Vector3.ONE, FALL_TELL - FALL_TIME)
	tw.tween_callback(func() -> void: stone.visible = true)
	tw.tween_property(stone, "position", Vector3.UP * (1.3 if kind == "stalactites" else 0.4), FALL_TIME) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_landed.bind(spot, stone, ring, fill))
	tw.tween_interval(0.8)
	tw.tween_callback(spot.queue_free)


func _landed(spot: Node3D, stone: MeshInstance3D, ring: Node3D, fill: Node3D) -> void:
	var at := spot.global_position
	ring.visible = false
	fill.visible = false
	stone.visible = false
	SkillFx.burst(spot.get_parent(), at + Vector3.UP * 0.3, Color(0.55, 0.52, 0.48), 50,
			Vector2(3.0, 7.0), Vector3.UP, 120.0, Vector2(0.06, 0.18), Vector3(0, -9.0, 0), 0.7)
	ImpactFx.thud(spot, at, true)
	Sfx.play(spot, Dungeon.SND + "crumble.wav", null, at, randf_range(0.9, 1.15), 2.0)
	if not _d.decides():
		return
	_combo += 1
	for hero in _d._heroes():
		if hero.is_dead:
			continue
		var gap := Vector2(hero.global_position.x - at.x, hero.global_position.z - at.z).length()
		if gap <= FALL_R and absf(hero.global_position.y - at.y) < 2.5:
			hero.receive_blow(hero.max_health * FALL_HURT, spot, 0, 1, _combo, false)
#endregion


#region Pools
func _lay_pools() -> void:
	var world := Blood.world_of(_d)
	if world == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 6151 * (_i + 1) + 31 * _d.id
	var c := _d.centre(_i)
	var room: Dictionary = _d._room(_i)
	var w := float(room.get("w", 40.0)) * 0.35
	var l := float(room.get("l", 60.0)) * 0.3
	# (the room's own ground height: its water lies under it, in the hollows)
	var base := c.y
	# (the user's word, 2026-10-28: the swamp itself as it was; the poison as
	# Arkdeva's venom lies on the ground, bubbling, a thin green steam; and one
	# or two hidden in the water, seen only by their bubbles)
	for k in POOLS + HIDDEN:
		var hidden := k >= POOLS
		var at := c
		for tries in 40:
			at = c + Vector3(rng.randf_range(-w, w), 0.0, rng.randf_range(-l, l))
			var y := _floor(at).y
			if (not hidden and y > base - 0.03) or (hidden and y < base + SwampMere.SURFACE - 0.12):
				break
		var r := rng.randf_range(POOL_R.x, POOL_R.y)
		var pool := Node3D.new()
		pool.name = "PoisonPool"
		world.add_child(pool)
		pool.global_position = _floor(at)
		if hidden:
			# under the water: bubbles breaking at its surface, nothing else
			var fizz := _bubbles(r * 0.6, false)
			pool.add_child(fizz)
			fizz.global_position = Vector3(at.x, base + SwampMere.SURFACE - 0.02, at.z)
		else:
			var venom := Venom.pool(pool, pool.global_position + Vector3.UP * 0.3, r, 1.0e7)
			if venom != null:
				venom.name = "Venom"
			pool.add_child(_bubbles(r * 0.7, true))
		_pools.append([pool, r])
	tree_exiting.connect(func() -> void:
		for p: Array in _pools:
			if is_instance_valid(p[0]):
				(p[0] as Node).queue_free())


var _pool_clock := 0.0


func _in_pools(delta: float) -> void:
	if not _d.decides():
		return
	# a few times a second, not every frame (the venom goes out to every peer)
	_pool_clock += delta
	if _pool_clock < 0.25:
		return
	delta = _pool_clock
	_pool_clock = 0.0
	for hero in _d._heroes():
		if hero.is_dead:
			continue
		for p: Array in _pools:
			var pool := p[0] as Node3D
			if not is_instance_valid(pool):
				continue
			var gap := Vector2(hero.global_position.x - pool.global_position.x,
					hero.global_position.z - pool.global_position.z).length()
			if gap <= float(p[1]) and absf(hero.global_position.y - pool.global_position.y) < 1.5:
				var venom := HeroPoison.of(hero)
				if venom != null:
					venom.apply_venom(HeroPoison.FULL * POOL_VENOM * delta)
				break
#endregion


static func _disc(r: float, tint: Color) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.03
	cyl.radial_segments = 36
	d.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = tint
	d.material_override = m
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return d


## Bubbles rising and breaking off a pool, within `r` of its middle, small and
## quick; with `wisp`, a thin green steam over it as well, low and faint.
static func _bubbles(r: float, wisp: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Bubbles"
	var b := GPUParticles3D.new()
	b.amount = int(clampf(r * 10.0, 8.0, 24.0))
	b.lifetime = 0.9
	b.preprocess = 1.0
	b.randomness = 0.6
	b.visibility_aabb = AABB(Vector3(-r - 0.5, -0.3, -r - 0.5), Vector3(r * 2.0 + 1.0, 1.5, r * 2.0 + 1.0))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = r
	m.emission_shape_scale = Vector3(1.0, 0.02, 1.0)
	m.direction = Vector3.UP
	m.spread = 6.0
	m.initial_velocity_min = 0.05
	m.initial_velocity_max = 0.18
	m.gravity = Vector3.ZERO
	m.scale_min = 0.05
	m.scale_max = 0.13
	# swell, then burst
	var swell := Curve.new()
	swell.add_point(Vector2(0.0, 0.2))
	swell.add_point(Vector2(0.85, 1.0))
	swell.add_point(Vector2(1.0, 0.0))
	var st := CurveTexture.new()
	st.curve = swell
	m.scale_curve = st
	b.process_material = m
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.45, 0.85, 0.2, 0.75)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.roughness = 0.15
	bm.metallic_specular = 0.9
	bm.emission_enabled = true
	bm.emission = Color(0.25, 0.6, 0.1)
	bm.emission_energy_multiplier = 0.4
	ball.material = bm
	b.draw_pass_1 = ball
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(b)
	if wisp:
		var w := GPUParticles3D.new()
		w.amount = int(clampf(r * 4.0, 5.0, 10.0))
		w.lifetime = 2.6
		w.preprocess = 2.6
		w.visibility_aabb = AABB(Vector3(-r - 1.0, -0.3, -r - 1.0), Vector3(r * 2.0 + 2.0, 3.5, r * 2.0 + 2.0))
		var wm := ParticleProcessMaterial.new()
		wm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		wm.emission_sphere_radius = r * 0.8
		wm.emission_shape_scale = Vector3(1.0, 0.02, 1.0)
		wm.direction = Vector3.UP
		wm.spread = 8.0
		wm.initial_velocity_min = 0.2
		wm.initial_velocity_max = 0.4
		wm.gravity = Vector3.ZERO
		wm.scale_min = 0.18
		wm.scale_max = 0.32
		var thin := Curve.new()
		thin.add_point(Vector2(0.0, 0.5))
		thin.add_point(Vector2(1.0, 1.0))
		var tt := CurveTexture.new()
		tt.curve = thin
		wm.scale_curve = tt
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.55, 1.0, 0.35, 0.0))
		ramp.add_point(0.25, Color(0.5, 0.95, 0.3, 0.12))
		ramp.set_color(ramp.get_point_count() - 1, Color(0.45, 0.8, 0.3, 0.0))
		var rt := GradientTexture1D.new()
		rt.gradient = ramp
		wm.color_ramp = rt
		w.process_material = wm
		var quad := QuadMesh.new()
		# tall and narrow: a thread of steam, not a ball of it
		quad.size = Vector2(0.6, 1.6)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		qm.vertex_color_use_as_albedo = true
		qm.albedo_texture = SkillFx.dot()
		quad.material = qm
		w.draw_pass_1 = quad
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.position.y = 0.5
		root.add_child(w)
	return root